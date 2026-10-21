--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/Settings.lua
    Version: 1.0.0

    Defaults + SavedVariables via ArcadiaNexus.Persistence.
    3 Save-Slots für Level-Fortschritt.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BRB_Settings = {}
local S = ArcadiaNexus.BRB_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty   = "normal",
    soundEnabled = true,
    soundOnScore = true,
    soundOnHit   = true,
    soundOnWin   = true,
    soundOnWarning = true,
}

local DB_KEY = "BARREL_BRAWL"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.BRB_Engine
    if key=="difficulty" and E and E.board and E.state~="IDLE" then return E.board.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    local E=ArcadiaNexus.BRB_Engine
    if key=="difficulty" and (not ArcadiaNexus.BRB_Logic.DIFFICULTY[value] or E and E.board and E.state~="IDLE") then return false end
    P:SetGameSetting(DB_KEY, key, value)
    return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        local E=ArcadiaNexus.BRB_Engine
        if k~="difficulty" or not (E and E.board and E.state~="IDLE") then db[k] = nil end
    end
    local R=ArcadiaNexus.BRB_Renderer; if R and R.RefreshConfig then R:RefreshConfig() end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Save-Slots ────────────────────────────────────────────────
local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    return db.saves
end

function S:GetActiveSlot()
    local db = GetDB()
    EnsureSaves(db)
    return db.activeSlot or 1
end

function S:SetActiveSlot(slot)
    local db = GetDB()
    EnsureSaves(db)
    slot = tonumber(slot) or 1
    if slot >= 1 and slot <= S.MAX_SLOTS then db.activeSlot = slot end
end

function S:LoadSlot(slot)
    slot = tonumber(slot) or self:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return nil end
    local db = GetDB()
    EnsureSaves(db)
    return db.saves[slot]
end

function S:SaveSlot(slot, data)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)[slot] = ArcadiaNexus.BRB_Logic:Copy(data)
    data=EnsureSaves(db)[slot]
    if data then data.timestamp = time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:SaveProgress(board,slot,phase)
    local save=ArcadiaNexus.BRB_Logic:Snapshot(board,phase)
    if save then self:SaveSlot(slot,save) end
end
function S:LoadProgress(slot) return ArcadiaNexus.BRB_Logic:Copy(self:LoadSlot(slot)) end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.BRB_Logic:Copy(data)
end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
function S:GetPending() return GetDB().pendingResults or {} end

function S:ClearProgress(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end
