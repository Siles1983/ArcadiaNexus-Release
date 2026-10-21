-- Versioned, witnessed puzzles and cancellable generation jobs. No timers/UI.
local A = _G.ArcadiaNexus
local G = {}; A.ALS_LevelGen=G
G.BUDGET={stepEdges=64,stepMs=1.5,states=50000,edges=200000,cpuMs=250,waitMs=2000}
function G:_GetParams(level) return A.ALS_Colors:GetColorCount(level),2 end
function G:MakePuzzle(tubes, solution, minimum, origin)
    local L=A.ALS_Logic
    return {puzzleVersion=1,ruleVersion=2,generatorVersion=3,origin=origin or "generated",
        colors=#tubes-2,capacity=5,baseTubes=#tubes,initialTubes=L:DeepCopy(tubes),
        puzzleId=L:PuzzleId(tubes),solution=L:Copy(solution or {}),minimum=L:Copy(minimum or {kind="unknown"})}
end
function G:Fallback(level, index)
    local colors=self:_GetParams(level)
    local entry=A.LevelPool.GetEntry(A.ALS_Pool,tostring(colors),index)
    local tubes={}; local palette=A.ALS_Colors.PALETTE
    for i,t in ipairs(entry.tubes) do tubes[i]={}; for j,c in ipairs(t) do tubes[i][j]=palette[c] end end
    return self:MakePuzzle(tubes,entry.solution,entry.minimum,"template")
end
-- Levels 1–1000 are the checked-in catalog. Later levels stay runtime-generated.
function G:CatalogPuzzle(level)
    local entry=A.ALS_Catalog and A.ALS_Catalog[level]
    if type(entry)~="table" or not A.ALS_Logic:Int(level,1000) or level<1 then return nil end
    local tubes={}; local palette=A.ALS_Colors.PALETTE
    for i,t in ipairs(entry.tubes) do
        tubes[i]={}
        for j,c in ipairs(t) do tubes[i][j]=palette[c] end
    end
    return self:MakePuzzle(tubes,entry.solution,entry.minimum,"catalog")
end
-- Only the 3-color band carries an offline BFS proof. Built once, then reused.
function G:ExactProofs()
    if self._exactProofs then return self._exactProofs end
    local idx={}
    for level=1,40 do
        local known=self:CatalogPuzzle(level)
        if known and known.minimum.kind=="exact" then idx[known.puzzleId]=known.minimum end
    end
    self._exactProofs=idx
    return idx
end
function G:VerifyPuzzle(p)
    local L=A.ALS_Logic
    if type(p)~="table" or p.ruleVersion~=2 or p.puzzleVersion~=1 or p.generatorVersion~=3 or p.capacity~=5
        or p.origin~="generated" and p.origin~="template" and p.origin~="legacy" and p.origin~="catalog"
        or not L:Int(p.colors,8) or p.colors<3 or p.baseTubes~=p.colors+2
        or not L:ValidateBoard(p.initialTubes,p.colors,p.baseTubes)
        or p.puzzleId~=L:PuzzleId(p.initialTubes) or L:CheckWin(p.initialTubes)
        or not L:IsDense(p.solution,400) then return false end
    if p.origin=="legacy" then
        return #p.solution==0 and type(p.minimum)=="table" and p.minimum.kind=="unknown"
    end
    local b=L:DeepCopy(p.initialTubes)
    for _,m in ipairs(p.solution) do
        if type(m)~="table" or not L:CanMove(b,m[1],m[2]) then return false end
        L:ExecuteMove(b[m[1]],b[m[2]])
    end
    if not L:CheckWin(b) then return false end
    if type(p.minimum)~="table" or p.minimum.kind~="unknown" and p.minimum.kind~="exact" then return false end
    if p.minimum.kind=="exact" then
        -- Exactness comes from checked-in offline proofs, never from a save claim.
        local proof
        if p.origin=="catalog" then proof=self:ExactProofs()[p.puzzleId]
        elseif p.origin=="template" then
            for i=1,#(A.ALS_Pool[tostring(p.colors)] or {}) do
                local known=self:Fallback(p.colors==3 and 1 or p.colors==4 and 41 or p.colors==5 and 121
                    or p.colors==6 and 251 or p.colors==7 and 451 or 701,i)
                if known.puzzleId==p.puzzleId and known.minimum.kind=="exact" then proof=known.minimum end
            end
        end
        if not proof or proof.moves~=p.minimum.moves or proof.proofVersion~=p.minimum.proofVersion then return false end
    end
    return true
end
function G:Begin(level, clock, forceFallback)
    local L=A.ALS_Logic; local budget=self.BUDGET
    local job={status="running",clock=clock,started=clock(),cpu=0,states=0,edges=0,attempts=0,
        samples={},peak=0,level=level,forceFallback=forceFallback}
    local function candidate()
        local colors=G:_GetParams(level); local all={}
        for i=1,colors do for _=1,5 do all[#all+1]=A.ALS_Colors.PALETTE[i] end end
        A.ArrayUtils.Shuffle(all)
        local b={}; for i=1,colors do b[i]={}; for j=1,5 do b[i][j]=all[(i-1)*5+j] end end
        b[colors+1]={}; b[colors+2]={}; return b
    end
    function job:Cancel()
        if self.search then self.search:Cancel() end
        self.search=nil; self.checkBoard=nil; self.status="unknown"
    end
    function job:Step()
        if self.status~="running" then return self.status end
        local start=self.clock(); local remaining=budget.stepEdges
        if not self.checkBoard and (self.forceFallback or self.attempts>=20 or self.states>=budget.states or self.edges>=budget.edges
            or self.cpu>=budget.cpuMs or self.clock()-self.started>=budget.waitMs) then
            if self.search then self.search:Cancel(); self.search=nil end
            self.puzzle=G:Fallback(self.level,math.random(1,4)); self.checkBoard=L:DeepCopy(self.puzzle.initialTubes); self.checkIndex=1
            self.forceFallback=false; self.checkingFallback=true
        end
        if self.checkBoard then
            while self.checkIndex<=#self.puzzle.solution and remaining>0 and self.clock()-start<budget.stepMs do
                local m=self.puzzle.solution[self.checkIndex]
                if not L:CanMove(self.checkBoard,m[1],m[2]) then self:Cancel(); return self.status end
                L:ExecuteMove(self.checkBoard[m[1]],self.checkBoard[m[2]])
                remaining=remaining-1; self.checkIndex=self.checkIndex+1
            end
            if self.checkIndex>#self.puzzle.solution then
                self.status=L:CheckWin(self.checkBoard) and "solved" or "unknown"; self.checkBoard=nil
            end
        elseif not self.search then
            self.attempts=self.attempts+1; self.board=candidate()
            self.search=L:NewSearch(self.board,{clock=self.clock,maxStates=budget.states-self.states,
                maxEdges=budget.edges-self.edges,maxCpu=budget.cpuMs-self.cpu,maxWait=math.max(0,budget.waitMs-(self.clock()-self.started))})
        else
            local status=self.search:Step(remaining,budget.stepMs)
            self.peak=math.max(self.peak,self.search.peak)
            if status~="running" then
                self.states=self.states+self.search.states; self.edges=self.edges+self.search.edges
                if status=="solved" then
                    self.puzzle=G:MakePuzzle(self.board,self.search.path)
                    self.checkBoard=L:DeepCopy(self.board); self.checkIndex=1
                end
                self.search=nil
            end
        end
        local used=self.clock()-start; self.cpu=self.cpu+used; self.samples[#self.samples+1]=used
        return self.status
    end
    return job
end
