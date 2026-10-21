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
        nextEnemyId=cfg.nextEnemyId or 1,nextBombId=cfg.nextBombId or 1,simRemainder=0,
        runId=cfg.runId,clearedLevel=cfg.clearedLevel or 0,stagesCleared=cfg.stagesCleared or 0,
        legacyContinuation=cfg.legacyContinuation==true,legacyScore=cfg.legacyScore or 0,
        levelPerformances=cfg.levelPerformances or {},stageStartScore=cfg.score or 0,
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
            id=board.nextEnemyId,
            gx = s[1], gy = s[2], px = s[1], py = s[2],
            dir = "down", moving = nil, animT = 0,
            bombActive = false,
        })
        board.nextEnemyId=board.nextEnemyId+1
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
        id=board.nextBombId,
        gx = p.gx, gy = p.gy,
        t = BOMB_FUSE, radius = p.radius,
        passable = true,            -- solange der Spieler noch drauf steht
        owner = "player",
    })
    board.nextBombId=board.nextBombId+1
    p.bombsActive = p.bombsActive + 1
    return true
end

-- ============================================================
-- Explosionen (mit Kettenreaktion)
-- ============================================================
local function explodeBomb(board, bomb, events)
    if bomb.exploded then return 0 end
    bomb.exploded=true
    for i, b in ipairs(board.bombs) do
        if b == bomb then table.remove(board.bombs, i) break end
    end
    if bomb.owner == "player" then
        board.player.bombsActive = math.max(0, board.player.bombsActive - 1)
    elseif bomb.owner=="enemy" then
        for _,e in ipairs(board.enemies) do if e.id==bomb.ownerId then e.bombActive=false end end
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
    events[#events+1]={type="explosion",id=bomb.id}
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
    if board.state~="RUNNING" or p.invuln>0 then return end
    board.lives = math.max(0,board.lives-1)
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

local function updatePlayer(board,dt,events)
    local p=board.player
    p.invuln=math.max(0,p.invuln-dt); p.animT=p.animT+dt
    local remaining=PLAYER_SPEED*dt
    for _=1,3 do
        if not p.moving then
            local dir=board.heldDirs[#board.heldDirs]; local v=dir and DIR_VECS[dir]
            if not v then break end
            p.dir=dir
            if not isWalkable(board,p.gx+v[1],p.gy+v[2],true) then break end
            p.moving={fx=p.gx,fy=p.gy,tx=p.gx+v[1],ty=p.gy+v[2],progress=0}
        end
        local m=p.moving; local amount=math.min(remaining,1-m.progress)
        m.progress=m.progress+amount; remaining=remaining-amount
        p.px=m.fx+(m.tx-m.fx)*m.progress; p.py=m.fy+(m.ty-m.fy)*m.progress
        if m.progress>=1-1e-10 then
            p.gx,p.gy=m.tx,m.ty; p.px,p.py=p.gx,p.gy; p.moving=nil
            tryPickupPowerup(board,events)
            for _,bomb in ipairs(board.bombs) do if bomb.passable and (bomb.gx~=p.gx or bomb.gy~=p.gy) then bomb.passable=false end end
        end
        if remaining<=1e-10 then break end
    end
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
        id=board.nextBombId,
        gx = e.gx, gy = e.gy,
        t = BOMB_FUSE, radius = ENEMY_BOMB_RADIUS,
        passable = false,
        owner = "enemy",ownerId=e.id,
    })
    board.nextBombId=board.nextBombId+1
    e.bombActive = true
end

local function updateEnemy(board,e,dt)
    e.animT=e.animT+dt
    local remaining=board.lvl.enemySpeed*board.diff.speedMul*dt
    for _=1,3 do
        if not e.moving then
            local dir=enemyPickDir(board,e); if not dir then break end
            local v=DIR_VECS[dir]; e.dir=dir
            e.moving={fx=e.gx,fy=e.gy,tx=e.gx+v[1],ty=e.gy+v[2],progress=0}
        end
        local m=e.moving; local amount=math.min(remaining,1-m.progress)
        m.progress=m.progress+amount; remaining=remaining-amount
        e.px=m.fx+(m.tx-m.fx)*m.progress; e.py=m.fy+(m.ty-m.fy)*m.progress
        if m.progress>=1-1e-10 then
            e.gx,e.gy=m.tx,m.ty; e.px,e.py=e.gx,e.gy; e.moving=nil; enemyTryPlaceBomb(board,e)
        end
        if remaining<=1e-10 then break end
    end
end

-- Interpolated gameplay centres share a quarter-tile footprint against blast tiles.
L.ACTOR_RADIUS=.25
local function actorInBlast(board,actor)
    for _,blast in ipairs(board.explosions) do for _,cell in ipairs(blast.cells) do
        local dx=math.max(0,math.abs(actor.px-cell.x)-.5)
        local dy=math.max(0,math.abs(actor.py-cell.y)-.5)
        if dx*dx+dy*dy<=L.ACTOR_RADIUS^2 then return true end
    end end
    return false
end
L.ActorInBlast=actorInBlast

-- ============================================================
-- Update – ein Simulationsschritt
-- ============================================================
function L:_Step(board, dt)
    local events = {}
    if board.state ~= "RUNNING" then return events end

    board.time      = board.time + dt
    board.levelTime = board.levelTime + dt

    updatePlayer(board, dt, events)

    for _,enemy in ipairs(board.enemies) do updateEnemy(board,enemy,dt) end
    -- Existing explosions age first; new explosions keep their complete lifetime.
    for i=#board.explosions,1,-1 do
        local blast=board.explosions[i]; blast.t=blast.t-dt
        if blast.t<=0 then table.remove(board.explosions,i) end
    end
    -- No list mutation during timer aging. Recursive chains consume identities once.
    local due={}
    for _,bomb in ipairs(board.bombs) do bomb.t=bomb.t-dt; if bomb.t<=1e-10 then due[#due+1]=bomb end end
    for _,bomb in ipairs(due) do
        if not bomb.exploded then
            local chain=explodeBomb(board,bomb,events)
            board.stats.maxChain=math.max(board.stats.maxChain,chain)
        end
    end

    -- Gegner
    for i = #board.enemies, 1, -1 do
        local e = board.enemies[i]
        if actorInBlast(board,e) then
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
                if board.state=="LOST" then return events end
            end
        end
    end

    -- Spieler in Explosion?
    if board.state == "RUNNING" and actorInBlast(board,board.player) then
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

L.FIXED_STEP=1/120
function L:Update(board,dt)
    local events={}; if not board or board.state~="RUNNING" then return events end
    board.simRemainder=(board.simRemainder or 0)+math.max(0,math.min(dt or 0,.1))
    for _=1,12 do
        if board.simRemainder+1e-10<self.FIXED_STEP then break end
        board.simRemainder=math.max(0,board.simRemainder-self.FIXED_STEP)
        local stepEvents=self:_Step(board,self.FIXED_STEP)
        for _,event in ipairs(stepEvents) do events[#events+1]=event end
        if board.state~="RUNNING" then board.simRemainder=0; break end
    end
    return events
end
function L:Copy(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=self:Copy(x) end return out
end
function L:Snapshot(board,state)
    if not board or board.terminal or board.state=="LOST" then return nil end
    local out={}
    for k,v in pairs(board) do if k~="diff" and k~="lvl" and k~="resultData" and k~="spawns" then out[k]=self:Copy(v) end end
    out.heldDirs={}; out.version=2; out.ruleVersion=2; out.phase=state or "PLAYING"
    out.diff=board.difficulty -- outer slot metadata and old checkpoint field remain readable
    return out
end

function L:Restore(data)
    local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
    local function integer(n) return finite(n) and n>=0 and n%1==0 end
    if type(data)~="table" or not self.DIFFS[data.diff or data.difficulty] or not integer(data.level) or data.level<1 or data.level>12
        or not integer(data.score) or not integer(data.lives) or data.lives<1 or data.lives>3 then return nil end
    if data.version==nil then
        for _,key in ipairs({"radius","bombsMax","time"}) do if not finite(data[key]) or data[key]<0 then return nil end end
        if data.radius%1~=0 or data.radius<1 or data.radius>6 or data.bombsMax%1~=0 or data.bombsMax<1 or data.bombsMax>5 then return nil end
        if data.stats~=nil and type(data.stats)~="table" then return nil end
        local stats=data.stats or {}
        for _,key in ipairs({"walls","enemies","powerups","maxChain"}) do if stats[key]~=nil and not integer(stats[key]) then return nil end end
        return self:NewBoard({difficulty=data.diff or data.difficulty,level=data.level,lives=data.lives,radius=data.radius,bombsMax=data.bombsMax,
            time=data.time,score=0,clearedLevel=data.level-1,legacyContinuation=true,legacyScore=data.score})
    end
    if data.version~=2 or data.ruleVersion~=2 or data.terminal or type(data.runId)~="string" or data.diff~=data.difficulty
        or type(data.legacyContinuation)~="boolean" or not integer(data.legacyScore)
        or data.phase~="PLAYING" and data.phase~="PAUSED" and data.phase~="LEVELWIN" and data.phase~="PAUSED_LEVELWIN"
        or data.state~="RUNNING" and data.state~="LEVEL_WON" or not integer(data.clearedLevel) or data.clearedLevel>12
        or not integer(data.stagesCleared) or data.stagesCleared>data.clearedLevel
        or not integer(data.nextEnemyId) or data.nextEnemyId<1 or not integer(data.nextBombId) or data.nextBombId<1
        or not finite(data.simRemainder) or data.simRemainder<0 or data.simRemainder>=self.FIXED_STEP+1e-8
        or type(data.grid)~="table" or type(data.player)~="table" or type(data.stats)~="table" or type(data.heldDirs)~="table" or next(data.heldDirs) then return nil end
    local cleared=data.state=="LEVEL_WON"
    if (data.phase=="LEVELWIN" or data.phase=="PAUSED_LEVELWIN")~=cleared
        or data.clearedLevel~=(cleared and data.level or data.level-1) or cleared and (data.level>=12 or data.stagesCleared<1)
        or not data.legacyContinuation and (data.legacyScore~=0 or data.stagesCleared~=data.clearedLevel)
        or not data.legacyContinuation and data.lives>self.DIFFS[data.diff].lives then return nil end
    for _,key in ipairs({"time","levelTime","lastTimeBonus","stageStartScore"}) do if not finite(data[key]) or data[key]<0 then return nil end end
    if data.levelTime>data.time+1e-8 or data.stageStartScore>data.score then return nil end
    for _,key in ipairs({"walls","enemies","powerups","maxChain","levelReached"}) do if not integer(data.stats[key]) then return nil end end
    if data.stats.levelReached~=data.level then return nil end
    local b={difficulty=data.difficulty,diff=self.DIFFS[data.diff],level=data.level,lvl=ArcadiaNexus.GB_Levels:GetLevel(data.level)}
    for _,key in ipairs({"state","score","lives","time","levelTime","lastTimeBonus","stageStartScore","simRemainder","runId","clearedLevel","stagesCleared","legacyContinuation","legacyScore","nextEnemyId","nextBombId"}) do b[key]=data[key] end
    b.stats=self:Copy(data.stats); b.grid={}; b.heldDirs={}; b.spawns={}
    for y=0,self.GRID_H-1 do
        if type(data.grid[y])~="table" then return nil end
        b.grid[y]={}
        for x=0,self.GRID_W-1 do
            local value=data.grid[y][x]
            if value~=self.FLOOR and value~=self.SOLID and value~=self.BRICK then return nil end
            local solid=x==0 or y==0 or x==12 or y==10 or x%2==0 and y%2==0
            if solid~=(value==self.SOLID) then return nil end
            b.grid[y][x]=value
        end
        for x in pairs(data.grid[y]) do if not integer(x) or x>=self.GRID_W then return nil end end
    end
    for y in pairs(data.grid) do if not integer(y) or y>=self.GRID_H then return nil end end
    local function cell(x,y) return integer(x) and integer(y) and inGrid(x,y) and b.grid[y][x]==self.FLOOR end
    local function actor(a)
        if type(a)~="table" or not cell(a.gx,a.gy) or not DIR_VECS[a.dir] or not finite(a.px) or not finite(a.py)
            or not finite(a.animT) or a.animT<0 then return false end
        if a.moving~=nil then
            local m=a.moving
            if type(m)~="table" or m.fx~=a.gx or m.fy~=a.gy or not cell(m.tx,m.ty)
                or math.abs(m.tx-m.fx)+math.abs(m.ty-m.fy)~=1 or not finite(m.progress) or m.progress<0 or m.progress>=1
                or math.abs(a.px-(m.fx+(m.tx-m.fx)*m.progress))>1e-7
                or math.abs(a.py-(m.fy+(m.ty-m.fy)*m.progress))>1e-7 then return false end
        elseif a.px~=a.gx or a.py~=a.gy then return false end
        return true
    end
    local p=data.player
    if not actor(p) or not finite(p.invuln) or p.invuln<0 or p.invuln>INVULN_TIME or not integer(p.radius) or p.radius<1 or p.radius>6
        or not integer(p.bombsMax) or p.bombsMax<1 or p.bombsMax>5 or not integer(p.bombsActive) or p.bombsActive>p.bombsMax then return nil end
    b.player=self:Copy(p)
    local function array(t)
        if type(t)~="table" then return false end
        for i=1,#t do if t[i]==nil then return false end end
        for k in pairs(t) do if not integer(k) or k<1 or k>#t then return false end end
        return true
    end
    if not array(data.enemies) or #data.enemies>6 or cleared and #data.enemies~=0 or not cleared and #data.enemies==0
        or not array(data.bombs) or not array(data.explosions) or type(data.powerups)~="table" then return nil end
    b.enemies={}; local ids={}
    for i,e in ipairs(data.enemies) do
        if not actor(e) or not integer(e.id) or e.id<1 or e.id>=b.nextEnemyId or ids[e.id] or type(e.bombActive)~="boolean" then return nil end
        ids[e.id]=true; b.enemies[i]=self:Copy(e)
    end
    b.bombs={}; local bombIds,positions,owners={}, {}, {}; local playerBombs=0
    for i,bomb in ipairs(data.bombs) do
        if type(bomb)~="table" or not integer(bomb.id) or bomb.id<1 or bomb.id>=b.nextBombId or bombIds[bomb.id] or bomb.exploded
            or not cell(bomb.gx,bomb.gy) or positions[cellKey(bomb.gx,bomb.gy)] or not finite(bomb.t) or bomb.t<=0 or bomb.t>BOMB_FUSE
            or not integer(bomb.radius) or bomb.radius<1 or bomb.radius>6 or type(bomb.passable)~="boolean" then return nil end
        if bomb.owner=="player" then playerBombs=playerBombs+1
        elseif bomb.owner=="enemy" and integer(bomb.ownerId) and bomb.ownerId>0 and bomb.ownerId<b.nextEnemyId and not owners[bomb.ownerId] then
            owners[bomb.ownerId]=true
        else return nil end
        bombIds[bomb.id]=true; positions[cellKey(bomb.gx,bomb.gy)]=true; b.bombs[i]=self:Copy(bomb)
    end
    if playerBombs~=p.bombsActive then return nil end
    for _,enemy in ipairs(b.enemies) do if enemy.bombActive~=(owners[enemy.id]==true) then return nil end end
    b.explosions={}
    for i,blast in ipairs(data.explosions) do
        if type(blast)~="table" or not finite(blast.t) or blast.t<=0 or blast.t>EXPLOSION_TIME or not array(blast.cells) or #blast.cells<1 then return nil end
        for _,c in ipairs(blast.cells) do if type(c)~="table" or not cell(c.x,c.y) or c.tex~="explosion" and c.tex~="explosion_h" and c.tex~="explosion_v" then return nil end end
        b.explosions[i]=self:Copy(blast)
    end
    b.powerups={}
    for key,pu in pairs(data.powerups) do
        if type(pu)~="table" or not cell(pu.x,pu.y) or key~=cellKey(pu.x,pu.y) or pu.kind~="radius" and pu.kind~="bombs" then return nil end
        b.powerups[key]=self:Copy(pu)
    end
    if not array(data.levelPerformances) or #data.levelPerformances~=data.stagesCleared then return nil end
    b.levelPerformances={}; local earnedScore=0
    for i,perf in ipairs(data.levelPerformances) do
        if type(perf)~="table" or perf.id~=i or not integer(perf.level) or perf.level<1 or perf.level>b.clearedLevel
            or not integer(perf.score) or perf.score>b.score or not integer(perf.elapsedMs)
            or perf.level~=b.clearedLevel-b.stagesCleared+i then return nil end
        b.levelPerformances[i]=self:Copy(perf)
        earnedScore=earnedScore+perf.score
    end
    if earnedScore>b.score or cleared and earnedScore~=b.score
        or not cleared and earnedScore~=b.stageStartScore
        or cleared and b.stageStartScore~=earnedScore-b.levelPerformances[#b.levelPerformances].score then return nil end
    return b
end
