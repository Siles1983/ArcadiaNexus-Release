-- Blockdrop – Games/Blockdrop/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BLD_Settings = {}
local S = ArcadiaNexus.BLD_Settings

local DB_KEY  = "BLOCKDROP"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    difficulty   = "NORMAL",
    theme        = "CLASSIC",
    background   = "CLASSIC",
    snd_move     = true,
    snd_rotate   = true,
    snd_line     = true,
    snd_blockdrop = true,
    snd_levelup  = true,
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

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

S.MAX_SLOTS = 3

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
    if slot >= 1 and slot <= S.MAX_SLOTS then
        db.activeSlot = slot
    end
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
    local saves = EnsureSaves(db)
    saves[slot] = ArcadiaNexus.BLD_Logic:Copy(data)
    if data then saves[slot].timestamp=time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:ResetSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    self:SaveSlot(slot, { level = 0, score = 0, lines = 0, midGame = nil })
end

function S:SaveMidGame(slot,midGame)
    if not midGame then return end
    self:SaveSlot(slot,{runId=midGame.runId,level=midGame.level,score=midGame.score,lines=midGame.lines,midGame=midGame})
end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=ArcadiaNexus.BLD_Logic:Copy(data)
end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end

function S:ClearMidGame(slot)
    local save = self:LoadSlot(slot)
    if save then save.midGame = nil end
end

-- Highscore-Verwaltung erfolgt ausschliesslich ueber ScoreManager (GAME_RESULT-Event).
