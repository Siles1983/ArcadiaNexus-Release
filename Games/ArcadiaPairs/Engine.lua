--[[
    Games/ArcadiaPairs/Engine.lua
    Spiele-Tab: Solo vs. Timer. MP: 2-Sitz-Duell, Layout nur Host, 4×4.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Engine = {}
local E = ArcadiaNexus.AP_Engine

E._sessionId = nil
E.activeGame = nil
E.activeConfig = nil
E.state = "IDLE"
E.mode = "hotseat"
E.match = nil
E._resultEmitted = false
E._mpTheme = "classes"

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local function Logic()
    return ArcadiaNexus.AP_Logic
end

local function Notify()
    local R = ArcadiaNexus.AP_Renderer
    local M = ArcadiaNexus.Match
    if M and M.NotifyGameView then
        M.NotifyGameView(E, "ARCADIAPAIRS", function()
            if R and R.Render then R:Render() end
        end)
        return
    end
    if R and R.Render then R:Render() end
end

local function MatchOpts(engine)
    return Logic().MatchOpts(engine)
end

local function PlayGameSound(event)
    local S = ArcadiaNexus.AP_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "flip"     and S:Get("soundOnFlip")     then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX") end
    if event == "match"    and S:Get("soundOnMatch")    then PlaySound(SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 888, "SFX") end
    if event == "mismatch" and S:Get("soundOnMismatch") then PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX") end
    if event == "win"      and S:Get("soundOnWin")      then PlaySound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or 888, "SFX") end
    if event == "lose"     and S:Get("soundOnLose")     then PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX") end
end

function E:MaybeScheduleResolve()
    if not self.match or not self.match.isHost then return end
    if self._resolvePending then return end
    local pub = self.match.GetPublicState and self.match:GetPublicState()
    if not pub or pub.over or tonumber(pub.o) == 1 then return end
    if tonumber(pub.bl) ~= 1 then return end
    local x, y = tonumber(pub.x) or 0, tonumber(pub.y) or 0
    if x < 1 or y < 1 then return end
    self._resolvePending = true
    local sid = E._sessionId
    _timerGuard:After(0.8, function()
        E._resolvePending = false
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
        if not E.match or not E.match.isHost then return end
        E.match:SendIntent("RESOLVE", {})
        Notify()
    end)
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then M.HandleGamePublic(self) end
    local st = self:GetBoardState()
    local prevFlip = self._mpFlip
    local prevPairs = self._mpPairs or 0
    if st then
        local now = st.flippedIdx or {}
        if prevFlip and #prevFlip == 2 and #now == 0 and (st.matchedPairs or 0) == prevPairs then
            PlayGameSound("mismatch")
        elseif st.matchedPairs and st.matchedPairs > prevPairs then
            PlayGameSound("match")
        elseif now and #now > (prevFlip and #prevFlip or 0) then
            PlayGameSound("flip")
        end
        self._mpFlip = { now[1], now[2] }
        self._mpPairs = st.matchedPairs or 0
    end
    self:MaybeScheduleResolve()
    Notify()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then
        M.HandleGameState(self, "ARCADIAPAIRS", st, {
            onPlaying = function()
                self._resolvePending = false
                self._mpFlip = nil
                self._mpPairs = 0
            end,
        })
    end
    Notify()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then M.HandleGameReject(self, "ARCADIAPAIRS", f) end
    Notify()
end

function E:OnMatchResult(node, resultId)
    if self.match ~= node or not self._sessionId or node:GetState() ~= "FINISHED" then return end
    if self._resultEmitted then return end
    self._resultEmitted = true
    local board = self:GetBoardState()
    local result = (board and board.result) or "DRAW"
    local score = 0
    if result == "WIN" then score = 150
    elseif result == "DRAW" then score = 50 end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "ARCADIAPAIRS",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "easy",
        score = score,
        result = result,
        stats = {
            moves = board and board.moves or 0,
            pairs = board and board.pairs or 0,
            vsHuman = 1,
        },
    })
    self:MaybeShowResult(result, board)
end

function E:MaybeShowResult(result, board)
    local Rnd = ArcadiaNexus.AP_Renderer
    if not Rnd or not Rnd.ShowMatchResult then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    if result == "WIN" and Rnd.PlayWinFlourish then
        Rnd:PlayWinFlourish(L["hud_mp_win_float"] or "Sieg!")
    elseif result == "LOSS" and Rnd.PlayLoseFlourish then
        Rnd:PlayLoseFlourish(L["hud_mp_loss_float"] or "Niederlage!")
    elseif result == "DRAW" and Rnd._SpawnBoardFloat then
        Rnd:_SpawnBoardFloat(L["hud_mp_draw_float"] or "Unentschieden!", {
            size = 30, amp = 36, y0 = -80, y1 = 150, scale = 1.25,
            cr = 0.85, cg = 0.85, cb = 0.85, burst = 0.3, dur = 2.0,
        })
    end
    local sid = E._sessionId
    _timerGuard:After(0.72, function()
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
        Rnd:ShowMatchResult(result, board or self:GetBoardState())
    end)
end

function E:StartGame(config)
    config = config or {}
    self._resolvePending = false
    _timerGuard:Cancel()
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            Notify()
            return
        end
        M.BeginNetworkedGame(self, "ARCADIAPAIRS", config, Notify, MatchOpts, {
            onBefore = function()
                if self.activeGame then
                    self.activeGame = nil
                    self.activeConfig = nil
                end
                local S = ArcadiaNexus.AP_Settings
                self._mpTheme = (config.theme or (S and S:Get("theme")) or "classes")
            end,
        })
        return
    end
    self.mode = mode
    self._resultEmitted = false
    self._notice = nil

    self:StopMatchQuiet()
    if self.activeGame then
        self:StopGame()
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ARCADIAPAIRS", E._sessionId)
    local S = ArcadiaNexus.AP_Settings
    local cfg = {
        difficulty  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy",
        theme       = (config and config.theme) or (S and S:Get("theme")) or "classes",
        timerActive = false,
    }
    if config and config.timerActive ~= nil then
        cfg.timerActive = config.timerActive and true or false
    elseif S then
        cfg.timerActive = S:Get("timerActive") and true or false
    end
    local instance = ArcadiaNexus.AP_Game:New()
    instance:Init(cfg)
    self.activeGame = instance
    self.activeConfig = cfg
    self.state = "PLAYING"
    self.mode = "hotseat"
    ArcadiaNexus.Engine:Emit("AP_GAME_STARTED", instance:GetBoardState())
    if cfg.timerActive then self:StartTimer() end
end

function E:SetReady(ready)
    local M = ArcadiaNexus.Match
    if M and M.SetEngineReady then M.SetEngineReady(self, ready) end
    Notify()
end

function E:TryStartMatch()
    local M = ArcadiaNexus.Match
    if M and M.TryEngineStart then M.TryEngineStart(self) end
    Notify()
end

function E:GetBoardState()
    if self.mode ~= "hotseat" and self.match then
        return Logic().BoardStateFromPublic(self.match:GetPublicState(), self.match.seat or 1)
    end
    if self.activeGame then
        return self.activeGame:GetBoardState()
    end
    return nil
end

function E:HandleFlip(idx)
    if self.mode ~= "hotseat" and self.match then
        if self.state ~= "PLAYING" then return end
        local st = self:GetBoardState()
        if not st or st.gameOver or st.blocked then return end
        if st.turn ~= st.localSeat then return end
        self.match:SendIntent("FLIP", { i = idx })
        Notify()
        return
    end
    if not self.activeGame then return end
    if self.activeGame:IsBlocked() then return end

    local result = self.activeGame:FlipCard(idx)
    if result ~= "flipped" then return end

    PlayGameSound("flip")

    local Renderer = ArcadiaNexus.AP_Renderer
    if Renderer then Renderer:UpdateBoard() end

    local board = self.activeGame.board
    if #board.flippedIdx == 2 then
        local i1, i2 = board.flippedIdx[1], board.flippedIdx[2]
        self.activeGame:SetBlocked(true)
        local sid = E._sessionId
        _timerGuard:After(0.6, function()
            if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
            if not self.activeGame then return end

            local matchResult = self.activeGame:CheckMatch()

            if matchResult == "match" then
                PlayGameSound("match")
                self.activeGame:SetBlocked(false)
                if Renderer then Renderer:UpdateBoard() end

                local board2 = self.activeGame.board
                if board2.phase == "WON" then
                    self:StopTimer()
                    PlayGameSound("win")
                    if Renderer and Renderer.PlayWinFlourish then
                        Renderer:PlayWinFlourish()
                    end
                    local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
                    local scoreMap = { easy = 50, normal = 100, hard = 200 }
                    local base = scoreMap[diff] or 50
                    local pairsN = math.max(1, board2.pairs or 1)
                    local moves = math.max(pairsN, board2.moves or pairsN)
                    local score = math.max(1, math.floor(base * pairsN / moves))
                    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                        gameId = "ARCADIAPAIRS", difficulty = diff,
                        score = score, result = "WIN",
                        stats = {
                            moves = board2.moves or 0,
                            pairs = board2.pairs or 0,
                        },
                    })
                    _timerGuard:After(0.72, function()
                        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
                        if not self.activeGame then return end
                        ArcadiaNexus.Engine:Emit("AP_GAME_WON", self.activeGame:GetBoardState())
                    end)
                end
            else
                if Renderer then Renderer:FlashMismatch(i1, i2) end
                _timerGuard:After(0.42, function()
                    if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
                    if not self.activeGame then return end
                    self.activeGame:ResetFlipped()
                    PlayGameSound("mismatch")
                    self.activeGame:SetBlocked(false)
                    if Renderer then Renderer:UpdateBoard() end
                end)
            end
        end)
    end
end

function E:StartTimer()
    _timerGuard:Cancel()
    _timerGuard:EveryAfter(1, function()
        if not self.activeGame then return false end
        local result = self.activeGame:TickTimer(1)
        local state  = self.activeGame:GetBoardState()
        ArcadiaNexus.Engine:Emit("AP_TIMER_TICK", state)
        if result == "expired" then
            self:StopTimer()
            if self.activeGame then self.activeGame:SetBlocked(true) end
            PlayGameSound("lose")
            local Renderer = ArcadiaNexus.AP_Renderer
            if Renderer and Renderer.PlayLoseFlourish then
                Renderer:PlayLoseFlourish()
            end
            local sid = E._sessionId
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId = "ARCADIAPAIRS", difficulty = diff, score = 0, result = "LOSS",
                stats = {
                    moves = state.moves or 0,
                    pairs = state.pairs or 0,
                },
            })
            _timerGuard:After(1.15, function()
                if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
                ArcadiaNexus.Engine:Emit("AP_GAME_LOST", state)
            end)
            return false
        end
        return true
    end)
end

function E:StopTimer()
    _timerGuard:Cancel()
end

function E:GetView()
    local lobbyPlayers = {}
    local pub
    local seat = 1
    if self.mode ~= "hotseat" and self.match then
        pub = self.match:GetPublicState() or Logic().EmptyPublic()
        seat = self.match.seat or 1
        if self.state == "LOBBY" then
            local seats = self.match.seats or {}
            local ready = self.match.ready or {}
            local seen = {}
            for i = 1, 2 do
                local k = seats[i]
                if k and k ~= "" and not seen[k] then
                    seen[k] = true
                    lobbyPlayers[#lobbyPlayers + 1] = {
                        key = k,
                        name = k:match("^([^-]+)") or k,
                        ready = ready[i] and true or false,
                        self = k == self.match.playerKey,
                    }
                end
            end
        end
    end
    return {
        state = self.state,
        mode = self.mode,
        pub = pub,
        seat = seat,
        mp = self.mode ~= "hotseat",
        isHost = self.match and self.match.isHost,
        matchState = self.match and self.match:GetState(),
        notice = self._notice,
        lobbyPlayers = lobbyPlayers,
    }
end

function E:HideView()
    local M = ArcadiaNexus.Match
    if M and M.HideEngineView then M.HideEngineView(self) end
end

function E:StopMatchQuiet()
    local M = ArcadiaNexus.Match
    if M and M.StopEngineMatch then M.StopEngineMatch(self) end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARCADIAPAIRS", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    _timerGuard:Cancel()
    self._resolvePending = false
    self.activeGame = nil
    self.activeConfig = nil
    self.state = "IDLE"
    self.mode = "hotseat"
    ArcadiaNexus.Engine:Emit("AP_GAME_STOPPED")
    Notify()
end

function E:Pause()
end

function E:Resume()
end

function E:EnterIdleState()
    local rnd = ArcadiaNexus.AP_Renderer
    if rnd and rnd.EnterIdleState then
        rnd:EnterIdleState()
    end
end

function E:SaveState()
end
