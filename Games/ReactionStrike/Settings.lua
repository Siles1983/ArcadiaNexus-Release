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
    local E=ArcadiaNexus.RS_Engine
    if key=="difficulty" and E and E._gameState then return E._gameState.difficulty end
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, val)
    local E=ArcadiaNexus.RS_Engine
    if key=="difficulty" and (E and E._gameState or not ArcadiaNexus.RS_Logic:IsDifficulty(val)) then return false end
    P:SetGameSetting(DB_KEY,key,val)
    local R=ArcadiaNexus.RS_Renderer
    if R and R.RefreshConfiguration then R:RefreshConfiguration() end
    return true
end

function S:Reset()
    local db = GetDB()
    local E=ArcadiaNexus.RS_Engine
    for k in pairs(self.Defaults) do if k~="difficulty" or not E or not E._gameState then db[k]=nil end end
    local R=ArcadiaNexus.RS_Renderer
    if R and R.RefreshConfiguration then R:RefreshConfiguration() end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

-- ── Originalzeit pro Schwierigkeit (lower-is-better) ───────────
function S:GetBestMs(diff)
    local SM = ArcadiaNexus.ScoreManager
    local Logic = ArcadiaNexus.RS_Logic
    if SM and Logic then
        local records=SM:GetScores("REACTIONSTRIKE",diff).bestTimes
        return records and records[1] and records[1].value
    end
    return nil
end

function S:EnsureCounters()
    local db=GetDB()
    if db.reactionRuleVersion==2 then return end
    local ach=ArcadiaNexus.AchievementStore.Get()
    local fake=ach.progress.RS_FAKEOUT
    local baseline=math.max(db.fakeoutsSurvived or 0,fake and fake.current or 0)
    for i,id in ipairs({"RS_FAKEOUT_BRONZE","RS_FAKEOUT_SILBER","RS_FAKEOUT_GOLD"}) do
        if ach.unlocked[id] then baseline=math.max(baseline,({5,20,50})[i]) end
    end
    db.legacyFakeoutsSurvived=db.fakeoutsSurvived or 0
    db.fakeoutsSurvived=baseline
    if fake then fake.legacyCurrent=fake.current; fake.current=baseline end
    db.legacyLastMs=db.lastMs; db.lastMs={}; db.reactionRuleVersion=2
end

function S:RecordFakeout()
    self:EnsureCounters()
    local db=GetDB()
    local prog=ArcadiaNexus.AchievementStore.Get().progress.RS_FAKEOUT
    db.fakeoutsSurvived=math.max(db.fakeoutsSurvived,prog and prog.current or 0)+1
    local AM=ArcadiaNexus.AchievementManager
    if AM then AM:HandleReactionFakeout() end
    return db.fakeoutsSurvived
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
