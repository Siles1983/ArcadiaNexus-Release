--[[
    ArcadiaNexus - Minesweeper Leaderboard-Schema
    Games/Minesweeper/Minesweeper_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "MINESWEEPER",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsWL() },
})