--[[
    ArcadiaNexus - GoblinBlast Leaderboard-Schema
    Games/GoblinBlast/GoblinBlast_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "GOBLINBLAST",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed(), S.BestLevelBox() },
})
