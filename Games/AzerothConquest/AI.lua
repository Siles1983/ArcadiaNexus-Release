--[[
    Gaming Hub
    Games/AzerothConquest/AI.lua
    Version: 1.0.0

    3 Schwierigkeits-Modi:

    CLASSIC (easy)
      Schießt zufällig auf unbeschossene Felder.

    PRO (normal) – Hunt/Target
      HUNT:   Schießt auf jedem zweiten Feld (Schachbrett-Muster) um Schiffe
              effizienter zu finden.
      TARGET: Nach einem Treffer werden benachbarte Felder systematisch
              abgearbeitet bis das Schiff versenkt ist.

    INSANE (hard) – Parity + Hunt/Target + Wahrscheinlichkeitskarte
      Berechnet für jedes Feld wie viele noch nicht versenkte Schiffe
      theoretisch dort liegen könnten. Schießt immer auf das Feld mit
      der höchsten Wahrscheinlichkeit. Nach einem Treffer wie PRO.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_AI = {}
local AI = ArcadiaNexus.AC_AI

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function getUnshot(board)
    local cells = {}
    for r = 1, board.size do
        for c = 1, board.size do
            if not board.hits[r][c] then
                table.insert(cells, { r = r, c = c })
            end
        end
    end
    return cells
end

local function pickRandom(list)
    if #list == 0 then return nil end
    return list[math.random(1, #list)]
end

-- Alle angeschossenen aber noch nicht versenkten Trefferzellen
local function getActiveHits(board)
    local hits = {}
    for r = 1, board.size do
        for c = 1, board.size do
            if board.hits[r][c] and board.cells[r][c] ~= 0 then
                local ship = board.ships[board.cells[r][c]]
                if ship and not ship.sunk then
                    table.insert(hits, { r = r, c = c })
                end
            end
        end
    end
    return hits
end

-- Benachbarte Felder die noch nicht beschossen wurden
local DIRS = { {0,1},{0,-1},{1,0},{-1,0} }
local function getNeighbors(board, r, c)
    local result = {}
    for _, d in ipairs(DIRS) do
        local nr = r + d[1]
        local nc = c + d[2]
        if nr >= 1 and nr <= board.size and
           nc >= 1 and nc <= board.size and
           not board.hits[nr][nc] then
            table.insert(result, { r = nr, c = nc })
        end
    end
    return result
end

-- ============================================================
-- CLASSIC – Zufälliger Schuss
-- ============================================================

local function shootClassic(board)
    return pickRandom(getUnshot(board))
end

-- ============================================================
-- PRO – Hunt/Target mit Schachbrett-Muster
-- ============================================================

local function shootPro(board)
    -- TARGET: Aktive Treffer vorhanden → benachbarte Felder abarbeiten
    local activeHits = getActiveHits(board)
    if #activeHits > 0 then
        -- Gerichtetes Target: wenn ≥2 Treffer eines Schiffes → Linie verlängern
        if #activeHits >= 2 then
            -- Sortiere nach r dann c
            table.sort(activeHits, function(a,b)
                return a.r < b.r or (a.r == b.r and a.c < b.c)
            end)
            local first = activeHits[1]
            local last  = activeHits[#activeHits]
            local dr    = last.r - first.r
            local dc    = last.c - first.c
            -- Normalisieren
            local stepR = dr == 0 and 0 or (dr > 0 and 1 or -1)
            local stepC = dc == 0 and 0 or (dc > 0 and 1 or -1)
            -- Versuche beide Enden zu verlängern
            local candidates = {}
            local nr, nc
            nr = last.r  + stepR; nc = last.c  + stepC
            if nr>=1 and nr<=board.size and nc>=1 and nc<=board.size and not board.hits[nr][nc] then
                table.insert(candidates, {r=nr, c=nc})
            end
            nr = first.r - stepR; nc = first.c - stepC
            if nr>=1 and nr<=board.size and nc>=1 and nc<=board.size and not board.hits[nr][nc] then
                table.insert(candidates, {r=nr, c=nc})
            end
            if #candidates > 0 then return pickRandom(candidates) end
        end
        -- Noch kein Muster → alle Nachbarn der Treffer
        local neighbors = {}
        for _, hit in ipairs(activeHits) do
            for _, n in ipairs(getNeighbors(board, hit.r, hit.c)) do
                table.insert(neighbors, n)
            end
        end
        if #neighbors > 0 then return pickRandom(neighbors) end
    end

    -- HUNT: Schachbrett-Muster (nur gerade oder ungerade Felder)
    local parity = {}
    for r = 1, board.size do
        for c = 1, board.size do
            if not board.hits[r][c] and (r + c) % 2 == 0 then
                table.insert(parity, { r = r, c = c })
            end
        end
    end
    if #parity > 0 then return pickRandom(parity) end
    return shootClassic(board)
end

-- ============================================================
-- INSANE – Wahrscheinlichkeitskarte + Hunt/Target
-- ============================================================

local function buildProbabilityMap(board)
    local size = board.size
    local prob = {}
    for r = 1, size do
        prob[r] = {}
        for c = 1, size do prob[r][c] = 0 end
    end

    -- Sammle alle noch nicht versenkten Schiffslängen
    local lengths = {}
    for _, ship in pairs(board.ships) do
        if not ship.sunk then
            table.insert(lengths, ship.length)
        end
    end

    -- Für jede Länge: zähle wie oft das Schiff horizontal/vertikal
    -- auf jedes Feld passen würde
    for _, len in ipairs(lengths) do
        for r = 1, size do
            for c = 1, size do
                -- Horizontal
                local fits = true
                for i = 0, len - 1 do
                    local nc = c + i
                    if nc > size or board.hits[r][nc] then
                        fits = false; break
                    end
                    -- Kein bekanntes leeres Feld (beschossen + leer = MISS)
                    if board.hits[r][nc] and board.cells[r][nc] == 0 then
                        fits = false; break
                    end
                end
                if fits then
                    for i = 0, len - 1 do
                        if not board.hits[r][c+i] then
                            prob[r][c+i] = prob[r][c+i] + 1
                        end
                    end
                end
                -- Vertikal
                fits = true
                for i = 0, len - 1 do
                    local nr = r + i
                    if nr > size or board.hits[nr][c] then
                        fits = false; break
                    end
                    if board.hits[nr][c] and board.cells[nr][c] == 0 then
                        fits = false; break
                    end
                end
                if fits then
                    for i = 0, len - 1 do
                        if not board.hits[r+i][c] then
                            prob[r+i][c] = prob[r+i][c] + 1
                        end
                    end
                end
            end
        end
    end

    return prob
end

local function shootInsane(board)
    -- TARGET: Aktive Treffer → wie PRO
    local activeHits = getActiveHits(board)
    if #activeHits > 0 then
        return shootPro(board)  -- PRO-Target ist bereits sehr gut
    end

    -- HUNT: Wahrscheinlichkeitskarte
    local prob    = buildProbabilityMap(board)
    local best    = -1
    local bestCells = {}

    for r = 1, board.size do
        for c = 1, board.size do
            if not board.hits[r][c] then
                local p = prob[r][c]
                if p > best then
                    best      = p
                    bestCells = { { r = r, c = c } }
                elseif p == best then
                    table.insert(bestCells, { r = r, c = c })
                end
            end
        end
    end

    if #bestCells > 0 then return pickRandom(bestCells) end
    return shootClassic(board)
end

-- ============================================================
-- GetBestMove (öffentliche API)
-- ============================================================

function AI:GetBestMove(board, difficulty)
    if difficulty == "hard" then
        return shootInsane(board)
    elseif difficulty == "normal" then
        return shootPro(board)
    else
        return shootClassic(board)
    end
end
