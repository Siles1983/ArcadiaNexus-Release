--[[
    ArcadiaNexus - BlockBreaker Leaderboard-Schema
    Games/BlockBreaker/BlockBreaker_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

local stats = S.StatsWL()
table.insert(stats.rows,{field="clearedStages",labelKey="lb_bb_cleared"})
table.insert(stats.rows, S.BestLevel())

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BLOCKBREAKER",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), stats,
        {type="top_scores",field="legacyHighscores",count=3,titleKey="lb_bb_legacy",hideIfEmpty=true},
        {type="stats",titleKey="lb_bb_legacy_stats",rows={
            {field="legacyGamesPlayed",labelKey="lb_played"},
            {field="legacyWins",labelKey="lb_wins"},{field="legacyLosses",labelKey="lb_losses"},
            {field="legacyBestLevel",labelKey="lb_best_level"},
        }},
    },
})