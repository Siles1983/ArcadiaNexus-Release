--[[
    ArcadiaNexus – Core/CampaignProgress.lua

    Shared persistence helpers for linear, level-based campaigns.
    Games own their rating rules and pass an already calculated star value.
    This module owns no SavedVariables and creates no UI.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CampaignProgress = {}
local CP = ArcadiaNexus.CampaignProgress

CP.VERSION = 1
CP.DEFAULT_MAX_STARS = 3

local function ClampInt(value, lo, hi)
    value = math.floor(tonumber(value) or 0)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

local function Options(opts)
    opts = opts or {}
    local count = math.max(1, math.floor(tonumber(opts.levelCount) or 1))
    local maxStars = math.max(1, math.floor(tonumber(opts.maxStars) or CP.DEFAULT_MAX_STARS))
    return count, maxStars
end

-- Ensures that a game's own save table contains the common campaign fields.
-- Existing game-specific fields are deliberately left untouched.
function CP.Normalize(progress, opts)
    if type(progress) ~= "table" then return nil end
    local count, maxStars = Options(opts)
    if type(progress.stars) ~= "table" then progress.stars = {} end

    local clean = {}
    for key, value in pairs(progress.stars) do
        local level = tonumber(key)
        if level then
            level = math.floor(level)
            if level >= 1 and level <= count then
                clean[level] = ClampInt(value, 0, maxStars)
            end
        end
    end
    progress.stars = clean
    progress.campaignVersion = CP.VERSION
    progress.currentLevel = ClampInt(progress.currentLevel or progress.level or 1, 1, count)
    progress.clearedLevel = ClampInt(progress.clearedLevel, 0, count)
    return progress
end

function CP.GetStars(progress, level)
    if type(progress) ~= "table" or type(progress.stars) ~= "table" then return 0 end
    return math.max(0, math.floor(tonumber(progress.stars[tonumber(level)]) or 0))
end

function CP.TotalStars(progress)
    if type(progress) ~= "table" or type(progress.stars) ~= "table" then return 0 end
    local total = 0
    for _, stars in pairs(progress.stars) do
        total = total + math.max(0, math.floor(tonumber(stars) or 0))
    end
    return total
end

function CP.IsLevelUnlocked(progress, level, opts)
    local count = Options(opts)
    level = ClampInt(level, 1, count)
    if level == 1 then return true end
    if type(progress) ~= "table" then return false end
    return (tonumber(progress.clearedLevel) or 0) >= level - 1
        or CP.GetStars(progress, level - 1) >= 1
        or (tonumber(progress.currentLevel) or 1) >= level
end

-- Stores only an improvement and returns bestStars, improved, gainedStars.
function CP.RecordLevel(progress, level, stars, opts)
    progress = CP.Normalize(progress, opts)
    if not progress then return 0, false, 0 end
    local count, maxStars = Options(opts)
    level = ClampInt(level, 1, count)
    stars = ClampInt(stars, 0, maxStars)

    local previous = CP.GetStars(progress, level)
    local best = math.max(previous, stars)
    progress.stars[level] = best
    progress.clearedLevel = math.max(progress.clearedLevel or 0, level)
    progress.currentLevel = math.max(progress.currentLevel or 1, math.min(count, level + 1))
    return best, best > previous, best - previous
end

function CP.Reset(progress)
    if type(progress) ~= "table" then return nil end
    progress.stars = {}
    progress.clearedLevel = 0
    progress.currentLevel = 1
    progress.campaignVersion = CP.VERSION
    return progress
end
