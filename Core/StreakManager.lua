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

    local now     = GetServerTime()
    local last    = db.lastLogin or 0
    local DAY_SEC = 86400

    local diff = now - last

    if diff < DAY_SEC then
        -- Gleicher Tag – nichts tun (Streak bleibt)
    elseif diff < DAY_SEC * 2 then
        -- Nächster Tag: Streak fortführen
        db.current       = (db.current or 0) + 1
        db.claimedToday  = false
        SM:_CheckMilestone()
    else
        -- Mehr als 1 Tag Pause: Streak gebrochen
        db.current      = 1
        db.claimedToday = false
    end

    db.lastLogin = now

    if (db.current or 0) > (db.best or 0) then
        db.best = db.current
    end

    -- Erstes tägliches Spiel: +2 Gold (falls heute noch nicht erhalten)
    -- wird in _CheckFirstGameOfDay() ausgelöst wenn GAME_RESULT eintrifft

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
