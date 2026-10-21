--[[
    ArcadiaNexus - Minesweeper Leaderboard-Schema
    Games/Minesweeper/Minesweeper_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "MINESWEEPER",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        {type="top_scores",titleKey="lb_best_times",field="bestTimes",resultField="elapsedMs",
            result="WIN",order="asc",format="milliseconds",count=3},
        S.StatsWL(),
        {type="top_scores",titleKey="lb_legacy_points",field="legacyHighscores",hideIfEmpty=true,count=3},
    },
})
