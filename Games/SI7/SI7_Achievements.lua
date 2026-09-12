--[[
    ArcadiaNexus – Azeroth Intelligence (SI:7)
    Games/SI7/SI7_Achievements.lua
    Nur Mehrspieler (GAME_RESULT); Hotseat zählt nicht.
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

local function getGamesPlayed(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.gamesPlayed or 0)
    end
    return total
end

local function bump(db, groupId)
    local prog = db.achievements and db.achievements.progress
                 and db.achievements.progress[groupId]
    return (prog and prog.current or 0) + 1
end

local function flag(data, key)
    return data.stats and (data.stats[key] or 0) or 0
end

ArcadiaNexus.RegisterAchievements({

    {
        id = "SI7_WINS", gameId = "SI7", category = "WORT",
        title_de = "Feldagent", title_en = "Field Agent",
        desc_de = "Gewinne Mehrspieler-Runden in Azeroth Intelligence.",
        desc_en = "Win multiplayer rounds of Azeroth Intelligence.",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        condition = function(data, db)
            if data.gameId ~= "SI7" then return 0 end
            return getTotalWins(db, "SI7")
        end,
        tiers = {
            { id = "SI7_WINS_BRONZE", tierName = "Bronze", target = 3,  xp = 20,
              desc_de = "Gewinne 3 MP-Runden.", desc_en = "Win 3 MP rounds." },
            { id = "SI7_WINS_SILBER", tierName = "Silber", target = 10, xp = 40,
              desc_de = "Gewinne 10 MP-Runden.", desc_en = "Win 10 MP rounds." },
            { id = "SI7_WINS_GOLD",   tierName = "Gold",   target = 25, xp = 70,
              desc_de = "Gewinne 25 MP-Runden.", desc_en = "Win 25 MP rounds." },
        },
    },

    {
        id = "SI7_MISSIONS", gameId = "SI7", category = "WORT",
        title_de = "Akte SI:7", title_en = "SI:7 Dossier",
        desc_de = "Schließe Mehrspieler-Einsätze ab — Sieg oder Niederlage.",
        desc_en = "Complete multiplayer operations — win or lose.",
        icon = "Interface\\Icons\\INV_Letter_04",
        condition = function(data, db)
            if data.gameId ~= "SI7" then return 0 end
            return getGamesPlayed(db, "SI7")
        end,
        tiers = {
            { id = "SI7_MISSIONS_BRONZE", tierName = "Bronze", target = 1,  xp = 10,
              desc_de = "Spiele 1 MP-Runde.", desc_en = "Play 1 MP round." },
            { id = "SI7_MISSIONS_SILBER", tierName = "Silber", target = 10, xp = 25,
              desc_de = "Spiele 10 MP-Runden.", desc_en = "Play 10 MP rounds." },
            { id = "SI7_MISSIONS_GOLD",   tierName = "Gold",   target = 30, xp = 50,
              desc_de = "Spiele 30 MP-Runden.", desc_en = "Play 30 MP rounds." },
        },
    },

    {
        id = "SI7_CLEARED", gameId = "SI7", category = "WORT",
        title_de = "Netzwerk enttarnt", title_en = "Network Exposed",
        desc_de = "Identifiziere alle Agenten deines Teams.",
        desc_en = "Identify all of your team's agents.",
        icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "cleared") ~= 1 then return 0 end
            return bump(db, "SI7_CLEARED")
        end,
        tiers = {
            { id = "SI7_CLEARED_BRONZE", tierName = "Bronze", target = 1, xp = 25,
              desc_de = "Einmal alle eigenen Agenten finden.", desc_en = "Find all your agents once." },
            { id = "SI7_CLEARED_SILBER", tierName = "Silber", target = 5, xp = 45,
              desc_de = "Fünfmal das komplette Netz aufdecken.", desc_en = "Expose the full net 5 times." },
            { id = "SI7_CLEARED_GOLD",   tierName = "Gold",   target = 12, xp = 75,
              desc_de = "Zwölf komplette Enttarnungen.", desc_en = "Complete 12 full exposures." },
        },
    },

    {
        id = "SI7_ASSASSIN", gameId = "SI7", category = "WORT",
        title_de = "Schwarzer Auftrag", title_en = "Black Contract",
        desc_de = "Gewinne, weil die Gegenseite den Assassinen aufdeckt.",
        desc_en = "Win because the other team reveals the assassin.",
        icon = "Interface\\Icons\\Ability_Rogue_Shadowstep",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "assassin") ~= 1 then return 0 end
            return bump(db, "SI7_ASSASSIN")
        end,
        tiers = {
            { id = "SI7_ASSASSIN_BRONZE", tierName = "Bronze", target = 1, xp = 20,
              desc_de = "Ein Sieg durch den Assassinen.", desc_en = "Win once via the assassin." },
            { id = "SI7_ASSASSIN_SILBER", tierName = "Silber", target = 5, xp = 40,
              desc_de = "Fünf Siege durch den Assassinen.", desc_en = "Win 5 times via the assassin." },
            { id = "SI7_ASSASSIN_GOLD",   tierName = "Gold",   target = 10, xp = 65,
              desc_de = "Zehn Siege durch den Assassinen.", desc_en = "Win 10 times via the assassin." },
        },
    },

    {
        id = "SI7_HORDE", gameId = "SI7", category = "WORT",
        title_de = "Für die Horde", title_en = "For the Horde",
        desc_de = "Gewinne Einsätze auf Seiten der Horde.",
        desc_en = "Win operations for the Horde.",
        icon = "Interface\\Icons\\INV_BannerPVP_01",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "hordeWin") ~= 1 then return 0 end
            return bump(db, "SI7_HORDE")
        end,
        tiers = {
            { id = "SI7_HORDE_BRONZE", tierName = "Bronze", target = 1, xp = 15,
              desc_de = "Ein Horden-Sieg.", desc_en = "Win 1 as Horde." },
            { id = "SI7_HORDE_SILBER", tierName = "Silber", target = 5, xp = 35,
              desc_de = "Fünf Horden-Siege.", desc_en = "Win 5 as Horde." },
            { id = "SI7_HORDE_GOLD",   tierName = "Gold",   target = 15, xp = 60,
              desc_de = "Fünfzehn Horden-Siege.", desc_en = "Win 15 as Horde." },
        },
    },

    {
        id = "SI7_ALLIANCE", gameId = "SI7", category = "WORT",
        title_de = "Für die Allianz", title_en = "For the Alliance",
        desc_de = "Gewinne Einsätze auf Seiten der Allianz.",
        desc_en = "Win operations for the Alliance.",
        icon = "Interface\\Icons\\INV_BannerPVP_02",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "allianceWin") ~= 1 then return 0 end
            return bump(db, "SI7_ALLIANCE")
        end,
        tiers = {
            { id = "SI7_ALLIANCE_BRONZE", tierName = "Bronze", target = 1, xp = 15,
              desc_de = "Ein Allianz-Sieg.", desc_en = "Win 1 as Alliance." },
            { id = "SI7_ALLIANCE_SILBER", tierName = "Silber", target = 5, xp = 35,
              desc_de = "Fünf Allianz-Siege.", desc_en = "Win 5 as Alliance." },
            { id = "SI7_ALLIANCE_GOLD",   tierName = "Gold",   target = 15, xp = 60,
              desc_de = "Fünfzehn Allianz-Siege.", desc_en = "Win 15 as Alliance." },
        },
    },

    {
        id = "SI7_SPY", gameId = "SI7", category = "WORT",
        title_de = "Spionagemeister", title_en = "Spymaster",
        desc_de = "Gewinne als Spion — die Key-Karte bleibt bei dir.",
        desc_en = "Win as spymaster — you hold the key card.",
        icon = "Interface\\Icons\\Ability_Stealth",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "spyWin") ~= 1 then return 0 end
            return bump(db, "SI7_SPY")
        end,
        tiers = {
            { id = "SI7_SPY_BRONZE", tierName = "Bronze", target = 1, xp = 20,
              desc_de = "Ein Sieg als Spion.", desc_en = "Win 1 as spymaster." },
            { id = "SI7_SPY_SILBER", tierName = "Silber", target = 5, xp = 40,
              desc_de = "Fünf Siege als Spion.", desc_en = "Win 5 as spymaster." },
            { id = "SI7_SPY_GOLD",   tierName = "Gold",   target = 12, xp = 70,
              desc_de = "Zwölf Siege als Spion.", desc_en = "Win 12 as spymaster." },
        },
    },

    {
        id = "SI7_OPERATIVE", gameId = "SI7", category = "WORT",
        title_de = "Im Feld", title_en = "In the Field",
        desc_de = "Gewinne als Agent — nur Wörter, keine Farben.",
        desc_en = "Win as operative — words only, no colors.",
        icon = "Interface\\Icons\\Ability_Rogue_Disguise",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            if flag(data, "opWin") ~= 1 then return 0 end
            return bump(db, "SI7_OPERATIVE")
        end,
        tiers = {
            { id = "SI7_OPERATIVE_BRONZE", tierName = "Bronze", target = 1, xp = 20,
              desc_de = "Ein Sieg als Agent.", desc_en = "Win 1 as operative." },
            { id = "SI7_OPERATIVE_SILBER", tierName = "Silber", target = 5, xp = 40,
              desc_de = "Fünf Siege als Agent.", desc_en = "Win 5 as operative." },
            { id = "SI7_OPERATIVE_GOLD",   tierName = "Gold",   target = 12, xp = 70,
              desc_de = "Zwölf Siege als Agent.", desc_en = "Win 12 as operative." },
        },
    },

    {
        id = "SI7_SWEEP", gameId = "SI7", category = "WORT",
        title_de = "Überlegenheit", title_en = "Overwhelming Odds",
        desc_de = "Gewinne, während dem Gegner noch viele Agenten bleiben.",
        desc_en = "Win while the enemy still has many agents left.",
        icon = "Interface\\Icons\\Achievement_PVP_O_H",
        condition = function(data, db)
            if data.gameId ~= "SI7" or data.result ~= "WIN" then return 0 end
            local left = flag(data, "enemyLeft")
            if left >= 7 then return 3 end
            if left >= 5 then return 2 end
            if left >= 3 then return 1 end
            return 0
        end,
        tiers = {
            { id = "SI7_SWEEP_BRONZE", tierName = "Bronze", target = 1, xp = 25,
              desc_de = "Sieg bei mindestens 3 gegnerischen Agenten.", desc_en = "Win with at least 3 enemy agents left." },
            { id = "SI7_SWEEP_SILBER", tierName = "Silber", target = 2, xp = 45,
              desc_de = "Sieg bei mindestens 5 gegnerischen Agenten.", desc_en = "Win with at least 5 enemy agents left." },
            { id = "SI7_SWEEP_GOLD",   tierName = "Gold",   target = 3, xp = 80,
              desc_de = "Sieg bei mindestens 7 gegnerischen Agenten.", desc_en = "Win with at least 7 enemy agents left." },
        },
    },
})
