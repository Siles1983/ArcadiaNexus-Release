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
        ruleVersion=2, bag={}, bagIndex=1, gravityRemaining=0.65, lockRemaining=nil, lockResets=0,
        pieceSerial=0, elapsedSecs=0, simRemainder=0,
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
    if board.bagIndex>#board.bag then
        board.bag={} for i,t in ipairs(PIECE_TYPES) do board.bag[i]=t end
        ArcadiaNexus.ArrayUtils.Shuffle(board.bag); board.bagIndex=1
    end
    local t=board.bag[board.bagIndex]; board.bagIndex=board.bagIndex+1
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
        return true
    end
    return false
end

function L:MoveRight(board)
    if self:CanPlace(board, board.piece, 0, 1) then
        board.piece.col = board.piece.col + 1
        return true
    end
    return false
end

-- Deliberate clockwise kicks for the existing 2/4 rotation shape representation.
L.KICKS={
    normal={
        {{0,0},{-1,0},{1,0},{-1,-1},{1,-1},{0,-1}},
        {{0,0},{1,0},{-1,0},{1,-1},{-1,-1},{0,-1}},
        {{0,0},{1,0},{-1,0},{1,-1},{-1,-1},{0,-1}},
        {{0,0},{-1,0},{1,0},{-1,-1},{1,-1},{0,-1}},
    },
    I={
        {{0,0},{-1,0},{1,0},{-2,0},{2,0},{0,-1},{0,-2}},
        {{0,0},{2,0},{-2,0},{1,0},{-1,0},{0,-1},{0,-2}},
    },
}
function L:Rotate(board)
    local p=board.piece
    if not p or #p.shapes==1 then return false end
    local candidate={type=p.type,shapes=p.shapes,rot=p.rot%#p.shapes+1,row=p.row,col=p.col}
    local kicks=self.KICKS[p.type] or self.KICKS.normal
    for _,kick in ipairs(kicks[p.rot]) do
        candidate.row=p.row+kick[2]; candidate.col=p.col+kick[1]
        if self:CanPlace(board,candidate) then p.rot=candidate.rot; p.row=candidate.row; p.col=candidate.col; return true end
    end
    return false
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
    if not def then return nil end
    return {
        type   = snap.type,
        shapes = def.shapes,
        rot    = snap.rot or 1,
        row    = snap.row or 1,
        col    = snap.col or 1,
    }
end

L.LOCK_DELAY=0.35
L.LOCK_RESET_LIMIT=8
L.MOVE_DELAY=0.18
L.MOVE_RATE=0.06
L.SOFT_RATE=0.04
function L:Copy(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=self:Copy(x) end return out
end
function L:SerializeBoard(board,phase)
    if not board or board.terminal then return nil end
    local save=self:Copy(board)
    save.piece=self:PieceSnapshot(board.piece); save.nextPiece=self:PieceSnapshot(board.nextPiece)
    save.version=2; save.phase=phase or "PLAYING"; save.interval=self:GetTickInterval(board.level)
    save.resultData=nil
    return save
end
function L:DeserializeBoard(data)
    local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
    local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
    if type(data)~="table" or data.terminal or data.cols~=10 or data.rows~=20 or data.difficulty~="NORMAL"
        or not integer(data.score) or not integer(data.lines) or data.level~=math.floor(data.lines/10)
        or type(data.cells)~="table" then return nil end
    local b=self:NewBoard()
    for r=1,20 do
        if type(data.cells[r])~="table" then return nil end
        for c,v in pairs(data.cells[r]) do
            if not integer(c) or c<1 or c>10 or not PIECES[v] then return nil end
            b.cells[r][c]=v
        end
    end
    for r in pairs(data.cells) do if not integer(r) or r<1 or r>20 then return nil end end
    local function piece(snap)
        if type(snap)~="table" or not PIECES[snap.type] or not integer(snap.rot) or snap.rot<1 or snap.rot>#PIECES[snap.type].shapes
            or not finite(snap.row) or snap.row%1~=0 or snap.row< -3 or snap.row>20
            or not finite(snap.col) or snap.col%1~=0 or snap.col< -3 or snap.col>10 then return nil end
        return self:RestorePiece(b,snap)
    end
    b.piece=piece(data.piece); b.nextPiece=piece(data.nextPiece)
    if not b.piece or not b.nextPiece or not self:CanPlace(b,b.piece) then return nil end
    -- Preview must be the canonical, not-yet-spawned orientation/anchor.
    local np=b.nextPiece
    if np.rot~=1 or np.row~=1 or np.col~=math.floor((10-#np.shapes[1][1])/2)+1 then return nil end
    b.score=data.score; b.lines=data.lines; b.level=data.level; b.interval=self:GetTickInterval(b.level)
    if data.version==nil then
        b.legacyContinuation=true; b.gravityRemaining=b.interval
        return b
    end
    if data.version~=2 or data.ruleVersion~=2 or type(data.runId)~="string"
        or data.legacyContinuation~=nil and type(data.legacyContinuation)~="boolean"
        or data.phase~="PLAYING" and data.phase~="PAUSED" or not integer(data.pieceSerial) or data.pieceSerial<1
        or not integer(data.lockResets) or data.lockResets>self.LOCK_RESET_LIMIT
        or not finite(data.gravityRemaining) or data.gravityRemaining<0 or data.gravityRemaining>b.interval+1e-8
        or not finite(data.elapsedSecs) or data.elapsedSecs<0
        or not finite(data.simRemainder) or data.simRemainder<0 or data.simRemainder>=1/120+1e-8
        or type(data.bag)~="table" or not integer(data.bagIndex) then return nil end
    if data.lockRemaining~=nil and (not finite(data.lockRemaining) or data.lockRemaining<0 or data.lockRemaining>self.LOCK_DELAY) then return nil end
    if #data.bag~=7 and not (data.legacyContinuation and #data.bag==0 and data.bagIndex==1) then return nil end
    local seen={} for i,v in pairs(data.bag) do
        if not integer(i) or i<1 or i>7 or not PIECES[v] or seen[v] then return nil end
        seen[v]=true
    end
    if data.bagIndex<1 or data.bagIndex>#data.bag+1 then return nil end
    for _,key in ipairs({"runId","pieceSerial","lockResets","lockRemaining","gravityRemaining","elapsedSecs","simRemainder","phase","legacyContinuation"}) do b[key]=data[key] end
    b.bag=self:Copy(data.bag); b.bagIndex=data.bagIndex
    return b
end
