--[[
    Gaming Hub
    Games/ArcadiaRows/Logic.lua
    Version: 1.0.0

    Unterschiede zu TicTacToe/Logic.lua:
      - Brett ist NICHT quadratisch: cols × rows (z.B. 7×6)
      - ApplyMove() erhält nur eine Spalte (col).
        Der Stein fällt durch Schwerkraft zur untersten freien Zeile.
      - CheckWin() prüft immer auf genau 4 in einer Reihe (winLength = 4).
      - GetLowestRow() gibt die Zielzeile für eine Spalte zurück.
      - IsBoardFull() für Unentschieden-Erkennung.

    Board-Struktur:
      board.cols     – Anzahl Spalten
      board.rows     – Anzahl Zeilen
      board.winLength – immer 4
      board.cells[row][col] – 0 = leer, 1 = Spieler 1, 2 = Spieler 2
      Zeile 1 = OBEN, Zeile board.rows = UNTEN (Schwerkraft-Logik)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Logic = {}

local Logic = ArcadiaNexus.AR_Logic

-- ============================================================
-- CreateBoard
-- cols: Spalten (x-Achse), rows: Zeilen (y-Achse)
-- winLength: immer 4 für Vier Gewinnt
-- ============================================================

function Logic:CreateBoard(cols, rows)
    local board = {
        cols      = cols,
        rows      = rows,
        winLength = 4,
        cells     = {},
    }

    for row = 1, rows do
        board.cells[row] = {}
        for col = 1, cols do
            board.cells[row][col] = 0
        end
    end

    return board
end

-- ============================================================
-- GetLowestRow
-- Gibt die unterste freie Zeile in einer Spalte zurück.
-- Rückgabe nil wenn Spalte voll ist.
-- ============================================================

function Logic:GetLowestRow(board, col)
    for row = board.rows, 1, -1 do
        if board.cells[row][col] == 0 then
            return row
        end
    end
    return nil  -- Spalte voll
end

-- ============================================================
-- IsColumnFull
-- ============================================================

function Logic:IsColumnFull(board, col)
    return board.cells[1][col] ~= 0
end

-- ============================================================
-- GetAvailableColumns
-- Gibt alle Spalten zurück die noch mindestens eine freie Zeile haben.
-- ============================================================

function Logic:GetAvailableColumns(board)
    local cols = {}
    for col = 1, board.cols do
        if not self:IsColumnFull(board, col) then
            table.insert(cols, col)
        end
    end
    return cols
end

-- ============================================================
-- ApplyMove
-- col: Zielspalte (1-basiert)
-- player: 1 oder 2
-- Rückgabe: die Zeile in die der Stein gefallen ist, oder nil wenn voll.
-- ============================================================

function Logic:ApplyMove(board, col, player)
    local row = self:GetLowestRow(board, col)
    if not row then return nil end

    board.cells[row][col] = player
    return row
end

-- ============================================================
-- IsBoardFull
-- ============================================================

function Logic:IsBoardFull(board)
    return #self:GetAvailableColumns(board) == 0
end

-- ============================================================
-- CheckWin
-- Prüft ob player nach dem Zug in Spalte col / Zeile row gewonnen hat.
-- Gibt "WIN" + winningLine oder nil zurück.
-- ============================================================

local function countDir(board, col, row, dc, dr, player)
    local count = 0
    local c = col + dc
    local r = row + dr

    while c >= 1 and c <= board.cols
      and r >= 1 and r <= board.rows
      and board.cells[r][c] == player do
        count = count + 1
        c = c + dc
        r = r + dr
    end

    return count
end

function Logic:GetWinningLine(board, col, row, dc, dr, player)
    -- Anfang der Linie rückwärts finden
    local startCol = col
    local startRow = row

    while startCol - dc >= 1 and startCol - dc <= board.cols
      and startRow - dr >= 1 and startRow - dr <= board.rows
      and board.cells[startRow - dr][startCol - dc] == player do
        startCol = startCol - dc
        startRow = startRow - dr
    end

    -- Linie vorwärts sammeln
    local line = {}
    local c = startCol
    local r = startRow

    while c >= 1 and c <= board.cols
      and r >= 1 and r <= board.rows
      and board.cells[r][c] == player do
        table.insert(line, { col = c, row = r })
        c = c + dc
        r = r + dr
    end

    return line
end

function Logic:CheckWin(board, col, row, player)
    -- Vier Richtungspaare (jede Achse einmal)
    local directions = {
        { 1,  0 },  -- horizontal →
        { 0,  1 },  -- vertikal ↓
        { 1,  1 },  -- diagonal ↘
        { 1, -1 },  -- diagonal ↗
    }

    for _, dir in ipairs(directions) do
        local dc = dir[1]
        local dr = dir[2]

        -- Zähle in beide Richtungen auf dieser Achse
        local count = 1
            + countDir(board, col, row,  dc,  dr, player)
            + countDir(board, col, row, -dc, -dr, player)

        if count >= board.winLength then
            return "WIN", self:GetWinningLine(board, col, row, dc, dr, player)
        end
    end

    return nil
end

-- ============================================================
-- CloneBoard (Deep Copy)
-- ============================================================

function Logic:CloneBoard(board)
    local clone = {
        cols      = board.cols,
        rows      = board.rows,
        winLength = board.winLength,
        cells     = {},
    }

    for row = 1, board.rows do
        clone.cells[row] = {}
        for col = 1, board.cols do
            clone.cells[row][col] = board.cells[row][col]
        end
    end

    return clone
end
