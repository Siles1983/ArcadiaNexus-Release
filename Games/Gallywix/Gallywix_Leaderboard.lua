local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
-- Completed solo games only; forced debug landings are unranked.
ArcadiaNexus.RegisterLeaderboard({
    gameId = "GALLYWIX", difficulties = {
        {id="default",labelKey="lb_without_gallywix"},
        {id="gallywix",labelKey="lb_with_gallywix"},
        {id="match_2p",labelKey="lb_match_2p"},
        {id="match_2p_gallywix",labelKey="lb_match_2p_gallywix"},
        {id="match_2p_ai",labelKey="lb_match_2p_ai"},
        {id="match_2p_ai_gallywix",labelKey="lb_match_2p_ai_gallywix"},
        {id="match_3p",labelKey="lb_match_3p"},
        {id="match_3p_gallywix",labelKey="lb_match_3p_gallywix"},
        {id="match",labelKey="lb_match"},
        {id="match_gallywix",labelKey="lb_match_gallywix"},
    }, sections = { LR.SECTION.TopScores(3), LR.SECTION.StatsWLD() },
})
