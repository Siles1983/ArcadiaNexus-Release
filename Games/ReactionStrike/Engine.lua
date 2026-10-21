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
--   - GAME_RESULT genau einmal bei Treffer, Fehlstart oder Fake-Klick

ArcadiaNexus.RS_Engine = {}
local E = ArcadiaNexus.RS_Engine

E._sessionId = nil

E.state       = "IDLE"
E._gameState  = nil   -- aktueller Versuch-State (Logic:NewState)

local _gameLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_RS_LoopFrame")

E._currentDiff   = "normal"

-- Sound-IDs (direkte Integer, kein SOUNDKIT-nil-Risiko)
local SND_SIGNAL  = 888    -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_STRIKE  = 850    -- IG_MAINMENU_OPTION_CHECKBOX_ON
local SND_PENALTY = 847    -- INTERFACE_SOUND_LOST_TARGET_UNIT
local SND_RESULT  = 888    -- UI_ACHIEVEMENT_TOAST_SPARK

local function GetLogic()    return ArcadiaNexus.RS_Logic    end
local function GetRenderer() return ArcadiaNexus.RS_Renderer end
local function GetSettings() return ArcadiaNexus.RS_Settings end

local GAME_ID = "REACTIONSTRIKE"

local function CopyResult(data)
    if type(data) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(data) do
        if type(value) == "table" then
            local inner = {}
            for innerKey, innerValue in pairs(value) do
                if type(innerValue) ~= "table" and type(innerValue) ~= "function" then
                    inner[innerKey] = innerValue
                end
            end
            copy[key] = inner
        elseif type(value) ~= "function" then
            copy[key] = value
        end
    end
    return copy
end

local function ValidRunId(runId)
    return type(runId) == "string" and runId ~= ""
end

local function Receipt(runId)
    local LR = ArcadiaNexus.LocalResults
    if not LR or not ValidRunId(runId) then return nil end
    return LR:GetReceipt(runId)
end

local function CopyValue(value)
    if type(value) ~= "table" then
        if type(value) == "function" then return nil end
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = CopyValue(inner)
    end
    return copy
end

local function ApplyBookingFields(target, payload)
    if type(target) ~= "table" or type(payload) ~= "table" then return end
    if not ValidRunId(target.runId) or target.runId ~= payload.runId then return end
    for _, key in ipairs({ "newHighscore", "newMetricRecords", "awardedXP", "awardedGold" }) do
        if payload[key] ~= nil then
            target[key] = CopyValue(payload[key])
        end
    end
end

-- pendingResults[runId] ist die von LocalResults:Prune gelesene Form.
-- nil ist leer. Ein anderer Typ bleibt stehen und blockiert.
local function InspectPending()
    local db = ArcadiaNexus.Persistence:GetGameSettings(GAME_ID)
    local bucket = db.pendingResults
    if bucket == nil then return nil, false end
    if type(bucket) ~= "table" then return nil, true end
    local open, blocked = nil, false
    for id, row in pairs(bucket) do
        local runId = type(row) == "table" and row.runId or nil
        if ValidRunId(id) and ValidRunId(runId) and id == runId and Receipt(id) then
            bucket[id] = nil
        elseif open or type(row) ~= "table" or not ValidRunId(runId) or id ~= runId then
            blocked = true
        else
            open = row
        end
    end
    if blocked then return nil, true end
    if not next(bucket) then db.pendingResults = nil end
    return open, false
end

local function StorePending(data)
    local copy = CopyResult(data)
    if not copy or copy.gameId ~= GAME_ID or not ValidRunId(copy.runId) then
        return false
    end
    local open, blocked = InspectPending()
    if blocked then return false end
    if open then return open.runId == copy.runId end
    local db = ArcadiaNexus.Persistence:GetGameSettings(GAME_ID)
    if db.pendingResults == nil then
        db.pendingResults = {}
    elseif type(db.pendingResults) ~= "table" then
        return false
    end
    db.pendingResults[copy.runId] = copy
    return true
end

local function Bookable(row)
    return type(row) == "table" and row.gameId == GAME_ID and type(row.runId) == "string"
        and (row.result == "WIN" or row.result == "LOSS")
        and type(row.score) == "number" and row.score >= 0 and row.score == row.score and row.score < math.huge
end

local function BookOpenPending()
    local open, blocked = InspectPending()
    if blocked then return false end
    if not open then return true end
    if not Bookable(open) then return false end
    if not Receipt(open.runId) then
        local payload = CopyResult(open)
        pcall(function() ArcadiaNexus.Engine:Emit("GAME_RESULT", payload) end)
    end
    if not Receipt(open.runId) then return false end
    InspectPending()
    return true
end

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
    local gs,sid=self._gameState,self._sessionId
    _gameLoop:Start(function(dt)
        if self._gameState~=gs or not ArcadiaNexus.GameSession:IsSession(self,sid) then _gameLoop:Stop(); return end
        E:_Tick(dt)
    end)
end

function E:_Owned(gs)
    return gs and self._gameState==gs and ArcadiaNexus.GameSession:IsSession(self,self._sessionId)
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
    if not Logic or not gs or not self:_Owned(gs) then return end
    local now=GetTime()

    if E.state == "WAITING" then
        if now >= self._deadline then
            self:_ShowSignal(gs)
        end

    elseif E.state == "SIGNAL" then
        -- Orb bewegen (Moving Target)
        if gs.cfg.moving then
            Logic:TickOrb(gs, math.min(dt,0.1))
            if R then R:UpdateOrbPosition(gs) end
        end

    elseif E.state == "FAKEOUT" then
        if gs.cfg.moving then
            Logic:TickOrb(gs, math.min(dt,0.1))
            if R then R:UpdateOrbPosition(gs) end
        end
        if now >= self._deadline then
            -- Fakeout korrekt überlebt
            self:_FakeoutSurvived(gs)
        end

    elseif E.state == "PENALTY" or E.state=="FAKEOUT_PAUSE" then
        if E.state=="PENALTY" and R and R.UpdatePenaltyCountdown then
            R:UpdatePenaltyCountdown(math.max(0,self._deadline-now))
        end
        if now >= self._deadline then
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
    if not Logic then return false end
    if type(difficulty)=="table" then difficulty=difficulty.difficulty end
    local diff=difficulty or GetSettings():Get("difficulty") or "normal"
    if not Logic:IsDifficulty(diff) then return false end
    GetSettings():EnsureCounters()
    if not BookOpenPending() then return false end

    local sid = ArcadiaNexus.Lifecycle:RestartGame("REACTIONSTRIKE", E._sessionId)
    if not sid then return false end
    E._sessionId = sid

    self:_StopLoop()

    self._currentDiff = diff

    self:_StartWaiting()
    if R then R:OnGameStarted(self._gameState); R:ShowWaiting(self._gameState) end
    self:_StartLoop()
    return true
end

-- ============================================================
-- WAITING-STATE
-- ============================================================
function E:_StartWaiting(gs)
    local Logic = GetLogic()
    local R     = GetRenderer()
    local open, blocked = InspectPending()
    if blocked or open then return end

    gs=Logic:NewState(self._currentDiff)
    gs.runId=ArcadiaNexus.LocalResults:NewRun("REACTIONSTRIKE")
    self._gameState=gs
    E.state           = "WAITING"
    self._deadline=GetTime()+Logic:RollWaitDelay(gs)

    if R then R:ShowWaiting(gs) end
    ArcadiaNexus.LocalResults:Prune()
    self:_StartLoop()
end

-- ============================================================
-- SIGNAL / FAKEOUT ANZEIGEN
-- ============================================================
function E:_ShowSignal(gs)
    local Logic = GetLogic()
    local R     = GetRenderer()
    if self.state~="WAITING" or not self:_Owned(gs) then return false end

    local signalType = Logic:RollSignalType(gs)

    -- Orb zentrieren + Geschwindigkeit setzen
    gs.orb.x = (Logic.FIELD_W - Logic.ORB_SIZE) / 2
    gs.orb.y = (Logic.FIELD_H - Logic.ORB_SIZE) / 2
    Logic:RollOrbVelocity(gs)

    E.state="PRESENTING"
    if signalType == "FAKEOUT" then
        gs.signalTime   = nil
        if R then R:ShowFakeout(gs) end
        if not self:_Owned(gs) then return false end
        self._deadline=GetTime()+gs.cfg.fakeoutDur
    else
        if R then R:ShowSignal(gs) end
        if not self:_Owned(gs) then return false end
        gs.signalTime=GetTime(); self._deadline=nil
    end
    E.state=signalType
    PlayRS("soundOnSignal",SND_SIGNAL)
    return true
end

-- ============================================================
-- FAKEOUT ÜBERLEBT (kein Klick während Fakeout)
-- ============================================================
function E:_FakeoutSurvived(gs)
    -- Zähler für Achievement RS_FAKEOUT persistieren
    if self.state~="FAKEOUT" or not self:_Owned(gs) then return false end
    self.state="FAKEOUT_PAUSE"; self._deadline=GetTime()+0.6
    GetSettings():RecordFakeout()
    local R = GetRenderer()
    if R and self:_Owned(gs) then R:ShowFakeoutSurvived(gs) end
    -- Kurze Pause, dann nächster Versuch
    return true
end

-- ============================================================
-- INPUT-HANDLER (Klick oder Leertaste)
-- ============================================================
function E:HandleInput(inputType)
    local Logic = GetLogic()
    local R     = GetRenderer()
    local gs    = self._gameState
    if inputType~="STRIKE" or not Logic or not gs or not self:_Owned(gs) then return false end
    if self._deadline and GetTime()>=self._deadline then
        local old=self.state; self:_Tick(0)
        if old=="WAITING" or self._gameState~=gs then return false end
    end

    if E.state == "WAITING" then
        -- Fehlstart
        return self:_Complete(gs,"EARLYCLICK")

    elseif E.state == "SIGNAL" then
        -- Gültiger Treffer
        return self:_Complete(gs,"STRIKE")

    elseif E.state == "FAKEOUT" then
        -- Fakeout angeklickt → Strafe
        return self:_Complete(gs,"FAKEOUT")

    elseif E.state == "RESULT" or E.state == "PENALTY" then
        -- Eingaben während Ergebnis/Strafe ignorieren
    end
    return false
end

function E:_Complete(gs,reason)
    if gs.closed then return false end
    gs.closed=true; gs.reason=reason
    self.state="RESULT_PENDING"; self:_StopLoop()
    if reason=="STRIKE" then
        gs.reactionMs=GetLogic():RecordStrike(gs,GetTime())
        gs.score=GetLogic():CalcScore(gs.reactionMs,gs.difficulty)
    else gs.score=0; gs.penaltyType=reason end
    gs.resultData={gameId="REACTIONSTRIKE",difficulty=gs.difficulty,runId=gs.runId,
        ruleVersion=2,skipHighscores=true,result=reason=="STRIKE" and "WIN" or "LOSS",
        reason=reason,score=gs.score,reactionMs=gs.reactionMs}
    if not Bookable(gs.resultData) or not StorePending(gs.resultData) then return false end
    self:RetryResult()
    return true
end

function E:RetryResult()
    local gs=self._gameState
    if self.state~="RESULT_PENDING" or not gs or not self:_Owned(gs) then return false end
    if type(gs.resultData) ~= "table" or not Bookable(gs.resultData) or not StorePending(gs.resultData) then return false end
    local open = InspectPending()
    if not open or open.runId ~= gs.runId or not Bookable(open) then return false end
    if not Receipt(gs.runId) then
        local payload = CopyResult(open)
        pcall(function() ArcadiaNexus.Engine:Emit("GAME_RESULT", payload) end)
        if Receipt(gs.runId) and self._gameState == gs and gs.resultData.runId == gs.runId then
            ApplyBookingFields(gs.resultData, payload)
        end
    end
    if not self:_Owned(gs) then return false end
    if not Receipt(gs.runId) or gs.resultData.runId ~= gs.runId then
        local R = GetRenderer()
        if R then R:ShowResultPending(gs) end
        return false
    end
    InspectPending()
    gs.resultData.processed = true
    local R=GetRenderer()
    if gs.reason=="STRIKE" then
        GetSettings():SetLastMs(gs.difficulty,gs.reactionMs)
        self.state="RESULT"; PlayRS("soundOnStrike",SND_STRIKE); PlayRS("soundOnResult",SND_RESULT)
        if R then R:ShowResult(gs) end
    else
        self:_BeginPenalty(gs,gs.reason,gs.cfg.penaltySec)
        PlayRS("soundOnPenalty",SND_PENALTY)
    end
    return true
end

-- ============================================================
-- PENALTY-STATE
-- ============================================================
function E:_BeginPenalty(gs, penaltyType, duration)
    local R = GetRenderer()

    -- Loop weiterhin aktiv für Countdown
    E.state          = "PENALTY"
    gs.penaltyType   = penaltyType
    self._deadline=GetTime()+duration

    if R then R:ShowPenalty(gs, duration) end
    self:_StartLoop()
end

-- ============================================================
-- NOCHMAL (nach RESULT, Overlay-Button)
-- ============================================================
function E:Retry()
    local gs = self._gameState
    if E.state~="RESULT" or not self:_Owned(gs) then return false end
    -- Selbe Schwierigkeit, neuer Versuch
    self:_StartWaiting(gs)
    self:_StartLoop()
    return true
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
    self._deadline=nil
    local R = GetRenderer()
    if R then R:EnterIdleState() end
end
