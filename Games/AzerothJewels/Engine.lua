-- ============================================================
--  Azeroth Jewels – Engine.lua
--  State-Machine, Lifecycle, Timer, PowerUp-Fluss, GAME_RESULT.
--  KEINE UI-Frames (Renderer), KEINE Spielregeln (Logic).
--
--  States: IDLE | MAP | PLAYING | ANIMATING | POWERUP_TARGETING
--          | LEVEL_COMPLETE | GAMEOVER
--
--  Session-Ownership:
--    StartGame  → Validierung, dann BeginGame (bzw. ResumeGame bei
--                 pausierter eigener Session)
--    StopGame   → EndGame, _sessionId = nil
--    SaveAndPause → PauseGame, _sessionId BLEIBT gesetzt,
--                   Mid-Level-State in den aktiven Slot
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_Engine = {}
local E = ArcadiaNexus.AJ_Engine

local GAME_ID = "AZEROTHJEWELS"

E._sessionId = nil

E.state      = "IDLE"
E.gameState  = nil    -- Logic-State des laufenden Levels
E.powerUps   = nil    -- { inv = {..}, progress = {..} }
E.totalScore = 0
E.activeSlot = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard   -- Renderer nutzt denselben Guard für Effekte
local _idleGuard = ArcadiaNexus.TimerGuard.New()
local IDLE_HINT_SEC = 5

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AJ_LoopFrame")

local _animGen        = 0
local _selected       = nil
local _pendingPowerUp = nil
local _timeAccum      = 0
local _moveCount      = 0

-- ============================================================
-- Hilfen
-- ============================================================
local function Loc()
    return ArcadiaNexus.GetLocaleTable(GAME_ID)
end

function E:_CancelIdleHint()
    _idleGuard:Cancel()
    local R = ArcadiaNexus.AJ_Renderer
    if R and R.ClearMoveHint then R:ClearMoveHint() end
end

function E:_ArmIdleHint()
    self:_CancelIdleHint()
    if E.state ~= "PLAYING" then return end
    local Settings = ArcadiaNexus.AJ_Settings
    if Settings and Settings:Get("hintSparkle") == false then return end
    local gs = self.gameState
    if not gs or gs.gameOver then return end
    local sid = E._sessionId
    _idleGuard:After(IDLE_HINT_SEC, function()
        local Session = ArcadiaNexus.GameSession
        if Session and not Session:IsSession(E, sid) then return end
        if E.state ~= "PLAYING" then return end
        local Logic = ArcadiaNexus.AJ_Logic
        local R = ArcadiaNexus.AJ_Renderer
        if not Logic or not R or not E.gameState then return end
        local hint = Logic:FindHintMove(E.gameState)
        if hint and R.ShowMoveHint then
            R:ShowMoveHint(hint)
        end
    end)
end

local function PlayAJ(event)
    local S = ArcadiaNexus.AJ_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "match" and S:Get("soundOnMatch") then
        PlaySoundFile("Sound\\Spells\\ShiningRay.ogg", "Master")
    elseif event == "powerup" and S:Get("soundOnPowerup") then
        PlaySound(SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or 63971, "SFX")
    elseif event == "lowmoves" and S:Get("soundOnLowMoves") ~= false
           and S:Get("soundOnGameover") ~= false then
        PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3 or 18871, "SFX")
    elseif event == "win" and S:Get("soundOnGameover") then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "SFX")
    elseif event == "loss" and S:Get("soundOnGameover") then
        PlaySoundFile("Sound\\Doodad\\BellTollHorde.ogg", "Master")
    end
end

local function CopyInv(src)
    local t = { fire = 0, frost = 0, chain = 0, bomb = 0, holy = 0 }
    if type(src) == "table" then
        for k, v in pairs(src) do t[k] = v end
    end
    return t
end

local function GetHighScore(difficulty)
    local SM = ArcadiaNexus.ScoreManager
    if SM then return SM:GetBestScore(GAME_ID, difficulty) end
    return 0
end

-- ============================================================
-- Zeitmodus (GameLoop-Tick + Anzeige)
-- ============================================================
function E:_StartTimeMode()
    _timeAccum = 0
    _gameLoop:Start(function(dt) E:_TickTime(dt) end, {
        stateCheck = function()
            return E.state == "PLAYING"
                or E.state == "ANIMATING"
                or E.state == "POWERUP_TARGETING"
        end,
    })
end

function E:_TickTime(dt)
    local gs = self.gameState
    if not gs or not gs.timerActive or gs.gameOver then return end
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer

    local before = math.ceil(gs.timeLeft)
    Logic:TickTimer(gs, dt)
    local after = math.ceil(gs.timeLeft)
    if after ~= before and R then
        R:UpdateHUD(gs)
    end

    -- Timeout nur im ruhenden Zustand auslösen; während einer laufenden
    -- Kaskade greift der Check am Kaskaden-Ende.
    if gs.timeLeft <= 0 and E.state == "PLAYING" then
        if Logic:CheckTimeout(gs) then
            self:_HandleGameOver()
        end
    end
end

-- ============================================================
-- StartGame
-- ============================================================
-- config = {
--   slot   = 1..3   (Pflicht)
--   mode   = "new" | "continue"
--   level  = optional, Karten-Sprung (nur unlocked)
--   skipMid = true  → Mid-Level ignorieren
--   startPowerUps = { inv, progress }  → Restart-Inventar
-- }
function E:StartGame(config)
    -- ── Validierung ZUERST (kein BeginGame bei kaputtem Setup) ──
    local Logic    = ArcadiaNexus.AJ_Logic
    local Levels   = ArcadiaNexus.AJ_Levels
    local Renderer = ArcadiaNexus.AJ_Renderer
    local Settings = ArcadiaNexus.AJ_Settings
    local PU       = ArcadiaNexus.AJ_PowerUps
    if not Logic or not Levels or not Renderer or not Settings or not PU then return end

    config = config or {}
    local slot = config.slot or Settings:GetActiveSlot()
    if slot < 1 or slot > Settings.MAX_SLOTS then return end

    local mode = config.mode or "continue"
    local save = Settings:LoadSlot(slot)
    if mode == "continue" and not save then return end

    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen        = _animGen + 1
    _selected       = nil
    _pendingPowerUp = nil
    _moveCount      = 0

    -- ── Slot vorbereiten ────────────────────────────────────────
    if mode == "new" then
        Settings:SaveSlot(slot, {
            level        = 1,
            clearedLevel = 0,
            totalScore   = 0,
            difficulty   = Settings:Get("difficulty"),
            timerActive  = Settings:Get("timerActive"),
            powerUps     = { fire=0, frost=0, chain=0, bomb=0, holy=0 },
            progress     = { fire=0, frost=0, chain=0, bomb=0, holy=0 },
            stars        = {},
            endlessWave     = 0,
            endlessRunScore = 0,
        })
        save = Settings:LoadSlot(slot)
        self:OpenMap(slot, 1)
        return
    end

    local requested = config.level or save.level or 1
    if config.endless then
        return self:StartEndless(config)
    end
    if requested > Levels.COUNT then
        self:OpenMap(slot, Levels.COUNT)
        return
    end

    local levelNum = math.min(requested, Levels.COUNT)
    if not Settings:IsLevelUnlocked(save, levelNum, Levels.COUNT) then
        levelNum = math.min(save.level or 1, Levels.COUNT)
        if not Settings:IsLevelUnlocked(save, levelNum, Levels.COUNT) then
            levelNum = 1
        end
    end
    local levelDef = Levels:GetLevel(levelNum)
    if not levelDef then return end

    -- ── Session ────────────────────────────────────────────────
    local GS = ArcadiaNexus.GameSession
    if E._sessionId and GS:IsCurrent(GAME_ID, E._sessionId) then
        -- Pausierte eigene Session weiterführen
        ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID, E._sessionId)
    else
        E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
    end

    Settings:SetActiveSlot(slot)
    self.activeSlot = slot
    self.totalScore = save.totalScore or 0
    if config.startPowerUps then
        self.powerUps = PU:NewState(config.startPowerUps.inv, config.startPowerUps.progress)
    else
        self.powerUps = PU:NewState(save.powerUps, save.progress)
    end

    -- ── Mid-Level-Resume oder frisches Level ───────────────────
    local mid = (mode == "continue" and not config.skipMid) and Settings:LoadMidLevel(slot) or nil
    if mid and mid.logic and mid.logic.endless then
        mid = nil
    end
    if mid and mid.logic and mid.logic.level == levelNum then
        self.gameState = Logic:Deserialize(mid.logic)
        self.powerUps  = PU:NewState(mid.powerUps or save.powerUps,
                                     mid.progress or save.progress)
        Settings:ClearMidLevel(slot)
    else
        self.gameState = Logic:NewState(levelNum, levelDef, save.difficulty or "easy")
        self.gameState.timerActive = save.timerActive or false
        Logic:InitGrid(self.gameState)
        if not config.startPowerUps then
            self.powerUps = PU:NewState(save.powerUps, save.progress)
        end
    end

    self._playingLevel = levelNum
    self._playingEndless = false
    self._levelStartPU = {
        inv      = CopyInv(self.powerUps and self.powerUps.inv),
        progress = CopyInv(self.powerUps and self.powerUps.progress),
    }

    self.gameState.highScore = GetHighScore(self.gameState.difficulty)
    self.gameState.mapBestStars = Settings:GetStar(save, levelNum)

    E.state = "PLAYING"
    Renderer:OnGameStarted(self.gameState)

    if self.gameState.timerActive then
        self:_StartTimeMode()
    end
    self:_ArmIdleHint()
end

-- Endlos nach Kampagne 100. config: slot, wave, skipMid, startPowerUps, resetRun
function E:StartEndless(config)
    local Logic    = ArcadiaNexus.AJ_Logic
    local Levels   = ArcadiaNexus.AJ_Levels
    local Renderer = ArcadiaNexus.AJ_Renderer
    local Settings = ArcadiaNexus.AJ_Settings
    local PU       = ArcadiaNexus.AJ_PowerUps
    if not Logic or not Levels or not Renderer or not Settings or not PU then return end

    config = config or {}
    local slot = config.slot or self.activeSlot or Settings:GetActiveSlot()
    local save = Settings:LoadSlot(slot)
    if not save or (save.clearedLevel or 0) < Levels.COUNT then
        self:OpenMap(slot, Levels.COUNT)
        return
    end

    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen        = _animGen + 1
    _selected       = nil
    _pendingPowerUp = nil
    _moveCount      = 0

    if config.resetRun then
        save.endlessWave = 1
        save.endlessRunScore = 0
        Settings:ClearMidLevel(slot)
    end

    local wave = math.max(1, tonumber(config.wave) or save.endlessWave or 1)
    local def = Levels:GetEndlessDef(wave)
    if not def or not Levels:ValidateDef(def) then return end

    local GS = ArcadiaNexus.GameSession
    if E._sessionId and GS:IsCurrent(GAME_ID, E._sessionId) then
        ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID, E._sessionId)
    else
        E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
    end

    Settings:SetActiveSlot(slot)
    self.activeSlot = slot
    self.totalScore = save.totalScore or 0
    if config.startPowerUps then
        self.powerUps = PU:NewState(config.startPowerUps.inv, config.startPowerUps.progress)
    else
        self.powerUps = PU:NewState(save.powerUps, save.progress)
    end

    local mid = (not config.skipMid) and Settings:LoadMidLevel(slot) or nil
    if mid and mid.logic and mid.logic.endless and mid.logic.endlessWave == wave then
        self.gameState = Logic:Deserialize(mid.logic)
        self.powerUps  = PU:NewState(mid.powerUps or save.powerUps,
                                     mid.progress or save.progress)
        Settings:ClearMidLevel(slot)
    else
        self.gameState = Logic:NewState(Levels.COUNT, def, save.difficulty or "easy")
        self.gameState.timerActive = save.timerActive or false
        Logic:InitGrid(self.gameState)
        if not config.startPowerUps then
            self.powerUps = PU:NewState(save.powerUps, save.progress)
        end
        Settings:ClearMidLevel(slot)
    end

    self.gameState.endless = true
    self.gameState.endlessWave = wave
    self.gameState.endlessRunScore = save.endlessRunScore or 0
    self.gameState.highScore = GetHighScore(self.gameState.difficulty)
    self.gameState.mapBestStars = 0

    save.endlessWave = wave
    save.timestamp = time()

    self._playingLevel = Levels.COUNT
    self._playingEndless = true
    self._levelStartPU = {
        inv      = CopyInv(self.powerUps and self.powerUps.inv),
        progress = CopyInv(self.powerUps and self.powerUps.progress),
    }

    E.state = "PLAYING"
    Renderer:OnGameStarted(self.gameState)
    if self.gameState.timerActive then
        self:_StartTimeMode()
    end
    self:_ArmIdleHint()
end

-- ============================================================
-- StopGame (Framework-Pflicht)
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen        = _animGen + 1
    _selected       = nil
    _pendingPowerUp = nil
    E.state         = "IDLE"
    self.gameState  = nil
    self.powerUps   = nil

    local R = ArcadiaNexus.AJ_Renderer
    if R then R:EnterIdleState() end
end

-- ============================================================
-- SaveAndPause (Tab schließen / Renderer OnHide)
-- Session bleibt registriert, _sessionId bleibt gesetzt.
-- ============================================================
function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame(GAME_ID, E._sessionId)
    end
    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen        = _animGen + 1
    _selected       = nil
    _pendingPowerUp = nil

    local gs       = self.gameState
    local Settings = ArcadiaNexus.AJ_Settings
    local Logic    = ArcadiaNexus.AJ_Logic
    if gs and Settings and Logic and self.activeSlot then
        local save = Settings:LoadSlot(self.activeSlot)
        if save then
            save.powerUps  = self.powerUps and self.powerUps.inv or save.powerUps
            save.progress  = self.powerUps and self.powerUps.progress or save.progress
            save.timestamp = time()
            if not gs.gameOver then
                -- Laufendes Level einfrieren (Resume beim nächsten Öffnen)
                Settings:SaveMidLevel(self.activeSlot, {
                    logic    = Logic:Serialize(gs),
                    powerUps = self.powerUps and self.powerUps.inv,
                    progress = self.powerUps and self.powerUps.progress,
                })
            end
        end
    end

    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    E.state        = "IDLE"
    self.gameState = nil
end

-- ============================================================
-- Eingabe: Zelle geklickt
-- ============================================================
-- Gültiger Nachbar-Tausch oder Ungültig-Animation. false = kein Tauschversuch.
function E:_AttemptSwap(r1, c1, r2, c2)
    local gs = self.gameState
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    if not gs or not Logic or not R then return false end
    if not Logic:IsAdjacent(r1, c1, r2, c2) then return false end
    if not Logic:IsSwappable(gs, r1, c1) or not Logic:IsSwappable(gs, r2, c2) then
        return false
    end

    local valid, matches, info = Logic:TrySwap(gs, r1, c1, r2, c2)
    _selected = nil
    R:ClearSelection()

    if not valid then
        R:AnimateInvalidSwap(r1, c1, r2, c2, function()
            local R2 = ArcadiaNexus.AJ_Renderer
            if R2 then R2:ShowHint(Loc()["hint_invalid"]) end
            E:_ArmIdleHint()
        end)
        return true
    end

    _moveCount = _moveCount + 1
    if (gs.movesLeft or 0) >= 1 and (gs.movesLeft or 0) <= 3 then
        PlayAJ("lowmoves")
    end
    E.state = "ANIMATING"
    local myGen = _animGen
    R:AnimateSwap(r1, c1, r2, c2, gs, function()
        if myGen ~= _animGen then return end
        self:_ProcessCascade(gs, matches, info, myGen)
    end)
    return true
end

-- Ziehen auf den Nachbarn (Klick-Auswahl bleibt separat).
function E:OnCellDrag(r1, c1, r2, c2)
    if E.state == "POWERUP_TARGETING" or E.state ~= "PLAYING" then return end
    self:_CancelIdleHint()
    local gs = self.gameState
    if not gs or gs.gameOver then return end
    if self:_AttemptSwap(r1, c1, r2, c2) then return end
    -- Nicht benachbart / nicht tauschbar: Zielzelle wie Klick behandeln.
    self:OnCellClick(r2, c2, "LeftButton", false)
end

function E:OnCellClick(row, col, button, isShift)
    if E.state == "POWERUP_TARGETING" then
        if button == "RightButton" then
            self:CancelTargeting()
        else
            self:_ApplyPendingPowerUp(row, col, isShift)
        end
        return
    end

    if E.state ~= "PLAYING" then return end
    self:_CancelIdleHint()
    if button == "RightButton" then
        self:_ArmIdleHint()
        return
    end
    local gs = self.gameState
    if not gs or gs.gameOver then return end

    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local L     = Loc()
    if not Logic or not R then return end

    if not Logic:IsSwappable(gs, row, col) then
        self:_ArmIdleHint()
        return
    end

    if not _selected then
        _selected = { row = row, col = col }
        R:SetSelection(row, col)
        R:ShowHint(L["hint_swap"])
        self:_ArmIdleHint()
        return
    end

    local r1, c1 = _selected.row, _selected.col
    if r1 == row and c1 == col then
        _selected = nil
        R:ClearSelection()
        R:ShowHint(L["hint_select"])
        self:_ArmIdleHint()
        return
    end
    if self:_AttemptSwap(r1, c1, row, col) then return end

    _selected = { row = row, col = col }
    R:SetSelection(row, col)
    self:_ArmIdleHint()
end

-- ============================================================
-- Kaskade
-- ============================================================
function E:_ProcessCascade(gs, matches, info, myGen)
    if myGen ~= _animGen then return end
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local PU    = ArcadiaNexus.AJ_PowerUps
    local L     = Loc()
    if not Logic or not R or not PU then return end

    local iceKeys = Logic.CollectAdjacentIce and Logic:CollectAdjacentIce(gs, matches) or {}
    local removed, gained = Logic:RemoveMatches(gs, matches, info)
    if removed == 0 then
        E.state = "PLAYING"
        R:UpdateHUD(gs)
        R:ShowHint(L["hint_select"])
        self:_CheckEndOfTurn(gs)
        return
    end

    PlayAJ("match")

    -- ── PowerUp-Aufladung ───────────────────────────────────────
    local charged = {}
    local function merge(list)
        for _, id in ipairs(list) do charged[#charged+1] = id end
    end
    merge(PU:OnScoreGained(self.powerUps, gained))
    merge(PU:OnComboStep(self.powerUps, gs.comboCount))
    if info then
        for _, run in ipairs(info.runs or {}) do
            if run.len >= 5 then
                merge(PU:OnFivePlusMatch(self.powerUps))
                break
            end
        end
    end
    R:UpdatePowerUpBar(self.powerUps)
    for _, id in ipairs(charged) do
        R:OnPowerUpCharged(id)
    end

    R:UpdateHUD(gs)
    if gs.comboCount > 1 then R:ShowCombo(gs.comboCount) end
    if R.ShowImpactFx then R:ShowImpactFx(gained, gs.comboCount, matches) end

    R:AnimatePulseAndFade(matches, gs, function()
        if myGen ~= _animGen then return end
        local fallInfo = Logic:ApplyGravity(gs)
        R:AnimateFall(fallInfo, gs, function()
            if myGen ~= _animGen then return end
            local newMatches, newInfo = Logic:FindMatches(gs)
            if next(newMatches) then
                self:_ProcessCascade(gs, newMatches, newInfo, myGen)
            else
                gs.comboCount = 0
                E.state = "PLAYING"
                R:UpdateHUD(gs)
                R:HideCombo()
                self:_CheckEndOfTurn(gs)
            end
        end)
    end, { iceKeys = iceKeys, combo = gs.comboCount })
end

-- ── Nach stabilem Board: Ziel / Züge / Zeit / Softlock prüfen ──
function E:_CheckEndOfTurn(gs)
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local L     = Loc()

    if Logic:IsGoalMet(gs) then
        gs.gameOver = true
        gs.won = true
        self:_HandleLevelComplete()
        return
    end
    if gs.timerActive and Logic:CheckTimeout(gs) then
        self:_HandleGameOver()
        return
    end
    if Logic:CheckGameOver(gs) then
        self:_HandleGameOver()
        return
    end
    if not Logic:HasPossibleMoves(gs) then
        self:_DoShuffle(gs)
    else
        if R then
            R:ShowHint(L["hint_select"])
            self:_ArmIdleHint()
        end
    end
end

-- ── Auto-Shuffle (Softlock-Schutz) ─────────────────────────────
function E:_DoShuffle(gs)
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local L     = Loc()
    if not Logic or not R then return end

    R:ShowHint(L["hint_shuffle"])
    E.state = "ANIMATING"

    _timerGuard:After(0.8, function()
        if E.state ~= "ANIMATING" then return end
        Logic:ShuffleBoard(gs)
        E.state = "PLAYING"
        R:DrawGrid(gs)
        R:ShowHint(L["hint_select"])
        E:_ArmIdleHint()
    end)
end

-- ============================================================
-- PowerUps
-- ============================================================
function E:OnPowerUpClick(id)
    if E.state ~= "PLAYING" and E.state ~= "POWERUP_TARGETING" then return end
    self:_CancelIdleHint()
    local PU = ArcadiaNexus.AJ_PowerUps
    local R  = ArcadiaNexus.AJ_Renderer
    local gs = self.gameState
    if not PU or not R or not gs or gs.gameOver then return end
    if not PU:CanUse(self.powerUps, id) then return end

    local def = PU.DEFS[id]
    if not def.needsTarget then
        -- Heiliger Strahl: sofort anwenden
        if E.state == "POWERUP_TARGETING" then self:CancelTargeting() end
        PU:Consume(self.powerUps, id)
        local result = PU:Apply(gs, id)
        PlayAJ("powerup")
        R:UpdatePowerUpBar(self.powerUps)
        self:_AfterPowerUp(gs, result)
        return
    end

    _pendingPowerUp = id
    _selected = nil
    R:ClearSelection()
    E.state = "POWERUP_TARGETING"
    R:EnterTargetingMode(id)
end

function E:CancelTargeting()
    if E.state ~= "POWERUP_TARGETING" then return end
    _pendingPowerUp = nil
    E.state = "PLAYING"
    local R = ArcadiaNexus.AJ_Renderer
    if R then R:ExitTargetingMode() end
    self:_ArmIdleHint()
end

--- Renderer-Hover: Wirkungsbereich für Highlight.
function E:GetPowerUpPreview(row, col, isShift)
    if E.state ~= "POWERUP_TARGETING" or not _pendingPowerUp then return nil end
    local PU = ArcadiaNexus.AJ_PowerUps
    local gs = self.gameState
    if not PU or not gs then return nil end
    local target = { row = row, col = col,
                     axis = (_pendingPowerUp == "frost" and isShift) and "col" or "row" }
    if not PU:IsValidTarget(gs, _pendingPowerUp, target) then return nil end
    return PU:GetTargetCells(gs, _pendingPowerUp, target)
end

function E:_ApplyPendingPowerUp(row, col, isShift)
    local id = _pendingPowerUp
    local PU = ArcadiaNexus.AJ_PowerUps
    local R  = ArcadiaNexus.AJ_Renderer
    local gs = self.gameState
    if not id or not PU or not R or not gs then return end

    local target = { row = row, col = col,
                     axis = (id == "frost" and isShift) and "col" or "row" }
    if not PU:IsValidTarget(gs, id, target) then return end

    _pendingPowerUp = nil
    R:ExitTargetingMode()
    PU:Consume(self.powerUps, id)
    local result = PU:Apply(gs, id, target)
    PlayAJ("powerup")
    R:UpdatePowerUpBar(self.powerUps)
    self:_AfterPowerUp(gs, result)
end

--- Gemeinsamer Abschluss: Animation + Gravitation + Kaskade.
function E:_AfterPowerUp(gs, result)
    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local PU    = ArcadiaNexus.AJ_PowerUps

    -- Punkte aus dem PowerUp laden die Score-PowerUps weiter auf
    if result.gainedScore and result.gainedScore > 0 then
        local charged = PU:OnScoreGained(self.powerUps, result.gainedScore)
        R:UpdatePowerUpBar(self.powerUps)
        for _, cid in ipairs(charged) do R:OnPowerUpCharged(cid) end
    end

    E.state = "ANIMATING"
    local myGen = _animGen
    R:UpdateHUD(gs)

    if result.gainedScore and result.gainedScore > 0 and R.ShowImpactFx then
        R:ShowImpactFx(result.gainedScore, 1, result.removedKeys)
    end

    local function afterRemoval()
        if myGen ~= _animGen then return end
        local fallInfo = Logic:ApplyGravity(gs)
        R:AnimateFall(fallInfo, gs, function()
            if myGen ~= _animGen then return end
            local newMatches, newInfo = Logic:FindMatches(gs)
            if next(newMatches) then
                gs.comboCount = 0
                self:_ProcessCascade(gs, newMatches, newInfo, myGen)
            else
                E.state = "PLAYING"
                R:UpdateHUD(gs)
                self:_CheckEndOfTurn(gs)
            end
        end)
    end

    if result.removedKeys and next(result.removedKeys) then
        R:AnimatePowerUpRemoval(result.removedKeys, gs, afterRemoval)
    elseif result.converted and #result.converted > 0 then
        R:AnimateWildcardConversion(result.converted, gs, function()
            if myGen ~= _animGen then return end
            local newMatches, newInfo = Logic:FindMatches(gs)
            if next(newMatches) then
                gs.comboCount = 0
                self:_ProcessCascade(gs, newMatches, newInfo, myGen)
            else
                E.state = "PLAYING"
                R:UpdateHUD(gs)
                self:_CheckEndOfTurn(gs)
            end
        end)
    else
        afterRemoval()
    end
end

-- ============================================================
-- Level geschafft
-- ============================================================
function E:_HandleLevelComplete()
    local gs       = self.gameState
    local Settings = ArcadiaNexus.AJ_Settings
    local Levels   = ArcadiaNexus.AJ_Levels
    local Logic    = ArcadiaNexus.AJ_Logic
    local R        = ArcadiaNexus.AJ_Renderer
    if not gs then return end

    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen = _animGen + 1
    E.state  = "LEVEL_COMPLETE"

    local isEndless = gs.endless == true
    local isFinal = (not isEndless) and gs.level >= Levels.COUNT
    self.totalScore = self.totalScore + gs.score

    local prevSave = Settings:LoadSlot(self.activeSlot) or {}
    local stars = Settings:CopyStars(prevSave.stars)
    local grade, prevStar = 0, 0
    if not isEndless then
        prevStar = stars[gs.level] or 0
        grade = Logic:GradeStars(gs)
        stars[gs.level] = math.max(prevStar, grade)
        gs.lastStars = grade
        gs.bestStars = stars[gs.level]
    else
        gs.lastStars = 0
        gs.bestStars = 0
    end

    local cleared = math.max(tonumber(prevSave.clearedLevel) or 0, isEndless and (prevSave.clearedLevel or 0) or gs.level)
    local cursor = tonumber(prevSave.level) or 1
    if not isEndless and gs.level >= (tonumber(prevSave.clearedLevel) or 0) then
        cursor = gs.level + 1
    end

    local wave = gs.endlessWave or 0
    local runScore = (prevSave.endlessRunScore or 0) + (isEndless and gs.score or 0)
    if isEndless then
        gs.endlessRunScore = runScore
        Settings:NoteEndlessBest(wave)
        Settings:AddStats({ totalEndlessWaves = 1 })
    end

    Settings:AddStats({
        totalLevels   = isEndless and 0 or 1,
        totalPowerUps = gs.stats.powerUpsUsed,
        totalIce      = gs.stats.iceDestroyed,
        totalTimeWins = (not isEndless and gs.timerActive) and 1 or 0,
        totalCombo5   = (gs.maxCombo >= 5) and 1 or 0,
        totalStars    = isEndless and 0 or math.max(0, stars[gs.level] - prevStar),
    })
    local totals = Settings:GetStats()

    Settings:SaveSlot(self.activeSlot, {
        level        = cursor,
        clearedLevel = cleared,
        totalScore   = self.totalScore,
        difficulty   = gs.difficulty,
        timerActive  = gs.timerActive,
        powerUps     = self.powerUps.inv,
        progress     = self.powerUps.progress,
        stars        = stars,
        endlessWave     = isEndless and (wave + 1) or (prevSave.endlessWave or 0),
        endlessRunScore = isEndless and runScore or (prevSave.endlessRunScore or 0),
    })

    -- Leaderboard-Score: hard × 1,5 (GDD §3.3 – nur Leaderboard)
    local lbScore = gs.score
    if gs.difficulty == "hard" then
        lbScore = math.floor(lbScore * 1.5 + 0.5)
    end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = GAME_ID,
        difficulty = gs.difficulty,
        score      = lbScore,
        result     = "WIN",
        stats      = {
            levelReached    = gs.level,
            levelsCompleted = totals.totalLevels,
            maxCombo        = gs.maxCombo,
            powerUpsUsed    = gs.stats.powerUpsUsed,
            iceDestroyed    = gs.stats.iceDestroyed,
            timeMode        = gs.timerActive,
            stars           = gs.lastStars,
            bestStars       = gs.bestStars,
            totalStars      = totals.totalStars,
            endlessWave     = isEndless and wave or nil,
            endlessBestWave = totals.endlessBestWave,
        },
    })

    PlayAJ("win")
    if R then
        if isEndless then
            R:ShowEndlessWaveWin(gs, self.totalScore)
        elseif isFinal then
            R:ShowFinalWin(gs, self.totalScore)
        else
            R:ShowLevelWin(gs, self.totalScore)
        end
    end
end

function E:OpenMap(slot, focusLevel)
    local Settings = ArcadiaNexus.AJ_Settings
    local Renderer = ArcadiaNexus.AJ_Renderer
    if not Settings or not Renderer then return end
    slot = slot or self.activeSlot or Settings:GetActiveSlot()
    local save = Settings:LoadSlot(slot)
    if not save then return end

    self:_CancelIdleHint()
    _timerGuard:Cancel()
    _gameLoop:Stop()
    _animGen = _animGen + 1
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    Settings:SetActiveSlot(slot)
    self.activeSlot = slot
    self.totalScore = save.totalScore or 0
    self.gameState  = nil
    E.state = "MAP"
    Renderer:ShowLevelMap(save, focusLevel)
end

function E:SelectMapLevel(level)
    if E.state ~= "MAP" then return end
    self:StartGame({
        slot    = self.activeSlot,
        mode    = "continue",
        level   = level,
        skipMid = true,
    })
end

function E:MapBackToSlots()
    if E.state ~= "MAP" then return end
    E.state = "IDLE"
    local R = ArcadiaNexus.AJ_Renderer
    if R then R:EnterSlotMenu() end
end

-- ── Weiter: zurück zur Karte ──────────────────────────────────
function E:SelectEndless()
    if E.state ~= "MAP" then return end
    self:StartEndless({
        slot     = self.activeSlot,
        skipMid  = true,
        resetRun = false,
    })
end

function E:ContinueToNextLevel()
    if E.state ~= "LEVEL_COMPLETE" then return end
    local gs = self.gameState
    if gs and gs.endless then
        self:StartEndless({
            slot    = self.activeSlot,
            wave    = (gs.endlessWave or 1) + 1,
            skipMid = true,
        })
        return
    end
    local nextLevel = gs and (gs.level + 1) or 1
    self:OpenMap(self.activeSlot, nextLevel)
end

function E:ContinueCampaign()
    local Settings = ArcadiaNexus.AJ_Settings
    local Levels   = ArcadiaNexus.AJ_Levels
    if not Settings or not Levels or not self.activeSlot then return end
    local save = Settings:LoadSlot(self.activeSlot)
    if not save then return end
    local nextLevel = math.max((save.clearedLevel or save.level or 1) + 1, 1)
    if nextLevel > Levels.COUNT then nextLevel = Levels.COUNT end
    save.midLevel = nil
    self:OpenMap(self.activeSlot, nextLevel)
end

function E:RestartLevel()
    if self._playingEndless or (self.gameState and self.gameState.endless) then
        local wave = self.gameState and self.gameState.endlessWave or 1
        self:StartEndless({
            slot          = self.activeSlot,
            wave          = wave,
            skipMid       = true,
            startPowerUps = self._levelStartPU,
        })
        return
    end
    local lvl = self._playingLevel
        or (self.gameState and self.gameState.level)
    self:StartGame({
        slot          = self.activeSlot,
        mode          = "continue",
        level         = lvl,
        skipMid       = true,
        startPowerUps = self._levelStartPU,
    })
end

-- ============================================================
-- Game Over
-- ============================================================
function E:_HandleGameOver()
    local gs = self.gameState
    if not gs or E.state == "IDLE" or E.state == "GAMEOVER" then return end

    _timerGuard:Cancel()
    _idleGuard:Cancel()
    _gameLoop:Stop()
    _animGen = _animGen + 1
    E.state  = "GAMEOVER"

    local Settings = ArcadiaNexus.AJ_Settings

    -- Inventar/Fortschritt behalten, Mid-Level verwerfen (Level wird wiederholt)
    local save = Settings:LoadSlot(self.activeSlot)
    if save then
        save.powerUps  = self.powerUps.inv
        save.progress  = self.powerUps.progress
        save.midLevel  = nil
        save.timestamp = time()
    end

    Settings:AddStats({
        totalPowerUps = gs.stats.powerUpsUsed,
        totalIce      = gs.stats.iceDestroyed,
        totalCombo5   = (gs.maxCombo >= 5) and 1 or 0,
    })

    if _moveCount > 0 or gs.score > 0 then
        local lbScore = gs.score
        if gs.difficulty == "hard" then
            lbScore = math.floor(lbScore * 1.5 + 0.5)
        end
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = GAME_ID,
            difficulty = gs.difficulty,
            score      = lbScore,
            result     = "LOSS",
            stats      = {
                levelReached    = gs.level,
                levelsCompleted = Settings:GetStats().totalLevels,
                maxCombo        = gs.maxCombo,
                powerUpsUsed    = gs.stats.powerUpsUsed,
                iceDestroyed    = gs.stats.iceDestroyed,
                timeMode        = gs.timerActive,
                endlessWave     = gs.endless and gs.endlessWave or nil,
                endlessBestWave = Settings:GetStats().endlessBestWave,
            },
        })
    end

    PlayAJ("loss")
    local R = ArcadiaNexus.AJ_Renderer
    if R then R:ShowGameOver(gs) end
end
