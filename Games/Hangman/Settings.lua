-- Hangman Settings.lua
-- v1.1.0: Migration auf ArcadiaNexusDB.gameSettings.HANGMAN

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HGM_Settings = {}
local S = ArcadiaNexus.HGM_Settings

local DB_KEY  = "HANGMAN"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    category      = "all",
    difficulty    = "Normal",   -- Easy / Normal / Hard
    soundEnabled  = true,
    wins          = 0,
    losses        = 0,
}

local CATEGORY_ALIASES = {
    all="all", alle="all",
    chars="chars", characters="chars", charaktere="chars",
    places="places", orte="places",
    weapons="weapons", waffen="weapons",
    instances="raids", instanzen="raids", raids="raids",
    ["Schlachtzüge"]="raids", ["schlachtzüge"]="raids", schlachtzuege="raids",
    dungeons="dungeons",
    classes="classes", klassen="classes",
    races="races", ["Völker"]="races", ["völker"]="races", voelker="races", peoples="races",
    bosses="bosses", bosse="bosses",
    factions="factions", fraktionen="factions",
    creatures="creatures", kreaturen="creatures",
    professions="professions", berufe="professions",
}

local function NormalizeCategory(value)
    if type(value) ~= "string" then return "all" end
    return CATEGORY_ALIASES[value] or CATEGORY_ALIASES[string.lower(value)] or "all"
end

local function MigrateSoundKey(db)
    if db.sound ~= nil and db.soundEnabled == nil then
        db.soundEnabled = db.sound
        db.sound = nil
    end
end

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

function S:Get(key)
    local db = GetDB()
    MigrateSoundKey(db)
    local v = db[key]
    if v == nil then return DEFAULTS[key] end
    if key == "category" then
        local normalized = NormalizeCategory(v)
        if normalized ~= v then
            P:SetGameSetting(DB_KEY, key, normalized)
        end
        return normalized
    end
    return v
end

function S:Set(key, value)
    if key == "category" then value = NormalizeCategory(value) end
    P:SetGameSetting(DB_KEY, key, value)
end

function S:IncrWins()
    S:Set("wins", S:Get("wins") + 1)
end

function S:IncrLosses()
    S:Set("losses", S:Get("losses") + 1)
end

function S:GetMaxErrors()
    local diff = S:Get("difficulty")
    if diff == "Easy" then return 8 end
    if diff == "Hard" then return 4 end
    return 6  -- Normal
end

function S:Reset()
    local db = GetDB()
    MigrateSoundKey(db)
    db.soundEnabled = nil
end
