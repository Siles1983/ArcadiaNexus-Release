--[[
    ArcadiaNexus - Nonogram Leaderboard-Schema
    Games/Nonogram/Nonogram_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "NONOGRAM",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWinsPlayed() },
})
