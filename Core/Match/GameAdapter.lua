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
    if not MT or not MT.LocalPlayerKey then return {} end
    local me = MT.LocalPlayerKey()
    local keys, seen = {}, {}
    local function add(unit)
        if not unit or not UnitExists or not UnitExists(unit) then return end
        if UnitIsUnit and UnitIsUnit(unit, "player") then return end
        local name, realm = UnitFullName(unit)
        if not name then return end
        realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
        realm = tostring(realm):gsub("%s+", "")
        local key = (realm ~= "") and (name .. "-" .. realm) or name
        if key ~= me and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do add("raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 4
        for i = 1, n do add("party" .. i) end
    end
    return keys
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

function Match.StopEngineMatch(engine)
    local node = engine.match
    if not node then return end
    Match.CloseGameClient(node)
    engine.match = nil
end

--- Host/Join/Rejoin. true = MP-Pfad erledigt (Caller return); false = lokales Spiel.
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
    engine.mode = mode
    engine._resultEmitted = false
    engine._notice = nil
    if hooks.onBefore then hooks.onBefore(engine, config) end
    if engine.StopMatchQuiet then
        engine:StopMatchQuiet()
    else
        Match.StopEngineMatch(engine)
    end
    local node = Match.EnsureGameClient(engine, matchOptsFn)
    if not node then
        Match.EndGameClient(engine, gameId)
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
        engine._sessionId = ArcadiaNexus.Lifecycle:RestartGame(gameId, engine._sessionId)
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
    engine._sessionId = ArcadiaNexus.Lifecycle:RestartGame(gameId, engine._sessionId)
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
