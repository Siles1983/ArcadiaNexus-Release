-- Pure standard backgammon. Seat 1 moves 24 -> 1; seat 2 moves 1 -> 24.
-- Bar is source 0; bearing off is destination 0. Never infer rules in the UI.
local A = ArcadiaNexus
A.BG_Logic = {}
local L = A.BG_Logic
L.GAME_ID, L.GAME_PROTO = "BACKGAMMON", 1
local alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTU"
local function sign(seat) return seat == 1 and 1 or -1 end
local function integer(n, lo, hi)
    return type(n) == "number" and n == math.floor(n) and n >= lo and n <= hi
end

function L.Copy(s)
    local t = {}
    for k, v in pairs(s) do
        if type(v) == "table" then
            t[k] = {}
            for i, x in pairs(v) do t[k][i] = x end
        else t[k] = v end
    end
    return t
end

function L.New()
    local s = { points = {}, bar = {0, 0}, off = {0, 0}, dice = {},
        turn = 1, turnNo = 0, revision = 0, phase = "opening", winner = 0, pointsWon = 0 }
    for i = 1, 24 do s.points[i] = 0 end
    s.points[24], s.points[13], s.points[8], s.points[6] = 2, 5, 3, 5
    s.points[1], s.points[12], s.points[17], s.points[19] = -2, -5, -3, -5
    return s
end

function L.Distance(point, seat) return seat == 1 and point or 25 - point end

function L.Pips(s, seat)
    local total = s.bar[seat] * 25
    for i = 1, 24 do
        if s.points[i] * sign(seat) > 0 then
            total = total + math.abs(s.points[i]) * L.Distance(i, seat)
        end
    end
    return total
end

function L.AllHome(s, seat)
    if s.bar[seat] > 0 then return false end
    for i = 1, 24 do
        if s.points[i] * sign(seat) > 0 and L.Distance(i, seat) > 6 then return false end
    end
    return true
end

function L.SingleMoves(s, seat, die)
    local out, sg = {}, sign(seat)
    if s.off[seat] == 15 then return out end
    if s.bar[seat] > 0 then
        local dest = seat == 1 and 25 - die or die
        if s.points[dest] * sg >= -1 then out[1] = { from = 0, to = dest, die = die } end
        return out
    end
    local home = L.AllHome(s, seat)
    for from = 1, 24 do
        if s.points[from] * sg > 0 then
            local dest = from - sg * die
            if dest >= 1 and dest <= 24 then
                if s.points[dest] * sg >= -1 then
                    out[#out + 1] = { from = from, to = dest, die = die }
                end
            elseif home then
                local distance, allowed = L.Distance(from, seat), true
                if die > distance then
                    for p = 1, 24 do
                        if s.points[p] * sg > 0 and L.Distance(p, seat) > distance then
                            allowed = false; break
                        end
                    end
                end
                if die >= distance and allowed then
                    out[#out + 1] = { from = from, to = 0, die = die }
                end
            end
        end
    end
    return out
end

-- Internal simulation primitive; callers must obtain moves from LegalTurns.
function L.Step(s, seat, m)
    local t, sg, enemy = L.Copy(s), sign(seat), 3 - seat
    if m.from == 0 then t.bar[seat] = t.bar[seat] - 1
    else t.points[m.from] = t.points[m.from] - sg end
    if m.to == 0 then t.off[seat] = t.off[seat] + 1
    else
        if t.points[m.to] == -sg then
            t.points[m.to] = 0
            t.bar[enemy] = t.bar[enemy] + 1
        end
        t.points[m.to] = t.points[m.to] + sg
    end
    return t
end

function L.EncodeMoves(moves)
    local out = {}
    for i, m in ipairs(moves) do out[i] = m.from .. "," .. m.to .. "," .. m.die end
    return table.concat(out, ";")
end

function L.DecodeMoves(text)
    if type(text) ~= "string" or #text > 40 then return nil end
    if text == "" then return {} end
    local out = {}
    for part in text:gmatch("[^;]+") do
        local f, t, d = part:match("^(%d+),(%d+),(%d+)$")
        f, t, d = tonumber(f), tonumber(t), tonumber(d)
        if not integer(f, 0, 24) or not integer(t, 0, 24) or not integer(d, 1, 6) then return nil end
        out[#out + 1] = { from = f, to = t, die = d }
    end
    if #out > 4 or L.EncodeMoves(out) ~= text then return nil end
    return out
end

-- Explore both orders, then enforce maximum dice usage and the higher-die rule.
-- Prefixes of these complete sequences are the ONLY moves offered to the player.
function L.LegalTurns(s)
    if s.phase ~= "move" then return {} end
    local leaves, best, higher = {}, -1, 0
    local function walk(board, dice, seq)
        if #dice == 0 then
            if #seq > best then leaves, best, higher = {}, #seq, 0 end
            if #seq == best then
                local copy = {}
                for i, m in ipairs(seq) do copy[i] = m end
                leaves[#leaves + 1] = copy
                if #seq == 1 then higher = math.max(higher, seq[1].die) end
            end
            return
        end
        local seen = {}
        for i, die in ipairs(dice) do
            if not seen[die] then
                seen[die] = true
                local rest = {}
                for j, d in ipairs(dice) do if j ~= i then rest[#rest + 1] = d end end
                local moves = L.SingleMoves(board, s.turn, die)
                if #moves == 0 then walk(board, rest, seq) end
                for _, m in ipairs(moves) do
                    seq[#seq + 1] = m
                    walk(L.Step(board, s.turn, m), rest, seq)
                    seq[#seq] = nil
                end
            end
        end
    end
    walk(s, s.dice, {})
    local out, unique = {}, {}
    for _, seq in ipairs(leaves) do
        local key = L.EncodeMoves(seq)
        if not unique[key] and (best ~= 1 or seq[1].die == higher) then
            unique[key] = true
            out[#out + 1] = seq
        end
    end
    return out
end

function L.PrefixMatches(seq, prefix)
    if #prefix > #seq then return false end
    for i, m in ipairs(prefix) do
        local x = seq[i]
        if x.from ~= m.from or x.to ~= m.to or x.die ~= m.die then return false end
    end
    return true
end

function L.NextMoves(turns, prefix)
    local moves, seen, complete = {}, {}, false
    for _, seq in ipairs(turns) do
        if L.PrefixMatches(seq, prefix) then
            local m = seq[#prefix + 1]
            if not m then complete = true
            else
                local key = L.EncodeMoves({m})
                if not seen[key] then moves[#moves + 1], seen[key] = m, true end
            end
        end
    end
    return moves, complete
end

function L.WinValue(s, winner)
    local loser = 3 - winner
    if s.off[loser] > 0 then return 1 end
    if s.bar[loser] > 0 then return 3 end
    for i = 1, 24 do
        if s.points[i] * sign(loser) > 0 and L.Distance(i, winner) <= 6 then return 3 end
    end
    return 2
end

function L.Roll(s, a, b)
    if (s.phase ~= "opening" and s.phase ~= "roll") or
        not integer(a, 1, 6) or not integer(b, 1, 6) then return false end
    s.dice = {a, b}
    s.revision = s.revision + 1
    if s.phase == "opening" then
        if a == b then return true end
        s.turn = a > b and 1 or 2
        s.turnNo = 1
    elseif a == b then s.dice = {a, a, a, a} end
    s.phase = "move"
    return true
end

function L.Commit(s, moves)
    local encoded, valid = L.EncodeMoves(moves), false
    for _, seq in ipairs(L.LegalTurns(s)) do
        if L.EncodeMoves(seq) == encoded then valid = true; break end
    end
    if not valid then return false end
    local nextState = s
    for _, m in ipairs(moves) do nextState = L.Step(nextState, s.turn, m) end
    local seat = s.turn
    s.points, s.bar, s.off = nextState.points, nextState.bar, nextState.off
    s.revision, s.dice = s.revision + 1, {}
    if s.off[seat] == 15 then
        s.winner, s.pointsWon, s.phase = seat, L.WinValue(s, seat), "over"
    else
        s.turn, s.turnNo, s.phase = 3 - seat, s.turnNo + 1, "roll"
    end
    return true
end

-- n binds each intent to the observed game revision (reject stale rolls/turns).
-- c is the runtime's existing compact game-payload field. Dice never come from clients.
function L.Apply(s, intent, seat, rng)
    if not s or not intent or s.winner ~= 0 or tonumber(intent.n) ~= s.revision then return false end
    if seat ~= (s.phase == "opening" and 1 or s.turn) then return false end
    if intent.kind == "ROLL" then
        if s.phase ~= "opening" and s.phase ~= "roll" then return false end
        rng = rng or math.random
        return L.Roll(s, rng(1, 6), rng(1, 6))
    end
    if intent.kind == "TURN" and s.phase == "move" then
        local moves = L.DecodeMoves(intent.c)
        return moves ~= nil and L.Commit(s, moves) or false
    end
    return false
end

function L.Validate(s)
    if type(s) ~= "table" or type(s.points) ~= "table" or type(s.bar) ~= "table"
        or type(s.off) ~= "table" or type(s.dice) ~= "table" then return false end
    if not integer(s.turn, 1, 2) or not integer(s.turnNo, 0, 1000000)
        or not integer(s.revision, 0, 10000000) or not integer(s.winner, 0, 2)
        or not integer(s.pointsWon, 0, 3) then return false end
    for seat = 1, 2 do
        if not integer(s.bar[seat], 0, 15) or not integer(s.off[seat], 0, 15) then return false end
        local count = s.bar[seat] + s.off[seat]
        for i = 1, 24 do
            if not integer(s.points[i], -15, 15) then return false end
            if s.points[i] * sign(seat) > 0 then count = count + math.abs(s.points[i]) end
        end
        if count ~= 15 then return false end
    end
    local n = #s.dice
    if n ~= 0 and n ~= 2 and n ~= 4 then return false end
    for _, d in ipairs(s.dice) do if not integer(d, 1, 6) then return false end end
    if n == 4 then
        for i = 2, 4 do if s.dice[i] ~= s.dice[1] then return false end end
    end
    if s.phase == "over" then
        return s.winner > 0 and s.off[s.winner] == 15 and s.pointsWon == L.WinValue(s, s.winner) and n == 0
    end
    if s.winner ~= 0 or s.pointsWon ~= 0 or s.off[1] == 15 or s.off[2] == 15 then return false end
    if s.phase == "opening" then return s.turnNo == 0 and (n == 0 or (n == 2 and s.dice[1] == s.dice[2])) end
    if s.turnNo < 1 then return false end
    if s.phase == "roll" then return n == 0 end
    return s.phase == "move" and (n == 4 or (n == 2 and s.dice[1] ~= s.dice[2]))
end

-- One character per point plus four bar/off counts; <100 bytes including metadata.
function L.Serialize(s)
    local board = {}
    for i = 1, 24 do board[i] = alphabet:sub(s.points[i] + 16, s.points[i] + 16) end
    for i, n in ipairs({s.bar[1], s.bar[2], s.off[1], s.off[2]}) do
        board[24 + i] = alphabet:sub(n + 1, n + 1)
    end
    return table.concat({"1", table.concat(board), s.turn, s.turnNo, s.revision,
        s.phase, s.winner, s.pointsWon, table.concat(s.dice)}, ":")
end

function L.Deserialize(text)
    if type(text) ~= "string" or #text > 110 then return nil end
    local v, b, turn, num, rev, phase, win, value, dice = text:match(
        "^(%d+):([0-9A-U]+):(%d+):(%d+):(%d+):(%a+):(%d+):(%d+):([1-6]*)$")
    if v ~= "1" or not b or #b ~= 28 then return nil end
    local s = { points = {}, bar = {}, off = {}, dice = {}, turn = tonumber(turn),
        turnNo = tonumber(num), revision = tonumber(rev), phase = phase,
        winner = tonumber(win), pointsWon = tonumber(value) }
    for i = 1, 24 do s.points[i] = alphabet:find(b:sub(i, i), 1, true) - 16 end
    s.bar = {alphabet:find(b:sub(25, 25), 1, true) - 1, alphabet:find(b:sub(26, 26), 1, true) - 1}
    s.off = {alphabet:find(b:sub(27, 27), 1, true) - 1, alphabet:find(b:sub(28, 28), 1, true) - 1}
    for d in dice:gmatch(".") do s.dice[#s.dice + 1] = tonumber(d) end
    if not L.Validate(s) then return nil end
    return s
end
