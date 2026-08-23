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
    soundEnabled    = true,
    soundOnPlay     = true,
    soundOnDraw     = true,
    soundOnSpecial  = true,
    soundOnWin      = true,
    soundOnLose     = true,
    soundOnUno      = true,
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
    if key == "rules" then
        local r = db.rules or {}
        local out = {}
        for k, v in pairs(self.Defaults.rules) do
            out[k] = r[k] ~= nil and r[k] or v
        end
        return out
    end
    if key == "stats" then
        local st = db.stats or {}
        local out = {}
        for k, v in pairs(self.Defaults.stats) do
            out[k] = st[k] or v
        end
        return out
    end
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    P:SetGameSetting(DB_KEY, key, value)
end

function S:GetRule(key)
    return self:Get("rules")[key]
end

function S:SetRule(key, value)
    local rules = self:Get("rules")
    rules[key] = value
    self:Set("rules", rules)
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do
        if k ~= "pausedState" then r[k] = self:Get(k) end
    end
    return r
end

function S:SavePausedState(gs)
    local Logic = ArcadiaNexus.TC_Logic
    if Logic then self:Set("pausedState", Logic:CloneGameState(gs)) end
end

function S:LoadPausedState()
    return self:Get("pausedState")
end

function S:ClearPausedState()
    self:Set("pausedState", nil)
end

function S:RecordGameResult(result, gs)
    local stats = self:Get("stats")
    stats.played = stats.played + 1
    if result == "WIN" then stats.won = stats.won + 1 else stats.lost = stats.lost + 1 end
    if gs and gs.stats then
        stats.unosCalled = stats.unosCalled + (gs.stats.unosCalled or 0)
        stats.unosMissed = stats.unosMissed + (gs.stats.unosMissed or 0)
        stats.unosCaught = stats.unosCaught + (gs.stats.unosCaught or 0)
    end
    self:Set("stats", stats)
end

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
