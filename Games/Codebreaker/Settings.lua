--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Settings.lua
    v1.1.0: Migration auf ArcadiaNexusDB.gameSettings.CODEBREAKER
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Settings = {}
local S = ArcadiaNexus.CB_Settings

local DB_KEY  = "CODEBREAKER"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    difficulty   = "normal",
    theme        = "gems",
    codeLength   = 4,
    duplicates   = true,
    soundEnabled = true,
    soundOnPlace = true,
    soundOnSubmit= true,
    soundOnWin   = true,
    soundOnLose  = true,
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

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:GetAll()
    local t = {}
    for k, v in pairs(DEFAULTS) do t[k] = self:Get(k) end
    return t
end

function S:Reset()
    local db = GetDB()
    for k in pairs(db) do db[k] = nil end
end
