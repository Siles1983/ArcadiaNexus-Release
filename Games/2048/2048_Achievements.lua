--[[
    ArcadiaNexus
    Games/2048/2048_Achievements.lua
    Achievements fuer 2048 (Kategorie: DENKSPIELE)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    {
        id       = "TDG_TILE",
        gameId   = "2048",
        category = "DENKSPIELE",
        title_de = "Zahlenkönig",
        title_en = "Number King",
        desc_de  = "Erreiche hohe Kachelwerte in 2048.",
        desc_en  = "Reach high tile values in 2048.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01",
        condition = function(data, db)
            if data.gameId ~= "2048" then return 0 end
            local tile = data.stats and data.stats.highestTile or 0
            if tile >= 2048 then return 3 end
            if tile >= 1024 then return 2 end
            if tile >= 512  then return 1 end
            return 0
        end,
        tiers = {
            { id="TDG_TILE_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Erreiche die 512-Kachel.",  desc_en="Reach the 512 tile."  },
            { id="TDG_TILE_SILBER", tierName="Silber", target=2, xp=40, desc_de="Erreiche die 1024-Kachel.", desc_en="Reach the 1024 tile." },
            { id="TDG_TILE_GOLD",   tierName="Gold",   target=3, xp=75, desc_de="Erreiche die 2048-Kachel!", desc_en="Reach the 2048 tile!" },
        },
    },

    {
        id       = "TDG_SCORE",
        gameId   = "2048",
        category = "DENKSPIELE",
        title_de = "Endlose Kombination",
        title_en = "Endless Combo",
        desc_de  = "Erziele hohe Punktzahlen in 2048.",
        desc_en  = "Achieve high scores in 2048.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
        condition = function(data, db)
            if data.gameId ~= "2048" then return 0 end
            local score = data.score or 0
            if score >= 20000 then return 3 end
            if score >= 8000  then return 2 end
            if score >= 2000  then return 1 end
            return 0
        end,
        tiers = {
            { id="TDG_SCORE_BRONZE", tierName="Bronze", target=1, xp=15, desc_de="Erziele 2.000 Punkte.",  desc_en="Score 2,000 points."  },
            { id="TDG_SCORE_SILBER", tierName="Silber", target=2, xp=35, desc_de="Erziele 8.000 Punkte.",  desc_en="Score 8,000 points."  },
            { id="TDG_SCORE_GOLD",   tierName="Gold",   target=3, xp=65, desc_de="Erziele 20.000 Punkte.", desc_en="Score 20,000 points." },
        },
    },
})
