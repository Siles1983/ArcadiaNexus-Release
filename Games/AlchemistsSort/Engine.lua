-- M7: confirmed board commits own gameplay; rendering never commits a move/result.
local A=_G.ArcadiaNexus
local E={state="IDLE",_undosLeft=3,_hintsLeft=3,_undoStack={},_elapsed=0,_revision=0}
A.ALS_Engine=E
local guard=A.TimerGuard.New(); E._timerGuard=guard
local timer=A.TimerGuard.New()
local loop=A.GameLoop.Create("ArcadiaNexus_ALS_Work")
local function Clock() return debugprofilestop and debugprofilestop() or GetTime()*1000 end
local function UI(method,...)
    local R=A.ALS_Renderer
    if not R or not R[method] then return false end
    local ok,err=pcall(R[method],R,...)
    if not ok and GH_LogError then GH_LogError("AlchemistsSort",method..": "..tostring(err)) end
    return ok
end
local function Sound(key,name)
    local S=A.ALS_Settings
    if S:Get("soundEnabled") and S:Get(key) then
        pcall(PlaySoundFile,"Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\sounds\\"..name..".wav","SFX")
    end
end
function E:_SetState(state) self.state=state; UI("OnStateChanged",state); UI("UpdateHUD") end
function E:_InvalidateTimers()
    guard:Cancel(); loop:Stop()
    if self._job then self._job:Cancel(); self._job=nil end
    UI("CancelTransientEffects")
end
function E:_StartTimer(elapsed)
    self._elapsed=elapsed or self._elapsed or 0; self._startTime=GetTime()
    timer:Cancel(); timer:EveryTicker(1,function() UI("UpdateHUD") end)
end
function E:GetElapsed() return (self._elapsed or 0)+(self._startTime and GetTime()-self._startTime or 0) end
function E:_StopTimer() self._elapsed=self:GetElapsed(); self._startTime=nil; timer:Cancel() end
function E:CanAct() return not self._animating and (self.state=="PLAYING" or self.state=="SELECTED") end
function E:_Refresh()
    UI("BuildGrid",self._tubes,self._numTubes); UI("RefreshAll",self._tubes); UI("SetSelected",nil); UI("UpdateHUD")
end
function E:_EndSession()
    if self._sessionId then A.Lifecycle:EndGame("ALCHEMISTSSORT",self._sessionId); self._sessionId=nil end
end
function E:_Install(p, slot, level, mid)
    local L,S=A.ALS_Logic,A.ALS_Settings
    self._puzzle=L:Copy(p); self._slot,self._level=slot,level
    self._runId=mid and mid.runId or A.LocalResults:NewRun("ALCHEMISTSSORT")
    self._tubes=L:DeepCopy(mid and mid.tubes or p.initialTubes); self._initTubes=L:DeepCopy(p.initialTubes)
    self._baseTubes=p.baseTubes; self._numTubes=#self._tubes
    self._minMoves=p.minimum.kind=="exact" and p.minimum.moves or 0
    self._moveCount=mid and mid.moveCount or 0; self._revision=mid and mid.revision or 0
    self._undosLeft=mid and mid.undosLeft or 3; self._hintsLeft=mid and mid.hintsLeft or 3
    self._addedTube=mid and mid.addedTube or false
    self._usedUndo=mid and mid.usedUndo or false; self._usedHint=mid and mid.usedHint or false
    self._usedAddTube=mid and mid.usedAddTube or false
    self._undoStack=L:Copy(mid and mid.undoStack or {})
    self._selected=nil; self._animating=false; self._result=nil; self._lastMove=nil
    self._witness=(not mid and #p.solution>0) and {key=L:BoardKey(self._tubes),path=L:Copy(p.solution),index=1} or nil
    S:ReservePuzzle(slot,level,p); S:SetCurrentLevel(level)
    if not mid then S:IncrementPlayed() end
    self:_StartTimer(mid and mid.elapsed or 0)
    UI("HideLoading"); UI("HideLevelSelect"); self:_Refresh(); self:_SetState("PLAYING")
    S:SaveMidGame(slot,self:_CaptureMidGame())
end
function E:StartLevel(level)
    local S,L,G=A.ALS_Settings,A.ALS_Logic,A.ALS_LevelGen
    if not L:Int(level) or level<1 or not S:IsLevelUnlocked(level) or self.state=="RESULT_PENDING" then return false end
    local slot=S:GetActiveSlot()
    if S:GetPending(slot) then return false end
    local existing=S:GetPuzzle(slot,level)
    local broken=existing and not G:VerifyPuzzle(existing)
    if broken then existing=nil end
    local sid=A.Lifecycle:ClaimRestart("ALCHEMISTSSORT",self._sessionId)
    if not sid then return false end
    if broken then S:ClearPuzzle(slot,level) end
    self:_InvalidateTimers(); self:_StopTimer()
    self._sessionId=sid
    self._slot,self._level=slot,level; self._tubes=nil; self._selected=nil; self._result=nil
    self:_SetState("GENERATING"); UI("HideLevelSelect"); UI("ShowLoading")
    if existing then self:_Install(existing,slot,level); return true end
    if level<=1000 then
        local catalog=G:CatalogPuzzle(level)
        if catalog and G:VerifyPuzzle(catalog) then self:_Install(catalog,slot,level); return true end
        self:StopGame(); UI("ShowFeedback","msg_generation_failed"); return false
    end
    local job=G:Begin(level,Clock); self._job=job; local sid=self._sessionId
    loop:Start(function()
        if self._job~=job or self._sessionId~=sid then return end
        local status=job:Step()
        if status~="running" then
            loop:Stop(); self._job=nil; self._lastGeneration=job
            if status=="solved" then self:_Install(job.puzzle,slot,level)
            else self:StopGame(); UI("ShowFeedback","msg_generation_failed") end
        end
    end)
    return true
end
function E:PushUndo(tubes)
    if #self._undoStack>=3 then table.remove(self._undoStack,1) end
    self._undoStack[#self._undoStack+1]={tubes=A.ALS_Logic:DeepCopy(tubes),moves=self._moveCount}
end
function E:Undo()
    if not self:CanAct() or self._undosLeft<=0 or #self._undoStack==0 then return false end
    local prev=table.remove(self._undoStack)
    self._tubes=A.ALS_Logic:DeepCopy(prev.tubes)
    if self._addedTube and #self._tubes==self._baseTubes then self._tubes[#self._tubes+1]={} end
    self._numTubes=#self._tubes; self._moveCount=prev.moves; self._undosLeft=self._undosLeft-1
    self._usedUndo=true; self._selected=nil; self._revision=self._revision+1; self._lastMove=nil; self._witness=nil
    self:_SetState("PLAYING"); self:_Refresh(); return true
end
function E:ClearSelection()
    if self.state=="SELECTED" or self.state=="HINT" then
        UI("CancelTransientEffects"); self._selected=nil; self:_SetState("PLAYING"); UI("SetSelected",nil)
    end
end
function E:OnTubeClicked(idx)
    if self.state=="HINT" then self:ClearSelection() end
    if not self:CanAct() or not A.ALS_Logic:Int(idx,self._numTubes) or idx<1 then return false end
    local L=A.ALS_Logic
    if not self._selected then
        if #self._tubes[idx]==0 then return false end
        self._selected=idx; self:_SetState("SELECTED"); UI("SetSelected",idx); return true
    end
    local src=self._selected
    if src==idx then self:ClearSelection(); return true end
    local valid,count=L:CanMove(self._tubes,src,idx)
    if not valid then
        local S=A.ALS_Settings
        if S:Get("soundEnabled") and S:Get("soundOnInvalid") and C_Sound and C_Sound.PlaySound then
            pcall(C_Sound.PlaySound,SOUNDKIT and SOUNDKIT.UI_MINIMAP_PING or 1,"Master")
        end
        UI("ShakeTube",idx)
        self._selected=#self._tubes[idx]>0 and idx or nil
        self:_SetState(self._selected and "SELECTED" or "PLAYING"); UI("SetSelected",self._selected); return false
    end
    local before=L:DeepCopy(self._tubes); local after=L:DeepCopy(before)
    L:ExecuteMove(after[src],after[idx]); self:PushUndo(before)
    self._tubes=after; self._moveCount=self._moveCount+1; self._revision=self._revision+1
    self._selected=nil; self._lastMove={src,idx}
    local witness=self._witness; local nextMove=witness and witness.path[witness.index]
    if nextMove and nextMove[1]==src and nextMove[2]==idx then
        witness.index=witness.index+1; witness.key=L:BoardKey(after)
    else self._witness=nil end
    self._animating=true
    local terminal=L:CheckWin(after)
    if terminal then self:_OnWin(true) else self:_SetState("POURING") end
    local run,rev=self._runId,self._revision
    local finished=false
    local function finish()
        if finished or self._runId~=run or self._revision~=rev then return end
        finished=true; loop:Stop()
        UI("CancelPour")
        self._animating=false; self:_Refresh()
        if terminal then if self._result and self._result.processed then UI("ShowWinOverlay",self._result) end
        else self:_CheckWinOrContinue() end
    end
    local elapsed=0
    loop:Start(function(dt) elapsed=elapsed+dt; if elapsed>=0.7 then loop:Stop(); finish() end end)
    local ok=UI("AnimatePour",src,idx,before[src][1],count,finish,before,after)
    if not ok then loop:Stop(); finish() end
    return true
end
function E:_CheckWinOrContinue()
    if self._result then return end
    if A.ALS_Logic:CheckWin(self._tubes) then self:_OnWin()
    else self:_SetState("PLAYING"); if not A.ALS_Logic:HasAnyMove(self._tubes) then UI("ShowFeedback","msg_deadlock") end end
end
function E:RetryResult(deferDisplay)
    local data=self._result
    if not data then return false end
    local ok=pcall(A.Engine.Emit,A.Engine,"GAME_RESULT",data)
    if not ok or not data.processed then
        self:_SetState("RESULT_PENDING"); UI("ShowFeedback","msg_result_pending"); UI("ShowPendingResult"); return false
    end
    self.state="WIN"; UI("OnStateChanged","WIN"); UI("UpdateHUD")
    if not self._streakCounted then A.ALS_Settings._sessionStreak=data.stats.streak; self._streakCounted=true end
    if not deferDisplay then self._animating=false; self:_Refresh(); UI("ShowWinOverlay",data) end
    return true
end
function E:_OnWin(deferDisplay)
    if self._result or not self._runId or not A.ALS_Logic:CheckWin(self._tubes) then return false end
    self:_StopTimer(); self:_InvalidateTimers(); self.state="RESULT_PENDING"
    local L,S=A.ALS_Logic,A.ALS_Settings
    local exact=self._puzzle.minimum.kind=="exact" and not self._usedAddTube
    local stats={levelReached=self._level,level=self._level,moves=self._moveCount,
        elapsedMs=math.floor(self._elapsed*1000+0.5),time=math.floor(self._elapsed),
        minMoves=exact and self._puzzle.minimum.moves or 0,minimumExact=exact,
        streak=S:GetSessionStreak()+1,usedUndo=self._usedUndo,usedHint=self._usedHint,usedAddTube=self._usedAddTube}
    stats.time=math.floor(stats.elapsedMs/1000)
    stats.stars=L:GradeCampaignStars({tubes=self._tubes,usedUndo=stats.usedUndo,usedHint=stats.usedHint,usedAddTube=stats.usedAddTube})
    self._result={gameId="ALCHEMISTSSORT",difficulty="normal",result="WIN",score=0,skipHighscores=true,
        runId=self._runId,slot=self._slot,level=self._level,ruleVersion=2,ratingVersion=1,puzzleId=self._puzzle.puzzleId,
        minimum=L:Copy(self._puzzle.minimum),finalTubes=L:DeepCopy(self._tubes),aidClass=L:AidClass(stats),stats=stats}
    S:QueueResult(self._result); self._streakCounted=false; self:_EndSession()
    local done=self:RetryResult(deferDisplay); if done then Sound("soundOnWin","win") end
    return done
end
function E:ResetLevel()
    if not self:CanAct() then return false end
    local sid,run,rev=self._sessionId,self._runId,self._revision
    self._selected=nil; self:_SetState("RESET_CONFIRM"); UI("SetSelected",nil)
    local function answer(yes)
        if self._sessionId~=sid or self._runId~=run or self._revision~=rev or self.state~="RESET_CONFIRM" then return end
        if yes then
            self._tubes=A.ALS_Logic:DeepCopy(self._initTubes)
            if self._addedTube then self._tubes[#self._tubes+1]={} end
            self._numTubes=#self._tubes; self._moveCount=0; self._undoStack={}; self._revision=rev+1; self._lastMove=nil
            self._witness=#self._puzzle.solution>0 and {key=A.ALS_Logic:BoardKey(self._tubes),path=self._puzzle.solution,index=1} or nil
        end
        self:_SetState("PLAYING"); self:_Refresh()
    end
    if not UI("ShowConfirmReset",function() answer(true) end,function() answer(false) end) then answer(false) end
    return true
end
function E:AddEmptyTube()
    if not self:CanAct() or self._addedTube or self._numTubes>=11 then return false end
    self._addedTube=true; self._usedAddTube=true; self._tubes[#self._tubes+1]={}
    self._numTubes=#self._tubes; self._revision=self._revision+1; self._selected=nil; self._lastMove=nil
    if self._witness then self._witness.key=A.ALS_Logic:BoardKey(self._tubes) end
    self:_SetState("PLAYING"); self:_Refresh(); return true
end
function E:_HintUseful(first)
    local L=A.ALS_Logic
    if not first or not L:CanMove(self._tubes,first[1],first[2]) then return false end
    if #self._tubes[first[2]]==0 and L:TopCount(self._tubes[first[1]])==#self._tubes[first[1]] then return false end
    return not self._lastMove or first[1]~=self._lastMove[2] or first[2]~=self._lastMove[1]
end
function E:_OfferHint(first,run,rev)
    self._hintsLeft=self._hintsLeft-1; self._usedHint=true; self:_SetState("HINT")
    local function finish()
        if self._runId==run and self._revision==rev and self.state=="HINT" then self:_SetState("PLAYING") end
    end
    guard:After(2,finish); UI("ShowHint",first[1],first[2],finish)
end
function E:RequestHint()
    if not self:CanAct() or self._hintsLeft<=0 then return false end
    local L=A.ALS_Logic; self._selected=nil; UI("SetSelected",nil)
    local w=self._witness
    if w and w.key==L:BoardKey(self._tubes) and self:_HintUseful(w.path[w.index]) then
        self:_OfferHint(w.path[w.index],self._runId,self._revision); return true
    end
    self._witness=nil; self:_StopTimer(); self:_SetState("HINT_SEARCH")
    local job=L:NewSearch(self._tubes,{clock=Clock,maxStates=20000,maxEdges=80000,maxCpu=100,maxWait=1000})
    local sid,run,rev=self._sessionId,self._runId,self._revision; self._job=job
    loop:Start(function()
        if self._job~=job or self._sessionId~=sid or self._runId~=run or self._revision~=rev then return end
        local status=job:Step(64,1.5)
        if status=="running" then return end
        loop:Stop(); self._job=nil; self._lastHintSearch=job; self:_StartTimer()
        local first=status=="solved" and job.path[1]
        if not self:_HintUseful(first) then self:_SetState("PLAYING"); UI("ShowFeedback",status=="unsolvable" and "msg_no_hint" or "msg_hint_unknown"); return end
        self._witness={key=L:BoardKey(self._tubes),path=job.path,index=1}
        self:_OfferHint(first,run,rev)
    end)
    return true
end
function E:_CaptureMidGame()
    if not self._tubes or not self._runId or self._result then return nil end
    local L=A.ALS_Logic
    return {snapshotVersion=2,ruleVersion=2,ratingVersion=1,slot=self._slot,level=self._level,runId=self._runId,
        puzzle=L:Copy(self._puzzle),tubes=L:DeepCopy(self._tubes),initTubes=L:DeepCopy(self._initTubes),
        baseTubes=self._baseTubes,numTubes=self._numTubes,revision=self._revision,moveCount=self._moveCount,
        minMoves=self._minMoves,undosLeft=self._undosLeft,hintsLeft=self._hintsLeft,addedTube=self._addedTube,
        usedUndo=self._usedUndo,usedHint=self._usedHint,usedAddTube=self._usedAddTube,
        elapsed=self:GetElapsed(),undoStack=L:Copy(self._undoStack)}
end
function E:SaveAndStop()
    local saveable=self.state=="PLAYING" or self.state=="SELECTED" or self.state=="POURING" or self.state=="HINT" or self.state=="HINT_SEARCH" or self.state=="RESET_CONFIRM"
    local mid=saveable and self:_CaptureMidGame()
    if mid then A.ALS_Settings:SaveMidGame(self._slot,mid) end
    if self._sessionId and A.Lifecycle.PauseGame then A.Lifecycle:PauseGame("ALCHEMISTSSORT",self._sessionId) end
    self:StopGame()
end
function E:StopGame()
    self._leavePending=nil
    self:_InvalidateTimers(); self:_StopTimer(); self:_EndSession()
    self._revision=(self._revision or 0)+1
    self._animating=false; self._selected=nil; self:_SetState("IDLE")
end
function E:OpenLevelSelect()
    if self.state=="RESULT_PENDING" or self.state=="GENERATING" then return false end
    local S=A.ALS_Settings
    if not S:LoadSlot(S:GetActiveSlot()) then return false end
    self:SaveAndStop(); self:_SetState("LEVEL_SELECT"); UI("ShowLevelSelect",S:LoadSlot(S:GetActiveSlot())); return true
end
function E:SelectLevel(level)
    if self.state~="LEVEL_SELECT" or self._leavePending then return false end
    level=tonumber(level)
    local S,L=A.ALS_Settings,A.ALS_Logic
    if not L:Int(level) or level<1 or not S:IsLevelUnlocked(level) then return false end
    local save=S:LoadSlot(S:GetActiveSlot())
    local mid=save and save.midGame
    local midLevel=type(mid)=="table" and (mid.level or save.currentLevel)
    if mid and midLevel==level then return self:ResumeMidGame(mid) end
    if not mid then return self:StartLevel(level) end
    local function answer(yes)
        if self.state~="LEVEL_SELECT" then self._leavePending=nil; return end
        self._leavePending=nil
        if yes then self:StartLevel(level) end
    end
    self._leavePending=true
    if not UI("ShowConfirmLeave",function() answer(true) end,function() answer(false) end) then
        self._leavePending=nil
    end
    return true
end
function E:ResumeSelectedLevel()
    if self.state~="LEVEL_SELECT" then return false end
    local s=A.ALS_Settings:LoadSlot(A.ALS_Settings:GetActiveSlot())
    return s and s.midGame and self:ResumeMidGame(s.midGame) or false
end
function E:ResumeMidGame(mid)
    local S=A.ALS_Settings; local slot=S:GetActiveSlot(); local save=S:LoadSlot(slot)
    if S:GetPending(slot) then return false end
    local level=type(mid)=="table" and (mid.level or save and save.currentLevel)
    local m,legacy=S:PrepareSnapshot(mid,slot,level)
    if not m then
        if self.state=="IDLE" then self:OpenLevelSelect() end
        UI("ShowFeedback","msg_invalid_save"); return false
    end
    local receipt=m.runId and A.LocalResults:GetReceipt(m.runId)
    if receipt or m.runId and not A.LocalResults:GetJournal().issued[m.runId] then UI("ShowFeedback","msg_invalid_save"); return false end
    local sid=A.Lifecycle:ClaimRestart("ALCHEMISTSSORT",self._sessionId)
    if not sid then return false end
    m=S:AdoptSnapshot(m,legacy)
    self:_InvalidateTimers(); self:_StopTimer()
    self._sessionId=sid
    self:_Install(m.puzzle,slot,level,m); return true
end
function E:StartGame(config)
    config=config or {}; local S=A.ALS_Settings; local slot=config.slot or S:GetActiveSlot()
    if not A.ALS_Logic:Int(slot,3) or slot<1 then return false end
    self:SaveAndStop(); S:SetActiveSlot(slot)
    -- A new game discards an unbooked win. Continue still retries that receipt.
    if config.mode=="new" then S:ResetSlot(slot); return self:OpenLevelSelect() end
    local pending=S:GetPending(slot)
    if pending then self._result=A.ALS_Logic:Copy(pending); self._runId=pending.runId; self._slot=slot
        self._level=pending.level; self._tubes=A.ALS_Logic:DeepCopy(pending.finalTubes); self._numTubes=#self._tubes
        self._moveCount=pending.stats.moves; self._elapsed=pending.stats.elapsedMs/1000
        self.state="RESULT_PENDING"; self._streakCounted=false; return self:RetryResult() end
    local save=S:LoadSlot(slot)
    if save and save.midGame then return self:ResumeMidGame(save.midGame) end
    -- Create an empty slot through the existing reset operation before level start.
    if not save then S:ResetSlot(slot) end
    return self:StartLevel((save and save.currentLevel) or 1)
end
function E:On() end
function E:Off() self:SaveAndStop() end
