--[[
    ArcadiaNexus
    Games/WhackAMole/WhackAMole_Achievements.lua
    Achievements fuer WhackAMole (Kategorie: GESCHICK)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    {
        id       = "WAM_HITS",
        gameId   = "WHACKAMOLE",
        category = "GESCHICK",
        title_de = "Maulwurfjäger",
        title_en = "Mole Hunter",
        desc_de  = "Treffe Maulwürfe in Whack-a-Mole.",
        desc_en  = "Hit moles in Whack-a-Mole.",
        icon     = "Interface\\Icons\\Ability_Warrior_ShieldBash",
        condition = function(data, db)
            if data.gameId ~= "WHACKAMOLE" then return 0 end
            local hits = data.stats and data.stats.hitCount or 0
            if hits <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["WAM_HITS"]
            return (prog and prog.current or 0) + hits
        end,
        tiers = {
            { id="WAM_HITS_BRONZE", tierName="Bronze", target=20,  xp=15, desc_de="Treffe 20 Maulwürfe.",  desc_en="Hit 20 moles."  },
            { id="WAM_HITS_SILBER", tierName="Silber", target=60,  xp=30, desc_de="Treffe 60 Maulwürfe.",  desc_en="Hit 60 moles."  },
            { id="WAM_HITS_GOLD",   tierName="Gold",   target=150, xp=55, desc_de="Treffe 150 Maulwürfe!", desc_en="Hit 150 moles!" },
        },
    },

    {
        id       = "WAM_SCORE",
        gameId   = "WHACKAMOLE",
        category = "GESCHICK",
        title_de = "Hammerhand",
        title_en = "Hammer Hand",
        desc_de  = "Erziele hohe Punktzahlen in Whack-a-Mole.",
        desc_en  = "Score high in Whack-a-Mole.",
        icon     = "Interface\\Icons\\INV_Hammer_14",
        condition = function(data, db)
            if data.gameId ~= "WHACKAMOLE" then return 0 end
            local score = data.score or 0
            if score >= 500  then return 3 end
            if score >= 200  then return 2 end
            if score >= 80   then return 1 end
            return 0
        end,
        tiers = {
            { id="WAM_SCORE_BRONZE", tierName="Bronze", target=1, xp=15, desc_de="Erziele 80 Punkte.",  desc_en="Score 80 points."  },
            { id="WAM_SCORE_SILBER", tierName="Silber", target=2, xp=35, desc_de="Erziele 200 Punkte.", desc_en="Score 200 points." },
            { id="WAM_SCORE_GOLD",   tierName="Gold",   target=3, xp=60, desc_de="Erziele 500 Punkte!", desc_en="Score 500 points!" },
        },
    },
})
