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

    -- BJ_PROFIT: kumulativer Win-Zähler via Leaderboard
    {
        id="BJ_PROFIT", gameId="BLACKJACK", category="KARTEN",
        title_de="Im Gewinn", title_en="In Profit",
        desc_de="Erziele Gewinne in Blackjack.", desc_en="Achieve profits in Blackjack.",
        icon="Interface\\Icons\\INV_Misc_Coin_01",
        condition = function(data, db)
            if data.gameId ~= "BLACKJACK" then return 0 end
            return getTotalWins(db, "BLACKJACK")
        end,
        tiers = {
            { id="BJ_PROFIT_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Gewinne 1x.",   desc_en="Win once."        },
            { id="BJ_PROFIT_SILBER", tierName="Silber", target=5,  xp=30, desc_de="Gewinne 5x.",   desc_en="Win five times."  },
            { id="BJ_PROFIT_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="Gewinne 15x!",  desc_en="Win 15 times!"    },
        },
    },

    -- BJ_HIGHROLLER: gestaffelte Chip-Schwelle (3 Stufen 1/2/3)
    {
        id="BJ_HIGHROLLER", gameId="BLACKJACK", category="KARTEN",
        title_de="Hochstapler", title_en="High Roller",
        desc_de="Erreiche ein hohes Kapital.", desc_en="Reach a high capital.",
        icon="Interface\\Icons\\INV_Misc_Coin_04",
        condition = function(data, db)
            if data.gameId ~= "BLACKJACK" then return 0 end
            local chips = data.stats and data.stats.finalChips or 0
            if chips >= 1000 then return 3 end
            if chips >= 500  then return 2 end
            if chips >= 300  then return 1 end
            return 0
        end,
        tiers = {
            { id="BJ_HIGHROLLER_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="300 Gold erreicht.",  desc_en="Reach 300 Gold."  },
            { id="BJ_HIGHROLLER_SILBER", tierName="Silber", target=2, xp=50, desc_de="500 Gold erreicht.",  desc_en="Reach 500 Gold."  },
            { id="BJ_HIGHROLLER_GOLD",   tierName="Gold",   target=3, xp=90, desc_de="1000 Gold erreicht!", desc_en="Reach 1000 Gold!" },
        },
    },

    -- BJ_BLACKJACK: Zähler aus GameState (Engine trackt gs.blackjacks)
    {
        id="BJ_BLACKJACK", gameId="BLACKJACK", category="KARTEN",
        title_de="Schwarzer Bube", title_en="Natural",
        desc_de="Erziele Blackjacks.", desc_en="Get Blackjacks.",
        icon=237168, -- INV_Inscription_TarotLords
        condition = function(data, db)
            if data.gameId ~= "BLACKJACK" or not data.stats then return 0 end
            local sessionBJ = data.stats.blackjacks or 0
            if sessionBJ <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["BJ_BLACKJACK"]
            return (prog and prog.current or 0) + sessionBJ
        end,
        tiers = {
            { id="BJ_BLACKJACK_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="1 Blackjack.",   desc_en="Get 1 Blackjack."   },
            { id="BJ_BLACKJACK_SILBER", tierName="Silber", target=5,  xp=40, desc_de="5 Blackjacks.",  desc_en="Get 5 Blackjacks."  },
            { id="BJ_BLACKJACK_GOLD",   tierName="Gold",   target=15, xp=75, desc_de="15 Blackjacks!", desc_en="Get 15 Blackjacks!" },
        },
    },

    -- BJ_SURVIVOR: stats.finalChips jetzt in beiden Pfaden vorhanden
    {
        id="BJ_SURVIVOR", gameId="BLACKJACK", category="KARTEN",
        title_de="Durchhalter", title_en="Survivor",
        desc_de="Spiele auf Schwer und beende mit mehr als 100 Gold.", desc_en="Play on Hard and finish with over 100 Gold.",
        icon="Interface\\Icons\\INV_Misc_Dice_01",
        condition = function(data, db)
            if data.gameId ~= "BLACKJACK" then return 0 end
            if data.difficulty ~= "hard"  then return 0 end
            local chips = data.stats and data.stats.finalChips or 0
            return chips > 100 and 1 or 0
        end,
        tiers = {
            { id="BJ_SURVIVOR_GOLD", tierName="Gold", target=1, xp=80, desc_de="Schwer: über 100 Gold.", desc_en="Hard: over 100 Gold." },
        },
    },

})
