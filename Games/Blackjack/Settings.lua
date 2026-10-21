-- ============================================================
--  Blackjack – Settings.lua
--  Persistente Einstellungen via ArcadiaNexusDB
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BJ_Settings = {}
local S = ArcadiaNexus.BJ_Settings

S.Defaults = {
    theme        = "neutral",
    aiCount      = 0,
    soundEnabled = true,
    soundOnDeal  = true,
    soundOnFlip  = true,
    soundOnWin   = true,
    soundOnLose  = true,
    soundOnBust  = true,
    soundOnChip  = true,
}

local DB_KEY = "BLACKJACK"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    local E=ArcadiaNexus.BJ_Engine
    if key=="aiCount" and E and E.gameState then return E.gameState.aiCount end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key,value)
    if self.Defaults[key]==nil then return false end
    if key=="aiCount" then return ArcadiaNexus.BJ_Engine:SetAICount(value) end
    P:SetGameSetting(DB_KEY,key,value); return true
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


S.MAX_SLOTS=3
function S:EnsureMigration()
    local db=GetDB()
    if db.tableMigration==2 then return end
    db.slots=db.slots or {}
    if type(db.chips)=="number" and db.chips>=0 and db.chips<1073741823 and db.chips*2==math.floor(db.chips*2) then
        local slot
        for i=1,3 do if not db.slots[i] then slot=i; break end end
        if not slot then return end
        local count=tonumber(db.aiCount) or 0
        if count~=math.floor(count) or count<0 or count>2 then count=0 end
        local gs=ArcadiaNexus.BJ_Logic:NewGameState("table",count,db.chips)
        gs.runId=ArcadiaNexus.LocalResults:NewRun("BLACKJACK"); gs.tableId=gs.runId; gs.legacyCapital=true
        if gs.chips2<50 then gs.phase="GAMEOVER" end
        db.slots[slot]=gs
    end
    db.chips=nil; db.difficulty=nil; db.tableMigration=2
end
function S:LoadSlot(slot) self:EnsureMigration(); return GetDB().slots[slot] end
function S:SaveSlot(slot,save)
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 then return false end
    local db=GetDB(); db.slots=db.slots or {}; db.slots[slot]=save; return true
end
function S:DeleteSlot(slot)
    local E=ArcadiaNexus.BJ_Engine
    if E.gameState and E.activeSlot==slot then return false end
    local db=GetDB(); if db.slots then db.slots[slot]=nil end
    ArcadiaNexus.LocalResults:Prune(); return true
end
function S:_SetAICount(value) P:SetGameSetting(DB_KEY,"aiCount",value) end
