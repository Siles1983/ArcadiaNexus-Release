-- ============================================================
--  BlockBreaker – Settings.lua
--  Persistente Einstellungen. Kein UI, kein Gameplay.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BB_Settings = {}
local S = ArcadiaNexus.BB_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty      = "easy",   -- "easy" | "normal" | "hard"
    theme           = "random", -- "random" | "blue" | "green" | "red" | "violett" | "yellow"
    soundEnabled    = true,
    soundOnBounce   = true,
    soundOnBreak    = true,
    soundOnPowerUp  = true,
    soundOnLifeLost = true,
    soundOnWin      = true,
    soundOnLose     = true,
    screenFlash     = true,
}

local DB_KEY = "BLOCKBREAKER"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

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
local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    if not db.saves[1] and db.savedLevel then
        db.saves[1] = {
            level     = db.savedLevel,
            score     = db.savedScore or 0,
            lives     = db.savedLives or 3,
            diff      = db.savedDiff or "easy",
            completed = db.savedCompleted and true or nil,
            timestamp = time(),
        }
        db.savedLevel, db.savedScore, db.savedLives = nil, nil, nil
        db.savedDiff, db.savedCompleted = nil, nil
    end
    return db.saves
end

function S:GetActiveSlot()
    local db = GetDB()
    EnsureSaves(db)
    return db.activeSlot or 1
end

function S:SetActiveSlot(slot)
    local db = GetDB()
    EnsureSaves(db)
    slot = tonumber(slot) or 1
    if slot >= 1 and slot <= S.MAX_SLOTS then db.activeSlot = slot end
end

function S:LoadSlot(slot)
    slot = tonumber(slot) or self:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return nil end
    local db = GetDB()
    EnsureSaves(db)
    return db.saves[slot]
end

function S:SaveSlot(slot, data)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)[slot] = data
    if data then data.timestamp = data.timestamp or time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:ResetSlot(slot)
    self:SaveSlot(slot, {
        level = 1, score = 0, lives = 3,
        diff = self:Get("difficulty") or "easy",
    })
end

function S:SaveProgress(level, score, lives, diff, completed)
    local slot = self:GetActiveSlot()
    self:SaveSlot(slot, {
        level     = level,
        score     = score,
        lives     = lives,
        diff      = diff,
        completed = completed and true or nil,
    })
end

function S:LoadProgress(slot)
    local save = self:LoadSlot(slot or self:GetActiveSlot())
    if not save then return nil end
    local level = save.level or 1
    if save.completed then level = level + 1 end
    return {
        level = level,
        score = save.score or 0,
        lives = save.lives or 3,
        diff  = save.diff or "easy",
    }
end

function S:ClearProgress(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end
