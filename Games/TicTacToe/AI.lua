--[[
    Gaming Hub
    TicTacToe AI.lua
    Version: 0.4.0 (Performance Insane Mode – No Minimax Freeze)
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.TicTacToeAI = {}
local AI = ArcadiaNexus.TicTacToeAI

-- ==========================================
-- Public Entry
-- ==========================================

function AI:GetBestMove(board, player, difficulty)

    difficulty = difficulty or "normal"

    if difficulty == "easy" then
        return self:GetRandomMove(board)
    elseif difficulty == "hard" then
        return self:GetBestStrategicMove(board, player)
    else
        return self:GetStrategicMove(board, player)
    end
end

-- ==========================================
-- EASY – Random
-- ==========================================

function AI:GetRandomMove(board)
    local moves = ArcadiaNexus.TicTacToeLogic:GetAvailableMoves(board)
    if #moves == 0 then return nil end
    return moves[math.random(1, #moves)]
end

-- ==========================================
-- NORMAL – Win + Block
-- ==========================================

function AI:GetStrategicMove(board, player)

    local logic = ArcadiaNexus.TicTacToeLogic
    local opponent = (player == 1) and 2 or 1
    local moves = logic:GetAvailableMoves(board)

    -- Try to win
    for _, move in ipairs(moves) do
        local clone = logic:CloneBoard(board)
        logic:ApplyMove(clone, move.x, move.y, player)
        local result = logic:CheckWin(clone, move.x, move.y, player)
        if result == "WIN" then
            return move
        end
    end

    -- Try to block
    for _, move in ipairs(moves) do
        local clone = logic:CloneBoard(board)
        logic:ApplyMove(clone, move.x, move.y, opponent)
        local result = logic:CheckWin(clone, move.x, move.y, opponent)
        if result == "WIN" then
            return move
        end
    end

    return self:GetRandomMove(board)
end

-- ==========================================
-- HARD – Depth 1 Lookahead + Heuristic
-- ==========================================

function AI:GetBestStrategicMove(board, player)

    local logic = ArcadiaNexus.TicTacToeLogic
    local opponent = (player == 1) and 2 or 1
    local moves = logic:GetAvailableMoves(board)

    local bestScore = -math.huge
    local bestMove = nil

    for _, move in ipairs(moves) do

        local clone = logic:CloneBoard(board)
        logic:ApplyMove(clone, move.x, move.y, player)

        local score = 0

        -- Immediate win
        local result = logic:CheckWin(clone, move.x, move.y, player)
        if result == "WIN" then
            return move
        end

        -- Check if opponent can win next
        local opponentMoves = logic:GetAvailableMoves(clone)

        for _, opMove in ipairs(opponentMoves) do
            local testBoard = logic:CloneBoard(clone)
            logic:ApplyMove(testBoard, opMove.x, opMove.y, opponent)

            local opResult = logic:CheckWin(testBoard, opMove.x, opMove.y, opponent)
            if opResult == "WIN" then
                score = score - 90
            end
        end

        -- Prefer center
        local center = math.ceil(board.size / 2)
        if move.x == center and move.y == center then
            score = score + 15
        end

        -- Slight preference for corners
        if (move.x == 1 or move.x == board.size) and
           (move.y == 1 or move.y == board.size) then
            score = score + 5
        end

        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end

    return bestMove or self:GetRandomMove(board)
end