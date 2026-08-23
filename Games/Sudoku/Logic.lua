--[[
    Gaming Hub
    Games/Sudoku/Logic.lua
    Version: 1.0.0

    Reine Spiellogik – kein UI, keine Events.

    Grid-Konvention:
      grid[r][c]  – Zahl 1-9, oder 0 = leer
      fixed[r][c] – true = vom System vorgegeben (nicht änderbar)
      errors[r][c]– true = Spieler-Eintrag ist ungültig

    Schwierigkeit (Anzahl vorgegebene Felder):
      easy   → 45-50 Clues (~36-31 leer)
      normal → 36-44 Clues (~45-37 leer)
      hard   → 26-35 Clues (~55-46 leer)

    Öffentliche API:
      Logic:NewGrid()                        → leeres 9×9-Grid
      Logic:GeneratePuzzle(difficulty)       → { grid, fixed, solution }
      Logic:IsValidMove(grid, r, c, num)     → bool, reason
      Logic:IsBoardComplete(grid, fixed)     → bool
      Logic:GetHighlightCells(grid, num)     → { {r,c}, ... }
      Logic:GetBoxIndex(r, c)                → 1-9 (welcher 3×3 Block)
      Logic:ValidateAll(grid, fixed)         → errors[r][c] table
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Logic = {}
local Logic = ArcadiaNexus.SDK_Logic

-- ============================================================
-- Clue-Anzahl nach Schwierigkeit
-- ============================================================
local CLUES = {
    easy   = 46,
    normal = 38,
    hard   = 28,
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function newGrid()
    local g = {}
    for r = 1, 9 do
        g[r] = {}
        for c = 1, 9 do g[r][c] = 0 end
    end
    return g
end

local function copyGrid(g)
    local n = {}
    for r = 1, 9 do
        n[r] = {}
        for c = 1, 9 do n[r][c] = g[r][c] end
    end
    return n
end

-- Schachbrett-Shuffle für Fisher-Yates
local function shuffle(t)
    return ArcadiaNexus.ArrayUtils.Shuffle(t)
end

-- ============================================================
-- Sudoku-Solver (Backtracking)
-- Gibt true zurück wenn eine Lösung gefunden wurde.
-- Füllt `grid` in-place.
-- maxSolutions: abbrechenn wenn mehr als N Lösungen existieren
-- ============================================================

local function isValidCell(grid, r, c, num)
    -- Zeile
    for cc = 1, 9 do
        if cc ~= c and grid[r][cc] == num then return false end
    end
    -- Spalte
    for rr = 1, 9 do
        if rr ~= r and grid[rr][c] == num then return false end
    end
    -- 3×3 Block
    local br = math.floor((r-1)/3)*3 + 1
    local bc = math.floor((c-1)/3)*3 + 1
    for dr = 0, 2 do
        for dc = 0, 2 do
            local rr, cc = br+dr, bc+dc
            if (rr ~= r or cc ~= c) and grid[rr][cc] == num then
                return false
            end
        end
    end
    return true
end

local function solve(grid, countRef, maxSolutions)
    -- Leere Zelle finden
    local bestR, bestC, bestCandidates = nil, nil, nil
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == 0 then
                -- MRV-Heuristik: Zelle mit wenigsten Kandidaten zuerst
                local cands = {}
                for n = 1, 9 do
                    if isValidCell(grid, r, c, n) then
                        cands[#cands+1] = n
                    end
                end
                if #cands == 0 then return end  -- Sackgasse
                if bestCandidates == nil or #cands < #bestCandidates then
                    bestR, bestC, bestCandidates = r, c, cands
                end
            end
        end
    end

    if bestR == nil then
        -- Alle Felder gefüllt → Lösung gefunden
        countRef[1] = countRef[1] + 1
        return countRef[1] >= maxSolutions
    end

    shuffle(bestCandidates)
    for _, num in ipairs(bestCandidates) do
        grid[bestR][bestC] = num
        if solve(grid, countRef, maxSolutions) then
            return true
        end
        grid[bestR][bestC] = 0
    end
end

-- ============================================================
-- Puzzle-Generierung
-- 1. Komplett gefülltes valides Grid erzeugen (Lösung)
-- 2. Felder entfernen bis Clue-Anzahl erreicht, dabei
--    Eindeutigkeit der Lösung sicherstellen
-- ============================================================

function Logic:GeneratePuzzle(difficulty)
    difficulty = difficulty or "normal"
    local targetClues = CLUES[difficulty] or CLUES.normal

    -- Schritt 1: Vollständiges Grid generieren
    local solution = newGrid()
    local countRef = {0}
    solve(solution, countRef, 1)

    -- Schritt 2: Felder zufällig entfernen
    local puzzle = copyGrid(solution)
    local fixed  = {}
    for r = 1, 9 do
        fixed[r] = {}
        for c = 1, 9 do fixed[r][c] = true end
    end

    -- Alle Positionen shufflen
    local positions = {}
    for r = 1, 9 do
        for c = 1, 9 do positions[#positions+1] = {r, c} end
    end
    shuffle(positions)

    local cluesLeft = 81
    for _, pos in ipairs(positions) do
        if cluesLeft <= targetClues then break end

        local r, c   = pos[1], pos[2]
        local backup = puzzle[r][c]
        puzzle[r][c] = 0

        -- Eindeutigkeit prüfen (max 1 Lösung erlaubt)
        local test     = copyGrid(puzzle)
        local cntRef   = {0}
        solve(test, cntRef, 2)

        if cntRef[1] == 1 then
            fixed[r][c] = false
            cluesLeft   = cluesLeft - 1
        else
            puzzle[r][c] = backup  -- Rückgängig
        end
    end

    return {
        grid     = puzzle,
        fixed    = fixed,
        solution = solution,
    }
end

-- ============================================================
-- NewGrid – leeres 9×9-Grid
-- ============================================================

function Logic:NewGrid()
    return newGrid()
end

-- ============================================================
-- GetBoxIndex – welcher 3×3-Block (1-9, zeilenweise)
-- ============================================================

function Logic:GetBoxIndex(r, c)
    local br = math.floor((r-1)/3)
    local bc = math.floor((c-1)/3)
    return br * 3 + bc + 1
end

-- ============================================================
-- IsValidMove
-- Prüft ob `num` an (r,c) regelkonform ist.
-- Gibt zurück: valid(bool), reason(string)
-- ============================================================

function Logic:IsValidMove(grid, r, c, num)
    if num == 0 then return true, "empty" end

    -- Zeile
    for cc = 1, 9 do
        if cc ~= c and grid[r][cc] == num then
            return false, "row"
        end
    end
    -- Spalte
    for rr = 1, 9 do
        if rr ~= r and grid[rr][c] == num then
            return false, "col"
        end
    end
    -- 3×3 Block
    local br = math.floor((r-1)/3)*3 + 1
    local bc = math.floor((c-1)/3)*3 + 1
    for dr = 0, 2 do
        for dc = 0, 2 do
            local rr, cc = br+dr, bc+dc
            if (rr ~= r or cc ~= c) and grid[rr][cc] == num then
                return false, "box"
            end
        end
    end
    return true, "ok"
end

-- ============================================================
-- ValidateAll
-- Gibt errors[r][c] = true für alle ungültigen Spieler-Einträge
-- ============================================================

function Logic:ValidateAll(grid, fixed)
    local errors = {}
    for r = 1, 9 do
        errors[r] = {}
        for c = 1, 9 do errors[r][c] = false end
    end

    for r = 1, 9 do
        for c = 1, 9 do
            if not fixed[r][c] and grid[r][c] ~= 0 then
                local valid = self:IsValidMove(grid, r, c, grid[r][c])
                if not valid then
                    errors[r][c] = true
                end
            end
        end
    end
    return errors
end

-- ============================================================
-- IsBoardComplete
-- Alle Felder gefüllt und keine Fehler
-- ============================================================

function Logic:IsBoardComplete(grid, fixed)
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == 0 then return false end
            if not fixed[r][c] then
                local valid = self:IsValidMove(grid, r, c, grid[r][c])
                if not valid then return false end
            end
        end
    end
    return true
end

-- ============================================================
-- GetHighlightCells
-- Gibt alle Zellen zurück die dieselbe Zahl `num` haben
-- ============================================================

function Logic:GetHighlightCells(grid, num)
    local cells = {}
    if num == 0 then return cells end
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == num then
                cells[#cells+1] = { r = r, c = c }
            end
        end
    end
    return cells
end

-- ============================================================
-- GetCandidates
-- Gibt alle gültigen Zahlen für eine Zelle zurück (für Hint)
-- ============================================================

function Logic:GetCandidates(grid, r, c)
    if grid[r][c] ~= 0 then return {} end
    local cands = {}
    for n = 1, 9 do
        if isValidCell(grid, r, c, n) then
            cands[#cands+1] = n
        end
    end
    return cands
end
