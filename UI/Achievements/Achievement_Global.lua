--[[
    ArcadiaNexus
    UI/Achievements/Achievement_Global.lua
    Spielübergreifende Achievement-Definitionen (gameId = "ALLGEMEIN").
]]

local ArcadiaNexus = _G.ArcadiaNexus

local groups = {}

-- ============================================================
-- HILFSFUNKTIONEN (lokal, geteilt mit anderen Ach-Dateien via Closure)
-- Hinweis: Die globalen Helpers sind in Achievement_Index.lua definiert
-- und per ArcadiaNexus.AchHelpers zugänglich.
-- ============================================================

local function getAllGamesTotal(db)
    if not db.leaderboard then return 0 end
    local total = 0
    for _, diffTable in pairs(db.leaderboard) do
        for _, entry in pairs(diffTable) do
            total = total + (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
        end
    end
    return total
end

local function getAllWinsTotal(db)
    if not db.leaderboard then return 0 end
    local total = 0
    for _, diffTable in pairs(db.leaderboard) do
        for _, entry in pairs(diffTable) do
            total = total + (entry.wins or 0)
        end
    end
    return total
end

-- ============================================================
-- SPIELÜBERGREIFENDE ACHIEVEMENTS
-- ============================================================

-- Gesamt-Spielanzahl
groups[#groups + 1] = {
    id       = "GLOBAL_GAMES_PLAYED",
    gameId   = "ALLGEMEIN",
    category = nil,
    title_de = "Spielsüchtig",
    title_en = "Game Addict",
    desc_de  = "Spiele eine bestimmte Anzahl an Spielen.",
    desc_en  = "Play a certain number of games.",
    icon     = "Interface\\Icons\\INV_Misc_Dice_02",
    condition = function(data, db)
        if data._retroactive then return data.totalGames or 0 end
        return getAllGamesTotal(db)
    end,
    tiers = {
        { id="GLOBAL_GAMES_PLAYED_BRONZE", tierName="Bronze", target=25,  xp=15, desc_de="Spiele 25 Spiele.",   desc_en="Play 25 games."   },
        { id="GLOBAL_GAMES_PLAYED_SILBER", tierName="Silber", target=100, xp=30, desc_de="Spiele 100 Spiele.",  desc_en="Play 100 games."  },
        { id="GLOBAL_GAMES_PLAYED_GOLD",   tierName="Gold",   target=500, xp=60, desc_de="Spiele 500 Spiele.",  desc_en="Play 500 games."  },
    },
}

-- Gesamt-Siege
groups[#groups + 1] = {
    id       = "GLOBAL_WINS",
    gameId   = "ALLGEMEIN",
    category = nil,
    title_de = "Siegreicher Held",
    title_en = "Victorious Hero",
    desc_de  = "Gewinne Spiele im Nexus Gaming Hub.",
    desc_en  = "Win games in Nexus Gaming Hub.",
    icon     = 236700, -- Achievement_Win_Wintergrasp
    condition = function(data, db)
        if data._retroactive then return data.totalWins or 0 end
        return getAllWinsTotal(db)
    end,
    tiers = {
        { id="GLOBAL_WINS_BRONZE", tierName="Bronze", target=10,  xp=15, desc_de="Gewinne 10 Spiele.",  desc_en="Win 10 games."  },
        { id="GLOBAL_WINS_SILBER", tierName="Silber", target=50,  xp=30, desc_de="Gewinne 50 Spiele.",  desc_en="Win 50 games."  },
        { id="GLOBAL_WINS_GOLD",   tierName="Gold",   target=200, xp=60, desc_de="Gewinne 200 Spiele.", desc_en="Win 200 games." },
    },
}

-- Level-System
groups[#groups + 1] = {
    id       = "GLOBAL_LEVEL",
    gameId   = "ALLGEMEIN",
    category = nil,
    title_de = "Aufsteiger",
    title_en = "Rising Star",
    desc_de  = "Erreiche ein bestimmtes Level im Nexus.",
    desc_en  = "Reach a certain level in the Nexus.",
    icon     = "Interface\\Icons\\Ability_Warrior_Revenge",
    condition = function(data, db)
        if data._retroactive then return data.level or 0 end
        local XPM = ArcadiaNexus.XPManager
        if not XPM then return 0 end
        local p = XPM:GetProfile()
        return p and p.level or 0
    end,
    tiers = {
        { id="GLOBAL_LEVEL_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="Erreiche Level 5.",  desc_en="Reach level 5."  },
        { id="GLOBAL_LEVEL_SILBER", tierName="Silber", target=15, xp=40, desc_de="Erreiche Level 15.", desc_en="Reach level 15." },
        { id="GLOBAL_LEVEL_GOLD",   tierName="Gold",   target=30, xp=75, desc_de="Erreiche Level 30.", desc_en="Reach level 30." },
    },
}

-- Vielseitiger Spieler
groups[#groups + 1] = {
    id       = "GLOBAL_VARIETY",
    gameId   = "ALLGEMEIN",
    category = nil,
    title_de = "Alleskönner",
    title_en = "Jack of All Trades",
    desc_de  = "Spiele viele verschiedene Spiele.",
    desc_en  = "Play many different games.",
    icon     = "Interface\\Icons\\INV_Misc_Spyglass_03",
    condition = function(data, db)
        if not db.leaderboard then return 0 end
        local count = 0
        for _ in pairs(db.leaderboard) do count = count + 1 end
        return count
    end,
    tiers = {
        { id="GLOBAL_VARIETY_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Spiele 5 verschiedene Spiele.",  desc_en="Play 5 different games."  },
        { id="GLOBAL_VARIETY_SILBER", tierName="Silber", target=10, xp=30, desc_de="Spiele 10 verschiedene Spiele.", desc_en="Play 10 different games." },
        { id="GLOBAL_VARIETY_GOLD",   tierName="Gold",   target=22, xp=75, desc_de="Spiele 22 verschiedene Spiele.", desc_en="Play 22 different games."  },
    },
}

ArcadiaNexus.RegisterAchievements(groups)
