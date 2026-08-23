--[[
    ArcadiaNexus - 2048 Leaderboard-Schema
    Games/2048/2048_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "2048",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed() },
})
