local A=ArcadiaNexus
local LR=A.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S=LR.SECTION
local variants={}
for _,mode in ipairs({'free','limit'}) do for _,diff in ipairs({'easy','normal','hard'}) do
 variants[#variants+1]={id='v2_'..mode..'_'..diff,labelKey='variant_'..mode..'_'..diff}
end end
local historical=S.TopScores(3); historical.titleKey='legacy_title'; historical.hideIfEmpty=true; historical.difficulties={'easy','normal','hard'}
local historicalStats=S.StatsWL('legacy_title'); historicalStats.difficulties={'easy','normal','hard'}
A.RegisterLeaderboard({gameId='SHADOWSCONQUEST',difficulties=variants,sections={S.TopScores(3),S.StatsWL(),historical,historicalStats}})
