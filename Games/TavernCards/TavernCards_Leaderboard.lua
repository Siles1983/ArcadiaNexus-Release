-- Future origins are explicit; historical aggregates are retained without guessing.
local LR=ArcadiaNexus.LeaderboardRegistry; local S=LR.SECTION
local solo=S.StatsWL(); solo.titleKey="lb_solo"; solo.difficulties={
    {id="solo_easy",labelKey="diff_easy"},{id="solo_normal",labelKey="diff_normal"},{id="solo_hard",labelKey="diff_hard"}}
local match=S.StatsWL(); match.titleKey="lb_match"; match.difficulties={"match"}
local legacy=S.StatsWL(); legacy.titleKey="lb_legacy"; legacy.difficulties={"easy","normal","hard"}
ArcadiaNexus.RegisterLeaderboard({gameId="TAVERNCARDS",difficulties=solo.difficulties,sections={solo,match,legacy}})
