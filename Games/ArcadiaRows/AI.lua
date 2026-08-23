--[[
    Gaming Hub
    Games/ArcadiaRows/AI.lua
    Version: 1.0.0

    KI-Stufen:
      Classic (easy)  – zufällige Spalte aus verfügbaren
      Pro (normal)    – Win-Check → Block-Check → Heuristik
      Insane (hard)   – Negamax mit Alpha-Beta (Tiefe 6), Bedrohungsanalyse

    Alle Methoden arbeiten spaltenbasiert:
      GetBestMove(board, player, difficulty) → col (1-basiert) oder nil
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_AI = {}

local AI    = ArcadiaNexus.AR_AI
local Logic = nil  -- wird lazy gesetzt (nach Logic.lua geladen)

local function GetLogic()
    if not Logic then Logic = ArcadiaNexus.AR_Logic end
    return Logic
end

-- ============================================================
-- PUBLIC ENTRY
-- ============================================================

function AI:GetBestMove(board, player, difficulty)
    difficulty = difficulty or "normal"

    if difficulty == "easy" then
        return self:RandomMove(board)
    elseif difficulty == "hard" then
        return self:NegamaxMove(board, player)
    else
        return self:StrategicMove(board, player)
    end
end

-- ============================================================
-- CLASSIC – Zufall
-- ============================================================

function AI:RandomMove(board)
    local L = GetLogic()
    local cols = L:GetAvailableColumns(board)
    if #cols == 0 then return nil end
    return cols[math.random(1, #cols)]
end

-- ============================================================
-- PRO – Win + Block + Mitte bevorzugen
-- ============================================================

function AI:StrategicMove(board, player)
    local L        = GetLogic()
    local opponent = (player == 1) and 2 or 1
    local cols     = L:GetAvailableColumns(board)

    if #cols == 0 then return nil end

    -- Sofort gewinnen?
    for _, col in ipairs(cols) do
        local clone = L:CloneBoard(board)
        local row   = L:ApplyMove(clone, col, player)
        if row then
            local result = L:CheckWin(clone, col, row, player)
            if result == "WIN" then return col end
        end
    end

    -- Gegner blockieren?
    for _, col in ipairs(cols) do
        local clone = L:CloneBoard(board)
        local row   = L:ApplyMove(clone, col, opponent)
        if row then
            local result = L:CheckWin(clone, col, row, opponent)
            if result == "WIN" then return col end
        end
    end

    -- Mitte bevorzugen, dann Nähe zur Mitte
    local center = math.ceil(board.cols / 2)
    table.sort(cols, function(a, b)
        return math.abs(a - center) < math.abs(b - center)
    end)

    return cols[1]
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

local function Negamax(board, depth, alpha, beta, player)
    local L        = GetLogic()
    local opponent = (player == 1) and 2 or 1
    local cols     = L:GetAvailableColumns(board)

    -- Terminal: voll oder Tiefe 0
    if L:IsBoardFull(board) then return 0, nil end
    if depth == 0 then
        return HeuristicScore(board, player) - HeuristicScore(board, opponent), nil
    end

    -- Gewinnen sofort prüfen (vor rekursiver Suche)
    for _, col in ipairs(cols) do
        local clone = L:CloneBoard(board)
        local row   = L:ApplyMove(clone, col, player)
        if row then
            local result = L:CheckWin(clone, col, row, player)
            if result == "WIN" then
                -- Sofortiger Sieg: sehr hoher Wert
                return 1000 + depth, col
            end
        end
    end

    -- Mittelspalten zuerst durchsuchen (Move Ordering)
    local center = math.ceil(board.cols / 2)
    table.sort(cols, function(a, b)
        return math.abs(a - center) < math.abs(b - center)
    end)

    local bestScore = -math.huge
    local bestCol   = cols[1]

    for _, col in ipairs(cols) do
        local clone = L:CloneBoard(board)
        local row   = L:ApplyMove(clone, col, player)
        if row then
            local childScore = -Negamax(clone, depth - 1, -beta, -alpha, opponent)
            if childScore > bestScore then
                bestScore = childScore
                bestCol   = col
            end
            alpha = math.max(alpha, bestScore)
            if alpha >= beta then break end  -- Beta-Cutoff
        end
    end

    return bestScore, bestCol
end

function AI:NegamaxMove(board, player)
    local _, col = Negamax(board, MAX_DEPTH, -math.huge, math.huge, player)
    return col or self:RandomMove(board)
end
