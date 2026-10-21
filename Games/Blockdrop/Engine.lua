-- Blockdrop: one shared landing operation, bounded gameplay clock and owned saves.
local A=_G.ArcadiaNexus
A.BLD_Engine={state="IDLE",_board=nil,_sessionId=nil,_generation=0}
local E=A.BLD_Engine
local GAME_ID="BLOCKDROP"
local loop=A.GameLoop.Create("ArcadiaNexus_BLD_LoopFrame")
local SND_PATH="Interface\\AddOns\\ArcadiaNexus\\Games\\Blockdrop\\assets\\sounds\\"
local sounds={move="move_piece.wav",rotate="rotate_piece.wav",line="line_clear.wav",blockdrop="4_lines_clear.wav",levelup="level_up.wav"}
local function Sound(key)
    if A.BLD_Settings:Get("snd_"..key) then PlaySoundFile(SND_PATH..sounds[key],"Master") end
end
local function Call(method,...)
    local R=A.BLD_Renderer; if R and R[method] then R[method](R,...) end
end
function E:Init() end
function E:EnableKeys(on) if self._keyFrame then self._keyFrame:EnableKeyboard(on) end end
function E:_setupKeyFrame()
    if self._keyFrame then return end
    local R=A.BLD_Renderer; local parent=R and R.frame or UIParent
    local k=CreateFrame("Frame",nil,parent); k:SetAllPoints(parent); k:EnableKeyboard(false); k:SetPropagateKeyboardInput(true)
    k:SetScript("OnKeyDown",function(f,key)
        local mapped=({A=true,LEFT=true,D=true,RIGHT=true,W=true,UP=true,S=true,DOWN=true,SPACE=true,P=true,ESCAPE=true})[key]
        local focused=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        f:SetPropagateKeyboardInput(not (mapped and not focused and (E.state=="PLAYING" or E.state=="PAUSED")))
        if mapped then E:HandlePlayKey(key) end
    end)
    k:SetScript("OnKeyUp",function(_,key) E:HandleKeyUp(key) end)
    self._keyFrame=k
end
function E:_startTick() loop:Start(function(dt) E:_Tick(dt) end,{stateCheck=function() return E.state=="PLAYING" end}) end
function E:_stopTick() loop:Stop() end
function E:_NeutralizeInput()
    self._blocked=self._blocked or {}
    for token in pairs(self._held or {}) do self._blocked[token]=true end
    self._moveDir=nil; self._moveRemaining=0; self._softRemaining=0
end
function E:_Held(command)
    for token,value in pairs(self._held or {}) do if value==command and not (self._blocked or {})[token] then return true end end
    return false
end
function E:_GroundChanged(b,changed)
    local L=A.BLD_Logic
    if changed and b.lockRemaining~=nil and b.lockResets<L.LOCK_RESET_LIMIT then
        b.lockResets=b.lockResets+1; b.lockRemaining=L.LOCK_DELAY
    end
    local grounded=not L:CanPlace(b,b.piece,1,0)
    if grounded and b.lockRemaining==nil then b.lockRemaining=L.LOCK_DELAY
    elseif not grounded and b.lockResets<L.LOCK_RESET_LIMIT then b.lockRemaining=nil end
    return grounded
end
function E:Move(direction)
    local b=self._board; if self.state~="PLAYING" or not b then return false end
    local changed=direction=="LEFT" and A.BLD_Logic:MoveLeft(b) or direction=="RIGHT" and A.BLD_Logic:MoveRight(b)
    if changed then self:_GroundChanged(b,true); Sound("move"); Call("UpdatePiece",b) end
    return changed==true
end
function E:Rotate()
    local b=self._board; if self.state~="PLAYING" or not b or GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return false end
    if not A.BLD_Logic:Rotate(b) then return false end
    self:_GroundChanged(b,true); Sound("rotate"); Call("UpdatePiece",b); return true
end
function E:SoftDrop()
    local b=self._board; if self.state~="PLAYING" or not b then return false end
    local moved=A.BLD_Logic:Tick(b,b.piece); self:_GroundChanged(b,false)
    if moved then Call("UpdatePiece",b) end; return moved
end
function E:HardDrop()
    local b=self._board; if self.state~="PLAYING" or not b then return false end
    A.BLD_Logic:HardDrop(b); return self:_Land(b.piece)
end
function E:_InputDown(token,command)
    self._held,self._blocked=self._held or {},self._blocked or {}
    if self._held[token] then return end
    self._held[token]=command
    if self._blocked[token] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    if command=="PAUSE" then self:TogglePause(); return
    elseif command=="EXIT" then self:StopGame(); return end
    if self.state~="PLAYING" then self._blocked[token]=true; return end
    if command=="LEFT" or command=="RIGHT" then
        self._moveDir=command; self._moveRemaining=A.BLD_Logic.MOVE_DELAY; self:Move(command)
    elseif command=="DOWN" then self._softRemaining=A.BLD_Logic.SOFT_RATE; self:SoftDrop()
    elseif command=="ROTATE" then self:Rotate()
    elseif command=="DROP" then self:HardDrop() end
end
function E:HandlePlayKey(key)
    local command=({A="LEFT",LEFT="LEFT",D="RIGHT",RIGHT="RIGHT",W="ROTATE",UP="ROTATE",S="DOWN",DOWN="DOWN",SPACE="DROP",P="PAUSE",ESCAPE="EXIT"})[key]
    if command then self:_InputDown(key,command) end
end
function E:HandleKeyUp(token)
    self._held,self._blocked=self._held or {},self._blocked or {}; self._held[token]=nil; self._blocked[token]=nil
    if self._moveDir and not self:_Held(self._moveDir) then
        local opposite=self._moveDir=="LEFT" and "RIGHT" or "LEFT"
        self._moveDir=self:_Held(opposite) and opposite or nil; self._moveRemaining=A.BLD_Logic.MOVE_DELAY
    end
end
function E:HandlePadButton(btn,pressed)
    local command=({PADLEFT="LEFT",PADRIGHT="RIGHT",PADUP="ROTATE",PADDOWN="DOWN",PAD1="DROP",PAD4="PAUSE",PADFORWARD="PAUSE"})[btn]
    if not command then return end
    if pressed then self:_InputDown(btn,command) else self:HandleKeyUp(btn) end
end
function E:_Save()
    local b=self._board
    if b and self.state~="GAMEOVER" and not b.terminal then
        A.BLD_Settings:SaveMidGame(self.activeSlot,A.BLD_Logic:SerializeBoard(b,self.state))
    end
end
function E:RetryPending()
    local S=A.BLD_Settings
    for id,data in pairs(A.BLD_Logic:Copy(S:GetPending())) do
        A.Engine:Emit("GAME_RESULT",data); if data.processed then S:ClearPending(id) end
    end
end
function E:StartGame(config)
    config=type(config)=="table" and config or {}
    local L,S=A.BLD_Logic,A.BLD_Settings
    local slot=tonumber(config.slot or S:GetActiveSlot()); local mode=config.mode or "new"
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS or mode~="new" and mode~="continue" then return false end
    local save=mode=="continue" and S:LoadSlot(slot)
    local b
    if mode=="continue" then
        b=type(save)=="table" and L:DeserializeBoard(save.midGame)
        if not b then Call("ShowInvalidSave"); return false end
        if save.midGame.version and not A.LocalResults:GetSerial(GAME_ID,b.runId) then Call("ShowInvalidSave"); return false end
    else b=L:NewBoard(); b.nextPiece=L:NewPiece(b) end
    self:RetryPending()
    if b.runId and A.LocalResults:GetReceipt(b.runId) then Call("ShowInvalidSave"); return false end
    self:_Save(); self:_stopTick(); self:_NeutralizeInput(); self._generation=self._generation+1
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self.activeSlot=slot; S:SetActiveSlot(slot); b.runId=b.runId or A.LocalResults:NewRun(GAME_ID)
    self._board=b; self.state=b.phase or "PLAYING"
    if not b.piece then self:_spawnNext() elseif b.pieceSerial==0 then b.pieceSerial=1 end
    if self.state=="GAMEOVER" then return false end
    self:_setupKeyFrame(); self:EnableKeys(true); self:_Save()
    local gen=self._generation
    Call("EnterPlayState",b); Call("FullRedraw",b)
    if self._board~=b or self._generation~=gen then return true end
    if self.state=="PAUSED" then A.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause") else self:_startTick() end
    A.Engine:Emit("BLD_GAME_STARTED",{}); return true
end
function E:TogglePause()
    if self.state~="PLAYING" and self.state~="PAUSED" then return end
    self:_NeutralizeInput()
    if self.state=="PLAYING" then
        self.state="PAUSED"; self:_stopTick(); A.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
    else self.state="PLAYING"; A.Lifecycle:ResumeGame(GAME_ID,self._sessionId); Call("HidePause"); self:_startTick() end
    self:EnableKeys(true)
end
function E:SaveAndPause()
    self:_Save(); self:_stopTick(); self:_NeutralizeInput(); self:EnableKeys(false)
    if self._sessionId then A.Lifecycle:PauseGame(GAME_ID,self._sessionId); A.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self.state="IDLE"; self._board=nil; self._generation=self._generation+1
end
function E:StopGame() self:SaveAndPause(); Call("EnterIdleState") end
function E:_spawnNext()
    local b=self._board; local L=A.BLD_Logic
    b.piece=b.nextPiece; b.nextPiece=L:NewPiece(b); b.pieceSerial=b.pieceSerial+1
    b.interval=L:GetTickInterval(b.level); b.gravityRemaining=b.interval; b.lockRemaining=nil; b.lockResets=0
    self:_GroundChanged(b,false)
    if L:CheckGameOver(b,b.piece) then self:_gameOver() end
end
function E:_Land(expected)
    local b=self._board; local L=A.BLD_Logic
    if self.state~="PLAYING" or not b or b.piece~=expected or b.lockedPieceSerial==b.pieceSerial then return false end
    if L:CanPlace(b,b.piece,1,0) then return false end
    b.lockedPieceSerial=b.pieceSerial; self:_NeutralizeInput()
    L:LockPiece(b,b.piece); local cleared=L:ClearLines(b); local oldLevel=b.level
    L:AddScore(b,cleared); self:_spawnNext()
    -- Spawn/top-out is fixed and booked before effects, sounds and callbacks.
    local gen=self._generation
    if self._board~=b then return true end
    if cleared>0 then Sound(cleared==4 and "blockdrop" or "line") end
    if b.level~=oldLevel then Sound("levelup"); A.Engine:Emit("BLD_LEVEL_UP",{level=b.level}) end
    if self._board~=b or self._generation~=gen then return true end
    Call("FullRedraw",b)
    if self._board~=b or self._generation~=gen then return true end
    if cleared>0 then Call("ShowLineFeedback",cleared); A.Engine:Emit("BLD_LINES_CLEARED",{lines=cleared,score=b.score}) end
    return true
end
function E:_Tick(dt)
    local b=self._board; if self.state~="PLAYING" or not b then return end
    local L=A.BLD_Logic
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput() end
    b.simRemainder=b.simRemainder+math.max(0,math.min(dt or 0,0.1))
    for _=1,12 do
        if b.simRemainder+1e-10<1/120 then break end
        b.simRemainder=math.max(0,b.simRemainder-1/120); b.elapsedSecs=b.elapsedSecs+1/120
        if self._moveDir and self:_Held(self._moveDir) then
            self._moveRemaining=self._moveRemaining-1/120
            if self._moveRemaining<=1e-9 then self._moveRemaining=self._moveRemaining+L.MOVE_RATE; self:Move(self._moveDir) end
        end
        if self._board~=b or self.state~="PLAYING" then return end
        if self:_Held("DOWN") then
            self._softRemaining=self._softRemaining-1/120
            if self._softRemaining<=1e-9 then self._softRemaining=self._softRemaining+L.SOFT_RATE; self:SoftDrop() end
        else
            b.gravityRemaining=b.gravityRemaining-1/120
            if b.gravityRemaining<=1e-9 then b.gravityRemaining=b.gravityRemaining+b.interval; self:SoftDrop() end
        end
        if self._board~=b or self.state~="PLAYING" then return end
        local grounded=self:_GroundChanged(b,false)
        if b.lockRemaining and (grounded or b.lockResets>=L.LOCK_RESET_LIMIT) then
            b.lockRemaining=math.max(0,b.lockRemaining-1/120)
            if b.lockRemaining<=1e-9 and grounded then
                self:_Land(b.piece); if self._board==b then b.simRemainder=0 end; return
            end
        end
    end
    Call("UpdateFeedback",math.max(0,math.min(dt or 0,0.1)))
end
function E:_tick() self:_Tick(1/120) end
function E:_gameOver()
    local b=self._board; if not b or b.terminal then return end
    b.terminal=true; self.state="GAMEOVER"; self:_stopTick(); self:_NeutralizeInput(); self:EnableKeys(false)
    A.BLD_Settings:DeleteSlot(self.activeSlot)
    -- Session bleibt bis SaveAndPause/StopGame, damit der Ergebnisdialog beim Verlassen schließt.
    local data={gameId=GAME_ID,difficulty="normal",ruleVersion=2,runId=b.runId,score=b.score,result="LOSS",
        legacyContinuation=b.legacyContinuation==true,stats={linesCleared=b.lines}}
    local S=A.BLD_Settings; S:SavePending(data); A.Engine:Emit("GAME_RESULT",data)
    if data.processed then S:ClearPending(b.runId) end
    b.resultData=data
    if self._board~=b then return end
    Call("ShowGameOver",b)
    if self._board==b then A.Engine:Emit("BLD_GAME_OVER",{score=b.score}) end
end
