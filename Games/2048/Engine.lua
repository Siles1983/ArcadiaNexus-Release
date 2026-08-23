--[[
    Gaming Hub
    Games/2048/Engine.lua
    Version: 1.1.0

    Events (TDG_ Prefix):
      TDG_GAME_STARTED(boardState)
      TDG_BOARD_UPDATED(boardState)
      TDG_GAME_OVER(result)   – "LOSS" (keine Züge mehr)
      TDG_GAME_STOPPED

    Keine Sieg-Bedingung. Kein TDG_GAME_WON.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TDG_Engine = {}
local E = ArcadiaNexus.TDG_Engine

E._sessionId = nil

E.activeGame = nil

-- ============================================================
-- Sound
-- ============================================================

local function PlayGameSound(event)
    local S = ArcadiaNexus.TDG_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "LOSS" and S:Get("soundOnLoss") then PlaySound(847, "SFX") end
end

-- ============================================================
-- StartGame
-- ============================================================

function E:StartGame(config)
    local gameClass = ArcadiaNexus.TDG_Game
    if not gameClass then
        GH_LogError("TDG_Engine", "TDG_Game nicht registriert.")
        return
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("2048", E._sessionId)

    local S   = ArcadiaNexus.TDG_Settings
    local cfg = {
        size = (config and config.size) or (S and S:Get("boardSize")) or 4,
    }

    local instance = gameClass:New()
    instance:Init(cfg)
    self.activeGame = instance

    ArcadiaNexus.Engine:Emit("TDG_GAME_STARTED", instance:GetBoardState())
end

-- ============================================================
-- HandlePlayerMove
-- direction: "UP" | "DOWN" | "LEFT" | "RIGHT"
-- ============================================================

function E:HandlePlayerMove(direction)
    if not self.activeGame then return end

    self.activeGame:HandleMove(direction)

    local state = self.activeGame:GetBoardState()

    ArcadiaNexus.Engine:Emit("TDG_BOARD_UPDATED", state)

    if state.gameOver then
        ArcadiaNexus.Engine:Emit("TDG_GAME_OVER", state.result)
        PlayGameSound("LOSS")

        -- Zentraler GAME_RESULT-Event (2048 hat nur LOSS, Score ist Punkte)
        -- highestTile: höchste Kachel im Board ermitteln
        local highestTile = 0
        if state.board then
            for r = 1, (state.boardSize or 4) do
                for c = 1, (state.boardSize or 4) do
                    local v = state.board[r] and state.board[r][c] or 0
                    if v > highestTile then highestTile = v end
                end
            end
        end
        local size = state.boardSize or 4
        local difficulty = (size <= 3 and "easy") or (size >= 5 and "hard") or "normal"
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "2048",
            difficulty = difficulty,
            score      = state.score or 0,
            result     = state.result or "LOSS",
            stats      = {
                highestTile = highestTile,
            },
        })
    end
end

-- ============================================================
-- StopGame
-- ============================================================

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("2048", E._sessionId)
        E._sessionId = nil
    end
    if not self.activeGame then return end
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("TDG_GAME_STOPPED")
end
