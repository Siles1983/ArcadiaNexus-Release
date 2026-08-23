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
        id="WRD_WINS", gameId="AZEROTHWORDS", category="WORT",
        title_de="Worte des Lichts", title_en="Words of Light",
        desc_de="Errate Wörter in Azeroth Words.", desc_en="Guess words in Azeroth Words.",
        icon="Interface\\Icons\\INV_Letter_17",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHWORDS" then return 0 end
            return getTotalWins(db, "AZEROTHWORDS")
        end,
        tiers = {
            { id="WRD_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Errate 5 Wörter.",  desc_en="Guess 5 words."  },
            { id="WRD_WINS_SILBER", tierName="Silber", target=25, xp=35, desc_de="Errate 25 Wörter.", desc_en="Guess 25 words." },
            { id="WRD_WINS_GOLD",   tierName="Gold",   target=75, xp=60, desc_de="Errate 75 Wörter!", desc_en="Guess 75 words!" },
        },
    },

    {
        id="WRD_FIRSTTRY", gameId="AZEROTHWORDS", category="WORT",
        title_de="Arkane Intuition", title_en="Arcane Intuition",
        desc_de="Errate das Wort im ersten Versuch.", desc_en="Guess the word on the first try.",
        icon=135732, -- Spell_Arcane_ArcanePotency
        condition = function(data, db)
            if data.gameId ~= "AZEROTHWORDS" or data.result ~= "WIN" then return 0 end
            if (data.stats and data.stats.attemptsUsed or 999) ~= 1 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["WRD_FIRSTTRY"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="WRD_FIRSTTRY_BRONZE", tierName="Bronze", target=1, xp=30, desc_de="Einmal im ersten Versuch.",  desc_en="First try once."  },
            { id="WRD_FIRSTTRY_SILBER", tierName="Silber", target=3, xp=55, desc_de="Dreimal im ersten Versuch.", desc_en="First try 3 times." },
            { id="WRD_FIRSTTRY_GOLD",   tierName="Gold",   target=7, xp=85, desc_de="Siebenmal im ersten Versuch!", desc_en="First try 7 times!" },
        },
    },

    {
        id="WRD_HARD", gameId="AZEROTHWORDS", category="WORT",
        title_de="Meister der Runen", title_en="Rune Master",
        desc_de="Gewinne auf Schwer.", desc_en="Win on Hard difficulty.",
        icon=136206, -- Spell_Shadow_ShadowWordDominate
        condition = function(data, db)
            if data.gameId ~= "AZEROTHWORDS" or data.result ~= "WIN" then return 0 end
            local entry = db.leaderboard and db.leaderboard["AZEROTHWORDS"]
            local h = entry and (entry["hard"] or entry["HARD"]) or {}
            return h.wins or 0
        end,
        tiers = {
            { id="WRD_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Gewinne 1x auf Schwer.",   desc_en="Win 1 on Hard."   },
            { id="WRD_HARD_SILBER", tierName="Silber", target=10, xp=50, desc_de="Gewinne 10x auf Schwer.",  desc_en="Win 10 on Hard."  },
            { id="WRD_HARD_GOLD",   tierName="Gold",   target=25, xp=80, desc_de="Gewinne 25x auf Schwer!",  desc_en="Win 25 on Hard!"  },
        },
    },
})
