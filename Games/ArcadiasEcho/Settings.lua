--[[
    Gaming Hub – Simon Says
    Games/ArcadiasEcho/Settings.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AE_Settings = {}
local S = ArcadiaNexus.AE_Settings

S.Defaults = {
    difficulty      = "easy",
    theme           = "runes",
    soundEnabled    = true,
    soundOnFlash    = true,
    soundOnInput    = true,
    soundOnWin      = true,
    soundOnLose     = true,
}

local DB_KEY = "ARCADIASECHO"
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
