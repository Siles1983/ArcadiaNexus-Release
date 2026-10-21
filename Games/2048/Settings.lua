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
    reducedMotion = false,
}
S.MAX_SLOTS = 3

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
    local E = ArcadiaNexus.TDG_Engine
    if key == "boardSize" then
        if E and E.activeGame then return false end
        if value ~= 3 and value ~= 4 and value ~= 5 then return false end
    end
    GetDB()[key] = value
    self:_EnforceRules(key)
    if key == "colorTheme" or key == "reducedMotion" then ArcadiaNexus.Engine:Emit("TDG_APPEARANCE_CHANGED") end
    return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
    ArcadiaNexus.Engine:Emit("TDG_APPEARANCE_CHANGED")
end

function S:LoadSlot(slot)
    local slots = GetDB().slots
    return slots and slots[slot]
end

function S:SaveSlot(slot, save)
    if type(slot) ~= "number" or slot < 1 or slot > self.MAX_SLOTS or slot ~= math.floor(slot) then return false end
    local db = GetDB()
    db.slots = db.slots or {}
    db.slots[slot] = save
    return true
end

function S:DeleteSlot(slot)
    local E = ArcadiaNexus.TDG_Engine
    if E and E.activeGame and E.activeSlot == slot then return false end
    local slots = GetDB().slots
    if slots then slots[slot] = nil end
    if ArcadiaNexus.LocalResults then ArcadiaNexus.LocalResults:Prune() end
    return true
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
