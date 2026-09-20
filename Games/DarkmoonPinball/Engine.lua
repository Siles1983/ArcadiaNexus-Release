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

function E:_Tick(dt)
    local Logic = ArcadiaNexus.DMP_Logic
    local Renderer = ArcadiaNexus.DMP_Renderer
    local Settings = ArcadiaNexus.DMP_Settings
    local gs = self.gameState
    if not Logic or not gs then return end

    local actions = Logic:Tick(gs, dt)
    if gs.justLaunched then
        gs.justLaunched = false
        PlayId(Settings, "soundOnLaunch", SND_LAUNCH)
    end
    local over
    for i = 1, #actions do
        local act = actions[i]
        if act.type == "game_over" then
            over = true
        else
            PresentAction(act, gs, Settings, Renderer)
        end
    end

    if Renderer and Renderer.UpdateView then
        Renderer:UpdateView(gs, dt)
    end
    if over then
        self:_HandleGameOver()
    end
end

function E:HandleKey(msg)
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
        if S then S:Set("debugOverlay", not S:Get("debugOverlay")) end
    end
end

function E:StartGame()
    local Logic = ArcadiaNexus.DMP_Logic
    local Renderer = ArcadiaNexus.DMP_Renderer
    if not Logic then return end

    local tableId = SelectedTable()
    local gs = Logic:NewState(tableId)
    if not gs then return end
    gs.highScore = GetHighScore(tableId)
    _lastPlay = {}

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
    self:_StopLoop()
    self.gameState = gs
    E.state = "PLAYING"
    if Renderer and Renderer.OnGameStarted then
        Renderer:OnGameStarted(gs)
    end
    self:_StartLoop()
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    E.state = "IDLE"
    self.gameState = nil
    local R = ArcadiaNexus.DMP_Renderer
    if R and R.EnterIdleState then
        R:EnterIdleState()
    end
end

function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    local gs = self.gameState
    if gs then
        local Logic = ArcadiaNexus.DMP_Logic
        if Logic then
            Logic:SetFlipperInput(gs, "left", false)
            Logic:SetFlipperInput(gs, "right", false)
        end
    end
    local R = ArcadiaNexus.DMP_Renderer
    if R and R.ShowPause then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    E.state = "PLAYING"
    local R = ArcadiaNexus.DMP_Renderer
    if R and R.HidePause then R:HidePause() end
    self:_StartLoop()
end

function E:_HandleGameOver()
    self:_StopLoop()
    E.state = "GAMEOVER"
    local gs = self.gameState
    local Settings = ArcadiaNexus.DMP_Settings
    local Renderer = ArcadiaNexus.DMP_Renderer
    if not gs then return end

    if gs.score > (gs.highScore or 0) then
        gs.highScore = gs.score
    end
    PlayId(Settings, "soundOnDrain", SND_LOSE)

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = GAME_ID,
        difficulty = gs.tableId or SelectedTable(),
        score      = gs.score,
        result     = "LOSS",
        stats      = {
            maxCombo    = gs.maxCombo or 0,
            bumperHits  = gs.bumperHits or 0,
            ballSaves    = gs.saves or 0,
            kickbacks    = gs.kickbacks or 0,
            tilts         = gs.tilts or 0,
            multiballs    = gs.multiballs or 0,
            jackpots      = gs.jackpots or 0,
            missionsDone  = gs.missionsDone or 0,
            extraBalls    = gs.extraBalls or 0,
            elapsed       = math.floor((gs.elapsed or 0) + 0.5),
        },
    })

    if Renderer and Renderer.ShowGameOver then
        Renderer:ShowGameOver(gs)
    end
end
