--[[
    Gaming Hub – Snake
    Games/Snake/Logic.lua

    Pure Spiellogik. Kein UI, keine Timer.

    Board:
    {
        gridSize    number   Anzahl Zellen pro Seite
        snake       table    { {r,c}, ... } – Kopf = [1], Schwanz = [#]
        dir         table    {dr, dc} – aktuelle Richtung
        dirQueue    table    FIFO mit höchstens zwei gültigen Kurven
        food        table    {r, c}
        score       number
        alive       bool
        multiplier  number
    }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Logic = {}
local L = ArcadiaNexus.SNK_Logic

-- ============================================================
-- NewBoard
-- ============================================================
function L:NewBoard(config)
    config=config or {}
    local T    = ArcadiaNexus.SNK_Themes
    local difficulty=T:NormalizeDifficulty(config.difficulty)
    local diff = T:GetDiff(difficulty)
    local g    = diff.gridSize

    -- Startposition: Mitte des Grids, 3 Segmente nach rechts
    local midR = math.floor(g / 2)
    local midC = math.floor(g / 2)
    local snake = {
        { r=midR, c=midC   },
        { r=midR, c=midC-1 },
        { r=midR, c=midC-2 },
    }

    local board = {
        gridSize   = g,
        snake      = snake,
        dir        = { dr=0, dc=1 },   -- startet nach rechts
        dirQueue   = {},
        state      = "RUNNING", tickRemainder=0,
        food       = nil,
        score      = 0,
        alive      = true,
        multiplier = diff.multiplier,
        difficulty = difficulty,
        theme      = "tiles",
        fruitsEaten = 0,
    }

    board.food = self:SpawnFood(board)
    return board
end

-- ============================================================
-- SpawnFood – zufällige Position die nicht auf der Schlange liegt
-- ============================================================
function L:SpawnFood(board)
    local g = board.gridSize
    -- Schnellen Lookup der belegten Zellen
    local occupied = {}
    for _, seg in ipairs(board.snake) do
        occupied[seg.r .. "," .. seg.c] = true
    end
    -- Versuche bis zu 200× eine freie Position finden
    for _ = 1, 200 do
        local r = math.random(1, g)
        local c = math.random(1, g)
        if not occupied[r .. "," .. c] then
            return { r=r, c=c }
        end
    end
    -- Fallback: erste freie Zelle
    for r = 1, g do
        for c = 1, g do
            if not occupied[r .. "," .. c] then
                return { r=r, c=c }
            end
        end
    end
    return nil   -- Spielfeld komplett voll (gewonnen)
end

-- ============================================================
-- QueueDir – puffert neue Richtung (verhindert 180°-Umkehr)
-- ============================================================
function L:IsDirection(dr,dc)
    return type(dr)=="number" and type(dc)=="number" and (dr==0 and (dc==1 or dc==-1) or dc==0 and (dr==1 or dr==-1))
end
function L:QueueDir(board,dr,dc)
    if not board or not board.alive or not self:IsDirection(dr,dc) then return false end
    local queue=board.dirQueue
    local last=queue[#queue] or board.dir
    if #queue>=2 or dr==last.dr and dc==last.dc or dr==-last.dr and dc==-last.dc then return false end
    queue[#queue+1]={dr=dr,dc=dc}; return true
end

-- ============================================================
-- Tick – einen Spielschritt ausführen
-- Gibt zurück: "moved" | "ate" | "died" | "won"
-- ============================================================
function L:Tick(board)
    if not board.alive then return board.state=="WON" and "won" or "died" end

    -- Richtung übernehmen
    local queued=table.remove(board.dirQueue,1)
    if queued then board.dir=queued end

    local head  = board.snake[1]
    local g     = board.gridSize

    -- Neue Kopfposition (Wrap-Around am Rand)
    local newR = head.r + board.dir.dr
    local newC = head.c + board.dir.dc

    -- Wrap-Around (klassisch)
    if newR < 1 then newR = g end
    if newR > g then newR = 1 end
    if newC < 1 then newC = g end
    if newC > g then newC = 1 end

    -- Selbst-Kollision prüfen (nur Körper ohne letztes Segment,
    -- da das im selben Tick wegfällt)
    local bodyLen = #board.snake
    local growing=board.food and newR==board.food.r and newC==board.food.c
    for i = 1, bodyLen-(growing and 0 or 1) do
        local seg = board.snake[i]
        if seg.r == newR and seg.c == newC then
            board.alive = false; board.state="LOST"
            return "died"
        end
    end

    -- Kopf einfügen
    table.insert(board.snake, 1, { r=newR, c=newC })

    -- Futter gefressen?
    local ate = false
    if board.food and newR == board.food.r and newC == board.food.c then
        ate = true
        board.fruitsEaten = (board.fruitsEaten or 0) + 1
        board.score = board.score + (1 * board.multiplier)
        board.food  = self:SpawnFood(board)
        if board.food == nil then
            board.alive=false; board.state="WON"
            return "won"
        end
    end

    if not ate then
        -- Schwanz entfernen (Schlange bewegt sich ohne zu wachsen)
        table.remove(board.snake)
    end

    return ate and "ate" or "moved"
end

function L:Copy(v)
    if type(v)~="table" then return v end local out={} for k,x in pairs(v) do out[k]=self:Copy(x) end return out
end
function L:Snapshot(b,phase)
    if not b or b.terminal or not b.alive or b.state~="RUNNING" then return nil end
    local out={version=1,ruleVersion=2,phase=phase or "PLAYING"}
    for _,key in ipairs({"gridSize","snake","dir","dirQueue","food","score","alive","state","multiplier","difficulty","theme","fruitsEaten","tickRemainder","runId"}) do out[key]=self:Copy(b[key]) end
    out.tickRate=ArcadiaNexus.SNK_Themes:GetDiff(b.difficulty).tickRate
    return out
end
function L:Restore(data)
    local function int(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
    local function array(t)
        if type(t)~="table" then return false end
        for i=1,#t do if t[i]==nil then return false end end
        for k in pairs(t) do if not int(k) or k<1 or k>#t then return false end end
        return true
    end
    if type(data)~="table" or data.version~=1 or data.ruleVersion~=2 or data.terminal or data.alive~=true or data.state~="RUNNING"
        or type(data.runId)~="string" or data.phase~="PLAYING" and data.phase~="PAUSED"
        or not ArcadiaNexus.SNK_Themes.DIFFICULTY[data.difficulty] or data.theme~="tiles" then return nil end
    local diff=ArcadiaNexus.SNK_Themes:GetDiff(data.difficulty); local g=diff.gridSize
    if data.gridSize~=g or data.multiplier~=diff.multiplier or data.tickRate~=diff.tickRate
        or not int(data.score) or not int(data.fruitsEaten) or data.score~=data.fruitsEaten*diff.multiplier
        or not array(data.snake) or #data.snake~=data.fruitsEaten+3 or #data.snake>=g*g
        or type(data.dir)~="table" or not self:IsDirection(data.dir.dr,data.dir.dc)
        or not array(data.dirQueue) or #data.dirQueue>2
        or type(data.tickRemainder)~="number" or data.tickRemainder~=data.tickRemainder or data.tickRemainder<0 or data.tickRemainder>=diff.tickRate then return nil end
    local function cell(p) return type(p)=="table" and int(p.r) and int(p.c) and p.r>=1 and p.r<=g and p.c>=1 and p.c<=g end
    local occupied={}
    for i,seg in ipairs(data.snake) do
        if not cell(seg) or occupied[seg.r*g+seg.c] then return nil end
        occupied[seg.r*g+seg.c]=true
        if i>1 then
            local prev=data.snake[i-1]; local dr=(seg.r-prev.r)%g; local dc=(seg.c-prev.c)%g
            if not (dr==0 and (dc==1 or dc==g-1) or dc==0 and (dr==1 or dr==g-1)) then return nil end
        end
    end
    local head,neck=data.snake[1],data.snake[2]
    if (neck.r+data.dir.dr-1)%g+1~=head.r or (neck.c+data.dir.dc-1)%g+1~=head.c then return nil end
    if not cell(data.food) or occupied[data.food.r*g+data.food.c] then return nil end
    local last=data.dir
    for _,dir in ipairs(data.dirQueue) do
        if type(dir)~="table" or not self:IsDirection(dir.dr,dir.dc) or dir.dr==last.dr and dir.dc==last.dc
            or dir.dr==-last.dr and dir.dc==-last.dc then return nil end
        last=dir
    end
    local b={}
    for _,key in ipairs({"gridSize","snake","dir","dirQueue","food","score","alive","state","multiplier","difficulty","theme","fruitsEaten","tickRemainder","runId"}) do b[key]=self:Copy(data[key]) end
    return b
end
