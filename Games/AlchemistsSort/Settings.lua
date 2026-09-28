-- ============================================================
--  AlchemistsSort – Settings.lua
--  Persistente Einstellungen, Statistiken, Level-Fortschritt
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Settings = {}
local S = ArcadiaNexus.ALS_Settings

S.Defaults = {
    soundEnabled    = true,
    soundOnPour     = true,
    soundOnWin      = true,
    soundOnInvalid  = true,
}

S.MAX_SLOTS = 3

local DB_KEY = "ALCHEMISTSSORT"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

local function NonNegativeInt(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return 0 end
    return math.max(0, math.floor(value))
end

-- Sort has no final level. Grow the normalization bound with the saved progress;
-- never use the currently selected replay level as the campaign's upper bound.
local function NormalizeCampaign(save)
    if type(save) ~= "table" then return nil end
    local CP = ArcadiaNexus.CampaignProgress
    local legacy = save.campaignVersion == nil
    local unlocked = math.max(1, NonNegativeInt(save.unlockedLevel),
        NonNegativeInt(save.currentLevel), NonNegativeInt(save.clearedLevel) + 1)
    if type(save.stars) == "table" then
        for level, stars in pairs(save.stars) do
            if NonNegativeInt(stars) > 0 then
                unlocked = math.max(unlocked, NonNegativeInt(level) + 1)
            end
        end
    end
    save.clearedLevel = math.max(NonNegativeInt(save.clearedLevel), unlocked - 1)
    CP.Normalize(save, { levelCount=unlocked, maxStars=3 })
    -- Legacy unlocks prove completion, but not how many aids were used.
    -- Grant only the completion star, once; global move/time records are not ratings.
    if legacy then
        for level = 1, save.clearedLevel do
            if CP.GetStars(save, level) == 0 then save.stars[level] = 1 end
        end
    end
    save.unlockedLevel = unlocked -- compatibility field for the existing slot UI
    return save
end

local function EnsureSaves(db)
    local hadSlots = type(db.saves) == "table"
    if not hadSlots then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    -- Nur Daten ohne Slot-Tabelle sind noch nicht migriert. Eine vorhandene,
    -- leere Tabelle kann einen bewusst gelöschten ersten Slot bedeuten.
    if not hadSlots and (db.currentLevel or db.unlockedLevel) then
        db.saves[1] = {
            currentLevel  = db.currentLevel or 1,
            unlockedLevel = db.unlockedLevel or db.currentLevel or 1,
        }
    end
    db.currentLevel = nil
    db.unlockedLevel = nil
    return db.saves
end

local function EnsureSlot(db, slot)
    local saves = EnsureSaves(db)
    if not saves[slot] then
        saves[slot] = { currentLevel = 1, unlockedLevel = 1 }
    end
    return NormalizeCampaign(saves[slot])
end

local function EnsureStats()
    local db = GetDB()
    if not db.stats then
        db.stats = { played = 0, solved = 0, topScores = { 0, 0, 0 } }
    end
    return db.stats
end

local function EnsureLevelBest()
    local db = GetDB()
    if not db.levelBest then db.levelBest = {} end
    return db.levelBest
end

-- ── Einstellungen ─────────────────────────────────────────────
function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Save-Slots ────────────────────────────────────────────────
function S:GetActiveSlot()
    local db = GetDB()
    EnsureSaves(db)
    return db.activeSlot or 1
end

function S:SetActiveSlot(slot)
    local db = GetDB()
    EnsureSaves(db)
    slot = tonumber(slot) or 1
    if slot >= 1 and slot <= S.MAX_SLOTS then
        db.activeSlot = slot
    end
end

function S:LoadSlot(slot)
    slot = tonumber(slot) or self:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return nil end
    local db = GetDB()
    EnsureSaves(db)
    return NormalizeCampaign(db.saves[slot])
end

function S:SaveMidGame(slot, midGame)
    local db = GetDB()
    local save = EnsureSlot(db, slot)
    save.midGame   = midGame
    save.timestamp = time()
end

function S:ClearMidGame(slot)
    local save = self:LoadSlot(slot)
    if save then save.midGame = nil end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:ResetSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    local save = EnsureSlot(db, slot)
    ArcadiaNexus.CampaignProgress.Reset(save)
    save.unlockedLevel = 1
    save.midGame       = nil
    save.timestamp     = time()
end

-- ── Level-Fortschritt (pro aktivem Slot) ──────────────────────
function S:GetCurrentLevel()
    local save = self:LoadSlot(self:GetActiveSlot())
    return (save and save.currentLevel) or 1
end

function S:SetCurrentLevel(lvl)
    local db = GetDB()
    local save = EnsureSlot(db, self:GetActiveSlot())
    save.currentLevel = math.max(1, math.min(save.unlockedLevel, NonNegativeInt(lvl)))
end

function S:GetUnlockedLevel()
    local save = self:LoadSlot(self:GetActiveSlot())
    return (save and save.unlockedLevel) or 1
end

function S:IsLevelUnlocked(level)
    local save = self:LoadSlot(self:GetActiveSlot())
    if not save or type(level) ~= "number" or level ~= math.floor(level)
        or level < 1 or level > save.unlockedLevel then return false end
    return ArcadiaNexus.CampaignProgress.IsLevelUnlocked(save, level,
        { levelCount=save.unlockedLevel, maxStars=3 })
end

function S:GetStar(save, level)
    return ArcadiaNexus.CampaignProgress.GetStars(save, level)
end

function S:SumStars(save)
    return ArcadiaNexus.CampaignProgress.TotalStars(save)
end

function S:RecordLevel(level, stars)
    if not self:IsLevelUnlocked(level) or type(stars) ~= "number"
        or stars ~= math.floor(stars) or stars < 1 or stars > 3 then return 0, false, 0 end
    local save = self:LoadSlot(self:GetActiveSlot())
    local best, improved, gained = ArcadiaNexus.CampaignProgress.RecordLevel(save, level, stars,
        { levelCount=math.max(save.unlockedLevel, level + 1), maxStars=3 })
    save.unlockedLevel = math.max(save.unlockedLevel, save.clearedLevel + 1)
    save.timestamp = time()
    return best, improved, gained
end

-- ── Statistiken ───────────────────────────────────────────────
function S:IncrementPlayed()
    local st = EnsureStats()
    st.played = (st.played or 0) + 1
end

function S:IncrementSolved()
    local st = EnsureStats()
    st.solved = (st.solved or 0) + 1
end

function S:GetStat(key)
    return EnsureStats()[key] or 0
end

-- Top-3 Score aktualisieren
function S:SubmitScore(score)
    local st = EnsureStats()
    local top = st.topScores or { 0, 0, 0 }
    table.insert(top, score)
    table.sort(top, function(a, b) return a > b end)
    while #top > 3 do table.remove(top) end
    st.topScores = top
end

-- ── Level-Bestleistungen ──────────────────────────────────────
function S:GetLevelBest(levelId)
    return EnsureLevelBest()[levelId]
end

function S:SubmitLevelBest(levelId, moves, time)
    local lb = EnsureLevelBest()
    local cur = lb[levelId]
    if not cur then
        lb[levelId] = { moves = moves, time = time }
    else
        if moves < (cur.moves or math.huge) then cur.moves = moves end
        if time  < (cur.time  or math.huge) then cur.time  = time  end
    end
end

-- ── Streak-Tracking (Session, nicht persistent) ───────────────
S._sessionStreak = 0

function S:GetSessionStreak() return S._sessionStreak end

function S:IncrementStreak()
    S._sessionStreak = S._sessionStreak + 1
end

function S:ResetStreak()
    S._sessionStreak = 0
end
