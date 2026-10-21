-- Current per-round records and untouched historical payout/session records.
local LR=ArcadiaNexus.LeaderboardRegistry; if not LR or not LR.SECTION then return end
local S=LR.SECTION
local legacy={"easy","normal","hard","default"}
local capital=S.StatBox("lb_capital",{{fromStats="finalChips",labelKey="lb_max_capital",format="halfChips",valueColor="gold"}})
local oldTop=S.TopScores(3); oldTop.titleKey="lb_legacy_scores"; oldTop.difficulties=legacy
local oldStats=S.StatBox("lb_legacy_records",{
    {fromStats="maxStreak",labelKey="lb_max_streak"},
    {fromStats="maxMultiplier",labelKey="lb_max_multiplier",format="multiplier"},
    {fromStats="finalChips",labelKey="lb_max_capital",format="halfChips"},
}); oldStats.difficulties=legacy
local oldRounds=S.StatsWLD("lb_legacy_sessions"); oldRounds.difficulties=legacy
ArcadiaNexus.RegisterLeaderboard({gameId="HIGHERORLOWER",difficulties={{id="standard",labelKey="variant_standard"},{id="joker",labelKey="variant_joker"}},sections={
    S.StatBox("lb_records",{{fromStats="maxStreak",labelKey="lb_max_streak",valueColor="gold"}}),
    capital,S.StatsWLD("lb_rounds"),oldTop,oldStats,oldRounds,
}})
