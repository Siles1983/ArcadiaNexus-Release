-- Games/Nonogram/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
local S = {}
ArcadiaNexus.NON_Settings = S

S.Defaults = {
    difficulty   = "easy",
    defaultMode  = "free",
    soundEnabled = true,
    soundOnFill  = true,
    soundOnMark  = true,
    soundOnError = true,
    soundOnWin   = true,
    soundOnLose  = true,
}

local DB_KEY = "NONOGRAM"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return S.Defaults[key]
end

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:GetAll()
    return GetDB()
end

function S:Reset()
    local db = GetDB()
    for k, v in pairs(S.Defaults) do
        db[k] = v
    end
end

-- ============================================================
-- STATISTIKEN
-- ============================================================
function S:GetStats()
    local db = GetDB()
    if not db.stats then
        db.stats = {
            played        = 0,
            wins          = 0,
            losses        = 0,
            puzzlesSolved = 0,
        }
    end
    return db.stats
end

function S:RecordResult(result)
    local stats = S:GetStats()
    stats.played = (stats.played or 0) + 1
    if result == "WIN" then
        stats.wins          = (stats.wins or 0) + 1
        stats.puzzlesSolved = (stats.puzzlesSolved or 0) + 1
    else
        stats.losses = (stats.losses or 0) + 1
    end
end
