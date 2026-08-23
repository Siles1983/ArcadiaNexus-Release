--[[
    ArcadiaNexus - AlchemistsSort Leaderboard-Schema
    Games/AlchemistsSort/AlchemistsSort_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ALCHEMISTSSORT",
    difficulties = { "normal" },
    sections = { S.TopScores(3), S.StatsPlayed(), S.BestLevelBox() },
})
