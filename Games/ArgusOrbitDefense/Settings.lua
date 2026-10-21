-- ============================================================
--  ArgusOrbitDefense – Settings.lua
--  Persistente Einstellungen + Spielfortschritt.
--  Kein UI, kein Gameplay.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AOD_Settings = {}
local S = ArcadiaNexus.AOD_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty          = "normal",
    gameMode            = "endless",
    soundEnabled        = true,
    soundOnShoot        = true,    -- shoot_01.wav
    soundOnExplode      = true,    -- player_destroy.wav (Meteore, Hunter, Schiff)
    soundOnPowerUpBomb  = true,    -- powerup_bomb.wav
    soundOnPowerUpLife  = true,    -- powerup_life.wav
    soundOnPowerUpShield= true,    -- powerup_shield.wav
    soundOnEngine       = true,    -- engine.wav (Spieler + Hunter)
    soundOnLifeLost     = true,    -- player_destroy.wav
    soundOnWaveClear    = true,    -- WoW-Fallback
    soundOnWin          = true,    -- WoW-Fallback
    soundOnLose         = true,    -- WoW-Fallback
    screenFlash         = true,
    shipParallax        = true,    -- Sterne folgen leicht der Schiffposition
}

local DB_KEY = "ARGUSORBDEFENSE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E=ArcadiaNexus.AOD_Engine
    if (key=="difficulty" or key=="gameMode") and E and E.gameState and E.state~="IDLE" then return E.gameState[key] end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key,value)
    local E=ArcadiaNexus.AOD_Engine
    if (key=="difficulty" or key=="gameMode") and E and E.gameState and E.state~="IDLE" then return false end
    if key=="difficulty" and not ArcadiaNexus.AOD_Logic.DIFFICULTY_DEFS[value] then return false end
    if key=="gameMode" and value~="levels" and value~="endless" then return false end
    P:SetGameSetting(DB_KEY,key,value); return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.AOD_Engine
    for k in pairs(self.Defaults) do
        if (k~="difficulty" and k~="gameMode") or not (E and E.gameState and E.state~="IDLE") then db[k]=nil end
    end
    local R=ArcadiaNexus.AOD_Renderer
    if R and R.RefreshConfig then R:RefreshConfig() end
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
            level = db.savedLevel,
            score = db.savedScore or 0,
            lives = db.savedLives or 3,
            diff  = db.savedDiff or "normal",
            mode  = db.savedMode or "levels",
            timestamp = time(),
        }
        db.savedLevel, db.savedScore, db.savedLives = nil, nil, nil
        db.savedDiff, db.savedMode = nil, nil
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
    EnsureSaves(db)[slot] = data
    if data then data.timestamp = time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:ResetSlot(slot) self:DeleteSlot(slot) end
function S:SaveProgress(state,slot,phase)
    local save=ArcadiaNexus.AOD_Logic:Snapshot(state,phase)
    if save then self:SaveSlot(slot,save) end
end
function S:LoadProgress(slot) return ArcadiaNexus.AOD_Logic:Copy(self:LoadSlot(slot)) end
function S:SavePending(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}
    db.pendingResults[data.runId]=ArcadiaNexus.AOD_Logic:Copy(data)
end
function S:ClearPending(id) local db=GetDB(); if db.pendingResults then db.pendingResults[id]=nil end end
function S:GetPending() return GetDB().pendingResults or {} end
function S:ApplyResult(data)
    local db=GetDB()
    if not db.counterVersion then
        db.legacyCounters={wins=db.wins or 0,losses=db.losses or 0,played=db.played or 0}
        db.wins,db.losses,db.played=0,0,0; db.counterVersion=2
    end
    db.totalMeteors=(db.totalMeteors or 0)+(data.meteorDelta or 0)
    db.totalHunters=(db.totalHunters or 0)+(data.hunterDelta or 0)
    db.stagesCleared=(db.stagesCleared or 0)+(data.stagesDelta or 0)
    if data.recordPlayed then
        db.played=db.played+1
        local key=data.result=="WIN" and "wins" or "losses"; db[key]=db[key]+1
    end
end

function S:ClearProgress(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end

-- ── Statistiken ───────────────────────────────────────────────
function S:IncrementStat(key, amount)
    local db  = GetDB()
    db[key]   = (db[key] or 0) + (amount or 1)
end

function S:GetStat(key)
    return GetDB()[key] or 0
end
