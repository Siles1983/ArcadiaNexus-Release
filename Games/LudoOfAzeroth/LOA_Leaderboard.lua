--[[
    ArcadiaNexus - LudoOfAzeroth Leaderboard-Schema
    Games/LudoOfAzeroth/LOA_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "LOA",
    difficulties = { {id="ai_1",labelKey="players_1"},{id="ai_2",labelKey="players_2"},
        {id="ai_3",labelKey="players_3"},{id="default",labelKey="legacy_stats"} },
    sections = { S.StatsWL() },
})
