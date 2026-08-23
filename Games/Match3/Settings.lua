-- ============================================================
--  Match3 – Settings.lua
--  Persistente Einstellungen. Kein UI, kein Gameplay.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.M3_Settings = {}
local S = ArcadiaNexus.M3_Settings

S.Defaults = {
    difficulty      = "easy",       -- "easy" | "normal" | "hard"
    theme           = "raidmarker", -- "raidmarker" | "professions" | "resources" | "abilities" | "classic"
    timerActive     = false,
    soundEnabled    = true,
    soundOnMatch    = true,
    soundOnMove     = true,
    soundOnCombo    = true,
    soundOnGameover = true,
}

local DB_KEY = "MATCH3"
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
