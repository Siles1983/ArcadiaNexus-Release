--[[
    ArcadiaNexus – Core/Match/GameAdapter.lua
    Gemeinsamer Host/Join/Rejoin/State/Abort-Pfad für Match-Consumer.
    Regeln, Intents und Renderer bleiben im jeweiligen Spiel.
]]

local ArcadiaNexus = _G.ArcadiaNexus
local Match = ArcadiaNexus and ArcadiaNexus.Match
if not Match then return end

function Match.HasMp()
    return ArcadiaNexus.HasMultiplayer and ArcadiaNexus.HasMultiplayer() == true
end

function Match.GroupKeys()
    local MT = Match.Transport
    return (MT and MT.GroupMemberKeys and MT.GroupMemberKeys()) or {}
end

function Match.EnsureGameClient(engine, matchOptsFn)
    if not Match.HasMp() then return nil end
    if engine.match then
        local st = engine.match:GetState()
        if st ~= "ABORTED" and st ~= "FINISHED" and st ~= "IDLE" then
            return engine.match
        end
    end
    local opts = matchOptsFn(engine)
    local node = Match.CreateGameClient(opts)
    engine.match = node
    return node
end

function Match.NotifyGameView(engine, gameId, render)
    if render then render() end
    if engine.mode ~= "hotseat" then
        Match.PresentGameView(gameId, engine:GetView())
    end
end

function Match.HandleGamePublic(engine, extra)
    if extra then extra(engine) end
    if engine.state == "LOBBY" then
        Match.UpdateGamePresence(engine.match)
    end
end

function Match.HandleGameState(engine, gameId, st, extra)
    extra = extra or {}
    if st == "PLAYING" then
        engine.state = "PLAYING"
        engine._notice = nil
        Match.UpdateGamePresence(engine.match)
        if extra.onPlaying then extra.onPlaying(engine) end
    elseif st == "FINISHED" then
        engine.state = "FINISHED"
        Match.UpdateGamePresence(engine.match)
        if extra.onFinished then extra.onFinished(engine) end
    elseif st == "ABORTED" then
        Match.EndGameClient(engine, gameId)
        engine.state = "IDLE"
        if extra.onAborted then extra.onAborted(engine) end
    elseif st == "LOBBY" then
        engine.state = "LOBBY"
        Match.UpdateGamePresence(engine.match)
        if extra.onLobby then extra.onLobby(engine) end
    end
end

function Match.HandleGameReject(engine, gameId, fields)
    engine._notice = (fields and fields.reason) or "reject"
    local Shell = ArcadiaNexus.MatchShell
    if Shell and Shell.OnJoinRejected then
        Shell.OnJoinRejected(gameId, fields and fields.reason, fields)
    end
end

function Match.SetEngineReady(engine, ready)
    if engine.match then
        engine.match:SetReady(ready ~= false)
    end
end

function Match.TryEngineStart(engine)
    if not engine.match then return end
    if not engine.match:TryStart() then
        if not engine._notice then
            engine._notice = "start-fail"
        end
    else
        engine._notice = nil
    end
end

function Match.HideEngineView(engine)
    if engine.match and engine.match.HideView then
        engine.match:HideView()
    end
end

function Match.ClientSettled(node)
    if not node or node._closed then return false end
    if not node.GetState or node:GetState() ~= "FINISHED" then return false end
    if node._resultBusy then return false end
    return type(node.processedResultId) == "string" and node.processedResultId ~= ""
end

function Match.ReleaseSettledClient(engine, node)
    if not engine or engine.match ~= node or not Match.ClientSettled(node) then return false end
    local resultId = node.processedResultId
    if engine.match ~= node or node.processedResultId ~= resultId or node._resultBusy then return false end
    node:Dispose({ keepTerminal = true })
    if engine.match == node then engine.match = nil end
    return true
end

function Match.StopEngineMatch(engine)
    local node = engine.match
    if not node then return end
    Match.CloseGameClient(node)
    engine.match = nil
end

--- Host/Join/Rejoin. true = MP-Pfad erledigt (Caller return); false = lokales Spiel.
local function ProtectedMatch(engine)
    local node = engine.match
    if not node or node._closed then
        if node then engine.match = nil end
        return nil
    end
    if Match.ClientSettled(node) then return nil end
    return node
end

local function AttachFreshClient(engine, matchOptsFn)
    if ProtectedMatch(engine) then return nil, "held" end
    if not Match.HasMp() then return nil end
    local opts = matchOptsFn(engine)
    local node = Match.CreateGameClient(opts)
    if not node then return nil end
    if ProtectedMatch(engine) then
        node:Dispose()
        return nil, "held"
    end
    engine.match = node
    return node
end

function Match.BeginNetworkedGame(engine, gameId, config, notify, matchOptsFn, hooks)
    config = config or {}
    hooks = hooks or {}
    local mode = config.mode or "hotseat"
    if mode ~= "host" and mode ~= "join" and mode ~= "rejoin" then
        return false
    end
    if not Match.HasMp() then
        engine._notice = "nomp"
        notify()
        return true
    end
    -- Ein lebender Client bleibt Eigentümer von Transport und Ticket.
    -- Ohne bestätigten MatchShell-Abschluss wird hier nicht gewechselt.
    if ProtectedMatch(engine) then
        return true
    end
    local previousMode = engine.mode
    local sid = ArcadiaNexus.Lifecycle:ClaimRestart(gameId, engine._sessionId)
    if not sid then
        engine._notice = "session"
        notify()
        return true
    end
    local retiring = engine.match
    if retiring and not Match.ReleaseSettledClient(engine, retiring) and engine.match and not engine.match._closed then
        ArcadiaNexus.Lifecycle:EndGame(gameId, sid)
        return true
    end
    engine._sessionId = sid
    engine.mode = mode
    engine._resultEmitted = false
    engine._notice = nil
    if hooks.onBefore then hooks.onBefore(engine, config) end
    local node, held = AttachFreshClient(engine, matchOptsFn)
    if held == "held" then
        ArcadiaNexus.Lifecycle:EndGame(gameId, sid)
        if engine._sessionId == sid then engine._sessionId = nil end
        engine.mode = previousMode
        return true
    end
    if not node then
        Match.EndGameClient(engine, gameId)
        engine.mode = previousMode or "hotseat"
        engine._notice = "nomp"
        notify()
        return true
    end
    if mode == "join" or mode == "rejoin" then
        local target = config.joinTarget
        local targets = {}
        if target and target ~= "" then
            local MT = Match.Transport
            targets[1] = MT.NormalizeSender and MT.NormalizeSender(target) or target
        else
            targets = Match.GroupKeys()
        end
        if #targets == 0 then
            Match.EndGameClient(engine, gameId)
            engine._notice = "joinhint"
            notify()
            return true
        end
    if mode == "rejoin" then
            if not config.matchId or not node.Rejoin then
                Match.EndGameClient(engine, gameId)
                engine._notice = "joinhint"
                notify()
                return true
            end
            node:Rejoin(targets[1], config.matchId)
            if node:GetState() == "IDLE" then
                engine.state = "LOBBY"
                engine._notice = "rejoin"
            end
            notify()
            return true
        end
        for i = 1, #targets do
            node:Join(targets[i], config.pin)
        end
        local state = node:GetState()
        engine.state = state == "ABORTED" and "IDLE" or (state == "IDLE" and "LOBBY" or state)
        notify()
        return true
    end
    if config.policy and node.SetPolicy then
        if not node:SetPolicy(config.policy, config.pin) then
            Match.EndGameClient(engine, gameId)
            engine._notice = "host-fail"
            notify()
            return true
        end
    end
    if not node:HostMatch() then
        Match.EndGameClient(engine, gameId)
        engine._notice = "host-fail"
        notify()
        return true
    end
    engine.state = "LOBBY"
    if hooks.onHosted then hooks.onHosted(engine, node) end
    notify()
    return true
end
