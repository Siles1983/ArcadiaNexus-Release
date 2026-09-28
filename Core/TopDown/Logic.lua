--[[
    ArcadiaNexus – Core/TopDown/Logic.lua
    Welle 1: Laufen, Kollision, Warps, Flags, Tuer, Truhe, Kamera-Follow.
    Kein UI.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TD_Logic = {}
local L = ArcadiaNexus.TD_Logic

local function Cat()
    return ArcadiaNexus.TD_Catalog
end

local function Ser()
    return ArcadiaNexus.TD_Serialize
end

local function CurrentMap(gs)
    return Ser().FindMap(gs.world, gs.mapId)
end

local function DoorBlocks(gs, map, x, y)
    for i = 1, #(map.entities or {}) do
        local e = map.entities[i]
        if e.type == "door" and e.x == x and e.y == y then
            if not gs.flags[e.flag] then
                return true
            end
        end
    end
    return false
end

function L:IsWalkable(gs, x, y, map)
    map = map or CurrentMap(gs)
    if not map then return false end
    if x < 1 or y < 1 or x > map.width or y > map.height then
        return false
    end
    local ch = Ser().GetCell(map.layers.collision, x, y)
    if not Cat().CollisionWalkable(ch) then
        return false
    end
    if DoorBlocks(gs, map, x, y) then
        return false
    end
    return true
end

function L:PlaceAtSpawn(gs, map, spawnId)
    local sp = Ser().FindSpawn(map, spawnId or "start")
    if not sp then
        gs.player.x, gs.player.y = 2, 2
        return
    end
    gs.player.x, gs.player.y = sp.x, sp.y
end

function L:UpdateCamera(gs)
    local map = CurrentMap(gs)
    if not map then return end
    local ts = gs.tileSize
    local px = (gs.player.x - 0.5) * ts
    local py = (gs.player.y - 0.5) * ts
    gs.player.px, gs.player.py = px, py
    local vw = gs.viewW or 320
    local vh = gs.viewH or 240
    local maxX = math.max(0, map.width * ts - vw)
    local maxY = math.max(0, map.height * ts - vh)
    gs.camX = math.max(0, math.min(maxX, px - vw * 0.5))
    gs.camY = math.max(0, math.min(maxY, py - vh * 0.5))
end

local function ApplyChest(gs, e)
    if gs.flags[e.flag] then
        return "chest_empty"
    end
    gs.flags[e.flag] = true
    if e.loot and e.loot ~= "" then
        gs.flags[e.loot] = true
        gs.inventory[e.loot] = true
    end
    if e.flag == "demo_done" or e.loot == "demo_done" then
        gs.won = true
        gs.state = "WON"
        return "won"
    end
    return "chest"
end

local function ApplySwitch(gs, e)
    if e.mode == "once" and gs.flags[e.flag] then
        return "switch_noop"
    end
    gs.flags[e.flag] = not gs.flags[e.flag]
    return "switch"
end

function L:WarpTo(gs, targetMap, targetSpawn)
    local dest = Ser().FindMap(gs.world, targetMap)
    if not dest then
        return false
    end
    gs.mapId = dest.id
    gs.map = dest
    self:PlaceAtSpawn(gs, dest, targetSpawn)
    self:UpdateCamera(gs)
    if gs.won then
        return true
    end
    return true
end

local function AfterStep(self, gs, map, x, y)
    for i = 1, #(map.entities or {}) do
        local e = map.entities[i]
        if e.x == x and e.y == y then
            if e.type == "warp" then
                self:WarpTo(gs, e.targetMap, e.targetSpawn)
                return gs.won and "won" or "warp"
            elseif e.type == "switch" then
                return ApplySwitch(gs, e)
            elseif e.type == "chest" then
                return ApplyChest(gs, e)
            end
        end
    end
    return "move"
end

function L:NewBoard(world, opts)
    opts = opts or {}
    world = Ser().NormalizeWorld(world)
    local C = Cat()
    local gs = {
        world = world,
        tileSize = world.tileSize or C.TILE,
        mapId = opts.mapId or world.start.map,
        flags = {},
        inventory = {},
        won = false,
        state = "PLAYING",
        player = { x = 2, y = 2, facing = "down" },
        viewW = opts.viewW or 320,
        viewH = opts.viewH or 240,
        camX = 0,
        camY = 0,
        moveLock = 0,
    }
    local map = Ser().FindMap(world, gs.mapId)
    if not map then
        map = world.maps[1]
        gs.mapId = map.id
    end
    gs.map = map
    self:PlaceAtSpawn(gs, map, opts.spawnId or world.start.spawn)
    if not self:IsWalkable(gs, gs.player.x, gs.player.y, map) then
        -- Spawn may sit on a walk tile; if not, search a neighbour.
        for dy = -1, 1 do
            for dx = -1, 1 do
                if self:IsWalkable(gs, gs.player.x + dx, gs.player.y + dy, map) then
                    gs.player.x = gs.player.x + dx
                    gs.player.y = gs.player.y + dy
                    break
                end
            end
        end
    end
    self:UpdateCamera(gs)
    return gs
end

function L:SetViewSize(gs, w, h)
    if not gs then return end
    gs.viewW, gs.viewH = w, h
    self:UpdateCamera(gs)
end

function L:TryMove(gs, dx, dy)
    if not gs or gs.won or gs.state ~= "PLAYING" then
        return false, "ended"
    end
    dx = dx or 0
    dy = dy or 0
    if dx == 0 and dy == 0 then
        return false, "idle"
    end
    if dy < 0 then gs.player.facing = "up"
    elseif dy > 0 then gs.player.facing = "down"
    elseif dx < 0 then gs.player.facing = "left"
    else gs.player.facing = "right" end

    local map = CurrentMap(gs)
    local nx, ny = gs.player.x + dx, gs.player.y + dy
    if not self:IsWalkable(gs, nx, ny, map) then
        return false, "blocked"
    end
    gs.player.x, gs.player.y = nx, ny
    local result = AfterStep(self, gs, CurrentMap(gs), nx, ny)
    self:UpdateCamera(gs)
    return true, result
end

function L:Update(gs, dt)
    if not gs or gs.state ~= "PLAYING" then return end
    dt = dt or 0
    if gs.moveLock and gs.moveLock > 0 then
        gs.moveLock = math.max(0, gs.moveLock - dt)
    end
    self:UpdateCamera(gs)
end

function L:HasItem(gs, id)
    return gs and gs.inventory and gs.inventory[id] == true
end
