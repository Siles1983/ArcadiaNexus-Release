local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SI7_Settings = {}
local S = ArcadiaNexus.SI7_Settings

local DB_KEY = "SI7"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    soundEnabled = true,
    lastMode     = "hotseat",
    wordSet      = "AZEROTH",
    colorblindSymbols = false,
}

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    local v = db[key]
    if v == nil and key == "puzzleLocale" then return ArcadiaNexus.ActiveLocale == "deDE" and "deDE" or "enUS" end
    if v == nil then return DEFAULTS[key] end
    return v
end

function S:IsConfigLocked()
    local E = ArcadiaNexus.SI7_Engine
    return E and E.state ~= "IDLE" or false
end

function S:Set(key, value)
    if (key == "wordSet" or key == "puzzleLocale") and self:IsConfigLocked() then return false end
    if key == "puzzleLocale" and value ~= "deDE" and value ~= "enUS" then return false end
    P:SetGameSetting(DB_KEY, key, value)
end

function S:Reset()
    local db = GetDB()
    db.soundEnabled = nil
    db.lastMode = nil
    if not self:IsConfigLocked() then db.wordSet = nil db.puzzleLocale = nil end
    db.colorblindSymbols = nil
end
