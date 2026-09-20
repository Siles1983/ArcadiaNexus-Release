--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Settings.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Settings = {}
local S = ArcadiaNexus.BS_Settings

S.MAX_SLOTS = 3
S.DB_KEY = "BUBBLESHOOTER"
-- Bump when a campaign board layout changes in a way that makes paused
-- snapshots incompatible with the authored/generated level definition.
S.CAMPAIGN_VERSION = 2

S.Defaults = {
    difficulty       = "easy",
    mode             = "endless",
    theme            = "energies",
    soundEnabled     = true,
    soundOnShoot     = true,
    soundOnPop       = true,
    soundOnDrop      = true,
    soundOnPower     = true,
    soundOnOvercharge = true,
    soundOnWin       = true,
    soundOnLose      = true,
    screenFlash      = true,
    colorblind       = false,
}

local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(S.DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    P:SetGameSetting(S.DB_KEY, key, value)
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

function S:AddStat(key, amount)
    local db = GetDB()
    db.stats = db.stats or {}
    db.stats[key] = (db.stats[key] or 0) + (amount or 1)
end

function S:GetStats()
    local db = GetDB()
    return db.stats or {}
end

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
    if data then
        local now = (time and time()) or 0
        data.timestamp = data.timestamp or now
    end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:PackProgress(state, extra)
    extra = extra or {}
    local Logic = ArcadiaNexus.BS_Logic
    local paused = extra.paused == true
    local mid = extra.midGame
    if mid == nil and paused and Logic then
        mid = Logic:Serialize(state)
    end
    return {
        currentLevel = extra.currentLevel or (state and state.levelIndex) or 1,
        score        = extra.score or (state and state.score) or 0,
        diff         = extra.diff or (state and state.difficulty) or "easy",
        mode         = "shot",
        midGame      = mid,
        stars        = extra.stars or {},
        campaignVersion = extra.campaignVersion or S.CAMPAIGN_VERSION,
        clearedLevel = extra.clearedLevel or 0,
        timestamp    = (time and time()) or 0,
        paused       = paused,
    }
end
