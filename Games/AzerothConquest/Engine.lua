-- Owned slots, stored answer timer and terminal receipts; UI remains a consumer.
local A = _G.ArcadiaNexus
A.AC_Engine={state="IDLE",activeGame=nil,_sessionId=nil}
local E=A.AC_Engine
local ID="AZEROTHCONQUEST"
local timer=A.TimerGuard.New()
local SND_BASE="Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\sounds\\"
local function sound(event)
    local S=A.AC_Settings
    if not S:Get("soundEnabled") or not S:Get("soundOn"..(event=="WIN" and "Win" or event=="LOSS" and "Loss" or event=="HIT" and "Hit" or event=="MISS" and "Miss" or "Sunk")) then return end
    if event=="WIN" then PlaySound(888,"SFX")
    elseif event=="LOSS" then PlaySound(847,"SFX")
    else PlaySoundFile(SND_BASE..(event=="HIT" and "hit.wav" or event=="MISS" and "miss.wav" or "sink.wav"),"SFX") end
end
function E:IsConfigLocked() return self.activeGame~=nil and self.state~="IDLE" and self.state~="GAMEOVER" end
function E:_FreezeAnswer()
    local g=self.activeGame
    if g and g.pending and self._answerDue then
        g.pending.remaining=math.max(0,math.min(.65,self._answerDue-GetTime()))
    end
    self._answerDue=nil; timer:Cancel()
end
function E:_SaveProgress()
    local g=self.activeGame
    if g and not g.gameOver then
        local snapshot=g:Snapshot()
        if g.pending and self._answerDue then snapshot.pending.remaining=math.max(0,math.min(.65,self._answerDue-GetTime())) end
        A.AC_Settings:SaveGame(snapshot)
    end
end
function E:RetryPending()
    local S=A.AC_Settings
    for id,data in pairs(A.AC_Logic:Copy(S:GetPending())) do
        A.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end
function E:CanContinue(saved)
    local g=A.AC_Game:Restore(saved)
    if not g then return false end
    local LR=A.LocalResults
    return LR:GetSerial(ID,g.runId)~=nil and LR:GetJournal().issued[g.runId]~=nil
        and not LR:GetReceipt(g.runId) and not A.AC_Settings:GetPending()[g.runId]
end
function E:StartGame(config)
    config=type(config)=="table" and config or {}
    local S=A.AC_Settings
    if config.slot ~= nil and config.slot ~= 1 then return false end
    local mode=config.mode or "new"
    if mode~="new" and mode~="continue" then return false end
    local g
    if mode=="continue" then
        local saved=S:LoadSave()
        if not self:CanContinue(saved) then A.Engine:Emit("AC_INVALID_SAVE"); return false end
        if self.activeGame and not self.activeGame.gameOver and self.activeGame.runId==saved.runId then
            saved=self.activeGame:Snapshot()
            if saved.pending and self._answerDue then saved.pending.remaining=math.max(0,math.min(.65,self._answerDue-GetTime())) end
        end
        g=A.AC_Game:Restore(saved)
        if not g then A.Engine:Emit("AC_INVALID_SAVE"); return false end
    else
        g=A.AC_Game:New()
        if not g:Init({aiDifficulty=config.aiDifficulty or S:Get("aiDifficulty")}) then
            A.Engine:Emit("AC_PLACEMENT_FAILED"); return false
        end
    end
    self:RetryPending()
    self:_SaveProgress(); self:_FreezeAnswer()
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:RestartGame(ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    g.runId=g.runId or A.LocalResults:NewRun(ID)
    self.activeGame,self.activeSlot,self.activeConfig=g,1,A.AC_Logic:Copy(g.config)
    self.state=g.phase; S:SetActiveSlot(1)
    self:_SaveProgress()
    -- Arm before callbacks so a callback-driven save/restart cancels this timer.
    self:_ScheduleAnswer()
    A.Engine:Emit("AC_GAME_STARTED",g:GetBoardState())
    return true
end
function E:HandlePlacement(r,c)
    local g=self.activeGame
    if not g then return false end
    if not g:PlaceShip(r,c) then
        if g.phase=="PLACEMENT" then A.Engine:Emit("AC_PLACEMENT_INVALID") end
        return false
    end
    self:_SaveProgress(); A.Engine:Emit("AC_PLACEMENT_UPDATED",g:GetBoardState()); return true
end
function E:HandleRandomPlacement()
    local g=self.activeGame
    if not g or g.phase~="PLACEMENT" then return false end
    if not g:PlaceAllRandom() then A.Engine:Emit("AC_PLACEMENT_FAILED"); return false end
    self:_SaveProgress(); A.Engine:Emit("AC_PLACEMENT_UPDATED",g:GetBoardState()); return true
end
function E:UndoPlacement()
    local g=self.activeGame
    if not g or not g:UndoPlacement() then return false end
    self:_SaveProgress(); A.Engine:Emit("AC_PLACEMENT_UPDATED",g:GetBoardState()); return true
end
function E:ToggleOrientation()
    local g=self.activeGame
    if not g or not g:ToggleOrientation() then return false end
    self:_SaveProgress(); A.Engine:Emit("AC_PLACEMENT_UPDATED",g:GetBoardState()); return true
end
function E:StartBattle()
    local g=self.activeGame
    if not g or not g:StartBattle() then return false end
    self.state="BATTLE"; self:_SaveProgress(); A.Engine:Emit("AC_BATTLE_STARTED",g:GetBoardState()); return true
end
function E:_ScheduleAnswer()
    local g,sid=self.activeGame,self._sessionId
    if not g or g.phase~="BATTLE" or g.turnPhase~="AI_PENDING" then return end
    self._answerDue=GetTime()+g.pending.remaining
    timer:After(g.pending.remaining,function()
        if self.activeGame~=g or not A.GameSession:IsSession(self,sid) or g.phase~="BATTLE" or g.turnPhase~="AI_PENDING" then return end
        self._answerDue=nil
        g:ResolveAIShot()
        if g.gameOver then self:_Finish(g)
        else self:_SaveProgress(); sound(g.lastAiShot.result); A.Engine:Emit("AC_SHOT_FIRED",g:GetBoardState()) end
    end)
end
function E:HandleShot(r,c)
    local g=self.activeGame
    if not g or not g:HandleShot(r,c) then return false end
    if g.gameOver then self:_Finish(g)
    else
        self:_SaveProgress(); self:_ScheduleAnswer(); sound(g.lastShot.result)
        A.Engine:Emit("AC_SHOT_FIRED",g:GetBoardState())
    end
    return true
end
function E:_Finish(g)
    if self.activeGame~=g or not g.gameOver or g.resultData then return end
    self.state="GAMEOVER"; self:_FreezeAnswer()
    local diff=g.aiDifficulty
    local data={gameId=ID,difficulty=diff,ruleVersion=1,runId=g.runId,
        score=g.result=="WIN" and ({easy=100,normal=150,hard=200})[diff] or 0,
        result=g.result,skipHighscores=true,
        stats={shotsTotal=g.totalShots,misses=g.totalMisses,hits=g.totalShots-g.totalMisses,
            hitRate=g.totalShots>0 and (g.totalShots-g.totalMisses)/g.totalShots*100 or 0}}
    g.resultData=data
    -- Persist terminal proof before removing the playable snapshot.
    A.AC_Settings:SavePending(data); A.AC_Settings:DeleteSlot(1)
    -- Session bleibt bis SaveAndPause/StopGame, damit Tabwechsel und Hub-Hide
    -- den Ergebnisdialog schließen. Die Buchung ist davon unabhängig.
    A.Engine:Emit("GAME_RESULT",data)
    if data.processed then A.AC_Settings:ClearPending(g.runId) end
    if self.activeGame~=g then return end
    sound((g.result=="WIN" and g.lastShot or g.lastAiShot).result)
    sound(g.result)
    A.Engine:Emit("AC_SHOT_FIRED",g:GetBoardState())
    if self.activeGame==g then A.Engine:Emit("AC_GAME_OVER",A.AC_Logic:Copy(data)) end
end
function E:SaveAndPause()
    self:_FreezeAnswer(); self:_SaveProgress()
    local sid=self._sessionId
    self._sessionId=nil; self.activeGame=nil; self.activeConfig=nil; self.state="IDLE"
    if sid then A.Lifecycle:PauseGame(ID,sid); A.Lifecycle:EndGame(ID,sid) end
end
function E:StopGame()
    self:SaveAndPause()
    A.Engine:Emit("AC_GAME_STOPPED")
end
