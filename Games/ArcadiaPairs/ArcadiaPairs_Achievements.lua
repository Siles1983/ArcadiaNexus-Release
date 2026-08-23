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
        id="AP_WINS", gameId="ARCADIAPAIRS", category="KARTEN",
        title_de="Scharfes Gedächtnis", title_en="Sharp Memory",
        desc_de="Gewinne Arcadia-Pairs-Spiele.", desc_en="Win Arcadia Pairs games.",
        icon=132150, -- Ability_EyeOfTheOwl
        condition = function(data, db)
            if data.gameId ~= "ARCADIAPAIRS" then return 0 end
            return getTotalWins(db, "ARCADIAPAIRS")
        end,
        tiers = {
            { id="AP_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="AP_WINS_SILBER", tierName="Silber", target=20, xp=30, desc_de="Gewinne 20x.", desc_en="Win 20 games." },
            { id="AP_WINS_GOLD",   tierName="Gold",   target=50, xp=55, desc_de="Gewinne 50x.", desc_en="Win 50 games." },
        },
    },

    {
        id="AP_EFFICIENT", gameId="ARCADIAPAIRS", category="KARTEN",
        title_de="Fotografisches Gedächtnis", title_en="Photographic Memory",
        desc_de="Gewinne mit sehr wenigen Versuchen.", desc_en="Win with very few attempts.",
        icon="Interface\\Icons\\Spell_Shadow_MindShear",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAPAIRS" or data.result ~= "WIN" then return 0 end
            local moves = data.stats and data.stats.moves or 999
            local pairs = data.stats and data.stats.pairs or 1
            local ratio = moves / math.max(pairs, 1)
            if ratio <= 1.2 then return 3 end
            if ratio <= 1.5 then return 2 end
            if ratio <= 2.0 then return 1 end
            return 0
        end,
        tiers = {
            { id="AP_EFFICIENT_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Max. 2x Versuche.",   desc_en="At most 2x attempts."   },
            { id="AP_EFFICIENT_SILBER", tierName="Silber", target=2, xp=40, desc_de="Max. 1,5x Versuche.", desc_en="At most 1.5x attempts." },
            { id="AP_EFFICIENT_GOLD",   tierName="Gold",   target=3, xp=65, desc_de="Max. 1,2x Versuche!", desc_en="At most 1.2x attempts!" },
        },
    },
})
