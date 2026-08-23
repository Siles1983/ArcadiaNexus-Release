-- Whack-a-Mole – Games/WhackAMole/Settings.lua
-- v1.1.0: Migration auf ArcadiaNexusDB.gameSettings.WHACKAMOLE

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.WAM_Settings = {}
local S = ArcadiaNexus.WAM_Settings

local DB_KEY  = "WHACKAMOLE"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    soundEnabled = true,
    soundOnHit   = true,
    soundOnBomb  = true,
}

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
    return v
end

function S:Set(key, value) P:SetGameSetting(DB_KEY, key, value) end

function S:Reset()
    local db = GetDB()
    MigrateSoundKey(db)
    for k in pairs(DEFAULTS) do db[k] = nil end
end

-- Highscore-Verwaltung erfolgt ausschliesslich ueber ScoreManager (GAME_RESULT-Event).
