-- Nether Bound: session-owned durable rounds; presentation cannot prevent results.
local A=ArcadiaNexus
local E={state='IDLE',_revision=0}; A.HGM_Engine=E
local function L() return A.HGM_Logic end
local function S() return A.HGM_Settings end
local function UI(name,...)
 local R=A.HGM_Renderer; if not R or not R[name] then return end
 local ok,err=pcall(R[name],R,...)
 if not ok and GH_LogError then GH_LogError('Nether Bound '..name,tostring(err)) end
end
function E:IsConfigLocked() return self.state~='IDLE' or self._layoutEditing==true end
function E:_EndSession()
 if self._sessionId then A.Lifecycle:EndGame('HANGMAN',self._sessionId); self._sessionId=nil end
end
-- Lifecycle compatibility: this game has no resumable rounds or slot menu.
function E:SaveAndPause() self:StopGame() end
function E:StopGame()
 if A.HGM_DevLayout then A.HGM_DevLayout:Disable() end
 self:_EndSession(); self.state='IDLE'; self.board=nil; self._result=nil; self._revision=self._revision+1
 UI('EnterIdleState')
end
function E:StartGame(config)
 if self._layoutEditing then return false end
 if config==nil then config={} end
 if type(config)~='table' then return false end
 if config.slot~=nil or config.action=='continue' then return false end
 local pending=S():GetPending()
 if pending then
  if not A.LocalResults:GetSerial('HANGMAN',pending.runId) or not S():ValidateResult(pending,A.LocalResults:GetReceipt(pending.runId)) then UI('ShowFeedback','msg_invalid_save'); return false end
  self:StopGame(); self._runId=pending.runId; self.board=L():ValidateBoard(pending.board); self._result=L():Copy(pending)
  self.state='RESULT_PENDING'; UI('ShowPlaying',self.board); return self:RetryResult()
 end
 local board
  local diff=S():NormalizeDifficulty(config.difficulty or S():Get('difficulty'))
  local cat=S():NormalizeCategory(config.category or S():Get('category'))
  local locale=A.ActiveLocale=='deDE' and 'deDE' or 'enUS'
  local entry=A.HGM_Words:Pick(cat,diff,S():GetHistory(locale)); if not entry then return false end
  board=L():NewBoard(entry,L().ERRORS[diff]); board.difficulty=diff; board.selectedCategory=cat; board.locale=locale
  board.petId=A.HGM_Pets and A.HGM_Pets:Resolve(S():Get('petChoice')) or 'imp'
 self:StopGame()
 local sessionId=A.Lifecycle:RestartGame('HANGMAN',nil)
 if not sessionId then return false end
 self._sessionId=sessionId; self.board=board
 self._runId=A.LocalResults:NewRun('HANGMAN'); self._revision=0
 S():RecordStart(board)
 self.state='PLAYING'; UI('ShowPlaying',board); self:PlaySound('start')
 return true
end
function E:PlaySound(key)
 if not S():Get('soundEnabled') then return end
 local id=({start=166314,hit=166310,error=166308,win=166318,loss=168449})[key]
 if id and PlaySound then PlaySound(id,'SFX') end
end
function E:GuessLetter(letter)
 if self.state~='PLAYING' or not self._sessionId or not A.GameSession:IsSession(self,self._sessionId)
  or type(letter)~='string' or not letter:match('^[a-zA-Z]$') then return false end
 local found=L():GuessLetter(self.board,letter); if found==nil then return false end
 self._revision=self._revision+1
 if self.board.won or self.board.lost then return self:_Finish() end
 self:PlaySound(found and 'hit' or 'error'); UI('RenderBoard',self.board); UI('Pulse',found and 'hit' or 'error'); return true
end
function E:_Finish()
 if self.state~='PLAYING' or self._result or not (self.board.won or self.board.lost) then return false end
 local b=self.board; local result=b.won and 'WIN' or 'LOSS'
 -- Session bleibt bis StopGame, damit Hide den Ergebnisdialog schließt.
 self.state='RESULT_PENDING'
 self._result={gameId='HANGMAN',runId=self._runId,slot=0,ruleVersion=1,catalogVersion=1,scoreVersion=1,
  difficulty=b.difficulty,score=b.won and L().SCORES[b.difficulty] or 0,result=result,board=L():Copy(b),stats={errors=b.errors}}
 S():QueueResult(self._result); return self:RetryResult()
end
function E:RetryResult()
 local d=self._result; if not d then return false end
 local ok=pcall(A.Engine.Emit,A.Engine,'GAME_RESULT',d)
 if not ok or not d.processed then self.state='RESULT_PENDING'; UI('RenderBoard',self.board); UI('ShowPending',d); return false end
 self.state=d.result=='WIN' and 'WON' or 'LOST'; self:PlaySound(d.result=='WIN' and 'win' or 'loss')
 UI('RenderBoard',self.board); UI('Pulse',d.result=='WIN' and 'win' or 'loss'); UI('ShowResult',d)
 return true
end
function E:RetryPuzzle()
 if self.state~='WON' and self.state~='LOST' or not self._result or not self._result.processed then return false end
 return self:StartGame({difficulty=self.board.difficulty,category=self.board.selectedCategory})
end
function E:On() UI('_UpdateControlLabels') end
function E:Off() self:SaveAndPause() end
