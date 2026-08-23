--[[
    ArcadiaNexus - TicTacToe Leaderboard-Schema
    Games/TicTacToe/TicTacToe_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "TICTACTOE",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.StatsWLD() },
})