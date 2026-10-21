-- Barrel Brawl: session-owned run; all gameplay clocks live in Logic.
local A=_G.ArcadiaNexus
A.BRB_Engine={state="IDLE",board=nil,_sessionId=nil,_generation=0}
local E=A.BRB_Engine
local GAME_ID="BARREL_BRAWL"
local loop=A.GameLoop.Create("ArcadiaNexus_BRB_LoopFrame")
local function Sound(event)
    local S=A.BRB_Settings
    if not S:Get("soundEnabled") then return end
    local key,sound
    if event=="start" then sound=774
    elseif event=="jumped" then key,sound="soundOnScore",775
    elseif event=="hit" then key,sound="soundOnHit",847
    elseif event=="rescue" then key,sound="soundOnWin",8960
    elseif event=="warning" then key,sound="soundOnWarning",8959 end
    if sound and (not key or S:Get(key)) then PlaySound(sound,"SFX") end
end
function E:_StartLoop()
    loop:Start(function(dt) E:_Tick(dt) end,{stateCheck=function() return E.state=="PLAYING" end})
end
function E:_NeutralizeInput()
    A.BRB_Logic:Neutralize(self.board)
    self._blockedKeys=self._blockedKeys or {}
    for key,down in pairs(self._heldKeys or {}) do if down then self._blockedKeys[key]=true end end
    self._padBlocked=self._padBlocked or {}
    for key,down in pairs(self._padHeld or {}) do if down then self._padBlocked[key]=true end end
    if math.abs(self._padX or 0)>0.35 or math.abs(self._padY or 0)>0.35 then self._axisBlocked=true end
end
function E:RetryPending()
    local S=A.BRB_Settings
    for id,data in pairs(A.BRB_Logic:Copy(S:GetPending())) do
        A.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end
function E:StartGame(config)
    config=type(config)=="table" and config or {}
    local S,L=A.BRB_Settings,A.BRB_Logic
    local slot=tonumber(config.slot or S:GetActiveSlot())
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS then return end
    if config.mode and config.mode~="new" and config.mode~="continue" then return end
    local save=config.mode=="continue" and S:LoadProgress(slot) or nil
    if config.mode=="continue" and not save then return end
    local diff=save and (save.difficulty or save.diff) or config.difficulty or S:Get("difficulty")
    if not L.DIFFICULTY[diff] then return end
    local board
    if save and save.version then
        if save.version~=2 then return end
        board=L:Restore(save)
        if not board or not A.LocalResults:GetSerial(GAME_ID,board.runId) then return end
    else
        local cfg={difficulty=diff}
        if save then
            local function number(n) return type(n)=="number" and n==n and n>=0 and n<math.huge end
            if not number(save.level) or save.level<1 or save.level%1~=0
                or not number(save.lives) or save.lives%1~=0 or save.lives<1 or save.lives>3
                or not number(save.score or 0) or (save.score or 0)%1~=0 or not number(save.time or 0)
                or save.stats~=nil and type(save.stats)~="table" then return end
            for _,key in ipairs({"jumped","rescues","spawned"}) do
                local n=save.stats and save.stats[key] or 0
                if not number(n) or n%1~=0 then return end
            end
            for _,k in ipairs({"level","score","lives","time","stats"}) do cfg[k]=save[k] end
        end
        board=L:NewBoard(cfg)
        if save then board.legacyContinuation=true end
    end
    self:RetryPending()
    local receipt=board.runId and A.LocalResults:GetReceipt(board.runId)
    if receipt then return end
    if self.board and self.state~="IDLE" and self.state~="GAMEOVER" then S:SaveProgress(self.board,self.activeSlot,self.state) end
    loop:Stop(); self:_NeutralizeInput(); self._generation=self._generation+1
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return end
    self.activeSlot=slot; S:SetActiveSlot(slot)
    board.runId=board.runId or A.LocalResults:NewRun(GAME_ID)
    self.board=board; self.state=save and save.version==2 and save.phase or "PLAYING"
    S:SaveProgress(board,slot,self.state)
    local gen=self._generation
    Sound("start"); A.Engine:Emit("BRB_GAME_STARTED",board)
    if self.board~=board or self._generation~=gen then return end
    if self.state=="PAUSED" then
        A.Lifecycle:PauseGame(GAME_ID,self._sessionId)
        local R=A.BRB_Renderer; if R and R.OnPauseChanged then R:OnPauseChanged(true) end
    else self:_StartLoop() end
end
function E:TogglePause()
    if self.state~="PLAYING" and self.state~="PAUSED" then return end
    self:_NeutralizeInput()
    local paused=self.state=="PLAYING"
    self.state=paused and "PAUSED" or "PLAYING"
    if paused then loop:Stop(); A.Lifecycle:PauseGame(GAME_ID,self._sessionId)
    else A.Lifecycle:ResumeGame(GAME_ID,self._sessionId); self:_StartLoop() end
    local R=A.BRB_Renderer; if R and R.OnPauseChanged then R:OnPauseChanged(paused) end
end
function E:_Tick(dt)
    if self.state~="PLAYING" or not self.board then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput() end
    local board,gen=self.board,self._generation
    local events=A.BRB_Logic:Update(board,dt)
    if board.state=="LOST" then self:_HandleGameOver(true) end
    if self.board~=board or self._generation~=gen then return end
    for _,ev in ipairs(events) do
        if ev.type=="hit" or ev.type=="rescue" then self:_NeutralizeInput() end
        Sound(ev.type)
    end
    local R=A.BRB_Renderer
    if R and R.OnFrame then R:OnFrame(board,events) end
    if self.board~=board or self._generation~=gen then return end
    if self.state=="GAMEOVER" and R and R.OnGameOver then R:OnGameOver(board,board.resultData and board.resultData.newHighscore) end
end
function E:_HandleGameOver(deferPresentation)
    local board=self.board
    if not board or board.state~="LOST" or board.resultLocked then return false end
    board.resultLocked=true; self.state="GAMEOVER"; loop:Stop(); self:_NeutralizeInput()
    local S=A.BRB_Settings; S:ClearProgress(self.activeSlot)
    -- Session bleibt bis SaveAndPause/StopGame, damit der Ergebnisdialog beim Verlassen schließt.
    local data={gameId=GAME_ID,difficulty=board.difficulty,score=board.score,ruleVersion=2,runId=board.runId,
        result=board.stats.rescues>0 and "WIN" or "LOSS",reason=board.endCause,
        elapsedMs=math.floor(board.time*1000+0.5),
        stats={levelReached=board.level,rescues=board.stats.rescues,barrelsJumped=board.stats.jumped}}
    S:SavePending(data); A.Engine:Emit("GAME_RESULT",data)
    if data.processed then S:ClearPending(board.runId) end
    board.resultData=data
    if self.board~=board then return true end
    local R=A.BRB_Renderer
    if not deferPresentation and R and R.OnGameOver then R:OnGameOver(board,data.newHighscore) end
    return true
end
function E:HandleKeyDown(key)
    self._heldKeys,self._blockedKeys=self._heldKeys or {},self._blockedKeys or {}
    if self._heldKeys[key] then return end
    self._heldKeys[key]=true
    if self._blockedKeys[key] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    if key=="ESCAPE" then
        if self.state~="IDLE" then self:StopGame() end
        return
    elseif key=="P" then self:TogglePause(); return end
    if self.state~="PLAYING" or not self.board then return end
    local dir=({A="left",LEFT="left",D="right",RIGHT="right",W="up",UP="up",S="down",DOWN="down"})[key]
    if dir then A.BRB_Logic:Press(self.board,dir)
    elseif key=="SPACE" then A.BRB_Logic:QueueJump(self.board) end
end
function E:HandleKeyUp(key)
    self._heldKeys=self._heldKeys or {}; self._blockedKeys=self._blockedKeys or {}
    self._heldKeys[key]=nil; self._blockedKeys[key]=nil
    local dir=({A="left",LEFT="left",D="right",RIGHT="right",W="up",UP="up",S="down",DOWN="down"})[key]
    if dir and self.board then A.BRB_Logic:Release(self.board,dir) end
end
function E:HandlePadButton(btn,pressed)
    self._padHeld,self._padBlocked=self._padHeld or {},self._padBlocked or {}
    self._padHeld[btn]=pressed or nil
    if not pressed then self._padBlocked[btn]=nil end
    local key=({PAD1="SPACE",PADFORWARD="P",PAD4="P",PADLEFT="LEFT",PADRIGHT="RIGHT",PADUP="UP",PADDOWN="DOWN"})[btn]
    if not key then return end
    if not pressed then self:HandleKeyUp(key) elseif not self._padBlocked[btn] then self:HandleKeyDown(key) end
end
function E:HandlePadAxis(x,y,dz)
    dz=dz or 0.35; self._padX,self._padY=x,y
    if math.abs(x)<=dz and math.abs(y)<=dz then self._axisBlocked=nil end
    if self._axisBlocked then return end
    for key,down in pairs({LEFT=x < -dz,RIGHT=x > dz,UP=y > dz,DOWN=y < -dz}) do
        if down then self:HandleKeyDown(key) else self:HandleKeyUp(key) end
    end
end
function E:SaveAndPause()
    local S=A.BRB_Settings
    if self.board and (self.state=="PLAYING" or self.state=="PAUSED") then S:SaveProgress(self.board,self.activeSlot,self.state) end
    if self._sessionId then A.Lifecycle:PauseGame(GAME_ID,self._sessionId); A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    loop:Stop(); self:_NeutralizeInput(); self.state="IDLE"; self.board=nil; self._generation=self._generation+1
end
function E:StopGame()
    self:SaveAndPause()
    A.Engine:Emit("BRB_GAME_STOPPED")
end
