--[[
    Gaming Hub
    Games/TicTacToe/Engine.lua
    Version: 1.0.0

    Lifecycle-Wrapper für Tic Tac Toe.
    Delegiert Spiellogik an TicTacToeGame (Game.lua).
    Nutzt die generischen Core-Engine-Events (kein eigener Prefix),
    da TTT_Renderer direkt auf ArcadiaNexus.Engine:On() lauscht.

    Lifecycle-Contract:
      StartGame(config)   – Spiel initialisieren und starten
      StopGame()          – Spiel beenden, Renderer in Idle
      Pause()             – no-op (rundenbasiert, kein aktiver Loop)
      Resume()            – no-op (rundenbasiert)
      EnterIdleState()    – Renderer zurücksetzen ohne StopGame-Event
      SaveState()         – no-op (kein resumierbarer State nötig)
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.TTT_Engine = {}
local E = ArcadiaNexus.TTT_Engine

E._sessionId = nil

E.activeGame   = nil
E.activeConfig = nil

-- ============================================================
-- StartGame
-- config: { boardSize, winLength, aiDifficulty }
-- ============================================================

function E:StartGame(config)
    if self.activeGame then
        GH_LogWarn("TTT_Engine", "StartGame aufgerufen obwohl Spiel bereits läuft – stoppe zuerst.")
        self:StopGame()
    end

    local gameClass = ArcadiaNexus.TicTacToeGame
    if not gameClass then
        GH_LogError("TTT_Engine", "TicTacToeGame nicht gefunden.")
        return
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("TICTACTOE", E._sessionId)

    local instance = gameClass:New()
    instance:Init(config or {})

    self.activeGame   = instance
    self.activeConfig = config or {}

    GH_LogDebug("TTT_Engine", "Spiel gestartet – boardSize=" ..
        tostring((config and config.boardSize) or 3) ..
        " diff=" .. tostring((config and config.aiDifficulty) or "normal"))

    ArcadiaNexus.Engine:Emit("GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandlePlayerMove
-- Wird vom Renderer aufgerufen (Klick auf Zelle).
-- ============================================================

function E:HandlePlayerMove(x, y)
    if not self.activeGame then return end

    self.activeGame:HandleMove(x, y)

    local board = self.activeGame:GetBoardState()
    ArcadiaNexus.Engine:Emit("BOARD_UPDATED", board)

    if board.gameOver then
        ArcadiaNexus.Engine:Emit("GAME_OVER", board.result)

        if board.winningLine then
            ArcadiaNexus.Engine:Emit("WIN_LINE", board.winningLine)
        end

        -- Zentraler GAME_RESULT-Event für ScoreManager / XPManager
        local diff     = (self.activeConfig and self.activeConfig.aiDifficulty) or "normal"
        local scoreMap = { easy = 100, normal = 150, hard = 200 }
        local score    = 0
        if     board.result == "WIN"  then score = scoreMap[diff] or 100
        elseif board.result == "DRAW" then score = 50 end

        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "TICTACTOE",
            difficulty = diff,
            score      = score,
            result     = board.result,
            stats      = { moveCount = board.moveCount or 0 },
        })

        GH_LogDebug("TTT_Engine", "Spiel beendet – result=" .. tostring(board.result))
    end
end

-- ============================================================
-- StopGame
-- ============================================================

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("TICTACTOE", E._sessionId)
        E._sessionId = nil
    end
    if not self.activeGame then
        GH_LogDebug("TTT_Engine", "StopGame aufgerufen ohne aktives Spiel.")
        return
    end

    self.activeGame   = nil
    self.activeConfig = nil

    GH_LogDebug("TTT_Engine", "Spiel gestoppt.")
    ArcadiaNexus.Engine:Emit("GAME_STOPPED")
end

-- ============================================================
-- Pause / Resume
-- TicTacToe ist rundenbasiert – kein aktiver Loop, kein State-Verlust.
-- no-op Implementierung erfüllt den Lifecycle-Contract.
-- ============================================================

function E:Pause()
    -- no-op: rundenbasiert
end

function E:Resume()
    -- no-op: rundenbasiert
end

-- ============================================================
-- EnterIdleState
-- Setzt Renderer zurück ohne GAME_STOPPED zu emittieren.
-- Wird z.B. beim Tab-Wechsel ohne laufendes Spiel genutzt.
-- ============================================================

function E:EnterIdleState()
    local rnd = ArcadiaNexus.TTT_Renderer
    if rnd and rnd.EnterIdleState then
        rnd:EnterIdleState()
    end
end

-- ============================================================
-- SaveState
-- TicTacToe hat keinen resumierbaren State.
-- no-op Implementierung erfüllt den Lifecycle-Contract.
-- ============================================================

function E:SaveState()
    -- no-op: kein persistierbarer Spielzustand
end
