-- ============================================================
--  HigherOrLower – Settings.lua
--  Persistente Einstellungen via ArcadiaNexusDB
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HOL_Settings = {}
local S = ArcadiaNexus.HOL_Settings

S.Defaults = {
    difficulty      = "easy",
    theme           = "neutral",
    soundEnabled    = true,
    soundOnFlip     = true,
    soundOnCorrect  = true,
    soundOnWrong    = true,
    soundOnCashout  = true,
    soundOnJoker    = true,
    chips           = 100,   -- Kapital persistent gespeichert
    bet             = 25,    -- Letzter Einsatz
}

local DB_KEY = "HIGHERORLOWER"
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

-- Kapital speichern (nach jeder Runden-Abrechnung aufrufen)
function S:SaveChips(amount)
    self:Set("chips", amount)
end

-- Kapital laden (beim Spielstart)
function S:LoadChips()
    local chips = self:Get("chips")
    if not chips or chips <= 0 then
        self:SaveChips(100)
        return 100
    end
    return chips
end

-- Kapital auf Startwert zurücksetzen (nur bei Bankrott)
function S:ResetChips()
    self:Set("chips", 100)
end
