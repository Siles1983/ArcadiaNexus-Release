-- Session-owned Klondike. Pause is not defeat; explicit confirmed give-up is LOSS.
local A=_G.ArcadiaNexus
local E={state="IDLE"}; A.SOL_Engine=E
local auto=A.TimerGuard.New(); E._autoGuard=auto
local clock=A.GameLoop.Create("ArcadiaNexus_SOL_Clock")
local function Render(method,...) local R=A.SOL_Renderer; if R and R[method] then R[method](R,...) end end
function E:_PlaySound(key)
    local S=A.SOL_Settings
    local keys={deal="soundOnDeal",place="soundOnPlace",foundation="soundOnFnd",invalid="soundOnInval",win="soundOnWin",undo="soundOnUndo"}
    local names={deal="select_card",place="select_card",foundation="select_card",invalid="missmatch",win="win",undo="select_card"}
    if S:Get("soundEnabled") and S:Get(keys[key]) and names[key] then
        PlaySoundFile("Interface\\AddOns\\ArcadiaNexus\\Games\\Solitaire\\Assets\\sounds\\"..names[key]..".wav","SFX")
    end
end
function E:_AccumulateTime()
    local gs=self.gameState; if not gs or not self._timeAnchor then return end
    local now=GetTime(); local delta=math.max(0,(now-self._timeAnchor)*1000)+(self._timeRemainder or 0)
    local whole=math.floor(delta); self._timeRemainder=delta-whole
    gs.elapsedMs=math.min(2147483647,gs.elapsedMs+whole)
    self._timeAnchor=now; A.SOL_Logic:Sync(gs)
end
function E:_StartTimer()
    self._timeAnchor=GetTime(); self._timeRemainder=0; local sid,gs=self._sessionId,self.gameState
    clock:Start(function()
        E:_AccumulateTime(); Render("UpdateHUD",gs)
    end,{stateCheck=function() return A.GameSession:IsSession(E,sid) and E.gameState==gs and (E.state=="PLAYING" or E.state=="AUTO") end})
end
function E:_StopTimer() self:_AccumulateTime(); clock:Stop(); self._timeAnchor=nil end
function E:_Snapshot() if self.gameState then A.SOL_Settings:SaveGame(self.gameState) end end
function E:_Refresh()
    local gs=self.gameState; self.state=gs.phase; self:_Snapshot()
    Render("SetState",self.state); Render("Refresh",gs); Render("UpdateHUD",gs)
    Render("SetAutoCompleteVisible",self.state=="PLAYING" and A.SOL_Logic:CanAutoComplete(gs))
end
function E:CanContinueSave(save)
    local gs=type(save)=="table" and save.midGame
    if not A.SOL_Logic:ValidateSave(gs) or gs.phase=="WIN" or gs.phase=="LOSS" then return false end
    local serial=A.LocalResults:GetSerial("SOLITAIRE",gs.runId)
    if not serial then return false end
    local j,r=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(gs.runId)
    if not r and not j.issued[gs.runId] and serial<=j.retiredThrough then return false end
    if r and (gs.phase~="RESULT_PENDING" or r.gameId~="SOLITAIRE" or r.difficulty~=gs.mode or r.result~=gs.result
        or r.score~=gs.score or r.elapsedMs~=gs.elapsedMs or r.scoreVersion~=gs.scoreVersion or r.undoUsed~=gs.undoUsed or r.wastePass~=gs.wastePass) then return false end
    return true
end
function E:StartGame(config,fromSave)
    if self.gameState then return false end
    local S,L=A.SOL_Settings,A.SOL_Logic; S:EnsureSaves()
    if type(config)~="table" then config={cardMode=config,mode=fromSave and "continue" or "new"} end
    local slot=config.slot or S:GetActiveSlot(); local mode=config.mode or "new"
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 or mode~="new" and mode~="continue" then return false end
    local save=S:LoadSlot(slot); local gs
    if mode=="continue" then
        if not self:CanContinueSave(save) then return false end
        gs=S:LoadGame(slot); if gs.phase=="AUTO" then gs.phase="PLAYING" end
    else
        local cardMode=config.cardMode or S:Get("mode")
        if not L:IsMode(cardMode) or save and not config.overwrite then return false end
        gs=L:NewGameState(cardMode)
    end
    local sid=A.Lifecycle:ClaimRestart("SOLITAIRE",self._sessionId)
    if not sid then return false end
    if mode~="continue" then gs.runId=A.LocalResults:NewRun("SOLITAIRE") end
    self.gameState,self.activeSlot,self._lastResult=gs,slot,nil; S:SetActiveSlot(slot)
    self._sessionId=sid; auto:Cancel(); self._autoRunning=false
    self:_Refresh()
    if gs.phase=="RESULT_PENDING" then self:RetryResult() else self:_StartTimer() end
    A.LocalResults:Prune(); return true
end
function E:CanInteract() return self.state=="PLAYING" and self.gameState and self.gameState.phase=="PLAYING" and A.GameSession:IsSession(self,self._sessionId) or false end
function E:_AfterAction()
    self:_AccumulateTime()
    if A.SOL_Logic:IsWin(self.gameState) then return self:_Finish("WIN") end
    self:_Refresh(); return true
end
function E:OnStockClick()
    if not self:CanInteract() then return false end
    local ok=A.SOL_Logic:DrawFromStock(self.gameState); if not ok then return false end
    self:_PlaySound("deal"); return self:_AfterAction()
end
function E:OnCardClick(zone,index,cardIndex)
    if not self:CanInteract() then return false end
    if zone=="stock" then return self:OnStockClick() end
    local gs,L=self.gameState,A.SOL_Logic
    if gs.selected then
        local ok=L:TryMove(gs,gs.selected,{zone=zone,index=index,cardIndex=cardIndex}); gs.selected=nil
        if ok then self:_PlaySound(zone=="foundation" and "foundation" or "place"); return self:_AfterAction() end
    end
    if L:IsSelectable(gs,zone,index,cardIndex) then gs.selected={zone=zone,index=index,cardIndex=cardIndex} end
    Render("Refresh",gs); return true
end
function E:OnCardDoubleClick(zone,index,cardIndex)
    if not self:CanInteract() then return false end
    local gs,L=self.gameState,A.SOL_Logic; gs.selected=nil
    local ok=L:TryMoveToFoundation(gs,zone,index,cardIndex)
    if not ok then ok=L:TryMoveToTableau(gs,zone,index,cardIndex) end
    if not ok then Render("Refresh",gs); return false end
    self:_PlaySound("place"); return self:_AfterAction()
end
function E:OnDragDrop(src,dst)
    if not self:CanInteract() then return false end
    local gs=self.gameState; gs.selected=nil
    local ok=A.SOL_Logic:TryMove(gs,src,dst)
    if not ok then Render("Refresh",gs); return false end
    self:_PlaySound("place"); return self:_AfterAction()
end
function E:OnUndo()
    if not self:CanInteract() or not A.SOL_Logic:Undo(self.gameState) then return false end
    self:_PlaySound("undo"); self:_AccumulateTime(); self:_Refresh(); return true
end
function E:OnAutoComplete()
    if not self:CanInteract() then return false end
    local gs=self.gameState; local queue=A.SOL_Logic:AutoBuildMoveQueue(gs)
    if not queue or #queue==0 then Render("SetAutoCompleteVisible",false); return false end
    gs.selected=nil; gs.phase="AUTO"; self._autoRunning=true; Render("EndDrag"); self:_Refresh()
    local sid,idx=self._sessionId,1
    local function Step()
        if not A.GameSession:IsSession(E,sid) or E.gameState~=gs or E.state~="AUTO" then return end
        local move=queue[idx]
        if not move then
            E._autoRunning=false; gs.phase="PLAYING"
            if A.SOL_Logic:IsWin(gs) then E:_Finish("WIN") else E:_Refresh() end
            return
        end
        local cards=A.SOL_Logic:GetSelectedCards(gs,move.src.zone,move.src.index,move.src.cardIndex)
        if not cards or cards[1].rank~=move.rank or cards[1].suit~=move.suit or not A.SOL_Logic:TryMove(gs,move.src,move.dst) then
            E._autoRunning=false; gs.phase="PLAYING"; E:_Refresh(); return
        end
        idx=idx+1; E:_AccumulateTime(); E:_PlaySound("foundation")
        if A.SOL_Logic:IsWin(gs) then E:_Finish("WIN"); return end
        E:_Refresh(); auto:After(0.08,Step)
    end
    auto:After(0.08,Step); return true
end
function E:RequestForfeit()
    if not self:CanInteract() then return false end
    Render("ConfirmForfeit",self._sessionId,self.gameState.runId); return true
end
function E:ConfirmForfeit(sid,runId)
    if not self:CanInteract() or self._sessionId~=sid or self.gameState.runId~=runId then return false end
    return self:_Finish("LOSS")
end
function E:_Finish(result)
    local gs=self.gameState; if not gs or self.state~="PLAYING" and self.state~="AUTO" then return false end
    if result=="WIN" and not A.SOL_Logic:IsWin(gs) then return false end
    self:_StopTimer(); auto:Cancel(); self._autoRunning=false
    gs.selected=nil; gs.phase="RESULT_PENDING"; gs.result=result; self:_Refresh(); return self:RetryResult()
end
function E:RetryResult()
    local gs=self.gameState; if not gs or gs.phase~="RESULT_PENDING" then return false end
    local data={gameId="SOLITAIRE",difficulty=gs.mode,runId=gs.runId,result=gs.result,score=gs.score,
        newScore=gs.scoreVersion==2 and gs.score or nil,scoreVersion=gs.scoreVersion,skipHighscores=true,
        elapsedMs=gs.elapsedMs,undoUsed=gs.undoUsed,wastePass=gs.wastePass}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then self:_Snapshot(); Render("ShowResultPending",gs); return false end
    self._lastResult=data; gs.phase=gs.result; self:_Refresh()
    if not data.localReplay and gs.result=="WIN" then self:_PlaySound("win") end
    Render("ShowResult",gs.result,gs.score); return true
end
function E:SaveAndPause()
    self:_StopTimer(); auto:Cancel(); self._autoRunning=false; Render("EndDrag")
    if self.gameState then
        if self.gameState.phase=="AUTO" then self.gameState.phase="PLAYING" end
        self.gameState.selected=nil; self:_Snapshot()
    end
    if self._sessionId then
        A.Lifecycle:PauseGame("SOLITAIRE",self._sessionId); A.Lifecycle:EndGame("SOLITAIRE",self._sessionId); self._sessionId=nil
    end
    self.state="IDLE"; self.gameState,self.activeSlot,self._lastResult=nil,nil,nil
    Render("SetState","IDLE"); return true
end
function E:StopGame() return self:SaveAndPause() end
function E:SetMode(mode)
    if self.gameState or not A.SOL_Logic:IsMode(mode) then return false end
    A.SOL_Settings:_SetMode(mode); return true
end
