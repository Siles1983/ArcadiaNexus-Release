--[[
    Gaming Hub
    TicTacToe Game.lua
    Version: 0.3.0 (AI as separate step)
    Lokales Spiel ist immer Sitz 1 vs. KI. Kein 2P-Hotseat (docs/TicTacToe.md).
]]

local ArcadiaNexus = _G.ArcadiaNexus

local TicTacToeGame = {}
TicTacToeGame.__index = TicTacToeGame
ArcadiaNexus.TicTacToeGame = TicTacToeGame

function TicTacToeGame:New()
    return setmetatable({}, self)
end

function TicTacToeGame:Init(config)
    self.config = config or {}
    self.logic = ArcadiaNexus.TicTacToeLogic
    self.ai = ArcadiaNexus.TicTacToeAI

    self.gameOver = false
    self.result = nil
    self.winningLine = nil
    self.lastMove = nil

    self.board = self.logic:CreateBoard(
        self.config.boardSize or 3,
        self.config.winLength or 3
    )

    local starter = self.config.firstPlayer or "you"
    if starter == "random" then
        starter = (math.random(1, 2) == 1) and "you" or "ai"
    end
    self.currentPlayer = (starter == "ai") and 2 or 1
    self.startedAs = self.currentPlayer
end

function TicTacToeGame:Reset()
    self:Init(self.config)
end

local function FinishAfterMove(self, x, y, player)
    local result, line = self.logic:CheckWin(self.board, x, y, player)
    if result == "WIN" then
        self.gameOver = true
        self.result = (player == 1) and "WIN" or "LOSS"
        self.winningLine = line
        return true
    elseif result == "DRAW" then
        self.gameOver = true
        self.result = "DRAW"
        return true
    end
    return false
end

function TicTacToeGame:HandleMove(x, y)
    if self.gameOver then return false end
    if self.currentPlayer ~= 1 then return false end

    local success = self.logic:ApplyMove(self.board, x, y, 1)
    if not success then return false end
    self.board.moveCount = (self.board.moveCount or 0) + 1
    self.lastMove = { x = x, y = y, actor = 1 }

    if FinishAfterMove(self, x, y, 1) then
        return true
    end

    self.currentPlayer = 2
    return true
end

function TicTacToeGame:PlayAIMove()
    if self.gameOver then return end
    if self.currentPlayer ~= 2 then return end

    local aiMove = self.ai:GetBestMove(
        self.board,
        self.currentPlayer,
        self.config.aiDifficulty
    )
    if not aiMove then
        self.currentPlayer = 1
        return
    end

    self.logic:ApplyMove(self.board, aiMove.x, aiMove.y, 2)
    self.board.moveCount = (self.board.moveCount or 0) + 1
    self.lastMove = { x = aiMove.x, y = aiMove.y, actor = 2 }

    if FinishAfterMove(self, aiMove.x, aiMove.y, 2) then
        return
    end

    self.currentPlayer = 1
end

function TicTacToeGame:GetBoardState()
    return {
        size = self.board.size,
        cells = self.board.cells,
        gameOver = self.gameOver,
        result = self.result,
        winningLine = self.winningLine,
        lastMove = self.lastMove,
        moveCount = self.board.moveCount or 0,
        winLength = self.board.winLength,
        turn = self.currentPlayer,
        localSeat = 1,
        startedAs = self.startedAs or 1,
    }
end
