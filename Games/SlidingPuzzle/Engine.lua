-- M7: logical moves/results own state; animations are bounded presentation.
local A=_G.ArcadiaNexus
local E={state="IDLE",_revision=0,_elapsed=0,_moveCount=0}; A.SLP_Engine=E
local guard=A.TimerGuard.New(); local ticker=A.TimerGuard.New()
local loop=A.GameLoop.Create("ArcadiaNexus_Mosaic_Work")
local function Clock() return debugprofilestop and debugprofilestop() or GetTime()*1000 end
local function UI(name,...)
    local R=A.SLP_Renderer
    if not R or not R[name] then return false end
    local ok,err=pcall(R[name],R,...)
    if not ok and GH_LogError then GH_LogError("Mosaic",name..": "..tostring(err)) end
    return ok
end
function E:PlayEffect(key,sound)
    local S=A.SLP_Settings
    if S:Get("soundEnabled") and S:Get(key) and C_Sound and C_Sound.PlaySound then pcall(C_Sound.PlaySound,sound or 1,"Master") end
end
function E:IsConfigLocked() return self.state~="IDLE" and self.state~="SLOT_MENU" end
function E:_SetState(state) self.state=state; UI("OnStateChanged",state); UI("UpdateHUD") end
function E:GetElapsed() return (self._elapsed or 0)+(self._startTime and GetTime()-self._startTime or 0) end
function E:_StopTimer() self._elapsed=self:GetElapsed(); self._startTime=nil; ticker:Cancel() end
function E:_StartTimer()
    self._startTime=GetTime(); ticker:Cancel(); ticker:EveryTicker(1,function() UI("UpdateHUD") end)
end
function E:_InvalidateTimers()
    guard:Cancel(); loop:Stop()
    if self._job then self._job:Cancel(); self._job=nil end
    UI("CancelPresentation")
end
function E:_EndSession()
    if self._sessionId then A.Lifecycle:EndGame("MOSAICOFAZEROTH",self._sessionId); self._sessionId=nil end
end
function E:_Snapshot()
    if not self._puzzle or self._result then return nil end
    local L=A.SLP_Logic
    return {snapshotVersion=1,ruleVersion=2,ratingVersion=1,slot=self._slot,runId=self._runId,puzzle=L:Copy(self._puzzle),
        board=L:Copy(L.board),emptyPos=L.emptyPos,moves=self._moveCount,elapsedMs=math.floor(self:GetElapsed()*1000+0.5),
        revision=self._revision,phase=self.state,timestamp=time()}
end
function E:_Install(p,slot,save)
    local L,S=A.SLP_Logic,A.SLP_Settings
    self._puzzle=L:Copy(p); self._slot=slot; self._difficulty=p.difficulty; self._cols=p.cols; self._imageIdx=p.imageIndex
    self._runId=save and save.runId or A.LocalResults:NewRun("MOSAICOFAZEROTH")
    self._revision=(self._revision or 0)+1; self._moveCount=save and save.moves or 0; self._elapsed=save and save.elapsedMs/1000 or 0
    L.board=L:Copy(save and save.board or p.initialBoard); L.emptyPos=save and save.emptyPos or p.initialEmpty; L.cols=p.cols; L.moves=self._moveCount
    self._result=nil; self._startTime=nil
    if not save then S:RecordStart(p.difficulty) end
    S:SaveSlot(slot,self:_Snapshot())
    UI("BuildGrid",p.cols,p.imageIndex); UI("HideSlotMenu")
    if save then self:_SetState("PLAYING"); self:_StartTimer(); return end
    self:_SetState("INTRO")
    local run,rev=self._runId,self._revision; local done=false
    local function ready()
        if done or self._runId~=run or self._revision~=rev or self.state~="INTRO" then return end
        done=true; loop:Stop(); UI("CancelPresentation"); UI("RefreshGrid"); self:_SetState("PLAYING"); self:_StartTimer()
    end
    self._introReady=ready
    local elapsed=0; loop:Start(function(dt) elapsed=elapsed+dt; if elapsed>=3 then ready() end end)
    if not UI("StartIntroSequence",p.cols,p.imageIndex,p.history,ready) then ready() end
end
function E:SkipIntro() if self.state~="INTRO" then return false end; self._introReady(); return true end
function E:StartGame(config)
    if config~=nil and type(config)~="table" then return false end
    config=config or {}; local S,L=A.SLP_Settings,A.SLP_Logic; local slot=config.slot or 1
    if not L:Int(slot,3) or slot<1 then return false end
    if config.mode~=nil and config.mode~="new" and config.mode~="continue" then return false end
    if self.state=="RESULT_PENDING" and slot~=self._slot then return false end
    local pending=S:GetPending(slot)
    if pending and (not A.LocalResults:GetSerial("MOSAICOFAZEROTH",pending.runId) or not S:ValidateResult(pending,A.LocalResults:GetReceipt(pending.runId))) then
        UI("ShowFeedback","msg_invalid_save"); return false
    end
    local p=config.puzzle
    if p~=nil and not L:ValidPuzzle(p) then return false end
    local diff=p and p.difficulty or S:Get("difficulty"); local img=p and p.imageIndex or S:Get("imageIndex")
    if not pending and config.mode~="continue" and (not L.SIZES[diff] or not L:Int(img,19)) then return false end
    local validatedSave
    if config.mode=="continue" and not pending then
        validatedSave=S:ValidateSnapshot(S:LoadSlot(slot),slot)
        if not validatedSave then
            if self.state=="IDLE" then self:_SetState("SLOT_MENU"); UI("ShowSlotMenu") end
            UI("ShowFeedback","msg_invalid_save"); return false
        end
    end
    self:SaveAndPause()
    if pending then
        self._slot=slot; self._puzzle=L:Copy(pending.puzzle); self._runId=pending.runId; self._result=L:Copy(pending)
        self._difficulty=self._puzzle.difficulty; self._cols=self._puzzle.cols; self._imageIdx=self._puzzle.imageIndex
        L.board=L:Copy(pending.finalBoard); L.cols=self._cols; L.emptyPos=self._cols*self._cols; self._moveCount=pending.stats.moves
        self._elapsed=pending.stats.elapsedMs/1000; UI("BuildGrid",self._cols,self._imageIdx); return self:RetryResult()
    end
    if config.mode=="continue" then
        local save=validatedSave
        local sid=A.Lifecycle:ClaimRestart("MOSAICOFAZEROTH",self._sessionId); if not sid then return false end
        self._sessionId=sid; self:_Install(save.puzzle,slot,save); return true
    end
    if img==0 then img=math.random(1,19) end
    local sid=A.Lifecycle:ClaimRestart("MOSAICOFAZEROTH",self._sessionId)
    if not sid then return false end
    self._sessionId=sid
    self._slot=slot; self._difficulty=diff; self._cols=L.SIZES[diff]; self._imageIdx=img; self._puzzle=nil; self._result=nil
    self:_SetState("GENERATING"); UI("HideSlotMenu")
    if p then self:_Install(p,slot); return true end
    local job=L:Generate(diff,img,Clock); self._job=job; local sid=self._sessionId
    loop:Start(function()
        if self._job~=job or self._sessionId~=sid then return end
        if job:Step()~="running" then
            loop:Stop(); self._job=nil; self._lastGeneration=job
            if job.status=="solved" then self:_Install(job.puzzle,slot)
            else self:StopGame(); UI("ShowFeedback","msg_generation_failed") end
        end
    end)
    return true
end
function E:OnTileClicked(pos)
    local L=A.SLP_Logic
    if self.state~="PLAYING" or not L:CanMove(pos) then return false end
    local target=L.emptyPos; local tile=L.board[pos]; local before=L:Copy(L.board)
    if not L:ExecuteMove(pos) then return false end
    self._moveCount=L.moves; self._revision=self._revision+1
    self:PlayEffect("soundOnMove",SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP)
    local terminal=L:IsSolved()
    if terminal then self:_OnWin() else self:_SetState("SLIDING") end
    local run,rev=self._runId,self._revision; local done=false
    local function ready()
        if done or self._runId~=run or self._revision~=rev then return end
        done=true; loop:Stop(); UI("CancelSlide"); UI("RefreshGrid")
        if terminal then if self._result.processed then self:_PresentWin() end
        else self:_SetState("PLAYING") end
    end
    local elapsed=0; loop:Start(function(dt) elapsed=elapsed+dt; if elapsed>=0.16 then ready() end end)
    if not UI("MoveTile",pos,target,ready,before,tile) then ready() end
    return true
end
function E:_OnWin()
    if self._result or not A.SLP_Logic:IsSolved() then return false end
    self:_StopTimer(); self:_InvalidateTimers(); self.state="RESULT_PENDING"
    local L,S=A.SLP_Logic,A.SLP_Settings
    local ms=math.floor(self._elapsed*1000+0.5)
    self._result={gameId="MOSAICOFAZEROTH",difficulty="v2_"..self._difficulty,result="WIN",score=0,skipHighscores=true,
        runId=self._runId,slot=self._slot,ruleVersion=2,ratingVersion=1,puzzle=L:Copy(self._puzzle),finalBoard=L:Copy(L.board),
        stats={difficulty=self._difficulty,cols=self._cols,imageIndex=self._imageIdx,moves=self._moveCount,elapsedMs=ms,time=math.floor(ms/1000)}}
    S:QueueResult(self._result); self:_EndSession()
    return self:RetryResult(true)
end
function E:RetryResult(defer)
    local data=self._result; if not data then return false end
    local ok=pcall(A.Engine.Emit,A.Engine,"GAME_RESULT",data)
    if not ok or not data.processed then self:_SetState("RESULT_PENDING"); UI("ShowPendingResult"); return false end
    self:_SetState("WIN")
    if not defer then self:_PresentWin() end
    return true
end
function E:_PresentWin()
    local run,rev=self._runId,self._revision; local done=false
    local function ready()
        if done or self._runId~=run or self._revision~=rev or self.state~="WIN" then return end
        done=true; loop:Stop(); UI("ShowWinResult",self._result)
    end
    local elapsed=0; loop:Start(function(dt) elapsed=elapsed+dt; if elapsed>=1.5 then ready() end end)
    self:PlayEffect("soundOnWin",SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END)
    if not UI("StartWinReveal",ready) then ready() end
end
function E:RetryPuzzle()
    if self.state~="WIN" or not self._result or not self._result.processed then return false end
    return self:StartGame({slot=self._slot,puzzle=A.SLP_Logic:Copy(self._puzzle)})
end
function E:SaveAndPause()
    if self.state=="PLAYING" or self.state=="SLIDING" or self.state=="INTRO" then
        local save=self:_Snapshot(); if save then A.SLP_Settings:SaveSlot(self._slot,save) end
    end
    if self._sessionId then A.Lifecycle:PauseGame("MOSAICOFAZEROTH",self._sessionId) end
    self:StopGame()
end
function E:StopGame()
    self:_InvalidateTimers(); self:_StopTimer(); self:_EndSession(); self._revision=self._revision+1; self:_SetState("IDLE")
end
function E:ShowSlots() self:SaveAndPause(); self:_SetState("SLOT_MENU"); UI("ShowSlotMenu") end
function E:On() UI("UpdateHUD") end
function E:Off() self:SaveAndPause() end
