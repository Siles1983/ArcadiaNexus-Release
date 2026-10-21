-- Fixed blackjack table: stable draws, slot ownership and one result per round.
local A=_G.ArcadiaNexus
local E={state="IDLE"}; A.BJ_Engine=E
local guard=A.TimerGuard.New(); E._timerGuard=guard
local function Render(method,...)
    local R=A.BJ_Renderer; if R and R[method] then R[method](R,...) end
end
local function Sound(key)
    local S=A.BJ_Settings
    local options={deal="soundOnDeal",flip="soundOnFlip",win="soundOnWin",lose="soundOnLose",chip="soundOnChip"}
    if S:Get("soundEnabled") and S:Get(options[key]) then PlaySound(({deal=774,flip=774,win=888,lose=847,chip=774})[key],"SFX") end
end
function E:_Snapshot()
    if not self.gameState then return true end
    return A.BJ_Settings:SaveSlot(self.activeSlot,A.BJ_Logic:Copy(self.gameState))
end
function E:_SetState(state)
    self.state=state; if self.gameState then self.gameState.phase=state end
    Render("OnStateChanged",state)
end
function E:_Refresh()
    self.state=self.gameState.phase; self:_Snapshot(); Render("RestoreBoard",self.gameState)
end
function E:_Schedule(delay,fn)
    local sid,gs=self._sessionId,self.gameState
    guard:After(delay,function()
        if A.GameSession:IsSession(E,sid) and E.gameState==gs then fn() end
    end)
end
function E:CanContinueSave(save)
    if not A.BJ_Logic:ValidateSave(save) or save.phase=="GAMEOVER" then return false end
    local serial=A.LocalResults:GetSerial("BLACKJACK",save.runId)
    if not serial then return false end
    local j,r=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(save.runId)
    if not r and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if save.phase=="ROUND_RESULT" and not r then return false end
    if r and (not save.settled or r.finalChips2~=save.chips2 or r.net2~=save.net2 or r.tableId~=save.tableId
        or r.roundNo~=save.roundNo or r.blackjacks~=save.roundBlackjacks) then return false end
    return true
end
function E:StartGame(config)
    if self.gameState then return false end
    config=type(config)=="table" and config or {}; local S=A.BJ_Settings
    S:EnsureMigration()
    local slot=config.slot or 1; local mode=config.mode or "new"
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 or (mode~="new" and mode~="continue") then return false end
    local save=S:LoadSlot(slot); local gs
    if mode=="continue" then
        if not self:CanContinueSave(save) then return false end
        gs=A.BJ_Logic:Copy(save)
    else
        local count=config.aiCount or S:Get("aiCount")
        if save and not config.overwrite or type(count)~="number" or count~=math.floor(count) or count<0 or count>2 then return false end
        gs=A.BJ_Logic:NewGameState("table",count,100)
    end
    local sid=A.Lifecycle:ClaimRestart("BLACKJACK",self._sessionId)
    if not sid then return false end
    if mode~="continue" then gs.runId=A.LocalResults:NewRun("BLACKJACK"); gs.tableId=gs.runId end
    self.gameState,self.activeSlot,self.activeConfig=gs,slot,{ruleVersion=2}
    self._sessionId=sid; self._busy=false; self._lastResult=nil
    self.state=gs.phase; self:_Snapshot(); Render("OnGameStarted",gs); self:_Refresh()
    if gs.phase=="DEALING" then self:_ContinueDeal()
    elseif gs.phase=="DEALER_TURN" then self:_ContinueDealer()
    elseif gs.phase=="RESULT_PENDING" then self:RetryResult()
    elseif gs.phase=="ROUND_RESULT" then Render("ShowRoundResult",gs,gs.results) end
    A.LocalResults:Prune(); return true
end
function E:SaveAndPause()
    if self.gameState and self:_Snapshot()==false then return false end
    guard:Cancel(); self._busy=false
    if self._sessionId then
        A.Lifecycle:PauseGame("BLACKJACK",self._sessionId); A.Lifecycle:EndGame("BLACKJACK",self._sessionId); self._sessionId=nil
    end
    self.gameState,self.activeSlot,self.activeConfig,self._lastResult=nil,nil,nil,nil
    self.state="IDLE"; Render("OnGameStopped"); return true
end
function E:StopGame() return self:SaveAndPause() end
function E:SetBet(amount)
    if not self.gameState or not A.BJ_Logic:SetBet(self.gameState,amount) then return false end
    self:_Snapshot(); Sound("chip"); Render("UpdateBetDisplay",self.gameState); Render("UpdateActionButtons",self.gameState); return true
end
function E:RemoveLastBetOfColor(_,amount) return self:SetBet(-amount) end
function E:ClearBet()
    if self.state~="BETTING" then return false end
    self.gameState.bet2=0; self.gameState.betConfirmed=false; A.BJ_Logic:Sync(self.gameState)
    self:_Snapshot(); Render("_ClearBetChip"); Render("UpdateBetDisplay",self.gameState); return true
end
function E:StartRound()
    if not self.gameState or not A.BJ_Logic:BeginRound(self.gameState) then return false end
    self:_Refresh(); self:_ContinueDeal(); return true
end
function E:_ContinueDeal()
    self:_Schedule(0.3,function()
        A.BJ_Logic:DealStep(E.gameState); Sound("deal"); E:_Refresh()
        if E.state=="DEALING" then E:_ContinueDeal() else E:_AfterPeek() end
    end)
end
function E:_AfterPeek()
    local gs=self.gameState
    A.BJ_Logic:CheckPeek(gs); self:_Refresh()
    if gs.insuranceOpen then Render("ShowInsurancePrompt",gs)
    elseif gs.phase=="DEALER_TURN" then self:_ContinueDealer() end
end
function E:ActionBlockReason(action)
    if not self.gameState or self._busy then return "action_phase" end
    return A.BJ_Logic:ActionBlockReason(self.gameState,action)
end
function E:CanAction(action)
    return self.gameState and not self._busy and A.BJ_Logic:CanAction(self.gameState,action) or false
end
function E:_Action(method,key)
    if not self:CanAction(key) or not A.BJ_Logic[method](A.BJ_Logic,self.gameState) then return false end
    self._busy=true; self:_Refresh(); if key~="stand" then Sound("deal") end
    self:_Schedule(0.15,function()
        E._busy=false; E:_Refresh()
        if E.state=="DEALER_TURN" then E:_ContinueDealer() end
    end)
    return true
end
function E:PlayerHit() return self:_Action("PlayerHit","hit") end
function E:PlayerStand() return self:_Action("PlayerStand","stand") end
function E:PlayerDouble() return self:_Action("PlayerDouble","double") end
function E:PlayerSplit() return self:_Action("PlayerSplit","split") end
function E:PlayerInsurance()
    if not self:CanAction("insurance") or not A.BJ_Logic:PlayerInsurance(self.gameState) then return false end
    Sound("chip"); Render("HideInsurancePrompt"); self:_AfterPeek(); return true
end
function E:DeclineInsurance()
    if self._busy or not self.gameState or not A.BJ_Logic:DeclineInsurance(self.gameState) then return false end
    Render("HideInsurancePrompt"); self:_AfterPeek(); return true
end
function E:_ContinueDealer()
    self:_Schedule(0.35,function()
        local draw=A.BJ_Logic:DealerStep(E.gameState); E:_Refresh()
        if draw then Sound("deal"); E:_ContinueDealer()
        else A.BJ_Logic:SettleRound(E.gameState); E:_Refresh(); E:RetryResult() end
    end)
end
function E:RetryResult()
    local gs=self.gameState
    if not gs or gs.phase~="RESULT_PENDING" then return false end
    local data={gameId="BLACKJACK",difficulty="table",runId=gs.runId,score=0,
        result=gs.net2>0 and "WIN" or gs.net2<0 and "LOSS" or "DRAW",
        tableId=gs.tableId,roundNo=gs.roundNo,finalChips2=gs.chips2,net2=gs.net2,
        startChips2=gs.startChips2,stake2=gs.stake2,return2=gs.return2,
        stats={finalChips=gs.chips2/2,blackjacks=gs.roundBlackjacks}}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then self:_Snapshot(); Render("ShowResultPending",gs); return false end
    gs.resultPending=nil; self._lastResult=data
    gs.phase=gs.chips2<50 and "GAMEOVER" or "ROUND_RESULT"
    self:_Refresh()
    if not data.localReplay and data.result~="DRAW" then Sound(data.result=="WIN" and "win" or "lose") end
    if gs.phase=="GAMEOVER" then Render("ShowGameOver",gs) else Render("ShowRoundResult",gs,gs.results) end
    return true
end
function E:NewRound()
    if not self.gameState or self.state~="ROUND_RESULT" then return false end
    A.BJ_Logic:ResetRound(self.gameState)
    self.gameState.runId=A.LocalResults:NewRun("BLACKJACK"); self._lastResult=nil
    self:_Snapshot(); self:_SetState("BETTING"); Render("OnNewRound",self.gameState); self:_Refresh(); return true
end
function E:SetAICount(count)
    if type(count)~="number" or count~=math.floor(count) or count<0 or count>2 then return false end
    if self.gameState and self.state~="BETTING" and self.state~="ROUND_RESULT" then return false end
    A.BJ_Settings:_SetAICount(count)
    if self.gameState then
        self.gameState.aiCount=count
        if self.state=="BETTING" then
            self.gameState.aiHands={}; self.gameState.aiStates={}; self.gameState.aiBets={}
            for i=1,count do self.gameState.aiHands[i]={}; self.gameState.aiStates[i]="playing"; self.gameState.aiBets[i]=25 end
        else
            -- Completed hands remain in the result; the next round uses this choice.
            self.gameState.aiCount=count
            for i=1,count do self.gameState.aiHands[i]=self.gameState.aiHands[i] or {}; self.gameState.aiStates[i]=self.gameState.aiStates[i] or "stand"; self.gameState.aiBets[i]=self.gameState.aiBets[i] or 25 end
        end
        self:_Refresh()
    end
    return true
end
