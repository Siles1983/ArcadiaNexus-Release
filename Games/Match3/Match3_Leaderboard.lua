--[[
    ArcadiaNexus - Match3 Leaderboard-Schema
    Games/Match3/Match3_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "MATCH3",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed() },
})