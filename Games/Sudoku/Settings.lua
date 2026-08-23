--[[
    Gaming Hub
    Games/Sudoku/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Settings = {}
local S = ArcadiaNexus.SDK_Settings

S.Defaults = {
    difficulty     = "normal",  -- "easy" | "normal" | "hard"
    soundEnabled   = true,
    soundOnPlace   = true,
    soundOnError   = true,
    soundOnComplete = true,
}

local DB_KEY = "SUDOKU"
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
    local result = {}
    for k in pairs(self.Defaults) do result[k] = self:Get(k) end
    return result
end
