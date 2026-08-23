-- ============================================================
--  BlockBreaker – Logic.lua
--  Spielregeln und State. KEIN UI, KEINE WoW-API-Calls.
--
--  Power-Up-Typen (9):
--    lives     – +1 Leben (max 5)
--    score250  – Sofort +250 Punkte
--    score500  – Sofort +500 Punkte
--    big       – Paddle x2, 10s
--    bullet    – Extra-Ball (max 3 gleichzeitig), dauerhaft bis Leben verloren
--    fast      – Kugel + Paddle +50% Speed, 8s
--    slow      – Kugel + Paddle -50% Speed, 8s
--    small     – Paddle /2, 8s (Malus)
--    strength  – Gepanzerte Blöcke mit 1 Treffer zerstören, 8s
-- ============================================================

ArcadiaNexus.BB_Logic = {}
local Logic = ArcadiaNexus.BB_Logic

-- ── Spielfeld-Konstanten (müssen Renderer-Feld 565×370 füllen) ─
Logic.FIELD_W       = 695
Logic.FIELD_H       = 480
Logic.FIELD_COLS    = 20
Logic.FIELD_ROWS    = 16
Logic.BLOCK_W       = 28
Logic.BLOCK_H       = 16
Logic.BLOCK_OX      = 2    -- (565 - 20*28) / 2  → 2px, Rest 1px rechts
Logic.BLOCK_TOP_PAD = 20
Logic.PADDLE_Y      = 425  -- 25px über dem unteren Rand, wie zuvor
Logic.PADDLE_SPEED  = 430
Logic.BALL_RADIUS   = 6
Logic.BASE_SPEED    = 280
Logic.MAX_LIVES     = 5
Logic.MAX_BALLS     = 3   -- Hauptball + max 2 Extra

-- Schwierigkeits-Definitionen (Paddle-Breite an Feld 565 skaliert)
Logic.DIFFICULTY_DEFS = {
    easy   = { paddleW=80, speedMul=1.00, accelInterval=0,  accelAmt=0,    lives=5, scoreFac=1.00 },
    normal = { paddleW=56, speedMul=1.30, accelInterval=15, accelAmt=0.02, lives=3, scoreFac=1.25 },
    hard   = { paddleW=40, speedMul=1.60, accelInterval=10, accelAmt=0.05, lives=1, scoreFac=2.00 },
}

Logic.BLOCK_POINTS = { [1]=10, [2]=25, [4]=15, [5]=15 }

-- Drop-Chance für normale Blöcke (Prozent, 1–100)
Logic.PU_DROP_CHANCE = 8   -- 8% pro zerstörtem normalen Block

-- Gewichteter PU-Pool
Logic.PU_POOL = {
    "lives",
    "score250", "score250", "score250",
    "score500",
    "big",      "big",
    "bullet",   "bullet",   "bullet",
    "fast",     "fast",
    "slow",     "slow",
    "small",
    "strength", "strength",
}

-- ── State ─────────────────────────────────────────────────────
function Logic:NewState(difficulty, savedProgress)
    local def = self.DIFFICULTY_DEFS[difficulty] or self.DIFFICULTY_DEFS.easy
    local s = {
        difficulty        = difficulty,
        paddleW           = def.paddleW,
        paddleX           = (self.FIELD_W - def.paddleW) / 2,
        ballX             = self.FIELD_W / 2,
        ballY             = self.PADDLE_Y - self.BALL_RADIUS - 5,
        ballVX            = self.BASE_SPEED * def.speedMul * 0.6,
        ballVY            = -self.BASE_SPEED * def.speedMul * 0.8,
        ballActive        = true,
        balls             = {},
        speedMul          = 1.0,
        baseSpeed         = self.BASE_SPEED * def.speedMul,
        accelInterval     = def.accelInterval,
        accelAmt          = def.accelAmt,
        accelTimer        = 0,
        lives             = def.lives,
        score             = 0,
        scoreFac          = def.scoreFac,
        comboCount        = 0,
        keyLeft           = false,
        keyRight          = false,
        level             = 1,
        endlessMode       = false,
        endlessSpeedBonus = 0,
        grid              = {},
        blocksLeft        = 0,
        elapsedSecs       = 0,
        -- PU-Timer
        bigTimer          = nil,
        fastTimer         = nil,
        slowTimer         = nil,
        smallTimer        = nil,
        strengthTimer     = nil,
        -- Fallender PU-Drop
        droppedPUs        = {},   -- Liste aktiver PU-Drops (mehrere gleichzeitig möglich)
        activePUText      = nil,
        gameOver          = false,
        won               = false,
    }
    if savedProgress then
        s.level      = savedProgress.level or 1
        s.score      = savedProgress.score or 0
        s.lives      = savedProgress.lives or def.lives
        s.difficulty = savedProgress.diff  or difficulty
    end
    return s
end

-- Zeile auf FIELD_COLS strecken (nicht rechts mit 0 auffüllen — das
-- lässt das Raster links kleben und die rechte Feldseite leer).
local function StretchRow(row, destCols)
    local n = #row
    if n == destCols then return row end
    if n < 1 then return string.rep("0", destCols) end
    if destCols <= 1 then return row:sub(1, 1) end
    local out = {}
    local last = n - 1
    local destLast = destCols - 1
    for i = 0, destLast do
        local src = math.floor(i * last / destLast + 0.5) + 1
        if src < 1 then src = 1 elseif src > n then src = n end
        out[i + 1] = row:sub(src, src)
    end
    return table.concat(out)
end

function Logic:RefreshBlockMetrics()
    local cols = self.FIELD_COLS
    self.BLOCK_W = math.max(1, math.floor(self.FIELD_W / cols))
    local used = self.BLOCK_W * cols
    self.BLOCK_OX = math.floor((self.FIELD_W - used) / 2)
end

-- ── Level-Parser ──────────────────────────────────────────────
function Logic:ParseLevel(state, levelIndex)
    local realIndex = ((levelIndex - 1) % 100) + 1
    local entry = ArcadiaNexus.BB_Levels and ArcadiaNexus.BB_Levels[realIndex]
    if not entry then entry = { map = "11111111111111111111", name = "?" } end
    self:RefreshBlockMetrics()
    state.grid = {}
    state.blocksLeft = 0
    local row = 1
    local cols = self.FIELD_COLS
    for line in (entry.map .. "|"):gmatch("([^|]*)|") do
        local stretched = StretchRow(line, cols)
        state.grid[row] = {}
        for col = 1, cols do
            local ch = stretched:sub(col, col)
            local typ = 0
            if     ch == "1" then typ = 1
            elseif ch == "2" then typ = 2
            elseif ch == "3" then typ = 3
            elseif ch == "P" then typ = 4
            end
            state.grid[row][col] = typ
            if typ == 1 or typ == 2 or typ == 4 then
                state.blocksLeft = state.blocksLeft + 1
            end
        end
        row = row + 1
    end
    state.levelRows = row - 1
    state.levelName = entry.name or ("Level " .. levelIndex)
end

-- ── Ball-Reset ────────────────────────────────────────────────
function Logic:ResetBall(state)
    state.ballX = self.FIELD_W / 2
    state.ballY = self.PADDLE_Y - self.BALL_RADIUS - 5
    local angle  = -math.pi/2 + (math.random() - 0.5) * 0.8
    local spd    = self:_EffectiveSpeed(state)
    state.ballVX = spd * math.cos(angle)
    state.ballVY = spd * math.sin(angle)
    state.ballActive = true
    state.balls      = {}
    state.comboCount = 0
end

-- ── Effektive Geschwindigkeit ─────────────────────────────────
function Logic:_EffectiveSpeed(state)
    local spd = state.baseSpeed * state.speedMul
    if state.fastTimer  and state.fastTimer  > 0 then spd = spd * 1.50 end
    if state.slowTimer  and state.slowTimer  > 0 then spd = spd * 0.50 end
    return spd
end

function Logic:_EffectivePaddleSpeed(state)
    local spd = self.PADDLE_SPEED
    if state.fastTimer and state.fastTimer > 0 then spd = spd * 1.50 end
    if state.slowTimer and state.slowTimer > 0 then spd = spd * 0.50 end
    return spd
end

-- ── Haupt-Tick ────────────────────────────────────────────────
function Logic:Tick(state, dt)
    if state.gameOver then return {} end
    local actions = {}

    -- Paddle bewegen
    local paddleSpd = self:_EffectivePaddleSpeed(state)
    if state.keyLeft  then state.paddleX = math.max(0, state.paddleX - paddleSpd * dt) end
    if state.keyRight then state.paddleX = math.min(self.FIELD_W - state.paddleW, state.paddleX + paddleSpd * dt) end

    -- Beschleunigung
    if state.accelInterval > 0 then
        state.accelTimer = state.accelTimer + dt
        if state.accelTimer >= state.accelInterval then
            state.accelTimer = state.accelTimer - state.accelInterval
            state.speedMul   = state.speedMul + state.accelAmt
        end
    end

    state.elapsedSecs = state.elapsedSecs + dt
    self:_TickPowerUps(state, dt, actions)

    if state.ballActive then self:_MoveBall(state, dt, actions) end

    local i = 1
    while i <= #state.balls do
        self:_MoveBallObj(state, state.balls[i], dt, actions)
        if state.balls[i]._lost then table.remove(state.balls, i)
        else i = i + 1 end
    end

    self:_MovePowerUpDrops(state, dt, actions)
    self:_CheckWin(state, actions)
    return actions
end

-- ── AABB ─────────────────────────────────────────────────────
local function _BallAABB(bx, by, r, rx, ry, rw, rh)
    local cx = math.max(rx, math.min(bx, rx+rw))
    local cy = math.max(ry, math.min(by, ry+rh))
    local dx = bx-cx; local dy = by-cy
    return (dx*dx + dy*dy) <= (r*r)
end

local function _ResolveSide(bx, by, r, rx, ry, rw, rh)
    local minO = math.min((bx+r)-rx, (rx+rw)-(bx-r), (by+r)-ry, (ry+rh)-(by-r))
    if minO == (by+r)-ry or minO == (ry+rh)-(by-r) then return "v" end
    return "h"
end

-- ── Ball-Bewegung ─────────────────────────────────────────────
function Logic:_MoveBall(state, dt, actions)
    local obj = { x=state.ballX, y=state.ballY, vx=state.ballVX, vy=state.ballVY, _lost=false }
    self:_MoveBallObj(state, obj, dt, actions)
    if obj._lost then
        state.lives = state.lives - 1
        state.ballActive = false
        state.balls = {}
        state.droppedPUs = {}
        -- Alle Timer aufheben
        state.bigTimer = nil; state.fastTimer = nil; state.slowTimer = nil
        state.smallTimer = nil; state.strengthTimer = nil
        state.activePUText = nil
        -- Paddle zurücksetzen
        local def = self.DIFFICULTY_DEFS[state.difficulty] or self.DIFFICULTY_DEFS.easy
        state.paddleW = def.paddleW
        actions[#actions+1] = { type="life_lost" }
        if state.lives <= 0 then
            state.gameOver = true; state.won = false
            actions[#actions+1] = { type="game_over" }
        end
    else
        state.ballX=obj.x; state.ballY=obj.y
        state.ballVX=obj.vx; state.ballVY=obj.vy
    end
end

function Logic:_MoveBallObj(state, ball, dt, actions)
    local r   = self.BALL_RADIUS
    local spd = self:_EffectiveSpeed(state)
    local len = math.sqrt(ball.vx*ball.vx + ball.vy*ball.vy)
    if len > 0 then ball.vx=(ball.vx/len)*spd; ball.vy=(ball.vy/len)*spd end

    local nx = ball.x + ball.vx * dt
    local ny = ball.y + ball.vy * dt

    if nx-r < 0 then nx=r; ball.vx=math.abs(ball.vx); actions[#actions+1]={type="bounce_wall"}
    elseif nx+r > self.FIELD_W then nx=self.FIELD_W-r; ball.vx=-math.abs(ball.vx); actions[#actions+1]={type="bounce_wall"} end
    if ny-r < 0 then ny=r; ball.vy=math.abs(ball.vy); actions[#actions+1]={type="bounce_wall"} end

    if ny+r > self.FIELD_H then
        ball._lost = true; return
    end

    local px,py,pw,ph = state.paddleX, self.PADDLE_Y, state.paddleW, 8
    if _BallAABB(nx, ny, r, px, py, pw, ph) and ball.vy > 0 then
        local hitPos = math.max(-1, math.min(1, (nx-(px+pw/2))/(pw/2)))
        local angle  = hitPos * (math.pi * 0.4)
        local spd2   = math.sqrt(ball.vx*ball.vx + ball.vy*ball.vy)
        ball.vx = spd2*math.sin(angle); ball.vy = -math.abs(spd2*math.cos(angle))
        ny = py-r; state.comboCount = 0; actions[#actions+1]={type="bounce_paddle"}
    end

    self:_CheckBlockCollision(state, ball, nx, ny, r, actions)
    ball.x = ball.x; ball.y = ball.y  -- bereits in _CheckBlockCollision gesetzt
end

function Logic:_CheckBlockCollision(state, ball, nx, ny, r, actions)
    local BW, BH = self.BLOCK_W, self.BLOCK_H
    local ox, tp = self.BLOCK_OX, self.BLOCK_TOP_PAD
    local colMin = math.max(1, math.floor((nx-r-ox)/BW)+1)
    local colMax = math.min(self.FIELD_COLS, math.floor((nx+r-ox)/BW)+1)
    local rowMin = math.max(1, math.floor((ny-r-tp)/BH)+1)
    local rowMax = math.min(state.levelRows or self.FIELD_ROWS, math.floor((ny+r-tp)/BH)+1)

    local pierce = state.strengthTimer and state.strengthTimer > 0
    local hitAny = false

    for row = rowMin, rowMax do
        if state.grid[row] then
            for col = colMin, colMax do
                local typ = state.grid[row][col]
                if typ and typ > 0 then
                    local bx = ox+(col-1)*BW; local by = tp+(row-1)*BH
                    if _BallAABB(nx, ny, r, bx, by, BW, BH) then
                        if pierce and typ ~= 3 then
                            -- Pierce: Block zerstören ohne zu reflektieren
                            self:_HitBlock(state, ball, row, col, typ, actions)
                            hitAny = true
                        else
                            -- Seite bestimmen und reflektieren
                            local side = _ResolveSide(nx, ny, r, bx, by, BW, BH)
                            if side == "v" then
                                ball.vy = -ball.vy
                                -- Kugel aus Block heraussetzen (Depenetration)
                                if ny < by + BH/2 then
                                    ny = by - r      -- Kugel kam von oben
                                else
                                    ny = by + BH + r  -- Kugel kam von unten
                                end
                            else
                                ball.vx = -ball.vx
                                -- Kugel aus Block heraussetzen (Depenetration)
                                if nx < bx + BW/2 then
                                    nx = bx - r      -- Kugel kam von links
                                else
                                    nx = bx + BW + r  -- Kugel kam von rechts
                                end
                            end
                            self:_HitBlock(state, ball, row, col, typ, actions)
                            ball.x = nx; ball.y = ny; return
                        end
                    end
                end
            end
        end
    end
    ball.x = nx; ball.y = ny
end

function Logic:_HitBlock(state, ball, row, col, typ, actions)
    if typ == 3 then return end
    local strength = state.strengthTimer and state.strengthTimer > 0
    local destroyed = false; local newTyp = typ

    if     typ == 1 then destroyed=true; newTyp=0
    elseif typ == 2 then
        if strength then destroyed=true; newTyp=0
        else newTyp=5 end
    elseif typ == 5 then destroyed=true; newTyp=0
    elseif typ == 4 then destroyed=true; newTyp=0
    end

    state.grid[row][col] = newTyp
    if destroyed then
        state.blocksLeft = math.max(0, state.blocksLeft-1)
        state.comboCount = state.comboCount+1
        if state.comboCount > (state.maxCombo or 0) then state.maxCombo=state.comboCount end

        local pts   = self.BLOCK_POINTS[typ] or 10
        local diff  = state.scoreFac or 1.0
        local speed = 1.0 + math.floor((state.speedMul-1.0)/0.10)*0.10
        local combo = 1.0 + math.max(0, state.comboCount-1)*0.10
        local gain  = math.floor(pts * diff * speed * combo)
        state.score = state.score + gain

        local cx = self.BLOCK_OX + (col-1)*self.BLOCK_W + self.BLOCK_W/2
        local cy = self.BLOCK_TOP_PAD+(row-1)*self.BLOCK_H + self.BLOCK_H/2

        if typ == 4 then
            -- P-Block: garantierter PU-Drop
            local pool   = self.PU_POOL
            local puType = pool[math.random(#pool)]
            table.insert(state.droppedPUs, { x=cx, y=cy, type=puType, vy=100 })
            actions[#actions+1] = { type="powerup_drop", puType=puType, x=cx, y=cy }
        elseif math.random(100) <= self.PU_DROP_CHANCE then
            -- Normaler/gepanzerter Block: zufälliger Drop mit Chance PU_DROP_CHANCE%
            local pool   = self.PU_POOL
            local puType = pool[math.random(#pool)]
            table.insert(state.droppedPUs, { x=cx, y=cy, type=puType, vy=100 })
            actions[#actions+1] = { type="powerup_drop", puType=puType, x=cx, y=cy }
        end
        actions[#actions+1] = { type="break_block", row=row, col=col, blockType=typ, points=gain }
    else
        actions[#actions+1] = { type="damage_block", row=row, col=col, newTyp=newTyp }
    end
end

-- ── Power-Up-Drop ─────────────────────────────────────────────
function Logic:_MovePowerUpDrops(state, dt, actions)
    local px, py, pw = state.paddleX, self.PADDLE_Y, state.paddleW
    local i = 1
    while i <= #state.droppedPUs do
        local pu = state.droppedPUs[i]
        pu.y = pu.y + pu.vy * dt
        -- Paddle-Kollision
        if pu.x >= px and pu.x <= px+pw and pu.y+16 >= py and pu.y <= py+8 then
            self:_ActivatePowerUp(state, pu.type, actions)
            table.remove(state.droppedPUs, i)
        -- Unterer Rand
        elseif pu.y > self.FIELD_H + 30 then
            table.remove(state.droppedPUs, i)
        else
            i = i + 1
        end
    end
end

function Logic:_ActivatePowerUp(state, puType, actions)
    actions[#actions+1] = { type="powerup_collect", puType=puType }
    local def = self.DIFFICULTY_DEFS[state.difficulty] or self.DIFFICULTY_DEFS.easy

    if puType == "lives" then
        state.lives = math.min(state.lives + 1, self.MAX_LIVES)
        actions[#actions+1] = { type="lives_gained" }

    elseif puType == "score250" then
        state.score = state.score + 250
        actions[#actions+1] = { type="score_bonus", amount=250 }

    elseif puType == "score500" then
        state.score = state.score + 500
        actions[#actions+1] = { type="score_bonus", amount=500 }

    elseif puType == "big" then
        state.smallTimer = nil
        state.paddleW    = def.paddleW * 2
        state.bigTimer   = 10
        state.activePUText = "big"

    elseif puType == "bullet" then
        -- Extra-Ball hinzufügen (max MAX_BALLS-1 Extra-Bälle)
        local totalBalls = 1 + #state.balls
        if totalBalls < self.MAX_BALLS then
            local angle = math.atan2(state.ballVY, state.ballVX)
            local spd   = self:_EffectiveSpeed(state)
            local off   = math.pi / 6
            state.balls[#state.balls+1] = {
                x=state.ballX, y=state.ballY,
                vx=spd*math.cos(angle+off), vy=spd*math.sin(angle+off),
                _lost=false,
            }
        end
        state.activePUText = "bullet"

    elseif puType == "fast" then
        state.slowTimer = nil
        state.fastTimer = 8
        state.activePUText = "fast"

    elseif puType == "slow" then
        state.fastTimer = nil
        state.slowTimer = 8
        state.activePUText = "slow"

    elseif puType == "small" then
        state.bigTimer   = nil
        state.paddleW    = math.max(32, math.floor(def.paddleW * 0.5))
        state.smallTimer = 8
        state.activePUText = "small"

    elseif puType == "strength" then
        state.strengthTimer = 8
        state.activePUText  = "strength"
    end
end

-- ── PU-Timer dekrementieren ───────────────────────────────────
function Logic:_TickPowerUps(state, dt, actions)
    local def = self.DIFFICULTY_DEFS[state.difficulty] or self.DIFFICULTY_DEFS.easy
    local function tick(field, label, onExpire)
        if state[field] and state[field] > 0 then
            state[field] = state[field] - dt
            if state[field] <= 0 then
                state[field] = nil
                if onExpire then onExpire() end
                actions[#actions+1] = { type="powerup_expired", puType=label }
            end
        end
    end
    tick("bigTimer",      "big",      function() state.paddleW = def.paddleW end)
    tick("fastTimer",     "fast",     nil)
    tick("slowTimer",     "slow",     nil)
    tick("smallTimer",    "small",    function() state.paddleW = def.paddleW end)
    tick("strengthTimer", "strength", nil)
end

-- ── Spielende ─────────────────────────────────────────────────
function Logic:_CheckWin(state, actions)
    if state.gameOver then return end
    if state.blocksLeft <= 0 then
        state.gameOver = true; state.won = true
        actions[#actions+1] = { type="level_win" }
    end
end

function Logic:ReloadLevel(state)
    state.speedMul      = 1.0 + (state.endlessSpeedBonus or 0)
    state.accelTimer    = 0; state.comboCount = 0
    state.gameOver      = false; state.won = false
    state.droppedPUs    = {}
    state.bigTimer      = nil; state.fastTimer    = nil
    state.slowTimer     = nil; state.smallTimer   = nil
    state.strengthTimer = nil; state.activePUText = nil
    state.balls         = {}
    local def = self.DIFFICULTY_DEFS[state.difficulty] or self.DIFFICULTY_DEFS.easy
    state.paddleW = def.paddleW
    self:ResetBall(state)
    self:ParseLevel(state, state.level)
end

function Logic:AdvanceLevel(state)
    state.level = state.level + 1
    if state.level > 100 then
        state.endlessMode       = true
        state.endlessSpeedBonus = state.endlessSpeedBonus + 0.20
    end
    self:ReloadLevel(state)
end

function Logic:RetryLevel(state)
    self:ReloadLevel(state)
end

Logic:RefreshBlockMetrics()
