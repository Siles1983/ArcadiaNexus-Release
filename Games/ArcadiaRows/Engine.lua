--[[
    Games/ArcadiaRows/Engine.lua
    Spiele-Tab: vs. KI. MP nur über HasMultiplayer() + Match-Runtime (7×6, 2 Sitze).
    KI läuft nie im MATCH-Pfad. Best-of-3 nur Hotseat.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Engine = {}
local E = ArcadiaNexus.AR_Engine

E._sessionId = nil
E.activeGame = nil
E.activeConfig = nil
E.state = "IDLE"
E.mode = "hotseat"
E.match = nil
E._resultEmitted = false
E._busy = false
E.series = { you = 0, opp = 0, bestOf = 3 }

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local THINK = { easy = 0.28, normal = 0.48, hard = 0.72 }
local SCORE = { easy = 100, normal = 150, hard = 200 }

local WIN_IN = { easy = 1, normal = 2, hard = 3 }

local function InstantDrops()
    local S = ArcadiaNexus.AR_Settings
    return S and S:Get("instantDrops") and true or false
end

local function Logic()
    return ArcadiaNexus.AR_Logic
end

local function PrepareHotseatConfig(config)
    config.playMode = config.playMode or "play"
    if config.playMode ~= "puzzle" then
        return true
    end
    config.firstPlayer = "you"
    config.popOut = false
    local diff = config.aiDifficulty or "easy"
    config.puzzleDiff = diff
    local S = ArcadiaNexus.AR_Settings
    local idx = config.puzzleIndex
    if not idx and S and S.GetPuzzleIndex then
        idx = S:GetPuzzleIndex(diff)
    end
    idx = idx or 1
    local pool = ArcadiaNexus.AR_Levels
    local LP = ArcadiaNexus.LevelPool
    if not pool or not LP then
        GH_LogError("AR_Engine", "Stellung-Pool nicht geladen.")
        return false
    end
    local entry, realIdx = LP.GetEntry(pool, diff, idx)
    if not entry then
        GH_LogError("AR_Engine", "Keine Stellung für Schwierigkeit " .. tostring(diff))
        return false
    end
    config.puzzle = entry
    config.puzzleIndex = realIdx or idx
    config.winIn = entry.winIn or WIN_IN[diff] or 1
    config.aiDifficulty = "hard"
    return true
end

local function Notify()
    local R = ArcadiaNexus.AR_Renderer
    local M = ArcadiaNexus.Match
    if M and M.NotifyGameView then
        M.NotifyGameView(E, "ARCADIAROWS", function()
            if R and R.Render then R:Render() end
        end)
        return
    end
    if R and R.Render then R:Render() end
end

local function MatchOpts(engine)
    return Logic().MatchOpts(engine)
end

local function ResetSeries()
    E.series = { you = 0, opp = 0, bestOf = 3 }
end

function E:IsSeriesOver()
    local s = self.series
    if not s then return false end
    local need = math.ceil((s.bestOf or 3) / 2)
    return (s.you or 0) >= need or (s.opp or 0) >= need
end

function E:GetSeries()
    return self.series
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then M.HandleGamePublic(self) end
    Notify()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then M.HandleGameState(self, "ARCADIAROWS", st) end
    Notify()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then M.HandleGameReject(self, "ARCADIAROWS", f) end
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
        gameId = "ARCADIAROWS",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "normal",
        score = score,
        result = result,
        stats = { moveCount = board and board.moveCount or 0, vsHuman = 1 },
    })
    -- Dialog erst nach Fall-Animation (Renderer → OnDropSettled).
    Notify()
end

function E:MaybeShowResult(result)
    local R = ArcadiaNexus.AR_Renderer
    if R and R.ShowGameOver then R:ShowGameOver(result) end
end

function E:_EmitHotseatResult(board)
    local cfg = self.activeConfig or {}
    local diff = cfg.puzzleDiff or cfg.aiDifficulty or "normal"
    local score = 0
    if board.result == "WIN" then score = SCORE[diff] or 100
    elseif board.result == "DRAW" then score = 50 end
    if board.playMode ~= "puzzle" then
        if board.result == "WIN" then
            self.series.you = (self.series.you or 0) + 1
        elseif board.result == "LOSS" then
            self.series.opp = (self.series.opp or 0) + 1
        end
    elseif board.result == "WIN" then
        local S = ArcadiaNexus.AR_Settings
        if S and S.SetPuzzleIndex then
            S:SetPuzzleIndex(diff, (cfg.puzzleIndex or 1) + 1)
        end
    end
    local stats = {
        moveCount = board.moveCount or 0,
        fork      = board.forkSeen and 1 or 0,
        seriesYou = self.series.you,
        seriesOpp = self.series.opp,
    }
    local S = ArcadiaNexus.AR_Settings
    if board.playMode == "puzzle" then
        if board.result == "WIN" and S and S.IncrementPuzzlesSolved then
            stats.puzzleSolved = S:IncrementPuzzlesSolved()
        elseif S and S.GetPuzzlesSolved then
            stats.puzzleSolved = S:GetPuzzlesSolved()
        end
    elseif board.result == "WIN" and board.popUsed and S and S.IncrementPopWins then
        stats.popWins = S:IncrementPopWins()
    elseif S and S.GetPopWins then
        stats.popWins = S:GetPopWins()
    end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId       = "ARCADIAROWS",
        difficulty   = diff,
        score        = score,
        result       = board.result,
        recordPlayed = board.playMode ~= "puzzle",
        stats        = stats,
    })
end

function E:StartGame(config)
    config = config or {}
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            Notify()
            return
        end
        M.BeginNetworkedGame(self, "ARCADIAROWS", config, Notify, MatchOpts, {
            onBefore = function()
                if self.activeGame then
                    self.activeGame = nil
                    self.activeConfig = nil
                end
            end,
        })
        return
    end
    self.mode = mode
    self._resultEmitted = false
    self._notice = nil
    self._busy = false
    _timerGuard:Cancel()

    self:StopMatchQuiet()
    if self.activeGame then
        GH_LogWarn("AR_Engine", "StartGame aufgerufen obwohl Spiel bereits läuft – stoppe zuerst.")
        self:StopGame()
    end

    local gameClass = ArcadiaNexus.AR_Game
    if not gameClass then
        GH_LogError("AR_Engine", "AR_Game nicht registriert.")
        return
    end

    if not PrepareHotseatConfig(config) then
        return
    end

    if config.playMode ~= "puzzle" and not config.seriesContinue then
        ResetSeries()
    end

    if config.playMode ~= "puzzle" and config.popOut == nil then
        local S = ArcadiaNexus.AR_Settings
        config.popOut = S and S:Get("popOut") and true or false
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ARCADIAROWS", E._sessionId)
    local instance = gameClass:New()
    instance:Init(config)
    self.activeGame = instance
    self.activeConfig = config
    self.state = "PLAYING"
    self.mode = "hotseat"

    ArcadiaNexus.Engine:Emit("AR_GAME_STARTED", instance:GetBoardState())
    self:_KickHotseatAI()
end

function E:SkipPuzzle()
    if self.mode ~= "hotseat" then return end
    local cfg = self.activeConfig or {}
    if (cfg.playMode or "play") ~= "puzzle" then return end
    local diff = cfg.puzzleDiff or "easy"
    local S = ArcadiaNexus.AR_Settings
    local idx = (cfg.puzzleIndex or 1) + 1
    if S and S.SetPuzzleIndex then
        S:SetPuzzleIndex(diff, idx)
    end
    local R = ArcadiaNexus.AR_Renderer
    self:StartGame({
        cols         = 7,
        rows         = 6,
        aiDifficulty = diff,
        firstPlayer  = "you",
        playMode     = "puzzle",
        mode         = "hotseat",
        puzzleIndex  = idx,
    })
    if R then R._resultShown = false end
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
        local seat = self.match.seat or 1
        return Logic().BoardStateFromPublic(self.match:GetPublicState(), seat)
    end
    if self.activeGame then
        return self.activeGame:GetBoardState()
    end
    return nil
end

function E:HandlePlayerMove(col)
    if self._busy then return end
    if self.mode ~= "hotseat" and self.match then
        if self.state ~= "PLAYING" then return end
        local st = self:GetBoardState()
        if not st or st.gameOver then return end
        if st.turn ~= st.localSeat then return end
        self._busy = true
        self.match:SendIntent("MOVE", { i = col })
        Notify()
        return
    end
    if not self.activeGame then return end
    if self.activeGame.currentPlayer ~= 1 then return end

    if not self.activeGame:HandleMove(col) then return end
    self:_AfterHotseatAction()
end

function E:HandlePlayerPopOut(col)
    if self._busy then return end
    if self.mode ~= "hotseat" then return end
    if not self.activeGame then return end
    if self.activeGame.currentPlayer ~= 1 then return end
    self._busy = true
    if not self.activeGame:HandlePopOut(col) then
        self._busy = false
        return
    end
    self:_AfterHotseatAction()
end

function E:_AfterHotseatAction()
    local board = self.activeGame:GetBoardState()
    if not board then return end

    self._busy = true
    ArcadiaNexus.Engine:Emit("AR_BOARD_UPDATED", board)

    if board.gameOver then
        self:_EmitHotseatResult(board)
    end
end

function E:PlayAIMove()
    if self.mode ~= "hotseat" then return end
    if self.state ~= "PLAYING" then return end
    if not self.activeGame or self.activeGame.gameOver then
        self._busy = false
        local R = ArcadiaNexus.AR_Renderer
        if R and R.RefreshChrome then R:RefreshChrome() end
        return
    end
    self._busy = true
    self.activeGame:PlayAIMove()
    local board = self.activeGame:GetBoardState()
    ArcadiaNexus.Engine:Emit("AR_BOARD_UPDATED", board)
    if board.gameOver then
        self:_EmitHotseatResult(board)
    end
end

-- Renderer ruft das nach der Fall-Animation (Hotseat und MATCH).
function E:OnDropSettled()
    if self.state ~= "PLAYING" and self.state ~= "FINISHED" then
        self._busy = false
        return
    end
    local board = self:GetBoardState()
    if not board then
        self._busy = false
        return
    end

    if board.winningLine then
        ArcadiaNexus.Engine:Emit("AR_WIN_LINE", board.winningLine)
    end

    if board.gameOver then
        local delay = InstantDrops() and 0.05 or 0.55
        _timerGuard:After(delay, function()
            if self.state ~= "PLAYING" and self.state ~= "FINISHED" then return end
            ArcadiaNexus.Engine:Emit("AR_GAME_OVER", board.result)
            self:MaybeShowResult(board.result)
        end)
        return
    end

    self._busy = false

    self:_KickHotseatAI()
end

function E:_KickHotseatAI()
    if self.mode ~= "hotseat" then return end
    if self.state ~= "PLAYING" then return end
    if not self.activeGame or self.activeGame.gameOver then return end
    if self.activeGame.currentPlayer ~= 2 then return end
    self._busy = true
    if InstantDrops() then
        self:PlayAIMove()
        return
    end
    local diff = (self.activeConfig and self.activeConfig.aiDifficulty) or "normal"
    local delay = THINK[diff] or THINK.normal
    _timerGuard:After(delay, function()
        if self.state ~= "PLAYING" then return end
        self:PlayAIMove()
    end)
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
                        self = k == self.match.playerKey,
                        ready = ready[i] and true or false,
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
    _timerGuard:Cancel()
    self._busy = false
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARCADIAROWS", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    self.activeGame = nil
    self.activeConfig = nil
    self.state = "IDLE"
    self.mode = "hotseat"
    ArcadiaNexus.Engine:Emit("AR_GAME_STOPPED")
    Notify()
    GH_LogDebug("AR_Engine", "Spiel gestoppt.")
end

function E:Pause()
end

function E:Resume()
end

function E:EnterIdleState()
    local rnd = ArcadiaNexus.AR_Renderer
    if rnd and rnd.EnterIdleState then
        rnd:EnterIdleState()
    end
end

function E:SaveState()
end
