--[[
    ArcadiaNexus – Goblin Blast
    Games/GoblinBlast/Settings.lua
    Version: 1.0.0
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GB_Settings = {}
local S = ArcadiaNexus.GB_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty      = "easy",
    soundEnabled    = true,
    soundOnExplode  = true,
    soundOnPowerup  = true,
    soundOnDie      = true,
    soundOnWin      = true,
}

local DB_KEY = "GOBLINBLAST"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.GB_Engine
    if key=="difficulty" and E and E.board and E.state~="IDLE" and E.state~="GAMEOVER" then return E.board.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    local E=ArcadiaNexus.GB_Engine
    if key=="difficulty" and E and E.state~="IDLE" and E.state~="GAMEOVER" then return false end
    P:SetGameSetting(DB_KEY,key,value); return true
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        if k~="difficulty" or not ArcadiaNexus.GB_Engine or ArcadiaNexus.GB_Engine.state=="IDLE" or ArcadiaNexus.GB_Engine.state=="GAMEOVER" then db[k]=nil end
    end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Save-Slots ────────────────────────────────────────────────
local function PackProgress(p)
    return {
        level    = p.level,
        score    = p.score or 0,
        lives    = p.lives or 3,
        diff     = p.diff or "easy",
        radius   = p.radius or 2,
        bombsMax = p.bombsMax or 1,
        time     = p.time or 0,
        stats    = p.stats and {
            walls    = p.stats.walls    or 0,
            enemies  = p.stats.enemies  or 0,
            powerups = p.stats.powerups or 0,
            maxChain = p.stats.maxChain or 0,
        } or nil,
        timestamp = time(),
    }
end

local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
    if not db.saves[1] and db.savedLevel then
        db.saves[1] = PackProgress({
            level = db.savedLevel, score = db.savedScore, lives = db.savedLives,
            diff = db.savedDiff, radius = db.savedRadius, bombsMax = db.savedBombsMax,
            time = db.savedTime, stats = db.savedStats,
        })
        db.savedLevel, db.savedScore, db.savedLives, db.savedDiff = nil, nil, nil, nil
        db.savedRadius, db.savedBombsMax, db.savedTime, db.savedStats = nil, nil, nil, nil
    end
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
    EnsureSaves(db)[slot] = ArcadiaNexus.GB_Logic:Copy(data)
    if data then db.saves[slot].timestamp=time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

-- New runs write their validated actual world instead of a fabricated checkpoint.
function S:ResetSlot(slot,config)
    config=config or {difficulty=self:Get("difficulty")}
    local L=ArcadiaNexus.GB_Logic
    if not L.DIFFS[config.difficulty] then return false end
    local b=L:NewBoard(config); b.runId=ArcadiaNexus.LocalResults:NewRun("GOBLINBLAST")
    self:SaveSlot(slot,L:Snapshot(b,"PLAYING")); return true
end
function S:SaveProgress(snapshot,slot) self:SaveSlot(slot or self:GetActiveSlot(),snapshot) end
function S:LoadProgress(slot)
    return self:LoadSlot(slot or self:GetActiveSlot())
end

function S:ClearProgress(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end

function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.GB_Logic:Copy(data)
end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
