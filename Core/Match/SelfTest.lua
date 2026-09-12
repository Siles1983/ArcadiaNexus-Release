--[[
    ArcadiaNexus – Core/Match/SelfTest.lua
    Loopback-Dummy: vier virtuelle Sitze, ohne SI:7.
    Slash: /anmatch
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchSelfTest = {}
local ST = ArcadiaNexus.MatchSelfTest

local function MakeNodes(transport, extra)
    extra = extra or {}
    local rt = ArcadiaNexus.MatchRuntime
    local keys = { "A-Loop", "B-Loop", "C-Loop", "D-Loop" }
    local nodes = {}
    for i, key in ipairs(keys) do
        local opts = {
            playerKey = key,
            transport = transport,
            proto = extra.proto or nil,
        }
        if extra.protoFor and extra.protoFor[key] then
            opts.proto = extra.protoFor[key]
        end
        nodes[i] = rt.Create(opts)
        nodes[key] = nodes[i]
    end
    return nodes
end

local function Check(fails, cond, msg)
    if not cond then
        fails[#fails + 1] = msg
    end
end

--- Midnight: Secret Values dürfen oft nicht per == verglichen werden.
local function IsOne(v)
    if v == nil then return false end
    local ok, eq = pcall(function() return v == 1 end)
    if ok and eq then return true end
    return tostring(v) == "1"
end

function ST.Run()
    local P = ArcadiaNexus.MatchProtocol
    local D = ArcadiaNexus.MatchDummy
    local fails = {}
    local n = 0

    local function Case(name, fn)
        n = n + 1
        local ok, err = pcall(fn)
        if not ok then
            fails[#fails + 1] = name .. ": lua " .. tostring(err)
        end
    end

    Case("happy-path", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        Check(fails, A:HostMatch(), "host")
        Check(fails, A:GetState() == P.STATE.LOBBY, "host lobby")
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        Check(fails, B:GetState() == P.STATE.LOBBY, "B lobby")
        Check(fails, B.seat == 2, "B seat 2")
        Check(fails, C.seat == 3, "C seat 3")
        Check(fails, D.seat == 4, "D seat 4")
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        Check(fails, A:TryStart(), "start")
        Check(fails, A:GetState() == P.STATE.PLAYING, "A playing")
        Check(fails, B:GetState() == P.STATE.PLAYING, "B playing")
        B:SendIntent("TAP")
        C:SendIntent("TAP")
        Check(fails, (A:GetPublicState().count or 0) == 2, "count 2")
        Check(fails, (B:GetPublicState().count or 0) == 2, "B public 2")
        Check(fails, IsOne(A:GetPrivateState()), "A hid got=" .. tostring(A:GetPrivateState()))
        Check(fails, IsOne(B:GetPrivateState()), "B hid got=" .. tostring(B:GetPrivateState()))
        Check(fails, C:GetPrivateState() == nil, "C no hid")
        Check(fails, D:GetPrivateState() == nil, "D no hid")
        D:SendIntent("TAP")
        Check(fails, A:GetState() == P.STATE.FINISHED, "A finished")
        Check(fails, B:GetState() == P.STATE.FINISHED, "B finished")
        Check(fails, A.processedResultId ~= nil, "host result")
        Check(fails, B.processedResultId == A.processedResultId, "same resultId")
        local again = B:ConsumeResult(B.processedResultId)
        Check(fails, again == false, "result idempotent")
    end)

    Case("duplicate-intent", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        T:SetDuplicateNext(1)
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        B:SendIntent("TAP")
        Check(fails, A:GetPublicState().count == 1, "dup count 1")
    end)

    Case("same-player-realm", function()
        Check(fails, P.SamePlayer("Bob-Home", "Bob-Home"), "exact")
        Check(fails, P.SamePlayer("Bob", "Bob-Home", { localRealm = "Home" }), "short local")
        Check(fails, P.SamePlayer("Bob", "Bob-Home", { hostRealm = "Home" }), "short host")
        Check(fails, not P.SamePlayer("Bob", "Bob-Other", { localRealm = "Home", hostRealm = "Home" }), "other realm")
        Check(fails, not P.SamePlayer("Bob-Home", "Bob-Other"), "two realms")
    end)

    Case("peer-cannot-abort", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C = nodes[1], nodes[2], nodes[3]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        local payload = P.Encode(P.TYPE.ABORT, { matchId = A.matchId, reason = "spoof" })
        T:Inject(C.playerKey, payload, "BROADCAST")
        Check(fails, B:GetState() == P.STATE.LOBBY, "B still lobby")
        Check(fails, A:GetState() == P.STATE.LOBBY, "A still lobby")
    end)

    Case("peer-cannot-welcome", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local A = MakeNodes(T)[1]
        A:HostMatch()
        local E = ArcadiaNexus.MatchRuntime.Create({ playerKey = "E-Loop", transport = T })
        E.hostKey = A.playerKey
        local wel = P.Encode(P.TYPE.WELCOME, {
            matchId = A.matchId, seat = 2, hostKey = A.playerKey, ss = "12",
        })
        T:Inject("C-Loop", wel, "UNICAST", E.playerKey)
        Check(fails, E:GetState() == P.STATE.IDLE, "fake welcome ignored")
        Check(fails, E.seat == nil, "no spoof seat")
    end)

    Case("peer-cannot-private", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        local leaked = P.Encode(P.TYPE.PRIVATE, { matchId = A.matchId, h = "9", rev = 99 })
        T:Inject(C.playerKey, leaked, "UNICAST", B.playerKey)
        Check(fails, IsOne(B:GetPrivateState()), "private still host")
    end)

    Case("cross-realm-not-seat", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local rt = ArcadiaNexus.MatchRuntime
        local A = rt.Create({ playerKey = "Kathalina-Blackmoore", transport = T })
        local B = rt.Create({ playerKey = "Lyria-Blackmoore", transport = T })
        A:HostMatch()
        B:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        A:TryStart()
        local payload = P.Encode(P.TYPE.SYNC, { matchId = A.matchId })
        T:Inject("Lyria-OtherRealm", payload, "BROADCAST")
        Check(fails, A.seats[2] == B.playerKey, "seat unchanged")
        Check(fails, A:GetState() == P.STATE.PLAYING, "host playing")
    end)

    Case("seat-spoof", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        local payload = P.Encode(P.TYPE.INTENT, {
            matchId = A.matchId,
            senderSeat = 1,
            clientSeq = 99,
            intentId = "1-99",
            kind = "TAP",
        })
        T:Inject(D.playerKey, payload, "UNICAST", A.playerKey)
        Check(fails, A:GetPublicState().count == 0, "spoof ignored")
    end)

    Case("proto-mismatch", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T, { protoFor = { ["B-Loop"] = 2 } })
        local A, B = nodes[1], nodes[2]
        A:HostMatch()
        B:Join(A.playerKey)
        Check(fails, B:GetState() == P.STATE.ABORTED, "B aborted")
        Check(fails, B.rejectReason == "proto-high" or B.rejectReason == "proto-mismatch", "reject reason")
        Check(fails, B.seat == nil, "B no seat")
    end)

    Case("private-broadcast-ignored", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        local leaked = P.Encode(P.TYPE.PRIVATE, {
            matchId = A.matchId,
            stateRevision = 9,
            h = "9",
        })
        T:Inject(A.playerKey, leaked, "BROADCAST", nil)
        Check(fails, C:GetPrivateState() == nil, "C still no hid")
        Check(fails, D:GetPrivateState() == nil, "D still no hid")
    end)

    Case("hide-does-not-abort", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        B:HideView()
        Check(fails, B.viewHidden == true, "hidden")
        Check(fails, B:GetState() == P.STATE.PLAYING, "still playing")
        Check(fails, A:GetState() == P.STATE.PLAYING, "host still playing")
    end)

    Case("host-abort", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:Abort("test")
        Check(fails, A:GetState() == P.STATE.ABORTED, "A abort")
        Check(fails, B:GetState() == P.STATE.ABORTED, "B abort")
    end)

    Case("drop-then-retry", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C, D = nodes[1], nodes[2], nodes[3], nodes[4]
        A:HostMatch()
        B:Join(A.playerKey)
        C:Join(A.playerKey)
        D:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        C:SetReady(true)
        D:SetReady(true)
        A:TryStart()
        T:SetDropNext(1)
        B:SendIntent("TAP")
        Check(fails, (A:GetPublicState().count or 0) == 0, "dropped")
        B:SendIntent("TAP")
        Check(fails, A:GetPublicState().count == 1, "retried")
    end)

    Case("pin-required", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        Check(fails, A:SetPolicy(P.POLICY.PIN, "4321"), "set pin")
        Check(fails, A:HostMatch(), "host pin")
        B:Join(A.playerKey)
        Check(fails, B:GetState() == P.STATE.ABORTED, "no pin aborted")
        Check(fails, B.rejectReason == "pin", "reject pin")
    end)

    Case("pin-ok", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        A:SetPolicy(P.POLICY.PIN, "ab12")
        A:HostMatch()
        B:Join(A.playerKey, "ab12")
        Check(fails, B:GetState() == P.STATE.LOBBY, "pin join")
        Check(fails, B.seat == 2, "pin seat")
    end)

    Case("pin-not-on-list", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local A = MakeNodes(T)[1]
        A:SetPolicy(P.POLICY.PIN, "SECRET")
        A:HostMatch()
        local Brows = ArcadiaNexus.MatchBrowser
        Brows.AdvertiseFromNode(A)
        local list = Brows.List()
        local found
        for i = 1, #list do
            if list[i].matchId == A.matchId then found = list[i] break end
        end
        Check(fails, found ~= nil, "listed")
        Check(fails, found and found.policy == "PIN", "policy on list")
        Check(fails, found and found.pin == nil, "pin not listed")
        Check(fails, found and found.locked == true, "locked flag")
        Brows.StopAdvertise()
        Brows.Remove(A.matchId)
    end)

    Case("invite-gate", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B, C = nodes[1], nodes[2], nodes[3]
        A:SetPolicy(P.POLICY.INVITE)
        A:HostMatch()
        B:Join(A.playerKey)
        Check(fails, B:GetState() == P.STATE.ABORTED, "uninvited aborted")
        Check(fails, B.rejectReason == "invite", "reject invite")
        Check(fails, A:Invite(C.playerKey), "invite C")
        C:Join(A.playerKey)
        Check(fails, C:GetState() == P.STATE.LOBBY, "invited join")
    end)

    Case("invited-notice-from-host", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, C = nodes[1], nodes[3]
        A:SetPolicy(P.POLICY.INVITE)
        A:HostMatch()
        local Brows = ArcadiaNexus.MatchBrowser
        Brows.AdvertiseFromNode(A)
        Brows._invitedMatchId = nil
        local payload = P.Encode(P.TYPE.INVITED, { matchId = A.matchId, gameId = A.gameId })
        Brows.OnPayload(C.playerKey, payload)
        Check(fails, Brows._invitedMatchId == nil, "spoof ignored")
        A:Invite(C.playerKey)
        Brows.OnPayload(A.playerKey, payload)
        Check(fails, Brows._invitedMatchId == A.matchId, "guest saw allow")
        Brows.StopAdvertise()
        Brows.Remove(A.matchId)
        Brows._invitedMatchId = nil
    end)

    Case("host-pin-empty-fails", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local A = MakeNodes(T)[1]
        A.policy = P.POLICY.PIN
        A.pin = ""
        Check(fails, A:HostMatch() == false, "no empty pin host")
        Check(fails, A:GetState() == P.STATE.IDLE, "still idle")
    end)

    Case("guest-rejoin-playing", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        A:HostMatch()
        B:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        Check(fails, A:TryStart(), "start")
        B:SendIntent("TAP")
        Check(fails, A:GetPublicState().count == 1, "tap before drop")
        local hostKey, matchId = A.playerKey, A.matchId
        local B2 = ArcadiaNexus.MatchRuntime.Create({
            playerKey = "B-Loop",
            transport = T,
        })
        Check(fails, B2:Rejoin(hostKey, matchId), "rejoin send")
        Check(fails, B2:GetState() == P.STATE.PLAYING, "rejoin playing")
        Check(fails, B2.seat == 2, "same seat")
        Check(fails, (B2:GetPublicState() and B2:GetPublicState().count) == 1, "count restored")
        Check(fails, IsOne(B2:GetPrivateState()), "private restored")
    end)

    Case("guest-rejoin-lobby", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        A:HostMatch()
        B:Join(A.playerKey)
        local hostKey, matchId = A.playerKey, A.matchId
        local B2 = ArcadiaNexus.MatchRuntime.Create({
            playerKey = "B-Loop",
            transport = T,
        })
        B2:Rejoin(hostKey, matchId)
        Check(fails, B2:GetState() == P.STATE.LOBBY, "lobby rejoin")
        Check(fails, B2.seat == 2, "lobby seat")
    end)

    Case("rejoin-wrong-match", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        A:HostMatch()
        B:Join(A.playerKey)
        local B2 = ArcadiaNexus.MatchRuntime.Create({
            playerKey = "B-Loop",
            transport = T,
        })
        B2:Rejoin(A.playerKey, "M999999")
        Check(fails, B2:GetState() == P.STATE.ABORTED, "bad id abort")
        Check(fails, B2.rejectReason == "no-match", "no-match")
    end)

    Case("sync-broadcast-recovers", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local rt = ArcadiaNexus.MatchRuntime
        local A = rt.Create({ playerKey = "Kathalina-Blackmoore", transport = T })
        local B = rt.Create({ playerKey = "Lyria-Blackmoore", transport = T })
        Check(fails, A:HostMatch(), "host")
        B:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        Check(fails, A:TryStart(), "start")
        local B2 = rt.Create({ playerKey = "Lyria-Blackmoore", transport = T })
        local payload = P.Encode(P.TYPE.SYNC, { matchId = A.matchId })
        T:Inject("Lyria", payload, "BROADCAST")
        Check(fails, B2:GetState() == P.STATE.PLAYING, "broadcast sync recovered")
        Check(fails, B2.seat == 2, "short-name seat")
        Check(fails, A:GetState() == P.STATE.PLAYING, "host still playing")
    end)

    Case("leave-playing-keeps-seat", function()
        local T = ArcadiaNexus.MatchTransport.CreateLoopback({ sync = true })
        local nodes = MakeNodes(T)
        local A, B = nodes[1], nodes[2]
        A:HostMatch()
        B:Join(A.playerKey)
        A:SetReady(true)
        B:SetReady(true)
        A:TryStart()
        B:Leave()
        Check(fails, A:GetState() == P.STATE.PLAYING, "host not aborted")
        Check(fails, A.seats[2] == B.playerKey, "seat reserved")
        local B2 = ArcadiaNexus.MatchRuntime.Create({
            playerKey = "B-Loop",
            transport = T,
        })
        B2:Rejoin(A.playerKey, A.matchId)
        Check(fails, B2:GetState() == P.STATE.PLAYING, "rejoin after leave")
    end)

    local passed = n - #fails
    return {
        cases = n,
        passed = passed,
        failed = #fails,
        fails = fails,
    }
end

function ST.Print()
    local r = ST.Run()
    local prefix = "|cff7ec8e3[Arcadia Match]|r "
    if r.failed == 0 then
        print(prefix .. "|cff00ff88SelfTest OK|r " .. r.passed .. "/" .. r.cases)
    else
        print(prefix .. "|cffff4444SelfTest FAIL|r " .. r.passed .. "/" .. r.cases)
        for i = 1, math.min(8, #r.fails) do
            print(prefix .. r.fails[i])
        end
    end
    return r
end

SLASH_ANMATCH1 = "/anmatch"
SlashCmdList["ANMATCH"] = function()
    if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then
        print("|cffffaa00[Arcadia]|r Multiplayer-Modul nicht geladen.")
        return
    end
    ST.Print()
end
