--[[
    Gaming Hub
    Core/XPManager.lua
    Version: 2.0.0

    Verantwortlichkeiten:
      - Berechnet XP (RegisterGame.xp x DifficultyMulti x ResultMulti)
      - Verwaltet Level-Up-Logik mit Max Level 50
      - Wird von GameResultProcessor aufgerufen (nicht direkt auf GAME_RESULT)
      - XP-Kurve: 80 + (level x 12) + (level^1.35)
      - Titel alle 5 Level (Arcade Initiate -> Arcade Master of the Nexus)
      - Emittet XP_UPDATED und ARCADE_LEVEL_UP

    Oeffentliche API:
      XPManager:GetProfile()           -> ArcadiaNexusDB.profile
      XPManager:NormalizeProfile()     -> ArcadiaNexusDB.profile
      XPManager:GetXPRequired(level)   -> number
      XPManager:GetBaseXP(gameId)      -> number  (RegisterGame.xp)
      XPManager:GetTitle(level)        -> string
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

local MAX_LEVEL = 50

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
}

function XPM:GetTitle(level)
    local title = TITLES[1]
    for lvl = 1, level do
        if TITLES[lvl] then title = TITLES[lvl] end
    end
    return title
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
-- Level 10 -> 246 XP (~27 Spiele)
-- Level 50 -> 2220 XP
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
