-- Higher or Lower: immutable table variant, stable reveal and exactly one round receipt.
local A=_G.ArcadiaNexus
local E={state="IDLE"}; A.HOL_Engine=E
local guard=A.TimerGuard.New(); E._timerGuard=guard
local function Render(method,...)
    local R=A.HOL_Renderer; if R and R[method] then R[method](R,...) end
end
local function Sound(key)
    local S=A.HOL_Settings
    local options={flip="soundOnFlip",correct="soundOnCorrect",wrong="soundOnWrong",cashout="soundOnCashout",joker="soundOnJoker"}
    if S:Get("soundEnabled") and S:Get(options[key]) then PlaySound(({flip=774,correct=888,wrong=847,cashout=878,joker=847})[key],"SFX") end
end
function E:_Snapshot()
    if self.gameState then A.HOL_Settings:SaveSlot(self.activeSlot,A.HOL_Logic:Copy(self.gameState)) end
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
    if not A.HOL_Logic:ValidateSave(save) or save.phase=="GAMEOVER" then return false end
    local serial=A.LocalResults:GetSerial("HIGHERORLOWER",save.runId)
    local tableSerial=A.LocalResults:GetSerial("HIGHERORLOWER",save.tableId)
    if not serial or not tableSerial or tableSerial>serial then return false end
    local j,r=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(save.runId)
    if not r and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if save.phase=="ROUND_RESULT" and not r then return false end
    if r and (r.gameId~="HIGHERORLOWER" or r.difficulty~=save.variant or not save.settled or r.finalChips2~=save.chips2 or r.net2~=save.net2 or r.tableId~=save.tableId
        or r.roundNo~=save.roundNo or r.roundBest~=save.roundBest or r.stake2~=save.bet2 or r.return2~=save.return2 or r.startChips2~=save.startChips2 or r.reason~=save.reason) then return false end
    return true
end
function E:StartGame(config)
    if self.gameState then return false end
    config=type(config)=="table" and config or {}; local S=A.HOL_Settings
    S:EnsureMigration()
    local slot=config.slot or 1; local mode=config.mode or "new"
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 or (mode~="new" and mode~="continue") then return false end
    local save=S:LoadSlot(slot); local gs
    if mode=="continue" then
        if not self:CanContinueSave(save) then return false end
        gs=A.HOL_Logic:Copy(save)
    else
        local variant=config.variant or S:Get("variant")
        if save and not config.overwrite or not A.HOL_Logic:IsVariant(variant) then return false end
        gs=A.HOL_Logic:NewGameState(variant,100)
    end
    local sid=A.Lifecycle:ClaimRestart("HIGHERORLOWER",self._sessionId)
    if not sid then return false end
    if mode~="continue" then gs.runId=A.LocalResults:NewRun("HIGHERORLOWER"); gs.tableId=gs.runId end
    self.gameState,self.activeSlot,self.activeConfig=gs,slot,{ruleVersion=2}
    self._sessionId=sid; self._lastResult=nil
    self.state=gs.phase; self:_Snapshot(); Render("OnGameStarted",gs); self:_Refresh()
    if gs.phase=="REVEALING" then self:_ContinueReveal()
    elseif gs.phase=="RESULT_PENDING" then self:RetryResult()
    elseif gs.phase=="ROUND_RESULT" then Render("ShowResult",gs) end
    A.LocalResults:Prune(); return true
end
function E:SaveAndPause()
    guard:Cancel()
    if self.gameState then self:_Snapshot() end
    if self._sessionId then
        A.Lifecycle:PauseGame("HIGHERORLOWER",self._sessionId); A.Lifecycle:EndGame("HIGHERORLOWER",self._sessionId); self._sessionId=nil
    end
    self.gameState,self.activeSlot,self.activeConfig,self._lastResult=nil,nil,nil,nil
    self.state="IDLE"; Render("OnGameStopped"); return true
end
function E:StopGame() return self:SaveAndPause() end
function E:AdjustBet(delta)
    if not self.gameState or not A.HOL_Logic:AdjustBet(self.gameState,delta) then return false end
    self:_Snapshot(); Render("RestoreBoard",self.gameState); return true
end
function E:DealFirstCard()
    if not self.gameState or not A.HOL_Logic:StartRound(self.gameState) then return false end
    self:_Refresh(); Sound("flip"); return true
end
function E:Guess(guess)
    if not self.gameState or not A.HOL_Logic:QueueGuess(self.gameState,guess) then return false end
    self:_Refresh(); self:_ContinueReveal(); return true
end
function E:_ContinueReveal()
    self:_Schedule(0.3,function()
        local outcome=A.HOL_Logic:ResolveGuess(E.gameState); Sound("flip"); E:_Refresh()
        if E.state=="RESULT_PENDING" then E:RetryResult()
        elseif outcome=="WIN" then Sound("correct") end
    end)
end
function E:CashOut()
    if not self.gameState or not A.HOL_Logic:Settle(self.gameState,"CASHOUT") then return false end
    self:_Refresh(); return self:RetryResult()
end
function E:ContinueStreak() return self.state=="PLAYING" end
function E:RetryResult()
    local gs=self.gameState; if not gs or gs.phase~="RESULT_PENDING" then return false end
    local data={gameId="HIGHERORLOWER",difficulty=gs.variant,runId=gs.runId,score=0,
        result=gs.net2>0 and "WIN" or gs.net2<0 and "LOSS" or "DRAW",
        tableId=gs.tableId,roundNo=gs.roundNo,finalChips2=gs.chips2,net2=gs.net2,
        startChips2=gs.startChips2,stake2=gs.bet2,return2=gs.return2,
        reason=gs.reason,roundBest=gs.roundBest,
        stats={finalChips=gs.chips2/2,maxStreak=gs.roundBest,cashouts=gs.reason~="LOSS" and gs.streak>0 and 1 or 0}}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then self:_Snapshot(); Render("ShowResultPending",gs); return false end
    gs.resultPending=nil; self._lastResult=data
    gs.phase=gs.chips2<50 and "GAMEOVER" or "ROUND_RESULT"; self:_Refresh()
    if not data.localReplay and data.result~="DRAW" then Sound(data.result=="WIN" and "cashout" or (gs.currentCard.isJoker and "joker" or "wrong")) end
    Render("ShowResult",gs); return true
end
function E:NewRound()
    if not self.gameState or self.state~="ROUND_RESULT" then return false end
    A.HOL_Logic:ResetRound(self.gameState)
    self.gameState.runId=A.LocalResults:NewRun("HIGHERORLOWER"); self._lastResult=nil
    self:_Refresh(); return true
end
function E:SetVariant(variant)
    if self.gameState or not A.HOL_Logic:IsVariant(variant) then return false end
    A.HOL_Settings:_SetVariant(variant); return true
end
function E:SetDifficulty() return false end
function E:HandleKey(key)
    if key=="UP" or key=="RIGHT" then return self:Guess("HIGHER") end
    if key=="DOWN" or key=="LEFT" then return self:Guess("LOWER") end
    if key=="SPACE" or key=="ENTER" then
        if self.state=="BETTING" then return self:DealFirstCard() end
        if self.state=="PLAYING" then return self:CashOut() end
    end
    if key=="ADD_BET" then return self:AdjustBet(25) end
    if key=="REMOVE_BET" then return self:AdjustBet(-25) end
    return false
end
