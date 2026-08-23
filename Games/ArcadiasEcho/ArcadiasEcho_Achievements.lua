--[[
    ArcadiaNexus
    Games/ArcadiasEcho/ArcadiasEcho_Achievements.lua
    Achievements fuer ArcadiasEcho (Kategorie: GESCHICK)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    {
        id       = "AE_SEQUENCE",
        gameId   = "ARCADIASECHO",
        category = "GESCHICK",
        title_de = "Gedächtniskünstler",
        title_en = "Memory Virtuoso",
        desc_de  = "Merke lange Sequenzen in Arcadia's Echo.",
        desc_en  = "Remember long sequences in Arcadia's Echo.",
        icon     = "Interface\\Icons\\Spell_Shadow_ManaBurn",
        condition = function(data, db)
            if data.gameId ~= "ARCADIASECHO" then return 0 end
            local seq = data.stats and data.stats.maxSequence or 0
            return seq
        end,
        tiers = {
            { id="AE_SEQUENCE_BRONZE", tierName="Bronze", target=8,  xp=15, desc_de="Merke 8 Symbole.",  desc_en="Remember 8 symbols."  },
            { id="AE_SEQUENCE_SILBER", tierName="Silber", target=15, xp=35, desc_de="Merke 15 Symbole.", desc_en="Remember 15 symbols." },
            { id="AE_SEQUENCE_GOLD",   tierName="Gold",   target=25, xp=65, desc_de="Merke 25 Symbole!", desc_en="Remember 25 symbols!" },
        },
    },
})
