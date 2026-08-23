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
        id="SNK_WINS", gameId="SNAKE", category="ARCADE",
        title_de="Schlangenbeschwörer", title_en="Snake Charmer",
        desc_de="Gewinne Snake-Spiele.", desc_en="Win Snake games.",
        icon=2399269, -- INV_GiantSnake_Green
        condition = function(data, db)
            if data.gameId ~= "SNAKE" then return 0 end
            return getTotalWins(db, "SNAKE")
        end,
        tiers = {
            { id="SNK_WINS_BRONZE", tierName="Bronze", target=3,  xp=15, desc_de="Gewinne 3x.",  desc_en="Win 3 games."  },
            { id="SNK_WINS_SILBER", tierName="Silber", target=10, xp=30, desc_de="Gewinne 10x.", desc_en="Win 10 games." },
            { id="SNK_WINS_GOLD",   tierName="Gold",   target=30, xp=55, desc_de="Gewinne 30x.", desc_en="Win 30 games." },
        },
    },

    {
        id="SNK_LENGTH", gameId="SNAKE", category="ARCADE",
        title_de="Riesenschlange", title_en="Giant Serpent",
        desc_de="Wachse auf eine beeindruckende Länge.", desc_en="Grow to an impressive length.",
        icon="Interface\\Icons\\Ability_Druid_NaturalPerfection",
        condition = function(data, db)
            if data.gameId ~= "SNAKE" then return 0 end
            return data.stats and data.stats.length or 0
        end,
        tiers = {
            { id="SNK_LENGTH_BRONZE", tierName="Bronze", target=15, xp=15, desc_de="Länge 15.", desc_en="Length 15." },
            { id="SNK_LENGTH_SILBER", tierName="Silber", target=30, xp=35, desc_de="Länge 30.", desc_en="Length 30." },
            { id="SNK_LENGTH_GOLD",   tierName="Gold",   target=50, xp=60, desc_de="Länge 50!", desc_en="Length 50!" },
        },
    },
})
