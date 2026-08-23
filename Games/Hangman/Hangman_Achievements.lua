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
        id="HGM_WINS", gameId="HANGMAN", category="WORT",
        title_de="Buchstabenjäger", title_en="Letter Hunter",
        desc_de="Löse Wörter im Galgenmännchen.", desc_en="Solve words in Hangman.",
        icon="Interface\\Icons\\INV_Letter_17",
        condition = function(data, db)
            if data.gameId ~= "HANGMAN" then return 0 end
            return getTotalWins(db, "HANGMAN")
        end,
        tiers = {
            { id="HGM_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Löse 5 Wörter.",  desc_en="Solve 5 words."  },
            { id="HGM_WINS_SILBER", tierName="Silber", target=25, xp=30, desc_de="Löse 25 Wörter.", desc_en="Solve 25 words." },
            { id="HGM_WINS_GOLD",   tierName="Gold",   target=75, xp=55, desc_de="Löse 75 Wörter.", desc_en="Solve 75 words." },
        },
    },

    {
        id="HGM_PERFECT", gameId="HANGMAN", category="WORT",
        title_de="Unfehlbar", title_en="Infallible",
        desc_de="Löse Wörter ohne einen Fehler.", desc_en="Solve words without mistakes.",
        icon="Interface\\Icons\\Spell_Holy_SealOfRighteousness",
        condition = function(data, db)
            if data.gameId ~= "HANGMAN" or data.result ~= "WIN" then return 0 end
            if (data.stats and data.stats.errors or 999) ~= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["HGM_PERFECT"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="HGM_PERFECT_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Einmal ohne Fehler.",   desc_en="Solve 1 without mistakes."   },
            { id="HGM_PERFECT_SILBER", tierName="Silber", target=5,  xp=40, desc_de="Fünfmal ohne Fehler.",  desc_en="Solve 5 without mistakes."   },
            { id="HGM_PERFECT_GOLD",   tierName="Gold",   target=15, xp=65, desc_de="Fünfzehnmal ohne Fehler!", desc_en="Solve 15 without mistakes!" },
        },
    },
})
