--[[
    ArcadiaNexus – Core/GameRegistry.lua

    Zentrale Hub-Registry für Spiel-Metadaten (Sidebar, Tabs, Settings).
    Einziger Speicherort für RegisterGame-Einträge.

    Öffentliche API:
        ArcadiaNexus.RegisterGame(info)           – Facade (Bootstrap.lua)
        ArcadiaNexus.GameRegistry.Register(info)
        ArcadiaNexus.GameRegistry.GetById(id)
        ArcadiaNexus.GameRegistry.GetLogo(id)
        ArcadiaNexus.GameRegistry.GetLabel(id)
        ArcadiaNexus.GameRegistry.GetBaseXP(id)
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
        ArcadiaNexus.GameRegistry.LeaveActiveGame()
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
GR.DEFAULT_BASE_XP    = 10

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
        if ArcadiaNexus.HiddenGamesStore and ArcadiaNexus.HiddenGamesStore.IsHidden(info.id) then
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
    if ArcadiaNexus.RetiredContent and ArcadiaNexus.RetiredContent:IsGame(info.id) then return false end

    if byId[info.id] then
        GH_LogWarn("GameRegistry", "Spiel bereits registriert: " .. tostring(info.id))
        return false
    end

    if info.xp ~= nil then
        if type(info.xp) ~= "number" or info.xp < 0 then
            GH_LogWarn("GameRegistry", "Ungültiges xp für " .. tostring(info.id) .. " – Default " .. tostring(GR.DEFAULT_BASE_XP))
            info.xp = nil
        else
            info.xp = math.floor(info.xp)
        end
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

local function LogoPathFromTex(tex)
    if not tex then return nil end
    local path = tex._anLogoPath
    if type(path) == "string" and path ~= "" then
        return path
    end
    return nil
end

--- Logo-Pfad: Idle-Textur von `CreateGameLogo` (tatsächliches Asset), sonst `RegisterGame.logo`.
--- Ohne Renderer-Init bleibt nur `RegisterGame.logo` (InitRenderers läuft beim Hub-Start).
--- @return string|nil
function GR.GetLogo(id)
    local rnd = GR.GetRenderer(id)
    local fromIdle = rnd and (
        LogoPathFromTex(rnd._logoTex)
        or LogoPathFromTex(rnd._logo)
        or LogoPathFromTex(rnd._F and rnd._F.logoTex)
    )
    if fromIdle then return fromIdle end
    local info = GR.GetById(id)
    if info and type(info.logo) == "string" and info.logo ~= "" then
        return info.logo
    end
    return nil
end

--- @return string
function GR.GetLabel(id)
    local info = GR.GetById(id)
    if info and info.label then
        return info.label
    end
    return id or "–"
end

--- Basis-XP für GAME_RESULT. Ohne Feld oder ungültig: DEFAULT_BASE_XP.
--- @return number
function GR.GetBaseXP(id)
    local info = GR.GetById(id)
    local xp = info and info.xp
    if type(xp) ~= "number" or xp < 0 then
        return GR.DEFAULT_BASE_XP
    end
    return xp
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

--- Solo-Abschluss. StopGame bleibt der Abbruch, wenn das Spiel keinen
--- Speichervertrag hat. SaveAndPause wird danach nicht noch einmal gestoppt.
local CLOSE_METHOD = {
    ARCADIASECHO = "StopGame",
    SUDOKU = "SaveAndPause",
    MINESWEEPER = "SaveAndPause",
    CODEBREAKER = "SaveAndPause",
    WHACKAMOLE = "StopGame",
    HANGMAN = "StopGame",
    SHADOWSCONQUEST = "SaveAndPause",
    MOSAICOFAZEROTH = "SaveAndPause",
    BLACKJACK = "SaveAndPause",
    CHESS = "StopGame",
    ARCADIAPAIRS = "StopGame",
    SI7 = "StopGame",
    TAVERNCARDS = "SaveAndPause",
    GALLYWIX = "SaveAndPause",
}

local function RunIdOf(eng)
    if not eng then return nil end
    if type(eng._runId) == "string" and eng._runId ~= "" then return eng._runId end
    local gs = eng.gameState or eng.activeGame
    if type(gs) == "table" and type(gs.runId) == "string" and gs.runId ~= "" then
        return gs.runId
    end
    return nil
end

local function TargetHeld(eng, gameId, sessionId)
    if not sessionId then return false end
    if eng and eng._sessionId == sessionId then return true end
    local GS = ArcadiaNexus.GameSession
    local cur = GS and GS.GetCurrent and GS:GetCurrent()
    return cur ~= nil and cur.sessionId == sessionId and cur.gameId == gameId
end

local function MarkBlocked(eng, sessionId)
    local GS = ArcadiaNexus.GameSession
    if GS and GS.MarkResumeFailed and eng and sessionId and eng._sessionId == sessionId then
        GS:MarkResumeFailed(sessionId)
    end
    return false, "blocked"
end

local function SelectCloseMethod(gameId, eng, purpose)
    local listed = CLOSE_METHOD[gameId]
    if purpose ~= "stop" and listed and type(eng[listed]) == "function" then
        return listed
    end
    if purpose == "stop" and type(eng.StopGame) == "function" then
        return "StopGame"
    end
    if listed and type(eng[listed]) == "function" then return listed end
    if type(eng.SaveAndPause) == "function" then return "SaveAndPause" end
    if type(eng.SaveAndStop) == "function" then return "SaveAndStop" end
    if type(eng.StopGame) == "function" then return "StopGame" end
    return nil
end

local function CleanupIsStale(note)
    if not note then return false end
    local eng = GR.GetEngine(note.gameId)
    if eng and eng._sessionId and eng._sessionId ~= note.sessionId then return true end
    local GS = ArcadiaNexus.GameSession
    local cur = GS and GS.GetCurrent and GS:GetCurrent()
    if cur and cur.sessionId ~= note.sessionId and cur.gameId == note.gameId then return true end
    local runId = RunIdOf(eng)
    if note.runId and runId and runId ~= note.runId and eng and eng._sessionId then return true end
    return false
end

--- Stoppt nur das aktuell laufende Spiel (Lifecycle-aware).
--- Rückgabe: Boolean, dann ended | already-ended | blocked | confirmation-pending | view-hidden | stale.
function GR.StopActiveGame(opts)
    return GR._FinishActive("stop", opts)
end

local MATCH_MODES = { host = true, join = true, rejoin = true }

--- Netzwerkpartie: SaveAndPause ist dort kein gemeinsamer Speichervertrag.
local function IsNetworkMatch(eng)
    if type(eng.match) == "table" then return true end
    return MATCH_MODES[eng.mode] == true
end

function GR.HasPendingCleanup()
    return GR._cleanup ~= nil
end

function GR.IdleRenderer(gameId, sessionId)
    local eng = GR.GetEngine(gameId)
    if sessionId and eng and eng._sessionId and eng._sessionId ~= sessionId then
        return false, "stale"
    end
    local rnd = GR.GetRenderer(gameId)
    if not rnd then return false, "blocked" end
    local method, arg
    if type(rnd.EnterIdleState) == "function" then
        method = "EnterIdleState"
    elseif type(rnd.EnterIdle) == "function" then
        method = "EnterIdle"
    elseif type(rnd._EnterIdleState) == "function" then
        method = "_EnterIdleState"
    elseif type(rnd.SetState) == "function" then
        method, arg = "SetState", "IDLE"
    else
        return false, "blocked"
    end
    local returned
    local ok, err = xpcall(function()
        if arg then returned = rnd[method](rnd, arg) else returned = rnd[method](rnd) end
    end, CaptureError)
    if not ok then
        LogGameError(gameId, method, err)
        return false, "blocked"
    end
    if returned == false then
        LogGameError(gameId, method, "Cleanup abgelehnt")
        return false, "blocked"
    end
    if sessionId and eng and eng._sessionId and eng._sessionId ~= sessionId then
        return false, "stale"
    end
    return true, "ended"
end

local function RememberCleanup(gameId, sessionId, runId, kind)
    GR._cleanup = {
        gameId = gameId, sessionId = sessionId, runId = runId,
        kind = kind == "engine" and "engine" or "renderer",
        engine = GR.GetEngine(gameId),
        renderer = GR.GetRenderer(gameId),
    }
    return false, "blocked"
end

function GR.NotePendingCleanup(gameId, sessionId, kind)
    if GR._cleanup then return false end
    local eng = GR.GetEngine(gameId)
    if eng and eng._sessionId and sessionId and eng._sessionId ~= sessionId then return false end
    RememberCleanup(gameId, sessionId, nil, kind)
    return true
end

local function NeedsLocalConfirm(gameId, eng)
    if gameId == "SHELLGAME" then
        local gs = eng.gameState
        local phase = gs and gs.phase
        return phase == "REVEAL" or phase == "SHUFFLE" or phase == "GUESSING"
    end
    if gameId == "TICTACTOE" then
        return eng.mode == "hotseat" and eng.activeGame ~= nil
            and type(eng.IsSeriesOver) == "function" and not eng:IsSeriesOver()
    end
    return false
end

local function ConfirmLive(pending)
    if not pending then return false end
    local eng = GR.GetEngine(pending.gameId)
    return eng and eng._sessionId == pending.sessionId or false
end

local function PopupStillOpen(pending)
    local UI = ArcadiaNexus.UI
    local parent = pending and pending.parent
    local popup = parent and UI and UI._choicePopups and UI._choicePopups[parent]
    local owner = popup and popup._anOwner
    return popup and popup.IsShown and popup:IsShown()
        and owner and owner.gameId == pending.gameId and owner.sessionId == pending.sessionId
end

local function OpenLocalConfirm(gameId, eng, sessionId)
    local pending = GR._confirm
    if pending and not ConfirmLive(pending) then
        GR._confirm = nil
        pending = nil
    end
    if pending and pending.gameId == gameId and pending.sessionId == sessionId and PopupStillOpen(pending) then
        return false, "confirmation-pending"
    end
    local rnd = GR.GetRenderer(gameId)
    if not rnd or type(rnd.RequestExit) ~= "function" then
        return false, "blocked"
    end
    GR._confirm = {
        gameId = gameId,
        sessionId = sessionId,
        identity = gameId == "SHELLGAME" and eng.gameState and eng.gameState.runId or eng.activeGame,
    }
    local ran, err = xpcall(function()
        rnd:RequestExit()
    end, CaptureError)
    if not ran then
        GR._confirm = nil
        LogGameError(gameId, "RequestExit", err)
        return false, "blocked"
    end
    if not TargetHeld(eng, gameId, sessionId) then
        return false, "stale"
    end
    return false, "confirmation-pending"
end

local function TerminalSudoku()
    local eng = GR.GetEngine("SUDOKU")
    local rnd = GR.GetRenderer("SUDOKU")
    if not eng or eng._sessionId or eng.state ~= "COMPLETE" or not eng.activeGame then
        return nil
    end
    if not rnd or rnd.state ~= "COMPLETE" then
        return false
    end
    return eng
end

local function FinishCleanup(note)
    if note.kind == "engine" then return false, "blocked" end
    if note.engine and GR.GetEngine(note.gameId) ~= note.engine then return false, "blocked" end
    if note.renderer and GR.GetRenderer(note.gameId) ~= note.renderer then return false, "blocked" end
    if CleanupIsStale(note) then
        return false, "stale"
    end
    local ok, reason = GR.IdleRenderer(note.gameId, note.sessionId)
    if not ok then
        return false, reason or "blocked"
    end
    if note.gameId == "SUDOKU" and note.engine and not note.engine._sessionId and note.engine.state == "COMPLETE" then
        note.engine.state = "IDLE"
        note.engine.activeGame = nil
    end
    GR._cleanup = nil
    return true, "ended"
end

function GR._FinishActive(purpose, opts)
    if GR._closing then return false, "blocked" end
    GR._closing = true
    local ok, status, reason = pcall(function()
        local force = type(opts) == "table" and opts.force == true
        local cleaned = false
        local note = GR._cleanup
        if note then
            local done, why = FinishCleanup(note)
            if not done then
                return false, why or "blocked"
            end
            cleaned = true
        end
        local LC = ArcadiaNexus.Lifecycle
        local GS = ArcadiaNexus.GameSession
        local activeId = LC and LC:GetActiveGame()
        if not activeId then
            local terminal = TerminalSudoku()
            if terminal == false then return false, "blocked" end
            if terminal then
                local idleOk, idleWhy = GR.IdleRenderer("SUDOKU", nil)
                if not idleOk then
                    if idleWhy == "stale" then return false, "stale" end
                    return RememberCleanup("SUDOKU", nil, RunIdOf(terminal), "renderer")
                end
                if not terminal._sessionId and terminal.state == "COMPLETE" then
                    terminal.state = "IDLE"
                    terminal.activeGame = nil
                end
                return true, "ended"
            end
            return true, cleaned and "ended" or "already-ended"
        end
        local cur = GS and GS.GetCurrent and GS:GetCurrent()
        local sessionId = cur and cur.gameId == activeId and cur.sessionId or nil
        local eng = GR.GetEngine(activeId)
        if not eng then return false, "blocked" end
        if eng._sessionId and sessionId and eng._sessionId ~= sessionId then
            return false, "stale"
        end
        if IsNetworkMatch(eng) and not force then
            return false, purpose == "leave" and "view-hidden" or "blocked"
        end
        if sessionId and GS and GS.ResumeSaveBlocked and GS:ResumeSaveBlocked(sessionId) and not force then
            return false, "blocked"
        end
        local confirmed = type(opts) == "table" and opts.confirmed == true
        if confirmed then
            if opts.gameId ~= activeId or not TargetHeld(eng, activeId, opts.sessionId) then
                return false, "stale"
            end
            sessionId = opts.sessionId
        elseif not force and NeedsLocalConfirm(activeId, eng) then
            return OpenLocalConfirm(activeId, eng, sessionId)
        end
        local method = SelectCloseMethod(activeId, eng, purpose)
        if not method then return false, "blocked" end
        local runId = RunIdOf(eng)
        local returned
        local ran, err = xpcall(function()
            returned = eng[method](eng)
        end, CaptureError)
        if not ran or returned == false then
            LogGameError(activeId, method, ran and "Abschluss abgelehnt" or err)
            if TargetHeld(eng, activeId, sessionId) then
                return MarkBlocked(eng, sessionId)
            end
            return RememberCleanup(activeId, sessionId, runId, "engine")
        end
        if TargetHeld(eng, activeId, sessionId) then
            LogGameError(activeId, method, "Session blieb aktiv")
            return MarkBlocked(eng, sessionId)
        end
        if eng._sessionId and eng._sessionId ~= sessionId and sessionId then
            return false, "stale"
        end
        local idleOk, idleWhy = GR.IdleRenderer(activeId, sessionId)
        if not idleOk then
            if idleWhy == "stale" then return false, "stale" end
            return RememberCleanup(activeId, sessionId, runId, "renderer")
        end
        return true, "ended"
    end)
    GR._closing = false
    if not ok then
        LogGameError("GameRegistry", purpose or "FinishActive", status)
        return false, "blocked"
    end
    return status, reason
end

--- Fortschritt behalten und die Session danach beenden.
--- Ein Fehler oder ein abgelehntes Speichern ruft StopGame nicht zusätzlich auf.
--- Eine Netzwerkpartie wird hier nicht abgebrochen.
--- @return boolean, string
function GR.LeaveActiveGame()
    return GR._FinishActive("leave")
end

function GR.LeaveKeepsProgress(gameId)
    local eng = GR.GetEngine(gameId)
    if not eng then return false end
    local method = SelectCloseMethod(gameId, eng, "leave")
    return method == "SaveAndPause" or method == "SaveAndStop"
end

function GR.RequiresLocalExit(gameId)
    local eng = GR.GetEngine(gameId)
    return eng ~= nil and NeedsLocalConfirm(gameId, eng) or false
end

function GR.HasTerminalWork()
    if GR._cleanup then return true end
    return TerminalSudoku() ~= nil
end

function GR.SetCloseWatcher(fn)
    GR._closeWatcher = fn
end

local function FireClose(ok, reason, gameId, sessionId)
    local fn = GR._closeWatcher
    GR._closeWatcher = nil
    if fn then fn(ok, reason, gameId, sessionId) end
end

function GR.AcceptClose(gameId, sessionId, identity)
    local pending = GR._confirm
    if pending and (pending.gameId ~= gameId or pending.sessionId ~= sessionId
        or (identity and pending.identity and identity ~= pending.identity)) then
        if ConfirmLive(pending) then
            FireClose(false, "stale", gameId, sessionId)
            return false, "stale"
        end
        GR._confirm = nil
        pending = nil
    end
    if pending then
        if pending.accepted then return false, "blocked" end
        pending.accepted = true
        GR._confirm = nil
    end
    local ok, reason = GR._FinishActive("leave", { confirmed = true, gameId = gameId, sessionId = sessionId })
    FireClose(ok, reason, gameId, sessionId)
    return ok, reason
end

function GR.DeclineClose(gameId, sessionId)
    local pending = GR._confirm
    if pending and pending.gameId == gameId and pending.sessionId == sessionId then
        GR._confirm = nil
        FireClose(false, "declined", gameId, sessionId)
    end
    return false, "blocked"
end

function GR.ReleaseConfirm(gameId, sessionId)
    local pending = GR._confirm
    if not pending or pending.gameId ~= gameId or pending.sessionId ~= sessionId then return end
    if pending.accepted then return end
    local parent = pending.parent
    GR._confirm = nil
    local UI = ArcadiaNexus.UI
    local owner = parent and UI and UI.ChoicePopupOwner and UI.ChoicePopupOwner(parent)
    if owner and owner.gameId == gameId and owner.sessionId == sessionId and UI.HideChoicePopup then
        UI.HideChoicePopup(parent)
    end
    FireClose(false, "released", gameId, sessionId)
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
