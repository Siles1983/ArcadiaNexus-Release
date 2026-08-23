--[[
    ArcadiaNexus - AzerothsTinyGuardians Leaderboard-Schema
    Games/AzerothsTinyGuardians/AzerothsTinyGuardians_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "AZEROTHTINYGUARDIANS",
    difficulties = { "default" },
    sections = {
        S.StatBox("lb_adoptions", {
            { fromStats = "adoptions", labelKey = "lb_adoptions", valueColor = "gold" },
        }),
        S.StatsPlayed(),
    },
})
