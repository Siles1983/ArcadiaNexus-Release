-- ============================================================
--  BlockBreaker – Logic.lua
--  Spielregeln und State. KEIN UI, KEINE WoW-API-Calls.
--
--  Power-Up-Typen (9):
--    lives     – +1 Leben (max 5)
--    score250  – Sofort +250 Punkte
--    score500  – Sofort +500 Punkte
--    big       – Paddle x2, 10s
--    bullet    – Extra-Ball (max 3 gleichzeitig); Leben erst, wenn der letzte Ball fällt
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

Logic.PU_TYPES = {
    "lives", "score250", "score500",
    "big", "bullet", "fast", "slow", "small", "strength",
}

-- ── State ─────────────────────────────────────────────────────
function Logic:NewState(difficulty, savedProgress)
    difficulty = self.DIFFICULTY_DEFS[difficulty] and difficulty or "easy"
    local def = self.DIFFICULTY_DEFS[difficulty]
    local s = {
        difficulty        = difficulty,
        ruleVersion=2, layoutVersion=2, phase="PLAYING", simRemainder=0,
        clearedLevel=0, stagesCleared=0, regularCleared=0, levelId=1, levelStartScore=0, levelStartTime=0, maxCombo=0,
        paddleW           = def.paddleW,
        paddleX           = (self.FIELD_W - def.paddleW) / 2,
        ballX             = self.FIELD_W / 2,
        ballY             = self.PADDLE_Y - self.BALL_RADIUS - 5,
        ballVX            = 0,
        ballVY            = 0,
        ballActive        = true,
        ballDocked        = true,
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
        s.level=savedProgress.level or 1
        s.lives=savedProgress.lives or def.lives
        s.legacyScore=savedProgress.score or 0
        s.legacyContinuation=true
        s.endlessMode=s.level>100
        s.endlessSpeedBonus=math.max(0,s.level-100)*0.20
        s.speedMul=1+s.endlessSpeedBonus
        s.legacyCompleted=s.endlessMode
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

-- ── Ball am Paddle ────────────────────────────────────────────
function Logic:_StickBallToPaddle(state)
    state.ballX = (state.paddleX or 0) + (state.paddleW or 0) / 2
    state.ballY = self.PADDLE_Y - self.BALL_RADIUS - 5
end

function Logic:ResetBall(state)
    state.balls      = {}
    state.comboCount = 0
    state.ballActive = true
    state.ballDocked = true
    state.ballVX     = 0
    state.ballVY     = 0
    self:_StickBallToPaddle(state)
end

function Logic:LaunchBall(state)
    if not state or state.gameOver or not state.ballDocked then return false end
    self:_StickBallToPaddle(state)
    local angle = -math.pi / 2 + (math.random() - 0.5) * 0.8
    local spd   = self:_EffectiveSpeed(state)
    state.ballVX     = spd * math.cos(angle)
    state.ballVY     = spd * math.sin(angle)
    state.ballDocked = false
    state.ballActive = true
    return true
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
function Logic:_Step(state, dt)
    if state.gameOver or state.phase~="PLAYING" then return {} end
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
    state.paddleX=math.max(0,math.min(self.FIELD_W-state.paddleW,state.paddleX))

    if state.ballDocked then
        self:_StickBallToPaddle(state)
    elseif state.ballActive then
        self:_MoveBall(state, dt, actions)
    end

    local i = 1
    while i <= #state.balls do
        self:_MoveBallObj(state, state.balls[i], dt, actions)
        if state.balls[i]._lost then table.remove(state.balls, i)
        else i = i + 1 end
    end

    -- Leben nur, wenn kein Ball mehr im Feld ist (Arkanoid-Regel).
    self:_PromoteOrLoseLife(state, actions)

    if state.phase=="PLAYING" then
        self:_MovePowerUpDrops(state, dt, actions)
        self:_CheckWin(state, actions)
    end
    return actions
end

-- ── Ball-Bewegung ─────────────────────────────────────────────
function Logic:_MoveBall(state, dt, actions)
    local obj = { x=state.ballX, y=state.ballY, vx=state.ballVX, vy=state.ballVY, _lost=false }
    self:_MoveBallObj(state, obj, dt, actions)
    if obj._lost then
        state.ballActive = false
    else
        state.ballX=obj.x; state.ballY=obj.y
        state.ballVX=obj.vx; state.ballVY=obj.vy
    end
end

function Logic:_PromoteOrLoseLife(state, actions)
    if state.ballActive or state.phase~="PLAYING" then return end
    if #state.balls > 0 then
        local nextBall = table.remove(state.balls, 1)
        state.ballX  = nextBall.x
        state.ballY  = nextBall.y
        state.ballVX = nextBall.vx
        state.ballVY = nextBall.vy
        state.ballActive = true
        state.ballDocked = false
        return
    end
    state.lives = state.lives - 1
    state.droppedPUs = {}
    state.bigTimer = nil; state.fastTimer = nil; state.slowTimer = nil
    state.smallTimer = nil; state.strengthTimer = nil
    state.activePUText = nil
    local def = self.DIFFICULTY_DEFS[state.difficulty] or self.DIFFICULTY_DEFS.easy
    state.paddleW = def.paddleW
    state.paddleX=math.max(0,math.min(self.FIELD_W-state.paddleW,state.paddleX))
    actions[#actions+1] = { type="life_lost" }
    if state.lives <= 0 then
        state.gameOver = true; state.won = false; state.phase="GAMEOVER"
        actions[#actions+1] = { type="game_over" }
    else
        state.phase="RESPAWNING"; state.transitionRemaining=1
    end
end

-- Exact circle sweep: rectangle face strips plus rounded corner contacts.
local function SweepCircle(x,y,dx,dy,r,rx,ry,rw,rh)
    local cx=math.max(rx,math.min(x,rx+rw)); local cy=math.max(ry,math.min(y,ry+rh))
    local ox,oy=x-cx,y-cy; local distance=math.sqrt(ox*ox+oy*oy)
    if distance>0 and distance<r-1e-7 then return 0,ox/distance,oy/distance,r-distance end
    if distance==0 then
        local faces={{x-rx,-1,0},{rx+rw-x,1,0},{y-ry,0,-1},{ry+rh-y,0,1}}
        table.sort(faces,function(a,b) return a[1]<b[1] end)
        return 0,faces[1][2],faces[1][3],r+faces[1][1]
    end
    local best,nx,ny
    local function accept(t,a,b)
        if t>=-1e-9 and t<=1+1e-9 and dx*a+dy*b< -1e-9 and (not best or t<best) then
            best,nx,ny=math.max(0,t),a,b
        end
    end
    if dx~=0 then
        local t=(rx-r-x)/dx; local yy=y+dy*t
        if yy>=ry and yy<=ry+rh then accept(t,-1,0) end
        t=(rx+rw+r-x)/dx; yy=y+dy*t
        if yy>=ry and yy<=ry+rh then accept(t,1,0) end
    end
    if dy~=0 then
        local t=(ry-r-y)/dy; local xx=x+dx*t
        if xx>=rx and xx<=rx+rw then accept(t,0,-1) end
        t=(ry+rh+r-y)/dy; xx=x+dx*t
        if xx>=rx and xx<=rx+rw then accept(t,0,1) end
    end
    local aa=dx*dx+dy*dy
    if aa>0 then
        for _,corner in ipairs({{rx,ry,-1,-1},{rx+rw,ry,1,-1},{rx,ry+rh,-1,1},{rx+rw,ry+rh,1,1}}) do
            local ox,oy=x-corner[1],y-corner[2]
            local bb=2*(ox*dx+oy*dy); local cc=ox*ox+oy*oy-r*r
            local discr=bb*bb-4*aa*cc
            if discr>=0 then
                local t=(-bb-math.sqrt(discr))/(2*aa)
                local hx,hy=ox+dx*t,oy+dy*t
                if hx*corner[3]>=-1e-8 and hy*corner[4]>=-1e-8 then accept(t,hx/r,hy/r) end
            end
        end
    end
    return best,nx,ny
end

function Logic:_MoveBallObj(state, ball, dt, actions)
    local r=self.BALL_RADIUS
    if ball.y>=self.FIELD_H-r and ball.vy>0 then ball._lost=true; return end
    if ball.x<r then
        ball.x=r
        if ball.vx<0 then ball.vx=-ball.vx; actions[#actions+1]={type="bounce_wall",side="left"} end
    elseif ball.x>self.FIELD_W-r then
        ball.x=self.FIELD_W-r
        if ball.vx>0 then ball.vx=-ball.vx; actions[#actions+1]={type="bounce_wall",side="right"} end
    end
    if ball.y<r then ball.y=r; if ball.vy<0 then ball.vy=-ball.vy; actions[#actions+1]={type="bounce_wall",side="top"} end end
    local spd=self:_EffectiveSpeed(state)
    local len=math.sqrt(ball.vx*ball.vx+ball.vy*ball.vy)
    if len>0 then ball.vx=ball.vx/len*spd; ball.vy=ball.vy/len*spd end
    local remaining=dt
    for contact=1,48 do
        if remaining<=1e-10 then return end
        local dx,dy=ball.vx*remaining,ball.vy*remaining
        local best,hit,nx,ny
        local function offer(t,kind,a,b,row,col,penetration)
            if t and t>=-1e-9 and t<=1+1e-9 and (not best or t<best-1e-9) then
                best,hit,nx,ny=math.max(0,t),{kind=kind,row=row,col=col,penetration=penetration},a,b
            end
        end
        if dx<0 then offer((r-ball.x)/dx,"left",1,0)
        elseif dx>0 then offer((self.FIELD_W-r-ball.x)/dx,"right",-1,0) end
        if dy<0 then offer((r-ball.y)/dy,"top",0,1)
        elseif dy>0 then offer((self.FIELD_H-r-ball.y)/dy,"lost",0,-1) end
        if dy>0 then
            local t,a,b,push=SweepCircle(ball.x,ball.y,dx,dy,r,state.paddleX,self.PADDLE_Y,state.paddleW,8)
            offer(t,"paddle",a,b,nil,nil,push)
        end
        local c0=math.max(1,math.floor((math.min(ball.x,ball.x+dx)-r-self.BLOCK_OX)/self.BLOCK_W)+1)
        local c1=math.min(self.FIELD_COLS,math.floor((math.max(ball.x,ball.x+dx)+r-self.BLOCK_OX)/self.BLOCK_W)+1)
        local r0=math.max(1,math.floor((math.min(ball.y,ball.y+dy)-r-self.BLOCK_TOP_PAD)/self.BLOCK_H)+1)
        local r1=math.min(state.levelRows or self.FIELD_ROWS,math.floor((math.max(ball.y,ball.y+dy)+r-self.BLOCK_TOP_PAD)/self.BLOCK_H)+1)
        for row=r0,r1 do for col=c0,c1 do
            local typ=state.grid[row] and state.grid[row][col]
            if typ and typ>0 then
                local t,a,b,push=SweepCircle(ball.x,ball.y,dx,dy,r,self.BLOCK_OX+(col-1)*self.BLOCK_W,
                    self.BLOCK_TOP_PAD+(row-1)*self.BLOCK_H,self.BLOCK_W,self.BLOCK_H)
                offer(t,"block",a,b,row,col,push)
            end
        end end
        if not best then ball.x=ball.x+dx; ball.y=ball.y+dy; return end
        ball.x=ball.x+dx*best; ball.y=ball.y+dy*best
        remaining=remaining*(1-best)
        if hit.kind=="lost" then ball._lost=true; return end
        local pierce=false
        if hit.kind=="block" then
            local typ=state.grid[hit.row][hit.col]
            pierce=state.strengthTimer and state.strengthTimer>0 and typ~=3
            self:_HitBlock(state,ball,hit.row,hit.col,typ,actions)
        end
        if hit.kind=="paddle" then
            local hitPos=math.max(-1,math.min(1,(ball.x-(state.paddleX+state.paddleW/2))/(state.paddleW/2)))
            local angle=hitPos*(math.pi*0.4)
            ball.vx=spd*math.sin(angle); ball.vy=-math.abs(spd*math.cos(angle))
            ball.y=math.min(ball.y,self.PADDLE_Y-r-1e-6)
            state.comboCount=0; actions[#actions+1]={type="bounce_paddle"}
        elseif not pierce then
            local dot=ball.vx*nx+ball.vy*ny
            if dot<0 then ball.vx=ball.vx-2*dot*nx; ball.vy=ball.vy-2*dot*ny end
            local push=(hit.penetration or 0)+1e-6
            ball.x=ball.x+nx*push; ball.y=ball.y+ny*push
            if hit.kind~="block" then actions[#actions+1]={type="bounce_wall",side=hit.kind} end
        end
        if state.blocksLeft<=0 then return end
    end
    state.contactLimitHits=(state.contactLimitHits or 0)+1
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
        -- Extra-Ball hinzufügen (max MAX_BALLS-1 Extra-Bälle); nicht während Serve
        local totalBalls = 1 + #state.balls
        if not state.ballDocked and totalBalls < self.MAX_BALLS then
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
    state.paddleX=math.max(0,math.min(self.FIELD_W-state.paddleW,state.paddleX))
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
        state.gameOver = true; state.won = true; state.phase="LEVEL_CLEAR"
        state.transitionRemaining=0.45; state.clearReady=false; state.levelWon=true
        state.clearedLevel=state.level; state.stagesCleared=state.stagesCleared+1
        if state.level<=100 then state.regularCleared=state.regularCleared+1 end
        state.levelPerformance={id=state.levelId,level=state.level,score=state.score-state.levelStartScore,
            elapsedMs=math.floor((state.elapsedSecs-state.levelStartTime)*1000+0.5)}
        actions[#actions+1] = { type="level_win" }
    end
end

function Logic:ReloadLevel(state)
    state.speedMul      = 1.0 + (state.endlessSpeedBonus or 0)
    state.accelTimer    = 0; state.comboCount = 0
    state.gameOver      = false; state.won = false
    state.phase="PLAYING"; state.transitionRemaining=nil; state.clearReady=nil; state.levelWon=false
    state.levelStartScore=state.score; state.levelStartTime=state.elapsedSecs; state.simRemainder=0
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
    state.levelId=(state.levelId or 1)+1
    if state.level > 100 then
        state.endlessMode       = true
        state.endlessSpeedBonus = state.endlessSpeedBonus + 0.20
    end
    self:ReloadLevel(state)
end

function Logic:RetryLevel(state)
    if not state.devPlaytest then return false end
    self:ReloadLevel(state)
end

-- DevMode: Power-Up über dem Paddle fallen lassen.
function Logic:DevDropPowerUp(state, puType)
    if not state or state.gameOver or type(puType) ~= "string" then return false end
    if not self._puTypeSet then
        self._puTypeSet = {}
        for i = 1, #self.PU_TYPES do
            self._puTypeSet[self.PU_TYPES[i]] = true
        end
    end
    if not self._puTypeSet[puType] then return false end
    local pw = state.paddleW or 80
    local x  = (state.paddleX or 0) + pw / 2
    state.droppedPUs = state.droppedPUs or {}
    state.droppedPUs[#state.droppedPUs + 1] = { x = x, y = 24, type = puType, vy = 100 }
    return true
end

Logic:RefreshBlockMetrics()


function Logic:Neutralize(state)
    if state then state.keyLeft=false; state.keyRight=false end
end
function Logic:Copy(v)
    if type(v)~="table" then return v end
    local out={} for k,x in pairs(v) do out[k]=self:Copy(x) end return out
end
function Logic:Tick(state,dt)
    if not state or state.phase~="PLAYING" or state.gameOver then return {} end
    state.simRemainder=(state.simRemainder or 0)+math.max(0,math.min(0.1,dt or 0))
    local events={}
    for _=1,12 do
        if state.simRemainder+1e-10<1/120 then break end
        state.simRemainder=math.max(0,state.simRemainder-1/120)
        for _,event in ipairs(self:_Step(state,1/120)) do events[#events+1]=event end
        if state.phase~="PLAYING" then state.simRemainder=0; self:Neutralize(state); break end
    end
    return events
end
function Logic:Snapshot(state,engineState)
    if not state or state.devPlaytest or state.phase=="GAMEOVER" or state.runClosed or state.lives<=0 then return nil end
    local save=self:Copy(state); self:Neutralize(save)
    save.version=2; save.engineState=engineState or state.phase; save.diff=state.difficulty
    save.resultData=nil; save.highScore=nil; save.clearPresented=nil
    return save
end
function Logic:Restore(save)
    local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
    local function integer(n) return finite(n) and n>=0 and n%1==0 end
    if type(save)~="table" or save.version~=2 or save.ruleVersion~=2 or save.layoutVersion~=2
        or not self.DIFFICULTY_DEFS[save.difficulty] or type(save.runId)~="string" or save.devPlaytest or save.runClosed
        or not ({PLAYING=true,RESPAWNING=true,LEVEL_CLEAR=true})[save.phase]
        or save.engineState~=save.phase and save.engineState~="PAUSED" then return nil end
    for _,key in ipairs({"score","lives","level","levelId","comboCount","maxCombo","blocksLeft","clearedLevel","stagesCleared","regularCleared"}) do
        if not integer(save[key]) then return nil end
    end
    if save.lives<1 or save.lives>5 or save.level<1 or save.levelId<1 or save.regularCleared>100 or save.comboCount>save.maxCombo
        or save.regularCleared>save.stagesCleared or save.clearedLevel>save.level then return nil end
    for _,key in ipairs({"paddleX","paddleW","ballX","ballY","ballVX","ballVY","baseSpeed","speedMul","endlessSpeedBonus",
        "accelTimer","elapsedSecs","levelStartScore","levelStartTime","simRemainder"}) do if not finite(save[key]) then return nil end end
    local def=self.DIFFICULTY_DEFS[save.difficulty]
    if save.baseSpeed~=self.BASE_SPEED*def.speedMul or save.scoreFac~=def.scoreFac or save.accelInterval~=def.accelInterval or save.accelAmt~=def.accelAmt
        or save.speedMul<1+save.endlessSpeedBonus-1e-8 or save.endlessSpeedBonus<0 or save.elapsedSecs<0 or save.accelTimer<0
        or math.abs(save.endlessSpeedBonus-math.max(0,save.level-100)*0.2)>1e-6
        or save.levelStartScore<0 or save.levelStartScore%1~=0 or save.levelStartScore>save.score or save.levelStartTime<0 or save.levelStartTime>save.elapsedSecs
        or save.paddleW<32 or save.paddleW>def.paddleW*2 or save.paddleX<0 or save.paddleX>self.FIELD_W-save.paddleW
        or save.simRemainder<0 or save.simRemainder>=1/120+1e-8
        or type(save.endlessMode)~="boolean" or save.endlessMode~=(save.level>100)
        or type(save.ballActive)~="boolean" or type(save.ballDocked)~="boolean" or type(save.gameOver)~="boolean" or type(save.won)~="boolean"
        or type(save.balls)~="table" or #save.balls>2 or type(save.droppedPUs)~="table" or #save.droppedPUs>320
        or type(save.grid)~="table" or not integer(save.levelRows) or save.levelRows<1 or save.levelRows>16 then return nil end
    for _,key in ipairs({"bigTimer","smallTimer","fastTimer","slowTimer","strengthTimer"}) do
        if save[key]~=nil and (not finite(save[key]) or save[key]<0 or save[key]>(key=="bigTimer" and 10 or 8)) then return nil end
    end
    if save.bigTimer and save.smallTimer or save.fastTimer and save.slowTimer then return nil end
    if self:_EffectiveSpeed(save)>=math.huge then return nil end
    for _,b in ipairs(save.balls) do
        if type(b)~="table" then return nil end
        for _,key in ipairs({"x","y","vx","vy"}) do if not finite(b[key]) then return nil end end
    end
    local types={} for _,key in ipairs(self.PU_TYPES) do types[key]=true end
    for _,b in ipairs(save.droppedPUs) do if type(b)~="table" or not types[b.type] then return nil end
        for _,key in ipairs({"x","y","vy"}) do if not finite(b[key]) then return nil end end
    end
    local template=self:NewState(save.difficulty); self:ParseLevel(template,save.level)
    if template.levelRows~=save.levelRows then return nil end
    local left=0
    for row=1,save.levelRows do
        if type(save.grid[row])~="table" then return nil end
        for col=1,self.FIELD_COLS do
            local typ,original=save.grid[row][col],template.grid[row][col]
            if not integer(typ) or typ>5 or original==3 and typ~=3 or original==0 and typ~=0
                or original~=3 and typ==3 or typ~=0 and typ~=original and not (original==2 and typ==5) then return nil end
            if typ~=0 and typ~=3 then left=left+1 end
        end
    end
    if left~=save.blocksLeft or save.phase=="LEVEL_CLEAR" and (left~=0 or not save.won or not save.gameOver or not save.levelWon)
        or save.phase=="PLAYING" and (save.gameOver or save.won or not save.ballActive and #save.balls==0)
        or save.phase=="RESPAWNING" and (save.gameOver or save.ballActive or #save.balls>0) then return nil end
    if save.phase~="PLAYING" and (not finite(save.transitionRemaining) or save.transitionRemaining<0 or save.transitionRemaining>1) then return nil end
    if save.runResult~=nil and save.runResult~="WIN" then return nil end
    if save.runResult=="WIN" and save.regularCleared~=100 then return nil end
    if save.levelPerformance then
        local p=save.levelPerformance
        if type(p)~="table" or not integer(p.id) or p.id>save.levelId or not integer(p.level) or p.level>save.level
            or not integer(p.score) or p.score>save.score or not integer(p.elapsedMs) then return nil end
    end
    local state=self:Copy(save); self:Neutralize(state); return state
end

-- Read-only projection of a resumable run. No stars or inferred legacy unlocks.
function Logic:RunOverview(save,defaultDifficulty)
    if type(save)~="table" then return nil end
    local gs
    if save.version then
        gs=self:Restore(save)
        if not gs then return nil end
    else
        local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
        local diff=save.difficulty or save.diff or defaultDifficulty or "easy"
        if not self.DIFFICULTY_DEFS[diff] or not integer(save.level) or save.level<1
            or not integer(save.score or 0) or not integer(save.lives) or save.lives<1 or save.lives>5
            or save.completed~=nil and type(save.completed)~="boolean" then return nil end
        gs={level=save.level+(save.completed and 1 or 0),difficulty=diff,lives=save.lives,
            score=0,legacyScore=save.score or 0,legacyContinuation=true,stagesCleared=0,clearedLevel=0}
    end
    return {level=gs.level,currentLevel=math.min(gs.level,100),difficulty=gs.difficulty,
        score=gs.score,lives=gs.lives,legacy=gs.legacyContinuation==true,legacyScore=gs.legacyScore or 0,
        completedFrom=math.max(1,gs.level-gs.stagesCleared+(gs.phase=="LEVEL_CLEAR" and 1 or 0)),
        clearedLevel=math.min(gs.clearedLevel,100),runId=gs.runId,endless=gs.level>100}
end
