--[[
    ArcadiaNexus - ShellGame Leaderboard-Schema
    Games/ShellGame/ShellGame_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SHELLGAME",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.GlobalStats("lb_capital", { S.MaxCapitalRow() }),
        S.StatsWL(),
    },
})
