-- ============================================================
--  ArgusOrbitDefense – Engine.lua
--  Spielfluss, State-Machine, OnUpdate-Loop, Sound, Pause/Resume.
--
--  State-Machine: IDLE → PLAYING → PAUSED → PLAYING
--                                          ↘ GAMEOVER
--                                          ↘ WAVE_CLEAR  (Level-Modus)
--
--  Regeln:
--  - GameLoop (Core/GameLoop) für OnUpdate-Loop
--  - OnHide → SaveAndPause (kein Spiel läuft im Hintergrund)
--  - GAME_RESULT-Event bei Win/Loss (uppercase)
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AOD_Engine = {}
local E = ArcadiaNexus.AOD_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AOD_LoopFrame")

E._wasThrusting      = false
E._hunterWasThrusting = {}
E._engineTicker      = nil   -- Ticker für Engine-Sound-Loop

-- ── Sound-Pfade (Custom WAV) ───────────────────────────────────
local SND_PATH      = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArgusOrbitDefense\\Assets\\sounds\\"
local SND_SHOOT     = SND_PATH .. "shoot_01.wav"
local SND_DESTROY   = SND_PATH .. "player_destroy.wav"
local SND_PU_BOMB   = SND_PATH .. "powerup_bomb.wav"
local SND_PU_LIFE   = SND_PATH .. "powerup_life.wav"
local SND_PU_SHIELD = SND_PATH .. "powerup_shield.wav"
local SND_ENGINE    = SND_PATH .. "engine.wav"

-- WoW-Fallback-IDs für Win/Lose/WaveClear (keine Custom-Assets)
local SND_WAVECLEAR = 11685  -- UI_ACHIEVEMENT_TOAST_GLOW
local SND_WIN       = 8959   -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_LOSE      = 847    -- IG_QUEST_ABANDON

local function PlayAODSound(key, soundPath)
    local Settings = ArcadiaNexus.AOD_Settings
    if Settings and Settings:Get("soundEnabled") and Settings:Get(key) then
        if type(soundPath) == "number" then
            PlaySound(soundPath, "Master")
        else
            PlaySoundFile(soundPath, "Master")
        end
    end
end

local function CheckEndlessWaveAchievements(gs)
    local AM = ArcadiaNexus.AchievementManager
    if not gs or not AM or not AM.HandleGameResult then return end
    local Settings = ArcadiaNexus.AOD_Settings
    pcall(AM.HandleGameResult, AM, {
        gameId      = "ARGUSORBDEFENSE",
        difficulty  = gs.difficulty,
        score       = gs.score or 0,
        result      = "STATS",
        recordPlayed = false,
        stats       = {
            waveReached   = gs.wave or 1,
            meteorsKilled = Settings and Settings:GetStat("totalMeteors") or 0,
            huntersKilled = Settings and Settings:GetStat("totalHunters") or 0,
            usedBomb      = gs.usedBomb or false,
        },
    })
end

-- ── Loop-Frame ────────────────────────────────────────────────
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

function E:_StopLoop()
    if E._engineTicker then E._engineTicker:Cancel(); E._engineTicker = nil end
    _gameLoop:Stop()
end

-- ── Tick ──────────────────────────────────────────────────────
function E:_Tick(dt)
    local Logic    = ArcadiaNexus.AOD_Logic
    local Renderer = ArcadiaNexus.AOD_Renderer
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    local actions = Logic:Tick(gs, dt)

    -- Engine-Sound: Ticker läuft solange Spieler oder Hunter thrust
    -- "thrusting" = echter Schub (keyThrust), nicht nur Rotation
    local anyThrusting = false
    local ship = gs.ship
    if ship and ship.alive and ship.thrusting then
        anyThrusting = true
    end
    if not anyThrusting then
        for _, h in ipairs(gs.hunters) do
            if h.thrusting then anyThrusting = true; break end
        end
    end
    if anyThrusting then
        if not E._engineTicker then
            -- Sofort einmal spielen, dann alle 0.5s wiederholen
            PlayAODSound("soundOnEngine", SND_ENGINE)
            E._engineTicker = C_Timer.NewTicker(0.1, function()
                if E.state ~= "PLAYING" then
                    if E._engineTicker then E._engineTicker:Cancel(); E._engineTicker = nil end
                    return
                end
                PlayAODSound("soundOnEngine", SND_ENGINE)
            end)
        end
    else
        if E._engineTicker then
            E._engineTicker:Cancel()
            E._engineTicker = nil
        end
    end

    -- Renderer immer aktualisieren (bevor Overlays erscheinen)
    Renderer:UpdatePhysics(gs)
    Renderer:UpdateHUD(gs)

    -- Nachgelagerte Auswertung der Actions
    local doGameOver = false
    local doWaveClear = false
    local doWin = false

    for _, act in ipairs(actions) do
        if act.type == "shoot" then
            PlayAODSound("soundOnShoot", SND_SHOOT)

        elseif act.type == "meteor_destroyed" then
            PlayAODSound("soundOnExplode", SND_DESTROY)
            Renderer:OnMeteorDestroyed(act.meteor, act.bomb)

        elseif act.type == "hunter_destroyed" then
            PlayAODSound("soundOnExplode", SND_DESTROY)
            Renderer:OnHunterDestroyed(act.hunter, act.bomb)

        elseif act.type == "bomb_explode" then
            local Settings = ArcadiaNexus.AOD_Settings
            if Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(1, 0.95, 0.6, 0.4)
            end
            Renderer:OnBombExplode(act.x, act.y)

        elseif act.type == "powerup_collected" then
            -- Typ-spezifischer Sound
            if act.puType == "BOMB" then
                PlayAODSound("soundOnPowerUpBomb",   SND_PU_BOMB)
            elseif act.puType == "LIFE" then
                PlayAODSound("soundOnPowerUpLife",   SND_PU_LIFE)
            elseif act.puType == "SHIELD" then
                PlayAODSound("soundOnPowerUpShield", SND_PU_SHIELD)
            else
                -- RAPID / SPREAD: generischer Shoot-Sound
                PlayAODSound("soundOnShoot", SND_SHOOT)
            end
            Renderer:OnPowerUpCollected(act.puType, gs)

        elseif act.type == "powerup_activated" then
            Renderer:UpdatePowerUpBar(gs)

        elseif act.type == "powerup_expired" then
            Renderer:OnPowerUpExpired(act.puType, gs)

        elseif act.type == "ship_died" then
            PlayAODSound("soundOnLifeLost", SND_DESTROY)
            local Settings = ArcadiaNexus.AOD_Settings
            if Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(1, 0.1, 0.1, 0.3)
            end
            Renderer:OnShipDied(gs)

        elseif act.type == "ship_respawned" then
            Renderer:OnShipRespawned(gs)

        elseif act.type == "life_gained" then
            Renderer:UpdateHUD(gs)

        elseif act.type == "stat_meteor" then
            local Settings = ArcadiaNexus.AOD_Settings
            if Settings then Settings:IncrementStat("totalMeteors") end

        elseif act.type == "stat_hunter" then
            local Settings = ArcadiaNexus.AOD_Settings
            if Settings then Settings:IncrementStat("totalHunters") end

        elseif act.type == "wave_clear" then
            -- Endless: Loop läuft weiter, Logic steuert den Wave-Wechsel selbst
            -- Level-Modus: Engine übernimmt (WAVE_CLEAR-State, Overlay)
            if self.gameState and self.gameState.gameMode == "levels" then
                doWaveClear = true
            else
                -- Endless: Fortschritt sofort auswerten und kurz im HUD anzeigen.
                CheckEndlessWaveAchievements(self.gameState)
                local Settings = ArcadiaNexus.AOD_Settings
                if Settings and Settings:Get("screenFlash") then
                    Renderer:FlashScreen(0.3, 0.6, 1, 0.2)
                end
                Renderer:UpdateHUD(self.gameState)
            end

        elseif act.type == "game_over" then
            doGameOver = true

        elseif act.type == "game_win" then
            doWin = true
        end
    end

    if doWin then
        self:_HandleWin()
    elseif doGameOver then
        self:_HandleGameOver()
    elseif doWaveClear then
        self:_HandleWaveClear()
    end
end

-- ── Key-Input ─────────────────────────────────────────────────
function E:HandleKey(action, pressed)
    local gs = self.gameState
    if action == "ROTATE_LEFT"  then if gs then gs.keyLeft   = pressed end
    elseif action == "ROTATE_RIGHT" then if gs then gs.keyRight  = pressed end
    elseif action == "THRUST"       then if gs then gs.keyThrust = pressed end
    elseif action == "FIRE"         then if gs then gs.keyFire   = pressed end
    elseif action == "PAUSE" and pressed then
        if E.state == "PLAYING" then
            self:Pause()
        elseif E.state == "PAUSED" then
            self:Resume()
        end
    end
end

-- ── StartGame ────────────────────────────────────────────────
function E:StartGame(difficulty, gameMode, resumeSaved)
    local Logic    = ArcadiaNexus.AOD_Logic
    local Renderer = ArcadiaNexus.AOD_Renderer
    local Settings = ArcadiaNexus.AOD_Settings
    if not Logic or not Renderer then return end

    local config = difficulty
    if type(difficulty) ~= "table" then
        config = {
            slot       = Settings and Settings:GetActiveSlot() or 1,
            mode       = resumeSaved and "continue" or "new",
            difficulty = difficulty,
            gameMode   = gameMode,
        }
    end
    local slot = config.slot or (Settings and Settings:GetActiveSlot()) or 1
    if Settings and (slot < 1 or slot > Settings.MAX_SLOTS) then return end
    local startMode = config.mode or "new"
    if Settings then Settings:SetActiveSlot(slot) end
    self.activeSlot = slot

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ARGUSORBDEFENSE", E._sessionId)

    self:_StopLoop()
    self:_ClearKeys()

    local diff    = config.difficulty or (Settings and Settings:Get("difficulty")) or "normal"
    local mode    = config.gameMode   or (Settings and Settings:Get("gameMode"))   or "endless"

    local savedProgress = nil
    if startMode == "continue" and Settings then
        savedProgress = Settings:LoadProgress(slot)
        if savedProgress then
            diff = savedProgress.diff or diff
            mode = savedProgress.mode or mode
        end
    elseif startMode == "new" and Settings then
        Settings:ClearProgress(slot)
        Settings:ResetSlot(slot)
        local save = Settings:LoadSlot(slot)
        if save then save.mode = mode; save.diff = diff end
    end

    local gs = Logic:NewState(diff, mode, savedProgress)

    self.gameState = gs
    E.state = "PLAYING"

    Logic:SpawnWave(gs)
    Renderer:OnGameStarted(gs)
    self:_StartLoop()
end

-- ── StopGame ─────────────────────────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARGUSORBDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    self:_ClearKeys()
    E.state               = "IDLE"
    E._wasThrusting       = false
    E._hunterWasThrusting = {}
    if E._engineTicker then E._engineTicker:Cancel(); E._engineTicker = nil end
    self.gameState = nil
    local R = ArcadiaNexus.AOD_Renderer
    if R then R:EnterIdleState() end
end

-- ── Pause / Resume ───────────────────────────────────────────
function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    self:_ClearKeys()
    local R = ArcadiaNexus.AOD_Renderer
    if R then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    E.state = "PLAYING"
    local R = ArcadiaNexus.AOD_Renderer
    if R then R:HidePause() end
    self:_StartLoop()
end

-- ── SaveAndPause (OnHide-Handler) ────────────────────────────
function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("ARGUSORBDEFENSE", E._sessionId)
    end
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AOD_Settings
    if gs and Settings then
        Settings:SaveProgress(gs.level or gs.wave or 1, gs.score, gs.lives, gs.difficulty, gs.gameMode)
    end
    self:_StopLoop()
    self:_ClearKeys()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARGUSORBDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    self.gameState = nil
end

-- ── Wave Clear (Level-Modus) ─────────────────────────────────
function E:_HandleWaveClear()
    self:_StopLoop()
    E.state = "WAVE_CLEAR"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AOD_Settings
    local Renderer = ArcadiaNexus.AOD_Renderer
    if not gs then return end

    PlayAODSound("soundOnWaveClear", SND_WAVECLEAR)
    local flash = Settings and Settings:Get("screenFlash")
    if flash and Renderer then
        Renderer:FlashScreen(0.4, 0.6, 1, 0.25)  -- blauer Flash
    end

    if Settings then
        Settings:IncrementStat("wins")
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "ARGUSORBDEFENSE",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "WIN",
        stats      = {
            levelReached  = gs.level,
            meteorsKilled = Settings and Settings:GetStat("totalMeteors") or 0,
            huntersKilled = Settings and Settings:GetStat("totalHunters") or 0,
            usedBomb      = gs.usedBomb or false,
        },
    })

    if Renderer then Renderer:ShowWaveClear(gs) end
end

-- ── Nächstes Level (Level-Modus, aufgerufen vom Renderer) ────
function E:ContinueToNextLevel()
    local Logic    = ArcadiaNexus.AOD_Logic
    local Renderer = ArcadiaNexus.AOD_Renderer
    local gs       = self.gameState
    if not Logic or not Renderer or not gs then return end

    gs.level    = gs.level + 1
    gs.allClear = false
    gs.wave     = gs.level

    -- Aktive Power-Ups beim Level-Wechsel behalten
    E.state = "PLAYING"
    Logic:SpawnWave(gs)
    Renderer:OnLevelAdvanced(gs)
    self:_StartLoop()
end

-- ── Win (Level-Modus: alle 30 Level) ────────────────────────
function E:_HandleWin()
    self:_StopLoop()
    E.state = "GAMEOVER"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AOD_Settings
    local Renderer = ArcadiaNexus.AOD_Renderer
    if not gs then return end

    PlayAODSound("soundOnWin", SND_WIN)
    if Settings then
        Settings:IncrementStat("wins")
        Settings:ClearProgress()
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "ARGUSORBDEFENSE",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "WIN",
        stats      = {
            levelReached  = gs.level,
            meteorsKilled = Settings and Settings:GetStat("totalMeteors") or 0,
            huntersKilled = Settings and Settings:GetStat("totalHunters") or 0,
            usedBomb      = gs.usedBomb or false,
        },
    })

    if Renderer then Renderer:ShowVictory(gs) end
end

-- ── Game Over ────────────────────────────────────────────────
function E:_HandleGameOver()
    self:_StopLoop()
    E.state = "GAMEOVER"
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AOD_Settings
    local Renderer = ArcadiaNexus.AOD_Renderer
    if not gs then return end

    PlayAODSound("soundOnLose", SND_LOSE)
    if Settings then
        Settings:IncrementStat("losses")
        Settings:IncrementStat("played")
        Settings:ClearProgress()
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "ARGUSORBDEFENSE",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = "LOSS",
        stats      = {
            levelReached  = gs.level,
            waveReached   = gs.wave,
            meteorsKilled = Settings and Settings:GetStat("totalMeteors") or 0,
            huntersKilled = Settings and Settings:GetStat("totalHunters") or 0,
            usedBomb      = gs.usedBomb or false,
        },
    })

    if Renderer then Renderer:ShowGameOver(gs) end
end

-- ── Hilfsfunktion: alle Tastatur-Flags löschen ───────────────
function E:_ClearKeys()
    local gs = self.gameState
    if gs then
        gs.keyLeft   = false
        gs.keyRight  = false
        gs.keyThrust = false
        gs.keyFire   = false
    end
end
