--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/BubbleShooter_Achievements.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalWins(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0)
    end
    return total
end

local function GetTotals(db)
    local gs = db and db.gameSettings and db.gameSettings.BUBBLESHOOTER
    return gs and gs.stats or {}
end

ArcadiaNexus.RegisterAchievements({
    {
        id = "BS_LEVELS", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Ley-Kartograph", title_en = "Ley Cartographer",
        desc_de = "Schließe Kampagnen-Level ab.", desc_en = "Complete campaign levels.",
        icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            return GetTotals(db).totalLevels or 0
        end,
        tiers = {
            { id = "BS_LEVELS_BRONZE", tierName = "Bronze", target = 10,  xp = 15, desc_de = "Schließe 10 Level ab.",  desc_en = "Complete 10 levels." },
            { id = "BS_LEVELS_SILBER", tierName = "Silber", target = 50,  xp = 35, desc_de = "Schließe 50 Level ab.",  desc_en = "Complete 50 levels." },
            { id = "BS_LEVELS_GOLD",   tierName = "Gold",   target = 100, xp = 70, desc_de = "Schließe 100 Level ab.", desc_en = "Complete 100 levels." },
        },
    },
    {
        id = "BS_COMBO", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Ley-Kette", title_en = "Ley Chain",
        desc_de = "Erreiche hohe Kombos.", desc_en = "Reach high combos.",
        icon = "Interface\\Icons\\Spell_Nature_ChainLightning",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            return (data.stats and data.stats.maxCombo) or 0
        end,
        tiers = {
            { id = "BS_COMBO_BRONZE", tierName = "Bronze", target = 4, xp = 15, desc_de = "Kombo x4.", desc_en = "Combo x4." },
            { id = "BS_COMBO_SILBER", tierName = "Silber", target = 8, xp = 35, desc_de = "Kombo x8.", desc_en = "Combo x8." },
            { id = "BS_COMBO_GOLD",   tierName = "Gold",   target = 12, xp = 60, desc_de = "Kombo x12.", desc_en = "Combo x12." },
        },
    },
    {
        id = "BS_DROP", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Arkaner Einsturz", title_en = "Arcane Collapse",
        desc_de = "Lass große Cluster fallen.", desc_en = "Drop large clusters.",
        icon = "Interface\\Icons\\Spell_Arcane_Arcane04",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            return (data.stats and data.stats.maxDrop) or 0
        end,
        tiers = {
            { id = "BS_DROP_BRONZE", tierName = "Bronze", target = 5,  xp = 15, desc_de = "5 Kugeln in einem Fall.",  desc_en = "Drop 5 orbs at once." },
            { id = "BS_DROP_SILBER", tierName = "Silber", target = 10, xp = 35, desc_de = "10 Kugeln in einem Fall.", desc_en = "Drop 10 orbs at once." },
            { id = "BS_DROP_GOLD",   tierName = "Gold",   target = 20, xp = 60, desc_de = "20 Kugeln in einem Fall.", desc_en = "Drop 20 orbs at once." },
        },
    },
    {
        id = "BS_POWER", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Machtweber", title_en = "Power Weaver",
        desc_de = "Setze Mächte ein.", desc_en = "Use power-ups.",
        icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            return GetTotals(db).totalPowerUsed or 0
        end,
        tiers = {
            { id = "BS_POWER_BRONZE", tierName = "Bronze", target = 5,  xp = 15, desc_de = "5 Mächte einsetzen.",  desc_en = "Use 5 powers." },
            { id = "BS_POWER_SILBER", tierName = "Silber", target = 20, xp = 30, desc_de = "20 Mächte einsetzen.", desc_en = "Use 20 powers." },
            { id = "BS_POWER_GOLD",   tierName = "Gold",   target = 50, xp = 55, desc_de = "50 Mächte einsetzen.", desc_en = "Use 50 powers." },
        },
    },
    {
        id = "BS_OVERCHARGE", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Overcharge", title_en = "Overcharge",
        desc_de = "Löse Overcharge aus.", desc_en = "Trigger Overcharge.",
        icon = "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            local fromEvent = data.stats and data.stats.overchargeCount or 0
            local fromDb = GetTotals(db).totalOvercharge or 0
            if fromEvent > fromDb then return fromEvent end
            return fromDb
        end,
        tiers = {
            { id = "BS_OVERCHARGE_BRONZE", tierName = "Bronze", target = 1,  xp = 15, desc_de = "1× Overcharge.",  desc_en = "Trigger Overcharge once." },
            { id = "BS_OVERCHARGE_SILBER", tierName = "Silber", target = 10, xp = 30, desc_de = "10× Overcharge.", desc_en = "Trigger Overcharge 10 times." },
            { id = "BS_OVERCHARGE_GOLD",   tierName = "Gold",   target = 25, xp = 55, desc_de = "25× Overcharge.", desc_en = "Trigger Overcharge 25 times." },
        },
    },
    {
        id = "BS_WINS", gameId = "BUBBLESHOOTER", category = "ARCADE",
        title_de = "Kugelmeister", title_en = "Orb Master",
        desc_de = "Gewinne Partien.", desc_en = "Win games.",
        icon = "Interface\\Icons\\INV_Misc_Orb_01",
        condition = function(data, db)
            if data.gameId ~= "BUBBLESHOOTER" then return 0 end
            return getTotalWins(db, "BUBBLESHOOTER")
        end,
        tiers = {
            { id = "BS_WINS_BRONZE", tierName = "Bronze", target = 3,  xp = 15, desc_de = "Gewinne 3×.",  desc_en = "Win 3 games." },
            { id = "BS_WINS_SILBER", tierName = "Silber", target = 10, xp = 30, desc_de = "Gewinne 10×.", desc_en = "Win 10 games." },
            { id = "BS_WINS_GOLD",   tierName = "Gold",   target = 25, xp = 55, desc_de = "Gewinne 25×.", desc_en = "Win 25 games." },
        },
    },
})
