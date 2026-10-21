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

function S:Set(key,value)
    if key=="difficulty" then
        if ArcadiaNexus.SHG_Engine.gameState or not ArcadiaNexus.SHG_Logic:IsDifficulty(value) then return false end
    end
    P:SetGameSetting(DB_KEY,key,value)
    local R=ArcadiaNexus.SHG_Renderer; if R and R.RefreshConfiguration then R:RefreshConfiguration() end
    return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do if k~="chips" and k~="bet" then db[k]=nil end end
    local E=ArcadiaNexus.SHG_Engine
    if E.gameState then db.difficulty=E.gameState.difficulty end
    local R=ArcadiaNexus.SHG_Renderer; if R and R.RefreshConfiguration then R:RefreshConfiguration() end
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

S.MAX_SLOTS=3
function S:EnsureMigration()
    local db=GetDB(); db.slots=db.slots or {}
    if db.capitalMigration==2 then return end
    local L=ArcadiaNexus.SHG_Logic
    if db.chips~=nil then
        if type(db.chips)~="number" or not L:IsUnits(db.chips*2) then return end
        local slot; for i=1,3 do if not db.slots[i] then slot=i; break end end
        if not slot then return end
        local diff=L:IsDifficulty(db.difficulty) and db.difficulty or self.Defaults.difficulty
        local gs=L:NewGameState(diff,db.chips,0)
        gs.legacyCapital=true
        if gs.chips2<50 then gs.phase="GAMEOVER" end
        gs.runId=ArcadiaNexus.LocalResults:NewRun("SHELLGAME"); gs.tableId=gs.runId
        db.slots[slot]=gs
    end
    db.capitalMigration=2
end
function S:LoadSlot(slot) self:EnsureMigration(); return GetDB().slots[slot] end
function S:SaveSlot(slot,save)
    if not ArcadiaNexus.SHG_Logic:IsUnits(slot) or slot<1 or slot>3 then return false end
    local db=GetDB(); db.slots=db.slots or {}; db.slots[slot]=save; return true
end
function S:DeleteSlot(slot)
    local E=ArcadiaNexus.SHG_Engine
    if E.gameState and E.activeSlot==slot then return false end
    local db=GetDB(); if db.slots then db.slots[slot]=nil end
    ArcadiaNexus.LocalResults:Prune(); return true
end
