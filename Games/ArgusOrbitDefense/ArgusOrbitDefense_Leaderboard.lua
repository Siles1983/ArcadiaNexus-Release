local LR=ArcadiaNexus.LeaderboardRegistry
local S=LR.SECTION
local variants={}; local ids={}
for _,mode in ipairs({"levels","endless"}) do
    for _,diff in ipairs({"easy","normal","hard"}) do
        local id=mode.."_"..diff; ids[#ids+1]=id
        variants[#variants+1]={id=id,labelKey="lb_aod_"..id}
    end
end
for _,diff in ipairs({"easy","normal","hard"}) do variants[#variants+1]={id=diff,labelKey="lb_aod_legacy_"..diff} end
local scores=S.TopScores(3); scores.difficulties=ids
local stats=S.StatsWinsPlayed(); stats.difficulties=ids
stats.rows[#stats.rows+1]=S.BestLevel()
stats.rows[#stats.rows+1]={field="clearedStages",labelKey="lb_aod_stages",valueColor="gold"}
local legacy=S.TopScores(3); legacy.titleKey="lb_aod_legacy"; legacy.difficulties={"easy","normal","hard"}
ArcadiaNexus.RegisterLeaderboard({gameId="ARGUSORBDEFENSE",difficulties=variants,sections={scores,stats,legacy}})
