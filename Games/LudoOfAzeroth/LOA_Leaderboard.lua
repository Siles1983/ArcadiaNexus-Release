--[[
    ArcadiaNexus - LudoOfAzeroth Leaderboard-Schema
    Games/LudoOfAzeroth/LOA_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "LOA",
    difficulties = { "default" },
    sections = { S.StatsWL() },
})
