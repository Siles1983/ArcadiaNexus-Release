-- ============================================================
--  AlienDefense – Logic.lua
--  Reine Spielregeln: kein UI, keine WoW-Frames.
--
--  Separation of Concerns:
--    Logic  → Zustand & Regeln
--    Engine → Lifecycle, Input-Routing, Action-Auswertung
--    Renderer → Darstellung
--
--  Tick-Reihenfolge:
--    1. Spieler-Bewegung
--    2. Spieler-Projektile bewegen + Kollision mit Aliens
--    3. Alien-Formation bewegen (Schritt-Logik)
--    4. Alien-Projektile bewegen + Kollision mit Spieler
--    5. Waffen-Drops bewegen + Kollision mit Spieler
--    6. Waffen-Timer dekrementieren
--    7. Gewinn-/Verlust-Bedingung prüfen
-- ============================================================

ArcadiaNexus.AD_Logic = {}
local Logic = ArcadiaNexus.AD_Logic

-- ── Spielfeld-Konstanten ──────────────────────────────────────
Logic.FIELD_W      = 600
Logic.FIELD_H      = 460
Logic.FIELD_LEFT   = 0
Logic.FIELD_RIGHT  = 600
Logic.FIELD_TOP    = 0
Logic.FIELD_BOTTOM = 460   -- Aliens die diese Y-Linie erreichen → Invasion

Logic.ALIEN_W      = 40   -- Raster-Breite (Kompromiss Typ1=32, Typ2=24, Typ3=48)
Logic.ALIEN_H      = 30   -- Raster-Höhe  (Kompromiss Typ1=24, Typ2=20, Typ3=40)
Logic.ALIEN_ROWS   = 3
Logic.ALIEN_COLS   = 11
Logic.ALIEN_GAP_X  = 12  -- Abstand horizontal
Logic.ALIEN_GAP_Y  = 10  -- Abstand vertikal

Logic.PLAYER_W     = 50
Logic.PLAYER_H     = 70
Logic.PLAYER_Y     = 382  -- Laufzeit-Wert: wird von Renderer via Logic:SetFieldSize() gesetzt

-- Multi-Box Hitboxen Spieler (3 Zonen, pixel-exakt aus TGA-Analyse)
Logic.PLAYER_HITBOXES = {
    { offX=14, offY= 0, w=22, h=22 },  -- Spitze  (oben, schmal)
    { offX= 6, offY=22, w=38, h=20 },  -- Körper  (mitte)
    { offX= 0, offY=42, w=50, h=25 },  -- Basis   (unten, breit)
}

-- Alien Typ 1 (32x24) — volle Textur
Logic.ALIEN_HB_OX  = 0
Logic.ALIEN_HB_OY  = 0
Logic.ALIEN_HB_W   = 32
Logic.ALIEN_HB_H   = 24

-- Alien Typ 2 (24x20) — volle Textur
Logic.ALIEN2_HB_OX = 0
Logic.ALIEN2_HB_OY = 0
Logic.ALIEN2_HB_W  = 24
Logic.ALIEN2_HB_H  = 20

-- Alien Typ 3 (48x40) — volle Textur
Logic.ALIEN3_HB_OX = 0
Logic.ALIEN3_HB_OY = 0
Logic.ALIEN3_HB_W  = 48
Logic.ALIEN3_HB_H  = 40

Logic.SHOT_W       = 13
Logic.SHOT_H       = 26
Logic.SHOT_SPD     = 320  -- px/s (Spieler-Schuss nach oben)

Logic.ALIEN_SHOT_W = 11
Logic.ALIEN_SHOT_H = 23
Logic.ALIEN_SHOT_SPD = 160  -- px/s (nach unten)

Logic.DROP_W       = 10
Logic.DROP_H       = 10
Logic.DROP_SPD     = 60   -- px/s (Waffen-Drop fällt nach unten)
Logic.DROP_DURATION = 15  -- Sekunden

-- ── Alien-Typen ────────────────────────────────────────────────
Logic.ALIEN_TYPES = {
    [1] = { name="GRUNT",   points=10, dropChance=0.10 },
    [2] = { name="SOLDIER", points=20, dropChance=0.15 },
    [3] = { name="ELITE",   points=30, dropChance=0.20 },
}

-- ── Waffen-Feuerrate ──────────────────────────────────────────
Logic.WEAPON_FIRE_RATES = {
    SINGLE = 0.25,
    DOUBLE = 0.40,
    LASER  = 0.80,
}

-- ── Schwierigkeits-Definitionen ────────────────────────────────
Logic.DIFFICULTY_DEFS = {
    easy   = { playerSpd=200, stepRate=1.00, alienFireRate=3.0, lives=5, scoreFac=1.00, accelPerWave=0.00 },
    normal = { playerSpd=180, stepRate=0.65, alienFireRate=1.8, lives=3, scoreFac=1.25, accelPerWave=0.10 },
    hard   = { playerSpd=160, stepRate=0.40, alienFireRate=0.9, lives=1, scoreFac=2.00, accelPerWave=0.15 },
}

-- ── NewState ──────────────────────────────────────────────────
function Logic:NewState(diff, savedProgress, startEndless)
    local def = self.DIFFICULTY_DEFS[diff] or self.DIFFICULTY_DEFS.easy
    local s = {
        difficulty       = diff,
        playerSpd        = def.playerSpd,
        baseStepRate     = def.stepRate,
        baseAlienFire    = def.alienFireRate,
        scoreFac         = def.scoreFac,
        accelPerWave     = def.accelPerWave,

        lives            = def.lives,
        score            = 0,
        wave             = 1,
        highScore        = 0,
        elapsedSecs      = 0,
        endlessMode      = startEndless and true or false,
        endlessSpeedBonus = 0,
        perfectWave      = true,   -- kein Leben verloren in aktueller Welle

        -- Spieler
        playerX          = (self.FIELD_W - self.PLAYER_W) / 2,
        keyLeft          = false,
        keyRight         = false,
        keyFire          = false,
        fireCooldown     = 0,

        -- Waffen
        activeWeapon     = "SINGLE",
        weaponTimer      = 0,

        -- Alien-Formation
        aliens           = {},
        formationDir     = 1,
        stepTimer        = def.stepRate,
        stepRate         = def.stepRate,
        stepSize         = 6,
        descentStep      = 16,
        killedCount          = 0,
        totalKillsAllWaves   = 0,
        totalAliens          = 0,

        -- Alien-Beschuss
        alienFireTimer   = def.alienFireRate,
        alienFireRate    = def.alienFireRate,

        -- Projektile & Drops
        playerShots      = {},
        alienShots       = {},
        weaponDrops      = {},

        -- Endstatus
        gameOver         = false,
        won              = false,
        invaded          = false,
        waveWon          = false,
    }

    if savedProgress then
        s.wave  = savedProgress.wave  or 1
        s.score = savedProgress.score or 0
        s.lives = savedProgress.lives or def.lives
    end

    -- Speed-Faktor für aktuelle Welle übernehmen
    self:_ApplyWaveAccel(s)
    return s
end

-- ── Wave-Beschleunigung ────────────────────────────────────────
function Logic:_ApplyWaveAccel(s)
    local waveBonus = (s.wave - 1) * s.accelPerWave + s.endlessSpeedBonus
    s.stepRate      = math.max(0.05, s.baseStepRate  * (1.0 - waveBonus))
    s.alienFireRate = math.max(0.20, s.baseAlienFire * (1.0 - waveBonus))
    s.stepTimer     = s.stepRate
    s.alienFireTimer = s.alienFireRate
end

-- ── ParseWave ─────────────────────────────────────────────────
function Logic:ParseWave(s)
    local Levels = ArcadiaNexus.AD_Levels
    if not Levels then return end
    local waveIdx = ((s.wave - 1) % #Levels) + 1
    local entry   = Levels[waveIdx]
    if not entry then return end

    s.aliens      = {}
    s.killedCount = 0

    -- Startposition der Formation (horizontal zentriert)
    local numCols = 0
    local rows    = {}
    for line in (entry.map .. "|"):gmatch("([^|]*)|") do
        rows[#rows + 1] = line
        numCols = math.max(numCols, #line)
    end

    local formW   = numCols * (self.ALIEN_W + self.ALIEN_GAP_X) - self.ALIEN_GAP_X
    local startX  = math.floor((self.FIELD_W - formW) / 2)
    local startY  = 20   -- Formation beginnt 20px vom oberen Rand

    for row, line in ipairs(rows) do
        for col = 1, #line do
            local t = tonumber(line:sub(col, col)) or 0
            if t > 0 then
                s.aliens[#s.aliens + 1] = {
                    x     = startX + (col - 1) * (self.ALIEN_W + self.ALIEN_GAP_X),
                    y     = startY + (row - 1) * (self.ALIEN_H + self.ALIEN_GAP_Y),
                    typ   = t,
                    alive = true,
                    row   = row,
                    col   = col,
                }
            end
        end
    end

    s.totalAliens  = #s.aliens
    s.playerShots  = {}
    s.alienShots   = {}
    s.weaponDrops  = {}
    s.formationDir = 1
    s.perfectWave  = true
    self:_ApplyWaveAccel(s)

    -- Spieler zurück zur Mitte
    s.playerX = (self.FIELD_W - self.PLAYER_W) / 2
    s.keyLeft  = false
    s.keyRight = false
    s.keyFire  = false
    s.fireCooldown = 0
end

-- ── Tick (Haupt-Loop) ─────────────────────────────────────────
-- Gibt actions-Tabelle zurück.
function Logic:Tick(s, dt)
    local actions = {}
    if s.gameOver then return actions end

    s.elapsedSecs = s.elapsedSecs + dt

    -- 1. Spieler-Bewegung
    self:_MovePlayer(s, dt)

    -- 2. Spieler-Schüsse abfeuern + bewegen + Kollision
    self:_HandleFire(s, dt, actions)
    self:_MovePlayerShots(s, dt, actions)

    -- 3. Alien-Formation
    s.stepTimer = s.stepTimer - dt
    if s.stepTimer <= 0 then
        s.stepTimer = s.stepRate
        self:_MoveFormation(s, actions)
    end

    -- 4. Alien-Schüsse
    s.alienFireTimer = s.alienFireTimer - dt
    if s.alienFireTimer <= 0 then
        s.alienFireTimer = s.alienFireRate
        self:_AlienFire(s, actions)
    end
    self:_MoveAlienShots(s, dt, actions)

    -- 5. Waffen-Drops
    self:_MoveDrops(s, dt, actions)

    -- 6. Waffen-Timer
    if s.weaponTimer > 0 then
        s.weaponTimer = s.weaponTimer - dt
        if s.weaponTimer <= 0 then
            s.weaponTimer  = 0
            s.activeWeapon = "SINGLE"
            actions[#actions + 1] = { type = "weapon_expired" }
        end
    end

    -- 7. Gewinn-/Verlust-Bedingung
    self:_CheckConditions(s, actions)

    return actions
end

-- ── Spieler-Bewegung ──────────────────────────────────────────
function Logic:_MovePlayer(s, dt)
    if s.keyLeft  then s.playerX = s.playerX - s.playerSpd * dt end
    if s.keyRight then s.playerX = s.playerX + s.playerSpd * dt end
    s.playerX = math.max(0, math.min(self.FIELD_W - self.PLAYER_W, s.playerX))
end

-- ── Feuer ─────────────────────────────────────────────────────
function Logic:_HandleFire(s, dt, actions)
    s.fireCooldown = s.fireCooldown - dt
    if s.keyFire and s.fireCooldown <= 0 then
        s.fireCooldown = self.WEAPON_FIRE_RATES[s.activeWeapon] or 0.25
        self:_SpawnPlayerShots(s, actions)
    end
end

function Logic:_SpawnPlayerShots(s, actions)
    local cx = s.playerX + self.PLAYER_W / 2
    local sy = self.PLAYER_Y - self.SHOT_H

    if s.activeWeapon == "SINGLE" then
        s.playerShots[#s.playerShots + 1] = {
            x = cx - self.SHOT_W / 2, y = sy,
            isLaser = false,
        }
        actions[#actions + 1] = { type = "player_shoot", weapon = "SINGLE" }

    elseif s.activeWeapon == "DOUBLE" then
        s.playerShots[#s.playerShots + 1] = {
            x = cx - 12 - self.SHOT_W / 2, y = sy, isLaser = false,
        }
        s.playerShots[#s.playerShots + 1] = {
            x = cx + 12 - self.SHOT_W / 2, y = sy, isLaser = false,
        }
        actions[#actions + 1] = { type = "player_shoot", weapon = "DOUBLE" }

    elseif s.activeWeapon == "LASER" then
        -- Laser: sofortige Linie von Spieler bis oben
        -- Wird als spezieller Shot-Typ behandelt: isLaser=true, y=0 (Top), height=PLAYER_Y
        local laserX = cx - self.SHOT_W / 2
        -- Kollision sofort auflösen (alle Aliens in dieser X-Spalte)
        local hitAny = false
        for _, alien in ipairs(s.aliens) do
            if alien.alive then
                local hox, hoy, hw, hh = self:_AlienHB(alien.typ)
                if self:_AABBOverlap(
                    laserX, 0, self.SHOT_W, self.PLAYER_Y,
                    alien.x + hox, alien.y + hoy, hw, hh)
                then
                    alien.alive = false
                    s.killedCount          = s.killedCount + 1
                    s.totalKillsAllWaves   = s.totalKillsAllWaves + 1
                    local pts = self:_AlienPoints(alien, s)
                    s.score   = s.score + pts
                    -- Drop-Chance
                    local drop = self:_RollDrop(alien)
                    if drop then
                        s.weaponDrops[#s.weaponDrops + 1] = {
                            x     = alien.x + self.ALIEN_W / 2 - self.DROP_W / 2,
                            y     = alien.y,
                            wtype = drop,
                        }
                        actions[#actions + 1] = {
                            type  = "drop_spawned",
                            wtype = drop,
                            x     = s.weaponDrops[#s.weaponDrops].x,
                            y     = s.weaponDrops[#s.weaponDrops].y,
                        }
                    end
                    actions[#actions + 1] = {
                        type   = "alien_killed",
                        alien  = alien,
                        points = pts,
                        laser  = true,
                    }
                    hitAny = true
                end
            end
        end
        -- Laser-Schuss für Renderer (visuell) — lebt 3 Ticks für sichtbaren Effekt
        s.playerShots[#s.playerShots + 1] = {
            x = laserX, y = 0, isLaser = true, height = self.PLAYER_Y,
            _laserTicks = 3,
        }
        actions[#actions + 1] = { type = "player_shoot", weapon = "LASER", laserFlash = true }
    end
end

-- ── Spieler-Schüsse bewegen ────────────────────────────────────
function Logic:_MovePlayerShots(s, dt, actions)
    local toRemove = {}
    for i, shot in ipairs(s.playerShots) do
        if shot._laserTicks ~= nil then
            shot._laserTicks = shot._laserTicks - 1
            if shot._laserTicks <= 0 then
                toRemove[#toRemove + 1] = i
            end
            -- Laser-Kollision bereits in _SpawnPlayerShots aufgelöst — nichts mehr zu tun
        else
            shot.y = shot.y - self.SHOT_SPD * dt
            if shot.y + self.SHOT_H < 0 then
                toRemove[#toRemove + 1] = i
            else
                -- Kollision mit Aliens
                for _, alien in ipairs(s.aliens) do
                    if alien.alive then
                        local hox, hoy, hw, hh = self:_AlienHB(alien.typ)
                        if self:_AABBOverlap(
                            shot.x, shot.y, self.SHOT_W, self.SHOT_H,
                            alien.x + hox, alien.y + hoy, hw, hh)
                        then
                            alien.alive = false
                            s.killedCount          = s.killedCount + 1
                            s.totalKillsAllWaves   = s.totalKillsAllWaves + 1
                            local pts = self:_AlienPoints(alien, s)
                            s.score   = s.score + pts
                            -- Drop-Chance
                            local drop = self:_RollDrop(alien)
                            if drop then
                                s.weaponDrops[#s.weaponDrops + 1] = {
                                    x     = alien.x + self.ALIEN_W / 2 - self.DROP_W / 2,
                                    y     = alien.y,
                                    wtype = drop,
                                }
                                actions[#actions + 1] = {
                                    type  = "drop_spawned",
                                    wtype = drop,
                                    x     = s.weaponDrops[#s.weaponDrops].x,
                                    y     = s.weaponDrops[#s.weaponDrops].y,
                                }
                            end
                            actions[#actions + 1] = {
                                type   = "alien_killed",
                                alien  = alien,
                                points = pts,
                            }
                            toRemove[#toRemove + 1] = i
                            break
                        end
                    end
                end
            end
        end
    end
    -- Rückwärts entfernen
    for i = #toRemove, 1, -1 do
        table.remove(s.playerShots, toRemove[i])
    end
end

-- ── Alien-Formation bewegen ────────────────────────────────────
function Logic:_MoveFormation(s, actions)
    -- Prüfe Wand-Kollision
    local hitWall = false
    for _, alien in ipairs(s.aliens) do
        if alien.alive then
            local nextX = alien.x + s.formationDir * s.stepSize
            if nextX < self.FIELD_LEFT or nextX + self.ALIEN_W > self.FIELD_RIGHT then
                hitWall = true
                break
            end
        end
    end

    if hitWall then
        s.formationDir = -s.formationDir
        for _, alien in ipairs(s.aliens) do
            if alien.alive then
                alien.y = alien.y + s.descentStep
            end
        end
        actions[#actions + 1] = { type = "formation_descent" }
    else
        for _, alien in ipairs(s.aliens) do
            if alien.alive then
                alien.x = alien.x + s.formationDir * s.stepSize
            end
        end
    end

    -- Beschleunigung: stepRate sinkt je mehr Aliens besiegt wurden
    local totalAliens = s.totalAliens
    if totalAliens > 0 then
        local killFrac = s.killedCount / totalAliens
        -- Je mehr getötet: stepRate gegen baseStepRate * 0.2 (80% schneller max)
        local speedBonus = killFrac * 0.80
        s.stepRate = math.max(0.05, s.baseStepRate * (1.0 - speedBonus)
            * (1.0 - (s.wave - 1) * s.accelPerWave))
    end

    actions[#actions + 1] = { type = "formation_step" }
end

-- ── Alien-Beschuss ─────────────────────────────────────────────
-- Nur die unterste lebende Alien pro Spalte kann feuern.
function Logic:_AlienFire(s, actions)
    -- Unterste lebende Alien pro Spalte sammeln
    local bottomPerCol = {}
    for _, alien in ipairs(s.aliens) do
        if alien.alive then
            local c = alien.col
            if not bottomPerCol[c] or alien.y > bottomPerCol[c].y then
                bottomPerCol[c] = alien
            end
        end
    end

    -- Kandidaten in Liste
    local candidates = {}
    for _, alien in pairs(bottomPerCol) do
        candidates[#candidates + 1] = alien
    end

    if #candidates == 0 then return end

    -- Zufälligen Schützen wählen
    local shooter = candidates[math.random(#candidates)]
    local sx = shooter.x + self.ALIEN_W / 2 - self.ALIEN_SHOT_W / 2
    local sy = shooter.y + self.ALIEN_H

    s.alienShots[#s.alienShots + 1] = {
        x = sx, y = sy,
    }
    actions[#actions + 1] = { type = "alien_shoot", x = sx, y = sy }
end

-- ── Alien-Schüsse bewegen + Kollision ─────────────────────────
function Logic:_MoveAlienShots(s, dt, actions)
    local toRemove = {}
    local px = s.playerX
    local py = self.PLAYER_Y

    for i, shot in ipairs(s.alienShots) do
        shot.y = shot.y + self.ALIEN_SHOT_SPD * dt

        if shot.y >= self.FIELD_BOTTOM then
            toRemove[#toRemove + 1] = i
        else
            -- AABB gegen Spieler (Multi-Box)
            if self:_AABBOverlapMulti(
                shot.x, shot.y, self.ALIEN_SHOT_W, self.ALIEN_SHOT_H,
                px, py, self.PLAYER_HITBOXES)
            then
                s.lives = s.lives - 1
                s.perfectWave = false
                toRemove[#toRemove + 1] = i
                if s.lives <= 0 then
                    s.gameOver = true
                    actions[#actions + 1] = { type = "game_over", reason = "lives" }
                else
                    actions[#actions + 1] = { type = "player_hit", livesLeft = s.lives }
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(s.alienShots, toRemove[i])
    end
end

-- ── Waffen-Drops bewegen ──────────────────────────────────────
function Logic:_MoveDrops(s, dt, actions)
    local toRemove = {}
    local px = s.playerX
    local py = self.PLAYER_Y

    for i, drop in ipairs(s.weaponDrops) do
        drop.y = drop.y + self.DROP_SPD * dt

        if drop.y >= self.FIELD_BOTTOM then
            toRemove[#toRemove + 1] = i
        else
            -- Kollision mit Spieler (Multi-Box)
            if self:_AABBOverlapMulti(
                drop.x, drop.y, self.DROP_W, self.DROP_H,
                px, py, self.PLAYER_HITBOXES)
            then
                s.activeWeapon         = drop.wtype
                s._lastCollectedWeapon = drop.wtype
                s.weaponTimer          = self.DROP_DURATION
                toRemove[#toRemove + 1] = i
                actions[#actions + 1] = {
                    type  = "weapon_collected",
                    wtype = drop.wtype,
                }
            end
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(s.weaponDrops, toRemove[i])
    end
end

-- ── Gewinn-/Verlust-Bedingung ──────────────────────────────────
function Logic:_CheckConditions(s, actions)
    if s.gameOver then return end

    -- Invasion: Alien hat FIELD_BOTTOM erreicht
    for _, alien in ipairs(s.aliens) do
        if alien.alive and (alien.y + self.ALIEN_H) >= self.FIELD_BOTTOM then
            s.gameOver = true
            s.invaded  = true
            actions[#actions + 1] = { type = "game_over", reason = "invasion" }
            return
        end
    end

    -- Alle Aliens besiegt → Welle gewonnen
    local aliveCount = 0
    for _, alien in ipairs(s.aliens) do
        if alien.alive then aliveCount = aliveCount + 1 end
    end

    if aliveCount == 0 then
        -- Perfekt-Bonus
        if s.perfectWave then
            s.score = s.score + 500
            actions[#actions + 1] = { type = "perfect_wave_bonus", bonus = 500 }
        end
        actions[#actions + 1] = { type = "wave_cleared" }
    end
end

-- ── Nächste Welle vorbereiten ─────────────────────────────────
function Logic:AdvanceWave(s)
    local Levels = ArcadiaNexus.AD_Levels
    local maxWaves = Levels and #Levels or 1
    s.wave = s.wave + 1

    -- Endless-Modus ab Welle maxWaves+1
    if s.wave > maxWaves then
        s.endlessMode = true
        s.endlessSpeedBonus = s.endlessSpeedBonus + 0.15
    end

    -- Waffe zurücksetzen
    s.activeWeapon = "SINGLE"
    s.weaponTimer  = 0

    self:ParseWave(s)
end

-- ── Hilfsfunktionen ───────────────────────────────────────────
function Logic:_AABBOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx
       and ay < by + bh and ay + ah > by
end

-- Multi-Box Kollision: Projektil gegen Liste von Hitboxen (mit World-Offset px/py)
function Logic:_AABBOverlapMulti(ax, ay, aw, ah, px, py, hitboxes)
    for _, hb in ipairs(hitboxes) do
        if self:_AABBOverlap(ax, ay, aw, ah,
            px + hb.offX, py + hb.offY, hb.w, hb.h) then
            return true
        end
    end
    return false
end

-- Gibt die Hitbox-Werte für einen Alien-Typ zurück
function Logic:_AlienHB(typ)
    if typ == 2 then
        return self.ALIEN2_HB_OX, self.ALIEN2_HB_OY, self.ALIEN2_HB_W, self.ALIEN2_HB_H
    elseif typ == 3 then
        return self.ALIEN3_HB_OX, self.ALIEN3_HB_OY, self.ALIEN3_HB_W, self.ALIEN3_HB_H
    else
        return self.ALIEN_HB_OX, self.ALIEN_HB_OY, self.ALIEN_HB_W, self.ALIEN_HB_H
    end
end
function Logic:SetFieldSize(fieldW, fieldH)
    self.FIELD_W      = fieldW
    self.FIELD_H      = fieldH
    self.FIELD_RIGHT  = fieldW
    self.FIELD_BOTTOM = fieldH
    self.PLAYER_Y     = fieldH - self.PLAYER_H - 8
end

function Logic:_AlienPoints(alien, s)
    local basePoints = self.ALIEN_TYPES[alien.typ] and self.ALIEN_TYPES[alien.typ].points or 10
    local waveFac    = 1.0 + (s.wave - 1) * 0.05
    return math.floor(basePoints * s.scoreFac * waveFac)
end

function Logic:_RollDrop(alien)
    local def = self.ALIEN_TYPES[alien.typ]
    if not def then return nil end
    if math.random() > def.dropChance then return nil end
    local weapons = { "DOUBLE", "LASER" }
    return weapons[math.random(#weapons)]
end

-- ── Waffe wechseln ────────────────────────────────────────────
-- Toggelt zwischen SINGLE und der zuletzt eingesammelten Waffe,
-- solange deren Timer noch läuft.
function Logic:CycleWeapon(s, dir)
    if s.weaponTimer <= 0 then return end  -- kein Toggle ohne aktive Waffe
    if s.activeWeapon == "SINGLE" then
        -- Zurück zur zuletzt eingesammelten Waffe
        if s._lastCollectedWeapon then
            s.activeWeapon = s._lastCollectedWeapon
        end
    else
        -- Merken + zu SINGLE wechseln
        s._lastCollectedWeapon = s.activeWeapon
        s.activeWeapon = "SINGLE"
    end
end
