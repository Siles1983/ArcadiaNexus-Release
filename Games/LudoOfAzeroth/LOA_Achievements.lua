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
        id = "LOA_WINS", gameId = "LOA", category = "STRATEGIE",
        title_de = "Brettspielkönig", title_en = "Board Game King",
        desc_de = "Gewinne Ludo-of-Azeroth-Spiele.", desc_en = "Win Ludo of Azeroth games.",
        icon = "Interface\\Icons\\INV_Misc_Dice_01",
        condition = function(data, db)
            if data.gameId ~= "LOA" then return 0 end
            return getTotalWins(db, "LOA")
        end,
        tiers = {
            { id = "LOA_WINS_BRONZE", tierName = "Bronze", target = 3,  xp = 15, desc_de = "Gewinne 3x.",  desc_en = "Win 3 games."  },
            { id = "LOA_WINS_SILVER", tierName = "Silber", target = 10, xp = 30, desc_de = "Gewinne 10x.", desc_en = "Win 10 games." },
            { id = "LOA_WINS_GOLD",   tierName = "Gold",   target = 30, xp = 55, desc_de = "Gewinne 30x.", desc_en = "Win 30 games." },
        },
    },

    {
        id = "LOA_CLEAN", gameId = "LOA", category = "STRATEGIE",
        title_de = "Heimholer", title_en = "Home Bringer",
        desc_de = "Bring alle 4 Figuren ins Ziel.", desc_en = "Bring all 4 pieces home.",
        icon = "Interface\\Icons\\Ability_Mount_Mammoth_White",
        condition = function(data, db)
            if data.gameId ~= "LOA" or data.result ~= "WIN" then return 0 end
            if (data.stats and data.stats.figuresHome or 0) < 4 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["LOA_CLEAN"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id = "LOA_CLEAN_BRONZE", tierName = "Bronze", target = 1, xp = 20, desc_de = "Einmal alle 4 ins Ziel.",  desc_en = "All 4 home once."      },
            { id = "LOA_CLEAN_SILVER", tierName = "Silver", target = 3, xp = 40, desc_de = "Dreimal alle 4 ins Ziel.", desc_en = "All 4 home 3 times."   },
            { id = "LOA_CLEAN_GOLD",   tierName = "Gold",   target = 5, xp = 65, desc_de = "Fünfmal alle 4 ins Ziel!", desc_en = "All 4 home 5 times!"   },
        },
    },
})
