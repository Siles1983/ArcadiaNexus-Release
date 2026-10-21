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
      SM:GetGameTotals(gameId)          → { plays, wins, losses, draws, bestScore }
      SM:GetRankedGames()               → { { gameId, plays, ... }, ... } nach Partien
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
    ArcadiaNexus.StatsStore.GetLeaderboard()
end

-- ============================================================
-- Sicherstellen dass Eintrag existiert
-- ============================================================

local function NormalizeBarrage(entry,key)
    if type(key)=="string" and key:match("^shot_") and not entry.campaignLayoutVersion then
        entry.legacyCampaignScores=entry.highscores or {}; entry.highscores={}; entry.highscoreRuns=nil
        entry.campaignLayoutVersion=3
        entry.completedLevels,entry.campaignStars=0,0
    end
end

local function NormalizeBlockdrop(entry)
    if entry.bagRuleVersion==2 then return end
    entry.legacyHighscores=entry.highscores or {}; entry.legacyHighscoreRuns=entry.highscoreRuns
    entry.legacyBestLines=entry.customStats and entry.customStats.linesCleared or 0
    entry.highscores={}; entry.highscoreRuns=nil
    if entry.customStats then entry.customStats.linesCleared=nil end
    entry.bagRuleVersion=2
end
local function RecordLegacyBlockdrop(entry,data)
    local records,found={},false
    for i,value in ipairs(entry.legacyHighscores or {}) do
        local id=(entry.legacyHighscoreRuns or {})[i]
        if id==data.runId then
            if not found then records[#records+1]={score=math.max(value,data.score),runId=id} end
            found=true
        else records[#records+1]={score=value,runId=id or false} end
    end
    data.newHighscore=data.score>((entry.legacyHighscores or {})[1] or 0)
    if not found and data.score>0 then records[#records+1]={score=data.score,runId=data.runId} end
    table.sort(records,function(a,b) return a.score>b.score end)
    entry.legacyHighscores={}; entry.legacyHighscoreRuns={}
    for i=1,math.min(3,#records) do entry.legacyHighscores[i]=records[i].score; entry.legacyHighscoreRuns[i]=records[i].runId end
    if data.stats.linesCleared then entry.legacyBestLines=math.max(entry.legacyBestLines or 0,data.stats.linesCleared) end
end

local function NormalizeBlockBreaker(entry)
    if entry.runRuleVersion==2 then return end
    entry.legacyHighscores=entry.highscores or {}
    entry.legacyWins=entry.wins or 0; entry.legacyLosses=entry.losses or 0
    entry.legacyGamesPlayed=entry.gamesPlayed or 0; entry.legacyBestLevel=entry.bestLevel or 0
    entry.legacyCustomStats=entry.customStats
    entry.highscores={}; entry.highscoreRuns=nil; entry.customStats={}
    entry.wins,entry.losses,entry.gamesPlayed,entry.bestLevel=0,0,0,0
    entry.runRuleVersion=2
end

function SM:_EnsureEntry(gameId, difficulty)
    local lb = ArcadiaNexus.StatsStore.GetLeaderboard()
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
    local entry = lb[gameId][key]
    if gameId == "CODEBREAKER" then ArcadiaNexus.StatsStore.NormalizeCodebreakerEntry(entry) end
    if gameId == "MINESWEEPER" then ArcadiaNexus.Persistence:NormalizeMinesweeperEntry(entry) end
    if gameId == "SUDOKU" then ArcadiaNexus.Persistence:NormalizeSudokuEntry(entry) end
    if gameId=="BLOCKDROP" then NormalizeBlockdrop(entry) end
    if (gameId=="BLOCKBREAKER" or gameId=="GOBLINBLAST") then NormalizeBlockBreaker(entry) end
    if gameId == "ALIENDEFENSE" then ArcadiaNexus.Persistence:NormalizeAlienDefenseEntry(entry) end
    if gameId == "ARCADIASECHO" then ArcadiaNexus.Persistence:NormalizeEchoEntry(entry) end
    if gameId == "REACTIONSTRIKE" then ArcadiaNexus.Persistence:NormalizeReactionEntry(entry) end
    if gameId=="BUBBLESHOOTER" then NormalizeBarrage(entry,key) end
    return entry
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
    if recordPlayed and data.gameId=="GOBLINBLAST" and data.legacyContinuation then
        entry.checkpointRunsPlayed=(entry.checkpointRunsPlayed or 0)+1
        local field=data.result=="WIN" and "checkpointRunsWon" or "checkpointRunsLost"
        entry[field]=(entry[field] or 0)+1
    elseif recordPlayed then
        entry.gamesPlayed = (entry.gamesPlayed or 0) + 1
        if data.result == "WIN" then
            entry.wins = (entry.wins or 0) + 1
        elseif data.result == "LOSS" then
            entry.losses = (entry.losses or 0) + 1
        elseif data.result == "DRAW" then
            entry.draws = (entry.draws or 0) + 1
        end
    end

    if data.gameId=="BLOCKDROP" and data.legacyContinuation then
        RecordLegacyBlockdrop(entry,data); return
    end
    if data.gameId == "ALIENDEFENSE" then
        entry.clearedWaves = (entry.clearedWaves or 0) + (data.wavesDelta or 0)
    end

    if data.gameId=="ARGUSORBDEFENSE" then
        entry.clearedStages=(entry.clearedStages or 0)+(data.stagesDelta or 0)
    end
    if data.gameId=="GOBLINBLAST" then
        entry.clearedStages=(entry.clearedStages or 0)+(data.stagesDelta or 0)
        if data.legacyContinuation then
            local legacy={score=data.legacyScore+data.score,runId=data.runId,stats={}}
            RecordLegacyBlockdrop(entry,legacy); data.newHighscore=false
            return
        end
        entry.levelBests=entry.levelBests or {}
        for _,perf in ipairs(data.levelPerformances) do
            local previous=entry.levelBests[perf.level]
            if not previous or perf.score>previous.score or perf.score==previous.score and perf.elapsedMs<previous.elapsedMs then
                entry.levelBests[perf.level]={score=perf.score,elapsedMs=perf.elapsedMs,runId=data.runId,ruleVersion=2}
            end
        end
    end
    if data.gameId=="BLOCKBREAKER" then
        entry.clearedStages=(entry.clearedStages or 0)+(data.stagesDelta or 0)
        local perf=data.levelPerformance
        if perf and perf.level<=100 then
            entry.levelBests=entry.levelBests or {}
            local previous=entry.levelBests[perf.level]
            if not previous or perf.score>previous.score or perf.score==previous.score and perf.elapsedMs<previous.elapsedMs then
                entry.levelBests[perf.level]={score=perf.score,elapsedMs=perf.elapsedMs,runId=data.runId,layoutVersion=2}
            end
        end
    end
    if data.gameId=="BUBBLESHOOTER" and data.playMode=="shot" then
        if not entry.campaignLayoutVersion then
            entry.legacyCampaignScores=entry.highscores; entry.highscores={}; entry.highscoreRuns=nil
            entry.campaignLayoutVersion=3
        end
        entry.levelBests=entry.levelBests or {}; local version=data.ruleVersion
        entry.levelBests[version]=entry.levelBests[version] or {}
        local bests=entry.levelBests[version]
        if data.result=="WIN" then
            local previous=bests[data.levelIndex] or {}
            data.newHighscore=not data.localReplay and data.score>(previous.score or 0)
            previous.score=math.max(previous.score or 0,data.score)
            previous.shots=math.min(previous.shots or data.stats.shotsUsed,data.stats.shotsUsed)
            previous.stars=math.max(previous.stars or 0,data.stars)
            previous.maxCombo=math.max(previous.maxCombo or 1,data.stats.maxCombo)
            previous.maxDrop=math.max(previous.maxDrop or 0,data.stats.maxDrop)
            bests[data.levelIndex]=previous
        end
        entry.completedLevels,entry.campaignStars=0,0
        for _,best in pairs(bests) do
            entry.completedLevels=entry.completedLevels+1; entry.campaignStars=entry.campaignStars+best.stars
        end
        data.skipHighscores=true
    end

    -- Höchstes erreichtes Level (stats.levelReached / waveReached / level)
    local stats = data.stats
    local levelReached = stats and (
        (data.gameId=="ARGUSORBDEFENSE" and tonumber(data.gameMode=="levels" and stats.clearedLevel or stats.clearedWave))
        or (data.gameId~="ARGUSORBDEFENSE" and tonumber(stats.clearedWave))
        or tonumber(stats.levelReached)
        or tonumber(stats.waveReached)
        or tonumber(stats.level)
    )
    if data.gameId=="GOBLINBLAST" then levelReached=stats.clearedLevel end
    if levelReached and levelReached > (entry.bestLevel or 0) then
        entry.bestLevel = levelReached
    end

    if data.gameId=="GALLYWIX" and not data.localReplay then
        entry.lastContext={category=data.category,locale=data.locale,format=data.difficulty,firstStarter=data.firstStarter}
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
    if (score > 0 or data.gameId=="WHACKAMOLE" and data.ruleVersion==2 and score==0) and not data.skipHighscores then
        local hs = entry.highscores
        -- Alten Bestwert VOR dem Eintragen merken (für ChallengeManager)
        local prevBest = hs[1] or 0
        data.newHighscore = (score > prevBest)
        if (data.gameId == "2048" or data.gameId == "CODEBREAKER" or data.gameId == "MINESWEEPER" or data.gameId == "SUDOKU" or data.gameId == "ARCADIASECHO" or data.gameId == "WHACKAMOLE" or data.gameId == "ALIENDEFENSE" or data.gameId == "ARGUSORBDEFENSE" or data.gameId == "BARREL_BRAWL" or data.gameId == "BLOCKBREAKER" or data.gameId == "BLOCKDROP" or data.gameId == "DARKMOON_PINBALL" or data.gameId == "GOBLINBLAST" or data.gameId == "SNAKE" or data.gameId == "BUBBLESHOOTER" or data.gameId == "GALLYWIX") and data.runId then
            local records, found = {}, false
            local ids = entry.highscoreRuns or {}
            for i, value in ipairs(hs) do
                if ids[i] == data.runId then
                    if not found then records[#records + 1] = { score = math.max(value, score), runId = data.runId } end
                    found = true
                else records[#records + 1] = { score = value, runId = ids[i] or false } end
            end
            if not found then records[#records + 1] = { score = score, runId = data.runId } end
            table.sort(records, function(a, b) return a.score > b.score end)
            entry.highscoreRuns = {}
            for i = 1, math.min(MAX_HIGHSCORES, #records) do
                hs[i], entry.highscoreRuns[i] = records[i].score, records[i].runId
            end
            for i = #hs, math.min(MAX_HIGHSCORES, #records) + 1, -1 do hs[i] = nil end
        else
            -- Numeric API and pre-existing writers retain their behavior. Keep
            -- metadata aligned if a legacy 2048 writer touches this entry.
            table.insert(hs, score)
            if entry.highscoreRuns then
                local records = {}
                for i, value in ipairs(hs) do records[i] = {score=value, runId=entry.highscoreRuns[i] or false} end
                table.sort(records, function(a,b) return a.score > b.score end)
                entry.highscoreRuns = {}
                for i, record in ipairs(records) do hs[i], entry.highscoreRuns[i] = record.score, record.runId end
            else table.sort(hs, function(a, b) return a > b end) end
        end
        while #hs > MAX_HIGHSCORES do
            table.remove(hs)
            if entry.highscoreRuns then table.remove(entry.highscoreRuns) end
        end
    end
    self:_RecordDeclaredMetrics(entry,data)
end

-- Separate metric lists never enter score or max-stat aggregation. Schema
-- owns eligibility, ordering and storage field. Ties keep insertion order.
function SM:_RecordDeclaredMetrics(entry,data)
    local LR=ArcadiaNexus.LeaderboardRegistry
    local schema=LR and LR.GetSchema(data.gameId)
    for _,section in ipairs(schema and schema.sections or {}) do
        if section.type=="top_scores" and section.resultField and section.field
            and (not section.result or section.result==data.result) and data.runId then
            local value=data[section.resultField]
            if type(value)=="number" and value==math.floor(value) and value>=0 and value<math.huge then
                local records=entry[section.field] or {}
                local best=records[1] and records[1].value
                data.newMetricRecords=data.newMetricRecords or {}
                data.newMetricRecords[section.field]=not data.localReplay and
                    (best==nil or (section.order=="asc" and value<best) or (section.order~="asc" and value>best))
                local found=false
                for _,record in ipairs(records) do if record.runId==data.runId then found=true end end
                if not found then records[#records+1]={value=value,runId=data.runId} end
                for i,record in ipairs(records) do record._order=i end
                table.sort(records,function(a,b)
                    if a.value==b.value then return a._order<b._order end
                    if section.order=="asc" then return a.value<b.value end
                    return a.value>b.value
                end)
                while #records>(section.count or 3) do table.remove(records) end
                for _,record in ipairs(records) do record._order=nil end
                entry[section.field]=records
            end
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
    local lb    = ArcadiaNexus.StatsStore.GetLeaderboard()
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
    if gameId=="BLOCKDROP" then NormalizeBlockdrop(lb[gameId][key]) end
    if (gameId=="BLOCKBREAKER" or gameId=="GOBLINBLAST") then NormalizeBlockBreaker(lb[gameId][key]) end
    if gameId == "ALIENDEFENSE" then ArcadiaNexus.Persistence:NormalizeAlienDefenseEntry(lb[gameId][key]) end
    if gameId=="BUBBLESHOOTER" then NormalizeBarrage(lb[gameId][key],key) end
    return lb[gameId][key]
end

-- Optionales lb reicht die bereits gelesene Tabelle innerhalb einer Abfrage weiter.
function SM:GetAllEntries(gameId, lb)
    if lb == nil then lb = ArcadiaNexus.StatsStore.GetLeaderboard() end
    if not lb or not lb[gameId] then return {} end
    local list = {}
    for _, entry in pairs(lb[gameId]) do
        if type(entry) == "table" then
            if gameId=="BLOCKDROP" then NormalizeBlockdrop(entry) end
            if (gameId=="BLOCKBREAKER" or gameId=="GOBLINBLAST") then NormalizeBlockBreaker(entry) end
            list[#list + 1] = entry
        end
    end
    return list
end

-- Gibt alle bekannten GameIDs zurück
function SM:GetAllGames()
    return ArcadiaNexus.StatsStore.GetLeaderboard()
end

function SM:GetGameTotals(gameId, lb)
    local plays, wins, losses, draws, best = 0, 0, 0, 0, 0
    for _, entry in ipairs(self:GetAllEntries(gameId, lb)) do
        local played = tonumber(entry.gamesPlayed)
        if not played or played <= 0 then
            played = (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
        end
        plays  = plays  + played
        wins   = wins   + (entry.wins or 0)
        losses = losses + (entry.losses or 0)
        draws  = draws  + (entry.draws or 0)
        for _, hs in ipairs(entry.highscores or {}) do
            if type(hs) == "number" and hs > best then
                best = hs
            end
        end
    end
    return {
        plays     = plays,
        wins      = wins,
        losses    = losses,
        draws     = draws,
        bestScore = best,
    }
end

function SM:GetRankedGames(lb)
    if lb == nil then lb = ArcadiaNexus.StatsStore.GetLeaderboard() end
    local list = {}
    if type(lb) ~= "table" then return list end
    for gameId, _ in pairs(lb) do
        local totals = self:GetGameTotals(gameId, lb)
        if totals.plays > 0 then
            totals.gameId = gameId
            list[#list + 1] = totals
        end
    end
    table.sort(list, function(a, b)
        if a.plays ~= b.plays then
            return a.plays > b.plays
        end
        return tostring(a.gameId) < tostring(b.gameId)
    end)
    return list
end

-- Bester gespeicherter Score (Highscore #1) für Spiel + Difficulty
function SM:GetBestScore(gameId, difficulty)
    local entry = self:GetScores(gameId, difficulty)
    return (entry.highscores and entry.highscores[1]) or 0
end
