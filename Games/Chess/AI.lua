--[[
    Gaming Hub
    Games/Chess/AI.lua
    Version: 1.0.0

    Drei KI-Modi:
      Classic (easy)   – Zufälliger legaler Zug
      Pro     (normal) – Greedy: wählt den Zug mit bestem Material-Gewinn,
                         schlägt immer wenn möglich, vermeidet Selbstverlust
      Insane  (hard)   – Minimax mit Alpha-Beta-Pruning, Tiefe 3
                         Bewertet Board nach Material + Position
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_AI = {}
local AI = ArcadiaNexus.Chess_AI

-- ============================================================
-- Classic – Zufall
-- ============================================================

function AI:GetMoveClassic(board)
    local Logic = ArcadiaNexus.Chess_Logic
    local moves = Logic:GetAllLegalMoves(board, "black")
    if #moves == 0 then return nil end
    return moves[math.random(1, #moves)]
end

-- ============================================================
-- Pro – Greedy (1-Ply mit Heuristiken)
-- Priorität: (1) Schachmatt, (2) Schlagen, (3) Schach geben, (4) Zufall
-- ============================================================

function AI:GetMovePro(board)
    local Logic = ArcadiaNexus.Chess_Logic
    local moves = Logic:GetAllLegalMoves(board, "black")
    if #moves == 0 then return nil end

    local best      = nil
    local bestScore = -math.huge

    for _, move in ipairs(moves) do
        local newBoard = Logic:ApplyMove(board, move)
        local score    = 0

        -- Schachmatt sofort gewinnen
        if Logic:IsCheckmate(newBoard, "white") then
            return move
        end

        -- Schlagen
        local target = board[move.toR][move.toC]
        if target then
            score = score + Logic:GetPieceValue(target.type)
        end

        -- Schach geben (kleiner Bonus)
        if Logic:IsInCheck(newBoard, "white") then
            score = score + 50
        end

        -- Eigene Figur in Gefahr vermeiden
        local piece = board[move.fromR][move.fromC]
        local enemyMoves = Logic:GetAllLegalMoves(newBoard, "white")
        for _, em in ipairs(enemyMoves) do
            if em.toR == move.toR and em.toC == move.toC then
                score = score - Logic:GetPieceValue(piece.type) * 0.8
                break
            end
        end

        -- Bauern vorwärts bevorzugen
        if piece.type == "PAWN" then
            score = score + (move.toR - move.fromR) * 10
        end

        if score > bestScore then
            bestScore = score
            best      = move
        end
    end

    return best or moves[math.random(1, #moves)]
end

-- ============================================================
-- Insane – Minimax mit Alpha-Beta (Tiefe 3)
-- ============================================================

local MAX_DEPTH = 3

local function minimax(board, depth, alpha, beta, maximizing)
    local Logic = ArcadiaNexus.Chess_Logic

    local color = maximizing and "black" or "white"

    -- Abbruchbedingungen
    if depth == 0 then
        return Logic:EvaluateBoard(board) * -1, nil  -- negiert: schwarz will minimieren
    end

    if Logic:IsCheckmate(board, "white") then return  1000000 - (MAX_DEPTH - depth)*10, nil end
    if Logic:IsCheckmate(board, "black") then return -1000000 + (MAX_DEPTH - depth)*10, nil end
    if Logic:IsStalemate(board, color)   then return 0, nil end

    local moves = Logic:GetAllLegalMoves(board, color)
    if #moves == 0 then return Logic:EvaluateBoard(board) * -1, nil end

    -- Züge nach Material-Gewinn vorsortieren (verbessert Alpha-Beta-Schnitte)
    table.sort(moves, function(a, b)
        local ta = board[a.toR][a.toC]
        local tb = board[b.toR][b.toC]
        local va = ta and Logic:GetPieceValue(ta.type) or 0
        local vb = tb and Logic:GetPieceValue(tb.type) or 0
        return va > vb
    end)

    local bestMove  = moves[1]

    if maximizing then
        local maxEval = -math.huge
        for _, move in ipairs(moves) do
            local newBoard  = Logic:ApplyMove(board, move)
            local eval, _   = minimax(newBoard, depth-1, alpha, beta, false)
            if eval > maxEval then
                maxEval  = eval
                bestMove = move
            end
            alpha = math.max(alpha, eval)
            if beta <= alpha then break end
        end
        return maxEval, bestMove
    else
        local minEval = math.huge
        for _, move in ipairs(moves) do
            local newBoard  = Logic:ApplyMove(board, move)
            local eval, _   = minimax(newBoard, depth-1, alpha, beta, true)
            if eval < minEval then
                minEval  = eval
                bestMove = move
            end
            beta = math.min(beta, eval)
            if beta <= alpha then break end
        end
        return minEval, bestMove
    end
end

function AI:GetMoveInsane(board)
    local Logic = ArcadiaNexus.Chess_Logic
    local moves = Logic:GetAllLegalMoves(board, "black")
    if #moves == 0 then return nil end

    local _, best = minimax(board, MAX_DEPTH, -math.huge, math.huge, true)
    return best or moves[1]
end

-- ============================================================
-- Haupt-Einstieg
-- ============================================================

function AI:GetMove(board, difficulty)
    if difficulty == "easy"   then return self:GetMoveClassic(board) end
    if difficulty == "normal" then return self:GetMovePro(board)     end
    if difficulty == "hard"   then return self:GetMoveInsane(board)  end
    return self:GetMoveClassic(board)
end
