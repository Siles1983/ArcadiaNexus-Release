--[[
    ArcadiaNexus / Games/ArcadiaRows/ArcadiaRows_Achievements.lua
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
        id="AR_WINS", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Vier im Sturm", title_en="Four in a Storm",
        desc_de="Gewinne Spiele in Arcadia Rows.", desc_en="Win games of Arcadia Rows.",
        icon="Interface\\Icons\\INV_Misc_Gem_Topaz_01",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" then return 0 end
            return getTotalWins(db, "ARCADIAROWS")
        end,
        tiers = {
            { id="AR_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="AR_WINS_SILBER", tierName="Silber", target=25, xp=30, desc_de="Gewinne 25x.", desc_en="Win 25 games." },
            { id="AR_WINS_GOLD",   tierName="Gold",   target=75, xp=55, desc_de="Gewinne 75x.", desc_en="Win 75 games." },
        },
    },

    {
        id="AR_QUICK", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Blitzverbindung", title_en="Lightning Connect",
        desc_de="Gewinne in wenigen Zügen.", desc_en="Win in few moves.",
        icon="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" or data.result ~= "WIN" then return 0 end
            local moves = data.stats and data.stats.moveCount or 999
            if moves <= 7  then return 3 end
            if moves <= 12 then return 2 end
            if moves <= 18 then return 1 end
            return 0
        end,
        tiers = {
            { id="AR_QUICK_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Sieg in max. 18 Zügen.", desc_en="Win in at most 18 moves." },
            { id="AR_QUICK_SILBER", tierName="Silber", target=2, xp=35, desc_de="Sieg in max. 12 Zügen.", desc_en="Win in at most 12 moves." },
            { id="AR_QUICK_GOLD",   tierName="Gold",   target=3, xp=55, desc_de="Sieg in max. 7 Zügen!",  desc_en="Win in at most 7 moves!"  },
        },
    },
})
