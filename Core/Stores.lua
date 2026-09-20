--[[
    ArcadiaNexus – Core/Stores.lua
    Kleine Domain-Stores für Schreibzugriffe auf ArcadiaNexusDB.

    Persistence bleibt Schema- und Migrations-Owner.
    Profile / Stats / GameSettings / Match / Gold / Achievements /
    Favorites / HiddenGames gehen über diese APIs.
]]

local ArcadiaNexus = _G.ArcadiaNexus

local function DB()
    if not _G.ArcadiaNexusDB then
        _G.ArcadiaNexusDB = {}
    end
    return _G.ArcadiaNexusDB
end

local function CopyTable(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = CopyTable(v)
    end
    return copy
end

-- ============================================================
-- PROFILE
-- ============================================================

local EMPTY_PROFILE = {
    level        = 1,
    xp           = 0,
    totalXP      = 0,
    totalGames   = 0,
    wins         = 0,
    losses       = 0,
    draws        = 0,
    activeTitle  = nil,
    titleVisible = true,
}

local ProfileStore = {}
ArcadiaNexus.ProfileStore = ProfileStore

function ProfileStore.Get()
    local db = DB()
    if type(db.profile) ~= "table" then
        db.profile = CopyTable(EMPTY_PROFILE)
    end
    return db.profile
end

function ProfileStore.Replace(profile)
    DB().profile = type(profile) == "table" and profile or CopyTable(EMPTY_PROFILE)
    return ProfileStore.Get()
end

function ProfileStore.Reset()
    return ProfileStore.Replace(CopyTable(EMPTY_PROFILE))
end

function ProfileStore.SetActiveTitle(title)
    local p = ProfileStore.Get()
    p.activeTitle = title
    return p
end

function ProfileStore.SetTitleVisible(visible)
    local p = ProfileStore.Get()
    p.titleVisible = visible and true or false
    return p
end

-- ============================================================
-- STATS (Leaderboard, Streak, Challenges)
-- ============================================================

local EMPTY_STREAK = { current = 0, best = 0, lastLogin = 0, claimedToday = false }
local EMPTY_CHALLENGES = {
    daily   = {},
    weekly  = {},
    history = { completedTotal = 0, goldEarned = 0 },
}

local StatsStore = {}
ArcadiaNexus.StatsStore = StatsStore

function StatsStore.GetLeaderboard()
    local db = DB()
    if type(db.leaderboard) ~= "table" then
        db.leaderboard = {}
    end
    return db.leaderboard
end

function StatsStore.ReplaceLeaderboard(leaderboard)
    DB().leaderboard = type(leaderboard) == "table" and leaderboard or {}
    return StatsStore.GetLeaderboard()
end

function StatsStore.GetStreak()
    local db = DB()
    if type(db.streak) ~= "table" then
        db.streak = CopyTable(EMPTY_STREAK)
    end
    return db.streak
end

function StatsStore.ReplaceStreak(streak)
    DB().streak = type(streak) == "table" and streak or CopyTable(EMPTY_STREAK)
    return StatsStore.GetStreak()
end

function StatsStore.ResetStreak()
    return StatsStore.ReplaceStreak(CopyTable(EMPTY_STREAK))
end

function StatsStore.GetChallenges()
    local db = DB()
    if type(db.challenges) ~= "table" then
        db.challenges = CopyTable(EMPTY_CHALLENGES)
    end
    local ch = db.challenges
    if type(ch.history) ~= "table" then
        ch.history = { completedTotal = 0, goldEarned = 0 }
    end
    return ch
end

function StatsStore.SetChallengeHistory(history)
    local ch = StatsStore.GetChallenges()
    ch.history = type(history) == "table" and history or { completedTotal = 0, goldEarned = 0 }
    return ch.history
end

function StatsStore.ResetProgression()
    StatsStore.ReplaceLeaderboard({})
    ProfileStore.Reset()
    StatsStore.ResetStreak()
    DB().challenges = CopyTable(EMPTY_CHALLENGES)
end

function StatsStore.ImportProgression(data)
    if type(data) ~= "table" then return end
    StatsStore.ReplaceLeaderboard(data.leaderboard)
    ProfileStore.Replace(data.profile)
    StatsStore.ReplaceStreak(data.streak)
    if data.challenges and data.challenges.history then
        StatsStore.SetChallengeHistory(data.challenges.history)
    end
end

-- ============================================================
-- GAME SETTINGS (Facade auf Persistence)
-- ============================================================

local GameSettingsStore = {}
ArcadiaNexus.GameSettingsStore = GameSettingsStore

function GameSettingsStore.Get(gameID)
    local P = ArcadiaNexus.Persistence
    if P and P.GetGameSettings then
        return P:GetGameSettings(gameID)
    end
    if not gameID then return {} end
    local db = DB()
    if type(db.gameSettings) ~= "table" then
        db.gameSettings = {}
    end
    if type(db.gameSettings[gameID]) ~= "table" then
        db.gameSettings[gameID] = {}
    end
    return db.gameSettings[gameID]
end

function GameSettingsStore.Set(gameID, key, value)
    return ArcadiaNexus.Persistence:SetGameSetting(gameID, key, value)
end

-- ============================================================
-- MATCH TICKET
-- ============================================================

local MatchStore = {}
ArcadiaNexus.MatchStore = MatchStore

function MatchStore.GetTicket()
    local t = DB().matchTicket
    if type(t) ~= "table" then return nil end
    return t
end

function MatchStore.SetTicket(ticket)
    if type(ticket) ~= "table" then
        DB().matchTicket = nil
        return
    end
    DB().matchTicket = ticket
end

function MatchStore.ClearTicket()
    DB().matchTicket = nil
end

function MatchStore.NextSerial()
    local db = DB()
    db.matchSerial = (tonumber(db.matchSerial) or 0) + 1
    return db.matchSerial
end

--- true = neu markiert; false = bereits verbucht oder unvollständige Identität.
function MatchStore.TryMarkResult(character, key)
    if not character or not key then return false end
    local db = DB()
    if type(db.matchResults) ~= "table" then
        db.matchResults = {}
    end
    if type(db.matchResults[character]) ~= "table" then
        db.matchResults[character] = {}
    end
    local results = db.matchResults[character]
    if results[key] then return false end
    results[key] = true
    return true
end

-- ============================================================
-- TAVERN GOLD
-- ============================================================

local EMPTY_GOLD = { balance = 0, lifetime = 0, log = {} }

local TavernGoldStore = {}
ArcadiaNexus.TavernGoldStore = TavernGoldStore

function TavernGoldStore.Get()
    local db = DB()
    if type(db.tavernGold) ~= "table" then
        db.tavernGold = CopyTable(EMPTY_GOLD)
    end
    local g = db.tavernGold
    if type(g.log) ~= "table" then g.log = {} end
    if type(g.lifetime) ~= "number" then g.lifetime = 0 end
    if type(g.balance) ~= "number" then g.balance = 0 end
    return g
end

function TavernGoldStore.GetBalance()
    return TavernGoldStore.Get().balance or 0
end

function TavernGoldStore.GetLifetime()
    return TavernGoldStore.Get().lifetime or 0
end

-- ============================================================
-- ACHIEVEMENTS
-- ============================================================

local EMPTY_ACHIEVEMENTS = { unlocked = {}, progress = {} }

local AchievementStore = {}
ArcadiaNexus.AchievementStore = AchievementStore

function AchievementStore.Get()
    local db = DB()
    if type(db.achievements) ~= "table" then
        db.achievements = CopyTable(EMPTY_ACHIEVEMENTS)
    end
    local a = db.achievements
    if type(a.unlocked) ~= "table" then a.unlocked = {} end
    if type(a.progress) ~= "table" then a.progress = {} end
    return a
end

function AchievementStore.GetUnlocked()
    return AchievementStore.Get().unlocked
end

function AchievementStore.GetProgress()
    return AchievementStore.Get().progress
end

function AchievementStore.EnsureGroup(groupId)
    local progress = AchievementStore.GetProgress()
    if type(progress[groupId]) ~= "table" then
        progress[groupId] = { tier = 0, current = 0 }
    end
    return progress[groupId]
end

function AchievementStore.Unlock(achId, timestamp)
    if not achId then return end
    AchievementStore.GetUnlocked()[achId] = timestamp or (GetServerTime and GetServerTime() or 0)
end

function AchievementStore.IsUnlocked(achId)
    return AchievementStore.GetUnlocked()[achId] ~= nil
end

--- Vollständige SavedVariables für Achievement-Conditions (Lesen, kein Schema-Owner).
function AchievementStore.ConditionDB()
    return DB()
end

-- ============================================================
-- FAVORITES (Liste)
-- ============================================================

local FavoritesStore = {}
ArcadiaNexus.FavoritesStore = FavoritesStore

function FavoritesStore.GetList()
    local db = DB()
    if type(db.favorites) ~= "table" then
        db.favorites = {}
    end
    return db.favorites
end

function FavoritesStore.IsFavorite(gameId)
    if not gameId then return false end
    for _, id in ipairs(FavoritesStore.GetList()) do
        if id == gameId then return true end
    end
    return false
end

function FavoritesStore.Add(gameId)
    if not gameId or FavoritesStore.IsFavorite(gameId) then return end
    table.insert(FavoritesStore.GetList(), gameId)
end

function FavoritesStore.Remove(gameId)
    if not gameId then return end
    local list = FavoritesStore.GetList()
    for i, id in ipairs(list) do
        if id == gameId then
            table.remove(list, i)
            return
        end
    end
end

-- ============================================================
-- HIDDEN GAMES (Map id → true)
-- ============================================================

local HiddenGamesStore = {}
ArcadiaNexus.HiddenGamesStore = HiddenGamesStore

function HiddenGamesStore.Get()
    local db = DB()
    if type(db.hiddenGames) ~= "table" then
        db.hiddenGames = {}
    end
    return db.hiddenGames
end

function HiddenGamesStore.IsHidden(gameId)
    if not gameId then return false end
    return HiddenGamesStore.Get()[gameId] and true or false
end

function HiddenGamesStore.Replace(map)
    local copy = {}
    if type(map) == "table" then
        for id, v in pairs(map) do
            if v then copy[id] = true end
        end
    end
    DB().hiddenGames = copy
    return HiddenGamesStore.Get()
end

-- ============================================================
-- CLIENT SETTINGS (Hub: lockUI, uiScale, showGotd, showToast, …)
-- ============================================================

local ClientSettingsStore = {}
ArcadiaNexus.ClientSettingsStore = ClientSettingsStore

function ClientSettingsStore.Get()
    local db = DB()
    if type(db.settings) ~= "table" then
        db.settings = {}
    end
    return db.settings
end

function ClientSettingsStore.GetFlag(key, default)
    local v = ClientSettingsStore.Get()[key]
    if v == nil then return default end
    return v
end

function ClientSettingsStore.SetFlag(key, value)
    ClientSettingsStore.Get()[key] = value and true or false
end

function ClientSettingsStore.GetNumber(key, default)
    local v = ClientSettingsStore.Get()[key]
    if type(v) ~= "number" then return default end
    return v
end

function ClientSettingsStore.SetNumber(key, value)
    ClientSettingsStore.Get()[key] = value
end

local ANCHOR_DEFAULTS = {
    toastAnchor = { x = 0, y = -200 },
    gotdAnchor  = { x = 0, y = -220 },
}

function ClientSettingsStore.GetAnchor(key)
    local db = DB()
    local def = ANCHOR_DEFAULTS[key] or { x = 0, y = 0 }
    if type(db[key]) ~= "table" then
        db[key] = { x = def.x, y = def.y }
    end
    local a = db[key]
    if type(a.x) ~= "number" then a.x = def.x end
    if type(a.y) ~= "number" then a.y = def.y end
    return a
end

function ClientSettingsStore.SetAnchor(key, x, y)
    local a = ClientSettingsStore.GetAnchor(key)
    if type(x) == "number" then a.x = x end
    if type(y) == "number" then a.y = y end
    return a
end

function ClientSettingsStore.ResetAnchor(key, x, y)
    local def = ANCHOR_DEFAULTS[key] or { x = 0, y = 0 }
    DB()[key] = { x = x or def.x, y = y or def.y }
    return ClientSettingsStore.GetAnchor(key)
end

function ClientSettingsStore.GetWindowPos()
    local pos = DB().windowPos
    if type(pos) ~= "table" then return nil end
    return pos
end

function ClientSettingsStore.SetWindowPos(pos)
    if type(pos) ~= "table" then
        DB().windowPos = nil
        return
    end
    DB().windowPos = pos
end

function ClientSettingsStore.GetGroupOpen(key, default)
    local db = DB()
    if type(db.categoryGroupState) ~= "table" then
        db.categoryGroupState = {}
    end
    local v = db.categoryGroupState[key]
    if v == nil then
        if default == nil then return true end
        return default
    end
    return v
end

function ClientSettingsStore.SetGroupOpen(key, open)
    local db = DB()
    if type(db.categoryGroupState) ~= "table" then
        db.categoryGroupState = {}
    end
    db.categoryGroupState[key] = open and true or false
end

-- ============================================================
-- DEV
-- ============================================================

local DevStore = {}
ArcadiaNexus.DevStore = DevStore

function DevStore.Get()
    local db = DB()
    if type(db.dev) ~= "table" then
        db.dev = { devMode = false }
    end
    return db.dev
end

function DevStore.IsDevMode()
    local v = DevStore.Get().devMode
    return v and v ~= false and v ~= 0 and true or false
end

function DevStore.SetDevMode(enabled)
    DevStore.Get().devMode = enabled and true or false
end
