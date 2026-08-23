--[[
    ArcadiaNexus - Blackjack Leaderboard-Schema
    Games/Blackjack/Blackjack_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BLACKJACK",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.GlobalStats("lb_capital", { S.MaxCapitalRow() }),
        S.StatsWL(),
    },
})
