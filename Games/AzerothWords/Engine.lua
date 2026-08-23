-- Games/AzerothWords/Engine.lua
--
-- State-Machine: IDLE → PLAYING → RESULT_WIN / RESULT_LOSS
--
-- KEIN OnUpdate-Loop – rein event-getrieben.
-- C_Timer.After NUR für Reveal-Animation (kurze Delays).
-- _revealGen verhindert veraltete Reveal-Callbacks.

ArcadiaNexus.WRD_Engine = {}
local E = ArcadiaNexus.WRD_Engine

E._sessionId = nil

E.state       = "IDLE"
E._gameState  = nil
E._revealGen  = 0   -- verhindert veraltete C_Timer-Callbacks

-- Sound-IDs (direkte Integer – kein SOUNDKIT-nil-Risiko)
local SND_REVEAL  = 850    -- IG_MAINMENU_OPTION_CHECKBOX_ON
local SND_CORRECT = 888    -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_WIN     = 1115   -- UI_GARRISON_MISSION_COMPLETE
local SND_LOSE    = 847    -- IG_QUEST_ABANDON
local SND_INVALID = 847    -- INTERFACE_SOUND_LOST_TARGET_UNIT

local function GetLogic()    return ArcadiaNexus.WRD_Logic    end
local function GetRenderer() return ArcadiaNexus.WRD_Renderer end
local function GetSettings() return ArcadiaNexus.WRD_Settings end

local function PlayWRD(key, id)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    if not S:Get(key) then return end
    PlaySound(id, "Master")
end

-- ============================================================
-- SPIELSTART
-- ============================================================
function E:StartGame(difficulty)
    local Logic = GetLogic()
    local R     = GetRenderer()
    if not Logic or not R then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("AZEROTHWORDS", E._sessionId)

    -- Laufende Reveal-Callbacks invalidieren
    E._revealGen = E._revealGen + 1

    local diff = difficulty or "normal"
    local gs   = Logic:NewState(diff)
    self._gameState = gs
    E.state = "PLAYING"

    R:OnGameStarted(gs)
    R:EnableKeyboard(true)
end

-- ============================================================
-- INPUT-HANDLER
-- ============================================================
function E:HandleInput(action, value)
    if E.state ~= "PLAYING" then return end
    local gs = self._gameState
    if not gs then return end

    local R     = GetRenderer()
    local Logic = GetLogic()

    if action == "LETTER" then
        if #gs.currentGuess < gs.wordLength then
            gs.currentGuess = gs.currentGuess .. value:upper()
            if R then R:UpdateCurrentRow(gs) end
        end

    elseif action == "BACKSPACE" then
        if #gs.currentGuess > 0 then
            gs.currentGuess = gs.currentGuess:sub(1, -2)
            if R then R:UpdateCurrentRow(gs) end
        end

    elseif action == "CONFIRM" then
        self:_SubmitGuess()
    end
end

-- ============================================================
-- GUESS EINREICHEN
-- ============================================================
function E:_SubmitGuess()
    local gs    = self._gameState
    local Logic = GetLogic()
    local R     = GetRenderer()
    if not gs or not Logic or not R then return end

    local guess = gs.currentGuess

    -- Länge prüfen
    if #guess < gs.wordLength then
        R:ShakeCurrentRow()
        PlayWRD("soundEnabled", SND_INVALID)
        return
    end

    -- WordList-Validierung
    if not Logic:IsValidWord(guess, gs.wordLength) then
        R:ShakeCurrentRow()
        R:ShowMessage(ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")["msg_invalid"] or "Kein WoW-Begriff!")
        PlayWRD("soundEnabled", SND_INVALID)
        return
    end

    -- Feedback berechnen
    local result = Logic:CheckGuess(guess, gs.target)
    Logic:UpdateKeyboard(gs, guess, result)

    gs.attemptsUsed = gs.attemptsUsed + 1
    gs.guesses[#gs.guesses + 1] = { guess=guess, result=result }
    gs.currentGuess = ""

    local rowIndex = gs.attemptsUsed

    -- Reveal-Animation (sequenziell, C_Timer.After)
    E._revealGen = E._revealGen + 1
    local gen = E._revealGen

    for i = 1, gs.wordLength do
        local idx = i
        C_Timer.After(idx * 0.12, function()
            if E._revealGen ~= gen then return end
            PlayWRD("soundOnReveal", SND_REVEAL)
            if R then R:RevealTile(rowIndex, idx, result[idx], gs) end
        end)
    end

    -- Nach Reveal: Ergebnis prüfen
    local totalDelay = gs.wordLength * 0.12 + 0.1
    C_Timer.After(totalDelay, function()
        if E._revealGen ~= gen then return end
        self:_AfterReveal(gs, result)
    end)
end

-- ── Nach abgeschlossener Reveal-Animation ───────────────────
function E:_AfterReveal(gs, result)
    local R     = GetRenderer()
    local Logic = GetLogic()
    local S     = GetSettings()

    -- Gewonnen?
    local allCorrect = true
    for _, r in ipairs(result) do
        if r ~= "CORRECT" then allCorrect = false; break end
    end

    if allCorrect then
        gs.won   = true
        gs.score = Logic:CalcScore(gs.attemptsUsed, gs.maxAttempts, gs.difficulty)
        E.state  = "RESULT_WIN"
        if R then R:UpdateKeyboard(gs) end
        PlayWRD("soundOnCorrect", SND_CORRECT)
        C_Timer.After(0.3, function()
            PlayWRD("soundOnWin", SND_WIN)
            if R then R:ShowResult(gs) end
        end)
        self:_EmitResult(gs)
        return
    end

    -- Niederlage?
    if gs.attemptsUsed >= gs.maxAttempts then
        gs.won   = false
        gs.score = 0
        E.state  = "RESULT_LOSS"
        if R then R:UpdateKeyboard(gs) end
        PlayWRD("soundOnLose", SND_LOSE)
        C_Timer.After(0.3, function()
            if R then R:ShowResult(gs) end
        end)
        self:_EmitResult(gs)
        return
    end

    -- Weiter spielen – Tastatur-Status aktualisieren
    if R then R:UpdateKeyboard(gs) end
end

-- ── GAME_RESULT emittieren ───────────────────────────────────
function E:_EmitResult(gs)
    local S = GetSettings()
    if S then
        S:RecordResult(gs.difficulty, gs.won, gs.attemptsUsed)
    end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "AZEROTHWORDS",
        difficulty = gs.difficulty,
        score      = gs.score,
        result     = gs.won and "WIN" or "LOSS",
        stats      = {
            attemptsUsed = gs.attemptsUsed,
            maxAttempts  = gs.maxAttempts,
        },
    })
end

-- ============================================================
-- STOPGAME
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("AZEROTHWORDS", E._sessionId)
        E._sessionId = nil
    end
    E._revealGen = E._revealGen + 1  -- Alle laufenden Timers invalidieren
    E.state      = "IDLE"
    self._gameState = nil
    local R = GetRenderer()
    if R then
        R:EnableKeyboard(false)
        R:EnterIdleState()
    end
end

-- ============================================================
-- RETRY (nach Ergebnis)
-- ============================================================
function E:Retry()
    local gs = self._gameState
    local diff = gs and gs.difficulty or "normal"
    self:StartGame(diff)
end
