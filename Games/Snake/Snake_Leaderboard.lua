--[[
    ArcadiaNexus - Snake Leaderboard-Schema
    Games/Snake/Snake_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SNAKE",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.TopScores(3),
        S.StatsPlayed(),
        S.StatBox("lb_fruits_eaten", {
            { fromStats = "fruitsEaten", labelKey = "lb_fruits_eaten", valueColor = "gold" },
        }),
    },
})
