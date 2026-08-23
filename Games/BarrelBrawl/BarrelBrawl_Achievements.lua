--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/BarrelBrawl_Achievements.lua
    Version: 1.0.0

    Datenquelle: GAME_RESULT-Payload der Engine
      stats.levelReached, stats.rescues, stats.barrelsJumped, score
    Siege (WIN = mind. eine Rettung im Durchlauf) via Leaderboard-DB.
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
        id="BRB_WINS", gameId="BARREL_BRAWL", category="ARCADE",
        title_de="Gnomenheld", title_en="Gnomish Hero",
        desc_de="Rette die Prinzessin in Barrel Brawl.", desc_en="Rescue the princess in Barrel Brawl.",
        icon="Interface\\Icons\\Achievement_Character_Gnome_Male",
        condition = function(data, db)
            if data.gameId ~= "BARREL_BRAWL" then return 0 end
            return getTotalWins(db, "BARREL_BRAWL")
        end,
        tiers = {
            { id="BRB_WINS_BRONZE", tierName="Bronze", target=3,  xp=15, desc_de="3 erfolgreiche Durchläufe.",  desc_en="3 successful runs."  },
            { id="BRB_WINS_SILBER", tierName="Silber", target=10, xp=30, desc_de="10 erfolgreiche Durchläufe.", desc_en="10 successful runs." },
            { id="BRB_WINS_GOLD",   tierName="Gold",   target=30, xp=55, desc_de="30 erfolgreiche Durchläufe.", desc_en="30 successful runs." },
        },
    },

    {
        id="BRB_LEVEL", gameId="BARREL_BRAWL", category="ARCADE",
        title_de="Turmstürmer", title_en="Tower Climber",
        desc_de="Erreiche hohe Level in einem Durchlauf.", desc_en="Reach high levels in a single run.",
        icon="Interface\\Icons\\INV_Ammo_FireTar",
        condition = function(data, db)
            if data.gameId ~= "BARREL_BRAWL" then return 0 end
            return data.stats and data.stats.levelReached or 0
        end,
        tiers = {
            { id="BRB_LEVEL_BRONZE", tierName="Bronze", target=3,  xp=20, desc_de="Erreiche Level 3.",  desc_en="Reach level 3."  },
            { id="BRB_LEVEL_SILBER", tierName="Silber", target=6,  xp=40, desc_de="Erreiche Level 6.",  desc_en="Reach level 6."  },
            { id="BRB_LEVEL_GOLD",   tierName="Gold",   target=10, xp=70, desc_de="Erreiche Level 10!", desc_en="Reach level 10!" },
        },
    },

    {
        id="BRB_JUMPED", gameId="BARREL_BRAWL", category="ARCADE",
        title_de="Fass-Hüpfer", title_en="Barrel Hopper",
        desc_de="Überspringe viele Fässer in einem Durchlauf.", desc_en="Jump over many barrels in a single run.",
        icon="Interface\\Icons\\Ability_Rogue_Sprint",
        condition = function(data, db)
            if data.gameId ~= "BARREL_BRAWL" then return 0 end
            return data.stats and data.stats.barrelsJumped or 0
        end,
        tiers = {
            { id="BRB_JUMPED_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="5 Fässer in einem Durchlauf.",  desc_en="5 barrels in one run."  },
            { id="BRB_JUMPED_SILBER", tierName="Silber", target=15, xp=35, desc_de="15 Fässer in einem Durchlauf.", desc_en="15 barrels in one run." },
            { id="BRB_JUMPED_GOLD",   tierName="Gold",   target=30, xp=60, desc_de="30 Fässer in einem Durchlauf!", desc_en="30 barrels in one run!" },
        },
    },

    {
        id="BRB_SCORE", gameId="BARREL_BRAWL", category="ARCADE",
        title_de="Bonusjäger", title_en="Bonus Hunter",
        desc_de="Erziele hohe Scores in einem Durchlauf.", desc_en="Achieve high scores in a single run.",
        icon="Interface\\Icons\\INV_Misc_Coin_02",
        condition = function(data, db)
            if data.gameId ~= "BARREL_BRAWL" then return 0 end
            return data.score or 0
        end,
        tiers = {
            { id="BRB_SCORE_BRONZE", tierName="Bronze", target=5000,  xp=20, desc_de="5.000 Punkte.",  desc_en="5,000 points."  },
            { id="BRB_SCORE_SILBER", tierName="Silber", target=15000, xp=40, desc_de="15.000 Punkte.", desc_en="15,000 points." },
            { id="BRB_SCORE_GOLD",   tierName="Gold",   target=30000, xp=65, desc_de="30.000 Punkte!", desc_en="30,000 points!" },
        },
    },
})
