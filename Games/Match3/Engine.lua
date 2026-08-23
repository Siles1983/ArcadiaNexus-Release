-- ============================================================
--  Match3 – Engine.lua
--  v1.0.2 – Bugfix
--
--  Fixes:
--  - FireEvent → Emit (korrektes Framework-API)
--  - Timer läuft auch während "ANIMATING" (stoppt nicht bei Match)
--  - result "WIN"/"LOSS" uppercase (wie ScoreManager erwartet)
-- ============================================================

ArcadiaNexus.M3_Engine = {}
local E = ArcadiaNexus.M3_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
local _animGen    = 0
local _selected   = nil

-- ── Highscore (ScoreManager) ──────────────────────────────────
local function GetHighScore(difficulty)
    local SM = ArcadiaNexus.ScoreManager
    if SM then return SM:GetBestScore("MATCH3", difficulty) end
    return 0
end

-- ── StartGame ──────────────────────────────────────────────────
function E:StartGame(difficulty)
    if E.state == "ANIMATING" then return end
    _timerGuard:Cancel()
    _animGen  = _animGen + 1
    _selected = nil

    local Logic    = ArcadiaNexus.M3_Logic
    local Renderer = ArcadiaNexus.M3_Renderer
    local Settings = ArcadiaNexus.M3_Settings
    local Themes   = ArcadiaNexus.M3_Themes

    if not Logic or not Renderer then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("MATCH3", E._sessionId)

    local diff        = difficulty or (Settings and Settings:Get("difficulty")) or "easy"
    local theme       = (Settings and Settings:Get("theme")) or "raidmarker"
    local timerActive = (Settings and Settings:Get("timerActive")) or false

    self.gameState = Logic:NewState(diff)
    self.gameState.timerActive = timerActive
    self.gameState.gemCount    = Themes and Themes:GetGemCount(theme) or 7
    self.gameState.theme       = theme
    self.gameState.highScore   = GetHighScore(diff)
    Logic:InitGrid(self.gameState)

    E.state = "PLAYING"
    Renderer:OnGameStarted(self.gameState)

    if timerActive then self:_StartTimer() end
end

-- ── StopGame (Framework-Pflicht) ───────────────────────────────
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("MATCH3", E._sessionId)
        E._sessionId = nil
    end
    _timerGuard:Cancel()
    _animGen  = _animGen + 1
    _selected = nil
    E.state   = "IDLE"
    self.gameState = nil
    local R = ArcadiaNexus.M3_Renderer
    if R then R:EnterIdleState() end
end

-- ── Timer ──────────────────────────────────────────────────────
-- BUG FIX: Timer läuft auch während "ANIMATING" durch.
-- Vorher: E.state ~= "PLAYING" → abbrechen → Timer stoppte bei jedem Match.
-- Fix: Nur bei "IDLE" und "GAMEOVER" abbrechen.
function E:_StartTimer()
    _timerGuard:EveryAfter(1, function()
        if E.state == "IDLE" or E.state == "GAMEOVER" then return false end
        local gs = self.gameState
        if not gs or not gs.timerActive then return false end
        local Logic = ArcadiaNexus.M3_Logic
        local R     = ArcadiaNexus.M3_Renderer
        if not Logic then return false end
        Logic:TickTimer(gs, 1)
        if R then R:UpdateHUD(gs) end
        if Logic:CheckTimeout(gs) then
            self:_HandleGameOver()
            return false
        end
        return true
    end)
end

-- ── Input: Zelle geklickt ──────────────────────────────────────
function E:OnCellClick(row, col)
    if E.state ~= "PLAYING" then return end
    local gs = self.gameState
    if not gs or gs.gameOver then return end

    local Logic    = ArcadiaNexus.M3_Logic
    local R        = ArcadiaNexus.M3_Renderer
    local Settings = ArcadiaNexus.M3_Settings
    local L        = ArcadiaNexus.GetLocaleTable("MATCH3")
    if not Logic or not R then return end

    if not _selected then
        _selected = { row = row, col = col }
        R:SetSelection(row, col)
        R:ShowHint(L["hint_swap"])
        if Settings and Settings:Get("soundEnabled") and Settings:Get("soundOnMove") then
            PlaySoundFile("Interface\\Buttons\\UI-CheckBox-Up.ogg", "Master")
        end
    else
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
        local valid, matches = Logic:TrySwap(gs, r1, c1, row, col)
        _selected = nil
        R:ClearSelection()
        if not valid then
            R:AnimateInvalidSwap(r1, c1, row, col, function()
                if ArcadiaNexus.M3_Renderer then
                    ArcadiaNexus.M3_Renderer:ShowHint(L["hint_invalid"])
                end
            end)
            return
        end
        E.state = "ANIMATING"
        local myGen = _animGen
        R:AnimateSwap(r1, c1, row, col, gs, function()
            if myGen ~= _animGen then return end
            self:_ProcessCascade(gs, matches, myGen)
        end)
    end
end

-- ── Kaskade ────────────────────────────────────────────────────
function E:_ProcessCascade(gs, matches, myGen)
    if myGen ~= _animGen then return end
    local Logic    = ArcadiaNexus.M3_Logic
    local R        = ArcadiaNexus.M3_Renderer
    local Settings = ArcadiaNexus.M3_Settings
    local L        = ArcadiaNexus.GetLocaleTable("MATCH3")
    if not Logic or not R then return end

    local matchCount = Logic:RemoveMatches(gs, matches)
    if matchCount == 0 then
        E.state = "PLAYING"
        R:UpdateHUD(gs)
        R:ShowHint(L["hint_select"])
        if Logic:CheckGameOver(gs) then self:_HandleGameOver() end
        return
    end

    if Settings and Settings:Get("soundEnabled") and Settings:Get("soundOnMatch") then
        PlaySoundFile("Sound\\Spells\\ShiningRay.ogg", "Master")
    end

    R:UpdateHUD(gs)
    if gs.comboCount > 1 then R:ShowCombo(gs.comboCount) end

    R:AnimatePulseAndFade(matches, gs, function()
        if myGen ~= _animGen then return end
        local fallInfo = Logic:ApplyGravity(gs)
        R:AnimateFall(fallInfo, gs, function()
            if myGen ~= _animGen then return end
            local newMatches = Logic:FindMatches(gs)
            if next(newMatches) then
                self:_ProcessCascade(gs, newMatches, myGen)
            else
                gs.comboCount = 0
                E.state = "PLAYING"
                R:UpdateHUD(gs)
                R:HideCombo()
                -- Kein Match mehr möglich → Auto-Shuffle (kein Game Over wegen Softlock)
                if not Logic:HasPossibleMoves(gs) and not Logic:CheckGameOver(gs) then
                    self:_DoShuffle(gs)
                else
                    R:ShowHint(L["hint_select"])
                    if Logic:CheckGameOver(gs) then self:_HandleGameOver() end
                end
            end
        end)
    end)
end

-- ── Auto-Shuffle ───────────────────────────────────────────────
function E:_DoShuffle(gs)
    local Logic    = ArcadiaNexus.M3_Logic
    local R        = ArcadiaNexus.M3_Renderer
    local L        = ArcadiaNexus.GetLocaleTable("MATCH3")
    if not Logic or not R then return end

    R:ShowHint(L["hint_shuffle"] or "Board wird gemischt...")
    E.state = "ANIMATING"

    _timerGuard:After(0.8, function()
        if E.state ~= "ANIMATING" then return end
        Logic:ShuffleBoard(gs)
        E.state = "PLAYING"
        R:_DrawGrid(gs)
        R:ShowHint(L["hint_select"])
    end)
end

-- ── Game Over ──────────────────────────────────────────────────
-- BUG FIX: FireEvent → Emit (korrektes Framework-API)
-- BUG FIX: result "WIN"/"LOSS" uppercase (ScoreManager erwartet uppercase)
function E:_HandleGameOver()
    if E.state == "IDLE" then return end
    _timerGuard:Cancel()
    _animGen  = _animGen + 1
    E.state   = "GAMEOVER"
    local gs = self.gameState
    if not gs then return end
    if gs.score > (gs.highScore or 0) then gs.highScore = gs.score end

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "MATCH3",
        result     = gs.won and "WIN" or "LOSS",
        score      = gs.score,
        difficulty = gs.difficulty,
        stats      = {
            maxCombo = gs.maxCombo or 0,
        },
    })

    local Settings = ArcadiaNexus.M3_Settings
    if Settings and Settings:Get("soundEnabled") and Settings:Get("soundOnGameover") then
        if gs.won then
            PlaySoundFile("Sound\\Spells\\ShiningRay.ogg", "Master")
        else
            PlaySoundFile("Sound\\Doodad\\BellTollHorde.ogg", "Master")
        end
    end
    local R = ArcadiaNexus.M3_Renderer
    if R then R:ShowGameOver(gs) end
end
