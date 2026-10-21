--[[
    ArcadiaNexus - Hangman Leaderboard-Schema
    Games/Hangman/Hangman_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "HANGMAN",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.StatsWL(), S.StatBox("lb_perfect", {{field="perfectWins",labelKey="lb_perfect",valueColor="win"}}) },
})