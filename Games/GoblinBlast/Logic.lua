--[[
    ArcadiaNexus – Goblin Blast
    Games/GoblinBlast/Logic.lua
    Version: 2.0.0  (Level-System, Timer, Gegner-Bomben)

    Reine Spiellogik ohne UI. Koordinaten:
      gx/gy = Gitterzellen (0-basiert), px/py = Position in Kachel-Einheiten (float).
    Der Renderer multipliziert px/py mit der Kachelgroesse in Pixeln.

    API:
      NewBoard(cfg)     cfg = { difficulty, level, score, lives, radius, bombsMax, time }
                        (level/score/... optional – fuer Level-Fortschritt und Resume)
      Update(board, dt) → events { {type="explosion"|"wall"|"enemy"|"powerup"|"hit"
                                        |"level_won"|"lost"}, ... }
      PressDir / ReleaseDir / PlaceBomb
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GB_Logic = {}
local L = ArcadiaNexus.GB_Logic

-- ============================================================
-- Konstanten
-- ============================================================
L.GRID_W, L.GRID_H = 13, 11

local PLAYER_SPEED     = 4.5    -- Kacheln/Sekunde
local BOMB_FUSE        = 2.5
local EXPLOSION_TIME   = 0.45
local START_RADIUS     = 2
local START_BOMBS      = 1
local INVULN_TIME      = 2.0
local POWERUP_CHANCE   = 0.25
local ENEMY_BOMB_RADIUS = 2

-- Zelltypen
L.FLOOR, L.SOLID, L.BRICK = 0, 1, 2

local SCORE_BRICK, SCORE_ENEMY, SCORE_LEVEL = 10, 100, 500
local TIME_BONUS_PER_SEC = 2    -- Punkte pro gesparter Sekunde unter Par-Zeit

-- Globale Schwierigkeit als Multiplikator ueber den Level-Werten
-- enemyBonus: zusaetzliche Gegner pro Level (Level 1 → Easy 2, Normal 3, Hard 4)
L.DIFFS = {
    easy   = { lives = 3, multi = 1, speedMul = 0.85, bombMul = 0.7, enemyBonus = 0 },
    normal = { lives = 3, multi = 2, speedMul = 1.00, bombMul = 1.0, enemyBonus = 1 },
    hard   = { lives = 2, multi = 4, speedMul = 1.20, bombMul = 1.4, enemyBonus = 2 },
}

local DIR_VECS = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}

-- Gegner-Spawnpunkte (max. 6), sortiert nach Distanz zum Spieler (1,1)
local ENEMY_SPAWNS = {
    { 11, 9 }, { 11, 1 }, { 1, 9 }, { 6, 5 }, { 11, 5 }, { 6, 9 },
}

-- ============================================================
-- Hilfen
-- ============================================================
local function cellKey(x, y) return y * 100 + x end
L.CellKey = cellKey

local function inGrid(x, y)
    return x >= 0 and x < L.GRID_W and y >= 0 and y < L.GRID_H
end

local function bombAt(board, x, y)
    for _, b in ipairs(board.bombs) do
        if b.gx == x and b.gy == y then return b end
    end
end

local function isWalkable(board, x, y, allowPassableBomb)
    if not inGrid(x, y) then return false end
    if board.grid[y][x] ~= L.FLOOR then return false end
    local b = bombAt(board, x, y)
    if b and not (allowPassableBomb and b.passable) then return false end
    return true
end

local function explosionAt(board, x, y)
    for _, e in ipairs(board.explosions) do
        for _, c in ipairs(e.cells) do
            if c.x == x and c.y == y then return true end
        end
    end
    return false
end

-- Freie Sicht entlang einer Achse (keine Wand dazwischen)?
local function lineOfSight(board, x1, y1, x2, y2)
    if x1 ~= x2 and y1 ~= y2 then return false end
    local dx = (x2 > x1 and 1) or (x2 < x1 and -1) or 0
    local dy = (y2 > y1 and 1) or (y2 < y1 and -1) or 0
    local x, y = x1 + dx, y1 + dy
    while x ~= x2 or y ~= y2 do
        if board.grid[y][x] ~= L.FLOOR then return false end
        x, y = x + dx, y + dy
    end
    return true
end

-- ============================================================
-- Board-Erzeugung
-- ============================================================
local function generateGrid(board)
    local grid = {}
    for y = 0, L.GRID_H - 1 do
        grid[y] = {}
        for x = 0, L.GRID_W - 1 do
            if x == 0 or y == 0 or x == L.GRID_W - 1 or y == L.GRID_H - 1 then
                grid[y][x] = L.SOLID                    -- Aussenmauer
            elseif x % 2 == 0 and y % 2 == 0 then
                grid[y][x] = L.SOLID                    -- Saeulenraster
            elseif math.random() < board.lvl.brickChance then
                grid[y][x] = L.BRICK
            else
                grid[y][x] = L.FLOOR
            end
        end
    end
    board.grid = grid

    -- Spawnpunkte freiraeumen (Spieler + Gegner)
    for _, s in ipairs(board.spawns) do
        local cx, cy = s[1], s[2]
        grid[cy][cx] = L.FLOOR
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = cx + d[1], cy + d[2]
            if inGrid(nx, ny) and grid[ny][nx] == L.BRICK then
                grid[ny][nx] = L.FLOOR
            end
        end
    end
end

function L:NewBoard(cfg)
    cfg = cfg or {}
    local difficulty = cfg.difficulty or "easy"
    local diff       = self.DIFFS[difficulty] or self.DIFFS.easy
    local level      = cfg.level or 1
    local lvl        = ArcadiaNexus.GB_Levels:GetLevel(level)

    local board = {
        difficulty = difficulty,
        diff       = diff,
        level      = level,
        lvl        = lvl,
        state      = "RUNNING",     -- RUNNING | LEVEL_WON | LOST
        score      = cfg.score or 0,
        lives      = cfg.lives or diff.lives,
        time       = cfg.time or 0, -- Gesamtzeit des Durchlaufs
        levelTime  = 0,             -- Zeit im aktuellen Level (fuer Zeitbonus)
        lastTimeBonus = 0,
        bombs      = {},
        explosions = {},
        enemies    = {},
        powerups   = {},            -- [cellKey] = { x, y, kind = "radius"|"bombs" }
        heldDirs   = {},
        -- Statistiken zaehlen ueber den gesamten Durchlauf (werden beim
        -- Level-Wechsel/Resume via cfg.stats weitergereicht)
        stats      = cfg.stats or { walls = 0, enemies = 0, powerups = 0, maxChain = 0 },
        player = {
            gx = 1, gy = 1, px = 1, py = 1,
            dir = "down", moving = nil, animT = 0,
            invuln = 0,
            radius   = cfg.radius   or START_RADIUS,
            bombsMax = cfg.bombsMax or START_BOMBS,
            bombsActive = 0,
        },
    }

    board.stats.levelReached = level

    local enemyCount = math.min(lvl.enemies + diff.enemyBonus, #ENEMY_SPAWNS)

    board.spawns = { { 1, 1 } }
    for i = 1, enemyCount do
        table.insert(board.spawns, ENEMY_SPAWNS[i])
    end

    generateGrid(board)

    for i = 1, enemyCount do
        local s = ENEMY_SPAWNS[i]
        table.insert(board.enemies, {
            gx = s[1], gy = s[2], px = s[1], py = s[2],
            dir = "down", moving = nil, animT = 0,
            bombActive = false,
        })
    end

    return board
end

-- ============================================================
-- Eingabe
-- ============================================================
local function removeHeldDir(board, dir)
    for i = #board.heldDirs, 1, -1 do
        if board.heldDirs[i] == dir then table.remove(board.heldDirs, i) end
    end
end

function L:PressDir(board, dir)
    if not DIR_VECS[dir] then return end
    removeHeldDir(board, dir)
    table.insert(board.heldDirs, dir)
end

function L:ReleaseDir(board, dir)
    removeHeldDir(board, dir)
end

function L:PlaceBomb(board)
    local p = board.player
    if board.state ~= "RUNNING" then return false end
    if p.bombsActive >= p.bombsMax then return false end
    if bombAt(board, p.gx, p.gy) then return false end

    table.insert(board.bombs, {
        gx = p.gx, gy = p.gy,
        t = BOMB_FUSE, radius = p.radius,
        passable = true,            -- solange der Spieler noch drauf steht
        owner = "player",
    })
    p.bombsActive = p.bombsActive + 1
    return true
end

-- ============================================================
-- Explosionen (mit Kettenreaktion)
-- ============================================================
local function explodeBomb(board, bomb, events)
    for i, b in ipairs(board.bombs) do
        if b == bomb then table.remove(board.bombs, i) break end
    end
    if bomb.owner == "player" then
        board.player.bombsActive = math.max(0, board.player.bombsActive - 1)
    elseif type(bomb.owner) == "table" then
        bomb.owner.bombActive = false
    end

    local chainCount = 1
    local cells = { { x = bomb.gx, y = bomb.gy, tex = "explosion" } }
    local wallsChanged = false

    local dirs = {
        { 1, 0, "explosion_h" }, { -1, 0, "explosion_h" },
        { 0, 1, "explosion_v" }, { 0, -1, "explosion_v" },
    }
    for _, d in ipairs(dirs) do
        for dist = 1, bomb.radius do
            local x, y = bomb.gx + d[1] * dist, bomb.gy + d[2] * dist
            if not inGrid(x, y) or board.grid[y][x] == L.SOLID then break end
            if board.grid[y][x] == L.BRICK then
                board.grid[y][x] = L.FLOOR
                board.score = board.score + SCORE_BRICK * board.diff.multi
                board.stats.walls = board.stats.walls + 1
                wallsChanged = true
                if math.random() < POWERUP_CHANCE then
                    board.powerups[cellKey(x, y)] = {
                        x = x, y = y,
                        kind = (math.random() < 0.5) and "radius" or "bombs",
                    }
                end
                table.insert(cells, { x = x, y = y, tex = "explosion" })
                break
            end
            table.insert(cells, { x = x, y = y, tex = d[3] })
            local other = bombAt(board, x, y)
            if other then
                chainCount = chainCount + explodeBomb(board, other, events)
                break
            end
        end
    end

    table.insert(board.explosions, { t = EXPLOSION_TIME, cells = cells })
    if wallsChanged then
        table.insert(events, { type = "wall" })
    end
    return chainCount
end

-- ============================================================
-- Spieler
-- ============================================================
local function respawnPlayer(board)
    local p = board.player
    p.gx, p.gy = 1, 1
    p.px, p.py = 1, 1
    p.dir = "down"
    p.moving = nil
    p.invuln = INVULN_TIME
end

local function hitPlayer(board, events)
    local p = board.player
    if p.invuln > 0 then return end
    board.lives = board.lives - 1
    if board.lives <= 0 then
        board.state = "LOST"
        table.insert(events, { type = "lost" })
    else
        respawnPlayer(board)
        table.insert(events, { type = "hit" })
    end
end

local function tryPickupPowerup(board, events)
    local p  = board.player
    local pu = board.powerups[cellKey(p.gx, p.gy)]
    if not pu then return end
    if pu.kind == "radius" then
        p.radius = math.min(p.radius + 1, 6)
    else
        p.bombsMax = math.min(p.bombsMax + 1, 5)
    end
    board.powerups[cellKey(p.gx, p.gy)] = nil
    board.stats.powerups = board.stats.powerups + 1
    table.insert(events, { type = "powerup" })
end

local function updatePlayer(board, dt, events)
    local p = board.player
    if p.invuln > 0 then
        p.invuln = math.max(0, p.invuln - dt)
    end

    if p.moving then
        local m = p.moving
        m.progress = m.progress + PLAYER_SPEED * dt
        if m.progress >= 1 then
            p.gx, p.gy = m.tx, m.ty
            p.px, p.py = p.gx, p.gy
            p.moving = nil
            tryPickupPowerup(board, events)
            -- Eigene Bombe blockiert, sobald der Spieler sie verlaesst
            for _, b in ipairs(board.bombs) do
                if b.passable and (b.gx ~= p.gx or b.gy ~= p.gy) then
                    b.passable = false
                end
            end
        else
            p.px = m.fx + (m.tx - m.fx) * m.progress
            p.py = m.fy + (m.ty - m.fy) * m.progress
        end
    end

    if not p.moving then
        -- zuletzt gedrueckte, noch gehaltene Richtung hat Prioritaet
        local dir = board.heldDirs[#board.heldDirs]
        if dir then
            local v = DIR_VECS[dir]
            p.dir = dir
            if isWalkable(board, p.gx + v[1], p.gy + v[2], true) then
                p.moving = {
                    fx = p.gx, fy = p.gy,
                    tx = p.gx + v[1], ty = p.gy + v[2],
                    progress = 0,
                }
            end
        end
    end

    p.animT = p.animT + dt
end

-- ============================================================
-- Gegner
-- ============================================================
local function enemyPickDir(board, e)
    local options = {}
    for dir, v in pairs(DIR_VECS) do
        local nx, ny = e.gx + v[1], e.gy + v[2]
        if isWalkable(board, nx, ny, false) and not explosionAt(board, nx, ny) then
            table.insert(options, dir)
        end
    end
    if #options == 0 then return nil end
    -- Mit 60 % Wahrscheinlichkeit aktuelle Richtung beibehalten, wenn frei
    local cur = DIR_VECS[e.dir]
    if cur then
        local nx, ny = e.gx + cur[1], e.gy + cur[2]
        if isWalkable(board, nx, ny, false) and not explosionAt(board, nx, ny)
            and math.random() < 0.6 then
            return e.dir
        end
    end
    return options[math.random(#options)]
end

-- Soll der Gegner hier eine Bombe legen? (Spieler in Sichtlinie oder Wand daneben)
local function enemyWantsBomb(board, e)
    local p = board.player
    if (e.gx == p.gx and math.abs(e.gy - p.gy) <= 4)
        or (e.gy == p.gy and math.abs(e.gx - p.gx) <= 4) then
        if lineOfSight(board, e.gx, e.gy, p.gx, p.gy) then return true end
    end
    for _, v in pairs(DIR_VECS) do
        local nx, ny = e.gx + v[1], e.gy + v[2]
        if inGrid(nx, ny) and board.grid[ny][nx] == L.BRICK then return true end
    end
    return false
end

local function enemyTryPlaceBomb(board, e)
    local chance = board.lvl.enemyBombChance * board.diff.bombMul
    if chance <= 0 or e.bombActive then return end
    if bombAt(board, e.gx, e.gy) then return end
    if math.random() >= chance then return end
    if not enemyWantsBomb(board, e) then return end

    table.insert(board.bombs, {
        gx = e.gx, gy = e.gy,
        t = BOMB_FUSE, radius = ENEMY_BOMB_RADIUS,
        passable = false,
        owner = e,
    })
    e.bombActive = true
end

local function updateEnemy(board, e, dt)
    e.animT = e.animT + dt
    local speed = board.lvl.enemySpeed * board.diff.speedMul

    if e.moving then
        local m = e.moving
        m.progress = m.progress + speed * dt
        if m.progress >= 1 then
            e.gx, e.gy = m.tx, m.ty
            e.px, e.py = e.gx, e.gy
            e.moving = nil
            enemyTryPlaceBomb(board, e)     -- nur bei Ankunft auf einer Kachel
        else
            e.px = m.fx + (m.tx - m.fx) * m.progress
            e.py = m.fy + (m.ty - m.fy) * m.progress
        end
    else
        local dir = enemyPickDir(board, e)
        if dir then
            local v = DIR_VECS[dir]
            e.dir = dir
            e.moving = {
                fx = e.gx, fy = e.gy,
                tx = e.gx + v[1], ty = e.gy + v[2],
                progress = 0,
            }
        end
    end
end

-- ============================================================
-- Update – ein Simulationsschritt
-- ============================================================
function L:Update(board, dt)
    local events = {}
    if board.state ~= "RUNNING" then return events end

    board.time      = board.time + dt
    board.levelTime = board.levelTime + dt

    updatePlayer(board, dt, events)

    -- Bomben-Timer (Kettenreaktionen entfernen ggf. mehrere Eintraege)
    for i = #board.bombs, 1, -1 do
        local b = board.bombs[i]
        if b then
            b.t = b.t - dt
            if b.t <= 0 then
                local chain = explodeBomb(board, b, events)
                if chain > board.stats.maxChain then
                    board.stats.maxChain = chain
                end
                table.insert(events, { type = "explosion" })
            end
        end
    end

    -- Explosionen abbauen
    for i = #board.explosions, 1, -1 do
        local e = board.explosions[i]
        e.t = e.t - dt
        if e.t <= 0 then
            table.remove(board.explosions, i)
        end
    end

    -- Gegner
    for i = #board.enemies, 1, -1 do
        local e = board.enemies[i]
        updateEnemy(board, e, dt)
        if explosionAt(board, e.gx, e.gy) then
            table.remove(board.enemies, i)
            board.score = board.score + SCORE_ENEMY * board.diff.multi
            board.stats.enemies = board.stats.enemies + 1
            table.insert(events, { type = "enemy" })
        else
            -- Kollision mit Spieler (Distanz in Kachel-Einheiten)
            local p  = board.player
            local dx = e.px - p.px
            local dy = e.py - p.py
            if dx * dx + dy * dy < 0.36 then   -- 0.6 Kacheln
                hitPlayer(board, events)
            end
        end
    end

    -- Spieler in Explosion?
    if board.state == "RUNNING" and explosionAt(board, board.player.gx, board.player.gy) then
        hitPlayer(board, events)
    end

    -- Level geschafft: alle Gegner besiegt
    if board.state == "RUNNING" and #board.enemies == 0 then
        board.state = "LEVEL_WON"
        local saved = math.max(0, board.lvl.parTime - board.levelTime)
        board.lastTimeBonus = math.floor(saved) * TIME_BONUS_PER_SEC * board.diff.multi
        board.score = board.score
            + SCORE_LEVEL * board.diff.multi
            + board.lastTimeBonus
        board.stats.levelReached = board.level
        table.insert(events, { type = "level_won" })
    end

    return events
end
