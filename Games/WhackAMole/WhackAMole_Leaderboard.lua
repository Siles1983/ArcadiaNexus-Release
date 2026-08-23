--[[
    ArcadiaNexus - WhackAMole Leaderboard-Schema
    Games/WhackAMole/WhackAMole_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "WHACKAMOLE",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed() },
})