--[[
    ArcadiaNexus - AzerothJewels Leaderboard-Schema
    Games/AzerothJewels/AzerothJewels_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, S.BestLevel())
table.insert(stats.rows, {
    fromStats  = "totalStars",
    labelKey   = "lb_stars",
    valueColor = "gold",
})
table.insert(stats.rows, {
    fromStats  = "endlessBestWave",
    labelKey   = "lb_endless",
    valueColor = "gold",
})

ArcadiaNexus.RegisterLeaderboard({
    gameId = "AZEROTHJEWELS",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), stats },
})