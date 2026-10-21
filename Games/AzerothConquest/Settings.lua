--[[
    Gaming Hub
    Games/AzerothConquest/Settings.lua
    Version: 1.0.0

    Namespace: ArcadiaNexus.AC_Settings
    DB-Key:    "AzerothConquest"
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_Settings = {}
local S = ArcadiaNexus.AC_Settings
S.MAX_SLOTS = 1

S.Defaults = {
    gridSize     = 10,       -- Public rules are fixed at 10x10.
    aiDifficulty = "easy",   -- "easy" | "normal" | "hard"
    soundEnabled = true,
    soundOnWin   = true,
    soundOnLoss  = true,
    soundOnHit   = true,
    soundOnMiss  = true,
    soundOnSunk  = true,
}

local DB_KEY = "AZEROTHCONQUEST"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E = ArcadiaNexus.AC_Engine
    if key == "gridSize" then return 10 end
    if key == "aiDifficulty" and E and E:IsConfigLocked() then return E.activeGame.aiDifficulty end
    local db = GetDB()
    if key == "aiDifficulty" then return ArcadiaNexus.AC_Logic:NormalizeDifficulty(db[key]) end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    if key == "gridSize" then return false end
    local E = ArcadiaNexus.AC_Engine
    if key == "aiDifficulty" and E and E:IsConfigLocked() then return false end
    if key == "aiDifficulty" then value = ArcadiaNexus.AC_Logic:NormalizeDifficulty(value) end
    GetDB()[key] = value
    self:_EnforceRules(key)
    return true
end

function S:Reset()
    local db = GetDB()
    local E = ArcadiaNexus.AC_Engine
    for k in pairs(self.Defaults) do
        if k ~= "aiDifficulty" or not E or not E:IsConfigLocked() then db[k] = nil end
    end
end

function S:GetActiveSlot() return GetDB().activeSlot or 1 end
function S:SetActiveSlot(slot)
    if type(slot)=="number" and slot%1==0 and slot>=1 and slot<=3 then GetDB().activeSlot=slot end
end
function S:LoadSlot(slot)
    local saves = GetDB().saves or {}
    if slot ~= nil and slot ~= 1 then return saves[slot] end
    return saves[1]
end
function S:LoadSave()
    local save = self:LoadSlot(1)
    if save then return save end
    local saves = GetDB().saves
    if not saves then return nil end
    for i = 2, 3 do
        if saves[i] then
            saves[1] = saves[i]
            saves[2], saves[3] = nil, nil
            return saves[1]
        end
    end
end
function S:SaveSlot(slot,data)
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    local db=GetDB(); db.saves=db.saves or {}; db.saves[slot]=ArcadiaNexus.AC_Logic:Copy(data)
    if data then db.saves[slot].timestamp=time() end
    return true
end
function S:SaveGame(data) return self:SaveSlot(1, data) end
function S:DeleteSlot(slot)
    if slot ~= nil and slot ~= 1 then
        local db = GetDB()
        if db.saves then db.saves[slot] = nil end
        return
    end
    local db=GetDB(); if db.saves then db.saves[1]=nil end
end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.AC_Logic:Copy(data)
end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end

function S:GetAll()
    local result = {}
    for k in pairs(self.Defaults) do result[k] = self:Get(k) end
    return result
end

function S:_EnforceRules(changedKey)
    local db = GetDB()
    if changedKey == "soundEnabled" and db["soundEnabled"] == false then
        db["soundOnWin"]  = false
        db["soundOnLoss"] = false
        db["soundOnHit"]  = false
        db["soundOnMiss"] = false
        db["soundOnSunk"] = false
    end
    if (changedKey == "soundOnWin" or changedKey == "soundOnLoss" or
        changedKey == "soundOnHit" or changedKey == "soundOnMiss" or
        changedKey == "soundOnSunk")
        and db[changedKey] == true then
        db["soundEnabled"] = true
    end
end
