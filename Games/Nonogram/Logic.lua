-- Games/Nonogram/Logic.lua

local ArcadiaNexus = _G.ArcadiaNexus
local Logic = {}
ArcadiaNexus.NON_Logic = Logic

-- ============================================================
-- ZELL-ZUSTÄNDE
-- ============================================================
Logic.CELL_EMPTY  = 0
Logic.CELL_FILLED = 1
Logic.CELL_MARKED = 2

-- ============================================================
-- DIFFICULTY-KONFIGURATION
-- ============================================================
Logic.DiffConfig = {
    easy   = { gridSize = 5,  timerSec = 300,  errorLimit = 3, baseScoreFree = 100, baseScoreStrict = 150,  errorBonus = 25  },
    normal = { gridSize = 10, timerSec = 720,  errorLimit = 4, baseScoreFree = 250, baseScoreStrict = 375,  errorBonus = 50  },
    hard   = { gridSize = 15, timerSec = 1500, errorLimit = 5, baseScoreFree = 500, baseScoreStrict = 750,  errorBonus = 100 },
}

-- Zellgrößen je Schwierigkeit
Logic.CellSize = {
    easy   = 36,
    normal = 22,
    hard   = 16,
}

-- ============================================================
-- PUZZLE PARSEN
-- ============================================================
function Logic:ParsePuzzle(entry, size)
    local solution = {}
    local row = 1
    for line in (entry.map .. "|"):gmatch("([^|]*)%|") do
        if row <= size then
            solution[row] = {}
            for col = 1, size do
                solution[row][col] = tonumber(line:sub(col, col)) or 0
            end
            row = row + 1
        end
    end
    -- Fehlende Zeilen mit 0 auffüllen
    while row <= size do
        solution[row] = {}
        for col = 1, size do solution[row][col] = 0 end
        row = row + 1
    end
    local rowClues, colClues = Logic:CalcClues(solution, size)
    return solution, rowClues, colClues
end

-- ============================================================
-- CLUE-BERECHNUNG
-- ============================================================
function Logic:CalcClues(solution, size)
    local rowClues = {}
    local colClues = {}

    for r = 1, size do
        rowClues[r] = {}
        local count = 0
        for c = 1, size do
            if solution[r][c] == 1 then
                count = count + 1
            elseif count > 0 then
                table.insert(rowClues[r], count)
                count = 0
            end
        end
        if count > 0 then table.insert(rowClues[r], count) end
        if #rowClues[r] == 0 then rowClues[r] = {0} end
    end

    for c = 1, size do
        colClues[c] = {}
        local count = 0
        for r = 1, size do
            if solution[r][c] == 1 then
                count = count + 1
            elseif count > 0 then
                table.insert(colClues[c], count)
                count = 0
            end
        end
        if count > 0 then table.insert(colClues[c], count) end
        if #colClues[c] == 0 then colClues[c] = {0} end
    end

    return rowClues, colClues
end

-- ============================================================
-- INITIALER GRID-STATE
-- ============================================================
function Logic:CreateState(diff, mode, puzzleIndex, puzzleEntry)
    local cfg      = Logic.DiffConfig[diff]
    local size     = cfg.gridSize
    local solution, rowClues, colClues = Logic:ParsePuzzle(puzzleEntry, size)

    local grid = {}
    for r = 1, size do
        grid[r] = {}
        for c = 1, size do grid[r][c] = Logic.CELL_EMPTY end
    end

    return {
        difficulty   = diff,
        mode         = mode,           -- "free" | "strict"
        gridSize     = size,
        grid         = grid,
        solution     = solution,
        rowClues     = rowClues,
        colClues     = colClues,
        puzzleIndex  = puzzleIndex,
        puzzleName   = puzzleEntry.name or "",
        errors       = 0,
        errorLimit   = cfg.errorLimit,
        timeLeft     = cfg.timerSec,
        timerActive  = true,
        inputMode    = "fill",          -- "fill" | "mark"
        cursorR      = 1,
        cursorC      = 1,
        finalScore   = 0,
        won          = false,
    }
end

-- ============================================================
-- ZELL-INTERAKTION
-- ============================================================
-- Gibt zurück: "ok" | "error" | "gameover" | "already_filled"
function Logic:HandleClick(state, row, col, action)
    if state.won then return "ok" end
    local cell = state.grid[row][col]

    if action == "FILL" then
        if cell == Logic.CELL_FILLED then
            state.grid[row][col] = Logic.CELL_EMPTY
            return "ok"
        elseif cell == Logic.CELL_EMPTY then
            -- Strenger Modus: Fehler bei falschem Füllen
            if state.mode == "strict" and state.solution[row][col] == 0 then
                state.errors = state.errors + 1
                if state.errors >= state.errorLimit then
                    return "gameover"
                end
                return "error"
            end
            state.grid[row][col] = Logic.CELL_FILLED
            return "ok"
        elseif cell == Logic.CELL_MARKED then
            -- MARKED → FILLED (kein Fehler, da Spieler entscheidet)
            if state.mode == "strict" and state.solution[row][col] == 0 then
                state.errors = state.errors + 1
                if state.errors >= state.errorLimit then
                    return "gameover"
                end
                return "error"
            end
            state.grid[row][col] = Logic.CELL_FILLED
            return "ok"
        end
    elseif action == "MARK" then
        -- Markieren zählt NIE als Fehler
        if cell == Logic.CELL_EMPTY then
            state.grid[row][col] = Logic.CELL_MARKED
        elseif cell == Logic.CELL_MARKED then
            state.grid[row][col] = Logic.CELL_EMPTY
        elseif cell == Logic.CELL_FILLED then
            state.grid[row][col] = Logic.CELL_MARKED
        end
        return "ok"
    end

    return "ok"
end

-- ============================================================
-- GEWINN-PRÜFUNG
-- ============================================================
function Logic:CheckWin(state)
    for r = 1, state.gridSize do
        for c = 1, state.gridSize do
            if state.solution[r][c] == 1 and state.grid[r][c] ~= Logic.CELL_FILLED then
                return false
            end
        end
    end
    return true
end

-- ============================================================
-- CURSOR-NAVIGATION
-- ============================================================
function Logic:MoveCursor(state, dr, dc)
    local r = math.max(1, math.min(state.gridSize, state.cursorR + dr))
    local c = math.max(1, math.min(state.gridSize, state.cursorC + dc))
    state.cursorR = r
    state.cursorC = c
end

function Logic:ToggleInputMode(state)
    if state.inputMode == "fill" then
        state.inputMode = "mark"
    else
        state.inputMode = "fill"
    end
end

-- ============================================================
-- CLUE-HIGHLIGHTING: Zeile/Spalte vollständig gelöst?
-- ============================================================
-- Gibt zurück: rowSolved[r] = true/false, colSolved[c] = true/false
function Logic:CalcSolved(state)
    local rowSolved = {}
    local colSolved = {}

    for r = 1, state.gridSize do
        local ok = true
        for c = 1, state.gridSize do
            if state.solution[r][c] == 1 and state.grid[r][c] ~= Logic.CELL_FILLED then
                ok = false; break
            end
            -- Keine Extrastrafe für FILLED an leerer Lösungsposition (freies Spiel)
        end
        -- Außerdem: keine überschüssigen FILLED-Zellen (nur relevante Clue-Prüfung)
        rowSolved[r] = ok and Logic:_RowMatchesClue(state, r)
    end

    for c = 1, state.gridSize do
        colSolved[c] = Logic:_ColMatchesClue(state, c)
    end

    return rowSolved, colSolved
end

function Logic:_RowMatchesClue(state, r)
    local groups = {}
    local count = 0
    for c = 1, state.gridSize do
        if state.grid[r][c] == Logic.CELL_FILLED then
            count = count + 1
        elseif count > 0 then
            table.insert(groups, count); count = 0
        end
    end
    if count > 0 then table.insert(groups, count) end
    if #groups == 0 then groups = {0} end
    local clue = state.rowClues[r]
    if #groups ~= #clue then return false end
    for i = 1, #clue do
        if groups[i] ~= clue[i] then return false end
    end
    return true
end

function Logic:_ColMatchesClue(state, c)
    local groups = {}
    local count = 0
    for r = 1, state.gridSize do
        if state.grid[r][c] == Logic.CELL_FILLED then
            count = count + 1
        elseif count > 0 then
            table.insert(groups, count); count = 0
        end
    end
    if count > 0 then table.insert(groups, count) end
    if #groups == 0 then groups = {0} end
    local clue = state.colClues[c]
    if #groups ~= #clue then return false end
    for i = 1, #clue do
        if groups[i] ~= clue[i] then return false end
    end
    return true
end

-- ============================================================
-- SCORE-BERECHNUNG
-- ============================================================
function Logic:CalcScore(state)
    local cfg = Logic.DiffConfig[state.difficulty]
    local score = 0

    if state.mode == "free" then
        score = cfg.baseScoreFree + (state.timeLeft * 2)
    else
        local unusedErrors = math.max(0, cfg.errorLimit - state.errors)
        score = cfg.baseScoreStrict + (unusedErrors * cfg.errorBonus)
    end

    return math.max(0, score)
end

-- ============================================================
-- GRID KLONEN (für SaveAndPause)
-- ============================================================
function Logic:CloneGrid(grid)
    local clone = {}
    for r, row in ipairs(grid) do
        clone[r] = {}
        for c, val in ipairs(row) do
            clone[r][c] = val
        end
    end
    return clone
end
