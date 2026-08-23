--[[
    ArcadiaNexus - Solitaire Leaderboard-Schema
    Games/Solitaire/Solitaire_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SOLITAIRE",
    difficulties = {
        { id = "1card", labelKey = "lb_diff_1card" },
        { id = "3card", labelKey = "lb_diff_3card" },
    },
    sections = { S.TopScores(3), S.StatsWL() },
})