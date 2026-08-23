--[[
    Gaming Hub
    Games/2048/Logic.lua
    Version: 1.0.0

    Reines Spiellogik-Modul – kein UI, kein State außer dem Board.

    Board-Struktur:
      board.size        – Breite/Höhe (default 4)
      board.cells[row][col] – Wert (0 = leer, 2/4/8/…)
      board.score       – aktueller Spielstand
      board.moved       – true wenn letzter Zug das Board verändert hat
      board.merged[row][col] – true wenn diese Zelle in diesem Zug gemerged wurde
                               (für Merge-Animation im Renderer)

    Richtungen: "UP" | "DOWN" | "LEFT" | "RIGHT"

    Öffentliche API:
      Logic:CreateBoard(size)          → board
      Logic:CloneBoard(board)          → board
      Logic:SpawnTile(board)           → row, col, value  (oder nil wenn voll)
      Logic:Slide(board, direction)    → moved (bool), scoreGained
      Logic:HasMoves(board)            → bool
      Logic:HasWon(board)              → bool (irgendeine Zelle == 2048)
      Logic:IsFull(board)              → bool
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TDG_Logic = {}
local Logic = ArcadiaNexus.TDG_Logic

-- ============================================================
-- CreateBoard
-- ============================================================

function Logic:CreateBoard(size)
    size = size or 4
    local board = {
        size   = size,
        cells  = {},
        merged = {},
        score  = 0,
        moved  = false,
    }
    for r = 1, size do
        board.cells[r]  = {}
        board.merged[r] = {}
        for c = 1, size do
            board.cells[r][c]  = 0
            board.merged[r][c] = false
        end
    end
    return board
end

-- ============================================================
-- CloneBoard
-- ============================================================

function Logic:CloneBoard(board)
    local clone = {
        size   = board.size,
        score  = board.score,
        moved  = board.moved,
        cells  = {},
        merged = {},
    }
    for r = 1, board.size do
        clone.cells[r]  = {}
        clone.merged[r] = {}
        for c = 1, board.size do
            clone.cells[r][c]  = board.cells[r][c]
            clone.merged[r][c] = board.merged[r][c]
        end
    end
    return clone
end

-- ============================================================
-- SpawnTile
-- Platziert eine neue Kachel (90% = 2, 10% = 4) auf einer
-- zufälligen leeren Zelle.
-- Gibt row, col, value zurück oder nil wenn kein Platz.
-- ============================================================

function Logic:SpawnTile(board)
    local empty = {}
    for r = 1, board.size do
        for c = 1, board.size do
            if board.cells[r][c] == 0 then
                table.insert(empty, {r = r, c = c})
            end
        end
    end
    if #empty == 0 then return nil end

    local pick  = empty[math.random(1, #empty)]
    local value = (math.random() < 0.9) and 2 or 4

    board.cells[pick.r][pick.c] = value
    return pick.r, pick.c, value
end

-- ============================================================
-- INTERNE: Zeile nach links schieben und mergen
-- Gibt neue Zeile + gewonnene Punkte zurück.
-- ============================================================

local function SlideRowLeft(row, size, merged)
    -- 1. Nullen rausfiltern
    local tiles = {}
    for c = 1, size do
        if row[c] ~= 0 then
            table.insert(tiles, {val = row[c], srcCol = c})
        end
    end

    -- 2. Mergen
    local newRow   = {}
    local newMerge = {}
    local score    = 0
    local i = 1

    while i <= #tiles do
        if i + 1 <= #tiles and tiles[i].val == tiles[i+1].val
            and not merged[tiles[i].srcCol] and not merged[tiles[i+1].srcCol] then
            -- Merge
            local val = tiles[i].val * 2
            table.insert(newRow,   val)
            table.insert(newMerge, true)
            score = score + val
            i = i + 2
        else
            table.insert(newRow,   tiles[i].val)
            table.insert(newMerge, false)
            i = i + 1
        end
    end

    -- 3. Auffüllen
    while #newRow < size do
        table.insert(newRow,   0)
        table.insert(newMerge, false)
    end

    return newRow, newMerge, score
end

-- ============================================================
-- Slide
-- Schiebt das gesamte Board in eine Richtung.
-- Setzt board.moved und board.merged.
-- Gibt zusätzlich scoreGained zurück.
-- ============================================================

function Logic:Slide(board, direction)
    local size  = board.size
    local total = 0
    local moved = false

    -- Reset merged-flags
    for r = 1, size do
        for c = 1, size do
            board.merged[r][c] = false
        end
    end

    -- Rotations-Hilfsfunktion: wir rotieren das Board immer so,
    -- dass wir nur SlideRowLeft brauchen.
    -- "LEFT"  → kein Rotate
    -- "RIGHT" → Board horizontal spiegeln, slide, zurückspiegeln
    -- "UP"    → Board transponieren, slide, zurücktransponieren
    -- "DOWN"  → Board transponieren + spiegeln, slide, zurück

    -- Extrahiere Zeilen gemäß Richtung
    local function getRow(r)
        local row    = {}
        local mergeR = {}
        if direction == "LEFT" then
            for c = 1, size do row[c] = board.cells[r][c]; mergeR[c] = board.merged[r][c] end
        elseif direction == "RIGHT" then
            for c = 1, size do row[c] = board.cells[r][size-c+1]; mergeR[c] = board.merged[r][size-c+1] end
        elseif direction == "UP" then
            for c = 1, size do row[c] = board.cells[c][r]; mergeR[c] = board.merged[c][r] end
        elseif direction == "DOWN" then
            for c = 1, size do row[c] = board.cells[size-c+1][r]; mergeR[c] = board.merged[size-c+1][r] end
        end
        return row, mergeR
    end

    local function setRow(r, newRow, newMerge)
        if direction == "LEFT" then
            for c = 1, size do board.cells[r][c] = newRow[c]; board.merged[r][c] = newMerge[c] end
        elseif direction == "RIGHT" then
            for c = 1, size do board.cells[r][size-c+1] = newRow[c]; board.merged[r][size-c+1] = newMerge[c] end
        elseif direction == "UP" then
            for c = 1, size do board.cells[c][r] = newRow[c]; board.merged[c][r] = newMerge[c] end
        elseif direction == "DOWN" then
            for c = 1, size do board.cells[size-c+1][r] = newRow[c]; board.merged[size-c+1][r] = newMerge[c] end
        end
    end

    for r = 1, size do
        local row, mergeR = getRow(r)

        -- Kopie zum Vergleich
        local before = {}
        for c = 1, size do before[c] = row[c] end

        local newRow, newMerge, gain = SlideRowLeft(row, size, mergeR)
        total = total + gain

        -- Bewegt sich etwas?
        for c = 1, size do
            if newRow[c] ~= before[c] then
                moved = true
                break
            end
        end

        setRow(r, newRow, newMerge)
    end

    board.moved  = moved
    board.score  = board.score + total
    return moved, total
end

-- ============================================================
-- HasMoves
-- Gibt true zurück wenn noch mindestens ein Zug möglich ist.
-- ============================================================

function Logic:HasMoves(board)
    local size = board.size
    -- Leere Zelle vorhanden?
    for r = 1, size do
        for c = 1, size do
            if board.cells[r][c] == 0 then return true end
        end
    end
    -- Benachbarte gleiche Werte?
    for r = 1, size do
        for c = 1, size do
            local v = board.cells[r][c]
            if c < size and board.cells[r][c+1] == v then return true end
            if r < size and board.cells[r+1][c] == v then return true end
        end
    end
    return false
end

-- ============================================================
-- HasWon
-- ============================================================

function Logic:HasWon(board)
    for r = 1, board.size do
        for c = 1, board.size do
            if (board.cells[r] and board.cells[r][c] or 0) >= 2048 then
                return true
            end
        end
    end
    return false
end

-- ============================================================
-- IsFull
-- ============================================================

function Logic:IsFull(board)
    for r = 1, board.size do
        for c = 1, board.size do
            if board.cells[r][c] == 0 then return false end
        end
    end
    return true
end
