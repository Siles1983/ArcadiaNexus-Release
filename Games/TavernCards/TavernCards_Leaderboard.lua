--[[
    ArcadiaNexus - TavernCards Leaderboard-Schema
    Games/TavernCards/TavernCards_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "TAVERNCARDS",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.StatsWL() },
})