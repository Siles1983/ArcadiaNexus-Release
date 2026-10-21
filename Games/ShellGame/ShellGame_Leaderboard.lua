--[[
    ArcadiaNexus - ShellGame Leaderboard-Schema
    Games/ShellGame/ShellGame_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SHELLGAME",
    difficulties = {{id="round_easy",labelKey="lb_diff_easy"},{id="round_normal",labelKey="lb_diff_normal"},{id="round_hard",labelKey="lb_diff_hard"}},
    sections = {
        S.GlobalStats("lb_capital", {{fromStats="finalChips",labelKey="lb_max_capital",format="halfChips",valueColor="gold"}}),
        S.StatsWL("lb_rounds"),
        {type="stats",titleKey="lb_legacy_sessions",difficulties={"easy","normal","hard","default"},rows=S.StatsWL().rows},
    },
})
