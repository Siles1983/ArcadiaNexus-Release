-- Session-owned Nonogram: state/clock/save/result independent of presentation.
local A=ArcadiaNexus
local E={state='IDLE',_revision=0}
A.NON_Engine=E
local guard=A.TimerGuard.New()
local function L() return A.NON_Logic end
local function S() return A.NON_Settings end
local function UI(name,...)
 local R=A.NON_Renderer; if not R or not R[name] then return end
 local ok,err=pcall(R[name],R,...); if not ok and GH_LogError then GH_LogError('Nonogram '..name..': '..tostring(err)) end
end
function E:IsConfigLocked() return self.state~='IDLE' and self.state~='SLOT_MENU' end
function E:_Clock()
 if self._clockStart and self._gameState then self._gameState.elapsedMs=self._elapsedBase+math.max(0,math.floor((GetTime()-self._clockStart)*1000+.5)) end
end
function E:_EndSession()
 if self._sessionId then A.Lifecycle:EndGame('NONOGRAM',self._sessionId); self._sessionId=nil end
end
function E:_StartTimer()
 guard:Cancel(); self._clockStart=GetTime(); self._elapsedBase=self._gameState.elapsedMs
 local sid=self._sessionId; guard:EveryAfter(1,function()
  if self.state~='PLAYING' or self._sessionId~=sid then return false end self:_Clock(); self:_Save(); UI('UpdateHUD',self._gameState); return true
 end)
end
function E:_StopTimer() self:_Clock(); self._clockStart=nil; guard:Cancel() end
function E:_TickTimer() self:_Clock(); UI('UpdateHUD',self._gameState) end
function E:_Save()
 if self.state~='PLAYING' then return end self:_Clock()
 S():SaveSlot(self._slot,{snapshotVersion=1,ruleVersion=2,catalogVersion=2,scoreVersion=2,slot=self._slot,runId=self._runId,
  gameState=L():Copy(self._gameState),revision=self._revision,bags=L():Copy(self._bags),timestamp=time()})
end
function E:SaveAndPause()
 if self.state=='PLAYING' then self:_Save(); if self._sessionId then A.Lifecycle:PauseGame('NONOGRAM',self._sessionId) end end
 self:StopGame()
end
function E:StopGame()
 if self.state=='PLAYING' then self:_Save() end
 self:_StopTimer(); self:_EndSession(); self._revision=self._revision+1; self.state='IDLE'; self._gameState=nil; self._result=nil
 UI('EnterIdleState')
end
function E:ShowSlots() self:SaveAndPause(); self.state='SLOT_MENU'; UI('ShowSlotMenu'); UI('_UpdateControlLabels') end
function E:StartGame(config,legacyMode)
 if type(config)=='string' then config={difficulty=config,mode=legacyMode,slot=1,action='new'} end
 if config==nil then config={} end if type(config)~='table' then return false end
 local slot=config.slot or 1; if not L():Int(slot,3) or slot<1 then return false end
 local action=config.action or 'new'; if action~='new' and action~='continue' and action~='retry' and action~='next' then return false end
 for i=1,3 do if i~=slot and S():GetPending(i) then UI('ShowFeedback','msg_pending'); return false end end
 local pending=S():GetPending(slot)
 if pending then
  if not A.LocalResults:GetSerial("NONOGRAM",pending.runId) or not S():ValidateResult(pending,A.LocalResults:GetReceipt(pending.runId)) then return false end
  self:SaveAndPause(); self._slot=slot; self._gameState=L():ValidateState(pending.gameState); self._runId=pending.runId; self._result=L():Copy(pending)
  self.state='RESULT_PENDING'; UI('HideSlotMenu'); UI('ShowPlaying',self._gameState); return self:RetryResult()
 end
 local save=S():LoadSlot(slot); local gs,bags
 if action=='continue' then
  local valid=S():ValidateSnapshot(save,slot); if not valid then UI('ShowFeedback','msg_invalid_save'); return false end
  gs=valid.gameState; bags=valid.bags
 else
  local diff=config.difficulty or S():Get('difficulty'); local mode=config.mode or S():Get('defaultMode')
  if not L().DiffConfig[diff] or mode~='free' and mode~='strict' then return false end
  bags=type(save)=='table' and L():Copy(save.bags) or {}; if not S():ValidBags(bags) then bags={} end
  local index
  if action=='retry' then index=config.puzzleIndex
  else
   local bag=bags[diff]
   if not bag or bag.pos>50 then
    local last=bag and bag.last; bag={items={},pos=1,last=last}; for i=1,50 do bag.items[i]=i end A.ArrayUtils.Shuffle(bag.items)
    if bag.items[1]==last then bag.items[1],bag.items[2]=bag.items[2],bag.items[1] end bags[diff]=bag
   end
   index=bag.items[bag.pos]; bag.pos=bag.pos+1; bag.last=index
  end
  local entry=L():Entry(diff,index); if not entry then return false end
  gs=L():CreateState(diff,mode,index,entry); if not gs then return false end
 end
 self:SaveAndPause(); local sid=A.Lifecycle:ClaimRestart('NONOGRAM',nil); if not sid then return false end; self._sessionId=sid; self._slot=slot; self._gameState=gs; self._bags=bags
 self._runId=action=='continue' and save.runId or A.LocalResults:NewRun('NONOGRAM'); self._revision=action=='continue' and save.revision or 0
 if action~='continue' then S():RecordStart() end
 self.state='PLAYING'; self:_StartTimer(); self:_Save(); UI('HideSlotMenu'); UI('ShowPlaying',gs); return true
end
function E:PlaySound(key)
 local setting={fill='soundOnFill',mark='soundOnMark',error='soundOnError',win='soundOnWin',lose='soundOnLose'}
 if not S():Get('soundEnabled') or not S():Get(setting[key]) then return end
 if C_Sound and C_Sound.PlaySound then C_Sound.PlaySound(({fill=850,mark=850,error=846,win=888,lose=842})[key],'Master') end
end
function E:HandleClick(r,c,action)
 if self.state~='PLAYING' and self.state~='TUTORIAL' then return false end local gs=self._gameState
 if action=='PRIMARY' then action=gs.inputMode=='fill' and 'FILL' or 'MARK' end
 if not L():CellInput(gs,r,c,action) then return false end self:_Clock(); gs.cursorR=r; gs.cursorC=c
 local result=L():HandleClick(gs,r,c,action); self._revision=self._revision+1
 if result=='gameover' then self:_GameOver('errors'); return true end
 if L():CheckWin(gs) then self:_Win(); return true end
 if self.state=='PLAYING' then self:_Save() end
 self:PlaySound(result=='error' and 'error' or action=='MARK' and 'mark' or 'fill'); UI('UpdateBoard',gs); UI('UpdateHUD',gs); UI('UpdateCursor',gs); return true
end
function E:MoveCursor(dr,dc)
 if self.state~='PLAYING' and self.state~='TUTORIAL' then return false end
 if not L():MoveCursor(self._gameState,dr,dc) then return false end self:_Save(); UI('UpdateCursor',self._gameState); return true
end
function E:HandleKeyAction(action)
 if self.state~='PLAYING' and self.state~='TUTORIAL' then return false end local gs=self._gameState
 if action=='TOGGLE_MODE' then L():ToggleInputMode(gs); self:_Save(); UI('UpdateInputModeLabel',gs); return true end
 if action=='FILL' or action=='PRIMARY' then return self:HandleClick(gs.cursorR,gs.cursorC,'PRIMARY') end
 if action=='MARK' then return self:HandleClick(gs.cursorR,gs.cursorC,'MARK') end return false
end
function E:_Finish(result,reason)
 if self.state=='TUTORIAL' then
  if result~='WIN' or not L():CheckWin(self._gameState) then return false end
  self:_EndSession(); self.state='TUTORIAL_DONE'; UI('ShowTutorialDone',self._gameState); return true
 end
 if self.state~='PLAYING' or self._result then return false end local gs=self._gameState
 if result=='WIN' and not L():CheckWin(gs) or result=='LOSS' and (gs.mode~='strict' or gs.errors~=gs.errorLimit) then return false end
 self:_StopTimer(); self.state='RESULT_PENDING'; self:_EndSession()
 self._result={gameId='NONOGRAM',runId=self._runId,slot=self._slot,ruleVersion=2,catalogVersion=2,scoreVersion=2,
  difficulty=L():ScoreKey(gs.difficulty,gs.mode),score=result=='WIN' and L():CalcScore(gs) or 0,result=result,reason=reason,gameState=L():Copy(gs),
  stats={difficulty=gs.difficulty,mode=gs.mode,elapsedMs=gs.elapsedMs,errors=gs.errors}}
 S():QueueResult(self._result); return self:RetryResult()
end
function E:_Win() return self:_Finish('WIN','solved') end
function E:_GameOver(reason) if reason~='errors' then return false end return self:_Finish('LOSS',reason) end
function E:RetryResult()
 local d=self._result; if not d then return false end
 local ok=pcall(A.Engine.Emit,A.Engine,'GAME_RESULT',d)
 if not ok or not d.processed then self.state='RESULT_PENDING'; UI('ShowPending',d); return false end
 self.state=d.result=='WIN' and 'WIN' or 'GAMEOVER'; self._gameState.finalScore=d.score; self._gameState.won=d.result=='WIN'
 self:PlaySound(d.result=='WIN' and 'win' or 'lose'); UI('UpdateBoard',self._gameState); UI('ShowResult',d); return true
end
function E:RetryPuzzle(nextPuzzle)
 if self.state~='WIN' and self.state~='GAMEOVER' or not self._result or not self._result.processed then return false end
 local gs=self._gameState
 return self:StartGame({slot=self._slot,action=nextPuzzle and 'next' or 'retry',difficulty=gs.difficulty,mode=gs.mode,puzzleIndex=gs.puzzleIndex})
end
function E:StartTutorial()
 if self.state=='RESULT_PENDING' then return false end self:SaveAndPause()
 local sid=A.Lifecycle:ClaimRestart('NONOGRAM',nil); if not sid then return false end
 self._sessionId=sid; self._gameState=L():CreateState('easy','free',0,{map='11101|00100|00100|00000|00000',name='',id='tutorial:1'})
 self.state='TUTORIAL'; UI('HideSlotMenu'); UI('ShowPlaying',self._gameState); UI('ShowTutorial'); return true
end
function E:On() UI('_UpdateControlLabels') end
function E:Off() self:SaveAndPause() end
