-- ============================================================
--  SlidingPuzzle – Logic.lua
--  Board-State, Shuffle, Zug-Validierung, Gewinn-Check.
--
--  board[i] = tileID an Position i (0 = leeres Feld)
--  Zielzustand: board[i] == i für i=1..n-1, board[n] == 0
--  Positionen sind 1-basiert, von links-oben nach rechts-unten.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SLP_Logic = {}
local L = ArcadiaNexus.SLP_Logic
L.SIZES={easy=3,medium=4,hard=5}
function L:Int(n,max) return type(n)=="number" and n==n and n>=0 and n<math.huge and n%1==0 and (not max or n<=max) end
function L:Copy(t)
    if type(t)~="table" then return t end
    local r={}; for k,v in pairs(t) do r[k]=self:Copy(v) end; return r
end
function L:ValidBoard(board,cols,empty)
    if not self:Int(cols,5) or cols<3 or type(board)~="table" or #board~=cols*cols or not self:Int(empty,#board) or empty<1 then return false end
    local seen={}; local count=0
    for k,v in pairs(board) do
        if not self:Int(k,#board) or k<1 or not self:Int(v,#board-1) or seen[v] then return false end
        seen[v]=true; count=count+1
    end
    if count~=#board or board[empty]~=0 then return false end
    local inversions=0
    for i=1,#board do if board[i]~=0 then for j=i+1,#board do if board[j]~=0 and board[i]>board[j] then inversions=inversions+1 end end end end
    return cols%2==1 and inversions%2==0 or cols%2==0 and (inversions+cols-math.floor((empty-1)/cols))%2==1
end
function L:PuzzleId(p) return "moa:2:"..p.cols..":"..p.imageIndex..":"..table.concat(p.initialBoard,",") end
function L:Model(board,cols,empty,moves)
    return setmetatable({board=self:Copy(board),cols=cols,emptyPos=empty,moves=moves or 0},{__index=self})
end
function L:GoalBoard(cols)
    local board={}; for i=1,cols*cols do board[i]=i==cols*cols and 0 or i end; return board
end
function L:ValidPuzzle(p)
    if type(p)~="table" or p.puzzleVersion~=1 or p.ruleVersion~=2 or p.generatorVersion~=2
        or self.SIZES[p.difficulty]~=p.cols or not self:Int(p.imageIndex,19) or p.imageIndex<1
        or not self:ValidBoard(p.initialBoard,p.cols,p.initialEmpty) or p.puzzleId~=self:PuzzleId(p)
        or type(p.history)~="table" or #p.history<1 or #p.history>128 then return false end
    local model=self:Model(p.initialBoard,p.cols,p.initialEmpty)
    if model:IsSolved() then return false end
    local entries=0; for k in pairs(p.history) do if not self:Int(k,#p.history) or k<1 then return false end; entries=entries+1 end
    if entries~=#p.history then return false end
    for i=#p.history,1,-1 do
        local m=p.history[i]
        if type(m)~="table" or m.tilePos~=model.emptyPos or not model:ExecuteMove(m.emptyPos) then return false end
    end
    return model:IsSolved()
end

-- Legal random walks with replay witnesses; no runtime minimum solver.
-- Fixed fallback walks are forward/reverse checked by the M7 suite.
L.FALLBACK={
 [3]={board={3,1,6,2,0,4,7,5,8},empty=5,history={{tilePos=6,emptyPos=9},{tilePos=5,emptyPos=6},{tilePos=8,emptyPos=5},{tilePos=9,emptyPos=8},{tilePos=6,emptyPos=9},{tilePos=5,emptyPos=6},{tilePos=8,emptyPos=5},{tilePos=9,emptyPos=8},{tilePos=6,emptyPos=9},{tilePos=5,emptyPos=6},{tilePos=4,emptyPos=5},{tilePos=1,emptyPos=4},{tilePos=2,emptyPos=1},{tilePos=3,emptyPos=2},{tilePos=6,emptyPos=3},{tilePos=5,emptyPos=6},{tilePos=4,emptyPos=5},{tilePos=1,emptyPos=4},{tilePos=2,emptyPos=1},{tilePos=5,emptyPos=2}}},
 [4]={board={4,9,7,8,10,2,1,12,0,6,5,15,13,14,3,11},empty=9,history={{tilePos=12,emptyPos=16},{tilePos=8,emptyPos=12},{tilePos=7,emptyPos=8},{tilePos=3,emptyPos=7},{tilePos=2,emptyPos=3},{tilePos=6,emptyPos=2},{tilePos=5,emptyPos=6},{tilePos=1,emptyPos=5},{tilePos=2,emptyPos=1},{tilePos=3,emptyPos=2},{tilePos=4,emptyPos=3},{tilePos=8,emptyPos=4},{tilePos=12,emptyPos=8},{tilePos=16,emptyPos=12},{tilePos=15,emptyPos=16},{tilePos=11,emptyPos=15},{tilePos=7,emptyPos=11},{tilePos=6,emptyPos=7},{tilePos=5,emptyPos=6},{tilePos=1,emptyPos=5},{tilePos=2,emptyPos=1},{tilePos=3,emptyPos=2},{tilePos=4,emptyPos=3},{tilePos=8,emptyPos=4},{tilePos=12,emptyPos=8},{tilePos=11,emptyPos=12},{tilePos=7,emptyPos=11},{tilePos=6,emptyPos=7},{tilePos=5,emptyPos=6},{tilePos=9,emptyPos=5},{tilePos=10,emptyPos=9},{tilePos=6,emptyPos=10},{tilePos=2,emptyPos=6},{tilePos=1,emptyPos=2},{tilePos=5,emptyPos=1},{tilePos=6,emptyPos=5},{tilePos=2,emptyPos=6},{tilePos=3,emptyPos=2},{tilePos=7,emptyPos=3},{tilePos=11,emptyPos=7},{tilePos=12,emptyPos=11},{tilePos=16,emptyPos=12},{tilePos=15,emptyPos=16},{tilePos=11,emptyPos=15},{tilePos=7,emptyPos=11},{tilePos=3,emptyPos=7},{tilePos=2,emptyPos=3},{tilePos=1,emptyPos=2},{tilePos=5,emptyPos=1},{tilePos=9,emptyPos=5}}},
 [5]={board={6,7,2,18,8,13,3,1,0,9,16,21,14,10,4,19,22,12,15,5,11,23,17,24,20},empty=9,history={{tilePos=20,emptyPos=25},{tilePos=15,emptyPos=20},{tilePos=10,emptyPos=15},{tilePos=5,emptyPos=10},{tilePos=4,emptyPos=5},{tilePos=9,emptyPos=4},{tilePos=8,emptyPos=9},{tilePos=3,emptyPos=8},{tilePos=2,emptyPos=3},{tilePos=1,emptyPos=2},{tilePos=6,emptyPos=1},{tilePos=11,emptyPos=6},{tilePos=12,emptyPos=11},{tilePos=13,emptyPos=12},{tilePos=14,emptyPos=13},{tilePos=15,emptyPos=14},{tilePos=10,emptyPos=15},{tilePos=5,emptyPos=10},{tilePos=4,emptyPos=5},{tilePos=3,emptyPos=4},{tilePos=2,emptyPos=3},{tilePos=7,emptyPos=2},{tilePos=12,emptyPos=7},{tilePos=11,emptyPos=12},{tilePos=6,emptyPos=11},{tilePos=1,emptyPos=6},{tilePos=2,emptyPos=1},{tilePos=7,emptyPos=2},{tilePos=6,emptyPos=7},{tilePos=1,emptyPos=6},{tilePos=2,emptyPos=1},{tilePos=7,emptyPos=2},{tilePos=8,emptyPos=7},{tilePos=13,emptyPos=8},{tilePos=18,emptyPos=13},{tilePos=19,emptyPos=18},{tilePos=14,emptyPos=19},{tilePos=13,emptyPos=14},{tilePos=12,emptyPos=13},{tilePos=11,emptyPos=12},{tilePos=16,emptyPos=11},{tilePos=21,emptyPos=16},{tilePos=22,emptyPos=21},{tilePos=23,emptyPos=22},{tilePos=18,emptyPos=23},{tilePos=17,emptyPos=18},{tilePos=16,emptyPos=17},{tilePos=21,emptyPos=16},{tilePos=22,emptyPos=21},{tilePos=23,emptyPos=22},{tilePos=18,emptyPos=23},{tilePos=13,emptyPos=18},{tilePos=8,emptyPos=13},{tilePos=7,emptyPos=8},{tilePos=2,emptyPos=7},{tilePos=1,emptyPos=2},{tilePos=6,emptyPos=1},{tilePos=11,emptyPos=6},{tilePos=16,emptyPos=11},{tilePos=17,emptyPos=16},{tilePos=12,emptyPos=17},{tilePos=11,emptyPos=12},{tilePos=16,emptyPos=11},{tilePos=21,emptyPos=16},{tilePos=22,emptyPos=21},{tilePos=17,emptyPos=22},{tilePos=12,emptyPos=17},{tilePos=13,emptyPos=12},{tilePos=8,emptyPos=13},{tilePos=3,emptyPos=8},{tilePos=4,emptyPos=3},{tilePos=9,emptyPos=4},{tilePos=14,emptyPos=9},{tilePos=19,emptyPos=14},{tilePos=20,emptyPos=19},{tilePos=15,emptyPos=20},{tilePos=10,emptyPos=15},{tilePos=5,emptyPos=10},{tilePos=4,emptyPos=5},{tilePos=3,emptyPos=4},{tilePos=8,emptyPos=3},{tilePos=13,emptyPos=8},{tilePos=12,emptyPos=13},{tilePos=17,emptyPos=12},{tilePos=16,emptyPos=17},{tilePos=21,emptyPos=16},{tilePos=22,emptyPos=21},{tilePos=17,emptyPos=22},{tilePos=12,emptyPos=17},{tilePos=11,emptyPos=12},{tilePos=6,emptyPos=11},{tilePos=7,emptyPos=6},{tilePos=2,emptyPos=7},{tilePos=1,emptyPos=2},{tilePos=6,emptyPos=1},{tilePos=7,emptyPos=6},{tilePos=8,emptyPos=7},{tilePos=3,emptyPos=8},{tilePos=4,emptyPos=3},{tilePos=9,emptyPos=4}}},
}
L.BUDGET={stepEdges=16,stepMs=1.5,edges=2000,cpuMs=100,waitMs=1000}
function L:Generate(diff,img,clock)
    if not self.SIZES[diff] or not self:Int(img,19) or img<1 then return nil end
    local budget=self.BUDGET; local steps=({easy=20,medium=50,hard=100})[diff]
    local job={status="running",edges=0,cpu=0,attempts=0,started=clock(),samples={}}
    local function init()
        job.model=L:Model({},L.SIZES[diff],1); job.model:Init(L.SIZES[diff]); job.history={}; job.last=-1; job.attempts=job.attempts+1
    end
    init()
    function job:Cancel() self.status="unknown"; self.model=nil; self.history=nil; self.check=nil end
    function job:Step()
        if self.status~="running" then return self.status end
        local start=clock(); local work=0
        if self.check then
            while self.checkIndex>0 and work<budget.stepEdges and clock()-start<budget.stepMs do
                local m=self.puzzle.history[self.checkIndex]
                if m.tilePos~=self.check.emptyPos or not self.check:ExecuteMove(m.emptyPos) then self:Cancel(); return self.status end
                self.checkIndex=self.checkIndex-1; work=work+1; self.edges=self.edges+1
            end
            if self.checkIndex==0 then self.status=self.check:IsSolved() and "solved" or "unknown"; self.check=nil end
        elseif self.cpu>=budget.cpuMs or self.edges>=budget.edges or clock()-self.started>=budget.waitMs or self.attempts>8 then
            local known=L.FALLBACK[L.SIZES[diff]]
            self.model=L:Model(known.board,L.SIZES[diff],known.empty); self.history=L:Copy(known.history); self.fallback=true
        else
            while #self.history<steps and work<budget.stepEdges and clock()-start<budget.stepMs do
                local neighbors=self.model:GetValidMoves(); local choices={}
                for _,pos in ipairs(neighbors) do if pos~=self.last then choices[#choices+1]=pos end end
                local pick=choices[math.random(1,#choices)]; local empty=self.model.emptyPos
                self.last=empty; self.model:ExecuteMove(pick)
                self.history[#self.history+1]={tilePos=pick,emptyPos=empty}; work=work+1; self.edges=self.edges+1
            end
        end
        if self.history and (self.fallback or #self.history==steps) then
            if self.model:IsSolved() then init()
            else
                local p={puzzleVersion=1,ruleVersion=2,generatorVersion=2,difficulty=diff,cols=self.model.cols,imageIndex=img,
                    initialBoard=L:Copy(self.model.board),initialEmpty=self.model.emptyPos,history=L:Copy(self.history)}
                p.puzzleId=L:PuzzleId(p); self.puzzle=p
                self.check=L:Model(p.initialBoard,p.cols,p.initialEmpty); self.checkIndex=#p.history
                self.model=nil; self.history=nil
            end
        end
        local elapsed=clock()-start; self.cpu=self.cpu+elapsed; self.samples[#self.samples+1]=elapsed
        return self.status
    end
    return job
end

-- ── State ─────────────────────────────────────────────────────
L.board    = {}
L.emptyPos = 0
L.cols     = 3
L.moves    = 0
L.solved   = false

-- ── Hilfsfunktionen ───────────────────────────────────────────

-- Gibt Zeile und Spalte (1-basiert) einer Position zurück
local function RowCol(pos, cols)
    local row = math.ceil(pos / cols)
    local col = ((pos - 1) % cols) + 1
    return row, col
end

-- ── Board initialisieren ──────────────────────────────────────

function L:Init(cols)
    if cols~=3 and cols~=4 and cols~=5 then return false end
    self.cols   = cols
    self.moves  = 0
    self.solved = false
    local n = cols * cols
    self.board = {}
    for i = 1, n - 1 do
        self.board[i] = i
    end
    self.board[n] = 0
    self.emptyPos = n
end

-- ── Shuffle (N gültige Züge vom Zielzustand rückwärts) ───────

function L:Shuffle(numMoves)
    -- Verhindert Hin-und-Her-Ping-Pong: letzten Zug merken
    local lastMoved = -1
    for _ = 1, numMoves do
        local neighbors = self:GetValidMoves()
        -- Ping-Pong-Schutz: Letzte Position herausfiltern
        local filtered = {}
        for _, pos in ipairs(neighbors) do
            if pos ~= lastMoved then
                filtered[#filtered + 1] = pos
            end
        end
        if #filtered == 0 then filtered = neighbors end
        local pick = filtered[math.random(1, #filtered)]
        lastMoved = self.emptyPos
        self:ExecuteMove(pick)
    end
    self.moves = 0   -- Züge nach Shuffle zurücksetzen
end

-- ── Shuffle mit Zugliste (für Shuffle-Animation) ──────────────
-- Führt numMoves gültige Züge durch und gibt eine Liste von
-- { tilePos, emptyPos } zurück — tilePos = gezogene Kachel,
-- emptyPos = Position des leeren Feldes VOR dem Zug (= Ziel).
-- Das Board wird dabei in-place verändert (identisch zu Shuffle).
-- Aufruf: nach Init(), vor BuildGrid().

function L:ShuffleWithHistory(numMoves)
    local history   = {}
    local lastMoved = -1
    for _ = 1, numMoves do
        local neighbors = self:GetValidMoves()
        local filtered  = {}
        for _, pos in ipairs(neighbors) do
            if pos ~= lastMoved then
                filtered[#filtered + 1] = pos
            end
        end
        if #filtered == 0 then filtered = neighbors end
        local pick     = filtered[math.random(1, #filtered)]
        local fromEmpty = self.emptyPos   -- leeres Feld VOR Zug = Ziel der Kachel
        lastMoved      = self.emptyPos
        self:ExecuteMove(pick)
        history[#history + 1] = { tilePos = pick, emptyPos = fromEmpty }
    end
    self.moves = 0
    return history
end

-- ── Gültige Züge (Positionen die ans leere Feld angrenzen) ───

function L:GetValidMoves()
    local eRow, eCol = RowCol(self.emptyPos, self.cols)
    local result = {}
    local deltas = { {0,1}, {0,-1}, {1,0}, {-1,0} }
    for _, d in ipairs(deltas) do
        local nr = eRow + d[1]
        local nc = eCol + d[2]
        if nr >= 1 and nr <= self.cols and nc >= 1 and nc <= self.cols then
            result[#result + 1] = (nr - 1) * self.cols + nc
        end
    end
    return result
end

-- ── Zug-Validierung ───────────────────────────────────────────

function L:CanMove(tilePos)
    if not self:Int(tilePos,self.cols*self.cols) or tilePos<1 or not self.board[tilePos] or self.board[tilePos]==0 then return false end
    local eRow, eCol = RowCol(self.emptyPos, self.cols)
    local tRow, tCol = RowCol(tilePos,       self.cols)
    return (eRow == tRow and math.abs(eCol - tCol) == 1)
        or (eCol == tCol and math.abs(eRow - tRow) == 1)
end

-- ── Zug ausführen ─────────────────────────────────────────────

function L:ExecuteMove(tilePos)
    if not self:CanMove(tilePos) then return false end
    self.board[self.emptyPos] = self.board[tilePos]
    self.board[tilePos]       = 0
    self.emptyPos             = tilePos
    self.moves                = self.moves + 1
    return true
end

-- ── Gewinn-Check ──────────────────────────────────────────────

function L:IsSolved()
    local n = self.cols * self.cols
    for i = 1, n do
        local expected = (i == n) and 0 or i
        if self.board[i] ~= expected then return false end
    end
    return true
end

-- ── UV-Koordinaten für eine Kachel ───────────────────────────
-- tileID: 1-basiert, von links-oben nach rechts-unten.
-- SetTexCoord(left, right, top, bottom) — WoW 4-Parameter-Form

function L:GetTexCoord(tileID, cols)
    local col = (tileID - 1) % cols
    local row = math.floor((tileID - 1) / cols)
    local l = col / cols
    local r = (col + 1) / cols
    local t = row / cols
    local b = (row + 1) / cols
    return l, r, t, b
end
