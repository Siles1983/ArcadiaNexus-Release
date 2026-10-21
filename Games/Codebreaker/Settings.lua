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

S.MAX_SLOTS = 1
function S:Set(key, value)
    if key == "difficulty" then
        if ArcadiaNexus.CB_Engine.activeGame or not ArcadiaNexus.CB_Logic.CONFIGS[value] then return false end
    elseif key == "theme" then
        if not ArcadiaNexus.CB_Themes.THEMES[value] then return false end
    elseif DEFAULTS[key] == nil then return false end
    P:SetGameSetting(DB_KEY, key, value)
    return true
end

function S:GetAll()
    local t = {}
    for k, v in pairs(DEFAULTS) do t[k] = self:Get(k) end
    return t
end

function S:Reset()
    local db = GetDB()
    for k in pairs(DEFAULTS) do db[k] = nil end
    db.codeLength, db.duplicates = nil, nil
end

function S:LoadSlot(slot)
    if slot~=nil and slot~=1 then return nil end
    local slots=GetDB().slots
    if not slots then return nil end
    if slots[1] then return slots[1] end
    for i=2,3 do
        if slots[i] then
            slots[1]=slots[i]
            slots[2],slots[3]=nil,nil
            return slots[1]
        end
    end
end
function S:LoadSave()
    return self:LoadSlot(1)
end
function S:SaveSlot(slot, save)
    if slot~=nil and slot~=1 then return false end
    local db=GetDB()
    db.slots={ [1]=save }
    return true
end
function S:SaveGame(save)
    return self:SaveSlot(1, save)
end
function S:DeleteSlot(slot)
    if slot~=nil and slot~=1 then return false end
    local E=ArcadiaNexus.CB_Engine
    if E.activeGame then return false end
    local db=GetDB()
    if db.slots then db.slots[1]=nil end
    ArcadiaNexus.LocalResults:Prune()
    return true
end
