--[[
    ArcadiaNexus – Snake
    Games/Snake/Settings.lua
    Version: 2.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Settings = {}
local S = ArcadiaNexus.SNK_Settings

S.Defaults = {
    difficulty      = "easy",
    soundEnabled    = true,
    soundOnEat      = true,
    soundOnDie      = true,
    soundOnStart    = true,
}

local DB_KEY = "SNAKE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    if key == "theme" then return "tiles" end  -- immer tiles
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    if key == "theme" then return end  -- theme ist fix, nicht speichern
    P:SetGameSetting(DB_KEY, key, value)
end

function S:Reset()
    local db = GetDB()
    db.difficulty   = nil
    db.soundEnabled = nil
    db.soundOnEat   = nil
    db.soundOnDie   = nil
    db.soundOnStart = nil
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end
