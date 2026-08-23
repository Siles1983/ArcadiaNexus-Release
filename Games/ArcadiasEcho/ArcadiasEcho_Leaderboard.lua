--[[
    ArcadiaNexus - ArcadiasEcho Leaderboard-Schema
    Games/ArcadiasEcho/ArcadiasEcho_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ARCADIASECHO",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsLossesPlayed() },
})
