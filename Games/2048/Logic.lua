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
    if direction ~= "LEFT" and direction ~= "RIGHT" and direction ~= "UP" and direction ~= "DOWN" then return false, 0 end
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

-- Complete move trace. Only Logic decides merges; renderer interpolates it.
function Logic:Move(board, direction)
    if direction ~= "LEFT" and direction ~= "RIGHT" and direction ~= "UP" and direction ~= "DOWN" then return false end
    local size, motions, gain, moved = board.size, {}, 0, false
    local function Position(line, index)
        if direction == "LEFT" then return line, index
        elseif direction == "RIGHT" then return line, size - index + 1
        elseif direction == "UP" then return index, line
        else return size - index + 1, line end
    end
    for r = 1, size do
        for c = 1, size do board.merged[r][c] = false end
    end
    for line = 1, size do
        local tiles = {}
        for index = 1, size do
            local r, c = Position(line, index)
            local value = board.cells[r][c]
            if value > 0 then tiles[#tiles + 1] = { row = r, col = c, value = value } end
            board.cells[r][c] = 0
        end
        local i, dest = 1, 1
        while i <= #tiles do
            local tile, nextTile = tiles[i], tiles[i + 1]
            local merge = nextTile and tile.value == nextTile.value
            local r, c = Position(line, dest)
            board.cells[r][c] = tile.value * (merge and 2 or 1)
            board.merged[r][c] = merge and true or false
            local function Record(source)
                motions[#motions + 1] = { fromRow = source.row, fromCol = source.col,
                    toRow = r, toCol = c, value = source.value, merged = merge and true or false }
                if source.row ~= r or source.col ~= c then moved = true end
            end
            Record(tile)
            if merge then Record(nextTile); gain, moved = gain + board.cells[r][c], true end
            i, dest = i + (merge and 2 or 1), dest + 1
        end
    end
    board.moved, board.score = moved, board.score + gain
    return moved, gain, motions
end

function Logic:GetDifficulty(size)
    return ({ [3] = "easy", [4] = "normal", [5] = "hard" })[size]
end

function Logic:HighestTile(board)
    local highest = 0
    for r = 1, board.size do
        for c = 1, board.size do highest = math.max(highest, board.cells[r][c]) end
    end
    return highest
end

function Logic:ValidateSave(save)
    if type(save) ~= "table" or save.saveVersion ~= 1 then return false end
    local size = save.boardSize
    if not self:GetDifficulty(size) or save.difficulty ~= self:GetDifficulty(size) then return false end
    if type(save.runId) ~= "string" or save.runId == "" then return false end
    if type(save.score) ~= "number" or save.score < 0 or save.score ~= math.floor(save.score) or save.score == math.huge then return false end
    if type(save.cells) ~= "table" or #save.cells ~= size then return false end
    for r = 1, size do
        if type(save.cells[r]) ~= "table" or #save.cells[r] ~= size then return false end
        for c = 1, size do
            local value = save.cells[r][c]
            if type(value) ~= "number" or value < 0 or value ~= math.floor(value) or value == math.huge then return false end
            if value > 0 then
                if value < 2 then return false end
                while value > 1 and value % 2 == 0 do value = value / 2 end
                if value ~= 1 then return false end
            end
        end
    end
    if save.phase ~= "ACTIVE" and save.phase ~= "AWAITING_WIN_CHOICE" and save.phase ~= "FINISHED" then return false end
    if save.resultPending ~= nil and type(save.resultPending) ~= "boolean" then return false end
    if save.resultPending and not save.reached2048 and save.phase ~= "FINISHED" then return false end
    local board = { size = size, cells = save.cells }
    if type(save.reached2048) ~= "boolean" or save.reached2048 ~= self:HasWon(board) then return false end
    if save.highestTile ~= self:HighestTile(board) then return false end
    if save.phase == "AWAITING_WIN_CHOICE" and (not save.reached2048 or not self:HasMoves(board)) then return false end
    if save.phase == "ACTIVE" and not self:HasMoves(board) then return false end
    if save.phase == "FINISHED" and not save.reached2048 and self:HasMoves(board) then return false end
    return true
end
