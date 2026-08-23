--[[
    Gaming Hub
    Core/ScoreManager.lua
    Version: 1.0.0

    Verantwortlichkeiten:
      - Highscore-Verwaltung (Top 3 pro Spiel + Difficulty)
      - Win/Loss/Draw-Statistiken pro Spiel
      - Keine UI-Abhängigkeiten
      - Kein Spiel schreibt direkt in die DB
      - Wird von GameResultProcessor aufgerufen (nicht direkt auf GAME_RESULT)

    GAME_RESULT-Event Payload (Standard für alle Spiele):
      {
        gameId     = "TICTACTOE",   -- exakt RegisterGame.id (UPPERCASE)
        difficulty = "normal",      -- "easy"|"normal"|"hard" oder nil
        score      = 150,           -- numerischer Score (0 wenn kein Konzept)
        result     = "WIN",         -- "WIN"|"LOSS"|"DRAW"|"STATS"
        recordPlayed = true,        -- false: nur Score/Stats, kein Gespielt/W-L
        stats      = { … },         -- optional; numerisch → customStats (max)
      }

    Öffentliche API:
      SM:GetScores(gameId, difficulty)  → { highscores={}, wins=N, losses=N, draws=N, gamesPlayed=N, bestLevel=N, customStats={} }
      SM:GetBestScore(gameId, difficulty) → bester Score (Highscore #1)
      SM:GetAllGames()                  → { gameId = { difficulties = {...} } }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ScoreManager = {}

local SM = ArcadiaNexus.ScoreManager

-- ============================================================
-- Konstanten
-- ============================================================

local MAX_HIGHSCORES = 3   -- Nur Top 3 speichern

-- ============================================================
-- DB-Init
-- ============================================================

function SM:Init()
    GH_LogInfo("ScoreManager", "Leaderboard bereit")
    if not ArcadiaNexusDB.leaderboard then
        ArcadiaNexusDB.leaderboard = {}
    end
end

-- ============================================================
-- Sicherstellen dass Eintrag existiert
-- ============================================================

function SM:_EnsureEntry(gameId, difficulty)
    local lb = ArcadiaNexusDB.leaderboard
    if not lb[gameId] then
        lb[gameId] = {}
    end
    local key = difficulty or "default"
    if not lb[gameId][key] then
        lb[gameId][key] = {
            highscores = {},
            wins       = 0,
            losses     = 0,
            draws      = 0,
        }
    end
    return lb[gameId][key]
end

-- ============================================================
-- GAME_RESULT verarbeiten
-- ============================================================

function SM:HandleGameResult(data)
    if not data or not data.gameId or not data.result then return end

    -- Difficulty-Key normalisieren: "EASY"/"NORMAL"/"HARD" → "easy"/"normal"/"hard"
    -- WAM und Tetris liefern UPPERCASE, alle anderen lowercase
    local difficulty = data.difficulty
    if type(difficulty) == "string" then
        difficulty = difficulty:lower()
    end

    local entry = self:_EnsureEntry(data.gameId, difficulty)

    local recordPlayed = data.recordPlayed ~= false
    if recordPlayed then
        entry.gamesPlayed = (entry.gamesPlayed or 0) + 1
        if data.result == "WIN" then
            entry.wins = (entry.wins or 0) + 1
        elseif data.result == "LOSS" then
            entry.losses = (entry.losses or 0) + 1
        elseif data.result == "DRAW" then
            entry.draws = (entry.draws or 0) + 1
        end
    end

    -- Höchstes erreichtes Level (stats.levelReached / waveReached / level)
    local stats = data.stats
    local levelReached = stats and (
        tonumber(stats.levelReached)
        or tonumber(stats.waveReached)
        or tonumber(stats.level)
    )
    if levelReached and levelReached > (entry.bestLevel or 0) then
        entry.bestLevel = levelReached
    end

    -- Zusätzliche Statistiken aus GAME_RESULT.stats (max-Aggregation)
    if data.stats then
        entry.customStats = entry.customStats or {}
        for key, val in pairs(data.stats) do
            if key ~= "levelReached" and type(val) == "number" then
                local prev = entry.customStats[key]
                if not prev or val > prev then
                    entry.customStats[key] = val
                end
            end
        end
    end

    -- Highscore eintragen und auf Top 3 kürzen (nur positive Scores)
    local score = data.score or 0
    if score > 0 then
        local hs = entry.highscores
        -- Alten Bestwert VOR dem Eintragen merken (für ChallengeManager)
        local prevBest = hs[1] or 0
        data.newHighscore = (score > prevBest)
        table.insert(hs, score)
        table.sort(hs, function(a, b) return a > b end)
        while #hs > MAX_HIGHSCORES do
            table.remove(hs)
        end
    end
end

-- ============================================================
-- Öffentliche Abfrage-API
-- ============================================================

-- Gibt Scores für ein Spiel + Difficulty zurück
-- difficulty = nil → key "default"
function SM:GetScores(gameId, difficulty)
    -- Ebenfalls normalisieren für konsistente Abfragen
    if type(difficulty) == "string" then
        difficulty = difficulty:lower()
    end
    local key   = difficulty or "default"
    local lb    = ArcadiaNexusDB.leaderboard
    if not lb or not lb[gameId] or not lb[gameId][key] then
        return {
            highscores  = {},
            wins        = 0,
            losses      = 0,
            draws       = 0,
            gamesPlayed = 0,
            customStats = {},
        }
    end
    return lb[gameId][key]
end

function SM:GetAllEntries(gameId)
    local lb = ArcadiaNexusDB.leaderboard
    if not lb or not lb[gameId] then return {} end
    local list = {}
    for _, entry in pairs(lb[gameId]) do
        if type(entry) == "table" then
            list[#list + 1] = entry
        end
    end
    return list
end

-- Gibt alle bekannten GameIDs zurück
function SM:GetAllGames()
    return ArcadiaNexusDB.leaderboard or {}
end

-- Bester gespeicherter Score (Highscore #1) für Spiel + Difficulty
function SM:GetBestScore(gameId, difficulty)
    local entry = self:GetScores(gameId, difficulty)
    return (entry.highscores and entry.highscores[1]) or 0
end
