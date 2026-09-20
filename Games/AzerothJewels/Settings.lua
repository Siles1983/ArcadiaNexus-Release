--[[
    ArcadiaNexus – Azeroth Jewels
    Games/AzerothJewels/Settings.lua

    Persistence via ArcadiaNexus.Persistence (gameSettings.AZEROTHJEWELS).

    Struktur:
      db.difficulty / db.timerActive / db.sound*   – Defaults-Keys
      db.activeSlot = 1..3
      db.saves[slot] = {
          level, totalScore, difficulty, timerActive,
          powerUps  = { fire=0, frost=0, chain=0, bomb=0, holy=0 },  -- max 3 je Typ
          progress  = { fire=0, ... },     -- Ladefortschritt (Rohwerte)
          midLevel  = { ... } | nil,       -- Board-State für Resume
          timestamp = time(),
      }
      db.stats = { totalLevels, totalPowerUps, totalTimeWins, totalIce }
                 – kumulative Zähler für Achievements
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_Settings = {}
local S = ArcadiaNexus.AJ_Settings

S.Defaults = {
    difficulty      = "easy",
    timerActive     = false,
    soundEnabled    = true,
    soundOnMatch    = true,
    soundOnPowerup  = true,
    soundOnGameover = true,
    soundOnLowMoves = true,
    hintSparkle     = true,
    reducedMotion   = false,
    impactFx        = true,
}

S.MAX_SLOTS = 3

local DB_KEY = "AZEROTHJEWELS"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

-- ── Standard-Settings ─────────────────────────────────────────
function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    P:SetGameSetting(DB_KEY, key, value)
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        db[k] = nil
    end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Save-Slots ────────────────────────────────────────────────
local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    return db.saves
end

function S:GetActiveSlot()
    local db = GetDB()
    EnsureSaves(db)
    return db.activeSlot
end

function S:SetActiveSlot(slot)
    local db = GetDB()
    EnsureSaves(db)
    if slot >= 1 and slot <= S.MAX_SLOTS then
        db.activeSlot = slot
    end
end

--- Legt einen kompletten Slot-Datensatz ab (überschreibt).
function S:SaveSlot(slot, data)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    local saves = EnsureSaves(db)
    saves[slot] = {
        level       = data.level or 1,
        totalScore  = data.totalScore or 0,
        difficulty  = data.difficulty or "easy",
        timerActive = data.timerActive or false,
        powerUps    = data.powerUps or { fire=0, frost=0, chain=0, bomb=0, holy=0 },
        progress    = data.progress or { fire=0, frost=0, chain=0, bomb=0, holy=0 },
        midLevel    = data.midLevel,
        timestamp    = data.timestamp or time(),
        clearedLevel = data.clearedLevel or (data.level and math.max(0, data.level - 1)) or 0,
        stars        = data.stars or {},
        endlessWave     = data.endlessWave or 0,
        endlessRunScore = data.endlessRunScore or 0,
    }
end

function S:LoadSlot(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return nil end
    local db = GetDB()
    return EnsureSaves(db)[slot]
end

function S:DeleteSlot(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)[slot] = nil
end

-- ── Mid-Level-State (Resume) ──────────────────────────────────
function S:SaveMidLevel(slot, gameState)
    local save = self:LoadSlot(slot)
    if not save then return end
    save.midLevel  = gameState
    save.timestamp = time()
end

function S:LoadMidLevel(slot)
    local save = self:LoadSlot(slot)
    return save and save.midLevel or nil
end

function S:ClearMidLevel(slot)
    local save = self:LoadSlot(slot)
    if save then save.midLevel = nil end
end

-- ── Kumulative Achievement-Zähler ─────────────────────────────
local function EnsureStats(db)
    if not db.stats then
        db.stats = { totalLevels = 0, totalPowerUps = 0, totalTimeWins = 0,
                     totalIce = 0, totalCombo5 = 0, totalStars = 0,
                     totalEndlessWaves = 0, endlessBestWave = 0 }
    end
    return db.stats
end

function S:GetStats()
    return EnsureStats(GetDB())
end

function S:AddStats(delta)
    local stats = EnsureStats(GetDB())
    for k, v in pairs(delta) do
        stats[k] = (stats[k] or 0) + v
    end
end

function S:NoteEndlessBest(wave)
    local stats = EnsureStats(GetDB())
    local w = tonumber(wave) or 0
    if w > (stats.endlessBestWave or 0) then
        stats.endlessBestWave = w
    end
end

function S:CopyStars(stars)
    local out = {}
    if type(stars) ~= "table" then return out end
    for k, v in pairs(stars) do
        local n = tonumber(k)
        if n then out[n] = tonumber(v) or 0 end
    end
    return out
end

function S:SumStars(save)
    local sum = 0
    if not save or type(save.stars) ~= "table" then return 0 end
    for _, v in pairs(save.stars) do
        sum = sum + (tonumber(v) or 0)
    end
    return sum
end

function S:GetStar(save, level)
    if not save or type(save.stars) ~= "table" then return 0 end
    return tonumber(save.stars[level]) or 0
end

function S:IsLevelUnlocked(save, level, count)
    if not save or not level or level < 1 then return false end
    if count and level > count then return false end
    if level == 1 then return true end
    local cleared = tonumber(save.clearedLevel) or 0
    if cleared >= (level - 1) then return true end
    if self:GetStar(save, level - 1) >= 1 then return true end
    local cursor = tonumber(save.level) or 1
    return cursor >= level
end
