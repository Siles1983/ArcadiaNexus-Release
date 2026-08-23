--[[
    ArcadiaNexus - HigherOrLower Leaderboard-Schema
    Games/HigherOrLower/HigherOrLower_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "HIGHERORLOWER",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.GlobalStats("lb_capital", { S.MaxCapitalRow() }),
        S.TopScores(3),
        S.StatBox("lb_records", {
            { fromStats = "maxMultiplier", labelKey = "lb_max_multiplier", valueColor = "gold", format = "multiplier" },
            { fromStats = "maxStreak",     labelKey = "lb_max_streak",     valueColor = "gold" },
        }),
        S.StatsWL(),
    },
})
