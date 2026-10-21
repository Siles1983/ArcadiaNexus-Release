--[[
    ArcadiaNexus
    Games/ShadowsConquest/ShadowsConquest_Achievements.lua
    Achievements fuer ShadowsConquest (Kategorie: RAETSEL)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
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
        id       = "SC_WINS",
        gameId   = "SHADOWSCONQUEST",
        category = "RAETSEL",
        title_de = "Lichtermeister",
        title_en = "Lights Master",
        desc_de  = "Löse Shadows-Conquest-Rätsel.",
        desc_en  = "Solve Shadows Conquest puzzles.",
        icon     = "Interface\\Icons\\Spell_Holy_HolyBolt",
        condition = function(data, db)
            if data.gameId ~= "SHADOWSCONQUEST" then return 0 end
            return getTotalWins(db, "SHADOWSCONQUEST")
        end,
        tiers = {
            { id="SC_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Löse 5 Rätsel.",   desc_en="Solve 5 puzzles."   },
            { id="SC_WINS_SILBER", tierName="Silber", target=25, xp=35, desc_de="Löse 25 Rätsel.",  desc_en="Solve 25 puzzles."  },
            { id="SC_WINS_GOLD",   tierName="Gold",   target=75, xp=60, desc_de="Löse 75 Rätsel!",  desc_en="Solve 75 puzzles!"  },
        },
    },

    {
        id       = "SC_HARD",
        gameId   = "SHADOWSCONQUEST",
        category = "RAETSEL",
        title_de = "Dunkelkammer",
        title_en = "Dark Chamber",
        desc_de  = "Löse schwere Shadows-Conquest-Rätsel.",
        desc_en  = "Solve hard Shadows Conquest puzzles.",
        icon     = 136206, -- Spell_Shadow_ShadowWordDominate
        condition = function(data, db)
            if data.gameId ~= "SHADOWSCONQUEST" then return 0 end
            local entries=db.leaderboard and db.leaderboard.SHADOWSCONQUEST or {}
            local total=0
            for _,key in ipairs({'hard','HARD','v2_free_hard','v2_limit_hard'}) do total=total+((entries[key] or {}).wins or 0) end
            return total
        end,
        tiers = {
            { id="SC_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Löse 1 schweres Rätsel.",   desc_en="Solve 1 hard puzzle."    },
            { id="SC_HARD_SILBER", tierName="Silber", target=10, xp=50, desc_de="Löse 10 schwere Rätsel.",  desc_en="Solve 10 hard puzzles."  },
            { id="SC_HARD_GOLD",   tierName="Gold",   target=30, xp=80, desc_de="Löse 30 schwere Rätsel!",  desc_en="Solve 30 hard puzzles!"  },
        },
    },

    {
        id       = "SC_SCORE",
        retired=true, retiredVersion=6, gameLabel="Shadows Conquest",
        retiredReason_de="Die ursprüngliche Punkteformel wurde durch die M7-Leistungswertung ersetzt.",
        retiredReason_en="The original score formula was replaced by the M7 performance rating.",
        gameId   = "SHADOWSCONQUEST",
        category = "RAETSEL",
        title_de = "Arkaner Lichtbogen",
        title_en = "Arcane Arc",
        desc_de  = "Erziele hohe Punktzahlen in Shadows Conquest.",
        desc_en  = "Achieve high scores in Shadows Conquest.",
        icon     = 135732, -- Spell_Arcane_ArcanePotency
        condition = function(data, db)
            if data.gameId ~= "SHADOWSCONQUEST" or data.result ~= "WIN" then return 0 end
            local score = data.score or 0
            if score >= 800 then return 3 end
            if score >= 400 then return 2 end
            if score >= 150 then return 1 end
            return 0
        end,
        tiers = {
            { id="SC_SCORE_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Erziele 150 Punkte.",  desc_en="Score 150 points."  },
            { id="SC_SCORE_SILBER", tierName="Silber", target=2, xp=40, desc_de="Erziele 400 Punkte.",  desc_en="Score 400 points."  },
            { id="SC_SCORE_GOLD",   tierName="Gold",   target=3, xp=65, desc_de="Erziele 800 Punkte!",  desc_en="Score 800 points!"  },
        },
    },
})

ArcadiaNexus.RegisterAchievements({{
    id="SC_OPTIMAL",gameId="SHADOWSCONQUEST",category="RAETSEL",title_de="Licht in Perfektion",title_en="Perfect Light",
    desc_de="Löse verschiedene Rätsel mit den bewiesenen Mindestzügen.",desc_en="Solve different puzzles in the proven minimum number of moves.",icon=135732,
    condition=function(data,db)
        if data.gameId~="SHADOWSCONQUEST" then return 0 end
        local st=db.gameSettings and db.gameSettings.SHADOWSCONQUEST and db.gameSettings.SHADOWSCONQUEST.modern
        local count=0; for _,v in pairs(st and st.uniqueOptimal or {}) do if v==true then count=count+1 end end return count
    end,
    tiers={
        {id="SC_OPTIMAL_BRONZE",tierName="Bronze",target=1,xp=20,desc_de="Löse 1 Rätsel optimal.",desc_en="Solve 1 puzzle optimally."},
        {id="SC_OPTIMAL_SILBER",tierName="Silber",target=10,xp=40,desc_de="Löse 10 verschiedene Rätsel optimal.",desc_en="Solve 10 different puzzles optimally."},
        {id="SC_OPTIMAL_GOLD",tierName="Gold",target=30,xp=65,desc_de="Löse 30 verschiedene Rätsel optimal.",desc_en="Solve 30 different puzzles optimally."}
    }
}})
