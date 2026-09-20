-- ============================================================
--  Darkmoon Pinball – Settings.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.DMP_Settings = {}
local S = ArcadiaNexus.DMP_Settings

S.Defaults = {
    soundEnabled   = true,
    soundOnBumper  = true,
    soundOnFlipper = true,
    soundOnDrain   = true,
    soundOnLaunch  = true,
    soundOnPlunger = true,
    soundOnKickback = true,
    soundOnTilt    = true,
    screenFlash    = true,
    reducedMotion  = false,
    debugOverlay   = false,
    tableId        = "darkmoon_midway",
    soundOnTarget  = true,
    soundOnSling   = true,
    soundOnMission = true,
    soundOnJackpot = true,
    soundOnMultiball = true,
    soundOnSave    = true,
}

local DB_KEY = "DARKMOON_PINBALL"
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
    for k in pairs(self.Defaults) do
        r[k] = self:Get(k)
    end
    return r
end
