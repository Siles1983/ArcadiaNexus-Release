--[[
    ArcadiaNexus - AzerothConquest Leaderboard-Schema
    Games/AzerothConquest/AzerothConquest_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "AZEROTHCONQUEST",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.StatsWLD() },
})