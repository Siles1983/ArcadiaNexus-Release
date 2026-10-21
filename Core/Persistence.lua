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

    Domain-Writes: Core/Stores.lua (ProfileStore, StatsStore,
    GameSettingsStore, MatchStore).
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.Persistence = {}

local P = ArcadiaNexus.Persistence

-- Wird erst am Ende einer vollständig durchlaufenen Initialisierung gesetzt.
P.dbReady = false

-- Per-entry rule migration also runs through StatsStore on import. It never
-- creates a second statistics category or touches profile/achievement rewards.
function P:NormalizeCodebreakerEntry(entry)
    if type(entry) ~= "table" or entry.ruleVersion == 2 then return end
    local archive = {}
    for _, value in ipairs(entry.legacyHighscores or {}) do archive[#archive+1] = value end
    for _, value in ipairs(entry.highscores or {}) do archive[#archive+1] = value end
    table.sort(archive, function(a,b) return a > b end)
    while #archive > 3 do table.remove(archive) end
    entry.legacyHighscores = archive
    entry.highscores, entry.highscoreRuns, entry.ruleVersion = {}, nil, 2
end

-- ============================================================
-- SCHEMA VERSION
-- Erhöhe diese Nummer bei strukturellen DB-Änderungen.
-- ============================================================
local CURRENT_SCHEMA = 10

function P:NormalizeSudokuEntry(entry)
    -- Identical archive contract, with all historical counters preserved.
    self:NormalizeCodebreakerEntry(entry)
end

-- Old Alien Defense statistics are per-wave cumulative deliveries, not runs.
function P:NormalizeAlienDefenseEntry(entry)
    if type(entry)~="table" or entry.ruleVersion==2 then return end
    local legacy={}
    for k,v in pairs(entry) do legacy[k]=v end
    entry.legacyStats=legacy
    entry.legacyWaves=entry.wins or 0
    entry.legacyPlayed=entry.gamesPlayed or ((entry.wins or 0)+(entry.losses or 0))
    entry.legacyLosses=entry.losses or 0
    self:NormalizeCodebreakerEntry(entry)
    entry.wins,entry.losses,entry.draws,entry.gamesPlayed=0,0,0,0
    entry.bestLevel,entry.clearedWaves,entry.customStats=0,0,{}
end

function P:NormalizeEchoEntry(entry)
    if type(entry) ~= "table" or entry.ruleVersion == 2 then return end
    self:NormalizeCodebreakerEntry(entry)
    entry.customStats = entry.customStats or {}
    -- The old maximum describes a begun sequence; it cannot be inferred as mastered.
    local old = entry.customStats.maxSequence
    if type(old) == "number" then
        entry.customStats.legacyMaxSequence = math.max(entry.customStats.legacyMaxSequence or 0, old)
        entry.customStats.maxSequence = nil
    end
end

function P:NormalizeEchoAchievements(achievements)
    local progress = achievements.progress.AE_SEQUENCE
    if type(progress) ~= "table" or progress.ruleVersion == 2 then return end
    progress.legacyCurrent = progress.current or 0
    local tier, earned = 0, 0
    local ids = {"AE_SEQUENCE_BRONZE", "AE_SEQUENCE_SILBER", "AE_SEQUENCE_GOLD"}
    local targets = {8, 15, 25}
    for i, id in ipairs(ids) do
        if achievements.unlocked[id] ~= nil then tier, earned = i, targets[i] end
    end
    progress.tier, progress.current, progress.ruleVersion = tier, earned, 2
end

function P:NormalizeShellAchievements(achievements)
    local progress=achievements.progress.SHG_PROFIT
    if type(progress)~="table" or progress.ruleVersion==2 then return end
    progress.legacyCurrent=progress.current or 0
    local tier,earned=0,0
    for i,id in ipairs({"SHG_PROFIT_BRONZE","SHG_PROFIT_SILBER","SHG_PROFIT_GOLD"}) do
        if achievements.unlocked[id]~=nil then tier,earned=i,({1,10,25})[i] end
    end
    progress.tier,progress.current,progress.legacyEarned,progress.ruleVersion=tier,earned,earned,2
end

function P:NormalizeMinesweeperEntry(entry)
    if type(entry)~="table" or entry.ruleVersion==2 then return end
    local archive={}
    for _,v in ipairs(entry.legacyHighscores or {}) do archive[#archive+1]=v end
    for _,v in ipairs(entry.highscores or {}) do archive[#archive+1]=v end
    table.sort(archive,function(a,b) return a>b end)
    while #archive>3 do table.remove(archive) end
    entry.legacyHighscores=archive
    entry.highscores,entry.highscoreRuns,entry.bestTimes,entry.ruleVersion={},nil,{},2
end

function P:NormalizeReactionEntry(entry)
    self:NormalizeMinesweeperEntry(entry)
end

function P:NormalizeReactionAchievements(achievements)
    local speed=achievements.progress.RS_SPEED
    if type(speed)~="table" or speed.ruleVersion==2 then return end
    speed.legacyCurrent=speed.current
    local tier=0
    for i,id in ipairs({"RS_SPEED_BRONZE","RS_SPEED_SILBER","RS_SPEED_GOLD"}) do
        if achievements.unlocked[id] then tier=i end
    end
    speed.tier,speed.current,speed.ruleVersion=tier,tier,2
end

function P:NormalizeTicTacToeAchievements(achievements)
    for group,targets in pairs({TTT_WINS={5,25,75},TTT_HARD={1,10,30},TTT_STREAK={3,5,8}}) do
        local prog=achievements.progress[group]
        if type(prog)=="table" and prog.ruleVersion~=2 then
            local tier,earned=0,0
            for i,suffix in ipairs({"BRONZE","SILBER","GOLD"}) do
                if achievements.unlocked[group.."_"..suffix] then tier,earned=i,targets[i] end
            end
            prog.legacyCurrent=prog.current or 0
            prog.tier,prog.current,prog.legacyEarned,prog.ruleVersion=tier,earned,earned,2
        end
    end
end

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
        showToast         = true,
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
        xpRequired    = 93,
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
    streak       = { current = 0, best = 0, lastLogin = 0 },
    challenges   = { daily = {}, weekly = {}, history = { completedTotal = 0, goldEarned = 0 } },
    tavernGold   = { balance = 0, lifetime = 0, log = {}, lastFirstGameDay = 0 },
    toastAnchor  = { x = 0, y = -200 },
    gotdAnchor   = { x = 0, y = -220 },
    windowPos    = nil,   -- gespeicherte Fensterposition (wird beim Verschieben gefüllt)
    dev          = { devMode = false },
}

-- ============================================================
-- INITIALIZE
-- ============================================================

-- Pflichtcontainer, die InitializeDB selbst vor den Migrationen indiziert.
-- Nil bleibt „fehlend“ und wird danach wie bisher ergänzt.
local STRUCTURAL_CONTAINERS = {
    { key = "achievements", path = "achievements" },
    { key = "challenges", path = "challenges" },
}

local NESTED_CONTAINERS = {
    { parent = "achievements", key = "unlocked", path = "achievements.unlocked" },
    { parent = "achievements", key = "progress", path = "achievements.progress" },
    { parent = "challenges", key = "history", path = "challenges.history" },
}

-- Nur wenn der gespeicherte Stand die betreffende Migration noch ausführt.
-- Die Schwellen folgen den Vergleichen in _RunMigrations.
local MIGRATION_CONTAINERS = {
    { versionBelow = 10, key = "gameSettings", path = "gameSettings" },
    { versionBelow = 10, key = "leaderboard", path = "leaderboard" },
    { versionBelow = 7, key = "favorites", path = "favorites" },
    { versionBelow = 7, key = "hiddenGames", path = "hiddenGames" },
    { versionBelow = 5, key = "settings", path = "settings" },
}

local function PendingVersion(storedVersion)
    if type(storedVersion) ~= "number" then return 0 end
    return storedVersion
end

local function NoteWrongType(faults, parent, key, path)
    local value = parent[key]
    if value == nil or type(value) == "table" then return end
    faults[#faults + 1] = { path = path, luaType = type(value) }
end

-- Steht unterhalb bei den Migrationshelfern. Muss vor dem ersten Schreibzugriff laufen.
local CollectScoreMigrationFaults

local function CollectStructureFaults(db, storedVersion)
    local faults = {}
    local pending = PendingVersion(storedVersion)
    for i = 1, #STRUCTURAL_CONTAINERS do
        local spec = STRUCTURAL_CONTAINERS[i]
        NoteWrongType(faults, db, spec.key, spec.path)
    end
    for i = 1, #NESTED_CONTAINERS do
        local spec = NESTED_CONTAINERS[i]
        local parent = db[spec.parent]
        if type(parent) == "table" then
            NoteWrongType(faults, parent, spec.key, spec.path)
        end
    end
    for i = 1, #MIGRATION_CONTAINERS do
        local spec = MIGRATION_CONTAINERS[i]
        if pending < spec.versionBelow then
            NoteWrongType(faults, db, spec.key, spec.path)
        end
    end
    CollectScoreMigrationFaults(db, pending, faults)
    return faults
end

function P:_RejectDB(faults)
    self.dbReady = false
    self.initFault = faults
    local parts = {}
    for i = 1, #faults do
        parts[i] = faults[i].path .. " (" .. faults[i].luaType .. ")"
    end
    GH_LogError("Persistence", "DB-Prüfung abgebrochen, Original bleibt: " .. table.concat(parts, ", "))
end

function P:InitializeDB()
    self.dbReady = false
    self.initFault = nil

    -- Nil ist Erstanlage. Jeder andere Nicht-Tabelle-Wert bleibt unangetastet.
    if ArcadiaNexusDB == nil then
        ArcadiaNexusDB = {}
    elseif type(ArcadiaNexusDB) ~= "table" then
        self:_RejectDB({ { path = "ArcadiaNexusDB", luaType = type(ArcadiaNexusDB) } })
        return false
    end

    -- Vor den Defaults. Eine fehlende Angabe ist Altbestand, keine aktuelle Version.
    local storedVersion = ArcadiaNexusDB.schemaVersion
    local faults = CollectStructureFaults(ArcadiaNexusDB, storedVersion)
    if #faults > 0 then
        self:_RejectDB(faults)
        return false
    end

    -- Fehlende Top-Level-Keys auffüllen (idempotent).
    -- schemaVersion setzt erst der Abschluss nach den Migrationen.
    for key, default in pairs(DB_DEFAULTS) do
        if key ~= "schemaVersion" and ArcadiaNexusDB[key] == nil then
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

    -- Migrationen ausführen. Nur die vorher gesicherte Angabe, nicht den Default.
    self:_RunMigrations(storedVersion)
    -- Repeat the scoped cleanup even for restored current-schema backups.
    if ArcadiaNexus.RetiredContent then ArcadiaNexus.RetiredContent:CleanDB(ArcadiaNexusDB) end

    -- Schema-Version aktualisieren
    ArcadiaNexusDB.schemaVersion = CURRENT_SCHEMA
    self.dbReady = true

    GH_LogInfo("Persistence", "DB initialisiert (Schema v" .. CURRENT_SCHEMA .. ")")
    return true
end

-- ============================================================
-- MIGRATIONEN
-- ============================================================

function P:_RunMigrations(storedVersion)
    local dbVersion = storedVersion
    if type(dbVersion) ~= "number" then dbVersion = 0 end

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
    if dbVersion < 9 and ArcadiaNexus.RetiredContent then
        ArcadiaNexus.RetiredContent:CleanDB(ArcadiaNexusDB)
        GH_LogInfo("Persistence", "Migration v8 -> v9: entferntes Spiel bereinigt; Erfolge erhalten")
    end

    -- Schema v9 → v10: verbliebene Alt-Schlüssel, auch wenn der Stand schon 9 trägt.
    if dbVersion < 10 then
        self:_RepairLegacyResidue()
        GH_LogInfo("Persistence", "Migration v9 -> v10: verbliebene Alt-Schlüssel geprüft")
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

local RS_TIME_FACTORS = { easy = 1.0, normal = 1.5, hard = 2.0 }
local function ReactionStrikeScore(diff, ms)
    local factor = RS_TIME_FACTORS[diff] or 1.0
    return math.floor(math.max(0, 1000 - ms) * factor)
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

    -- hs_<diff> Pattern (AlienDefense, BlockBreaker)
    local hsGames = { "ALIENDEFENSE", "BLOCKBREAKER" }
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
        for diff, ms in pairs(rs.bestMs) do
            if ms and ms > 0 then
                mergeScore("REACTIONSTRIKE", diff, ReactionStrikeScore(diff, ms))
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
-- v10: Verbliebene Alt-Schlüssel nachziehen
-- Arbeitet auf einer Kopie. Die Sicherung bleibt nach gelungener Übernahme.
-- ============================================================

local SETTINGS_ALIASES = {
    { old = "Snake", new = "SNAKE" },
    { old = "AlienDefense", new = "ALIENDEFENSE" },
    { old = "Battleship", new = "BATTLESHIP" },
    { old = "BlockBreaker", new = "BLOCKBREAKER" },
    { old = "Chess", new = "CHESS" },
    { old = "LightsOut", new = "LIGHTSOUT" },
    { old = "Ludo", new = "LOA" },
    { old = "LUDO", new = "LOA" },
    { old = "Memory", new = "MEMORY" },
    { old = "Minesweeper", new = "MINESWEEPER" },
    { old = "Nonogram", new = "NONOGRAM" },
    { old = "ReactionStrike", new = "REACTIONSTRIKE" },
    { old = "SimonSays", new = "SIMONSAYS" },
    { old = "Sudoku", new = "SUDOKU" },
    { old = "VierGewinnt", new = "CONNECT4" },
}

local ROOT_ALIASES = {
    { old = "WhackAMole", new = "WHACKAMOLE" },
    { old = "Tetris", new = "TETRIS" },
    { old = "Mastermind", new = "MASTERMIND" },
    { old = "Hangman", new = "HANGMAN" },
}

-- Punktezahlen, deren heutige Bestenliste eine andere Wertung führt.
local LEGACY_SCORE_GAMES = {
    ALIENDEFENSE = true, BLOCKBREAKER = true, BLOCKDROP = true,
    GOBLINBLAST = true, CODEBREAKER = true, SUDOKU = true,
    MINESWEEPER = true, ARCADIASECHO = true, BUBBLESHOOTER = true,
}

local function FiniteScore(value)
    return type(value) == "number" and value > 0 and value == value and value < math.huge
end

local function RankValue(better)
    return function(scores, runs, value)
        if not FiniteScore(value) then return false end
        for _, existing in ipairs(scores) do
            if existing == value then return false end
        end
        local records = {}
        for i, score in ipairs(scores) do
            records[#records + 1] = {
                score = score,
                runId = runs and runs[i] or false,
                kept = true,
            }
        end
        records[#records + 1] = { score = value, runId = false, kept = false }
        table.sort(records, function(a, b)
            if a.score == b.score then return a.kept and not b.kept end
            return better(a.score, b.score)
        end)
        local admitted = false
        for i = 1, math.min(3, #records) do
            if not records[i].kept then admitted = true end
        end
        if not admitted then return false end
        for i = #scores, 1, -1 do scores[i] = nil end
        for i = 1, math.min(3, #records) do scores[i] = records[i].score end
        if runs then
            for i = #runs, 1, -1 do runs[i] = nil end
            for i = 1, math.min(3, #records) do runs[i] = records[i].runId end
        end
        return true
    end
end

local InsertHigher = RankValue(function(a, b) return a > b end)
local InsertLower = RankValue(function(a, b) return a < b end)

local function BoardEntry(db, gameId, difficulty)
    db.leaderboard = db.leaderboard or {}
    local board = db.leaderboard
    board[gameId] = board[gameId] or {}
    local key = difficulty or "default"
    local entry = board[gameId][key]
    if type(entry) ~= "table" then
        entry = { highscores = {}, wins = 0, losses = 0, draws = 0 }
        board[gameId][key] = entry
    end
    if type(entry.highscores) ~= "table" then entry.highscores = {} end
    return entry
end

local function KeepScore(db, gameId, difficulty, value, mode)
    if not FiniteScore(value) then return false end
    local entry = BoardEntry(db, gameId, difficulty)
    if mode == "legacy" then
        if type(entry.legacyHighscores) ~= "table" then entry.legacyHighscores = {} end
        return InsertHigher(entry.legacyHighscores, nil, value)
    end
    if mode == "time" then
        P:NormalizeReactionEntry(entry)
        if type(entry.bestTimes) ~= "table" then entry.bestTimes = {} end
        return InsertLower(entry.bestTimes, nil, value)
    end
    local runs = type(entry.highscoreRuns) == "table" and entry.highscoreRuns or nil
    return InsertHigher(entry.highscores, runs, value)
end

local function ScoreMode(gameId)
    if gameId == "REACTIONSTRIKE" then return "time" end
    if LEGACY_SCORE_GAMES[gameId] then return "legacy" end
    return "current"
end

-- Dieselbe Zielentscheidung wie AbsorbKnownScore. emit(spiel, schwierigkeit, modus, punkt).
-- Rückgabe: erkannt, danach löschbar.
local function EachKeptScore(gameId, field, value, emit)
    local mode = ScoreMode(gameId)
    if gameId == "2048" and field == "_bestScore" then
        if FiniteScore(value) then emit("2048", "default", "current", value) end
        return true, FiniteScore(value)
    end
    if gameId == "SNAKE" then
        local difficulty = field == "highscoreEasy" and "easy"
            or field == "highscoreNormal" and "normal"
            or field == "highscoreHard" and "hard"
        if difficulty then
            if FiniteScore(value) then emit("SNAKE", difficulty, "current", value) end
            return true, FiniteScore(value)
        end
    end
    if field == "hs_easy" or field == "hs_normal" or field == "hs_hard" then
        if FiniteScore(value) then emit(gameId, field:sub(4), mode, value) end
        return true, FiniteScore(value)
    end
    if field == "highScore" then
        if FiniteScore(value) then emit(gameId, "default", mode, value) end
        return true, FiniteScore(value)
    end
    if type(field) == "string" and field:sub(1, 5) == "top3_" and type(value) == "table" then
        local clearable = true
        for _, score in ipairs(value) do
            if FiniteScore(score) then
                emit(gameId, field:sub(6), mode, score)
            else
                clearable = false
            end
        end
        return true, clearable
    end
    if field == "bestMs" and type(value) == "table" then
        local clearable = true
        for difficulty, ms in pairs(value) do
            if type(difficulty) == "string" and FiniteScore(ms) then
                emit("REACTIONSTRIKE", difficulty, "time", ms)
            else
                clearable = false
            end
        end
        return true, clearable
    end
    return false, false
end

-- Liest nur. Lehnt Zielcontainer ab, die eine noch anstehende Highscore-Migration
-- indizieren oder durch {} ersetzen würde. Nil bleibt der bestehende Ergänzungspfad.
local V6_PLAIN_SCORES = {
    SNAKE = {
        { "highscoreEasy", "easy" },
        { "highscoreNormal", "normal" },
        { "highscoreHard", "hard" },
    },
    ["2048"] = { { "_bestScore", "default" } },
    ALIENDEFENSE = {
        { "hs_easy", "easy" }, { "hs_normal", "normal" }, { "hs_hard", "hard" },
    },
    BLOCKBREAKER = {
        { "hs_easy", "easy" }, { "hs_normal", "normal" }, { "hs_hard", "hard" },
    },
    GOBLINBLAST = { { "highScore", "default" } },
}

local REPAIR_SCORE_FIELDS = {
    SNAKE = { "highscoreEasy", "highscoreNormal", "highscoreHard" },
    ALIENDEFENSE = { "hs_easy", "hs_normal", "hs_hard" },
    BLOCKBREAKER = { "hs_easy", "hs_normal", "hs_hard" },
    GOBLINBLAST = { "highScore" },
    ARGUSORBDEFENSE = { "top3_easy", "top3_normal", "top3_hard" },
    REACTIONSTRIKE = { "bestMs" },
}

CollectScoreMigrationFaults = function(db, pending, faults)
    if pending >= 10 then return end
    local seen = {}
    local function add(path, value)
        if seen[path] then return end
        seen[path] = true
        faults[#faults + 1] = { path = path, luaType = type(value) }
    end

    local targets, queued = {}, {}
    local function queue(gameId, difficulty, mode, createsHighscores)
        if type(difficulty) ~= "string" or difficulty == "" then return end
        local id = gameId .. "\0" .. difficulty .. "\0" .. mode
        if queued[id] then
            if not createsHighscores then
                for n = 1, #targets do
                    if targets[n].id == id then targets[n].createsHighscores = false end
                end
            end
            return
        end
        queued[id] = true
        targets[#targets + 1] = {
            id = id,
            gameId = gameId,
            difficulty = difficulty,
            mode = mode,
            createsHighscores = createsHighscores and true or false,
        }
    end

    local function queueAbsorb(gameId, field, value, createsHighscores)
        EachKeptScore(gameId, field, value, function(target, difficulty, mode)
            queue(target, difficulty, mode, createsHighscores)
        end)
    end

    -- V6 löscht diese Felder, bevor die V10-Reparatur sie sieht.
    local function V6Consumes(gameId, field, value)
        if pending >= 6 or not value or value == false then return false end
        if type(value) == "number" and value > 0 then
            if gameId == "SNAKE" and (field == "highscoreEasy" or field == "highscoreNormal" or field == "highscoreHard") then return true end
            if gameId == "2048" and field == "_bestScore" then return true end
            if (gameId == "ALIENDEFENSE" or gameId == "BLOCKBREAKER") and (field == "hs_easy" or field == "hs_normal" or field == "hs_hard") then return true end
            if gameId == "GOBLINBLAST" and field == "highScore" then return true end
        end
        if gameId == "ARGUSORBDEFENSE" and type(field) == "string" and field:sub(1, 5) == "top3_" then return true end
        if gameId == "REACTIONSTRIKE" and field == "bestMs" then return true end
        return false
    end

    if pending < 6 and type(db.gameSettings) == "table" then
        local gs = db.gameSettings
        local view = gs
        if pending < 2 then
            view = {}
            for key, value in pairs(gs) do view[key] = value end
            local renames = {
                { old = "Snake", new = "SNAKE" },
                { old = "AlienDefense", new = "ALIENDEFENSE" },
                { old = "BlockBreaker", new = "BLOCKBREAKER" },
                { old = "ReactionStrike", new = "REACTIONSTRIKE" },
            }
            for i = 1, #renames do
                local spec = renames[i]
                local source = gs[spec.old]
                local dest = gs[spec.new]
                if source and (dest == nil or type(dest) ~= "table") then
                    if type(source) ~= "table" then
                        add("gameSettings." .. spec.old, source)
                    elseif dest ~= nil then
                        add("gameSettings." .. spec.new, dest)
                    else
                        view[spec.new] = source
                    end
                end
            end
        end
        local function bucketOrFault(gameId)
            local bucket = view[gameId]
            if bucket == nil or bucket == false then return nil end
            if type(bucket) ~= "table" then
                add("gameSettings." .. gameId, bucket)
                return nil
            end
            return bucket
        end
        for gameId, fields in pairs(V6_PLAIN_SCORES) do
            local bucket = bucketOrFault(gameId)
            if bucket then
                for i = 1, #fields do
                    local field, difficulty = fields[i][1], fields[i][2]
                    local value = bucket[field]
                    if value ~= nil and value ~= false and type(value) ~= "number" then
                        add("gameSettings." .. gameId .. "." .. field, value)
                    elseif type(value) == "number" and value > 0 then
                        queue(gameId, difficulty, "current", false)
                    end
                end
            end
        end
        local aod = bucketOrFault("ARGUSORBDEFENSE")
        if aod then
            for _, diff in ipairs({ "easy", "normal", "hard" }) do
                local field = "top3_" .. diff
                local list = aod[field]
                local path = "gameSettings.ARGUSORBDEFENSE." .. field
                if list ~= nil and list ~= false and type(list) ~= "table" then
                    add(path, list)
                elseif type(list) == "table" then
                    local used = false
                    for index, score in ipairs(list) do
                        if score ~= nil and score ~= false and type(score) ~= "number" then
                            add(path .. "[" .. index .. "]", score)
                        elseif type(score) == "number" and score > 0 then
                            used = true
                        end
                    end
                    if used then queue("ARGUSORBDEFENSE", diff, "current", false) end
                end
            end
        end
        local reaction = bucketOrFault("REACTIONSTRIKE")
        if reaction then
            local best = reaction.bestMs
            if best ~= nil and best ~= false and type(best) ~= "table" then
                add("gameSettings.REACTIONSTRIKE.bestMs", best)
            elseif type(best) == "table" then
                for diff, ms in pairs(best) do
                    if ms ~= nil and ms ~= false and type(ms) ~= "number" then
                        local key = type(diff) == "string" and diff or tostring(diff)
                        add("gameSettings.REACTIONSTRIKE.bestMs." .. key, ms)
                    elseif type(diff) == "string" and type(ms) == "number" and ms > 0
                        and ReactionStrikeScore(diff, ms) > 0 then
                        queue("REACTIONSTRIKE", diff:lower(), "current", false)
                    end
                end
            end
        end
    end

    if pending < 3 and db["2048_BestScore"] and type(db.gameSettings) == "table" then
        local slot = db.gameSettings["2048"]
        if slot ~= nil and type(slot) ~= "table" then
            add("gameSettings.2048", slot)
        end
    end
    if FiniteScore(db["2048_BestScore"]) then
        queue("2048", "default", "current", pending >= 6)
    end
    local gs = type(db.gameSettings) == "table" and db.gameSettings or nil
    if gs then
        local t2048 = gs["2048"]
        if type(t2048) == "table" and FiniteScore(t2048._bestScore) then
            queue("2048", "default", "current", pending >= 6)
        end
        for i = 1, #SETTINGS_ALIASES do
            local alias = SETTINGS_ALIASES[i]
            local source = gs[alias.old]
            if type(source) == "table" then
                local slot = gs[alias.new]
                local movedBeforeV6 = pending < 2 and (slot == nil or type(slot) ~= "table")
                if not movedBeforeV6 then
                    if slot ~= nil and type(slot) ~= "table" then
                        add("gameSettings." .. alias.new, slot)
                    end
                    for field, value in pairs(source) do
                        queueAbsorb(alias.new, field, value, true)
                    end
                end
            end
        end
        for gameId, fields in pairs(REPAIR_SCORE_FIELDS) do
            local settings = gs[gameId]
            if type(settings) == "table" then
                for i = 1, #fields do
                    local field = fields[i]
                    local value = settings[field]
                    if value ~= nil and not V6Consumes(gameId, field, value) then
                        queueAbsorb(gameId, field, value, true)
                    end
                end
            end
        end
    end
    for i = 1, #ROOT_ALIASES do
        local alias = ROOT_ALIASES[i]
        local source = db[alias.old]
        if type(source) == "table" then
            if gs then
                local slot = gs[alias.new]
                if slot ~= nil and type(slot) ~= "table" then
                    add("gameSettings." .. alias.new, slot)
                end
            end
            for field, value in pairs(source) do
                queueAbsorb(alias.new, field, value, true)
            end
        end
    end
    if type(db.leaderboard) == "table" and type(db.leaderboard.LUDO) == "table" then
        for difficulty, entry in pairs(db.leaderboard.LUDO) do
            if type(difficulty) == "string" and type(entry) == "table" and type(entry.highscores) == "table" then
                for _, score in ipairs(entry.highscores) do
                    if FiniteScore(score) then
                        queue("LOA", difficulty, "legacy", true)
                        break
                    end
                end
            end
        end
    end

    -- v7 benennt LUDO direkt um, auch ohne Score: `if source and not dest`.
    -- false ist der einzige vorhandene Wert, den `not` als fehlend behandelt.
    if pending < 7 then
        local function renameFalse(parent, path)
            if type(parent) ~= "table" then return end
            if parent.LUDO and parent.LOA == false then
                add(path, false)
            end
        end
        renameFalse(db.gameSettings, "gameSettings.LOA")
        renameFalse(db.leaderboard, "leaderboard.LOA")
    end

    if type(db.leaderboard) ~= "table" then return end
    for i = 1, #targets do
        local target = targets[i]
        local game = db.leaderboard[target.gameId]
        local gamePath = "leaderboard." .. target.gameId
        if game ~= nil and type(game) ~= "table" then
            add(gamePath, game)
        elseif type(game) == "table" then
            local entry = game[target.difficulty]
            local entryPath = gamePath .. "." .. target.difficulty
            if entry ~= nil and type(entry) ~= "table" then
                add(entryPath, entry)
            elseif type(entry) == "table" then
                local function list(field, checkItems, required)
                    local value = entry[field]
                    local path = entryPath .. "." .. field
                    if value == nil then
                        if required then add(path, nil) end
                        return
                    end
                    if type(value) ~= "table" then
                        add(path, value)
                        return
                    end
                    if not checkItems then return end
                    for index, item in ipairs(value) do
                        if type(item) ~= "number" then
                            add(path .. "[" .. index .. "]", item)
                        end
                    end
                end
                -- V6 fügt in eine vorhandene Schwierigkeit ein und legt highscores
                -- dabei nicht an. BoardEntry ergänzt eine fehlende Liste.
                list("highscores", target.mode ~= "legacy", not target.createsHighscores)
                if target.mode == "legacy" or target.mode == "time" then
                    list("legacyHighscores", true)
                end
                if target.mode == "time" then
                    list("bestTimes", true)
                end
            end
        end
    end
end

-- Rückgabe: Feld erkannt, Quelle danach löschbar.
local function AbsorbKnownScore(db, gameId, field, value)
    return EachKeptScore(gameId, field, value, function(target, difficulty, mode, score)
        KeepScore(db, target, difficulty, score, mode)
    end)
end

local function MergeSettings(db, bucket, oldKey, gameId)
    local source = bucket[oldKey]
    if type(source) ~= "table" then return end
    bucket[gameId] = type(bucket[gameId]) == "table" and bucket[gameId] or {}
    local target = bucket[gameId]
    local drop = true
    for field, value in pairs(source) do
        local recognized, clearable = AbsorbKnownScore(db, gameId, field, value)
        if recognized then
            if not clearable then drop = false end
        elseif target[field] == nil then
            target[field] = P:_DeepCopy(value)
        end
    end
    if drop then bucket[oldKey] = nil end
end

local function RenameId(list, oldId, newId)
    if type(list) ~= "table" then return end
    local hasNew = false
    for _, id in ipairs(list) do
        if id == newId then hasNew = true end
    end
    for i = #list, 1, -1 do
        if list[i] == oldId then
            if hasNew then table.remove(list, i) else list[i] = newId; hasNew = true end
        end
    end
end

local function MovePrefixed(tbl, oldPrefix, newPrefix, backup)
    if type(tbl) ~= "table" then return end
    local pending = {}
    for key, value in pairs(tbl) do
        if type(key) == "string" and key:sub(1, #oldPrefix) == oldPrefix then
            pending[#pending + 1] = key
            backup[key] = P:_DeepCopy(value)
        end
    end
    for _, key in ipairs(pending) do
        local renamed = newPrefix .. key:sub(#oldPrefix + 1)
        if tbl[renamed] == nil then tbl[renamed] = tbl[key] end
        tbl[key] = nil
    end
end

function P:_ApplyLegacyRepair(db)
    local backup = {}
    local found = false
    local function note(group, key, value)
        found = true
        backup[group] = backup[group] or {}
        backup[group][key] = self:_DeepCopy(value)
    end

    if db["2048_BestScore"] ~= nil then
        note("root", "2048_BestScore", db["2048_BestScore"])
        if FiniteScore(db["2048_BestScore"]) then
            KeepScore(db, "2048", "default", db["2048_BestScore"], "current")
            db["2048_BestScore"] = nil
        end
    end

    db.gameSettings = type(db.gameSettings) == "table" and db.gameSettings or {}
    if type(db.gameSettings["2048"]) == "table" and db.gameSettings["2048"]._bestScore ~= nil then
        note("gameSettings", "2048._bestScore", db.gameSettings["2048"]._bestScore)
        if FiniteScore(db.gameSettings["2048"]._bestScore) then
            KeepScore(db, "2048", "default", db.gameSettings["2048"]._bestScore, "current")
            db.gameSettings["2048"]._bestScore = nil
        end
    end

    for _, alias in ipairs(SETTINGS_ALIASES) do
        if db.gameSettings[alias.old] ~= nil then
            note("gameSettings", alias.old, db.gameSettings[alias.old])
            if type(db.gameSettings[alias.old]) == "table" then
                MergeSettings(db, db.gameSettings, alias.old, alias.new)
            end
        end
    end

    for _, alias in ipairs(ROOT_ALIASES) do
        local source = db[alias.old]
        if type(source) == "table" then
            note("root", alias.old, source)
            db.gameSettings[alias.new] = type(db.gameSettings[alias.new]) == "table" and db.gameSettings[alias.new] or {}
            local target = db.gameSettings[alias.new]
            for field, value in pairs(source) do
                local recognized = AbsorbKnownScore(db, alias.new, field, value)
                if not recognized and target[field] == nil then
                    target[field] = self:_DeepCopy(value)
                end
            end
            db[alias.old] = nil
        end
    end

    if type(db.leaderboard) == "table" and db.leaderboard.LUDO ~= nil then
        note("leaderboard", "LUDO", db.leaderboard.LUDO)
        local source = db.leaderboard.LUDO
        if type(source) == "table" then
            local clear = true
            for difficulty, entry in pairs(source) do
                if type(difficulty) ~= "string" or type(entry) ~= "table" or type(entry.highscores) ~= "table" then
                    clear = false
                else
                    for _, score in ipairs(entry.highscores) do
                        if FiniteScore(score) then
                            KeepScore(db, "LOA", difficulty, score, "legacy")
                        else
                            clear = false
                        end
                    end
                end
            end
            if clear then db.leaderboard.LUDO = nil end
        end
    end

    if type(db.favorites) == "table" then
        for _, id in ipairs(db.favorites) do
            if id == "LUDO" then note("lists", "favorites", db.favorites); break end
        end
        RenameId(db.favorites, "LUDO", "LOA")
    end
    if type(db.hiddenGames) == "table" then
        local hidden = db.hiddenGames
        local listed = false
        for _, id in ipairs(hidden) do
            if id == "LUDO" then listed = true; break end
        end
        if hidden.LUDO ~= nil or listed then
            note("lists", "hiddenGames", hidden)
        end
        if hidden.LUDO ~= nil then
            if hidden.LOA == nil then hidden.LOA = hidden.LUDO end
            hidden.LUDO = nil
        end
        RenameId(hidden, "LUDO", "LOA")
    end

    local achievements = db.achievements
    if type(achievements) == "table" then
        local unlockedBackup, progressBackup = {}, {}
        MovePrefixed(achievements.unlocked, "LUDO_", "LOA_", unlockedBackup)
        MovePrefixed(achievements.progress, "LUDO_", "LOA_", progressBackup)
        if next(unlockedBackup) then note("achievements", "unlocked", unlockedBackup) end
        if next(progressBackup) then note("achievements", "progress", progressBackup) end
    end

    -- Bekannte Score-Felder, die noch am heutigen Settings-Schlüssel hängen.
    local residue = {
        SNAKE = { "highscoreEasy", "highscoreNormal", "highscoreHard" },
        ALIENDEFENSE = { "hs_easy", "hs_normal", "hs_hard" },
        BLOCKBREAKER = { "hs_easy", "hs_normal", "hs_hard" },
        GOBLINBLAST = { "highScore" },
        ARGUSORBDEFENSE = { "top3_easy", "top3_normal", "top3_hard" },
        REACTIONSTRIKE = { "bestMs" },
    }
    for gameId, fields in pairs(residue) do
        local settings = db.gameSettings[gameId]
        if type(settings) == "table" then
            for _, field in ipairs(fields) do
                if settings[field] ~= nil then
                    note("gameSettings", gameId .. "." .. field, settings[field])
                    local recognized, clearable = AbsorbKnownScore(db, gameId, field, settings[field])
                    if recognized and clearable then settings[field] = nil end
                end
            end
        end
    end

    if not found then return nil end
    return backup
end

function P:_RepairLegacyResidue()
    local live = ArcadiaNexusDB
    local copy = self:_DeepCopy(live)
    local backup
    local ok, err = pcall(function()
        backup = self:_ApplyLegacyRepair(copy)
        if self._repairProbe then self:_repairProbe() end
        if backup then copy.schemaRepair = backup end
    end)
    if not ok then error(err) end
    for key in pairs(live) do live[key] = nil end
    for key, value in pairs(copy) do live[key] = value end
end

-- ============================================================
-- HELPER: GAME SETTINGS ACCESS
-- ============================================================

--- Stellt sicher, dass ArcadiaNexusDB und gameSettings existieren.
function P:_EnsureDB()
    if not self.dbReady then return end
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
    if not self.dbReady then return {} end
    if ArcadiaNexus.RetiredContent and ArcadiaNexus.RetiredContent:IsGame(gameID) then return {} end
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
    if not self.dbReady then return end
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
