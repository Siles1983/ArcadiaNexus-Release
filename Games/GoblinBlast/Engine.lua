-- Goblin Blast: complete owned worlds, fixed gameplay clocks and one twelve-stage run.
local ArcadiaNexus=_G.ArcadiaNexus
ArcadiaNexus.GB_Engine={board=nil,state="IDLE",_sessionId=nil,_generation=0}
local E=ArcadiaNexus.GB_Engine
local GAME_ID="GOBLINBLAST"
local _gameLoop=ArcadiaNexus.GameLoop.Create("ArcadiaNexus_GB_LoopFrame")
local function PlayGB(event)
    local S = ArcadiaNexus.GB_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "start" then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "explosion" and S:Get("soundOnExplode") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    elseif event == "powerup" and S:Get("soundOnPowerup") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 775, "SFX")
    elseif (event == "hit" or event == "lost") and S:Get("soundOnDie") then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847, "SFX")
    elseif (event == "level_won" or event == "final_won") and S:Get("soundOnWin") then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "SFX")
    end
end

local function Call(method,...)
    local R=ArcadiaNexus.GB_Renderer; if R and R[method] then R[method](R,...) end
end
function E:_StartLoop() _gameLoop:Start(function(dt) E:_Tick(dt) end,{stateCheck=function() return E.state=="PLAYING" end}) end
function E:_StopLoop() _gameLoop:Stop() end
function E:_Neutralize()
    self._blocked=self._blocked or {}
    for token in pairs(self._held or {}) do self._blocked[token]=true end
    if self.board then self.board.heldDirs={} end
end
function E:_SaveProgress()
    if self.board and (self.state=="PLAYING" or self.state=="LEVELWIN" or self.state=="PAUSED") then
        local phase=self.state=="PAUSED" and self._resumePhase=="LEVELWIN" and "PAUSED_LEVELWIN" or self.state
        ArcadiaNexus.GB_Settings:SaveSlot(self.activeSlot,ArcadiaNexus.GB_Logic:Snapshot(self.board,phase))
    end
end
function E:RetryPending()
    local L,S=ArcadiaNexus.GB_Logic,ArcadiaNexus.GB_Settings
    for id,data in pairs(L:Copy(S:GetPending())) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data); if data.processed then S:ClearPending(id) end
    end
end
function E:_Payload(result,closed)
    local b=self.board; local st=b.stats
    return {gameId=GAME_ID,difficulty=b.difficulty,ruleVersion=2,runId=b.runId,score=b.score,result=result,closed=closed,
        legacyContinuation=b.legacyContinuation,legacyScore=b.legacyScore,levelPerformances=ArcadiaNexus.GB_Logic:Copy(b.levelPerformances),
        stats={walls=st.walls,enemies=st.enemies,powerups=st.powerups,maxChain=st.maxChain,levelReached=b.level,
            clearedLevel=b.clearedLevel,stagesCleared=b.stagesCleared}}
end
function E:_Book(result,closed)
    local S=ArcadiaNexus.GB_Settings; local data=self:_Payload(result,closed)
    S:SavePending(data); ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
    if data.processed then S:ClearPending(data.runId) end
    return data
end
function E:_Tick(dt)
    if self.state~="PLAYING" or not self.board then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_Neutralize() end
    local b=self.board; local gen=self._generation
    local events=ArcadiaNexus.GB_Logic:Update(b,dt)
    -- Resolve/freeze/save/book before sounds, sprites, or external callbacks.
    if b.state=="LEVEL_WON" then self:_HandleLevelWin() elseif b.state=="LOST" then self:_HandleGameOver() end
    if self.board~=b or self._generation~=gen then return end
    for _,event in ipairs(events) do if event.type~="level_won" and event.type~="lost" then PlayGB(event.type) end end
    Call("OnFrame",b,events)
end
function E:StartGame(config,resumeSaved)
    local L,S=ArcadiaNexus.GB_Logic,ArcadiaNexus.GB_Settings
    config=type(config)=="table" and config or {mode=resumeSaved and "continue" or "new"}
    local slot=tonumber(config.slot or S:GetActiveSlot()); local mode=config.mode or "new"
    if not slot or slot%1~=0 or slot<1 or slot>3 or mode~="new" and mode~="continue" then return false end
    local b,phase
    if mode=="continue" then
        local saved=S:LoadSlot(slot); b=L:Restore(saved); phase=type(saved)=="table" and saved.phase or "PLAYING"
        if not b or saved.version and not ArcadiaNexus.LocalResults:GetSerial(GAME_ID,b.runId) then Call("ShowInvalidSave"); return false end
    else
        local diff=config.difficulty or S:Get("difficulty")
        if not L.DIFFS[diff] then return false end
        b=L:NewBoard({difficulty=diff})
    end
    self:RetryPending()
    local receipt=b.runId and ArcadiaNexus.LocalResults:GetReceipt(b.runId)
    if receipt and receipt.closed then Call("ShowInvalidSave"); return false end
    self:_SaveProgress(); self:_StopLoop(); self:_Neutralize(); self._generation=self._generation+1
    local previous=self._sessionId
    self._sessionId=ArcadiaNexus.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self.activeSlot=slot; S:SetActiveSlot(slot); b.runId=b.runId or ArcadiaNexus.LocalResults:NewRun(GAME_ID)
    self.board=b; self._resumePhase=b.state=="LEVEL_WON" and "LEVELWIN" or "PLAYING"
    self.state=(phase=="PAUSED" or phase=="PAUSED_LEVELWIN") and "PAUSED" or self._resumePhase
    self:_SaveProgress(); local gen=self._generation
    Call("OnGameStarted",b)
    if self.board~=b or self._generation~=gen then return true end
    if self.state=="PAUSED" then ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
    elseif self.state=="LEVELWIN" then Call("ShowLevelWin",b) else self:_StartLoop() end
    if self.board~=b or self._generation~=gen then return true end
    PlayGB("start"); ArcadiaNexus.Engine:Emit("GB_GAME_STARTED",b); return true
end
function E:_HandleLevelWin()
    local b=self.board
    if not b or self.state~="PLAYING" or b.state~="LEVEL_WON" or b.clearedLevel>=b.level or b.terminal then return false end
    self:_StopLoop(); self:_Neutralize(); b.clearedLevel=b.level; b.stagesCleared=b.stagesCleared+1
    b.levelPerformances[b.stagesCleared]={id=b.stagesCleared,level=b.level,score=b.score-b.stageStartScore,elapsedMs=math.floor(b.levelTime*1000+.5)}
    if b.level==12 then self:_Finish("WIN")
    else
        self.state="LEVELWIN"; self:_SaveProgress(); local gen=self._generation
        b.resultData=self:_Book("STATS",false)
        if self.board~=b or self._generation~=gen or self.state~="LEVELWIN" then return true end
        PlayGB("level_won"); Call("ShowLevelWin",b)
    end
    return true
end
function E:ContinueToNextLevel(expected)
    local b=self.board
    if self.state~="LEVELWIN" or not b or expected and expected~=b or b.clearedLevel~=b.level or b.level>=12 then return false end
    self:RetryPending(); if self.board~=b or self.state~="LEVELWIN" then return false end
    local L=ArcadiaNexus.GB_Logic
    local nextBoard=L:NewBoard({difficulty=b.difficulty,level=b.level+1,score=b.score,lives=b.lives,radius=b.player.radius,
        bombsMax=b.player.bombsMax,time=b.time,stats=L:Copy(b.stats),runId=b.runId,clearedLevel=b.clearedLevel,
        stagesCleared=b.stagesCleared,levelPerformances=L:Copy(b.levelPerformances),nextEnemyId=b.nextEnemyId,nextBombId=b.nextBombId,
        legacyContinuation=b.legacyContinuation,legacyScore=b.legacyScore})
    self:_Neutralize(); self.board=nextBoard; self.state="PLAYING"; self._generation=self._generation+1
    self:_SaveProgress(); local gen=self._generation; Call("OnLevelAdvanced",nextBoard)
    if self.board==nextBoard and self._generation==gen and self.state=="PLAYING" then self:_StartLoop() end
    return true
end
function E:_Finish(result)
    local b=self.board; if not b or b.terminal then return end
    b.terminal=true; b.runResult=result; self.state="GAMEOVER"; self:_StopLoop(); self:_Neutralize()
    ArcadiaNexus.GB_Settings:DeleteSlot(self.activeSlot)
    if self._sessionId then ArcadiaNexus.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    local gen=self._generation; b.resultData=self:_Book(result,true)
    if self.board~=b or self._generation~=gen then return end
    PlayGB(result=="WIN" and "final_won" or "lost")
    Call(result=="WIN" and "ShowFinalWin" or "OnGameLost",b,b.resultData.newHighscore==true)
end
function E:_HandleGameOver()
    if not self.board or self.board.terminal then return end
    self.board.state="LOST"; self.board.lives=0; self:_Finish("LOSS")
end
function E:Pause()
    if self.state~="PLAYING" and self.state~="LEVELWIN" then return end
    self._resumePhase=self.state; self:_Neutralize(); self.state="PAUSED"; self:_StopLoop()
    ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
end
function E:Resume()
    if self.state~="PAUSED" then return end
    local b,gen=self.board,self._generation
    self:_Neutralize(); self.state=self._resumePhase or "PLAYING"
    ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID,self._sessionId); Call("HidePause")
    if self.board~=b or self._generation~=gen then return end
    if self.state=="PLAYING" then self:_StartLoop() else Call("ShowLevelWin",self.board) end
end
function E:TogglePause() if self.state=="PAUSED" then self:Resume() else self:Pause() end end
local keys={W="up",UP="up",S="down",DOWN="down",A="left",LEFT="left",D="right",RIGHT="right"}
function E:HandleKeyDown(key,token)
    token=token or key; self._held,self._blocked=self._held or {},self._blocked or {}
    if self._held[token] then return end
    self._held[token]=keys[key] or key
    if self._blocked[token] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_Neutralize(); return end
    if key=="ESCAPE" then self:StopGame(); return elseif key=="P" then self:TogglePause(); return end
    if self.state~="PLAYING" then self._blocked[token]=true; return end
    local L=ArcadiaNexus.GB_Logic
    if keys[key] then L:PressDir(self.board,keys[key]) elseif key=="SPACE" then L:PlaceBomb(self.board) end
end
function E:HandleKeyUp(key,token)
    token=token or key; self._held,self._blocked=self._held or {},self._blocked or {}
    local dir=self._held[token]; self._held[token]=nil; self._blocked[token]=nil
    if not self.board or not keys[key] then return end
    for held,command in pairs(self._held) do if command==dir and not self._blocked[held] then return end end
    ArcadiaNexus.GB_Logic:ReleaseDir(self.board,keys[key])
end
function E:HandlePadButton(btn,pressed)
    local key=({PADLEFT="LEFT",PADRIGHT="RIGHT",PADUP="UP",PADDOWN="DOWN",PAD1="SPACE",PAD4="P",PADFORWARD="P",PADBACK="ESCAPE"})[btn]
    if key then if pressed then self:HandleKeyDown(key,btn) else self:HandleKeyUp(key,btn) end end
end
function E:HandlePadAxis(x,y,deadzone)
    local dz=deadzone or .35; local dir
    if math.max(math.abs(x),math.abs(y))>dz then dir=math.abs(x)>math.abs(y) and (x<0 and "LEFT" or "RIGHT") or (y<0 and "DOWN" or "UP") end
    for _,key in ipairs({"LEFT","RIGHT","UP","DOWN"}) do
        if key==dir then self:HandleKeyDown(key,"axis"..key) else self:HandleKeyUp(key,"axis"..key) end
    end
end
function E:SaveAndPause()
    self:_SaveProgress(); self:_StopLoop(); self:_Neutralize()
    if self._sessionId then ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); ArcadiaNexus.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self.state="IDLE"; self.board=nil; self._generation=self._generation+1
end
function E:StopGame()
    self:SaveAndPause(); local gen=self._generation
    ArcadiaNexus.Engine:Emit("GB_GAME_STOPPED")
    if self._generation==gen and self.state=="IDLE" then Call("EnterIdleState") end
end
