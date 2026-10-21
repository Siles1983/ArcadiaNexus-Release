--[[
    ArcadiaNexus – Snake
    Games/Snake/Settings.lua
    Version: 2.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Settings = {}
local S = ArcadiaNexus.SNK_Settings

S.MAX_SLOTS=3

S.Defaults = {
    difficulty      = "easy",
    soundEnabled    = true,
    soundOnEat      = true,
    soundOnDie      = true,
    soundOnStart    = true,
}

local DB_KEY = "SNAKE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.SNK_Engine
    if key=="difficulty" and E and E.activeGame and (E.state=="PLAYING" or E.state=="PAUSED") then return E.activeGame.board.difficulty end
    if key == "theme" then return "tiles" end  -- immer tiles
    local db = GetDB()
    if key=="difficulty" then return ArcadiaNexus.SNK_Themes:NormalizeDifficulty(db[key]) end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    if key == "theme" then return end  -- theme ist fix, nicht speichern
    local E=ArcadiaNexus.SNK_Engine
    if key=="difficulty" and E and (E.state=="PLAYING" or E.state=="PAUSED") then return false end
    if key=="difficulty" then value=ArcadiaNexus.SNK_Themes:NormalizeDifficulty(value) end
    P:SetGameSetting(DB_KEY, key, value); return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.SNK_Engine
    if not E or E.state=="IDLE" or E.state=="GAMEOVER" then db.difficulty=nil end
    db.soundEnabled = nil
    db.soundOnEat   = nil
    db.soundOnDie   = nil
    db.soundOnStart = nil
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

function S:GetActiveSlot() return GetDB().activeSlot or 1 end
function S:SetActiveSlot(slot) if type(slot)=="number" and slot%1==0 and slot>=1 and slot<=3 then GetDB().activeSlot=slot end end
function S:LoadSlot(slot) return (GetDB().saves or {})[slot] end
function S:SaveSlot(slot,data)
    if not slot or slot%1~=0 or slot<1 or slot>3 then return end
    local db=GetDB(); db.saves=db.saves or {}; db.saves[slot]=ArcadiaNexus.SNK_Logic:Copy(data)
    if data then db.saves[slot].timestamp=time() end
end
function S:DeleteSlot(slot) local db=GetDB(); if db.saves then db.saves[slot]=nil end end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.SNK_Logic:Copy(data)
end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
