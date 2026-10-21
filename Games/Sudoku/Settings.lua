--[[
    Gaming Hub
    Games/Sudoku/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Settings = {}
local S = ArcadiaNexus.SDK_Settings

S.Defaults = {
    difficulty     = "normal",  -- "easy" | "normal" | "hard"
    soundEnabled   = true,
    soundOnPlace   = true,
    soundOnError   = true,
    soundOnComplete = true,
}

local DB_KEY = "SUDOKU"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.SDK_Engine
    if key=="difficulty" and E and E.activeGame then return E.activeGame.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

S.MAX_SLOTS=3
function S:Set(key,value)
    if self.Defaults[key]==nil then return false end
    if key=="difficulty" and (ArcadiaNexus.SDK_Engine.activeGame or not ArcadiaNexus.SDK_Logic:GetScore(value)) then return false end
    P:SetGameSetting(DB_KEY,key,value); return true
end
function S:LoadSlot(slot) local slots=GetDB().slots; return slots and slots[slot] end
function S:SaveSlot(slot,save)
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>self.MAX_SLOTS then return false end
    local db=GetDB(); db.slots=db.slots or {}; db.slots[slot]=save; return true
end
function S:DeleteSlot(slot)
    local E=ArcadiaNexus.SDK_Engine
    if E.activeGame and E.activeSlot==slot then return false end
    local slots=GetDB().slots; if slots then slots[slot]=nil end
    ArcadiaNexus.LocalResults:Prune(); return true
end
function S:NextPuzzleIndex(diff)
    local db=GetDB(); db.poolCursor=db.poolCursor or {}
    local previous=db.poolCursor[diff]
    if type(previous)~="number" or previous~=math.floor(previous) or previous<0 or previous>#ArcadiaNexus.SDK_Pools[diff] then previous=0 end
    local n=previous+1
    if n>#ArcadiaNexus.SDK_Pools[diff] then n=1 end
    db.poolCursor[diff]=n; return n
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
