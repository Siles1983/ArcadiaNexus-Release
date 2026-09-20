--[[
    Gaming Hub
    Games/ArcadiaRows/AI.lua
    Version: 1.0.0

    KI-Stufen:
      Classic (easy)  – zufällige Spalte aus verfügbaren
      Pro (normal)    – Win-Check → Block-Check → Heuristik
      Insane (hard)   – Negamax mit Alpha-Beta (Tiefe 6), Bedrohungsanalyse

    Alle Methoden arbeiten spaltenbasiert:
      GetBestMove(board, player, difficulty, allowPop) → col, pop
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_AI = {}

local AI    = ArcadiaNexus.AR_AI
local Logic = nil  -- wird lazy gesetzt (nach Logic.lua geladen)

local function GetLogic()
    if not Logic then Logic = ArcadiaNexus.AR_Logic end
    return Logic
end

local function ApplyAction(L, board, player, col, pop)
    if pop then
        return L:ApplyPopOut(board, col, player)
    end
    return L:ApplyMove(board, col, player)
end

local function FirstWinningAction(board, player, allowPop)
    local L = GetLogic()
    local cols = L:GetAvailableColumns(board)
    for i = 1, #cols do
        local clone = L:CloneBoard(board)
        local row = L:ApplyMove(clone, cols[i], player)
        if row and L:CheckWin(clone, cols[i], row, player) == "WIN" then
            return cols[i], false
        end
    end
    if allowPop then
        local pops = L:GetPopColumns(board, player)
        for i = 1, #pops do
            local clone = L:CloneBoard(board)
            if L:ApplyPopOut(clone, pops[i], player) and L:CheckAnyWin(clone, player) == "WIN" then
                return pops[i], true
            end
        end
    end
    return nil
end

function AI:GetBestMove(board, player, difficulty, allowPop)
    difficulty = difficulty or "normal"
    allowPop = allowPop and true or false

    if difficulty == "easy" then
        local col, pop = FirstWinningAction(board, player, allowPop)
        if col then return col, pop end
        return self:RandomMove(board, player, allowPop)
    elseif difficulty == "hard" then
        return self:NegamaxMove(board, player, allowPop)
    else
        return self:StrategicMove(board, player, allowPop)
    end
end

function AI:RandomMove(board, player, allowPop)
    local L = GetLogic()
    local drops = L:GetAvailableColumns(board)
    if #drops > 0 then
        return drops[math.random(1, #drops)], false
    end
    -- Pop nur wenn kein Wurf mehr möglich ist. Sonst nimmt Easy nach einem
    -- Spieler-Pop oft denselben Stein der KI wieder vom Brett.
    if not allowPop or not player then return nil end
    local pops = L:GetPopColumns(board, player)
    if #pops == 0 then return nil end
    return pops[math.random(1, #pops)], true
end

-- ============================================================
-- PRO – Win + Block + Mitte bevorzugen
-- ============================================================

function AI:StrategicMove(board, player, allowPop)
    local L        = GetLogic()
    local opponent = (player == 1) and 2 or 1
    local cols     = L:GetAvailableColumns(board)
    local pops     = allowPop and L:GetPopColumns(board, player) or {}

    local col, pop = FirstWinningAction(board, player, allowPop)
    if col then return col, pop end

    for i = 1, #cols do
        local clone = L:CloneBoard(board)
        local row   = L:ApplyMove(clone, cols[i], opponent)
        if row and L:CheckWin(clone, cols[i], row, opponent) == "WIN" then
            return cols[i], false
        end
    end

    if #cols == 0 then
        if #pops == 0 then return nil end
        return pops[1], true
    end

    local center = math.ceil(board.cols / 2)
    table.sort(cols, function(a, b)
        return math.abs(a - center) < math.abs(b - center)
    end)

    local roll = math.random()
    if roll > 0.90 and cols[3] then
        return cols[3], false
    elseif roll > 0.70 and cols[2] then
        return cols[2], false
    end
    return cols[1], false
end

-- ============================================================
-- INSANE – Negamax mit Alpha-Beta, Tiefe 6
-- ============================================================

-- Einfache Bewertung: zählt Gruppen von 2/3 gleichfarbigen Steinen
local function ScoreWindow(window, player)
    local score    = 0
    local opponent = (player == 1) and 2 or 1
    local countP   = 0
    local countO   = 0
    local empty    = 0

    for _, v in ipairs(window) do
        if v == player   then countP = countP + 1
        elseif v == opponent then countO = countO + 1
        else empty = empty + 1
        end
    end

    if countP == 4 then
        score = score + 100
    elseif countP == 3 and empty == 1 then
        score = score + 5
    elseif countP == 2 and empty == 2 then
        score = score + 2
    end

    if countO == 3 and empty == 1 then
        score = score - 4
    end

    return score
end

local function HeuristicScore(board, player)
    local L     = GetLogic()
    local score = 0
    local W     = board.winLength  -- 4

    -- Mittelspalte bevorzugen
    local center = math.ceil(board.cols / 2)
    local centerCount = 0
    for row = 1, board.rows do
        if board.cells[row][center] == player then
            centerCount = centerCount + 1
        end
    end
    score = score + centerCount * 3

    -- Horizontal
    for row = 1, board.rows do
        for col = 1, board.cols - W + 1 do
            local window = {}
            for k = 0, W-1 do
                table.insert(window, board.cells[row][col + k])
            end
            score = score + ScoreWindow(window, player)
        end
    end

    -- Vertikal
    for col = 1, board.cols do
        for row = 1, board.rows - W + 1 do
            local window = {}
            for k = 0, W-1 do
                table.insert(window, board.cells[row + k][col])
            end
            score = score + ScoreWindow(window, player)
        end
    end

    -- Diagonal ↘
    for row = 1, board.rows - W + 1 do
        for col = 1, board.cols - W + 1 do
            local window = {}
            for k = 0, W-1 do
                table.insert(window, board.cells[row + k][col + k])
            end
            score = score + ScoreWindow(window, player)
        end
    end

    -- Diagonal ↗
    for row = W, board.rows do
        for col = 1, board.cols - W + 1 do
            local window = {}
            for k = 0, W-1 do
                table.insert(window, board.cells[row - k][col + k])
            end
            score = score + ScoreWindow(window, player)
        end
    end

    return score
end

-- Negamax mit Alpha-Beta
local MAX_DEPTH = 6

local function Negamax(board, depth, alpha, beta, player, allowPop)
    local L        = GetLogic()
    local opponent = (player == 1) and 2 or 1
    local cols     = L:GetAvailableColumns(board)
    local pops     = allowPop and L:GetPopColumns(board, player) or {}

    if not L:HasMoves(board, player, allowPop) then return 0, nil, false end
    if depth == 0 then
        return HeuristicScore(board, player) - HeuristicScore(board, opponent), nil, false
    end

    local winCol, winPop = FirstWinningAction(board, player, allowPop)
    if winCol then
        return 1000 + depth, winCol, winPop
    end

    local center = math.ceil(board.cols / 2)
    table.sort(cols, function(a, b)
        return math.abs(a - center) < math.abs(b - center)
    end)

    local bestScore = -math.huge
    local bestCol   = cols[1] or pops[1]
    local bestPop   = not cols[1] and pops[1] ~= nil

    local function Consider(col, pop)
        local clone = L:CloneBoard(board)
        if not ApplyAction(L, clone, player, col, pop) then return false end
        local pWin = L:CheckAnyWin(clone, player)
        local oWin = L:CheckAnyWin(clone, opponent)
        local childScore
        if pWin then
            childScore = 1000 + depth
        elseif oWin then
            childScore = -1000 - depth
        else
            childScore = -Negamax(clone, depth - 1, -beta, -alpha, opponent, allowPop)
        end
        if childScore > bestScore then
            bestScore = childScore
            bestCol   = col
            bestPop   = pop
        end
        alpha = math.max(alpha, bestScore)
        return alpha >= beta
    end

    for i = 1, #cols do
        if Consider(cols[i], false) then break end
    end
    if alpha < beta then
        for i = 1, #pops do
            if Consider(pops[i], true) then break end
        end
    end

    return bestScore, bestCol, bestPop
end

function AI:NegamaxMove(board, player, allowPop)
    local _, col, pop = Negamax(board, MAX_DEPTH, -math.huge, math.huge, player, allowPop)
    if col then return col, pop end
    return self:RandomMove(board, player, allowPop)
end
