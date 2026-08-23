-- ============================================================
--  Solitaire – Settings.lua
--  Persistente Einstellungen via ArcadiaNexusDB
--  Namespace: SOL_
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SOL_Settings = {}
local S = ArcadiaNexus.SOL_Settings

S.MAX_SLOTS = 3

S.Defaults = {
    theme        = "neutral",
    mode         = "1card",
    soundEnabled = true,
    soundOnDeal  = true,
    soundOnPlace = true,
    soundOnFnd   = true,
    soundOnInval = true,
    soundOnWin   = true,
    soundOnUndo  = true,
}

local DB_KEY = "SOLITAIRE"
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
    -- Einstellungen zurücksetzen, gespeichertes Spiel behalten
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
    if not db.saves[1] and db.savedMode then
        db.saves[1] = {
            mode      = db.savedMode,
            score     = db.savedScore or 0,
            elapsed   = db.savedElapsed or 0,
            midGame   = {
                mode       = db.savedMode,
                stock      = db.savedStock,
                waste      = db.savedWaste,
                foundation = db.savedFoundation,
                tableau    = db.savedTableau,
                score      = db.savedScore,
                elapsed    = db.savedElapsed,
                wastePass  = db.savedWastePass,
                undoCount  = db.savedUndoCount,
            },
            timestamp = time(),
        }
        db.savedMode, db.savedStock, db.savedWaste = nil, nil, nil
        db.savedFoundation, db.savedTableau = nil, nil
        db.savedScore, db.savedElapsed, db.savedWastePass, db.savedUndoCount = nil, nil, nil, nil
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
        mode = self:Get("mode") or "1card",
        score = 0, elapsed = 0, midGame = nil,
    })
end

-- ── Spielstand-Persistenz (SaveAndPause) ────────────────────
function S:SaveGame(gs)
    local slot = self:GetActiveSlot()
    self:SaveSlot(slot, {
        mode    = gs.mode,
        score   = gs.score,
        elapsed = gs.elapsed,
        midGame = {
            mode       = gs.mode,
            stock      = self:_DeepCopy(gs.stock),
            waste      = self:_DeepCopy(gs.waste),
            foundation = self:_DeepCopy(gs.foundation),
            tableau    = self:_DeepCopy(gs.tableau),
            score      = gs.score,
            elapsed    = gs.elapsed,
            wastePass  = gs.wastePass,
            undoCount  = gs.undoStack and #gs.undoStack or 0,
        },
    })
end

function S:LoadGame(slot)
    local save = self:LoadSlot(slot or self:GetActiveSlot())
    local mid  = save and save.midGame
    if not mid then return nil end
    return {
        mode       = mid.mode,
        stock      = self:_DeepCopy(mid.stock or {}),
        waste      = self:_DeepCopy(mid.waste or {}),
        foundation = self:_DeepCopy(mid.foundation or {C={},D={},H={},S={}}),
        tableau    = self:_DeepCopy(mid.tableau or {}),
        score      = mid.score or 0,
        elapsed    = mid.elapsed or 0,
        wastePass  = mid.wastePass or 0,
        undoCount  = mid.undoCount or 0,
    }
end

function S:ClearSave(slot)
    self:DeleteSlot(slot or self:GetActiveSlot())
end

function S:HasSavedGame(slot)
    local save = self:LoadSlot(slot or self:GetActiveSlot())
    return save and save.midGame ~= nil
end

function S:_DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:_DeepCopy(v)
    end
    return copy
end
