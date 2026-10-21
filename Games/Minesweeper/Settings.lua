--[[
    Gaming Hub
    Games/Minesweeper/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MS_Settings = {}
local S = ArcadiaNexus.MS_Settings

S.Defaults = {
    difficulty      = "easy",
    soundEnabled    = true,
    soundOnReveal   = true,
    soundOnFlag     = true,
    soundOnExplode  = true,
    soundOnWin      = true,
}

local DB_KEY = "MINESWEEPER"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

S.MAX_SLOTS=3
function S:Set(key,value)
    if key=="difficulty" and (ArcadiaNexus.MS_Engine.activeGame or not ArcadiaNexus.MS_Logic.CONFIGS[value]) then return false end
    if self.Defaults[key]==nil then return false end
    P:SetGameSetting(DB_KEY,key,value)
    return true
end

function S:LoadSlot(slot)
    local slots=GetDB().slots
    return slots and slots[slot]
end
function S:SaveSlot(slot,save)
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>self.MAX_SLOTS then return false end
    local db=GetDB()
    db.slots=db.slots or {}
    db.slots[slot]=save
    return true
end
function S:DeleteSlot(slot)
    local E=ArcadiaNexus.MS_Engine
    if E.activeGame and E.activeSlot==slot then return false end
    local slots=GetDB().slots
    if slots then slots[slot]=nil end
    ArcadiaNexus.LocalResults:Prune()
    return true
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
