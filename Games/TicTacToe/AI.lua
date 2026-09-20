--[[
    Gaming Hub
    TicTacToe AI.lua
    Version: 0.5.0

    easy   – Zufall
    normal – sofortiger Sieg, sonst Block, sonst Zufall
    hard   – 3x3 (Gewinnlänge 3): perfektes Minimax (unbesiegbar)
             größere Bretter: Sieg/Block, Gabeln, offene Reihen
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.TicTacToeAI = {}
local AI = ArcadiaNexus.TicTacToeAI

local INF = 1000
local DIRS = {
    { 1,  0 },
    { 0,  1 },
    { 1,  1 },
    { 1, -1 },
}

local function Logic()
    return ArcadiaNexus.TicTacToeLogic
end

local function Opponent(player)
    return (player == 1) and 2 or 1
end

function AI:GetRandomMove(board)
    local moves = Logic():GetAvailableMoves(board)
    if #moves == 0 then return nil end
    return moves[math.random(1, #moves)]
end

function AI:GetStrategicMove(board, player)
    local logic = Logic()
    local opponent = Opponent(player)
    local moves = logic:GetAvailableMoves(board)

    for i = 1, #moves do
        local move = moves[i]
        local clone = logic:CloneBoard(board)
        logic:ApplyMove(clone, move.x, move.y, player)
        if logic:CheckWin(clone, move.x, move.y, player) == "WIN" then
            return move
        end
    end

    for i = 1, #moves do
        local move = moves[i]
        local clone = logic:CloneBoard(board)
        logic:ApplyMove(clone, move.x, move.y, opponent)
        if logic:CheckWin(clone, move.x, move.y, opponent) == "WIN" then
            return move
        end
    end

    return self:GetRandomMove(board)
end

local function Place(board, x, y, player)
    board.cells[y][x] = player
end

local function Clear(board, x, y)
    board.cells[y][x] = 0
end

local function TerminalScore(board, lastX, lastY, lastPlayer, aiPlayer, depth)
    local result = Logic():CheckWin(board, lastX, lastY, lastPlayer)
    if result == "WIN" then
        if lastPlayer == aiPlayer then
            return INF - depth
        end
        return depth - INF
    elseif result == "DRAW" then
        return 0
    end
    return nil
end

local function MoveBias(board, x, y)
    local size = board.size
    local center = math.ceil(size / 2)
    if x == center and y == center then
        return 3
    end
    if (x == 1 or x == size) and (y == 1 or y == size) then
        return 1
    end
    return 0
end

local function Minimax(board, toMove, aiPlayer, depth, alpha, beta, lastX, lastY, lastPlayer)
    if lastX then
        local term = TerminalScore(board, lastX, lastY, lastPlayer, aiPlayer, depth)
        if term ~= nil then
            return term
        end
    end

    local size = board.size
    local opp = Opponent(toMove)
    local isMax = (toMove == aiPlayer)
    local best = isMax and -INF or INF

    for y = 1, size do
        for x = 1, size do
            if board.cells[y][x] == 0 then
                Place(board, x, y, toMove)
                local score = Minimax(board, opp, aiPlayer, depth + 1, alpha, beta, x, y, toMove)
                Clear(board, x, y)
                if isMax then
                    if score > best then best = score end
                    if best > alpha then alpha = best end
                else
                    if score < best then best = score end
                    if best < beta then beta = best end
                end
                if beta <= alpha then
                    return best
                end
            end
        end
    end

    return best
end

function AI:GetPerfectMove(board, player)
    local logic = Logic()
    local moves = logic:GetAvailableMoves(board)
    if #moves == 0 then return nil end
    if #moves == 1 then return moves[1] end

    local bestScore = -INF
    local bestMove = moves[1]
    local bestBias = -1

    for i = 1, #moves do
        local move = moves[i]
        Place(board, move.x, move.y, player)
        local score = Minimax(
            board,
            Opponent(player),
            player,
            1,
            -INF,
            INF,
            move.x,
            move.y,
            player
        )
        Clear(board, move.x, move.y)
        local bias = MoveBias(board, move.x, move.y)
        if score > bestScore or (score == bestScore and bias > bestBias) then
            bestScore = score
            bestMove = move
            bestBias = bias
        end
    end

    return bestMove
end

local function CountWinningMoves(board, player)
    local logic = Logic()
    local size = board.size
    local n = 0
    for y = 1, size do
        for x = 1, size do
            if board.cells[y][x] == 0 then
                Place(board, x, y, player)
                if logic:CheckWin(board, x, y, player) == "WIN" then
                    n = n + 1
                end
                Clear(board, x, y)
            end
        end
    end
    return n
end

local function ScoreWindows(board, player)
    local size = board.size
    local W = board.winLength or size
    local opp = Opponent(player)
    local score = 0
    for y = 1, size do
        for x = 1, size do
            for d = 1, #DIRS do
                local dx, dy = DIRS[d][1], DIRS[d][2]
                local countP, countO, empty = 0, 0, 0
                local fits = true
                for k = 0, W - 1 do
                    local nx = x + dx * k
                    local ny = y + dy * k
                    if nx < 1 or ny < 1 or nx > size or ny > size then
                        fits = false
                        break
                    end
                    local v = board.cells[ny][nx]
                    if v == player then
                        countP = countP + 1
                    elseif v == opp then
                        countO = countO + 1
                    else
                        empty = empty + 1
                    end
                end
                if fits then
                    if countO == 0 then
                        if countP == W - 1 and empty == 1 then
                            score = score + 50
                        elseif countP == W - 2 and empty == 2 then
                            score = score + 10
                        elseif countP > 0 then
                            score = score + countP
                        end
                    elseif countP == 0 then
                        if countO == W - 1 and empty == 1 then
                            score = score - 45
                        elseif countO == W - 2 and empty == 2 then
                            score = score - 8
                        end
                    end
                end
            end
        end
    end
    return score
end

function AI:GetBestStrategicMove(board, player)
    if board.size == 3 and (board.winLength or 3) == 3 then
        return self:GetPerfectMove(board, player)
    end

    local logic = Logic()
    local opponent = Opponent(player)
    local moves = logic:GetAvailableMoves(board)
    if #moves == 0 then return nil end

    local bestScore = -math.huge
    local bestMove = moves[1]

    for i = 1, #moves do
        local move = moves[i]
        Place(board, move.x, move.y, player)

        local score = 0
        if logic:CheckWin(board, move.x, move.y, player) == "WIN" then
            Clear(board, move.x, move.y)
            return move
        end

        local ourWins = CountWinningMoves(board, player)
        local oppWins = CountWinningMoves(board, opponent)

        if oppWins >= 2 then
            score = score - 800
        elseif oppWins == 1 then
            score = score - 220
        end
        if ourWins >= 2 then
            score = score + 700
        elseif ourWins == 1 then
            score = score + 140
        end

        score = score + ScoreWindows(board, player)
        score = score + MoveBias(board, move.x, move.y)

        Clear(board, move.x, move.y)

        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end

    return bestMove
end

function AI:GetBestMove(board, player, difficulty)
    difficulty = difficulty or "normal"
    if difficulty == "easy" then
        return self:GetRandomMove(board)
    elseif difficulty == "hard" then
        return self:GetBestStrategicMove(board, player)
    end
    return self:GetStrategicMove(board, player)
end
