--[[
    Gaming Hub
    Core/XPManager.lua
    Version: 2.0.0

    Verantwortlichkeiten:
      - Berechnet XP (BASE_XP x DifficultyMulti x ResultMulti)
      - Verwaltet Level-Up-Logik mit Max Level 50
      - Wird von GameResultProcessor aufgerufen (nicht direkt auf GAME_RESULT)
      - XP-Kurve: 80 + (level x 12) + (level^1.35)
      - Titel alle 5 Level (Arcade Initiate -> Arcade Master of the Nexus)
      - Emittet XP_UPDATED und ARCADE_LEVEL_UP

    Oeffentliche API:
      XPManager:GetProfile()           -> ArcadiaNexusDB.profile
      XPManager:GetXPRequired(level)   -> number
      XPManager:GetTitle(level)        -> string
      XPManager:IsMaxLevel()           -> bool
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.XPManager = {}
local XPM = ArcadiaNexus.XPManager

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

-- ============================================================
-- XP-Tabellen
-- ============================================================

local BASE_XP = {
    TICTACTOE      =  8,
    CONNECT4       = 10,
    ["2048"]       = 12,
    BATTLESHIP     = 14,
    SUDOKU         = 18,
    CHESS          = 20,
    MINESWEEPER    = 10,
    MEMORY         = 10,
    MASTERMIND     = 12,
    SIMONSAYS      =  8,
    SNAKE          = 10,
    LOA            = 12,
    TETRIS         = 12,
    WHACKAMOLE     =  8,
    HANGMAN        = 10,
    GGH            = 14,
    -- Neuere Spiele (ab v1.0)
    MATCH3         = 12,
    BLOCKBREAKER   = 10,
    ALIENDEFENSE   = 14,
    LIGHTSOUT      =  8,
    REACTIONSTRIKE =  8,
    AZEROTHWORDS   = 12,
    NONOGRAM       = 16,
    GOBLINBLAST    = 12,
}

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
    local p = ArcadiaNexusDB and ArcadiaNexusDB.profile
    return p and p.level >= MAX_LEVEL
end

-- ============================================================
-- DB-Init
-- ============================================================

local function EnsureProfile()
    if not ArcadiaNexusDB.profile then
        ArcadiaNexusDB.profile = {
            level      = 1,
            xp         = 0,
            xpRequired = 0,
            totalXP    = 0,
            totalGames = 0,
            wins       = 0,
            losses     = 0,
            draws      = 0,
        }
    end
    local p = ArcadiaNexusDB.profile
    if not p.level      then p.level      = 1 end
    if not p.xp         then p.xp         = 0 end
    if not p.totalXP    then p.totalXP    = 0 end
    if not p.totalGames then p.totalGames = 0 end
    if not p.wins       then p.wins       = 0 end
    if not p.losses     then p.losses     = 0 end
    if not p.draws      then p.draws      = 0 end
    -- Immer neu berechnen (Migration: alte falsche Werte ueberschreiben)
    p.xpRequired = XPM:GetXPRequired(p.level)
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

    local profile = ArcadiaNexusDB.profile
    profile.totalGames = profile.totalGames + 1
    if     data.result == "WIN"  then profile.wins   = profile.wins   + 1
    elseif data.result == "LOSS" then profile.losses = profile.losses + 1
    elseif data.result == "DRAW" then profile.draws  = profile.draws  + 1
    end

    -- Kein XP mehr bei Max Level
    if self:IsMaxLevel() then
        ArcadiaNexus.Engine:Emit("XP_UPDATED", ArcadiaNexusDB.profile)
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
        ArcadiaNexus.Engine:Emit("XP_UPDATED", ArcadiaNexusDB.profile)
    end
end

-- ============================================================
-- XP berechnen
-- ============================================================

function XPM:CalculateXP(gameId, difficulty, result)
    local base = BASE_XP[gameId] or 10
    local diff = DIFF_MULTI[difficulty and difficulty:lower() or ""] or 1.0
    local res  = RESULT_MULTI[result] or 0
    return math.floor(base * diff * res)
end

-- ============================================================
-- XP hinzufuegen
-- ============================================================

function XPM:AddXP(amount)
    local profile = ArcadiaNexusDB.profile
    profile.xp      = profile.xp      + amount
    profile.totalXP = profile.totalXP + amount
    self:CheckLevelUp()
    ArcadiaNexus.Engine:Emit("XP_UPDATED", ArcadiaNexusDB.profile)
end

-- ============================================================
-- Level-Up pruefen (mit MAX_LEVEL-Cap)
-- ============================================================

function XPM:CheckLevelUp()
    local profile = ArcadiaNexusDB.profile

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
    return ArcadiaNexusDB.profile
end
