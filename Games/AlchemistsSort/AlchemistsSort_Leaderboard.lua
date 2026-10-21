--[[
    ArcadiaNexus - AlchemistsSort Leaderboard-Schema
    Games/AlchemistsSort/AlchemistsSort_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, { fromStats="totalStars", labelKey="lb_stars", valueColor="gold" })

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ALCHEMISTSSORT",
    difficulties = { "normal" },
    sections = { {type="top_scores",titleKey="lb_legacy_points",count=3,hideIfEmpty=true}, stats, S.BestLevelBox() },
})
