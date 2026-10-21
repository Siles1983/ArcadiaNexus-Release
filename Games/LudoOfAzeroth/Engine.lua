-- Engine-owned actions, deadlines and terminal receipts; presentation is optional.
local A=_G.ArcadiaNexus
local E={_running=false,AI_DELAY=1.2,AI_MOVE_DELAY=.8,state="IDLE"}
A.LOA_Engine=E
local L=A.LOA_Logic
local guard=A.TimerGuard.New(); E._timerGuard=guard
local function DB() return A.Persistence:GetGameSettings("LOA") end
local function Sound(event)
    local S=A.LOA_Settings
    local key=({roll="soundOnRoll",move="soundOnMove",captured="soundOnCapture",finished="soundOnHome",win="soundOnWin"})[event]
    local ids={roll=774,move=847,captured=847,finished=888,win=888}
    if key and S:Get("soundEnabled") and S:Get(key) and PlaySound then pcall(PlaySound,ids[event],"SFX") end
end
local function Present(method,...)
    local R=A.LOA_Renderer
    if R and R[method] then
        local ok,err=pcall(R[method],R,...)
        if not ok and GH_LogError then pcall(GH_LogError,"LudoRenderer",tostring(err)) end
    end
end
local function Emit(event,...) A.Engine:Emit(event,...) end
function E:IsLive(g) return self._running and self.activeGame==g and A.GameSession:IsSession(self,self._sessionId) end
function E:IsAITurn(g) return g and g.current~=g.humanID end
function E:MigrateLegacy()
    local db=DB()
    if not db.saveState or db.legacyImported then return end
    local g=L:Deserialize(db.saveState)
    if not g then return end
    db.slots=db.slots or {}
    -- Never overwrite or consume the original until a successful continuation.
    for _,s in pairs(db.slots) do if s.legacySource then return end end
    for i=1,3 do if not db.slots[i] then
        db.slots[i]=L:Copy(db.saveState); db.slots[i].legacySource=true; db.legacyImported=true; return
    end end
end
function E:LoadSlot(slot) self:MigrateLegacy(); return (DB().slots or {})[slot] end
function E:SaveSlot(slot,data)
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    DB().slots=DB().slots or {}; DB().slots[slot]=data and L:Copy(data); return true
end
function E:HasSave() self:MigrateLegacy(); return next(DB().slots or {})~=nil end
function E:ClearSave() if self.slot then self:SaveSlot(self.slot,nil) end end
function E:CanContinue(data)
    local g=L:Deserialize(data)
    if not g then return false end
    if g.version==2 then
        local LR=A.LocalResults
        if not LR:GetSerial("LOA",g.runId) or not LR:GetJournal().issued[g.runId]
            or LR:GetReceipt(g.runId) or (DB().pendingResults or {})[g.runId] then return false end
    end
    return true
end
function E:SaveGame()
    if not self._running or not self.activeGame then return end
    local snap=L:Serialize(self.activeGame)
    if snap then snap.timestamp=time and time() or 0; self:SaveSlot(self.slot,snap) end
end
function E:RetryPending()
    for id,data in pairs(DB().pendingResults or {}) do
        local copy=L:Copy(data); Emit("GAME_RESULT",copy)
        if copy.processed then DB().pendingResults[id]=nil end
    end
end
function E:_Arm(g,kind,delay,outcome)
    guard:Cancel()
    local p={kind=kind,remaining=delay,deadline=GetTime()+delay,outcome=outcome}
    g.pending=p; self:SaveGame()
    local sid,action=self._sessionId,g.action
    guard:After(delay,function()
        if not self:IsLive(g) or self._sessionId~=sid or g.action~=action or g.pending~=p then return end
        g.pending=nil; self:_Resolve(g,p)
    end)
end
function E:_Resolve(g,p)
    if p.kind=="ROLL" then
        g.phase=p.outcome; self:SaveGame()
        Present("OnRollResolved",g)
        if g.phase=="roll" then Present("OnRollAgain",g) end
        self:_Drive(g)
    elseif p.kind=="MOVE" then
        if g.motion and g.motion.result=="captured" then Sound("captured") end
        g.phase="TURN_PENDING"; self:_Arm(g,"TURN",.15)
        Present("OnMovementComplete",g)
    elseif p.kind=="TURN" then
        g.motion=nil; L:NextTurn(g); g.action=g.action+1; self:StartTurn(g)
    elseif p.kind=="AI_ROLL" then self:DoRoll(g)
    elseif p.kind=="AI_MOVE" then
        local move=L:AIPickMove(g)
        if move then self:DoMove(g,move.pieceIdx) else g.phase,g.rolled="TURN_PENDING",false; self:_Arm(g,"TURN",1) end
    end
end
function E:_Drive(g)
    if not self:IsLive(g) or g.pending then return end
    if g.phase=="move" and not L:HasAnyMove(g) then
        g.phase,g.rolled="TURN_PENDING",false; self:_Arm(g,"TURN",1); Present("OnNoMove",g); Emit("LOA_NO_MOVE",g)
    elseif self:IsAITurn(g) then
        if g.phase=="roll" then self:_Arm(g,"AI_ROLL",self.AI_DELAY)
        elseif g.phase=="move" then self:_Arm(g,"AI_MOVE",self.AI_MOVE_DELAY) end
    end
end
function E:StartGame(config)
    config=config or {}; local slot=config.slot or 1
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    local g,saved
    if config.resume then
        saved=self:LoadSlot(slot)
        if not self:CanContinue(saved) then Present("OnInvalidSave"); return false end
        g=L:Deserialize(saved)
        if g.legacyChoice and config.legacyChoice~="open" and config.legacyChoice~="consumed" then
            Present("AskLegacyPhase",slot); return false
        end
        if g.legacy then
            if g.phase=="move" and (config.legacyChoice=="consumed" or not g.legacyChoice) then
                g.phase,g.rolled="TURN_PENDING",false
                g.pending={kind="TURN",remaining=.15}
            end
            g.version,g.ruleVersion,g.layoutVersion,g.action=2,2,2,0
            g.runId=nil; g.legacy,g.legacyChoice=nil,nil
        end
    else
        local color=config.humanColor or A.LOA_Settings:Get("playerColor")
        local count=config.aiCount or A.LOA_Settings:Get("aiCount")
        if type(color)~="number" or color%1~=0 or color<1 or color>4 or type(count)~="number" or count%1~=0 or count<1 or count>3 then return false end
        g=L:NewGame({humanColor=color,aiCount=count})
        g.version,g.ruleVersion,g.layoutVersion,g.action=2,2,2,0
    end
    self:RetryPending(); self:StopGame()
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:BeginGame("LOA")
    if not self._sessionId then self._sessionId=previous; return false end
    self.slot,self.activeGame,self._running,self.state=slot,g,true,"PLAYING"
    g.runId=g.runId or A.LocalResults:NewRun("LOA")
    if saved and saved.legacySource then DB().legacyArchive=L:Copy(DB().saveState); DB().saveState=nil end
    g.legacySource=nil
    local p=g.pending; g.pending=nil
    if p then self:_Arm(g,p.kind,p.remaining,p.outcome) else self:SaveGame() end
    Present("OnGameStarted",g); Emit("LOA_GAME_STARTED",g)
    if self.activeGame~=g or not self._running then return true end
    if not p then self:_Drive(g) end
    return true
end
function E:ResumeGame(slot,choice) return self:StartGame({slot=slot or self.slot or 1,resume=true,legacyChoice=choice}) end
function E:StartTurn(g)
    if not self:IsLive(g) then return end
    Present("OnTurnStart",g); Emit("LOA_TURN_CHANGED",g)
    if not self:IsLive(g) then return end
    self:SaveGame(); self:_Drive(g)
end
function E:HandleRollClick()
    local g=self.activeGame
    if g and g.current==g.humanID then return self:DoRoll(g) end
    return false
end
function E:DoRoll(g)
    if not self:IsLive(g) or g.phase~="roll" or g.pending or g.rolled then return false end
    local val=L:RollDice(g); local outcome=g.phase
    g.phase,g.action="ROLLING",g.action+1
    self:_Arm(g,"ROLL",2,outcome)
    Sound("roll"); Present("OnDiceRolled",g,val); Emit("LOA_DICE_ROLLED",g,val)
    return true
end
function E:HandlePieceClick(index)
    local g=self.activeGame
    if g and g.current==g.humanID then return self:DoMove(g,index) end
    return false
end
function E:DoMove(g,index)
    if not self:IsLive(g) or g.phase~="move" or g.pending or not g.rolled then return false end
    local valid=false
    for _,m in ipairs(L:GetValidMoves(g)) do if m.pieceIdx==index then valid=true; break end end
    if not valid then return false end
    local player=g.players[g.current]; local piece=player.pieces[index]
    local motion={player=g.current,piece=index,from=piece.relPos,to=piece.relPos==0 and 1 or piece.relPos+g.dice,captured={}}
    motion.route=L:Route(player.colorIdx,motion.from,motion.to)
    for id,p in ipairs(g.players) do if id~=g.current then for i,pc in ipairs(p.pieces) do
        if pc.relPos>0 and pc.relPos<=40 and motion.to<=40
            and A.LOA_Board:GetGridIndex(p.colorIdx,pc.relPos)==A.LOA_Board:GetGridIndex(player.colorIdx,motion.to) then
            motion.captured[#motion.captured+1]={player=id,piece=i,from=pc.relPos}
        end
    end end end
    local result=L:ApplyMove(g,index)
    motion.result=result
    motion.travel=motion.from==0 and .25 or #motion.route*.11
    motion.duration=motion.travel+(#motion.captured>0 and .25 or 0)
    g.motion,g.action,g.rolled=motion,g.action+1,false
    if result=="win" then self:_Finish(g) else
        g.phase="MOVE_RESOLVING"; self:_Arm(g,"MOVE",motion.duration)
    end
    if self.activeGame~=g then return true end
    if result~="captured" then Sound(result) end
    Present("OnPieceMoved",g,g.current,index,result); Emit("LOA_PIECE_MOVED",g,g.current,index,result)
    if self.activeGame~=g then return true end
    if result=="win" then Present("OnGameWon",g,g.winner); Emit("LOA_GAME_WON",g,g.winner) end
    return true
end
function E:_Finish(g)
    if g.resultData then return end
    guard:Cancel(); g.pending=nil; self._running,self.state=false,"GAMEOVER"
    local data={gameId="LOA",ruleVersion=2,runId=g.runId,difficulty="ai_"..g.aiCount,score=0,
        result=g.winner==1 and "WIN" or "LOSS",stats={figuresHome=L:CountHomePieces(g.players[1]),
        humanColor=g.humanColor,startColor=g.players[g.playerOrder[1]].colorIdx,aiCount=g.aiCount}}
    g.resultData=data
    DB().pendingResults=DB().pendingResults or {}; DB().pendingResults[g.runId]=L:Copy(data)
    self:ClearSave()
    local sid=self._sessionId; self._sessionId=nil
    if sid then A.Lifecycle:EndGame("LOA",sid) end
    Emit("GAME_RESULT",data)
    if data.processed then DB().pendingResults[g.runId]=nil end
end
function E:SaveAndPause()
    self:SaveGame()
    if self._sessionId then A.Lifecycle:PauseGame("LOA",self._sessionId) end
    self:StopGame(true)
end
function E:StopGame(skipSave)
    if not skipSave then self:SaveGame() end
    guard:Cancel()
    local sid=self._sessionId; self._sessionId=nil
    self._running,self.state=false,"IDLE"
    self.activeGame=nil
    if sid then A.Lifecycle:EndGame("LOA",sid) end
    Present("EnterIdleState"); Emit("LOA_GAME_STOPPED")
end
