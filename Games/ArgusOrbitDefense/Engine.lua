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
local _soundGuard = ArcadiaNexus.TimerGuard.New()

E._wasThrusting      = false
E._hunterWasThrusting = {}
E._engineSoundOn     = false

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

function E:_Book(result)
    local gs=self.gameState; if not gs then return end
    local S=ArcadiaNexus.AOD_Settings
    local data={gameId="ARGUSORBDEFENSE",difficulty=gs.gameMode.."_"..gs.difficulty,
        aiDifficulty=gs.difficulty,gameMode=gs.gameMode,ruleVersion=2,runId=gs.runId,
        score=gs.score,result=result or "STATS",closed=result=="WIN" or result=="LOSS",
        stats={meteorsKilled=gs.meteorsKilled,huntersKilled=gs.huntersKilled,
            clearedWave=gs.clearedWave,clearedLevel=gs.clearedLevel,stagesCleared=gs.stagesCleared,
            hardLevelsCleared=gs.hardLevelsCleared,bombLevelsCleared=gs.bombLevelsCleared}}
    S:SavePending(data)
    ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
    if data.processed then S:ClearPending(gs.runId) end
    if self.gameState==gs then self.resultData=data end
end
function E:RetryPending()
    local S=ArcadiaNexus.AOD_Settings
    for id,data in pairs(ArcadiaNexus.AOD_Logic:Copy(S:GetPending())) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then S:ClearPending(id) end
    end
end

-- ── Loop-Frame ────────────────────────────────────────────────
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function() return E.state == "PLAYING" end,
    })
end

function E:_StopLoop()
    _soundGuard:Cancel()
    E._engineSoundOn = false
    _gameLoop:Stop()
end

-- ── Tick ──────────────────────────────────────────────────────
function E:_Tick(dt)
    local Logic    = ArcadiaNexus.AOD_Logic
    local Renderer = ArcadiaNexus.AOD_Renderer
    local gs       = self.gameState
    if self.state~="PLAYING" or not Logic or not Renderer or not gs then return end

    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput() end
    local actions = Logic:Tick(gs, dt)
    local sid=self._sessionId
    local stageClear=false
    for _,act in ipairs(actions) do if act.type=="wave_clear" then stageClear=true end end
    -- Freeze before callbacks and synchronous progression events.
    if gs.gameOver or gs.win then self.state="GAMEOVER"; self:_StopLoop(); self:_NeutralizeInput()
    elseif stageClear and gs.gameMode=="levels" then self.state="WAVE_CLEAR"; self:_StopLoop(); self:_NeutralizeInput() end
    local old=ArcadiaNexus.LocalResults:GetReceipt(gs.runId)
    if gs.gameOver or gs.win or stageClear or not old
        or gs.meteorsKilled~=(old.personalStats and old.personalStats.meteorsKilled)
        or gs.huntersKilled~=(old.personalStats and old.personalStats.huntersKilled) then
        if gs.gameOver or gs.win then ArcadiaNexus.AOD_Settings:ClearProgress(self.activeSlot) end
        self:_Book(gs.win and "WIN" or gs.gameOver and "LOSS" or "STATS")
    end
    if self.gameState~=gs or self._sessionId~=sid then return end

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
    if anyThrusting and self.state=="PLAYING" then
        if not E._engineSoundOn then
            -- Sofort einmal spielen, dann alle 0.1s wiederholen
            PlayAODSound("soundOnEngine", SND_ENGINE)
            E._engineSoundOn = true
            _soundGuard:EveryTicker(0.1, function()
                if E.state ~= "PLAYING" then
                    _soundGuard:Cancel()
                    E._engineSoundOn = false
                    return
                end
                PlayAODSound("soundOnEngine", SND_ENGINE)
            end)
        end
    else
        if E._engineSoundOn then
            _soundGuard:Cancel()
            E._engineSoundOn = false
        end
    end

    -- Renderer immer aktualisieren (bevor Overlays erscheinen)
    Renderer:UpdatePhysics(gs)
    if self.gameState~=gs or self._sessionId~=sid then return end
    Renderer:UpdateHUD(gs)
    if self.gameState~=gs or self._sessionId~=sid then return end

    -- Nachgelagerte Auswertung der Actions
    local doGameOver = false
    local doWaveClear = false
    local doWin = false

    for _, act in ipairs(actions) do
        if self.gameState~=gs or self._sessionId~=sid then return end
        if act.type == "shoot" then
            PlayAODSound("soundOnShoot", SND_SHOOT)
            Renderer:OnShoot(gs)

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
            -- Monotone run totals are committed by LocalResults.

        elseif act.type == "stat_hunter" then
            -- Monotone run totals are committed by LocalResults.

        elseif act.type == "wave_started" then
            Renderer:ShowWaveBanner(self.gameState)

        elseif act.type == "wave_clear" then
            -- Endless: Loop läuft weiter, Logic steuert den Wave-Wechsel selbst
            -- Level-Modus: Engine übernimmt (WAVE_CLEAR-State, Overlay)
            if self.gameState and self.gameState.gameMode == "levels" then
                doWaveClear = true
            else
                -- Endless: Fortschritt sofort auswerten und kurz im HUD anzeigen.
                -- Stage progress was committed before presentation.
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
    if action~="PAUSE" and self.state~="PLAYING" then return end
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
function E:StartGame(difficulty,gameMode,resumeSaved)
    local L,R,S=ArcadiaNexus.AOD_Logic,ArcadiaNexus.AOD_Renderer,ArcadiaNexus.AOD_Settings
    if not L or not R or not S then return end
    local config=type(difficulty)=="table" and difficulty or {difficulty=difficulty,gameMode=gameMode,mode=resumeSaved and "continue" or "new"}
    local slot=tonumber(config.slot or S:GetActiveSlot())
    if not slot or slot%1~=0 or slot<1 or slot>S.MAX_SLOTS then return end
    local saved=config.mode=="continue" and S:LoadProgress(slot) or nil
    if config.mode=="continue" and not saved then return end
    if saved and saved.version and saved.version~=2 then return end
    local diff=saved and (saved.difficulty or saved.diff) or config.difficulty or S:Get("difficulty")
    local mode=saved and (saved.gameMode or saved.mode) or config.gameMode or S:Get("gameMode")
    if not L.DIFFICULTY_DEFS[diff] or mode~="levels" and mode~="endless" then return end
    local gs=L:NewState(diff,mode,saved)
    if not gs then return end
    if type(gs.level)~="number" or gs.level%1~=0 or gs.level<1 or gs.level>30
        or type(gs.lives)~="number" or gs.lives%1~=0 or gs.lives<1 or gs.lives>L.MAX_LIVES then return end
    if saved and saved.version==2 then
        local receipt=ArcadiaNexus.LocalResults:GetReceipt(gs.runId)
        if not ArcadiaNexus.LocalResults:GetSerial("ARGUSORBDEFENSE",gs.runId) or receipt and receipt.closed then return end
    end
    self:RetryPending()
    if saved and saved.version==2 then
        local receipt=ArcadiaNexus.LocalResults:GetReceipt(gs.runId)
        if receipt and receipt.closed then return end
    end
    if self.gameState and self.state~="IDLE" and self.state~="GAMEOVER" then S:SaveProgress(self.gameState,self.activeSlot,self.state) end
    local sid=ArcadiaNexus.Lifecycle:ClaimRestart("ARGUSORBDEFENSE",self._sessionId)
    if not sid then return false end
    self:_StopLoop(); self:_NeutralizeInput()
    self._sessionId=sid
    self.activeSlot=slot; S:SetActiveSlot(slot)
    if not saved or saved.version~=2 then
        gs.runId=ArcadiaNexus.LocalResults:NewRun("ARGUSORBDEFENSE")
        L:SpawnWave(gs)
    end
    self.gameState=gs; self.state=saved and saved.version==2 and saved.phase or "PLAYING"
    if config.mode~="continue" then S:ClearProgress(slot) end
    R:OnGameStarted(gs); R:UpdatePhysics(gs)
    if self.state=="WAVE_CLEAR" then R:ShowWaveClear(gs)
    elseif self.state=="PAUSED" then R:ShowPause()
    else self:_StartLoop() end
end

-- ── StopGame ─────────────────────────────────────────────────
function E:StopGame()
    if self.gameState and self.state~="IDLE" and self.state~="GAMEOVER" then self:SaveAndPause() end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARGUSORBDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    self:_NeutralizeInput()
    E.state               = "IDLE"
    E._wasThrusting       = false
    E._hunterWasThrusting = {}
    E._engineSoundOn      = false
    self.gameState = nil
    local R = ArcadiaNexus.AOD_Renderer
    if R then R:EnterIdleState() end
end

-- ── Pause / Resume ───────────────────────────────────────────
function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    self:_NeutralizeInput()
    local R = ArcadiaNexus.AOD_Renderer
    if R then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    self:_NeutralizeInput()
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
    if gs and Settings and (self.state=="PLAYING" or self.state=="PAUSED" or self.state=="WAVE_CLEAR") then
        Settings:SaveProgress(gs,self.activeSlot,self.state)
    end
    self:_StopLoop()
    self:_NeutralizeInput()
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

    if Renderer then Renderer:ShowWaveClear(gs) end
end

-- ── Nächstes Level (Level-Modus, aufgerufen vom Renderer) ────
function E:ContinueToNextLevel(expectedStageId)
    local Logic    = ArcadiaNexus.AOD_Logic
    local Renderer = ArcadiaNexus.AOD_Renderer
    local gs       = self.gameState
    if self.state~="WAVE_CLEAR" or not Logic or not Renderer or not gs or not gs.allClear or gs.gameMode~="levels" or gs.level>=30 then return end
    if expectedStageId and expectedStageId~=gs.stageId then return end
    self:_NeutralizeInput()

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

function E:_NeutralizeInput()
    self:_ClearKeys()
    self._padBlocked=self._padBlocked or {}
    for key,down in pairs(self._padHeld or {}) do if down then self._padBlocked[key]=true end end
    if math.abs(self._padX or 0)>0.35 or math.abs(self._padY or 0)>0.35 then self._padAxisBlocked=true end
    local R=ArcadiaNexus.AOD_Renderer
    if R and R.NeutralizeInput then R:NeutralizeInput() end
end

function E:HandlePadButton(button,pressed)
    self._padHeld,self._padBlocked=self._padHeld or {},self._padBlocked or {}
    self._padHeld[button]=pressed or nil
    if not pressed then self._padBlocked[button]=nil end
    if self._padBlocked[button] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    local action=({PADLEFT="ROTATE_LEFT",PADRIGHT="ROTATE_RIGHT",PADUP="THRUST",PADLSHOULDER="THRUST",PAD1="FIRE",PADFORWARD="PAUSE",PAD4="PAUSE"})[button]
    if action then self:HandleKey(action,pressed) end
end
function E:HandlePadAxis(x,y,deadzone)
    local dz=deadzone or 0.35; self._padX,self._padY=x,y
    if math.abs(x)<=dz and math.abs(y)<=dz then self._padAxisBlocked=nil end
    if self._padAxisBlocked or self.state~="PLAYING" then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    self:HandleKey("ROTATE_LEFT",x < -dz); self:HandleKey("ROTATE_RIGHT",x > dz); self:HandleKey("THRUST",y > dz)
end
