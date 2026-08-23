local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalWins(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0)
    end
    return total
end

ArcadiaNexus.RegisterAchievements({
    {
        id = "TC_WINS", gameId = "TAVERNCARDS", category = "KARTEN",
        title_de = "Kartenspieler", title_en = "Card Shark",
        desc_de = "Gewinne Spiele in Tavern Cards.", desc_en = "Win games in Tavern Cards.",
        icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_05",
        condition = function(data, db)
            if data.gameId ~= "TAVERNCARDS" then return 0 end
            return getTotalWins(db, "TAVERNCARDS")
        end,
        tiers = {
            { id = "TC_WINS_BRONZE", tierName = "Bronze", target = 1,  xp = 15, desc_de = "1 Sieg.",  desc_en = "1 win."  },
            { id = "TC_WINS_SILBER", tierName = "Silber", target = 10, xp = 35, desc_de = "10 Siege.", desc_en = "10 wins." },
            { id = "TC_WINS_GOLD",   tierName = "Gold",   target = 50, xp = 70, desc_de = "50 Siege!", desc_en = "50 wins!" },
        },
    },
    {
        id = "TC_UNO", gameId = "TAVERNCARDS", category = "KARTEN",
        title_de = "UNO-Meister", title_en = "UNO Master",
        desc_de = "Rufe UNO! erfolgreich.", desc_en = "Call UNO successfully.",
        icon = 134484, -- INV_Misc_Ticket_Tarot_BlueDragon_01
        condition = function(data, db)
            if data.gameId ~= "TAVERNCARDS" or not data.stats then return 0 end
            local session = data.stats.unosCalled or 0
            if session <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress and db.achievements.progress["TC_UNO"]
            return (prog and prog.current or 0) + session
        end,
        tiers = {
            { id = "TC_UNO_BRONZE", tierName = "Bronze", target = 10,  xp = 15, desc_de = "10 UNOs.",  desc_en = "10 UNOs."  },
            { id = "TC_UNO_SILBER", tierName = "Silber", target = 50,  xp = 35, desc_de = "50 UNOs.",  desc_en = "50 UNOs."  },
            { id = "TC_UNO_GOLD",   tierName = "Gold",   target = 200, xp = 65, desc_de = "200 UNOs!", desc_en = "200 UNOs!" },
        },
    },
    {
        id = "TC_WILD", gameId = "TAVERNCARDS", category = "KARTEN",
        title_de = "Wildcards", title_en = "Wildcards",
        desc_de = "Spiele +4-Wild-Karten.", desc_en = "Play Wild Draw Four cards.",
        icon = 237164, -- INV_Inscription_TarotChaos
        condition = function(data, db)
            if data.gameId ~= "TAVERNCARDS" or not data.stats then return 0 end
            local session = data.stats.wild4Played or 0
            if session <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress and db.achievements.progress["TC_WILD"]
            return (prog and prog.current or 0) + session
        end,
        tiers = {
            { id = "TC_WILD_BRONZE", tierName = "Bronze", target = 10,  xp = 15, desc_de = "10 +4.",  desc_en = "10 Wild +4."  },
            { id = "TC_WILD_SILBER", tierName = "Silber", target = 50,  xp = 35, desc_de = "50 +4.",  desc_en = "50 Wild +4."  },
            { id = "TC_WILD_GOLD",   tierName = "Gold",   target = 150, xp = 60, desc_de = "150 +4!", desc_en = "150 Wild +4!" },
        },
    },
})
