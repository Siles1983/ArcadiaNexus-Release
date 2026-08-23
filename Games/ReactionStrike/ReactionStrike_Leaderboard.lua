--[[
    ArcadiaNexus - ReactionStrike Leaderboard-Schema
    Games/ReactionStrike/ReactionStrike_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "REACTIONSTRIKE",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), S.StatsPlayed() },
})