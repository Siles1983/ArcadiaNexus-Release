--[[
    Gaming Hub
    Games/TicTacToe/Settings.lua
    Version: 1.0.0

    Verantwortlichkeiten:
      - Default-Werte definieren
      - Einstellungen lesen / schreiben (ArcadiaNexusDB)
      - Gegenseitige Ausschluss-Regeln durchsetzen
      - Keinerlei UI-Code

    Zugriff von außen NUR über die öffentliche API:
      ArcadiaNexus.TicTacToeSettings:Get(key)
      ArcadiaNexus.TicTacToeSettings:Set(key, value)
      ArcadiaNexus.TicTacToeSettings:Reset()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TicTacToeSettings = {}

local S = ArcadiaNexus.TicTacToeSettings

-- ============================================================
-- DEFAULTS
-- ============================================================

S.Defaults = {

    -- === SYMBOLE ===
    -- Welches Symbol-Set wird genutzt?
    -- Werte: "STANDARD" | "FACTION"
    symbolMode = "STANDARD",

    -- Bei symbolMode = "FACTION":
    -- Welches Wappen wählt Spieler 1?
    -- Werte: "ALLIANCE" | "HORDE"
    player1Symbol = "ALLIANCE",

    -- Bei symbolMode = "FACTION":
    -- automatisch per Charakter-Fraktion bestimmen?
    symbolAutoDetect = true,

    -- === HINTERGRUND ===
    -- Welcher Hintergrund-Typ ist aktiv?
    -- Werte: "NEUTRAL" | "FACTION" | "CLASS" | "RACE"
    -- Nur EINER darf aktiv sein (gegenseitiger Ausschluss)
    backgroundMode = "NEUTRAL",

    -- Bei backgroundMode = "FACTION":
    -- Werte: "ALLIANCE" | "HORDE"
    backgroundFaction = "ALLIANCE",

    -- Automatisch per Charakter-Fraktion bestimmen?
    backgroundFactionAuto = true,

    -- Bei backgroundMode = "CLASS":
    -- Klassenname (englisch, Großbuchstaben), z.B. "WARRIOR"
    backgroundClass = "",

    -- Automatisch per Charakter-Klasse bestimmen?
    backgroundClassAuto = true,

    -- Bei backgroundMode = "RACE":
    -- Rassenname (englisch, Großbuchstaben), z.B. "HUMAN"
    backgroundRace = "",

    -- Automatisch per Charakter-Rasse bestimmen?
    backgroundRaceAuto = true,

    -- === SOUNDS ===
    -- Sounds generell aktiv?
    soundEnabled = true,

    -- Einzelne Sound-Events (nur relevant wenn soundEnabled = true)
    soundOnWin  = true,
    soundOnLoss = true,
    soundOnDraw = true,
}

-- ============================================================
-- INTERNE HILFSFUNKTION: DB-Pfad sicherstellen
-- ============================================================

local DB_KEY = "TICTACTOE"
local P = ArcadiaNexus.Persistence

local function GetDB()
    return P:GetGameSettings(DB_KEY)
end

-- ============================================================
-- PUBLIC API: Get
-- ============================================================

function S:Get(key)
    local db = GetDB()
    if db[key] ~= nil then
        return db[key]
    end
    return S.Defaults[key]
end

-- ============================================================
-- PUBLIC API: Set
-- Schreibt den Wert und erzwingt danach Ausschluss-Regeln.
-- ============================================================

function S:Set(key, value)
    local db = GetDB()
    db[key] = value
    self:_EnforceRules(key)
end

-- ============================================================
-- PUBLIC API: Reset
-- Setzt alle TicTacToe-Einstellungen auf Defaults zurück.
-- ============================================================

function S:Reset()
    local db = GetDB()
    for k, v in pairs(S.Defaults) do
        db[k] = v
    end
end

-- ============================================================
-- PUBLIC API: GetAll
-- Gibt eine flache Kopie aller aktuellen Einstellungen zurück.
-- Nützlich für die UI, damit sie alles in einem Rutsch lesen kann.
-- ============================================================

function S:GetAll()
    local result = {}
    for k, _ in pairs(S.Defaults) do
        result[k] = self:Get(k)
    end
    return result
end

-- ============================================================
-- INTERNE AUSSCHLUSS-REGELN
-- Wird nach jedem Set() aufgerufen.
-- ============================================================

function S:_EnforceRules(changedKey)

    local db = GetDB()

    -- ── Regel 1: Hintergrund-Modi schließen sich gegenseitig aus ──
    -- Wenn backgroundMode gesetzt wird, dürfen keine anderen
    -- backgroundMode-Werte aktiv bleiben – das ist bereits durch
    -- den einzelnen Enum-Wert sichergestellt.
    -- Aber: Wenn backgroundFactionAuto / backgroundClassAuto /
    -- backgroundRaceAuto aktiviert wird, sollen die manuellen
    -- Felder geleert werden.

    if changedKey == "backgroundFactionAuto" and db["backgroundFactionAuto"] == true then
        db["backgroundFaction"] = ""
    end

    if changedKey == "backgroundClassAuto" and db["backgroundClassAuto"] == true then
        db["backgroundClass"] = ""
    end

    if changedKey == "backgroundRaceAuto" and db["backgroundRaceAuto"] == true then
        db["backgroundRace"] = ""
    end

    -- ── Regel 2: Wenn backgroundMode auf NEUTRAL gesetzt wird,
    --    alle Auto-Flags und manuellen Werte zurücksetzen ──
    if changedKey == "backgroundMode" and db["backgroundMode"] == "NEUTRAL" then
        db["backgroundFactionAuto"] = true
        db["backgroundFaction"]     = ""
        db["backgroundClassAuto"]   = true
        db["backgroundClass"]       = ""
        db["backgroundRaceAuto"]    = true
        db["backgroundRace"]        = ""
    end

    -- ── Regel 3: symbolAutoDetect aktiv →
    --    symbolMode auf FACTION setzen + manuellen Symbol-Wert löschen.
    --    Auto-Erkennung macht nur Sinn wenn Fraktions-Wappen aktiv sind.
    if changedKey == "symbolAutoDetect" and db["symbolAutoDetect"] == true then
        db["symbolMode"]    = "FACTION"
        db["player1Symbol"] = ""
    end

    -- ── Regel 4: Sounds generell deaktiviert → alle Einzel-Sounds aus ──
    if changedKey == "soundEnabled" and db["soundEnabled"] == false then
        db["soundOnWin"]  = false
        db["soundOnLoss"] = false
        db["soundOnDraw"] = false
    end

    -- ── Regel 5: Ein Einzel-Sound aktiviert → soundEnabled muss true sein ──
    if (changedKey == "soundOnWin" or changedKey == "soundOnLoss" or changedKey == "soundOnDraw")
        and db[changedKey] == true then
        db["soundEnabled"] = true
    end
end

-- ============================================================
-- INIT
-- Wird von Bootstrap / Engine aufgerufen nachdem DB geladen.
-- Stellt sicher, dass alle Defaults in der DB vorhanden sind.
-- ============================================================

function S:Init()
    local db = GetDB()
    for k, v in pairs(S.Defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
end
