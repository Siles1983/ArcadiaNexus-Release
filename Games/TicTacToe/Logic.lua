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

function Logic:CreateBoard(size, winLength)
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