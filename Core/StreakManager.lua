--[[
    ArcadiaNexus – StreakManager
    Core/StreakManager.lua
    Verwaltet Login-Streaks und Meilenstein-Belohnungen.
    Login-Streaks werden beim Login, der Tagesbonus in der Ergebnis-Pipeline verarbeitet.
]]

local SM = {}
ArcadiaNexus.StreakManager = SM

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

-- Ältere Speicherstände können den Bonus-Anspruch noch am Streak tragen.
-- Der Anspruch gehört zur Gold-Bilanz und gilt pro Kalendertag.
local function MigrateBonusClaim()
    local db = ArcadiaNexus.StatsStore.GetStreak()
    local gold = ArcadiaNexus.TavernGoldStore.Get()
    if db.claimedToday then
        local today = GetCalendarDay(GetServerTime())
        local claimedDay = GetCalendarDay(db.lastLogin) or today
        if today and claimedDay == today then
            gold.lastFirstGameDay = today
        end
    end
    db.claimedToday = nil
    return db
end

-- ============================================================
-- MEILENSTEINE
-- ============================================================
local MILESTONES = {
    { days=3,  xp=50, gold=0   },
    { days=7,  xp=0,  gold=20  },
    { days=14, xp=0,  gold=50  },
    { days=30, xp=0,  gold=100 },
}

-- ============================================================
-- INIT
-- ============================================================
function SM:Init()
    MigrateBonusClaim()
end

function SM:Refresh()
    local db = MigrateBonusClaim()
    ArcadiaNexus.Engine:Emit("STREAK_UPDATED", db)
end

function SM:HandleGameResult(data)
    if not data or data.recordPlayed == false then return end
    local today = GetCalendarDay(GetServerTime())
    if not today then return end
    local gold = ArcadiaNexus.TavernGoldStore.Get()
    if gold.lastFirstGameDay == today then return end
    local TG = ArcadiaNexus.TavernGold
    if not TG then return end
    gold.lastFirstGameDay = today
    TG:Add(2, "first_game")
end

-- ============================================================
-- LOGIN-HANDLER — wird von Bootstrap:OnPlayerLogin() aufgerufen
-- ============================================================
function SM:OnLogin()
    local db = MigrateBonusClaim()

    local now        = GetServerTime()
    local currentDay = GetCalendarDay(now)
    local lastDay    = GetCalendarDay(db.lastLogin)
    local dayDiff    = lastDay and currentDay and (currentDay - lastDay) or nil

    if dayDiff == 0 then
        -- Gleicher Kalendertag – nichts tun (Streak bleibt)
    elseif dayDiff == 1 then
        -- Direkt folgender Kalendertag: Streak fortführen
        db.current       = (db.current or 0) + 1
        SM:_CheckMilestone()
    else
        -- Erster Login, übersprungener Tag oder ungültige/future Daten:
        -- eine neue Streak mit dem heutigen Tag beginnen.
        db.current      = 1
    end

    db.lastLogin = now

    if (db.current or 0) > (db.best or 0) then
        db.best = db.current
    end

    ArcadiaNexus.Engine:Emit("STREAK_UPDATED", db)
end

-- ============================================================
-- MEILENSTEIN-CHECK
-- ============================================================
function SM:_CheckMilestone()
    local streak = ArcadiaNexus.StatsStore.GetStreak().current or 0
    for _, m in ipairs(MILESTONES) do
        if streak == m.days then
            if m.xp > 0 then
                ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = m.xp })
            end
            if m.gold > 0 then
                local TG = ArcadiaNexus.TavernGold
                if TG then TG:Add(m.gold, "streak_milestone") end
            end
        end
    end
end

-- ============================================================
-- PUBLIC GETTER
-- ============================================================
function SM:GetCurrent()
    return ArcadiaNexus.StatsStore.GetStreak().current or 0
end

function SM:GetBest()
    return ArcadiaNexus.StatsStore.GetStreak().best or 0
end
