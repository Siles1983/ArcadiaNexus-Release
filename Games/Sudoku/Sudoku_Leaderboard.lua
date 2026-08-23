--[[
    ArcadiaNexus - Sudoku Leaderboard-Schema
    Games/Sudoku/Sudoku_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SUDOKU",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWL() },
})