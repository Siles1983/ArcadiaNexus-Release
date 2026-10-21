-- Whack-a-Mole – Games/WhackAMole/Engine.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.WAM_Engine = {}
local E = ArcadiaNexus.WAM_Engine

E._sessionId = nil

E.state         = "IDLE"
E._board        = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard
E._loop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_WAM_Loop")

function E:_ExpireTargets(now)
    local b,L,R=self._board,ArcadiaNexus.WAM_Logic,ArcadiaNexus.WAM_Renderer
    if not b then return end
    for r,row in ipairs(b.holes) do
        for c,h in ipairs(row) do
            if h.active and L:Expire(b,r,c,h.spawnId,now) and R then R:HideMole(r,c) end
        end
    end
end

function E:_Tick()
    local b=self._board
    if self.state~="PLAYING" or not b then return end
    local now=GetTime()
    local previousTime,previousMissed=b.timeLeft,b.missed
    b.timeLeft=math.max(0,math.ceil(b.endsAt-now))
    if now>=b.endsAt then self:_gameOver(false); return end
    self:_ExpireTargets(now)
    if now>=self._nextSpawnAt then
        self._nextSpawnAt=now+ArcadiaNexus.WAM_Logic:GetSpawnInterval(b)
        self:_spawnMole()
        if b.timeLeft<=15 and math.random(100)<=35 then
            local sid=self._sessionId
            _timerGuard:After(0.25,function()
                if E._board==b and E.state=="PLAYING" and ArcadiaNexus.GameSession:IsSession(E,sid) then E:_spawnMole() end
            end)
        end
    end
    if ArcadiaNexus.WAM_Renderer and (previousTime~=b.timeLeft or previousMissed~=b.missed) then
        ArcadiaNexus.WAM_Renderer:UpdateHUD(b)
    end
end

function E:RetryResult()
    local b=self._board
    if not b or not b.resultData or b.resultData.processed or self._booking then return false end
    self._booking=true
    ArcadiaNexus.Engine:Emit("GAME_RESULT",b.resultData)
    self._booking=false
    if b.resultData.processed then
        local settings=ArcadiaNexus.Persistence:GetGameSettings("WHACKAMOLE")
        if settings.pendingResults then settings.pendingResults[b.runId]=nil end
    end
    return b.resultData.processed==true
end

function E:FlushPendingResults()
    local settings=ArcadiaNexus.Persistence:GetGameSettings("WHACKAMOLE")
    for id,data in pairs(settings.pendingResults or {}) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then settings.pendingResults[id]=nil end
    end
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(difficulty)
    self:StopGame()
    self:FlushPendingResults()
    local previous = self._sessionId
    self._sessionId = ArcadiaNexus.Lifecycle:BeginGame("WHACKAMOLE")
    if not self._sessionId then self._sessionId = previous; return false end
    local L, R, S = ArcadiaNexus.WAM_Logic, ArcadiaNexus.WAM_Renderer, ArcadiaNexus.WAM_Settings
    local b = L:NewBoard(difficulty)
    b.gameActive, b.runId = true, ArcadiaNexus.LocalResults:NewRun("WHACKAMOLE")
    b.endsAt = GetTime()+30
    self._board, self.state = b, "PLAYING"
    self._nextSpawnAt = GetTime()+L:GetSpawnInterval(b)
    if R then R:EnterPlayState(b) end
    local sid=self._sessionId
    self._loop:Start(function() E:_Tick() end, {
        stateCheck=function() return E.state=="PLAYING" and E._board==b
            and ArcadiaNexus.GameSession:IsSession(E,sid) end,
    })
    if S:Get("soundEnabled")~=false and S:Get("soundOnRound")~=false then PlaySound(774) end
    return true
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    self._loop:Stop()
    _timerGuard:Cancel()
    if self._board then self._board.gameActive=false end
    if self._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("WHACKAMOLE",self._sessionId)
        self._sessionId=nil
    end
    self.state,self._board="IDLE",nil
    local R=ArcadiaNexus.WAM_Renderer
    if R and R.CancelEffects then R:CancelEffects() end
end

-- ============================================================
-- _spawnMole
-- ============================================================
function E:_spawnMole()
    local b=self._board
    if self.state~="PLAYING" or not b then return false end
    if not ArcadiaNexus.GameSession:IsSession(self,self._sessionId) then return false end
    local now=GetTime()
    if now>=b.endsAt then self:_gameOver(false); return false end
    local L,R=ArcadiaNexus.WAM_Logic,ArcadiaNexus.WAM_Renderer
    self:_ExpireTargets(now)
    local free=L:GetFreeHoles(b)
    if #free==0 then return false end
    local slot=free[math.random(#free)]
    local bomb,icon=L:PickSpawnType(b)
    local id=L:Spawn(b,slot.r,slot.c,now,bomb,icon)
    if not id then return false end
    if R then R:ShowMole(slot.r,slot.c,icon,bomb) end
    local sid=self._sessionId
    _timerGuard:After(b.moleSpeed,function()
        if E.state~="PLAYING" or E._board~=b or not ArcadiaNexus.GameSession:IsSession(E,sid) then return end
        if GetTime()>=b.endsAt then E:_gameOver(false); return end
        if L:Expire(b,slot.r,slot.c,id,GetTime()) and R then
            R:HideMole(slot.r,slot.c); R:UpdateHUD(b)
        end
    end)
    return true
end

-- ============================================================
-- OnMoleClick – von Renderer aufgerufen
-- ============================================================
function E:OnMoleClick(r,c)
    local b=self._board
    if self.state~="PLAYING" or not b then return false end
    if not ArcadiaNexus.GameSession:IsSession(self,self._sessionId) then return false end
    local L,R,S=ArcadiaNexus.WAM_Logic,ArcadiaNexus.WAM_Renderer,ArcadiaNexus.WAM_Settings
    if not L:GetHole(b,r,c) then return false end
    if GetTime()>=b.endsAt then self:_gameOver(false); return false end
    local result,pts=L:HitMole(b,r,c,GetTime())
    if result=="bomb" then
        self:_gameOver(true,r,c)
    elseif result=="hit" then
        if R then R:HideMole(r,c); R:ShowHitEffect(r,c,"+"..pts); R:UpdateHUD(b) end
        if S:Get("soundEnabled")~=false and S:Get("soundOnHit")~=false then PlaySound(1115) end
    elseif result=="miss" or result=="expired" then
        if R then R:HideMole(r,c); R:ShowHitEffect(r,c,"",true); R:UpdateHUD(b) end
    end
    return result~="invalid"
end

-- ============================================================
-- _gameOver
-- ============================================================
function E:_gameOver(hitBomb,r,c)
    local b=self._board
    if self.state~="PLAYING" or not b or not ArcadiaNexus.WAM_Logic:Finish(b,hitBomb) then return false end
    self.state="GAMEOVER"
    self._loop:Stop()
    _timerGuard:Cancel()
    b.timeLeft=math.max(0,math.ceil(b.endsAt-GetTime()))
    b.resultData={gameId="WHACKAMOLE",runId=b.runId,difficulty=b.difficulty:lower(),
        score=b.score,result=b.result,reason=b.reason,ruleVersion=2,
        stats={hitCount=b.hitCount,missed=b.missed}}
    local pending=ArcadiaNexus.Persistence:GetGameSettings("WHACKAMOLE")
    pending.pendingResults=pending.pendingResults or {}
    pending.pendingResults[b.runId]=b.resultData
    self:RetryResult()
    local R,S=ArcadiaNexus.WAM_Renderer,ArcadiaNexus.WAM_Settings
    -- Result listeners can synchronously stop or replace this session.
    if self._board~=b or self.state~="GAMEOVER" then return true end
    if R then
        for row=1,b.gridSize do for col=1,b.gridSize do R:HideMole(row,col) end end
        R:UpdateHUD(b)
        if R.SetRoundClosed then R:SetRoundClosed(b) end
    end
    if hitBomb then
        if R and r and c then R:ShowBoomEffect(r,c) end
        if S:Get("soundEnabled")~=false and S:Get("soundOnBomb")~=false then PlaySound(8959) end
    elseif S:Get("soundEnabled")~=false and S:Get("soundOnRound")~=false then PlaySound(847) end
    local sid=self._sessionId
    local function show()
        if E._board==b and E.state=="GAMEOVER" and ArcadiaNexus.GameSession:IsSession(E,sid) and R then
            R:ShowGameOver(b,hitBomb)
        end
    end
    if hitBomb then _timerGuard:After(0.6,show) else show() end
    return true
end
