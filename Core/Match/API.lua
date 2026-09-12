--[[
    ArcadiaNexus – Core/Match/API.lua
    Öffentliche Fassade. Games fragen nur HasMultiplayer() / Match.
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.Match = {
    _ready = true,
    Protocol = ArcadiaNexus.MatchProtocol,
    Transport = ArcadiaNexus.MatchTransport,
    Runtime = ArcadiaNexus.MatchRuntime,
    Dummy = ArcadiaNexus.MatchDummy,
    SelfTest = ArcadiaNexus.MatchSelfTest,
    Live = ArcadiaNexus.MatchLive,
    Browser = ArcadiaNexus.MatchBrowser,
}

function ArcadiaNexus.Match.Init()
    local P = ArcadiaNexus.MatchProtocol
    if ArcadiaNexus.MatchTransport and ArcadiaNexus.MatchTransport.StartWow then
        ArcadiaNexus.MatchTransport.StartWow()
    end
    if ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser.Start then
        ArcadiaNexus.MatchBrowser.Start()
    end
    if GH_LogInfo then
        GH_LogInfo("Match", "Runtime bereit (proto " ..
            tostring(P and P.MATCH_PROTO) .. ", prefix " ..
            tostring(P and P.PREFIX) .. ")")
    end
    if hooksecurefunc then
        hooksecurefunc("ReloadUI", function()
            ArcadiaNexus.Match.OnUnload()
        end)
        if C_UI and C_UI.Reload then
            hooksecurefunc(C_UI, "Reload", function()
                ArcadiaNexus.Match.OnUnload()
            end)
        end
    end
end

function ArcadiaNexus.Match.OnEnteringWorld(isLogin, isReload)
    if ArcadiaNexus.MatchTransport and ArcadiaNexus.MatchTransport.StartWow then
        ArcadiaNexus.MatchTransport.StartWow()
    end
    if not ArcadiaNexus.Match.GetTicket() then return end
    if not isLogin and not isReload then
        -- manche Reloads liefern beide Flags false; Ticket reicht.
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if ArcadiaNexus.Match.TryResume then ArcadiaNexus.Match.TryResume() end
        end)
    elseif ArcadiaNexus.Match.TryResume then
        ArcadiaNexus.Match.TryResume()
    end
end

function ArcadiaNexus.Match.IsAvailable()
    return ArcadiaNexus.Match._ready == true
end

local liveNodes = {}
ArcadiaNexus.Match._unloading = false

function ArcadiaNexus.Match.TrackNode(node)
    if not node then return end
    liveNodes[#liveNodes + 1] = node
end

function ArcadiaNexus.Match.IsUnloading()
    return ArcadiaNexus.Match._unloading == true
end

local function TicketStore()
    if not _G.ArcadiaNexusDB then return nil end
    return _G.ArcadiaNexusDB
end

function ArcadiaNexus.Match.SaveTicket(node)
    if not node or node.isHost then return end
    if not node.matchId or not node.hostKey or not node.gameId then return end
    local st = node.GetState and node:GetState()
    if st ~= "LOBBY" and st ~= "PLAYING" and st ~= "FINISHED" then return end
    local db = TicketStore()
    if not db then return end
    db.matchTicket = {
        matchId = node.matchId,
        hostKey = node.hostKey,
        gameId = node.gameId,
        playerKey = node.playerKey,
    }
end

function ArcadiaNexus.Match.ClearTicket()
    local db = TicketStore()
    if db then db.matchTicket = nil end
end

function ArcadiaNexus.Match.ClearTicketFor(node)
    local db = TicketStore()
    local t = db and db.matchTicket
    if not t or not node then return end
    if t.matchId == node.matchId and t.playerKey == node.playerKey then
        db.matchTicket = nil
    end
end

function ArcadiaNexus.Match.GetTicket()
    local db = TicketStore()
    local t = db and db.matchTicket
    if type(t) ~= "table" or not t.matchId or not t.hostKey or not t.gameId then
        return nil
    end
    return t
end

function ArcadiaNexus.Match.OnUnload()
    local M = ArcadiaNexus.Match
    M._unloading = true
    for i = 1, #liveNodes do
        local node = liveNodes[i]
        if node and node.GetState then
            local st = node:GetState()
            if st ~= "IDLE" and st ~= "ABORTED" then
                if node.isHost then
                    node:Abort("host-reload")
                else
                    M.SaveTicket(node)
                end
            end
        end
    end
end

function ArcadiaNexus.Match.TryResume()
    if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then return end
    local t = ArcadiaNexus.Match.GetTicket()
    if not t then return end
    local MT = ArcadiaNexus.Match.Transport
    local me = MT and MT.LocalPlayerKey and MT.LocalPlayerKey()
    if not me or t.playerKey ~= me then
        ArcadiaNexus.Match.ClearTicket()
        return
    end
    local GR = ArcadiaNexus.GameRegistry
    local eng = GR and GR.GetEngine and GR.GetEngine(t.gameId)
    if not eng or not eng.StartGame then
        ArcadiaNexus.Match.ClearTicket()
        return
    end
    if eng.mode and eng.mode ~= "hotseat" and eng.state and eng.state ~= "IDLE" then
        return
    end
    eng:StartGame({
        mode = "rejoin",
        joinTarget = t.hostKey,
        matchId = t.matchId,
    })
end

-- Public game helpers: transport/browser details stay in Core/Match.
function ArcadiaNexus.Match.CreateGameClient(opts)
    if not ArcadiaNexus.HasMultiplayer() then return nil end
    local M, config = ArcadiaNexus.Match, {}
    for k, v in pairs(opts) do config[k] = v end
    config.playerKey = M.Transport.LocalPlayerKey()
    if not config.playerKey then return nil end
    config.transport = M.Transport.StartWow()
    return M.Runtime.Create(config)
end

function ArcadiaNexus.Match.UpdateGamePresence(node)
    local B = ArcadiaNexus.Match.Browser
    if not B or not node then return end
    if node.isHost and node:GetState() == "LOBBY" then
        B.AdvertiseFromNode(node)
    elseif node.matchId then
        if node.isHost then B.StopAdvertise() end
        B.Remove(node.matchId)
    end
end

function ArcadiaNexus.Match.CloseGameClient(node)
    if not node then return end
    local M = ArcadiaNexus.Match
    if M.IsUnloading() and not node.isHost then
        M.SaveTicket(node)
        if node._startGuard then node._startGuard:Cancel() end
        if node._rejoinGuard then node._rejoinGuard:Cancel() end
        if node.transport and node.transport.Unregister then
            node.transport:Unregister(node.playerKey)
        end
        return
    end
    if node.isHost then node:Abort("ui-stop") else node:Leave() end
    ArcadiaNexus.Match.UpdateGamePresence(node)
    if node._startGuard then node._startGuard:Cancel() end
    if node._rejoinGuard then node._rejoinGuard:Cancel() end
    if node.transport and node.transport.Unregister then node.transport:Unregister(node.playerKey) end
end

function ArcadiaNexus.Match.PresentGameView(gameId, view)
    local shell = ArcadiaNexus.MatchShell
    if shell then shell.OnGameView(gameId, view) end
end

function ArcadiaNexus.Match.IsPresentingBoard()
    return ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting == true
end
