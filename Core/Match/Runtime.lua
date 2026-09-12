--[[
    ArcadiaNexus – Core/Match/Runtime.lua
    Host-autoritative Match-Nodes. Intents, Snapshots, Unicast-Private.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchRuntime = {}
local R = ArcadiaNexus.MatchRuntime

local function Proto()
    return ArcadiaNexus.MatchProtocol
end

local function Dummy()
    return ArcadiaNexus.MatchDummy
end

local function Log(msg)
    if GH_LogDebug then GH_LogDebug("Match", msg) end
end

local function Warn(msg)
    if GH_LogWarn then GH_LogWarn("Match", msg) end
end

local nextMatch = 0
local function NewMatchId()
    nextMatch = nextMatch + 1
    return string.format("M%06d", nextMatch)
end

local ALLOWED = {
    IDLE     = { LOBBY = true, PLAYING = true, ABORTED = true },
    LOBBY    = { PLAYING = true, ABORTED = true, IDLE = true },
    PLAYING  = { FINISHED = true, ABORTED = true },
    FINISHED = { IDLE = true, ABORTED = true },
    ABORTED  = { IDLE = true },
}

local function Transition(node, newState)
    local P = Proto()
    local cur = node.state
    if cur == newState then return true end
    local ok = ALLOWED[cur] and ALLOWED[cur][newState]
    if not ok then
        Warn("illegal " .. tostring(cur) .. " -> " .. tostring(newState))
        return false
    end
    node.state = newState
    if node.onState then
        node.onState(node, newState, cur)
    end
    Log((node.playerKey or "?") .. " " .. cur .. " -> " .. newState)
    local M = ArcadiaNexus.Match
    if M then
        if newState == P.STATE.ABORTED or newState == P.STATE.IDLE then
            if M.ClearTicketFor and not (M.IsUnloading and M.IsUnloading()) then
                M.ClearTicketFor(node)
            end
        elseif not node.isHost and (newState == P.STATE.LOBBY
            or newState == P.STATE.PLAYING or newState == P.STATE.FINISHED) then
            if M.SaveTicket then M.SaveTicket(node) end
        end
    end
    return true
end

local function Encode(msgType, fields)
    return Proto().Encode(msgType, fields)
end

--- @param opts table
function R.Create(opts)
    opts = opts or {}
    local P = Proto()
    local D = Dummy()
    local node = {
        playerKey     = opts.playerKey,
        transport     = opts.transport,
        proto         = opts.proto or P.MATCH_PROTO,
        addon         = opts.addon or P.AddonVersion(),
        gameId        = opts.gameId or D.GAME_ID,
        gameProto     = opts.gameProto or D.GAME_PROTO,
        maxSeats      = opts.maxSeats or 4,
        policy        = opts.policy or P.POLICY.OPEN,
        pin           = P.NormalizePin(opts.pin),
        invited       = {},
        applyIntent   = opts.applyIntent or D.ApplyIntent,
        privateForSeat = opts.privateForSeat or D.PrivateForSeat,
        isFinished    = opts.isFinished or D.IsFinished,
        newPublic     = opts.newPublic or D.NewPublic,
        packPublic    = opts.packPublic,
        unpackPublic  = opts.unpackPublic,
        packStart     = opts.packStart,
        unpackStart   = opts.unpackStart,
        seedOnStart   = opts.seedOnStart,
        assignSeats   = opts.assignSeats,
        canTryStart   = opts.canTryStart,
        onState       = opts.onState,
        onPublic      = opts.onPublic,
        onReject      = opts.onReject,
        onResult      = opts.onResult,
        isHost        = false,
        state         = P.STATE.IDLE,
        matchId       = nil,
        seat          = nil,
        hostKey       = nil,
        seats         = {},
        ready         = {},
        publicState   = nil,
        clientSeq     = 0,
        stateRevision = 0,
        processedIntent = {},
        lastClientSeq = {},
        seenResults   = {},
        lastAck       = nil,
        rejectReason  = nil,
        viewHidden    = false,
        processedResultId = nil,
        gotStart      = false,
        _startPayload = nil,
        _startAcks    = nil,
        _pendingPlay  = nil,
        _p            = nil,
    }

    local function Wire(dir, channel, payload, extra)
        local p = payload or ""
        local t = p:match("^AN1|([^|]+)") or "?"
        if t == "ANNOUNCE" then return end
        local bits = dir .. " " .. t
            .. " ch=" .. tostring(channel or "-")
            .. " n=" .. tostring(#p)
        if extra and extra ~= "" then
            bits = bits .. " " .. extra
        end
        if GH_LogInfo then
            GH_LogInfo("MatchWire", bits)
        else
            Log(bits)
        end
    end

    local function SendBroadcast(payload)
        if not payload then
            Warn("broadcast dropped (encode/size)")
            return
        end
        Wire("tx", "BROADCAST", payload)
        if node.transport then
            node.transport:Broadcast(node.playerKey, payload)
        end
    end

    local function SendUnicast(toKey, payload)
        if not payload then
            Warn("unicast dropped (encode/size) to=" .. tostring(toKey))
            return
        end
        Wire("tx", "UNICAST", payload, "to=" .. tostring(toKey))
        if toKey and node.transport then
            node.transport:Unicast(node.playerKey, toKey, payload)
        end
    end

    -- Öffentlicher State: Gruppenkanal wenn vorhanden, sonst Whisper an die Sitze.
    -- Nicht beides — sonst verdoppelt sich die Last unter dem Prefix-Throttle.
    local function SendToMembers(payload)
        if not payload then return end
        local MT = ArcadiaNexus.MatchTransport
        if MT and MT.BroadcastChatType and MT.BroadcastChatType() then
            SendBroadcast(payload)
            return
        end
        if not node.isHost then
            SendBroadcast(payload)
            return
        end
        local seen = {}
        for i = 1, node.maxSeats do
            local k = node.seats[i]
            if k and k ~= "" and k ~= node.playerKey and not seen[k] then
                seen[k] = true
                SendUnicast(k, payload)
            end
        end
        if not next(seen) then
            SendBroadcast(payload)
        end
    end

    local function CancelRejoinWait()
        if node._rejoinGuard then
            node._rejoinGuard:Cancel()
            node._rejoinGuard = nil
        end
    end

    local function BindLocalSeat()
        local host = node.hostKey or node.playerKey
        local _, hostRealm = P.SplitPlayerKey(host)
        for i = 1, node.maxSeats do
            if P.SamePlayer(node.seats[i], node.playerKey, { hostRealm = hostRealm }) then
                node.seat = i
                return
            end
        end
    end

    local function SeatWireFields(into)
        local keys, index = {}, {}
        local ss, rs = {}, {}
        local sharedRealm
        local mixed = false
        for i = 1, node.maxSeats do
            local k = node.seats[i]
            if k and k ~= "" then
                if not index[k] then
                    keys[#keys + 1] = k
                    index[k] = #keys
                    local _, realm = P.SplitPlayerKey(k)
                    if sharedRealm == nil then
                        sharedRealm = realm
                    elseif realm ~= sharedRealm then
                        mixed = true
                    end
                end
                ss[i] = tostring(index[k])
            else
                ss[i] = "0"
            end
            rs[i] = node.ready[i] and "1" or "0"
        end
        if not mixed and sharedRealm and sharedRealm ~= "" then
            into.kr = sharedRealm
            for i = 1, #keys do
                into["k" .. i] = P.SplitPlayerKey(keys[i])
            end
        else
            for i = 1, #keys do
                into["k" .. i] = keys[i]
            end
        end
        into.ss = table.concat(ss)
        into.rs = table.concat(rs)
        if node.lobbyGroup then
            local lg = {}
            for i = 1, node.maxSeats do
                local k = node.seats[i]
                local g = k and node.lobbyGroup[k]
                lg[i] = (g == "B" and "B") or (g == "A" and "A") or "0"
            end
            into.lg = table.concat(lg)
        end
    end

    local function ApplySeatFields(fields)
        if fields.ss then
            local keys = {}
            local realm = fields.kr
            for i = 1, node.maxSeats do
                local k = fields["k" .. i]
                if k and k ~= "" then
                    if realm and realm ~= "" and not string.find(k, "-", 1, true) then
                        k = k .. "-" .. realm
                    end
                    keys[i] = k
                end
            end
            local ss = tostring(fields.ss)
            local rs = tostring(fields.rs or "")
            for i = 1, node.maxSeats do
                local idx = tonumber(ss:sub(i, i))
                node.seats[i] = (idx and idx > 0) and keys[idx] or nil
                node.ready[i] = rs:sub(i, i) == "1"
            end
            if fields.lg then
                node.lobbyGroup = {}
                local lg = tostring(fields.lg)
                for i = 1, node.maxSeats do
                    local g = lg:sub(i, i)
                    if node.seats[i] and (g == "A" or g == "B") then
                        node.lobbyGroup[node.seats[i]] = g
                    end
                end
            end
            BindLocalSeat()
            return
        end
        if fields.s1 == nil then
            return
        end
        for i = 1, node.maxSeats do
            local s = fields["s" .. i]
            if s == "" then s = nil end
            node.seats[i] = s
            node.ready[i] = fields["r" .. i] == "1"
        end
        BindLocalSeat()
    end

    local function SamePlayer(a, b)
        local host = node.hostKey or node.playerKey
        local _, hostRealm = P.SplitPlayerKey(host)
        return P.SamePlayer(a, b, { hostRealm = hostRealm })
    end

    local function SeatOf(playerKey)
        for i = 1, node.maxSeats do
            if SamePlayer(node.seats[i], playerKey) then
                return i
            end
        end
        return nil
    end

    local function OwnsSeat(playerKey, seat)
        return seat and SamePlayer(node.seats[seat], playerKey)
    end

    local function FromHost(fromKey)
        local host = node.hostKey or (node.isHost and node.playerKey)
        if not host or not fromKey then return false end
        return SamePlayer(fromKey, host)
    end

    local function IsInvited(fromKey)
        if not node.invited or not fromKey then return false end
        if node.invited[fromKey] then return true end
        for k, v in pairs(node.invited) do
            if v and SamePlayer(k, fromKey) then return true end
        end
        return false
    end

    local function MarkReadyFor(playerKey, isReady)
        local any = false
        for i = 1, node.maxSeats do
            if SamePlayer(node.seats[i], playerKey) then
                node.ready[i] = isReady and true or false
                any = true
            end
        end
        return any
    end

    local function AllReady()
        for i = 1, node.maxSeats do
            if not node.seats[i] then return false end
            if not node.ready[i] then return false end
        end
        return true
    end

    local function SnapshotFields(ackSeat, ackIntentId)
        local f = {
            matchId = node.matchId,
            stateRevision = node.stateRevision,
            matchState = node.state,
        }
        local pub = node.publicState
        if pub then
            if pub.count then f.count = pub.count end
            if pub.lastSeat then f.lastSeat = pub.lastSeat end
        end
        if ackSeat then f.ackSeat = ackSeat end
        if ackIntentId then f.ackIntentId = ackIntentId end
        if node.state == P.STATE.LOBBY then
            SeatWireFields(f)
        elseif node.state == P.STATE.PLAYING or node.state == P.STATE.FINISHED then
            if node.packPublic then
                local extra = node.packPublic(pub)
                if extra then
                    for k, v in pairs(extra) do
                        if v ~= nil and v ~= "" then
                            f[k] = v
                        end
                    end
                end
            end
        end
        return f
    end

    local function BroadcastSnapshot(ackSeat, ackIntentId)
        node.stateRevision = node.stateRevision + 1
        local payload, err = Encode(P.TYPE.SNAPSHOT, SnapshotFields(ackSeat, ackIntentId))
        if not payload then
            Warn("snapshot " .. tostring(err))
            return
        end
        SendToMembers(payload)
        if node.isHost then
            for i = 1, node.maxSeats do
                local key = node.seats[i]
                local hid = node.privateForSeat(i, node.publicState, node._hostHidden)
                if key and hid ~= nil then
                    if key == node.playerKey then
                        node._p = hid
                    else
                        local pp = Encode(P.TYPE.PRIVATE, {
                            matchId = node.matchId,
                            rev = node.stateRevision,
                            h = hid,
                        })
                        SendUnicast(key, pp)
                    end
                end
            end
        end
    end

    local function SendWelcomeTo(toKey, seat)
        local wfields = {
            matchId = node.matchId,
            seat = seat,
            hostKey = node.playerKey,
            proto = node.proto,
            addon = node.addon,
        }
        SeatWireFields(wfields)
        local welcome = Encode(P.TYPE.WELCOME, wfields)
        if not welcome then
            welcome = Encode(P.TYPE.WELCOME, {
                matchId = node.matchId,
                seat = seat,
                hostKey = node.playerKey,
                proto = node.proto,
                addon = node.addon,
            })
        end
        SendUnicast(toKey, welcome)
    end

    local function RecoverGuest(fromKey)
        local seat = SeatOf(fromKey)
        if not seat then
            SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "no-seat", proto = node.proto }))
            return
        end
        local toKey = node.seats[seat] or fromKey
        local now = (GetTime and GetTime()) or 0
        if node._recoverAt and node._recoverWho == toKey and (now - node._recoverAt) < 2 then
            return
        end
        node._recoverAt = now
        node._recoverWho = toKey
        if node.state == P.STATE.LOBBY then
            SendWelcomeTo(toKey, seat)
            local snap = Encode(P.TYPE.SNAPSHOT, SnapshotFields())
            SendUnicast(toKey, snap)
            return
        end
        if node.state == P.STATE.PLAYING then
            SendWelcomeTo(toKey, seat)
            if node._startPayload then
                SendUnicast(toKey, node._startPayload)
            end
            local snap = Encode(P.TYPE.SNAPSHOT, SnapshotFields())
            SendUnicast(toKey, snap)
            local hid = node.privateForSeat(seat, node.publicState, node._hostHidden)
            if hid ~= nil then
                SendUnicast(toKey, Encode(P.TYPE.PRIVATE, {
                    matchId = node.matchId,
                    rev = node.stateRevision,
                    h = hid,
                }))
            end
            return
        end
        if node.state == P.STATE.FINISHED then
            SendWelcomeTo(toKey, seat)
            if node._startPayload then
                SendUnicast(toKey, node._startPayload)
            end
            local snap = Encode(P.TYPE.SNAPSHOT, SnapshotFields())
            SendUnicast(toKey, snap)
            SendUnicast(toKey, Encode(P.TYPE.RESULT, {
                matchId = node.matchId, resultId = node.matchId .. "-R1",
                count = node.publicState and node.publicState.count,
            }))
            return
        end
        SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "no-match", proto = node.proto }))
    end

    local function ApplyLobbyFields(fields)
        ApplySeatFields(fields)
        node.publicState = node.publicState or node.newPublic()
        node.publicState.count = P.Tonumber(fields.count, node.publicState.count)
        node.publicState.lastSeat = P.Tonumber(fields.lastSeat, node.publicState.lastSeat)
        if node.unpackPublic then
            node.unpackPublic(node.publicState, fields)
        end
        node.stateRevision = P.Tonumber(fields.stateRevision, node.stateRevision)
        if fields.ackSeat and tostring(P.Tonumber(fields.ackSeat, 0)) == tostring(node.seat) then
            node.lastAck = fields.ackIntentId
        end
        for i = 1, node.maxSeats do
            if node.seats[i] == node.playerKey then
                node.seat = i
                break
            end
        end
        if node.onPublic then node.onPublic(node) end
    end

    local function MaybeFinish()
        if node.state ~= P.STATE.PLAYING then return end
        if not node.isFinished(node.publicState) then return end
        if not Transition(node, P.STATE.FINISHED) then return end
        if not node.isHost then return end
        local resultId = node.matchId .. "-R1"
        local payload = Encode(P.TYPE.RESULT, {
            matchId = node.matchId,
            resultId = resultId,
            count = node.publicState.count,
        })
        SendToMembers(payload)
        node:ConsumeResult(resultId)
    end

    function node:ConsumeResult(resultId)
        if not resultId or resultId == "" then return false end
        if self.processedResultId == resultId or self.seenResults[resultId] then
            return false
        end
        self.seenResults[resultId] = true
        self.processedResultId = resultId
        if self.onResult then
            self.onResult(self, resultId)
        end
        return true
    end

    function node:GetState()
        return self.state
    end

    function node:GetPublicState()
        return self.publicState
    end

    function node:GetPrivateState()
        return self._p
    end

    function node:HideView()
        self.viewHidden = true
    end

    function node:ShowView()
        self.viewHidden = false
    end

    function node:SetPolicy(policy, pin)
        if self.state ~= P.STATE.IDLE and not (self.isHost and self.state == P.STATE.LOBBY) then
            return false
        end
        policy = policy or P.POLICY.OPEN
        if policy ~= P.POLICY.OPEN and policy ~= P.POLICY.PIN and policy ~= P.POLICY.INVITE then
            policy = P.POLICY.OPEN
        end
        if policy == P.POLICY.PIN then
            pin = P.NormalizePin(pin)
            if pin == "" then return false end
            self.pin = pin
        else
            self.pin = nil
        end
        self.policy = policy
        if self.isHost and self.state == P.STATE.LOBBY then
            local B = ArcadiaNexus.MatchBrowser
            if B and B.AdvertiseFromNode then B.AdvertiseFromNode(self) end
        end
        return true
    end

    function node:Invite(playerKey)
        if not self.isHost or self.state ~= P.STATE.LOBBY then return false end
        if not playerKey or playerKey == "" then return false end
        self.invited = self.invited or {}
        self.invited[playerKey] = true
        SendUnicast(playerKey, Encode(P.TYPE.INVITED, {
            matchId = self.matchId,
            gameId = self.gameId,
        }))
        return true
    end

    function node:HostMatch()
        if self.state ~= P.STATE.IDLE then return false end
        if self.policy == P.POLICY.PIN and P.NormalizePin(self.pin) == "" then
            return false
        end
        self.isHost = true
        self.matchId = NewMatchId()
        self.hostKey = self.playerKey
        self.seat = 1
        self.seats = { self.playerKey }
        self.ready = { false }
        self.invited = { [self.playerKey] = true }
        if self.policy == P.POLICY.PIN then
            self.pin = P.NormalizePin(self.pin)
        else
            self.pin = nil
        end
        self.publicState = self.newPublic()
        self._hostHidden = nil
        self._p = self.privateForSeat(1, self.publicState, self._hostHidden)
        self.stateRevision = 0
        self.processedIntent = {}
        self.lastClientSeq = {}
        self.gotStart = false
        self._startPayload = nil
        self._startAcks = nil
        self._pendingPlay = nil
        return Transition(self, P.STATE.LOBBY)
    end

    function node:Join(hostKey, pin)
        if self.state ~= P.STATE.IDLE then return false end
        if not hostKey then return false end
        self.hostKey = hostKey
        self.gotStart = false
        self._pendingPlay = nil
        local fields = {
            proto = self.proto,
            addon = self.addon,
            gameId = self.gameId,
            gameProto = self.gameProto,
            playerKey = self.playerKey,
        }
        pin = P.NormalizePin(pin)
        if pin ~= "" then
            fields.pin = pin
            self.pin = pin
        end
        local payload = Encode(P.TYPE.JOIN, fields)
        SendUnicast(hostKey, payload)
        return true
    end

    function node:Rejoin(hostKey, matchId)
        if self.state ~= P.STATE.IDLE then return false end
        if not hostKey or not matchId or matchId == "" then return false end
        self.hostKey = hostKey
        self.matchId = matchId
        self.isHost = false
        self.gotStart = false
        self._pendingPlay = nil
        local function PulseSync()
            if self.state ~= P.STATE.IDLE then return end
            local payload = Encode(P.TYPE.SYNC, { matchId = matchId })
            local MT = ArcadiaNexus.MatchTransport
            if MT and MT.BroadcastChatType and MT.BroadcastChatType() then
                SendBroadcast(payload)
            else
                SendUnicast(hostKey, payload)
            end
        end
        PulseSync()
        if ArcadiaNexus.TimerGuard then
            CancelRejoinWait()
            self._rejoinGuard = ArcadiaNexus.TimerGuard.New()
            local tries = 0
            self._rejoinGuard:EveryTicker(2, function()
                if self.state ~= P.STATE.IDLE then
                    self._rejoinGuard:Cancel()
                    return
                end
                tries = tries + 1
                if tries >= 8 then
                    self.rejectReason = "rejoin-timeout"
                    if self.onReject then
                        self.onReject(self, { reason = "rejoin-timeout" })
                    end
                    Transition(self, P.STATE.ABORTED)
                    self._rejoinGuard:Cancel()
                    return
                end
                PulseSync()
            end)
        end
        return true
    end

    function node:SetReady(ready)
        if self.state ~= P.STATE.LOBBY or not self.seat then return false end
        local payload = Encode(P.TYPE.READY, {
            matchId = self.matchId,
            ready = ready and "1" or "0",
        })
        if self.isHost then
            MarkReadyFor(self.playerKey, ready)
            BroadcastSnapshot()
            return true
        end
        SendUnicast(self.hostKey, payload)
        return true
    end

    function node:LobbyChanged()
        if not self.isHost or self.state ~= P.STATE.LOBBY then return false end
        BroadcastSnapshot()
        if self.onPublic then self.onPublic(self) end
        return true
    end

    function node:TryStart()
        if not self.isHost or self.state ~= P.STATE.LOBBY then return false end
        local readyOk
        if self.canTryStart then
            readyOk = self.canTryStart(self) == true
        else
            readyOk = AllReady()
        end
        if not readyOk then return false end
        if self.assignSeats then
            if self.assignSeats(self) == false then return false end
        end
        if self.seedOnStart then
            local pub, hid = self.seedOnStart()
            if pub then self.publicState = pub end
            if hid ~= nil then self._hostHidden = hid end
        end
        local fields = { matchId = self.matchId }
        SeatWireFields(fields)
        if self.packStart then
            local extra = self.packStart(self.publicState)
            if extra then
                for k, v in pairs(extra) do fields[k] = v end
            end
        end
        local payload, err = Encode(P.TYPE.START, fields)
        if not payload then
            Warn("start aborted: " .. tostring(err))
            return false
        end
        if not Transition(self, P.STATE.PLAYING) then return false end
        self.gotStart = true
        self._startPayload = payload
        self._startAcks = { [self.playerKey] = true }
        SendToMembers(payload)
        BroadcastSnapshot()
        if ArcadiaNexus.TimerGuard then
            if self._startGuard then self._startGuard:Cancel() end
            self._startGuard = ArcadiaNexus.TimerGuard.New()
            self._startTries = 0
            self._startGuard:EveryTicker(1.5, function()
                if self.state ~= P.STATE.PLAYING then
                    self._startGuard:Cancel()
                    return
                end
                local missing = false
                for i = 1, self.maxSeats do
                    local k = self.seats[i]
                    if k and k ~= "" then
                        local acked = self._startAcks[k]
                        if not acked then
                            for who in pairs(self._startAcks) do
                                if SamePlayer(who, k) then
                                    acked = true
                                    break
                                end
                            end
                        end
                        if not acked then
                            missing = true
                            break
                        end
                    end
                end
                if not missing then
                    self._startGuard:Cancel()
                    return
                end
                self._startTries = (self._startTries or 0) + 1
                if self._startTries > 5 then
                    Warn("start ack timeout")
                    self._startGuard:Cancel()
                    return
                end
                Log("start retry " .. tostring(self._startTries))
                SendToMembers(self._startPayload)
            end)
        end
        return true
    end

    function node:SendIntent(kind, extra)
        extra = extra or {}
        local seat = P.Tonumber(extra.senderSeat, self.seat)
        if self.state ~= P.STATE.PLAYING or not seat then return false end
        self.clientSeq = self.clientSeq + 1
        local intentId = P.IntentId(seat, self.clientSeq)
        local fields = {
            matchId = self.matchId,
            senderSeat = seat,
            clientSeq = self.clientSeq,
            intentId = intentId,
            kind = kind or "TAP",
        }
        for k, v in pairs(extra) do
            if k ~= "senderSeat" then
                fields[k] = v
            end
        end
        local payload = Encode(P.TYPE.INTENT, fields)
        if self.isHost then
            self:HandleIntent(self.playerKey, fields)
            return true
        end
        SendUnicast(self.hostKey, payload)
        return true
    end

    function node:RequestSnapshot()
        if self.isHost or not self.matchId or not self.seat then return false end
        if self.state ~= P.STATE.PLAYING and self.state ~= P.STATE.FINISHED then return false end
        SendUnicast(self.hostKey, Encode(P.TYPE.SYNC, { matchId = self.matchId }))
        return true
    end

    function node:Leave()
        if self.state == P.STATE.IDLE then return false end
        if self.isHost then
            return self:Abort("host-leave")
        end
        local payload = Encode(P.TYPE.LEAVE, { matchId = self.matchId })
        if self.hostKey then
            SendUnicast(self.hostKey, payload)
        end
        self.matchId = nil
        self.seat = nil
        self._p = nil
        self._hostHidden = nil
        return Transition(self, P.STATE.ABORTED) or Transition(self, P.STATE.IDLE)
    end

    function node:Abort(reason)
        if self.state == P.STATE.IDLE or self.state == P.STATE.ABORTED then
            return false
        end
        if self.isHost then
            local payload = Encode(P.TYPE.ABORT, {
                matchId = self.matchId,
                reason = reason or "host-abort",
            })
            SendToMembers(payload)
        end
        self._p = nil
        self._hostHidden = nil
        return Transition(self, P.STATE.ABORTED)
    end

    function node:HandleIntent(fromKey, fields)
        if not self.isHost then return end
        if self.state ~= P.STATE.PLAYING then
            Warn("intent drop state=" .. tostring(self.state) .. " from=" .. tostring(fromKey))
            return
        end
        if fields.matchId ~= self.matchId then return end
        local claimed = P.Tonumber(fields.senderSeat, 0)
        local seat = (claimed ~= 0) and claimed or SeatOf(fromKey)
        if not OwnsSeat(fromKey, seat) then
            Warn("intent drop unbound from=" .. tostring(fromKey)
                .. " claimed=" .. tostring(claimed) .. " seat=" .. tostring(self.seat))
            return
        end
        local intentId = fields.intentId
        if not intentId or intentId == "" then
            Warn("intent drop no-id from=" .. tostring(fromKey))
            return
        end
        if self.processedIntent[intentId] then
            BroadcastSnapshot(seat, intentId)
            return
        end
        local cseq = P.Tonumber(fields.clientSeq, 0)
        local last = self.lastClientSeq[seat] or 0
        if cseq <= last then
            Warn("intent drop seq from=" .. tostring(fromKey) .. " cseq=" .. tostring(cseq))
            return
        end
        local ok = self.applyIntent(self.publicState, {
            kind = fields.kind,
            c = fields.c,
            n = fields.n,
            i = fields.i,
        }, seat, self._hostHidden)
        if not ok then
            Warn("intent drop apply from=" .. tostring(fromKey)
                .. " kind=" .. tostring(fields.kind) .. " seat=" .. tostring(seat))
            return
        end
        self.processedIntent[intentId] = true
        self.lastClientSeq[seat] = cseq
        self._p = self.privateForSeat(self.seat, self.publicState, self._hostHidden)
        BroadcastSnapshot(seat, intentId)
        -- CHAT_MSG_ADDON liefert dem Sender keinen eigenen Broadcast zurück.
        -- Der Host besitzt den aktualisierten autoritativen State bereits und
        -- muss seine lokale View daher direkt neu zeichnen.
        if self.onPublic then self.onPublic(self) end
        MaybeFinish()
    end

    function node:OnMessage(fromKey, payload, channel)
        Wire("rx", channel, payload, "from=" .. tostring(fromKey)
            .. " ss=" .. tostring(self.seats and (self.seats[1] and "y" or "n"))
            .. " seat=" .. tostring(self.seat)
            .. " gotStart=" .. tostring(self.gotStart))
        local msg, err = P.Decode(payload)
        if not msg then
            Log("decode " .. tostring(err))
            return
        end
        local t = msg.type
        local f = msg.fields

        if t == P.TYPE.PRIVATE then
            if channel ~= P.CHANNEL.UNICAST then
                Warn("private on broadcast ignored")
                return
            end
            if not FromHost(fromKey) then return end
            if f.matchId ~= self.matchId then return end
            local h = f.h
            if h == nil or h == "" then
                Warn("private without h ignored")
                return
            end
            if tostring(h) == "1" then
                self._p = 1
            else
                self._p = tostring(h)
            end
            self.stateRevision = P.Tonumber(f.rev or f.stateRevision, self.stateRevision)
            if self.onPublic then self.onPublic(self) end
            return
        end

        if t == P.TYPE.JOIN then
            if not self.isHost or self.state ~= P.STATE.LOBBY then return end
            if channel ~= P.CHANNEL.UNICAST then return end
            local theirProto = P.Tonumber(f.proto, 0)
            local theirGame = P.Tonumber(f.gameProto, 0)
            if theirProto ~= self.proto or f.gameId ~= self.gameId or theirGame ~= self.gameProto then
                local reason = "proto-mismatch"
                if theirProto < self.proto then reason = "proto-low" end
                if theirProto > self.proto then reason = "proto-high" end
                SendUnicast(fromKey, Encode(P.TYPE.REJECT, {
                    reason = reason,
                    proto = self.proto,
                    addon = self.addon,
                    youProto = theirProto,
                }))
                return
            end
            if SeatOf(fromKey) then return end
            if self.policy == P.POLICY.PIN then
                if P.NormalizePin(f.pin) ~= P.NormalizePin(self.pin) then
                    SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "pin", proto = self.proto }))
                    return
                end
            elseif self.policy == P.POLICY.INVITE then
                if not IsInvited(fromKey) then
                    SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "invite", proto = self.proto }))
                    return
                end
            end
            local seat
            for i = 2, self.maxSeats do
                if not self.seats[i] then seat = i break end
            end
            if not seat then
                SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "full", proto = self.proto }))
                return
            end
            self.seats[seat] = fromKey
            self.ready[seat] = false
            local wfields = {
                matchId = self.matchId,
                seat = seat,
                hostKey = self.playerKey,
                proto = self.proto,
                addon = self.addon,
            }
            SeatWireFields(wfields)
            local welcome = Encode(P.TYPE.WELCOME, wfields)
            if not welcome then
                welcome = Encode(P.TYPE.WELCOME, {
                    matchId = self.matchId,
                    seat = seat,
                    hostKey = self.playerKey,
                    proto = self.proto,
                    addon = self.addon,
                })
            end
            SendUnicast(fromKey, welcome)
            if self.onPublic then self.onPublic(self) end
            BroadcastSnapshot()
            return
        end

        if t == P.TYPE.WELCOME then
            if self.state ~= P.STATE.IDLE then return end
            if channel ~= P.CHANNEL.UNICAST then return end
            if not self.hostKey or not FromHost(fromKey) then return end
            CancelRejoinWait()
            self.matchId = f.matchId
            self.seat = P.Tonumber(f.seat, nil)
            self.hostKey = fromKey
            self.publicState = self.newPublic()
            ApplySeatFields(f)
            Transition(self, P.STATE.LOBBY)
            if self.onPublic then self.onPublic(self) end
            return
        end

        if t == P.TYPE.REJECT then
            if not FromHost(fromKey) then return end
            CancelRejoinWait()
            self.rejectReason = f.reason
            if self.onReject then self.onReject(self, f) end
            if self.state ~= P.STATE.ABORTED and self.state ~= P.STATE.FINISHED then
                Transition(self, P.STATE.ABORTED)
            end
            return
        end

        if t == P.TYPE.READY then
            if not self.isHost or self.state ~= P.STATE.LOBBY then return end
            if f.matchId ~= self.matchId then return end
            local seat = SeatOf(fromKey)
            if not seat then return end
            MarkReadyFor(fromKey, f.ready == "1")
            if self.onPublic then self.onPublic(self) end
            BroadcastSnapshot()
            return
        end

        if t == P.TYPE.START then
            if self.isHost then return end
            if not FromHost(fromKey) then return end
            if f.matchId ~= self.matchId then return end
            if not f.ss and f.s1 == nil then
                Warn("start ignored: no seats")
                return
            end
            CancelRejoinWait()
            if self.gotStart then
                ApplySeatFields(f)
                return
            end
            self.publicState = self.publicState or self.newPublic()
            ApplySeatFields(f)
            if self.unpackStart then
                self.unpackStart(self.publicState, f)
            end
            if self._pendingPlay then
                ApplyLobbyFields(self._pendingPlay)
                self._pendingPlay = nil
            end
            self.gotStart = true
            Transition(self, P.STATE.PLAYING)
            if self.hostKey then
                SendUnicast(self.hostKey, Encode(P.TYPE.STARTACK, {
                    matchId = self.matchId,
                }))
            end
            if self.onPublic then self.onPublic(self) end
            return
        end

        if t == P.TYPE.STARTACK then
            if not self.isHost then return end
            if f.matchId ~= self.matchId then return end
            self._startAcks = self._startAcks or {}
            self._startAcks[fromKey] = true
            Log("start ack from " .. tostring(fromKey))
            return
        end

        if t == P.TYPE.INTENT then
            if channel == P.CHANNEL.BROADCAST then
                return
            end
            self:HandleIntent(fromKey, f)
            return
        end

        if t == P.TYPE.SYNC then
            if not self.isHost then return end
            if f.matchId ~= self.matchId then
                SendUnicast(fromKey, Encode(P.TYPE.REJECT, { reason = "no-match", proto = self.proto }))
                return
            end
            RecoverGuest(fromKey)
            return
        end

        if t == P.TYPE.SNAPSHOT then
            if self.isHost then return end
            if not FromHost(fromKey) then return end
            if f.matchId ~= self.matchId then return end
            if f.matchState == P.STATE.PLAYING and not self.gotStart then
                self._pendingPlay = f
                Warn("snapshot playing before start; held seat=" .. tostring(self.seat))
                return
            end
            ApplyLobbyFields(f)
            return
        end

        if t == P.TYPE.RESULT then
            if not FromHost(fromKey) then return end
            if f.matchId ~= self.matchId then return end
            if self.state == P.STATE.PLAYING then
                Transition(self, P.STATE.FINISHED)
            end
            self:ConsumeResult(f.resultId)
            return
        end

        if t == P.TYPE.ABORT then
            if not FromHost(fromKey) then return end
            if f.matchId ~= self.matchId then return end
            self._p = nil
            self._hostHidden = nil
            Transition(self, P.STATE.ABORTED)
            return
        end

        if t == P.TYPE.LEAVE then
            if not self.isHost then return end
            if f.matchId ~= self.matchId then return end
            -- PLAYING: Sitz bleibt (Reload darf die Runde nicht sprengen).
            if self.state == P.STATE.PLAYING or self.state == P.STATE.FINISHED then
                return
            end
            local seat = SeatOf(fromKey)
            if seat then
                self.seats[seat] = nil
                self.ready[seat] = false
                if self.onPublic then self.onPublic(self) end
                BroadcastSnapshot()
            end
        end
    end

    if node.transport and node.transport.Register then
        node.transport:Register(node.playerKey, function(fromKey, payload, channel)
            node:OnMessage(fromKey, payload, channel)
        end)
    end

    local M = ArcadiaNexus.Match
    if M and M.TrackNode then M.TrackNode(node) end

    return node
end
