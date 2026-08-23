-- ============================================================
--  SlidingPuzzle – Logic.lua
--  Board-State, Shuffle, Zug-Validierung, Gewinn-Check.
--
--  board[i] = tileID an Position i (0 = leeres Feld)
--  Zielzustand: board[i] == i für i=1..n-1, board[n] == 0
--  Positionen sind 1-basiert, von links-oben nach rechts-unten.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SLP_Logic = {}
local L = ArcadiaNexus.SLP_Logic

-- ── State ─────────────────────────────────────────────────────
L.board    = {}
L.emptyPos = 0
L.cols     = 3
L.moves    = 0
L.solved   = false

-- ── Hilfsfunktionen ───────────────────────────────────────────

-- Gibt Zeile und Spalte (1-basiert) einer Position zurück
local function RowCol(pos, cols)
    local row = math.ceil(pos / cols)
    local col = ((pos - 1) % cols) + 1
    return row, col
end

-- ── Board initialisieren ──────────────────────────────────────

function L:Init(cols)
    self.cols   = cols
    self.moves  = 0
    self.solved = false
    local n = cols * cols
    self.board = {}
    for i = 1, n - 1 do
        self.board[i] = i
    end
    self.board[n] = 0
    self.emptyPos = n
end

-- ── Shuffle (N gültige Züge vom Zielzustand rückwärts) ───────

function L:Shuffle(numMoves)
    -- Verhindert Hin-und-Her-Ping-Pong: letzten Zug merken
    local lastMoved = -1
    for _ = 1, numMoves do
        local neighbors = self:GetValidMoves()
        -- Ping-Pong-Schutz: Letzte Position herausfiltern
        local filtered = {}
        for _, pos in ipairs(neighbors) do
            if pos ~= lastMoved then
                filtered[#filtered + 1] = pos
            end
        end
        if #filtered == 0 then filtered = neighbors end
        local pick = filtered[math.random(1, #filtered)]
        lastMoved = self.emptyPos
        self:ExecuteMove(pick)
    end
    self.moves = 0   -- Züge nach Shuffle zurücksetzen
end

-- ── Shuffle mit Zugliste (für Shuffle-Animation) ──────────────
-- Führt numMoves gültige Züge durch und gibt eine Liste von
-- { tilePos, emptyPos } zurück — tilePos = gezogene Kachel,
-- emptyPos = Position des leeren Feldes VOR dem Zug (= Ziel).
-- Das Board wird dabei in-place verändert (identisch zu Shuffle).
-- Aufruf: nach Init(), vor BuildGrid().

function L:ShuffleWithHistory(numMoves)
    local history   = {}
    local lastMoved = -1
    for _ = 1, numMoves do
        local neighbors = self:GetValidMoves()
        local filtered  = {}
        for _, pos in ipairs(neighbors) do
            if pos ~= lastMoved then
                filtered[#filtered + 1] = pos
            end
        end
        if #filtered == 0 then filtered = neighbors end
        local pick     = filtered[math.random(1, #filtered)]
        local fromEmpty = self.emptyPos   -- leeres Feld VOR Zug = Ziel der Kachel
        lastMoved      = self.emptyPos
        self:ExecuteMove(pick)
        history[#history + 1] = { tilePos = pick, emptyPos = fromEmpty }
    end
    self.moves = 0
    return history
end

-- ── Gültige Züge (Positionen die ans leere Feld angrenzen) ───

function L:GetValidMoves()
    local eRow, eCol = RowCol(self.emptyPos, self.cols)
    local result = {}
    local deltas = { {0,1}, {0,-1}, {1,0}, {-1,0} }
    for _, d in ipairs(deltas) do
        local nr = eRow + d[1]
        local nc = eCol + d[2]
        if nr >= 1 and nr <= self.cols and nc >= 1 and nc <= self.cols then
            result[#result + 1] = (nr - 1) * self.cols + nc
        end
    end
    return result
end

-- ── Zug-Validierung ───────────────────────────────────────────

function L:CanMove(tilePos)
    local eRow, eCol = RowCol(self.emptyPos, self.cols)
    local tRow, tCol = RowCol(tilePos,       self.cols)
    return (eRow == tRow and math.abs(eCol - tCol) == 1)
        or (eCol == tCol and math.abs(eRow - tRow) == 1)
end

-- ── Zug ausführen ─────────────────────────────────────────────

function L:ExecuteMove(tilePos)
    if not self:CanMove(tilePos) then return false end
    self.board[self.emptyPos] = self.board[tilePos]
    self.board[tilePos]       = 0
    self.emptyPos             = tilePos
    self.moves                = self.moves + 1
    return true
end

-- ── Gewinn-Check ──────────────────────────────────────────────

function L:IsSolved()
    local n = self.cols * self.cols
    for i = 1, n do
        local expected = (i == n) and 0 or i
        if self.board[i] ~= expected then return false end
    end
    return true
end

-- ── UV-Koordinaten für eine Kachel ───────────────────────────
-- tileID: 1-basiert, von links-oben nach rechts-unten.
-- SetTexCoord(left, right, top, bottom) — WoW 4-Parameter-Form

function L:GetTexCoord(tileID, cols)
    local col = (tileID - 1) % cols
    local row = math.floor((tileID - 1) / cols)
    local l = col / cols
    local r = (col + 1) / cols
    local t = row / cols
    local b = (row + 1) / cols
    return l, r, t, b
end
