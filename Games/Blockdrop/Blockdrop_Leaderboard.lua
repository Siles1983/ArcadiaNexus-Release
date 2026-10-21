--[[
    ArcadiaNexus - Blockdrop Leaderboard-Schema
    Games/Blockdrop/Blockdrop_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "BLOCKDROP",
    difficulties = { "normal" },
    sections = {
        S.TopScores(3),
        S.StatsPlayed(),
        {type="top_scores",field="legacyHighscores",count=3,titleKey="lb_bld_legacy",hideIfEmpty=true},
        S.StatBox("lb_bld_legacy_lines",{{field="legacyBestLines",labelKey="lb_bld_best_lines"}}),
        S.StatBox("lb_bld_best_lines", {
            { fromStats = "linesCleared", labelKey = "lb_bld_best_lines", valueColor = "gold" },
        }),
    },
})
