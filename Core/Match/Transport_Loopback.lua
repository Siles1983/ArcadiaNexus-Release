--[[
    ArcadiaNexus – Core/Match/Transport_Loopback.lua
    In-process Transport: Broadcast / Unicast, optionale Fault Injection.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchTransport = ArcadiaNexus.MatchTransport or {}
local MT = ArcadiaNexus.MatchTransport

local P = nil
local function Proto()
    if not P then P = ArcadiaNexus.MatchProtocol end
    return P
end

--- @param opts table|nil { sync?, dropNext?, duplicateNext?, truncate?, delaySec? }
function MT.CreateLoopback(opts)
    opts = opts or {}
    local proto = Proto()
    local maxLen = proto and proto.MAX_PAYLOAD or 255
    local handlers = {}
    local owners = {}
    local held = {}
    local holding = false
    local dropNext = opts.dropNext or 0
    local duplicateNext = opts.duplicateNext or 0
    local truncate = opts.truncate == true
    local delaySec = opts.delaySec
    local sync = opts.sync ~= false

    local T = {
        name = "loopback",
        _sent = 0,
        _dropped = 0,
        _delivered = 0,
    }

    function T:Register(playerKey, fn, owner)
        handlers[playerKey] = fn
        owners[playerKey] = owner
    end

    function T:Unregister(playerKey, owner)
        if owner and owners[playerKey] ~= owner then return false end
        handlers[playerKey] = nil
        owners[playerKey] = nil
        return true
    end

    function T:SetDropNext(n)
        dropNext = n or 0
    end

    function T:SetDuplicateNext(n)
        duplicateNext = n or 0
    end

    function T:SetHold(value) holding = value == true end
    function T:FlushHeld(reverse)
        local pending = held
        held = {}
        if reverse then
            for i = #pending, 1, -1 do pending[i]() end
        else
            for i = 1, #pending do pending[i]() end
        end
    end

    local function DeliverOnce(fromKey, payload, channel, toKey)
        if channel == "UNICAST" then
            local fn = handlers[toKey]
            if fn then
                T._delivered = T._delivered + 1
                fn(fromKey, payload, channel)
            end
            return
        end
        for key, fn in pairs(handlers) do
            if key ~= fromKey then
                T._delivered = T._delivered + 1
                fn(fromKey, payload, channel)
            end
        end
    end

    function T:_enqueue(fromKey, payload, channel, toKey)
        T._sent = T._sent + 1
        if truncate and #payload > maxLen then
            payload = payload:sub(1, maxLen)
        elseif #payload > maxLen then
            if GH_LogWarn then
                GH_LogWarn("MatchTransport", "payload > " .. maxLen .. " verworfen")
            end
            T._dropped = T._dropped + 1
            return
        end
        if dropNext > 0 then
            dropNext = dropNext - 1
            T._dropped = T._dropped + 1
            return
        end
        local copies = 1
        if duplicateNext > 0 then
            duplicateNext = duplicateNext - 1
            copies = 2
        end
        local function go()
            for _ = 1, copies do
                DeliverOnce(fromKey, payload, channel, toKey)
            end
        end
        if holding then held[#held + 1] = go; return end
        if (not sync) or (delaySec and delaySec > 0) then
            local wait = delaySec or 0
            if C_Timer and C_Timer.After then
                C_Timer.After(wait, go)
                return
            end
        end
        go()
    end

    function T:Broadcast(fromKey, payload)
        self:_enqueue(fromKey, payload, "BROADCAST", nil)
    end

    function T:Unicast(fromKey, toKey, payload)
        self:_enqueue(fromKey, payload, "UNICAST", toKey)
    end

    --- Spoof: beliebiger fromKey, für Host-Validierungstests.
    function T:Inject(fromKey, payload, channel, toKey)
        self:_enqueue(fromKey, payload, channel or "BROADCAST", toKey)
    end

    return T
end
