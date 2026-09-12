local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SI7_Settings = {}
local S = ArcadiaNexus.SI7_Settings

local DB_KEY = "SI7"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    soundEnabled = true,
    lastMode     = "hotseat",
}

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    local v = db[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

function S:Set(key, value)
    P:SetGameSetting(DB_KEY, key, value)
end

function S:Reset()
    local db = GetDB()
    db.soundEnabled = nil
    db.lastMode = nil
end
