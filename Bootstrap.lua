--[[
    Arcadia Nexus
    Bootstrap.lua
    Version: 1.1.5
]]

local ADDON_NAME = ...
local ArcadiaNexus = {}
_G.ArcadiaNexus = ArcadiaNexus

local frame = CreateFrame("Frame")

-- ==========================================
-- Event Handling
-- ==========================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local arg1 = ...
        if arg1 == ADDON_NAME then
            ArcadiaNexus:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        ArcadiaNexus:OnPlayerLogin()
    elseif event == "PLAYER_LOGOUT" then
        ArcadiaNexus:OnPlayerLogout()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ArcadiaNexus:OnPlayerEnteringWorld(...)
    end
end)

-- ==========================================
-- Initialization
-- ==========================================

function ArcadiaNexus:OnAddonLoaded()
    self.Persistence:InitializeDB()
end

local STARTUP = {
    { name = "Engine",               method = "Init" },
    { name = "ScoreManager",         method = "Init" },
    { name = "XPManager",            method = "Init" },
    { name = "AchievementManager",   method = "Init" },
    { name = "TavernGold",           method = "Init" },
    { name = "StreakManager",        method = "Init" },
    { name = "StreakManager",        method = "OnLogin" },
    { name = "ChallengeManager",     method = "Init" },
    { name = "GameResultProcessor",  method = "Init" },
    { name = "ToastManager",         method = "Init" },
    { name = "ConsolePortBridge",    method = "Init" },
    { name = "GameInput",            method = "Init" },
    { name = "Match",                method = "Init", static = true },
}

local SHUTDOWN = {
    { name = "Match", method = "OnUnload", static = true },
}

local function SafeInvoke(addon, step, ...)
    local target = addon[step.name]
    if not target then return end
    local fn = target[step.method]
    if type(fn) ~= "function" then return end
    local ok, err
    if step.static then
        ok, err = pcall(fn, ...)
    else
        ok, err = pcall(fn, target, ...)
    end
    local label = step.name .. (step.method == "Init" and "" or (" " .. step.method))
    if ok then
        GH_LogInfo("Bootstrap", label .. (step.method == "Init" and " initialisiert" or " OK"))
    else
        GH_LogError("Bootstrap", label .. " fehlgeschlagen: " .. tostring(err))
    end
end

function ArcadiaNexus:OnPlayerLogin()
    for i = 1, #STARTUP do
        SafeInvoke(self, STARTUP[i])
    end
end

function ArcadiaNexus:OnPlayerLogout()
    local GR = self.GameRegistry
    if GR and GR.StopActiveGame then
        pcall(GR.StopActiveGame)
    end
    for i = 1, #SHUTDOWN do
        SafeInvoke(self, SHUTDOWN[i])
    end
end

function ArcadiaNexus:OnPlayerEnteringWorld(isLogin, isReload)
    local m = self.Match
    if m and m.OnEnteringWorld then
        pcall(m.OnEnteringWorld, isLogin, isReload)
    end
end

-- ==========================================
-- Spiel-Registry
-- Jedes Spiel registriert sich selbst via:
--   ArcadiaNexus.RegisterGame({
--       id        = "TETRIS",          -- catID, muss eindeutig sein
--       label     = "BlockDrop",       -- Anzeigename in der Sidebar
--       renderer  = "TET_Renderer",    -- ArcadiaNexus[renderer]-Key
--       engine    = "TET_Engine",      -- ArcadiaNexus[engine]-Key (optional)
--       container = "_tetContainer",   -- ArcadiaNexus[container]-Key
--       category  = "DENKSPIELE",      -- ID, DE/EN-Name oder Alias (docs/RegisterGame_API.md)
--       xp        = 10,                -- Basis-XP bei GAME_RESULT (Default 10)
--   })
--
-- Speicherort: Core/GameRegistry.lua (nicht Engine:RegisterGame — Legacy entfernt).
-- ==========================================

-- ==========================================
-- Kategorie-Registry
--   ArcadiaNexus.RegisterCategory({ id, label?, order? })
-- Standard-Kategorien: Core/CategoryRegistry.lua
-- ==========================================

function ArcadiaNexus.RegisterCategory(info)
    if ArcadiaNexus.CategoryRegistry and ArcadiaNexus.CategoryRegistry.Register then
        return ArcadiaNexus.CategoryRegistry.Register(info)
    end
    GH_LogError("Bootstrap", "RegisterCategory: CategoryRegistry nicht geladen.")
    return false
end

-- ==========================================
-- Hub-Tab-Registry
--   ArcadiaNexus.RegisterHubTab({ id, labelKey, order?, ... })
-- Tab-Module: UI/HubTabs/HubTab_*.lua
-- ==========================================

function ArcadiaNexus.RegisterHubTab(info)
    if ArcadiaNexus.TabRegistry and ArcadiaNexus.TabRegistry.Register then
        return ArcadiaNexus.TabRegistry.Register(info)
    end
    GH_LogError("Bootstrap", "RegisterHubTab: TabRegistry nicht geladen.")
    return false
end

-- ==========================================
-- Hub-Settings-SubTab-Registry
--   ArcadiaNexus.RegisterHubSettingsTab({ id, labelKey, buildContent, ... })
-- Tab-Module: UI/Settings/HubSettings_Tab*.lua
-- ==========================================

function ArcadiaNexus.RegisterHubSettingsTab(info)
    if ArcadiaNexus.HubSettingsTabRegistry and ArcadiaNexus.HubSettingsTabRegistry.Register then
        return ArcadiaNexus.HubSettingsTabRegistry.Register(info)
    end
    GH_LogError("Bootstrap", "RegisterHubSettingsTab: HubSettingsTabRegistry nicht geladen.")
    return false
end

-- Suchfilter-State (wird von SearchBar geschrieben, von GamesPanel gelesen)
ArcadiaNexus._filterState = { query = "" }

--- Multiplayer-Capability. Games dürfen nur diese Funktion fragen,
--- nie TOC-Pfade oder Comms-Typen. False, wenn Core/Match auskommentiert ist.
function ArcadiaNexus.HasMultiplayer()
    local M = ArcadiaNexus.Match
    return M ~= nil and M._ready == true
end

--- ConsolePort ist geladen. Unabhängig vom Hub-Schalter.
function ArcadiaNexus.HasConsolePort()
    local B = ArcadiaNexus.ConsolePortBridge
    return B ~= nil and B.HasAddon() == true
end

function ArcadiaNexus.RegisterGame(info)
    if ArcadiaNexus.GameRegistry and ArcadiaNexus.GameRegistry.Register then
        return ArcadiaNexus.GameRegistry.Register(info)
    end
    GH_LogError("Bootstrap", "RegisterGame: GameRegistry nicht geladen.")
    return false
end

-- ==========================================
-- Achievement Registry
-- ==========================================
-- Jedes Spiel registriert seine Achievements via seiner eigenen
-- <SpielName>_Achievements.lua:
--   ArcadiaNexus.RegisterAchievements({
--       { id="TTT_WINS", gameId="TICTACTOE", ... },
--       { id="TTT_HARD", gameId="TICTACTOE", ... },
--   })
--
-- Externe Addons nutzen denselben Weg nach ArcadiaNexus.RegisterGame().
-- Achievement_Index.lua aggregiert _pendingAchievements in AchievementData.
-- ==========================================

ArcadiaNexus._pendingAchievements = {}

function ArcadiaNexus.RegisterAchievements(groups)
    if not groups then return end
    for _, group in ipairs(groups) do
        table.insert(ArcadiaNexus._pendingAchievements, group)
    end
end

-- ==========================================
-- Leaderboard Registry
-- ==========================================
-- Jedes Spiel deklariert seine Bestenliste via
--   Games/MyGame/MyGame_Leaderboard.lua:
--     ArcadiaNexus.RegisterLeaderboard({ gameId, difficulties, sections })
--
-- Externe Addons: nach ArcadiaNexus.RegisterGame() laden.
-- Leaderboard_Index.lua aggregiert _pendingLeaderboards.
-- ==========================================

ArcadiaNexus._pendingLeaderboards = {}

function ArcadiaNexus.RegisterLeaderboard(schema)
    if not schema then return false end
    if ArcadiaNexus.LeaderboardRegistry and ArcadiaNexus.LeaderboardRegistry.Register then
        return ArcadiaNexus.LeaderboardRegistry.Register(schema)
    end
    table.insert(ArcadiaNexus._pendingLeaderboards, schema)
    return true
end

-- ==========================================
-- Locale Framework
-- ==========================================
-- Erkennung: deDE = Deutsch, alles andere = Englisch (Fallback)
-- Verwendung in jedem Spiel:
--   local L = ArcadiaNexus.GetLocaleTable("TICTACTOE")
--   someFrame:SetText(L["btn_new_game"])
--
-- Jedes Spiel registriert Strings via Language.lua:
--   ArcadiaNexus.RegisterLocale("TICTACTOE", "deDE", { ... })
--   ArcadiaNexus.RegisterLocale("TICTACTOE", "enUS", { ... })
-- ==========================================

ArcadiaNexus._locales = {}   -- [gameID][locale] = stringTable
ArcadiaNexus._localeCache = {}

-- Sprache einmalig beim Addon-Load ermitteln
local _clientLocale = GetLocale and GetLocale() or "enUS"
ArcadiaNexus.ActiveLocale = (_clientLocale == "deDE") and "deDE" or "enUS"

-- Strings fuer ein Spiel + Sprache registrieren
function ArcadiaNexus.RegisterLocale(gameID, locale, strings)
    ArcadiaNexus._locales[gameID] = ArcadiaNexus._locales[gameID] or {}
    ArcadiaNexus._locales[gameID][locale] = strings
    ArcadiaNexus._localeCache[gameID] = nil
end

-- Locale-Tabelle fuer ein Spiel abrufen.
-- Aktive Sprache zuerst; fehlende Keys fallen auf enUS zurueck.
-- Fehlende Keys in enUS geben "[key]" als Platzhalter zurueck.
function ArcadiaNexus.GetLocaleTable(gameID)
    local cached = ArcadiaNexus._localeCache[gameID]
    if cached then return cached end

    local locales = ArcadiaNexus._locales[gameID]
    local localeTable
    if not locales then
        localeTable = setmetatable({}, {
            __index = function(_, k) return "[" .. tostring(k) .. "]" end
        })
    else
        local active   = locales[ArcadiaNexus.ActiveLocale] or {}
        local fallback = locales["enUS"] or {}
        -- rawget: wenn ActiveLocale == "enUS" sind active und fallback
        -- dieselbe Tabelle. fallback[k] wuerde sonst __index endlos aufrufen.
        localeTable = setmetatable(active, {
            __index = function(_, k)
                if fallback ~= active then
                    local v = rawget(fallback, k)
                    if v ~= nil then
                        return v
                    end
                end
                return "[" .. tostring(k) .. "]"
            end
        })
    end
    ArcadiaNexus._localeCache[gameID] = localeTable
    return localeTable
end
