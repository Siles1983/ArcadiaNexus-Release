-- Games/ReactionStrike/Engine.lua
--
-- State-Machine:
--   IDLE → WAITING → SIGNAL  → RESULT → WAITING
--                 ↘ FAKEOUT → PENALTY → WAITING
--                 ↘ EARLYCLICK        → PENALTY → WAITING
--
-- Pflicht-Pattern:
--   - GameLoop (Core/GameLoop) für OnUpdate-Loop
--   - OnHide → StopGame() (kein SaveAndPause nötig)
--   - GAME_RESULT nur bei gültigem Versuch (kein Penalty)

ArcadiaNexus.RS_Engine = {}
local E = ArcadiaNexus.RS_Engine

E._sessionId = nil

E.state       = "IDLE"
E._gameState  = nil   -- aktueller Versuch-State (Logic:NewState)

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_RS_LoopFrame")

E._waitAccum  = 0
E._waitDelay  = 0
E._reactionAccum = 0
E._penaltyAccum  = 0
E._penaltySec    = 0
E._fakeoutAccum  = 0
E._fakeoutDur    = 0
E._currentDiff   = "normal"

-- Sound-IDs (direkte Integer, kein SOUNDKIT-nil-Risiko)
local SND_SIGNAL  = 888    -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_STRIKE  = 850    -- IG_MAINMENU_OPTION_CHECKBOX_ON
local SND_PENALTY = 847    -- INTERFACE_SOUND_LOST_TARGET_UNIT
local SND_RESULT  = 888    -- UI_ACHIEVEMENT_TOAST_SPARK

local function GetLogic()    return ArcadiaNexus.RS_Logic    end
local function GetRenderer() return ArcadiaNexus.RS_Renderer end
local function GetSettings() return ArcadiaNexus.RS_Settings end

local function PlayRS(key, id)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    if not S:Get(key) then return end
    PlaySound(id, "Master")
end

-- ============================================================
-- LOOP-FRAME (einmal erstellt, nie zerstört)
-- ============================================================
function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end)
end

function E:_StopLoop()
    _gameLoop:Stop()
end

-- ============================================================
-- TICK
-- ============================================================
function E:_Tick(dt)
    local Logic = GetLogic()
    local R     = GetRenderer()
    local gs    = self._gameState
    if not Logic or not R or not gs then return end

    if E.state == "WAITING" then
        E._waitAccum = E._waitAccum + dt
        if E._waitAccum >= E._waitDelay then
            self:_ShowSignal(gs)
        end

    elseif E.state == "SIGNAL" then
        E._reactionAccum = E._reactionAccum + dt
        -- Orb bewegen (Moving Target)
        if gs.cfg.moving then
            Logic:TickOrb(gs, dt)
            R:UpdateOrbPosition(gs)
        end

    elseif E.state == "FAKEOUT" then
        E._fakeoutAccum = E._fakeoutAccum + dt
        if gs.cfg.moving then
            Logic:TickOrb(gs, dt)
            R:UpdateOrbPosition(gs)
        end
        if E._fakeoutAccum >= E._fakeoutDur then
            -- Fakeout korrekt überlebt
            self:_FakeoutSurvived(gs)
        end

    elseif E.state == "PENALTY" then
        E._penaltyAccum = E._penaltyAccum + dt
        if R.UpdatePenaltyCountdown then
            R:UpdatePenaltyCountdown(E._penaltySec - E._penaltyAccum)
        end
        if E._penaltyAccum >= E._penaltySec then
            self:_StartWaiting(gs)
        end
    end
end

-- ============================================================
-- SPIELSTART
-- ============================================================
function E:StartGame(difficulty)
    local Logic = GetLogic()
    local R     = GetRenderer()
    if not Logic or not R then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("REACTIONSTRIKE", E._sessionId)

    self:_StopLoop()

    local diff = difficulty or self._currentDiff or "normal"
    self._currentDiff = diff

    local gs = Logic:NewState(diff)
    self._gameState = gs

    R:OnGameStarted(gs)
    self:_StartWaiting(gs)
    self:_StartLoop()
end

-- ============================================================
-- WAITING-STATE
-- ============================================================
function E:_StartWaiting(gs)
    local Logic = GetLogic()
    local R     = GetRenderer()

    E.state           = "WAITING"
    E._waitAccum      = 0
    E._reactionAccum  = 0
    E._waitDelay      = Logic:RollWaitDelay(gs)

    if R then R:ShowWaiting(gs) end
end

-- ============================================================
-- SIGNAL / FAKEOUT ANZEIGEN
-- ============================================================
function E:_ShowSignal(gs)
    local Logic = GetLogic()
    local R     = GetRenderer()

    local signalType = Logic:RollSignalType(gs)

    -- Orb zentrieren + Geschwindigkeit setzen
    gs.orb.x = (Logic.FIELD_W - Logic.ORB_SIZE) / 2
    gs.orb.y = (Logic.FIELD_H - Logic.ORB_SIZE) / 2
    Logic:RollOrbVelocity(gs)

    if signalType == "FAKEOUT" then
        E.state         = "FAKEOUT"
        E._fakeoutAccum = 0
        E._fakeoutDur   = gs.cfg.fakeoutDur
        gs.signalTime   = nil
        if R then R:ShowFakeout(gs) end
    else
        E.state          = "SIGNAL"
        E._reactionAccum = 0
        gs.signalTime    = GetTime()
        PlayRS("soundOnSignal", SND_SIGNAL)
        if R then R:ShowSignal(gs) end
    end
end

-- ============================================================
-- FAKEOUT ÜBERLEBT (kein Klick während Fakeout)
-- ============================================================
function E:_FakeoutSurvived(gs)
    -- Zähler für Achievement RS_FAKEOUT persistieren
    local S = GetSettings()
    if S then
        local db = _G.ArcadiaNexusDB
        if db then
            db.gameSettings = db.gameSettings or {}
            db.gameSettings["REACTIONSTRIKE"] = db.gameSettings["REACTIONSTRIKE"] or {}
            local rs = db.gameSettings["REACTIONSTRIKE"]
            rs.fakeoutsSurvived = (rs.fakeoutsSurvived or 0) + 1
        end
    end
    local R = GetRenderer()
    if R then R:ShowFakeoutSurvived(gs) end
    -- Kurze Pause, dann nächster Versuch
    self:_BeginPenalty(gs, "FAKEOUT_SURVIVED", 0.6)
end

-- ============================================================
-- INPUT-HANDLER (Klick oder Leertaste)
-- ============================================================
function E:HandleInput(inputType)
    local Logic = GetLogic()
    local R     = GetRenderer()
    local gs    = self._gameState
    if not Logic or not R or not gs then return end

    if E.state == "WAITING" then
        -- Fehlstart
        PlayRS("soundOnPenalty", SND_PENALTY)
        gs.penaltyType = "EARLYCLICK"
        self:_BeginPenalty(gs, "EARLYCLICK", gs.cfg.penaltySec)

    elseif E.state == "SIGNAL" then
        -- Gültiger Treffer
        local ms    = Logic:RecordStrike(gs)
        local score = Logic:CalcScore(ms, gs.difficulty)
        gs.score    = score

        PlayRS("soundOnStrike", SND_STRIKE)

        -- Letzter Versuch speichern (kein Highscore — der läuft über ScoreManager)
        local S = GetSettings()
        if S then
            S:SetLastMs(gs.difficulty, ms)
        end

        -- GAME_RESULT an zentrales System
        local rsDB = _G.ArcadiaNexusDB
        local rsStats = rsDB and rsDB.gameSettings and rsDB.gameSettings["REACTIONSTRIKE"]
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "REACTIONSTRIKE",
            difficulty = gs.difficulty,
            score      = score,
            result     = "WIN",
            stats      = {
                fakeoutsSurvived = rsStats and rsStats.fakeoutsSurvived or 0,
            },
        })

        E.state = "RESULT"
        self:_StopLoop()
        PlayRS("soundOnResult", SND_RESULT)
        if R then R:ShowResult(gs) end

    elseif E.state == "FAKEOUT" then
        -- Fakeout angeklickt → Strafe
        PlayRS("soundOnPenalty", SND_PENALTY)
        gs.penaltyType = "FAKEOUT"
        self:_BeginPenalty(gs, "FAKEOUT", gs.cfg.penaltySec)

    elseif E.state == "RESULT" or E.state == "PENALTY" then
        -- Eingaben während Ergebnis/Strafe ignorieren
    end
end

-- ============================================================
-- PENALTY-STATE
-- ============================================================
function E:_BeginPenalty(gs, penaltyType, duration)
    local R = GetRenderer()

    -- Loop weiterhin aktiv für Countdown
    E.state          = "PENALTY"
    E._penaltyAccum  = 0
    E._penaltySec    = duration
    gs.penaltyType   = penaltyType

    if R then R:ShowPenalty(gs, duration) end
end

-- ============================================================
-- NOCHMAL (nach RESULT, Overlay-Button)
-- ============================================================
function E:Retry()
    local gs = self._gameState
    if not gs then return end
    -- Selbe Schwierigkeit, neuer Versuch
    self:_StartWaiting(gs)
    self:_StartLoop()
end

-- ============================================================
-- STOPGAME
-- ============================================================
function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("REACTIONSTRIKE", E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    E.state       = "IDLE"
    self._gameState = nil
    local R = GetRenderer()
    if R then R:EnterIdleState() end
end
