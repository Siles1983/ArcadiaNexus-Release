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
        id="M3_WINS", gameId="MATCH3", category="DENKSPIELE",
        title_de="Drei-Kombinierer", title_en="Triple Matcher",
        desc_de="Gewinne Match-3-Partien.", desc_en="Win Match-3 games.",
        icon="Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
        condition = function(data, db)
            if data.gameId ~= "MATCH3" then return 0 end
            return getTotalWins(db, "MATCH3")
        end,
        tiers = {
            { id="M3_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="M3_WINS_SILBER", tierName="Silber", target=20, xp=30, desc_de="Gewinne 20x.", desc_en="Win 20 games." },
            { id="M3_WINS_GOLD",   tierName="Gold",   target=60, xp=55, desc_de="Gewinne 60x.", desc_en="Win 60 games." },
        },
    },

    {
        id="M3_COMBO", gameId="MATCH3", category="DENKSPIELE",
        title_de="Kaskadenmeister", title_en="Cascade Master",
        desc_de="Erziele hohe Combos in Match-3.", desc_en="Achieve high combos in Match-3.",
        icon="Interface\\Icons\\Spell_Fire_Fireball",
        condition = function(data, db)
            if data.gameId ~= "MATCH3" then return 0 end
            return data.stats and data.stats.maxCombo or 0
        end,
        tiers = {
            { id="M3_COMBO_BRONZE", tierName="Bronze", target=3, xp=20, desc_de="Combo x3.", desc_en="Combo x3." },
            { id="M3_COMBO_SILBER", tierName="Silber", target=5, xp=40, desc_de="Combo x5.", desc_en="Combo x5." },
            { id="M3_COMBO_GOLD",   tierName="Gold",   target=8, xp=65, desc_de="Combo x8!", desc_en="Combo x8!" },
        },
    },
})
