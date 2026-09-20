--[[
    ArcadiaNexus – Core/StatsTransfer.lua
    Export/Import von Fortschrittsdaten (JSON + Base64).
    Persistence bleibt Schema-Owner; Stores übernehmen die Schreibzugriffe.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.StatsTransfer = {}
local ST = ArcadiaNexus.StatsTransfer

ST.VERSION = "1.0"

-- ============================================================
-- JSON
-- ============================================================

local function JsonEncode(val)
    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end
        return tostring(val)
    elseif t == "string" then
        val = val:gsub("\\", "\\\\")
        val = val:gsub('"', '\\"'  )
        val = val:gsub("\n", "\\n" )
        val = val:gsub("\r", "\\r" )
        val = val:gsub("\t", "\\t" )
        return '"' .. val .. '"'
    elseif t == "table" then
        local isArray = true
        local maxN    = 0
        for k in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                isArray = false; break
            end
            if k > maxN then maxN = k end
        end
        if isArray and maxN ~= #val then isArray = false end
        if isArray then
            local parts = {}
            for i = 1, #val do parts[i] = JsonEncode(val[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(parts, JsonEncode(tostring(k)) .. ":" .. JsonEncode(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function JsonDecode(s)
    local pos = 1
    local function skip()
        while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
    end
    local function peek() skip(); return s:sub(pos,pos) end
    local decode
    local function decodeString()
        pos = pos + 1
        local result = {}
        while pos <= #s do
            local c = s:sub(pos,pos)
            if c == "\\" then
                pos = pos + 1
                local esc = s:sub(pos,pos)
                if     esc == "n"  then table.insert(result, "\n")
                elseif esc == "r"  then table.insert(result, "\r")
                elseif esc == "t"  then table.insert(result, "\t")
                elseif esc == "\\" then table.insert(result, "\\")
                elseif esc == "/"  then table.insert(result, "/")
                elseif esc == '"'  then table.insert(result, '"')
                else                    table.insert(result, esc) end
            elseif c == '"' then
                pos = pos + 1; break
            else
                table.insert(result, c)
            end
            pos = pos + 1
        end
        return table.concat(result)
    end
    local function decodeNumber()
        local start = pos
        while pos <= #s and s:sub(pos,pos):match("[%d%.%-%+eE]") do pos = pos + 1 end
        return tonumber(s:sub(start, pos-1))
    end
    local function decodeArray()
        local arr = {}
        pos = pos + 1
        skip()
        if peek() == "]" then pos = pos + 1; return arr end
        repeat
            table.insert(arr, decode())
            skip()
            if peek() == "," then pos = pos + 1 end
        until peek() == "]" or pos > #s
        pos = pos + 1
        return arr
    end
    local function decodeObject()
        local obj = {}
        pos = pos + 1
        skip()
        if peek() == "}" then pos = pos + 1; return obj end
        repeat
            skip()
            local key = decodeString()
            skip()
            pos = pos + 1
            obj[key] = decode()
            skip()
            if peek() == "," then pos = pos + 1 end
        until peek() == "}" or pos > #s
        pos = pos + 1
        return obj
    end
    decode = function()
        skip()
        local c = peek()
        if     c == '"' then return decodeString()
        elseif c == "[" then return decodeArray()
        elseif c == "{" then return decodeObject()
        elseif c == "t" then pos = pos + 4; return true
        elseif c == "f" then pos = pos + 5; return false
        elseif c == "n" then pos = pos + 4; return nil
        else                 return decodeNumber() end
    end
    local ok, result = pcall(decode)
    if ok then return result else return nil, result end
end

-- ============================================================
-- BASE64
-- ============================================================

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function B64Encode(data)
    local res = {}
    local len = #data
    local i   = 1
    while i <= len do
        local b0 = data:byte(i) or 0
        local b1 = data:byte(i+1) or 0
        local b2 = data:byte(i+2) or 0
        local n  = b0*65536 + b1*256 + b2
        local s  = B64:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1)
                .. B64:sub(math.floor(n/4096)%64+1,  math.floor(n/4096)%64+1)
                .. B64:sub(math.floor(n/64)%64+1,    math.floor(n/64)%64+1)
                .. B64:sub(n%64+1, n%64+1)
        local rem = len - i + 1
        if rem == 1 then s = s:sub(1,2).."=="
        elseif rem == 2 then s = s:sub(1,3).."=" end
        table.insert(res, s)
        i = i + 3
    end
    return table.concat(res)
end

local B64_DEC = {}
for i = 1, #B64 do B64_DEC[B64:sub(i,i)] = i-1 end
B64_DEC["="] = 0

local function B64Decode(data)
    data = data:gsub("[^%w%+%/%=]","")
    local res = {}
    local i   = 1
    while i <= #data do
        local c0 = B64_DEC[data:sub(i,i)]   or 0
        local c1 = B64_DEC[data:sub(i+1,i+1)] or 0
        local c2 = B64_DEC[data:sub(i+2,i+2)] or 0
        local c3 = B64_DEC[data:sub(i+3,i+3)] or 0
        local n  = c0*262144 + c1*4096 + c2*64 + c3
        table.insert(res, string.char(math.floor(n/65536)%256))
        if data:sub(i+2,i+2) ~= "=" then
            table.insert(res, string.char(math.floor(n/256)%256))
        end
        if data:sub(i+3,i+3) ~= "=" then
            table.insert(res, string.char(n%256))
        end
        i = i + 4
    end
    return table.concat(res)
end

-- ============================================================
-- PAYLOAD
-- ============================================================

function ST.Refresh()
    local XPM = ArcadiaNexus.XPManager
    if XPM and XPM.NormalizeProfile then
        XPM:NormalizeProfile()
        if ArcadiaNexus.Engine and ArcadiaNexus.Engine.Emit then
            ArcadiaNexus.Engine:Emit("XP_UPDATED", ArcadiaNexus.ProfileStore.Get())
        end
    end
    if ArcadiaNexus.StreakManager and ArcadiaNexus.StreakManager.Refresh then
        pcall(function() ArcadiaNexus.StreakManager:Refresh() end)
    end
    if ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
        pcall(function() ArcadiaNexus.UI.UpdateBadge() end)
    end
end

function ST.BuildPayload()
    if not _G.ArcadiaNexusDB then return nil end
    return {
        version     = ST.VERSION,
        exportedAt  = GetServerTime and GetServerTime() or 0,
        leaderboard = ArcadiaNexus.StatsStore.GetLeaderboard(),
        profile     = ArcadiaNexus.ProfileStore.Get(),
        streak      = ArcadiaNexus.StatsStore.GetStreak(),
        challenges  = { history = ArcadiaNexus.StatsStore.GetChallenges().history or {} },
    }
end

function ST.Validate(data)
    if type(data) ~= "table" then return false, "Kein gültiges Datenformat." end
    if data.version ~= ST.VERSION then
        return false, "Ungültige Version: " .. tostring(data.version)
    end
    if type(data.leaderboard) ~= "table" then return false, "leaderboard fehlt." end
    if type(data.profile)     ~= "table" then return false, "profile fehlt." end
    if type(data.streak)      ~= "table" then return false, "streak fehlt." end
    return true
end

function ST.Encode(payload)
    payload = payload or ST.BuildPayload()
    if not payload then return nil end
    return B64Encode(JsonEncode(payload))
end

function ST.Decode(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil, "Kein Text eingefügt."
    end
    local ok, jsonStr = pcall(B64Decode, raw)
    if not ok or not jsonStr then
        return nil, "Ungültiger Export-String."
    end
    local data, err = JsonDecode(jsonStr)
    if not data then
        return nil, "JSON-Fehler: " .. tostring(err)
    end
    local valid, validErr = ST.Validate(data)
    if not valid then return nil, validErr end
    return data
end

function ST.ApplyImport(data)
    local valid, err = ST.Validate(data)
    if not valid then return false, err end
    ArcadiaNexus.StatsStore.ImportProgression(data)
    ST.Refresh()
    if GH_LogInfo then GH_LogInfo("StatsTransfer", "Import erfolgreich angewendet.") end
    return true
end

function ST.Reset()
    ArcadiaNexus.StatsStore.ResetProgression()
    ST.Refresh()
end
