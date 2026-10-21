-- Snake: owned world slots, queued turns, bounded fixed movement and atomic results.
local ArcadiaNexus=_G.ArcadiaNexus
ArcadiaNexus.SNK_Engine={activeGame=nil,state="IDLE",_running=false,_sessionId=nil,_generation=0,_tickRate=.18}
local E=ArcadiaNexus.SNK_Engine
local GAME_ID="SNAKE"
local loop=ArcadiaNexus.GameLoop.Create("ArcadiaNexus_SNK_LoopFrame")
local function PlaySNK(event)
    local S = ArcadiaNexus.SNK_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "eat" and S:Get("soundOnEat") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    elseif event == "die" and S:Get("soundOnDie") then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847, "SFX")
    elseif event == "start" and S:Get("soundOnStart") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    end
end


local function Call(method,...)
    local R=ArcadiaNexus.SNK_Renderer
    if R and R[method] then
        local ok,err=pcall(R[method],R,...)
        if not ok then pcall(GH_LogError,"SnakeRenderer",tostring(err)) end
    end
end
function E:_Neutralize()
    self._blocked=self._blocked or {}
    for token in pairs(self._held or {}) do self._blocked[token]=true end
    -- Accepted turns remain part of the world; no held command is synthesized.
end
function E:_StartLoop()
    self._running=true
    loop:Start(function(dt) E:_Tick(dt) end,{maxDt=math.huge,stateCheck=function() return E.state=="PLAYING" end})
end
function E:_StopLoop() self._running=false; loop:Stop() end
function E:_FreezeClock()
    local b=self.activeGame and self.activeGame.board
    if b and b.tickRemainder>=self._tickRate then b.tickRemainder=b.tickRemainder%self._tickRate end
end
function E:_SaveProgress()
    if self.activeGame and (self.state=="PLAYING" or self.state=="PAUSED") then
        self:_FreezeClock()
        ArcadiaNexus.SNK_Settings:SaveSlot(self.activeSlot,ArcadiaNexus.SNK_Logic:Snapshot(self.activeGame.board,self.state))
    end
end
function E:RetryPending()
    local S,L=ArcadiaNexus.SNK_Settings,ArcadiaNexus.SNK_Logic
    for id,data in pairs(L:Copy(S:GetPending())) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end
function E:StartGame(config)
    config=type(config)=="table" and config or {}
    local S,L=ArcadiaNexus.SNK_Settings,ArcadiaNexus.SNK_Logic
    local mode=config.mode or "new"; local slot=tonumber(config.slot or S:GetActiveSlot())
    if not slot or slot%1~=0 or slot<1 or slot>3 or mode~="new" and mode~="continue" then return false end
    local b,phase
    if mode=="continue" then
        local saved=S:LoadSlot(slot); b=L:Restore(saved)
        if not b or not ArcadiaNexus.LocalResults:GetSerial(GAME_ID,b.runId) then Call("ShowInvalidSave"); return false end
        phase=saved.phase
    else b=L:NewBoard({difficulty=config.difficulty or S:Get("difficulty")}) end
    self:RetryPending()
    local receipt=b.runId and ArcadiaNexus.LocalResults:GetReceipt(b.runId)
    if receipt then Call("ShowInvalidSave"); return false end
    self:_SaveProgress(); self:_StopLoop(); self:_Neutralize(); self._generation=self._generation+1
    local previous=self._sessionId
    self._sessionId=ArcadiaNexus.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self.activeSlot=slot; S:SetActiveSlot(slot); b.runId=b.runId or ArcadiaNexus.LocalResults:NewRun(GAME_ID)
    self.activeGame={board=b}; self.state=phase=="PAUSED" and "PAUSED" or "PLAYING"
    self._tickRate=ArcadiaNexus.SNK_Themes:GetDiff(b.difficulty).tickRate
    self.pauseReason=nil; self:_SaveProgress(); local gen=self._generation
    Call("OnGameStarted",b)
    if not self.activeGame or self.activeGame.board~=b or self._generation~=gen then return true end
    if self.state=="PAUSED" then ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
    elseif self.state=="PLAYING" then self:_StartLoop() end
    if not self.activeGame or self.activeGame.board~=b or self._generation~=gen then return true end
    PlaySNK("start"); ArcadiaNexus.Engine:Emit("SNK_GAME_STARTED",b); return true
end
function E:_Tick(dt)
    if self.state~="PLAYING" or not self.activeGame then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:Pause("FOCUS"); return end
    if type(dt)~="number" or dt~=dt or dt<0 then return end
    if dt>.25 then self:Pause("STALL"); return end
    local b=self.activeGame.board; local gen=self._generation
    b.tickRemainder=b.tickRemainder+dt
    for _=1,4 do
        if b.tickRemainder+1e-10<self._tickRate then break end
        b.tickRemainder=math.max(0,b.tickRemainder-self._tickRate)
        self:DoTick()
        if not self.activeGame or self.activeGame.board~=b or self._generation~=gen or self.state~="PLAYING" then return end
    end
end
function E:DoTick()
    if self.state~="PLAYING" or not self.activeGame then return end
    local b=self.activeGame.board; local gen=self._generation
    local tail=b.snake[#b.snake]; local oldTail={r=tail.r,c=tail.c}
    local result=ArcadiaNexus.SNK_Logic:Tick(b)
    if result=="won" or result=="died" then self:_Finish(result=="won" and "WIN" or "LOSS") end
    if not self.activeGame or self.activeGame.board~=b or self._generation~=gen then return end
    if result=="ate" then PlaySNK("eat") end
    Call("OnTick",b,result,oldTail)
end
function E:_Finish(result)
    local b=self.activeGame and self.activeGame.board
    if not b or b.terminal then return end
    b.terminal=true; b.alive=false; b.state=result=="WIN" and "WON" or "LOST"
    self.state="GAMEOVER"; self:_StopLoop(); self:_Neutralize()
    local S=ArcadiaNexus.SNK_Settings; S:DeleteSlot(self.activeSlot)
    -- Session bleibt bis SaveAndPause/StopGame, damit der Ergebnisdialog beim Verlassen schließt.
    local data={gameId=GAME_ID,difficulty=b.difficulty,ruleVersion=2,runId=b.runId,score=b.score,result=result,
        stats={length=#b.snake,fruitsEaten=b.fruitsEaten}}
    b.resultData=data; S:SavePending(data); local gen=self._generation
    ArcadiaNexus.Engine:Emit("GAME_RESULT",data); if data.processed then S:ClearPending(b.runId) end
    if not self.activeGame or self.activeGame.board~=b or self._generation~=gen then return end
    if result=="LOSS" then PlaySNK("die") end
    Call(result=="WIN" and "OnGameWon" or "OnGameLost",b,data.newHighscore==true)
    if self.activeGame and self.activeGame.board==b and self._generation==gen then
        ArcadiaNexus.Engine:Emit(result=="WIN" and "SNK_GAME_WON" or "SNK_GAME_LOST",b,data.newHighscore==true)
    end
end
function E:Pause(reason)
    if self.state~="PLAYING" then return end
    local b,gen=self.activeGame.board,self._generation; self:_FreezeClock()
    self.state="PAUSED"; self.pauseReason=reason; self:_Neutralize(); self:_StopLoop()
    ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId)
    if self.activeGame and self.activeGame.board==b and self._generation==gen and self.state=="PAUSED" then Call("ShowPause",reason) end
end
function E:Resume()
    if self.state~="PAUSED" then return end
    local b,gen=self.activeGame.board,self._generation
    self:_Neutralize(); self.state="PLAYING"; self.pauseReason=nil
    ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID,self._sessionId)
    if not self.activeGame or self.activeGame.board~=b or self._generation~=gen then return end
    Call("HidePause")
    if self.activeGame and self.activeGame.board==b and self._generation==gen and self.state=="PLAYING" then self:_StartLoop() end
end
function E:TogglePause() if self.state=="PAUSED" then self:Resume() else self:Pause() end end
local dirs={W={-1,0},UP={-1,0},S={1,0},DOWN={1,0},A={0,-1},LEFT={0,-1},D={0,1},RIGHT={0,1}}
function E:HandleKeyDown(key,token)
    token=token or key; self._held,self._blocked=self._held or {},self._blocked or {}
    if self._held[token] then return end
    self._held[token]=true; if self._blocked[token] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_Neutralize(); self:Pause("FOCUS"); return end
    if key=="ESCAPE" then self:StopGame(); return elseif key=="P" then self:TogglePause(); return end
    if self.state~="PLAYING" then self._blocked[token]=true; return end
    local dir=dirs[key]; if dir then ArcadiaNexus.SNK_Logic:QueueDir(self.activeGame.board,dir[1],dir[2]) end
end
function E:HandleKeyUp(key,token)
    token=token or key; self._held,self._blocked=self._held or {},self._blocked or {}
    self._held[token]=nil; self._blocked[token]=nil
end
function E:HandleKey(key) self:HandleKeyDown(key); self:HandleKeyUp(key) end
function E:HandlePadButton(btn,pressed)
    local key=({PADLEFT="LEFT",PADRIGHT="RIGHT",PADUP="UP",PADDOWN="DOWN",PAD4="P",PADFORWARD="P",PADBACK="ESCAPE"})[btn]
    if key then if pressed then self:HandleKeyDown(key,btn) else self:HandleKeyUp(key,btn) end end
end
function E:SaveAndPause()
    self:_FreezeClock(); self:_SaveProgress(); self:_StopLoop(); self:_Neutralize()
    local sid=self._sessionId; self._sessionId=nil
    self.state="IDLE"; self.activeGame=nil; self._generation=self._generation+1
    if sid then ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,sid); ArcadiaNexus.Lifecycle:EndGame(GAME_ID,sid) end
end
function E:StopGame()
    self:SaveAndPause(); local gen=self._generation
    ArcadiaNexus.Engine:Emit("SNK_GAME_STOPPED")
    if self._generation==gen and self.state=="IDLE" then Call("EnterIdleState") end
end
