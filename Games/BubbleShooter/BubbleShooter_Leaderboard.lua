--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/BubbleShooter_Leaderboard.lua
]]

local LR = ArcadiaNexus.LeaderboardRegistry
if not LR or not LR.SECTION then return end
local S = LR.SECTION

local stats = S.StatsWinsPlayed()
table.insert(stats.rows, { fromStats = "maxCombo", labelKey = "lb_max_combo", valueColor = "gold" })
table.insert(stats.rows, { fromStats = "maxDrop",  labelKey = "lb_max_drop",  valueColor = "gold" })

local arcade={"endless_easy","endless_normal","endless_hard","time_easy","time_normal","time_hard"}
local campaign={"shot_easy","shot_normal","shot_hard"}
local scores=S.TopScores(3); scores.difficulties=arcade
local history=S.TopScores(3); history.difficulties=campaign
history.field="legacyCampaignScores"; history.titleKey="lb_campaign_legacy"
local progress={type="stats",titleKey="lb_campaign_progress",difficulties=campaign,rows={
    {field="completedLevels",labelKey="lb_campaign_levels",valueColor="gold"},
    {field="campaignStars",labelKey="lb_campaign_stars",valueColor="gold"}}}
ArcadiaNexus.RegisterLeaderboard({
    gameId = "BUBBLESHOOTER",
    difficulties = {
        { id = "endless_easy",   labelKey = "lb_endless_easy" },
        { id = "endless_normal", labelKey = "lb_endless_normal" },
        { id = "endless_hard",   labelKey = "lb_endless_hard" },
        { id = "time_easy",      labelKey = "lb_time_easy" },
        { id = "time_normal",    labelKey = "lb_time_normal" },
        { id = "time_hard",      labelKey = "lb_time_hard" },
        { id = "shot_easy",      labelKey = "lb_shot_easy" },
        { id = "shot_normal",    labelKey = "lb_shot_normal" },
        { id = "shot_hard",      labelKey = "lb_shot_hard" },
    },
    sections = {
        scores,
        progress,
        stats,
        history,
    },
})
