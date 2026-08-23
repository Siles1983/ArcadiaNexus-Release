--[[
    ArcadiaNexus – ChallengeManager
    Core/ChallengeManager.lua
    Verwaltet Daily/Weekly Challenges und Spiel des Tages.
    Gleicher Seed = gleiche Challenges für alle Spieler täglich.
]]

local CM = {}
ArcadiaNexus.ChallengeManager = CM

-- ============================================================
-- CHALLENGE-POOL
-- Format: { id, type, gameId, title_de, title_en, desc_de, desc_en,
--           goal, metric, reward={xp,gold} }
-- metric: "score"|"wins"|"gamesPlayed"|"highscore"
-- ============================================================
local DAILY_POOL = {
    -- EINFACH
    { id="d_play1",      diff="EASY",   gameId=nil,         title_de="Spieler des Tages",    title_en="Player of the Day",
      desc_de="Spiele 1x ein beliebiges Spiel",              desc_en="Play any game 1 time",
      goal=1,  metric="gamesPlayed",  reward={xp=20,  gold=1} },

    { id="d_ttt_win",    diff="EASY",   gameId="TICTACTOE", title_de="Drei in einer Reihe",  title_en="Three in a Row",
      desc_de="Gewinne 1x TicTacToe",                        desc_en="Win 1 game of TicTacToe",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_snake500",   diff="EASY",   gameId="SNAKE",     title_de="Schlangen-Anfänger",   title_en="Snake Beginner",
      desc_de="Erreiche 500 Punkte in Snake",                 desc_en="Reach 500 points in Snake",
      goal=500, metric="score",       reward={xp=25,  gold=2} },

    { id="d_memory_win", diff="EASY",   gameId="MEMORY",    title_de="Gutes Gedächtnis",     title_en="Good Memory",
      desc_de="Gewinne 1x Memory",                            desc_en="Win 1 game of Memory",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    -- MITTEL
    { id="d_win3",       diff="MEDIUM", gameId=nil,         title_de="Siegesserie",          title_en="Winning Streak",
      desc_de="Gewinne 3x beliebige Spiele",                  desc_en="Win 3 games of any type",
      goal=3,  metric="wins",         reward={xp=40,  gold=3} },

    { id="d_match3_1500",diff="MEDIUM", gameId="MATCH3",    title_de="Match-Meister",        title_en="Match Master",
      desc_de="Erreiche 1500 Punkte in Match-3",              desc_en="Reach 1500 points in Match-3",
      goal=1500, metric="score",      reward={xp=50,  gold=3} },

    { id="d_hard_win",   diff="MEDIUM", gameId=nil,         title_de="Herausforderung",      title_en="Challenge Accepted",
      desc_de="Gewinne 1x auf Schwer",                        desc_en="Win 1 game on Hard",
      goal=1,  metric="wins_hard",    reward={xp=50,  gold=5} },

    { id="d_tetris1000", diff="MEDIUM", gameId="TETRIS",    title_de="Block-Künstler",       title_en="Block Artist",
      desc_de="Erreiche 1000 Punkte in Tetris",               desc_en="Reach 1000 points in Tetris",
      goal=1000, metric="score",      reward={xp=45,  gold=4} },

    -- SCHWER
    { id="d_win5",       diff="HARD",   gameId=nil,         title_de="Unaufhaltsam",         title_en="Unstoppable",
      desc_de="Gewinne 5x beliebige Spiele",                  desc_en="Win 5 games of any type",
      goal=5,  metric="wins",         reward={xp=75,  gold=8} },

    { id="d_topscore",   diff="HARD",   gameId=nil,         title_de="Rekordbrecher",        title_en="Record Breaker",
      desc_de="Erreiche deinen Highscore in einem Spiel",     desc_en="Beat your highscore in any game",
      goal=1,  metric="highscore",    reward={xp=80,  gold=10} },

    { id="d_2hard_nodeath",diff="HARD", gameId=nil,         title_de="Unbesiegbar",          title_en="Invincible",
      desc_de="Gewinne 2x auf Schwer ohne Niederlage dazwischen", desc_en="Win 2 Hard games without a loss in between",
      goal=2,  metric="wins_hard_nodeath", reward={xp=100, gold=15} },

    { id="d_play5",      diff="HARD",   gameId=nil,         title_de="Marathon-Spieler",     title_en="Marathon Player",
      desc_de="Spiele 5x beliebige Spiele",                   desc_en="Play 5 games of any type",
      goal=5,  metric="gamesPlayed",  reward={xp=60,  gold=7} },
}

local WEEKLY_POOL = {
    { id="w_win10",    title_de="Wöchentlicher Sieger",    title_en="Weekly Victor",
      desc_de="Gewinne 10x beliebige Spiele",               desc_en="Win 10 games of any type",
      goal=10, metric="wins",        reward={xp=200, gold=30} },

    { id="w_5games",   title_de="Allrounder",              title_en="All-Rounder",
      desc_de="Spiele 5 verschiedene Spieltypen",            desc_en="Play 5 different game types",
      goal=5,  metric="uniqueGames", reward={xp=150, gold=25} },

    { id="w_3hs",      title_de="Highscore-Jäger",         title_en="Highscore Hunter",
      desc_de="Schlage in 3 verschiedenen Spielen deinen Highscore", desc_en="Beat your highscore in 3 different games",
      goal=3,  metric="hsGames",     reward={xp=300, gold=50} },

    { id="w_play20",   title_de="Ausdauer-Gamer",          title_en="Endurance Gamer",
      desc_de="Spiele insgesamt 20 Spiele diese Woche",      desc_en="Play 20 total games this week",
      goal=20, metric="gamesPlayed", reward={xp=180, gold=28} },
}

-- ============================================================
-- ZEITSTEMPEL-HELPERS
-- ============================================================
function CM:_GetDayTimestamp()
    -- Abrunden auf 00:00 UTC des aktuellen Tages
    local now = GetServerTime()
    return now - (now % 86400)
end

function CM:_GetWeekTimestamp()
    -- Abrunden auf Montag 00:00 UTC der aktuellen Woche
    local dayTs = self:_GetDayTimestamp()
    -- Wochentag: 0=Do (epoch), epochal: epoch day 0 = 1970-01-01 = Donnerstag
    -- Offset zum letzten Montag:
    local dayOfWeek = math.floor(dayTs / 86400) % 7  -- 0=Do,1=Fr,2=Sa,3=So,4=Mo,5=Di,6=Mi
    local offsetToMon = (dayOfWeek - 4) % 7
    return dayTs - offsetToMon * 86400
end

function CM:_DateInt()
    -- YYYYMMDD als Integer für DB-Vergleich
    local t = C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if t then
        return t.year * 10000 + t.month * 100 + t.monthDay
    end
    -- Fallback via Timestamp
    return math.floor(GetServerTime() / 86400)
end

function CM:_WeekInt()
    return math.floor(self:_GetWeekTimestamp() / 86400)
end

-- ============================================================
-- DETERMINISTISCHER SHUFFLE (ArrayUtils)
-- ============================================================
local AU = ArcadiaNexus.ArrayUtils

-- ============================================================
-- CHALLENGE-GENERIERUNG
-- ============================================================
function CM:_GenerateDailies(dayTs)
    local easy, medium, hard = {}, {}, {}
    for _, c in ipairs(DAILY_POOL) do
        if     c.diff == "EASY"   then table.insert(easy,   c)
        elseif c.diff == "MEDIUM" then table.insert(medium, c)
        elseif c.diff == "HARD"   then table.insert(hard,   c)
        end
    end
    AU.ShuffleSeeded(easy,   dayTs)
    AU.ShuffleSeeded(medium, dayTs + 1)
    AU.ShuffleSeeded(hard,   dayTs + 2)

    local result = {}
    if easy[1]   then table.insert(result, easy[1])   end
    if medium[1] then table.insert(result, medium[1]) end
    if hard[1]   then table.insert(result, hard[1])   end
    return result
end

function CM:_GenerateWeekly(weekTs)
    local pool = {}
    for _, c in ipairs(WEEKLY_POOL) do table.insert(pool, c) end
    AU.ShuffleSeeded(pool, weekTs)
    return pool[1]
end

-- ============================================================
-- INIT / RESET-CHECK
-- ============================================================
function CM:Init()
    if not ArcadiaNexusDB.challenges then
        ArcadiaNexusDB.challenges = { daily={}, weekly={}, history={ completedTotal=0, goldEarned=0 } }
    end
    local db = ArcadiaNexusDB.challenges
    if not db.history then db.history = { completedTotal=0, goldEarned=0 } end

    self:_ResetIfNeeded()
end

function CM:HandleGameResult(data)
    local ok, err = pcall(function() CM:_UpdateProgress(data) end)
    if not ok then
        GH_LogError("ChallengeManager", "HandleGameResult: " .. tostring(err))
    end
end

function CM:_ResetIfNeeded()
    local db    = ArcadiaNexusDB.challenges
    local today = self:_DateInt()
    local week  = self:_WeekInt()
    local dayTs = self:_GetDayTimestamp()
    local wkTs  = self:_GetWeekTimestamp()

    -- Daily Reset
    if not db.daily or db.daily.date ~= today then
        local defs = self:_GenerateDailies(dayTs)
        local active = {}
        for _, def in ipairs(defs) do
            table.insert(active, {
                id       = def.id,
                diff     = def.diff,
                gameId   = def.gameId,
                title_de = def.title_de,
                title_en = def.title_en,
                desc_de  = def.desc_de,
                desc_en  = def.desc_en,
                goal     = def.goal,
                metric   = def.metric,
                reward   = { xp=def.reward.xp, gold=def.reward.gold },
                progress = 0,
                claimed  = false,
            })
        end
        db.daily = { date=today, active=active }
    end

    -- Weekly Reset
    if not db.weekly or db.weekly.weekStart ~= week then
        local def = self:_GenerateWeekly(wkTs)
        if def then
            db.weekly = {
                weekStart = week,
                active    = {{
                    id       = def.id,
                    title_de = def.title_de,
                    title_en = def.title_en,
                    desc_de  = def.desc_de,
                    desc_en  = def.desc_en,
                    goal     = def.goal,
                    metric   = def.metric,
                    reward   = { xp=def.reward.xp, gold=def.reward.gold },
                    progress = 0,
                    claimed  = false,
                }},
            }
        end
        -- Wöchentliche Tracking-Sets zurücksetzen
        db._uniqueGames = {}
        db._hsGames     = {}
    end
end

-- Hard-win-streak Tracking (für wins_hard_nodeath)
local _hardWinStreak = 0

function CM:_UpdateProgress(data)
    local db = ArcadiaNexusDB.challenges
    if not db then return end

    -- Hard-win streak tracking
    if data.difficulty and data.difficulty:lower() == "hard" then
        if data.result == "WIN" then
            _hardWinStreak = _hardWinStreak + 1
        elseif data.result == "LOSS" then
            _hardWinStreak = 0
        end
    end

    -- Highscore-tracking: hat Spieler seinen eigenen Highscore geschlagen?
    -- data.newHighscore wird von ScoreManager VOR dem Eintragen gesetzt
    local beatsHighscore = data.newHighscore == true

    -- Unique Games für Weekly
    local _uniqueGames = db._uniqueGames or {}
    if data.gameId then _uniqueGames[data.gameId] = true end
    db._uniqueGames = _uniqueGames

    local _hsGames = db._hsGames or {}
    if beatsHighscore and data.gameId then _hsGames[data.gameId] = true end
    db._hsGames = _hsGames

    -- Alle aktiven Challenges (Daily + Weekly) durchlaufen
    local allActive = {}
    if db.daily and db.daily.active then
        for _, c in ipairs(db.daily.active) do table.insert(allActive, c) end
    end
    if db.weekly and db.weekly.active then
        for _, c in ipairs(db.weekly.active) do table.insert(allActive, c) end
    end

    for _, ch in ipairs(allActive) do
        if not ch.claimed then
            local m = ch.metric
            local ok = not ch.gameId or ch.gameId == data.gameId

            if m == "gamesPlayed" then
                ch.progress = ch.progress + 1

            elseif m == "wins" and data.result == "WIN" and ok then
                ch.progress = ch.progress + 1

            elseif m == "wins_hard" and data.result == "WIN"
                   and data.difficulty and data.difficulty:lower() == "hard" then
                ch.progress = ch.progress + 1

            elseif m == "score" and data.score and ok then
                ch.progress = math.max(ch.progress, data.score)

            elseif m == "highscore" and beatsHighscore then
                ch.progress = ch.progress + 1

            elseif m == "wins_hard_nodeath" and data.difficulty
                   and data.difficulty:lower() == "hard" and data.result == "WIN" then
                ch.progress = math.min(_hardWinStreak, ch.goal)

            elseif m == "uniqueGames" then
                ch.progress = 0
                for _ in pairs(_uniqueGames) do ch.progress = ch.progress + 1 end

            elseif m == "hsGames" then
                ch.progress = 0
                for _ in pairs(_hsGames) do ch.progress = ch.progress + 1 end
            end

            -- Fertig?
            if ch.progress >= ch.goal then
                pcall(function() CM:_Complete(ch) end)
            end
        end
    end

    -- UI-Refresh Signal
    ArcadiaNexus.Engine:Emit("CHALLENGE_PROGRESS", {})
end

-- ============================================================
-- CHALLENGE ABSCHLIESSEN
-- ============================================================
function CM:_Complete(ch)
    ch.claimed = true

    -- Belohnungen
    if ch.reward.xp > 0 then
        ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = ch.reward.xp })
    end
    if ch.reward.gold > 0 then
        local TG = ArcadiaNexus.TavernGold
        if TG then TG:Add(ch.reward.gold, "challenge") end
    end

    -- Statistik
    local hist = ArcadiaNexusDB.challenges.history
    if hist then
        hist.completedTotal = (hist.completedTotal or 0) + 1
        hist.goldEarned     = (hist.goldEarned or 0) + (ch.reward.gold or 0)
    end

    ArcadiaNexus.Engine:Emit("CHALLENGE_COMPLETE", ch)
end

-- ============================================================
-- SPIEL DES TAGES
-- ============================================================
function CM:GetGameOfDay()
    local dayTs = self:_GetDayTimestamp()
    local GR = ArcadiaNexus.GameRegistry
    local games = GR and GR.GetIds(GR.FILTER_REGISTRY) or {}
    if #games == 0 then return nil end
    table.sort(games)   -- Sortierung für Konsistenz

    local idx = AU.SeededIndex(#games, dayTs + 9999)
    return games[idx]
end

-- ============================================================
-- PUBLIC GETTER
-- ============================================================
function CM:GetDailies()
    local db = ArcadiaNexusDB.challenges
    return (db and db.daily and db.daily.active) or {}
end

function CM:GetWeekly()
    local db = ArcadiaNexusDB.challenges
    return (db and db.weekly and db.weekly.active) or {}
end

function CM:GetHistory()
    local db = ArcadiaNexusDB.challenges
    return (db and db.history) or { completedTotal=0, goldEarned=0 }
end

function CM:GetDaysUntilReset()
    local wkTs    = self:_GetWeekTimestamp()
    local nextMon = wkTs + 7 * 86400
    local diff    = nextMon - GetServerTime()
    return math.max(0, math.ceil(diff / 86400))
end
