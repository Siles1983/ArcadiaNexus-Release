-- Arcadia top-down dungeon topology: screen rooms, cardinal doors, two floors and key locks.
local A=_G.ArcadiaNexus
A.DungeonTopology={}
local T=A.DungeonTopology
local M,AA,CC=2147483647,1664525,1013904223
local DIRS={{id="north",dx=0,dy=-1,opposite="south"},{id="east",dx=1,dy=0,opposite="west"},{id="south",dx=0,dy=1,opposite="north"},{id="west",dx=-1,dy=0,opposite="east"}}
local function rng(seed) local s=math.floor(tonumber(seed) or 1)%M;if s<1 then s=1 end;return function(n) s=(s*AA+CC)%M;return s%n+1 end end
local function pos(x,y)return x..":"..y end
local function path(f,from,to)
 local near={};for i=1,#f.links do local e=f.links[i];near[e.a]=near[e.a] or {};near[e.b]=near[e.b] or {};near[e.a][#near[e.a]+1]={id=e.b,edge=e};near[e.b][#near[e.b]+1]={id=e.a,edge=e} end
 local parent,q={[from]=false},{from};local head=1;while q[head] do local id=q[head];head=head+1;if id==to then break end;for _,n in ipairs(near[id] or {}) do if parent[n.id]==nil then parent[n.id]={id=id,edge=n.edge};q[#q+1]=n.id end end end
 local rooms,edges={to},{};while rooms[1]~=from do local p=parent[rooms[1]];if not p then return nil end;table.insert(rooms,1,p.id);table.insert(edges,1,p.edge) end;return rooms,edges
end
local function farthest(f) local best,bestDist=f.rooms[1],-1;for i=1,#f.rooms do local r=f.rooms[i];local _,edges=path(f,1,r.id);if #edges>bestDist then best,bestDist=r,#edges end end;return best end
local function newFloor(level,count,lockCount,roll)
 local f={level=level,rooms={},links={},locks={},startRoomId=1};local first={id=1,x=0,y=0,doors={}};f.rooms[1]=first;local used={[pos(0,0)]=first}
 for id=2,count do local parent,d;repeat parent=f.rooms[roll(#f.rooms)];d=DIRS[roll(4)] until not used[pos(parent.x+d.dx,parent.y+d.dy)];local r={id=id,x=parent.x+d.dx,y=parent.y+d.dy,doors={}};f.rooms[id]=r;used[pos(r.x,r.y)]=r;local e={a=parent.id,b=r.id,from=d.id,to=d.opposite};f.links[#f.links+1]=e;parent.doors[d.id]={to=r.id,edge=e};r.doors[d.opposite]={to=parent.id,edge=e} end
 local exit=farthest(f);f.exitRoomId=exit.id;first.type="start";exit.type=level==2 and "boss" or "stairs"
 local critical,edges=path(f,1,exit.id);for i=2,#critical-1 do local r=f.rooms[critical[i]];r.type=i==2 and "treasure" or "combat" end
 for i=1,#f.rooms do if not f.rooms[i].type then f.rooms[i].type=roll(3)==1 and "event" or "combat" end end
 local maxLocks=math.min(lockCount,math.max(0,#edges-1));for i=1,maxLocks do local edgeIndex=#edges-i+1;local keyRoom=f.rooms[critical[edgeIndex]];local edge=edges[edgeIndex];edge.lockId=i;keyRoom.keys=keyRoom.keys or {};keyRoom.keys[#keyRoom.keys+1]=i;f.locks[#f.locks+1]={id=i,edge=edge,keyRoomId=keyRoom.id} end
 return f
end
function T:Generate(options)
 options=options or {};local roll=rng(options.seed);local count=math.max(3,math.min(24,math.floor(tonumber(options.roomsPerFloor) or 8)));local locks=math.max(0,math.min(4,math.floor(tonumber(options.locksPerFloor) or 1)));local floors={newFloor(1,count,locks,roll),newFloor(2,count,locks,roll)}
 floors[1].rooms[floors[1].exitRoomId].stairsDown={floor=2,roomId=1};floors[2].rooms[1].stairsUp={floor=1,roomId=floors[1].exitRoomId}
 return {seed=math.floor(tonumber(options.seed) or 1),tilesetId=options.tilesetId or "INSIDE_A2",roomCols=options.roomCols or 18,roomRows=options.roomRows or 12,floors=floors}
end
function T:GetRoom(dungeon,floor,id)local f=dungeon and dungeon.floors and dungeon.floors[floor];return f and f.rooms[id] end
function T:Validate(dungeon)
 if not dungeon or not dungeon.floors or #dungeon.floors~=2 then return false,"missing_floors" end
 for fi=1,2 do local f=dungeon.floors[fi];if not f or not f.rooms[1] or not f.rooms[f.exitRoomId] then return false,"missing_rooms" end;for i=1,#f.links do local e=f.links[i];local a,b=f.rooms[e.a],f.rooms[e.b];if not a or not b or not a.doors[e.from] or not b.doors[e.to] then return false,"broken_door" end end;for i=1,#f.locks do local lock=f.locks[i];local r=f.rooms[lock.keyRoomId];if not lock.edge.lockId or not r or not r.keys then return false,"broken_lock" end end;local rooms=path(f,1,f.exitRoomId);if not rooms then return false,"exit_unreachable" end end
 return true
end