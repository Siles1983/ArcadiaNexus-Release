--[[
    ArcadiaNexus – Core/Match/Live.lua
    Dummy-Match über WoW-Transport. Zweifenster-Test in einer Party:

      /anlive host
      /anlive join          (an alle Gruppenmitglieder)
      /anlive ready
      /anlive start         (nur Host, beide ready)
      /anlive tap
      /anlive abort
      /anlive status
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchLive = {}
local L = ArcadiaNexus.MatchLive

local PFX = "|cff7ec8e3[Arcadia Live]|r "
local node

local function Say(msg)
    print(PFX .. msg)
end

local function NeedMp()
    if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then
        Say("|cffffaa00Multiplayer-Modul nicht geladen.|r")
        return false
    end
    return true
end

local function GroupKeys()
    local me = ArcadiaNexus.MatchTransport.LocalPlayerKey()
    local keys = {}
    local seen = {}
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

function L.EnsureNode()
    if node and node:GetState() ~= "ABORTED" and node:GetState() ~= "FINISHED" then
        return node
    end
    local MT = ArcadiaNexus.MatchTransport
    local transport = MT.StartWow()
    local key = MT.LocalPlayerKey()
    if not key then
        Say("Spielername noch nicht geladen.")
        return nil
    end
    node = ArcadiaNexus.MatchRuntime.Create({
        playerKey = key,
        transport = transport,
        maxSeats = 2,
        onState = function(n, newState)
            Say(n.playerKey .. " → " .. tostring(newState))
        end,
        onReject = function(_, f)
            Say("|cffff4444Reject:|r " .. tostring(f and f.reason) ..
                " (dein proto " .. tostring(f and f.youProto) ..
                ", nötig " .. tostring(f and f.proto) .. ")")
        end,
        onResult = function(_, resultId)
            Say("Ergebnis " .. tostring(resultId) .. " (count=" ..
                tostring(node:GetPublicState() and node:GetPublicState().count) .. ")")
        end,
    })
    return node
end

function L.Host()
    if not NeedMp() then return end
    node = nil
    local n = L.EnsureNode()
    if not n then return end
    if not n:HostMatch() then
        Say("Host fehlgeschlagen (nicht IDLE).")
        return
    end
    Say("Host läuft. Party-Partner: |cffffffff/anlive join|r")
    if not ArcadiaNexus.MatchTransport.BroadcastChatType() then
        Say("|cffffaa00Keine Gruppe — Join per Whisper: /anlive join Name-Realm|r")
    end
end

function L.Join(target)
    if not NeedMp() then return end
    if node and node.isHost then
        Say("Du hostest bereits. Der zweite Spieler tippt |cffffffff/anlive join|r — nicht du.")
        return
    end
    target = target and tostring(target):gsub("^%s+", ""):gsub("%s+$", "") or ""
    local targets = {}
    if target ~= "" then
        targets[1] = ArcadiaNexus.MatchTransport.NormalizeSender(target)
    else
        targets = GroupKeys()
    end
    if #targets == 0 then
        Say("Kein zweiter Spieler. /anlive braucht eine Party oder |cffffffff/anlive join Name-Realm|r")
        return
    end
    node = nil
    local n = L.EnsureNode()
    if not n then return end
    for i = 1, #targets do
        n:Join(targets[i])
        Say("JOIN an " .. targets[i])
    end
end

function L.Ready()
    if not node then Say("Kein Match. /anlive host oder join") return end
    if not node:SetReady(true) then
        Say("Ready fehlgeschlagen (nicht in LOBBY?).")
        return
    end
    Say("Ready.")
end

function L.Start()
    if not node or not node.isHost then
        Say("Nur der Host startet (/anlive start).")
        return
    end
    if not node:TryStart() then
        Say("Start fehlgeschlagen — Ready fehlt oder START-Paket zu groß.")
        return
    end
    Say("Match gestartet. /anlive tap")
end

function L.Tap()
    if not node then Say("Kein Match.") return end
    if not node:SendIntent("TAP") then
        Say("TAP fehlgeschlagen (nicht PLAYING?).")
        return
    end
    local pub = node:GetPublicState()
    Say("TAP count=" .. tostring(pub and pub.count))
end

function L.Abort()
    if not node then Say("Kein Match.") return end
    node:Abort("live-abort")
    Say("Abort.")
end

function L.Status()
    if not node then
        Say("Kein Live-Node. /anlive host | join")
        return
    end
    local pub = node:GetPublicState()
    local seats = {}
    for i = 1, node.maxSeats or 2 do
        seats[#seats + 1] = tostring(i) .. "=" .. tostring(node.seats and node.seats[i] or "-")
    end
    Say(string.format("state=%s seat=%s match=%s count=%s hid=%s host=%s gotStart=%s",
        tostring(node:GetState()),
        tostring(node.seat),
        tostring(node.matchId),
        tostring(pub and pub.count),
        tostring(node:GetPrivateState()),
        tostring(node.isHost),
        tostring(node.gotStart)))
    Say("seats " .. table.concat(seats, " "))
end

SLASH_ANLIVE1 = "/anlive"
SlashCmdList["ANLIVE"] = function(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and string.lower(cmd) or "status"
    if cmd == "host" then
        L.Host()
    elseif cmd == "join" then
        L.Join(rest)
    elseif cmd == "ready" then
        L.Ready()
    elseif cmd == "start" then
        L.Start()
    elseif cmd == "tap" then
        L.Tap()
    elseif cmd == "abort" then
        L.Abort()
    elseif cmd == "status" then
        L.Status()
    else
        print(PFX .. "host | join [Name] | ready | start | tap | abort | status")
        print(PFX .. "Loopback-Test bleibt |cffffffff/anmatch|r")
    end
end
