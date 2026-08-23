--[[
    ArcadiaNexus
    Games/AlienDefense/AlienDefense_Achievements.lua
    Achievements fuer AlienDefense (Kategorie: ARCADE)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    {
        id       = "AD_WAVES",
        gameId   = "ALIENDEFENSE",
        category = "ARCADE",
        title_de = "Planetenverteidiger",
        title_en = "Planet Defender",
        desc_de  = "Überlebe Angriffswellen in Alien Defense.",
        desc_en  = "Survive attack waves in Alien Defense.",
        icon     = 7554216, -- INV_12_DH_Void_Ability_StarFragments
        condition = function(data, db)
            if data.gameId ~= "ALIENDEFENSE" then return 0 end
            local wave = data.stats and data.stats.waveReached or 0
            return wave
        end,
        tiers = {
            { id="AD_WAVES_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="Überlebe Welle 5.",  desc_en="Survive wave 5."  },
            { id="AD_WAVES_SILBER", tierName="Silber", target=10, xp=40, desc_de="Überlebe Welle 10.", desc_en="Survive wave 10." },
            { id="AD_WAVES_GOLD",   tierName="Gold",   target=20, xp=70, desc_de="Überlebe Welle 20!", desc_en="Survive wave 20!" },
        },
    },

    {
        id       = "AD_KILLS",
        gameId   = "ALIENDEFENSE",
        category = "ARCADE",
        title_de = "Alienvernichter",
        title_en = "Alien Exterminator",
        desc_de  = "Besiege viele Aliens in Alien Defense.",
        desc_en  = "Defeat many aliens in Alien Defense.",
        icon     = "Interface\\Icons\\Ability_Marksmanship",
        condition = function(data, db)
            if data.gameId ~= "ALIENDEFENSE" then return 0 end
            local kills = data.stats and data.stats.enemiesKilled or 0
            if kills <= 0 then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["AD_KILLS"]
            return (prog and prog.current or 0) + kills
        end,
        tiers = {
            { id="AD_KILLS_BRONZE", tierName="Bronze", target=50,  xp=15, desc_de="Besiege 50 Aliens.",  desc_en="Defeat 50 aliens."  },
            { id="AD_KILLS_SILBER", tierName="Silber", target=150, xp=35, desc_de="Besiege 150 Aliens.", desc_en="Defeat 150 aliens." },
            { id="AD_KILLS_GOLD",   tierName="Gold",   target=400, xp=65, desc_de="Besiege 400 Aliens!", desc_en="Defeat 400 aliens!" },
        },
    },
})
