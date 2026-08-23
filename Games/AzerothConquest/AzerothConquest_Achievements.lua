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
        id="AC_WINS", gameId="AZEROTHCONQUEST", category="STRATEGIE",
        title_de="Flottenstratege", title_en="Fleet Strategist",
        desc_de="Versenke die feindliche Flotte.", desc_en="Sink the enemy fleet.",
        icon="Interface\\Icons\\INV_Misc_Anchor",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHCONQUEST" then return 0 end
            return getTotalWins(db, "AZEROTHCONQUEST")
        end,
        tiers = {
            { id="AC_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="AC_WINS_SILBER", tierName="Silber", target=25, xp=35, desc_de="Gewinne 25x.", desc_en="Win 25 games." },
            { id="AC_WINS_GOLD",   tierName="Gold",   target=75, xp=60, desc_de="Gewinne 75x.", desc_en="Win 75 games." },
        },
    },

    {
        id="AC_PERFECT", gameId="AZEROTHCONQUEST", category="STRATEGIE",
        title_de="Scharfschütze der Meere", title_en="Naval Sharpshooter",
        desc_de="Versenke alle Schiffe ohne Fehlschuss.", desc_en="Sink all ships without missing.",
        icon=132329, -- Ability_TrueShot
        condition = function(data, db)
            if data.gameId ~= "AZEROTHCONQUEST" or data.result ~= "WIN" then return 0 end
            if (data.stats and data.stats.misses or 999) ~= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["AC_PERFECT"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="AC_PERFECT_BRONZE", tierName="Bronze", target=1, xp=35, desc_de="Einmal ohne Fehlschuss.",  desc_en="Win without missing."       },
            { id="AC_PERFECT_SILBER", tierName="Silber", target=3, xp=55, desc_de="Dreimal ohne Fehlschuss.", desc_en="Win 3 times without missing." },
            { id="AC_PERFECT_GOLD",   tierName="Gold",   target=5, xp=80, desc_de="Fünfmal ohne Fehlschuss.", desc_en="Win 5 times without missing." },
        },
    },
})
