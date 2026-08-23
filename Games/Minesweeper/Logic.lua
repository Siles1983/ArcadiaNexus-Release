--[[
    Gaming Hub
    Games/Minesweeper/Logic.lua
    Version: 1.0.0

    Goblin-Edition Minesweeper

    Board-Struktur:
      cells[r][c] = {
        isMine    – bool
        revealed  – bool
        flagged   – bool
        neighbors – 0-8 (Anzahl Minen in den 8 Nachbarfeldern)
      }

    Koordinaten: r=1 oben, r=size unten; c=1 links, c=size rechts

    Schwierigkeitsgrade:
      easy   – 9×9,  10 Minen
      normal – 12×12, 20 Minen
      hard   – 16×16, 40 Minen

    Öffentliche API:
      Logic:NewBoard(difficulty)       → { cells, size, mineCount, ... }
      Logic:RevealCell(board, r, c)    → "mine" | "empty" | "number" | "already_revealed" | "flagged"
      Logic:ToggleFlag(board, r, c)    → "flagged" | "unflagged" | "already_revealed"
      Logic:CheckWin(board)            → bool
      Logic:RevealAllMines(board)      → liste aller Minen-Positionen
      Logic:GetNeighborCount(board, r, c) → 0-8
      Logic:GetBoardState(board)       → snapshot für Renderer
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MS_Logic = {}
local Logic = ArcadiaNexus.MS_Logic

-- ============================================================
-- Schwierigkeitsgrade
-- ============================================================
local CONFIGS = {
    easy   = { size = 9,  mines = 10 },
    normal = { size = 12, mines = 20 },
    hard   = { size = 16, mines = 40 },
}

-- ============================================================
-- Nachbarn iterieren
-- ============================================================
local DIRS = {
    {-1,-1},{-1,0},{-1,1},
    { 0,-1},       { 0,1},
    { 1,-1},{ 1,0},{ 1,1},
}

local function eachNeighbor(size, r, c, fn)
    for _, d in ipairs(DIRS) do
        local nr, nc = r + d[1], c + d[2]
        if nr >= 1 and nr <= size and nc >= 1 and nc <= size then
            fn(nr, nc)
        end
    end
end

-- ============================================================
-- NewBoard
-- ============================================================
function Logic:NewBoard(difficulty)
    difficulty = difficulty or "easy"
    local cfg  = CONFIGS[difficulty] or CONFIGS.easy
    local size = cfg.size

    -- Leere Zellen erstellen
    local cells = {}
    for r = 1, size do
        cells[r] = {}
        for c = 1, size do
            cells[r][c] = {
                isMine   = false,
                revealed = false,
                flagged  = false,
                neighbors= 0,
            }
        end
    end

    -- Minen zufällig platzieren
    local placed = 0
    while placed < cfg.mines do
        local r = math.random(1, size)
        local c = math.random(1, size)
        if not cells[r][c].isMine then
            cells[r][c].isMine = true
            placed = placed + 1
        end
    end

    -- Nachbar-Zählungen berechnen
    for r = 1, size do
        for c = 1, size do
            if not cells[r][c].isMine then
                local count = 0
                eachNeighbor(size, r, c, function(nr, nc)
                    if cells[nr][nc].isMine then count = count + 1 end
                end)
                cells[r][c].neighbors = count
            end
        end
    end

    return {
        cells       = cells,
        size        = size,
        mineCount   = cfg.mines,
        flagCount   = 0,
        revealCount = 0,
        phase       = "PLAYING",   -- "PLAYING" | "WON" | "LOST"
        difficulty  = difficulty,
        minePositions = nil,       -- gefüllt bei Verlust
    }
end

-- ============================================================
-- RevealCell – Linksklick
-- Flood-Fill für leere Felder (neighbors == 0)
-- ============================================================
function Logic:RevealCell(board, r, c)
    local cell = board.cells[r][c]
    if not cell then return "invalid" end
    if cell.revealed then return "already_revealed" end
    if cell.flagged  then return "flagged" end

    if cell.isMine then
        cell.revealed = true
        board.phase   = "LOST"
        -- Alle Minen aufdecken
        board.minePositions = self:RevealAllMines(board)
        return "mine"
    end

    -- Flood-Fill via Stack (keine Rekursion – vermeidet WoW-Stack-Limit)
    local stack = { {r, c} }
    local visited = {}

    while #stack > 0 do
        local pos  = table.remove(stack)
        local pr, pc = pos[1], pos[2]
        local key  = pr .. "_" .. pc

        if not visited[key] then
            visited[key] = true
            local pcell  = board.cells[pr][pc]

            if not pcell.revealed and not pcell.flagged and not pcell.isMine then
                pcell.revealed   = true
                board.revealCount= board.revealCount + 1

                -- Wenn leer: Nachbarn ebenfalls aufdecken
                if pcell.neighbors == 0 then
                    eachNeighbor(board.size, pr, pc, function(nr, nc)
                        local nkey = nr .. "_" .. nc
                        if not visited[nkey] and not board.cells[nr][nc].revealed then
                            stack[#stack+1] = { nr, nc }
                        end
                    end)
                end
            end
        end
    end

    -- Sieg prüfen
    if self:CheckWin(board) then
        board.phase = "WON"
        return "won"
    end

    -- Rückgabe basierend auf Ausgangsfeld
    local origCell = board.cells[r][c]
    return origCell.neighbors > 0 and "number" or "empty"
end

-- ============================================================
-- ToggleFlag – Rechtsklick
-- ============================================================
function Logic:ToggleFlag(board, r, c)
    local cell = board.cells[r][c]
    if not cell then return "invalid" end
    if cell.revealed then return "already_revealed" end

    if cell.flagged then
        cell.flagged    = false
        board.flagCount = board.flagCount - 1
        return "unflagged"
    else
        cell.flagged    = true
        board.flagCount = board.flagCount + 1
        return "flagged"
    end
end

-- ============================================================
-- CheckWin
-- Alle Nicht-Minen-Felder aufgedeckt
-- ============================================================
function Logic:CheckWin(board)
    local size  = board.size
    local total = size * size
    return board.revealCount == (total - board.mineCount)
end

-- ============================================================
-- RevealAllMines – bei Verlust
-- ============================================================
function Logic:RevealAllMines(board)
    local positions = {}
    for r = 1, board.size do
        for c = 1, board.size do
            if board.cells[r][c].isMine then
                board.cells[r][c].revealed = true
                positions[#positions+1] = { r = r, c = c }
            end
        end
    end
    return positions
end

-- ============================================================
-- GetBoardState – Snapshot für Engine/Renderer
-- ============================================================
function Logic:GetBoardState(board)
    return {
        cells         = board.cells,
        size          = board.size,
        mineCount     = board.mineCount,
        flagCount     = board.flagCount,
        revealCount   = board.revealCount,
        phase         = board.phase,
        difficulty    = board.difficulty,
        minePositions = board.minePositions,
        remaining     = board.mineCount - board.flagCount,
    }
end
