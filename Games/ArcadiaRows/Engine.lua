--[[
    Gaming Hub
    Games/ArcadiaRows/Engine.lua
    Version: 1.0.0

    Schlanker Engine-Wrapper speziell für Vier Gewinnt.
    Emittet eigene Events mit AR_-Prefix damit TicTacToe-Renderer
    nicht versehentlich auf ArcadiaRows-Events reagiert.

    Events:
      AR_GAME_STARTED(boardState)
      AR_BOARD_UPDATED
      AR_GAME_OVER(result)
      AR_WIN_LINE(line)
      AR_GAME_STOPPED
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Engine = {}

local VGE = ArcadiaNexus.AR_Engine

VGE._sessionId = nil
VGE.activeGame = nil

-- ============================================================
-- StartGame
-- ============================================================

function VGE:StartGame(config)
    local gameClass = ArcadiaNexus.AR_Game
    if not gameClass then
        GH_LogError("AR_Engine", "AR_Game nicht registriert.")
        return
    end

    VGE._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ARCADIAROWS", VGE._sessionId)

    local instance = gameClass:New()
    instance:Init(config or {})

    self.activeGame   = instance
    self.activeConfig = config or {}

    ArcadiaNexus.Engine:Emit("AR_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandlePlayerMove
-- col: Zielspalte (1-basiert)
-- ============================================================

function VGE:HandlePlayerMove(col)
    if not self.activeGame then return end

    self.activeGame:HandleMove(col)

    local board = self.activeGame:GetBoardState()

    ArcadiaNexus.Engine:Emit("AR_BOARD_UPDATED", board)

    if board.gameOver then
        ArcadiaNexus.Engine:Emit("AR_GAME_OVER", board.result)

        if board.winningLine then
            ArcadiaNexus.Engine:Emit("AR_WIN_LINE", board.winningLine)
        end

        -- Zentraler GAME_RESULT-Event
        local diff = (self.activeConfig and self.activeConfig.aiDifficulty) or "normal"
        local scoreMap = { easy = 100, normal = 150, hard = 200 }
        local score = 0
        if board.result == "WIN" then score = scoreMap[diff] or 100
        elseif board.result == "DRAW" then score = 50 end
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "ARCADIAROWS",
            difficulty = diff,
            score      = score,
            result     = board.result,
            stats      = {
                moveCount = board.moveCount or 0,
            },
        })
    end
end

-- ============================================================
-- StopGame
-- ============================================================

function VGE:StopGame()
    if VGE._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARCADIAROWS", VGE._sessionId)
        VGE._sessionId = nil
    end
    if not self.activeGame then return end

    self.activeGame = nil

    ArcadiaNexus.Engine:Emit("AR_GAME_STOPPED")

    GH_LogDebug("AR_Engine", "Spiel gestoppt.")
end
