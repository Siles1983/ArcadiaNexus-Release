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
        id="CHE_WINS", gameId="CHESS", category="DENKSPIELE",
        title_de="Schachmeister", title_en="Chess Master",
        desc_de="Gewinne Schachpartien.", desc_en="Win chess matches.",
        icon=134471, -- INV_Misc_SymbolOfKings_01
        condition = function(data, db)
            if data.gameId ~= "CHESS" then return 0 end
            return getTotalWins(db, "CHESS")
        end,
        tiers = {
            { id="CHE_WINS_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="Gewinne 5x.",  desc_en="Win 5 matches."  },
            { id="CHE_WINS_SILBER", tierName="Silber", target=20, xp=40, desc_de="Gewinne 20x.", desc_en="Win 20 matches." },
            { id="CHE_WINS_GOLD",   tierName="Gold",   target=50, xp=70, desc_de="Gewinne 50x.", desc_en="Win 50 matches." },
        },
    },

    {
        id="CHE_QUICK", gameId="CHESS", category="DENKSPIELE",
        title_de="Blitzschach", title_en="Lightning Chess",
        desc_de="Gewinne in wenigen Zügen.", desc_en="Win in few moves.",
        icon="Interface\\Icons\\Ability_Rogue_Sprint",
        condition = function(data, db)
            if data.gameId ~= "CHESS" or data.result ~= "WIN" then return 0 end
            local moves = data.stats and data.stats.moveCount or 999
            if moves <= 8  then return 3 end
            if moves <= 12 then return 2 end
            if moves <= 20 then return 1 end
            return 0
        end,
        tiers = {
            { id="CHE_QUICK_BRONZE", tierName="Bronze", target=1, xp=25, desc_de="Sieg in max. 20 Zügen.", desc_en="Win in at most 20 moves." },
            { id="CHE_QUICK_SILBER", tierName="Silber", target=2, xp=45, desc_de="Sieg in max. 12 Zügen.", desc_en="Win in at most 12 moves." },
            { id="CHE_QUICK_GOLD",   tierName="Gold",   target=3, xp=70, desc_de="Sieg in max. 8 Zügen!",  desc_en="Win in at most 8 moves!"  },
        },
    },
})
