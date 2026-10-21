-- New win-only action scores are kept outside the untouched historical scores.
local LR=ArcadiaNexus.LeaderboardRegistry; if not LR or not LR.SECTION then return end
local S=LR.SECTION
local current=S.TopScores(3); current.titleKey="lb_current_scores"; current.field="winScores"
current.resultField="newScore"; current.result="WIN"; current.order="desc"
local legacy=S.TopScores(3); legacy.titleKey="lb_legacy_scores"
ArcadiaNexus.RegisterLeaderboard({gameId="SOLITAIRE",difficulties={"1card","3card"},sections={current,S.StatsWL(),legacy}})
