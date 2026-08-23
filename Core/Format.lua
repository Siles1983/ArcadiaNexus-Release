--[[
    ArcadiaNexus – Core/Format.lua

    Shared formatting for HUD labels (no UI dependencies).

    Öffentliche API:
      ArcadiaNexus.Format.SecondsMMSS(seconds, padMinutes)
      ArcadiaNexus.Format.SecondsWithUrgency(seconds, thresholds)
      ArcadiaNexus.Format.Score(number)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Format = {}
local F = ArcadiaNexus.Format

local URGENCY_COLORS = {
    normal = { 1.00, 1.00, 1.00 },
    warn   = { 1.00, 0.85, 0.20 },
    crit   = { 1.00, 0.30, 0.20 },
}

--- @param seconds number
--- @param padMinutes boolean|nil  default true → "02:05"; false → "2:05"
function F.SecondsMMSS(seconds, padMinutes)
    if padMinutes == nil then padMinutes = true end
    seconds = math.max(0, math.floor(seconds or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    if padMinutes then
        return string.format("%02d:%02d", m, s)
    end
    return string.format("%d:%02d", m, s)
end

--- Countdown urgency by remaining seconds (lower = more urgent).
--- thresholds: { warn = 60, crit = 30, padMinutes = true|false }
--- @return formatted, level ("normal"|"warn"|"crit"), r, g, b
function F.SecondsWithUrgency(seconds, thresholds)
    thresholds = thresholds or {}
    local warn = thresholds.warn or 60
    local crit = thresholds.crit or 30
    seconds = math.max(0, math.floor(seconds or 0))

    local level = "normal"
    if seconds <= crit then
        level = "crit"
    elseif seconds <= warn then
        level = "warn"
    end

    local text = F.SecondsMMSS(seconds, thresholds.padMinutes)
    local rgb  = URGENCY_COLORS[level]
    return text, level, rgb[1], rgb[2], rgb[3]
end

function F.Score(number)
    number = number or 0
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(number)
    end
    return tostring(number)
end
