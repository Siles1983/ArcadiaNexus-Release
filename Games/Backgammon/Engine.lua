local A, L = ArcadiaNexus, ArcadiaNexus.BG_Logic
A.BG_Engine = { state = "IDLE", mode = "solo", _sessionId = nil }
local E = A.BG_Engine
local guard = A.TimerGuard.New()
local networkGuard = A.TimerGuard.New()
local searchGuard = A.TimerGuard.New()
E._timerGuard = guard
local function Multiplayer() return A.HasMultiplayer and A.HasMultiplayer() end
local function Notify()
    if A.BG_Renderer and A.BG_Renderer.Render then
        local ok,err=pcall(A.BG_Renderer.Render,A.BG_Renderer)
        if not ok and GH_LogError then pcall(GH_LogError,"BackgammonRenderer",tostring(err)) end
    end
    if E.mode ~= "solo" and Multiplayer() then
        local ok,err=pcall(A.Match.PresentGameView,L.GAME_ID,E:GetView())
        if not ok and GH_LogError then pcall(GH_LogError,"BackgammonMatchView",tostring(err)) end
    end
end
local function Sound()
    if A.BG_Settings:Get("soundEnabled") and PlaySound then PlaySound(857) end
end
function E:Board() return self.match and self.match:GetPublicState() or self.public end
function E:ResetDraft()
    searchGuard:Cancel(); self._work=nil; self._busy=false
    self.draft,self._turns,self._draftRevision={},nil,nil
end
function E:_Work(fn,done,s)
    searchGuard:Cancel()
    local units=0
    local job={board=s,revision=s.revision,sid=self._sessionId,done=done}
    job.co=coroutine.create(function()
        return fn(function()
            units=units+1
            if units>64 then units=1; coroutine.yield() end
        end)
    end)
    self._work,self._busy=job,true
    self:_ResumeWork(job)
end
function E:_ResumeWork(job)
    if self._work~=job or self:Board()~=job.board or job.board.revision~=job.revision
        or not A.GameSession:IsSession(self,job.sid) then return end
    local ok,value=coroutine.resume(job.co)
    if not ok then
        self._work,self._busy=nil,false; self._notice="search_error"
        if GH_LogError then pcall(GH_LogError,"BackgammonSearch",tostring(value)) end
        Notify(); return
    end
    if coroutine.status(job.co)=="dead" then
        self._work,self._busy=nil,false; job.done(value)
    else
        searchGuard:After(0,function() E:_ResumeWork(job) end)
    end
end
function E:SyncDraft()
    local s = self:Board()
    if s and self._draftRevision ~= s.revision then
        self:ResetDraft()
        self._draftRevision=s.revision
        if s.phase=="move" and self._sessionId then
            self:_Work(function(checkpoint) return L.BuildPolicy(s,checkpoint) end,function(policy)
                self._turns=policy; Notify(); self:ScheduleAI()
            end,s)
        end
    end
end
function E:Persist()
    if self.mode == "solo" and self.slot and self.public then
        A.BG_Settings:SaveSlot(self.slot, { board = L.Serialize(self.public),
            version=2,runId=self.runId,difficulty = self.difficulty, timestamp = time and time() or 0 })
    end
end
function E:CanContinue(saved)
    if type(saved)~="table" or saved.version~=nil and saved.version~=2
        or saved.difficulty~=nil and saved.difficulty~="easy" and saved.difficulty~="normal" and saved.difficulty~="hard" then return false end
    local board=L.Deserialize(saved.board)
    if not board or board.winner~=0 then return false end
    if saved.version==2 then
        local LR=A.LocalResults
        if not saved.difficulty or not LR:GetSerial(L.GAME_ID,saved.runId) or not LR:GetJournal().issued[saved.runId]
            or LR:GetReceipt(saved.runId) or A.BG_Settings:GetPending()[saved.runId] then return false end
    elseif saved.runId~=nil then return false end
    return true
end
function E:RetryLocalResults()
    for id,data in pairs(A.BG_Settings:GetPending()) do
        local copy=L.Copy(data)
        A.Engine:Emit("GAME_RESULT",copy)
        if copy.processed then A.BG_Settings:ClearPending(id) end
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
            if not self:CanContinue(saved) then self._notice = "bad_save"; Notify(); return false end
            board=L.Deserialize(saved.board)
        else board = L.New() end
    end
    self:RetryLocalResults()
    if mode ~= "solo" and self.match and not self.match._closed and not (A.Match and A.Match.ClientSettled and A.Match.ClientSettled(self.match)) then
        Notify()
        return false
    end
    if mode == "solo" then self:StopGame() end
    self._dialogShown = false
    self:ResetDraft()
    if mode == "solo" then
        self.mode, self._notice, self._resultEmitted = mode, nil, false
        self.slot = config.slot or 1
        self.difficulty = (saved and saved.difficulty) or config.difficulty or A.BG_Settings:Get("difficulty")
        if self.difficulty ~= "easy" and self.difficulty ~= "hard" then self.difficulty = "normal" end
        self.public = board
        local previous = self._sessionId
        self._sessionId = A.Lifecycle:RestartGame(L.GAME_ID, self._sessionId)
        if not self._sessionId then self._sessionId = previous; self.public=nil; return false end
        self.runId=(saved and saved.runId) or A.LocalResults:NewRun(L.GAME_ID)
        self.resultData=nil
        self.state = "PLAYING"
        self:Persist()
    else
        local previousMode = self.mode
        local sid = A.Lifecycle:ClaimRestart(L.GAME_ID, self._sessionId)
        if not sid then
            self._notice = "session"
            Notify()
            return false
        end
        local retiring = self.match
        if retiring and not (A.Match.ReleaseSettledClient and A.Match.ReleaseSettledClient(self, retiring)) and self.match and not self.match._closed then
            A.Lifecycle:EndGame(L.GAME_ID, sid)
            self._sessionId = nil
            self._notice = "session"
            Notify()
            return false
        end
        local node = A.Match.CreateGameClient(A.BG_Match.Options(self))
        if self.match and not self.match._closed then
            if node then node:Dispose() end
            A.Lifecycle:EndGame(L.GAME_ID, sid)
            self._sessionId = nil
            self.mode = previousMode
            self._notice = "session"
            Notify()
            return false
        end
        if not node then
            A.Lifecycle:EndGame(L.GAME_ID, sid)
            self._sessionId = nil
            self.mode, self._notice = previousMode or "solo", "nomp"
            Notify()
            return false
        end
        self.match = node
        self.mode, self._notice, self._resultEmitted = mode, nil, false
        self._sessionId = sid
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
    local current=self:Board()
    local needsPolicy=current and current.phase=="move" and self._draftRevision~=current.revision
    self:SyncDraft()
    -- The completed search schedules the response, including synchronous small graphs.
    if needsPolicy then return end
    local s = self:Board()
    if self.mode ~= "solo" or self.state ~= "PLAYING"
        or not s or s.turn ~= 2 or s.phase == "opening" or self._busy then return end
    local sid, revision = self._sessionId, s.revision
    guard:After(0.65, function()
        if not A.GameSession:IsSession(E, sid) or E:Board() ~= s or s.revision ~= revision then return end
        if s.phase == "roll" then E:ApplyLocal("ROLL", nil, 2)
        elseif s.phase == "move" then
            E:_Work(function(checkpoint) return A.BG_AI.Choose(s,E.difficulty,E._turns,nil,checkpoint) end,
                function(seq) if seq then E:ApplyLocal("TURN",L.EncodeMoves(seq),2) end end,s)
            Notify()
        end
    end)
end
function E:EmitResult(s, seat, resultId)
    if self._resultEmitted then return true end
    local data={ gameId = L.GAME_ID,
        resultId = resultId, matchHost = resultId and self.match and self.match.hostKey,
        difficulty = self.mode == "solo" and self.difficulty or "multiplayer",
        result = s.winner == seat and "WIN" or "LOSS", score = 0,
        stats = { pointsWon = s.winner == seat and s.pointsWon or 0 } }
    if self.mode=="solo" then
        self._resultEmitted = true
        guard:Cancel(); self:ResetDraft()
        data.ruleVersion,data.runId=1,self.runId
        self.resultData=data
        A.BG_Settings:SavePending(data)
        A.BG_Settings:SaveSlot(self.slot,nil)
        local sid=self._sessionId; self._sessionId=nil
        if sid then A.Lifecycle:EndGame(L.GAME_ID,sid) end
    else self.resultData=data end
    A.Engine:Emit("GAME_RESULT",data)
    if resultId then
        if data.matchBooked ~= true then return false end
        self._resultEmitted = true
        return true
    end
    if data.processed then A.BG_Settings:ClearPending(data.runId) end
end
function E:ApplyLocal(kind, payload, seat)
    local s = self.public
    if self.mode~="solo" or self.state~="PLAYING" or not s or self._busy then return false end
    if not L.Apply(s, {kind = kind, c = payload, n = s.revision}, seat) then return false end
    if s.winner ~= 0 then
        self.state = "FINISHED"
        self:EmitResult(s, 1)
    else self:Persist() end
    if self.public~=s then return true end
    Sound()
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
    local booked
    if s and s.winner ~= 0 and node.seat then
        booked = self:EmitResult(s, node.seat, node.matchId .. "-R1")
    end
    Notify()
    return booked
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
    local canAct = self.state == "PLAYING" and seat == actor and not self._pending and not self._busy
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
        lobbyPlayers = players, notice = self._notice, pending = self._pending ~= nil,
        computing=self._busy==true,difficulty=self.mode=="solo" and self.difficulty or "multiplayer" }
end
function E:HideView() if self.match then self.match:HideView() end end
function E:SaveAndPause()
    if self.mode ~= "solo" then self:HideView(); return end
    if self.draft and #self.draft>0 then self._discardedDraft=true end
    if self.state == "PLAYING" then self:Persist() end
    if self._sessionId then A.Lifecycle:PauseGame(L.GAME_ID,self._sessionId) end
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
    self.runId,self.resultData=nil,nil
    Notify()
end
