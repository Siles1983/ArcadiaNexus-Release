--[[
    ArcadiaNexus - SI7 Leaderboard
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SI7",
    difficulties = { "normal" },
    sections = { S.StatsWL() },
})
