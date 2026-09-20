--[[
    ArcadiaNexus – Core/Match/Transport_WoW.lua
    C_ChatInfo: PARTY/RAID/INSTANCE_CHAT = Broadcast, WHISPER = Unicast.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchTransport = ArcadiaNexus.MatchTransport or {}
local MT = ArcadiaNexus.MatchTransport

local PREFIX
local MAX_LEN = 255
local TOKENS_MAX = 10
local QUEUE_MAX = 128
local QUEUE_TTL = 30

local function Proto()
    return ArcadiaNexus.MatchProtocol
end

local function ResultCode(r)
    if r == nil or r == true then return 0 end
    if r == false then return 9 end
    return r
end

local function IsSuccess(r)
    r = ResultCode(r)
    local E = Enum and Enum.SendAddonMessageResult
    if E and E.Success ~= nil then
        return r == E.Success
    end
    return r == 0
end

local function IsNotInGroup(r)
    r = ResultCode(r)
    local E = Enum and Enum.SendAddonMessageResult
    if E and E.NotInGroup ~= nil then
        return r == E.NotInGroup
    end
    return r == 5
end

local function IsRetryable(r)
    local E = Enum and Enum.SendAddonMessageResult
    if not E then return r == 3 or r == 8 or r == 11 end
    return (E.AddonMessageThrottle ~= nil and r == E.AddonMessageThrottle)
        or (E.ChannelThrottle ~= nil and r == E.ChannelThrottle)
        or (E.AddOnMessageLockdown ~= nil and r == E.AddOnMessageLockdown)
end

function MT.LocalPlayerKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    name = name or (UnitName and UnitName("player"))
    if not name or name == "" then return nil end
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    realm = tostring(realm):gsub("%s+", "")
    if realm == "" then return name end
    return name .. "-" .. realm
end

function MT.NormalizeSender(sender)
    if not sender or sender == "" then return nil end
    if string.find(sender, "-", 1, true) then
        return sender
    end
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    realm = tostring(realm):gsub("%s+", "")
    if realm == "" then return sender end
    return sender .. "-" .. realm
end

function MT.GroupSize()
    if IsInRaid and IsInRaid() then
        return GetNumGroupMembers and GetNumGroupMembers() or 0
    end
    if IsInGroup and IsInGroup() then
        return (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) + 1
    end
    return 1
end

function MT.GroupMemberKeys()
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

function MT.BroadcastChatType()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local singleton

function MT.CreateWow()
    if singleton then return singleton end

    local P = Proto()
    PREFIX = (P and P.PREFIX) or "ANMATCH"
    MAX_LEN = (P and P.MAX_PAYLOAD) or 255

    local handler
    local handlerKey
    local handlerOwner
    local subs = {}
    local peers = {}
    local queue = {}
    local tokens = TOKENS_MAX
    local lastRegen = GetTime and GetTime() or 0
    local pumping = false

    local T = {
        name = "wow",
        _sent = 0,
        _dropped = 0,
        _delivered = 0,
    }

    local function Regen()
        local now = GetTime and GetTime() or lastRegen
        local add = math.floor(now - lastRegen)
        if add > 0 then
            tokens = math.min(TOKENS_MAX, tokens + add)
            lastRegen = lastRegen + add
        end
    end

    local function RawSend(chatType, payload, target)
        if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
            return 9
        end
        local result = select(-1, C_ChatInfo.SendAddonMessage(PREFIX, payload, chatType, target))
        return ResultCode(result)
    end

    local function Flush()
        Regen()
        while #queue > 0 and tokens > 0 do
            local item = queue[1]
            local expired = ((GetTime and GetTime()) or 0) - item.at > QUEUE_TTL
            local r = not expired and RawSend(item.chatType, item.payload, item.target)
            if expired then
                table.remove(queue, 1)
                T._dropped = T._dropped + 1
            elseif IsSuccess(r) then
                table.remove(queue, 1)
                tokens = tokens - 1
                T._sent = T._sent + 1
            elseif IsNotInGroup(r) and item.chatType ~= "WHISPER" then
                table.remove(queue, 1)
                T._dropped = T._dropped + 1
                if GH_LogWarn then
                    GH_LogWarn("MatchWow", "Broadcast ohne Gruppe")
                end
            elseif IsRetryable(r) then
                -- Throttle / Lockdown: später erneut
                break
            else
                table.remove(queue, 1)
                T._dropped = T._dropped + 1
                if GH_LogWarn then GH_LogWarn("MatchWow", "send failed: " .. tostring(r)) end
            end
        end
        if #queue > 0 and C_Timer and C_Timer.After and not pumping then
            pumping = true
            C_Timer.After(0.25, function()
                pumping = false
                Flush()
            end)
        end
    end

    local function Enqueue(chatType, payload, target)
        if type(payload) ~= "string" or payload == "" then return end
        if #payload > MAX_LEN then
            T._dropped = T._dropped + 1
            if GH_LogWarn then
                local t = payload:match("^AN1|([^|]+)") or "?"
                GH_LogWarn("MatchWow", "drop " .. t .. " n=" .. tostring(#payload) .. " >" .. tostring(MAX_LEN))
            end
            return
        end
        local msg = P.Decode(payload)
        if not msg then return end
        local kind, fields = msg.type, msg.fields
        local revision = tonumber(fields.rev or fields.stateRevision) or 0
        local replaceable = kind == "SNAPSHOT" or kind == "PRIVATE" or kind == "PRIVATEPART" or kind == "ANNOUNCE"
        for i = #queue, 1, -1 do
            local prior = queue[i]
            if prior.matchId == fields.matchId and prior.chatType == chatType and prior.target == target then
                local private = (kind == "PRIVATE" or kind == "PRIVATEPART")
                    and (prior.kind == "PRIVATE" or prior.kind == "PRIVATEPART")
                if replaceable and (prior.kind == kind or private) and prior.revision > revision then
                    return -- an older producer must not reinsert stale state
                end
                local replace = replaceable and ((prior.kind == kind and prior.part == fields.part)
                    or (private and revision > prior.revision))
                if kind == "ABORT" or (replace and revision >= prior.revision) then
                    table.remove(queue, i)
                end
            end
        end
        if #queue >= QUEUE_MAX then
            table.remove(queue, 1)
            T._dropped = T._dropped + 1
            if GH_LogWarn then GH_LogWarn("MatchWow", "queue limit reached") end
        end
        local item = { chatType = chatType, payload = payload, target = target,
            kind = kind, matchId = fields.matchId, revision = revision, part = fields.part,
            at = (GetTime and GetTime()) or 0 }
        if kind == "ABORT" or kind == "LEAVE" then table.insert(queue, 1, item)
        else queue[#queue + 1] = item end
        Flush()
    end

    function T:Register(playerKey, fn, owner)
        handlerKey = playerKey
        handler = fn
        handlerOwner = owner
        if playerKey then
            peers[playerKey] = nil
        end
    end

    function T:Subscribe(fn)
        if type(fn) == "function" then
            for i = 1, #subs do if subs[i] == fn then return end end
            subs[#subs + 1] = fn
        end
    end

    function T:Unregister(playerKey, owner)
        if playerKey and handlerKey ~= playerKey then return false end
        if owner and handlerOwner ~= owner then return false end
        handler = nil
        handlerKey = nil
        handlerOwner = nil
        return true
    end

    function T:DiscardMatch(matchId)
        for i = #queue, 1, -1 do
            local item = queue[i]
            if item.matchId == matchId and item.kind ~= "ABORT" and item.kind ~= "LEAVE"
                and not (item.kind == "ANNOUNCE" and item.payload:find("st=GONE", 1, true)) then
                table.remove(queue, i)
            end
        end
    end

    function T:GetQueueSize() return #queue end

    function T:NotePeer(key)
        if key and key ~= handlerKey then
            peers[key] = true
        end
    end

    function T:Broadcast(fromKey, payload)
        local chatType = MT.BroadcastChatType()
        if chatType then
            Enqueue(chatType, payload, nil)
            return
        end
        for key in pairs(peers) do
            Enqueue("WHISPER", payload, key)
        end
    end

    function T:Unicast(fromKey, toKey, payload)
        if not toKey or toKey == "" then return end
        self:NotePeer(toKey)
        Enqueue("WHISPER", payload, toKey)
    end

    function T:Inject()
        -- nur Loopback
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
        if event ~= "CHAT_MSG_ADDON" then return end
        if prefix ~= PREFIX then return end
        if channel ~= "WHISPER" and channel ~= "PARTY" and channel ~= "RAID"
            and channel ~= "INSTANCE_CHAT" then return end
        local fromKey = MT.NormalizeSender(sender)
        if not fromKey then return end
        local ch = (channel == "WHISPER") and "UNICAST" or "BROADCAST"
        T._delivered = T._delivered + 1
        if GH_LogInfo then
            local t = (message or ""):match("^AN1|([^|]+)") or "?"
            if t ~= "ANNOUNCE" then
                GH_LogInfo("MatchWow", "rx " .. t .. " ch=" .. tostring(channel)
                    .. " n=" .. tostring(message and #message) .. " from=" .. tostring(fromKey))
            end
        end
        if handler and not (handlerKey and fromKey == handlerKey) then
            handler(fromKey, message, ch)
        end
        for i = 1, #subs do
            subs[i](fromKey, message, ch)
        end
    end)

    T._frame = frame
    singleton = T
    return T
end

function MT.StartWow()
    local P = Proto()
    local prefix = (P and P.PREFIX) or "ANMATCH"
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    end
    return MT.CreateWow()
end
