--[[
    Gaming Hub
    Games/2048/Settings.lua
    Version: 1.1.0

    Namespace: ArcadiaNexus.TDG_Settings
    DB-Key:    "2048"

    Einstellungen:
      Sound:  soundEnabled, soundOnLoss
      Thema:  colorTheme  ("CLASSIC"|"HORDE"|"ALLIANCE"|"NIGHTELF"|"GOBLIN")
      Brett:  boardSize   (3|4|5) – gespeichert vom Spielfeld-Button
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TDG_Settings = {}
local S = ArcadiaNexus.TDG_Settings

-- ============================================================
-- Defaults
-- ============================================================

S.Defaults = {
    -- Sound
    soundEnabled = true,
    soundOnLoss  = true,

    -- Thema
    colorTheme   = "CLASSIC",

    -- Brett-Größe (gespeichert für Buttons-Wiederherstellung, nicht Dropdown)
    boardSize    = 4,
}

local DB_KEY = "2048"
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
        db["soundOnLoss"] = false
    end
    if changedKey == "soundOnLoss" and db["soundOnLoss"] == true then
        db["soundEnabled"] = true
    end
end
