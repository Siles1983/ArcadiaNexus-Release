--[[
    ArcadiaNexus - SlidingPuzzle Leaderboard-Schema
    Games/SlidingPuzzle/SlidingPuzzle_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "MOSAICOFAZEROTH",
    difficulties = { "easy", { id = "medium", labelKey = "lb_diff_medium" }, "hard" },
    sections = { S.TopScores(3), S.StatsWinsPlayed() },
})
