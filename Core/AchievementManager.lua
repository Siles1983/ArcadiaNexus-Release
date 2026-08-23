--[[
    Gaming Hub
    Core/AchievementManager.lua
    Version: 1.0.0

    Verantwortlichkeiten:
      - Prüft Achievement-Conditions (via GameResultProcessor)
      - Verwaltet Bronze/Silber/Gold-Stufen pro Achievement-Gruppe
      - Schreibt ausschließlich in ArcadiaNexusDB.achievements
      - Emittiert ACHIEVEMENT_UNLOCKED (für UI-Toast)
      - Emittiert ACHIEVEMENT_XP (XPManager hört darauf)
      - Ausfall darf den Rest des Addons NICHT beeinflussen

    Öffentliche API:
      AM:GetUnlocked()        → { [achId] = timestamp }
      AM:GetProgress()        → { [groupId] = { tier, current, target } }
      AM:IsUnlocked(achId)    → bool
      AM:GetStats()           → { total, unlocked, xpEarned }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AchievementManager = {}
local AM = ArcadiaNexus.AchievementManager

-- ============================================================
-- Init
-- ============================================================

function AM:Init()
    -- DB sichern
    if not ArcadiaNexusDB.achievements then
        ArcadiaNexusDB.achievements = {
            unlocked = {},   -- [achId] = timestamp
            progress = {},   -- [groupId] = { tier=0, current=0 }
        }
    end
    if not ArcadiaNexusDB.achievements.unlocked then
        ArcadiaNexusDB.achievements.unlocked = {}
    end
    if not ArcadiaNexusDB.achievements.progress then
        ArcadiaNexusDB.achievements.progress = {}
    end

    AM:_CheckRetroactive()
end

-- ============================================================
-- GAME_RESULT (via GameResultProcessor)
-- ============================================================

function AM:HandleGameResult(data)
    AM:_Check(data)
end

-- ============================================================
-- Rückwirkende Prüfung beim Addon-Load
-- Nur für Achievements die aus ScoreManager-Daten berechenbar sind
-- ============================================================

function AM:_CheckRetroactive()
    local SM = ArcadiaNexus.ScoreManager
    if not SM then return end

    -- Simuliere ein synthetisches "summary"-Event für spielübergreifende Checks
    local allData = SM:GetAllGames()
    if not allData then return end

    local totalWins   = 0
    local totalGames  = 0
    local totalLosses = 0

    for gameId, diffTable in pairs(allData) do
        for _, entry in pairs(diffTable) do
            totalWins   = totalWins   + (entry.wins   or 0)
            totalLosses = totalLosses + (entry.losses or 0)
            totalGames  = totalGames  + (entry.wins   or 0)
                                      + (entry.losses or 0)
                                      + (entry.draws  or 0)
        end
    end

    local XPM = ArcadiaNexus.XPManager
    local profile = XPM and XPM:GetProfile()

    local retroData = {
        _retroactive = true,
        totalWins    = totalWins,
        totalGames   = totalGames,
        totalLosses  = totalLosses,
        level        = profile and profile.level or 0,
        allGames     = allData,
    }

    AM:_Check(retroData)
end

-- ============================================================
-- Haupt-Prüflogik
-- ============================================================

function AM:_Check(data)
    local achData = ArcadiaNexus.AchievementData
    if not achData then return end

    for _, group in ipairs(achData) do
        AM:_CheckGroup(group, data)
    end
end

function AM:_CheckGroup(group, data)
    local db       = ArcadiaNexusDB.achievements
    local groupId  = group.id
    local tiers    = group.tiers  -- { { id, target, xp }, ... } Bronze/Silber/Gold

    if not tiers or #tiers == 0 then return end

    -- Aktuellen Fortschrittsstand aus DB lesen
    if not db.progress[groupId] then
        db.progress[groupId] = { tier = 0, current = 0 }
    end
    local prog = db.progress[groupId]

    -- Alle bereits freigeschalteten Tiers überspringen
    local nextTierIdx = prog.tier + 1
    if nextTierIdx > #tiers then return end  -- Alle Tiers bereits erreicht

    -- Aktuellen Wert via condition ermitteln (pcall-geschützt)
    local ok, value = pcall(group.condition, data, ArcadiaNexusDB)
    if not ok or type(value) ~= "number" then return end

    -- Fortschritt aktualisieren (nur wenn value > current, für kumulative)
    if value > prog.current then
        prog.current = value
    end

    -- Alle erreichbaren Tiers freischalten (ein Event kann mehrere Stufen triggern)
    for i = nextTierIdx, #tiers do
        local tier = tiers[i]
        if prog.current >= tier.target then
            -- Nur freischalten wenn noch nicht in unlocked
            if not db.unlocked[tier.id] then
                AM:_Unlock(tier, group, i)
                prog.tier = i
            end
        else
            break  -- Nächste Stufe noch nicht erreicht
        end
    end
end

-- ============================================================
-- Achievement freischalten
-- ============================================================

function AM:_Unlock(tier, group, tierIdx)
    local db = ArcadiaNexusDB.achievements
    db.unlocked[tier.id] = GetServerTime()

    -- XP via Event an XPManager (keine direkte Kopplung)
    local xp = tier.xp or 20
    ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = xp })

    -- Tavern Gold für Achievement (5-50 Gold basierend auf XP-Wert)
    local TG = ArcadiaNexus.TavernGold
    if TG and TG.GoldFromXP and tier.xp then
        local goldReward = TG:GoldFromXP(tier.xp)
        if goldReward > 0 then
            pcall(function() TG:Add(goldReward, "achievement") end)
        end
    end

    -- Toast-Event für UI
    ArcadiaNexus.Engine:Emit("ACHIEVEMENT_UNLOCKED", {
        tierId   = tier.id,
        groupId  = group.id,
        gameId   = group.gameId,
        category = group.category,
        tierIdx  = tierIdx,
        tierName = tier.tierName,
        title_de = group.title_de,
        title_en = group.title_en,
        desc_de  = tier.desc_de or group.desc_de,
        desc_en  = tier.desc_en or group.desc_en,
        icon     = group.icon,
        xp       = xp,
    })
end

-- ============================================================
-- Öffentliche API
-- ============================================================

function AM:GetUnlocked()
    return ArcadiaNexusDB.achievements and ArcadiaNexusDB.achievements.unlocked or {}
end

function AM:GetProgress()
    return ArcadiaNexusDB.achievements and ArcadiaNexusDB.achievements.progress or {}
end

function AM:IsUnlocked(achId)
    local db = ArcadiaNexusDB.achievements
    return db and db.unlocked and db.unlocked[achId] ~= nil
end

function AM:GetStats()
    local achData  = ArcadiaNexus.AchievementData or {}
    local unlocked = ArcadiaNexusDB.achievements and ArcadiaNexusDB.achievements.unlocked or {}

    local totalTiers   = 0
    local unlockedCnt  = 0
    local xpEarned     = 0

    for _, group in ipairs(achData) do
        for _, tier in ipairs(group.tiers or {}) do
            totalTiers = totalTiers + 1
            if unlocked[tier.id] then
                unlockedCnt = unlockedCnt + 1
                xpEarned    = xpEarned + (tier.xp or 20)
            end
        end
    end

    return {
        total     = totalTiers,
        unlocked  = unlockedCnt,
        xpEarned  = xpEarned,
    }
end
