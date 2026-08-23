-- ============================================================
--  ShellGame – Settings.lua
--  Persistente Einstellungen via ArcadiaNexusDB
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SHG_Settings = {}
local S = ArcadiaNexus.SHG_Settings

S.Defaults = {
    difficulty      = "easy",
    themeGroup      = "alliance",   -- "alliance" | "horde" | "neutral" | "random"
    theme           = "random",     -- konkreter Key oder "random"
    ball            = "random",     -- "blue"|"green"|"red"|"violett"|"yellow"|"random"
    chips           = 100,
    bet             = 25,
    soundEnabled    = true,
    soundOnReveal   = true,
    soundOnShuffle  = true,
    soundOnLift     = true,
    soundOnWin      = true,
    soundOnLose     = true,
    soundOnBankrupt = true,
}

local DB_KEY = "SHELLGAME"
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

function S:SaveChips(amount)
    self:Set("chips", amount)
end

function S:LoadChips()
    local chips = self:Get("chips")
    if not chips or chips <= 0 then
        self:SaveChips(100)
        return 100
    end
    return chips
end

function S:ResetChips()
    self:Set("chips", 100)
end

function S:SaveBet(amount)
    self:Set("bet", amount)
end

function S:LoadBet()
    return self:Get("bet") or 25
end
