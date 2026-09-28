--[[
    Gaming Hub
    Core/XPManager.lua
    Version: 2.0.0

    Verantwortlichkeiten:
      - Berechnet XP (RegisterGame.xp x DifficultyMulti x ResultMulti)
      - Verwaltet Level-Up-Logik mit Max Level 100
      - Wird von GameResultProcessor aufgerufen (nicht direkt auf GAME_RESULT)
      - XP-Kurve: 80 + (level x 12) + (level^1.35)
      - Titel alle 5 Level (Arcade Initiate -> High Master of the Nexus)
      - Emittet XP_UPDATED und ARCADE_LEVEL_UP

    Oeffentliche API:
      XPManager:GetProfile()           -> ArcadiaNexusDB.profile
      XPManager:NormalizeProfile()     -> ArcadiaNexusDB.profile
      XPManager:GetXPRequired(level)   -> number
      XPManager:GetBaseXP(gameId)      -> number  (RegisterGame.xp)
      XPManager:GetTitle(level)        -> string (kanonischer Key)
      XPManager:GetTitleCatalog()      -> { { level, key }, ... }
      XPManager:GetLocalizedTitle(level) -> string
      XPManager:GetLocalizedTitleForKey(key) -> string
      XPManager:GetNextTitleUnlock(level) -> title, unlockLevel (oder nil)
      XPManager:GetTitleProgress(profile?) -> table
      XPManager:IsMaxLevel()           -> bool
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.XPManager = {}
local XPM = ArcadiaNexus.XPManager

local function Profile()
    return ArcadiaNexus.ProfileStore.Get()
end

-- ============================================================
-- Konstanten
-- ============================================================

local MAX_LEVEL = 100

-- ============================================================
-- Titel-System (alle 5 Level, ab Level 1)
-- ============================================================

local TITLES = {
    [1]  = "Arcade Initiate",
    [5]  = "Novice of the Nexus Arcade",
    [10] = "Arcade Challenger",
    [15] = "Arcade Contender",
    [20] = "Arcade Veteran",
    [25] = "Arcade Strategist",
    [30] = "Arcade Champion",
    [35] = "Arcade Conqueror",
    [40] = "Arcade Grandmaster",
    [45] = "Arcade Legend",
    [50] = "Arcade Master of the Nexus",
    [55] = "Nexus Vanguard",
    [60] = "Arcade Architect",
    [65] = "Guardian of the Arcade",
    [70] = "Nexus Trailblazer",
    [75] = "Master Strategist",
    [80] = "Arcadian Warlord",
    [85] = "Nexus Myth",
    [90] = "Grandmaster of Games",
    [95] = "Arcade Icon",
    [100] = "High Master of the Nexus",
}

local TITLE_UNLOCKS = {
    1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50,
    55, 60, 65, 70, 75, 80, 85, 90, 95, 100,
}

function XPM:GetTitle(level)
    local title = TITLES[1]
    for lvl = 1, level do
        if TITLES[lvl] then title = TITLES[lvl] end
    end
    return title
end

function XPM:GetTitleCatalog()
    local list = {}
    for i = 1, #TITLE_UNLOCKS do
        local lvl = TITLE_UNLOCKS[i]
        list[i] = { level = lvl, key = TITLES[lvl] }
    end
    return list
end

function XPM:GetTitleUnlockLevel(level)
    level = tonumber(level) or 1
    local unlock = TITLE_UNLOCKS[1]
    for i = 1, #TITLE_UNLOCKS do
        local lvl = TITLE_UNLOCKS[i]
        if lvl <= level then
            unlock = lvl
        else
            break
        end
    end
    return unlock
end

function XPM:GetUnlockLevelForKey(key)
    if type(key) ~= "string" or key == "" then return nil end
    for lvl, title in pairs(TITLES) do
        if title == key then return lvl end
    end
    return nil
end

function XPM:GetLocalizedTitle(level)
    local unlock = self:GetTitleUnlockLevel(level)
    local L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    local loc = L and L["stats_title_" .. unlock]
    if type(loc) == "string" and loc ~= "" then
        return loc
    end
    return TITLES[unlock] or TITLES[1]
end

function XPM:GetLocalizedTitleForKey(key)
    local unlock = self:GetUnlockLevelForKey(key)
    if unlock then
        return self:GetLocalizedTitle(unlock)
    end
    return key
end

function XPM:GetNextTitleUnlock(level)
    level = tonumber(level) or 1
    for i = 1, #TITLE_UNLOCKS do
        local unlockLevel = TITLE_UNLOCKS[i]
        if unlockLevel > level then
            return TITLES[unlockLevel], unlockLevel
        end
    end
    return nil, nil
end

-- Fortschritt im aktuellen Titel-Band (vorheriger Unlock bis zum nächsten).
-- remaining = XP, die noch fehlen, um den nächsten Titel-Level zu erreichen.
function XPM:GetTitleProgress(profile)
    local p = profile
    if type(p) ~= "table" then
        p = Profile()
    end
    local level = tonumber(p and p.level) or 1
    local xp = tonumber(p and p.xp) or 0
    local currentTitle = XPM:GetTitle(level)
    local nextTitle, nextLevel = XPM:GetNextTitleUnlock(level)
    if not nextTitle then
        return {
            maxed        = true,
            currentTitle = currentTitle,
            nextTitle    = nil,
            nextLevel    = nil,
            remaining    = 0,
            earned       = 1,
            total        = 1,
            fraction     = 1,
        }
    end

    local prevLevel = TITLE_UNLOCKS[1]
    for i = 1, #TITLE_UNLOCKS do
        local unlockLevel = TITLE_UNLOCKS[i]
        if unlockLevel <= level then
            prevLevel = unlockLevel
        else
            break
        end
    end

    local total, earned = 0, 0
    for lvl = prevLevel, nextLevel - 1 do
        local req = XPM:GetXPRequired(lvl)
        total = total + req
        if lvl < level then
            earned = earned + req
        elseif lvl == level then
            earned = earned + math.min(xp, req)
        end
    end
    if total < 1 then total = 1 end
    local remaining = math.max(0, total - earned)
    return {
        maxed        = false,
        currentTitle = currentTitle,
        nextTitle    = nextTitle,
        nextLevel    = nextLevel,
        remaining    = remaining,
        earned       = earned,
        total        = total,
        fraction     = math.min(1, earned / total),
    }
end

-- Basis-XP kommt aus RegisterGame.xp (GameRegistry.GetBaseXP).
-- Schwierigkeit und Ergebnis bleiben globale Multiplikatoren.

local DIFF_MULTI = {
    easy   = 1.0,
    normal = 1.5,
    hard   = 2.2,
}

local RESULT_MULTI = {
    WIN  = 1.0,
    DRAW = 0.6,
    LOSS = 0.3,
}

-- ============================================================
-- XP-Kurve: 80 + (level x 12) + floor(level^1.35)
-- Level  1 ->  93 XP (~10 Spiele)
-- Level 10 -> 222 XP
-- Level 50 -> 876 XP (Aufstieg auf 51)
-- Level 99 -> 1762 XP (Aufstieg auf 100)
-- ============================================================

function XPM:GetXPRequired(level)
    if level >= MAX_LEVEL then return 0 end
    return math.floor(80 + (level * 12) + (level ^ 1.35))
end

function XPM:IsMaxLevel()
    local PS = ArcadiaNexus.ProfileStore
    local p = PS and PS.Get()
    return p and p.level >= MAX_LEVEL
end

-- ============================================================
-- DB-Init
-- ============================================================

local function ClampInt(value, default, minV, maxV)
    if type(value) ~= "number" then value = default end
    if minV and value < minV then value = minV end
    if maxV and value > maxV then value = maxV end
    return math.floor(value)
end

function XPM:NormalizeProfile(profile)
    local PS = ArcadiaNexus.ProfileStore
    local p
    if PS then
        if type(profile) == "table" then
            PS.Replace(profile)
        end
        p = PS.Get()
    else
        if not ArcadiaNexusDB then return nil end
        if type(profile) == "table" then
            ArcadiaNexusDB.profile = profile
        elseif type(ArcadiaNexusDB.profile) ~= "table" then
            ArcadiaNexusDB.profile = {}
        end
        p = ArcadiaNexusDB.profile
    end
    p.level      = ClampInt(p.level, 1, 1, MAX_LEVEL)
    p.xp         = ClampInt(p.xp, 0, 0)
    p.totalXP    = ClampInt(p.totalXP, 0, 0)
    p.totalGames = ClampInt(p.totalGames, 0, 0)
    p.wins       = ClampInt(p.wins, 0, 0)
    p.losses     = ClampInt(p.losses, 0, 0)
    p.draws      = ClampInt(p.draws, 0, 0)
    -- xpRequired nie aus Import/Reset uebernehmen
    p.xpRequired = XPM:GetXPRequired(p.level)
    if p.level >= MAX_LEVEL then
        p.xp         = 0
        p.xpRequired = 0
    end
    return p
end

local function EnsureProfile()
    XPM:NormalizeProfile()
end

-- ============================================================
-- Init
-- ============================================================

function XPM:Init()
    GH_LogInfo("XPManager", "Level-System initialisiert")
    EnsureProfile()
    ArcadiaNexus.Engine:On("ACHIEVEMENT_XP", function(data)
        if data and data.amount and data.amount > 0 then
            XPM:AddXP(data.amount)
        end
    end)
end

-- ============================================================
-- GAME_RESULT verarbeiten
-- ============================================================

function XPM:HandleGameResult(data)
    if not data or not data.gameId or not data.result then return end

    local profile = Profile()
    profile.totalGames = profile.totalGames + 1
    if     data.result == "WIN"  then profile.wins   = profile.wins   + 1
    elseif data.result == "LOSS" then profile.losses = profile.losses + 1
    elseif data.result == "DRAW" then profile.draws  = profile.draws  + 1
    end

    -- Kein XP mehr bei Max Level
    if self:IsMaxLevel() then
        ArcadiaNexus.Engine:Emit("XP_UPDATED", Profile())
        return
    end

    local xp = self:CalculateXP(data.gameId, data.difficulty, data.result)
    -- Spiel des Tages: +25% XP Bonus
    local CM = ArcadiaNexus.ChallengeManager
    if CM and CM.GetGameOfDay then
        local ok, gid = pcall(function() return CM:GetGameOfDay() end)
        if ok and gid and gid == data.gameId then
            xp = math.floor(xp * 1.25)
        end
    end
    if xp > 0 then
        self:AddXP(xp)
    else
        ArcadiaNexus.Engine:Emit("XP_UPDATED", Profile())
    end
end

-- ============================================================
-- XP berechnen
-- ============================================================

function XPM:GetBaseXP(gameId)
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.GetBaseXP then
        return GR.GetBaseXP(gameId)
    end
    return (GR and GR.DEFAULT_BASE_XP) or 10
end

function XPM:CalculateXP(gameId, difficulty, result)
    local base = self:GetBaseXP(gameId)
    local diff = DIFF_MULTI[difficulty and difficulty:lower() or ""] or 1.0
    local res  = RESULT_MULTI[result] or 0
    return math.floor(base * diff * res)
end

-- ============================================================
-- XP hinzufuegen
-- ============================================================

function XPM:AddXP(amount)
    local profile = Profile()
    profile.xp      = profile.xp      + amount
    profile.totalXP = profile.totalXP + amount
    self:CheckLevelUp()
    ArcadiaNexus.Engine:Emit("XP_UPDATED", Profile())
end

-- ============================================================
-- Level-Up pruefen (mit MAX_LEVEL-Cap)
-- ============================================================

function XPM:CheckLevelUp()
    local profile = Profile()

    while profile.level < MAX_LEVEL and profile.xp >= profile.xpRequired do
        local prevLevel    = profile.level
        profile.xp         = profile.xp - profile.xpRequired
        profile.level      = profile.level + 1
        profile.xpRequired = self:GetXPRequired(profile.level)

        ArcadiaNexus.Engine:Emit("ARCADE_LEVEL_UP", {
            level     = profile.level,
            prevLevel = prevLevel,
            title     = self:GetTitle(profile.level),
        })
    end

    -- Bei Max Level: XP und xpRequired auf 0 klemmen
    if profile.level >= MAX_LEVEL then
        profile.xp         = 0
        profile.xpRequired = 0
    end
end

-- ============================================================
-- Oeffentliche Abfrage
-- ============================================================

function XPM:GetProfile()
    EnsureProfile()
    return Profile()
end
