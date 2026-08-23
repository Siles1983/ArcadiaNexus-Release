-- ============================================================
--  ShellGame – ShellGame_Achievements.lua
-- ============================================================

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

    -- SHG_PROFIT: Gewinn-Zähler
    {
        id="SHG_PROFIT", gameId="SHELLGAME", category="GESCHICK",
        title_de="Scharfe Augen", title_en="Sharp Eyes",
        desc_de="Gewinne Runden im Gadgetzan Cup Shuffle.", desc_en="Win rounds in Gadgetzan Cup Shuffle.",
        icon="Interface\\Icons\\INV_Misc_Gem_Ruby_01",
        condition = function(data, db)
            if data.gameId ~= "SHELLGAME" then return 0 end
            return getTotalWins(db, "SHELLGAME")
        end,
        tiers = {
            { id="SHG_PROFIT_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Gewinne 1x.",   desc_en="Win once."       },
            { id="SHG_PROFIT_SILBER", tierName="Silber", target=10, xp=30, desc_de="Gewinne 10x.",  desc_en="Win 10 times."   },
            { id="SHG_PROFIT_GOLD",   tierName="Gold",   target=25, xp=60, desc_de="Gewinne 25x!",  desc_en="Win 25 times!"   },
        },
    },

    -- SHG_HIGHROLLER: Kapital-Schwelle
    {
        id="SHG_HIGHROLLER", gameId="SHELLGAME", category="GESCHICK",
        title_de="Hochstapler", title_en="High Roller",
        desc_de="Erreiche ein hohes Kapital.", desc_en="Reach a high capital.",
        icon="Interface\\Icons\\INV_Misc_Coin_04",
        condition = function(data, db)
            if data.gameId ~= "SHELLGAME" then return 0 end
            local chips = data.stats and data.stats.finalChips or 0
            if chips >= 1000 then return 3 end
            if chips >= 500  then return 2 end
            if chips >= 300  then return 1 end
            return 0
        end,
        tiers = {
            { id="SHG_HIGHROLLER_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="300 Gold erreicht.",  desc_en="Reach 300 Gold."  },
            { id="SHG_HIGHROLLER_SILBER", tierName="Silber", target=2, xp=50, desc_de="500 Gold erreicht.",  desc_en="Reach 500 Gold."  },
            { id="SHG_HIGHROLLER_GOLD",   tierName="Gold",   target=3, xp=90, desc_de="1000 Gold erreicht!", desc_en="Reach 1000 Gold!" },
        },
    },

    -- SHG_HARD_WIN: Auf Schwer gewinnen
    {
        id="SHG_HARD_WIN", gameId="SHELLGAME", category="GESCHICK",
        title_de="Flinke Finger", title_en="Quick Hands",
        desc_de="Beende Schwer mit Gewinn.", desc_en="Finish Hard mode in profit.",
        icon="Interface\\Icons\\INV_Misc_Dice_01",
        condition = function(data, db)
            if data.gameId ~= "SHELLGAME" then return 0 end
            if data.difficulty ~= "hard"  then return 0 end
            local chips = data.stats and data.stats.finalChips or 0
            return chips > 100 and 1 or 0
        end,
        tiers = {
            { id="SHG_HARD_WIN_GOLD", tierName="Gold", target=1, xp=80, desc_de="Schwer: über 100 Gold.", desc_en="Hard: over 100 Gold." },
        },
    },

    -- SHG_SURVIVOR: Viele Runden gespielt
    {
        id="SHG_SURVIVOR", gameId="SHELLGAME", category="GESCHICK",
        title_de="Ausdauer", title_en="Endurance",
        desc_de="Spiele viele Runden Gadgetzan Cup Shuffle.", desc_en="Play many rounds of Gadgetzan Cup Shuffle.",
        icon="Interface\\Icons\\INV_Misc_Dice_02",
        condition = function(data, db)
            if data.gameId ~= "SHELLGAME" or not data.stats then return 0 end
            local sessionRounds = data.stats.roundsPlayed or 0
            if sessionRounds <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                and db.achievements.progress["SHG_SURVIVOR"]
            return (prog and prog.current or 0) + sessionRounds
        end,
        tiers = {
            { id="SHG_SURVIVOR_BRONZE", tierName="Bronze", target=10,  xp=15, desc_de="10 Runden gespielt.",  desc_en="Play 10 rounds."  },
            { id="SHG_SURVIVOR_SILBER", tierName="Silber", target=50,  xp=35, desc_de="50 Runden gespielt.",  desc_en="Play 50 rounds."  },
            { id="SHG_SURVIVOR_GOLD",   tierName="Gold",   target=100, xp=70, desc_de="100 Runden gespielt!", desc_en="Play 100 rounds!" },
        },
    },

})
