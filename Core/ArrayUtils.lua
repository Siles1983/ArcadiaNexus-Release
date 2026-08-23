--[[
    ArcadiaNexus – Core/ArrayUtils.lua

    Array helpers (in-place mutation unless noted).

    Öffentliche API:
      ArcadiaNexus.ArrayUtils.Shuffle(tbl)           -- Fisher-Yates, math.random
      ArcadiaNexus.ArrayUtils.ShuffleSeeded(tbl, seed) -- LCG Fisher-Yates
      ArcadiaNexus.ArrayUtils.SeededIndex(n, seed)   -- deterministic index 1..n
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ArrayUtils = {}
local AU = ArcadiaNexus.ArrayUtils

local LCG_A = 1664525
local LCG_C = 1013904223
local LCG_M = 2147483647

local function NextSeed(s)
    return (s * LCG_A + LCG_C) % LCG_M
end

--- In-place Fisher-Yates shuffle. Returns tbl for chaining.
function AU.Shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--- Deterministic in-place shuffle (ChallengeManager / Daily seed pattern).
function AU.ShuffleSeeded(tbl, seed)
    local s = seed % LCG_M
    for i = #tbl, 2, -1 do
        s = NextSeed(s)
        local j = (s % i) + 1
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--- Single deterministic pick from 1..n (same LCG stream as ShuffleSeeded).
function AU.SeededIndex(n, seed)
    if not n or n <= 0 then return 1 end
    local s = seed % LCG_M
    s = NextSeed(s)
    return (s % n) + 1
end
