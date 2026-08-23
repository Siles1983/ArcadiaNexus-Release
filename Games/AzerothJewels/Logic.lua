-- ============================================================
--  Azeroth Jewels – Logic.lua
--  Spielregeln und State. KEIN UI, KEINE Timer, KEINE WoW-Frames.
--
--  Begriffe:
--    board[row][col] – logisches Spielfeld (1-basiert, row=1 oben)
--    gemType         – Integer 1..7, WILD (99) = Wildcard, 0 = leer
--    obstacles[r][c] – "ICE" | "STONE" | "LOCKED" | nil
--                       ICE:    Gem darunter eingefroren (kein Swap/Match),
--                               angrenzendes Match entfernt die Eis-Schicht
--                       STONE:  kein Gem, unbeweglich, nur PowerUp zerstört
--                       LOCKED: kein Gem, bleibt das ganze Level
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_Logic = {}
local L = ArcadiaNexus.AJ_Logic

L.WILD = 99

-- Basispunkte pro entferntem Gem
local BASE_POINTS = 50

-- ── Difficulty-Modifikatoren (GDD §3.3) ────────────────────────
-- easy: Standard · normal: −2 Züge, +10% Punkte-Ziel · hard: −4 Züge, +20%
L.DIFF_MODS = {
    easy   = { moves = 0,  goalMult = 1.0 },
    normal = { moves = -2, goalMult = 1.1 },
    hard   = { moves = -4, goalMult = 1.2 },
}

-- ── Combo-Multiplikatoren (GDD §8) ─────────────────────────────
-- comboCount = Anzahl bereits erfolgter Matches in der laufenden Kaskade
function L:GetComboMultiplier(comboCount)
    if comboCount <= 0 then return 1.0 end
    if comboCount == 1 then return 1.25 end
    if comboCount == 2 then return 1.5 end
    if comboCount == 3 then return 1.75 end
    return 2.0
end

-- ============================================================
-- State
-- ============================================================
function L:NewState(levelNum, levelDef, difficulty)
    local mod = self.DIFF_MODS[difficulty] or self.DIFF_MODS.easy

    local goalCollect = nil
    if levelDef.goalCollect then
        goalCollect = {}
        for i, g in ipairs(levelDef.goalCollect) do
            goalCollect[i] = { gemType = g.gemType, amount = g.amount }
        end
    end

    local state = {
        level       = levelNum,
        difficulty  = difficulty,
        rows        = levelDef.grid,
        cols        = levelDef.grid,
        gemCount    = levelDef.gems,
        goalType    = levelDef.goalType,
        goalScore   = levelDef.goalScore
                      and math.floor(levelDef.goalScore * mod.goalMult + 0.5) or nil,
        goalCollect = goalCollect,
        movesLeft   = math.max(5, levelDef.moves + mod.moves),
        timeLimit   = levelDef.timeLimit,
        timeLeft    = levelDef.timeLimit,
        timerActive = false,   -- Engine setzt das aus Settings
        score       = 0,
        collected   = {},
        comboCount  = 0,
        maxCombo    = 0,
        board       = {},
        obstacles   = {},
        gameOver    = false,
        won         = false,
        timedOut    = false,
        stats       = { iceDestroyed = 0, powerUpsUsed = 0 },
    }

    for r = 1, state.rows do
        state.obstacles[r] = {}
    end
    for _, ob in ipairs(levelDef.obstacles or {}) do
        if ob.row >= 1 and ob.row <= state.rows and ob.col >= 1 and ob.col <= state.cols then
            state.obstacles[ob.row][ob.col] = ob.type
        end
    end

    return state
end

-- ── Zell-Eigenschaften ─────────────────────────────────────────
-- Zelle kann keinen Gem enthalten (STONE/LOCKED)
function L:IsBlocked(state, r, c)
    local ob = state.obstacles[r] and state.obstacles[r][c]
    return ob == "STONE" or ob == "LOCKED"
end

function L:IsFrozen(state, r, c)
    return (state.obstacles[r] and state.obstacles[r][c]) == "ICE"
end

-- Gem an (r,c) darf getauscht werden
function L:IsSwappable(state, r, c)
    if r < 1 or r > state.rows or c < 1 or c > state.cols then return false end
    if self:IsBlocked(state, r, c) or self:IsFrozen(state, r, c) then return false end
    return (state.board[r][c] or 0) > 0
end

-- Zelle nimmt an Matches teil (Gem vorhanden, nicht eingefroren/blockiert)
local function Matchable(state, r, c)
    if L:IsBlocked(state, r, c) or L:IsFrozen(state, r, c) then return false end
    return (state.board[r][c] or 0) > 0
end

-- ============================================================
-- Grid-Initialisierung
-- ============================================================
function L:InitGrid(state)
    local maxAttempts = 20
    local attempt = 0
    repeat
        attempt = attempt + 1
        self:_GenerateGrid(state)
    until self:HasPossibleMoves(state) or attempt >= maxAttempts
end

-- Generiert Gems ohne initiale Matches (blockierte Zellen bleiben 0)
function L:_GenerateGrid(state)
    local n = state.gemCount
    state.board = {}
    for r = 1, state.rows do
        state.board[r] = {}
        for c = 1, state.cols do
            if self:IsBlocked(state, r, c) then
                state.board[r][c] = 0
            else
                local validGems = {}
                for i = 1, n do
                    local ok = true
                    if c >= 3 and state.board[r][c-1] == i and state.board[r][c-2] == i then
                        ok = false
                    end
                    if ok and r >= 3 and state.board[r-1] and state.board[r-1][c] == i
                           and state.board[r-2] and state.board[r-2][c] == i then
                        ok = false
                    end
                    -- 2×2-Quadrat verhindern
                    if ok and r >= 2 and c >= 2
                       and state.board[r-1][c-1] == i and state.board[r-1][c] == i
                       and state.board[r][c-1] == i then
                        ok = false
                    end
                    if ok then validGems[#validGems+1] = i end
                end
                if #validGems > 0 then
                    state.board[r][c] = validGems[math.random(#validGems)]
                else
                    state.board[r][c] = math.random(1, n)
                end
            end
        end
    end
end

-- ============================================================
-- Match-Erkennung (3+, 4+, 5+, 2×2, Wildcards)
-- ============================================================
-- Rückgabe:
--   matches – { ["r,c"] = resolvedColor }  (0 = nur Wildcards)
--   info    – { count, runs = { {len,color}, … }, squares }
local function FlushRun(state, run, runColor, matches, info)
    if #run >= 3 then
        local color = runColor or 0
        for _, key in ipairs(run) do
            if not matches[key] then
                matches[key] = color
            end
        end
        info.runs[#info.runs+1] = { len = #run, color = color }
    end
end

function L:FindMatches(state)
    local matches = {}
    local info = { runs = {}, squares = 0 }

    local function scanLine(cellList)
        local run, runColor = {}, nil
        for _, cell in ipairs(cellList) do
            local r, c = cell[1], cell[2]
            local gem = state.board[r][c] or 0
            local usable = Matchable(state, r, c)
            if not usable then
                FlushRun(state, run, runColor, matches, info)
                run, runColor = {}, nil
            elseif gem == L.WILD then
                run[#run+1] = r .. "," .. c
            else
                if runColor == nil then
                    runColor = gem
                    run[#run+1] = r .. "," .. c
                elseif gem == runColor then
                    run[#run+1] = r .. "," .. c
                else
                    -- Farbkonflikt: Run schließen, neue Run startet mit
                    -- den Wildcards am Ende der alten Run + aktueller Zelle
                    local trailing = {}
                    for i = #run, 1, -1 do
                        local rr, cc = run[i]:match("(%d+),(%d+)")
                        if (state.board[tonumber(rr)][tonumber(cc)] or 0) == L.WILD then
                            table.insert(trailing, 1, run[i])
                        else
                            break
                        end
                    end
                    FlushRun(state, run, runColor, matches, info)
                    run = {}
                    for _, key in ipairs(trailing) do run[#run+1] = key end
                    run[#run+1] = r .. "," .. c
                    runColor = gem
                end
            end
        end
        FlushRun(state, run, runColor, matches, info)
    end

    -- Horizontal
    for r = 1, state.rows do
        local cells = {}
        for c = 1, state.cols do cells[#cells+1] = { r, c } end
        scanLine(cells)
    end
    -- Vertikal
    for c = 1, state.cols do
        local cells = {}
        for r = 1, state.rows do cells[#cells+1] = { r, c } end
        scanLine(cells)
    end

    -- 2×2-Quadrate
    for r = 1, state.rows - 1 do
        for c = 1, state.cols - 1 do
            local ok = Matchable(state, r, c) and Matchable(state, r, c+1)
                   and Matchable(state, r+1, c) and Matchable(state, r+1, c+1)
            if ok then
                local color = nil
                local valid = true
                for _, rc in ipairs({ {r,c}, {r,c+1}, {r+1,c}, {r+1,c+1} }) do
                    local gem = state.board[rc[1]][rc[2]]
                    if gem ~= L.WILD then
                        if color == nil then
                            color = gem
                        elseif gem ~= color then
                            valid = false
                            break
                        end
                    end
                end
                if valid then
                    color = color or 0
                    for _, rc in ipairs({ {r,c}, {r,c+1}, {r+1,c}, {r+1,c+1} }) do
                        local key = rc[1] .. "," .. rc[2]
                        if not matches[key] then matches[key] = color end
                    end
                    info.squares = info.squares + 1
                end
            end
        end
    end

    local count = 0
    for _ in pairs(matches) do count = count + 1 end
    info.count = count

    return matches, info
end

-- ============================================================
-- Matches entfernen + Punkte + Eis-Schichten
-- ============================================================
-- Rückgabe: removedCount, gainedScore
function L:RemoveMatches(state, matches, info)
    local count = info and info.count or 0
    if count == 0 then
        state.comboCount = 0
        return 0, 0
    end

    -- Punkte pro Match-Gruppe (GDD §3.1):
    --   3er ×1.0 · 4er ×1.5 · 5er+ ×2.0 · 2×2 ×1.25
    local groupPoints = 0
    for _, run in ipairs(info.runs) do
        local mult = 1.0
        if run.len >= 5 then mult = 2.0
        elseif run.len == 4 then mult = 1.5 end
        groupPoints = groupPoints + run.len * BASE_POINTS * mult
    end
    groupPoints = groupPoints + (info.squares or 0) * 4 * BASE_POINTS * 1.25

    -- Combo- und Zeitmodus-Multiplikatoren (GDD §8)
    local comboMult = self:GetComboMultiplier(state.comboCount)
    local timeMult  = state.timerActive and 1.5 or 1.0
    local gained = math.floor(groupPoints * comboMult * timeMult + 0.5)

    -- Zellen leeren + Sammeln zählen
    for key, color in pairs(matches) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        state.board[r][c] = 0
        if color and color > 0 then
            state.collected[color] = (state.collected[color] or 0) + 1
        end
    end

    -- Angrenzende Eis-Schichten entfernen
    self:_BreakAdjacentIce(state, matches)

    state.score      = state.score + gained
    state.comboCount = state.comboCount + 1
    if state.comboCount > state.maxCombo then
        state.maxCombo = state.comboCount
    end

    return count, gained
end

function L:_BreakAdjacentIce(state, removedCells)
    local toBreak = {}
    for key in pairs(removedCells) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        for _, d in ipairs({ {-1,0}, {1,0}, {0,-1}, {0,1} }) do
            local rr, cc = r + d[1], c + d[2]
            if rr >= 1 and rr <= state.rows and cc >= 1 and cc <= state.cols
               and self:IsFrozen(state, rr, cc) then
                toBreak[rr .. "," .. cc] = true
            end
        end
    end
    for key in pairs(toBreak) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        state.obstacles[r][c] = nil
        state.stats.iceDestroyed = state.stats.iceDestroyed + 1
    end
end

-- ============================================================
-- Schwerkraft + Refill (Hindernis-aware)
-- ============================================================
-- ICE-Zellen sind fixiert; STONE/LOCKED enthalten keine Gems,
-- fallende Gems passieren sie. Rückgabe wie Match3:
--   { [col] = { { fromRow, toRow, gemType, isNew }, … } }
function L:ApplyGravity(state)
    local fallInfo = {}
    local n = state.gemCount

    for c = 1, state.cols do
        fallInfo[c] = {}

        -- Freie Zeilen dieser Spalte (weder blockiert noch eingefroren)
        local freeRows = {}
        for r = 1, state.rows do
            if not self:IsBlocked(state, r, c) and not self:IsFrozen(state, r, c) then
                freeRows[#freeRows+1] = r
            end
        end

        -- Vorhandene Gems in freien Zellen (von oben nach unten)
        local existing = {}
        for _, r in ipairs(freeRows) do
            if (state.board[r][c] or 0) > 0 then
                existing[#existing+1] = { gemType = state.board[r][c], fromRow = r }
            end
            state.board[r][c] = 0
        end

        local newCount = #freeRows - #existing

        -- Neue Gems oben einfüllen (gestaffelt über dem Board spawnen)
        for i = 1, newCount do
            local targetRow = freeRows[i]
            local gemType   = math.random(1, n)
            state.board[targetRow][c] = gemType
            fallInfo[c][#fallInfo[c]+1] = {
                toRow   = targetRow,
                fromRow = i - newCount,   -- <= 0: über dem Board
                gemType = gemType,
                isNew   = true,
            }
        end

        -- Vorhandene Gems nach unten auffüllen
        for i, entry in ipairs(existing) do
            local targetRow = freeRows[newCount + i]
            state.board[targetRow][c] = entry.gemType
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

-- ============================================================
-- Tausch
-- ============================================================
function L:IsAdjacent(r1, c1, r2, c2)
    local dr = math.abs(r1 - r2)
    local dc = math.abs(c1 - c2)
    return (dr == 1 and dc == 0) or (dr == 0 and dc == 1)
end

-- Versucht Tausch. Gibt (true, matches, info) zurück wenn Matches entstehen.
-- Dekrementiert movesLeft NUR bei gültigem Tausch.
function L:TrySwap(state, r1, c1, r2, c2)
    if not self:IsAdjacent(r1, c1, r2, c2) then return false end
    if not self:IsSwappable(state, r1, c1) or not self:IsSwappable(state, r2, c2) then
        return false
    end

    local board = state.board
    board[r1][c1], board[r2][c2] = board[r2][c2], board[r1][c1]

    local matches, info = self:FindMatches(state)
    if next(matches) then
        state.movesLeft  = state.movesLeft - 1
        state.comboCount = 0
        return true, matches, info
    end

    board[r1][c1], board[r2][c2] = board[r2][c2], board[r1][c1]
    return false
end

-- ============================================================
-- Mögliche Züge / Shuffle
-- ============================================================
function L:HasPossibleMoves(state)
    for r = 1, state.rows do
        for c = 1, state.cols do
            if self:IsSwappable(state, r, c) then
                for _, d in ipairs({ {0,1}, {1,0} }) do
                    local rr, cc = r + d[1], c + d[2]
                    if rr <= state.rows and cc <= state.cols
                       and self:IsSwappable(state, rr, cc) then
                        local board = state.board
                        board[r][c], board[rr][cc] = board[rr][cc], board[r][c]
                        local matches = self:FindMatches(state)
                        board[r][c], board[rr][cc] = board[rr][cc], board[r][c]
                        if next(matches) then return true end
                    end
                end
            end
        end
    end
    return false
end

-- Mischt die frei beweglichen Gems (eingefrorene bleiben fixiert)
-- bis mindestens ein Zug möglich ist und keine initialen Matches existieren.
function L:ShuffleBoard(state)
    local Shuffle = ArcadiaNexus.ArrayUtils.Shuffle

    -- Positionen + Gems der freien Zellen einsammeln
    local cells, gems = {}, {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            if not self:IsBlocked(state, r, c) and not self:IsFrozen(state, r, c)
               and (state.board[r][c] or 0) > 0 then
                cells[#cells+1] = { r, c }
                gems[#gems+1]  = state.board[r][c]
            end
        end
    end

    local maxAttempts = 20
    for _ = 1, maxAttempts do
        Shuffle(gems)
        for i, rc in ipairs(cells) do
            state.board[rc[1]][rc[2]] = gems[i]
        end
        local matches = self:FindMatches(state)
        if not next(matches) and self:HasPossibleMoves(state) then
            return true
        end
    end

    -- Fallback: komplett neu generieren (Wildcards gehen verloren, aber lösbar)
    self:InitGrid(state)
    return true
end

-- ============================================================
-- PowerUp-Unterstützung (wird von AJ_PowerUps aufgerufen)
-- ============================================================
-- Entfernt eine Zell-Liste { {r,c}, … }:
--   Gems → zerstört (+Punkte, +Collect) · ICE → Schicht + Gem entfernt
--   STONE → zerstört (Zelle wird frei) · LOCKED → unverändert
-- Rückgabe: removedCount, gainedScore, removedKeys ({key=true})
function L:RemoveCellsForPowerUp(state, cellList)
    local removed, removedKeys = 0, {}
    local timeMult = state.timerActive and 1.5 or 1.0

    for _, rc in ipairs(cellList) do
        local r, c = rc[1], rc[2]
        if r >= 1 and r <= state.rows and c >= 1 and c <= state.cols then
            local ob = state.obstacles[r][c]
            if ob == "LOCKED" then
                -- bleibt bestehen
            elseif ob == "STONE" then
                state.obstacles[r][c] = nil
                removed = removed + 1
                removedKeys[r .. "," .. c] = true
            else
                if ob == "ICE" then
                    state.obstacles[r][c] = nil
                    state.stats.iceDestroyed = state.stats.iceDestroyed + 1
                end
                local gem = state.board[r][c] or 0
                if gem > 0 then
                    if gem ~= L.WILD then
                        state.collected[gem] = (state.collected[gem] or 0) + 1
                    end
                    state.board[r][c] = 0
                    removed = removed + 1
                    removedKeys[r .. "," .. c] = true
                end
            end
        end
    end

    local gained = math.floor(removed * BASE_POINTS * timeMult + 0.5)
    state.score = state.score + gained
    return removed, gained, removedKeys
end

-- Wandelt n zufällige normale Gems in Wildcards (Heiliger Strahl)
-- Rückgabe: Liste der Zellen { {r,c}, … }
function L:ConvertRandomToWild(state, n)
    local candidates = {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            local gem = state.board[r][c] or 0
            if gem > 0 and gem ~= L.WILD
               and not self:IsBlocked(state, r, c) and not self:IsFrozen(state, r, c) then
                candidates[#candidates+1] = { r, c }
            end
        end
    end
    ArcadiaNexus.ArrayUtils.Shuffle(candidates)

    local converted = {}
    for i = 1, math.min(n, #candidates) do
        local rc = candidates[i]
        state.board[rc[1]][rc[2]] = L.WILD
        converted[#converted+1] = rc
    end
    return converted
end

-- ============================================================
-- Ziel- & Spielende-Prüfung
-- ============================================================
function L:IsGoalMet(state)
    if state.goalType == "SCORE" then
        return state.score >= (state.goalScore or math.huge)
    elseif state.goalType == "COLLECT" then
        for _, g in ipairs(state.goalCollect or {}) do
            if (state.collected[g.gemType] or 0) < g.amount then
                return false
            end
        end
        return true
    end
    return false
end

function L:CheckGameOver(state)
    if state.gameOver then return true end
    if self:IsGoalMet(state) then
        state.gameOver = true
        state.won = true
        return true
    end
    if state.movesLeft <= 0 then
        state.gameOver = true
        state.won = false
        return true
    end
    return false
end

function L:CheckTimeout(state)
    if state.gameOver then return true end
    if state.timerActive and state.timeLeft <= 0 then
        state.gameOver = true
        state.timedOut = true
        state.won = false
        return true
    end
    return false
end

function L:TickTimer(state, dt)
    if state.gameOver then return end
    state.timeLeft = math.max(0, state.timeLeft - (dt or 1))
end

-- ============================================================
-- Serialisierung (Mid-Level-Resume)
-- ============================================================
function L:Serialize(state)
    local board = {}
    for r = 1, state.rows do
        board[r] = {}
        for c = 1, state.cols do
            board[r][c] = state.board[r][c] or 0
        end
    end
    local obstacles = {}
    for r = 1, state.rows do
        for c = 1, state.cols do
            local ob = state.obstacles[r] and state.obstacles[r][c]
            if ob then
                obstacles[#obstacles+1] = { type = ob, row = r, col = c }
            end
        end
    end
    local collected = {}
    for k, v in pairs(state.collected) do collected[k] = v end

    return {
        level       = state.level,
        difficulty  = state.difficulty,
        rows        = state.rows,
        cols        = state.cols,
        gemCount    = state.gemCount,
        goalType    = state.goalType,
        goalScore   = state.goalScore,
        goalCollect = state.goalCollect,
        movesLeft   = state.movesLeft,
        timeLimit   = state.timeLimit,
        timeLeft    = state.timeLeft,
        timerActive = state.timerActive,
        score       = state.score,
        collected   = collected,
        comboCount  = 0,
        maxCombo    = state.maxCombo,
        board       = board,
        obstacles   = obstacles,
        stats       = {
            iceDestroyed = state.stats.iceDestroyed,
            powerUpsUsed = state.stats.powerUpsUsed,
        },
    }
end

function L:Deserialize(saved)
    local state = {
        level       = saved.level,
        difficulty  = saved.difficulty,
        rows        = saved.rows,
        cols        = saved.cols,
        gemCount    = saved.gemCount,
        goalType    = saved.goalType,
        goalScore   = saved.goalScore,
        goalCollect = saved.goalCollect,
        movesLeft   = saved.movesLeft,
        timeLimit   = saved.timeLimit,
        timeLeft    = saved.timeLeft,
        timerActive = saved.timerActive,
        score       = saved.score or 0,
        collected   = saved.collected or {},
        comboCount  = 0,
        maxCombo    = saved.maxCombo or 0,
        board       = {},
        obstacles   = {},
        gameOver    = false,
        won         = false,
        timedOut    = false,
        stats       = {
            iceDestroyed = saved.stats and saved.stats.iceDestroyed or 0,
            powerUpsUsed = saved.stats and saved.stats.powerUpsUsed or 0,
        },
    }
    for r = 1, state.rows do
        state.board[r] = {}
        state.obstacles[r] = {}
        for c = 1, state.cols do
            state.board[r][c] = saved.board[r] and saved.board[r][c] or 0
        end
    end
    for _, ob in ipairs(saved.obstacles or {}) do
        state.obstacles[ob.row][ob.col] = ob.type
    end
    return state
end
