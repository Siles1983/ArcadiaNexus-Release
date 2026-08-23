--[[
    ArcadiaNexus - Blockdrop Leaderboard-Schema
    Games/Blockdrop/Blockdrop_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BLOCKDROP",
    difficulties = { "normal" },
    sections = {
        S.TopScores(3),
        S.StatsPlayed(),
        S.StatBox("lb_lines_cleared", {
            { fromStats = "linesCleared", labelKey = "lb_lines_cleared", valueColor = "gold" },
        }),
    },
})
