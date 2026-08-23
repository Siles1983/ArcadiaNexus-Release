--[[
    ArcadiaNexus – Azeroth Jewels
    Games/AzerothJewels/AzerothJewels_Achievements.lua

    6 Achievement-Gruppen (GDD §9), Kategorie DENKSPIELE,
    Tiers Bronze/Silber/Gold. Kumulative Werte kommen aus den
    Zählern in gameSettings.AZEROTHJEWELS.stats (Engine pflegt sie),
    Bestwerte direkt aus dem GAME_RESULT-Event.
]]

local ArcadiaNexus = _G.ArcadiaNexus

local function GetTotals(db)
    local gs = db and db.gameSettings and db.gameSettings.AZEROTHJEWELS
    return gs and gs.stats or {}
end

ArcadiaNexus.RegisterAchievements({

    {
        id = "AJ_LEVELS", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Juwelenjäger", title_en = "Jewel Hunter",
        desc_de  = "Schließe Level ab.", desc_en = "Complete levels.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return GetTotals(db).totalLevels or 0
        end,
        tiers = {
            { id="AJ_LEVELS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Schließe 5 Level ab.",  desc_en="Complete 5 levels."  },
            { id="AJ_LEVELS_SILBER", tierName="Silber", target=20, xp=30, desc_de="Schließe 20 Level ab.", desc_en="Complete 20 levels." },
            { id="AJ_LEVELS_GOLD",   tierName="Gold",   target=50, xp=55, desc_de="Schließe 50 Level ab.", desc_en="Complete 50 levels." },
        },
    },

    {
        id = "AJ_POWERUP", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Arkanist", title_en = "Arcanist",
        desc_de  = "Setze PowerUps ein.", desc_en = "Use PowerUps.",
        icon     = "Interface\\Icons\\Spell_Arcane_Arcane02",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return GetTotals(db).totalPowerUps or 0
        end,
        tiers = {
            { id="AJ_POWERUP_BRONZE", tierName="Bronze", target=10,  xp=15, desc_de="Setze 10 PowerUps ein.",  desc_en="Use 10 PowerUps."  },
            { id="AJ_POWERUP_SILBER", tierName="Silber", target=50,  xp=30, desc_de="Setze 50 PowerUps ein.",  desc_en="Use 50 PowerUps."  },
            { id="AJ_POWERUP_GOLD",   tierName="Gold",   target=150, xp=55, desc_de="Setze 150 PowerUps ein.", desc_en="Use 150 PowerUps." },
        },
    },

    {
        id = "AJ_COMBO", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Kettenreaktion", title_en = "Chain Reaction",
        desc_de  = "Erreiche Kombo x5 in einem Level.", desc_en = "Reach combo x5 in a level.",
        icon     = "Interface\\Icons\\Spell_Nature_ChainLightning",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return GetTotals(db).totalCombo5 or 0
        end,
        tiers = {
            { id="AJ_COMBO_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Erreiche 1x Kombo x5.",  desc_en="Reach combo x5 once."     },
            { id="AJ_COMBO_SILBER", tierName="Silber", target=10, xp=30, desc_de="Erreiche 10x Kombo x5.", desc_en="Reach combo x5 10 times." },
            { id="AJ_COMBO_GOLD",   tierName="Gold",   target=30, xp=55, desc_de="Erreiche 30x Kombo x5.", desc_en="Reach combo x5 30 times." },
        },
    },

    {
        id = "AJ_TIME", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Unter Druck", title_en = "Under Pressure",
        desc_de  = "Löse Level im Zeitmodus.", desc_en = "Complete levels in time mode.",
        icon     = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return GetTotals(db).totalTimeWins or 0
        end,
        tiers = {
            { id="AJ_TIME_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="Löse 1 Level im Zeitmodus.",   desc_en="Complete 1 level in time mode."   },
            { id="AJ_TIME_SILBER", tierName="Silber", target=10, xp=30, desc_de="Löse 10 Level im Zeitmodus.",  desc_en="Complete 10 levels in time mode." },
            { id="AJ_TIME_GOLD",   tierName="Gold",   target=30, xp=55, desc_de="Löse 30 Level im Zeitmodus.",  desc_en="Complete 30 levels in time mode." },
        },
    },

    {
        id = "AJ_SCORE", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Schatzmeister", title_en = "Treasurer",
        desc_de  = "Erziele hohe Punktzahlen in einem Level.", desc_en = "Score high in a single level.",
        icon     = "Interface\\Icons\\INV_Misc_Coin_02",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return data.score or 0
        end,
        tiers = {
            { id="AJ_SCORE_BRONZE", tierName="Bronze", target=2000,  xp=15, desc_de="2.000 Punkte in einem Level.",  desc_en="2,000 points in one level."  },
            { id="AJ_SCORE_SILBER", tierName="Silber", target=8000,  xp=30, desc_de="8.000 Punkte in einem Level.",  desc_en="8,000 points in one level."  },
            { id="AJ_SCORE_GOLD",   tierName="Gold",   target=20000, xp=55, desc_de="20.000 Punkte in einem Level!", desc_en="20,000 points in one level!" },
        },
    },

    {
        id = "AJ_OBSTACLE", gameId = "AZEROTHJEWELS", category = "DENKSPIELE",
        title_de = "Eisbrecher", title_en = "Icebreaker",
        desc_de  = "Zerstöre Eis-Blöcke.", desc_en = "Destroy ice blocks.",
        icon     = "Interface\\Icons\\Spell_Frost_Glacier",
        condition = function(data, db)
            if data.gameId ~= "AZEROTHJEWELS" then return 0 end
            return GetTotals(db).totalIce or 0
        end,
        tiers = {
            { id="AJ_OBSTACLE_BRONZE", tierName="Bronze", target=20,  xp=15, desc_de="Zerstöre 20 Eis-Blöcke.",  desc_en="Destroy 20 ice blocks."  },
            { id="AJ_OBSTACLE_SILBER", tierName="Silber", target=100, xp=30, desc_de="Zerstöre 100 Eis-Blöcke.", desc_en="Destroy 100 ice blocks." },
            { id="AJ_OBSTACLE_GOLD",   tierName="Gold",   target=300, xp=55, desc_de="Zerstöre 300 Eis-Blöcke.", desc_en="Destroy 300 ice blocks." },
        },
    },
})
