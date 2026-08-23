--[[
    Arcadia Nexus
    Bootstrap.lua
    Version: 0.2.0 (Persistence-only DB init)
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

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            ArcadiaNexus:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        ArcadiaNexus:OnPlayerLogin()
    end
end)

-- ==========================================
-- Initialization
-- ==========================================

function ArcadiaNexus:OnAddonLoaded()
    self.Persistence:InitializeDB()
end

function ArcadiaNexus:OnPlayerLogin()
    -- Engine
    if self.Engine and self.Engine.Init then
        local ok, err = pcall(function() self.Engine:Init() end)
        if ok then GH_LogInfo("Bootstrap", "Engine initialisiert")
        else GH_LogError("Bootstrap", "Engine Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- ScoreManager
    if self.ScoreManager and self.ScoreManager.Init then
        local ok, err = pcall(function() self.ScoreManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "ScoreManager initialisiert")
        else GH_LogError("Bootstrap", "ScoreManager Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- XPManager
    if self.XPManager and self.XPManager.Init then
        local ok, err = pcall(function() self.XPManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "XPManager initialisiert")
        else GH_LogError("Bootstrap", "XPManager Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- AchievementManager
    if self.AchievementManager and self.AchievementManager.Init then
        local ok, err = pcall(function() self.AchievementManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "AchievementManager initialisiert") else GH_LogError("Bootstrap", "AchievementManager Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- TavernGold muss vor StreakManager und ChallengeManager laufen
    if self.TavernGold and self.TavernGold.Init then
        local ok, err = pcall(function() self.TavernGold:Init() end)
        if ok then GH_LogInfo("Bootstrap", "TavernGold initialisiert") else GH_LogError("Bootstrap", "TavernGold Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- StreakManager: Login-Verarbeitung
    if self.StreakManager and self.StreakManager.Init then
        local ok, err = pcall(function() self.StreakManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "StreakManager initialisiert") else GH_LogError("Bootstrap", "StreakManager Init fehlgeschlagen: " .. tostring(err)) end
    end
    if self.StreakManager and self.StreakManager.OnLogin then
        local ok, err = pcall(function() self.StreakManager:OnLogin() end)
        if ok then GH_LogInfo("Bootstrap", "StreakManager OnLogin OK") else GH_LogError("Bootstrap", "StreakManager OnLogin fehlgeschlagen: " .. tostring(err)) end
    end
    -- ChallengeManager
    if self.ChallengeManager and self.ChallengeManager.Init then
        local ok, err = pcall(function() self.ChallengeManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "ChallengeManager initialisiert") else GH_LogError("Bootstrap", "ChallengeManager Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- GameResultProcessor (nach allen Pipeline-Modulen)
    if self.GameResultProcessor and self.GameResultProcessor.Init then
        local ok, err = pcall(function() self.GameResultProcessor:Init() end)
        if ok then GH_LogInfo("Bootstrap", "GameResultProcessor initialisiert")
        else GH_LogError("Bootstrap", "GameResultProcessor Init fehlgeschlagen: " .. tostring(err)) end
    end
    -- ToastManager
    if self.ToastManager and self.ToastManager.Init then
        local ok, err = pcall(function() self.ToastManager:Init() end)
        if ok then GH_LogInfo("Bootstrap", "ToastManager initialisiert") else GH_LogError("Bootstrap", "ToastManager Init fehlgeschlagen: " .. tostring(err)) end
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

-- Sprache einmalig beim Addon-Load ermitteln
local _clientLocale = GetLocale and GetLocale() or "enUS"
ArcadiaNexus.ActiveLocale = (_clientLocale == "deDE") and "deDE" or "enUS"

-- Strings fuer ein Spiel + Sprache registrieren
function ArcadiaNexus.RegisterLocale(gameID, locale, strings)
    ArcadiaNexus._locales[gameID] = ArcadiaNexus._locales[gameID] or {}
    ArcadiaNexus._locales[gameID][locale] = strings
end

-- Locale-Tabelle fuer ein Spiel abrufen.
-- Aktive Sprache zuerst; fehlende Keys fallen auf enUS zurueck.
-- Fehlende Keys in enUS geben "[key]" als Platzhalter zurueck.
function ArcadiaNexus.GetLocaleTable(gameID)
    local locales = ArcadiaNexus._locales[gameID]
    if not locales then
        return setmetatable({}, {
            __index = function(_, k) return "[" .. tostring(k) .. "]" end
        })
    end
    local active   = locales[ArcadiaNexus.ActiveLocale] or {}
    local fallback = locales["enUS"] or {}
    return setmetatable(active, {
        __index = function(_, k)
            return fallback[k] or ("[" .. tostring(k) .. "]")
        end
    })
end
