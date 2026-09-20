--[[
    Gaming Hub
    TicTacToe Logic.lua
    Version: 0.1.0 (Logic MVP)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TicTacToeLogic = {}

local Logic = ArcadiaNexus.TicTacToeLogic

-- ==========================================
-- Board Creation
-- ==========================================

function Logic.ClampSize(size)
    size = tonumber(size) or 3
    if size < 3 then size = 3 end
    if size > 5 then size = 5 end
    return size
end

function Logic.ClampWinLength(size, winLength)
    size = Logic.ClampSize(size)
    local w = tonumber(winLength) or size
    if w < 3 then w = 3 end
    if w > size then w = size end
    return w
end

function Logic:CreateBoard(size, winLength)
    size = Logic.ClampSize(size)
    winLength = Logic.ClampWinLength(size, winLength)
    local board = {
        size = size,
        winLength = winLength,
        cells = {}
    }

    for y = 1, size do
        board.cells[y] = {}
        for x = 1, size do
            board.cells[y][x] = 0
        end
    end

    return board
end

-- ==========================================
-- Get Available Moves
-- ==========================================

function Logic:GetAvailableMoves(board)
    local moves = {}

    for y = 1, board.size do
        for x = 1, board.size do
            if board.cells[y][x] == 0 then
                table.insert(moves, {x = x, y = y})
            end
        end
    end

    return moves
end

-- ==========================================
-- Apply Move
-- ==========================================

function Logic:ApplyMove(board, x, y, player)
    if board.cells[y][x] ~= 0 then
        return false
    end

    board.cells[y][x] = player
    return true
end

-- ==========================================
-- Check Win
-- ==========================================

local function countDirection(board, startX, startY, dx, dy, player)
    local count = 0
    local x = startX
    local y = startY

    while x >= 1 and x <= board.size and
          y >= 1 and y <= board.size and
          board.cells[y][x] == player do

        count = count + 1
        x = x + dx
        y = y + dy
    end

    return count
end

function Logic:CheckWin(board, lastX, lastY, player)
    local directions = {
        {1, 0},   -- horizontal
        {0, 1},   -- vertical
        {1, 1},   -- diagonal ↘
        {1, -1}   -- diagonal ↙
    }

    for _, dir in ipairs(directions) do
        local dx = dir[1]
        local dy = dir[2]

        local count = 1
        count = count + countDirection(board, lastX + dx, lastY + dy, dx, dy, player)
        count = count + countDirection(board, lastX - dx, lastY - dy, -dx, -dy, player)

        if count >= board.winLength then
        return "WIN", self:GetWinningLine(board, lastX, lastY, dx, dy, player)
        end
    end

-- ==========================================
    -- Check Draw
-- ==========================================

    if #self:GetAvailableMoves(board) == 0 then
        return "DRAW"
    end

    return nil
end
function Logic:DebugTestDraw()
    local b = self:CreateBoard(3,3)

    self:ApplyMove(b,1,1,1)
    self:ApplyMove(b,2,1,2)
    self:ApplyMove(b,3,1,1)

    self:ApplyMove(b,1,2,1)
    self:ApplyMove(b,2,2,2)
    self:ApplyMove(b,3,2,1)

    self:ApplyMove(b,1,3,2)
    self:ApplyMove(b,2,3,1)
    self:ApplyMove(b,3,3,2)

    print("Draw Test Result:", self:CheckWin(b,3,3,2))
end

-- ==========================================
    -- Check WinningLine
-- ==========================================

function Logic:GetWinningLine(board, lastX, lastY, dx, dy, player)
    local line = { {x = lastX, y = lastY} }

    local function collect(x, y, stepX, stepY)
        while x >= 1 and x <= board.size and
              y >= 1 and y <= board.size and
              board.cells[y][x] == player do
            table.insert(line, {x = x, y = y})
            x = x + stepX
            y = y + stepY
        end
    end

    collect(lastX + dx, lastY + dy,  dx,  dy)
    collect(lastX - dx, lastY - dy, -dx, -dy)

    -- BUGFIX: Die Punkte sind unsortiert (Reihenfolge der Sammlung hängt
    -- von lastX/lastY ab, nicht von der geometrischen Position auf dem Board).
    -- Damit line[1] und line[#line] immer die echten Endpunkte der Linie sind,
    -- sortieren wir nach der primären Achse der Richtung.
    -- Bei dx>0: sortiere nach x; bei dy>0 (und dx==0): sortiere nach y.
    if dx ~= 0 then
        table.sort(line, function(a, b) return a.x < b.x end)
    elseif dy ~= 0 then
        table.sort(line, function(a, b) return a.y < b.y end)
    end

    return line
end

-- ==========================================
-- Clone Board (Deep Copy)
-- ==========================================

function ArcadiaNexus.TicTacToeLogic:CloneBoard(board)

    local clone = {
        size = board.size,
        winLength = board.winLength,
        cells = {}
    }

    for y = 1, board.size do
        clone.cells[y] = {}
        for x = 1, board.size do
            clone.cells[y][x] = board.cells[y][x]
        end
    end

    return clone
end

-- ==========================================
-- Match (öffentliches 3x3, kein Hidden State, keine KI)
-- ==========================================

Logic.GAME_ID = "TICTACTOE"
Logic.GAME_PROTO = 1
Logic.MP_SIZE = 3

function Logic.EmptyPublic()
    local n = Logic.MP_SIZE
    return {
        size = n,
        winLength = n,
        turn = 1,
        over = false,
        winner = 0,
        cells = string.rep("0", n * n),
        line = nil,
        lastI = 0,
    }
end

local function CellIndex(size, x, y)
    return (y - 1) * size + x
end

function Logic.XY(size, i)
    i = tonumber(i) or 0
    local x = ((i - 1) % size) + 1
    local y = math.floor((i - 1) / size) + 1
    return x, y
end

function Logic.BoardFromPublic(pub)
    local size = (pub and pub.size) or Logic.MP_SIZE
    local board = Logic:CreateBoard(size, (pub and pub.winLength) or size)
    local cells = (pub and pub.cells) or ""
    for y = 1, size do
        for x = 1, size do
            local i = CellIndex(size, x, y)
            board.cells[y][x] = tonumber(cells:sub(i, i)) or 0
        end
    end
    return board
end

function Logic.PackLine(line)
    if type(line) ~= "table" then return "" end
    local parts = {}
    for i = 1, #line do
        local p = line[i]
        if p and p.x and p.y then
            parts[#parts + 1] = tostring(p.x) .. "." .. tostring(p.y)
        end
    end
    return table.concat(parts, ",")
end

function Logic.UnpackLine(s)
    if type(s) ~= "string" or s == "" then return nil end
    local line = {}
    for token in string.gmatch(s, "[^,]+") do
        local x, y = token:match("^(%d+)%.(%d+)$")
        if x then
            line[#line + 1] = { x = tonumber(x), y = tonumber(y) }
        end
    end
    return #line > 0 and line or nil
end

function Logic.ApplyMatch(pub, intent, seat)
    if not pub or pub.over then return false end
    seat = tonumber(seat) or 0
    if seat ~= 1 and seat ~= 2 then return false end
    if seat ~= (tonumber(pub.turn) or 1) then return false end
    local size = pub.size or Logic.MP_SIZE
    local i = tonumber(intent and intent.i)
    if not i or i < 1 or i > size * size then return false end
    local cells = pub.cells or string.rep("0", size * size)
    if #cells < size * size then
        cells = cells .. string.rep("0", size * size - #cells)
    end
    if cells:sub(i, i) ~= "0" then return false end
    pub.cells = cells:sub(1, i - 1) .. tostring(seat) .. cells:sub(i + 1)
    pub.lastI = i
    local x, y = Logic.XY(size, i)
    local board = Logic.BoardFromPublic(pub)
    local result, line = Logic:CheckWin(board, x, y, seat)
    if result == "WIN" then
        pub.over = true
        pub.winner = seat
        pub.line = line
    elseif result == "DRAW" then
        pub.over = true
        pub.winner = 0
        pub.line = nil
    else
        pub.turn = (seat == 1) and 2 or 1
        pub.line = nil
    end
    return true
end

function Logic.IsFinished(pub)
    return pub and pub.over == true
end

function Logic.PackPublic(pub)
    if not pub then return {} end
    return {
        sz = pub.size,
        wl = pub.winLength,
        t = pub.turn,
        o = pub.over and 1 or 0,
        w = pub.winner or 0,
        c = pub.cells,
        ln = Logic.PackLine(pub.line),
        li = pub.lastI or 0,
    }
end

function Logic.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.sz ~= nil then pub.size = tonumber(f.sz) or pub.size end
    if f.wl ~= nil then pub.winLength = tonumber(f.wl) or pub.winLength end
    if f.t ~= nil then pub.turn = tonumber(f.t) or pub.turn end
    if f.o ~= nil then pub.over = tonumber(f.o) == 1 end
    if f.w ~= nil then pub.winner = tonumber(f.w) or 0 end
    if f.c ~= nil and f.c ~= "" then pub.cells = f.c end
    if f.ln ~= nil then pub.line = Logic.UnpackLine(f.ln) end
    if f.li ~= nil then pub.lastI = tonumber(f.li) or 0 end
end

function Logic.PackStart(pub)
    return Logic.PackPublic(pub)
end

function Logic.UnpackStart(pub, f)
    Logic.UnpackPublic(pub, f)
end

function Logic.CanTryStart(node)
    if not node then return false end
    local n = 0
    local max = node.maxSeats or 2
    for i = 1, max do
        local k = node.seats and node.seats[i]
        if k and k ~= "" then
            n = n + 1
            if not (node.ready and node.ready[i]) then return false end
        end
    end
    return n == 2
end

function Logic.BoardStateFromPublic(pub, localSeat)
    pub = pub or Logic.EmptyPublic()
    local board = Logic.BoardFromPublic(pub)
    local result
    if pub.over then
        if (tonumber(pub.winner) or 0) == 0 then
            result = "DRAW"
        elseif tonumber(pub.winner) == tonumber(localSeat) then
            result = "WIN"
        else
            result = "LOSS"
        end
    end
    local moveCount = 0
    local cells = pub.cells or ""
    for i = 1, #cells do
        if cells:sub(i, i) ~= "0" then moveCount = moveCount + 1 end
    end
    local lastMove
    local lastI = tonumber(pub.lastI) or 0
    if lastI > 0 then
        local lx, ly = Logic.XY(pub.size or Logic.MP_SIZE, lastI)
        local actor = tonumber((pub.cells or ""):sub(lastI, lastI)) or 0
        lastMove = { x = lx, y = ly, actor = actor }
    end
    return {
        size = pub.size or Logic.MP_SIZE,
        cells = board.cells,
        gameOver = pub.over == true,
        result = result,
        winningLine = pub.line,
        lastMove = lastMove,
        moveCount = moveCount,
        turn = tonumber(pub.turn) or 1,
        localSeat = tonumber(localSeat) or 1,
    }
end

function Logic.MatchOpts(engine)
    return {
        gameId = Logic.GAME_ID,
        gameProto = Logic.GAME_PROTO,
        maxSeats = 2,
        newPublic = Logic.EmptyPublic,
        seedOnStart = function()
            return Logic.EmptyPublic()
        end,
        packPublic = Logic.PackPublic,
        unpackPublic = Logic.UnpackPublic,
        packStart = Logic.PackStart,
        unpackStart = Logic.UnpackStart,
        applyIntent = function(pub, intent, seat)
            return Logic.ApplyMatch(pub, intent, seat)
        end,
        privateForSeat = function()
            return nil
        end,
        isFinished = Logic.IsFinished,
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
        canTryStart = function(node)
            return Logic.CanTryStart(node)
        end,
    }
end