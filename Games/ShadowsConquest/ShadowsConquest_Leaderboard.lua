--[[
    ArcadiaNexus - ShadowsConquest Leaderboard-Schema
    Games/ShadowsConquest/ShadowsConquest_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SHADOWSCONQUEST",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWL() },
})