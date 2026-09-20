--[[
    Gaming Hub
    Games/ArcadiaRows/Logic.lua
    Version: 1.0.0

    Unterschiede zu TicTacToe/Logic.lua:
      - Brett ist NICHT quadratisch: cols × rows (z.B. 7×6)
      - ApplyMove() erhält nur eine Spalte (col).
        Der Stein fällt durch Schwerkraft zur untersten freien Zeile.
      - CheckWin() prüft immer auf genau 4 in einer Reihe (winLength = 4).
      - GetLowestRow() gibt die Zielzeile für eine Spalte zurück.
      - IsBoardFull() für Unentschieden-Erkennung.

    Board-Struktur:
      board.cols     – Anzahl Spalten
      board.rows     – Anzahl Zeilen
      board.winLength – immer 4
      board.cells[row][col] – 0 = leer, 1 = Spieler 1, 2 = Spieler 2
      Zeile 1 = OBEN, Zeile board.rows = UNTEN (Schwerkraft-Logik)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Logic = {}

local Logic = ArcadiaNexus.AR_Logic

-- ============================================================
-- CreateBoard
-- cols: Spalten (x-Achse), rows: Zeilen (y-Achse)
-- winLength: immer 4 für Vier Gewinnt
-- ============================================================

function Logic:CreateBoard(cols, rows)
    local board = {
        cols      = cols,
        rows      = rows,
        winLength = 4,
        cells     = {},
    }

    for row = 1, rows do
        board.cells[row] = {}
        for col = 1, cols do
            board.cells[row][col] = 0
        end
    end

    return board
end

-- Puzzle: 6 Zeilen à 7 Zeichen ('0' leer, '1' Spieler, '2' KI), Zeile 1 = oben.
-- Schwerkraft: keine schwebenden Steine. Setzt board.moveCount.
function Logic:LoadPuzzle(board, rowStrings)
    if not board or not rowStrings or #rowStrings ~= board.rows then
        return false
    end
    local moves = 0
    for r = 1, board.rows do
        local line = rowStrings[r]
        if type(line) ~= "string" or #line ~= board.cols then
            return false
        end
        for c = 1, board.cols do
            local n = tonumber(line:sub(c, c))
            if n ~= 0 and n ~= 1 and n ~= 2 then
                return false
            end
            board.cells[r][c] = n
            if n ~= 0 then
                moves = moves + 1
            end
        end
    end
    for c = 1, board.cols do
        local seenEmpty = false
        for r = board.rows, 1, -1 do
            if board.cells[r][c] == 0 then
                seenEmpty = true
            elseif seenEmpty then
                return false
            end
        end
    end
    if self:CheckAnyWin(board, 1) or self:CheckAnyWin(board, 2) then
        return false
    end
    board.moveCount = moves
    return true
end

-- ============================================================
-- GetLowestRow
-- Gibt die unterste freie Zeile in einer Spalte zurück.
-- Rückgabe nil wenn Spalte voll ist.
-- ============================================================

function Logic:GetLowestRow(board, col)
    for row = board.rows, 1, -1 do
        if board.cells[row][col] == 0 then
            return row
        end
    end
    return nil  -- Spalte voll
end

-- ============================================================
-- IsColumnFull
-- ============================================================

function Logic:IsColumnFull(board, col)
    return board.cells[1][col] ~= 0
end

-- ============================================================
-- GetAvailableColumns
-- Gibt alle Spalten zurück die noch mindestens eine freie Zeile haben.
-- ============================================================

function Logic:GetAvailableColumns(board)
    local cols = {}
    for col = 1, board.cols do
        if not self:IsColumnFull(board, col) then
            table.insert(cols, col)
        end
    end
    return cols
end

-- ============================================================
-- ApplyMove
-- col: Zielspalte (1-basiert)
-- player: 1 oder 2
-- Rückgabe: die Zeile in die der Stein gefallen ist, oder nil wenn voll.
-- ============================================================

function Logic:ApplyMove(board, col, player)
    local row = self:GetLowestRow(board, col)
    if not row then return nil end

    board.cells[row][col] = player
    return row
end

function Logic:CanPopOut(board, col, player)
    if not board or not col or not player then return false end
    if col < 1 or col > board.cols then return false end
    return board.cells[board.rows][col] == player
end

function Logic:GetPopColumns(board, player)
    local cols = {}
    for col = 1, board.cols do
        if self:CanPopOut(board, col, player) then
            cols[#cols + 1] = col
        end
    end
    return cols
end

function Logic:ApplyPopOut(board, col, player)
    if not self:CanPopOut(board, col, player) then return nil end
    local shifts = {}
    for row = board.rows, 2, -1 do
        local falling = board.cells[row - 1][col] or 0
        board.cells[row][col] = falling
        if falling ~= 0 then
            shifts[#shifts + 1] = {
                player  = falling,
                fromRow = row - 1,
                toRow   = row,
            }
        end
    end
    board.cells[1][col] = 0
    return board.rows, shifts, player
end

function Logic:HasMoves(board, player, allowPop)
    if #self:GetAvailableColumns(board) > 0 then return true end
    return allowPop and #self:GetPopColumns(board, player) > 0
end

-- ============================================================
-- IsBoardFull
-- ============================================================

function Logic:IsBoardFull(board)
    return #self:GetAvailableColumns(board) == 0
end

-- ============================================================
-- CheckWin
-- Prüft ob player nach dem Zug in Spalte col / Zeile row gewonnen hat.
-- Gibt "WIN" + winningLine oder nil zurück.
-- ============================================================

local function countDir(board, col, row, dc, dr, player)
    local count = 0
    local c = col + dc
    local r = row + dr

    while c >= 1 and c <= board.cols
      and r >= 1 and r <= board.rows
      and board.cells[r][c] == player do
        count = count + 1
        c = c + dc
        r = r + dr
    end

    return count
end

function Logic:GetWinningLine(board, col, row, dc, dr, player)
    -- Anfang der Linie rückwärts finden
    local startCol = col
    local startRow = row

    while startCol - dc >= 1 and startCol - dc <= board.cols
      and startRow - dr >= 1 and startRow - dr <= board.rows
      and board.cells[startRow - dr][startCol - dc] == player do
        startCol = startCol - dc
        startRow = startRow - dr
    end

    -- Linie vorwärts sammeln
    local line = {}
    local c = startCol
    local r = startRow

    while c >= 1 and c <= board.cols
      and r >= 1 and r <= board.rows
      and board.cells[r][c] == player do
        table.insert(line, { col = c, row = r })
        c = c + dc
        r = r + dr
    end

    return line
end

-- Landefelder, in denen player mit dem nächsten Stein sofort gewinnt.
function Logic:GetImmediateWinSlots(board, player)
    local slots = {}
    local cols = self:GetAvailableColumns(board)
    for i = 1, #cols do
        local col = cols[i]
        local clone = self:CloneBoard(board)
        local row = self:ApplyMove(clone, col, player)
        if row then
            local result = self:CheckWin(clone, col, row, player)
            if result == "WIN" then
                slots[#slots + 1] = { col = col, row = row }
            end
        end
    end
    return slots
end

function Logic:HasFork(board, player)
    return #self:GetImmediateWinSlots(board, player) >= 2
end

function Logic:CheckWin(board, col, row, player)
    -- Vier Richtungspaare (jede Achse einmal)
    local directions = {
        { 1,  0 },  -- horizontal →
        { 0,  1 },  -- vertikal ↓
        { 1,  1 },  -- diagonal ↘
        { 1, -1 },  -- diagonal ↗
    }

    for _, dir in ipairs(directions) do
        local dc = dir[1]
        local dr = dir[2]

        -- Zähle in beide Richtungen auf dieser Achse
        local count = 1
            + countDir(board, col, row,  dc,  dr, player)
            + countDir(board, col, row, -dc, -dr, player)

        if count >= board.winLength then
            return "WIN", self:GetWinningLine(board, col, row, dc, dr, player)
        end
    end

    return nil
end

function Logic:CheckAnyWin(board, player)
    for row = 1, board.rows do
        for col = 1, board.cols do
            if board.cells[row][col] == player then
                local result, line = self:CheckWin(board, col, row, player)
                if result == "WIN" then
                    return "WIN", line
                end
            end
        end
    end
    return nil
end

function Logic:GetImmediatePopSlots(board, player)
    local slots = {}
    local cols = self:GetPopColumns(board, player)
    for i = 1, #cols do
        local col = cols[i]
        local clone = self:CloneBoard(board)
        if self:ApplyPopOut(clone, col, player) then
            local result = self:CheckAnyWin(clone, player)
            if result == "WIN" then
                slots[#slots + 1] = { col = col, row = board.rows }
            end
        end
    end
    return slots
end

-- ============================================================
-- CloneBoard (Deep Copy)
-- ============================================================

function Logic:CloneBoard(board)
    local clone = {
        cols      = board.cols,
        rows      = board.rows,
        winLength = board.winLength,
        cells     = {},
    }

    for row = 1, board.rows do
        clone.cells[row] = {}
        for col = 1, board.cols do
            clone.cells[row][col] = board.cells[row][col]
        end
    end

    return clone
end

-- ============================================================
-- Match (öffentliches 7×6). KI bleibt im Spiele-Tab.
-- Intent MOVE: i = Spalte 1–7. Stein fällt per Schwerkraft.
-- ============================================================

Logic.GAME_ID = "ARCADIAROWS"
Logic.GAME_PROTO = 1
Logic.MP_COLS = 7
Logic.MP_ROWS = 6

local function CellCount(cols, rows)
    return cols * rows
end

function Logic.PackCells(board)
    local t = {}
    for row = 1, board.rows do
        for col = 1, board.cols do
            t[#t + 1] = tostring(board.cells[row][col] or 0)
        end
    end
    return table.concat(t)
end

function Logic.EmptyPublic()
    local cols, rows = Logic.MP_COLS, Logic.MP_ROWS
    return {
        cols = cols,
        rows = rows,
        winLength = 4,
        turn = 1,
        over = false,
        winner = 0,
        cells = string.rep("0", CellCount(cols, rows)),
        line = nil,
        lc = 0,
        lr = 0,
    }
end

function Logic.BoardFromPublic(pub)
    local cols = (pub and tonumber(pub.cols)) or Logic.MP_COLS
    local rows = (pub and tonumber(pub.rows)) or Logic.MP_ROWS
    local board = Logic:CreateBoard(cols, rows)
    local cells = (pub and pub.cells) or ""
    local n = CellCount(cols, rows)
    if #cells < n then
        cells = cells .. string.rep("0", n - #cells)
    end
    local i = 1
    for row = 1, rows do
        for col = 1, cols do
            board.cells[row][col] = tonumber(cells:sub(i, i)) or 0
            i = i + 1
        end
    end
    return board
end

function Logic.PackLine(line)
    if type(line) ~= "table" then return "" end
    local parts = {}
    for i = 1, #line do
        local p = line[i]
        if p and p.col and p.row then
            parts[#parts + 1] = tostring(p.col) .. "." .. tostring(p.row)
        end
    end
    return table.concat(parts, ",")
end

function Logic.UnpackLine(s)
    if type(s) ~= "string" or s == "" then return nil end
    local line = {}
    for token in string.gmatch(s, "[^,]+") do
        local col, row = token:match("^(%d+)%.(%d+)$")
        if col then
            line[#line + 1] = { col = tonumber(col), row = tonumber(row) }
        end
    end
    return #line > 0 and line or nil
end

function Logic.ApplyMatch(pub, intent, seat)
    if not pub or pub.over then return false end
    seat = tonumber(seat) or 0
    if seat ~= 1 and seat ~= 2 then return false end
    if seat ~= (tonumber(pub.turn) or 1) then return false end
    local col = tonumber(intent and intent.i)
    local cols = tonumber(pub.cols) or Logic.MP_COLS
    if not col or col < 1 or col > cols then return false end
    local board = Logic.BoardFromPublic(pub)
    local row = Logic:ApplyMove(board, col, seat)
    if not row then return false end
    pub.cells = Logic.PackCells(board)
    pub.lc = col
    pub.lr = row
    local result, line = Logic:CheckWin(board, col, row, seat)
    if result == "WIN" then
        pub.over = true
        pub.winner = seat
        pub.line = line
    elseif Logic:IsBoardFull(board) then
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
        co = pub.cols,
        ro = pub.rows,
        t = pub.turn,
        o = pub.over and 1 or 0,
        w = pub.winner or 0,
        c = pub.cells,
        ln = Logic.PackLine(pub.line),
        lc = pub.lc or 0,
        lr = pub.lr or 0,
    }
end

function Logic.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.co ~= nil then pub.cols = tonumber(f.co) or pub.cols end
    if f.ro ~= nil then pub.rows = tonumber(f.ro) or pub.rows end
    if f.t ~= nil then pub.turn = tonumber(f.t) or pub.turn end
    if f.o ~= nil then pub.over = tonumber(f.o) == 1 end
    if f.w ~= nil then pub.winner = tonumber(f.w) or 0 end
    if f.c ~= nil and f.c ~= "" then pub.cells = f.c end
    if f.ln ~= nil then pub.line = Logic.UnpackLine(f.ln) end
    if f.lc ~= nil then pub.lc = tonumber(f.lc) or 0 end
    if f.lr ~= nil then pub.lr = tonumber(f.lr) or 0 end
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
    local lc, lr = tonumber(pub.lc) or 0, tonumber(pub.lr) or 0
    if lc > 0 and lr > 0 then
        lastMove = { col = lc, row = lr }
    end
    return {
        cols = tonumber(pub.cols) or Logic.MP_COLS,
        rows = tonumber(pub.rows) or Logic.MP_ROWS,
        winLength = 4,
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
