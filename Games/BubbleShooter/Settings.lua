--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Settings.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Settings = {}
local S = ArcadiaNexus.BS_Settings

S.MAX_SLOTS = 3
S.DB_KEY = "BUBBLESHOOTER"
-- Bump when a campaign board layout changes in a way that makes paused
-- snapshots incompatible with the authored/generated level definition.
S.CAMPAIGN_VERSION = 3

S.Defaults = {
    difficulty       = "easy",
    mode             = "endless",
    theme            = "energies",
    soundEnabled     = true,
    soundOnShoot     = true,
    soundOnPop       = true,
    soundOnDrop      = true,
    soundOnPower     = true,
    soundOnOvercharge = true,
    soundOnWin       = true,
    soundOnLose      = true,
    screenFlash      = true,
    colorblind       = false,
}

local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(S.DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:IsConfigLocked()
    local E=ArcadiaNexus.BS_Engine
    return E and E.gameState and E.state~="IDLE"
end

function S:Set(key, value)
    if (key=="mode" or key=="difficulty") and self:IsConfigLocked() then return false end
    P:SetGameSetting(S.DB_KEY, key, value)
end

function S:Reset()
    local db = GetDB()
    for k in pairs(self.Defaults) do
        if (k~="mode" and k~="difficulty") or not self:IsConfigLocked() then db[k] = nil end
    end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

function S:AddStat(key, amount)
    local db = GetDB()
    db.stats = db.stats or {}
    db.stats[key] = (db.stats[key] or 0) + (amount or 1)
end

function S:GetStats()
    local db = GetDB()
    return db.stats or {}
end

local function EnsureSaves(db)
    if not db.saves then db.saves = {} end
    if not db.activeSlot then db.activeSlot = 1 end
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
    if data then
        local now = (time and time()) or 0
        data.timestamp = data.timestamp or now
    end
end

function S:DeleteSlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > S.MAX_SLOTS then return end
    local db = GetDB()
    EnsureSaves(db)
    db.saves[slot] = nil
end

function S:PackProgress(state, extra)
    extra = extra or {}
    local Logic = ArcadiaNexus.BS_Logic
    local paused = extra.paused == true
    local mid = extra.midGame
    if mid == nil and paused and Logic then
        mid = Logic:Serialize(state)
    end
    return {
        currentLevel = extra.currentLevel or (state and state.levelIndex) or 1,
        score        = extra.score or (state and state.score) or 0,
        diff         = extra.diff or (state and state.difficulty) or "easy",
        mode         = "shot",
        midGame      = mid,
        stars        = extra.stars or {},
        campaignVersion = extra.campaignVersion or S.CAMPAIGN_VERSION,
        layoutVersion = S.CAMPAIGN_VERSION,
        runId = state and state.runId,
        levelBests = extra.levelBests,
        clearedLevel = extra.clearedLevel or 0,
        timestamp    = (time and time()) or 0,
        paused       = paused,
    }
end

-- This step runs inside LocalResults' staged transaction, before achievements.
function S:ApplyResult(data)
    if data.localReplay then return end
    local st=data.stats
    if data.playMode=="shot" and data.result=="WIN" then self:AddStat("totalLevels",1) end
    self:AddStat("totalPowerUsed",st.powerUsed or 0)
    self:AddStat("totalOvercharge",st.overchargeCount or 0)
    if (st.maxCombo or 1)>=5 then self:AddStat("totalCombo5",1) end
    if (st.maxDrop or 0)>0 then self:AddStat("totalDrops",1) end
    if data.playMode=="shot" then
        local progress=self:LoadSlot(data.slot) or {}
        local bests=progress.levelBests or {}; progress.levelBests=bests
        bests[3]=bests[3] or {}; bests[3][data.aiDifficulty]=bests[3][data.aiDifficulty] or {}
        if data.result=="WIN" then
            local best,_,gained=ArcadiaNexus.CampaignProgress.RecordLevel(progress,data.levelIndex,data.stars,
                {levelCount=100,maxStars=3})
            self:AddStat("totalStars",gained)
            local old=bests[3][data.aiDifficulty][data.levelIndex] or {}
            old.score=math.max(old.score or 0,data.score)
            old.shots=math.min(old.shots or st.shotsUsed,st.shotsUsed)
            old.maxCombo=math.max(old.maxCombo or 1,st.maxCombo)
            old.maxDrop=math.max(old.maxDrop or 0,st.maxDrop)
            old.stars=math.max(old.stars or 0,data.stars)
            bests[3][data.aiDifficulty][data.levelIndex]=old
            progress.currentLevel=math.min(100,data.levelIndex+1)
        else progress.currentLevel=data.levelIndex end
        progress.score=0; progress.midGame=nil; progress.runId=nil; progress.paused=false
        progress.diff=data.aiDifficulty; progress.layoutVersion=3
        self:SaveSlot(data.slot,progress)
    end
end

function S:QueueResult(data)
    local db=GetDB(); db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=data
end
function S:FlushResults()
    local db=GetDB()
    for id,data in pairs(db.pendingResults or {}) do
        ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
        if data.processed then db.pendingResults[id]=nil end
    end
end
