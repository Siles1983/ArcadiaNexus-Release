--[[
    ArcadiaNexus – UI/Core/NavigationGuard.lua
    Bestätigung, bevor eine laufende Partie durch Tab, Spielwechsel
    oder Schließen des Hauptfensters verlassen wird.
    Der fachliche Abschluss bleibt bei GameRegistry.
]]

local Nav = {}
ArcadiaNexus.UI = ArcadiaNexus.UI or {}
ArcadiaNexus.UI.Navigation = Nav

local intent

local function L(key)
    return ArcadiaNexus.GetLocaleTable("UI")[key]
end

local function Registry()
    return ArcadiaNexus.GameRegistry
end

local function Refs()
    local ui = ArcadiaNexus.UI
    return ui and ui.GetF and ui.GetF()
end

local function Main()
    local refs = Refs()
    return refs and refs.main
end

local function ContentAnchor()
    local refs = Refs()
    local content = refs and refs.content
    if content and content.IsShown and content:IsShown() then return content end
    return nil
end

local function Owner()
    local LC = ArcadiaNexus.Lifecycle
    local gameId = LC and LC.GetActiveGame and LC:GetActiveGame()
    if not gameId then return nil, nil end
    local GS = ArcadiaNexus.GameSession
    local cur = GS and GS.GetCurrent and GS:GetCurrent()
    local sessionId = cur and cur.gameId == gameId and cur.sessionId or nil
    return gameId, sessionId
end

local function SameOwner(gameId, sessionId)
    local id, sid = Owner()
    return id == gameId and sid == sessionId
end

local function Network(gameId)
    local GR = Registry()
    local eng = GR and GR.GetEngine and GR.GetEngine(gameId)
    if not eng then return false end
    if type(eng.match) == "table" then return true end
    return eng.mode == "host" or eng.mode == "join" or eng.mode == "rejoin"
end

local function OwnMatchView(target)
    if target ~= "MATCH" then return false end
    local Shell = ArcadiaNexus.MatchShell
    if not Shell or not Shell._tabPass then return false end
    local gameId, sessionId = Owner()
    if not gameId or not sessionId or not Network(gameId) then return false end
    local GR = Registry()
    local eng = GR and GR.GetEngine and GR.GetEngine(gameId)
    local node = eng and eng.match
    if type(node) ~= "table" or node._closed then return false end
    if eng._sessionId ~= sessionId then return false end
    if Shell.selectedGameId ~= gameId then return false end
    return true
end

local function Released(ok, reason)
    if not ok then return false end
    if reason == "view-hidden" or reason == "blocked" or reason == "confirmation-pending" or reason == "stale" then
        return false
    end
    if reason ~= "ended" and reason ~= "already-ended" then return false end
    local GR = Registry()
    if GR and GR.HasPendingCleanup and GR.HasPendingCleanup() then return false end
    if ArcadiaNexus.Lifecycle and ArcadiaNexus.Lifecycle:GetActiveGame() then return false end
    return true
end

local function ClearIntent()
    local GR = Registry()
    if GR and GR.SetCloseWatcher then GR.SetCloseWatcher(nil) end
    intent = nil
end

local function Notice(text)
    local parent = Main()
    local UI = ArcadiaNexus.UI
    if not parent or not UI or not UI.ShowChoicePopup then return end
    UI.ShowChoicePopup({
        parent = parent,
        width = 420,
        height = 160,
        title = L("nav_cancelled"),
        body = text,
        owner = { kind = "navigation-notice" },
        buttons = {
            { label = "OK", onClick = function()
                if UI.HideChoicePopup then UI.HideChoicePopup(parent) end
            end },
        },
    })
end

local function Finish(ok, reason)
    local current = intent
    if not current or current.done then return end
    current.done = true
    local run = current.run
    ClearIntent()
    if Released(ok, reason) then
        if run then run() end
        return
    end
    if reason == "declined" or reason == "stale" or reason == "released" then return end
    Notice(reason == "view-hidden" and L("nav_network_active") or L("nav_failed"))
end

function Nav.Cancel()
    if not intent or intent.done or intent.closing then return false end
    local UI = ArcadiaNexus.UI
    if intent.localConfirm then
        local current = intent
        local GR = Registry()
        local parent = GR and GR._confirm and GR._confirm.parent
        current.hiding = true
        if parent and UI and UI.HideChoicePopup then UI.HideChoicePopup(parent) end
        if GR and GR.DeclineClose then
            GR.DeclineClose(current.gameId, current.sessionId)
        end
        if intent == current then ClearIntent() end
        return true
    end
    local parent = intent.parent
    intent.hiding = true
    ClearIntent()
    if parent and UI and UI.HideChoicePopup then UI.HideChoicePopup(parent) end
    return true
end

function Nav.Abandon()
    if not intent then return end
    if intent.localConfirm and not intent.closing and not intent.done then
        Nav.Cancel()
        return
    end
    intent.hiding = true
    local parent = intent.parent
    ClearIntent()
    local UI = ArcadiaNexus.UI
    if parent and UI and UI.HideChoicePopup then UI.HideChoicePopup(parent) end
end

local function WatchLocal(current)
    local GR = Registry()
    if not GR or not GR.SetCloseWatcher then return end
    GR.SetCloseWatcher(function(ok, reason, gameId, sessionId)
        if not intent or intent ~= current then return end
        if gameId ~= current.gameId or sessionId ~= current.sessionId then
            ClearIntent()
            return
        end
        Finish(ok, reason)
    end)
end

local function ShowDialog(current)
    local parent = Main()
    local UI = ArcadiaNexus.UI
    if not parent or not UI or not UI.ShowChoicePopup then
        ClearIntent()
        Notice(L("nav_failed"))
        return
    end
    current.parent = parent
    local prior = UI._choicePopups and UI._choicePopups[parent]
    local wasShown = prior and prior.IsShown and prior:IsShown()
    local GR = Registry()
    local keep = GR and GR.LeaveKeepsProgress and GR.LeaveKeepsProgress(current.gameId)
    local popup = UI.ShowChoicePopup({
        parent = parent,
        anchorFrame = ContentAnchor(),
        width = 460,
        height = 188,
        layout = "pair",
        title = L("nav_leave_title"),
        body = L("nav_leave_body"),
        onCancel = function() Nav.Cancel() end,
        owner = { kind = "navigation", gameId = current.gameId, sessionId = current.sessionId },
        buttons = {
            { label = L("btn_cancel"), onClick = function() Nav.Cancel() end },
            { label = keep and L("nav_save_leave") or L("nav_leave"), onClick = function()
                if not intent or intent ~= current or current.done or current.closing then return end
                current.closing = true
                if not SameOwner(current.gameId, current.sessionId) then
                    Nav.Abandon()
                    return
                end
                current.hiding = true
                if UI.HideChoicePopup then UI.HideChoicePopup(parent) end
                local reg = Registry()
                if not reg then
                    Finish(false, "blocked")
                    return
                end
                local ok, reason = reg.LeaveActiveGame()
                if reason == "confirmation-pending" then
                    WatchLocal(current)
                    return
                end
                Finish(ok, reason)
            end },
        },
    })
    if not popup then
        ClearIntent()
        if not wasShown then Notice(L("nav_failed")) end
        return
    end
    popup:SetScript("OnHide", function()
        if intent == current and not current.done and not current.hiding then
            ClearIntent()
        end
    end)
end

--- true = die Aktion ist angenommen oder blockiert. false = sofort ausführen.
function Nav.Request(spec)
    if Nav._pass or type(spec) ~= "table" or type(spec.run) ~= "function" then
        return false
    end
    if intent and intent.localConfirm and not intent.closing and not intent.done then
        local GR = Registry()
        local pending = GR and GR._confirm
        local parent = pending and pending.parent
        local UI = ArcadiaNexus.UI
        local popup = parent and UI and UI._choicePopups and UI._choicePopups[parent]
        local shown = popup and popup.IsShown and popup:IsShown()
        local same = pending and pending.gameId == intent.gameId and pending.sessionId == intent.sessionId
        if not same or not shown then
            if same and GR and GR.DeclineClose then
                GR.DeclineClose(intent.gameId, intent.sessionId)
            else
                ClearIntent()
            end
        end
    end
    if intent then return true end
    if OwnMatchView(spec.target) then return false end
    local gameId, sessionId = Owner()
    local GR = Registry()
    local terminal = GR and GR.HasTerminalWork and GR.HasTerminalWork()
    if spec.kind == "tab" and _G.NexusTabState and NexusTabState.activeTab == spec.target then
        if gameId or not terminal then return false end
        local ok, reason = GR.LeaveActiveGame()
        if Released(ok, reason) then return false end
        Notice(L("nav_failed"))
        return true
    end
    if not gameId then
        if not GR or not GR.HasTerminalWork or not GR.HasTerminalWork() then
            return false
        end
        local ok, reason = GR.LeaveActiveGame()
        if Released(ok, reason) then
            spec.run()
        else
            Notice(L("nav_failed"))
        end
        return true
    end
    if Network(gameId) then
        local ok, reason = GR.LeaveActiveGame()
        if Released(ok, reason) then
            spec.run()
        else
            Notice(reason == "view-hidden" and L("nav_network_active") or L("nav_failed"))
        end
        return true
    end
    if GR and GR.RequiresLocalExit and GR.RequiresLocalExit(gameId) then
        intent = {
            kind = spec.kind,
            target = spec.target,
            purpose = "leave",
            localConfirm = true,
            gameId = gameId,
            sessionId = sessionId,
            run = spec.run,
        }
        WatchLocal(intent)
        local ok, reason = GR.LeaveActiveGame()
        if reason == "confirmation-pending" then
            return true
        end
        local current = intent
        if current then Finish(ok, reason) end
        return true
    end
    intent = {
        kind = spec.kind,
        target = spec.target,
        purpose = spec.purpose or "leave",
        gameId = gameId,
        sessionId = sessionId,
        run = spec.run,
    }
    ShowDialog(intent)
    return true
end

function Nav.RequestHide()
    return Nav.Request({
        kind = "hide",
        purpose = "leave",
        run = function()
            local main = Main()
            if not main then return end
            Nav._pass = true
            main:Hide()
            Nav._pass = false
        end,
    })
end
