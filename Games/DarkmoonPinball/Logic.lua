-- ============================================================
--  Darkmoon Pinball – Logic.lua
--  Physik, Tischzustand, Score. Kein UI, kein Timer, keine WoW-API.
--  Phase 1–7: Physik, Missionen, TableDefinition-Registry.
-- ============================================================

ArcadiaNexus.DMP_Logic = {}
local Logic = ArcadiaNexus.DMP_Logic

Logic.GAME_ID     = "DARKMOON_PINBALL"
Logic.DEFAULT_TABLE = "darkmoon_midway"
Logic.FIXED_STEP  = 1 / 120
Logic.MAX_SUBSTEPS = 8
Logic.CONTACT_PASSES = 3
Logic.HIT_COOLDOWN = 0.08
Logic.MAX_FIXED_PER_TICK = 10

local EPS = 1e-8
local HandleDrain
local ResetToPlunger

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function Len(x, y)
    return math.sqrt(x * x + y * y)
end

function Logic.SubstepsForSpeed(speed, radius, fixedStep)
    local r = radius or 7
    local step = fixedStep or Logic.FIXED_STEP
    local n = math.ceil((speed * step) / (r * 0.5))
    return Clamp(n, 1, Logic.MAX_SUBSTEPS)
end

function Logic.ClosestOnSegment(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local ab2 = abx * abx + aby * aby
    local t = 0
    if ab2 > EPS then
        t = ((px - ax) * abx + (py - ay) * aby) / ab2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    return ax + abx * t, ay + aby * t, t
end

function Logic.CircleCircleHit(ax, ay, ar, bx, by, br)
    local dx, dy = ax - bx, ay - by
    local d = Len(dx, dy)
    local minD = ar + br
    if d >= minD then return false end
    if d < EPS then
        return true, 1, 0, minD
    end
    return true, dx / d, dy / d, minD - d
end

local function ReflectVelocity(ball, nx, ny, rest)
    local vn = Dot(ball.vx, ball.vy, nx, ny)
    if vn >= 0 then return vn end
    local e = 1 + (rest or 0.7)
    ball.vx = ball.vx - e * vn * nx
    ball.vy = ball.vy - e * vn * ny
    return vn
end

local function CapSpeed(ball, maxSpeed)
    local sp = Len(ball.vx, ball.vy)
    if sp > maxSpeed and sp > EPS then
        local s = maxSpeed / sp
        ball.vx = ball.vx * s
        ball.vy = ball.vy * s
    end
end

function Logic:GetTable(tableId)
    local TR = ArcadiaNexus.DMP_TableRegistry
    if TR and TR.Get then
        return TR.Get(tableId or self.DEFAULT_TABLE)
    end
    local pack = ArcadiaNexus.DMP_Tables
    if not pack then return nil end
    return pack[tableId or self.DEFAULT_TABLE] or pack[self.DEFAULT_TABLE]
end

function Logic:ListTables()
    local TR = ArcadiaNexus.DMP_TableRegistry
    if TR and TR.List then return TR.List() end
    local def = self:GetTable()
    if def then return { def } end
    return {}
end

local function ShooterX(def)
    local TR = ArcadiaNexus.DMP_TableRegistry
    if TR and TR.ShooterX then return TR.ShooterX(def) end
    return (def and def.shooterX) or 246
end

local function MissionDef(gs, id)
    local TR = ArcadiaNexus.DMP_TableRegistry
    if TR and TR.Mission then return TR.Mission(gs.def, id) end
    return nil
end

local function CopyFlipper(src)
    return {
        id = src.id,
        px = src.px, py = src.py,
        length = src.length, radius = src.radius,
        restAngle = src.restAngle,
        activeAngle = src.activeAngle,
        swingSpeed = src.swingSpeed,
        returnSpeed = src.returnSpeed,
        restitution = src.restitution or 0.35,
        angle = src.restAngle,
        omega = 0,
        pressed = false,
    }
end

function Logic:NewState(tableId)
    local def = self:GetTable(tableId)
    assert(def, "DMP table missing")
    local balls = {}
    balls[1] = {
        x = def.spawn.x, y = def.spawn.y,
        vx = 0, vy = 0,
        r = def.ballRadius,
        active = true,
        locked = true,
    }
    local flippers = {}
    for i = 1, #def.flippers do
        flippers[i] = CopyFlipper(def.flippers[i])
    end
    return {
        tableId = def.id,
        def = def,
        phase = "ready",
        ballsRemaining = def.ballsPerGame or 3,
        score = 0,
        combo = 0,
        comboT = 0,
        maxCombo = 0,
        ballSaveT = def.ballSaveLaunch or 6,
        bumperHits = 0,
        drains = 0,
        saves = 0,
        physAcc = 0,
        lastSubsteps = 1,
        hitCool = {},
        balls = balls,
        flippers = flippers,
        inputLeft = false,
        inputRight = false,
        pendingNudgeX = 0,
        pendingNudgeY = 0,
        nudgeCd = { left = 0, right = 0, up = 0 },
        tiltHeat = 0,
        tiltWarn = 0,
        tilted = false,
        tilts = 0,
        kickbackArmed = { left = false, right = false },
        kickbackT = { left = 0, right = 0 },
        kickbacks = 0,
        outlaneSaveT = 0,
        outlaneSaves = 0,
        bumperLit = {},
        rampQual = { left = false, right = false },
        targetLit = {},
        mission = nil,
        missionsDone = 0,
        locks = 0,
        multiball = false,
        multiballs = 0,
        jackpots = 0,
        superJackpots = 0,
        scoreFrenzyT = 0,
        scoreFrenzyMul = 1,
        shield = false,
        magnetT = 0,
        magnetX = 140,
        magnetY = 180,
        extraBalls = 0,
        lastBumperId = nil,
        bumperFarmSkip = false,
        lockDarkT = 0,
        plungerPull = 0,
        plungerHeld = false,
        plungerAuto = false,
        gameOver = false,
        elapsed = 0,
        debug = {
            lastNormalX = 0,
            lastNormalY = 0,
            lastHitId = "",
            contacts = 0,
        },
    }
end

function Logic:SetFlipperInput(gs, side, down)
    if not gs or gs.gameOver then return end
    if gs.tilted then
        gs.inputLeft = false
        gs.inputRight = false
        return
    end
    if side == "left" then
        gs.inputLeft = down and true or false
    else
        gs.inputRight = down and true or false
    end
end

local function NudgeCfg(gs)
    return (gs.def and gs.def.nudge) or {}
end

function Logic:QueueNudge(gs, dir)
    if not gs or gs.gameOver or gs.phase ~= "play" then return false end
    if gs.tilted then return false end
    local cfg = NudgeCfg(gs)
    local cd = gs.nudgeCd[dir] or 0
    local heavy = cd > 0
    local load = heavy and (cfg.tiltHeavy or 0.26) or (cfg.tiltLight or 0.10)
    gs.tiltHeat = (gs.tiltHeat or 0) + load
    if gs.tiltHeat > 1 then gs.tiltHeat = 1 end
    Logic:_RefreshTilt(gs)
    if gs.tilted then return false end
    if heavy then return false end
    gs.nudgeCd[dir] = cfg.cooldown or 0.18
    local ix = cfg.impulseX or 210
    local iy = cfg.impulseY or 250
    if dir == "left" then
        gs.pendingNudgeX = gs.pendingNudgeX - ix
    elseif dir == "right" then
        gs.pendingNudgeX = gs.pendingNudgeX + ix
    elseif dir == "up" then
        gs.pendingNudgeY = gs.pendingNudgeY - iy
    else
        return false
    end
    return true
end

function Logic:_RefreshTilt(gs)
    local cfg = NudgeCfg(gs)
    local h = gs.tiltHeat or 0
    local warn = 0
    if h >= (cfg.warn3 or 0.88) then warn = 3
    elseif h >= (cfg.warn2 or 0.66) then warn = 2
    elseif h >= (cfg.warn1 or 0.33) then warn = 1
    end
    local became = (not gs.tilted) and h >= 1
    gs.tiltWarn = warn
    if became then
        gs.tilted = true
        gs.tilts = (gs.tilts or 0) + 1
        gs.inputLeft = false
        gs.inputRight = false
        gs.pendingNudgeX = 0
        gs.pendingNudgeY = 0
        gs.kickbackArmed.left = false
        gs.kickbackArmed.right = false
        gs.kickbackT.left = 0
        gs.kickbackT.right = 0
        gs.outlaneSaveT = 0
        return "tilt"
    end
    if warn > 0 and not gs.tilted then return "warn" end
    return nil
end

local function PlungerPower(gs)
    local p = gs.plungerPull or 0
    if p < 0.05 then return 1 end
    if p < 0.4 then return 0.4 end
    if p > 1 then return 1 end
    return p
end

local function StartLaunchGuide(ball, def, speed)
    local guide = def.launchGuide
    local points = guide and guide.points
    if not points or #points < 2 then return false end
    ball.x, ball.y = points[1].x, points[1].y
    ball.launchGuide = {
        distance = 0,
        speed = speed,
        x = ball.x,
        y = ball.y,
        vx = 0,
        vy = 0,
    }
    for i = 1, #points - 1 do
        local dx, dy = points[i + 1].x - points[i].x, points[i + 1].y - points[i].y
        local length = Len(dx, dy)
        if length > 0 then
            ball.vx, ball.vy = dx / length * speed, dy / length * speed
            ball.launchGuide.vx, ball.launchGuide.vy = ball.vx, ball.vy
            return true
        end
    end
    ball.launchGuide = nil
    return false
end

local function AdvanceLaunchGuide(ball, def, dt)
    local guide = def.launchGuide
    local points = guide and guide.points
    local state = ball.launchGuide
    if not state or not points or #points < 2 then return false end
    -- A rescue, test, or future mechanic may place the ball directly. In that
    -- case it has left the launch lane and must immediately use normal physics.
    if state.x and (
        Len(ball.x - state.x, ball.y - state.y) > 1
        or Len(ball.vx - (state.vx or 0), ball.vy - (state.vy or 0)) > 20
    ) then
        ball.launchGuide = nil
        return false
    end

    state.distance = (state.distance or 0) + (state.speed or 0) * dt
    local remaining = state.distance
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local length = Len(dx, dy)
        if length > 0 then
            if remaining < length then
                local t = remaining / length
                ball.x = a.x + dx * t
                ball.y = a.y + dy * t
                ball.vx = dx / length * state.speed
                ball.vy = dy / length * state.speed
                state.x, state.y = ball.x, ball.y
                state.vx, state.vy = ball.vx, ball.vy
                return true
            end
            remaining = remaining - length
        end
    end

    local a, b = points[#points - 1], points[#points]
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.max(1, Len(dx, dy))
    ball.x, ball.y = b.x, b.y
    ball.vx = dx / length * state.speed
    ball.vy = dy / length * state.speed
    ball.launchGuide = nil
    return false
end

local function FirePlunger(gs)
    local ball = gs.balls[1]
    local def = gs.def
    local power = PlungerPower(gs)
    ball.locked = false
    ball.active = true
    local launchSpeed = (def.plungerSpeed or 880) * (0.52 + 0.48 * power)
    if not StartLaunchGuide(ball, def, launchSpeed) then
        ball.x = def.spawn.x
        ball.y = def.spawn.y
        ball.vx = def.launchVx or 0
        ball.vy = -launchSpeed
    end
    ball.saveT = 0
    gs.phase = "play"
    gs.ballSaveT = def.ballSaveLaunch or 6
    gs.plungerPull = 0
    gs.plungerHeld = false
    gs.plungerAuto = false
    gs.justLaunched = true
    return true
end

function Logic:SetPlungerInput(gs, held)
    if not gs or gs.gameOver or gs.phase == "over" then return end
    if gs.phase ~= "ready" then
        gs.plungerHeld = false
        gs.plungerAuto = false
        return
    end
    if held then
        gs.plungerHeld = true
        gs.plungerAuto = false
        return
    end
    local charged = gs.plungerHeld or gs.plungerAuto or (gs.plungerPull or 0) > 0.02
    gs.plungerHeld = false
    if not charged then return end
    if (gs.plungerPull or 0) >= 0.7 then
        FirePlunger(gs)
    else
        gs.plungerAuto = true
    end
end

function Logic:Launch(gs)
    if not gs or gs.gameOver or gs.phase == "over" then return false end
    if gs.phase ~= "ready" then
        local playfield, launching = 0, false
        for i = 1, #gs.balls do
            local b = gs.balls[i]
            if b.active and not b.locked then
                if b.x < ShooterX(gs.def) then
                    playfield = playfield + 1
                elseif b.vy < -20 or b.y < 280 then
                    launching = true
                end
            end
        end
        if playfield > 0 or launching then return false end
        ResetToPlunger(gs)
    end
    if (gs.plungerPull or 0) < 0.05 then
        gs.plungerPull = 1
    end
    return FirePlunger(gs)
end

local function TickPlunger(gs, dt)
    if gs.phase ~= "ready" then
        gs.plungerHeld = false
        gs.plungerAuto = false
        return
    end
    local def = gs.def
    local charge = def.plungerCharge or 0.55
    if charge < 0.08 then charge = 0.08 end
    if gs.plungerHeld or gs.plungerAuto then
        gs.plungerPull = math.min(1, (gs.plungerPull or 0) + dt / charge)
        if gs.plungerAuto and gs.plungerPull >= 0.7 then
            FirePlunger(gs)
            return
        end
    end
    local ball = gs.balls[1]
    if ball and ball.locked and ball.active then
        ball.x = def.spawn.x
        ball.y = def.spawn.y + (gs.plungerPull or 0) * (def.plungerTravel or 26)
    end
end

local function MarkHit(gs, id, dt)
    local t = gs.hitCool[id]
    if t and t > 0 then return false end
    gs.hitCool[id] = Logic.HIT_COOLDOWN
    return true
end

local function AddScore(gs, base, qualifyCombo)
    if gs.tilted then return 0, 1 end
    local mul = 1
    if gs.combo >= 7 then mul = 4
    elseif gs.combo >= 4 then mul = 3
    elseif gs.combo >= 1 then mul = 2
    end
    local gained = math.floor(base * mul)
    if gs.scoreFrenzyT and gs.scoreFrenzyT > 0 then
        gained = math.floor(gained * (gs.scoreFrenzyMul or 2))
    end
    gs.score = gs.score + gained
    if qualifyCombo then
        gs.combo = gs.combo + 1
        if gs.combo > gs.maxCombo then gs.maxCombo = gs.combo end
        gs.comboT = gs.def.comboWindow or 2.5
    end
    return gained, mul
end

local function UpdateFlippers(gs, dt)
    for i = 1, #gs.flippers do
        local f = gs.flippers[i]
        local side = f.control or f.side or (string.find(f.id or "", "^left") and "left") or (string.find(f.id or "", "^right") and "right")
        local pressed = (not gs.tilted)
            and ((side == "left" and gs.inputLeft) or (side == "right" and gs.inputRight))
        f.pressed = pressed
        local target = pressed and f.activeAngle or f.restAngle
        local speed = pressed and f.swingSpeed or f.returnSpeed
        local prev = f.angle
        local delta = target - prev
        local maxd = speed * dt
        if delta > maxd then
            f.angle = prev + maxd
        elseif delta < -maxd then
            f.angle = prev - maxd
        else
            f.angle = target
        end
        if dt > EPS then
            f.omega = (f.angle - prev) / dt
        else
            f.omega = 0
        end
    end
end

local function FlipperPoint(f)
    local c, s = math.cos(f.angle), math.sin(f.angle)
    return f.px + c * f.length, f.py + s * f.length
end

local function FlipperVelAt(f, x, y)
    local rx, ry = x - f.px, y - f.py
    local dist = Len(rx, ry)
    local tx, ty = -math.sin(f.angle), math.cos(f.angle)
    return tx * f.omega * dist, ty * f.omega * dist
end

local function ResolveCircleSolid(ball, cx, cy, rad, rest, kick, maxSpeed)
    local hit, nx, ny, overlap = Logic.CircleCircleHit(ball.x, ball.y, ball.r, cx, cy, rad)
    if not hit then return false, 0, 0 end
    ball.x = ball.x + nx * overlap
    ball.y = ball.y + ny * overlap
    ReflectVelocity(ball, nx, ny, rest)
    if kick and kick > 0 then
        ball.vx = ball.vx + nx * kick
        ball.vy = ball.vy + ny * kick
    end
    CapSpeed(ball, maxSpeed)
    return true, nx, ny
end

local function ResolveSegment(ball, ax, ay, bx, by, rest, maxSpeed, oneSided, snx, sny)
    local qx, qy = Logic.ClosestOnSegment(ball.x, ball.y, ax, ay, bx, by)
    if oneSided then
        local nx, ny = snx, sny
        if not nx then
            local dx, dy = bx - ax, by - ay
            local len = Len(dx, dy)
            if len > EPS then
                nx, ny = -dy / len, dx / len
            else
                nx, ny = -1, 0
            end
        end
        if Dot(ball.x - qx, ball.y - qy, nx, ny) < 0 then
            return false, 0, 0
        end
    end
    local hit, nx, ny, overlap = Logic.CircleCircleHit(ball.x, ball.y, ball.r, qx, qy, 0)
    if not hit then return false, 0, 0 end
    ball.x = ball.x + nx * overlap
    ball.y = ball.y + ny * overlap
    ReflectVelocity(ball, nx, ny, rest)
    CapSpeed(ball, maxSpeed)
    return true, nx, ny
end

local function ResolveCapsule(ball, f, maxSpeed, debug)
    local bx, by = FlipperPoint(f)
    local qx, qy = Logic.ClosestOnSegment(ball.x, ball.y, f.px, f.py, bx, by)
    local hit, nx, ny, overlap = Logic.CircleCircleHit(ball.x, ball.y, ball.r, qx, qy, f.radius)
    if not hit then return false, 0, 0 end
    ball.x = ball.x + nx * overlap
    ball.y = ball.y + ny * overlap
    local fvx, fvy = FlipperVelAt(f, qx, qy)
    local rvx, rvy = ball.vx - fvx, ball.vy - fvy
    local vn = Dot(rvx, rvy, nx, ny)
    if vn < 0 then
        local e = 1 + (f.restitution or 0.35)
        ball.vx = ball.vx - e * vn * nx
        ball.vy = ball.vy - e * vn * ny
    end
    CapSpeed(ball, maxSpeed)
    if debug then
        debug.lastNormalX, debug.lastNormalY = nx, ny
        debug.lastHitId = f.id
    end
    return true, nx, ny
end

local function InRect(r, ball)
    return ball.x >= r.x1 and ball.x <= r.x2 and ball.y >= r.y1 and ball.y <= r.y2
end

local function InDrain(def, ball)
    local d = def.drain
    local points = d.points
    local r = ball.r or 0
    if points and #points >= 4 then
        -- The four points form an open drain channel: 1->2, 2->3 and 3->4
        -- are active.  The deliberately missing closing edge 4->1 is never
        -- evaluated, so the channel cannot drain a ball across its opening.
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local len2 = dx * dx + dy * dy
            if len2 > 0 then
                local t = ((ball.x - a.x) * dx + (ball.y - a.y) * dy) / len2
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
                local ox, oy = ball.x - (a.x + dx * t), ball.y - (a.y + dy * t)
                if ox * ox + oy * oy <= r * r then return true end
            end
        end
    else
        local dx, dy = d.x2 - d.x1, d.y2 - d.y1
        local len2 = dx * dx + dy * dy
        local t = 0
        if len2 > 0 then
            t = ((ball.x - d.x1) * dx + (ball.y - d.y1) * dy) / len2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
        end
        local px, py = d.x1 + dx * t, d.y1 + dy * t
        local ox, oy = ball.x - px, ball.y - py
        if ox * ox + oy * oy <= r * r then return true end
    end
    -- Last-resort safety catch: no ball may leave the bottom of the table.
    return ball.y >= (def.height or 440) + r
end

local function ClearBallTilt(gs)
    gs.tilted = false
    gs.tiltHeat = 0
    gs.tiltWarn = 0
end

local function FireReturn(gs, ball, side, actions, kind)
    local kb = gs.def.kickbacks and gs.def.kickbacks[side]
    if kb then
        ball.vx = kb.vx
        ball.vy = kb.vy
    else
        ball.vx = (side == "left") and 300 or -300
        ball.vy = -680
    end
    if side == "left" then
        if ball.x < 90 then ball.x = 90 end
    else
        if ball.x > 190 then ball.x = 190 end
    end
    if ball.y > 380 then ball.y = 380 end
    actions[#actions + 1] = { type = kind, side = side }
end

local function LiveCount(gs)
    local n = 0
    for i = 1, #gs.balls do
        local b = gs.balls[i]
        if b.active and not b.locked then n = n + 1 end
    end
    return n
end

local function MakeBall(def, opts)
    opts = opts or {}
    return {
        x = opts.x or def.spawn.x,
        y = opts.y or def.spawn.y,
        vx = opts.vx or 0,
        vy = opts.vy or 0,
        r = def.ballRadius,
        active = true,
        locked = opts.locked and true or false,
        saveT = opts.saveT or 0,
    }
end

local function StartMission(gs, id, actions)
    if gs.mission or gs.tilted then return false end
    local md = MissionDef(gs, id)
    local times = gs.def.missionTime or {}
    local need = (md and md.need) or 12
    local t = (md and md.time) or times[id] or 28
    gs.mission = {
        id = id,
        t = t,
        need = need,
        have = 0,
        nextOrder = 1,
    }
    actions[#actions + 1] = { type = "mission_start", id = id, t = gs.mission.t }
    return true
end

local function FailMission(gs, actions)
    if not gs.mission then return end
    actions[#actions + 1] = { type = "mission_fail", id = gs.mission.id }
    gs.mission = nil
end

local function GrantPower(gs, kind, actions)
    if kind == "frenzy" then
        gs.scoreFrenzyT = gs.def.frenzyTime or 8
        gs.scoreFrenzyMul = gs.def.frenzyMul or 2
        gs.magnetT = gs.def.magnetTime or 3
        gs.magnetX, gs.magnetY = (gs.def.magnet and gs.def.magnet.x) or 140, (gs.def.magnet and gs.def.magnet.y) or 180
    elseif kind == "shield" then
        gs.shield = true
        gs.kickbackArmed.left = true
        gs.kickbackArmed.right = true
        gs.kickbackT.left = gs.def.kickbackDuration or 8
        gs.kickbackT.right = gs.def.kickbackDuration or 8
    elseif kind == "extra_ball" then
        local cap = gs.def.extraBallMax or 1
        if (gs.extraBalls or 0) >= cap then
            AddScore(gs, (gs.def.scoringRules and gs.def.scoringRules.extraBallBank) or 2500, false)
        else
            gs.ballsRemaining = gs.ballsRemaining + 1
            gs.extraBalls = (gs.extraBalls or 0) + 1
        end
    end
    actions[#actions + 1] = { type = "powerup", id = kind }
end

local StartMultiball

local function CompleteMission(gs, actions)
    local m = gs.mission
    if not m then return end
    gs.missionsDone = (gs.missionsDone or 0) + 1
    local id = m.id
    gs.mission = nil
    local md = MissionDef(gs, id)
    AddScore(gs, (md and md.score) or 0, false)
    local reward = md and md.reward
    if reward == "multiball" then
        StartMultiball(gs, actions)
    elseif reward then
        GrantPower(gs, reward, actions)
    end
    actions[#actions + 1] = { type = "mission_complete", id = id }
end

StartMultiball = function(gs, actions)
    if gs.tilted or gs.multiball then return end
    gs.multiball = true
    gs.multiballs = (gs.multiballs or 0) + 1
    gs.locks = 0
    gs.lockDarkT = 0
    gs.phase = "play"
    local def = gs.def
    local save = def.mbSave or 1
    for i = 1, #gs.balls do
        local b = gs.balls[i]
        if b.active then
            b.locked = false
        end
    end
    local want = (def.multiballDefinitions and def.multiballDefinitions.balls) or 3
    if LiveCount(gs) < 1 then
        local mag = def.magnet or { x = 140, y = 180 }
        local b = gs.balls[1]
        b.active = true
        b.locked = false
        b.x, b.y = mag.x, mag.y
        b.vx, b.vy = -40, 60
    end
    local extras = want - LiveCount(gs)
    if extras < 0 then extras = 0 end
    local spots = def.mbSpawns or (def.multiballDefinitions and def.multiballDefinitions.spawns) or {
        { x = 96, y = 210, vx = -80, vy = 50 },
        { x = 184, y = 210, vx = 80, vy = 50 },
        { x = 140, y = 150, vx = 0, vy = 80 },
    }
    for i = 1, extras do
        local sp = spots[i] or spots[1]
        gs.balls[#gs.balls + 1] = MakeBall(def, {
            x = sp.x, y = sp.y, vx = sp.vx, vy = sp.vy, saveT = save,
        })
    end
    actions[#actions + 1] = { type = "multiball_start", balls = LiveCount(gs) }
end

local function OnBumperMission(gs, actions, bumperId)
    local m = gs.mission
    local mid = (gs.def.bumperBank and gs.def.bumperBank.missionId) or "bumper_overdrive"
    if not (m and m.id == mid) then return end
    if bumperId and gs.lastBumperId == bumperId then
        gs.bumperFarmSkip = not gs.bumperFarmSkip
        if gs.bumperFarmSkip then return end
    else
        gs.lastBumperId = bumperId
        gs.bumperFarmSkip = false
    end
    m.have = m.have + 1
    if m.have >= m.need then CompleteMission(gs, actions) end
end

local function TrySensors(gs, ball, actions)
    if gs.tilted then return end
    local def = gs.def
    if def.ramps then
        for i = 1, #def.ramps do
            local r = def.ramps[i]
            if InRect(r, ball) and MarkHit(gs, r.id, 0) then
                AddScore(gs, (def.scoringRules and def.scoringRules.ramp) or 150, true)
                actions[#actions + 1] = { type = "ramp_hit", id = r.id }
                local side = r.side or ((r.id == "ramp_l") and "left" or "right")
                gs.rampQual[side] = true
                local mid = (def.rampModule and def.rampModule.missionId) or "ramp_run"
                local m = gs.mission
                if m and m.id == mid then
                    m.have = m.have + 1
                    if m.have >= m.need then CompleteMission(gs, actions) end
                elseif (not m) and gs.rampQual.left and gs.rampQual.right then
                    gs.rampQual.left, gs.rampQual.right = false, false
                    StartMission(gs, mid, actions)
                end
            end
        end
    end
    if def.targets then
        for i = 1, #def.targets do
            local t = def.targets[i]
            local hit = ResolveCircleSolid(ball, t.x, t.y, t.r, def.restitution, 0, def.maxSpeed)
            if hit and MarkHit(gs, t.id, 0) then
                AddScore(gs, (def.scoringRules and def.scoringRules.target) or 120, true)
                actions[#actions + 1] = { type = "target_hit", id = t.id, order = t.order }
                gs.targetLit[t.id] = true
                local mid = (def.targetBank and def.targetBank.missionId) or "target_hunt"
                local m = gs.mission
                if m and m.id == mid then
                    if t.order == m.nextOrder then
                        m.nextOrder = m.nextOrder + 1
                        m.have = m.have + 1
                        if m.have >= m.need then CompleteMission(gs, actions) end
                    end
                elseif not m then
                    local all = true
                    for ti = 1, #def.targets do
                        if not gs.targetLit[def.targets[ti].id] then all = false break end
                    end
                    if all then
                        gs.targetLit = {}
                        StartMission(gs, mid, actions)
                    end
                end
            end
        end
    end
    if def.lock and InRect(def.lock, ball) and MarkHit(gs, "lock", 0) then
        AddScore(gs, (def.scoringRules and def.scoringRules.lock) or 200, true)
        actions[#actions + 1] = { type = "lock_hit" }
        local mid = (def.lockModule and def.lockModule.missionId) or "arcane_lock"
        local dark = gs.multiball or ((gs.lockDarkT or 0) > 0)
        if not dark then
            local m = gs.mission
            if m and m.id == mid then
                gs.locks = (gs.locks or 0) + 1
                m.have = gs.locks
                if m.have >= m.need then CompleteMission(gs, actions) end
            elseif not m then
                gs.locks = 1
                StartMission(gs, mid, actions)
                if gs.mission then gs.mission.have = 1 end
            end
        end
    end
    local jpEvery = (def.multiballDefinitions and def.multiballDefinitions.jackpotEvery) or 3
    if gs.multiball and def.jackpot and InRect(def.jackpot, ball) and MarkHit(gs, "jp", 0) then
        gs.jackpots = (gs.jackpots or 0) + 1
        local super = gs.jackpots > 0 and (gs.jackpots % jpEvery == 0)
        local pts = super and (def.superJackpotScore or 10000) or (def.jackpotScore or 2500)
        if super then gs.superJackpots = (gs.superJackpots or 0) + 1 end
        AddScore(gs, pts, true)
        actions[#actions + 1] = { type = super and "super_jackpot" or "jackpot", n = gs.jackpots }
    end
end

local function TryOutlane(gs, ball, actions)
    local lanes = gs.def.outlanes
    if not lanes then return false end
    for i = 1, #lanes do
        local lane = lanes[i]
        if InRect(lane, ball) then
            local side = lane.side
            if (not gs.tilted) and gs.kickbackArmed[side] and (gs.kickbackT[side] or 0) > 0 then
                gs.kickbackArmed[side] = false
                gs.kickbackT[side] = 0
                gs.kickbacks = (gs.kickbacks or 0) + 1
                FireReturn(gs, ball, side, actions, "kickback")
                return true
            end
            if (not gs.tilted) and (gs.outlaneSaveT or 0) > 0 then
                gs.outlaneSaveT = 0
                gs.outlaneSaves = (gs.outlaneSaves or 0) + 1
                FireReturn(gs, ball, side, actions, "outlane_save")
                return true
            end
            if (not gs.tilted) and gs.shield then
                gs.shield = false
                FireReturn(gs, ball, side, actions, "shield_save")
                return true
            end
            gs.debug.lastHitId = lane.id
            HandleDrain(gs, ball, actions)
            return true
        end
    end
    return false
end

local function TryInlane(gs, ball, actions)
    if gs.tilted then return end
    local lanes = gs.def.inlanes
    if not lanes then return end
    for i = 1, #lanes do
        local lane = lanes[i]
        if InRect(lane, ball) and MarkHit(gs, lane.id, 0) then
            local side = lane.side
            gs.kickbackArmed[side] = true
            gs.kickbackT[side] = gs.def.kickbackDuration or 8
            actions[#actions + 1] = { type = "kickback_armed", side = side }
        end
    end
end

local function ResolveWorld(gs, ball, actions)
    local def = gs.def
    local maxS = def.maxSpeed
    local rest = def.restitution
    local contacts = 0
    for _ = 1, Logic.CONTACT_PASSES do
        for i = 1, #def.walls do
            local w = def.walls[i]
            local hit, nx, ny = ResolveSegment(
                ball, w.ax, w.ay, w.bx, w.by, rest, maxS,
                w.oneSided, w.nx, w.ny
            )
            if hit then
                contacts = contacts + 1
                gs.debug.lastNormalX, gs.debug.lastNormalY = nx, ny
                gs.debug.lastHitId = w.id
            end
        end
        if def.slingshots then
            for i = 1, #def.slingshots do
                local s = def.slingshots[i]
                local hit, nx, ny = ResolveSegment(
                    ball, s.ax, s.ay, s.bx, s.by, rest, maxS,
                    s.oneSided, s.nx, s.ny
                )
                if hit then
                    contacts = contacts + 1
                    gs.debug.lastHitId = s.id
                    if s.kick and nx then
                        ball.vx = ball.vx + nx * s.kick
                        ball.vy = ball.vy + ny * s.kick
                        CapSpeed(ball, maxS)
                    end
                    if (not gs.tilted) and MarkHit(gs, s.id, 0) then
                        actions[#actions + 1] = { type = "sling_hit", id = s.id }
                    end
                end
            end
        end
        for i = 1, #def.bumpers do
            local b = def.bumpers[i]
            local kick = b.kick or def.bumperKick
            local hit, nx, ny = ResolveCircleSolid(ball, b.x, b.y, b.r, rest, kick, maxS)
            if hit then
                contacts = contacts + 1
                gs.debug.lastNormalX, gs.debug.lastNormalY = nx, ny
                gs.debug.lastHitId = b.id
                if (not gs.tilted) and MarkHit(gs, b.id, 0) then
                    gs.bumperHits = gs.bumperHits + 1
                    gs.bumperLit[b.id] = true
                    local gained, mul = AddScore(gs, b.score or 100, not gs.tilted)
                    actions[#actions + 1] = {
                        type = "bumper_hit", id = b.id, score = gained, mul = mul,
                    }
                    local allLit = true
                    for bi = 1, #def.bumpers do
                        if not gs.bumperLit[def.bumpers[bi].id] then
                            allLit = false
                            break
                        end
                    end
                    if allLit and not gs.tilted then
                        gs.bumperLit = {}
                        gs.outlaneSaveT = def.outlaneSaveDuration or 10
                        actions[#actions + 1] = { type = "outlane_save_armed", t = gs.outlaneSaveT }
                        if not gs.mission then
                            StartMission(gs, (def.bumperBank and def.bumperBank.missionId) or "bumper_overdrive", actions)
                        end
                    end
                    OnBumperMission(gs, actions, b.id)
                end
            end
        end
        local kickers = def.kickers
        if kickers then
            for i = 1, #kickers do
                local k = kickers[i]
                local hit, nx, ny = ResolveCircleSolid(ball, k.x, k.y, k.r, rest, k.kick or 0, maxS)
                if hit then
                    contacts = contacts + 1
                    gs.debug.lastNormalX, gs.debug.lastNormalY = nx, ny
                    gs.debug.lastHitId = k.id
                end
            end
        end
        local posts = def.posts
        if posts then
            for i = 1, #posts do
                local p = posts[i]
                local hit = ResolveCircleSolid(ball, p.x, p.y, p.r, rest, 0, maxS)
                if hit then
                    contacts = contacts + 1
                    gs.debug.lastHitId = p.id
                end
            end
        end
        for i = 1, #gs.flippers do
            local hit = ResolveCapsule(ball, gs.flippers[i], maxS, gs.debug)
            if hit then
                contacts = contacts + 1
                if MarkHit(gs, gs.flippers[i].id, 0) then
                    actions[#actions + 1] = { type = "flipper_hit", id = gs.flippers[i].id }
                end
            end
        end
    end
    gs.debug.contacts = contacts
end

ResetToPlunger = function(gs)
    local def = gs.def
    for i = 2, #gs.balls do
        gs.balls[i].active = false
        gs.balls[i].locked = true
        gs.balls[i].vx, gs.balls[i].vy = 0, 0
        gs.balls[i].saveT = 0
    end
    local ball = gs.balls[1]
    ball.x, ball.y = def.spawn.x, def.spawn.y
    ball.vx, ball.vy = 0, 0
    ball.launchGuide = nil
    ball.locked = true
    ball.active = true
    ball.saveT = 0
    gs.phase = "ready"
    gs.combo = 0
    gs.comboT = 0
    gs.plungerPull = 0
    gs.plungerHeld = false
    gs.plungerAuto = false
    local wasMB = gs.multiball
    gs.multiball = false
    if wasMB then
        gs.lockDarkT = gs.def.lockDark or 18
        gs.locks = 0
    end
end

local function RecoverPlungerIfStuck(gs, actions)
    if gs.gameOver or gs.phase ~= "play" then return end
    local playfield, stuck = 0, false
    for i = 1, #gs.balls do
        local b = gs.balls[i]
        if b.active and not b.locked then
            if b.x < ShooterX(gs.def) then
                playfield = playfield + 1
            elseif not (b.vy < -20 or b.y < 280) then
                stuck = true
            end
        end
    end
    if playfield == 0 and stuck then
        ResetToPlunger(gs)
        actions[#actions + 1] = { type = "ball_ready" }
    end
end

HandleDrain = function(gs, ball, actions)
    ball = ball or gs.balls[1]
    gs.drains = gs.drains + 1
    if gs.shield and not gs.tilted then
        gs.shield = false
        local side = (ball.x < 140) and "left" or "right"
        FireReturn(gs, ball, side, actions, "shield_save")
        return
    end
    if (ball.saveT or 0) > 0 then
        gs.saves = gs.saves + 1
        ball.saveT = 0
        if gs.multiball and LiveCount(gs) > 1 then
            local side = (ball.x < 140) and "left" or "right"
            FireReturn(gs, ball, side, actions, "ball_save")
            return
        end
        ResetToPlunger(gs)
        actions[#actions + 1] = { type = "ball_save" }
        return
    end
    if gs.multiball then
        ball.active = false
        ball.locked = true
        local live = LiveCount(gs)
        if live >= 2 then
            actions[#actions + 1] = { type = "mb_drain", live = live }
            return
        end
        if live == 1 then
            gs.multiball = false
            gs.lockDarkT = gs.def.lockDark or 18
            gs.locks = 0
            actions[#actions + 1] = { type = "multiball_end" }
            return
        end
    end
    if gs.ballSaveT > 0 then
        gs.saves = gs.saves + 1
        ResetToPlunger(gs)
        gs.ballSaveT = 0
        actions[#actions + 1] = { type = "ball_save" }
        return
    end
    ClearBallTilt(gs)
    FailMission(gs, actions)
    gs.kickbackArmed.left = false
    gs.kickbackArmed.right = false
    gs.kickbackT.left = 0
    gs.kickbackT.right = 0
    gs.outlaneSaveT = 0
    gs.bumperLit = {}
    gs.scoreFrenzyT = 0
    gs.magnetT = 0
    gs.ballsRemaining = gs.ballsRemaining - 1
    actions[#actions + 1] = { type = "drain", ballsRemaining = gs.ballsRemaining }
    if gs.ballsRemaining <= 0 then
        gs.gameOver = true
        gs.phase = "over"
        for i = 1, #gs.balls do
            gs.balls[i].locked = true
            gs.balls[i].active = false
        end
        actions[#actions + 1] = { type = "game_over", score = gs.score }
    else
        ResetToPlunger(gs)
        actions[#actions + 1] = { type = "ball_ready" }
    end
end

local function AntiStall(gs, ball, dt, actions)
    if ball.locked or gs.phase ~= "play" then
        ball.stallT = 0
        return
    end
    local def = gs.def
    local floorY = (def.height or 440) - 90
    local sp = Len(ball.vx, ball.vy)
    if ball.y >= floorY or sp >= 50 then
        ball.stallT = 0
        return
    end
    ball.stallT = (ball.stallT or 0) + dt
    if ball.stallT < 0.55 then return end
    local cx = (def.magnet and def.magnet.x) or ((def.width or 280) * 0.5)
    local cy = (def.magnet and def.magnet.y) or 210
    local dx, dy = cx - ball.x, cy - ball.y
    local d = Len(dx, dy)
    if d > 6 then
        ball.vx = ball.vx + (dx / d) * 220
        ball.vy = ball.vy + (dy / d) * 160
    else
        ball.vy = ball.vy + 200
    end
    ball.stallT = 0
    actions[#actions + 1] = { type = "anti_stall" }
end

function Logic:PhysicsSubstep(gs, dt, actions)
    UpdateFlippers(gs, dt)
    local def = gs.def
    local nx, ny = gs.pendingNudgeX or 0, gs.pendingNudgeY or 0
    gs.pendingNudgeX, gs.pendingNudgeY = 0, 0
    for i = 1, #gs.balls do
        local ball = gs.balls[i]
        if ball.active and (not ball.locked) and gs.phase == "play" then
            if nx ~= 0 or ny ~= 0 then
                ball.vx = ball.vx + nx
                ball.vy = ball.vy + ny
            end
            if gs.magnetT and gs.magnetT > 0 then
                local dx, dy = (gs.magnetX or 140) - ball.x, (gs.magnetY or 180) - ball.y
                local d = Len(dx, dy)
                if d > 8 then
                    ball.vx = ball.vx + (dx / d) * 220 * dt
                    ball.vy = ball.vy + (dy / d) * 220 * dt
                end
            end
            local guided = AdvanceLaunchGuide(ball, def, dt)
            if not guided then
                ball.vy = ball.vy + def.gravity * dt
                ball.x = ball.x + ball.vx * dt
                ball.y = ball.y + ball.vy * dt
                CapSpeed(ball, def.maxSpeed)
                ResolveWorld(gs, ball, actions)
                AntiStall(gs, ball, dt, actions)
                TrySensors(gs, ball, actions)
                TryInlane(gs, ball, actions)
                if TryOutlane(gs, ball, actions) then
                    -- handled
                elseif InDrain(def, ball) then
                    HandleDrain(gs, ball, actions)
                end
            else
                ball.stallT = 0
            end
            if gs.gameOver then return end
        end
    end
    RecoverPlungerIfStuck(gs, actions)
end

function Logic:Tick(gs, dt)
    if not gs or gs.gameOver then return {} end
    local actions = {}
    gs.elapsed = gs.elapsed + dt
    TickPlunger(gs, dt)
    gs.physAcc = (gs.physAcc or 0) + dt
    if gs.comboT > 0 then
        gs.comboT = gs.comboT - dt
        if gs.comboT <= 0 then
            gs.comboT = 0
            gs.combo = 0
        end
    end
    if gs.phase == "play" and gs.ballSaveT > 0 then
        gs.ballSaveT = gs.ballSaveT - dt
        if gs.ballSaveT < 0 then gs.ballSaveT = 0 end
    end
    if gs.outlaneSaveT and gs.outlaneSaveT > 0 then
        gs.outlaneSaveT = gs.outlaneSaveT - dt
        if gs.outlaneSaveT < 0 then gs.outlaneSaveT = 0 end
    end
    if gs.lockDarkT and gs.lockDarkT > 0 then
        gs.lockDarkT = gs.lockDarkT - dt
        if gs.lockDarkT < 0 then gs.lockDarkT = 0 end
    end
    for _, side in ipairs({ "left", "right" }) do
        local cd = gs.nudgeCd[side]
        if cd and cd > 0 then
            gs.nudgeCd[side] = cd - dt
            if gs.nudgeCd[side] < 0 then gs.nudgeCd[side] = 0 end
        end
        local kt = gs.kickbackT[side]
        if kt and kt > 0 then
            gs.kickbackT[side] = kt - dt
            if gs.kickbackT[side] <= 0 then
                gs.kickbackT[side] = 0
                gs.kickbackArmed[side] = false
            end
        end
    end
    if gs.nudgeCd.up and gs.nudgeCd.up > 0 then
        gs.nudgeCd.up = gs.nudgeCd.up - dt
        if gs.nudgeCd.up < 0 then gs.nudgeCd.up = 0 end
    end
    if (not gs.tilted) and gs.tiltHeat and gs.tiltHeat > 0 then
        local decay = (NudgeCfg(gs).tiltDecay or 0.20) * dt
        gs.tiltHeat = gs.tiltHeat - decay
        if gs.tiltHeat < 0 then gs.tiltHeat = 0 end
        Logic:_RefreshTilt(gs)
    end
    if gs.scoreFrenzyT and gs.scoreFrenzyT > 0 then
        gs.scoreFrenzyT = gs.scoreFrenzyT - dt
        if gs.scoreFrenzyT < 0 then gs.scoreFrenzyT = 0 end
    end
    if gs.magnetT and gs.magnetT > 0 then
        gs.magnetT = gs.magnetT - dt
        if gs.magnetT < 0 then gs.magnetT = 0 end
    end
    if gs.mission then
        gs.mission.t = gs.mission.t - dt
        if gs.mission.t <= 0 then
            FailMission(gs, actions)
        end
    end
    for i = 1, #gs.balls do
        local b = gs.balls[i]
        if b.saveT and b.saveT > 0 then
            b.saveT = b.saveT - dt
            if b.saveT < 0 then b.saveT = 0 end
        end
    end
    for id, t in pairs(gs.hitCool) do
        local nt = t - dt
        if nt <= 0 then gs.hitCool[id] = nil else gs.hitCool[id] = nt end
    end

    local step = self.FIXED_STEP
    local n = 0
    local maxSub = 1
    while gs.physAcc >= step and n < self.MAX_FIXED_PER_TICK do
        local speed = 0
        for bi = 1, #gs.balls do
            local b = gs.balls[bi]
            if b.active and not b.locked then
                local sp = Len(b.vx, b.vy)
                if sp > speed then speed = sp end
            end
        end
        local sub = self.SubstepsForSpeed(speed, gs.def.ballRadius or 7, step)
        if sub > maxSub then maxSub = sub end
        local h = step / sub
        for _ = 1, sub do
            self:PhysicsSubstep(gs, h, actions)
            if gs.gameOver then break end
        end
        gs.physAcc = gs.physAcc - step
        n = n + 1
        if gs.gameOver then break end
    end
    gs.lastSubsteps = maxSub
    return actions
end

function Logic:GetBall(gs)
    if not gs or not gs.balls then return nil end
    for i = 1, #gs.balls do
        local b = gs.balls[i]
        if b.active and not b.locked then return b end
    end
    return gs.balls[1]
end

Logic.StartMultiball = StartMultiball
Logic.StartMission = StartMission
Logic.LiveCount = LiveCount
Logic.HandleDrain = HandleDrain
