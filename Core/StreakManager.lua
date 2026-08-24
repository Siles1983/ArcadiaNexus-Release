--[[
    ArcadiaNexus – StreakManager
    Core/StreakManager.lua
    Verwaltet Login-Streaks und Meilenstein-Belohnungen.
    Kommuniziert ausschließlich via Events – kein direkter Modul-Aufruf.
]]

local SM = {}
ArcadiaNexus.StreakManager = SM

-- Muss VOR Init() stehen – Lua local ist erst ab Deklarationszeile sichtbar
local _firstGameGiven = false

-- Serielle Nummer eines lokalen Kalendertags (Gregorianischer Kalender).
-- GetServerTime liefert einen stabilen Unix-Zeitstempel; date("*t", ...)
-- ordnet ihn dem Kalendertag des Clients zu. Die serielle Nummer erlaubt
-- korrekte Differenzen auch über Monats-, Jahres- und Schaltjahrgrenzen.
local function GetCalendarDay(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then return nil end

    local calendar = date("*t", timestamp)
    if not calendar then return nil end

    local year  = calendar.year
    local month = calendar.month
    local day   = calendar.day
    local a = math.floor((14 - month) / 12)
    local y = year + 4800 - a
    local m = month + 12 * a - 3

    return day
        + math.floor((153 * m + 2) / 5)
        + 365 * y
        + math.floor(y / 4)
        - math.floor(y / 100)
        + math.floor(y / 400)
        - 32045
end

-- ============================================================
-- MEILENSTEINE
-- ============================================================
local MILESTONES = {
    { days=3,   xp=50,  gold=0,   title=nil,                theme=nil           },
    { days=7,   xp=0,   gold=20,  title=nil,                theme=nil           },
    { days=14,  xp=0,   gold=50,  title="Stammgast",        theme=nil           },
    { days=30,  xp=0,   gold=100, title="Nexus-Veteran",    theme=nil           },
    { days=100, xp=0,   gold=0,   title="Legende des Nexus",theme="golden_nexus"},
}

-- ============================================================
-- INIT
-- ============================================================
function SM:Init()
    -- DB sicherstellen (Fallback falls Bootstrap-Migration noch nicht lief)
    if not ArcadiaNexusDB.streak then
        ArcadiaNexusDB.streak = { current=0, best=0, lastLogin=0, claimedToday=false }
    end

    -- Erstes Spiel des Tages: +2 Gold (einmalig pro Tag)
    ArcadiaNexus.Engine:On("GAME_RESULT", function(data)
        if _firstGameGiven then return end
        local db = ArcadiaNexusDB and ArcadiaNexusDB.streak
        if not db then return end
        if db.claimedToday then return end
        db.claimedToday  = true
        _firstGameGiven  = true
        local TG = ArcadiaNexus.TavernGold
        if TG then TG:Add(2, "first_game") end
    end)
end

-- ============================================================
-- LOGIN-HANDLER — wird von Bootstrap:OnPlayerLogin() aufgerufen
-- ============================================================
function SM:OnLogin()
    local db = ArcadiaNexusDB.streak
    if not db then return end

    local now        = GetServerTime()
    local currentDay = GetCalendarDay(now)
    local lastDay    = GetCalendarDay(db.lastLogin)
    local dayDiff    = lastDay and currentDay and (currentDay - lastDay) or nil

    if dayDiff == 0 then
        -- Gleicher Kalendertag – nichts tun (Streak bleibt)
    elseif dayDiff == 1 then
        -- Direkt folgender Kalendertag: Streak fortführen
        db.current       = (db.current or 0) + 1
        db.claimedToday  = false
        SM:_CheckMilestone()
    else
        -- Erster Login, übersprungener Tag oder ungültige/future Daten:
        -- eine neue Streak mit dem heutigen Tag beginnen.
        db.current      = 1
        db.claimedToday = false
    end

    db.lastLogin = now

    if (db.current or 0) > (db.best or 0) then
        db.best = db.current
    end

    -- Erstes tägliches Spiel: +2 Gold (falls heute noch nicht erhalten)
    -- wird vom GAME_RESULT-Listener aus Init() ausgelöst.

    ArcadiaNexus.Engine:Emit("STREAK_UPDATED", db)
end

-- ============================================================
-- MEILENSTEIN-CHECK
-- ============================================================
function SM:_CheckMilestone()
    local streak = ArcadiaNexusDB.streak.current or 0
    for _, m in ipairs(MILESTONES) do
        if streak == m.days then
            if m.xp > 0 then
                ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = m.xp })
            end
            if m.gold > 0 then
                local TG = ArcadiaNexus.TavernGold
                if TG then TG:Add(m.gold, "streak_milestone") end
            end
            if m.title then
                ArcadiaNexus.Engine:Emit("TITLE_UNLOCKED", { title = m.title })
            end
            if m.theme then
                ArcadiaNexus.Engine:Emit("THEME_UNLOCKED", { theme = m.theme })
            end
        end
    end
end

-- ============================================================
-- PUBLIC GETTER
-- ============================================================
function SM:GetCurrent()
    return (ArcadiaNexusDB.streak and ArcadiaNexusDB.streak.current) or 0
end

function SM:GetBest()
    return (ArcadiaNexusDB.streak and ArcadiaNexusDB.streak.best) or 0
end
