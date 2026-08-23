--[[
    ArcadiaNexus
    Games/Solitaire/Solitaire_Achievements.lua
    Achievements für Solitaire (Kategorie: KARTEN)
]]

local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalWins(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0)
    end
    return total
end

local function getTotalGames(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
    end
    return total
end

ArcadiaNexus.RegisterAchievements({

    -- SOL_FIRST_WIN: Kumulativer Win-Zähler (Bug-Klasse 2 behoben)
    {
        id       = "SOL_FIRST_WIN",
        gameId   = "SOLITAIRE",
        category = "KARTEN",
        title_de = "Kartenmeister",
        title_en = "Card Master",
        desc_de  = "Gewinne Solitaire-Spiele.",
        desc_en  = "Win Solitaire games.",
        icon     = 134493, -- INV_Misc_Ticket_Tarot_Stack_01
        condition = function(data, db)
            if data.gameId ~= "SOLITAIRE" then return 0 end
            return getTotalWins(db, "SOLITAIRE")
        end,
        tiers = {
            { id="SOL_FIRST_WIN_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Gewinne 1 Spiel.",   desc_en="Win 1 game."   },
            { id="SOL_FIRST_WIN_SILBER", tierName="Silber", target=5,  xp=30, desc_de="Gewinne 5 Spiele.",  desc_en="Win 5 games."  },
            { id="SOL_FIRST_WIN_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="Gewinne 15 Spiele!", desc_en="Win 15 games!" },
        },
    },

    -- SOL_WIN_1CARD: Kumulativer Zähler via leaderboard (Bug-Klasse 2 behoben)
    {
        id       = "SOL_WIN_1CARD",
        gameId   = "SOLITAIRE",
        category = "KARTEN",
        title_de = "Einzelkämpfer",
        title_en = "Solo Player",
        desc_de  = "Gewinne Spiele im 1-Karten-Modus.",
        desc_en  = "Win games in 1-card mode.",
        icon     = 134493, -- INV_Misc_Ticket_Tarot_Stack_01
        condition = function(data, db)
            if data.gameId ~= "SOLITAIRE" then return 0 end
            if data.result ~= "WIN"       then return 0 end
            if data.difficulty ~= "1card" then return 0 end
            local entry = db.leaderboard and db.leaderboard["SOLITAIRE"]
            local e = entry and (entry["1card"] or entry["1CARD"]) or {}
            return e.wins or 0
        end,
        tiers = {
            { id="SOL_WIN_1CARD_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Gewinne 1x.",   desc_en="Win 1 time."   },
            { id="SOL_WIN_1CARD_SILBER", tierName="Silber", target=5,  xp=35, desc_de="Gewinne 5x.",   desc_en="Win 5 times."  },
            { id="SOL_WIN_1CARD_GOLD",   tierName="Gold",   target=10, xp=70, desc_de="Gewinne 10x!",  desc_en="Win 10 times!" },
        },
    },

    -- SOL_WIN_3CARD: Kumulativer Zähler via leaderboard (Bug-Klasse 2 behoben)
    {
        id       = "SOL_WIN_3CARD",
        gameId   = "SOLITAIRE",
        category = "KARTEN",
        title_de = "Dreifach-Held",
        title_en = "Triple Hero",
        desc_de  = "Gewinne Spiele im 3-Karten-Modus.",
        desc_en  = "Win games in 3-card mode.",
        icon     = 237168, -- INV_Inscription_TarotLords
        condition = function(data, db)
            if data.gameId ~= "SOLITAIRE" then return 0 end
            if data.result ~= "WIN"       then return 0 end
            if data.difficulty ~= "3card" then return 0 end
            local entry = db.leaderboard and db.leaderboard["SOLITAIRE"]
            local e = entry and (entry["3card"] or entry["3CARD"]) or {}
            return e.wins or 0
        end,
        tiers = {
            { id="SOL_WIN_3CARD_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Gewinne 1x.",  desc_en="Win 1 time."  },
            { id="SOL_WIN_3CARD_SILBER", tierName="Silber", target=3, xp=50, desc_de="Gewinne 3x.",  desc_en="Win 3 times." },
            { id="SOL_WIN_3CARD_GOLD",   tierName="Gold",   target=7, xp=90, desc_de="Gewinne 7x!",  desc_en="Win 7 times!" },
        },
    },

    -- SOL_HIGHSCORE: Score-Schwellwerte — korrekt (kein Fix nötig)
    {
        id       = "SOL_HIGHSCORE",
        gameId   = "SOLITAIRE",
        category = "KARTEN",
        title_de = "Punktejäger",
        title_en = "Score Hunter",
        desc_de  = "Erreiche hohe Punktzahlen in einem Spiel.",
        desc_en  = "Reach high scores in a single game.",
        icon     = 236594, -- Achievement_PVP_A_H
        condition = function(data, db)
            if data.gameId ~= "SOLITAIRE" then return 0 end
            if data.result ~= "WIN"       then return 0 end
            return data.score or 0
        end,
        tiers = {
            { id="SOL_HIGHSCORE_BRONZE", tierName="Bronze", target=1000, xp=20, desc_de="Erreiche 1.000 Punkte.",  desc_en="Reach 1,000 points."  },
            { id="SOL_HIGHSCORE_SILBER", tierName="Silber", target=3000, xp=45, desc_de="Erreiche 3.000 Punkte.",  desc_en="Reach 3,000 points."  },
            { id="SOL_HIGHSCORE_GOLD",   tierName="Gold",   target=5000, xp=80, desc_de="Erreiche 5.000 Punkte!",  desc_en="Reach 5,000 points!"  },
        },
    },

    -- SOL_VETERAN: Kumulativer Spiel-Zähler (Bug-Klasse 7 behoben)
    {
        id       = "SOL_VETERAN",
        gameId   = "SOLITAIRE",
        category = "KARTEN",
        title_de = "Veteran",
        title_en = "Veteran",
        desc_de  = "Spiele viele Solitaire-Partien.",
        desc_en  = "Play many Solitaire games.",
        icon     = 236586, -- Achievement_PVP_A_10
        condition = function(data, db)
            if data.gameId ~= "SOLITAIRE" then return 0 end
            return getTotalGames(db, "SOLITAIRE")
        end,
        tiers = {
            { id="SOL_VETERAN_BRONZE", tierName="Bronze", target=10, xp=15, desc_de="Spiele 10 Partien.",  desc_en="Play 10 games."  },
            { id="SOL_VETERAN_SILBER", tierName="Silber", target=25, xp=30, desc_de="Spiele 25 Partien.",  desc_en="Play 25 games."  },
            { id="SOL_VETERAN_GOLD",   tierName="Gold",   target=50, xp=60, desc_de="Spiele 50 Partien!",  desc_en="Play 50 games!"  },
        },
    },

})
