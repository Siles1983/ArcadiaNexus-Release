-- ============================================================
--  Match3 – Logic.lua
--  Spielregeln und State. KEIN UI, KEINE WoW-API.
--
--  Begriffe:
--    grid[row][col]  – logisches Spielfeld (1-basiert, row=1 oben)
--    gemType         – Integer 1..N (Index in Themes-Tabelle)
--    0               – leere Zelle (während Entfernung)
-- ============================================================

ArcadiaNexus.M3_Logic = {}
local L = ArcadiaNexus.M3_Logic

-- ── Schwierigkeits-Definitionen ────────────────────────────────
L.DIFFICULTY_DEFS = {
    easy   = { cols = 8,  rows = 8,  moves = 20, timerSecs = 600 },
    normal = { cols = 10, rows = 10, moves = 15, timerSecs = 450 },
    hard   = { cols = 12, rows = 12, moves = 10, timerSecs = 300 },
}

-- ── State ──────────────────────────────────────────────────────
-- L.state wird von der Engine gehalten, hier nur Initialisierung
function L:NewState(difficulty)
    local def = self.DIFFICULTY_DEFS[difficulty] or self.DIFFICULTY_DEFS.easy
    return {
        difficulty  = difficulty,
        cols        = def.cols,
        rows        = def.rows,
        movesLeft   = def.moves,
        timerSecs   = def.timerSecs,
        timeLeft    = def.timerSecs,
        score       = 0,
        comboCount  = 0,
        gemCount    = 0,   -- wird von Renderer / Themes befüllt
        grid        = {},
        gameOver    = false,
        won         = false,
        timedOut    = false,
    }
end

-- ── Grid Initialisierung ───────────────────────────────────────
-- gemCount muss gesetzt sein bevor InitGrid aufgerufen wird.
-- Garantiert: keine initialen 3er-Ketten UND mindestens ein gültiger Zug.
function L:InitGrid(state)
    local maxAttempts = 20
    local attempt = 0
    repeat
        attempt = attempt + 1
        self:_GenerateGrid(state)
    until self:HasPossibleMoves(state) or attempt >= maxAttempts
end

-- Interne Hilfsfunktion: generiert Grid ohne initiale 3er-Ketten
function L:_GenerateGrid(state)
    local cols, rows, n = state.cols, state.rows, state.gemCount
    if n < 3 then n = 3 end
    state.grid = {}
    for r = 1, rows do
        state.grid[r] = {}
        for c = 1, cols do
            local validGems = {}
            for i = 1, n do
                local ok = true
                if c >= 3 and state.grid[r][c-1] == i and state.grid[r][c-2] == i then
                    ok = false
                end
                if ok and r >= 3 and state.grid[r-1] and state.grid[r-1][c] == i
                       and state.grid[r-2] and state.grid[r-2][c] == i then
                    ok = false
                end
                if ok then validGems[#validGems+1] = i end
            end
            if #validGems > 0 then
                state.grid[r][c] = validGems[math.random(#validGems)]
            else
                state.grid[r][c] = math.random(1, n)
            end
        end
    end
end

-- Prüft ob mindestens ein gültiger Swap-Move existiert.
-- Verhindert Softlock am Start und nach Kaskaden.
function L:HasPossibleMoves(state)
    local grid = state.grid
    local rows = state.rows
    local cols = state.cols

    for r = 1, rows do
        for c = 1, cols do
            -- Swap rechts prüfen
            if c < cols then
                grid[r][c], grid[r][c+1] = grid[r][c+1], grid[r][c]
                local matches = self:FindMatches(state)
                grid[r][c], grid[r][c+1] = grid[r][c+1], grid[r][c]
                if next(matches) then return true end
            end
            -- Swap nach unten prüfen
            if r < rows then
                grid[r][c], grid[r+1][c] = grid[r+1][c], grid[r][c]
                local matches = self:FindMatches(state)
                grid[r][c], grid[r+1][c] = grid[r+1][c], grid[r][c]
                if next(matches) then return true end
            end
        end
    end
    return false
end

-- Mischt das Board neu bis HasPossibleMoves true ist.
-- Garantiert lösbar, keine initialen 3er-Ketten.
-- Gibt true zurück (immer erfolgreich nach max 20 Versuchen).
function L:ShuffleBoard(state)
    local maxAttempts = 20
    local attempt = 0
    repeat
        attempt = attempt + 1
        self:_GenerateGrid(state)
    until self:HasPossibleMoves(state) or attempt >= maxAttempts
    return true
end

-- ── Match-Erkennung ────────────────────────────────────────────
-- Gibt zurück: matches = { ["r,c"] = true, ... }
function L:FindMatches(state)
    local matches = {}
    local grid, cols, rows = state.grid, state.cols, state.rows

    -- Horizontal
    for r = 1, rows do
        local run = 1
        for c = 2, cols do
            local cur = grid[r][c]
            if cur > 0 and cur == grid[r][c-1] then
                run = run + 1
            else
                if run >= 3 then
                    for i = c - run, c - 1 do
                        matches[r .. "," .. i] = true
                    end
                end
                run = 1
            end
        end
        -- Abschluss am Zeilenende
        if run >= 3 then
            for i = cols - run + 1, cols do
                matches[r .. "," .. i] = true
            end
        end
    end

    -- Vertikal
    for c = 1, cols do
        local run = 1
        for r = 2, rows do
            local cur = grid[r][c]
            if cur > 0 and cur == grid[r-1][c] then
                run = run + 1
            else
                if run >= 3 then
                    for i = r - run, r - 1 do
                        matches[i .. "," .. c] = true
                    end
                end
                run = 1
            end
        end
        if run >= 3 then
            for i = rows - run + 1, rows do
                matches[i .. "," .. c] = true
            end
        end
    end

    return matches
end

-- Zählt Einträge in matches-Tabelle
local function CountMatches(matches)
    local n = 0
    for _ in pairs(matches) do n = n + 1 end
    return n
end

-- ── Match entfernen + Punkte ───────────────────────────────────
-- Gibt matchCount zurück (0 = keine Matches)
function L:RemoveMatches(state, matches)
    local n = CountMatches(matches)
    if n == 0 then
        state.comboCount = 0
        return 0
    end
    for key in pairs(matches) do
        local r, c = key:match("(%d+),(%d+)")
        state.grid[tonumber(r)][tonumber(c)] = 0
    end
    -- Punkte: 50 pro Icon × (1 + Combo * 0.5) abgerundet
    local mult = 1 + math.floor(state.comboCount * 0.5)
    state.score = state.score + n * 50 * mult
    state.comboCount = state.comboCount + 1
    if state.comboCount > (state.maxCombo or 0) then
        state.maxCombo = state.comboCount
    end
    return n
end

-- ── Schwerkraft (Icons fallen nach unten) ─────────────────────
-- Füllt leere Zellen (0) mit neuen Icons von oben.
-- Gibt zurück: { [col] = { { fromRow, toRow, gemType, isNew } } }
-- für Animation (Renderer braucht diese Info)
function L:ApplyGravity(state)
    local grid, cols, rows, n = state.grid, state.cols, state.rows, state.gemCount
    local fallInfo = {}

    for c = 1, cols do
        fallInfo[c] = {}
        -- Sammle vorhandene Gems von OBEN nach UNTEN.
        -- existing[1] = oberster Gem, existing[N] = unterster Gem.
        -- Dadurch gilt: fromRow <= toRow → Gem fällt nach unten oder bleibt.
        local existing = {}
        for r = 1, rows do
            if grid[r][c] > 0 then
                existing[#existing+1] = { gemType = grid[r][c], fromRow = r }
            end
        end

        -- Spalte leeren
        for r = 1, rows do grid[r][c] = 0 end

        local newCount = rows - #existing

        -- Neue Gems gestaffelt von oben spawnen.
        -- i=1 (oberster neuer Gem) startet am weitesten über dem Board: fromRow = i - newCount
        -- Beispiel newCount=3: i=1 → fromRow=-2, i=2 → fromRow=-1, i=3 → fromRow=0
        -- Dadurch fällt jeder neue Gem eine unterschiedliche Distanz → natürliches Nachrutschen.
        for i = 1, newCount do
            local targetRow = i
            local gemType   = math.random(1, n)
            grid[targetRow][c] = gemType
            fallInfo[c][#fallInfo[c]+1] = {
                toRow   = targetRow,
                fromRow = i - newCount,  -- negativ = über dem Board
                gemType = gemType,
                isNew   = true,
            }
        end

        -- Vorhandene Gems nach unten einfüllen.
        -- existing[1] (oberster) → targetRow = newCount + 1
        -- existing[N] (unterster)→ targetRow = rows
        -- Nur tatsächlich bewegte Gems (fromRow ~= targetRow) in fallInfo aufnehmen.
        for i, entry in ipairs(existing) do
            local targetRow = newCount + i
            grid[targetRow][c] = entry.gemType
            if entry.fromRow ~= targetRow then
                fallInfo[c][#fallInfo[c]+1] = {
                    toRow   = targetRow,
                    fromRow = entry.fromRow,
                    gemType = entry.gemType,
                    isNew   = false,
                }
            end
        end
    end

    return fallInfo
end

-- ── Tausch-Validierung ─────────────────────────────────────────
-- Prüft ob (r1,c1)↔(r2,c2) benachbart und gültig
function L:IsAdjacent(r1, c1, r2, c2)
    local dr = math.abs(r1 - r2)
    local dc = math.abs(c1 - c2)
    return (dr == 1 and dc == 0) or (dr == 0 and dc == 1)
end

-- Versucht Tausch. Gibt true zurück wenn Matches entstehen.
-- Führt Tausch durch oder macht ihn rückgängig.
-- Dekrementiert movesLeft NUR wenn Tausch gültig.
function L:TrySwap(state, r1, c1, r2, c2)
    if not self:IsAdjacent(r1, c1, r2, c2) then return false end

    local grid = state.grid
    grid[r1][c1], grid[r2][c2] = grid[r2][c2], grid[r1][c1]

    local matches = self:FindMatches(state)
    if next(matches) then
        state.movesLeft = state.movesLeft - 1
        state.comboCount = 0  -- Reset vor Kaskade
        return true, matches
    else
        -- Ungültig → rückgängig
        grid[r1][c1], grid[r2][c2] = grid[r2][c2], grid[r1][c1]
        return false, nil
    end
end

-- ── Spielende-Prüfung ──────────────────────────────────────────
function L:CheckGameOver(state)
    if state.gameOver then return true end
    -- Keine Züge mehr (Zug-basiert)
    if state.movesLeft <= 0 then
        state.gameOver = true
        state.won = false
        return true
    end
    -- Kein gültiger Move möglich (Softlock-Schutz)
    if not self:HasPossibleMoves(state) then
        state.gameOver = true
        state.won = false
        return true
    end
    return false
end

function L:CheckTimeout(state)
    if state.gameOver then return true end
    if state.timeLeft <= 0 then
        state.gameOver = true
        state.timedOut = true
        state.won = false
        return true
    end
    return false
end

-- ── Timer-Tick ─────────────────────────────────────────────────
-- Aufgerufen vom Engine jede Sekunde
function L:TickTimer(state, dt)
    if state.gameOver then return end
    state.timeLeft = math.max(0, state.timeLeft - (dt or 1))
    if state.timeLeft <= 0 then
        self:CheckTimeout(state)
    end
end
