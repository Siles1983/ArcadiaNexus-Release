-- ============================================================
--  ArgusOrbitDefense – Logic.lua
--  Physik, Kollision, Splitting, Fel Hunter, Power-Ups, Projektile.
--  KEIN UI, KEINE WoW-API-Calls.
--
--  Verantwortlichkeiten:
--    - Spielfeld-Konstanten & Schwierigkeits-Definitionen
--    - State-Verwaltung (NewState)
--    - Schiff-Physik (Schub, Drehen, Trägheit, Geschwindigkeitsbegrenzung)
--    - Screen-Wrapping (Schiff, Meteore, Projektile, Fel Hunter)
--    - Meteor-Spawn & Splitting (BIG → MEDIUM → SMALL)
--    - Kreis-Kollision (Projektile↔Meteore, Projektile↔Hunter,
--                       Objekte↔Schiff, Hunter-Projektile↔Schiff)
--    - Fel Hunter (Tracking, Schuss)
--    - Power-Up Drop, Einsammeln, Timer
--    - Projektil-System (Schuss spawnen, lifetime)
--    - Score-Formel
--    - Respawn-System
--    - Wave/Level-Management
--    - Tick(): gibt actions-Tabelle zurück (keine WoW-Calls)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AOD_Logic = {}
local Logic = ArcadiaNexus.AOD_Logic

-- ── Spielfeld-Konstanten ──────────────────────────────────────
Logic.FIELD_W      = 560
Logic.FIELD_H      = 384

-- Laufzeit-Synchronisation: wird vom Renderer via OnShow gesetzt
function Logic:SetFieldSize(w, h)
    self.FIELD_W = w
    self.FIELD_H = h
end

-- Schiff
Logic.TURN_SPEED   = 3.2      -- Rad/s
Logic.THRUST       = 260      -- Pixel/s²
Logic.DRAG         = 1.2      -- Dämpfung pro Sekunde
Logic.MAX_SPEED    = 320      -- Pixel/s
Logic.SHIP_RADIUS  = 14
Logic.RESPAWN_INV  = 3.0      -- Sekunden Unverwundbarkeit nach Respawn

-- Projektile
Logic.BULLET_SPEED    = 480   -- Pixel/s
Logic.BULLET_LIFETIME = 1.4   -- Sekunden
Logic.SHOOT_COOLDOWN  = 0.35  -- Sekunden zwischen Schüssen (normal)
Logic.RAPID_COOLDOWN  = 0.12  -- Sekunden (Rapid Fire)
Logic.MAX_BULLETS     = 8
Logic.MAX_BULLETS_RAPID = 12
Logic.BULLET_RADIUS      = 3
Logic.BULLET_WRAP_RADIUS = 28   -- Wrap-Trigger: entspricht WRAP_MARGIN damit Bullet sofort an der Feldkante wrappt

-- Meteore
-- radius     = Kollisions-Hitbox (CircleHit)
-- wrapRadius = Wrap-Trigger (Rand-Wechsel) — entspricht dem Sprite-Radius
Logic.METEOR_DEFS = {
    BIG    = { radius=20, wrapRadius=38, speedMin=40,  speedMax=70,  points=20  },
    MEDIUM = { radius=12, wrapRadius=22, speedMin=70,  speedMax=110, points=50  },
    SMALL  = { radius=7,  wrapRadius=14, speedMin=110, speedMax=170, points=100 },
}
Logic.SPLIT_ANGLE_OFFSET_MIN = math.rad(20)
Logic.SPLIT_ANGLE_OFFSET_MAX = math.rad(50)
Logic.SPLIT_SPEED_MIN = 1.3
Logic.SPLIT_SPEED_MAX = 1.6

-- Fel Hunter
Logic.HUNTER_RADIUS     = 10
Logic.HUNTER_SPEED_MIN  = 90
Logic.HUNTER_SPEED_MAX  = 140
Logic.HUNTER_ACCEL      = 120   -- Pixel/s² Tracking-Beschleunigung
Logic.MAX_HUNTER_SPEED  = 160
Logic.HUNTER_POINTS     = 250
Logic.HUNTER_BULLET_RADIUS   = 4
Logic.HUNTER_BULLET_SPEED    = 260
Logic.HUNTER_BULLET_LIFETIME = 2.0

-- Power-Ups
Logic.PU_LIFETIME      = 8.0   -- Sekunden bis Drop verschwindet
Logic.PU_COLLECT_RADIUS= 12
Logic.PU_DROP_RADIUS   = 8
Logic.SHIELD_DURATION  = 6.0
Logic.RAPID_DURATION   = 8.0
Logic.SPREAD_DURATION  = 8.0
Logic.BOMB_RADIUS      = 120   -- Naaru-Bombe Wirkungsradius
Logic.MAX_LIVES        = 5

-- Wave/Endless
Logic.WAVE_SPEED_SCALE = 1.08  -- Geschwindigkeitsmultiplikator pro Wave
Logic.BETWEEN_WAVES    = 2.0   -- Sekunden Pause zwischen Waves

-- ── Schwierigkeits-Definitionen ───────────────────────────────
Logic.DIFFICULTY_DEFS = {
    easy   = {
        startMeteors   = 3,
        speedMul       = 0.8,
        hunterWave     = 5,
        hunterLevel    = 8,
        hunterShootRate= 5.0,
        puDropRate     = 0.30,
        scoreFac       = 1.0,
        startLives     = 5,
    },
    normal = {
        startMeteors   = 4,
        speedMul       = 1.0,
        hunterWave     = 3,
        hunterLevel    = 5,
        hunterShootRate= 4.0,
        puDropRate     = 0.20,
        scoreFac       = 1.5,
        startLives     = 3,
    },
    hard   = {
        startMeteors   = 5,
        speedMul       = 1.3,
        hunterWave     = 2,
        hunterLevel    = 3,
        hunterShootRate= 2.5,
        puDropRate     = 0.10,
        scoreFac       = 2.5,
        startLives     = 3,
    },
}

-- ── Level-Definitionen (Level-Modus, 30 Level) ───────────────
-- Jede Zeile: { big, medium, small, hunters }
Logic.LEVEL_DEFS = {
    [1]  = { big=2, medium=0, small=0, hunters=0 },
    [2]  = { big=3, medium=0, small=0, hunters=0 },
    [3]  = { big=3, medium=1, small=0, hunters=0 },
    [4]  = { big=3, medium=2, small=0, hunters=0 },
    [5]  = { big=3, medium=2, small=1, hunters=0 },
    [6]  = { big=4, medium=1, small=1, hunters=0 },
    [7]  = { big=4, medium=2, small=1, hunters=0 },
    [8]  = { big=4, medium=2, small=2, hunters=0 },
    [9]  = { big=4, medium=3, small=1, hunters=0 },
    [10] = { big=5, medium=2, small=2, hunters=0 },
    [11] = { big=5, medium=2, small=2, hunters=1 },
    [12] = { big=5, medium=3, small=2, hunters=1 },
    [13] = { big=5, medium=3, small=3, hunters=1 },
    [14] = { big=6, medium=2, small=2, hunters=1 },
    [15] = { big=6, medium=3, small=2, hunters=2 },
    [16] = { big=6, medium=3, small=3, hunters=2 },
    [17] = { big=6, medium=4, small=2, hunters=2 },
    [18] = { big=7, medium=3, small=3, hunters=2 },
    [19] = { big=7, medium=4, small=3, hunters=2 },
    [20] = { big=7, medium=4, small=4, hunters=3 },
    [21] = { big=7, medium=5, small=3, hunters=3 },
    [22] = { big=8, medium=4, small=4, hunters=3 },
    [23] = { big=8, medium=5, small=4, hunters=3 },
    [24] = { big=8, medium=5, small=5, hunters=4 },
    [25] = { big=9, medium=4, small=4, hunters=4 },
    [26] = { big=9, medium=5, small=5, hunters=4 },
    [27] = { big=9, medium=6, small=5, hunters=4 },
    [28] = { big=10,medium=5, small=5, hunters=5 },
    [29] = { big=10,medium=6, small=5, hunters=5 },
    [30] = { big=10,medium=6, small=6, hunters=6 },
}

-- ── Hilfsfunktionen (interne Mathematik) ─────────────────────
local function RandBetween(a, b)
    return a + math.random() * (b - a)
end

local function CircleHit(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return (dx*dx + dy*dy) < (a.radius + b.radius)^2
end

-- WRAP_MARGIN: Pixel-Überlauf über den Rand bevor der Wrap auslöst.
-- 0  = Wrap sobald der Sprite-Rand die Feldkante berührt
-- >0 = Objekt muss N Pixel in den Rand eindringen bevor Wrap feuert
-- Wert 28 = kalibriert auf das Schiff-Sprite (28×28px, Radius 14)
local WRAP_MARGIN = 28

local function Wrap(obj, W, H)
    local r = (obj.wrapRadius or obj.radius or 0) - WRAP_MARGIN
    if obj.x - r > W then obj.x = obj.x - W - r * 2 end
    if obj.x + r < 0 then obj.x = obj.x + W + r * 2 end
    if obj.y - r > H then obj.y = obj.y - H - r * 2 end
    if obj.y + r < 0 then obj.y = obj.y + H + r * 2 end
end

-- Richtungswinkel zwischen zwei Punkten (Radiant)
local function AngleTo(fx, fy, tx, ty)
    return math.atan2(ty - fy, tx - fx)
end

-- Sicherer Spawn-Abstand zum Schiff (mind. 100px)
local function SafeSpawnPos(W, H, shipX, shipY, minDist)
    local x, y, tries = 0, 0, 0
    repeat
        -- Spawn am Rand
        local edge = math.random(4)
        if edge == 1 then      x = RandBetween(0, W); y = 0
        elseif edge == 2 then  x = RandBetween(0, W); y = H
        elseif edge == 3 then  x = 0;                  y = RandBetween(0, H)
        else                   x = W;                  y = RandBetween(0, H)
        end
        tries = tries + 1
        local dx = x - shipX
        local dy = y - shipY
        if dx*dx + dy*dy >= minDist*minDist then break end
    until tries > 20
    return x, y
end

-- ── State ─────────────────────────────────────────────────────
function Logic:NewState(difficulty, gameMode, savedProgress)
    local def  = self.DIFFICULTY_DEFS[difficulty] or self.DIFFICULTY_DEFS.normal
    local mode = gameMode or "endless"

    local s = {
        difficulty   = difficulty or "normal",
        gameMode     = mode,
        diffDef      = def,

        -- Schiff
        ship = {
            x        = self.FIELD_W / 2,
            y        = self.FIELD_H / 2,
            vx       = 0,
            vy       = 0,
            angle    = 0,        -- 0 = nach oben (negatives Y)
            radius   = self.SHIP_RADIUS,
            invTimer = self.RESPAWN_INV,   -- Unverwundbarkeit zu Spielbeginn
            thrusting= false,
            alive    = true,
            respawnTimer = 0,    -- > 0 während Explosion + Pause vor Respawn
        },

        -- Tastatur-Flags (kontinuierlich im Tick ausgewertet)
        keyLeft    = false,
        keyRight   = false,
        keyThrust  = false,
        keyFire    = false,

        -- Projektile (Spieler)
        bullets    = {},
        shootTimer = 0,   -- Abkühlzeit bis nächster Schuss

        -- Meteore: { x,y,vx,vy,radius,size,points,rotAngle,rotSpeed }
        meteors    = {},

        -- Fel Hunter: { x,y,vx,vy,radius,shootTimer,points }
        hunters    = {},

        -- Hunter-Projektile: { x,y,vx,vy,radius,lifetime }
        hunterBullets = {},

        -- Power-Up Drops: { x,y,puType,lifetime,radius }
        powerDrops = {},

        -- Aktive Power-Ups
        shieldTimer = nil,
        rapidTimer  = nil,
        spreadTimer = nil,

        -- Score & Leben
        score      = 0,
        scoreFac   = def.scoreFac,
        lives      = def.startLives,

        -- Wave / Level
        wave       = 1,
        level      = 1,
        waveTimer  = 0,     -- Countdown zwischen Waves (Endless)
        wavePause  = false, -- true während Zwischen-Wave-Pause
        meteorCount= 0,     -- Verbleibende Meteore (inkl. noch zu spawnende Splits)
        allClear   = false, -- true wenn alle Meteore + Hunter weg

        -- Endless: Geschwindigkeitsmultiplikator (steigt pro Wave)
        waveSpeedMul = 1.0,

        -- Spielzustand
        gameOver   = false,
        win        = false,  -- Level-Modus: alle 30 Level geschafft
    }

    -- Gespeicherten Fortschritt laden
    if savedProgress then
        s.level    = savedProgress.level or 1
        s.score    = savedProgress.score or 0
        s.lives    = savedProgress.lives or def.startLives
        s.wave     = savedProgress.level or 1  -- im Level-Modus = Level-Nummer
        s.difficulty = savedProgress.diff or difficulty
        s.gameMode   = savedProgress.mode or mode
        s.diffDef    = self.DIFFICULTY_DEFS[s.difficulty] or def
        s.scoreFac   = s.diffDef.scoreFac
    end

    return s
end

-- ── Welle/Level initialisieren ───────────────────────────────
function Logic:SpawnWave(state)
    local def     = state.diffDef
    local W, H    = self.FIELD_W, self.FIELD_H
    local sx, sy  = state.ship.x, state.ship.y

    -- Geschwindikeitsmultiplikator für diese Wave
    local speedMul = def.speedMul * state.waveSpeedMul

    local count = 0

    if state.gameMode == "levels" then
        local levelNum = math.min(state.level, 30)
        local ld = self.LEVEL_DEFS[levelNum] or self.LEVEL_DEFS[30]

        for _ = 1, ld.big    do local mx,my = SafeSpawnPos(W,H,sx,sy,120); self:_SpawnMeteorAt("BIG",    mx,my,speedMul,state) end
        for _ = 1, ld.medium do local mx,my = SafeSpawnPos(W,H,sx,sy,100); self:_SpawnMeteorAt("MEDIUM", mx,my,speedMul,state) end
        for _ = 1, ld.small  do local mx,my = SafeSpawnPos(W,H,sx,sy,80);  self:_SpawnMeteorAt("SMALL",  mx,my,speedMul,state) end

        local hunterLevel = def.hunterLevel or 5
        if state.level >= hunterLevel then
            for _ = 1, ld.hunters do
                local hx, hy = SafeSpawnPos(W, H, sx, sy, 150)
                self:_SpawnHunter(hx, hy, def, state)
            end
        end
    else
        -- Endless-Modus: pro Wave +1 BIG, alle 5 Wellen zusätzlicher Bonus
        local baseCount = (def.startMeteors or 4) + (state.wave - 1)
        local bonusCount = math.floor((state.wave - 1) / 5)  -- +1 pro 5 Wellen
        local totalCount = baseCount + bonusCount
        for _ = 1, totalCount do
            local mx, my = SafeSpawnPos(W, H, sx, sy, 120)
            self:_SpawnMeteorAt("BIG", mx, my, speedMul, state)
            count = count + 1
        end

        -- Fel Hunter ab definierter Wave
        local hunterWave = def.hunterWave or 3
        if state.wave >= hunterWave then
            local numHunters = math.floor((state.wave - hunterWave) / 2) + 1
            numHunters = math.min(numHunters, 4)
            for _ = 1, numHunters do
                local hx, hy = SafeSpawnPos(W, H, sx, sy, 150)
                self:_SpawnHunter(hx, hy, def, state)
            end
        end
    end

    state.allClear = false
    state.wavePause = false
end

-- Meteor spawnen (interner Helper)
function Logic:_SpawnMeteorAt(size, x, y, speedMul, state)
    local def  = self.METEOR_DEFS[size]
    local spd  = RandBetween(def.speedMin, def.speedMax) * (speedMul or 1.0)
    local ang  = math.random() * math.pi * 2
    local m = {
        x        = x,
        y        = y,
        vx       = math.cos(ang) * spd,
        vy       = math.sin(ang) * spd,
        radius     = def.radius,
        wrapRadius = def.wrapRadius,
        size     = size,
        points   = def.points,
        rotAngle = math.random() * math.pi * 2,
        rotSpeed = RandBetween(0.5, 2.5) * (math.random(2) == 1 and 1 or -1),
        texType  = math.random(3),   -- 1/2/3 → meteo01/02/03
    }
    table.insert(state.meteors, m)
end

-- Overload: SafeSpawnPos gibt x,y als zwei Rückgabewerte
function Logic:_SpawnMeteorAtXY(size, x, y, speedMul, state)
    local def  = self.METEOR_DEFS[size]
    local spd  = RandBetween(def.speedMin, def.speedMax) * (speedMul or 1.0)
    local ang  = math.random() * math.pi * 2
    local m = {
        x        = x,
        y        = y,
        vx       = math.cos(ang) * spd,
        vy       = math.sin(ang) * spd,
        radius     = def.radius,
        wrapRadius = def.wrapRadius,
        size     = size,
        points   = def.points,
        rotAngle = math.random() * math.pi * 2,
        rotSpeed = RandBetween(0.5, 2.5) * (math.random(2) == 1 and 1 or -1),
    }
    table.insert(state.meteors, m)
end

-- Meteor splitten
function Logic:_SplitMeteor(meteor, state)
    local speedMul = state.diffDef.speedMul * state.waveSpeedMul
    local currSpeed = math.sqrt(meteor.vx^2 + meteor.vy^2)
    local currAngle = math.atan2(meteor.vy, meteor.vx)

    local nextSize = nil
    if meteor.size == "BIG"    then nextSize = "MEDIUM"
    elseif meteor.size == "MEDIUM" then nextSize = "SMALL"
    end
    if not nextSize then return end

    for i = 1, 2 do
        local offset = RandBetween(self.SPLIT_ANGLE_OFFSET_MIN, self.SPLIT_ANGLE_OFFSET_MAX)
        local sign   = (i == 1) and 1 or -1
        local ang    = currAngle + offset * sign
        local spd    = currSpeed * RandBetween(self.SPLIT_SPEED_MIN, self.SPLIT_SPEED_MAX)
        local def    = self.METEOR_DEFS[nextSize]
        local m = {
            x        = meteor.x,
            y        = meteor.y,
            vx       = math.cos(ang) * spd,
            vy       = math.sin(ang) * spd,
            radius     = def.radius,
            wrapRadius = def.wrapRadius,
            size     = nextSize,
            points   = def.points,
            rotAngle = math.random() * math.pi * 2,
            rotSpeed = RandBetween(0.5, 2.5) * (math.random(2) == 1 and 1 or -1),
            texType  = meteor.texType or math.random(3),  -- erbt Typ vom Eltern-Meteor
        }
        table.insert(state.meteors, m)
    end
end

-- Fel Hunter spawnen
function Logic:_SpawnHunter(x, y, def, state)
    local spd = RandBetween(self.HUNTER_SPEED_MIN, self.HUNTER_SPEED_MAX)
    local ang = math.random() * math.pi * 2
    local h = {
        x          = x,
        y          = y,
        vx         = math.cos(ang) * spd * 0.5,
        vy         = math.sin(ang) * spd * 0.5,
        radius     = self.HUNTER_RADIUS,
        shootTimer = RandBetween(2.0, def.hunterShootRate or 4.0),
        points     = self.HUNTER_POINTS,
        maxSpeed   = spd,
        thrusting  = false,
    }
    table.insert(state.hunters, h)
end

-- ── Power-Up Drop ─────────────────────────────────────────────
local PU_TYPES = { "SHIELD", "RAPID", "SPREAD", "BOMB", "LIFE" }

function Logic:_MaybeDropPowerUp(x, y, dropRate, state)
    if math.random() > dropRate then return end
    local puType = PU_TYPES[math.random(#PU_TYPES)]
    table.insert(state.powerDrops, {
        x        = x,
        y        = y,
        puType   = puType,
        lifetime = self.PU_LIFETIME,
        radius   = self.PU_DROP_RADIUS,
    })
end

function Logic:_ApplyPowerUp(puType, state, actions)
    if puType == "SHIELD" then
        -- Stacking: Timer addieren, max. doppelte Laufzeit
        local current = state.shieldTimer or 0
        state.shieldTimer = math.min(current + self.SHIELD_DURATION, self.SHIELD_DURATION * 2)
    elseif puType == "RAPID" then
        local current = state.rapidTimer or 0
        state.rapidTimer = math.min(current + self.RAPID_DURATION, self.RAPID_DURATION * 2)
    elseif puType == "SPREAD" then
        local current = state.spreadTimer or 0
        state.spreadTimer = math.min(current + self.SPREAD_DURATION, self.SPREAD_DURATION * 2)
    elseif puType == "BOMB" then
        -- Alle Objekte in Radius zerstören — kein Split, Bombe = Totalvernichtung
        state.usedBomb = true   -- Achievement-Tracking AOD_NAARU
        local bx, by = state.ship.x, state.ship.y
        local R2 = self.BOMB_RADIUS^2
        local toRemove = {}
        for i, m in ipairs(state.meteors) do
            local dx = m.x - bx; local dy = m.y - by
            if dx*dx + dy*dy <= R2 then
                toRemove[i] = true
                state.score = state.score + math.floor(m.points * state.scoreFac * (1 + (state.wave-1)*0.05))
                table.insert(actions, { type="meteor_destroyed", meteor=m, bomb=true })
                table.insert(actions, { type="stat_meteor" })
            end
        end
        for i = #state.meteors, 1, -1 do
            if toRemove[i] then table.remove(state.meteors, i) end
        end
        -- Hunter ebenfalls
        local toRemoveH = {}
        for i, h in ipairs(state.hunters) do
            local dx = h.x - bx; local dy = h.y - by
            if dx*dx + dy*dy <= R2 then
                toRemoveH[i] = true
                state.score = state.score + math.floor(self.HUNTER_POINTS * state.scoreFac)
                table.insert(actions, { type="hunter_destroyed", hunter=h, bomb=true })
                table.insert(actions, { type="stat_hunter" })
            end
        end
        for i = #state.hunters, 1, -1 do
            if toRemoveH[i] then table.remove(state.hunters, i) end
        end
        table.insert(actions, { type="bomb_explode", x=bx, y=by })
    elseif puType == "LIFE" then
        if state.lives < self.MAX_LIVES then
            state.lives = state.lives + 1
        end
        table.insert(actions, { type="life_gained" })
    end
    if puType ~= "BOMB" and puType ~= "LIFE" then
        table.insert(actions, { type="powerup_activated", puType=puType })
    end
end

-- ── Respawn ───────────────────────────────────────────────────
function Logic:_TriggerDeath(state, actions)
    state.lives = state.lives - 1
    table.insert(actions, { type="ship_died", livesLeft=state.lives })

    if state.lives <= 0 then
        state.ship.alive = false
        state.gameOver   = true
        table.insert(actions, { type="game_over" })
    else
        state.ship.alive      = false
        state.ship.respawnTimer = 2.5  -- 1.2s Explosion + 1.3s Pause
        state.ship.vx = 0
        state.ship.vy = 0
    end
end

-- ── Haupt-Tick ────────────────────────────────────────────────
-- Gibt actions-Tabelle zurück. Kein WoW-API-Call hier.
function Logic:Tick(state, dt)
    local actions = {}
    if state.gameOver or state.win then return actions end

    local W, H = self.FIELD_W, self.FIELD_H
    local ship  = state.ship

    -- ── Respawn-Timer ─────────────────────────────────────────
    if not ship.alive then
        if ship.respawnTimer > 0 then
            ship.respawnTimer = ship.respawnTimer - dt
            if ship.respawnTimer <= 0 then
                -- Respawn
                ship.x        = W / 2
                ship.y        = H / 2
                ship.vx       = 0
                ship.vy       = 0
                ship.angle    = 0
                ship.invTimer = self.RESPAWN_INV
                ship.alive    = true
                table.insert(actions, { type="ship_respawned" })
            end
        end
        -- Während Respawn keine weiteren Updates am Schiff — handled by if ship.alive below
    end

    -- ── Schiff-Physik (nur wenn lebendig) ────────────────────
    if ship.alive then
        -- Drehen
        if state.keyLeft  then ship.angle = ship.angle - self.TURN_SPEED * dt end
        if state.keyRight then ship.angle = ship.angle + self.TURN_SPEED * dt end

        -- Schub (Winkel 0 = nach oben = negative Y-Richtung in WoW-Koordinaten)
        ship.thrusting = state.keyThrust
        if state.keyThrust then
            ship.vx = ship.vx + math.cos(ship.angle - math.pi/2) * self.THRUST * dt
            ship.vy = ship.vy + math.sin(ship.angle - math.pi/2) * self.THRUST * dt
        end

        -- Trägheit
        ship.vx = ship.vx * (1 - self.DRAG * dt)
        ship.vy = ship.vy * (1 - self.DRAG * dt)

        -- Geschwindigkeit deckeln
        local spd = math.sqrt(ship.vx^2 + ship.vy^2)
        if spd > self.MAX_SPEED then
            ship.vx = ship.vx / spd * self.MAX_SPEED
            ship.vy = ship.vy / spd * self.MAX_SPEED
        end

        -- Bewegung
        ship.x = ship.x + ship.vx * dt
        ship.y = ship.y + ship.vy * dt
        Wrap(ship, W, H)

        -- Unverwundbarkeit dekrementieren
        if ship.invTimer > 0 then
            ship.invTimer = ship.invTimer - dt
            if ship.invTimer < 0 then ship.invTimer = 0 end
        end

        -- ── Schuss ────────────────────────────────────────────
        if state.shootTimer > 0 then
            state.shootTimer = state.shootTimer - dt
        end
        local cooldown   = (state.rapidTimer and state.rapidTimer > 0) and self.RAPID_COOLDOWN or self.SHOOT_COOLDOWN
        local maxBullets = (state.rapidTimer and state.rapidTimer > 0) and self.MAX_BULLETS_RAPID or self.MAX_BULLETS

        if state.keyFire and state.shootTimer <= 0 and #state.bullets < maxBullets then
            local hasSpread = state.spreadTimer and state.spreadTimer > 0
            local angles = hasSpread
                and { ship.angle - math.rad(20), ship.angle, ship.angle + math.rad(20) }
                or  { ship.angle }

            for _, ang in ipairs(angles) do
                local dirX = math.cos(ang - math.pi/2)
                local dirY = math.sin(ang - math.pi/2)
                local nose = self.SHIP_RADIUS
                local b = {
                    x          = ship.x + dirX * nose,
                    y          = ship.y + dirY * nose,
                    vx         = dirX * self.BULLET_SPEED + ship.vx * 0.3,
                    vy         = dirY * self.BULLET_SPEED + ship.vy * 0.3,
                    angle      = ang,   -- fest beim Abschuss; folgt nicht dem Schiff
                    radius     = self.BULLET_RADIUS,
                    wrapRadius = self.BULLET_WRAP_RADIUS,
                    lifetime   = self.BULLET_LIFETIME,
                }
                table.insert(state.bullets, b)
            end
            state.shootTimer = cooldown
            table.insert(actions, { type="shoot" })
        end
    else
        ship.thrusting = false
    end

    -- ── Projektile (Spieler) bewegen & lifetime ───────────────
    do
        local toRemove = {}
        for i, b in ipairs(state.bullets) do
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            Wrap(b, W, H)
            b.lifetime = b.lifetime - dt
            if b.lifetime <= 0 then toRemove[i] = true end
        end
        for i = #state.bullets, 1, -1 do
            if toRemove[i] then table.remove(state.bullets, i) end
        end
    end

    -- ── Meteore bewegen & rotieren ────────────────────────────
    for _, m in ipairs(state.meteors) do
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt
        Wrap(m, W, H)
        m.rotAngle = m.rotAngle + m.rotSpeed * dt
    end

    -- ── Fel Hunter bewegen & schießen ────────────────────────
    do
        local toRemoveH = {}
        for i, h in ipairs(state.hunters) do
            -- Weiches Tracking
            if ship.alive then
                local dx   = ship.x - h.x
                local dy   = ship.y - h.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 1 then
                    h.vx = h.vx + (dx/dist) * self.HUNTER_ACCEL * dt
                    h.vy = h.vy + (dy/dist) * self.HUNTER_ACCEL * dt
                    h.thrusting = true
                else
                    h.thrusting = false
                end
            else
                h.thrusting = false
            end
            -- Geschwindigkeit deckeln
            local spd = math.sqrt(h.vx^2 + h.vy^2)
            if spd > (h.maxSpeed or self.MAX_HUNTER_SPEED) then
                h.vx = h.vx / spd * (h.maxSpeed or self.MAX_HUNTER_SPEED)
                h.vy = h.vy / spd * (h.maxSpeed or self.MAX_HUNTER_SPEED)
            end
            h.x = h.x + h.vx * dt
            h.y = h.y + h.vy * dt
            Wrap(h, W, H)

            -- Schuss-Cooldown
            h.shootTimer = h.shootTimer - dt
            if h.shootTimer <= 0 and ship.alive then
                local shootRate = state.diffDef.hunterShootRate or 4.0
                h.shootTimer = RandBetween(shootRate * 0.7, shootRate * 1.3)
                local ang = AngleTo(h.x, h.y, ship.x, ship.y)
                table.insert(state.hunterBullets, {
                    x        = h.x,
                    y        = h.y,
                    vx       = math.cos(ang) * self.HUNTER_BULLET_SPEED,
                    vy       = math.sin(ang) * self.HUNTER_BULLET_SPEED,
                    angle    = ang + math.pi / 2,
                    radius   = self.HUNTER_BULLET_RADIUS,
                    lifetime = self.HUNTER_BULLET_LIFETIME,
                })
                table.insert(actions, { type="hunter_shoot" })
            end
        end
    end

    -- ── Hunter-Projektile bewegen ────────────────────────────
    do
        local toRemove = {}
        for i, b in ipairs(state.hunterBullets) do
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            Wrap(b, W, H)
            b.lifetime = b.lifetime - dt
            if b.lifetime <= 0 then toRemove[i] = true end
        end
        for i = #state.hunterBullets, 1, -1 do
            if toRemove[i] then table.remove(state.hunterBullets, i) end
        end
    end

    -- ── Power-Up Drops: lifetime ──────────────────────────────
    do
        local toRemove = {}
        for i, p in ipairs(state.powerDrops) do
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then toRemove[i] = true end
        end
        for i = #state.powerDrops, 1, -1 do
            if toRemove[i] then table.remove(state.powerDrops, i) end
        end
    end

    -- ── Power-Up Timer dekrementieren ────────────────────────
    do
        if state.shieldTimer and state.shieldTimer > 0 then
            state.shieldTimer = state.shieldTimer - dt
            if state.shieldTimer <= 0 then
                state.shieldTimer = nil
                table.insert(actions, { type="powerup_expired", puType="SHIELD" })
            end
        end
        if state.rapidTimer and state.rapidTimer > 0 then
            state.rapidTimer = state.rapidTimer - dt
            if state.rapidTimer <= 0 then
                state.rapidTimer = nil
                table.insert(actions, { type="powerup_expired", puType="RAPID" })
            end
        end
        if state.spreadTimer and state.spreadTimer > 0 then
            state.spreadTimer = state.spreadTimer - dt
            if state.spreadTimer <= 0 then
                state.spreadTimer = nil
                table.insert(actions, { type="powerup_expired", puType="SPREAD" })
            end
        end
    end

    -- ── Kollisionserkennung ───────────────────────────────────

    -- 1. Spieler-Projektile ↔ Meteore
    do
        local removeBullets = {}
        local removeMeteors = {}
        for bi, b in ipairs(state.bullets) do
            for mi, m in ipairs(state.meteors) do
                if not removeMeteors[mi] and CircleHit(b, m) then
                    removeBullets[bi] = true
                    removeMeteors[mi] = true
                    local waveBonus = (state.gameMode == "endless") and (1 + (state.wave-1)*0.05) or 1.0
                    state.score = state.score + math.floor(m.points * state.scoreFac * waveBonus)
                    table.insert(actions, { type="meteor_destroyed", meteor=m })
                    -- Statistik
                    table.insert(actions, { type="stat_meteor" })
                    -- Split oder destroy
                    if m.size ~= "SMALL" then
                        self:_SplitMeteor(m, state)
                    end
                    -- Power-Up Drop
                    local dropRate = state.diffDef.puDropRate or 0.20
                    if m.size == "BIG" or m.size == "MEDIUM" then
                        self:_MaybeDropPowerUp(m.x, m.y, dropRate, state)
                    end
                    break
                end
            end
        end
        for i = #state.meteors, 1, -1 do
            if removeMeteors[i] then table.remove(state.meteors, i) end
        end
        for i = #state.bullets, 1, -1 do
            if removeBullets[i] then table.remove(state.bullets, i) end
        end
    end

    -- 2. Spieler-Projektile ↔ Fel Hunter
    do
        local removeBullets = {}
        local removeHunters = {}
        for bi, b in ipairs(state.bullets) do
            for hi, h in ipairs(state.hunters) do
                if not removeHunters[hi] and CircleHit(b, h) then
                    removeBullets[bi] = true
                    removeHunters[hi] = true
                    state.score = state.score + math.floor(h.points * state.scoreFac)
                    table.insert(actions, { type="hunter_destroyed", hunter=h })
                    table.insert(actions, { type="stat_hunter" })
                    -- Power-Up Drop (50%)
                    self:_MaybeDropPowerUp(h.x, h.y, 0.50, state)
                    break
                end
            end
        end
        for i = #state.hunters, 1, -1 do
            if removeHunters[i] then table.remove(state.hunters, i) end
        end
        for i = #state.bullets, 1, -1 do
            if removeBullets[i] then table.remove(state.bullets, i) end
        end
    end

    -- 3. Meteore ↔ Schiff (wenn verwundbar und lebendig)
    if ship.alive and ship.invTimer <= 0 and not (state.shieldTimer and state.shieldTimer > 0) then
        for _, m in ipairs(state.meteors) do
            if CircleHit(ship, m) then
                self:_TriggerDeath(state, actions)
                break
            end
        end
    end

    -- 4. Fel Hunter ↔ Schiff
    if ship.alive and ship.invTimer <= 0 and not (state.shieldTimer and state.shieldTimer > 0) and not state.gameOver then
        for _, h in ipairs(state.hunters) do
            if CircleHit(ship, h) then
                self:_TriggerDeath(state, actions)
                break
            end
        end
    end

    -- 5. Hunter-Projektile ↔ Schiff
    if ship.alive and not (state.shieldTimer and state.shieldTimer > 0) and not state.gameOver then
        local toRemove = {}
        for i, b in ipairs(state.hunterBullets) do
            if CircleHit(ship, b) then
                toRemove[i] = true
                if ship.invTimer <= 0 then
                    self:_TriggerDeath(state, actions)
                    table.insert(actions, { type="stat_bullet_intercepted" })
                    break
                end
            end
        end
        for i = #state.hunterBullets, 1, -1 do
            if toRemove[i] then table.remove(state.hunterBullets, i) end
        end
    end

    -- 6. Power-Up Drops ↔ Schiff
    if ship.alive then
        local toRemove = {}
        for i, p in ipairs(state.powerDrops) do
            local fake = { x=ship.x, y=ship.y, radius=self.SHIP_RADIUS }
            local pu   = { x=p.x,    y=p.y,    radius=self.PU_COLLECT_RADIUS }
            if CircleHit(fake, pu) then
                toRemove[i] = true
                self:_ApplyPowerUp(p.puType, state, actions)
                table.insert(actions, { type="powerup_collected", puType=p.puType })
            end
        end
        for i = #state.powerDrops, 1, -1 do
            if toRemove[i] then table.remove(state.powerDrops, i) end
        end
    end

    -- ── AllClear-Prüfung ─────────────────────────────────────
    if not state.gameOver and #state.meteors == 0 and #state.hunters == 0 then
        if not state.allClear then
            state.allClear = true
            if state.gameMode == "levels" then
                if state.level >= 30 then
                    state.win = true
                    table.insert(actions, { type="game_win" })
                else
                    table.insert(actions, { type="wave_clear", level=state.level })
                end
            else
                -- Endless: Wave abgeschlossen → Pause, dann nächste Wave
                state.waveTimer = self.BETWEEN_WAVES
                state.wavePause = true
                table.insert(actions, { type="wave_clear", wave=state.wave })
            end
        end
    end

    -- ── Wave-Pause (Endless) ──────────────────────────────────
    if state.wavePause then
        state.waveTimer = state.waveTimer - dt
        if state.waveTimer <= 0 then
            state.wave        = state.wave + 1
            state.waveSpeedMul= state.waveSpeedMul * self.WAVE_SPEED_SCALE
            state.allClear    = false
            state.wavePause   = false
            self:SpawnWave(state)
            table.insert(actions, { type="wave_started", wave=state.wave })
        end
    end

    return actions
end
