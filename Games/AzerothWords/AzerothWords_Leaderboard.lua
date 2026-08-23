--[[
    ArcadiaNexus - AzerothWords Leaderboard-Schema
    Games/AzerothWords/AzerothWords_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "AZEROTHWORDS",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWL() },
})