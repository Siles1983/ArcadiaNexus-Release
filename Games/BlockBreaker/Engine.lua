-- BlockBreaker: session-owned run, full world saves and separate transitions.
local A=_G.ArcadiaNexus
A.BB_Engine={state="IDLE",gameState=nil,_sessionId=nil,_generation=0}
local E=A.BB_Engine
local GAME_ID="BLOCKBREAKER"
local loop=A.GameLoop.Create("ArcadiaNexus_BB_LoopFrame")
local SND_PATH      = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\sounds\\"
local SND_BLOCK_HIT = SND_PATH .. "block_hit.wav"
local SND_PADDLE    = SND_PATH .. "paddle_side_hit.wav"
local SND_POWERUP   = SND_PATH .. "power_up.wav"
local SND_WALL_HIT  = SND_PATH .. "wall_hit.wav"

-- SOUNDKIT-IDs für Sounds ohne eigene Datei
local SND_LIFELOST = 847   -- INTERFACE_SOUND_LOST_TARGET_UNIT
local SND_WIN      = 8959  -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_LOSE     = 847   -- IG_QUEST_ABANDON

-- Eigene Sound-Datei abspielen (nur wenn Sound aktiviert)
local function PlayBBFile(Settings, key, path)
    if Settings and Settings:Get("soundEnabled") and Settings:Get(key) then
        PlaySoundFile(path, "Master")
    end
end

-- SOUNDKIT-Sound abspielen
local function PlayBBSound(Settings, key, soundId)
    if Settings and Settings:Get("soundEnabled") and Settings:Get(key) then
        PlaySound(soundId, "Master")
    end
end


local function Call(method,...)
    local R=A.BB_Renderer
    if R and R[method] then R[method](R,...) end
end
function E:_StartLoop()
    loop:Start(function(dt) E:_Tick(dt) end,{stateCheck=function() return E.state=="PLAYING" or E.state=="RESPAWNING" or E.state=="LEVEL_CLEAR" end})
end
function E:_StopLoop() loop:Stop() end
function E:_NeutralizeInput()
    A.BB_Logic:Neutralize(self.gameState)
    self._blocked=self._blocked or {}
    for key,down in pairs(self._held or {}) do if down then self._blocked[key]=true end end
    if math.abs(self._padX or 0)>0.35 then self._axisBlocked=true end
end
function E:_Book(gs)
    if gs.devPlaytest or self._booking then return end
    local result=gs.runResult or (gs.runClosed and not gs.legacyCompleted and "LOSS") or "STATS"
    local data={gameId=GAME_ID,difficulty=gs.difficulty,ruleVersion=2,layoutVersion=2,runId=gs.runId,
        score=gs.score,result=result,closed=gs.runClosed==true,legacyCompleted=gs.legacyCompleted==true,
        stats={levelReached=gs.level,maxCombo=gs.maxCombo,clearedLevel=gs.clearedLevel,
            stagesCleared=gs.stagesCleared,regularCleared=gs.regularCleared},levelPerformance=gs.levelPerformance}
    local S=A.BB_Settings
    S:SavePending(data); self._booking=true
    A.Engine:Emit("GAME_RESULT",data); self._booking=nil
    if data.processed then S:ClearPending(gs.runId) end
    gs.resultData=data
end
function E:RetryPending()
    local S=A.BB_Settings
    for id,data in pairs(A.BB_Logic:Copy(S:GetPending())) do
        A.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end
function E:_Save()
    local gs=self.gameState
    if not gs or gs.devPlaytest or gs.practice then return end
    local S=A.BB_Settings
    if gs.runClosed or gs.phase=="GAMEOVER" then S:ClearProgress(self.activeSlot)
    else S:SaveProgress(gs,self.activeSlot,self.state) end
end
local function ReceiptAllows(gs)
    local receipt=gs.runId and A.LocalResults:GetReceipt(gs.runId)
    return not receipt or not (receipt.closed or receipt.score>gs.score
        or receipt.personalStats.stagesCleared>gs.stagesCleared
        or receipt.personalStats.levelReached>gs.level or receipt.personalStats.maxCombo>gs.maxCombo
        or receipt.result~="STATS" and receipt.result~=gs.runResult)
end
function E:OpenRunMap(slot)
    if self.state~="IDLE" and self.state~="MAP" then return false end
    local L,S=A.BB_Logic,A.BB_Settings
    slot=tonumber(slot)
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS then return false end
    local raw=S:LoadSlot(slot)
    local overview=L:RunOverview(raw,S:Get("difficulty"))
    if not overview then return false end
    if raw.version then
        local gs=L:Restore(raw)
        if not A.LocalResults:GetSerial(GAME_ID,gs.runId) or not ReceiptAllows(gs)
            or L:_EffectiveSpeed(gs)>=math.huge then return false end
    end
    self._runMap=overview; self._mapSource=raw; self._mapSlot=slot
    self.state="MAP"; Call("ShowRunMap",overview); return true
end
function E:ResumeRunMap(level)
    if self.state~="MAP" or not self._runMap or self._runMap.timeOnly or level and
        (self._runMap.endless or level~=self._runMap.level) then return false end
    if A.BB_Settings:LoadSlot(self._mapSlot)~=self._mapSource then return false end
    return self:StartGame({slot=self._mapSlot,mode="continue"})
end
function E:OpenTimeMap(slot, difficulty)
    if self.state~="IDLE" and self.state~="MAP" then return false end
    local S=A.BB_Settings
    slot=tonumber(slot)
    if not slot or slot<1 or slot>S.MAX_SLOTS then return false end
    if S:LoadSlot(slot) then return self:OpenRunMap(slot) end
    self._runMap={timeOnly=true,level=1,currentLevel=1,difficulty=difficulty or S:Get("difficulty"),
        score=0,lives=0,completedFrom=1,clearedLevel=0,endless=false}
    self._mapSource=nil; self._mapSlot=slot
    self.state="MAP"; Call("ShowRunMap",self._runMap); return true
end
function E:_BeginPractice(slot, level, difficulty)
    local L,S=A.BB_Logic,A.BB_Settings
    slot,level=tonumber(slot),tonumber(level)
    if not slot or slot<1 or slot>S.MAX_SLOTS or not L.DIFFICULTY_DEFS[difficulty] then return false end
    if not level or level<1 or level%1~=0 or level>=math.huge then return false end
    if self.gameState and not self.gameState.practice then return false end
    local gs=L:NewState(difficulty)
    gs.level=level
    if level>100 then gs.endlessMode=true; gs.endlessSpeedBonus=(level-100)*0.2 end
    L:ReloadLevel(gs)
    gs.practice=true
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self.gameState=nil
    self:_StopLoop(); self:_NeutralizeInput(); self._generation=self._generation+1
    self._runMap=nil; self._mapSource=nil; self._mapSlot=nil
    self.activeSlot=slot; S:SetActiveSlot(slot)
    self.gameState=gs; self.state="PLAYING"
    Call("OnGameStarted",gs); self:_StartLoop(); return true
end
function E:_LeavePractice()
    local slot=self.activeSlot
    local diff=self.gameState and self.gameState.difficulty
    self.gameState=nil
    self:_StopLoop(); self:_NeutralizeInput()
    if self._sessionId then A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self._generation=self._generation+1; self.state="IDLE"
    return slot,diff
end
function E:PracticeStop()
    if not (self.gameState and self.gameState.practice) then return false end
    self:_LeavePractice(); Call("EnterIdleState"); return true
end
function E:SelectRunMap(level)
    if self.state~="MAP" or not self._runMap then return false end
    local m=self._runMap
    level=tonumber(level)
    if not level or level%1~=0 or level<1 or level>100 then return false end
    local S=A.BB_Settings
    if m.timeOnly then
        if not S:GetLevelTime(self._mapSlot,level) then return false end
        return self:_BeginPractice(self._mapSlot,level,m.difficulty or S:Get("difficulty"))
    end
    if S:LoadSlot(self._mapSlot)~=self._mapSource or m.endless then return false end
    if level>=m.completedFrom and level<=m.clearedLevel then
        return self:_BeginPractice(self._mapSlot,level,m.difficulty)
    end
    if level==m.level then return self:ResumeRunMap(level) end
    return false
end
function E:ReplayFromResult(gs)
    if self.gameState~=gs or not gs then return false end
    local slot,level,diff=self.activeSlot,gs.level,gs.difficulty
    if gs.practice then self:_LeavePractice()
    elseif self.state=="LEVEL_CLEAR" and gs.clearReady then self:SaveAndPause()
    else self:StopGame() end
    return self:_BeginPractice(slot,level,diff)
end
function E:ResultToMap(gs)
    if self.gameState~=gs or not gs then return false end
    local slot,diff=self.activeSlot,gs.difficulty
    if gs.practice then
        self:_LeavePractice()
    elseif self.state=="LEVEL_CLEAR" and gs.clearReady then
        self:SaveAndPause()
    else
        self:StopGame()
    end
    if A.BB_Settings:LoadSlot(slot) then return self:OpenRunMap(slot) end
    return self:OpenTimeMap(slot,diff)
end
function E:StartGame(config,resumeSaved)
    local L,S=A.BB_Logic,A.BB_Settings
    if type(config)~="table" then config={difficulty=config,mode=resumeSaved and "continue" or "new"} end
    local slot=tonumber(config.slot or S:GetActiveSlot())
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS then return false end
    local mode=config.mode or "continue"
    if mode~="new" and mode~="continue" then return false end
    if mode=="new" then S:ClearLevelTimes(slot) end
    local save=mode=="continue" and S:LoadProgress(slot) or nil
    if mode=="continue" and not save then return false end
    if save~=nil and type(save)~="table" then return false end
    local diff=save and (save.difficulty or save.diff) or config.difficulty or S:Get("difficulty")
    if not L.DIFFICULTY_DEFS[diff] then return false end
    local gs
    if save and save.version then
        gs=L:Restore(save)
        if not gs or not A.LocalResults:GetSerial(GAME_ID,gs.runId) then return false end
    else
        if save then
            local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
            if not integer(save.level) or save.level<1 or not integer(save.score or 0)
                or not integer(save.lives) or save.lives<1 or save.lives>5
                or save.completed~=nil and type(save.completed)~="boolean" then return false end
            save.level=save.level+(save.completed and 1 or 0)
        end
        gs=L:NewState(diff,save); L:ParseLevel(gs,gs.level); L:ResetBall(gs)
    end
    if L:_EffectiveSpeed(gs)>=math.huge then return false end
    self:RetryPending()
    if not ReceiptAllows(gs) then return false end
    self:_Save(); self:_StopLoop(); self:_NeutralizeInput(); self._generation=self._generation+1
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self._runMap=nil; self._mapSource=nil; self._mapSlot=nil
    self.activeSlot=slot; S:SetActiveSlot(slot)
    gs.runId=gs.runId or A.LocalResults:NewRun(GAME_ID)
    gs.highScore=A.ScoreManager:GetBestScore(GAME_ID,diff)
    self.gameState=gs; self.state=save and save.version==2 and save.engineState or gs.phase
    local gen=self._generation
    self:_Save(); Call("OnGameStarted",gs)
    if self.gameState~=gs or self._generation~=gen then return true end
    if self.state=="PAUSED" then A.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
    else self:_StartLoop(); if self.state=="LEVEL_CLEAR" and gs.clearReady then self:_HandleLevelWin() end end
    return true
end
function E:Pause()
    if self.state~="PLAYING" and self.state~="RESPAWNING" and self.state~="LEVEL_CLEAR" then return end
    self:_NeutralizeInput(); self.state="PAUSED"; self:_StopLoop()
    A.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
end
function E:Resume()
    if self.state~="PAUSED" or not self.gameState then return end
    self:_NeutralizeInput(); self.state=self.gameState.phase
    A.Lifecycle:ResumeGame(GAME_ID,self._sessionId); Call("HidePause"); self:_StartLoop()
    if self.state=="LEVEL_CLEAR" and self.gameState.clearReady then self:_HandleLevelWin() end
end
function E:SaveAndPause()
    self:_Save()
    self._runMap=nil; self._mapSource=nil; self._mapSlot=nil
    if self._sessionId then A.Lifecycle:PauseGame(GAME_ID,self._sessionId); A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self:_StopLoop(); self:_NeutralizeInput(); self.state="IDLE"; self.gameState=nil; self._generation=self._generation+1
end
function E:StopGame() self:SaveAndPause(); Call("EnterIdleState") end
function E:_BeginLevelClear()
    local gs=self.gameState
    if not gs or gs.phase~="LEVEL_CLEAR" or gs.clearBooked then return end
    gs.clearBooked=true; self.state="LEVEL_CLEAR"; self:_NeutralizeInput()
    if not gs.devPlaytest and gs.level<=100 and gs.levelPerformance then
        A.BB_Settings:NoteLevelTime(self.activeSlot,gs.level,gs.levelPerformance.elapsedMs)
    end
    if gs.practice then return end
    if gs.regularCleared==100 then gs.runResult="WIN"
    elseif gs.legacyContinuation and gs.level==100 then gs.legacyCompleted=true end
    self:_Save(); self:_Book(gs)
end
function E:_HandleLevelWin()
    local gs=self.gameState
    if not gs or gs.phase~="LEVEL_CLEAR" or self.state~="LEVEL_CLEAR" then return end
    gs.clearReady=true; gs.transitionRemaining=0
    if gs.clearPresented then return end
    gs.clearPresented=true
    PlayBBSound(A.BB_Settings,"soundOnWin",SND_WIN)
    Call(gs.practice and "ShowPracticeResult" or "ShowLevelWin",gs)
end
function E:ContinueToNextLevel(expected)
    local gs=self.gameState
    if not gs or expected and expected~=gs or self.state~="LEVEL_CLEAR" or not gs.clearReady then return false end
    -- Claim the transition before callbacks; stale/double buttons cannot advance again.
    self.state="PLAYING"; self:_NeutralizeInput()
    A.BB_Logic:AdvanceLevel(gs); gs.clearBooked=nil; gs.clearPresented=nil
    self:_Save(); self:_Book(gs)
    if self.gameState~=gs then return false end
    Call("OnLevelAdvanced",gs); self:_StartLoop(); return true
end
function E:RetryLevel() return false end
function E:_HandleGameOver(_,defer)
    local gs=self.gameState
    if not gs or gs.runClosed then return end
    if gs.practice then
        if gs.practiceClosed then return end
        gs.practiceClosed=true; gs.phase="GAMEOVER"; gs.gameOver=true; self.state="GAMEOVER"
        self:_StopLoop(); self:_NeutralizeInput()
        if self._sessionId then A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
        if self.gameState~=gs then return end
        PlayBBSound(A.BB_Settings,"soundOnLose",SND_LOSE)
        if not defer then Call("ShowPracticeResult",gs) end
        return
    end
    gs.runClosed=true; gs.phase="GAMEOVER"; gs.gameOver=true; self.state="GAMEOVER"
    self:_StopLoop(); self:_NeutralizeInput(); self:_Save()
    if self._sessionId then A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self:_Book(gs)
    if self.gameState~=gs then return end
    PlayBBSound(A.BB_Settings,"soundOnLose",SND_LOSE)
    if not defer then Call("ShowGameOver",gs) end
end
function E:_Tick(dt)
    local gs=self.gameState
    if not gs or self.state=="PAUSED" or self.state=="IDLE" or self.state=="GAMEOVER" then return end
    local gen=self._generation
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput() end
    if self.state~="PLAYING" then
        if gs.clearReady then return end
        gs.transitionRemaining=math.max(0,(gs.transitionRemaining or 0)-math.max(0,math.min(dt,0.1)))
        Call("UpdatePhysics",gs,math.max(0,math.min(dt,0.1)))
        if self.gameState~=gs or self._generation~=gen then return end
        if gs.transitionRemaining<=1e-9 then
            if self.state=="RESPAWNING" then
                A.BB_Logic:ResetBall(gs); gs.phase="PLAYING"; self.state="PLAYING"; gs.transitionRemaining=nil
                self:_NeutralizeInput(); Call("UpdatePhysics",gs); Call("UpdateHUD",gs)
            elseif self.state=="LEVEL_CLEAR" then self:_HandleLevelWin() end
        end
        return
    end
    local actions=A.BB_Logic:Tick(gs,dt)
    -- Fix gameplay state and receipts before sound, effects or UI can hide/restart.
    local clear=gs.phase=="LEVEL_CLEAR"
    local ended=gs.phase=="GAMEOVER"
    if clear then self:_BeginLevelClear()
    elseif ended then self:_HandleGameOver(false,true)
    elseif gs.phase=="RESPAWNING" then self.state="RESPAWNING"; self:_NeutralizeInput() end
    if self.gameState~=gs or self._generation~=gen then return end
    local S=A.BB_Settings
    for _,act in ipairs(actions) do
        if act.type=="bounce_wall" then PlayBBFile(S,"soundOnBounce",SND_PADDLE); Call("OnWallHit",act.side,gs)
        elseif act.type=="bounce_paddle" then PlayBBFile(S,"soundOnBounce",SND_PADDLE); Call("OnPaddleHit",gs)
        elseif act.type=="break_block" then PlayBBFile(S,"soundOnBreak",SND_BLOCK_HIT); Call("OnBlockBroken",act.row,act.col,act.blockType,gs,act.points)
        elseif act.type=="damage_block" then PlayBBFile(S,"soundOnBreak",SND_WALL_HIT); Call("OnBlockDamaged",act.row,act.col,act.newTyp,gs)
        elseif act.type=="powerup_drop" then Call("OnPowerUpDropped",act.puType,act.x,act.y,gs)
        elseif act.type=="powerup_collect" then PlayBBFile(S,"soundOnPowerUp",SND_POWERUP); Call("OnPowerUpCollected",act.puType,gs)
        elseif act.type=="powerup_expired" then Call("OnPowerUpExpired",act.puType,gs)
        elseif act.type=="life_lost" then PlayBBSound(S,"soundOnLifeLost",SND_LIFELOST); if S:Get("screenFlash") then Call("FlashScreen",1,0.1,0.1) end end
        if self.gameState~=gs or self._generation~=gen then return end
    end
    Call("UpdatePhysics",gs,dt)
    if self.gameState~=gs or self._generation~=gen then return end
    Call("UpdateHUD",gs)
    if self.gameState~=gs or self._generation~=gen then return end
    if ended then Call(gs.practice and "ShowPracticeResult" or "ShowGameOver",gs)
    elseif clear then Call("OnLevelClear",gs) end
end
function E:HandleKey(key)
    local gs=self.gameState
    if key=="LEFT_UP" or key=="RIGHT_UP" then
        if gs then gs[key=="LEFT_UP" and "keyLeft" or "keyRight"]=false end; return
    end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    if key=="DEBUG" then
        if not (A.IsDevMode and A.IsDevMode()) then return end
        local S=A.BB_Settings; S:Set("debugOverlay",not S:Get("debugOverlay")); Call("RefreshDevOverlay"); return
    elseif key=="PAUSE" then if self.state=="PAUSED" then self:Resume() else self:Pause() end; return
    elseif key=="EXIT" then self:StopGame(); return end
    if self.state~="PLAYING" or not gs then return end
    if key=="LEFT_DOWN" then gs.keyLeft=true
    elseif key=="RIGHT_DOWN" then gs.keyRight=true
    elseif key=="LAUNCH" and A.BB_Logic:LaunchBall(gs) then Call("OnBallLaunched",gs) end
end
function E:HandleKeyDown(key)
    self._held,self._blocked=self._held or {},self._blocked or {}
    if self._held[key] then return end
    self._held[key]=true; if self._blocked[key] then return end
    local command=({A="LEFT_DOWN",LEFT="LEFT_DOWN",D="RIGHT_DOWN",RIGHT="RIGHT_DOWN",P="PAUSE",ESCAPE="EXIT",F8="DEBUG"})[key]
    if key=="SPACE" then command=self.state=="PLAYING" and self.gameState and self.gameState.ballDocked and "LAUNCH" or "PAUSE" end
    if command then self:HandleKey(command) end
end
function E:HandleKeyUp(key)
    self._held,self._blocked=self._held or {},self._blocked or {}; self._held[key]=nil; self._blocked[key]=nil
    if key=="A" or key=="LEFT" then self:HandleKey("LEFT_UP") elseif key=="D" or key=="RIGHT" then self:HandleKey("RIGHT_UP") end
end
function E:HandlePadButton(btn,pressed)
    local key=({PADLEFT="LEFT",PADRIGHT="RIGHT",PAD1="SPACE",PAD4="P",PADFORWARD="P"})[btn]
    if not key then return end
    key="PAD:"..key
    if not pressed then self:HandleKeyUp(key); if btn=="PADLEFT" then self:HandleKey("LEFT_UP") elseif btn=="PADRIGHT" then self:HandleKey("RIGHT_UP") end; return end
    self._held,self._blocked=self._held or {},self._blocked or {}
    if self._held[key] then return end
    self._held[key]=true; if self._blocked[key] then return end
    if btn=="PADLEFT" then self:HandleKey("LEFT_DOWN") elseif btn=="PADRIGHT" then self:HandleKey("RIGHT_DOWN")
    elseif btn=="PAD1" then self:HandleKey("LAUNCH") else self:HandleKey("PAUSE") end
end
function E:HandlePadAxis(x,dz)
    dz=dz or 0.35; self._padX=x
    if math.abs(x)<=dz then self._axisBlocked=nil end
    if self._axisBlocked then return end
    for key,down in pairs({LEFT=x < -dz,RIGHT=x > dz}) do
        local token="AXIS:"..key; self._held=self._held or {}; self._blocked=self._blocked or {}
        if not down then self._held[token]=nil; self._blocked[token]=nil; self:HandleKey(key.."_UP")
        elseif not self._held[token] then self._held[token]=true; if not self._blocked[token] then self:HandleKey(key.."_DOWN") end end
    end
end
function E:_MarkDevPlaytest()
    local gs=self.gameState
    if not gs or gs.devPlaytest then return end
    self:_Save(); gs.devPlaytest=true
end
function E:DevGoToLevel(level)
    if not (A.IsDevMode and A.IsDevMode()) then return false end
    level=tonumber(level)
    if not level or level%1~=0 or level<1 or level>100 or not A.BB_Levels[level] then return false end
    local old=self.gameState; local diff=old and old.difficulty or A.BB_Settings:Get("difficulty")
    self:SaveAndPause()
    local gs=A.BB_Logic:NewState(diff); gs.level=level; gs.devPlaytest=true; gs.highScore=0
    A.BB_Logic:ParseLevel(gs,level); A.BB_Logic:ResetBall(gs)
    local sid=A.Lifecycle:ClaimRestart(GAME_ID,self._sessionId)
    if not sid then return false end
    self._sessionId=sid
    self.gameState=gs; self.state="PLAYING"; Call("OnGameStarted",gs); self:_StartLoop(); return true
end
function E:DevDropPowerUp(puType)
    if not (A.IsDevMode and A.IsDevMode()) or self.state~="PLAYING" and self.state~="PAUSED" then return end
    local gs=self.gameState
    if not gs or gs.phase~="PLAYING" then return end
    local valid=false; for _,key in ipairs(A.BB_Logic.PU_TYPES) do if key==puType then valid=true end end
    if not valid then return end
    self:_MarkDevPlaytest()
    if A.BB_Logic:DevDropPowerUp(gs,puType) then Call("UpdatePhysics",gs) end
end
