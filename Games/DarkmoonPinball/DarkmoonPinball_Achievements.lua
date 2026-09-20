--[[
    ArcadiaNexus – Darkmoon Pinball
    Games/DarkmoonPinball/DarkmoonPinball_Achievements.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus

local GAME_ID = "DARKMOON_PINBALL"

local function Stat(data, key)
    return (data.stats and data.stats[key]) or 0
end

local function Cumulative(data, db, groupId, key)
    if data.gameId ~= GAME_ID then return 0 end
    local add = Stat(data, key)
    if add <= 0 then return 0 end
    local prog = db and db.achievements and db.achievements.progress and db.achievements.progress[groupId]
    return (prog and prog.current or 0) + add
end

ArcadiaNexus.RegisterAchievements({
    {
        id       = "DMP_SCORE",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Jahrmarkt-Tickets",
        title_en = "Faire Tickets",
        desc_de  = "Erziele hohe Punktzahlen in Darkmoon Pinball.",
        desc_en  = "Reach high scores in Darkmoon Pinball.",
        icon     = "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01",
        condition = function(data)
            if data.gameId ~= GAME_ID then return 0 end
            return data.score or 0
        end,
        tiers = {
            { id = "DMP_SCORE_BRONZE", tierName = "Bronze", target = 50000, xp = 20,
              desc_de = "Erreiche 50.000 Punkte.", desc_en = "Reach 50,000 points." },
            { id = "DMP_SCORE_SILBER", tierName = "Silber", target = 175000, xp = 45,
              desc_de = "Erreiche 175.000 Punkte.", desc_en = "Reach 175,000 points." },
            { id = "DMP_SCORE_GOLD",   tierName = "Gold",   target = 300000, xp = 80,
              desc_de = "Erreiche 300.000 Punkte.", desc_en = "Reach 300,000 points." },
        },
    },
    {
        id       = "DMP_COMBO",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Mondkette",
        title_en = "Moon Chain",
        desc_de  = "Baue hohe Combos auf.",
        desc_en  = "Build high combos.",
        icon     = "Interface\\Icons\\Spell_Nature_StarFall",
        condition = function(data)
            if data.gameId ~= GAME_ID then return 0 end
            return Stat(data, "maxCombo")
        end,
        tiers = {
            { id = "DMP_COMBO_BRONZE", tierName = "Bronze", target = 10, xp = 15,
              desc_de = "Combo x10.", desc_en = "Combo x10." },
            { id = "DMP_COMBO_SILBER", tierName = "Silber", target = 20, xp = 35,
              desc_de = "Combo x20.", desc_en = "Combo x20." },
            { id = "DMP_COMBO_GOLD",   tierName = "Gold",   target = 35, xp = 60,
              desc_de = "Combo x35.", desc_en = "Combo x35." },
        },
    },
    {
        id       = "DMP_MISSION",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Jahrmarkt-Aufträge",
        title_en = "Faire Contracts",
        desc_de  = "Schließe Missionen in einer Runde ab.",
        desc_en  = "Complete missions in a single round.",
        icon     = "Interface\\Icons\\INV_Misc_Note_01",
        condition = function(data)
            if data.gameId ~= GAME_ID then return 0 end
            return Stat(data, "missionsDone")
        end,
        tiers = {
            { id = "DMP_MISSION_BRONZE", tierName = "Bronze", target = 1, xp = 15,
              desc_de = "1 Mission in einer Runde.", desc_en = "1 mission in one round." },
            { id = "DMP_MISSION_SILBER", tierName = "Silber", target = 2, xp = 35,
              desc_de = "2 Missionen in einer Runde.", desc_en = "2 missions in one round." },
            { id = "DMP_MISSION_GOLD",   tierName = "Gold",   target = 4, xp = 65,
              desc_de = "Alle 4 Missionen in einer Runde.", desc_en = "All 4 missions in one round." },
        },
    },
    {
        id       = "DMP_MULTIBALL",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Arkanes Durcheinander",
        title_en = "Arcane Chaos",
        desc_de  = "Starte Multiballs.",
        desc_en  = "Start multiballs.",
        icon     = "Interface\\Icons\\Spell_Arcane_Arcane04",
        condition = function(data, db)
            return Cumulative(data, db, "DMP_MULTIBALL", "multiballs")
        end,
        tiers = {
            { id = "DMP_MULTIBALL_BRONZE", tierName = "Bronze", target = 1,  xp = 20,
              desc_de = "1 Multiball.",  desc_en = "1 multiball." },
            { id = "DMP_MULTIBALL_SILBER", tierName = "Silber", target = 5,  xp = 40,
              desc_de = "5 Multiballs.", desc_en = "5 multiballs." },
            { id = "DMP_MULTIBALL_GOLD",   tierName = "Gold",   target = 12, xp = 70,
              desc_de = "12 Multiballs.", desc_en = "12 multiballs." },
        },
    },
    {
        id       = "DMP_JACKPOT",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Preiszelt",
        title_en = "Prize Tent",
        desc_de  = "Triff Jackpots in einer Runde.",
        desc_en  = "Hit jackpots in a single round.",
        icon     = "Interface\\Icons\\INV_Misc_Coin_02",
        condition = function(data)
            if data.gameId ~= GAME_ID then return 0 end
            return Stat(data, "jackpots")
        end,
        tiers = {
            { id = "DMP_JACKPOT_BRONZE", tierName = "Bronze", target = 1, xp = 15,
              desc_de = "1 Jackpot.", desc_en = "1 jackpot." },
            { id = "DMP_JACKPOT_SILBER", tierName = "Silber", target = 3, xp = 40,
              desc_de = "3 Jackpots in einer Runde (Super).", desc_en = "3 jackpots in one round (super)." },
            { id = "DMP_JACKPOT_GOLD",   tierName = "Gold",   target = 6, xp = 70,
              desc_de = "6 Jackpots in einer Runde.", desc_en = "6 jackpots in one round." },
        },
    },
    {
        id       = "DMP_EXTRA",
        gameId   = GAME_ID,
        category = "ARCADE",
        title_de = "Freikugel",
        title_en = "Free Ball",
        desc_de  = "Verdiene Extra Balls.",
        desc_en  = "Earn extra balls.",
        icon     = "Interface\\Icons\\INV_Misc_Eye_02",
        condition = function(data, db)
            return Cumulative(data, db, "DMP_EXTRA", "extraBalls")
        end,
        tiers = {
            { id = "DMP_EXTRA_BRONZE", tierName = "Bronze", target = 1,  xp = 20,
              desc_de = "1 Extra Ball.",  desc_en = "1 extra ball." },
            { id = "DMP_EXTRA_SILBER", tierName = "Silber", target = 5,  xp = 40,
              desc_de = "5 Extra Balls.", desc_en = "5 extra balls." },
            { id = "DMP_EXTRA_GOLD",   tierName = "Gold",   target = 12, xp = 70,
              desc_de = "12 Extra Balls.", desc_en = "12 extra balls." },
        },
    },
})
