--[[
    ArcadiaNexus
    Games/BlockBreaker/BlockBreaker_Achievements.lua
    Achievements fuer BlockBreaker (Kategorie: ARCADE)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    {
        id       = "BB_LEVEL",
        gameId   = "BLOCKBREAKER",
        category = "ARCADE",
        title_de = "Unaufhaltsam",
        title_en = "Unstoppable",
        desc_de  = "Erreiche hohe Level in BlockBreaker.",
        desc_en  = "Reach high levels in BlockBreaker.",
        icon     = "Interface\\Icons\\Ability_Warrior_Charge",
        condition = function(data, db)
            if data.gameId ~= "BLOCKBREAKER" then return 0 end
            local level = data.stats and data.stats.levelReached or 0
            return level
        end,
        tiers = {
            { id="BB_LEVEL_BRONZE", tierName="Bronze", target=10,  xp=20, desc_de="Erreiche Level 10.",  desc_en="Reach level 10."  },
            { id="BB_LEVEL_SILBER", tierName="Silber", target=50,  xp=45, desc_de="Erreiche Level 50.",  desc_en="Reach level 50."  },
            { id="BB_LEVEL_GOLD",   tierName="Gold",   target=100, xp=80, desc_de="Erreiche Level 100!", desc_en="Reach level 100!" },
        },
    },

    {
        id       = "BB_COMBO",
        gameId   = "BLOCKBREAKER",
        category = "ARCADE",
        title_de = "Kettenreaktion",
        title_en = "Chain Reaction",
        desc_de  = "Erziele hohe Combos in BlockBreaker.",
        desc_en  = "Achieve high combos in BlockBreaker.",
        icon     = 1029721, -- Ability_FoundryRaid_BlastWave
        condition = function(data, db)
            if data.gameId ~= "BLOCKBREAKER" then return 0 end
            local combo = data.stats and data.stats.maxCombo or 0
            return combo
        end,
        tiers = {
            { id="BB_COMBO_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="Erreiche Combo x5.",  desc_en="Reach combo x5."  },
            { id="BB_COMBO_SILBER", tierName="Silber", target=10, xp=40, desc_de="Erreiche Combo x10.", desc_en="Reach combo x10." },
            { id="BB_COMBO_GOLD",   tierName="Gold",   target=20, xp=65, desc_de="Erreiche Combo x20!", desc_en="Reach combo x20!" },
        },
    },
})
