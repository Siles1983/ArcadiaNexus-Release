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
--  - Custom-WAVs via PlaySoundFile; Win bleibt SOUNDKIT-ID
-- ============================================================

ArcadiaNexus.AD_Engine = {}
local E = ArcadiaNexus.AD_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AD_LoopFrame")

-- ── Custom-WAVs (alle 0,5 s) ──────────────────────────────────
-- Kein StopSound: Samples dürfen überlappen, Retrigger wird gedrosselt.
local SND_PATH          = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlienDefense\\assets\\sound\\"
local SND_PLAYER_SHOOT  = SND_PATH .. "playership_shoot.wav"
local SND_ALIEN_SHOOT   = SND_PATH .. "enemyship_shoot.wav"
local SND_ENEMY_DEFEAT  = SND_PATH .. "enemy_defeat.wav"
local SND_PLAYER_DEFEAT = SND_PATH .. "playership_defeat.wav"
local SND_POWER_UP      = SND_PATH .. "power_up.wav"
local SND_WIN           = 8959  -- UI_ACHIEVEMENT_TOAST_SPARK

local SND_GAP = {
    soundOnShoot      = 0.22, -- SINGLE 0.25 s → jedes Feuer, max. ~2 Stimmen
    soundOnAlienShoot = 0.18, -- Dual-Salve im selben Tick = 1 Stimme
    soundOnAlienDeath = 0.16, -- Laser-Mehrfachkill im selben Tick = 1 Stimme
    soundOnPlayerHit  = 0.45,
    soundOnWeaponDrop = 0.40,
    soundOnLose       = 0.45,
}

local _lastPlay = {}

local function Now()
    if GetTime then return GetTime() end
    return 0
end

local function PlayADFile(Settings, key, path)
    if not Settings or not Settings:Get(key) then return end
    local t = Now()
    local last = _lastPlay[key]
    local gap = SND_GAP[key] or 0.20
    if last and (t - last) < gap then return end
    _lastPlay[key] = t
    PlaySoundFile(path, "Master")
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
    if self.state ~= "PLAYING" or not Logic or not Renderer or not gs then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput() end

    local actions = Logic:Tick(gs, dt)
    local sid = self._sessionId

    -- flags (wie BlockBreaker — Renderer läuft immer durch)
    local doGameOver  = false
    local doWaveWin   = false

    for _,act in ipairs(actions) do
        if act.type=="game_over" then doGameOver=true
        elseif act.type=="wave_cleared" then doWaveWin=true end
    end
    -- Result gates and persistence precede every presentation callback. A hit
    -- effect may hide the renderer or a result listener may start a new run.
    if doGameOver then self:_HandleGameOver(true)
    elseif doWaveWin then self:_HandleWaveWin(true) end
    if self.gameState~=gs or self._sessionId~=sid then return end

    for _, act in ipairs(actions) do
        if self.gameState~=gs or self._sessionId~=sid then return end
        if act.type == "player_shoot" then
            PlayADFile(Settings, "soundOnShoot", SND_PLAYER_SHOOT)
            Renderer:OnPlayerShoot(act.weapon)
            if act.laserFlash and Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(0.2, 0.9, 0.9, 0.08)
            end

        elseif act.type == "alien_killed" then
            PlayADFile(Settings, "soundOnAlienDeath", SND_ENEMY_DEFEAT)
            Renderer:OnAlienKilled(act.alien, gs)

        elseif act.type == "player_hit" then
            PlayADFile(Settings, "soundOnPlayerHit", SND_PLAYER_DEFEAT)
            if Settings and Settings:Get("screenFlash") then
                Renderer:FlashScreen(1, 0.1, 0.1)
            end
            Renderer:OnPlayerHit(gs)
            Renderer:UpdateHUD(gs)

        elseif act.type == "alien_shoot" then
            PlayADFile(Settings, "soundOnAlienShoot", SND_ALIEN_SHOOT)

        elseif act.type == "drop_spawned" then
            Renderer:OnDropSpawned(act.wtype, act.x, act.y, gs)

        elseif act.type == "weapon_collected" then
            PlayADFile(Settings, "soundOnWeaponDrop", SND_POWER_UP)
            Renderer:OnWeaponCollected(act.wtype, gs)

        elseif act.type == "weapon_expired" then
            Renderer:UpdateHUD(gs)

        elseif act.type == "perfect_wave_bonus" then
            -- Renderer zeigt Bonus im Overlay

        elseif act.type == "formation_step" then
            Renderer:OnFormationStep()

        elseif act.type == "formation_descent" then
            Renderer:OnFormationDescent()

        elseif act.type == "wave_cleared" then
            doWaveWin = true

        elseif act.type == "game_over" then
            doGameOver = true
        end
    end

    -- Renderer immer aktualisieren (letzter Alien-Frame verschwindet korrekt)
    Renderer:UpdatePhysics(gs, dt)
    Renderer:UpdateHUD(gs)

    if self.gameState~=gs or self._sessionId~=sid then return end
    if doGameOver then self:_PresentGameOver(gs)
    elseif doWaveWin then Renderer:ShowWaveWin(gs) end
end

-- Commit deltas at saves, wave boundaries and terminal results. The receipt
-- owns the monotonic counters; repeated payloads are harmless.
function E:_Book(gs, result)
    if self._booking then return false end
    local data = {gameId="ALIENDEFENSE", difficulty=gs.difficulty, runId=gs.runId,
        ruleVersion=2, score=gs.score, result=gs.legacyWon and "STATS" or result or gs.runResult or "STATS",
        closed=gs.gameOver or gs.runClosed or false,
        stats={clearedWave=gs.clearedWave or 0, wavesCleared=gs.totalWavesCleared or 0, enemiesKilled=gs.totalKillsAllWaves or 0}}
    ArcadiaNexus.AD_Settings:SavePending(data)
    self._booking = true
    ArcadiaNexus.Engine:Emit("GAME_RESULT", data)
    self._booking = nil
    if data.processed then ArcadiaNexus.AD_Settings:ClearPending(gs.runId) end
    gs.resultData=data
    return data.processed == true
end

function E:RetryPending()
    local S=ArcadiaNexus.AD_Settings
    for id,data in pairs(S:GetPending()) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT", data)
        if data.processed then S:ClearPending(id) end
    end
end

function E:_Save()
    local gs, S = self.gameState, ArcadiaNexus.AD_Settings
    if not gs then return end
    local slot = self.activeSlot
    if gs.gameOver or gs.runClosed then S:ClearProgress(self.activeSlot)
    else S:SaveProgress(gs, self.activeSlot) end
    self:_Book(gs)
    if self.gameState == gs and self.activeSlot == slot and not gs.gameOver and not gs.runClosed then
        S:SaveProgress(gs, slot)
    end
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
    local slot = tonumber(config.slot or (Settings and Settings:GetActiveSlot()) or 1)
    if not slot or slot ~= math.floor(slot) or slot < 1 or slot > Settings.MAX_SLOTS then return false end
    local mode = config.mode or "continue"
    if mode~="new" and mode~="continue" then return false end
    self:RetryPending()

    local diff = config.difficulty or (Settings and Settings:Get("difficulty")) or "easy"

    local savedProgress = nil
    if mode == "continue" and Settings then
        savedProgress = Settings:LoadProgress(slot)
        if savedProgress then diff = savedProgress.diff or diff end
    end

    local gs
    if savedProgress and savedProgress.version then
        gs = Logic:Restore(savedProgress)
        if not gs or not ArcadiaNexus.LocalResults:GetSerial("ALIENDEFENSE",gs.runId) then return false end
        local receipt=ArcadiaNexus.LocalResults:GetReceipt(gs.runId)
        if receipt and (receipt.closed or receipt.score>gs.score
            or receipt.enemiesKilled>gs.totalKillsAllWaves or receipt.clearedWave>gs.clearedWave
            or receipt.wavesCleared>gs.totalWavesCleared
            or receipt.result~="STATS" and receipt.result~=gs.runResult) then return false end
    else
        gs = Logic:NewState(diff, savedProgress)
        if savedProgress then
            gs.legacyRestart = true
            if gs.wave > 30 then
                gs.endlessMode, gs.runResult, gs.legacyWon = true, "WIN", true
            end
        end
        Logic:ParseWave(gs)
    end
    local SM = ArcadiaNexus.ScoreManager
    if SM then gs.highScore = SM:GetBestScore("ALIENDEFENSE", gs.difficulty) end
    local sid = ArcadiaNexus.Lifecycle:ClaimRestart("ALIENDEFENSE", E._sessionId)
    if not sid then return false end
    if mode == "new" and Settings then Settings:ResetSlot(slot) end
    if not (savedProgress and savedProgress.version) then
        gs.runId = ArcadiaNexus.LocalResults:NewRun("ALIENDEFENSE")
    end
    if Settings then Settings:SetActiveSlot(slot) end
    self.activeSlot = slot
    self:_StopLoop()
    self.gameState = gs
    E._sessionId = sid
    E.state = gs.waveWon and "TRANSITION" or "PLAYING"
    self:_NeutralizeInput()
    self:_Save()
    if self.gameState ~= gs then return false end
    Renderer:OnGameStarted(gs)
    if gs.waveWon then Renderer:ShowWaveWin(gs) else self:_StartLoop() end
    return true
end

-- ── StopGame ──────────────────────────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ALIENDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    local gs = self.gameState
    if gs and gs.waveWon and gs.wave == 30 and not gs.endlessMode then gs.runClosed = true end
    self:_Save()
    if self.gameState~=gs then return end
    E.state = "IDLE"
    self.gameState = nil
    local R = ArcadiaNexus.AD_Renderer
    if R then R:EnterIdleState() end
end

-- ── Pause / Resume ────────────────────────────────────────────
function E:_NeutralizeInput()
    if self.gameState then ArcadiaNexus.AD_Logic:Neutralize(self.gameState) end
    self._padBlocked = self._padBlocked or {}
    for key,down in pairs(self._padHeld or {}) do if down then self._padBlocked[key]=true end end
    if math.abs(self._padX or 0) > (self._padDeadzone or 0.35) then self._padAxisBlocked = true end
    local R=ArcadiaNexus.AD_Renderer
    if R and R.NeutralizeInput then R:NeutralizeInput() end
end

function E:HandlePadButton(button, pressed)
    self._padHeld, self._padBlocked = self._padHeld or {}, self._padBlocked or {}
    self._padHeld[button] = pressed or nil
    if not pressed then self._padBlocked[button]=nil end
    local gs = self.gameState
    if not gs or self._padBlocked[button] then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    if (button=="PADFORWARD" or button=="PAD4") and pressed then self:TogglePause(); return end
    if self.state ~= "PLAYING" then return end
    if button=="PADLEFT" then gs.keyLeft=pressed
    elseif button=="PADRIGHT" then gs.keyRight=pressed
    elseif button=="PAD1" then gs.keyFire=pressed
    elseif button=="PADUP" and pressed then self:CycleWeaponUp()
    elseif button=="PADDOWN" and pressed then self:CycleWeaponDown() end
end

function E:HandlePadAxis(x, deadzone)
    self._padDeadzone=deadzone or self._padDeadzone or 0.35
    self._padX=x
    if math.abs(x)<=self._padDeadzone then self._padAxisBlocked=nil end
    if self._padAxisBlocked or self.state~="PLAYING" or not self.gameState then return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then self:_NeutralizeInput(); return end
    self.gameState.keyLeft, self.gameState.keyRight=x < -self._padDeadzone, x > self._padDeadzone
end

function E:Pause()
    if E.state ~= "PLAYING" then return end
    E.state = "PAUSED"
    self:_StopLoop()
    self:_NeutralizeInput()
    local R = ArcadiaNexus.AD_Renderer
    if R then R:ShowPause() end
end

function E:Resume()
    if E.state ~= "PAUSED" then return end
    local R = ArcadiaNexus.AD_Renderer
    if R and ArcadiaNexus.UI.IsResultDialogVisible(R._fieldFrame) then return end
    self:_NeutralizeInput()
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
    local gs, sid = self.gameState, E._sessionId
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("ALIENDEFENSE", E._sessionId)
    end
    self:_NeutralizeInput()
    self:_StopLoop()
    self:_Save()
    if self.gameState~=gs or self._sessionId~=sid then return end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ALIENDEFENSE", E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    self.gameState = nil
end

-- ── Welle gewonnen ────────────────────────────────────────────
function E:_HandleWaveWin(deferPresentation)
    local gs = self.gameState
    if self.state ~= "PLAYING" or not gs or not gs.waveWon or gs.handledWaveId == gs.waveId then return false end
    gs.handledWaveId = gs.waveId -- before synchronous result callbacks
    self.state = "TRANSITION"
    self:_StopLoop()
    self:_NeutralizeInput()
    if gs.wave == 30 and not gs.runResult then gs.runResult = "WIN" end
    self:_Save()
    if self.gameState ~= gs or self.state ~= "TRANSITION" then return true end
    if ArcadiaNexus.AD_Settings:Get("soundOnWin") then PlaySound(SND_WIN, "Master") end
    gs.highScore = math.max(gs.highScore or 0, gs.score)
    if not deferPresentation then ArcadiaNexus.AD_Renderer:ShowWaveWin(gs) end
    return true
end

function E:ContinueToNextWave(expectedWaveId)
    local gs, Logic, Renderer = self.gameState, ArcadiaNexus.AD_Logic, ArcadiaNexus.AD_Renderer
    if self.state ~= "TRANSITION" or not gs or not gs.waveWon
        or expectedWaveId and expectedWaveId ~= gs.waveId then return false end
    self:_Save()
    if self.gameState ~= gs or self.state ~= "TRANSITION" then return false end
    if not gs.resultData or not gs.resultData.processed then
        Renderer:ShowWaveWin(gs) -- keep a retryable transition visible
        return false
    end
    if not Logic:AdvanceWave(gs, true) then return false end
    self.state = "PLAYING"
    Renderer:OnWaveAdvanced(gs)
    self:_Save()
    self:_StartLoop()
    return true
end

function E:_HandleGameOver(deferPresentation)
    local gs = self.gameState
    if self.state ~= "PLAYING" or not gs or not gs.gameOver or gs.runClosed then return false end
    gs.runClosed = true
    gs.runResult = gs.runResult or "LOSS"
    self.state = "GAMEOVER"
    self:_StopLoop()
    ArcadiaNexus.AD_Logic:Neutralize(gs)
    self:_Save()
    if self.gameState ~= gs or self.state ~= "GAMEOVER" then return true end
    if gs.invaded then PlayADFile(ArcadiaNexus.AD_Settings, "soundOnLose", SND_PLAYER_DEFEAT) end
    gs.highScore = math.max(gs.highScore or 0, gs.score)
    if not deferPresentation then self:_PresentGameOver(gs) end
    return true
end

function E:_PresentGameOver(gs)
    if self.gameState~=gs or self.state~="GAMEOVER" then return end
    local Renderer = ArcadiaNexus.AD_Renderer
    if (gs.playerBoomT or 0) > 0 then
        local sid = self._sessionId
        _gameLoop:Start(function(dt)
            if self.gameState ~= gs or self._sessionId ~= sid then self:_StopLoop(); return end
            gs.playerBoomT = math.max(0, gs.playerBoomT - dt)
            Renderer:UpdatePhysics(gs, dt) -- FX only; frozen final gameplay
            if gs.playerBoomT <= 0 then self:_StopLoop(); Renderer:ShowGameOver(gs) end
        end, {stateCheck=function() return self.state=="GAMEOVER" end})
    else Renderer:ShowGameOver(gs) end
end

-- ── Waffe wechseln (Keyboard W/S) ─────────────────────────────
function E:CycleWeaponUp()
    local Logic = ArcadiaNexus.AD_Logic
    local gs    = self.gameState
    if self.state ~= "PLAYING" then return end
    if Logic and gs then Logic:CycleWeapon(gs, 1) end
    local R = ArcadiaNexus.AD_Renderer
    if R and gs then R:UpdateHUD(gs) end
end

function E:CycleWeaponDown()
    local Logic = ArcadiaNexus.AD_Logic
    local gs    = self.gameState
    if self.state ~= "PLAYING" then return end
    if Logic and gs then Logic:CycleWeapon(gs, -1) end
    local R = ArcadiaNexus.AD_Renderer
    if R and gs then R:UpdateHUD(gs) end
end
