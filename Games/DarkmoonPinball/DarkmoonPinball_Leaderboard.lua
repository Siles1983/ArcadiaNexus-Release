--[[
    ArcadiaNexus – Darkmoon Pinball Leaderboard
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S = LR.SECTION

local stats = S.StatsPlayed()
table.insert(stats.rows, {
    fromStats = "maxCombo",
    labelKey = "dmp_best_combo",
    valueColor = "gold",
})
table.insert(stats.rows, {
    fromStats = "kickbacks",
    labelKey = "dmp_kickbacks",
    valueColor = "gold",
})
table.insert(stats.rows, {
    fromStats = "tilts",
    labelKey = "dmp_tilts",
})
table.insert(stats.rows, {
    fromStats = "multiballs",
    labelKey = "dmp_multiballs",
    valueColor = "gold",
})
table.insert(stats.rows, {
    fromStats = "jackpots",
    labelKey = "dmp_jackpots",
})
table.insert(stats.rows, {
    fromStats = "ballSaves",
    labelKey = "dmp_ball_saves",
})
table.insert(stats.rows, {
    fromStats = "missionsDone",
    labelKey = "dmp_missions",
    valueColor = "gold",
})
table.insert(stats.rows, {
    fromStats = "extraBalls",
    labelKey = "dmp_extra_balls",
    valueColor = "gold",
})

local diffs = {}
local TR = ArcadiaNexus.DMP_TableRegistry
local listed = TR and TR.List and TR.List() or {}
for i = 1, #listed do
    diffs[#diffs + 1] = {
        id = listed[i].id,
        labelKey = listed[i].labelKey or ("dmp_table_" .. listed[i].id),
    }
end
if #diffs < 1 then
    diffs[1] = { id = "darkmoon_midway", labelKey = "dmp_table_midway" }
end

ArcadiaNexus.RegisterLeaderboard({
    gameId = "DARKMOON_PINBALL",
    difficulties = diffs,
    sections = {
        S.TopScores(3),
        stats,
    },
})
