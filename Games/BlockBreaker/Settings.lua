-- ============================================================
--  BlockBreaker – Settings.lua
--  Persistente Einstellungen. Kein UI, kein Gameplay.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BB_Settings = {}
local S = ArcadiaNexus.BB_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty      = "easy",   -- "easy" | "normal" | "hard"
    theme           = "random", -- "random" | "blue" | "green" | "red" | "violett" | "yellow"
    soundEnabled    = true,
    soundOnBounce   = true,
    soundOnBreak    = true,
    soundOnPowerUp  = true,
    soundOnLifeLost = true,
    soundOnWin      = true,
    soundOnLose     = true,
    screenFlash     = true,
    reducedMotion   = false,
    debugOverlay    = true,  -- DevMode: F8 blendet Spawn-Buttons / Preview-HUD aus
}

local DB_KEY = "BLOCKBREAKER"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.BB_Engine
    if key=="difficulty" and E and E.gameState and E.state~="IDLE" and E.state~="GAMEOVER" then return E.gameState.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key,value)
    if key=="difficulty" then
        local E=ArcadiaNexus.BB_Engine
        if E and E.gameState and E.state~="IDLE" and E.state~="GAMEOVER" then return false end
        if not ArcadiaNexus.BB_Logic.DIFFICULTY_DEFS[value] then return false end
    end
    P:SetGameSetting(DB_KEY,key,value); return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.BB_Engine
    local locked=E and E.gameState and E.state~="IDLE" and E.state~="GAMEOVER"
    for k in pairs(self.Defaults) do if k~="difficulty" or not locked then db[k]=nil end end
    local R=ArcadiaNexus.BB_Renderer; if R and R.RefreshConfig then R:RefreshConfig() end
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
    if not db.saves[1] and db.savedLevel then
        db.saves[1] = {
            level     = db.savedLevel,
            score     = db.savedScore or 0,
            lives     = db.savedLives or 3,
            diff      = db.savedDiff or "easy",
            completed = db.savedCompleted and true or nil,
            timestamp = time(),
        }
        db.savedLevel, db.savedScore, db.savedLives = nil, nil, nil
        db.savedDiff, db.savedCompleted = nil, nil
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
    EnsureSaves(db)[slot] = ArcadiaNexus.BB_Logic:Copy(data)
    if data then EnsureSaves(db)[slot].timestamp=time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
    self:ClearLevelTimes(slot)
end

function S:NoteLevelTime(slot, level, elapsedMs)
    slot, level, elapsedMs = tonumber(slot), tonumber(level), tonumber(elapsedMs)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    if not level or level < 1 or level > 100 or level % 1 ~= 0 then return end
    if not elapsedMs or elapsedMs < 0 or elapsedMs ~= elapsedMs or elapsedMs >= math.huge or elapsedMs % 1 ~= 0 then return end
    local db = GetDB()
    db.levelBestMs = db.levelBestMs or {}
    db.levelBestMs[slot] = db.levelBestMs[slot] or {}
    local prev = db.levelBestMs[slot][level]
    if not prev or elapsedMs < prev then db.levelBestMs[slot][level] = elapsedMs end
end

function S:GetLevelTime(slot, level)
    local all = GetDB().levelBestMs
    local row = all and all[tonumber(slot)]
    return row and row[tonumber(level)] or nil
end

function S:ClearLevelTimes(slot)
    slot = tonumber(slot)
    local all = GetDB().levelBestMs
    if all and slot then all[slot] = nil end
end

function S:SaveProgress(state,slot,phase)
    local save=ArcadiaNexus.BB_Logic:Snapshot(state,phase)
    if save then self:SaveSlot(slot,save) end
end
function S:LoadProgress(slot) return ArcadiaNexus.BB_Logic:Copy(self:LoadSlot(slot)) end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}
    db.pendingResults[data.runId]=ArcadiaNexus.BB_Logic:Copy(data)
end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
function S:GetPending() return GetDB().pendingResults or {} end

function S:ClearProgress(slot)
    slot = tonumber(slot) or self:GetActiveSlot()
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end
