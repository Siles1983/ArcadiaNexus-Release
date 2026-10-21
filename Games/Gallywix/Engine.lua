-- Solo match ownership and timelines. Debug calibration is kept separately.
local A = _G.ArcadiaNexus
A.GWX_Engine = { state = "IDLE", rotationDegrees = 0 }
local E = A.GWX_Engine
local GAME_ID = "GALLYWIX"
local loop = A.GameLoop.Create("ArcadiaNexus_GWX_Loop")
local SPIN_SECONDS = 4.5
E.GALLYWIX_TIMING = {pause=0.65,laugh=4,entrance=0.5,spin=3.5,exit=1.5}

-- UI failures never own the clock or the next legal transition.
function E:_Present(method,...)
    local R=A.GWX_Renderer
    if not R or type(R[method])~="function" then return nil end
    local ok,value=pcall(R[method],R,...)
    if not ok then self._presentationError=tostring(value); return nil end
    return value
end
function E:_Schedule(kind,seconds)
    self._pending={kind=kind,remaining=seconds}
    self:_Wake()
end
function E:_Continue(kind)
    local s=self.gameState
    if not s or self.state~="PLAYING" then return end
    if kind=="reveal" then A.GWX_GameLogic:FinishReveal(s); self:_Changed()
    elseif kind=="ai" then self:_AIAction()
    elseif kind=="finish" then self:FinishGame()
    elseif kind=="landed" then self:_StartWheelMotion("dock","apply")
    elseif kind=="apply" then self:_ApplyFinalSpin(self.lastIndex)
    elseif kind=="intervention_pause" then
        self:_Schedule("laugh",self.GALLYWIX_TIMING.pause); self:_Changed()
    elseif kind=="laugh" then
        self:_Schedule("entrance",self.GALLYWIX_TIMING.laugh)
        self._laughHandle=self:_Present("PlayGallywixLaugh",self._intervention.forced)
    elseif kind=="entrance" then
        self:_Schedule("intervention_spin",self.GALLYWIX_TIMING.entrance)
        self:_Present("SetGallywixVisible",true); self:_Changed()
    elseif kind=="intervention_spin" then
        local index=self._intervention.target
        self._spin={index=index,elapsed=0,duration=self.GALLYWIX_TIMING.spin,
            startDegrees=self.rotationDegrees,distance=A.GWX_Logic:GetSpinDistance(self.rotationDegrees,index,2),
            targetDegrees=A.GWX_Logic:GetTargetDegrees(index),intervention=true}
        self:_Wake(); self:_Present("SetGallywixDancing",true)
    end
end
function E:_ApplyFinalSpin(index)
    self.lastIndex=index
    local intervention=self._intervention
    self._intervention=nil
    self:_Present("SetGallywixVisible",false)
    A.GWX_GameLogic:ApplySpin(self.gameState,index,intervention)
    self:_Changed()
end
function E:_BeginIntervention(index,forced,original)
    self._intervention={target=index,forced=forced,original=original}
    self:_StartWheelMotion("dock","intervention_pause")
end

function E:StartDemoSpin(selection)
    if self.gameState then return false end
    if self._spin then return false end
    local index = A.GWX_Logic:SelectIndex(selection or "random")
    if not index then return false end
    if self.state == "IDLE" then
        local previous = self._sessionId
        self._sessionId = A.Lifecycle:BeginGame(GAME_ID)
        if not self._sessionId then self._sessionId = previous; return false end
        self.state = "PLAYING"
    elseif not A.GameSession:IsSession(self, self._sessionId) then
        return false
    end
    self._spin = {
        index = index, elapsed = 0, duration = SPIN_SECONDS,
        startDegrees = self.rotationDegrees,
        distance = A.GWX_Logic:GetSpinDistance(self.rotationDegrees, index, 5),
        targetDegrees = A.GWX_Logic:GetTargetDegrees(index),
    }
    A.GWX_Renderer:OnSpinStarted(index)
    local sid = self._sessionId
    loop:Start(function(dt) self:_Tick(dt) end, {
        stateCheck = function()
            return E.state == "PLAYING" and E._spin ~= nil and A.GameSession:IsSession(E, sid)
        end,
    })
    return true
end

function E:_TickSpin(dt)
    local spin = self._spin
    if not spin then return end
    if spin.elapsed==0 then A.GWX_Sounds:StartWheel() end
    spin.elapsed = math.min(spin.duration, spin.elapsed + dt)
    local progress = spin.elapsed / spin.duration
    self.rotationDegrees = (spin.startDegrees + spin.distance * A.GWX_Logic:Ease(progress)) % 360
    if progress >= 1 then self.rotationDegrees = spin.targetDegrees end
    self:_Present("SetRotation",self.rotationDegrees)
    if progress >= 1 then
        A.GWX_Sounds:StopWheel(true)
        loop:Stop()
        self._spin = nil
        self.lastIndex = spin.index
        if self.gameState then
            if spin.intervention then
                self:_Present("SetGallywixDancing",false)
                self:_Schedule("apply",self.GALLYWIX_TIMING.exit)
            elseif spin.interventionTarget then self:_BeginIntervention(spin.interventionTarget,spin.forcedIntervention,spin.index)
            else
                self:_Schedule("landed",0.65)
            end
        else self:_Present("OnSpinFinished",spin.index,self.rotationDegrees) end
    end
end

function E:StopGame()
    if self:SaveSnapshot()==false then return false end
    loop:Stop()
    A.GWX_Sounds:Reset()
    self._spin = nil
    self._pending = nil
    self._wheelMotion = nil
    self._intervention=nil
    if self._laughHandle and StopSound then StopSound(self._laughHandle) end
    self._laughHandle=nil
    self.gameState = nil
    self._slot,self._runId,self._terminalData=nil,nil,nil
    if self._sessionId then
        A.Lifecycle:EndGame(GAME_ID, self._sessionId)
        self._sessionId = nil
    end
    self.state = "IDLE"
    self.rotationDegrees = 0
    self.lastIndex = nil
    self:_Present("EnterIdleState")
end

function E:_Wake()
    local sid = self._sessionId
    loop:Start(function(dt) E:_Tick(dt) end, { stateCheck=function()
        return E.state == "PLAYING" and A.GameSession:IsSession(E, sid)
    end })
end
function E:_StartWheelMotion(mode,kind)
    self._wheelMotion={mode=mode,elapsed=0,duration=mode=="expand" and 0.4 or 0.65,kind=kind}
    self:_Wake()
    self:_Present("BeginWheelMotion",mode)
end
function E:_Tick(dt)
    if self._wheelMotion then
        local motion=self._wheelMotion
        motion.elapsed=math.min(motion.duration,motion.elapsed+dt)
        self:_Present("AnimateWheel",motion.elapsed/motion.duration)
        if motion.elapsed>=motion.duration then
            self._wheelMotion=nil
            if motion.kind then self:_Continue(motion.kind) end
        end
    elseif self._spin then self:_TickSpin(dt)
    elseif self._pending then
        local pending = self._pending
        self:_Present("AnimateWall",dt)
        pending.remaining = pending.remaining-dt
        if pending.remaining <= 0 then
            self._pending = nil
            self:_Continue(pending.kind)
        end
    end
    if not self._wheelMotion and not self._spin and not self._pending then loop:Stop() end
end
function E:StartGame(config)
    config=config or {}
    local slot=config.slot or 1
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    local saved=config.resume and A.GWX_Settings:LoadSlot(slot)
    if config.resume and not self:CanContinue(saved) then return false end
    local R=A.GWX_Renderer
    local category=config.category or R.category or "all"
    local locale=config.locale or (A.ActiveLocale=="deDE" and "deDE" or "enUS")
    if locale~="deDE" and locale~="enUS" or config.gallywixEnabled~=nil and type(config.gallywixEnabled)~="boolean" then return false end
    if self._sessionId and A.GameSession:ResumeSaveBlocked(self._sessionId) then return false end
    if A.GameRegistry and A.GameRegistry.HasPendingCleanup and A.GameRegistry.HasPendingCleanup() then return false end
    local state=saved and A.GWX_GameLogic.Copy(saved.game) or A.GWX_GameLogic:NewGame(A.GWX_Words:NewDeck(category,locale))
    if not state then return false end
    local enabled=config.gallywixEnabled
    if enabled==nil then enabled=A.GWX_Settings:Get("gallywixEnabled")==true end
    if self:StopGame()==false then return false end
    local previous=self._sessionId
    self._sessionId=A.Lifecycle:BeginGame(GAME_ID)
    if not self._sessionId then self._sessionId=previous; return false end
    self.state,self.gameState,self._resultEmitted="PLAYING",state,false
    self._slot=slot
    if saved then
        self._runId=saved.runId; self.rotationDegrees=saved.rotation
        self._terminalData=A.GWX_GameLogic.Copy(saved.terminal)
        self._spin=A.GWX_GameLogic.Copy(saved.spin); self._pending=A.GWX_GameLogic.Copy(saved.pending)
        self._wheelMotion=A.GWX_GameLogic.Copy(saved.motion); self._intervention=A.GWX_GameLogic.Copy(saved.intervention)
        self.lastIndex=saved.lastIndex
        R.category=state.category
        if saved.finished then return self:FinishGame() end
        self:_RestorePresentation()
        self._restoring=true
        self:_Present("RenderGame",state)
        self._restoring=nil
        if self._spin or self._pending or self._wheelMotion then self:_Wake() else self:_Changed() end
    else
        state.locale,state.category=locale,category
        state.gallywixEnabled=enabled; state.difficulty=enabled and "gallywix" or "default"
        R.category=state.category
        self._runId=A.LocalResults and A.LocalResults:NewRun(GAME_ID) or nil
        self:_Changed()
    end
    self:SaveSnapshot()
    return true
end
function E:_Changed()
    local s, L = self.gameState, A.GWX_GameLogic
    if not s then return end
    if s.phase == "REVEAL" then
        self:_Schedule("reveal",0.7+#(s.event.positions or {})*0.1)
    elseif s.phase == "ROUND_END" and s.round == L.ROUND_COUNT then
        self:_Schedule("finish",1.5)
    elseif s.active ~= 1 and (s.phase == "CHOICE" or s.phase == "LETTER" or s.phase == "VOWEL") then
        self:_Schedule("ai",1)
    end
    self:SaveSnapshot()
    self:_Present("RenderGame",s)
end
function E:Spin(selection, ai)
    local s = self.gameState
    if self.state ~= "PLAYING" or not s or s.phase ~= "CHOICE" or (s.active ~= 1 and not ai) then return false end
    if selection and selection ~= "random" then
        if ai or not (A.IsDevMode and A.IsDevMode() and A.GWX_Renderer._diagnosticEnabled) then return false end
    end
    local index = A.GWX_Logic:SelectIndex(selection or "random")
    if not index then return false end
    if selection and selection ~= "random" then s.unranked = true end
    local ok,mode,target=pcall(A.GWX_Renderer.GetInterventionPreview,A.GWX_Renderer)
    if not ok then mode,target="auto","random" end
    if mode~="auto" and (mode=="force" or s.gallywixEnabled) then s.unranked=true end
    local interventionTarget=A.GWX_Logic:SelectIntervention(s.gallywixEnabled,mode,target,index)
    self._pending = nil
    s.phase = "SPINNING"
    self._spin = { index=index, elapsed=0, duration=SPIN_SECONDS, startDegrees=self.rotationDegrees,
        distance=A.GWX_Logic:GetSpinDistance(self.rotationDegrees,index,5), targetDegrees=A.GWX_Logic:GetTargetDegrees(index),
        interventionTarget=interventionTarget,forcedIntervention=mode=="force" }
    self:_StartWheelMotion("expand")
    self:_Changed()
    self:_Wake()
    return true
end
function E:BuyVowel(ai)
    local s = self.gameState
    if self.state ~= "PLAYING" or not s or (s.active ~= 1 and not ai) then return false end
    if not A.GWX_GameLogic:BuyVowel(s) then return false end
    self._pending = nil
    self:_Changed()
    return true
end
function E:GuessLetter(letter, ai)
    local s = self.gameState
    if self.state ~= "PLAYING" or not s or (s.active ~= 1 and not ai) then return false end
    if not A.GWX_GameLogic:Guess(s,letter) then return false end
    self._pending = nil
    self:_Changed()
    return true
end
function E:Solve(answer, ai)
    local s = self.gameState
    if self.state ~= "PLAYING" or not s or (s.active ~= 1 and not ai) then return false end
    if not A.GWX_GameLogic:Solve(s,answer) then return false end
    self._pending = nil
    self:_Changed()
    return true
end
function E:NextRound()
    local s = self.gameState
    if self.state ~= "PLAYING" or not s or s.phase ~= "ROUND_END" then return false end
    if not A.GWX_GameLogic:NextRound(s) then self:FinishGame() else self:_Changed() end
    return true
end
function E:_AIAction()
    local s = self.gameState
    if not s or s.active == 1 then return end
    local action, value = A.GWX_GameLogic:ChooseAI(s,s.locale or A.ActiveLocale)
    if action == "spin" then self:Spin(nil,true)
    elseif action == "vowel" then
        if not self:BuyVowel(true) then A.GWX_GameLogic:LoseTurn(s,"pass"); self:_Changed() end
    elseif action == "letter" then self:GuessLetter(value,true)
    elseif action == "solve" then self:Solve(value,true)
    elseif action == "pass" then A.GWX_GameLogic:LoseTurn(s,"pass"); self:_Changed() end
end
function E:FinishGame()
    local s=self.gameState
    if not s or self._resultEmitted or s.round~=A.GWX_GameLogic.ROUND_COUNT or s.phase~="ROUND_END" then return false end
    loop:Stop(); self._pending,self._spin,self._wheelMotion=nil,nil,nil
    self.state="FINISHED"
    -- Session bleibt bis SaveAndPause/StopGame, damit der Ergebnisdialog beim Verlassen schließt.
    local result=A.GWX_GameLogic:Result(s)
    if not self._terminalData then
        local games=A.ScoreManager and A.ScoreManager:GetAllGames() or {}
        local old=games[GAME_ID] and games[GAME_ID][s.difficulty]
        self._terminalData={gameId=GAME_ID,runId=self._runId,ruleVersion=1,difficulty=s.difficulty,
            score=s.players[1].total,result=result,stats=A.GWX_GameLogic:AchievementResult(s,old and old.customStats),
            category=s.category,locale=s.locale}
    end
    self:SaveSnapshot()
    local data=self._terminalData
    data.processingFailed=nil
    if not s.unranked then
        if A.GameResultProcessor and self._runId then
            A.Engine:Emit("GAME_RESULT",data)
            if not data.processed then return false end
        else A.Engine:Emit("GAME_RESULT",data) end
    else data.awardedXP,data.newHighscore=0,false end
    self._resultEmitted=true
    self:SaveSnapshot()
    self:_Present("ShowResult",s,result,data)
    return true
end
function E:SaveSnapshot()
    if not self._slot or not self.gameState then return end
    return A.GWX_Settings:SaveSlot(self._slot,{version=1,timestamp=GetServerTime and GetServerTime() or nil,runId=self._runId,game=A.GWX_GameLogic.Copy(self.gameState),
        rotation=self.rotationDegrees,lastIndex=self.lastIndex,spin=A.GWX_GameLogic.Copy(self._spin),
        pending=A.GWX_GameLogic.Copy(self._pending),motion=A.GWX_GameLogic.Copy(self._wheelMotion),
        intervention=A.GWX_GameLogic.Copy(self._intervention),finished=self.state=="FINISHED",
        emitted=self._resultEmitted==true,terminal=A.GWX_GameLogic.Copy(self._terminalData)})
end
function E:CanContinue(save)
    return A.GWX_GameLogic:ValidateSave(save) and not save.emitted
        and not (A.LocalResults and A.LocalResults:GetReceipt(save.runId))
end
function E:SaveAndPause()
    if self.mode and self.mode~="hotseat" then return false end
    if self.state=="PLAYING" or self.state=="FINISHED" then
        if self:SaveSnapshot()==false then return false end
        if self.state=="PLAYING" and self._sessionId then A.Lifecycle:PauseGame(GAME_ID,self._sessionId) end
        if self:StopGame()==false then return false end
        return true
    end
    return false
end
function E:_RestorePresentation()
    if self._spin and not self._wheelMotion and self._spin.elapsed>0 then A.GWX_Sounds:StartWheel() end
    local motion,spin,pending=self._wheelMotion,self._spin,self._pending
    local kind=pending and pending.kind
    local large=(motion and motion.mode=="expand") or (spin and not spin.intervention) or kind=="landed"
    self:_Present("BeginWheelMotion",large and "expand" or "dock"); self:_Present("AnimateWheel",1)
    if motion then
        -- Recreate the same transition from its canonical starting pose.
        self:_Present("BeginWheelMotion",motion.mode=="expand" and "dock" or "expand"); self:_Present("AnimateWheel",1)
        self:_Present("BeginWheelMotion",motion.mode); self:_Present("AnimateWheel",motion.elapsed/motion.duration)
    end
    self:_Present("SetGallywixVisible",kind=="intervention_spin" or kind=="apply" and self._intervention~=nil or spin and spin.intervention or false)
    self:_Present("SetGallywixDancing",spin and spin.intervention or false)
    self:_Present("SetRotation",self.rotationDegrees)
end
