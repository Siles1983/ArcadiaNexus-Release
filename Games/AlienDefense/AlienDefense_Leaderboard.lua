--[[
    ArcadiaNexus - AlienDefense Leaderboard-Schema
    Games/AlienDefense/AlienDefense_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, { field = "wins", labelKey = "lb_wins", valueColor = "win" })
table.insert(stats.rows, { field = "losses", labelKey = "lb_losses", valueColor = "loss" })
table.insert(stats.rows, { field = "clearedWaves", labelKey = "lb_ad_cleared", valueColor = "win" })
table.insert(stats.rows, { field = "bestLevel", labelKey = "lb_ad_best" })

ArcadiaNexus.RegisterLeaderboard({
    gameId = "ALIENDEFENSE",
    difficulties = { "easy", "normal", "hard" },
    sections = { S.TopScores(3), stats,
        {type="top_scores", field="legacyHighscores", count=3, titleKey="lb_ad_legacy", hideIfEmpty=true},
        {type="stats", titleKey="lb_ad_legacy_stats", rows={
            {field="legacyWaves", labelKey="lb_levels_cleared"},
            {field="legacyPlayed", labelKey="lb_played"},
            {field="legacyLosses", labelKey="lb_losses"},
        }},
    },
})
