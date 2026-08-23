--[[
    Gaming Hub
    Games/Memory/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Settings = {}
local S = ArcadiaNexus.AP_Settings

S.Defaults = {
    difficulty      = "easy",
    theme           = "classes",
    cardBackMode    = "AUTO",       -- "AUTO"|"ALLIANCE"|"HORDE"|"NEUTRAL"
    timerActive     = false,
    soundEnabled    = true,
    soundOnFlip     = true,
    soundOnMatch    = true,
    soundOnMismatch = true,
    soundOnWin      = true,
    soundOnLose     = true,
}

local DB_KEY = "ARCADIAPAIRS"
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

function S:GetDeckList()
    local Logic = ArcadiaNexus.AP_Logic
    return (Logic and Logic.GetDeckList) and Logic:GetDeckList() or {}
end
