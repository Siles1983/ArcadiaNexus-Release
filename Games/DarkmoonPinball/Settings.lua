-- ============================================================
--  Darkmoon Pinball – Settings.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.DMP_Settings = {}
local S = ArcadiaNexus.DMP_Settings

S.Defaults = {
    soundEnabled   = true,
    soundOnBumper  = true,
    soundOnFlipper = true,
    soundOnDrain   = true,
    soundOnLaunch  = true,
    soundOnPlunger = true,
    soundOnKickback = true,
    soundOnTilt    = true,
    screenFlash    = true,
    reducedMotion  = false,
    debugOverlay   = false,
    tableId        = "darkmoon_midway",
    soundOnTarget  = true,
    soundOnSling   = true,
    soundOnMission = true,
    soundOnJackpot = true,
    soundOnMultiball = true,
    soundOnSave    = true,
}

local DB_KEY = "DARKMOON_PINBALL"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key,value)
    local E=ArcadiaNexus.DMP_Engine
    if key=="tableId" and E and (E.state=="PLAYING" or E.state=="PAUSED") then return false end
    P:SetGameSetting(DB_KEY,key,value); return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        if k~="tableId" or not ArcadiaNexus.DMP_Engine or (ArcadiaNexus.DMP_Engine.state~="PLAYING" and ArcadiaNexus.DMP_Engine.state~="PAUSED") then db[k]=nil end
    end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do
        r[k] = self:Get(k)
    end
    return r
end

S.MAX_SLOTS=3
function S:GetActiveSlot() return GetDB().activeSlot or 1 end
function S:SetActiveSlot(slot) GetDB().activeSlot=slot end
function S:LoadSlot(slot) local db=GetDB(); return db.saves and db.saves[slot] end
function S:SaveSlot(slot,data)
    if not slot or slot%1~=0 or slot<1 or slot>3 then return end
    local db=GetDB(); db.saves=db.saves or {}
    db.saves[slot]=ArcadiaNexus.DMP_Logic:Copy(data)
    if data then db.saves[slot].timestamp=time() end
end
function S:DeleteSlot(slot) local db=GetDB(); if db.saves then db.saves[slot]=nil end end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.DMP_Logic:Copy(data)
end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
