-- Minesweeper rule v2: safe first reveal, atomic chording, pure board rules.
local A=_G.ArcadiaNexus
local L={}
A.MS_Logic=L
L.CONFIGS={easy={size=9,mines=10},normal={size=12,mines=20},hard={size=16,mines=40}}
local function Integer(v,lo,hi)
    return type(v)=="number" and v==math.floor(v) and v>=lo and v<=hi
end
local function Neighbors(size,r,c,fn)
    for dr=-1,1 do for dc=-1,1 do
        local nr,nc=r+dr,c+dc
        if (dr~=0 or dc~=0) and nr>=1 and nr<=size and nc>=1 and nc<=size then fn(nr,nc) end
    end end
end
local function Cell(b,r,c)
    if not Integer(r,1,b.size) or not Integer(c,1,b.size) then return nil end
    return b.cells[r][c]
end
local function Copy(t)
    if type(t)~="table" then return t end
    local out={}; for k,v in pairs(t) do out[k]=Copy(v) end; return out
end

function L:NewBoard(diff)
    diff=self.CONFIGS[diff] and diff or "easy"
    local cfg=self.CONFIGS[diff]
    local b={difficulty=diff,ruleVersion=2,size=cfg.size,mineCount=cfg.mines,
        flagCount=0,revealCount=0,cells={},phase="PLAYING",minesPlaced=false}
    for r=1,b.size do b.cells[r]={}; for c=1,b.size do
        b.cells[r][c]={isMine=false,revealed=false,flagged=false,neighbors=0}
    end end
    return b
end

function L:PlaceMines(b,r,c)
    local candidates={}
    for nr=1,b.size do for nc=1,b.size do
        if math.abs(nr-r)>1 or math.abs(nc-c)>1 then candidates[#candidates+1]={r=nr,c=nc} end
    end end
    -- Flags are guesses and have no influence on placement.
    A.ArrayUtils.Shuffle(candidates)
    for i=1,b.mineCount do local p=candidates[i]; b.cells[p.r][p.c].isMine=true end
    for nr=1,b.size do for nc=1,b.size do
        local cell=b.cells[nr][nc]
        Neighbors(b.size,nr,nc,function(ar,ac)
            if b.cells[ar][ac].isMine then cell.neighbors=cell.neighbors+1 end
        end)
    end end
    b.minesPlaced=true
    b.firstReveal={r=r,c=c}
end

function L:RevealAllMines(b)
    local positions={}
    for r=1,b.size do for c=1,b.size do
        if b.cells[r][c].isMine then
            b.cells[r][c].revealed=true
            positions[#positions+1]={r=r,c=c}
        end
    end end
    return positions
end

-- Resolve every target first; do not check victory in the middle of a chord.
function L:_RevealTargets(b,targets)
    local hit
    for _,p in ipairs(targets) do
        local cell=b.cells[p.r][p.c]
        if not cell.flagged and not cell.revealed and cell.isMine then hit=p; break end
    end
    local stack,visited={},{}
    for _,p in ipairs(targets) do stack[#stack+1]=p end
    while #stack>0 do
        local p=table.remove(stack)
        local key=p.r..":"..p.c
        if not visited[key] then
            visited[key]=true
            local cell=b.cells[p.r][p.c]
            if not cell.revealed and not cell.flagged and not cell.isMine then
                cell.revealed=true
                b.revealCount=b.revealCount+1
                if cell.neighbors==0 then
                    Neighbors(b.size,p.r,p.c,function(r,c) stack[#stack+1]={r=r,c=c} end)
                end
            end
        end
    end
    if hit then
        b.exploded={r=hit.r,c=hit.c}
        b.phase="LOST"
        b.minePositions=self:RevealAllMines(b)
        return "mine"
    end
    if self:CheckWin(b) then b.phase="WON"; return "won" end
    return "revealed"
end

function L:RevealCell(b,r,c)
    if b.phase~="PLAYING" then return "game_over" end
    local cell=Cell(b,r,c)
    if not cell then return "invalid" end
    if cell.flagged then return "flagged" end
    if cell.revealed then
        if cell.neighbors==0 then return "already_revealed" end
        local flags,targets=0,{}
        Neighbors(b.size,r,c,function(nr,nc)
            local neighbor=b.cells[nr][nc]
            if neighbor.flagged then flags=flags+1
            elseif not neighbor.revealed then targets[#targets+1]={r=nr,c=nc} end
        end)
        if flags~=cell.neighbors or #targets==0 then return "already_revealed" end
        return self:_RevealTargets(b,targets)
    end
    if not b.minesPlaced then self:PlaceMines(b,r,c) end
    return self:_RevealTargets(b,{{r=r,c=c}})
end

function L:ToggleFlag(b,r,c)
    if b.phase~="PLAYING" then return "game_over" end
    local cell=Cell(b,r,c)
    if not cell then return "invalid" end
    if cell.revealed then return "already_revealed" end
    cell.flagged=not cell.flagged
    b.flagCount=b.flagCount+(cell.flagged and 1 or -1)
    return cell.flagged and "flagged" or "unflagged"
end

function L:CheckWin(b) return b.minesPlaced and b.revealCount==b.size*b.size-b.mineCount end
function L:GetScore(b) return b.phase=="WON" and ({easy=50,normal=100,hard=200})[b.difficulty] or 0 end
function L:GetBoardState(b) return Copy(b) end

function L:ValidateSave(s)
    if type(s)~="table" or s.saveVersion~=1 or s.ruleVersion~=2
        or type(s.runId)~="string" or not self.CONFIGS[s.difficulty] then return false end
    local cfg=self.CONFIGS[s.difficulty]
    if s.size~=cfg.size or s.mineCount~=cfg.mines or type(s.minesPlaced)~="boolean"
        or not Integer(s.elapsedMs,0,2147483647) or type(s.cells)~="table" or #s.cells~=s.size
        or (s.resultPending~=nil and type(s.resultPending)~="boolean") then return false end
    local function Array(t,len)
        if type(t)~="table" or #t~=len then return false end
        for k in pairs(t) do if not Integer(k,1,len) then return false end end
        return true
    end
    if not Array(s.cells,s.size) then return false end
    local mines,flags,revealed=0,0,0
    for r=1,s.size do
        if not Array(s.cells[r],s.size) then return false end
        for c=1,s.size do
            local cell=s.cells[r][c]
            if type(cell)~="table" or type(cell.isMine)~="boolean" or type(cell.revealed)~="boolean"
                or type(cell.flagged)~="boolean" or not Integer(cell.neighbors,0,8) then return false end
            if cell.isMine then mines=mines+1 end
            if cell.flagged then flags=flags+1 end
            if cell.revealed and not cell.isMine then
                if cell.flagged then return false end
                revealed=revealed+1
            end
            if cell.isMine and cell.revealed and s.phase~="LOST" then return false end
        end
    end
    if mines~=(s.minesPlaced and s.mineCount or 0) or flags~=s.flagCount or revealed~=s.revealCount then return false end
    for r=1,s.size do for c=1,s.size do
        local count=0
        Neighbors(s.size,r,c,function(nr,nc) if s.cells[nr][nc].isMine then count=count+1 end end)
        if count~=s.cells[r][c].neighbors then return false end
    end end
    if not s.minesPlaced then
        return s.phase=="PLAYING" and revealed==0 and s.elapsedMs==0 and not s.firstReveal and not s.exploded
    end
    local first=s.firstReveal
    if type(first)~="table" or not Cell(s,first.r,first.c) then return false end
    if s.cells[first.r][first.c].isMine or s.cells[first.r][first.c].neighbors~=0
        or not s.cells[first.r][first.c].revealed then return false end
    if s.phase=="LOST" then
        local hit=s.exploded
        if type(hit)~="table" or not Cell(s,hit.r,hit.c) or not s.cells[hit.r][hit.c].isMine
            or s.cells[hit.r][hit.c].flagged then return false end
        for r=1,s.size do for c=1,s.size do
            if s.cells[r][c].isMine and not s.cells[r][c].revealed then return false end
        end end
        return true
    end
    if s.exploded then return false end
    if s.phase=="WON" then return self:CheckWin(s) end
    return s.phase=="PLAYING" and not self:CheckWin(s)
end
