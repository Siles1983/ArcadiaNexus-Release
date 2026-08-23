--[[
    Gaming Hub
    Games/Chess/Logic.lua
    Version: 1.0.0

    6×6 Mini-Schach (Silbermann-Aufstellung):
      Reihe 1 (Horde, Schwarz):  T  S  D  K  S  T
      Reihe 2 (Horde, Schwarz):  B  B  B  B  B  B
      Reihe 5 (Allianz, Weiß):   B  B  B  B  B  B
      Reihe 6 (Allianz, Weiß):   T  S  D  K  S  T

    Figuren-Codes:
      PAWN   = Bauer
      ROOK   = Turm
      KNIGHT = Springer
      QUEEN  = Dame
      KING   = König

    Farben:
      "white" = Allianz (menschlicher Spieler, zieht von unten)
      "black" = Horde (KI, zieht von oben)

    board[r][c]:
      nil   = leeres Feld
      { type, color }

    Koordinaten:
      r=1 oben (Horde), r=6 unten (Allianz)
      c=1 links,        c=6 rechts

    Öffentliche API:
      Logic:NewBoard()
      Logic:GetLegalMoves(board, r, c)         → { {fromR,fromC,toR,toC}, ... }
      Logic:GetAllLegalMoves(board, color)      → alle Züge einer Seite
      Logic:ApplyMove(board, move)              → newBoard
      Logic:IsInCheck(board, color)             → bool
      Logic:IsCheckmate(board, color)           → bool
      Logic:IsStalemate(board, color)           → bool
      Logic:GetPieceAt(board, r, c)             → piece or nil
      Logic:CopyBoard(board)                    → newBoard
      Logic:GetPieceValue(type)                 → number (für KI)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_Logic = {}
local Logic = ArcadiaNexus.Chess_Logic

-- ============================================================
-- Figurenwerte (für KI-Bewertung)
-- ============================================================
local PIECE_VALUE = {
    PAWN   = 100,
    KNIGHT = 300,
    ROOK   = 500,
    QUEEN  = 900,
    KING   = 10000,
}

-- Positionsboni für Bauern (fördern Vorwärtsbewegung)
-- Weiß bewegt sich von r=6 → r=1, Schwarz von r=1 → r=6
local PAWN_BONUS_WHITE = {
    [1]=60, [2]=50, [3]=30, [4]=20, [5]=10, [6]=0
}
local PAWN_BONUS_BLACK = {
    [1]=0, [2]=10, [3]=20, [4]=30, [5]=50, [6]=60
}

-- ============================================================
-- Board erstellen
-- ============================================================

function Logic:NewBoard()
    local board = {}
    for r = 1, 6 do
        board[r] = {}
        for c = 1, 6 do
            board[r][c] = nil
        end
    end

    -- Horde (schwarz) – oben
    local backRank = { "ROOK", "KNIGHT", "QUEEN", "KING", "KNIGHT", "ROOK" }
    for c = 1, 6 do
        board[1][c] = { type = backRank[c], color = "black" }
        board[2][c] = { type = "PAWN",      color = "black" }
    end

    -- Allianz (weiß) – unten
    for c = 1, 6 do
        board[5][c] = { type = "PAWN",      color = "white" }
        board[6][c] = { type = backRank[c], color = "white" }
    end

    return board
end

-- ============================================================
-- Board kopieren
-- ============================================================

function Logic:CopyBoard(board)
    local new = {}
    for r = 1, 6 do
        new[r] = {}
        for c = 1, 6 do
            if board[r][c] then
                new[r][c] = { type = board[r][c].type, color = board[r][c].color }
            else
                new[r][c] = nil
            end
        end
    end
    return new
end

-- ============================================================
-- Figur abrufen
-- ============================================================

function Logic:GetPieceAt(board, r, c)
    if r < 1 or r > 6 or c < 1 or c > 6 then return nil end
    return board[r][c]
end

-- ============================================================
-- Zug anwenden
-- ============================================================

function Logic:ApplyMove(board, move)
    local new = self:CopyBoard(board)
    local piece = new[move.fromR][move.fromC]
    new[move.toR][move.toC]     = piece
    new[move.fromR][move.fromC] = nil

    -- Bauernumwandlung: Bauer erreicht letzte Reihe → wird Dame
    if piece and piece.type == "PAWN" then
        if piece.color == "white" and move.toR == 1 then
            new[move.toR][move.toC].type = "QUEEN"
        elseif piece.color == "black" and move.toR == 6 then
            new[move.toR][move.toC].type = "QUEEN"
        end
    end

    return new
end

-- ============================================================
-- Rohe Züge (ohne Schach-Prüfung)
-- ============================================================

local function inBounds(r, c)
    return r >= 1 and r <= 6 and c >= 1 and c <= 6
end

local function addSlideMoves(board, r, c, dirs, moves)
    local piece = board[r][c]
    for _, d in ipairs(dirs) do
        local nr, nc = r + d[1], c + d[2]
        while inBounds(nr, nc) do
            local target = board[nr][nc]
            if target then
                if target.color ~= piece.color then
                    moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
                end
                break  -- blockiert
            end
            moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            nr = nr + d[1]; nc = nc + d[2]
        end
    end
end

local function addStepMoves(board, r, c, offsets, moves)
    local piece = board[r][c]
    for _, o in ipairs(offsets) do
        local nr, nc = r + o[1], c + o[2]
        if inBounds(nr, nc) then
            local target = board[nr][nc]
            if not target or target.color ~= piece.color then
                moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            end
        end
    end
end

function Logic:GetRawMoves(board, r, c)
    local piece = board[r][c]
    if not piece then return {} end
    local moves = {}

    if piece.type == "PAWN" then
        local dir = (piece.color == "white") and -1 or 1  -- weiß nach oben (r-1), schwarz nach unten
        local nr = r + dir
        -- Vorwärts (nur wenn leer)
        if inBounds(nr, c) and not board[nr][c] then
            moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=c }
        end
        -- Diagonal schlagen
        for _, dc in ipairs({ -1, 1 }) do
            local nc = c + dc
            if inBounds(nr, nc) and board[nr][nc] and board[nr][nc].color ~= piece.color then
                moves[#moves+1] = { fromR=r, fromC=c, toR=nr, toC=nc }
            end
        end

    elseif piece.type == "ROOK" then
        addSlideMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1} }, moves)

    elseif piece.type == "KNIGHT" then
        addStepMoves(board, r, c,
            { {2,1},{2,-1},{-2,1},{-2,-1},{1,2},{1,-2},{-1,2},{-1,-2} }, moves)

    elseif piece.type == "QUEEN" then
        addSlideMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }, moves)

    elseif piece.type == "KING" then
        addStepMoves(board, r, c,
            { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }, moves)
    end

    return moves
end

-- ============================================================
-- Schach-Prüfung: Steht `color`s König im Schach?
-- ============================================================

function Logic:IsInCheck(board, color)
    -- König finden
    local kr, kc
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == color and p.type == "KING" then
                kr, kc = r, c
            end
        end
    end
    if not kr then return true end  -- kein König = verloren

    -- Prüfen ob gegnerische Figur den König angreift
    local enemy = (color == "white") and "black" or "white"
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == enemy then
                local raw = self:GetRawMoves(board, r, c)
                for _, m in ipairs(raw) do
                    if m.toR == kr and m.toC == kc then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Legale Züge (bereinigt um Selbst-Schach)
-- ============================================================

function Logic:GetLegalMoves(board, r, c)
    local piece = board[r][c]
    if not piece then return {} end

    local raw    = self:GetRawMoves(board, r, c)
    local legal  = {}

    for _, move in ipairs(raw) do
        local newBoard = self:ApplyMove(board, move)
        if not self:IsInCheck(newBoard, piece.color) then
            legal[#legal+1] = move
        end
    end
    return legal
end

-- ============================================================
-- Alle legalen Züge einer Farbe
-- ============================================================

function Logic:GetAllLegalMoves(board, color)
    local all = {}
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p and p.color == color then
                local moves = self:GetLegalMoves(board, r, c)
                for _, m in ipairs(moves) do
                    all[#all+1] = m
                end
            end
        end
    end
    return all
end

-- ============================================================
-- Schachmatt / Patt
-- ============================================================

function Logic:IsCheckmate(board, color)
    if not self:IsInCheck(board, color) then return false end
    return #self:GetAllLegalMoves(board, color) == 0
end

function Logic:IsStalemate(board, color)
    if self:IsInCheck(board, color) then return false end
    return #self:GetAllLegalMoves(board, color) == 0
end

-- ============================================================
-- Figurenwert
-- ============================================================

function Logic:GetPieceValue(pieceType)
    return PIECE_VALUE[pieceType] or 0
end

-- ============================================================
-- Board-Bewertung für KI (positiv = gut für Weiß)
-- ============================================================

function Logic:EvaluateBoard(board)
    local score = 0
    for r = 1, 6 do
        for c = 1, 6 do
            local p = board[r][c]
            if p then
                local val = PIECE_VALUE[p.type] or 0
                -- Positionsbonus für Bauern
                if p.type == "PAWN" then
                    if p.color == "white" then
                        val = val + (PAWN_BONUS_WHITE[r] or 0)
                    else
                        val = val + (PAWN_BONUS_BLACK[r] or 0)
                    end
                end
                -- Zentrumsbonus für alle Figuren (c=3,4 und r=3,4)
                if (c == 3 or c == 4) and (r == 3 or r == 4) then
                    val = val + 15
                end
                if p.color == "white" then
                    score = score + val
                else
                    score = score - val
                end
            end
        end
    end
    return score
end
