-- ============================================================
--  ArcadiaNexus – Core/DevAccess.lua
--  Wer darf den Developer-Modus nutzen?
--
--  Client-Addons können kein echtes Geheimnis schützen: Alles in Lua
--  und SavedVariables ist les- und änderbar. Ein Passwort im Code ist
--  daher nur eine Hürde, keine Sicherheit.
--
--  Praktisch: Charakter-Allowlist. Andere Spieler sehen den Tab nicht,
--  und ArcadiaNexus.IsDevMode() bleibt aus — auch wenn jemand
--  ArcadiaNexusDB.dev.devMode in den SavedVariables auf true setzt.
--
--  1) /andevwho  →  gibt "Name-Realm" aus
--  2) Eintrag unten in ALLOW_CHARS
--  3) /reload
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus

-- Keys wie /andevwho sie ausgibt, kleingeschrieben.
-- Beispiel: ["siles-stormrage"] = true,
local ALLOW_CHARS = {
}

local function NormalizeKey(name, realm)
    if not name or name == "" then return nil end
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    realm = tostring(realm):gsub("%s+", "")
    return (tostring(name) .. "-" .. realm):lower()
end

local function CurrentPlayerKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    name = name or (UnitName and UnitName("player"))
    return NormalizeKey(name, realm)
end

local function AllowlistActive()
    return next(ALLOW_CHARS) ~= nil
end

local function IsAllowlisted()
    if not AllowlistActive() then return true end
    local key = CurrentPlayerKey()
    return key ~= nil and ALLOW_CHARS[key] == true
end

--- Darf diesen Charakter den Dev-Tab sehen / DevMode schalten?
function ArcadiaNexus.CanAccessDevMode()
    return IsAllowlisted()
end

--- Allowlist ist gesetzt — fremde Charaktere sind ausgesperrt.
function ArcadiaNexus.DevAccessLocked()
    return AllowlistActive()
end

function ArcadiaNexus.GetDevAccessPlayerKey()
    return CurrentPlayerKey()
end

SLASH_ANDEVWHO1 = "/andevwho"
SlashCmdList["ANDEVWHO"] = function()
    local key = CurrentPlayerKey()
    if not key then
        print("|cffffaa00[Arcadia]|r Charakter noch nicht geladen. Im Spiel erneut versuchen.")
        return
    end
    print("|cff7ec8e3[Arcadia]|r DevAccess-Key: |cffffffff" .. key .. "|r")
    print("|cff7ec8e3[Arcadia]|r In Core/DevAccess.lua unter ALLOW_CHARS eintragen:")
    print('|cffaaaaaa["' .. key .. '"] = true,|r')
    if AllowlistActive() then
        if ALLOW_CHARS[key] then
            print("|cff00ff88[Arcadia]|r Dieser Charakter ist auf der Allowlist.")
        else
            print("|cffffaa00[Arcadia]|r Dieser Charakter ist NICHT auf der Allowlist.")
        end
    else
        print("|cffffaa00[Arcadia]|r Allowlist ist leer — DevMode ist derzeit nicht an Charaktere gebunden.")
    end
end
