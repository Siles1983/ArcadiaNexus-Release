--[[
    ArcadiaNexus – Core/Debug.lua
    Zentrales Logging-System

    Verwendung:
        GH_LogInfo("XPManager", "Initialisiert")
        GH_LogWarn("Engine", "StopGame ohne laufendes Spiel")
        GH_LogError("Bootstrap", "ChallengeManager Init fehlgeschlagen: " .. err)
        GH_LogDebug("Snake", "Tick: pos=(" .. x .. "," .. y .. ")")  -- nur im devMode

    devMode aktivieren:
        ArcadiaNexusDB.dev.devMode = true  (via SettingsPanel-Checkbox)

    Slash-Commands:
        /andevcheck    – zeigt devMode-Status
        /anlogs        – zeigt die letzten Log-Einträge
        /anclearlogs   – leert den Log-Buffer
        /anachcheck    – prüft Achievement-Icons auf Lücken
]]

-- ============================================================
-- LOG HISTORY (Ring-Buffer)
-- ============================================================

local LOG_MAX = 100
local _logBuffer = {}
local _logIndex  = 0

local function _StoreLog(level, source, msg)
    _logIndex = _logIndex + 1
    if _logIndex > LOG_MAX then
        table.remove(_logBuffer, 1)
        _logIndex = LOG_MAX
    end
    _logBuffer[_logIndex] = {
        time   = date("%H:%M:%S"),
        level  = level,
        source = source or "",
        msg    = tostring(msg),
    }
end

-- ============================================================
-- INTERNE HILFSFUNKTIONEN
-- ============================================================

local function _IsAllowlisted()
    if ArcadiaNexus.CanAccessDevMode then
        return ArcadiaNexus.CanAccessDevMode() == true
    end
    return true
end

local function _IsDevMode()
    if not _IsAllowlisted() then
        return false
    end
    return ArcadiaNexusDB
        and ArcadiaNexusDB.dev
        and ArcadiaNexusDB.dev.devMode
        and ArcadiaNexusDB.dev.devMode ~= false
        and ArcadiaNexusDB.dev.devMode ~= 0
        or false
end

-- Öffentliche API — nutzbar von allen Modulen
function ArcadiaNexus.IsDevMode()
    return _IsDevMode()
end

local PREFIX_INFO  = "|cff7ec8e3[GH INFO]|r "
local PREFIX_WARN  = "|cffffaa00[GH WARN]|r "
local PREFIX_ERROR = "|cffff4444[GH ERROR]|r "
local PREFIX_DEBUG = "|cffaaaaaa[GH DEBUG]|r "

local PREFIXES = {
    INFO  = PREFIX_INFO,
    WARN  = PREFIX_WARN,
    ERROR = PREFIX_ERROR,
    DEBUG = PREFIX_DEBUG,
}

local function _Format(prefix, source, msg)
    if source and source ~= "" then
        return prefix .. "|cffcccccc" .. tostring(source) .. ":|r " .. tostring(msg)
    end
    return prefix .. tostring(msg)
end

local function _ParseArgs(source, msg)
    if msg == nil then
        return "", source
    end
    return source, msg
end

-- ============================================================
-- ÖFFENTLICHE API
-- ============================================================

--- Normaler Lifecycle-Log. Immer sichtbar im devMode.
--- Im Normalmode: nur gespeichert, nicht im Chat.
function GH_LogInfo(source, msg)
    source, msg = _ParseArgs(source, msg)
    _StoreLog("INFO", source, msg)
    if _IsDevMode() then
        print(_Format(PREFIX_INFO, source, msg))
    end
end

--- Warnung bei behebbaren Anomalien. Immer sichtbar.
function GH_LogWarn(source, msg)
    source, msg = _ParseArgs(source, msg)
    _StoreLog("WARN", source, msg)
    print(_Format(PREFIX_WARN, source, msg))
end

--- Fehler bei kritischen Failures. Immer sichtbar.
function GH_LogError(source, msg)
    source, msg = _ParseArgs(source, msg)
    _StoreLog("ERROR", source, msg)
    print(_Format(PREFIX_ERROR, source, msg))
end

--- Detail-Log. Nur sichtbar wenn devMode aktiv.
function GH_LogDebug(source, msg)
    source, msg = _ParseArgs(source, msg)
    _StoreLog("DEBUG", source, msg)
    if _IsDevMode() then
        print(_Format(PREFIX_DEBUG, source, msg))
    end
end

-- ============================================================
-- LOG QUERY API (für UI oder andere Module)
-- ============================================================

--- Gibt die letzten N Log-Einträge zurück (neueste zuletzt).
--- Optional filterbar nach level ("INFO", "WARN", "ERROR", "DEBUG").
function GH_GetLogs(count, levelFilter)
    count = count or LOG_MAX
    local result = {}
    local start = math.max(1, _logIndex - count + 1)
    for i = start, _logIndex do
        local entry = _logBuffer[i]
        if entry then
            if not levelFilter or entry.level == levelFilter then
                result[#result + 1] = entry
            end
        end
    end
    return result
end

function GH_ClearLogs()
    _logBuffer = {}
    _logIndex  = 0
end

function GH_GetLogCount()
    return _logIndex
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

-- /andevcheck – zeigt devMode-Status
SLASH_ANDEVCHECK1 = "/andevcheck"
SlashCmdList["ANDEVCHECK"] = function()
    local active = _IsDevMode()
    local raw    = ArcadiaNexusDB and ArcadiaNexusDB.dev and ArcadiaNexusDB.dev.devMode
    local allowed = _IsAllowlisted()
    if active then
        print("|cff00ff88[GH]|r Developer-Modus ist |cff00ff88AKTIV|r. (DB-Wert: " .. tostring(raw) .. ")")
    else
        print("|cffffaa00[GH]|r Developer-Modus ist |cffffaa00INAKTIV|r. (DB-Wert: " .. tostring(raw) .. ")")
        if not allowed then
            print("|cffffaa00[GH]|r Dieser Charakter steht nicht auf der DevAccess-Allowlist. /andevwho")
        end
    end
        print("|cff7ec8e3[GH]|r Log-Einträge: " .. _logIndex .. "/" .. LOG_MAX)
end

-- /anlogs [count] [level] – zeigt die letzten Log-Einträge
SLASH_ANLOGS1 = "/anlogs"
SlashCmdList["ANLOGS"] = function(input)
    local args = {}
    for word in (input or ""):gmatch("%S+") do
        args[#args + 1] = word
    end
    local count = tonumber(args[1]) or 20
    local level = args[2] and args[2]:upper() or nil

    local logs = GH_GetLogs(count, level)
    if #logs == 0 then
        print("|cff7ec8e3[GH]|r Keine Log-Einträge" .. (level and (" für Level " .. level) or "") .. ".")
        return
    end

    print("|cff7ec8e3[GH]|r --- Letzte " .. #logs .. " Log-Eintraege ---")
    for _, entry in ipairs(logs) do
        local prefix = PREFIXES[entry.level] or ""
        local src = entry.source ~= "" and ("|cffcccccc" .. entry.source .. ":|r ") or ""
        print("|cff666666" .. entry.time .. "|r " .. prefix .. src .. entry.msg)
    end
    print("|cff7ec8e3[GH]|r --- Ende ---")
end

-- /anclearlogs – leert den Buffer
SLASH_ANCLEARLOGS1 = "/anclearlogs"
SlashCmdList["ANCLEARLOGS"] = function()
    GH_ClearLogs()
    print("|cff7ec8e3[GH]|r Log-Buffer geleert.")
end

-- /anachcheck – Achievement-Icon-Audit (Dev-Log + Chat)
SLASH_ANACHCHECK1 = "/anachcheck"
SlashCmdList["ANACHCHECK"] = function()
    local AI = ArcadiaNexus and ArcadiaNexus.AchievementIcons
    if not AI then
        print("|cffff4444[GH]|r AchievementIcons-Modul nicht geladen.")
        return
    end

    local result = AI:AuditRegistered()
    local total  = result.total or 0
    local count  = result.issueCount or 0

    if count == 0 then
        print("|cff00ff88[GH]|r Achievement-Icon-Check: " .. total .. " Gruppen, keine Probleme.")
        GH_LogInfo("AchievementIcons", "Audit OK – " .. total .. " Gruppen geprüft.")
        return
    end

    print("|cffffaa00[GH]|r Achievement-Icon-Check: " .. count .. " Problem(e) bei " .. total .. " Gruppen.")
    for _, issue in ipairs(result.issues or {}) do
        local iconStr = issue.icon == nil and "nil"
            or (issue.icon == "" and '""')
            or tostring(issue.icon)
        local msg = string.format(
            "%s (%s): ungültiges Icon %s",
            tostring(issue.id),
            tostring(issue.gameId or "?"),
            iconStr
        )
        GH_LogWarn("AchievementIcons", msg)
        print("|cffffaa00[GH WARN]|r |cffccccccAchievementIcons:|r " .. msg)
    end
end
