--[[
    Gaming Hub
    Core/AchievementManager.lua
    Version: 1.0.0

    Verantwortlichkeiten:
      - Prüft Achievement-Conditions (via GameResultProcessor)
      - Verwaltet Bronze/Silber/Gold-Stufen pro Achievement-Gruppe
      - Schreibt ausschließlich über AchievementStore
      - Emittiert ACHIEVEMENT_UNLOCKED (für UI-Toast)
      - Emittiert ACHIEVEMENT_XP (XPManager hört darauf)
      - Ausfall einer fremden Gruppe darf eine Buchung nicht abbrechen.
        Gemeinsame Gruppen (ALLGEMEIN, LEVEL_TITEL) werden einzeln gesichert
        und bei Fehler nachgeholt. Eigene Spielgruppen bleiben strikt.

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
    ArcadiaNexus.AchievementStore.Get()
    AM:_MigrateLegacyLevel()
    AM:_MigrateRetired()
    ArcadiaNexus.Engine:On("STREAK_UPDATED", function()
        AM:_CheckById("GLOBAL_LOGIN_STREAK")
    end)
    ArcadiaNexus.Engine:On("CHALLENGE_COMPLETE", function(ch)
        if ch then
            AM:_CheckById("GLOBAL_DAILY_STREAK")
            AM:_CheckById("GLOBAL_WEEKLY_STREAK")
        end
    end)
    ArcadiaNexus.Engine:On("ARCADE_LEVEL_UP", function()
        AM:_CheckLevelGroups()
    end)
    ArcadiaNexus.Engine:On("ACHIEVEMENTS_REGISTERED", function(groups)
        AM:_MigrateRetired(groups)
        AM:_CheckRetroactive(groups)
    end)
    AM:_CheckRetroactive()
    AM:ResumePending()
end

local SNAP_KEYS = {
    "leaderboard", "profile", "achievements", "challenges",
    "streak", "tavernGold", "localResults", "gameSettings",
}

local function Clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Clone(v) end
    return out
end

--- Bestehende Tabellen bleiben dieselben Objekte. Äußere Handler halten sie bereits.
local function Restore(dst, src, skipKey)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k in pairs(dst) do
        if k ~= skipKey and src[k] == nil then dst[k] = nil end
    end
    for k, v in pairs(src) do
        if k ~= skipKey then
            if type(v) == "table" and type(dst[k]) == "table" then Restore(dst[k], v)
            else dst[k] = Clone(v) end
        end
    end
end

function AM:_IsShared(group)
    local gameId = group and group.gameId
    return gameId == "ALLGEMEIN" or gameId == "LEVEL_TITEL"
end

function AM:IsIsolating()
    return (self._isolating or 0) > 0
end

function AM:_Find(groupId)
    for _, group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.id == groupId then return group end
    end
end

function AM:_Pending()
    local ach = ArcadiaNexus.AchievementStore.Get()
    if type(ach.pendingGroups) ~= "table" then ach.pendingGroups = {} end
    return ach.pendingGroups
end

function AM:_Remember(groupId)
    if groupId then self:_Pending()[groupId] = true end
end

function AM:_Forget(groupId)
    local ach = ArcadiaNexusDB and ArcadiaNexusDB.achievements
    if type(ach) == "table" and type(ach.pendingGroups) == "table" then
        ach.pendingGroups[groupId] = nil
    end
end

function AM:_EventMark()
    local GRP = ArcadiaNexus.GameResultProcessor
    local LR = ArcadiaNexus.LocalResults
    return {
        grp = GRP and GRP._events and #GRP._events or 0,
        lr = LR and LR._events and #LR._events or 0,
        own = self._events and #self._events or 0,
    }
end

function AM:_TruncateEvents(mark)
    local function cut(list, n)
        if type(list) ~= "table" then return end
        for i = #list, (n or 0) + 1, -1 do list[i] = nil end
    end
    local GRP = ArcadiaNexus.GameResultProcessor
    local LR = ArcadiaNexus.LocalResults
    if GRP then cut(GRP._events, mark and mark.grp) end
    if LR then cut(LR._events, mark and mark.lr) end
    cut(self._events, mark and mark.own)
end

function AM:_Snapshot()
    local db = _G.ArcadiaNexusDB or {}
    local snap = { events = self:_EventMark() }
    for i = 1, #SNAP_KEYS do
        snap[SNAP_KEYS[i]] = Clone(db[SNAP_KEYS[i]])
    end
    return snap
end

function AM:_Restore(snap)
    local db = _G.ArcadiaNexusDB
    if type(db) ~= "table" or type(snap) ~= "table" then return end
    for i = 1, #SNAP_KEYS do
        local key = SNAP_KEYS[i]
        local saved = snap[key]
        local live = db[key]
        local skip = key == "achievements" and "pendingGroups" or nil
        if type(live) == "table" and type(saved) == "table" then
            Restore(live, saved, skip)
        elseif type(live) == "table" and saved == nil then
            for field in pairs(live) do
                if field ~= skip then live[field] = nil end
            end
        elseif saved ~= nil then
            db[key] = Clone(saved)
        end
    end
    self:_TruncateEvents(snap.events)
end

--- Meldungen während des Nachholens. Buchungen puffern bereits selbst.
function AM:BufferEvent(event, ...)
    if not self:IsIsolating() then return false end
    local args = { n = select("#", ...), ... }
    if event == "ACHIEVEMENT_XP" then
        local reward = args[1]
        local XPM = ArcadiaNexus.XPManager
        if reward and reward.amount and reward.amount > 0 and XPM and XPM.AddXP then
            XPM:AddXP(reward.amount)
        end
        return true
    end
    if event == "ARCADE_LEVEL_UP" then self:_CheckLevelGroups()
    elseif event == "CHALLENGE_COMPLETE" then
        self:_CheckById("GLOBAL_DAILY_STREAK")
        self:_CheckById("GLOBAL_WEEKLY_STREAK")
    elseif event == "STREAK_UPDATED" then self:_CheckById("GLOBAL_LOGIN_STREAK") end
    self._events = self._events or {}
    self._events[#self._events + 1] = { event = event, args = args }
    return true
end

function AM:_Publish()
    local events = self._events or {}
    self._events = {}
    local bus = ArcadiaNexus.EventBus
    for i = 1, #events do
        local item = events[i]
        if bus and bus.Emit then
            pcall(bus.Emit, bus, item.event, unpack(item.args, 1, item.args.n))
        end
        if item.event == "GOLD_UPDATED" then
            local gold = item.args[1]
            local TM = ArcadiaNexus.ToastManager
            if gold and TM and TM.ShowGold then
                pcall(TM.ShowGold, TM, gold.delta, gold.reason)
            end
        end
    end
end

--- Gemeinsame Gruppe: Bedingung, Fortschritt, Stufen, XP, Gold und Meldungen
--- gelten zusammen. Ein Fehler stellt denselben Tabellenstand wieder her.
function AM:_RunIsolated(group, data)
    local snap = self:_Snapshot()
    self._isolating = (self._isolating or 0) + 1
    local ok, err = pcall(function() AM:_CheckGroup(group, data) end)
    self._isolating = self._isolating - 1
    if not ok then
        self:_Restore(snap)
        self:_Remember(group.id)
        GH_LogError("AchievementManager", tostring(group.id) .. ": " .. tostring(err))
        return false
    end
    self:_Forget(group.id)
    if not self:IsIsolating() then self:_Publish() end
    return true
end

function AM:_RunGroup(group, data)
    if not group or group.retired then return end
    if self:_IsShared(group) then return self:_RunIsolated(group, data) end
    self:_CheckGroup(group, data)
end

--- Gemerkte gemeinsame Gruppen nach einem Neustart. Die Kennung bleibt,
--- bis Freischaltung und Belohnungen gemeinsam durchgelaufen sind.
function AM:ResumePending()
    local ach = ArcadiaNexusDB and ArcadiaNexusDB.achievements
    if type(ach) ~= "table" or type(ach.pendingGroups) ~= "table" then return end
    local ids = {}
    for id in pairs(ach.pendingGroups) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = 1, #ids do
        local group = self:_Find(ids[i])
        if group and self:_IsShared(group) and not group.retired then
            self:_RunIsolated(group, {})
        end
    end
end

function AM:_MigrateLegacyLevel()
    local unlocked = ArcadiaNexus.AchievementStore.GetUnlocked()
    local progress = ArcadiaNexus.AchievementStore.GetProgress()
    local old = {
        { id = "GLOBAL_LEVEL_BRONZE", level = 5 },
        { id = "GLOBAL_LEVEL_SILBER", level = 15 },
        { id = "GLOBAL_LEVEL_GOLD", level = 30 },
    }
    for _, entry in ipairs(old) do
        local timestamp = unlocked[entry.id]
        if timestamp then
            local groupId = "GLOBAL_LEVEL_" .. entry.level
            local tierId = groupId .. "_GOLD"
            if not unlocked[tierId] then unlocked[tierId] = timestamp end
            local groupProgress = ArcadiaNexus.AchievementStore.EnsureGroup(groupId)
            groupProgress.tier = 1
            groupProgress.current = math.max(groupProgress.current or 0, entry.level)
            unlocked[entry.id] = nil
        end
    end
    progress.GLOBAL_LEVEL = nil
end

function AM:_CheckById(groupId)
    for _, group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.id == groupId then
            AM:_RunGroup(group, {})
            return
        end
    end
end

function AM:_CheckLevelGroups()
    for _, group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.gameId == "LEVEL_TITEL" then AM:_RunGroup(group, {}) end
    end
end

-- ============================================================
-- GAME_RESULT (via GameResultProcessor)
-- ============================================================

function AM:HandleGameResult(data)
    AM:_Check(data)
end

-- Wave/score continuation is progress for these two groups, not another win
-- for global counters or unrelated game conditions.
function AM:HandleAlienDefenseProgress(data)
    for _,group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.id=="AD_KILLS" or group.id=="AD_WAVES" then AM:_RunGroup(group,data) end
    end
end

-- Orbit stage progress may unlock game achievements, never global game counters.
function AM:HandleOrbitProgress(data)
    for _,group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.gameId=="ARGUSORBDEFENSE" and group.id~="AOD_FIRST" then AM:_RunGroup(group,data) end
    end
end

function AM:HandleGoblinBlastProgress(data)
    for _,group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.gameId=="GOBLINBLAST" then AM:_RunGroup(group,data) end
    end
end

function AM:HandleBlockBreakerProgress(data)
    for _,group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.id=="BB_LEVEL" or group.id=="BB_COMBO" then AM:_RunGroup(group,data) end
    end
end

-- A survived fake is achievement progress, not a completed game or reward run.
function AM:HandleReactionFakeout()
    for _,group in ipairs(ArcadiaNexus.AchievementData or {}) do
        if group.id=="RS_FAKEOUT" then AM:_RunGroup(group,{gameId="REACTIONSTRIKE",fakeoutEvent=true}); return end
    end
end

-- ============================================================
-- Rückwirkende Prüfung beim Addon-Load
-- Nur für Achievements die aus ScoreManager-Daten berechenbar sind
-- ============================================================

function AM:_CheckRetroactive(groups)
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

    AM:_Check(retroData, groups)
end

-- ============================================================
-- Haupt-Prüflogik
-- ============================================================

function AM:_Check(data, groups)
    local achData = groups or ArcadiaNexus.AchievementData
    if not achData then return end
    local retro = type(data) == "table" and data._retroactive == true
    local gameId = (not retro and type(data) == "table") and data.gameId or nil
    if gameId == "" then gameId = nil end

    for _, group in ipairs(achData) do
        if retro or not gameId or group.gameId == gameId or group.gameId == "ALLGEMEIN" then
            AM:_RunGroup(group, data)
        end
    end
end

function AM:_CheckGroup(group, data)
    if group.retired then return end
    local groupId  = group.id
    local tiers    = group.tiers  -- { { id, target, xp }, ... } Bronze/Silber/Gold

    if not tiers or #tiers == 0 then return end

    -- Aktuellen Fortschrittsstand aus DB lesen
    local prog = ArcadiaNexus.AchievementStore.EnsureGroup(groupId)

    -- Alle bereits freigeschalteten Tiers überspringen
    local nextTierIdx = prog.tier + 1
    if nextTierIdx > #tiers then return end  -- Alle Tiers bereits erreicht

    -- Aktuellen Wert via condition ermitteln (pcall-geschützt)
    local ok, value = pcall(group.condition, data, ArcadiaNexus.AchievementStore.ConditionDB())
    if not ok then
        local LR = ArcadiaNexus.LocalResults
        local booked = ArcadiaNexus.GameResultProcessor
        -- Außerhalb einer Isolierung bleibt der Fehler geschluckt. Innerhalb muss er
        -- den Sicherungspunkt erreichen, auch beim Nachholen ohne laufende Buchung.
        if AM:IsIsolating() or (LR and LR:IsPreparing()) or (booked and booked:IsBooking()) then
            error(value)
        end
    end
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
            if not ArcadiaNexus.AchievementStore.IsUnlocked(tier.id) then
                prog.tier = i
                AM:_Unlock(tier, group, i)
            else
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
    if group.retired then return end
    ArcadiaNexus.AchievementStore.Unlock(tier.id)

    -- XP via Event an XPManager (keine direkte Kopplung)
    local xp = tier.xp or 20
    ArcadiaNexus.Engine:Emit("ACHIEVEMENT_XP", { amount = xp })

    -- Tavern Gold für Achievement (5-50 Gold basierend auf XP-Wert)
    local TG = ArcadiaNexus.TavernGold
    if TG and TG.GoldFromXP and tier.xp then
        local goldReward = TG:GoldFromXP(tier.xp)
        if goldReward > 0 then
            local LR = ArcadiaNexus.LocalResults
            local booked = ArcadiaNexus.GameResultProcessor
            if AM:IsIsolating() or (LR and LR:IsPreparing()) or (booked and booked:IsBooking()) then
                TG:Add(goldReward, "achievement")
            else pcall(function() TG:Add(goldReward, "achievement") end) end
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
    return ArcadiaNexus.AchievementStore.GetUnlocked()
end

function AM:GetProgress()
    return ArcadiaNexus.AchievementStore.GetProgress()
end

function AM:IsUnlocked(achId)
    return ArcadiaNexus.AchievementStore.IsUnlocked(achId)
end

function AM:GetStats()
    local achData  = ArcadiaNexus.AchievementData or {}
    local unlocked = ArcadiaNexus.AchievementStore.GetUnlocked()

    local totalTiers   = 0
    local unlockedCnt  = 0
    local xpEarned     = 0
    local feats        = 0

    for _, group in ipairs(achData) do
        for _, tier in ipairs(group.tiers or {}) do
            if not group.retired then totalTiers = totalTiers + 1 end
            if unlocked[tier.id] then
                if group.retired then feats=feats+1 else unlockedCnt = unlockedCnt + 1 end
                xpEarned    = xpEarned + (tier.xp or 20)
            end
        end
    end

    return {
        total     = totalTiers,
        unlocked  = unlockedCnt,
        xpEarned  = xpEarned,
        feats     = feats,
        allUnlocked = unlockedCnt+feats,
    }
end

-- Idempotent classification migration; IDs/timestamps and earned rewards stay put.
function AM:_MigrateRetired(groups)
    local ach=ArcadiaNexus.AchievementStore.Get()
    for _,group in ipairs(groups or ArcadiaNexus.AchievementData or {}) do
        if group.retired then
            if group.retiredProgressSource and not ach.progress[group.id] then
                local source=ach.progress[group.retiredProgressSource]
                if type(source)=="table" then
                    local frozen={}; for k,v in pairs(source) do frozen[k]=v end
                    ach.progress[group.id]=frozen
                end
            end
            local progress=ach.progress[group.id]
            if type(progress)=="table" then progress.retiredVersion=group.retiredVersion or 1 end
            ach.archiveVersion=math.max(ach.archiveVersion or 0,group.retiredVersion or 1)
        end
    end
end

function AM:GetDisplayGroups(target)
    local groups,unlocked={},self:GetUnlocked()
    local data=ArcadiaNexus.AchievementData or {}
    if target=="HELDENTATEN" then
        for _,group in ipairs(data) do if group.retired then
            local display={}; for key,value in pairs(group) do display[key]=value end
            display.tiers={}
            for _,tier in ipairs(group.tiers or {}) do
                if unlocked[tier.id]~=nil then display.tiers[#display.tiers+1]=tier end
            end
            if #display.tiers>0 then groups[#groups+1]=display end
        end end
        return groups
    end
    for _,group in ipairs(data) do
        if not group.retired and group.gameId==target then groups[#groups+1]=group end
    end
    if #groups==0 then
        for _,group in ipairs(data) do
            if not group.retired and (group.category or group.gameId)==target then groups[#groups+1]=group end
        end
    end
    return groups
end
