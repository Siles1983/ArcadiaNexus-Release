--[[
    ArcadiaNexus – Core/Match/Protocol.lua
    Wire-Framing und Konstanten. AN1 darf sich praktisch nie ändern.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchProtocol = {}
local P = ArcadiaNexus.MatchProtocol

P.WIRE = "AN1"
P.PREFIX = "ANMATCH"
P.MATCH_PROTO = 2
P.MAX_PAYLOAD = 255
P.MAX_PREFIX = 16

P.TYPE = {
    ANNOUNCE = "ANNOUNCE", -- Pulse; st=GONE zieht die Sitzung aus der Liste (kein Dauerpoll)
    JOIN     = "JOIN",
    WELCOME  = "WELCOME",
    REJECT   = "REJECT",
    READY    = "READY",
    START    = "START",
    STARTACK = "STARTACK",
    INTENT   = "INTENT",
    SNAPSHOT = "SNAPSHOT",
    PRIVATE  = "PRIVATE",
    PRIVATEPART = "PRIVATEPART", -- bounded, revision-bound private reassembly
    RESULT   = "RESULT",
    ABORT    = "ABORT",
    LEAVE    = "LEAVE",
    SYNC     = "SYNC", -- optional: seated client requests a fresh authoritative snapshot
    SYNCACK  = "SYNCACK", -- host liveness / revision acknowledgement
    INVITED  = "INVITED", -- Host → Gast: Whitelist-Freigabe, kein Auto-Join
}

P.CHANNEL = {
    BROADCAST = "BROADCAST",
    UNICAST   = "UNICAST",
}

P.STATE = {
    IDLE     = "IDLE",
    LOBBY    = "LOBBY",
    PLAYING  = "PLAYING",
    FINISHED = "FINISHED",
    ABORTED  = "ABORTED",
}

P.POLICY = {
    OPEN   = "OPEN",
    PIN    = "PIN",
    INVITE = "INVITE",
}

--- PIN is anti-click, not a vault. Never put it on ANNOUNCE.
function P.NormalizePin(s)
    s = tostring(s or ""):gsub("%s+", ""):upper()
    if #s > 8 then s = s:sub(1, 8) end
    return s
end

function P.IsLockedPolicy(policy)
    return policy == P.POLICY.PIN or policy == P.POLICY.INVITE
end

function P.SplitPlayerKey(key)
    key = tostring(key or "")
    if key == "" then return nil, "" end
    local name, realm = key:match("^([^%-]+)%-(.+)$")
    if name then return name, realm end
    return key, ""
end

function P.LocalRealm()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    return tostring(realm):gsub("%s+", "")
end

--- Kurznamen nur gegen lokalen oder Host-Realm, nie gegen ein fremdes Realm.
function P.SamePlayer(a, b, opts)
    if not a or not b or a == "" or b == "" then return false end
    if a == b then return true end
    local na, ra = P.SplitPlayerKey(a)
    local nb, rb = P.SplitPlayerKey(b)
    if not na or not nb or na ~= nb then return false end
    if ra == rb then return true end
    opts = opts or {}
    local localRealm = opts.localRealm
    if localRealm == nil then localRealm = P.LocalRealm() end
    local hostRealm = opts.hostRealm or ""
    local function realmOk(full)
        if full == "" then return false end
        if localRealm ~= "" and full == localRealm then return true end
        if hostRealm ~= "" and full == hostRealm then return true end
        return false
    end
    if ra == "" then return realmOk(rb) end
    if rb == "" then return realmOk(ra) end
    return false
end

local function Esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("|", "\\p")
    return s
end

local function Unesc(s)
    s = tostring(s or "")
    -- Decode each escape once: a literal backslash followed by p is not a pipe.
    return (s:gsub("\\(.)", function(c)
        if c == "p" then return "|" end
        if c == "\\" then return "\\" end
        return "\\" .. c
    end))
end

function P.AddonVersion()
    if GetAddOnMetadata then
        local v = GetAddOnMetadata("ArcadiaNexus", "Version")
        if v and v ~= "" then return v end
    end
    return "1.1.0"
end

--- @param msgType string
--- @param fields table
--- @return string|nil, string|nil payload, err
function P.Encode(msgType, fields)
    if type(msgType) ~= "string" or msgType == "" then
        return nil, "bad-type"
    end
    local parts = { P.WIRE, msgType }
    if fields then
        for k, v in pairs(fields) do
            if v ~= nil then
                parts[#parts + 1] = Esc(k) .. "=" .. Esc(v)
            end
        end
    end
    local payload = table.concat(parts, "|")
    if #payload > P.MAX_PAYLOAD then
        return nil, "too-long"
    end
    return payload
end

--- @param payload string
--- @return table|nil, string|nil msg, err
function P.Decode(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil, "empty"
    end
    if #payload > P.MAX_PAYLOAD then return nil, "too-long" end
    local parts = {}
    local buf = payload
    local start = 1
    while true do
        local pipe = buf:find("|", start, true)
        if not pipe then
            parts[#parts + 1] = buf:sub(start)
            break
        end
        -- do not split escaped pipes: decoder sees already-wire form with \p
        parts[#parts + 1] = buf:sub(start, pipe - 1)
        start = pipe + 1
    end
    if parts[1] ~= P.WIRE then
        return nil, "bad-wire"
    end
    local msgType = parts[2]
    if not msgType or msgType == "" then
        return nil, "no-type"
    end
    local fields = {}
    for i = 3, #parts do
        local kv = parts[i]
        local eq = kv:find("=", 1, true)
        if eq then
            fields[Unesc(kv:sub(1, eq - 1))] = Unesc(kv:sub(eq + 1))
        end
    end
    return { type = msgType, fields = fields }
end

function P.IntentId(seat, clientSeq)
    return tostring(seat) .. "-" .. tostring(clientSeq)
end

function P.Tonumber(v, fallback)
    local n = tonumber(v)
    if n then return n end
    return fallback
end
