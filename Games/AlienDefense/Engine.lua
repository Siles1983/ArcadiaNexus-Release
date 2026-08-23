-- ============================================================
--  AlienDefense – Engine.lua
--  Spielfluss, State-Machine, OnUpdate-Loop, Pause/Resume.
--
--  State-Machine: IDLE → PLAYING → PAUSED → PLAYING
--                                         ↘ GAMEOVER
--
--  Regeln:
--  - GameLoop (Core/GameLoop) für OnUpdate-Loop
--  - OnHide → SaveAndPause (kein Spiel läuft im Hintergrund)
--  - GAME_RESULT-Event bei Win/Loss (uppercase)
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
--  - PlaySound: direkte Integer-IDs (kein SOUNDKIT-nil-Risiko)
-- ============================================================

ArcadiaNexus.AD_Engine = {}
local E = ArcadiaNexus.AD_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AD_LoopFrame")

-- ── Sound-IDs (direkte Integer, kein SOUNDKIT) ────────────────
local SND_SHOOT      = 774   -- IG_MAINMENU_OPTION_CHECKBOX_ON
local SND_ALIENDEATH = 8959  -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_PLAYERHIT  = 847   -- INTERFACE_SOUND_LOST_TARGET_UNIT
local SND_WEAPONDROP = 1115  -- UI_GARRISON_MISSION_COMPLETE
local SND_WIN        = 8959  -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_LOSE       = 847   -- IG_QUEST_ABANDON

local function PlayADSound(Settings, key, soundId)
    if Settings and Settings:Get(key) then
        PlaySound(soundId, "Master")
    end
end

-- ── Loop-Frame ────────────────────────────────────────────────
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

function E:_StopLoop()
    _gameLoop:Stop()
end

-- ── Tick ──────────────────────────────────────────────────────
function E:_Tick(dt)
    local Logic    = ArcadiaNexus.AD_Logic
    local Renderer = ArcadiaNexus.AD_Renderer
    local Settings = ArcadiaNexus.AD_Settings
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    local actions = Logic:Tick(gs, dt)

    -- flags (wie BlockBreaker — Renderer läuft immer durch)
    local doGameOver  = false
    local doWaveWin   = false

    for _, act in ipairs(actions) do
        if act.type == "player_shoot" then
            PlayADSound(Settings, "soundOnShoot", SND_SHOOT)
            if act.laserFlash and Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(0.2, 0.9, 0.9, 0.08)
            end

        elseif act.type == "alien_killed" then
            PlayADSound(Settings, "soundOnAlienDeath", SND_ALIENDEATH)
            Renderer:OnAlienKilled(act.alien, gs)

        elseif act.type == "player_hit" then
            PlayADSound(Settings, "soundOnPlayerHit", SND_PLAYERHIT)
            if Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(1, 0.1, 0.1)
            end
            Renderer:UpdateHUD(gs)

        elseif act.type == "alien_shoot" then
            -- kein separater Sound (Alien-Schuss ist visuell)

        elseif act.type == "drop_spawned" then
            Renderer:OnDropSpawned(act.wtype, act.x, act.y, gs)

        elseif act.type == "weapon_collected" then
            PlayADSound(Settings, "soundOnWeaponDrop", SND_WEAPONDROP)
            Renderer:OnWeaponCollected(act.wtype, gs)

        elseif act.type == "weapon_expired" then
            Renderer:UpdateHUD(gs)

        elseif act.type == "perfect_wave_bonus" then
            -- Renderer zeigt Bonus im Overlay

        elseif act.type == "formation_step" then
            -- Renderer liest Positionen aus State — kein expliziter Aufruf nötig

        elseif act.type == "formation_descent" then
            -- optional: kurzer visueller Hinweis

        elseif act.type == "wave_cleared" then
            doWaveWin = true

        elseif act.type == "game_over" then
            doGameOver = true
        end
    end

    -- Renderer immer aktualisieren (letzter Alien-Frame verschwindet korrekt)
    Renderer:UpdatePhysics(gs)
    Renderer:UpdateHUD(gs)

    if doGameOver then
        self:_HandleGameOver()
    elseif doWaveWin then
        self:_HandleWaveWin()
    end
end

-- ── Fortschritt (Resume startet immer bei der nächsten zu spielenden Welle) ─
local function SaveResumeProgress(gs)
    local Settings = ArcadiaNexus.AD_Settings
    if not gs or not Settings then return end
    if (gs.lives or 0) <= 0 then
        Settings:ClearProgress()
        return
    end
    local wave = gs.wave or 1
    if gs.waveWon then wave = wave + 1 end
    Settings:SaveProgress(wave, gs.score, gs.lives, gs.difficulty)
end

-- ── StartGame ──────────────────────────────────────────────────
function E:StartGame(difficulty, resumeSaved)
    local Logic    = ArcadiaNexus.AD_Logic
    local Renderer = ArcadiaNexus.AD_Renderer
    local Settings = ArcadiaNexus.AD_Settings
    if not Logic or not Renderer then return end

    local config = difficulty
    if type(difficulty) ~= "table" then
        config = {
            slot       = Settings and Settings:GetActiveSlot() or 1,
            mode       = resumeSaved and "continue" or "new",
            difficulty = difficulty,
        }
    end
    local slot = config.slot or (Settings and Settings:GetActiveSlot()) or 1
    if Settings and (slot < 1 or slot > Settings.MAX_SLOTS) then return end
    local mode = config.mode or "continue"
    if Settings then Settings:SetActiveSlot(slot) end
    self.activeSlot = slot

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ALIENDEFENSE", E._sessionId)

    self:_StopLoop()

    local diff = config.difficulty or (Settings and Settings:Get("difficulty")) or "easy"
    local startEndless = Settings and Settings:Get("endlessMode") or false

    local savedProgress = nil
    if mode == "continue" and Settings then
        savedProgress = Settings:LoadProgress(slot)
        if savedProgress then diff = savedProgress.diff or diff end
    elseif mode == "new" and Settings then
        Settings:ResetSlot(slot)
    end

    local gs = Logic:NewState(diff, savedProgress, startEndless)
    local SM = ArcadiaNexus.ScoreManager
    if SM then gs.highScore = SM:GetBestScore("ALIENDEFENSE", diff) end
    Logic:ParseWave(gs)

    self.gameState = gs
    E.state = "PLAYING"

    Renderer:OnGameStarted(gs)
    self:_StartLoop()
end

-- ── StopGame ──────────────────────────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ALIENDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AD_Settings
    if gs and Settings then
        if (gs.lives or 0) > 0 then
            -- Manuell beendet: nächste Welle speichern, wenn die aktuelle schon geschafft ist
            SaveResumeProgress(gs)
        else
            -- Game Over: kein gültiger Fortschritt → Speicherstand löschen
            Settings:ClearProgress()
        end
    end
    E.state = "IDLE"
    self.gameState = nil
    local R = ArcadiaNexus.AD_Renderer
    if R then R:EnterIdleState() end
end

-- ── Pause / Resume ────────────────────────────────────────────
function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    if self.gameState then
        self.gameState.keyLeft  = false
        self.gameState.keyRight = false
        self.gameState.keyFire  = false
    end
    local R = ArcadiaNexus.AD_Renderer
    if R then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    local R = ArcadiaNexus.AD_Renderer
    if R and ArcadiaNexus.UI.IsResultDialogVisible(R._fieldFrame) then return end
    E.state = "PLAYING"
    local R = ArcadiaNexus.AD_Renderer
    if R then R:HidePause() end
    self:_StartLoop()
end

function E:TogglePause()
    local R = ArcadiaNexus.AD_Renderer
    if R and ArcadiaNexus.UI.IsResultDialogVisible(R._fieldFrame) then return end
    if E.state == "PLAYING" then self:Pause()
    elseif E.state == "PAUSED" then self:Resume() end
end

-- ── SaveAndPause (OnHide-Handler) ─────────────────────────────
function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("ALIENDEFENSE", E._sessionId)
    end
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AD_Settings
    if gs and Settings then
        SaveResumeProgress(gs)
    end
    self:_StopLoop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ALIENDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    self.gameState = nil
end

-- ── Welle gewonnen ────────────────────────────────────────────
function E:_HandleWaveWin()
    self:_StopLoop()
    E.state = "PAUSED"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AD_Settings
    local Renderer = ArcadiaNexus.AD_Renderer
    if not gs then return end

    if gs.score > (gs.highScore or 0) then gs.highScore = gs.score end
    gs.waveWon = true

    if Settings then
        if Settings:Get("soundOnWin") then
            PlaySound(SND_WIN, "Master")
        end
        -- Resume soll die nächste Welle starten, nicht die gerade geschaffte
        SaveResumeProgress(gs)
    end

    -- Score an Bestenliste weitergeben
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "ALIENDEFENSE",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "WIN",
        stats      = {
            levelReached  = gs.wave or 1,
            waveReached   = gs.wave or 1,
            enemiesKilled = gs.totalKillsAllWaves or 0,
        },
    })

    if Renderer then Renderer:ShowWaveWin(gs) end
end

-- ── Nächste Welle (aufgerufen vom Renderer-Button) ────────────
function E:ContinueToNextWave()
    local Logic    = ArcadiaNexus.AD_Logic
    local Renderer = ArcadiaNexus.AD_Renderer
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    Logic:AdvanceWave(gs)
    gs.waveWon = false
    E.state = "PLAYING"
    Renderer:OnWaveAdvanced(gs)
    self:_StartLoop()
end

-- ── Game Over ──────────────────────────────────────────────────
function E:_HandleGameOver()
    self:_StopLoop()
    E.state = "GAMEOVER"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AD_Settings
    local Renderer = ArcadiaNexus.AD_Renderer
    if not gs then return end

    if gs.score > (gs.highScore or 0) then gs.highScore = gs.score end

    if Settings then
        if Settings:Get("soundOnLose") then
            PlaySound(SND_LOSE, "Master")
        end
        Settings:ClearProgress()
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "ALIENDEFENSE",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "LOSS",
        stats      = {
            levelReached  = gs.wave or 1,
            waveReached   = gs.wave or 1,
            enemiesKilled = gs.totalKillsAllWaves or 0,
        },
    })

    if Renderer then Renderer:ShowGameOver(gs) end
end

-- ── Waffe wechseln (Keyboard W/S) ─────────────────────────────
function E:CycleWeaponUp()
    local Logic = ArcadiaNexus.AD_Logic
    local gs    = self.gameState
    if Logic and gs then Logic:CycleWeapon(gs, 1) end
    local R = ArcadiaNexus.AD_Renderer
    if R and gs then R:UpdateHUD(gs) end
end

function E:CycleWeaponDown()
    local Logic = ArcadiaNexus.AD_Logic
    local gs    = self.gameState
    if Logic and gs then Logic:CycleWeapon(gs, -1) end
    local R = ArcadiaNexus.AD_Renderer
    if R and gs then R:UpdateHUD(gs) end
end
