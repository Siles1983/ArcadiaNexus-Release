--[[
    ArcadiaNexus - ArcadiaRows Leaderboard-Schema
    Games/ArcadiaRows/ArcadiaRows_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ARCADIAROWS",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.StatsWLD(),
        S.StatBox("lb_puzzles", {
            { fromStats = "puzzleSolved", labelKey = "lb_puzzles_solved", valueColor = "win" },
            { fromStats = "popWins",      labelKey = "lb_pop_wins" },
        }),
    },
})
