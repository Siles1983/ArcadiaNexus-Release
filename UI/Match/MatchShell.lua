--[[
    UI/Match/MatchShell.lua
    Option B: Sitzung, Lobby und Canvas leben im Mehrspieler-Tab.
]]

if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then
    return
end

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchShell = {}
local S = ArcadiaNexus.MatchShell

S._boardFor = nil
S._tabPass = false
S._reparenting = false
S.selectedGameId = nil

local function Loc(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or key
end

local function GamesPanel()
    return _G.ArcadiaNexusUI and ArcadiaNexusUI.GetGamesPanel and ArcadiaNexusUI.GetGamesPanel()
end

function S.HostableGames()
    local GR = ArcadiaNexus.GameRegistry
    local out = {}
    if GR and GR.GetAll then
        for _, info in ipairs(GR.GetAll()) do
            if info.matchSeats and info.matchSeats > 0 then
                if not GR.IsVisible or GR.IsVisible(info, GR.FILTER_SIDEBAR) then
                    out[#out + 1] = {
                        id = info.id,
                        maxSeats = info.matchSeats,
                        label = info.label or info.id,
                    }
                end
            end
        end
    end
    return out
end

function S.Engine(gameId)
    local GR = ArcadiaNexus.GameRegistry
    return GR and GR.GetEngine and GR.GetEngine(gameId)
end

function S.LocalMpGame()
    local list = S.HostableGames()
    for i = 1, #list do
        local eng = S.Engine(list[i].id)
        if eng and eng.mode and eng.mode ~= "hotseat"
            and eng.state and eng.state ~= "IDLE" then
            return list[i].id, eng
        end
    end
    return nil, nil
end

function S.IsLive()
    local _, eng = S.LocalMpGame()
    return eng ~= nil
end

function S.OpenCount(gameId)
    local n = 0
    local listS = ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser.List()
    if not listS then return 0 end
    for i = 1, #listS do
        if listS[i].gameId == gameId then
            n = n + 1
        end
    end
    return n
end

function S.AbortSession()
    S._pendingJoin = nil
    local _, eng = S.LocalMpGame()
    if eng and eng.StopGame then
        eng:StopGame()
    end
    S._boardFor = nil
    S.ReleaseBoard()
end

local function ConfirmParent(preferred)
    if preferred then return preferred end
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs and ArcadiaNexus.UI.GetGamesPanelFrameRefs()
    if F and F.content then return F.content end
    local MB = ArcadiaNexus.MatchBrowserUI
    if MB and MB._panel then return MB._panel end
    return UIParent
end

--- Sicherheitsabfrage im GameResult-Design (Titel, Text, Ja/Nein).
function S.ShowConfirm(onYes, spec)
    spec = spec or {}
    local UI = ArcadiaNexus.UI
    if not UI or not UI.ShowResultDialog then
        if onYes then onYes() end
        return
    end
    local parent = ConfirmParent(spec.parent)
    local function hideThen(fn)
        return function()
            UI.HideResultDialog(parent)
            if fn then fn() end
        end
    end
    UI.ShowResultDialog({
        parent        = parent,
        title         = Loc(spec.titleKey or "match_confirm_leave_title"),
        subtitle      = Loc(spec.bodyKey or "match_confirm_leave_body"),
        hideHighscore = true,
        fadeIn        = true,
        buttons       = {
            {
                label   = Loc(spec.yesKey or "match_confirm_leave_yes"),
                onClick = hideThen(onYes),
                width   = spec.yesWidth or 150,
                variant = spec.yesVariant or "danger",
            },
            {
                label   = Loc(spec.noKey or "match_confirm_leave_no"),
                onClick = hideThen(),
                width   = spec.noWidth or 120,
            },
        },
    })
end

function S.ShowLeaveConfirm(onYes, parent)
    S.ShowConfirm(onYes, {
        parent   = parent,
        titleKey = "match_confirm_leave_title",
        bodyKey  = "match_confirm_leave_body",
        yesKey   = "match_confirm_leave_yes",
        noKey    = "match_confirm_leave_no",
    })
end

function S.ShowEndRoundConfirm(onYes, parent)
    S.ShowConfirm(onYes, {
        parent   = parent,
        titleKey = "match_confirm_end_title",
        bodyKey  = "match_confirm_end_body",
        yesKey   = "match_confirm_end_yes",
        noKey    = "match_confirm_end_no",
        yesWidth = 150,
    })
end

function S.ShouldDeferTab(id)
    if S._tabPass then return false end
    if not NexusTabState or NexusTabState.activeTab ~= "MATCH" then return false end
    if id == "MATCH" then return false end
    if not S.IsLive() then return false end
    S.ShowLeaveConfirm(function()
        S.AbortSession()
        S._tabPass = true
        NexusTabs.SetActive(id)
        S._tabPass = false
    end)
    return true
end

local function HomeParent()
    return GamesPanel()
end

function S.ReleaseBoard()
    local gameId = S._boardGameId
    if not gameId then return end
    local GR = ArcadiaNexus.GameRegistry
    local container = GR and GR.GetContainer and GR.GetContainer(gameId)
    local home = HomeParent()
    if container and home then
        local was = S._reparenting
        S._reparenting = true
        container:SetParent(home)
        container:ClearAllPoints()
        container:SetAllPoints(home)
        container:Hide()
        S._reparenting = was
    end
    S._boardGameId = nil
end

--- Reparent game outer onto MATCH _stage (same inset rect as F.games).
function S.PresentBoard(gameId)
    local MB = ArcadiaNexus.MatchBrowserUI
    local stage = MB and MB.GetStage and MB.GetStage()
    local GR = ArcadiaNexus.GameRegistry
    if not stage or not GR then return end
    if MB.ShowStage then MB.ShowStage(gameId) end
    local container = GR.GetContainer(gameId)
    if not container then return end
    S._reparenting = true
    if S._boardGameId and S._boardGameId ~= gameId then
        S.ReleaseBoard()
    end
    container:SetParent(stage)
    container:ClearAllPoints()
    container:SetAllPoints(stage)
    container:Show()
    S._reparenting = false
    S._boardGameId = gameId
    local rnd = GR.GetRenderer(gameId)
    if rnd and rnd.Render then
        pcall(rnd.Render, rnd)
    end
end

function S.Host(gameId, opts)
    S._pendingJoin = nil
    S.selectedGameId = gameId
    local eng = S.Engine(gameId)
    if not eng or not eng.StartGame then return end
    opts = opts or {}
    local MB = ArcadiaNexus.MatchBrowserUI
    if (not opts.policy) and MB and MB.GetHostOpts then
        local extra = MB.GetHostOpts()
        opts.policy = extra.policy
        opts.pin = extra.pin
    end
    eng:StartGame({ mode = "host", policy = opts.policy, pin = opts.pin })
end

function S.Join(gameId, hostKey, opts)
    S.selectedGameId = gameId
    local eng = S.Engine(gameId)
    if not eng or not eng.StartGame then return end
    opts = opts or {}
    if opts.pin and opts.pin ~= "" then
        S._lastPin = opts.pin
    end
    eng:StartGame({ mode = "join", joinTarget = hostKey or "", pin = opts.pin })
end

local function SamePlayer(a, b)
    local P = ArcadiaNexus.MatchProtocol
    if P and P.SamePlayer then
        local host = S._last and S._last.hostKey
        local hostRealm = ""
        if P.SplitPlayerKey and host then
            local _, r = P.SplitPlayerKey(host)
            hostRealm = r or ""
        end
        return P.SamePlayer(a, b, { hostRealm = hostRealm })
    end
    return a == b
end

local function LivePin(node)
    local P = ArcadiaNexus.MatchProtocol
    local function ok(p)
        if not p or p == "" then return nil end
        if P and P.NormalizePin then
            p = P.NormalizePin(p)
            if p == "" then return nil end
        end
        return p
    end
    return ok(node and node.pin) or ok(S._lastPin) or ok(S._last and S._last.pin)
end

function S.RememberLive(gameId)
    local eng = S.Engine(gameId)
    local node = eng and eng.match
    if not node or not node.matchId then return end
    local peers = {}
    for i = 1, node.maxSeats or 4 do
        local k = node.seats and node.seats[i]
        if k and k ~= "" and k ~= node.playerKey then
            peers[k] = true
        end
    end
    S._last = {
        gameId = gameId,
        hostKey = node.hostKey or node.playerKey,
        wasHost = node.isHost == true,
        pin = LivePin(node),
        policy = node.policy,
        peers = peers,
    }
end

--- Neues Spiel nach Ergebnis: Host legt die Lobby an, Gäste joinen denselben Host.
function S.Rematch(gameId)
    S.RememberLive(gameId)
    local last = S._last or {}
    local MB = ArcadiaNexus.MatchBrowserUI
    local pin = last.pin
    if (not pin or pin == "") and MB and MB.GetHostOpts then
        pin = (MB.GetHostOpts() or {}).pin
    end
    if last.wasHost or not last.hostKey then
        S._pendingJoin = nil
        S.Host(gameId, { policy = last.policy, pin = pin })
        if last.policy == "INVITE" and last.peers then
            for k in pairs(last.peers) do
                S.Invite(k)
            end
        end
        return
    end
    S._pendingJoin = { gameId = gameId, hostKey = last.hostKey, pin = pin }
    S._pendingJoinAt = 0
    S.Join(gameId, last.hostKey, { pin = pin })
end

function S.OnJoinRejected(gameId, reason)
    if not S._pendingJoin or S._pendingJoin.gameId ~= gameId then return end
    -- PIN falsch: nicht pollen. INVITE darf retried werden, bis der Host einlädt.
    if reason == "pin" then
        S._pendingJoin = nil
    end
end

function S.TryPendingJoin()
    local p = S._pendingJoin
    if not p then return end
    local eng = S.Engine(p.gameId)
    local node = eng and eng.match
    if node and node.seat and (eng.state == "LOBBY" or (node.GetState and node:GetState() == "LOBBY")) then
        S._pendingJoin = nil
        return
    end
    -- JOIN unterwegs: nicht jeden ANNOUNCE-Pulse erneut senden.
    if node and node.hostKey and (not node.GetState or node:GetState() == "IDLE") and not node.rejectReason then
        return
    end
    local now = (GetTime and GetTime()) or 0
    if (now - (S._pendingJoinAt or 0)) < 2 then return end
    local list = ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser.List()
    if not list then return end
    for i = 1, #list do
        local s = list[i]
        if s.gameId == p.gameId and SamePlayer(s.host, p.hostKey) and not s.localHost then
            S._pendingJoinAt = now
            S.Join(p.gameId, s.host, { pin = p.pin })
            return
        end
    end
end

function S.Invite(playerKey)
    local eng = S.Engine(S.selectedGameId)
    local node = eng and eng.match
    if not node or not node.Invite then return end
    local MT = ArcadiaNexus.MatchTransport
    if MT and MT.NormalizeSender then
        playerKey = MT.NormalizeSender(playerKey) or playerKey
    end
    node:Invite(playerKey)
    local MB = ArcadiaNexus.MatchBrowserUI
    if MB and MB.RefreshLobby then MB.RefreshLobby() end
end

function S.OnGameView(gameId, view)
    if not view or not gameId then return end
    local MB = ArcadiaNexus.MatchBrowserUI
    S.selectedGameId = gameId
    if view.state == "LOBBY" or view.state == "PLAYING" or view.state == "FINISHED" then
        S.RememberLive(gameId)
    end
    if view.state == "LOBBY" then
        if S._pendingJoin and S._pendingJoin.gameId == gameId then
            local eng = S.Engine(gameId)
            if eng and eng.match and eng.match.seat then
                S._pendingJoin = nil
            end
        end
        S._boardFor = nil
        S.ReleaseBoard()
        if NexusTabs and NexusTabs.GetActive and NexusTabs.GetActive() ~= "MATCH" then
            S._tabPass = true
            NexusTabs.SetActive("MATCH")
            S._tabPass = false
        end
        if MB and MB.ShowLobby then MB.ShowLobby(gameId) end
        return
    end
    if view.state == "PLAYING" then
        if NexusTabs and NexusTabs.GetActive and NexusTabs.GetActive() ~= "MATCH" then
            S._tabPass = true
            NexusTabs.SetActive("MATCH")
            S._tabPass = false
        end
        local eng = S.Engine(gameId)
        local mid = (eng and eng.match and eng.match.matchId) or (gameId .. "-play")
        if S._boardFor ~= mid then
            S._boardFor = mid
            S.PresentBoard(gameId)
        elseif MB and MB.ShowStage then
            MB.ShowStage(gameId)
        end
        return
    end
    if view.state == "FINISHED" then
        if NexusTabs and NexusTabs.GetActive and NexusTabs.GetActive() ~= "MATCH" then
            S._tabPass = true
            NexusTabs.SetActive("MATCH")
            S._tabPass = false
        end
        if S._boardGameId ~= gameId then
            S.PresentBoard(gameId)
        end
        return
    end
    S._boardFor = nil
    S.ReleaseBoard()
    if MB and MB.ShowSessions then MB.ShowSessions(gameId) end
    if view.notice and MB and MB.SetJoinNotice then
        MB.SetJoinNotice(view.notice)
    end
end
