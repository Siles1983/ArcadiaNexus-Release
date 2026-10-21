-- Sudoku session, durable input and transactional completion.
local A=_G.ArcadiaNexus
local E={state="IDLE"}; A.SDK_Engine=E
local function StopFeedbackSound()
    if E._soundHandle then
        StopSound(E._soundHandle)
        E._soundHandle=nil
    end
end
local function Sound(event)
    local S=A.SDK_Settings
    local opt=event=="complete" and "soundOnComplete" or event=="error" and "soundOnError" or "soundOnPlace"
    StopFeedbackSound()
    if S:Get("soundEnabled") and S:Get(opt) then
        -- Use the native UI scroll click for both input and clearing. 1116 is
        -- not a documented UI feedback kit and must not be used here.
        local click=(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON) or 1115
        local played,handle=PlaySound(({place=click,error=847,complete=888,clear=click})[event],"SFX")
        if played then E._soundHandle=handle end
    end
end
function E:_Snapshot()
    if not self.activeGame then return true end
    return A.SDK_Settings:SaveSlot(self.activeSlot,self.activeGame:Snapshot())
end
function E:_EndSession(paused)
    if self._sessionId then
        if paused then A.Lifecycle:PauseGame("SUDOKU",self._sessionId) end
        A.Lifecycle:EndGame("SUDOKU",self._sessionId); self._sessionId=nil
    end
end
function E:CanContinueSave(save)
    if not A.SDK_Logic:ValidateSave(save) or (save.phase~="PLAYING" and not save.resultPending) then return false end
    local serial=A.LocalResults:GetSerial("SUDOKU",save.runId)
    if not serial then return false end
    local j,receipt=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(save.runId)
    if not receipt and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if receipt and (save.phase=="PLAYING" or receipt.difficulty~=save.difficulty or receipt.result~="WIN"
        or receipt.score~=A.SDK_Logic:GetScore(save.difficulty)) then return false end
    return true
end
function E:StartGame(config)
    if self.activeGame then return false end
    config=type(config)=="table" and config or {}
    local S=A.SDK_Settings
    local slot,mode=config.slot or 1,config.mode or "new"
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>S.MAX_SLOTS
        or (mode~="new" and mode~="continue") then return false end
    local save=S:LoadSlot(slot)
    local game=A.SDK_Game:New()
    if mode=="continue" then
        if not self:CanContinueSave(save) or not game:Load(save) then return false end
    else
        local diff=config.difficulty or S:Get("difficulty")
        if not A.SDK_Logic:GetScore(diff) or (save and not config.overwrite) then return false end
        if not game:Init({difficulty=diff,index=S:NextPuzzleIndex(diff)}) then return false end
    end
    local sid=A.Lifecycle:ClaimRestart("SUDOKU",self._sessionId)
    if not sid then return false end
    if mode~="continue" then game.runId=A.LocalResults:NewRun("SUDOKU") end
    self.activeGame,self.activeSlot,self.activeConfig=game,slot,{difficulty=game.difficulty}
    self._lastResult=nil
    self._sessionId=sid
    self.state=game.phase=="PLAYING" and "PLAYING" or "RESULT_PENDING"
    self:_Snapshot()
    A.Engine:Emit("SDK_GAME_STARTED",game:GetBoardState())
    if self.state=="RESULT_PENDING" then self:RetryResult() end
    A.LocalResults:Prune(); return true
end
function E:HandleCellClick(r,c)
    if self.state~="PLAYING" then return false end
    local g=self.activeGame
    if not A.SDK_Logic:IsCell(r,c) then return false end
    local editable=g:SelectCell(r,c)
    self:_Snapshot()
    A.Engine:Emit(editable and "SDK_CELL_SELECTED" or "SDK_BOARD_UPDATED",g:GetBoardState())
    return true
end
function E:_Result()
    local g=self.activeGame
    local data={gameId="SUDOKU",difficulty=g.difficulty,runId=g.runId,result="WIN",score=A.SDK_Logic:GetScore(g.difficulty),
        stats={moves=g.moves,mistakes=g.mistakes}}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then
        self.state="RESULT_PENDING"; g.resultPending=true; self:_Snapshot()
        A.Engine:Emit("SDK_RESULT_FAILED",g:GetBoardState()); return false
    end
    self.state="COMPLETE"; g.resultPending=nil; self._lastResult=data
    self:_Snapshot(); self:_EndSession(false)
    if not data.localReplay then Sound("complete") end
    A.Engine:Emit("SDK_GAME_COMPLETE",g:GetBoardState(),data); return true
end
function E:RetryResult()
    if self.state~="RESULT_PENDING" or not self.activeGame then return false end
    return self:_Result()
end
function E:HandleNumberInput(n)
    if self.state~="PLAYING" then return false end
    local result=self.activeGame:PlaceNumber(n)
    if result=="noop" then return false end
    if result=="complete" then self.activeGame.resultPending=true; self.state="RESULT_PENDING" end
    self:_Snapshot()
    if result=="complete" then return self:_Result() end
    Sound(result=="error" and "error" or "place")
    A.Engine:Emit("SDK_BOARD_UPDATED",self.activeGame:GetBoardState(),result=="note")
    return true
end
function E:HandleCellRightClick(r,c)
    if self.state~="PLAYING" or not self.activeGame:ClearCell(r,c) then return false end
    self:_Snapshot(); Sound("clear")
    A.Engine:Emit("SDK_BOARD_UPDATED",self.activeGame:GetBoardState()); return true
end
function E:HandleUndo()
    if self.state~="PLAYING" or not self.activeGame:Undo() then return false end
    self:_Snapshot()
    A.Engine:Emit("SDK_BOARD_UPDATED",self.activeGame:GetBoardState(),self.activeGame.notesMode)
    return true
end
function E:ToggleNotesMode(value)
    if self.state~="PLAYING" then return false end
    self.activeGame.notesMode=not not value; self:_Snapshot()
    A.Engine:Emit("SDK_BOARD_UPDATED",self.activeGame:GetBoardState(),true); return true
end
function E:HandleKey(key,ctrl)
    if self.state~="PLAYING" then return false end
    local g=self.activeGame
    if key=="Z" and ctrl then self:HandleUndo(); return true end
    local n=tonumber(key) or tonumber(key:match("^NUMPAD(%d)$"))
    if n and n>=1 and n<=9 and not ctrl then self:HandleNumberInput(n); return true end
    if key=="DELETE" or key=="BACKSPACE" then
        if g.selected then self:HandleCellRightClick(g.selected.r,g.selected.c) end
        return true
    end
    if key=="ESCAPE" then
        g.selected=nil; g:Refresh(); self:_Snapshot()
        A.Engine:Emit("SDK_BOARD_UPDATED",g:GetBoardState()); return true
    end
    local delta={LEFT={0,-1},RIGHT={0,1},UP={-1,0},DOWN={1,0}}
    if delta[key] then
        local s=g.selected or {r=1,c=1}; local d=delta[key]
        local r,c=math.max(1,math.min(9,s.r+d[1])),math.max(1,math.min(9,s.c+d[2]))
        g:SelectCell(r,c); self:_Snapshot()
        A.Engine:Emit("SDK_BOARD_UPDATED",g:GetBoardState()); return true
    end
    return false
end
function E:SaveAndPause()
    StopFeedbackSound()
    if not self.activeGame then return true end
    if self:_Snapshot()==false then return false end
    self:_EndSession(true)
    self.activeGame,self.activeSlot,self.activeConfig,self._lastResult=nil,nil,nil,nil
    self.state="IDLE"; A.Engine:Emit("SDK_GAME_STOPPED"); return true
end
function E:StopGame() return self:SaveAndPause() end
