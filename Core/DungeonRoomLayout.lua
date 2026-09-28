-- Converts a topology room into a fixed Zelda-style tile layout.
local A=_G.ArcadiaNexus
A.DungeonRoomLayout={}
local R=A.DungeonRoomLayout
local function cell(ground,object,blocked) return {ground=ground,object=object,blocked=blocked and true or false} end
local function doorway(cells,side,door)
  local slots={north={{9,1},{10,1}},south={{9,12},{10,12}},west={{1,6},{1,7}},east={{18,6},{18,7}}}
  for _,p in ipairs(slots[side]) do cells[p[2]][p[1]]=cell(nil,door,false) end
end
function R:Build(room,tileset,paletteId)
  assert(room and tileset,"room and tileset required")
  local palette=tileset.palettes[paletteId or "crypt"] or tileset.palettes.crypt
  local cols,rows=tileset.roomCols,tileset.roomRows; local cells={}
  for y=1,rows do cells[y]={}; for x=1,cols do
    local edge=x==1 or x==cols or y==1 or y==rows
    cells[y][x]=cell(palette.floor,edge and palette.wall or nil,edge)
  end end
  for side,door in pairs(room.doors or {}) do doorway(cells,side,door.edge and door.edge.lockId and "door_locked" or palette.door) end
  local layout={cols=cols,rows=rows,cells=cells,spawn={x=math.floor(cols/2),y=math.floor(rows/2)},doorSpawns={north={x=9,y=2},south={x=9,y=rows-1},west={x=2,y=6},east={x=cols-1,y=6}}}
  local function object(x,y,id,blocked)
    if x>1 and x<cols and y>1 and y<rows and not (x==layout.spawn.x and y==layout.spawn.y) then cells[y][x]=cell(palette.floor,id,blocked) end
  end
  if room.type=="start" then
    object(4,3,"torch_wall",false); object(cols-3,3,"torch_wall",false)
  elseif room.type=="combat" then
    for _,p in ipairs({{6,4},{13,4},{6,9},{13,9}}) do object(p[1],p[2],"pillar_stone",true) end
  elseif room.type=="treasure" then
    object(layout.spawn.x,layout.spawn.y-2,"chest_gold",true)
    object(layout.spawn.x-2,layout.spawn.y,"floor_carpet",false); object(layout.spawn.x+2,layout.spawn.y,"floor_carpet",false)
  elseif room.type=="event" then
    for y=5,8 do for x=7,12 do object(x,y,"floor_carpet",false) end end
  elseif room.type=="boss" then
    for _,p in ipairs({{5,3},{14,3},{5,10},{14,10}}) do object(p[1],p[2],"pillar_stone",true) end
  end
  if room.keys and #room.keys>0 then object(layout.spawn.x-2,layout.spawn.y-2,"chest_gold",true) end
  return layout
end
function R:IsWalkable(layout,x,y) return layout and layout.cells[y] and layout.cells[y][x] and not layout.cells[y][x].blocked or false end
function R:Validate(layout)
  if not layout or not self:IsWalkable(layout,layout.spawn.x,layout.spawn.y) then return false,"blocked_spawn" end
  for _,p in pairs(layout.doorSpawns) do if not self:IsWalkable(layout,p.x,p.y) then return false,"blocked_door" end end
  return true
end