local A, L = ArcadiaNexus, ArcadiaNexus.BG_Logic
A.BG_Engine = { state = "IDLE", mode = "solo", _sessionId = nil }
local E = A.BG_Engine
local guard = A.TimerGuard.New()
local networkGuard = A.TimerGuard.New()
E._timerGuard = guard
local function Multiplayer() return A.HasMultiplayer and A.HasMultiplayer() end
local function Notify()
    if A.BG_Renderer and A.BG_Renderer.Render then A.BG_Renderer:Render() end
    if E.mode ~= "solo" and Multiplayer() then A.Match.PresentGameView(L.GAME_ID, E:GetView()) end
end
local function Sound()
    if A.BG_Settings:Get("soundEnabled") and PlaySound then PlaySound(857) end
end
function E:Board() return self.match and self.match:GetPublicState() or self.public end
function E:ResetDraft() self.draft, self._turns, self._draftRevision = {}, nil, nil end
function E:SyncDraft()
    local s = self:Board()
    if s and self._draftRevision ~= s.revision then
        self:ResetDraft()
        self._draftRevision, self._turns = s.revision, L.LegalTurns(s)
    end
end
function E:Persist()
    if self.mode == "solo" and self.slot and self.public then
        A.BG_Settings:SaveSlot(self.slot, { board = L.Serialize(self.public),
            difficulty = self.difficulty, timestamp = time and time() or 0 })
    end
end
function E:StartGame(config)
    config = config or {}
    local mode = config.mode or "solo"
    if mode ~= "solo" and mode ~= "host" and mode ~= "join" and mode ~= "rejoin" then return false end
    if mode ~= "solo" and not Multiplayer() then self._notice = "nomp"; Notify(); return false end
    if (mode == "join" or mode == "rejoin") and (type(config.joinTarget) ~= "string" or config.joinTarget == "") then return false end
    if mode == "rejoin" and (type(config.matchId) ~= "string" or config.matchId == "") then return false end
    local saved, board
    if mode == "solo" then
        local slot = config.slot or 1
        if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > 3 then return false end
        if config.resume then
            saved = A.BG_Settings:LoadSlot(slot)
            board = saved and L.Deserialize(saved.board)
            if not board or board.winner ~= 0 then self._notice = "bad_save"; Notify(); return false end
        else board = L.New() end
    end
    self:StopGame()
    self.mode, self._notice, self._resultEmitted = mode, nil, false
    self._dialogShown = false
    self:ResetDraft()
    if mode == "solo" then
        self.slot = config.slot or 1
        self.difficulty = (saved and saved.difficulty) or config.difficulty or A.BG_Settings:Get("difficulty")
        if self.difficulty ~= "easy" and self.difficulty ~= "hard" then self.difficulty = "normal" end
        self.public = board
        self._sessionId = A.Lifecycle:RestartGame(L.GAME_ID, self._sessionId)
        self.state = "PLAYING"
        self:Persist()
    else
        self.match = A.Match.CreateGameClient(A.BG_Match.Options(self))
        if not self.match then self.mode = "solo"; self._notice = "nomp"; Notify(); return false end
        self._sessionId = A.Lifecycle:RestartGame(L.GAME_ID, self._sessionId)
        self.state = "LOBBY"
        local ok
        if mode == "host" then
            if config.policy and self.match.SetPolicy then
                self.match:SetPolicy(config.policy, config.pin)
            end
            ok = self.match:HostMatch()
        elseif mode == "rejoin" then
            ok = self.match:Rejoin(config.joinTarget, config.matchId)
            self._notice = "rejoin"
        else
            ok = self.match:Join(config.joinTarget, config.pin)
        end
        if not ok then self:StopGame(); return false end
        if mode ~= "host" and self.match.GetState and self.match:GetState() ~= "LOBBY" then
            self.state = "IDLE"
        end
    end
    Notify()
    self:ScheduleAI()
    return true
end
function E:ScheduleAI()
    guard:Cancel()
    local s = self:Board()
    if self.mode ~= "solo" or self.state ~= "PLAYING"
        or not s or s.turn ~= 2 or s.phase == "opening" then return end
    local sid, revision = self._sessionId, s.revision
    guard:After(0.65, function()
        if not A.GameSession:IsSession(E, sid) or E:Board() ~= s or s.revision ~= revision then return end
        if s.phase == "roll" then E:ApplyLocal("ROLL", nil, 2)
        elseif s.phase == "move" then
            local seq = A.BG_AI.Choose(s, E.difficulty)
            if seq then E:ApplyLocal("TURN", L.EncodeMoves(seq), 2) end
        end
    end)
end
function E:EmitResult(s, seat, resultId)
    if self._resultEmitted then return end
    self._resultEmitted = true
    A.Engine:Emit("GAME_RESULT", { gameId = L.GAME_ID,
        resultId = resultId, matchHost = resultId and self.match and self.match.hostKey,
        difficulty = self.mode == "solo" and self.difficulty or "multiplayer",
        result = s.winner == seat and "WIN" or "LOSS", score = 0,
        stats = { pointsWon = s.winner == seat and s.pointsWon or 0 } })
end
function E:ApplyLocal(kind, payload, seat)
    local s = self.public
    if not L.Apply(s, {kind = kind, c = payload, n = s.revision}, seat) then return false end
    Sound()
    if s.winner ~= 0 then
        self.state = "FINISHED"
        self:EmitResult(s, 1)
        if self.slot then A.BG_Settings:SaveSlot(self.slot, nil) end
    else self:Persist() end
    Notify()
    self:ScheduleAI()
    return true
end
function E:Submit(kind, payload)
    local v = self:GetView()
    if not v.canAct then return false end
    if self.mode == "solo" then return self:ApplyLocal(kind, payload, v.seat) end
    if not Multiplayer() or not self.match then return false end
    local revision = self:Board().revision
    self._pending = { kind = kind, payload = payload, revision = revision, attempts = 0 }
    self.match:SendIntent(kind, { c = payload, n = revision })
    self:RetryPending()
    Notify()
    return true
end
function E:RetryPending()
    networkGuard:Cancel()
    local pending, node, sid = self._pending, self.match, self._sessionId
    if not pending or not node then return end
    networkGuard:After(2.5, function()
        if E._pending ~= pending or E.match ~= node or not A.GameSession:IsSession(E, sid) then return end
        node:RequestSnapshot()
        if E._pending ~= pending then return end
        pending.attempts = pending.attempts + 1
        if pending.attempts > 3 then
            E._pending, E._notice = nil, "network_wait"
            Notify(); return
        end
        node:SendIntent(pending.kind, { c = pending.payload, n = pending.revision })
        E:RetryPending()
    end)
end
function E:Resync()
    if Multiplayer() and self.match then self.match:RequestSnapshot() end
end
function E:Roll() return self:Submit("ROLL") end
function E:Move(from, to, die)
    local v = self:GetView()
    if not v.canAct then return false end
    for _, m in ipairs(v.moves) do
        if m.from == from and m.to == to and m.die == die then
            self.draft[#self.draft + 1] = m
            Sound(); Notify(); return true
        end
    end
    return false
end
function E:Undo()
    if not self:GetView().canAct or #self.draft == 0 then return end
    self.draft[#self.draft] = nil
    Notify()
end
function E:Confirm()
    if not self:GetView().complete then return false end
    return self:Submit("TURN", L.EncodeMoves(self.draft))
end
function E:SetReady(ready) if Multiplayer() and self.match then self.match:SetReady(ready ~= false); Notify() end end
function E:TryStartMatch()
    if Multiplayer() and self.match then
        if not self.match:TryStart() then self._notice = "need_ready" else self._notice = nil end
        Notify()
    end
end
function E:OnMatchPublic(node)
    if self.match ~= node or not Multiplayer() or node:GetState() == "ABORTED" then return end
    A.Match.UpdateGamePresence(node)
    self._notice = nil
    if self._pending and node:GetPublicState().revision > self._pending.revision then
        self._pending = nil; networkGuard:Cancel()
    end
    if node:GetState() == "FINISHED" and node:GetPublicState().winner ~= 0 then self:OnMatchResult(node) end
    Notify()
end
function E:OnMatchState(node, state)
    if self.match ~= node then return end
    self.state = state == "ABORTED" and "IDLE" or state
    A.Match.UpdateGamePresence(node)
    if state == "ABORTED" and self._sessionId then
        self._pending = nil; networkGuard:Cancel()
        A.Lifecycle:EndGame(L.GAME_ID, self._sessionId); self._sessionId = nil
        self._notice = self._notice or "aborted"
    end
    Notify()
end
function E:OnMatchResult(node)
    if self.match ~= node or self.state ~= "FINISHED" or node:GetState() ~= "FINISHED"
        or not self._sessionId then return end
    local s = node:GetPublicState()
    if s and s.winner ~= 0 and node.seat then self:EmitResult(s, node.seat, node.matchId .. "-R1") end
    Notify()
end
function E:OnMatchReject(fields, node)
    if node and self.match ~= node then return end
    self._notice = fields.reason or "aborted"
    local Shell = A.MatchShell
    if Shell and Shell.OnJoinRejected then
        Shell.OnJoinRejected(L.GAME_ID, fields.reason, fields)
    end
    Notify()
end
function E:GetView()
    self:SyncDraft()
    local s = self:Board() or L.New()
    local seat = self.mode ~= "solo" and self.match and self.match.seat or 1
    local actor = s.phase == "opening" and 1 or s.turn
    local canAct = self.state == "PLAYING" and seat == actor and not self._pending
    local preview, remaining = L.Copy(s), {}
    for i, d in ipairs(s.dice) do remaining[i] = d end
    for _, m in ipairs(self.draft or {}) do
        preview = L.Step(preview, s.turn, m)
        for i, d in ipairs(remaining) do if d == m.die then table.remove(remaining, i); break end end
    end
    local moves, complete = L.NextMoves(self._turns or {}, self.draft or {})
    local players = {}
    if self.match then
        for i = 1, 2 do
            local key = self.match.seats[i]
            if key then players[#players + 1] = { key = key, name = key:match("^([^-]+)") or key,
                ready = self.match.ready[i] == true, self = key == self.match.playerKey } end
        end
    end
    return { state = self.state, mode = self.mode, pub = s, board = preview,
        remaining = remaining, seat = seat, canAct = canAct, moves = moves,
        complete = complete and s.phase == "move", draftCount = #(self.draft or {}),
        mp = self.mode ~= "solo", isHost = self.match and self.match.isHost,
        lobbyPlayers = players, notice = self._notice, pending = self._pending ~= nil }
end
function E:HideView() if self.match then self.match:HideView() end end
function E:SaveAndPause()
    if self.mode ~= "solo" then self:HideView(); return end
    if self._sessionId then A.Lifecycle:PauseGame(L.GAME_ID, self._sessionId) end
    if self.state == "PLAYING" then self:Persist() end
    self:StopGame()
end
function E:StopGame()
    guard:Cancel()
    networkGuard:Cancel(); self._pending = nil
    if self.mode == "solo" and self.state == "PLAYING" then self:Persist() end
    if self._sessionId then A.Lifecycle:EndGame(L.GAME_ID, self._sessionId); self._sessionId = nil end
    local node = self.match
    self.match = nil
    if node and Multiplayer() then A.Match.CloseGameClient(node) end
    self.state, self.public = "IDLE", nil
    self:ResetDraft()
    -- Complete the MATCH-shell exit before exposing the local catalogue again.
    if self.mode ~= "solo" and Multiplayer() then A.Match.PresentGameView(L.GAME_ID, self:GetView()) end
    self.mode, self._notice, self.difficulty = "solo", nil, nil
    Notify()
end
