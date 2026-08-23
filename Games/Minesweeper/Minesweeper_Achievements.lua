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
        id="MS_WINS", gameId="MINESWEEPER", category="DENKSPIELE",
        title_de="Minensuchboot", title_en="Minesweeper",
        desc_de="Räume Minenfelder.", desc_en="Clear minefields.",
        icon=133009, -- INV_Gizmo_FelIronBomb
        condition = function(data, db)
            if data.gameId ~= "MINESWEEPER" then return 0 end
            return getTotalWins(db, "MINESWEEPER")
        end,
        tiers = {
            { id="MS_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Räume 5 Felder.",  desc_en="Clear 5 fields."  },
            { id="MS_WINS_SILBER", tierName="Silber", target=20, xp=30, desc_de="Räume 20 Felder.", desc_en="Clear 20 fields." },
            { id="MS_WINS_GOLD",   tierName="Gold",   target=50, xp=55, desc_de="Räume 50 Felder.", desc_en="Clear 50 fields." },
        },
    },

    {
        id="MS_HARD", gameId="MINESWEEPER", category="DENKSPIELE",
        title_de="Bombensicher", title_en="Bomb Proof",
        desc_de="Räume das schwere Minenfeld.", desc_en="Clear the hard minefield.",
        icon="Interface\\Icons\\INV_Misc_Bomb_05",
        condition = function(data, db)
            if data.gameId ~= "MINESWEEPER" or data.result ~= "WIN" then return 0 end
            local entry = db.leaderboard and db.leaderboard["MINESWEEPER"]
            local h = entry and (entry["hard"] or entry["HARD"]) or {}
            return h.wins or 0
        end,
        tiers = {
            { id="MS_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Einmal auf Schwer.",   desc_en="Clear hard once."    },
            { id="MS_HARD_SILBER", tierName="Silber", target=5,  xp=45, desc_de="Fünfmal auf Schwer.",  desc_en="Clear hard 5 times." },
            { id="MS_HARD_GOLD",   tierName="Gold",   target=20, xp=70, desc_de="Zwanzigmal auf Schwer!", desc_en="Clear hard 20 times!" },
        },
    },
})
