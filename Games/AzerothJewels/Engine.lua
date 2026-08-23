-- ============================================================
--  Azeroth Jewels – Engine.lua
--  State-Machine, Lifecycle, Timer, PowerUp-Fluss, GAME_RESULT.
--  KEINE UI-Frames (Renderer), KEINE Spielregeln (Logic).
--
--  States: IDLE | PLAYING | ANIMATING | POWERUP_TARGETING
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

local function PlayAJ(event)
    local S = ArcadiaNexus.AJ_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "match" and S:Get("soundOnMatch") then
        PlaySoundFile("Sound\\Spells\\ShiningRay.ogg", "Master")
    elseif event == "powerup" and S:Get("soundOnPowerup") then
        PlaySound(SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or 63971, "SFX")
    elseif event == "win" and S:Get("soundOnGameover") then
        PlaySound(SOUNDKIT.READY_CHECK or 8960, "SFX")
    elseif event == "loss" and S:Get("soundOnGameover") then
        PlaySoundFile("Sound\\Doodad\\BellTollHorde.ogg", "Master")
    end
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
--            new:      Slot wird (nach Renderer-Confirm) überschrieben
--            continue: Slot laden; Mid-Level-Resume falls vorhanden
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
    _gameLoop:Stop()
    _animGen        = _animGen + 1
    _selected       = nil
    _pendingPowerUp = nil
    _moveCount      = 0

    -- ── Slot vorbereiten ────────────────────────────────────────
    if mode == "new" then
        Settings:SaveSlot(slot, {
            level       = 1,
            totalScore  = 0,
            difficulty  = Settings:Get("difficulty"),
            timerActive = Settings:Get("timerActive"),
            powerUps    = { fire=0, frost=0, chain=0, bomb=0, holy=0 },
            progress    = { fire=0, frost=0, chain=0, bomb=0, holy=0 },
        })
        save = Settings:LoadSlot(slot)
    end

    local levelNum = math.min(save.level or 1, Levels.COUNT)
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
    self.powerUps   = PU:NewState(save.powerUps, save.progress)

    -- ── Mid-Level-Resume oder frisches Level ───────────────────
    local mid = (mode == "continue") and Settings:LoadMidLevel(slot) or nil
    if mid and mid.logic and mid.logic.level == levelNum then
        self.gameState = Logic:Deserialize(mid.logic)
        self.powerUps  = PU:NewState(mid.powerUps or save.powerUps,
                                     mid.progress or save.progress)
        Settings:ClearMidLevel(slot)
    else
        self.gameState = Logic:NewState(levelNum, levelDef, save.difficulty or "easy")
        self.gameState.timerActive = save.timerActive or false
        Logic:InitGrid(self.gameState)
    end

    self.gameState.highScore = GetHighScore(self.gameState.difficulty)

    E.state = "PLAYING"
    Renderer:OnGameStarted(self.gameState)

    if self.gameState.timerActive then
        self:_StartTimeMode()
    end
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
    if button == "RightButton" then return end
    local gs = self.gameState
    if not gs or gs.gameOver then return end

    local Logic = ArcadiaNexus.AJ_Logic
    local R     = ArcadiaNexus.AJ_Renderer
    local L     = Loc()
    if not Logic or not R then return end

    if not Logic:IsSwappable(gs, row, col) then return end

    if not _selected then
        _selected = { row = row, col = col }
        R:SetSelection(row, col)
        R:ShowHint(L["hint_swap"])
        return
    end

    local r1, c1 = _selected.row, _selected.col
    if r1 == row and c1 == col then
        _selected = nil
        R:ClearSelection()
        R:ShowHint(L["hint_select"])
        return
    end
    if not Logic:IsAdjacent(r1, c1, row, col) then
        _selected = { row = row, col = col }
        R:SetSelection(row, col)
        return
    end

    local valid, matches, info = Logic:TrySwap(gs, r1, c1, row, col)
    _selected = nil
    R:ClearSelection()

    if not valid then
        R:AnimateInvalidSwap(r1, c1, row, col, function()
            local R2 = ArcadiaNexus.AJ_Renderer
            if R2 then R2:ShowHint(Loc()["hint_invalid"]) end
        end)
        return
    end

    _moveCount = _moveCount + 1
    E.state = "ANIMATING"
    local myGen = _animGen
    R:AnimateSwap(r1, c1, row, col, gs, function()
        if myGen ~= _animGen then return end
        self:_ProcessCascade(gs, matches, info, myGen)
    end)
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
    end)
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
        if R then R:ShowHint(L["hint_select"]) end
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
    end)
end

-- ============================================================
-- PowerUps
-- ============================================================
function E:OnPowerUpClick(id)
    if E.state ~= "PLAYING" and E.state ~= "POWERUP_TARGETING" then return end
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
    local R        = ArcadiaNexus.AJ_Renderer
    if not gs then return end

    _timerGuard:Cancel()
    _gameLoop:Stop()
    _animGen = _animGen + 1
    E.state  = "LEVEL_COMPLETE"

    local isFinal = gs.level >= Levels.COUNT
    self.totalScore = self.totalScore + gs.score

    -- Kumulative Achievement-Zähler
    Settings:AddStats({
        totalLevels   = 1,
        totalPowerUps = gs.stats.powerUpsUsed,
        totalIce      = gs.stats.iceDestroyed,
        totalTimeWins = gs.timerActive and 1 or 0,
        totalCombo5   = (gs.maxCombo >= 5) and 1 or 0,
    })
    local totals = Settings:GetStats()

    -- Auto-Save in den aktiven Slot (nächstes Level, Inventar, kein MidLevel)
    Settings:SaveSlot(self.activeSlot, {
        level       = isFinal and gs.level or (gs.level + 1),
        totalScore  = self.totalScore,
        difficulty  = gs.difficulty,
        timerActive = gs.timerActive,
        powerUps    = self.powerUps.inv,
        progress    = self.powerUps.progress,
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
        },
    })

    PlayAJ("win")
    if R then
        if isFinal then
            R:ShowFinalWin(gs, self.totalScore)
        else
            R:ShowLevelWin(gs, self.totalScore)
        end
    end
end

-- ── Weiter zum nächsten Level (Renderer-Button) ────────────────
function E:ContinueToNextLevel()
    if E.state ~= "LEVEL_COMPLETE" then return end
    self:StartGame({ slot = self.activeSlot, mode = "continue" })
end

-- ── Aktuelles Level neu starten (Retry / "Level neu starten") ──
function E:RestartLevel()
    self:StartGame({ slot = self.activeSlot, mode = "continue" })
end

-- ============================================================
-- Game Over
-- ============================================================
function E:_HandleGameOver()
    local gs = self.gameState
    if not gs or E.state == "IDLE" or E.state == "GAMEOVER" then return end

    _timerGuard:Cancel()
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
            },
        })
    end

    PlayAJ("loss")
    local R = ArcadiaNexus.AJ_Renderer
    if R then R:ShowGameOver(gs) end
end
