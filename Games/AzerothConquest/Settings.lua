--[[
    Gaming Hub
    Games/AzerothConquest/Settings.lua
    Version: 1.0.0

    Namespace: ArcadiaNexus.AC_Settings
    DB-Key:    "AzerothConquest"
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_Settings = {}
local S = ArcadiaNexus.AC_Settings

S.Defaults = {
    gridSize     = 10,       -- 8 | 10 | 12
    aiDifficulty = "easy",   -- "easy" | "normal" | "hard"
    soundEnabled = true,
    soundOnWin   = true,
    soundOnLoss  = true,
    soundOnHit   = true,
    soundOnMiss  = true,
    soundOnSunk  = true,
}

local DB_KEY = "AZEROTHCONQUEST"
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
    GetDB()[key] = value
    self:_EnforceRules(key)
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local result = {}
    for k in pairs(self.Defaults) do result[k] = self:Get(k) end
    return result
end

function S:_EnforceRules(changedKey)
    local db = GetDB()
    if changedKey == "soundEnabled" and db["soundEnabled"] == false then
        db["soundOnWin"]  = false
        db["soundOnLoss"] = false
        db["soundOnHit"]  = false
        db["soundOnMiss"] = false
        db["soundOnSunk"] = false
    end
    if (changedKey == "soundOnWin" or changedKey == "soundOnLoss" or
        changedKey == "soundOnHit" or changedKey == "soundOnMiss" or
        changedKey == "soundOnSunk")
        and db[changedKey] == true then
        db["soundEnabled"] = true
    end
end
