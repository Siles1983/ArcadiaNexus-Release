-- Games/ShadowsConquest/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
local S = {}
ArcadiaNexus.SC_Settings = S

S.Defaults = {
    difficulty      = "easy",
    moveLimitActive = false,
    soundEnabled    = true,
    soundOnToggle   = true,
    soundOnWin      = true,
    soundOnLose     = true,
}

local DB_KEY = "SHADOWSCONQUEST"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, val) P:SetGameSetting(DB_KEY, key, val) end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- Puzzle-Index pro Schwierigkeit
function S:GetPuzzleIndex(diff)
    local db = GetDB()
    db.puzzleIndex = db.puzzleIndex or {}
    return db.puzzleIndex[diff] or 1
end

function S:SetPuzzleIndex(diff, idx)
    local db = GetDB()
    db.puzzleIndex = db.puzzleIndex or {}
    db.puzzleIndex[diff] = idx
end

-- Statistiken
function S:IncrementPuzzlesSolved()
    local db = GetDB()
    db.puzzlesSolved = (db.puzzlesSolved or 0) + 1
end

function S:GetPuzzlesSolved()
    local db = GetDB()
    return db.puzzlesSolved or 0
end
