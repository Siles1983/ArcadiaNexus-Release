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
        id="SDK_WINS", gameId="SUDOKU", category="DENKSPIELE",
        title_de="Zahlenweiser", title_en="Number Sage",
        desc_de="Löse Sudoku-Rätsel.", desc_en="Solve Sudoku puzzles.",
        icon="Interface\\Icons\\INV_Misc_Statue_02",
        condition = function(data, db)
            if data.gameId ~= "SUDOKU" then return 0 end
            return getTotalWins(db, "SUDOKU")
        end,
        tiers = {
            { id="SDK_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Löse 5 Sudokus.",  desc_en="Solve 5 Sudokus."  },
            { id="SDK_WINS_SILBER", tierName="Silber", target=20, xp=35, desc_de="Löse 20 Sudokus.", desc_en="Solve 20 Sudokus." },
            { id="SDK_WINS_GOLD",   tierName="Gold",   target=50, xp=60, desc_de="Löse 50 Sudokus.", desc_en="Solve 50 Sudokus." },
        },
    },

    {
        id="SDK_HARD", gameId="SUDOKU", category="DENKSPIELE",
        title_de="Sudoku-Meister", title_en="Sudoku Master",
        desc_de="Löse Sudokus auf Schwer.", desc_en="Solve Sudoku on Hard.",
        icon="Interface\\Icons\\Spell_Holy_GreaterHeal",
        condition = function(data, db)
            if data.gameId ~= "SUDOKU" or data.result ~= "WIN" then return 0 end
            local entry = db.leaderboard and db.leaderboard["SUDOKU"]
            local h = entry and (entry["hard"] or entry["HARD"]) or {}
            return h.wins or 0
        end,
        tiers = {
            { id="SDK_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Einmal auf Schwer.",    desc_en="Solve 1 on Hard."   },
            { id="SDK_HARD_SILBER", tierName="Silber", target=5,  xp=45, desc_de="Fünfmal auf Schwer.",   desc_en="Solve 5 on Hard."   },
            { id="SDK_HARD_GOLD",   tierName="Gold",   target=15, xp=70, desc_de="Fünfzehnmal auf Schwer!", desc_en="Solve 15 on Hard!" },
        },
    },
})
