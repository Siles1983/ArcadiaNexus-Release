--[[
    ArcadiaNexus - AlienDefense Leaderboard-Schema
    Games/AlienDefense/AlienDefense_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, { field = "wins", labelKey = "lb_levels_cleared", valueColor = "win" })
table.insert(stats.rows, S.BestLevel())

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ALIENDEFENSE",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), stats },
})
