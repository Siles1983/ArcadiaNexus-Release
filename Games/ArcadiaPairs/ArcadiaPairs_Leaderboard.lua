--[[
    ArcadiaNexus - ArcadiaPairs Leaderboard-Schema
    Games/ArcadiaPairs/ArcadiaPairs_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ARCADIAPAIRS",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWL() },
})