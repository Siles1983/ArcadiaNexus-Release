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
    local g=ArcadiaNexus.LOA_Engine and ArcadiaNexus.LOA_Engine.activeGame
    if g and key=="playerColor" then return g.humanColor end
    if g and key=="aiCount" then return g.aiCount end
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
    local E=ArcadiaNexus.LOA_Engine
    if (key=="playerColor" or key=="aiCount") and E and E._running then return false end
    P:SetGameSetting(DB_KEY, key, value)
    if key == "aiCount" then
        GetDB().playerCount = nil
    end
    return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.LOA_Engine
    for k in pairs(self.Defaults) do
        if not E or not E._running or k~="playerColor" and k~="aiCount" then db[k]=nil end
    end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end
