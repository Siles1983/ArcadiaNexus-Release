-- Azeroth Conquest: pure placement/turn rules and validated snapshot v1.
local A = _G.ArcadiaNexus
local Game = {}
Game.__index = Game
A.AC_Game = Game

function Game:New() return setmetatable({}, self) end
function Game:_BuildShipQueue(size)
    local queue={}
    for _,def in ipairs(A.AC_Logic:GetShipDefinitions(size)) do
        for _=1,def.count do queue[#queue+1]={name=def.name,length=def.length,icon=def.icon} end
    end
    return queue
end
function Game:Init(config)
    self.logic,self.ai=A.AC_Logic,A.AC_AI
    self.config={size=10,aiDifficulty=self.logic:NormalizeDifficulty(config and config.aiDifficulty)}
    self.aiDifficulty=self.config.aiDifficulty
    self.phase,self.turnPhase="PLACEMENT","PLAYER_TURN"
    self.playerBoard,self.aiBoard=self.logic:CreateBoard(10),self.logic:CreateBoard(10)
    if not self.logic:PlaceShipsRandom(self.aiBoard) then return false end
    self.shipQueue=self:_BuildShipQueue(10)
    self.currentShipIdx,self.placementHoriz=1,true
    self.totalShots,self.totalMisses=0,0
    self.gameOver=false
    self.aiKnowledge=self.ai:NewKnowledge(10,{5,4,3,3,2})
    return true
end
function Game:GetCurrentShip() return self.shipQueue[self.currentShipIdx] end
function Game:ToggleOrientation()
    if self.phase~="PLACEMENT" then return false end
    self.placementHoriz=not self.placementHoriz; return true
end
function Game:PlaceShip(r,c)
    if self.phase~="PLACEMENT" or not self:GetCurrentShip() then return false end
    if not self.logic:PlaceShip(self.playerBoard,self:GetCurrentShip(),r,c,self.placementHoriz) then return false end
    self.currentShipIdx=self.currentShipIdx+1; return true
end
function Game:UndoPlacement()
    if self.phase~="PLACEMENT" or self.currentShipIdx<=1 then return false end
    if not self.logic:RemoveLastShip(self.playerBoard,self.currentShipIdx-1) then return false end
    self.currentShipIdx=self.currentShipIdx-1; return true
end
function Game:PlaceAllRandom()
    if self.phase~="PLACEMENT" then return false end
    if not self.logic:PlaceShipsRandom(self.playerBoard) then return false end
    self.currentShipIdx=#self.shipQueue+1; return true
end
function Game:StartBattle()
    if self.phase~="PLACEMENT" or self.currentShipIdx~=#self.shipQueue+1 then return false end
    if self.playerBoard._nextShipID~=#self.shipQueue+1 then return false end
    self.phase="BATTLE"; return true
end
function Game:HandleShot(r,c)
    if self.phase~="BATTLE" or self.turnPhase~="PLAYER_TURN" or self.gameOver then return false end
    local result=self.logic:Shoot(self.aiBoard,r,c)
    if result=="INVALID" or result=="ALREADY_SHOT" then return false end
    self.lastShot={r=r,c=c,result=result}
    self.totalShots=self.totalShots+1
    if result=="MISS" then self.totalMisses=self.totalMisses+1 end
    if self.logic:AllShipsSunk(self.aiBoard) then
        self.gameOver,self.result,self.phase=true,"WIN","GAMEOVER"
    else
        local target=self.ai:GetBestMove(self.aiKnowledge,self.aiDifficulty)
        assert(target,"Live fleet has no remaining AI target")
        self.turnPhase="AI_PENDING"
        self.pending={r=target.r,c=target.c,remaining=.65}
    end
    return true
end
function Game:ResolveAIShot()
    if self.phase~="BATTLE" or self.turnPhase~="AI_PENDING" or not self.pending then return false end
    local target=self.pending
    local result=self.logic:Shoot(self.playerBoard,target.r,target.c)
    assert(result~="INVALID" and result~="ALREADY_SHOT","Invalid pending AI target")
    self.lastAiShot={r=target.r,c=target.c,result=result}
    local revealed=result=="SUNK" and self.logic:GetShipAt(self.playerBoard,target.r,target.c)
    self.ai:Observe(self.aiKnowledge,self.lastAiShot,revealed)
    self.pending=nil; self.turnPhase="PLAYER_TURN"
    if self.logic:AllShipsSunk(self.playerBoard) then
        self.gameOver,self.result,self.phase=true,"LOSS","GAMEOVER"
    end
    return true
end
function Game:GetBoardState()
    local byPlayer,byAI={},{}
    for _,s in ipairs(self.aiBoard.ships) do if s.sunk then byPlayer[#byPlayer+1]=s end end
    for _,s in ipairs(self.playerBoard.ships) do if s.sunk then byAI[#byAI+1]=s end end
    return {
        size=10,phase=self.phase,turnPhase=self.turnPhase,gameOver=self.gameOver,result=self.result,
        aiDifficulty=self.aiDifficulty,playerBoard=self.playerBoard,aiBoard=self.aiBoard,
        lastShot=self.lastShot,lastAiShot=self.lastAiShot,sunkByPlayer=byPlayer,sunkByAI=byAI,
        currentShip=self:GetCurrentShip(),placementHoriz=self.placementHoriz,
        shipsPlaced=self.currentShipIdx-1,totalShips=#self.shipQueue,
        totalShots=self.totalShots,totalMisses=self.totalMisses,
    }
end
function Game:Snapshot()
    local out={version=1,size=10}
    for _,key in ipairs({"aiDifficulty","phase","turnPhase","playerBoard","aiBoard","currentShipIdx",
        "placementHoriz","aiKnowledge","pending","lastShot","lastAiShot","totalShots","totalMisses","runId","gameOver"}) do
        out[key]=self.logic:Copy(self[key])
    end
    return out
end

local function integer(n,min,max) return type(n)=="number" and n==n and n%1==0 and n>=min and n<=max end
local function exactArray(t,n)
    if type(t)~="table" then return false end
    local count=0
    for k in pairs(t) do if not integer(k,1,n) then return false end; count=count+1 end
    return count==n
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
-- Rebuild from bounded canonical geometry, then verify redundant saved state.
local function restoreBoard(saved,queue,count)
    local L=A.AC_Logic
    if type(saved)~="table" or saved.size~=10 or saved._nextShipID~=count+1
        or not exactArray(saved.ships,count) or not exactArray(saved.cells,10) or not exactArray(saved.hits,10) then return nil end
    local board=L:CreateBoard(10)
    for id=1,count do
        local s=saved.ships[id]
        if type(s)~="table" or s.id~=id or s.length~=queue[id].length
            or type(s.horizontal)~="boolean" or not integer(s.startR,1,10) or not integer(s.startC,1,10)
            or not exactArray(s.cells,s.length) then return nil end
        local restored=L:PlaceShip(board,queue[id],s.startR,s.startC,s.horizontal)
        if not restored or not same(restored.cells,s.cells) then return nil end
    end
    local shots,misses=0,0
    for r=1,10 do
        if not exactArray(saved.cells[r],10) or not exactArray(saved.hits[r],10) then return nil end
        for c=1,10 do
            if saved.cells[r][c]~=board.cells[r][c] or type(saved.hits[r][c])~="boolean" then return nil end
            if saved.hits[r][c] then
                local result=L:Shoot(board,r,c); shots=shots+1
                if result=="MISS" then misses=misses+1 end
            end
        end
    end
    for id=1,count do
        if saved.ships[id].hits~=board.ships[id].hits or saved.ships[id].sunk~=board.ships[id].sunk then return nil end
    end
    return board,shots,misses
end
local function restoreShot(s,board,shotCount)
    if shotCount==0 then return s==nil end
    if type(s)~="table" or not integer(s.r,1,10) or not integer(s.c,1,10) or not board.hits[s.r][s.c] then return false end
    local ship=board.ships[board.cells[s.r][s.c]]
    return s.result=="MISS" and not ship or ship and (s.result=="HIT" and not ship.sunk or s.result=="SUNK" and ship.sunk)
end
function Game:Restore(saved)
    if type(saved)~="table" or saved.version~=1 or saved.size~=10 or saved.gameOver~=false
        or not A.AC_Logic:IsDifficulty(saved.aiDifficulty) or type(saved.runId)~="string"
        or saved.phase~="PLACEMENT" and saved.phase~="BATTLE"
        or saved.turnPhase~="PLAYER_TURN" and saved.turnPhase~="AI_PENDING"
        or not integer(saved.currentShipIdx,1,6) or type(saved.placementHoriz)~="boolean" then return nil end
    local g=self:New()
    g.logic,g.ai=A.AC_Logic,A.AC_AI; g.config={size=10,aiDifficulty=saved.aiDifficulty}
    g.shipQueue=g:_BuildShipQueue(10)
    local player,aiShots=restoreBoard(saved.playerBoard,g.shipQueue,saved.currentShipIdx-1)
    local enemy,shots,misses=restoreBoard(saved.aiBoard,g.shipQueue,5)
    if not player or not enemy or shots~=saved.totalShots or misses~=saved.totalMisses
        or not restoreShot(saved.lastShot,enemy,shots) or not restoreShot(saved.lastAiShot,player,aiShots) then return nil end
    if saved.phase=="PLACEMENT" then
        if shots~=0 or aiShots~=0 or saved.pending~=nil or saved.turnPhase~="PLAYER_TURN" then return nil end
    else
        if saved.currentShipIdx~=6 or g.logic:AllShipsSunk(player) or g.logic:AllShipsSunk(enemy) then return nil end
        if saved.turnPhase=="AI_PENDING" then
            local p=saved.pending
            if aiShots~=shots-1 or type(p)~="table" or not integer(p.r,1,10) or not integer(p.c,1,10)
                or player.hits[p.r][p.c] or type(p.remaining)~="number" or p.remaining~=p.remaining
                or p.remaining<0 or p.remaining>.65 then return nil end
        elseif aiShots~=shots or saved.pending~=nil then return nil end
    end
    local knowledge=g.ai:NewKnowledge(10,{})
    for _,ship in ipairs(player.ships) do if not ship.sunk then knowledge.remaining[#knowledge.remaining+1]=ship.length end end
    -- During partial placement the public fleet inventory remains the full one.
    if saved.phase=="PLACEMENT" then knowledge.remaining={5,4,3,3,2} end
    for r=1,10 do for c=1,10 do
        if player.hits[r][c] then
            local ship=player.ships[player.cells[r][c]]
            knowledge.shots[r][c]=not ship and "MISS" or ship.sunk and "SUNK" or "HIT"
        end
    end end
    if type(saved.aiKnowledge)~="table" or saved.aiKnowledge.size~=10 or not same(knowledge.shots,saved.aiKnowledge.shots)
        or not exactArray(saved.aiKnowledge.remaining,#knowledge.remaining) then return nil end
    for _,len in ipairs(saved.aiKnowledge.remaining) do if not integer(len,2,5) then return nil end end
    local lengths=g.logic:Copy(saved.aiKnowledge.remaining); table.sort(lengths)
    local expected=g.logic:Copy(knowledge.remaining); table.sort(expected)
    if not same(lengths,expected) then return nil end
    for _,key in ipairs({"aiDifficulty","phase","turnPhase","currentShipIdx","placementHoriz",
        "pending","lastShot","lastAiShot","totalShots","totalMisses","runId","gameOver"}) do g[key]=g.logic:Copy(saved[key]) end
    g.playerBoard,g.aiBoard,g.aiKnowledge=player,enemy,{size=10,shots=knowledge.shots,remaining=g.logic:Copy(saved.aiKnowledge.remaining)}
    return g
end
