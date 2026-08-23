-- Blockdrop – Games/Blockdrop/Logic.lua
-- Reine Spiellogik: Board, Pieces, Rotation, Kollision, Line-Clear

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.BLD_Logic = {}
local L = ArcadiaNexus.BLD_Logic

-- ============================================================
-- Schwierigkeit (nur noch ein Modus: NORMAL)
-- ============================================================
L.DIFFICULTY = {
    NORMAL = { cols=10, rows=20, startInterval=0.65, label="Normal" },
}

-- ============================================================
-- Piece-Definitionen (Rotationen als 2D-Arrays)
-- ============================================================
local PIECES = {
    I = {
        shapes = {
            {{0,0,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0}},
            {{0,0,1,0},{0,0,1,0},{0,0,1,0},{0,0,1,0}},
        },
        type = "I",
    },
    O = {
        shapes = {
            {{1,1},{1,1}},
        },
        type = "O",
    },
    T = {
        shapes = {
            {{0,1,0},{1,1,1},{0,0,0}},
            {{0,1,0},{0,1,1},{0,1,0}},
            {{0,0,0},{1,1,1},{0,1,0}},
            {{0,1,0},{1,1,0},{0,1,0}},
        },
        type = "T",
    },
    L = {
        shapes = {
            {{0,0,1},{1,1,1},{0,0,0}},
            {{0,1,0},{0,1,0},{0,1,1}},
            {{0,0,0},{1,1,1},{1,0,0}},
            {{1,1,0},{0,1,0},{0,1,0}},
        },
        type = "L",
    },
    J = {
        shapes = {
            {{1,0,0},{1,1,1},{0,0,0}},
            {{0,1,1},{0,1,0},{0,1,0}},
            {{0,0,0},{1,1,1},{0,0,1}},
            {{0,1,0},{0,1,0},{1,1,0}},
        },
        type = "J",
    },
    S = {
        shapes = {
            {{0,1,1},{1,1,0},{0,0,0}},
            {{0,1,0},{0,1,1},{0,0,1}},
        },
        type = "S",
    },
    Z = {
        shapes = {
            {{1,1,0},{0,1,1},{0,0,0}},
            {{0,0,1},{0,1,1},{0,1,0}},
        },
        type = "Z",
    },
}

local PIECE_TYPES = {"I","O","T","L","J","S","Z"}

-- ============================================================
-- Board erstellen
-- ============================================================
function L:NewBoard(difficulty)
    -- difficulty-Parameter wird ignoriert; immer NORMAL (10x20)
    local cfg = self.DIFFICULTY.NORMAL
    local b = {
        difficulty  = "NORMAL",
        cols        = cfg.cols,
        rows        = cfg.rows,
        interval    = cfg.startInterval,
        cells       = {},
        score       = 0,
        level       = 0,
        lines       = 0,
        piece       = nil,
        nextPiece   = nil,
    }
    for r = 1, cfg.rows do
        b.cells[r] = {}
        for c = 1, cfg.cols do
            b.cells[r][c] = nil
        end
    end
    return b
end

-- ============================================================
-- Piece erstellen
-- ============================================================
function L:NewPiece(board)
    local t   = PIECE_TYPES[math.random(#PIECE_TYPES)]
    local def = PIECES[t]
    return {
        type    = t,
        shapes  = def.shapes,
        rot     = 1,
        row     = 1,
        col     = math.floor((board.cols - #def.shapes[1][1]) / 2) + 1,
    }
end

-- ============================================================
-- Shape des aktuellen Pieces holen
-- ============================================================
function L:GetShape(piece)
    return piece.shapes[piece.rot] or piece.shapes[1]
end

-- ============================================================
-- Kollisionsprüfung
-- ============================================================
function L:CanPlace(board, piece, rowOff, colOff)
    local shape = self:GetShape(piece)
    rowOff = rowOff or 0
    colOff = colOff or 0
    for pr = 1, #shape do
        for pc = 1, #shape[pr] do
            if shape[pr][pc] == 1 then
                local br = piece.row + pr - 1 + rowOff
                local bc = piece.col + pc - 1 + colOff
                if br < 1 or br > board.rows then return false end
                if bc < 1 or bc > board.cols then return false end
                if board.cells[br][bc] then return false end
            end
        end
    end
    return true
end

-- ============================================================
-- Bewegungen
-- ============================================================
function L:MoveLeft(board)
    if self:CanPlace(board, board.piece, 0, -1) then
        board.piece.col = board.piece.col - 1
    end
end

function L:MoveRight(board)
    if self:CanPlace(board, board.piece, 0, 1) then
        board.piece.col = board.piece.col + 1
    end
end

function L:Rotate(board)
    local p      = board.piece
    local oldRot = p.rot
    p.rot = (p.rot % #p.shapes) + 1
    if not self:CanPlace(board, p, 0, 0) then
        if self:CanPlace(board, p, 0, 1) then
            p.col = p.col + 1
        elseif self:CanPlace(board, p, 0, -1) then
            p.col = p.col - 1
        else
            p.rot = oldRot
        end
    end
end

-- Soft-Drop (ein Schritt nach unten)
function L:Tick(board, piece)
    if self:CanPlace(board, piece, 1, 0) then
        piece.row = piece.row + 1
        return true
    end
    return false
end

-- Hard-Drop
function L:HardDrop(board)
    local p = board.piece
    while self:CanPlace(board, p, 1, 0) do
        p.row = p.row + 1
    end
end

-- Ghost-Row berechnen
function L:GetGhostRow(board)
    local p     = board.piece
    local ghost = p.row
    while self:CanPlace(board, { type=p.type, shapes=p.shapes, rot=p.rot, row=ghost+1, col=p.col }, 0, 0) do
        ghost = ghost + 1
    end
    return ghost
end

-- ============================================================
-- Piece einrasten
-- ============================================================
function L:LockPiece(board, piece)
    local shape = self:GetShape(piece)
    for pr = 1, #shape do
        for pc = 1, #shape[pr] do
            if shape[pr][pc] == 1 then
                local br = piece.row + pr - 1
                local bc = piece.col + pc - 1
                if br >= 1 and br <= board.rows and bc >= 1 and bc <= board.cols then
                    board.cells[br][bc] = piece.type
                end
            end
        end
    end
end

-- ============================================================
-- Reihen löschen
-- ============================================================
function L:ClearLines(board)
    local cleared = 0
    local r = board.rows
    while r >= 1 do
        local full = true
        for c = 1, board.cols do
            if not board.cells[r][c] then full = false; break end
        end
        if full then
            cleared = cleared + 1
            table.remove(board.cells, r)
            local newRow = {}
            for c = 1, board.cols do newRow[c] = nil end
            table.insert(board.cells, 1, newRow)
        else
            r = r - 1
        end
    end
    return cleared
end

-- ============================================================
-- Score (kein Difficulty-Multiplikator mehr nötig)
-- ============================================================
local LINE_SCORES = {40, 100, 300, 1200}

function L:AddScore(board, linesCleared)
    if linesCleared > 0 then
        local pts = (LINE_SCORES[linesCleared] or 1200) * (board.level + 1)
        board.score = board.score + pts
        board.lines = board.lines + linesCleared
        board.level = math.floor(board.lines / 10)
    end
end

-- ============================================================
-- Tick-Interval (nach Level)
-- ============================================================
function L:GetTickInterval(level)
    local base = L.DIFFICULTY.NORMAL.startInterval
    return math.max(0.08, base - level * 0.05)
end

-- ============================================================
-- Game-Over-Check
-- ============================================================
function L:CheckGameOver(board, piece)
    return not self:CanPlace(board, piece, 0, 0)
end

-- ============================================================
-- Save / Resume
-- ============================================================
function L:PieceSnapshot(piece)
    if not piece then return nil end
    return { type = piece.type, rot = piece.rot, row = piece.row, col = piece.col }
end

function L:RestorePiece(board, snap)
    if not snap or not snap.type then return nil end
    local def = PIECES[snap.type]
    if not def then return self:NewPiece(board) end
    return {
        type   = snap.type,
        shapes = def.shapes,
        rot    = snap.rot or 1,
        row    = snap.row or 1,
        col    = snap.col or 1,
    }
end

function L:SerializeBoard(board)
    if not board then return nil end
    local cells = {}
    for r = 1, board.rows do
        cells[r] = {}
        for c = 1, board.cols do
            cells[r][c] = board.cells[r][c]
        end
    end
    return {
        difficulty = board.difficulty,
        cols       = board.cols,
        rows       = board.rows,
        interval   = board.interval,
        score      = board.score,
        level      = board.level,
        lines      = board.lines,
        cells      = cells,
        piece      = self:PieceSnapshot(board.piece),
        nextPiece  = self:PieceSnapshot(board.nextPiece),
    }
end

function L:DeserializeBoard(data)
    local b = self:NewBoard(data and data.difficulty)
    if not data then return b end
    b.score     = data.score or 0
    b.level     = data.level or 0
    b.lines     = data.lines or 0
    b.interval  = data.interval or b.interval
    if data.cells then
        for r = 1, b.rows do
            for c = 1, b.cols do
                b.cells[r][c] = data.cells[r] and data.cells[r][c] or nil
            end
        end
    end
    b.piece     = self:RestorePiece(b, data.piece)
    b.nextPiece = self:RestorePiece(b, data.nextPiece)
    return b
end
