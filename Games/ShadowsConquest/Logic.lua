-- Games/ShadowsConquest/Logic.lua

local Logic = {}
ArcadiaNexus.SC_Logic = Logic

-- ============================================================
-- DIFFICULTY-KONFIGURATION
-- ============================================================
Logic.DiffConfig = {
    easy   = { gridSize = 3, timerSec = 180, moveLimit = 15, baseFactor = 1.00, baseScore = 100 },
    normal = { gridSize = 5, timerSec = 300, moveLimit = 25, baseFactor = 1.25, baseScore = 125 },
    hard   = { gridSize = 7, timerSec = 480, moveLimit = 30, baseFactor = 2.00, baseScore = 200 },
}

Logic.TimerFactor  = { easy = 1.10, normal = 1.25, hard = 1.50 }
Logic.MoveFactor   = { easy = 1.15, normal = 1.25, hard = 1.40 }

-- ============================================================
-- GRID-OPERATIONEN
-- ============================================================

-- Tiefer Klon eines 2D-Grids
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

-- Toggled Zelle (r,c) und alle direkten Nachbarn (NSEW)
function Logic:Toggle(state, row, col)
    local targets = {
        { row,   col   },
        { row-1, col   },
        { row+1, col   },
        { row,   col-1 },
        { row,   col+1 },
    }
    for _, t in ipairs(targets) do
        local r, c = t[1], t[2]
        if r >= 1 and r <= state.gridSize and
           c >= 1 and c <= state.gridSize then
            state.grid[r][c] = state.grid[r][c] == 1 and 0 or 1
        end
    end
    state.moveCount = state.moveCount + 1
    if state.movesLeft then
        state.movesLeft = math.max(0, state.movesLeft - 1)
    end
end

-- Gewinn-Prüfung: alle Felder == 0
function Logic:IsWon(state)
    for r = 1, state.gridSize do
        for c = 1, state.gridSize do
            if state.grid[r][c] == 1 then return false end
        end
    end
    return true
end

-- Züge-Limit erschöpft?
function Logic:IsMoveLimitReached(state)
    return state.movesLeft ~= nil and state.movesLeft <= 0
end

-- ============================================================
-- PUZZLE-PARSER
-- ============================================================
function Logic:ParsePuzzle(entry)
    local grid = {}
    local row  = 1
    for line in (entry.map .. "|"):gmatch("([^|]*)|") do
        grid[row] = {}
        for col = 1, #line do
            grid[row][col] = tonumber(line:sub(col, col)) or 0
        end
        row = row + 1
    end
    return grid
end

-- ============================================================
-- NEUEN STATE INITIALISIEREN
-- ============================================================
function Logic:NewState(difficulty, puzzleEntry, timerActive, moveLimitActive)
    local cfg  = self.DiffConfig[difficulty]
    local grid = self:ParsePuzzle(puzzleEntry)
    return {
        difficulty      = difficulty,
        gridSize        = cfg.gridSize,
        grid            = grid,
        startGrid       = self:CloneGrid(grid),  -- für Reset
        moveCount       = 0,
        score           = 0,
        timerActive     = timerActive,
        timeLeft        = timerActive and cfg.timerSec or nil,
        moveLimitActive = moveLimitActive,
        movesLeft       = moveLimitActive and cfg.moveLimit or nil,
        puzzleOptimal   = puzzleEntry.optimalMoves,
    }
end

-- ============================================================
-- SCORE-BERECHNUNG
-- ============================================================
function Logic:CalcScore(state)
    local cfg  = self.DiffConfig[state.difficulty]
    local base = cfg.baseScore

    local timerMult = 1.0
    if state.timerActive then
        timerMult = self.TimerFactor[state.difficulty]
    end

    local moveMult = 1.0
    if state.moveLimitActive then
        moveMult = self.MoveFactor[state.difficulty]
    end

    local used     = state.moveCount or 0
    local optimal  = math.max(1, state.puzzleOptimal or 1)
    local moveRatio = 1
    if used > 0 then
        moveRatio = math.min(1, optimal / used)
    end

    local score = math.floor(base * timerMult * moveMult * moveRatio)

    -- Bonus: verbleibende Züge
    if state.moveLimitActive and state.movesLeft and state.movesLeft > 0 then
        score = score + state.movesLeft * 5
    end

    -- Bonus: verbleibende Sekunden
    if state.timerActive and state.timeLeft and state.timeLeft > 0 then
        score = score + state.timeLeft * 2
    end

    return math.max(1, score)
end
