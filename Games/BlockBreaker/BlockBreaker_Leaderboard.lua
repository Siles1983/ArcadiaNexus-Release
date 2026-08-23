--[[
    ArcadiaNexus - BlockBreaker Leaderboard-Schema
    Games/BlockBreaker/BlockBreaker_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, S.BestLevel())

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BLOCKBREAKER",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), stats },
})