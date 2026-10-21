-- ============================================================
--  Tavern Cards – Settings.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Settings = {}
local S = ArcadiaNexus.TC_Settings

S.Defaults = {
    difficulty      = "easy",
    aiCount         = 1,
    gameMode        = "single",
    pointTarget     = 500,
    theme           = "neutral",
    playerCharacter = "thrall",
    randomPlayerCharacter = false,
    showCardTooltips = true,
    showHouseRulesButton = true,
    soundEnabled    = true,
    soundOnPlay     = true,
    soundOnDraw     = true,
    soundOnSpecial  = true,
    soundOnWin      = true,
    soundOnLose     = true,
    rules = {
        stackDraw2     = true,
        stackDraw4     = true,
        playDrawn      = true,
        unoCallRule    = true,
        challengeDraw4 = true,
    },
    stats = {
        played = 0, won = 0, lost = 0,
        unosCalled = 0, unosMissed = 0, unosCaught = 0,
    },
    pausedState = nil,
}

local DB_KEY = "TAVERNCARDS"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    local E = ArcadiaNexus.TC_Engine
    local gs = E and E.mode == "hotseat" and E.gameState
    if gs and (key == "difficulty" or key == "aiCount" or key == "gameMode" or key == "pointTarget" or key == "rules") then
        if key == "rules" then return ArcadiaNexus.TC_Logic:CloneGameState(gs.rules) end
        return gs[key]
    end
    if key=="rules" and E and E.mode~="hotseat" and E.match and (E.match:GetState()=="PLAYING" or E.match:GetState()=="FINISHED") then
        local board=E:GetBoardState(); if board then return ArcadiaNexus.TC_Logic:CloneGameState(board.rules) end
    end
    if key == "rules" then
        local r = db.rules or {}
        local out = {}
        for k, v in pairs(self.Defaults.rules) do
            if r[k] ~= nil then out[k] = r[k] else out[k] = v end
        end
        return out
    end
    if key == "stats" then
        local st = db.stats or {}
        local out = {}
        for k, v in pairs(self.Defaults.stats) do
            out[k] = st[k] or v
        end
        -- The leaderboard owns completed-game W/L. Retain historical action counters as stored.
        local entries=ArcadiaNexusDB.leaderboard and ArcadiaNexusDB.leaderboard.TAVERNCARDS
        if entries and next(entries) then
            out.played=0; out.won=0; out.lost=0
            for _,entry in pairs(entries) do out.played=out.played+((tonumber(entry.gamesPlayed) or 0)>0 and tonumber(entry.gamesPlayed) or (entry.wins or 0)+(entry.losses or 0)+(entry.draws or 0)); out.won=out.won+(entry.wins or 0); out.lost=out.lost+(entry.losses or 0) end
        end
        return out
    end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:IsConfigurationLocked()
    local E=ArcadiaNexus.TC_Engine
    return E and (E.gameState~=nil or E.mode~="hotseat" and E.match~=nil) or false
end
function S:Set(key, value)
    if self:IsConfigurationLocked() and (key=="difficulty" or key=="aiCount" or key=="gameMode" or key=="pointTarget" or key=="rules") then return false end
    P:SetGameSetting(DB_KEY, key, value)
    if key=="showCardTooltips" or key=="showHouseRulesButton" then
        local R=ArcadiaNexus.TC_Renderer
        if R and R.RefreshDisplayOptions then R:RefreshDisplayOptions() end
    end
    return true
end

function S:GetRule(key)
    return self:Get("rules")[key]
end

function S:SetRule(key, value)
    local rules = self:Get("rules")
    rules[key] = value
    return self:Set("rules", rules)
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do
        if k ~= "pausedState" then r[k] = self:Get(k) end
    end
    return r
end

S.MAX_SLOTS=3
local function Slot(slot) return type(slot)=="number" and slot==math.floor(slot) and slot>=1 and slot<=3 end
function S:EnsureSlots()
    local db=GetDB(); db.slots=db.slots or {}; if not Slot(db.activeSlot) then db.activeSlot=1 end
    if db.pausedState and not db._slotsMigrated and not db._slotsMigrationBlocked and not db.slots[1] then
        local ok,gs=pcall(ArcadiaNexus.TC_Logic.MigrateSave,ArcadiaNexus.TC_Logic,db.pausedState)
        if not ok then gs=nil end
        if gs then db.slots[1]=gs; db.pausedState=nil; db._slotsMigrated=true else db._slotsMigrationBlocked=true end
    elseif not db.pausedState then db._slotsMigrated=true end
    return db.slots
end
function S:GetActiveSlot() self:EnsureSlots(); return GetDB().activeSlot end
function S:SetActiveSlot(slot) if not Slot(slot) then return false end; GetDB().activeSlot=slot; return true end
function S:LoadSlot(slot) slot=slot or self:GetActiveSlot(); return Slot(slot) and self:EnsureSlots()[slot] or nil end
function S:SaveGame(gs)
    local E=ArcadiaNexus.TC_Engine; local slot=E.activeSlot or self:GetActiveSlot()
    self:EnsureSlots()[slot]=ArcadiaNexus.TC_Logic:CloneGameState(gs)
end
function S:DeleteSlot(slot)
    local E=ArcadiaNexus.TC_Engine
    if not Slot(slot) or E.gameState and E.activeSlot==slot then return false end
    self:EnsureSlots()[slot]=nil; ArcadiaNexus.LocalResults:Prune(); return true
end
function S:SavePausedState(gs) self:SaveGame(gs) end
function S:LoadPausedState() return self:LoadSlot() end
-- Kept as a no-op for older UI callers; only explicit slot deletion removes a save.
function S:ClearPausedState() end

function S:Reset()
    for k, v in pairs(self.Defaults) do
        if k ~= "stats" and k ~= "pausedState" then
            if k == "rules" then
                local rules = {}
                for rk, rv in pairs(v) do rules[rk] = rv end
                self:Set("rules", rules)
            else
                self:Set(k, v)
            end
        end
    end
end
