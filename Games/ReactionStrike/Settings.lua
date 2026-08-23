-- Games/ReactionStrike/Settings.lua

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.RS_Settings = {}
local S = ArcadiaNexus.RS_Settings

S.Defaults = {
    difficulty     = "normal",
    soundEnabled   = true,
    soundOnSignal  = true,
    soundOnStrike  = true,
    soundOnPenalty = true,
    soundOnResult  = true,
}

local DB_KEY = "REACTIONSTRIKE"
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

-- ── Bestzeit pro Schwierigkeit (aus ScoreManager abgeleitet) ──
function S:GetBestMs(diff)
    local SM = ArcadiaNexus.ScoreManager
    local Logic = ArcadiaNexus.RS_Logic
    if SM and Logic then
        local score = SM:GetBestScore("REACTIONSTRIKE", diff)
        if score and score > 0 then
            return Logic:MsFromScore(score, diff)
        end
    end
    return nil
end

function S:GetLastMs(diff)
    local db = GetDB()
    db.lastMs = db.lastMs or {}
    return db.lastMs[diff]
end

function S:SetLastMs(diff, ms)
    local db = GetDB()
    db.lastMs = db.lastMs or {}
    db.lastMs[diff] = ms
end
