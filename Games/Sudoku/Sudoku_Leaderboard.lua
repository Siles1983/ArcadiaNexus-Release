--[[
    ArcadiaNexus - Sudoku Leaderboard-Schema
    Games/Sudoku/Sudoku_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
local S  = LR.SECTION

ArcadiaNexus.RegisterLeaderboard({
    gameId = "SUDOKU",
    difficulties = { "easy", "normal", "hard" },
    sections = {
        {type="stats",titleKey="lb_solved",rows={{field="wins",labelKey="lb_solved",valueColor="win"}}},
        {type="top_scores",titleKey="lb_legacy_points",field="legacyHighscores",hideIfEmpty=true,count=3},
    },
})
