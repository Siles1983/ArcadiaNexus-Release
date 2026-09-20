--[[
    ArcadiaNexus – Core/Match/Browser.lua
    Party/Raid-Sessionliste. Kein LFG, nur Gruppe.
]]

local ArcadiaNexus = _G.ArcadiaNexus
local function NewBrowser(transport)
local B = {}
local function Transport()
    if transport then return transport end
    local MT = ArcadiaNexus.MatchTransport
    return MT and MT.StartWow and MT.StartWow()
end

local TTL = 12
local PULSE = 5
local sessions = {}
local advertise
local guard
local onChange

local function Proto()
    return ArcadiaNexus.MatchProtocol
end

local function Now()
    return (GetTime and GetTime()) or 0
end

local function CountTaken(seats, maxSeats)
    local n = 0
    maxSeats = maxSeats or 4
    for i = 1, maxSeats do
        if seats and seats[i] and seats[i] ~= "" then
            n = n + 1
        end
    end
    return n
end

function B.SetOnChange(fn)
    onChange = fn
end

function B.List()
    local now = Now()
    local out = {}
    for id, s in pairs(sessions) do
        if s.state == "GONE" or (now - (s.lastSeen or 0)) > TTL then
            sessions[id] = nil
        else
            out[#out + 1] = s
        end
    end
    table.sort(out, function(a, b)
        return (a.host or "") < (b.host or "")
    end)
    return out
end

function B.Upsert(fields, fromKey)
    if not fields or not fields.matchId then return end
    local id = fields.matchId
    sessions[id] = {
        matchId = id,
        gameId = fields.gameId or "SI7",
        host = fields.host or fromKey,
        taken = tonumber(fields.taken) or 1,
        maxSeats = tonumber(fields.max or fields.maxSeats) or 4,
        policy = fields.policy or "OPEN",
        locked = fields.locked == "1" or fields.policy == "PIN" or fields.policy == "INVITE",
        state = fields.st or fields.state or "LOBBY",
        proto = tonumber(fields.proto),
        gameProto = tonumber(fields.gameProto),
        wordSet = fields.ws,
        lastSeen = Now(),
        localHost = fields._local == true,
    }
    if onChange then onChange() end
end

function B.Remove(matchId)
    if matchId then sessions[matchId] = nil end
    if onChange then onChange() end
end

local function RetractBroadcast(matchId, host)
    if not matchId then return end
    local P = Proto()
    if not P then return end
    local payload = P.Encode(P.TYPE.ANNOUNCE, {
        matchId = matchId,
        st = "GONE",
        host = host,
    })
    local t = Transport()
    if t and t.Broadcast then
        t:Broadcast(host, payload)
    end
end

--- Lobby schließen: ein ANNOUNCE st=GONE, danach lokale Liste. TTL bleibt Fallback.
function B.StopAdvertise()
    local id = advertise and advertise.matchId
    local host = advertise and advertise.host
    advertise = nil
    if guard then guard:Cancel() end
    if id then
        RetractBroadcast(id, host)
        B.Remove(id)
    end
end

function B.Pulse()
    local P = Proto()
    if not advertise or not P then return end
    if advertise.node then
        advertise.taken = CountTaken(advertise.node.seats, advertise.node.maxSeats)
        advertise.policy = advertise.node.policy or advertise.policy
        advertise.state = advertise.node.state or advertise.state
    end
    local policy = advertise.policy or "OPEN"
    local fields = {
        matchId = advertise.matchId,
        gameId = advertise.gameId,
        host = advertise.host,
        taken = advertise.taken,
        max = advertise.maxSeats,
        policy = policy,
        locked = (P.IsLockedPolicy and P.IsLockedPolicy(policy)) and "1" or "0",
        st = advertise.state or "LOBBY",
        proto = advertise.proto or P.MATCH_PROTO,
        gameProto = advertise.gameProto or 1,
    }
    if advertise.node and advertise.node.announceFields then
        local extra = advertise.node.announceFields(advertise.node)
        if extra then for k, v in pairs(extra) do if v ~= nil then fields[k] = v end end end
    end
    local payload = P.Encode(P.TYPE.ANNOUNCE, fields)
    local t = Transport()
    if t and t.Broadcast then
        t:Broadcast(advertise.host, payload)
    end
    advertise._local = true
    B.Upsert(advertise, advertise.host)
end

function B.AdvertiseFromNode(node)
    if not node or not node.isHost or not node.matchId then return end
    if advertise and advertise.matchId and advertise.matchId ~= node.matchId then
        B.StopAdvertise()
    end
    local P = Proto()
    advertise = {
        matchId = node.matchId,
        gameId = node.gameId or "SI7",
        host = node.playerKey,
        taken = CountTaken(node.seats, node.maxSeats),
        maxSeats = node.maxSeats or 4,
        policy = node.policy or "OPEN",
        state = node.state or "LOBBY",
        proto = node.proto or (P and P.MATCH_PROTO),
        gameProto = node.gameProto or 1,
        node = node,
    }
    if not guard then
        guard = ArcadiaNexus.TimerGuard.New()
    end
    guard:Cancel()
    B.Pulse()
    guard:EveryTicker(PULSE, function()
        if advertise then B.Pulse() end
    end)
end

function B.OnPayload(fromKey, payload, channel)
    local P = Proto()
    if not P then return end
    local msg = P.Decode(payload)
    if not msg then return end
    if msg.type == P.TYPE.INVITED then
        if channel ~= P.CHANNEL.UNICAST then return end
        local id = msg.fields and msg.fields.matchId
        if not id then return end
        local ok = false
        for _, s in pairs(sessions) do
            if s.matchId == id and P.SamePlayer and P.SamePlayer(s.host, fromKey) then
                ok = true
                break
            end
        end
        if not ok then return end
        B._invitedMatchId = id
        B._invitedHost = fromKey
        if onChange then onChange() end
        return
    end
    if msg.type ~= P.TYPE.ANNOUNCE then return end
    if channel ~= P.CHANNEL.BROADCAST then return end
    if not msg.fields.matchId or not P.SamePlayer(msg.fields.host, fromKey) then return end
    local existing = sessions[msg.fields.matchId]
    if existing and not P.SamePlayer(existing.host, fromKey) then return end
    msg.fields._local = nil
    msg.fields.host = fromKey
    if msg.fields then msg.fields.pin = nil end
    if msg.fields and msg.fields.st == "GONE" then
        if B._invitedMatchId == msg.fields.matchId then
            B._invitedMatchId = nil
        end
        B.Remove(msg.fields.matchId)
        return
    end
    B.Upsert(msg.fields, fromKey)
end

function B.Start()
    local t = Transport()
    if t and t.Subscribe then
        t:Subscribe(B.OnPayload)
    end
end

B.New = NewBrowser
return B
end

ArcadiaNexus.MatchBrowser = NewBrowser()
