--[[
    Gaming Hub – Snake
    Games/Snake/Logic.lua

    Pure Spiellogik. Kein UI, keine Timer.

    Board:
    {
        gridSize    number   Anzahl Zellen pro Seite
        snake       table    { {r,c}, ... } – Kopf = [1], Schwanz = [#]
        dir         table    {dr, dc} – aktuelle Richtung
        nextDir     table    {dr, dc} – gepufferte nächste Richtung
        food        table    {r, c}
        score       number
        alive       bool
        multiplier  number
    }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Logic = {}
local L = ArcadiaNexus.SNK_Logic

-- ============================================================
-- NewBoard
-- ============================================================
function L:NewBoard(config)
    local T    = ArcadiaNexus.SNK_Themes
    local diff = T:GetDiff(config.difficulty)
    local g    = diff.gridSize

    -- Startposition: Mitte des Grids, 3 Segmente nach rechts
    local midR = math.floor(g / 2)
    local midC = math.floor(g / 2)
    local snake = {
        { r=midR, c=midC   },
        { r=midR, c=midC-1 },
        { r=midR, c=midC-2 },
    }

    local board = {
        gridSize   = g,
        snake      = snake,
        dir        = { dr=0, dc=1 },   -- startet nach rechts
        nextDir    = { dr=0, dc=1 },
        food       = nil,
        score      = 0,
        alive      = true,
        multiplier = diff.multiplier,
        difficulty = config.difficulty,
        theme      = config.theme,
        fruitsEaten = 0,
    }

    board.food = self:SpawnFood(board)
    return board
end

-- ============================================================
-- SpawnFood – zufällige Position die nicht auf der Schlange liegt
-- ============================================================
function L:SpawnFood(board)
    local g = board.gridSize
    -- Schnellen Lookup der belegten Zellen
    local occupied = {}
    for _, seg in ipairs(board.snake) do
        occupied[seg.r .. "," .. seg.c] = true
    end
    -- Versuche bis zu 200× eine freie Position finden
    for _ = 1, 200 do
        local r = math.random(1, g)
        local c = math.random(1, g)
        if not occupied[r .. "," .. c] then
            return { r=r, c=c }
        end
    end
    -- Fallback: erste freie Zelle
    for r = 1, g do
        for c = 1, g do
            if not occupied[r .. "," .. c] then
                return { r=r, c=c }
            end
        end
    end
    return nil   -- Spielfeld komplett voll (gewonnen)
end

-- ============================================================
-- QueueDir – puffert neue Richtung (verhindert 180°-Umkehr)
-- ============================================================
function L:QueueDir(board, dr, dc)
    -- Keine 180°-Umkehr erlaubt
    if dr == -board.dir.dr and dc == -board.dir.dc then return end
    -- Keine Diagonalen
    if dr ~= 0 and dc ~= 0 then return end
    board.nextDir.dr = dr
    board.nextDir.dc = dc
end

-- ============================================================
-- Tick – einen Spielschritt ausführen
-- Gibt zurück: "moved" | "ate" | "died" | "won"
-- ============================================================
function L:Tick(board)
    if not board.alive then return "died" end

    -- Richtung übernehmen
    board.dir.dr = board.nextDir.dr
    board.dir.dc = board.nextDir.dc

    local head  = board.snake[1]
    local g     = board.gridSize

    -- Neue Kopfposition (Wrap-Around am Rand)
    local newR = head.r + board.dir.dr
    local newC = head.c + board.dir.dc

    -- Wrap-Around (klassisch)
    if newR < 1 then newR = g end
    if newR > g then newR = 1 end
    if newC < 1 then newC = g end
    if newC > g then newC = 1 end

    -- Selbst-Kollision prüfen (nur Körper ohne letztes Segment,
    -- da das im selben Tick wegfällt)
    local bodyLen = #board.snake
    for i = 1, bodyLen - 1 do
        local seg = board.snake[i]
        if seg.r == newR and seg.c == newC then
            board.alive = false
            return "died"
        end
    end

    -- Kopf einfügen
    table.insert(board.snake, 1, { r=newR, c=newC })

    -- Futter gefressen?
    local ate = false
    if board.food and newR == board.food.r and newC == board.food.c then
        ate = true
        board.fruitsEaten = (board.fruitsEaten or 0) + 1
        board.score = board.score + (1 * board.multiplier)
        board.food  = self:SpawnFood(board)
        if board.food == nil then
            return "won"
        end
    end

    if not ate then
        -- Schwanz entfernen (Schlange bewegt sich ohne zu wachsen)
        table.remove(board.snake)
    end

    return ate and "ate" or "moved"
end
