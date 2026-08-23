--[[
    Gaming Hub
    Games/2048/Game.lua
    Version: 1.1.0

    - Kein Gegner, kein KI-Zug
    - HandleMove(direction) → "UP"|"DOWN"|"LEFT"|"RIGHT"
    - result: "LOSS" (keine Züge mehr) – keine Sieg-Bedingung
    - Score wird im Game-State mitgeführt
    - Best Score über ScoreManager (GAME_RESULT)
]]

local ArcadiaNexus = _G.ArcadiaNexus

local TDG_Game = {}
TDG_Game.__index = TDG_Game
ArcadiaNexus.TDG_Game = TDG_Game

function TDG_Game:New()
    return setmetatable({}, self)
end

-- ============================================================
-- Init
-- ============================================================

function TDG_Game:Init(config)
    self.config    = config or {}
    self.logic     = ArcadiaNexus.TDG_Logic
    self.gameOver  = false
    self.result    = nil
    self.lastSpawn = nil

    local size    = self.config.size or 4
    self.board    = self.logic:CreateBoard(size)

    self.logic:SpawnTile(self.board)
    self.logic:SpawnTile(self.board)

    self.bestScore = self:_LoadBestScore()
end

-- ============================================================
-- Reset
-- ============================================================

function TDG_Game:Reset()
    self:Init(self.config)
end

-- ============================================================
-- HandleMove
-- direction: "UP" | "DOWN" | "LEFT" | "RIGHT"
-- ============================================================

function TDG_Game:HandleMove(direction)
    if self.gameOver then return end

    local moved, _ = self.logic:Slide(self.board, direction)
    if not moved then return end

    local r, c, v = self.logic:SpawnTile(self.board)
    self.lastSpawn = r and { row = r, col = c, value = v } or nil

    if self.board.score > self.bestScore then
        self.bestScore = self.board.score
    end

    if not self.logic:HasMoves(self.board) then
        self.gameOver = true
        self.result   = "LOSS"
    elseif self.logic:HasWon(self.board) then
        self.gameOver = true
        self.result   = "WIN"
    end
end

-- ============================================================
-- GetBoardState
-- ============================================================

function TDG_Game:GetBoardState()
    return {
        size      = self.board.size,
        cells     = self.board.cells,
        merged    = self.board.merged,
        score     = self.board.score,
        bestScore = self.bestScore,
        gameOver  = self.gameOver,
        result    = self.result,
        lastSpawn = self.lastSpawn,
        board     = self.board.cells,  -- Alias für stats-Berechnung
        boardSize = self.board.size,
    }
end

-- ============================================================
-- Best Score (ScoreManager)
-- ============================================================

function TDG_Game:_LoadBestScore()
    local SM = ArcadiaNexus.ScoreManager
    if SM then return SM:GetBestScore("2048", "default") end
    return 0
end
