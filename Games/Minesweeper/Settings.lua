--[[
    Gaming Hub
    Games/Minesweeper/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MS_Settings = {}
local S = ArcadiaNexus.MS_Settings

S.Defaults = {
    difficulty      = "easy",
    soundEnabled    = true,
    soundOnReveal   = true,
    soundOnFlag     = true,
    soundOnExplode  = true,
    soundOnWin      = true,
}

local DB_KEY = "MINESWEEPER"
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
