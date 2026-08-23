--[[
    ArcadiaNexus - BarrelBrawl Leaderboard-Schema
    Games/BarrelBrawl/BarrelBrawl_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BARREL_BRAWL",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed(), S.BestLevelBox() },
})
