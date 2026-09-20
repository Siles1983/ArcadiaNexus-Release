--[[
    Games/TicTacToe/Engine.lua
    Spiele-Tab: ausschließlich vs. KI. Internes mode "hotseat" = lokales KI-Spiel
    (Match-Konvention), niemals zwei Menschen an einem Client.
    Produktvertrag: docs/TicTacToe.md
    MP nur über HasMultiplayer() + Match-Runtime.
    KI-Zug läuft verzögert über TimerGuard, nie im selben Tick wie der Spielerzug.
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.TTT_Engine = {}
local E = ArcadiaNexus.TTT_Engine

E._sessionId = nil
E.activeGame = nil
E.activeConfig = nil
E.state = "IDLE"
E.mode = "hotseat"
E.match = nil
E._resultEmitted = false
E._busy = false
E.series = { you = 0, opp = 0, draws = 0, bestOf = 3 }
E.winStreak = 0

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local THINK = { easy = 0.28, normal = 0.45, hard = 0.65 }
local RESULT_DELAY = 0.45
local SCORE = { easy = 100, normal = 150, hard = 200 }

local function Logic()
    return ArcadiaNexus.TicTacToeLogic
end

local function Notify()
    local R = ArcadiaNexus.TTT_Renderer
    local M = ArcadiaNexus.Match
    if M and M.NotifyGameView then
        M.NotifyGameView(E, "TICTACTOE", function()
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
    E.series = { you = 0, opp = 0, draws = 0, bestOf = 3 }
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

local function EmitHotseatResult(board)
    local diff = (E.activeConfig and E.activeConfig.aiDifficulty) or "normal"
    local result = (board and board.result) or "DRAW"
    local score = 0
    if result == "WIN" then
        score = SCORE[diff] or 100
        E.series.you = (E.series.you or 0) + 1
        E.winStreak = (E.winStreak or 0) + 1
    else
        E.winStreak = 0
        if result == "LOSS" then
            E.series.opp = (E.series.opp or 0) + 1
        else
            score = 50
            E.series.draws = (E.series.draws or 0) + 1
        end
    end
    local seriesWin = 0
    if E:IsSeriesOver() and (E.series.you or 0) > (E.series.opp or 0) then
        seriesWin = 1
    end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "TICTACTOE",
        difficulty = diff,
        score = score,
        result = result,
        stats = {
            moveCount = board and board.moveCount or 0,
            boardSize = board and board.size or 3,
            winStreak = E.winStreak or 0,
            seriesWin = seriesWin,
            startedAs = board and board.startedAs or 1,
            vsHuman = 0,
        },
    })
    GH_LogDebug("TTT_Engine", "Spiel beendet – result=" .. tostring(result))
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then M.HandleGamePublic(self) end
    Notify()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then M.HandleGameState(self, "TICTACTOE", st) end
    Notify()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then M.HandleGameReject(self, "TICTACTOE", f) end
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
        gameId = "TICTACTOE",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "normal",
        score = score,
        result = result,
        stats = {
            moveCount = board and board.moveCount or 0,
            boardSize = board and board.size or 3,
            vsHuman = 1,
        },
    })
    self:MaybeShowResult(result)
end

function E:MaybeShowResult(result)
    local R = ArcadiaNexus.TTT_Renderer
    if R and R.ShowGameOver then R:ShowGameOver(result) end
end

function E:StartGame(config)
    _timerGuard:Cancel()
    self._busy = false
    config = config or {}
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            Notify()
            return
        end
        M.BeginNetworkedGame(self, "TICTACTOE", config, Notify, MatchOpts, {
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

    self:StopMatchQuiet()
    if self.activeGame then
        GH_LogWarn("TTT_Engine", "StartGame aufgerufen obwohl Spiel bereits läuft – stoppe zuerst.")
        self:StopGame()
        _timerGuard:Cancel()
        self._busy = false
    end

    if not config.seriesContinue then
        ResetSeries()
    end

    local gameClass = ArcadiaNexus.TicTacToeGame
    if not gameClass then
        GH_LogError("TTT_Engine", "TicTacToeGame nicht gefunden.")
        return
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("TICTACTOE", E._sessionId)
    local instance = gameClass:New()
    instance:Init(config)
    self.activeGame = instance
    self.activeConfig = config
    self.state = "PLAYING"
    self.mode = "hotseat"

    GH_LogDebug("TTT_Engine", "Spiel gestartet – boardSize=" ..
        tostring(config.boardSize or 3) ..
        " winLength=" .. tostring(instance.board and instance.board.winLength) ..
        " starter=" .. tostring(instance.currentPlayer) ..
        " diff=" .. tostring(config.aiDifficulty or "normal"))

    ArcadiaNexus.Engine:Emit("GAME_STARTED", instance:GetBoardState())
    if instance.currentPlayer == 2 then
        self:_KickHotseatAI()
    end
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

function E:_PublishHotseat(board)
    ArcadiaNexus.Engine:Emit("BOARD_UPDATED", board)
    if board.winningLine then
        ArcadiaNexus.Engine:Emit("WIN_LINE", board.winningLine)
    end
end

function E:_FinishHotseat(board)
    local sid = E._sessionId
    _timerGuard:After(RESULT_DELAY, function()
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
        if self.state ~= "PLAYING" then return end
        if not self.activeGame then return end
        EmitHotseatResult(board)
        ArcadiaNexus.Engine:Emit("GAME_OVER", board.result)
        self._busy = false
    end)
end

function E:PlayAIMove()
    if self.mode ~= "hotseat" then return end
    if self.state ~= "PLAYING" then return end
    if not self.activeGame or self.activeGame.gameOver then
        self._busy = false
        return
    end
    if self.activeGame.currentPlayer ~= 2 then
        self._busy = false
        local board = self.activeGame:GetBoardState()
        if board then self:_PublishHotseat(board) end
        return
    end

    self.activeGame:PlayAIMove()
    local board = self.activeGame:GetBoardState()
    if board.gameOver then
        self:_PublishHotseat(board)
        self:_FinishHotseat(board)
        return
    end
    -- Busy muss vor dem Render fallen, sonst bleiben die Zellen disabled.
    self._busy = false
    self:_PublishHotseat(board)
end

function E:_KickHotseatAI()
    if self.mode ~= "hotseat" then return end
    if self.state ~= "PLAYING" then return end
    if not self.activeGame or self.activeGame.gameOver then return end
    if self.activeGame.currentPlayer ~= 2 then return end

    self._busy = true
    local diff = (self.activeConfig and self.activeConfig.aiDifficulty) or "normal"
    local delay = THINK[diff] or THINK.normal
    local sid = E._sessionId
    _timerGuard:After(delay, function()
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
        if self.state ~= "PLAYING" then return end
        self:PlayAIMove()
    end)
end

function E:_AfterHotseatAction()
    local board = self.activeGame:GetBoardState()
    if not board then return end

    self._busy = true
    self:_PublishHotseat(board)

    if board.gameOver then
        self:_FinishHotseat(board)
        return
    end

    self:_KickHotseatAI()
end

function E:HandlePlayerMove(x, y)
    if self.mode ~= "hotseat" and self.match then
        if self.state ~= "PLAYING" then return end
        local size = Logic().MP_SIZE
        local i = (y - 1) * size + x
        self.match:SendIntent("MOVE", { i = i })
        Notify()
        return
    end
    if self._busy then return end
    if not self.activeGame then return end
    if self.activeGame.currentPlayer ~= 1 then return end

    if not self.activeGame:HandleMove(x, y) then return end
    self:_AfterHotseatAction()
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
    _timerGuard:Cancel()
    self._busy = false
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("TICTACTOE", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    self.activeGame = nil
    self.activeConfig = nil
    self.state = "IDLE"
    self.mode = "hotseat"
    GH_LogDebug("TTT_Engine", "Spiel gestoppt.")
    ArcadiaNexus.Engine:Emit("GAME_STOPPED")
    Notify()
end

function E:Pause()
end

function E:Resume()
end

function E:EnterIdleState()
    local rnd = ArcadiaNexus.TTT_Renderer
    if rnd and rnd.EnterIdleState then
        rnd:EnterIdleState()
    end
end

function E:SaveState()
end
