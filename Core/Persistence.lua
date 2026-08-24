--[[
    ArcadiaNexus – Core/Persistence.lua
    Zentrales Persistence-Management

    Verantwortlichkeiten:
      - DB-Schema-Definition (Defaults)
      - Schema-Versionierung
      - Migration Legacy-Keys
      - Helper-Funktionen für DB-Zugriff

    API:
      ArcadiaNexus.Persistence:InitializeDB()
      ArcadiaNexus.Persistence:GetSchemaVersion()
      ArcadiaNexus.Persistence:GetGameSettings(gameID)
      ArcadiaNexus.Persistence:SetGameSetting(gameID, key, value)
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.Persistence = {}

local P = ArcadiaNexus.Persistence

-- ============================================================
-- SCHEMA VERSION
-- Erhöhe diese Nummer bei strukturellen DB-Änderungen.
-- ============================================================
local CURRENT_SCHEMA = 8

-- ============================================================
-- DEFAULT SCHEMA
-- ============================================================
local DB_DEFAULTS = {
    schemaVersion = CURRENT_SCHEMA,
    version       = "1.0.0",
    settings      = {
        soundEnabled      = true,
        animationsEnabled = true,
        showGotd          = true,
        lockUI            = false,
        uiScale           = 1.0,
    },
    gameSettings        = {},
    categoryGroupState  = {},
    leaderboard         = {},
    leaderboardUIState  = {},
    profile = {
        level         = 1,
        xp            = 0,
        xpRequired    = 2000,
        totalXP       = 0,
        totalGames    = 0,
        wins          = 0,
        losses        = 0,
        draws         = 0,
        activeTitle   = nil,   -- nil = höchster verfügbarer Titel (Runtime)
        titleVisible  = true,
    },
    favorites    = {},
    hiddenGames  = {},
    achievements = {
        unlocked = {},
        progress = {},
    },
    streak       = { current = 0, best = 0, lastLogin = 0, claimedToday = false },
    challenges   = { daily = {}, weekly = {}, history = { completedTotal = 0, goldEarned = 0 } },
    tavernGold   = { balance = 0, lifetime = 0, log = {} },
    toastAnchor  = { x = 0, y = -200 },
    gotdAnchor   = { x = 0, y = -220 },
    windowPos    = nil,   -- gespeicherte Fensterposition (wird beim Verschieben gefüllt)
    dev          = { devMode = false },
}

-- ============================================================
-- INITIALIZE
-- ============================================================

function P:InitializeDB()
    -- Erstanlage: komplettes Schema setzen
    if not ArcadiaNexusDB then
        ArcadiaNexusDB = {}
    end

    -- Fehlende Top-Level-Keys auffüllen (idempotent)
    for key, default in pairs(DB_DEFAULTS) do
        if ArcadiaNexusDB[key] == nil then
            if type(default) == "table" then
                ArcadiaNexusDB[key] = self:_DeepCopy(default)
            else
                ArcadiaNexusDB[key] = default
            end
        end
    end

    -- Sub-Tabellen absichern
    if not ArcadiaNexusDB.achievements.unlocked then ArcadiaNexusDB.achievements.unlocked = {} end
    if not ArcadiaNexusDB.achievements.progress then ArcadiaNexusDB.achievements.progress = {} end
    if not ArcadiaNexusDB.challenges.history    then ArcadiaNexusDB.challenges.history = { completedTotal = 0, goldEarned = 0 } end

    -- Fehlende Sub-Keys in bestehenden Tabellen auffüllen (z.B. profile.titleVisible)
    self:_EnsureNestedDefaults(ArcadiaNexusDB.profile,  DB_DEFAULTS.profile)
    self:_EnsureNestedDefaults(ArcadiaNexusDB.settings, DB_DEFAULTS.settings)

    -- Migrationen ausführen
    self:_RunMigrations()

    -- Schema-Version aktualisieren
    ArcadiaNexusDB.schemaVersion = CURRENT_SCHEMA

    GH_LogInfo("Persistence", "DB initialisiert (Schema v" .. CURRENT_SCHEMA .. ")")
end

-- ============================================================
-- MIGRATIONEN
-- ============================================================

function P:_RunMigrations()
    local dbVersion = ArcadiaNexusDB.schemaVersion or 0

    -- Schema v0 → v1: Root-Keys in gameSettings migrieren
    if dbVersion < 1 then
        self:_MigrateRootKeys()
        GH_LogInfo("Persistence", "Migration v0 -> v1 abgeschlossen")
    end

    -- Schema v1 → v2: PascalCase → UPPERCASE gameSettings-Keys
    if dbVersion < 2 then
        self:_MigrateSettingsKeys()
        GH_LogInfo("Persistence", "Migration v1 -> v2 abgeschlossen")
    end

    -- Schema v2 → v3: Alle Root-Level Game-Keys → gameSettings
    if dbVersion < 3 then
        self:_MigrateRootKeys()
        GH_LogInfo("Persistence", "Migration v2 -> v3 abgeschlossen")
    end

    -- Schema v3 → v4: Veralteten scores-Root-Key entfernen (wurde durch leaderboard ersetzt)
    if dbVersion < 4 then
        if ArcadiaNexusDB.scores then
            ArcadiaNexusDB.scores = nil
            GH_LogInfo("Persistence", "Migration v3 -> v4: scores-Key entfernt")
        end
    end

    -- Schema v4 → v5: Neue Settings-Keys (lockUI, hiddenGames) werden über DB_DEFAULTS aufgefüllt
    if dbVersion < 5 then
        if ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.lockUI == nil then
            ArcadiaNexusDB.settings.lockUI = false
        end
        if ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.uiScale == nil then
            ArcadiaNexusDB.settings.uiScale = 1.0
        end
        if ArcadiaNexusDB.hiddenGames == nil then
            ArcadiaNexusDB.hiddenGames = {}
        end
        GH_LogInfo("Persistence", "Migration v4 -> v5 abgeschlossen")
    end

    -- Schema v5 → v6: Lokale Highscore-Keys in gameSettings → leaderboard
    if dbVersion < 6 then
        self:_MigrateLocalHighscores()
        GH_LogInfo("Persistence", "Migration v5 -> v6 abgeschlossen")
    end

    -- Schema v6 → v7: LUDO → LOA (Ludo of Azeroth)
    if dbVersion < 7 then
        self:_MigrateLudoToLoa()
        GH_LogInfo("Persistence", "Migration v6 -> v7 abgeschlossen")
    end

    -- Schema v7 → v8: Goblin Gold Hunter und DevBlueprint entfernen
    if dbVersion < 8 then
        self:_RemoveRetiredGames()
        GH_LogInfo("Persistence", "Migration v7 -> v8 abgeschlossen")
    end
end

--- Phase 3: Alte Root-Keys in gameSettings überführen
function P:_MigrateRootKeys()
    local migrations = {
        { old = "WhackAMole", new = "WHACKAMOLE" },
        { old = "Tetris",     new = "TETRIS"     },
        { old = "Mastermind", new = "MASTERMIND"  },
        { old = "Hangman",    new = "HANGMAN"      },
    }
    -- Spezialfall: 2048 BestScore (eigener Root-Key)
    if ArcadiaNexusDB["2048_BestScore"] then
        local gs = ArcadiaNexusDB.gameSettings["2048"] or {}
        gs._bestScore = ArcadiaNexusDB["2048_BestScore"]
        ArcadiaNexusDB.gameSettings["2048"] = gs
        ArcadiaNexusDB["2048_BestScore"] = nil
        GH_LogInfo("Persistence", "Migration: DB.2048_BestScore -> gameSettings.2048._bestScore")
    end
    for _, m in ipairs(migrations) do
        if ArcadiaNexusDB[m.old] then
            if not ArcadiaNexusDB.gameSettings[m.new] then
                ArcadiaNexusDB.gameSettings[m.new] = ArcadiaNexusDB[m.old]
                GH_LogInfo("Persistence", "Migration: DB." .. m.old .. " -> gameSettings." .. m.new)
            end
            ArcadiaNexusDB[m.old] = nil
        end
    end
end

--- v6: Veraltete per-Spiel-Highscores in zentrale leaderboard-Struktur überführen.
function P:_MigrateLocalHighscores()
    if not ArcadiaNexusDB.gameSettings then return end

    local lb = ArcadiaNexusDB.leaderboard
    if not lb then
        lb = {}
        ArcadiaNexusDB.leaderboard = lb
    end

    local function mergeScore(gameId, difficulty, score)
        if not score or score <= 0 then return end
        if type(difficulty) == "string" then
            difficulty = difficulty:lower()
        end
        local key = difficulty or "default"
        if not lb[gameId] then lb[gameId] = {} end
        if not lb[gameId][key] then
            lb[gameId][key] = { highscores = {}, wins = 0, losses = 0, draws = 0 }
        end
        local hs = lb[gameId][key].highscores
        table.insert(hs, score)
        table.sort(hs, function(a, b) return a > b end)
        while #hs > 3 do table.remove(hs) end
    end

    local gs = ArcadiaNexusDB.gameSettings

    -- SNAKE: highscoreEasy / highscoreNormal / highscoreHard
    local snake = gs.SNAKE
    if snake then
        if snake.highscoreEasy and snake.highscoreEasy > 0 then
            mergeScore("SNAKE", "easy", snake.highscoreEasy)
            snake.highscoreEasy = nil
        end
        if snake.highscoreNormal and snake.highscoreNormal > 0 then
            mergeScore("SNAKE", "normal", snake.highscoreNormal)
            snake.highscoreNormal = nil
        end
        if snake.highscoreHard and snake.highscoreHard > 0 then
            mergeScore("SNAKE", "hard", snake.highscoreHard)
            snake.highscoreHard = nil
        end
    end

    -- 2048: _bestScore
    local t2048 = gs["2048"]
    if t2048 and t2048._bestScore and t2048._bestScore > 0 then
        mergeScore("2048", "default", t2048._bestScore)
        t2048._bestScore = nil
    end

    -- hs_<diff> Pattern (AlienDefense, BlockBreaker, Match3)
    local hsGames = { "ALIENDEFENSE", "BLOCKBREAKER", "MATCH3" }
    for _, gameId in ipairs(hsGames) do
        local db = gs[gameId]
        if db then
            for _, diff in ipairs({ "easy", "normal", "hard" }) do
                local k = "hs_" .. diff
                if db[k] and db[k] > 0 then
                    mergeScore(gameId, diff, db[k])
                    db[k] = nil
                end
            end
        end
    end

    -- GoblinBlast: globales highScore → default
    local gb = gs.GOBLINBLAST
    if gb and gb.highScore and gb.highScore > 0 then
        mergeScore("GOBLINBLAST", "default", gb.highScore)
        gb.highScore = nil
    end

    -- ArgusOrbitDefense: top3_<diff>
    local aod = gs.ARGUSORBDEFENSE
    if aod then
        for _, diff in ipairs({ "easy", "normal", "hard" }) do
            local k = "top3_" .. diff
            if aod[k] then
                for _, score in ipairs(aod[k]) do
                    mergeScore("ARGUSORBDEFENSE", diff, score)
                end
                aod[k] = nil
            end
        end
    end

    -- ReactionStrike: bestMs → berechneter Score
    local rs = gs.REACTIONSTRIKE
    if rs and rs.bestMs then
        local factors = { easy = 1.0, normal = 1.5, hard = 2.0 }
        for diff, ms in pairs(rs.bestMs) do
            if ms and ms > 0 then
                local factor = factors[diff] or 1.0
                local score = math.floor(math.max(0, 1000 - ms) * factor)
                mergeScore("REACTIONSTRIKE", diff, score)
            end
        end
        rs.bestMs = nil
    end
end

--- Phase 5: PascalCase → UPPERCASE
function P:_MigrateSettingsKeys()
    local migrations = {
        { old = "AlienDefense",   new = "ALIENDEFENSE"   },
        { old = "Battleship",     new = "BATTLESHIP"     },
        { old = "BlockBreaker",   new = "BLOCKBREAKER"   },
        { old = "Chess",          new = "CHESS"          },
        { old = "LightsOut",      new = "LIGHTSOUT"      },
        { old = "Ludo",           new = "LUDO"           },
        { old = "Match3",         new = "MATCH3"         },
        { old = "Memory",         new = "MEMORY"         },
        { old = "Minesweeper",    new = "MINESWEEPER"    },
        { old = "Nonogram",       new = "NONOGRAM"       },
        { old = "ReactionStrike", new = "REACTIONSTRIKE" },
        { old = "SimonSays",      new = "SIMONSAYS"      },
        { old = "Snake",          new = "SNAKE"          },
        { old = "Sudoku",         new = "SUDOKU"         },
        { old = "VierGewinnt",    new = "CONNECT4"       },
    }
    for _, m in ipairs(migrations) do
        if ArcadiaNexusDB.gameSettings[m.old] then
            if not ArcadiaNexusDB.gameSettings[m.new] then
                ArcadiaNexusDB.gameSettings[m.new] = ArcadiaNexusDB.gameSettings[m.old]
                GH_LogInfo("Persistence", "Migration: gameSettings." .. m.old .. " -> ." .. m.new)
            end
            ArcadiaNexusDB.gameSettings[m.old] = nil
        end
    end
end

--- v7: Ludo → Ludo of Azeroth (LUDO → LOA)
function P:_MigrateLudoToLoa()
    local gs = ArcadiaNexusDB.gameSettings
    if gs and gs.LUDO and not gs.LOA then
        gs.LOA = gs.LUDO
        gs.LUDO = nil
        GH_LogInfo("Persistence", "Migration: gameSettings.LUDO -> .LOA")
    end

    local lb = ArcadiaNexusDB.leaderboard
    if lb and lb.LUDO and not lb.LOA then
        lb.LOA = lb.LUDO
        lb.LUDO = nil
        GH_LogInfo("Persistence", "Migration: leaderboard.LUDO -> .LOA")
    end

    local ach = ArcadiaNexusDB.achievements
    if not ach then return end

    local function migrateKeys(tbl)
        if not tbl then return end
        local toMove = {}
        for key, val in pairs(tbl) do
            if type(key) == "string" and key:sub(1, 5) == "LUDO_" then
                toMove[#toMove+1] = { old = key, new = "LOA_" .. key:sub(6), val = val }
            end
        end
        for _, m in ipairs(toMove) do
            if not tbl[m.new] then tbl[m.new] = m.val end
            tbl[m.old] = nil
        end
    end

    migrateKeys(ach.unlocked)
    migrateKeys(ach.progress)

    if ArcadiaNexusDB.hiddenGames then
        for i, id in ipairs(ArcadiaNexusDB.hiddenGames) do
            if id == "LUDO" then ArcadiaNexusDB.hiddenGames[i] = "LOA" end
        end
    end

    if ArcadiaNexusDB.favorites then
        for i, id in ipairs(ArcadiaNexusDB.favorites) do
            if id == "LUDO" then ArcadiaNexusDB.favorites[i] = "LOA" end
        end
    end
end

--- v8: Goblin Gold Hunter (GGH) und DevBlueprint vollständig aus der DB entfernen.
function P:_RemoveRetiredGames()
    local retired = { GGH = true, DEVBLUEPRINT = true }

    if ArcadiaNexusDB.gameSettings then
        ArcadiaNexusDB.gameSettings.GGH = nil
        ArcadiaNexusDB.gameSettings.DEVBLUEPRINT = nil
    end

    if ArcadiaNexusDB.leaderboard then
        ArcadiaNexusDB.leaderboard.GGH = nil
        ArcadiaNexusDB.leaderboard.DEVBLUEPRINT = nil
    end

    ArcadiaNexusDB.blueprint = nil

    local function stripIdList(list)
        if type(list) ~= "table" then return end
        for i = #list, 1, -1 do
            if retired[list[i]] then
                table.remove(list, i)
            end
        end
        list.GGH = nil
        list.DEVBLUEPRINT = nil
    end
    stripIdList(ArcadiaNexusDB.favorites)
    stripIdList(ArcadiaNexusDB.hiddenGames)

    local ach = ArcadiaNexusDB.achievements
    if ach then
        local function stripAchKeys(tbl)
            if type(tbl) ~= "table" then return end
            local toRemove = {}
            for key in pairs(tbl) do
                if type(key) == "string" and (key:sub(1, 4) == "GGH_" or key:sub(1, 4) == "DBP_") then
                    toRemove[#toRemove + 1] = key
                end
            end
            for _, key in ipairs(toRemove) do
                tbl[key] = nil
            end
        end
        stripAchKeys(ach.unlocked)
        stripAchKeys(ach.progress)
    end
end

-- ============================================================
-- HELPER: GAME SETTINGS ACCESS
-- ============================================================

--- Stellt sicher, dass ArcadiaNexusDB und gameSettings existieren.
function P:_EnsureDB()
    if not ArcadiaNexusDB then
        ArcadiaNexusDB = {}
    end
    if not ArcadiaNexusDB.gameSettings then
        ArcadiaNexusDB.gameSettings = {}
    end
end

--- Gibt die Settings-Tabelle für ein Spiel zurück (legt sie bei Bedarf an).
--- @param gameID string UPPERCASE Spiel-ID, z.B. "SNAKE"
--- @return table
function P:GetGameSettings(gameID)
    if not gameID then
        GH_LogWarn("Persistence", "GetGameSettings() mit nil gameID")
        return {}
    end
    self:_EnsureDB()
    if not ArcadiaNexusDB.gameSettings[gameID] then
        ArcadiaNexusDB.gameSettings[gameID] = {}
    end
    return ArcadiaNexusDB.gameSettings[gameID]
end

--- Setzt einen einzelnen Settings-Wert für ein Spiel.
--- @param gameID string UPPERCASE Spiel-ID
--- @param key string
--- @param value any nil erlaubt (Key löschen)
function P:SetGameSetting(gameID, key, value)
    if not gameID or key == nil then
        GH_LogWarn("Persistence", "SetGameSetting() mit nil gameID oder key")
        return
    end
    self:GetGameSettings(gameID)[key] = value
end

function P:GetSchemaVersion()
    return ArcadiaNexusDB and ArcadiaNexusDB.schemaVersion or 0
end

-- ============================================================
-- UTILITY
-- ============================================================

function P:_DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:_DeepCopy(v)
    end
    return copy
end

--- Fehlende Sub-Keys in einer bestehenden Tabelle aus Defaults auffüllen.
function P:_EnsureNestedDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then return end
    for key, default in pairs(defaults) do
        if target[key] == nil then
            if type(default) == "table" then
                target[key] = self:_DeepCopy(default)
            else
                target[key] = default
            end
        end
    end
end
