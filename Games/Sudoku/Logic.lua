--[[
    Gaming Hub
    Games/Sudoku/Logic.lua
    Version: 1.0.0

    Reine Spiellogik – kein UI, keine Events.

    Grid-Konvention:
      grid[r][c]  – Zahl 1-9, oder 0 = leer
      fixed[r][c] – true = vom System vorgegeben (nicht änderbar)
      errors[r][c]– true = Spieler-Eintrag ist ungültig

    Technikstufen: Singles / zusätzlich gebundene Kandidaten / zusätzlich nackte Paare.

    Öffentliche API:
      Logic:NewGrid()                        → leeres 9×9-Grid
      Logic:GeneratePuzzle(difficulty)       → { grid, fixed, solution }
      Logic:IsValidMove(grid, r, c, num)     → bool, reason
      Logic:IsBoardComplete(grid, fixed)     → bool
      Logic:GetHighlightCells(grid, num)     → { {r,c}, ... }
      Logic:GetBoxIndex(r, c)                → 1-9 (welcher 3×3 Block)
      Logic:ValidateAll(grid, fixed)         → errors[r][c] table
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Logic = {}
local Logic = ArcadiaNexus.SDK_Logic

-- ============================================================
-- Clue-Anzahl nach Schwierigkeit
-- ============================================================

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function newGrid()
    local g = {}
    for r = 1, 9 do
        g[r] = {}
        for c = 1, 9 do g[r][c] = 0 end
    end
    return g
end

local function copyGrid(g)
    local n = {}
    for r = 1, 9 do
        n[r] = {}
        for c = 1, 9 do n[r][c] = g[r][c] end
    end
    return n
end

-- Runtime selects a verified template; no backtracking at game start.
function Logic:GeneratePuzzle(difficulty,index)
    local entry=ArcadiaNexus.LevelPool.GetEntry(ArcadiaNexus.SDK_Pools,difficulty,index)
    if not entry then return nil end
    local digits={1,2,3,4,5,6,7,8,9}
    ArcadiaNexus.ArrayUtils.Shuffle(digits)
    local grid,fixed,solution=newGrid(),{},newGrid()
    for r=1,9 do fixed[r]={}; for c=1,9 do
        local i=(r-1)*9+c
        local clue=tonumber(entry.grid:sub(i,i))
        solution[r][c]=digits[tonumber(entry.solution:sub(i,i))]
        grid[r][c]=clue==0 and 0 or digits[clue]
        fixed[r][c]=clue~=0
    end end
    return {grid=grid,fixed=fixed,solution=solution,puzzleId=entry.id,puzzleVersion=entry.version}
end

-- ============================================================
-- NewGrid – leeres 9×9-Grid
-- ============================================================

function Logic:NewGrid()
    return newGrid()
end

-- ============================================================
-- GetBoxIndex – welcher 3×3-Block (1-9, zeilenweise)
-- ============================================================

function Logic:GetBoxIndex(r, c)
    local br = math.floor((r-1)/3)
    local bc = math.floor((c-1)/3)
    return br * 3 + bc + 1
end

-- ============================================================
-- IsValidMove
-- Prüft ob `num` an (r,c) regelkonform ist.
-- Gibt zurück: valid(bool), reason(string)
-- ============================================================

function Logic:IsValidMove(grid, r, c, num)
    if num == 0 then return true, "empty" end

    -- Zeile
    for cc = 1, 9 do
        if cc ~= c and grid[r][cc] == num then
            return false, "row"
        end
    end
    -- Spalte
    for rr = 1, 9 do
        if rr ~= r and grid[rr][c] == num then
            return false, "col"
        end
    end
    -- 3×3 Block
    local br = math.floor((r-1)/3)*3 + 1
    local bc = math.floor((c-1)/3)*3 + 1
    for dr = 0, 2 do
        for dc = 0, 2 do
            local rr, cc = br+dr, bc+dc
            if (rr ~= r or cc ~= c) and grid[rr][cc] == num then
                return false, "box"
            end
        end
    end
    return true, "ok"
end

-- ============================================================
-- ValidateAll
-- Gibt errors[r][c] = true für alle ungültigen Spieler-Einträge
-- ============================================================

function Logic:ValidateAll(grid, fixed)
    local errors = {}
    for r = 1, 9 do
        errors[r] = {}
        for c = 1, 9 do errors[r][c] = false end
    end

    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] ~= 0 then
                local valid = self:IsValidMove(grid, r, c, grid[r][c])
                if not valid then
                    errors[r][c] = true
                end
            end
        end
    end
    return errors
end

-- ============================================================
-- IsBoardComplete
-- Alle Felder gefüllt und keine Fehler
-- ============================================================

function Logic:IsBoardComplete(grid, fixed)
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == 0 then return false end
            if grid[r][c] ~= 0 then
                local valid = self:IsValidMove(grid, r, c, grid[r][c])
                if not valid then return false end
            end
        end
    end
    return true
end

-- ============================================================
-- GetHighlightCells
-- Gibt alle Zellen zurück die dieselbe Zahl `num` haben
-- ============================================================

function Logic:GetHighlightCells(grid, num)
    local cells = {}
    if num == 0 then return cells end
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == num then
                cells[#cells+1] = { r = r, c = c }
            end
        end
    end
    return cells
end

-- ============================================================
-- GetCandidates
-- Gibt alle gültigen Zahlen für eine Zelle zurück (für Hint)
-- ============================================================

function Logic:GetCandidates(grid, r, c)
    if grid[r][c] ~= 0 then return {} end
    local cands = {}
    for n = 1, 9 do
        if self:IsValidMove(grid, r, c, n) then
            cands[#cands+1] = n
        end
    end
    return cands
end
function Logic:GetScore(difficulty) return ({easy=50,normal=100,hard=200})[difficulty] end

function Logic:IsCell(r,c)
    return type(r)=="number" and r==math.floor(r) and r>=1 and r<=9
        and type(c)=="number" and c==math.floor(c) and c>=1 and c<=9
end
function Logic:IsDigit(n) return type(n)=="number" and n==math.floor(n) and n>=1 and n<=9 end
local function integer(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
local function validNotes(notes,value)
    if type(notes)~="table" then return false end
    for n,v in pairs(notes) do if not Logic:IsDigit(n) or v~=true or value~=0 then return false end end
    return true
end
function Logic:ValidateSave(s)
    if type(s)~="table" or s.version~=1 or not self:GetScore(s.difficulty)
        or type(s.runId)~="string" or type(s.puzzleId)~="string" or s.puzzleId==""
        or not integer(s.puzzleVersion) or s.puzzleVersion<1
        or (s.phase~="PLAYING" and s.phase~="COMPLETE") or not integer(s.moves)
        or not integer(s.mistakes) or s.mistakes>s.moves or type(s.notesMode)~="boolean"
        or (s.resultPending~=nil and s.resultPending~=true) or (s.phase=="PLAYING" and s.resultPending)
        or type(s.history)~="table" then return false end
    if s.selected and (type(s.selected)~="table" or not self:IsCell(s.selected.r,s.selected.c)) then return false end
    for _,key in ipairs({"grid","fixed","solution","notes"}) do
        if type(s[key])~="table" or #s[key]~=9 then return false end
        for r=1,9 do if type(s[key][r])~="table" or #s[key][r]~=9 then return false end end
    end
    local clues=0
    for r=1,9 do for c=1,9 do
        local n=s.grid[r][c]
        if not integer(n) or n>9 or type(s.fixed[r][c])~="boolean"
            or not self:IsDigit(s.solution[r][c]) or not validNotes(s.notes[r][c],n) then return false end
        if s.fixed[r][c] then
            if n~=s.solution[r][c] then return false end
            clues=clues+1
        end
    end end
    if clues<17 or not self:IsBoardComplete(s.solution,s.fixed)
        or (self:IsBoardComplete(s.grid,s.fixed)~=(s.phase=="COMPLETE")) then return false end
    for i,h in pairs(s.history) do
        if not integer(i) or i<1 or i>#s.history or type(h)~="table" or not self:IsCell(h.r,h.c)
            or s.fixed[h.r][h.c] or not integer(h.value) or h.value>9 or not validNotes(h.notes,h.value)
            or not integer(h.afterValue) or h.afterValue>9 or not validNotes(h.afterNotes,h.afterValue) then return false end
    end
    local grid,notes=copyGrid(s.grid),{}
    for r=1,9 do notes[r]={}; for c=1,9 do notes[r][c]=s.notes[r][c] end end
    for i=#s.history,1,-1 do
        local h=s.history[i]
        if grid[h.r][h.c]~=h.afterValue then return false end
        for n=1,9 do if notes[h.r][h.c][n]~=h.afterNotes[n] then return false end end
        grid[h.r][h.c],notes[h.r][h.c]=h.value,h.notes
    end
    for r=1,9 do for c=1,9 do
        if not s.fixed[r][c] and (grid[r][c]~=0 or next(notes[r][c])) then return false end
    end end
    return true
end

-- Editing rules operate only on the session data, independent of engine/UI.
local function copy(v)
    if type(v)~="table" then return v end
    local t={}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
function Logic:Refresh(board)
    board.errors=board.logic:ValidateAll(board.grid,board.fixed)
    local s=board.selected
    board.highlightNum=s and board.grid[s.r][s.c]~=0 and board.grid[s.r][s.c] or nil
end
function Logic:SelectCell(board,r,c)
    if board.phase~="PLAYING" or not board.logic:IsCell(r,c) then return false end
    board.selected={r=r,c=c}; board:Refresh()
    return not board.fixed[r][c]
end
function Logic:Remember(board,r,c)
    board.history[#board.history+1]={r=r,c=c,value=board.grid[r][c],notes=copy(board.notes[r][c])}
end
function Logic:FinishEdit(board,r,c)
    local h=board.history[#board.history]
    h.afterValue,h.afterNotes=board.grid[r][c],copy(board.notes[r][c])
end
function Logic:PlaceNumber(board,n)
    local s=board.selected
    if board.phase~="PLAYING" or not s or board.fixed[s.r][s.c] or not board.logic:IsDigit(n) then return "noop" end
    local r,c=s.r,s.c
    if board.notesMode then
        if board.grid[r][c]~=0 then return "noop" end
        board:Remember(r,c); board.notes[r][c][n]=not board.notes[r][c][n] or nil
        board:FinishEdit(r,c)
        return "note"
    end
    if board.grid[r][c]==n then return "noop" end
    board:Remember(r,c); board.grid[r][c]=n; board.notes[r][c]={}
    board:FinishEdit(r,c)
    board.moves=board.moves+1; board:Refresh()
    local valid=board.logic:IsValidMove(board.grid,r,c,n)
    if not valid then board.mistakes=board.mistakes+1 end
    if board.logic:IsBoardComplete(board.grid,board.fixed) then board.phase="COMPLETE"; return "complete" end
    return valid and "ok" or "error"
end
function Logic:ClearCell(board,r,c)
    if board.phase~="PLAYING" or not board.logic:IsCell(r,c) or board.fixed[r][c]
        or (board.grid[r][c]==0 and not next(board.notes[r][c])) then return false end
    board:Remember(r,c); board.grid[r][c]=0; board.notes[r][c]={}; board:FinishEdit(r,c); board:Refresh(); return true
end
function Logic:Undo(board)
    if board.phase~="PLAYING" or #board.history==0 then return false end
    local h=table.remove(board.history)
    board.grid[h.r][h.c],board.notes[h.r][h.c]=h.value,h.notes
    board.selected={r=h.r,c=h.c}; board:Refresh(); return true
end
