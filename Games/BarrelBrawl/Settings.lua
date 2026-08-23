--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/Settings.lua
    Version: 1.0.0

    Defaults + SavedVariables via ArcadiaNexus.Persistence.
    3 Save-Slots für Level-Fortschritt.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BRB_Settings = {}
local S = ArcadiaNexus.BRB_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty   = "normal",
    soundEnabled = true,
    soundOnScore = true,
    soundOnHit   = true,
    soundOnWin   = true,
}

local DB_KEY = "BARREL_BRAWL"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

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
        diff = self:Get("difficulty") or "normal",
        time = 0,
        stats = { jumped = 0, rescues = 0, spawned = 0 },
    })
end

function S:SaveProgress(p)
    self:SaveSlot(self:GetActiveSlot(), {
        level = p.level, score = p.score, lives = p.lives,
        diff = p.diff, time = p.time or 0,
        stats = p.stats,
    })
end

function S:LoadProgress(slot)
    return self:LoadSlot(slot or self:GetActiveSlot())
end

function S:ClearProgress(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end
