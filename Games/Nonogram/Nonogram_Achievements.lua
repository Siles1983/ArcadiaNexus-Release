--[[
    ArcadiaNexus
    Games/Nonogram/Nonogram_Achievements.lua
    Achievements fuer Nonogram (Kategorie: RAETSEL)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
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

ArcadiaNexus.RegisterAchievements({

    {
        id       = "NON_WINS",
        gameId   = "NONOGRAM",
        category = "RAETSEL",
        title_de = "Pixel-Meister",
        title_en = "Pixel Master",
        desc_de  = "Löse Nonogram-Puzzles.",
        desc_en  = "Solve Nonogram puzzles.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
        condition = function(data, db)
            if data.gameId ~= "NONOGRAM" then return 0 end
            if data._retroactive then return getTotalWins(db, "NONOGRAM") end
            return getTotalWins(db, "NONOGRAM")
        end,
        tiers = {
            { id="NON_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Löse 5 Puzzles.",   desc_en="Solve 5 puzzles."   },
            { id="NON_WINS_SILBER", tierName="Silber", target=25, xp=35, desc_de="Löse 25 Puzzles.",  desc_en="Solve 25 puzzles."  },
            { id="NON_WINS_GOLD",   tierName="Gold",   target=75, xp=60, desc_de="Löse 75 Puzzles!",  desc_en="Solve 75 puzzles!"  },
        },
    },

    {
        id       = "NON_HARD",
        gameId   = "NONOGRAM",
        category = "RAETSEL",
        title_de = "Schwert des Pixels",
        title_en = "Pixel Blade",
        desc_de  = "Löse Nonogram-Puzzles auf Schwer.",
        desc_en  = "Solve hard Nonogram puzzles.",
        icon     = "Interface\\Icons\\INV_Sword_04",
        condition = function(data, db)
            if data.gameId ~= "NONOGRAM" then return 0 end
            if data._retroactive then
                local entry = db.leaderboard and db.leaderboard["NONOGRAM"]
                local h = entry and (entry["hard"] or entry["HARD"]) or {}
                return h.wins or 0
            end
            if data.result == "WIN" and (data.difficulty == "hard" or data.difficulty == "HARD") then
                local entry = db.leaderboard and db.leaderboard["NONOGRAM"]
                local h = entry and (entry["hard"] or entry["HARD"]) or {}
                return h.wins or 0
            end
            return 0
        end,
        tiers = {
            { id="NON_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Löse 1 schweres Puzzle.",   desc_en="Solve 1 hard puzzle."   },
            { id="NON_HARD_SILBER", tierName="Silber", target=10, xp=50, desc_de="Löse 10 schwere Puzzles.",  desc_en="Solve 10 hard puzzles."  },
            { id="NON_HARD_GOLD",   tierName="Gold",   target=30, xp=80, desc_de="Löse 30 schwere Puzzles!",  desc_en="Solve 30 hard puzzles!"  },
        },
    },

    {
        id       = "NON_STRICT",
        gameId   = "NONOGRAM",
        category = "RAETSEL",
        title_de = "Kein Pardon",
        title_en = "No Mercy",
        desc_de  = "Gewinne im Strikten Modus.",
        desc_en  = "Win in Strict Mode.",
        icon     = 136206, -- Spell_Shadow_ShadowWordDominate
        condition = function(data, db)
            if data.gameId ~= "NONOGRAM" or data.result ~= "WIN" then return 0 end
            if data.stats and data.stats.mode ~= "strict" then return 0 end
            -- Eigener kumulativer Zähler — nicht getTotalWins (der zählt alle Modi)
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["NON_STRICT"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="NON_STRICT_BRONZE", tierName="Bronze", target=1,  xp=30, desc_de="Gewinne 1x im Strikten Modus.",   desc_en="Win 1x in Strict Mode."   },
            { id="NON_STRICT_SILBER", tierName="Silber", target=10, xp=55, desc_de="Gewinne 10x im Strikten Modus.",  desc_en="Win 10x in Strict Mode."  },
            { id="NON_STRICT_GOLD",   tierName="Gold",   target=30, xp=85, desc_de="Gewinne 30x im Strikten Modus!",  desc_en="Win 30x in Strict Mode!"  },
        },
    },

    {
        id       = "NON_SCORE",
        gameId   = "NONOGRAM",
        category = "RAETSEL",
        title_de = "Pixel-Arkane",
        title_en = "Pixel Arcane",
        desc_de  = "Erziele hohe Punktzahlen in Nonogram.",
        desc_en  = "Achieve high scores in Nonogram.",
        icon     = 135869, -- Spell_Holy_ArcaneIntellect
        condition = function(data, db)
            if data.gameId ~= "NONOGRAM" or data.result ~= "WIN" then return 0 end
            local score = data.score or 0
            if score >= 1200 then return 3 end
            if score >= 500  then return 2 end
            if score >= 200  then return 1 end
            return 0
        end,
        tiers = {
            { id="NON_SCORE_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Erziele 200 Punkte.",    desc_en="Score 200 points."    },
            { id="NON_SCORE_SILBER", tierName="Silber", target=2, xp=45, desc_de="Erziele 500 Punkte.",    desc_en="Score 500 points."    },
            { id="NON_SCORE_GOLD",   tierName="Gold",   target=3, xp=75, desc_de="Erziele 1.200 Punkte!",  desc_en="Score 1,200 points!"  },
        },
    },
})
