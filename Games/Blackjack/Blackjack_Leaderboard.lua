local S=ArcadiaNexus.LeaderboardRegistry.SECTION
local old={"easy","normal","hard","default"}
local current={{id="table",labelKey="lb_table"}}
local capital={type="stats",titleKey="lb_capital",difficulties=current,rows={
    {fromStats="finalChips",labelKey="lb_max_capital",valueColor="gold",format="halfChips"}}}
local rounds=S.StatsWLD("lb_rounds"); rounds.difficulties=current
local legacy=S.StatsWLD("lb_legacy_sessions"); legacy.difficulties=old
local legacyCapital={type="stats",titleKey="lb_legacy_capital",difficulties=old,rows={
    {fromStats="finalChips",labelKey="lb_max_capital",valueColor="gold",format="halfChips"}}}
ArcadiaNexus.RegisterLeaderboard({gameId="BLACKJACK",difficulties=current,sections={capital,rounds,legacy,legacyCapital}})
