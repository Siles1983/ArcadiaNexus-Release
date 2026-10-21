--[[
    ArcadiaNexus - SlidingPuzzle Leaderboard-Schema
    Games/SlidingPuzzle/SlidingPuzzle_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

local history=S.StatsWinsPlayed(); history.titleKey="lb_legacy_stats"
history.difficulties={{id="easy",labelKey="lb_legacy_easy"},{id="medium",labelKey="lb_legacy_medium"},{id="hard",labelKey="lb_legacy_hard"}}
ArcadiaNexus.RegisterLeaderboard({
    gameId="MOSAICOFAZEROTH",
    difficulties={{id="v2_easy",labelKey="lb_size_easy"},{id="v2_medium",labelKey="lb_size_medium"},{id="v2_hard",labelKey="lb_size_hard"}},
    sections={S.StatsWinsPlayed(),history,{type="top_scores",titleKey="lb_legacy_points",count=3,hideIfEmpty=true,
        difficulties={{id="easy",labelKey="lb_legacy_easy"},{id="medium",labelKey="lb_legacy_medium"},{id="hard",labelKey="lb_legacy_hard"}}}},
})
