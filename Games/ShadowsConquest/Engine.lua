-- Session-owned campaign lifecycle; renderer failures never prevent booking a result.
local A=ArcadiaNexus
local E={state='IDLE',_revision=0}; A.SC_Engine=E
local function L() return A.SC_Logic end
local function S() return A.SC_Settings end
local function UI(name,...) local R=A.SC_Renderer; if not R or not R[name] then return end local ok,err=pcall(R[name],R,...); if not ok and GH_LogError then GH_LogError('Shadows Conquest '..name..': '..tostring(err)) end end
function E:IsConfigLocked() return self.state~='IDLE' and self.state~='SLOT_MENU' end
function E:_EndSession() if self._sessionId then A.Lifecycle:EndGame('SHADOWSCONQUEST',self._sessionId); self._sessionId=nil end end
function E:_Save()
 if self.state~='PLAYING' then return end
 self._book.inProgress={snapshotVersion=1,runId=self._runId,gameState=L():Copy(self._gameState),revision=self._revision}; self._book.runId=self._runId; self._book.mapLevel=self._gameState.puzzleIndex; self._book.timestamp=time(); S():SaveSlot(self._slot,self._book)
end
function E:StopGame()
 self:_Save(); self:_EndSession(); self._revision=self._revision+1; self.state='IDLE'; self._gameState=nil; self._result=nil; self._book=nil; self._slot=nil; UI('EnterIdleState')
end
function E:SaveAndPause() if self.state=='PLAYING' then self:_Save(); if self._sessionId then A.Lifecycle:PauseGame('SHADOWSCONQUEST',self._sessionId) end end self:StopGame() end
function E:ShowSlots() self:SaveAndPause(); self.state='SLOT_MENU'; UI('ShowSlotMenu'); UI('_UpdateControlLabels') end
function E:StartGame(config)
 if config==nil then self:ShowSlots(); return true end
 if type(config)=='string' then config={slot=1,action='new',difficulty=config,moveLimitActive=S():Get('moveLimitActive')} end
 if type(config)~='table' or not L():Int(config.slot,3) or config.slot<1 or config.action~='new' and config.action~='continue' then return false end
 local pending=S():GetPending()
 if pending then
  if pending.slot~=config.slot then UI('ShowFeedback','msg_pending'); return false end
  if not S():ValidateResult(pending,A.LocalResults:GetReceipt(pending.runId)) then UI('ShowFeedback','msg_invalid_save'); return false end
  self:SaveAndPause(); self._slot=config.slot; self._book=L():Copy(S():LoadSlot(config.slot)); self._gameState=L():ValidateState(pending.gameState); self._runId=pending.runId; self._result=L():Copy(pending); self.state='RESULT_PENDING'; UI('HideSlotMenu'); UI('RenderGame',self._gameState); return self:RetryResult()
 end
 local b
 if config.action=='continue' then b=S():ValidateBook(S():LoadSlot(config.slot),config.slot)
 else local limit=config.moveLimitActive; if limit==nil then limit=S():Get('moveLimitActive') end b=S():NewBook(config.slot,config.difficulty or S():Get('difficulty'),limit) end
 if not b then UI('ShowFeedback','msg_invalid_save'); return false end
 if self:SaveAndPause()==false then return false end
 if config.action=='continue' and b.inProgress then
  local sid=A.Lifecycle:ClaimRestart('SHADOWSCONQUEST',nil); if not sid then return false end
  self._sessionId=sid; self._slot=config.slot; self._book=b; S():SaveSlot(self._slot,b); UI('HideSlotMenu')
  self._gameState=L():Copy(b.inProgress.gameState); self._runId=b.inProgress.runId; self._revision=b.inProgress.revision; self.state='PLAYING'; UI('RenderGame',self._gameState); UI('_UpdateControlLabels'); return true
 end
 self._slot=config.slot; self._book=b; S():SaveSlot(self._slot,b); UI('HideSlotMenu')
 self.state='MAP'; UI('ShowMap',b); UI('_UpdateControlLabels'); return true
end
function E:SelectLevel(i)
 if self.state~='MAP' or S():GetPending() or not S():IsUnlocked(self._book,i) then return false end
 local e=L():Entry(self._book.difficulty,i); if not e then return false end
 local gs=L():NewState(self._book.difficulty,e,false,self._book.moveLimitActive); if not gs then return false end gs.puzzleIndex=i; gs.puzzleName=e.name
 local sid=A.Lifecycle:ClaimRestart('SHADOWSCONQUEST',nil); if not sid then return false end
 self._sessionId=sid; self._gameState=gs; self._runId=A.LocalResults:NewRun('SHADOWSCONQUEST'); self._revision=self._revision+1; self.state='PLAYING'; S():RecordStart(); self:_Save(); UI('HideMap'); UI('RenderGame',gs); return true
end
function E:ShowMap()
 if not self._slot or self.state=='RESULT_PENDING' then return false end
 self:_Save(); self:_EndSession(); self._book=S():ValidateBook(S():LoadSlot(self._slot),self._slot); if not self._book then return false end
 self.state='MAP'; self._gameState=nil; self._result=nil; self._revision=self._revision+1; UI('ShowMap',self._book); UI('_UpdateControlLabels'); return true
end
function E:ResumeSelectedLevel()
 if self.state~='MAP' or not self._book.inProgress then return false end return self:StartGame({slot=self._slot,action='continue'})
end
function E:PlaySound(k)
 local setting={toggle='soundOnToggle',win='soundOnWin',lose='soundOnLose'}
 if not S():Get('soundEnabled') or not S():Get(setting[k]) then return end if C_Sound and C_Sound.PlaySound then C_Sound.PlaySound(({toggle=850,win=888,lose=842})[k],'Master') end
end
function E:HandleClick(r,c)
 if self.state~='PLAYING' then return false end local gs=self._gameState
 if not L():Toggle(gs,r,c) then return false end gs.cursorR=r; gs.cursorC=c; self._revision=self._revision+1
 if L():IsWon(gs) then self:_Finish('WIN','solved'); return true end
 if L():IsMoveLimitReached(gs) then self:_Finish('LOSS','moves'); return true end
 self:_Save(); self:PlaySound('toggle'); UI('UpdateGrid',gs,r,c); UI('UpdateHUD',gs); return true
end
function E:ResetPuzzle()
 if self.state~='PLAYING' then return false end local run,rev=self._runId,self._revision
 UI('ShowConfirmReset',function()
  if self.state~='PLAYING' or self._runId~=run or self._revision~=rev then return false end
  local i=self._gameState.puzzleIndex; self:_EndSession(); self.state='MAP'; self._book.inProgress=nil; self._book.runId=nil; return self:SelectLevel(i)
 end); return true
end
function E:_Finish(result,reason)
 if self.state~='PLAYING' or self._result then return false end local gs=self._gameState
 if result=='WIN' and (reason~='solved' or not L():IsWon(gs)) or result=='LOSS' and (reason~='moves' or not L():IsMoveLimitReached(gs) or L():IsWon(gs)) or result~='WIN' and result~='LOSS' then return false end
 self.state='RESULT_PENDING'; self:_EndSession()
 self._result={gameId='SHADOWSCONQUEST',runId=self._runId,slot=self._slot,ruleVersion=2,catalogVersion=2,ratingVersion=2,scoreVersion=2,difficulty=L():ScoreKey(gs.difficulty,gs.moveLimitActive),result=result,reason=reason,score=result=='WIN' and L():CalcScore(gs) or 0,stars=result=='WIN' and L():Stars(gs) or 0,gameState=L():Copy(gs),stats={difficulty=gs.difficulty,moveLimitActive=gs.moveLimitActive,moves=gs.moveCount,puzzleId=gs.puzzleId}}
 S():QueueResult(self._result); return self:RetryResult()
end
function E:RetryResult()
 local d=self._result; if not d then return false end local ok=pcall(A.Engine.Emit,A.Engine,'GAME_RESULT',d)
 if not ok or not d.processed then self.state='RESULT_PENDING'; UI('ShowPending',d); return false end
 self.state=d.result=='WIN' and 'WIN' or 'GAMEOVER'; self._book=L():Copy(S():LoadSlot(self._slot)); self._gameState.finalScore=d.score; self:PlaySound(d.result=='WIN' and 'win' or 'lose'); UI('UpdateGrid',self._gameState); UI('UpdateHUD',self._gameState); UI('ShowResult',d); UI('_UpdateControlLabels'); return true
end
function E:RetryPuzzle()
 if self.state~='WIN' and self.state~='GAMEOVER' or not self._result or not self._result.processed then return false end local i=self._gameState.puzzleIndex; self.state='MAP'; self._result=nil; return self:SelectLevel(i)
end
function E:NextPuzzle()
 if self.state~='WIN' or not self._gameState then return false end
 local i=self._gameState.puzzleIndex+1
 if not S():IsUnlocked(self._book,i) then return false end
 self._result=nil; self.state='MAP'
 if not self:SelectLevel(i) then return self:ShowMap() end
 return true
end
function E:On() UI('_UpdateControlLabels') end
function E:Off() self:SaveAndPause() end
