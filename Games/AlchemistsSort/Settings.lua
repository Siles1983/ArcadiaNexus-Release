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

local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    if not db.saves[1] and (db.currentLevel or db.unlockedLevel) then
        db.saves[1] = {
            currentLevel  = db.currentLevel or 1,
            unlockedLevel = db.unlockedLevel or db.currentLevel or 1,
        }
    end
    return db.saves
end

local function EnsureSlot(db, slot)
    local saves = EnsureSaves(db)
    if not saves[slot] then
        saves[slot] = { currentLevel = 1, unlockedLevel = 1 }
    end
    return saves[slot]
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
    return db.saves[slot]
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
    save.currentLevel  = 1
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
    save.currentLevel = lvl
end

function S:GetUnlockedLevel()
    local save = self:LoadSlot(self:GetActiveSlot())
    return (save and save.unlockedLevel) or 1
end

function S:UnlockLevel(lvl)
    local db = GetDB()
    local save = EnsureSlot(db, self:GetActiveSlot())
    if not save.unlockedLevel or lvl > save.unlockedLevel then
        save.unlockedLevel = lvl
    end
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
