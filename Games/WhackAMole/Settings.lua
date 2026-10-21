-- Whack-a-Mole – Games/WhackAMole/Settings.lua
-- v1.1.0: Migration auf ArcadiaNexusDB.gameSettings.WHACKAMOLE

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.WAM_Settings = {}
local S = ArcadiaNexus.WAM_Settings

local DB_KEY  = "WHACKAMOLE"
local P = ArcadiaNexus.Persistence
local DEFAULTS = {
    difficulty   = "EASY",
    soundEnabled = true,
    soundOnHit   = true,
    soundOnBomb  = true,
    soundOnRound = true,
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
    -- The old panel only exposed hit/bomb switches. Preserve its fully muted
    -- state when the round-sound switch is first introduced.
    if key=="soundOnRound" and v==nil then
        return self:Get("soundOnHit")~=false or self:Get("soundOnBomb")~=false
    end
    if v == nil then return DEFAULTS[key] end
    return v
end

function S:Set(key, value)
    if key=="difficulty" then
        local E=ArcadiaNexus.WAM_Engine
        if E and E._board then return false end
        value=ArcadiaNexus.WAM_Logic:NormalizeDifficulty(value)
    end
    P:SetGameSetting(DB_KEY,key,value)
    return true
end

function S:Reset()
    local db = GetDB()
    MigrateSoundKey(db)
    for k in pairs(DEFAULTS) do
        if k~="difficulty" or not (ArcadiaNexus.WAM_Engine and ArcadiaNexus.WAM_Engine._board) then db[k]=nil end
    end
    local R=ArcadiaNexus.WAM_Renderer
    if R and R.RefreshDifficulty then R:RefreshDifficulty() end
end

-- Highscore-Verwaltung erfolgt ausschliesslich ueber ScoreManager (GAME_RESULT-Event).
