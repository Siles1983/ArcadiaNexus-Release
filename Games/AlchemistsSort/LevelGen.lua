-- ============================================================
--  AlchemistsSort – LevelGen.lua
--  Level-Generator: Direkter Zufalls-Shuffle der Farbschichten.
--
--  Optimierungen (v2):
--    A. DFS ohne DeepCopy: Undo-basierter Stack (kein Heap-Druck)
--    B. BFS-Tiefe 50 → 15 (minMoves ist nur Anzeige, nicht Spiellogik)
--    C. StateKey: feste 1-Zeichen-Kürzel statt table.concat
--    D. Solvability-Heuristik als Vorfilter vor DFS
--
--  Kein math.randomseed (existiert nicht in Midnight API12).
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_LevelGen = {}
local G = ArcadiaNexus.ALS_LevelGen

local TUBE_CAPACITY = 5

-- ── Level-Skalierung ──────────────────────────────────────────

local LEVEL_TABLE = {
    -- { maxLevel, numColors, emptyTubes }
    {   5, 3, 2 },
    {  15, 4, 2 },
    {  30, 5, 2 },
    {  50, 6, 2 },
    {  75, 7, 2 },
    { 999, 8, 2 },
}

function G:_GetParams(levelNum)
    for _, row in ipairs(LEVEL_TABLE) do
        if levelNum <= row[1] then
            return row[2], row[3]
        end
    end
    return 8, 2
end

-- ── Hilfsfunktionen ───────────────────────────────────────────

local Logic
local function GetLogic()
    if not Logic then Logic = ArcadiaNexus.ALS_Logic end
    return Logic
end

-- Optimierung C: 1-Zeichen-Kürzel pro Farbe für kompakten StateKey
local COLOR_KEY = {
    RED="R", BLUE="B", GREEN="G", YELLOW="Y",
    PURPLE="P", ORANGE="O", CYAN="C", PINK="K",
}

local function StateKey(tubes)
    local parts = {}
    for i, tube in ipairs(tubes) do
        local s = ""
        for j = 1, #tube do
            s = s .. (COLOR_KEY[tube[j]] or "?")
        end
        parts[i] = s
    end
    return table.concat(parts, "|")
end

-- Fisher-Yates Shuffle (Core/ArrayUtils)
local function FisherYates(arr)
    ArcadiaNexus.ArrayUtils.Shuffle(arr)
end

-- ── Optimierung D: Heuristischer Vorfilter ────────────────────
-- Schnelle strukturelle Prüfung bevor der DFS startet.
-- Schlägt fehl wenn eine Röhre offensichtlich unlösbar blockiert ist.
local function _PassesHeuristic(tubes, numColors)
    -- Prüfe: keine Röhre enthält mehr als 3 verschiedene Farben
    -- (bei 5 Slots und 2 leeren Röhren ist das ein starkes Signal für Unlösbarkeit)
    for _, tube in ipairs(tubes) do
        if #tube > 0 then
            local seen = {}
            local distinct = 0
            for _, c in ipairs(tube) do
                if not seen[c] then
                    seen[c] = true
                    distinct = distinct + 1
                end
            end
            if distinct > math.min(numColors, 4) then
                return false
            end
        end
    end
    return true
end

-- ── Optimierung A: Undo-basierter DFS (kein DeepCopy) ─────────

function G:_IsSolvable(tubes)
    local visited = {}
    local L = GetLogic()
    local maxDepth = 400  -- etwas reduziert, Heuristik filtert schlechte States bereits

    local function dfs(state, depth)
        if depth > maxDepth then return false end
        local k = StateKey(state)
        if visited[k] then return false end
        visited[k] = true
        if L:CheckWin(state) then return true end

        for i = 1, #state do
            for j = 1, #state do
                if i ~= j then
                    local valid, cnt = L:IsValidMove(state[i], state[j])
                    if valid and cnt > 0 then
                        -- Zug direkt ausführen (kein DeepCopy)
                        local moved = {}
                        for _ = 1, cnt do
                            local c = table.remove(state[i], 1)
                            table.insert(state[j], 1, c)
                            moved[#moved+1] = c
                        end

                        local solved = dfs(state, depth + 1)

                        -- Zug rückgängig machen (Undo)
                        for _ = 1, cnt do
                            local c = table.remove(state[j], 1)
                            table.insert(state[i], 1, c)
                        end

                        if solved then return true end
                    end
                end
            end
        end
        return false
    end

    -- Arbeite direkt auf einer Kopie (nur einmal, nicht pro Schritt)
    local copy = L:DeepCopy(tubes)
    return dfs(copy, 0)
end

-- ── Optimierung B: BFS mit reduzierter Tiefe (15 statt 50) ───

function G:CalcMinMoves(tubes)
    local L      = GetLogic()
    local queue  = { { state = L:DeepCopy(tubes), moves = 0 } }
    local visited = {}
    visited[StateKey(tubes)] = true

    local head  = 1
    local LIMIT = 15  -- war 50, minMoves ist nur Anzeige

    while head <= #queue do
        local item = queue[head]
        head = head + 1
        if item.moves >= LIMIT then break end

        local state = item.state
        for i = 1, #state do
            for j = 1, #state do
                if i ~= j then
                    local valid, cnt = L:IsValidMove(state[i], state[j])
                    if valid and cnt > 0 then
                        local next = L:DeepCopy(state)
                        L:ExecuteMove(next[i], next[j])
                        if L:CheckWin(next) then
                            return item.moves + 1
                        end
                        local k = StateKey(next)
                        if not visited[k] then
                            visited[k] = true
                            queue[#queue + 1] = { state = next, moves = item.moves + 1 }
                        end
                    end
                end
            end
        end
    end

    return 0
end

-- ── Haupt-Generator ───────────────────────────────────────────
-- GenerateSingle: EIN Versuch. Gibt tubes,numTubes,minMoves oder nil zurück.
-- Wird von der Engine pro Frame-Tick aufgerufen (async).

function G:GenerateSingle(levelNum)
    local numColors, emptyTubes = self:_GetParams(levelNum)
    local Colors   = ArcadiaNexus.ALS_Colors
    local palette  = Colors:GetPalette(numColors)
    local numTubes = numColors + emptyTubes
    local L        = GetLogic()

    -- 1. Alle Farbschichten sammeln
    local allColors = {}
    for _, color in ipairs(palette) do
        for _ = 1, TUBE_CAPACITY do
            allColors[#allColors + 1] = color
        end
    end

    -- 2. Fisher-Yates Shuffle
    FisherYates(allColors)

    -- 3. Auf Röhren verteilen
    local tubes = {}
    local idx = 1
    for i = 1, numColors do
        local tube = {}
        for _ = 1, TUBE_CAPACITY do
            tube[#tube + 1] = allColors[idx]
            idx = idx + 1
        end
        tubes[i] = tube
    end
    for i = numColors + 1, numTubes do
        tubes[i] = {}
    end

    -- 4. Gelösten Zustand + Heuristik + DFS prüfen
    if not L:CheckWin(tubes) and _PassesHeuristic(tubes, numColors) and self:_IsSolvable(tubes) then
        local minMoves = self:CalcMinMoves(tubes)
        return tubes, numTubes, minMoves
    end

    return nil  -- dieser Versuch fehlgeschlagen
end

-- GenerateFallback: garantierter (trivialer) Fallback wenn alle Versuche scheitern.
function G:GenerateFallback(levelNum)
    local numColors, emptyTubes = self:_GetParams(levelNum)
    local Colors   = ArcadiaNexus.ALS_Colors
    local palette  = Colors:GetPalette(numColors)
    local numTubes = numColors + emptyTubes

    local tubes = {}
    for i = 1, numColors do
        local tube = {}
        for _ = 1, TUBE_CAPACITY do tube[#tube + 1] = palette[i] end
        tubes[i] = tube
    end
    if numColors >= 2 then
        tubes[1][1], tubes[2][1] = tubes[2][1], tubes[1][1]
    end
    for i = numColors + 1, numTubes do tubes[i] = {} end
    return tubes, numTubes, 1
end

-- Generate: Legacy-Wrapper (synchron, für Kompatibilität falls noch verwendet)
function G:Generate(levelNum)
    for _ = 1, 20 do
        local tubes, numTubes, minMoves = self:GenerateSingle(levelNum)
        if tubes then return tubes, numTubes, minMoves end
    end
    return self:GenerateFallback(levelNum)
end
