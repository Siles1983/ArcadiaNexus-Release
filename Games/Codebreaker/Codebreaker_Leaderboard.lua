--[[
    ArcadiaNexus - Codebreaker Leaderboard-Schema
    Games/Codebreaker/Codebreaker_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "CODEBREAKER",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        S.TopScores(3), S.StatsWL(),
        {type="top_scores", titleKey="lb_legacy_rules", field="legacyHighscores", count=3, hideIfEmpty=true},
    },
})
