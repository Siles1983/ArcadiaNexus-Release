--[[
    Games/SI7/Logic.lua
    Reine Regeln. Key-Karte nie im Public-State.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SI7_Logic = {}
local L = ArcadiaNexus.SI7_Logic

L.GAME_ID = "SI7"
L.GAME_PROTO = 2

local ID_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local ID_BASE = #ID_ALPHABET

local function Words()
    return ArcadiaNexus.SI7_Words
end

function L.Word(id)
    local stableId = Words()[id]
    local catalogue = ArcadiaNexus.HGM_Words
    local word = catalogue and catalogue:GetLocalizedWord(stableId, ArcadiaNexus.ActiveLocale)
    return word or "?"
end

function L.EmptyPublic()
    return {
        ids = {},
        mask = string.rep(".", 25),
        turn = "R",
        phase = "C",
        clue = "",
        n = 0,
        red = 9,
        blue = 8,
        winner = "",
        winReason = "",
        clues = 0,
        guesses = 0,
    }
end

function L.Deal()
    local pool = {}
    local src = Words()
    for i = 1, #src do pool[i] = i end
    ArcadiaNexus.ArrayUtils.Shuffle(pool)
    local ids = {}
    for i = 1, 25 do ids[i] = pool[i] end
    local cells = {}
    for _ = 1, 9 do cells[#cells + 1] = "R" end
    for _ = 1, 8 do cells[#cells + 1] = "B" end
    for _ = 1, 7 do cells[#cells + 1] = "N" end
    cells[#cells + 1] = "X"
    ArcadiaNexus.ArrayUtils.Shuffle(cells)
    local pub = L.EmptyPublic()
    pub.ids = ids
    return pub, table.concat(cells)
end

--- Lobby-Gruppen A/B (je 2 Spieler) → Spielsitze 1–4.
--- Würfelt Horde/Allianz und Spion/Agent. Sitz 1+2 Horde, 3+4 Allianz.
--- Zwei Clients: jeder Key wird zum ganzen Paar (Spion+Agent lokal).
function L.PresentKeys(seats)
    local keys, seen = {}, {}
    for i = 1, 4 do
        local k = seats and seats[i]
        if k and k ~= "" and not seen[k] then
            seen[k] = true
            keys[#keys + 1] = k
        end
    end
    return keys
end

function L.CanTryStart(node)
    if not node then return false end
    local keys = L.PresentKeys(node.seats)
    local n = #keys
    if n ~= 2 and n ~= 4 then return false end
    local max = node.maxSeats or 4
    for i = 1, max do
        local k = node.seats and node.seats[i]
        if k and k ~= "" and not node.ready[i] then
            return false
        end
    end
    if n == 4 and node.lobbyGroup then
        local nA, nB = 0, 0
        for i = 1, #keys do
            if node.lobbyGroup[keys[i]] == "B" then
                nB = nB + 1
            else
                nA = nA + 1
            end
        end
        if nA ~= 2 or nB ~= 2 then return false end
    end
    return true
end

function L.RollGameSeats(seats, lobbyGroup)
    local keys = L.PresentKeys(seats)
    if #keys == 2 then
        local a, b = keys[1], keys[2]
        if lobbyGroup then
            local aIsB = lobbyGroup[a] == "B"
            local bIsB = lobbyGroup[b] == "B"
            if aIsB and not bIsB then
                a, b = b, a
            end
        end
        if math.random(1, 2) == 2 then
            a, b = b, a
        end
        return { a, a, b, b }
    end
    local a, b = {}, {}
    for i = 1, 4 do
        local key = seats and seats[i]
        if not key or key == "" then return nil end
        if lobbyGroup and lobbyGroup[key] == "B" then
            b[#b + 1] = key
        else
            a[#a + 1] = key
        end
    end
    if #a ~= 2 or #b ~= 2 then return nil end
    ArcadiaNexus.ArrayUtils.Shuffle(a)
    ArcadiaNexus.ArrayUtils.Shuffle(b)
    if math.random(1, 2) == 2 then
        a, b = b, a
    end
    return { a[1], a[2], b[1], b[2] }
end

function L.Role(seat)
    if seat == 1 then return "R", true end
    if seat == 2 then return "R", false end
    if seat == 3 then return "B", true end
    if seat == 4 then return "B", false end
    return nil, false
end

local function SetChar(s, i, ch)
    return s:sub(1, i - 1) .. ch .. s:sub(i + 1)
end

local function EndTurn(pub)
    pub.turn = (pub.turn == "R") and "B" or "R"
    pub.phase = "C"
    pub.clue = ""
    pub.n = 0
end

local function BoardHasWord(pub, word)
    word = string.upper(tostring(word or ""))
    for i = 1, 25 do
        if L.Word(pub.ids[i]) == word then return true end
    end
    return false
end

function L.Apply(pub, key, intent, seat)
    if not pub or not key or not intent or pub.winner ~= "" then
        return false
    end
    local team, spy = L.Role(seat)
    if not team then return false end
    local kind = intent.kind

    if kind == "CLUE" then
        if not spy or team ~= pub.turn or pub.phase ~= "C" then return false end
        local clue = string.upper(tostring(intent.c or ""):gsub("%s+", ""))
        if clue == "" or #clue > 16 then return false end
        if not clue:match("^[A-Z]+$") then return false end
        if BoardHasWord(pub, clue) then return false end
        local n = tonumber(intent.n) or 0
        if n < 0 or n > 9 then return false end
        pub.clue = clue
        pub.n = n
        pub.phase = "G"
        pub.clues = (pub.clues or 0) + 1
        return true
    end

    if kind == "PASS" then
        if spy or team ~= pub.turn or pub.phase ~= "G" then return false end
        EndTurn(pub)
        return true
    end

    if kind == "GUESS" then
        if spy or team ~= pub.turn or pub.phase ~= "G" then return false end
        local i = tonumber(intent.i)
        if not i or i < 1 or i > 25 then return false end
        if pub.mask:sub(i, i) ~= "." then return false end
        local col = key:sub(i, i)
        pub.mask = SetChar(pub.mask, i, col)
        pub.guesses = (pub.guesses or 0) + 1
        if col == "X" then
            pub.winner = (team == "R") and "B" or "R"
            pub.winReason = "assassin"
            pub.phase = "O"
            return true
        end
        if col == "R" then
            pub.red = pub.red - 1
            if pub.red <= 0 then
                pub.winner = "R"
                pub.winReason = "cleared"
                pub.phase = "O"
                return true
            end
            if team == "R" then
                if pub.n > 0 then
                    pub.n = pub.n - 1
                    if pub.n == 0 then EndTurn(pub) end
                end
            else
                EndTurn(pub)
            end
            return true
        end
        if col == "B" then
            pub.blue = pub.blue - 1
            if pub.blue <= 0 then
                pub.winner = "B"
                pub.winReason = "cleared"
                pub.phase = "O"
                return true
            end
            if team == "B" then
                if pub.n > 0 then
                    pub.n = pub.n - 1
                    if pub.n == 0 then EndTurn(pub) end
                end
            else
                EndTurn(pub)
            end
            return true
        end
        EndTurn(pub)
        return true
    end

    return false
end

function L.IsFinished(pub)
    return pub and pub.winner ~= nil and pub.winner ~= ""
end

function L.PackIds(pub)
    if not pub or not pub.ids then return "" end
    local t = {}
    for i = 1, 25 do
        local id = tonumber(pub.ids[i]) or 0
        if id < 0 or id >= ID_BASE * ID_BASE then return "" end
        t[i] = ID_ALPHABET:sub(math.floor(id / ID_BASE) + 1, math.floor(id / ID_BASE) + 1)
            .. ID_ALPHABET:sub((id % ID_BASE) + 1, (id % ID_BASE) + 1)
    end
    return table.concat(t)
end

function L.UnpackIds(s)
    local ids = {}
    if not s or s == "" then return ids end
    if not s:find(",", 1, true) and #s >= 50 then
        for i = 1, 25 do
            local hi = ID_ALPHABET:find(s:sub(i * 2 - 1, i * 2 - 1), 1, true)
            local lo = ID_ALPHABET:find(s:sub(i * 2, i * 2), 1, true)
            ids[i] = hi and lo and ((hi - 1) * ID_BASE + (lo - 1)) or 0
        end
        return ids
    end
    for part in string.gmatch(s, "[^,]+") do
        ids[#ids + 1] = tonumber(part)
    end
    return ids
end

function L.PackPublic(pub)
    if not pub then return {} end
    return {
        m = pub.mask,
        t = pub.turn,
        p = pub.phase,
        c = pub.clue,
        n = pub.n,
        a = pub.red,
        b = pub.blue,
        w = pub.winner,
        wr = pub.winReason,
        k = pub.clues,
        g = pub.guesses,
    }
end

function L.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.m ~= nil and f.m ~= "" then pub.mask = f.m end
    if f.t ~= nil and f.t ~= "" then pub.turn = f.t end
    if f.p ~= nil and f.p ~= "" then pub.phase = f.p end
    if f.c ~= nil then pub.clue = f.c end
    if f.n ~= nil then pub.n = tonumber(f.n) or pub.n end
    if f.a ~= nil then pub.red = tonumber(f.a) or pub.red end
    if f.b ~= nil then pub.blue = tonumber(f.b) or pub.blue end
    if f.w ~= nil then pub.winner = f.w end
    if f.wr ~= nil then pub.winReason = f.wr end
    if f.k ~= nil then pub.clues = tonumber(f.k) or pub.clues end
    if f.g ~= nil then pub.guesses = tonumber(f.g) or pub.guesses end
end

function L.PackStart(pub)
    return { ids = L.PackIds(pub) }
end

function L.UnpackStart(pub, f)
    if f and f.ids then
        pub.ids = L.UnpackIds(f.ids)
    end
end

function L.PrivateForSeat(seat, key)
    if (seat == 1 or seat == 3) and type(key) == "string" and #key == 25 then
        return key
    end
    return nil
end

--- Callbacks für MatchRuntime.Create — kein C_ChatInfo.
function L.MatchOpts(engine)
    return {
        gameId = L.GAME_ID,
        gameProto = L.GAME_PROTO,
        maxSeats = 4,
        newPublic = L.EmptyPublic,
        seedOnStart = function()
            return L.Deal()
        end,
        packPublic = L.PackPublic,
        unpackPublic = L.UnpackPublic,
        packStart = L.PackStart,
        unpackStart = L.UnpackStart,
        applyIntent = function(pub, intent, seat, key)
            return L.Apply(pub, key, intent, seat)
        end,
        privateForSeat = function(seat, _, key)
            return L.PrivateForSeat(seat, key)
        end,
        isFinished = L.IsFinished,
        onState = function(_, st)
            if engine then engine:OnMatchState(st) end
        end,
        onResult = function(node, resultId)
            if engine then engine:OnMatchResult(node, resultId) end
        end,
        onReject = function(_, f)
            if engine then engine:OnMatchReject(f) end
        end,
        onPublic = function()
            if engine then engine:OnMatchPublic() end
        end,
        assignSeats = function(node)
            if not engine then return false end
            return engine:AssignMatchSeats(node)
        end,
        canTryStart = function(node)
            return L.CanTryStart(node)
        end,
    }
end
