-- ============================================================
--  AlchemistsSort – Logic.lua
--  Reine Spielregeln: Zug-Validierung, Ausführung, Sieg-Prüfung,
--  Hint-Suche, DeepCopy.
--  KEINE UI, KEINE Timer, KEINE Engine-Aufrufe hier.
--
--  Datenstruktur Röhre:
--    tube[1] = oben (sichtbar / wird zuerst übertragen)
--    tube[N] = unten
--    Kapazität: 5 Schichten
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Logic = {}
local L = ArcadiaNexus.ALS_Logic

local TUBE_CAPACITY = 5

-- ── Hilfsfunktionen ───────────────────────────────────────────

-- Tiefe Kopie des gesamten Tubes-Arrays
function L:DeepCopy(tubes)
    local copy = {}
    for i, tube in ipairs(tubes) do
        copy[i] = {}
        for j, c in ipairs(tube) do
            copy[i][j] = c
        end
    end
    return copy
end

-- Oberste Farbe einer Röhre (nil wenn leer)
function L:TopColor(tube)
    return tube[1]
end

-- Anzahl aufeinanderfolgender gleicher Farben oben
function L:TopCount(tube)
    if #tube == 0 then return 0 end
    local top = tube[1]
    local count = 0
    for i = 1, #tube do
        if tube[i] == top then count = count + 1
        else break end
    end
    return count
end

-- Freie Plätze in einer Röhre
function L:FreeSlots(tube)
    return TUBE_CAPACITY - #tube
end

-- ── Zug-Validierung ───────────────────────────────────────────

-- Gibt zurück: gültig (bool), transferCount (int)
function L:IsValidMove(src, dst)
    if type(src) ~= "table" or type(dst) ~= "table" or src == dst then return false, 0 end
    -- Quell-Röhre leer?
    if #src == 0 then return false, 0 end
    -- Ziel-Röhre voll?
    if #dst >= TUBE_CAPACITY then return false, 0 end
    if #dst == 0 and #src == TUBE_CAPACITY and self:TopCount(src) == TUBE_CAPACITY then return false, 0 end

    local srcTop  = self:TopColor(src)
    local dstTop  = self:TopColor(dst)
    local free    = self:FreeSlots(dst)
    local topCnt  = self:TopCount(src)

    -- Farb-Kompatibilität prüfen
    if dstTop ~= nil and dstTop ~= srcTop then
        return false, 0
    end

    local transfer = math.min(topCnt, free)
    return true, transfer
end

-- ── Zug ausführen ─────────────────────────────────────────────

-- Führt einen validierten Zug direkt auf den Tubes aus.
-- Gibt Anzahl übertragener Schichten zurück.
function L:ExecuteMove(src, dst)
    local valid, count = self:IsValidMove(src, dst)
    if not valid or count == 0 then return 0 end

    for _ = 1, count do
        local color = table.remove(src, 1)
        table.insert(dst, 1, color)
    end
    return count
end

-- ── Sieg-Prüfung ──────────────────────────────────────────────

function L:CheckWin(tubes)
    for _, tube in ipairs(tubes) do
        if #tube > 0 then
            local top = tube[1]
            for _, color in ipairs(tube) do
                if color ~= top then return false end
            end
            if #tube ~= TUBE_CAPACITY then return false end
        end
    end
    return true
end

-- ── Hint-Suche ────────────────────────────────────────────────

-- Completion always earns one star. The generator's minMoves is only an
-- estimate, so ratings use the aid flags preserved across pause and reset.
function L:GradeCampaignStars(state)
    if not state or not state.tubes or #state.tubes == 0 or not self:CheckWin(state.tubes) then return 0 end
    if state.usedAddTube then return 1 end
    if state.usedHint or state.usedUndo then return 2 end
    return 3
end

-- Every caller, including search, uses the same indexed player move predicate.
function L:CanMove(tubes, i, j)
    if type(i) ~= "number" or type(j) ~= "number" or i % 1 ~= 0 or j % 1 ~= 0 or i == j then return false, 0 end
    return self:IsValidMove(tubes and tubes[i], tubes and tubes[j])
end

function L:HasAnyMove(tubes)
    for i = 1, #tubes do for j = 1, #tubes do
        if self:CanMove(tubes, i, j) then return true end
    end end
    return false
end

function L:BoardKey(tubes, symmetric)
    local out = {}
    for i,t in ipairs(tubes) do
        local row = {}
        for j,c in ipairs(t) do row[j] = tostring(#tostring(c)) .. ":" .. tostring(c) end
        out[i] = table.concat(row, ",")
    end
    if symmetric then table.sort(out) end
    return table.concat(out, "|")
end

function L:PuzzleId(tubes) return "als:2:" .. self:BoardKey(tubes) end
function L:Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k,v in pairs(value) do out[k] = self:Copy(v) end
    return out
end
function L:Int(n, max)
    return type(n)=="number" and n==n and n>=0 and n<math.huge and n%1==0 and (not max or n<=max)
end
function L:AidClass(s)
    return s.usedAddTube and "extra_bottle" or (s.usedHint or s.usedUndo) and "hint_or_undo" or "unassisted"
end
local function Dense(t, max)
    if type(t)~="table" or #t>max then return false end
    local n=0; for k in pairs(t) do
        if type(k)~="number" or k%1~=0 or k<1 or k>#t then return false end
        n=n+1
    end
    return n==#t
end
function L:IsDense(t, max) return Dense(t,max) end
function L:ValidateBoard(tubes, colors, count)
    if not Dense(tubes,11) or #tubes~=count then return false end
    local sums, palette = {}, ArcadiaNexus.ALS_Colors.PALETTE
    for _,t in ipairs(tubes) do
        if not Dense(t,5) then return false end
        for _,c in ipairs(t) do sums[c]=(sums[c] or 0)+1 end
    end
    for i=1,colors do if sums[palette[i]]~=5 then return false end; sums[palette[i]]=nil end
    return next(sums)==nil
end

-- An iterative DFS. Time and operation limits apply to invalid edges too.
-- Symmetry keys remove only interchangeable bottle positions; paths retain indices.
function L:NewSearch(tubes, opts)
    opts=opts or {}
    local job={status="running", stack={{board=self:DeepCopy(tubes),edge=0}}, visited={},
        states=1,edges=0,peak=1,cpu=0,clock=opts.clock or function() return 0 end,
        maxStates=opts.maxStates or 50000,maxEdges=opts.maxEdges or 200000,
        maxCpu=opts.maxCpu or 250,maxWait=opts.maxWait or 2000,maxDepth=opts.maxDepth or 400}
    job.started=job.clock(); job.visited[self:BoardKey(tubes,true)]=true
    function job:Cancel() self.status="unknown"; self.stack={}; self.visited={} end
    function job:Step(maxEdges, maxMs)
        if self.status~="running" then return self.status end
        local start=self.clock(); local work=0
        while work<(maxEdges or 64) and self.clock()-start<(maxMs or 1.5) do
            if self.states+#self.stack>=self.maxStates or self.edges>=self.maxEdges or self.cpu+self.clock()-start>=self.maxCpu
                or self.clock()-self.started>=self.maxWait then self:Cancel(); break end
            local node=self.stack[#self.stack]
            if not node then self.status=self.truncated and "unknown" or "unsolvable"; break end
            local b=node.board; local n=#b
            if L:CheckWin(b) then
                self.path={}; for k=2,#self.stack do self.path[#self.path+1]=self.stack[k].via end
                self.status="solved"; break
            end
            if node.edge>=n*n*2 or #self.stack>self.maxDepth then
                if #self.stack>self.maxDepth then self.truncated=true end
                self.stack[#self.stack]=nil
            else
                local e=node.edge; node.edge=e+1; work=work+1; self.edges=self.edges+1
                local i=math.floor((e%(n*n))/n)+1; local j=(e%n)+1
                local nonempty=e<n*n
                if (#b[j]>0)==nonempty and L:CanMove(b,i,j) then
                    local nextBoard=L:DeepCopy(b); L:ExecuteMove(nextBoard[i],nextBoard[j])
                    local key=L:BoardKey(nextBoard,true)
                    if not self.visited[key] then
                        self.visited[key]=true; self.states=self.states+1
                        self.stack[#self.stack+1]={board=nextBoard,edge=0,via={i,j}}
                        self.peak=math.max(self.peak,#self.stack+self.states)
                    end
                end
            end
        end
        self.cpu=self.cpu+self.clock()-start
        if self.status~="running" then self.stack={}; self.visited={} end
        self.lastWork=work
        return self.status
    end
    return job
end
