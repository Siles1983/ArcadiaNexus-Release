--[[
    ArcadiaNexus – Achievement_Summary_Helpers
    UI/Achievement_Summary_Helpers.lua

    Datenaggregation für die Achievement-Zusammenfassung.
    Kein State, keine Frames — reine Berechnungsfunktionen.

    API (auf ArcadiaNexus.AchSumH):
        AchSumH.GetOverallStats()
            → { total, unlocked, pct }

        AchSumH.GetStatsByCategory()
            → { { id, label, total, unlocked, pct }, ... }  (sortiert nach label)

        AchSumH.GetRecentUnlocks(maxCount)
            → { { tierId, tierName, groupTitle, groupIcon, timestamp }, ... }
               neueste zuerst, maximal maxCount Einträge
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AchSumH = {}
local SH = ArcadiaNexus.AchSumH

-- ============================================================
-- Interne Hilfsfunktion: AchievementData liefern
-- ============================================================
local function GetAD()
    return ArcadiaNexus.AchievementData or {}
end

local function GetUnlocked()
    return (ArcadiaNexusDB and ArcadiaNexusDB.achievements
        and ArcadiaNexusDB.achievements.unlocked) or {}
end

-- ============================================================
-- Gesamtfortschritt
-- ============================================================
function SH.GetOverallStats()
    local total, unlocked = 0, 0
    local ul = GetUnlocked()
    for _, group in ipairs(GetAD()) do
        for _, tier in ipairs(group.tiers or {}) do
            total = total + 1
            if ul[tier.id] then unlocked = unlocked + 1 end
        end
    end
    local pct = total > 0 and math.floor((unlocked / total) * 100) or 0
    return { total = total, unlocked = unlocked, pct = pct }
end

-- ============================================================
-- Fortschritt pro Kategorie
-- Kategorien: gameId-Gruppen aus AchievementData.
-- Jede Gruppe hat group.gameId → wir aggregieren per gameId.
-- Kategorie-Label kommt aus GameRegistry (info.label).
-- ============================================================
function SH.GetStatsByCategory()
    local ul     = GetUnlocked()
    local byGame = {}   -- [gameId] = { total, unlocked }

    for _, group in ipairs(GetAD()) do
        local gid = group.gameId or "ALLGEMEIN"
        if not byGame[gid] then byGame[gid] = { total = 0, unlocked = 0 } end
        for _, tier in ipairs(group.tiers or {}) do
            byGame[gid].total = byGame[gid].total + 1
            if ul[tier.id] then
                byGame[gid].unlocked = byGame[gid].unlocked + 1
            end
        end
    end

    local GR = ArcadiaNexus.GameRegistry
    local labelMap = {}
    if GR then
        GR.Iterate({ respectHidden = false, includeDevOnly = true }, function(info)
            labelMap[info.id] = info.label
        end)
    end

    local result = {}
    for gid, data in pairs(byGame) do
        local label = labelMap[gid] or gid
        local pct   = data.total > 0
            and math.floor((data.unlocked / data.total) * 100) or 0
        result[#result + 1] = {
            id       = gid,
            label    = label,
            total    = data.total,
            unlocked = data.unlocked,
            pct      = pct,
        }
    end

    -- Alphabetisch nach Label sortieren, ALLGEMEIN immer zuletzt
    table.sort(result, function(a, b)
        if a.id == "ALLGEMEIN" then return false end
        if b.id == "ALLGEMEIN" then return true  end
        return a.label < b.label
    end)

    return result
end

-- ============================================================
-- Letzte N freigeschaltete Tiers
-- ============================================================
function SH.GetRecentUnlocks(maxCount)
    local ul = GetUnlocked()
    local ad = GetAD()

    -- Reverse-Map: tierId → { group, tier }
    local tierMap = {}
    for _, group in ipairs(ad) do
        for _, tier in ipairs(group.tiers or {}) do
            tierMap[tier.id] = { group = group, tier = tier }
        end
    end

    -- Alle freigeschalteten mit Timestamp sammeln
    local entries = {}
    for tierId, ts in pairs(ul) do
        local info = tierMap[tierId]
        if info then
            local L = ArcadiaNexus.GetLocaleTable("UI")
            local locale = ArcadiaNexus.ActiveLocale or "deDE"
            local groupTitle = (locale == "deDE" and info.group.title_de)
                               or info.group.title_en or "???"
            entries[#entries + 1] = {
                tierId     = tierId,
                tierName   = info.tier.tierName,
                tierXP     = info.tier.xp or 0,
                groupTitle = groupTitle,
                groupIcon  = info.group.icon,
                gameId     = info.group.gameId,
                timestamp  = ts,
            }
        end
    end

    -- Nach Timestamp absteigend sortieren (neueste zuerst)
    table.sort(entries, function(a, b) return a.timestamp > b.timestamp end)

    -- Auf maxCount begrenzen
    local result = {}
    for i = 1, math.min(maxCount or 5, #entries) do
        result[i] = entries[i]
    end
    return result
end
