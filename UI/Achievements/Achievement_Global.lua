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

local function BestChallengeStreak(db, kind)
    local history = db.challenges and db.challenges.history
    local streak = history and history[kind]
    return streak and math.max(streak.best or 0, streak.current or 0) or 0
end

groups[#groups + 1] = {
    id = "GLOBAL_LOGIN_STREAK", gameId = "ALLGEMEIN",
    title_de = "Wiedersehen im Nexus", title_en = "Back to the Nexus",
    desc_de = "Logge dich an aufeinanderfolgenden Tagen ein.",
    desc_en = "Log in on consecutive days.",
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    condition = function(_, db)
        local streak = db.streak
        return streak and math.max(streak.best or 0, streak.current or 0) or 0
    end,
    tiers = {
        { id="GLOBAL_LOGIN_STREAK_BRONZE", tierName="Bronze", target=7, xp=20, desc_de="Logge dich 7 Tage in Folge ein.", desc_en="Log in for 7 consecutive days." },
        { id="GLOBAL_LOGIN_STREAK_SILBER", tierName="Silber", target=14, xp=40, desc_de="Logge dich 14 Tage in Folge ein.", desc_en="Log in for 14 consecutive days." },
        { id="GLOBAL_LOGIN_STREAK_GOLD", tierName="Gold", target=30, xp=75, desc_de="Logge dich 30 Tage in Folge ein.", desc_en="Log in for 30 consecutive days." },
    },
}

groups[#groups + 1] = {
    id = "GLOBAL_DAILY_STREAK", gameId = "ALLGEMEIN",
    title_de = "Täglicher Spieler", title_en = "Daily Player",
    desc_de = "Schließe an aufeinanderfolgenden Tagen mindestens eine tägliche Herausforderung ab.",
    desc_en = "Complete at least one daily challenge on consecutive days.",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    condition = function(_, db) return BestChallengeStreak(db, "dailyStreak") end,
    tiers = {
        { id="GLOBAL_DAILY_STREAK_BRONZE", tierName="Bronze", target=10, xp=20, desc_de="Schließe an 10 Tagen in Folge mindestens eine tägliche Herausforderung ab.", desc_en="Complete a daily challenge on 10 consecutive days." },
        { id="GLOBAL_DAILY_STREAK_SILBER", tierName="Silber", target=25, xp=40, desc_de="Schließe an 25 Tagen in Folge mindestens eine tägliche Herausforderung ab.", desc_en="Complete a daily challenge on 25 consecutive days." },
        { id="GLOBAL_DAILY_STREAK_GOLD", tierName="Gold", target=50, xp=75, desc_de="Schließe an 50 Tagen in Folge mindestens eine tägliche Herausforderung ab.", desc_en="Complete a daily challenge on 50 consecutive days." },
    },
}

groups[#groups + 1] = {
    id = "GLOBAL_WEEKLY_STREAK", gameId = "ALLGEMEIN",
    title_de = "Durchhaltevermögen", title_en = "Perseverance",
    desc_de = "Schließe in aufeinanderfolgenden Wochen mindestens eine wöchentliche Herausforderung ab.",
    desc_en = "Complete at least one weekly challenge in consecutive weeks.",
    icon = "Interface\\Icons\\INV_Misc_Calendar_01",
    condition = function(_, db) return BestChallengeStreak(db, "weeklyStreak") end,
    tiers = {
        { id="GLOBAL_WEEKLY_STREAK_BRONZE", tierName="Bronze", target=4, xp=20, desc_de="Schließe in 4 Wochen in Folge mindestens eine wöchentliche Herausforderung ab.", desc_en="Complete a weekly challenge in 4 consecutive weeks." },
        { id="GLOBAL_WEEKLY_STREAK_SILBER", tierName="Silber", target=8, xp=40, desc_de="Schließe in 8 Wochen in Folge mindestens eine wöchentliche Herausforderung ab.", desc_en="Complete a weekly challenge in 8 consecutive weeks." },
        { id="GLOBAL_WEEKLY_STREAK_GOLD", tierName="Gold", target=12, xp=75, desc_de="Schließe in 12 Wochen in Folge mindestens eine wöchentliche Herausforderung ab.", desc_en="Complete a weekly challenge in 12 consecutive weeks." },
    },
}

-- Ein eigener Gold-Erfolg pro Titel-Freischaltung ab Level 5.
local XPM = ArcadiaNexus.XPManager
local locales = ArcadiaNexus._locales and ArcadiaNexus._locales.UI or {}
local legacyLevelXP = { [5] = 20, [15] = 40, [30] = 75 }
for _, entry in ipairs(XPM:GetTitleCatalog()) do
    local level = entry.level
    if level >= 5 then
        local key = "stats_title_" .. level
        local titleDe = locales.deDE and locales.deDE[key] or entry.key
        local titleEn = locales.enUS and locales.enUS[key] or entry.key
        groups[#groups + 1] = {
            id = "GLOBAL_LEVEL_" .. level,
            gameId = "LEVEL_TITEL", category = "ALLGEMEIN",
            title_de = "Level " .. level, title_en = "Level " .. level,
            desc_de = "Erreiche Level " .. level .. " (" .. titleDe .. ").",
            desc_en = "Reach level " .. level .. " (" .. titleEn .. ").",
            icon = "Interface\\Icons\\Ability_Warrior_Revenge",
            condition = function(_, db)
                local profile = db.profile
                return profile and profile.level or 0
            end,
            tiers = {{
                id = "GLOBAL_LEVEL_" .. level .. "_GOLD", tierName = "Gold",
                target = level, xp = legacyLevelXP[level] or 30,
                desc_de = "Erreiche Level " .. level .. " (" .. titleDe .. ").",
                desc_en = "Reach level " .. level .. " (" .. titleEn .. ").",
            }},
        }
    end
end

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
