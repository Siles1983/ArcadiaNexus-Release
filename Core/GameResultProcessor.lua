--[[
    ArcadiaNexus – Core/GameResultProcessor.lua
    Sequenzielle Verarbeitungskette für GAME_RESULT-Events.

    Pipeline (synchron, ohne Frame-Delays):
      1. ScoreManager      → leaderboard, data.newHighscore
      2. XPManager         → Profil-XP, Level-Up
      3. AchievementManager → Achievements prüen / freischalten
      4. ChallengeManager  → Daily/Weekly-Fortschritt
      5. StreakManager     → erstes gezähltes Spiel des Tages

    API:
      ArcadiaNexus.GameResultProcessor:Init()
      ArcadiaNexus.GameResultProcessor:Process(data)

    MATCH (resultId) bucht jeden Schritt auf einer Kopie und schreibt die
    Schrittmarke erst danach. Offene Buchungen liegen mit den Ergebnisdaten
    in matchResults und werden beim Login nachgeholt, auch ohne Rejoin.
    data.matchBooked == true ist die Bestätigung für die Engine.
    Ein gespeichertes true oder complete ist bereits abgeschlossen.
    Der Solo-Pfad über LocalResults bleibt unverändert.
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.GameResultProcessor = {}

local GRP = ArcadiaNexus.GameResultProcessor
local ROOTS = { "leaderboard", "profile", "achievements", "challenges", "streak", "tavernGold" }
local unpack = unpack or table.unpack

local function Clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = Clone(v)
    end
    return out
end

-- ============================================================
-- INIT
-- ============================================================

function GRP:Init()
    self._inflight = {}
    ArcadiaNexus.Engine:On("GAME_RESULT", function(data)
        self:Process(data)
    end)
    self:ResumeOpen()
    GH_LogInfo("GameResultProcessor", "GAME_RESULT-Pipeline registriert")
end

function GRP:IsBooking()
    return self._booking == true
end

function GRP:BufferEvent(event, ...)
    if not self._booking or event == "GAME_RESULT" then return false end
    local args = { n = select("#", ...), ... }
    if event == "ACHIEVEMENT_XP" then
        local reward = args[1]
        local XPM = ArcadiaNexus.XPManager
        if reward and reward.amount and reward.amount > 0 and XPM and XPM.AddXP then
            XPM:AddXP(reward.amount)
        end
        return true
    end
    local AM = ArcadiaNexus.AchievementManager
    if AM then
        if event == "ARCADE_LEVEL_UP" and AM._CheckLevelGroups then
            AM:_CheckLevelGroups()
        elseif event == "CHALLENGE_COMPLETE" and AM._CheckById then
            AM:_CheckById("GLOBAL_DAILY_STREAK")
            AM:_CheckById("GLOBAL_WEEKLY_STREAK")
        elseif event == "STREAK_UPDATED" and AM._CheckById then
            AM:_CheckById("GLOBAL_LOGIN_STREAK")
        end
    end
    self._events = self._events or {}
    self._events[#self._events + 1] = { event = event, args = args }
    return true
end

--- UI-Meldungen nach der Schrittmarke. Fehler hier ändern die Buchung nicht.
function GRP:_Publish()
    local events = self._events or {}
    self._events = {}
    self._booking = false
    for i = 1, #events do
        local item = events[i]
        ArcadiaNexus.EventBus:Emit(item.event, unpack(item.args, 1, item.args.n))
        if item.event == "GOLD_UPDATED" then
            local gold = item.args[1]
            local TM = ArcadiaNexus.ToastManager
            if gold and TM and TM.ShowGold then
                pcall(TM.ShowGold, TM, gold.delta, gold.reason)
            end
        end
    end
end

function GRP:_Character()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    if not name then return nil end
    return name .. "-" .. tostring(realm):gsub("%s+", "")
end

function GRP:_Identity(data)
    local character = self:_Character()
    if not character or type(data) ~= "table" then return nil end
    if not data.matchHost or not data.resultId or not data.gameId then return nil end
    return character, tostring(data.matchHost) .. ":" .. data.gameId .. ":" .. tostring(data.resultId)
end

--- Offene MATCH-Buchungen fortsetzen. Ein Rejoin ist dafür nicht nötig.
function GRP:ResumeOpen()
    local character = self:_Character()
    local store = ArcadiaNexus.MatchStore
    if not character or not store or not store.OpenBookings then return end
    local open = store.OpenBookings(character)
    for i = 1, #open do
        local payload = Clone(open[i].payload)
        if type(payload) == "table" and payload.gameId and payload.result then
            self:Process(payload)
        end
    end
end

function GRP:_CommitStep(fn)
    local db = _G.ArcadiaNexusDB
    if type(db) ~= "table" then
        db = {}
        _G.ArcadiaNexusDB = db
    end
    local prior = {}
    for i = 1, #ROOTS do
        local key = ROOTS[i]
        prior[key] = db[key]
        db[key] = Clone(db[key])
    end
    self._booking = true
    self._events = {}
    local ok, err = pcall(fn)
    self._booking = false
    if not ok then
        self._events = {}
        for i = 1, #ROOTS do
            db[ROOTS[i]] = prior[ROOTS[i]]
        end
        return false, err
    end
    return true
end

-- ============================================================
-- PIPELINE
-- ============================================================

function GRP:Process(data)
    if not data or not data.gameId or not data.result then return end
    if ArcadiaNexus.RetiredContent and ArcadiaNexus.RetiredContent:IsGame(data.gameId) then return false end
    -- Explicit consumers opt into the roadmap's local receipt contract. Other games and
    -- Match resultId deliveries continue through the original pipeline below.
    if ArcadiaNexus.LocalResults and ArcadiaNexus.LocalResults:Supports(data.gameId) and data.runId and not data.resultId then
        return ArcadiaNexus.LocalResults:Process(data)
    end

    if data.resultId then
        return self:_ProcessMatch(data)
    end

    self:_RunStep("ScoreManager", ArcadiaNexus.ScoreManager, "HandleGameResult", data)
    -- Zwischenstände aktualisieren nur Scores und Spielstatistiken.
    if data.recordPlayed == false then return true end
    -- Keep the existing normal MATCH reward/achievement semantics after W/L separation.
    local progressionData=data
    if (data.gameId=="TAVERNCARDS" or data.gameId=="TICTACTOE") and data.difficulty=="match" then
        progressionData={}; for key,value in pairs(data) do progressionData[key]=value end
        progressionData.difficulty="normal"
    end
    self:_RunStep("XPManager", ArcadiaNexus.XPManager, "HandleGameResult", progressionData)
    self:_RunStep("AchievementManager", ArcadiaNexus.AchievementManager, "HandleGameResult", progressionData)
    self:_RunStep("ChallengeManager", ArcadiaNexus.ChallengeManager, "HandleGameResult", progressionData)
    self:_RunStep("StreakManager", ArcadiaNexus.StreakManager, "HandleGameResult", progressionData)
    return true
end

function GRP:_RunStep(label, module, method, data)
    if not module or not module[method] then return end
    local ok, err = pcall(module[method], module, data)
    if not ok then
        GH_LogError("GameResultProcessor", label .. ": " .. tostring(err))
    end
end

function GRP:_ProcessMatch(data)
    local store = ArcadiaNexus.MatchStore
    local character, key = self:_Identity(data)
    if not store or not character then return false end
    self._inflight = self._inflight or {}
    if self._inflight[key] then return false end
    self._inflight[key] = true
    local function done(ok)
        self._inflight[key] = nil
        self._booking = false
        if ok then data.matchBooked = true end
        return ok == true
    end

    local rec, status = store.BeginBooking(character, key, data)
    if status == "complete" then return done(true) end
    if type(rec) ~= "table" then return done(false) end
    if rec.steps.score and type(rec.derived) == "table" then
        data.newHighscore = rec.derived.newHighscore == true
    end

    if not rec.steps.score and ArcadiaNexus.ScoreManager and ArcadiaNexus.ScoreManager.HandleGameResult then
        local ok, err = self:_CommitStep(function()
            ArcadiaNexus.ScoreManager:HandleGameResult(data)
        end)
        if not ok then
            GH_LogError("GameResultProcessor", "ScoreManager: " .. tostring(err))
            return done(false)
        end
        store.CommitBookingStep(character, key, "score", { newHighscore = data.newHighscore == true })
        self:_Publish()
    end

    if data.recordPlayed == false then
        store.FinishBooking(character, key)
        return done(true)
    end

    local progression = data
    if (data.gameId == "TAVERNCARDS" or data.gameId == "TICTACTOE") and data.difficulty == "match" then
        progression = {}
        for field, value in pairs(data) do progression[field] = value end
        progression.difficulty = "normal"
    end

    local steps = {
        { "xp", "XPManager", ArcadiaNexus.XPManager },
        { "achievements", "AchievementManager", ArcadiaNexus.AchievementManager },
        { "challenges", "ChallengeManager", ArcadiaNexus.ChallengeManager },
        { "streak", "StreakManager", ArcadiaNexus.StreakManager },
    }
    for i = 1, #steps do
        local id, label, module = steps[i][1], steps[i][2], steps[i][3]
        if not rec.steps[id] and module and module.HandleGameResult then
            local ok, err = self:_CommitStep(function()
                module:HandleGameResult(progression)
            end)
            if not ok then
                GH_LogError("GameResultProcessor", label .. ": " .. tostring(err))
                return done(false)
            end
            store.CommitBookingStep(character, key, id)
            self:_Publish()
        end
    end

    store.FinishBooking(character, key)
    return done(true)
end
