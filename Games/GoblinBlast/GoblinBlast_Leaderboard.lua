local LR=ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S=LR.SECTION
local stats=S.StatsWL()
stats.rows[#stats.rows+1]={field="clearedStages",labelKey="lb_gb_cleared"}
stats.rows[#stats.rows+1]=S.BestLevel()
ArcadiaNexus.RegisterLeaderboard({gameId="GOBLINBLAST",difficulties={"easy","normal","hard"},sections={
    S.TopScores(3),stats,
    {type="top_scores",field="legacyHighscores",count=3,titleKey="lb_gb_legacy",hideIfEmpty=true},
    {type="stats",titleKey="lb_gb_legacy_stats",rows={
        {field="legacyGamesPlayed",labelKey="lb_played"},{field="legacyWins",labelKey="lb_gb_old_levels"},
        {field="legacyLosses",labelKey="lb_losses"},{field="legacyBestLevel",labelKey="lb_best_level"},
        {field="checkpointRunsPlayed",labelKey="lb_gb_checkpoints"},
        {field="checkpointRunsWon",labelKey="lb_wins"},{field="checkpointRunsLost",labelKey="lb_losses"},
    }},
}})
