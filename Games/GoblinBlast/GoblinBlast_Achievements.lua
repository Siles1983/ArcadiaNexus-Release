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
        id="GB_WINS", gameId="GOBLINBLAST", category="ARCADE",
        title_de="Sprengmeister", title_en="Demolition Expert",
        desc_de="Gewinne Goblin Blast-Runden.", desc_en="Win Goblin Blast rounds.",
        icon="Interface\\Icons\\INV_Misc_Bomb_02",
        condition = function(data, db)
            if data.gameId ~= "GOBLINBLAST" then return 0 end
            return getTotalWins(db, "GOBLINBLAST")
        end,
        tiers = {
            { id="GB_WINS_BRONZE", tierName="Bronze", target=3,  xp=15, desc_de="Gewinne 3x.",  desc_en="Win 3 rounds."  },
            { id="GB_WINS_SILBER", tierName="Silber", target=10, xp=30, desc_de="Gewinne 10x.", desc_en="Win 10 rounds." },
            { id="GB_WINS_GOLD",   tierName="Gold",   target=30, xp=55, desc_de="Gewinne 30x.", desc_en="Win 30 rounds." },
        },
    },

    {
        id="GB_WALLS", gameId="GOBLINBLAST", category="ARCADE",
        title_de="Abrissbirne", title_en="Wrecking Ball",
        desc_de="Zerstöre viele Wände in einem Durchlauf.", desc_en="Destroy many walls in a single run.",
        icon="Interface\\Icons\\INV_Misc_StoneTablet_05",
        condition = function(data, db)
            if data.gameId ~= "GOBLINBLAST" then return 0 end
            return data.stats and data.stats.walls or 0
        end,
        tiers = {
            { id="GB_WALLS_BRONZE", tierName="Bronze", target=25,  xp=15, desc_de="25 Wände in einem Durchlauf.",  desc_en="25 walls in one run."  },
            { id="GB_WALLS_SILBER", tierName="Silber", target=75,  xp=35, desc_de="75 Wände in einem Durchlauf.",  desc_en="75 walls in one run."  },
            { id="GB_WALLS_GOLD",   tierName="Gold",   target=150, xp=60, desc_de="150 Wände in einem Durchlauf!", desc_en="150 walls in one run!" },
        },
    },

    {
        id="GB_LEVEL", gameId="GOBLINBLAST", category="ARCADE",
        title_de="Levelstürmer", title_en="Level Crusher",
        desc_de="Erreiche hohe Level in einem Durchlauf.", desc_en="Reach high levels in a single run.",
        icon="Interface\\Icons\\INV_Misc_Bomb_04",
        condition = function(data, db)
            if data.gameId ~= "GOBLINBLAST" then return 0 end
            return data.stats and data.stats.levelReached or 0
        end,
        tiers = {
            { id="GB_LEVEL_BRONZE", tierName="Bronze", target=4,  xp=20, desc_de="Schaffe Level 4.",   desc_en="Clear level 4."   },
            { id="GB_LEVEL_SILBER", tierName="Silber", target=8,  xp=40, desc_de="Schaffe Level 8.",   desc_en="Clear level 8."   },
            { id="GB_LEVEL_GOLD",   tierName="Gold",   target=12, xp=70, desc_de="Schaffe alle 12 Level!", desc_en="Clear all 12 levels!" },
        },
    },

    {
        id="GB_CHAIN", gameId="GOBLINBLAST", category="ARCADE",
        title_de="Kettenreaktion", title_en="Chain Reaction",
        desc_de="Zünde mehrere Bomben in einer einzigen Kettenreaktion.", desc_en="Ignite multiple bombs in a single chain reaction.",
        icon="Interface\\Icons\\Spell_Fire_SelfDestruct",
        condition = function(data, db)
            if data.gameId ~= "GOBLINBLAST" then return 0 end
            return data.stats and data.stats.maxChain or 0
        end,
        tiers = {
            { id="GB_CHAIN_BRONZE", tierName="Bronze", target=2, xp=20, desc_de="2er-Kette.", desc_en="Chain of 2." },
            { id="GB_CHAIN_SILBER", tierName="Silber", target=3, xp=40, desc_de="3er-Kette.", desc_en="Chain of 3." },
            { id="GB_CHAIN_GOLD",   tierName="Gold",   target=4, xp=60, desc_de="4er-Kette!", desc_en="Chain of 4!" },
        },
    },
})
