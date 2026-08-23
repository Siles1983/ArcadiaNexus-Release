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
}

local DB_KEY = "ARGUSORBDEFENSE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
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
    if data then data.timestamp = data.timestamp or time() end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:ResetSlot(slot)
    self:SaveSlot(slot, {
        level = 1, score = 0, lives = 3,
        diff = self:Get("difficulty") or "normal",
        mode = "levels",
    })
end

function S:SaveProgress(level, score, lives, diff, mode)
    self:SaveSlot(self:GetActiveSlot(), {
        level = level, score = score, lives = lives,
        diff = diff, mode = mode,
    })
end

function S:LoadProgress(slot)
    local save = self:LoadSlot(slot or self:GetActiveSlot())
    if not save then return nil end
    return {
        level = save.level,
        score = save.score or 0,
        lives = save.lives or 3,
        diff  = save.diff or "normal",
        mode  = save.mode or "levels",
    }
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
