--[[
    Gaming Hub
    Games/ArcadiaRows/Game.lua
    Version: 1.3.0

    Nur Hotseat vs. KI. MATCH wendet Züge über Logic.ApplyMatch an.
    Pop-out nur hier (config.popOut), nie im MATCH-Pfad.
    playMode "puzzle": vorgelegtes Brett, Spieler am Zug, winIn-Budget.
]]

local ArcadiaNexus = _G.ArcadiaNexus

local AR_Game = {}
AR_Game.__index = AR_Game
ArcadiaNexus.AR_Game = AR_Game

function AR_Game:New()
    return setmetatable({}, self)
end

function AR_Game:Init(config)
    self.config  = config or {}
    self.logic   = ArcadiaNexus.AR_Logic
    self.ai      = ArcadiaNexus.AR_AI

    self.currentPlayer = 1
    self.gameOver      = false
    self.result        = nil
    self.winningLine   = nil
    self.lastMove      = nil
    self.forkSeen      = false
    self.popUsed       = false
    self.playMode      = self.config.playMode or "play"
    self.winIn         = self.config.winIn or 1
    self.playerPly     = 0
    self.puzzleIndex   = self.config.puzzleIndex

    local cols = self.config.cols or 7
    local rows = self.config.rows or 6

    self.board = self.logic:CreateBoard(cols, rows)

    if self.playMode == "puzzle" and self.config.puzzle and self.config.puzzle.rows then
        if self.config.puzzle.winIn then
            self.winIn = self.config.puzzle.winIn
        end
        self.logic:LoadPuzzle(self.board, self.config.puzzle.rows)
        self.currentPlayer = 1
    else
        local starter = self.config.firstPlayer or "you"
        if starter == "random" then
            starter = (math.random(1, 2) == 1) and "you" or "ai"
        end
        self.currentPlayer = (starter == "ai") and 2 or 1
    end
end

function AR_Game:Reset()
    self:Init(self.config)
end

local function AllowPop(self)
    return self.config and self.config.popOut and true or false
end

local function FinishAfterAction(self, mover)
    local mWin, mLine = self.logic:CheckAnyWin(self.board, mover)
    if mWin then
        self.gameOver    = true
        self.result      = (mover == 1) and "WIN" or "LOSS"
        self.winningLine = mLine
        return true
    end
    local other = (mover == 1) and 2 or 1
    local oWin, oLine = self.logic:CheckAnyWin(self.board, other)
    if oWin then
        self.gameOver    = true
        self.result      = (mover == 1) and "LOSS" or "WIN"
        self.winningLine = oLine
        return true
    end
    local nextP = (mover == 1) and 2 or 1
    if not self.logic:HasMoves(self.board, nextP, AllowPop(self)) then
        self.gameOver = true
        self.result   = (self.playMode == "puzzle") and "LOSS" or "DRAW"
        return true
    end
    return false
end

local function PuzzleBudgetLoss(self)
    if self.playMode ~= "puzzle" or self.gameOver then
        return false
    end
    if (self.playerPly or 0) >= (self.winIn or 1) then
        self.gameOver = true
        self.result   = "LOSS"
        return true
    end
    return false
end

function AR_Game:HandleMove(col)
    if self.gameOver then return false end
    if self.currentPlayer ~= 1 then return false end

    if self.logic:HasFork(self.board, 1) then
        self.forkSeen = true
    end

    local row = self.logic:ApplyMove(self.board, col, 1)
    if not row then return false end
    self.board.moveCount = (self.board.moveCount or 0) + 1
    self.lastMove = { col = col, row = row, pop = false, actor = 1 }
    self.playerPly = (self.playerPly or 0) + 1

    if FinishAfterAction(self, 1) then
        return true
    end

    if PuzzleBudgetLoss(self) then
        return true
    end

    if self.logic:HasFork(self.board, 1) then
        self.forkSeen = true
    end

    self.currentPlayer = 2
    return true
end

function AR_Game:HandlePopOut(col)
    if self.gameOver then return false end
    if self.currentPlayer ~= 1 then return false end
    if not AllowPop(self) then return false end

    local row, shifts, popped = self.logic:ApplyPopOut(self.board, col, 1)
    if not row then return false end
    self.board.moveCount = (self.board.moveCount or 0) + 1
    self.popUsed = true
    self.lastMove = {
        col    = col,
        row    = row,
        pop    = true,
        actor  = popped or 1,
        shifts = shifts or {},
    }

    if FinishAfterAction(self, 1) then
        return true
    end

    self.currentPlayer = 2
    return true
end

function AR_Game:PlayAIMove()
    if self.gameOver then return end
    if self.currentPlayer ~= 2 then return end

    local aiCol, aiPop = self.ai:GetBestMove(
        self.board, 2, self.config.aiDifficulty, AllowPop(self)
    )
    if not aiCol then
        self.currentPlayer = 1
        return
    end

    local aiRow, shifts, popped
    if aiPop then
        aiRow, shifts, popped = self.logic:ApplyPopOut(self.board, aiCol, 2)
    else
        aiRow = self.logic:ApplyMove(self.board, aiCol, 2)
    end
    if not aiRow then
        self.currentPlayer = 1
        return
    end

    self.board.moveCount = (self.board.moveCount or 0) + 1
    self.lastMove = {
        col    = aiCol,
        row    = aiRow,
        pop    = aiPop and true or false,
        actor  = popped or 2,
        shifts = shifts or {},
    }

    if FinishAfterAction(self, 2) then
        return
    end

    self.currentPlayer = 1
end

function AR_Game:GetBoardState()
    return {
        cols         = self.board.cols,
        rows         = self.board.rows,
        winLength    = self.board.winLength,
        cells        = self.board.cells,
        gameOver     = self.gameOver,
        result       = self.result,
        winningLine  = self.winningLine,
        lastMove     = self.lastMove,
        moveCount    = self.board.moveCount or 0,
        turn         = self.currentPlayer,
        localSeat    = 1,
        forkSeen     = self.forkSeen and true or false,
        popOut       = AllowPop(self),
        playMode     = self.playMode or "play",
        winIn        = self.winIn,
        playerPly    = self.playerPly or 0,
        puzzleIndex  = self.puzzleIndex,
        keyCol       = self.config.puzzle and self.config.puzzle.keyCol,
        popUsed      = self.popUsed and true or false,
    }
end
