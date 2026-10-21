-- ============================================================
--  AlienDefense – Settings.lua
--  Persistente Einstellungen. Kein UI, kein Gameplay.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AD_Settings = {}
local S = ArcadiaNexus.AD_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    difficulty        = "easy",
    soundOnShoot      = true,
    soundOnAlienShoot = true,
    soundOnAlienDeath = true,
    soundOnPlayerHit  = true,
    soundOnWeaponDrop = true,
    soundOnWin        = true,
    soundOnLose       = true,
    screenFlash       = true,
}

local DB_KEY = "ALIENDEFENSE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local E = ArcadiaNexus.AD_Engine
    if key == "difficulty" and E and E.gameState and E.state ~= "IDLE" then return E.gameState.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    local E = ArcadiaNexus.AD_Engine
    if key == "difficulty" and E and E.gameState and E.state ~= "IDLE" then return false end
    if key == "difficulty" and not ArcadiaNexus.AD_Logic.DIFFICULTY_DEFS[value] then return false end
    P:SetGameSetting(DB_KEY, key, value)
    return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.AD_Engine
    for k in pairs(self.Defaults) do
        if k~="difficulty" or not (E and E.gameState and E.state~="IDLE") then db[k]=nil end
    end
    local R=ArcadiaNexus.AD_Renderer
    if R and R._diffDropdown then R._diffDropdown:RefreshDisplay() end
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
            wave      = db.savedLevel,
            score     = db.savedScore or 0,
            lives     = db.savedLives or 3,
            diff      = db.savedDiff or "easy",
            timestamp = time(),
        }
        db.savedLevel, db.savedScore, db.savedLives, db.savedDiff = nil, nil, nil, nil
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

function S:ResetSlot(slot) self:DeleteSlot(slot) end
function S:LoadProgress(slot) return ArcadiaNexus.AD_Logic:Copy(self:LoadSlot(slot)) end
function S:SaveProgress(state, slot)
    local save = ArcadiaNexus.AD_Logic:Snapshot(state)
    if save then self:SaveSlot(slot, save) end
end
function S:ClearProgress(slot) self:DeleteSlot(slot) end

-- Failed bookings are not playable saves; pinned by LocalResults.Prune.
function S:SavePending(data)
    local db=GetDB()
    db.pendingResults=db.pendingResults or {}
    db.pendingResults[data.runId]=ArcadiaNexus.AD_Logic:Copy(data)
end
function S:ClearPending(runId)
    local db=GetDB()
    if db.pendingResults then db.pendingResults[runId]=nil end
end
function S:GetPending() return GetDB().pendingResults or {} end
