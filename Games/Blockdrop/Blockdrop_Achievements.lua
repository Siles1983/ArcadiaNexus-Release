--[[
    ArcadiaNexus
    Games/Blockdrop/Blockdrop_Achievements.lua
    Achievements fuer Blockdrop (Kategorie: ARCADE)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalGames(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
    end
    return total
end

ArcadiaNexus.RegisterAchievements({

    {
        id       = "BLD_PLAYED",
        gameId   = "BLOCKDROP",
        category = "ARCADE",
        title_de = "Blockstapel",
        title_en = "Block Stacker",
        desc_de  = "Spiele BlockDrop-Partien.",
        desc_en  = "Play BlockDrop games.",
        icon     = 134104, -- INV_Misc_Gem_Emerald_01
        condition = function(data, db)
            if data.gameId ~= "BLOCKDROP" then return 0 end
            return getTotalGames(db, "BLOCKDROP")
        end,
        tiers = {
            { id="BLD_PLAYED_BRONZE", tierName="Bronze", target=5,  xp=10, desc_de="Spiele 5x BlockDrop.",  desc_en="Play 5 BlockDrop games."  },
            { id="BLD_PLAYED_SILBER", tierName="Silber", target=25, xp=25, desc_de="Spiele 25x BlockDrop.", desc_en="Play 25 BlockDrop games." },
            { id="BLD_PLAYED_GOLD",   tierName="Gold",   target=75, xp=50, desc_de="Spiele 75x BlockDrop.", desc_en="Play 75 BlockDrop games." },
        },
    },

    {
        id       = "BLD_LINES",
        gameId   = "BLOCKDROP",
        category = "ARCADE",
        title_de = "Zeilenräumer",
        title_en = "Line Clearer",
        desc_de  = "Räume viele Zeilen in einer Partie.",
        desc_en  = "Clear many lines in a single game.",
        icon     = "Interface\\Icons\\Spell_Arcane_MassDispel",
        condition = function(data, db)
            if data.gameId ~= "BLOCKDROP" then return 0 end
            local lines = data.stats and data.stats.linesCleared or 0
            return lines
        end,
        tiers = {
            { id="BLD_LINES_BRONZE", tierName="Bronze", target=20,  xp=15, desc_de="Räume 20 Zeilen.",  desc_en="Clear 20 lines."  },
            { id="BLD_LINES_SILBER", tierName="Silber", target=60,  xp=35, desc_de="Räume 60 Zeilen.",  desc_en="Clear 60 lines."  },
            { id="BLD_LINES_GOLD",   tierName="Gold",   target=120, xp=65, desc_de="Räume 120 Zeilen!", desc_en="Clear 120 lines!" },
        },
    },
})
