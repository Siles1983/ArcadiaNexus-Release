--[[
    Ludo of Azeroth – Settings.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Settings = {}
local S = ArcadiaNexus.LOA_Settings

S.Defaults = {
    playerColor     = 1,
    aiCount         = 1,
    soundEnabled    = true,
    soundOnRoll     = true,
    soundOnMove     = true,
    soundOnCapture  = true,
    soundOnHome     = true,
    soundOnWin      = true,
}

local DB_KEY = "LOA"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if key == "aiCount" then
        if db.aiCount ~= nil then
            return math.max(1, math.min(3, tonumber(db.aiCount) or 1))
        end
        if db.playerCount ~= nil then
            return math.max(1, math.min(3, (tonumber(db.playerCount) or 2) - 1))
        end
    end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    P:SetGameSetting(DB_KEY, key, value)
    if key == "aiCount" then
        GetDB().playerCount = nil
    end
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end
