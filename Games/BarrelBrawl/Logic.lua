--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/Logic.lua
    Version: 1.0.0

    Reine Spielregeln – kein UI, kein C_Timer, keine Frames.

    Koordinatensystem: Pixel, Ursprung oben links im Spielfeld,
    y waechst nach UNTEN. Spieler-/Fass-y = Fusspunkt bzw. Mittelpunkt.

    Level-Aufbau (klassisches Traeger-Zickzack):
      Ebene 1 (unten) … Ebene 6 (Troll), Ebene 7 = Prinzessinnen-Sims.
      Traeger sind geneigt; Faesser rollen immer bergab, nehmen an
      Leitern zufaellig die Abkuerzung nach unten und fallen an offenen
      Enden auf die naechste Ebene.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BRB_Logic = {}
local Logic = ArcadiaNexus.BRB_Logic

-- ============================================================
-- Konstanten
-- ============================================================
Logic.FIELD_W = 448
Logic.FIELD_H = 400
Logic.TILE    = 32

Logic.MAX_BARRELS = 10   -- hartes Pool-Limit (Renderer-Vertrag)

local GRAVITY       = 640   -- px/s^2
local MOVE_SPEED    = 95    -- px/s
local CLIMB_SPEED   = 65    -- px/s
local JUMP_V        = 250   -- px/s Absprung
local BARREL_LADDER = 90    -- px/s Fass auf Leiter
local MAX_FALL      = 90    -- px Sturzhoehe, ab der ein Leben verloren geht
local LADDER_SNAP   = 10    -- px horizontale Einrast-Toleranz
local BARREL_R      = 12    -- px visueller Radius (Positionierung)

-- Spieler-Hitbox (Halbmasse, Mittelpunkt = Fusspunkt - h)
local P_HALF_W, P_HALF_H = 7, 12
-- Fass-Hitbox (Halbmasse um den Mittelpunkt)
local B_HALF = 9

-- ============================================================
-- Level-Geometrie
-- ============================================================
-- Plattform: { x0, x1, y0, y1 } – y0/y1 = Oberkante an x0/x1.
-- bottom = unterste Ebene (Faesser rollen aus dem Feld), ledge = Ziel-Sims.
Logic.PLATFORMS = {
    { x0 = 0,   x1 = 448, y0 = 374, y1 = 366, bottom = true },  -- 1: bergab links
    { x0 = 0,   x1 = 416, y0 = 314, y1 = 322 },                 -- 2: bergab rechts
    { x0 = 32,  x1 = 448, y0 = 270, y1 = 262 },                 -- 3: bergab links
    { x0 = 0,   x1 = 416, y0 = 206, y1 = 214 },                 -- 4: bergab rechts
    { x0 = 32,  x1 = 448, y0 = 162, y1 = 154 },                 -- 5: bergab links
    { x0 = 0,   x1 = 448, y0 = 98,  y1 = 106 },                 -- 6: Troll-Ebene
    { x0 = 176, x1 = 304, y0 = 56,  y1 = 56, ledge = true },    -- 7: Prinzessin
}
Logic.LEDGE_INDEX = 7

-- Leiter: verbindet lower-Plattform mit upper-Plattform bei x.
Logic.LADDERS = {
    { x = 176, lower = 1, upper = 2 },
    { x = 400, lower = 1, upper = 2 },
    { x = 64,  lower = 2, upper = 3 },
    { x = 288, lower = 2, upper = 3 },
    { x = 128, lower = 3, upper = 4 },
    { x = 384, lower = 3, upper = 4 },
    { x = 64,  lower = 4, upper = 5 },
    { x = 256, lower = 4, upper = 5 },
    { x = 160, lower = 5, upper = 6 },
    { x = 384, lower = 5, upper = 6 },
    { x = 224, lower = 6, upper = 7 },
}

-- Startpositionen
Logic.PLAYER_START_X  = 48
Logic.TROLL_X         = 48
Logic.TROLL_FLOOR     = 6
Logic.PRINCESS_X      = 268
Logic.BARREL_SPAWN_X  = 76

-- Schwierigkeit
local DIFF = {
    easy   = { lives = 3, barrelSpeed = 70,  spawnInterval = 3.2, ladderChance = 0.20, bonus = 5000 },
    normal = { lives = 3, barrelSpeed = 85,  spawnInterval = 2.6, ladderChance = 0.30, bonus = 5000 },
    hard   = { lives = 2, barrelSpeed = 100, spawnInterval = 2.1, ladderChance = 0.40, bonus = 4000 },
}

-- ============================================================
-- Geometrie-Helfer (pur)
-- ============================================================

--- Oberkante der Plattform i an Position x (lineare Neigung).
function Logic.PlatformYAt(i, x)
    local pf = Logic.PLATFORMS[i]
    if x < pf.x0 then x = pf.x0 end
    if x > pf.x1 then x = pf.x1 end
    return pf.y0 + (pf.y1 - pf.y0) * (x - pf.x0) / (pf.x1 - pf.x0)
end

--- Bergab-Richtung der Plattform i (+1 = nach rechts, -1 = nach links, 0 = flach).
function Logic.DownhillDir(i)
    local pf = Logic.PLATFORMS[i]
    if pf.y1 > pf.y0 then return 1 end
    if pf.y1 < pf.y0 then return -1 end
    return 0
end

--- Achsenparallele Kollisionspruefung (AABB, Mittelpunkte + Halbmasse).
function Logic.AABBOverlap(ax, ay, ahw, ahh, bx, by, bhw, bhh)
    return math.abs(ax - bx) < (ahw + bhw)
       and math.abs(ay - by) < (ahh + bhh)
end

-- Leiter-Endpunkte (einmalig aus der Geometrie abgeleitet)
for _, lad in ipairs(Logic.LADDERS) do
    lad.yTop    = Logic.PlatformYAt(lad.upper, lad.x)
    lad.yBottom = Logic.PlatformYAt(lad.lower, lad.x)
end

--- Erste Plattform, deren Oberkante zwischen y0 und y1 gekreuzt wurde.
function Logic:_FindLanding(x, yFrom, yTo)
    local bestIdx, bestY
    for i, pf in ipairs(Logic.PLATFORMS) do
        if x >= pf.x0 - 2 and x <= pf.x1 + 2 then
            local sy = Logic.PlatformYAt(i, x)
            if sy >= yFrom - 0.01 and sy <= yTo and (not bestY or sy < bestY) then
                bestIdx, bestY = i, sy
            end
        end
    end
    return bestIdx, bestY
end

--- Leiter in Einrast-Naehe: dir = "up" (lower == floor) oder "down" (upper == floor).
function Logic:_LadderAt(x, floor, dir)
    for i, lad in ipairs(Logic.LADDERS) do
        if math.abs(x - lad.x) <= LADDER_SNAP then
            if dir == "up" and lad.lower == floor then return i end
            if dir == "down" and lad.upper == floor then return i end
        end
    end
    return nil
end

-- ============================================================
-- Board-Aufbau
-- ============================================================
function Logic:NewBoard(cfg)
    cfg = cfg or {}
    local diff  = DIFF[cfg.difficulty] and cfg.difficulty or "normal"
    local d     = DIFF[diff]

    local board = {
        difficulty    = diff,
        state         = "PLAYING",   -- PLAYING | LOST
        time          = 0,
        score         = 0,
        lives         = d.lives,
        level         = 1,

        bonus         = d.bonus,
        bonusStart    = d.bonus,
        _bonusAcc     = 0,

        barrelSpeed   = d.barrelSpeed,
        spawnInterval = d.spawnInterval,
        ladderChance  = d.ladderChance,

        bannerT       = 0,
        flashT        = 0,

        input         = { left = false, right = false, up = false, down = false, jump = false },

        player = {
            x = Logic.PLAYER_START_X,
            y = Logic.PlatformYAt(1, Logic.PLAYER_START_X),
            floor = 1, state = "GROUND",   -- GROUND | JUMP | CLIMB
            vx = 0, vy = 0, dir = 1,
            ladder = nil, jumpStartY = 0,
            moving = false, animT = 0, invuln = 0,
        },

        troll = {
            x = Logic.TROLL_X,
            y = Logic.PlatformYAt(Logic.TROLL_FLOOR, Logic.TROLL_X),
            animT = 0, throwT = 0,
        },

        princess = {
            x = Logic.PRINCESS_X,
            y = Logic.PlatformYAt(Logic.LEDGE_INDEX, Logic.PRINCESS_X),
        },

        barrels = {},
        stats   = { jumped = 0, rescues = 0, spawned = 0 },
    }

    local targetLevel = tonumber(cfg.level) or 1
    if targetLevel > 1 then
        for _ = 2, targetLevel do
            board.barrelSpeed   = math.min(d.barrelSpeed * 2.2, board.barrelSpeed * 1.10)
            board.spawnInterval = math.max(1.0, board.spawnInterval * 0.88)
            board.ladderChance  = math.min(0.55, board.ladderChance + 0.03)
        end
        board.level = targetLevel
    end
    if cfg.score then board.score = cfg.score end
    if cfg.lives then board.lives = cfg.lives end
    if cfg.time  then board.time  = cfg.time  end
    if cfg.stats then
        board.stats.jumped  = cfg.stats.jumped  or 0
        board.stats.rescues = cfg.stats.rescues or 0
        board.stats.spawned = cfg.stats.spawned or 0
    end

    return board
end

-- ============================================================
-- Eingabe (vom Engine gesetzt)
-- ============================================================
function Logic:Press(board, dir)
    if board then board.input[dir] = true end
end

function Logic:Release(board, dir)
    if board then board.input[dir] = false end
end

function Logic:QueueJump(board)
    if board then board.input.jump = true end
end

-- ============================================================
-- Fass-Spawn (vom Engine-TimerGuard aufgerufen)
-- ============================================================
function Logic:SpawnBarrel(board)
    if not board or board.state ~= "PLAYING" then return end
    if #board.barrels >= Logic.MAX_BARRELS then return end

    local floor = Logic.TROLL_FLOOR
    board.troll.throwT = 0.35
    board.stats.spawned = board.stats.spawned + 1
    board.barrels[#board.barrels + 1] = {
        x = Logic.BARREL_SPAWN_X,
        y = Logic.PlatformYAt(floor, Logic.BARREL_SPAWN_X) - BARREL_R,
        floor = floor,
        dir = Logic.DownhillDir(floor),
        state = "ROLL",   -- ROLL | FALL | LADDER
        vy = 0, rollT = 0, ladder = nil, scored = false,
    }
end

-- ============================================================
-- Treffer / Respawn / Level
-- ============================================================
function Logic:_RespawnPlayer(board)
    local p = board.player
    p.x, p.floor = Logic.PLAYER_START_X, 1
    p.y = Logic.PlatformYAt(1, p.x)
    p.state, p.vx, p.vy = "GROUND", 0, 0
    p.ladder, p.moving = nil, false
    p.invuln = 2.5
    board.bonus = board.bonusStart
    board._bonusAcc = 0
end

function Logic:_ApplyHit(board, events)
    board.lives = board.lives - 1
    board.flashT = 0.8
    events[#events + 1] = { type = "hit" }
    if board.lives <= 0 then
        board.state = "LOST"
        events[#events + 1] = { type = "lost" }
    else
        self:_RespawnPlayer(board)
    end
end

function Logic:_AdvanceLevel(board, events)
    local d = DIFF[board.difficulty]
    board.score = board.score + board.bonus
    board.level = board.level + 1
    board.stats.rescues = board.stats.rescues + 1

    board.barrelSpeed   = math.min(d.barrelSpeed * 2.2, board.barrelSpeed * 1.10)
    board.spawnInterval = math.max(1.0, board.spawnInterval * 0.88)
    board.ladderChance  = math.min(0.55, board.ladderChance + 0.03)

    for i = #board.barrels, 1, -1 do
        board.barrels[i] = nil
    end
    self:_RespawnPlayer(board)
    board.player.invuln = 1.0
    board.bannerT = 2.2
    events[#events + 1] = { type = "rescue" }
end

-- ============================================================
-- Spieler-Update (Bodenlauf / Sprung / Leiter-Zustandsmaschine)
-- ============================================================
function Logic:_UpdatePlayer(board, dt, events)
    local p  = board.player
    local in_ = board.input

    if p.state == "CLIMB" then
        local lad = Logic.LADDERS[p.ladder]
        local dy = 0
        if in_.up then dy = -CLIMB_SPEED elseif in_.down then dy = CLIMB_SPEED end
        p.y = p.y + dy * dt
        p.moving = dy ~= 0
        if p.moving then p.animT = p.animT + dt end
        board.input.jump = false   -- kein gepufferter Sprung von der Leiter
        -- Abstieg nur in Bewegungsrichtung beenden (sonst sofortiger
        -- Wieder-Ausstieg beim Aufsteigen von der Oberkante)
        if dy < 0 and p.y <= lad.yTop then
            p.y, p.floor, p.state, p.ladder = lad.yTop, lad.upper, "GROUND", nil
        elseif dy > 0 and p.y >= lad.yBottom then
            p.y, p.floor, p.state, p.ladder = lad.yBottom, lad.lower, "GROUND", nil
        end
        return
    end

    if p.state == "JUMP" then
        p.x = p.x + p.vx * dt
        if p.x < 8 then p.x = 8 elseif p.x > Logic.FIELD_W - 8 then p.x = Logic.FIELD_W - 8 end
        p.vy = p.vy + GRAVITY * dt
        local prevY = p.y
        p.y = p.y + p.vy * dt
        if p.vy > 0 then
            local idx, sy = self:_FindLanding(p.x, prevY, p.y)
            if idx then
                p.y, p.floor, p.state, p.vx = sy, idx, "GROUND", 0
                if sy - p.jumpStartY > MAX_FALL then
                    self:_ApplyHit(board, events)
                end
            end
        end
        if p.y > Logic.FIELD_H + 40 then
            self:_ApplyHit(board, events)
        end
        return
    end

    -- GROUND
    local dir = 0
    if in_.left then dir = -1 elseif in_.right then dir = 1 end

    -- Leiter besteigen (hoch am Fuss, runter an der Oberkante)
    if in_.up or in_.down then
        local li = self:_LadderAt(p.x, p.floor, in_.up and "up" or "down")
        if li then
            local lad = Logic.LADDERS[li]
            p.state, p.ladder = "CLIMB", li
            p.x = lad.x
            p.y = in_.up and lad.yBottom or lad.yTop
            p.moving = false
            board.input.jump = false
            return
        end
    end

    if in_.jump then
        board.input.jump = false
        p.state, p.vy = "JUMP", -JUMP_V
        p.vx = dir * MOVE_SPEED
        if dir ~= 0 then p.dir = dir end
        p.jumpStartY = p.y
        events[#events + 1] = { type = "jump" }
        return
    end
    board.input.jump = false

    if dir ~= 0 then
        p.dir, p.moving = dir, true
        p.animT = p.animT + dt
        p.x = p.x + dir * MOVE_SPEED * dt

        local pf = Logic.PLATFORMS[p.floor]
        local minX = (pf.x0 <= 0) and 8 or (pf.x0 - 2)
        local maxX = (pf.x1 >= Logic.FIELD_W) and (Logic.FIELD_W - 8) or (pf.x1 + 2)
        if p.x < minX or p.x > maxX then
            if pf.x0 <= 0 and p.x < minX then
                p.x = minX
                p.y = Logic.PlatformYAt(p.floor, p.x)
            elseif pf.x1 >= Logic.FIELD_W and p.x > maxX then
                p.x = maxX
                p.y = Logic.PlatformYAt(p.floor, p.x)
            else
                -- ueber die offene Kante gelaufen → freier Fall
                p.state, p.vy = "JUMP", 0
                p.vx = dir * MOVE_SPEED * 0.6
                p.jumpStartY = p.y
            end
        else
            p.y = Logic.PlatformYAt(p.floor, p.x)
        end
    else
        p.moving = false
    end
end

-- ============================================================
-- Fass-Update (Rollen / Fallen / Leiter)
-- ============================================================
function Logic:_UpdateBarrels(board, dt)
    local barrels = board.barrels
    for i = #barrels, 1, -1 do
        local b = barrels[i]
        local remove = false

        if b.state == "ROLL" then
            local pf = Logic.PLATFORMS[b.floor]
            local prevX = b.x
            b.x = b.x + b.dir * board.barrelSpeed * dt
            b.rollT = b.rollT + dt

            -- Leiter-Abstieg (zufaellig, klassisches Zickzack brechen)
            for li, lad in ipairs(Logic.LADDERS) do
                if lad.upper == b.floor
                    and (prevX - lad.x) * (b.x - lad.x) <= 0
                    and math.random() < board.ladderChance then
                    b.state, b.ladder = "LADDER", li
                    b.x = lad.x
                    break
                end
            end

            if b.state == "ROLL" then
                if b.x < pf.x0 - 2 or b.x > pf.x1 + 2 then
                    if pf.bottom then
                        -- rollt aus dem Feld
                        if b.x < -24 or b.x > Logic.FIELD_W + 24 then
                            remove = true
                        end
                    else
                        b.state, b.vy = "FALL", 0
                    end
                else
                    b.y = Logic.PlatformYAt(b.floor, b.x) - BARREL_R
                end
            end

        elseif b.state == "FALL" then
            b.vy = b.vy + GRAVITY * dt
            local prevY = b.y + BARREL_R
            b.x = b.x + b.dir * board.barrelSpeed * 0.35 * dt
            -- An den Feldraendern klemmen: sonst driftet ein Fass, das am
            -- rechten Ende der obersten Etage abrollt, ueber die
            -- Landetoleranz von Ebene 5 hinaus und faellt aus dem Feld.
            if b.x < 4 then b.x = 4 elseif b.x > Logic.FIELD_W - 4 then b.x = Logic.FIELD_W - 4 end
            b.y = b.y + b.vy * dt
            local idx, sy = self:_FindLanding(b.x, prevY, b.y + BARREL_R)
            if idx then
                b.floor, b.state, b.vy = idx, "ROLL", 0
                b.dir = Logic.DownhillDir(idx)
                if b.dir == 0 then b.dir = 1 end
                b.y = sy - BARREL_R
            elseif b.y > Logic.FIELD_H + 60 then
                remove = true
            end

        elseif b.state == "LADDER" then
            local lad = Logic.LADDERS[b.ladder]
            b.y = b.y + BARREL_LADDER * dt
            b.rollT = b.rollT + dt
            local targetY = lad.yBottom - BARREL_R
            if b.y >= targetY then
                b.y, b.floor = targetY, lad.lower
                b.state, b.ladder = "ROLL", nil
                b.dir = Logic.DownhillDir(lad.lower)
                if b.dir == 0 then b.dir = 1 end
            end
        end

        if remove then
            table.remove(barrels, i)
        end
    end
end

-- ============================================================
-- Kollision & Sprung-Bonus
-- ============================================================
function Logic:_CheckCollisions(board, events)
    local p = board.player
    local pcx, pcy = p.x, p.y - P_HALF_H   -- Hitbox-Mittelpunkt

    for _, b in ipairs(board.barrels) do
        -- Punkte fuers Ueberspringen (einmal pro Fass)
        if p.state == "JUMP" and not b.scored
            and math.abs(b.x - p.x) < 16
            and b.y > p.y and (b.y - p.y) < 40 then
            b.scored = true
            board.score = board.score + 100
            board.stats.jumped = board.stats.jumped + 1
            events[#events + 1] = { type = "jumped" }
        end

        if p.invuln <= 0 and board.state == "PLAYING"
            and Logic.AABBOverlap(pcx, pcy, P_HALF_W, P_HALF_H, b.x, b.y, B_HALF, B_HALF) then
            self:_ApplyHit(board, events)
            if board.state ~= "PLAYING" then return end
        end
    end
end

-- ============================================================
-- Haupt-Update (vom Engine-GameLoop pro Frame aufgerufen)
-- ============================================================
function Logic:Update(board, dt)
    local events = {}
    if not board or board.state ~= "PLAYING" then return events end

    board.time = board.time + dt
    if board.bannerT > 0 then board.bannerT = board.bannerT - dt end
    if board.flashT > 0 then board.flashT = board.flashT - dt end

    local p = board.player
    if p.invuln > 0 then p.invuln = p.invuln - dt end

    -- Bonus-Countdown (alle 2 s -100); bei 0 geht ein Leben verloren
    board._bonusAcc = board._bonusAcc + dt
    while board._bonusAcc >= 2 do
        board._bonusAcc = board._bonusAcc - 2
        board.bonus = math.max(0, board.bonus - 100)
    end
    if board.bonus <= 0 then
        events[#events + 1] = { type = "timeout" }
        self:_ApplyHit(board, events)
        if board.state ~= "PLAYING" then return events end
    end

    board.troll.animT = board.troll.animT + dt
    if board.troll.throwT > 0 then board.troll.throwT = board.troll.throwT - dt end

    self:_UpdatePlayer(board, dt, events)
    if board.state ~= "PLAYING" then return events end

    self:_UpdateBarrels(board, dt)
    self:_CheckCollisions(board, events)
    if board.state ~= "PLAYING" then return events end

    -- Rettung: Spieler steht auf dem Sims neben der Prinzessin
    if p.floor == Logic.LEDGE_INDEX and p.state == "GROUND"
        and math.abs(p.x - board.princess.x) < 26 then
        self:_AdvanceLevel(board, events)
    end

    return events
end
