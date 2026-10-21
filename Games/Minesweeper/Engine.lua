-- Persistent Minesweeper runs. Wall-clock segments measure active time without
-- GameLoop's simulation dt clamp; logout goes through the shared registry stop.
local A=_G.ArcadiaNexus
local E={state="IDLE"}
A.MS_Engine=E
local function Sound(key)
    local S=A.MS_Settings
    if S:Get("soundEnabled") and S:Get("soundOn"..key) then
        PlaySound(({Reveal=774,Flag=3175,Explode=3789,Win=888})[key],"SFX")
    end
end
function E:GetElapsedMs()
    if not self.activeGame then return 0 end
    return math.min(2147483647,math.floor(self.activeGame.elapsedMs+
        (self._startedAt and math.max(0,GetTime()-self._startedAt)*1000 or 0)+0.00001))
end
function E:_Snapshot()
    if not self.activeGame then return true end
    return A.MS_Settings:SaveSlot(self.activeSlot,self.activeGame:Snapshot(self:GetElapsedMs()))
end
function E:_StartClock(start)
    self._startedAt=start or GetTime()
    if not self._clockLoop then self._clockLoop=A.GameLoop.Create("ArcadiaNexus_MS_Clock") end
    local sid=self._sessionId
    self._clockLoop:Start(function()
        local elapsed=self:GetElapsedMs()
        if math.floor(elapsed/1000)~=self._hudSecond then
            self._hudSecond=math.floor(elapsed/1000)
            A.Engine:Emit("MS_TIME_UPDATED",elapsed)
        end
    end,{stateCheck=function()
        return E.state=="PLAYING" and A.GameSession:IsSession(E,sid)
    end})
end
function E:_StopClock()
    if self.activeGame then self.activeGame.elapsedMs=self:GetElapsedMs() end
    self._startedAt=nil
    if self._clockLoop then self._clockLoop:Stop() end
end
function E:_EndSession(paused)
    if self._sessionId then
        if paused then A.Lifecycle:PauseGame("MINESWEEPER",self._sessionId) end
        A.Lifecycle:EndGame("MINESWEEPER",self._sessionId)
        self._sessionId=nil
    end
end
function E:CanContinueSave(save)
    if not A.MS_Logic:ValidateSave(save) or (save.phase~="PLAYING" and not save.resultPending) then return false end
    local serial=A.LocalResults:GetSerial("MINESWEEPER",save.runId)
    if not serial then return false end
    local j,receipt=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(save.runId)
    if not receipt and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if receipt and (save.phase=="PLAYING" or receipt.difficulty~=save.difficulty
        or receipt.result~=(save.phase=="WON" and "WIN" or "LOSS")
        or receipt.elapsedMs~=save.elapsedMs) then return false end
    return true
end
function E:StartGame(config)
    if self.activeGame then return false end
    config=type(config)=="table" and config or {}
    local S=A.MS_Settings
    local slot,mode=config.slot or 1,config.mode or "new"
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>S.MAX_SLOTS
        or (mode~="new" and mode~="continue") then return false end
    local save=S:LoadSlot(slot)
    local game=A.MS_Game:New()
    if mode=="continue" then
        if not self:CanContinueSave(save) or not game:Load(save) then return false end
    else
        local diff=config.difficulty or S:Get("difficulty")
        if (save and not config.overwrite) or not A.MS_Logic.CONFIGS[diff] then return false end
        game:Init({difficulty=diff})
    end
    local sid=A.Lifecycle:ClaimRestart("MINESWEEPER",self._sessionId)
    if not sid then return false end
    if mode~="continue" then game.runId=A.LocalResults:NewRun("MINESWEEPER") end
    self.activeGame,self.activeSlot,self.activeConfig=game,slot,{difficulty=game.board.difficulty}
    self._lastResult,self._hudSecond=nil,nil
    self._sessionId=sid
    self.state=game.board.phase=="PLAYING" and "PLAYING" or "RESULT_PENDING"
    if self.state=="PLAYING" and game.board.minesPlaced then self:_StartClock() end
    self:_Snapshot()
    A.Engine:Emit("MS_GAME_STARTED",game:Snapshot(self:GetElapsedMs()))
    if self.state=="RESULT_PENDING" then self:RetryResult() end
    A.LocalResults:Prune()
    return true
end
function E:_Result()
    local game=self.activeGame
    local state=game:GetBoardState()
    local data={gameId="MINESWEEPER",difficulty=state.difficulty,runId=game.runId,
        result=state.phase=="WON" and "WIN" or "LOSS",score=state.score,elapsedMs=game.elapsedMs}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then
        game.resultPending=true
        self.state="RESULT_PENDING"
        self:_Snapshot()
        A.Engine:Emit("MS_RESULT_FAILED",state)
        return false
    end
    game.resultPending=nil
    self._lastResult=data
    self.state=state.phase
    self:_Snapshot()
    -- Keep ownership until the result presentation closes so guarded OnHide
    -- can clean up after a tab switch or closing the hub. The clock is stopped.
    if not data.localReplay then Sound(state.phase=="WON" and "Win" or "Explode") end
    A.Engine:Emit(state.phase=="WON" and "MS_GAME_WON" or "MS_GAME_LOST",game:GetBoardState(),data)
    return true
end
function E:HandleReveal(r,c)
    if self.state~="PLAYING" or not self.activeGame then return false end
    local game=self.activeGame
    local placed,start=game.board.minesPlaced,GetTime()
    local result=game:RevealCell(r,c)
    if result~="revealed" and result~="won" and result~="mine" then return false end
    if not placed and game.board.minesPlaced then self:_StartClock(start) end
    if result=="won" or result=="mine" then
        self:_StopClock()
        game.resultPending=true
        self.state="RESULT_PENDING"
        self:_Snapshot()
        return self:_Result()
    end
    self:_Snapshot()
    Sound("Reveal")
    A.Engine:Emit("MS_CELL_REVEALED",game:Snapshot(self:GetElapsedMs()),result)
    return true
end
function E:HandleFlag(r,c)
    if self.state~="PLAYING" or not self.activeGame then return false end
    local result=self.activeGame:ToggleFlag(r,c)
    if result~="flagged" and result~="unflagged" then return false end
    self:_Snapshot()
    Sound("Flag")
    A.Engine:Emit("MS_FLAG_TOGGLED",self.activeGame:Snapshot(self:GetElapsedMs()),result)
    return true
end
function E:RetryResult()
    if self.state~="RESULT_PENDING" or not self.activeGame then return false end
    return self:_Result()
end
function E:SaveAndPause()
    if not self.activeGame then return true end
    if self:_Snapshot()==false then return false end
    self:_StopClock()
    self:_EndSession(true)
    self.activeGame,self.activeSlot,self.activeConfig,self._lastResult=nil,nil,nil,nil
    self.state="IDLE"
    A.Engine:Emit("MS_GAME_STOPPED")
    return true
end
function E:StopGame() return self:SaveAndPause() end
