--[[
    Gaming Hub
    Games/ArcadiaRows/Game.lua
    Version: 1.0.0

    Unterschiede zu TicTacToe/Game.lua:
      - HandleMove(col) → nur Spalte, Zeile wird durch Schwerkraft bestimmt
      - Config:
          cols        – Spalten (z.B. 7)
          rows        – Zeilen (z.B. 6)
          aiDifficulty – "easy" / "normal" / "hard"
      - GetBoardState() gibt cols + rows statt size zurück
      - lastMove = { col, row } für den Renderer (Animationshinweis)
]]

local ArcadiaNexus = _G.ArcadiaNexus

local AR_Game = {}
AR_Game.__index = AR_Game
ArcadiaNexus.AR_Game = AR_Game

function AR_Game:New()
    return setmetatable({}, self)
end

-- ============================================================
-- Init
-- ============================================================

function AR_Game:Init(config)
    self.config  = config or {}
    self.logic   = ArcadiaNexus.AR_Logic
    self.ai      = ArcadiaNexus.AR_AI

    self.currentPlayer = 1
    self.gameOver      = false
    self.result        = nil
    self.winningLine   = nil
    self.lastMove      = nil  -- { col, row } – letzter gesetzter Stein

    -- Standard: 7×6 (klassisches Vier Gewinnt)
    local cols = self.config.cols or 7
    local rows = self.config.rows or 6

    self.board = self.logic:CreateBoard(cols, rows)
end

-- ============================================================
-- Reset
-- ============================================================

function AR_Game:Reset()
    self:Init(self.config)
end

-- ============================================================
-- HandleMove
-- col: Zielspalte (1-basiert), vom Renderer übergeben
-- ============================================================

function AR_Game:HandleMove(col)
    if self.gameOver then return end

    -- ── Spieler-Zug ──
    local row = self.logic:ApplyMove(self.board, col, self.currentPlayer)
    if not row then return end  -- Spalte voll
    self.board.moveCount = (self.board.moveCount or 0) + 1

    self.lastMove = { col = col, row = row }

    -- Gewinn-Prüfung
    local result, line = self.logic:CheckWin(self.board, col, row, self.currentPlayer)

    if result == "WIN" then
        self.gameOver    = true
        self.result      = "WIN"
        self.winningLine = line
        return
    end

    if self.logic:IsBoardFull(self.board) then
        self.gameOver = true
        self.result   = "DRAW"
        return
    end

    -- ── KI-Zug ──
    self.currentPlayer = 2

    local aiCol = self.ai:GetBestMove(self.board, self.currentPlayer, self.config.aiDifficulty)

    if aiCol then
        local aiRow = self.logic:ApplyMove(self.board, aiCol, self.currentPlayer)

        if aiRow then
            self.lastMove = { col = aiCol, row = aiRow }

            local aiResult, aiLine = self.logic:CheckWin(
                self.board, aiCol, aiRow, self.currentPlayer
            )

            if aiResult == "WIN" then
                self.gameOver    = true
                self.result      = "LOSS"
                self.winningLine = aiLine
                return
            end

            if self.logic:IsBoardFull(self.board) then
                self.gameOver = true
                self.result   = "DRAW"
                return
            end
        end
    end

    -- Zurück zum Spieler
    self.currentPlayer = 1
end

-- ============================================================
-- GetBoardState
-- ============================================================

function AR_Game:GetBoardState()
    return {
        cols        = self.board.cols,
        rows        = self.board.rows,
        cells       = self.board.cells,
        gameOver    = self.gameOver,
        result      = self.result,
        winningLine = self.winningLine,
        lastMove    = self.lastMove,
        moveCount   = self.board.moveCount or 0,
    }
end
