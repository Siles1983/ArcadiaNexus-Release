-- ============================================================
--  Darkmoon Pinball – Engine.lua
--  Session, GameLoop, Sounds, GAME_RESULT. Kein UI.
--  Custom-WAVs: bumper, flipper, plunger_pull, targets, tilt.
-- ============================================================

ArcadiaNexus.DMP_Engine = {}
local E = ArcadiaNexus.DMP_Engine

E._sessionId = nil
E.state = "IDLE"
E.gameState = nil

local GAME_ID = "DARKMOON_PINBALL"

local function SelectedTable()
    local S = ArcadiaNexus.DMP_Settings
    local id = S and S:Get("tableId")
    local Logic = ArcadiaNexus.DMP_Logic
    if Logic and Logic.GetTable and Logic:GetTable(id) then
        return Logic:GetTable(id).id
    end
    return "darkmoon_midway"
end

local function GetHighScore(tableId)
    local SM = ArcadiaNexus.ScoreManager
    if SM then return SM:GetBestScore(GAME_ID, tableId or SelectedTable()) end
    return 0
end

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_DMP_LoopFrame")
local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

-- Custom-WAVs via PlaySoundFile; übrige Events bleiben SOUNDKIT-IDs.
local SND_ROOT = "Interface\\AddOns\\ArcadiaNexus\\Games\\DarkmoonPinball\\assets\\sound\\"
local FILE_BUMPER  = SND_ROOT .. "bumper.wav"
local FILE_FLIPPER = SND_ROOT .. "flipper.wav"
local FILE_PLUNGER = SND_ROOT .. "plunger_pull.wav"
local FILE_TARGET  = SND_ROOT .. "targets.wav"
local FILE_TILT    = SND_ROOT .. "tilt.wav"

local SND_DRAIN   = 847
local SND_LAUNCH  = 8959
local SND_KICK    = 8959
local SND_LOSE    = 847
local SND_SLING   = 1110
local SND_MISSION = 888
local SND_JACKPOT = 8959
local SND_MB      = 8960
local SND_WARN    = 847

local _lastPlay = {}

local function Now()
    if GetTime then return GetTime() end
    return 0
end

local function SoundOn(Settings, key)
    return Settings and Settings:Get("soundEnabled") and Settings:Get(key)
end

local function PlayId(Settings, key, soundId)
    if SoundOn(Settings, key) then
        PlaySound(soundId, "Master")
    end
end

local function PlayFile(Settings, key, path, gap, stamp)
    if not SoundOn(Settings, key) or not path then return end
    stamp = stamp or key
    local t = Now()
    local last = _lastPlay[stamp]
    if last and (t - last) < (gap or 0.12) then return end
    _lastPlay[stamp] = t
    PlaySoundFile(path, "Master")
end

local function PresentAction(act, gs, Settings, Renderer)
    local t = act.type
    if t == "bumper_hit" then
        PlayFile(Settings, "soundOnBumper", FILE_BUMPER, 0.08)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "flipper_hit" then
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "sling_hit" then
        PlayId(Settings, "soundOnSling", SND_SLING)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "target_hit" then
        PlayFile(Settings, "soundOnTarget", FILE_TARGET, 0.10)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "drain" then
        PlayId(Settings, "soundOnDrain", SND_DRAIN)
        if Settings and Settings:Get("screenFlash") and Renderer and Renderer.FlashScreen then
            Renderer:FlashScreen(0.8, 0.15, 0.15)
        end
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "ball_save" or t == "shield_save" then
        PlayId(Settings, "soundOnSave", SND_LAUNCH)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "kickback" or t == "outlane_save" then
        PlayId(Settings, "soundOnKickback", SND_KICK)
        if Settings and Settings:Get("screenFlash") and Renderer and Renderer.FlashScreen then
            Renderer:FlashScreen(0.25, 0.85, 0.4)
        end
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "kickback_armed" or t == "outlane_save_armed" then
        PlayId(Settings, "soundOnLaunch", SND_LAUNCH)
    elseif t == "mission_start" or t == "mission_complete" then
        PlayId(Settings, "soundOnMission", SND_MISSION)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "multiball_start" then
        PlayId(Settings, "soundOnMultiball", SND_MB)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "jackpot" or t == "super_jackpot" then
        PlayId(Settings, "soundOnJackpot", SND_JACKPOT)
        if Settings and Settings:Get("screenFlash") and Renderer and Renderer.FlashScreen then
            Renderer:FlashScreen(1, 0.82, 0.25)
        end
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "powerup" then
        PlayId(Settings, "soundOnMission", SND_MISSION)
        if Renderer and Renderer.OnFx then Renderer:OnFx(act, gs) end
    elseif t == "game_over" then
        -- handled after loop
    end
end

function E:_StartLoop()
    _gameLoop:Start(function(dt)
        E:_Tick(dt)
    end, {
        stateCheck = function()
            return E.state == "PLAYING"
        end,
    })
end

function E:_StopLoop()
    _timerGuard:Cancel()
    _gameLoop:Stop()
end

local function Call(method,...)
    local R=ArcadiaNexus.DMP_Renderer; if R and R[method] then R[method](R,...) end
end
function E:_Neutralize()
    self._blocked=self._blocked or {}
    for token in pairs(self._held or {}) do self._blocked[token]=true end
    ArcadiaNexus.DMP_Logic:Neutralize(self.gameState)
end
function E:_CheckDev(gs)
    if gs and (self._devActionSink or not ArcadiaNexus.DMP_TableRegistry.IsPublished(gs.def)) then gs.devRun=true end
end
function E:_Tick(dt)
    local gs=self.gameState
    if self.state~="PLAYING" or not gs then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_Neutralize() end
    self:_CheckDev(gs)
    local actions=ArcadiaNexus.DMP_Logic:Tick(gs,dt)
    -- Fix/book terminal state before sounds, FX, editor callbacks or view updates.
    if gs.gameOver then self:_HandleGameOver() end
    if self.gameState~=gs then return end
    if gs.justLaunched then gs.justLaunched=false; PlayId(ArcadiaNexus.DMP_Settings,"soundOnLaunch",SND_LAUNCH) end
    for _,act in ipairs(actions) do
        if act.type~="game_over" then
            PresentAction(act,gs,ArcadiaNexus.DMP_Settings,ArcadiaNexus.DMP_Renderer)
            if self.gameState~=gs then return end
            if self._devActionSink then self._devActionSink(act,gs) end
            if self.gameState~=gs then return end
        end
    end
    Call("UpdateView",gs,math.max(0,math.min(dt or 0,.1)))
end
function E:HandleKey(msg,token)
    local release=({LEFT_UP="LEFT_DOWN",RIGHT_UP="RIGHT_DOWN",LAUNCH_UP="LAUNCH"})[msg]
    local command=release or msg; token=token or command
    self._held,self._blocked=self._held or {},self._blocked or {}
    if release or msg=="RELEASE" then
        local held=self._held[token]; local wasBlocked=self._blocked[token]
        self._held[token],self._blocked[token]=nil,nil
        local gs=self.gameState
        if not gs then return end
        if held=="LAUNCH" and not wasBlocked and self.state=="PLAYING" and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
            self:_ApplyKey("LAUNCH_UP")
        elseif held=="LAUNCH" then gs.plungerHeld=false; gs.plungerAuto=false end
        -- Aliases/devices have independent ownership of a held flipper.
        if held=="LEFT_DOWN" or held=="RIGHT_DOWN" then
            local down=false
            for t,c in pairs(self._held) do if c==held and not self._blocked[t] then down=true end end
            ArcadiaNexus.DMP_Logic:SetFlipperInput(gs,held=="LEFT_DOWN" and "left" or "right",down and self.state=="PLAYING")
        end
        return
    end
    if self._held[token] then return end
    self._held[token]=command
    if self._blocked[token] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_Neutralize(); return end
    if msg=="EXIT" then self:StopGame(); return end
    if msg=="PAUSE" then self:_ApplyKey(msg); return end
    if self.state~="PLAYING" then self._blocked[token]=true; return end
    self:_ApplyKey(msg)
end
function E:HandlePadButton(btn,pressed)
    local command=({PADLEFT="LEFT_DOWN",PADLSHOULDER="LEFT_DOWN",PADLTRIGGER="LEFT_DOWN",
        PADRIGHT="RIGHT_DOWN",PADRSHOULDER="RIGHT_DOWN",PADRTRIGGER="RIGHT_DOWN",PAD1="LAUNCH",
        PADUP="NUDGE_UP",PADDOWN="NUDGE_LEFT",PAD3="NUDGE_RIGHT",PADFORWARD="PAUSE",PAD4="PAUSE"})[btn]
    if command then self:HandleKey(pressed and command or "RELEASE",btn) end
end
function E:HandlePadAxis(x)
    local left,right=x<-.35,x>.35
    if left then self:HandleKey("LEFT_DOWN","axisLeft") else self:HandleKey("RELEASE","axisLeft") end
    if right then self:HandleKey("RIGHT_DOWN","axisRight") else self:HandleKey("RELEASE","axisRight") end
end
function E:_ApplyKey(msg)
    local gs = self.gameState
    if msg == "LEFT_DOWN" then
        local Logic = ArcadiaNexus.DMP_Logic
        if Logic and gs then Logic:SetFlipperInput(gs, "left", true) end
        if E.state == "PLAYING" then
            PlayFile(ArcadiaNexus.DMP_Settings, "soundOnFlipper", FILE_FLIPPER, 0.04, "flipL")
        end
    elseif msg == "LEFT_UP" then
        local Logic = ArcadiaNexus.DMP_Logic
        if Logic and gs then Logic:SetFlipperInput(gs, "left", false) end
    elseif msg == "RIGHT_DOWN" then
        local Logic = ArcadiaNexus.DMP_Logic
        if Logic and gs then Logic:SetFlipperInput(gs, "right", true) end
        if E.state == "PLAYING" then
            PlayFile(ArcadiaNexus.DMP_Settings, "soundOnFlipper", FILE_FLIPPER, 0.04, "flipR")
        end
    elseif msg == "RIGHT_UP" then
        local Logic = ArcadiaNexus.DMP_Logic
        if Logic and gs then Logic:SetFlipperInput(gs, "right", false) end
    elseif msg == "LAUNCH" then
        if E.state == "PLAYING" then
            local Logic = ArcadiaNexus.DMP_Logic
            if Logic and gs then Logic:SetPlungerInput(gs, true) end
            if gs and gs.phase == "ready" then
                PlayFile(ArcadiaNexus.DMP_Settings, "soundOnPlunger", FILE_PLUNGER, 0.40)
            end
        end
    elseif msg == "LAUNCH_UP" then
        if E.state == "PLAYING" then
            local Logic = ArcadiaNexus.DMP_Logic
            if Logic and gs then Logic:SetPlungerInput(gs, false) end
            if gs and gs.justLaunched then
                gs.justLaunched = false
                PlayId(ArcadiaNexus.DMP_Settings, "soundOnLaunch", SND_LAUNCH)
            end
        end
    elseif msg == "NUDGE_LEFT" or msg == "NUDGE_RIGHT" or msg == "NUDGE_UP" then
        if E.state == "PLAYING" and gs then
            local Logic = ArcadiaNexus.DMP_Logic
            local dir = (msg == "NUDGE_LEFT" and "left") or (msg == "NUDGE_RIGHT" and "right") or "up"
            local wasTilted = gs.tilted
            local warn0 = gs.tiltWarn or 0
            if Logic then Logic:QueueNudge(gs, dir) end
            if gs.tilted and not wasTilted then
                PlayFile(ArcadiaNexus.DMP_Settings, "soundOnTilt", FILE_TILT, 0.20)
                local Renderer = ArcadiaNexus.DMP_Renderer
                if Renderer and Renderer.OnTilt then Renderer:OnTilt(gs) end
            elseif (gs.tiltWarn or 0) > warn0 then
                PlayId(ArcadiaNexus.DMP_Settings, "soundOnTilt", SND_WARN)
                local Renderer = ArcadiaNexus.DMP_Renderer
                local Settings = ArcadiaNexus.DMP_Settings
                if Settings and Settings:Get("screenFlash") and Renderer and Renderer.FlashScreen then
                    Renderer:FlashScreen(1, 0.45, 0.1)
                end
            end
        end
    elseif msg == "PAUSE" then
        if E.state == "PLAYING" then
            self:Pause()
        elseif E.state == "PAUSED" then
            self:Resume()
        end
    elseif msg == "DEBUG" then
        local S = ArcadiaNexus.DMP_Settings
        if S and ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() then S:Set("debugOverlay", not S:Get("debugOverlay")) end
    end
end


function E:_Save()
    local gs=self.gameState; self:_CheckDev(gs)
    if self.state=="PLAYING" or self.state=="PAUSED" then
        local snapshot=ArcadiaNexus.DMP_Logic:Snapshot(gs,self.state)
        if snapshot then ArcadiaNexus.DMP_Settings:SaveSlot(self.activeSlot,snapshot) end
    end
end
function E:RetryPending()
    local L,S=ArcadiaNexus.DMP_Logic,ArcadiaNexus.DMP_Settings
    for id,data in pairs(L:Copy(S:GetPending())) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end
function E:StartGame(config)
    config=type(config)=="table" and config or {}
    local L,S,TR=ArcadiaNexus.DMP_Logic,ArcadiaNexus.DMP_Settings,ArcadiaNexus.DMP_TableRegistry
    local slot=tonumber(config.slot or S:GetActiveSlot()); local mode=config.mode or "new"
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS or mode~="new" and mode~="continue" then return false end
    local tableId=config.tableId or S:Get("tableId")
    local gs,restorePhase
    if mode=="continue" then
        local saved=S:LoadSlot(slot); restorePhase=type(saved)=="table" and saved.engineState
        gs=L:Restore(S:LoadSlot(slot))
        if not gs or not ArcadiaNexus.LocalResults:GetSerial(GAME_ID,gs.runId) then Call("ShowInvalidSave"); return false end
    else
        if not TR._byId[tableId] then return false end
        gs=L:NewState(tableId)
    end
    self:RetryPending()
    if gs.runId and ArcadiaNexus.LocalResults:GetReceipt(gs.runId) then Call("ShowInvalidSave"); return false end
    self:_Save(); self:_StopLoop(); self:_Neutralize()
    local previous=self._sessionId
    self._sessionId=ArcadiaNexus.Lifecycle:RestartGame(GAME_ID,self._sessionId)
    if not self._sessionId then self._sessionId=previous; return false end
    self.activeSlot=slot; S:SetActiveSlot(slot)
    self.gameState=gs; self.state=restorePhase or "PLAYING"
    self:_CheckDev(gs)
    if not gs.devRun then gs.runId=gs.runId or ArcadiaNexus.LocalResults:NewRun(GAME_ID) end
    gs.highScore=GetHighScore(gs.tableId); _lastPlay={}
    self:_Save(); Call("OnGameStarted",gs)
    if self.gameState~=gs then return true end
    if self.state=="PAUSED" then ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause") else self:_StartLoop() end
    return true
end
function E:SaveAndPause()
    self:_Save(); self:_StopLoop(); self:_Neutralize()
    if self._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId)
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil
    end
    self.state="IDLE"; self.gameState=nil
end
function E:StopGame() self:SaveAndPause(); Call("EnterIdleState") end
function E:Pause()
    if self.state~="PLAYING" then return end
    self:_Neutralize(); self.state="PAUSED"; self:_StopLoop()
    ArcadiaNexus.Lifecycle:PauseGame(GAME_ID,self._sessionId); Call("ShowPause")
end
function E:Resume()
    if self.state~="PAUSED" then return end
    self:_Neutralize(); self.state="PLAYING"
    ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID,self._sessionId); Call("HidePause"); self:_StartLoop()
end
function E:_HandleGameOver()
    local gs=self.gameState; if not gs or gs.terminal then return end
    gs.gameOver,gs.terminal=true,true; gs.phase="over"
    self.state="GAMEOVER"; self:_StopLoop(); self:_Neutralize(); self:_CheckDev(gs)
    -- Session bleibt bis SaveAndPause/StopGame, damit der Ergebnisdialog beim Verlassen schließt.
    local L,S=ArcadiaNexus.DMP_Logic,ArcadiaNexus.DMP_Settings
    if not gs.devRun then
        S:DeleteSlot(self.activeSlot)
        local data={gameId=GAME_ID,difficulty=gs.tableId,ruleVersion=2,runId=gs.runId,score=gs.score,result="LOSS",stats={
            maxCombo=gs.maxCombo,bumperHits=gs.bumperHits,ballSaves=gs.saves,kickbacks=gs.kickbacks,tilts=gs.tilts,
            multiballs=gs.multiballs,jackpots=gs.jackpots,missionsDone=gs.missionsDone,
            distinctMissions=L:DistinctMissions(gs),extraBalls=gs.extraBalls,elapsed=math.floor(gs.elapsed+.5)}}
        S:SavePending(data); ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(gs.runId) end
        gs.resultData=data; gs.highScore=GetHighScore(gs.tableId)
    else gs.resultData={awardedXP=0,awardedGold=0,newHighscore=false} end
    if self.gameState~=gs then return end
    PlayId(S,"soundOnDrain",SND_LOSE); Call("ShowGameOver",gs)
end
