--[[
    ArcadiaNexus – Core/GameRegistry.lua

    Zentrale Hub-Registry für Spiel-Metadaten (Sidebar, Tabs, Settings).
    Einziger Speicherort für RegisterGame-Einträge.

    Öffentliche API:
        ArcadiaNexus.RegisterGame(info)           – Facade (Bootstrap.lua)
        ArcadiaNexus.GameRegistry.Register(info)
        ArcadiaNexus.GameRegistry.GetById(id)
        ArcadiaNexus.GameRegistry.GetLabel(id)
        ArcadiaNexus.GameRegistry.Exists(id)
        ArcadiaNexus.GameRegistry.ShouldShowGame(game, opts)
        ArcadiaNexus.GameRegistry.FILTER_SIDEBAR / FILTER_HUB_MANAGE / FILTER_REGISTRY
        ArcadiaNexus.GameRegistry.Iterate(opts, fn)
        ArcadiaNexus.GameRegistry.GetVisibleGames(opts)
        ArcadiaNexus.GameRegistry.GetIds(opts)
        ArcadiaNexus.GameRegistry.SortByLabel(list)
        ArcadiaNexus.GameRegistry.GetFirst(opts)
        ArcadiaNexus.GameRegistry.GetRandom(opts)
        ArcadiaNexus.GameRegistry.GetEngine(id)
        ArcadiaNexus.GameRegistry.GetRenderer(id)
        ArcadiaNexus.GameRegistry.GetContainer(id)
        ArcadiaNexus.GameRegistry.HideAllContainers()
        ArcadiaNexus.GameRegistry.ShowContainer(id)
        ArcadiaNexus.GameRegistry.StopActiveGame()
        ArcadiaNexus.GameRegistry.InitRenderer(id)
        ArcadiaNexus.GameRegistry.InitRenderers()
        ArcadiaNexus.GameRegistry.GetRendererInitStatus(id)
        ArcadiaNexus.GameRegistry.SetupInitialContainers()
        ArcadiaNexus.GameRegistry.GetAll()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GameRegistry = {}
local GR = ArcadiaNexus.GameRegistry

local registry = {}
local byId = {}
local rendererInitState = {}

local function CaptureError(err)
    local message = tostring(err)
    if debugstack then
        local ok, trace = pcall(debugstack, 2, 20, 20)
        if ok and trace and trace ~= "" then
            message = message .. "\n" .. trace
        end
    end
    return message
end

local function LogGameError(gameId, action, err)
    GH_LogError("GameRegistry",
        tostring(action) .. " fehlgeschlagen [" .. tostring(gameId) .. "]: " .. tostring(err))
end

local function SafeContainerCall(gameId, container, method)
    if not container or type(container[method]) ~= "function" then
        return false
    end
    local ok, err = xpcall(function()
        container[method](container)
    end, CaptureError)
    if not ok then
        LogGameError(gameId, "Container:" .. method, err)
    end
    return ok
end

-- Standard-Filter-Policies (single source of truth)
GR.FILTER_SIDEBAR     = { includeDevOnly = true,  respectHidden = true }
GR.FILTER_HUB_MANAGE  = { includeDevOnly = false, respectHidden = false }
GR.FILTER_REGISTRY    = { includeDevOnly = true,  respectHidden = false }

local function NotifyHubRegistryChanged()
    local UI = ArcadiaNexus.UI
    if UI and UI.OnHubRegistryChanged then
        pcall(UI.OnHubRegistryChanged)
    end
end

--- @param info table
--- @param opts table|nil  { includeDevOnly?, respectHidden? }
--- @return boolean
function GR.IsVisible(info, opts)
    if not info or not info.id then
        return false
    end

    opts = opts or {}

    if info.devOnly then
        if not opts.includeDevOnly then
            return false
        end
        local isDevMode = ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() == true
        if not isDevMode then
            return false
        end
    end

    if opts.respectHidden ~= false then
        if ArcadiaNexusDB and ArcadiaNexusDB.hiddenGames and ArcadiaNexusDB.hiddenGames[info.id] then
            return false
        end
    end

    return true
end

--- Sichtbarkeit + Sidebar-Suchfilter (_filterState.query).
--- @param game table  { id, label? }
--- @param opts table|nil  IsVisible-Optionen
--- @return boolean
function GR.ShouldShowGame(game, opts)
    if not game or not game.id then
        return false
    end

    opts = opts or GR.FILTER_SIDEBAR
    local info = GR.GetById(game.id)
    if info and not GR.IsVisible(info, opts) then
        return false
    end

    local q = ArcadiaNexus._filterState and ArcadiaNexus._filterState.query or ""
    if q == "" then
        return true
    end

    q = string.lower(q)
    local label = game.label or (info and info.label) or game.id
    if label and string.find(string.lower(label), q, 1, true) then
        return true
    end
    if string.find(string.lower(game.id), q, 1, true) then
        return true
    end
    return false
end

local function MatchesOpts(info, opts)
    if not GR.IsVisible(info, opts) then
        return false
    end
    if opts and opts.category and info.category ~= opts.category then
        return false
    end
    if opts and opts.excludeId and info.id == opts.excludeId then
        return false
    end
    if opts and opts.requireContainer and not info.container then
        return false
    end
    return true
end

--- @param info table  { id, label, category, renderer, engine, container, devOnly, ... }
--- @return boolean
function GR.Register(info)
    if not info or not info.id then
        return false
    end

    if byId[info.id] then
        GH_LogWarn("GameRegistry", "Spiel bereits registriert: " .. tostring(info.id))
        return false
    end

    local CR = ArcadiaNexus.CategoryRegistry
    if info.category and CR and CR.ResolveId then
        info.category = CR.ResolveId(info.category) or info.category
    end
    if info.category and info.category ~= "SONSTIGE" then
        if CR and CR.GetById and not CR.GetById(info.category) then
            GH_LogWarn("GameRegistry",
                "Unbekannte category für " .. tostring(info.id) .. ": " .. tostring(info.category)
                .. " (DE/EN-ID, Alias oder Anzeigename verwenden)")
        end
    end

    table.insert(registry, info)
    byId[info.id] = info
    NotifyHubRegistryChanged()
    return true
end

--- @return boolean
function GR.Exists(id)
    return GR.GetById(id) ~= nil
end

--- @return table|nil
function GR.GetById(id)
    if not id then return nil end
    return byId[id]
end

--- @return string
function GR.GetLabel(id)
    local info = GR.GetById(id)
    if info and info.label then
        return info.label
    end
    return id or "–"
end

--- opts: { visibleOnly?, includeDevOnly?, respectHidden?, category?, excludeId?, requireContainer? }
--- fn(info) bei jedem Treffer; ohne fn → Iterator via GetVisibleGames
function GR.Iterate(opts, fn)
    opts = opts or {}
    if opts.visibleOnly then
        opts.includeDevOnly = opts.includeDevOnly ~= false
        opts.respectHidden   = opts.respectHidden ~= false
    end

    for _, info in ipairs(registry) do
        if MatchesOpts(info, opts) then
            if fn then
                fn(info)
            end
        end
    end
end

--- @return table[]
function GR.GetVisibleGames(opts)
    local list = {}
    GR.Iterate(opts, function(info)
        table.insert(list, info)
    end)
    return list
end

--- @return string[]
function GR.GetIds(opts)
    local ids = {}
    GR.Iterate(opts, function(info)
        table.insert(ids, info.id)
    end)
    return ids
end

--- Sortiert Anzeige-Listen { id, label? } alphabetisch (case-insensitive).
--- In-place. Tie-Breaker: id. Ändert nicht die interne Registry-Reihenfolge.
--- @param list table[]
--- @return table[]
function GR.SortByLabel(list)
    if not list or #list < 2 then
        return list
    end
    table.sort(list, function(a, b)
        local la = string.lower((a and (a.label or a.id)) or "")
        local lb = string.lower((b and (b.label or b.id)) or "")
        if la ~= lb then
            return la < lb
        end
        return ((a and a.id) or "") < ((b and b.id) or "")
    end)
    return list
end

--- @return table|nil
function GR.GetFirst(opts)
    local found = nil
    GR.Iterate(opts, function(info)
        if not found then
            found = info
        end
    end)
    return found
end

--- opts darf die shared FILTER_*-Tabellen sein; excludeId wird nicht darauf geschrieben.
--- @return table|nil
function GR.GetRandom(opts)
    local filter = opts or GR.FILTER_SIDEBAR
    local games = GR.GetVisibleGames(filter)
    if #games == 0 then
        return nil
    end
    if #games == 1 then
        return games[1]
    end
    return games[math.random(#games)]
end

--- @return table|nil
function GR.GetEngine(id)
    local info = GR.GetById(id)
    if not info or not info.engine then return nil end
    return ArcadiaNexus[info.engine]
end

--- @return table|nil
function GR.GetRenderer(id)
    local info = GR.GetById(id)
    if not info or not info.renderer then return nil end
    return ArcadiaNexus[info.renderer]
end

--- @return table|nil
function GR.GetContainer(id)
    local info = GR.GetById(id)
    if not info or not info.container then return nil end
    return ArcadiaNexus[info.container]
end

function GR.HideAllContainers()
    for _, info in ipairs(registry) do
        local container = GR.GetContainer(info.id)
        if container then
            SafeContainerCall(info.id, container, "Hide")
        end
    end
end

function GR.ShowContainer(id)
    local state = rendererInitState[id]
    if state and state.state == "failed" then
        GH_LogWarn("GameRegistry", "Spiel ist wegen Renderer-Fehler nicht verfügbar: " .. tostring(id))
        return false
    end

    local container = GR.GetContainer(id)
    if container then
        return SafeContainerCall(id, container, "Show")
    end
    return false
end

--- Stoppt nur das aktuell laufende Spiel (Lifecycle-aware).
function GR.StopActiveGame()
    local LC = ArcadiaNexus.Lifecycle
    local activeId = LC and LC:GetActiveGame()
    if not activeId then
        return
    end

    local eng = GR.GetEngine(activeId)
    local rnd = GR.GetRenderer(activeId)
    local stopTarget, stopMethod
    if eng and eng.StopGame then
        stopTarget, stopMethod = eng, "StopGame"
    elseif rnd and rnd.StopGame then
        stopTarget, stopMethod = rnd, "StopGame"
    elseif rnd and rnd.EnterIdleState then
        stopTarget, stopMethod = rnd, "EnterIdleState"
    end

    if stopTarget then
        local ok, err = xpcall(function()
            stopTarget[stopMethod](stopTarget)
        end, CaptureError)
        if not ok then
            LogGameError(activeId, stopMethod, err)
        end
    end

    if LC and LC:IsGameActive() then
        local cur = ArcadiaNexus.GameSession and ArcadiaNexus.GameSession:GetCurrent()
        if cur then
            LC:EndGame(cur.gameId, cur.sessionId)
        end
    end
end

--- Initialisiert genau einen Renderer hinter einer Fehlergrenze.
--- Ein defektes Spiel darf weder weitere Renderer noch den Hub-Bootstrap abbrechen.
--- Erfolgreiche und fehlgeschlagene Initialisierungen werden in dieser UI-Session
--- nicht automatisch wiederholt, da viele Renderer Event-Listener registrieren.
function GR.InitRenderer(id)
    local info = GR.GetById(id)
    if not info then
        return false, "Spiel nicht registriert: " .. tostring(id)
    end

    local previous = rendererInitState[id]
    if previous then
        if previous.state == "ready" then
            return true
        end
        if previous.state == "failed" then
            return false, previous.error
        end
        if previous.state == "initializing" then
            return false, "Renderer-Initialisierung läuft bereits"
        end
    end

    local rnd = GR.GetRenderer(id)
    if not rnd or type(rnd.Init) ~= "function" then
        local err = "Renderer oder Init-Funktion fehlt"
        rendererInitState[id] = { state = "failed", error = err }
        LogGameError(id, "Renderer:Init", err)
        return false, err
    end

    rendererInitState[id] = { state = "initializing" }
    local ok, err = xpcall(function()
        rnd:Init()
    end, CaptureError)

    if ok then
        rendererInitState[id] = { state = "ready" }
        return true
    end

    rendererInitState[id] = { state = "failed", error = err }
    local container = GR.GetContainer(id)
    if container then
        SafeContainerCall(id, container, "Hide")
    end
    LogGameError(id, "Renderer:Init", err)
    return false, err
end

function GR.GetRendererInitStatus(id)
    local status = rendererInitState[id]
    if not status then
        return "pending", nil
    end
    return status.state, status.error
end

function GR.InitRenderers()
    local summary = { ready = 0, failed = 0 }
    GR.Iterate(GR.FILTER_REGISTRY, function(info)
        local ok = GR.InitRenderer(info.id)
        if ok then
            summary.ready = summary.ready + 1
        else
            summary.failed = summary.failed + 1
        end
    end)
    return summary
end

--- Erstes registriertes Spiel sichtbar, alle anderen Container versteckt.
function GR.SetupInitialContainers()
    local firstId
    GR.Iterate(GR.FILTER_REGISTRY, function(info)
        local status = rendererInitState[info.id]
        if not firstId and status and status.state == "ready" and GR.GetContainer(info.id) then
            firstId = info.id
        end
    end)

    GR.Iterate(GR.FILTER_REGISTRY, function(info)
        local container = GR.GetContainer(info.id)
        if container then
            if info.id == firstId then
                SafeContainerCall(info.id, container, "Show")
            else
                SafeContainerCall(info.id, container, "Hide")
            end
        end
    end)
end

--- @return table
function GR.GetAll()
    return registry
end
