--[[
    ArcadiaNexus - Chess Leaderboard-Schema
    Games/Chess/Chess_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "CHESS",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.StatsWLD() },
})