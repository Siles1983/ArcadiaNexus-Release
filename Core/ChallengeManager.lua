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
-- Nur öffentliche RegisterGame-IDs. DevOnly bleibt draußen:
-- AZEROTHTRAILS, DUNGEONDEMO, AZEROTH_ASCENT, TINKERSREVENGE, AZEROTHFIGHTERS
local DAILY_POOL = {
    -- EINFACH
    { id="d_play1",      diff="EASY",   gameId=nil,         title_de="Spieler des Tages",    title_en="Player of the Day",
      desc_de="Spiele 1x ein beliebiges Spiel",              desc_en="Play any game 1 time",
      goal=1,  metric="gamesPlayed",  reward={xp=20,  gold=1} },

    { id="d_ttt_win",    diff="EASY",   gameId="TICTACTOE", title_de="Drei in einer Reihe",  title_en="Three in a Row",
      desc_de="Gewinne 1x Tic Tac Toe",                      desc_en="Win 1 game of Tic Tac Toe",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_snake500",   diff="EASY",   gameId="SNAKE",     title_de="Schlangen-Anfänger",   title_en="Snake Beginner",
      desc_de="Erreiche 500 Punkte in Snake",                 desc_en="Reach 500 points in Snake",
      goal=500, metric="score",       reward={xp=25,  gold=2} },

    { id="d_pairs_win",  diff="EASY",   gameId="ARCADIAPAIRS", title_de="Gutes Gedächtnis",   title_en="Good Memory",
      desc_de="Gewinne 1x Arcadia Pairs",                     desc_en="Win 1 game of Arcadia Pairs",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_sudoku_win", diff="EASY",   gameId="SUDOKU",    title_de="Zahlenrätsel",         title_en="Number Puzzle",
      desc_de="Gewinne 1x Sudoku",                            desc_en="Win 1 game of Sudoku",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_mines_win",  diff="EASY",   gameId="MINESWEEPER", title_de="Minenräumer",        title_en="Mine Sweeper",
      desc_de="Gewinne 1x Minesweeper",                       desc_en="Win 1 game of Minesweeper",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_hang_win",   diff="EASY",   gameId="HANGMAN",   title_de="Wortfinder",           title_en="Word Finder",
      desc_de="Gewinne 1x Galgenmännchen",                    desc_en="Win 1 game of Hangman",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_soli_win",   diff="EASY",   gameId="SOLITAIRE", title_de="Kartenleger",          title_en="Card Layer",
      desc_de="Gewinne 1x Solitaire",                         desc_en="Win 1 game of Solitaire",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_shell_win",  diff="EASY",   gameId="SHELLGAME", title_de="Scharfes Auge",        title_en="Sharp Eye",
      desc_de="Gewinne 1x Becherspiel",                       desc_en="Win 1 game of Shell Game",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_mosaic_win", diff="EASY",   gameId="MOSAICOFAZEROTH", title_de="Schiebemeister", title_en="Slide Master",
      desc_de="Gewinne 1x Mosaik von Azeroth",                desc_en="Win 1 game of Mosaic of Azeroth",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_bj_win",     diff="EASY",   gameId="BLACKJACK", title_de="Einundzwanzig",        title_en="Twenty-One",
      desc_de="Gewinne 1x Blackjack",                         desc_en="Win 1 game of Blackjack",
      goal=1,  metric="wins",         reward={xp=25,  gold=2} },

    { id="d_2048_500",   diff="EASY",   gameId="2048",      title_de="Kleine Fusion",        title_en="Small Merge",
      desc_de="Erreiche 500 Punkte in 2048",                  desc_en="Reach 500 points in 2048",
      goal=500, metric="score",       reward={xp=25,  gold=2} },

    { id="d_wam_score",  diff="EASY",   gameId="WHACKAMOLE", title_de="Maulwurfjäger",      title_en="Mole Hunter",
      desc_de="Erreiche 300 Punkte in Whack-a-Mole",          desc_en="Reach 300 points in Whack-a-Mole",
      goal=300, metric="score",       reward={xp=25,  gold=2} },

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

    { id="d_blockdrop1000", diff="MEDIUM", gameId="BLOCKDROP", title_de="Block-Künstler",    title_en="Block Artist",
      desc_de="Erreiche 1000 Punkte in BlockDrop",            desc_en="Reach 1000 points in BlockDrop",
      goal=1000, metric="score",      reward={xp=45,  gold=4} },

    { id="d_chess_win",  diff="MEDIUM", gameId="CHESS",     title_de="Brettmeister",         title_en="Board Master",
      desc_de="Gewinne 1x Schach",                            desc_en="Win 1 game of Chess",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_bg_win",     diff="MEDIUM", gameId="BACKGAMMON", title_de="Würfelglück",        title_en="Dice Luck",
      desc_de="Gewinne 1x Backgammon",                        desc_en="Win 1 game of Backgammon",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_si7_win",    diff="MEDIUM", gameId="SI7",       title_de="Geheimdienst",         title_en="Intelligence",
      desc_de="Gewinne 1x Azeroth Intelligence",              desc_en="Win 1 game of Azeroth Intelligence",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_rows_win",   diff="MEDIUM", gameId="ARCADIAROWS", title_de="Reihenleger",        title_en="Row Builder",
      desc_de="Gewinne 1x Arcadia Rows",                      desc_en="Win 1 game of Arcadia Rows",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_loa_win",    diff="MEDIUM", gameId="LOA",       title_de="Pfadfinder",           title_en="Pathfinder",
      desc_de="Gewinne 1x Ludo of Azeroth",                   desc_en="Win 1 game of Ludo of Azeroth",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_cards_win",  diff="MEDIUM", gameId="TAVERNCARDS", title_de="Kartenhändler",      title_en="Card Trader",
      desc_de="Gewinne 1x Tavernenkarten",                    desc_en="Win 1 game of Tavern Cards",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_code_win",   diff="MEDIUM", gameId="CODEBREAKER", title_de="Codeknacker",        title_en="Code Breaker",
      desc_de="Gewinne 1x Codebreaker",                       desc_en="Win 1 game of Codebreaker",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_nono_win",   diff="MEDIUM", gameId="NONOGRAM",  title_de="Pixelrätsel",          title_en="Pixel Puzzle",
      desc_de="Gewinne 1x Nonogram",                          desc_en="Win 1 game of Nonogram",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_alch_win",   diff="MEDIUM", gameId="ALCHEMISTSSORT", title_de="Alchemie",        title_en="Alchemy",
      desc_de="Gewinne 1x Alchemist's Sort",                  desc_en="Win 1 game of Alchemist's Sort",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

    { id="d_hol_win",    diff="MEDIUM", gameId="HIGHERORLOWER", title_de="Höher oder Tiefer", title_en="Higher or Lower",
      desc_de="Gewinne 1x Higher or Lower",                   desc_en="Win 1 game of Higher or Lower",
      goal=1,  metric="wins",         reward={xp=40,  gold=3} },

    { id="d_bb_800",     diff="MEDIUM", gameId="BLOCKBREAKER", title_de="Ziegelbrecher",     title_en="Brick Breaker",
      desc_de="Erreiche 800 Punkte in Block Breaker",         desc_en="Reach 800 points in Block Breaker",
      goal=800, metric="score",       reward={xp=45,  gold=4} },

    { id="d_jewels_1200",diff="MEDIUM", gameId="AZEROTHJEWELS", title_de="Juwelenjäger",    title_en="Jewel Hunter",
      desc_de="Erreiche 1200 Punkte in Azeroth Jewels",       desc_en="Reach 1200 points in Azeroth Jewels",
      goal=1200, metric="score",      reward={xp=50,  gold=4} },

    { id="d_pinball_2k", diff="MEDIUM", gameId="DARKMOON_PINBALL", title_de="Jahrmarkt",     title_en="Fairground",
      desc_de="Erreiche 2000 Punkte in Darkmoon Pinball",     desc_en="Reach 2000 points in Darkmoon Pinball",
      goal=2000, metric="score",      reward={xp=50,  gold=4} },

    { id="d_react_win",  diff="MEDIUM", gameId="REACTIONSTRIKE", title_de="Blitzreflex",     title_en="Lightning Reflex",
      desc_de="Gewinne 1x Reaction Strike",                   desc_en="Win 1 game of Reaction Strike",
      goal=1,  metric="wins",         reward={xp=45,  gold=4} },

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

    { id="d_acq_win",    diff="HARD",   gameId="AZEROTHCONQUEST", title_de="Eroberer",       title_en="Conqueror",
      desc_de="Gewinne 1x Azeroth Conquest",                  desc_en="Win 1 game of Azeroth Conquest",
      goal=1,  metric="wins",         reward={xp=70,  gold=8} },

    { id="d_shadows_win",diff="HARD",   gameId="SHADOWSCONQUEST", title_de="Schattenfeldzug", title_en="Shadow Campaign",
      desc_de="Gewinne 1x Shadows Conquest",                  desc_en="Win 1 game of Shadows Conquest",
      goal=1,  metric="wins",         reward={xp=70,  gold=8} },

    { id="d_alien_2k",   diff="HARD",   gameId="ALIENDEFENSE", title_de="Orbitwache",        title_en="Orbit Guard",
      desc_de="Erreiche 2000 Punkte in Alien Defense",        desc_en="Reach 2000 points in Alien Defense",
      goal=2000, metric="score",      reward={xp=80,  gold=8} },

    { id="d_argus_2k",   diff="HARD",   gameId="ARGUSORBDEFENSE", title_de="Argus-Verteidiger", title_en="Argus Defender",
      desc_de="Erreiche 2000 Punkte in Argus Orbit Defense",  desc_en="Reach 2000 points in Argus Orbit Defense",
      goal=2000, metric="score",      reward={xp=80,  gold=8} },

    { id="d_goblin_2k",  diff="HARD",   gameId="GOBLINBLAST", title_de="Goblin-Sprenger",    title_en="Goblin Blaster",
      desc_de="Erreiche 2000 Punkte in Goblin Blast",         desc_en="Reach 2000 points in Goblin Blast",
      goal=2000, metric="score",      reward={xp=80,  gold=8} },

    { id="d_arcane_2k",  diff="HARD",   gameId="BUBBLESHOOTER", title_de="Arkanes Sperrfeuer", title_en="Arcane Barrage",
      desc_de="Erreiche 2000 Punkte in Arcane Barrage",       desc_en="Reach 2000 points in Arcane Barrage",
      goal=2000, metric="score",      reward={xp=80,  gold=8} },

    { id="d_barrel_1k",  diff="HARD",   gameId="BARREL_BRAWL", title_de="Fasskeile",         title_en="Barrel Brawl",
      desc_de="Erreiche 1000 Punkte in Barrel Brawl",         desc_en="Reach 1000 points in Barrel Brawl",
      goal=1000, metric="score",      reward={xp=70,  gold=7} },

    { id="d_words_win",  diff="HARD",   gameId="AZEROTHWORDS", title_de="Wortschatz",        title_en="Word Hoard",
      desc_de="Gewinne 1x Azeroth Words",                     desc_en="Win 1 game of Azeroth Words",
      goal=1,  metric="wins",         reward={xp=70,  gold=7} },

    { id="d_echo_win",   diff="HARD",   gameId="ARCADIASECHO", title_de="Echo",              title_en="Echo",
      desc_de="Gewinne 1x Arcadia's Echo",                    desc_en="Win 1 game of Arcadia's Echo",
      goal=1,  metric="wins",         reward={xp=70,  gold=7} },

    { id="d_pets_win",   diff="HARD",   gameId="AZEROTHTINYGUARDIANS", title_de="Winzige Wächter", title_en="Tiny Guardians",
      desc_de="Gewinne 1x Azeroth's Tiny Guardians",          desc_en="Win 1 game of Azeroth's Tiny Guardians",
      goal=1,  metric="wins",         reward={xp=70,  gold=7} },

    { id="d_2048_2k",    diff="HARD",   gameId="2048",      title_de="Große Fusion",         title_en="Big Merge",
      desc_de="Erreiche 2048 Punkte in 2048",                 desc_en="Reach 2048 points in 2048",
      goal=2048, metric="score",      reward={xp=75,  gold=8} },
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

    { id="w_hard3",    title_de="Schwere Woche",           title_en="Hard Week",
      desc_de="Gewinne 3x auf Schwer",                      desc_en="Win 3 games on Hard",
      goal=3,  metric="wins_hard",   reward={xp=220, gold=35} },
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

-- _DateInt uses YYYYMMDD when the calendar API is available. Convert that
-- value to a consecutive day number so month and year boundaries count.
local function DaySerial(dateInt)
    if type(dateInt) ~= "number" then return nil end
    if dateInt < 10000000 then return dateInt end
    local year = math.floor(dateInt / 10000)
    local month = math.floor(dateInt / 100) % 100
    local day = dateInt % 100
    local a = math.floor((14 - month) / 12)
    local y = year + 4800 - a
    local m = month + 12 * a - 3
    return day + math.floor((153 * m + 2) / 5) + 365 * y
        + math.floor(y / 4) - math.floor(y / 100)
        + math.floor(y / 400) - 32045
end

local function AdvanceStreak(history, key, period, step)
    if type(period) ~= "number" then return end
    local streak = history[key]
    if type(streak) ~= "table" then
        streak = { current = 0, best = 0, lastPeriod = nil }
        history[key] = streak
    end
    if streak.lastPeriod == period then return end
    streak.current = (streak.lastPeriod == period - step)
        and ((streak.current or 0) + 1) or 1
    streak.best = math.max(streak.best or 0, streak.current)
    streak.lastPeriod = period
end

-- ============================================================
-- DETERMINISTISCHER SHUFFLE (ArrayUtils)
-- ============================================================
local AU = ArcadiaNexus.ArrayUtils

local function IsKnownGame(gameId)
    if gameId == nil then return true end
    local GR = ArcadiaNexus.GameRegistry
    local info = GR and GR.GetById and GR.GetById(gameId)
    return type(info) == "table" and info.devOnly ~= true
end

local function FilterKnownChallenges(pool)
    local out = {}
    for _, c in ipairs(pool) do
        if IsKnownGame(c.gameId) then
            out[#out + 1] = c
        else
            GH_LogWarn("ChallengeManager", "Challenge '" .. tostring(c.id) ..
                "' ignoriert: unbekannte gameId '" .. tostring(c.gameId) .. "'")
        end
    end
    return out
end

function CM:_HasInvalidActive()
    local db = ArcadiaNexus.StatsStore.GetChallenges()
    local function scan(list)
        if type(list) ~= "table" then return false end
        for _, ch in ipairs(list) do
            if ch and not IsKnownGame(ch.gameId) then return true end
        end
        return false
    end
    return scan(db.daily and db.daily.active) or scan(db.weekly and db.weekly.active)
end

-- ============================================================
-- CHALLENGE-GENERIERUNG
-- ============================================================
function CM:_GenerateDailies(dayTs)
    local easy, medium, hard = {}, {}, {}
    for _, c in ipairs(FilterKnownChallenges(DAILY_POOL)) do
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
    for _, c in ipairs(FilterKnownChallenges(WEEKLY_POOL)) do table.insert(pool, c) end
    AU.ShuffleSeeded(pool, weekTs)
    return pool[1]
end

-- ============================================================
-- INIT / RESET-CHECK
-- ============================================================
function CM:Init()
    ArcadiaNexus.StatsStore.GetChallenges()

    self:_ResetIfNeeded()
    if self:_HasInvalidActive() then
        GH_LogWarn("ChallengeManager", "Aktive Challenges mit unbekannter gameId – neu auslosen")
        local db = ArcadiaNexus.StatsStore.GetChallenges()
        db.daily = nil
        db.weekly = nil
        self:_ResetIfNeeded()
    end
end

function CM:HandleGameResult(data)
    local ok, err = pcall(function()
        CM:_ResetIfNeeded()
        CM:_UpdateProgress(data)
    end)
    if not ok then
        GH_LogError("ChallengeManager", "HandleGameResult: " .. tostring(err))
    end
end

function CM:_ResetIfNeeded()
    local db    = ArcadiaNexus.StatsStore.GetChallenges()
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
        db.daily = { date=today, active=active, hardWinStreak=0 }
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

function CM:_UpdateProgress(data)
    local db = ArcadiaNexus.StatsStore.GetChallenges()
    if not db then return end

    -- Die Serie gehört zum aktuellen Tageszustand und überlebt einen Reload.
    local daily = db.daily or {}
    if data.result == "LOSS" then
        daily.hardWinStreak = 0
    elseif data.result == "WIN" and type(data.difficulty) == "string"
           and data.difficulty:lower() == "hard" then
        daily.hardWinStreak = (tonumber(daily.hardWinStreak) or 0) + 1
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

            if m == "gamesPlayed" and ok then
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

            elseif m == "wins_hard_nodeath" and data.result == "LOSS" then
                ch.progress = 0

            elseif m == "wins_hard_nodeath" and type(data.difficulty) == "string"
                   and data.difficulty:lower() == "hard" and data.result == "WIN" then
                ch.progress = math.min(daily.hardWinStreak or 0, ch.goal)

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

    local db = ArcadiaNexus.StatsStore.GetChallenges()
    local hist = db.history
    if db.daily and db.daily.active then
        for _, active in ipairs(db.daily.active) do
            if active == ch then
                AdvanceStreak(hist, "dailyStreak", DaySerial(db.daily.date), 1)
                break
            end
        end
    end
    if db.weekly and db.weekly.active then
        for _, active in ipairs(db.weekly.active) do
            if active == ch then
                AdvanceStreak(hist, "weeklyStreak", db.weekly.weekStart, 7)
                break
            end
        end
    end

    -- Belohnungen
    if ch.reward.xp > 0 then
        ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = ch.reward.xp })
    end
    if ch.reward.gold > 0 then
        local TG = ArcadiaNexus.TavernGold
        if TG then TG:Add(ch.reward.gold, "challenge") end
    end

    -- Statistik
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
    self:_ResetIfNeeded()
    local db = ArcadiaNexus.StatsStore.GetChallenges()
    return (db and db.daily and db.daily.active) or {}
end

function CM:GetWeekly()
    self:_ResetIfNeeded()
    local db = ArcadiaNexus.StatsStore.GetChallenges()
    return (db and db.weekly and db.weekly.active) or {}
end

function CM:GetHistory()
    local db = ArcadiaNexus.StatsStore.GetChallenges()
    return (db and db.history) or { completedTotal=0, goldEarned=0 }
end

function CM:GetDaysUntilReset()
    local wkTs    = self:_GetWeekTimestamp()
    local nextMon = wkTs + 7 * 86400
    local diff    = nextMon - GetServerTime()
    return math.max(0, math.ceil(diff / 86400))
end
