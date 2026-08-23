-- Games/AzerothWords/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.WRD_Settings = {}
local S = ArcadiaNexus.WRD_Settings

S.Defaults = {
    difficulty     = "normal",
    theme          = "classic",   -- "classic" | "wow"
    soundEnabled   = true,
    soundOnReveal  = true,
    soundOnCorrect = true,
    soundOnWin     = true,
    soundOnLose    = true,
}

local DB_KEY = "AZEROTHWORDS"
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

-- ── Statistiken pro Schwierigkeit ────────────────────────────
-- ArcadiaNexusDB.gameSettings["AZEROTHWORDS"].stats
local function EnsureStats(diff)
    local db = GetDB()
    db.stats = db.stats or {}
    db.stats[diff] = db.stats[diff] or { played=0, won=0, totalAttempts=0 }
    return db.stats[diff]
end

function S:RecordResult(diff, won, attemptsUsed)
    local st = EnsureStats(diff)
    st.played       = st.played + 1
    st.totalAttempts = st.totalAttempts + attemptsUsed
    if won then st.won = st.won + 1 end
end

function S:GetStats(diff)
    return EnsureStats(diff)
end

function S:GetAvgAttempts(diff)
    local st = EnsureStats(diff)
    if st.won == 0 then return nil end
    return math.floor((st.totalAttempts / st.won) * 10) / 10
end

function S:GetWinRate(diff)
    local st = EnsureStats(diff)
    if st.played == 0 then return 0 end
    return math.floor((st.won / st.played) * 100)
end
