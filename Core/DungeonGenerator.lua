-- Deterministic, renderer-independent dungeon layout generator.
local A = _G.ArcadiaNexus
A.DungeonGenerator = {}
local D = A.DungeonGenerator
D.TILE_WALL, D.TILE_FLOOR = "wall", "floor"
D.ROOM_START, D.ROOM_BOSS = "start", "boss"
D.ROOM_TREASURE, D.ROOM_REST = "treasure", "rest"
D.ROOM_COMBAT, D.ROOM_EVENT = "combat", "event"
D.DEFAULTS = { width=48, height=32, roomCount=9, minRoomWidth=4, maxRoomWidth=8, minRoomHeight=4, maxRoomHeight=7, roomPadding=1, attemptsPerRoom=24, lockCount=1, depth=1 }
local M, AA, CC = 2147483647, 1664525, 1013904223
local function clamp(v, lo, hi) v=math.floor(tonumber(v) or lo); return v<lo and lo or (v>hi and hi or v) end
local function rng(seed)
  local s=math.floor(tonumber(seed) or 1)%M; if s<1 then s=1 end
  return function(n) s=(s*AA+CC)%M; return s%n+1 end
end
local function config(o)
  local c={}; o=o or {}; for k,v in pairs(D.DEFAULTS) do c[k]=o[k] or v end
  c.width,c.height=clamp(c.width,9,120),clamp(c.height,9,120)
  c.minRoomWidth=clamp(c.minRoomWidth,3,c.width-2); c.minRoomHeight=clamp(c.minRoomHeight,3,c.height-2)
  c.maxRoomWidth=clamp(c.maxRoomWidth,c.minRoomWidth,c.width-2); c.maxRoomHeight=clamp(c.maxRoomHeight,c.minRoomHeight,c.height-2)
  c.roomCount=clamp(c.roomCount,1,50); c.roomPadding=clamp(c.roomPadding,0,3); c.attemptsPerRoom=clamp(c.attemptsPerRoom,1,100); c.lockCount=clamp(c.lockCount,0,8); c.depth=clamp(c.depth,1,100)
  return c
end
local function grid(w,h)
  local g={}; for y=1,h do g[y]={}; for x=1,w do g[y][x]=D.TILE_WALL end end; return g
end
local function carve(g,r) for y=r.y,r.y+r.h-1 do for x=r.x,r.x+r.w-1 do g[y][x]=D.TILE_FLOOR end end end
local function hor(g,x1,x2,y) if x1>x2 then x1,x2=x2,x1 end; for x=x1,x2 do g[y][x]=D.TILE_FLOOR end end
local function ver(g,x,y1,y2) if y1>y2 then y1,y2=y2,y1 end; for y=y1,y2 do g[y][x]=D.TILE_FLOOR end end
local function overlap(a,b,p) return a.x-p<=b.x+b.w-1 and a.x+a.w-1+p>=b.x and a.y-p<=b.y+b.h-1 and a.y+a.h-1+p>=b.y end
local function closest(rooms,r)
  local best,dist; for i=1,#rooms-1 do local q=rooms[i]; local d=math.abs(r.cx-q.cx)+math.abs(r.cy-q.cy); if not dist or d<dist then best,dist=q,d end end; return best
end
local function connect(g,a,b,roll)
  if roll(2)==1 then hor(g,a.cx,b.cx,a.cy); ver(g,b.cx,a.cy,b.cy) else ver(g,a.cx,a.cy,b.cy); hor(g,a.cx,b.cx,b.cy) end
end
local function assignTypes(rooms,start,exit,roll)
  start.type=D.ROOM_START
  if exit~=start then exit.type=D.ROOM_BOSS end
  local open={}
  for i=1,#rooms do local r=rooms[i]; if r~=start and r~=exit then open[#open+1]=r end end
  if open[1] then open[1].type=D.ROOM_TREASURE end
  if open[2] then open[2].type=D.ROOM_REST end
  for i=3,#open do open[i].type=roll(3)==1 and D.ROOM_EVENT or D.ROOM_COMBAT end
end
local function roomPath(links,from,to)
  local adjacent={}
  for i=1,#links do local e=links[i]; adjacent[e.a]=adjacent[e.a] or {}; adjacent[e.b]=adjacent[e.b] or {}; adjacent[e.a][#adjacent[e.a]+1]={id=e.b,edge=e}; adjacent[e.b][#adjacent[e.b]+1]={id=e.a,edge=e} end
  local parent,queue={[from]=false},{from}; local head=1
  while queue[head] do local id=queue[head]; head=head+1; if id==to then break end
    for _,n in ipairs(adjacent[id] or {}) do if parent[n.id]==nil then parent[n.id]={id=id,edge=n.edge}; queue[#queue+1]=n.id end end
  end
  if from~=to and parent[to]==nil then return nil end
  local rooms,edges={to},{}
  while rooms[1]~=from do local p=parent[rooms[1]]; table.insert(rooms,1,p.id); table.insert(edges,1,p.edge) end
  return rooms,edges
end
local function addLocks(dungeon,count)
  local path,edges=roomPath(dungeon.links,dungeon.start.roomId,dungeon.exit.roomId)
  dungeon.path=path or {dungeon.start.roomId}; dungeon.locks={}
  local max=math.min(count,math.max(0,#edges-1))
  for i=1,max do
    local edgeIndex=#edges-i+1; local keyRoomId=path[edgeIndex]
    local lock={id=i,keyRoomId=keyRoomId,edge=edges[edgeIndex]}
    lock.edge.lockId=i; dungeon.rooms[keyRoomId].keys=dungeon.rooms[keyRoomId].keys or {}; table.insert(dungeon.rooms[keyRoomId].keys,i); dungeon.locks[#dungeon.locks+1]=lock
  end
end
local function populate(rooms,depth,roll)
  for i=1,#rooms do
    local room=rooms[i]
    room.contents={}
    if room.type==D.ROOM_START then
      room.contents[1]={kind="entrance"}
    elseif room.type==D.ROOM_BOSS then
      room.contents[1]={kind="boss",threat=depth*8+roll(5),elite=true}
      room.contents[2]={kind="reward",reward="boss_cache",value=depth*20+roll(10)}
    elseif room.type==D.ROOM_COMBAT then
      room.contents[1]={kind="encounter",threat=depth*3+roll(4),count=1+roll(math.min(4,1+math.floor(depth/8))),elite=roll(5)==1}
    elseif room.type==D.ROOM_TREASURE then
      room.contents[1]={kind="reward",reward="treasure",value=depth*12+roll(8),rarity=roll(100)<=math.min(45,8+depth) and "rare" or "common"}
    elseif room.type==D.ROOM_REST then
      room.contents[1]={kind="rest",healing=20+math.min(60,depth*2),removesDebuff=true}
    else
      room.contents[1]={kind="event",event="unknown",threat=depth+roll(3),reward=depth*5+roll(5)}
    end
    if room.keys then for _,key in ipairs(room.keys) do room.contents[#room.contents+1]={kind="key",keyId=key} end end
  end
end
function D:Generate(o)
  o=o or {}; local c,seed=config(o),math.floor(tonumber(o.seed) or 1); local roll,g,rooms,links=rng(seed),grid(c.width,c.height),{},{}
  for _=1,c.roomCount do
    local made=false
    for _=1,c.attemptsPerRoom do
      local w=c.minRoomWidth+roll(c.maxRoomWidth-c.minRoomWidth+1)-1; local h=c.minRoomHeight+roll(c.maxRoomHeight-c.minRoomHeight+1)-1
      local r={x=roll(c.width-w-1)+1,y=roll(c.height-h-1)+1,w=w,h=h}; r.cx=r.x+math.floor((w-1)/2); r.cy=r.y+math.floor((h-1)/2)
      local blocked=false; for i=1,#rooms do if overlap(r,rooms[i],c.roomPadding) then blocked=true; break end end
      if not blocked then r.id=#rooms+1; rooms[#rooms+1]=r; carve(g,r); local q=closest(rooms,r); if q then connect(g,q,r,roll); links[#links+1]={a=q.id,b=r.id} end; made=true; break end
    end
    if not made then break end
  end
  if #rooms==0 then local r={id=1,x=math.floor((c.width-3)/2)+1,y=math.floor((c.height-3)/2)+1,w=3,h=3}; r.cx,r.cy=r.x+1,r.y+1; rooms[1]=r; carve(g,r) end
  local start,exit=rooms[1],rooms[1]; local far=-1
  for i=1,#rooms do local r=rooms[i]; local d=math.abs(r.cx-start.cx)+math.abs(r.cy-start.cy); if d>far then exit,far=r,d end end
  local dungeon={seed=seed,config=c,grid=g,rooms=rooms,links=links,start={x=start.cx,y=start.cy,roomId=start.id},exit={x=exit.cx,y=exit.cy,roomId=exit.id}}; assignTypes(rooms,start,exit,roll); addLocks(dungeon,c.lockCount); populate(rooms,c.depth,roll); return dungeon
end
function D:GetRoom(d,id) return d and d.rooms and d.rooms[id] or nil end
function D:GetRoomContents(d,id) local r=self:GetRoom(d,id); return r and r.contents or nil end
function D:GetRoomAt(d,x,y)
  if not self:IsInBounds(d,x,y) then return nil end
  for i=1,#d.rooms do local r=d.rooms[i]; if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then return r end end
end
function D:IsInBounds(d,x,y) return d and x>=1 and y>=1 and x<=d.config.width and y<=d.config.height end
function D:GetTile(d,x,y) return self:IsInBounds(d,x,y) and d.grid[y][x] or nil end
function D:IsWalkable(d,x,y) return self:GetTile(d,x,y)==D.TILE_FLOOR end
function D:ToRows(d,chars)
  chars=chars or {}; local rows={}; for y=1,d.config.height do local row={}; for x=1,d.config.width do row[x]=d.grid[y][x]==D.TILE_FLOOR and (chars.floor or ".") or (chars.wall or "#") end; rows[y]=table.concat(row) end
  local function mark(p,ch) local r=rows[p.y]; rows[p.y]=r:sub(1,p.x-1)..ch..r:sub(p.x+1) end
  mark(d.start,chars.start or "S"); if d.start.x~=d.exit.x or d.start.y~=d.exit.y then mark(d.exit,chars.exit or "E") end; return rows
end
function D:ValidateProgression(d)
  if not d or not d.links or not d.rooms then return false,"invalid_progression" end
  local reached,keys={[d.start.roomId]=true},{}
  local changed=true
  while changed do
    changed=false
    for id in pairs(reached) do for _,key in ipairs(d.rooms[id].keys or {}) do if not keys[key] then keys[key]=true; changed=true end end end
    for i=1,#d.links do local e=d.links[i]; local open=not e.lockId or keys[e.lockId]
      if open and reached[e.a] and not reached[e.b] then reached[e.b]=true; changed=true end
      if open and reached[e.b] and not reached[e.a] then reached[e.a]=true; changed=true end
    end
  end
  return reached[d.exit.roomId] and true or false, reached[d.exit.roomId] and nil or "boss_unreachable"
end
function D:Validate(d)
  if not d or not self:IsWalkable(d,d.start.x,d.start.y) or not self:IsWalkable(d,d.exit.x,d.exit.y) then return false,"invalid_endpoints" end
  if not self:ValidateProgression(d) then return false,"progression_invalid" end
  local seen,q={[d.start.y..":"..d.start.x]=true},{{x=d.start.x,y=d.start.y}}; local head=1
  while q[head] do local p=q[head]; head=head+1; if p.x==d.exit.x and p.y==d.exit.y then return true end
    local ns={{p.x+1,p.y},{p.x-1,p.y},{p.x,p.y+1},{p.x,p.y-1}}; for i=1,4 do local n=ns[i]; local k=n[2]..":"..n[1]; if not seen[k] and self:IsWalkable(d,n[1],n[2]) then seen[k]=true;q[#q+1]={x=n[1],y=n[2]} end end
  end
  return false,"exit_unreachable"
end