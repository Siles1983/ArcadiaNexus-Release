--[[
    ArcadiaNexus – Core/TopDown/Tileset.lua
    Cave-Atlas (16px), 4-Richtungs-Autotile, Wandschatten.
    Generator: _tools/gen_td_cave_tileset.py
]]

local AN = _G.ArcadiaNexus
AN.TD_Tileset = {}
local T = AN.TD_Tileset

T.ATLAS = "Interface\\AddOns\\ArcadiaNexus\\Core\\TopDown\\assets\\cave_atlas"
T.TILE = 16
T.COLS = 16
T.ROWS = 16

local N, E, S, W = 1, 2, 4, 8
local WHITE = "Interface\\Buttons\\WHITE8X8"

local OVERLAY_COL = {
    K = 0, M = 1, G = 2, P = 4, U = 5, X = 6, F = 7,
}
-- cluster uses col 3
OVERLAY_COL["Q"] = 3

local ENTITY_COL = {
    chest = 0, door = 2, switch = 4, spawn = 6, warp = 7,
}

local function Ser()
    return AN.TD_Serialize
end

function T.IsCave(map)
    local id = map and map.tileset
    return id == "cave" or id == "dungeon"
end

function T.UV(col, row)
    local c, r = T.COLS, T.ROWS
    return col / c, (col + 1) / c, row / r, (row + 1) / r
end

function T.Apply(tex, col, row, a)
    if not tex then return end
    tex:SetTexture(T.ATLAS)
    local u0, u1, v0, v1 = T.UV(col, row)
    tex:SetTexCoord(u0, u1, v0, v1)
    tex:SetVertexColor(1, 1, 1, a or 1)
    tex:SetAlpha(a or 1)
end

function T.ClearColor(tex)
    tex:SetTexture(WHITE)
    tex:SetTexCoord(0, 1, 0, 1)
end

function T.Coll(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then
        return "#"
    end
    return Ser().GetCell(map.layers.collision, x, y)
end

function T.GroundCh(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then
        return "."
    end
    return Ser().GetCell(map.layers.ground, x, y)
end

function T.Mask(map, x, y, pred)
    local m = 0
    if pred(x, y - 1) then m = m + N end
    if pred(x + 1, y) then m = m + E end
    if pred(x, y + 1) then m = m + S end
    if pred(x - 1, y) then m = m + W end
    return m
end

function T.IsWall(map, x, y)
    return T.Coll(map, x, y) == "#"
end

function T.IsWater(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then
        return false
    end
    if T.GroundCh(map, x, y) == "l" then return false end
    return T.GroundCh(map, x, y) == "w" or T.Coll(map, x, y) == "~"
end

function T.IsLava(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then
        return false
    end
    return T.GroundCh(map, x, y) == "l"
end

function T.IsPit(map, x, y)
    return T.Coll(map, x, y) == "o"
end

local function floorCol(ch, x, y)
    local v = (x * 3 + y * 7) % 2
    if ch == "s" then return 2 + v end
    if ch == "c" then return 4 + v end
    if ch == "p" then return 2 end
    if ch == "a" then return v end
    if ch == "k" then return 6 end
    if ch == "m" then return 7 end
    return v
end

function T.Place(tex, parent, x, y, ts)
    ts = ts or T.TILE
    tex:SetSize(ts, ts)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", (x - 1) * ts, -(y - 1) * ts)
end

function T.PaintCell(acquire, parent, map, x, y, opts)
    opts = opts or {}
    local ts = opts.tileSize or T.TILE
    local coll = T.Coll(map, x, y)
    local gch = T.GroundCh(map, x, y)
    local tex = acquire(parent, "BACKGROUND")
    T.Place(tex, parent, x, y, ts)

    if coll == "#" then
        T.Apply(tex, T.Mask(map, x, y, function(cx, cy) return T.IsWall(map, cx, cy) end), 0)
    elseif T.IsLava(map, x, y) then
        T.Apply(tex, T.Mask(map, x, y, function(cx, cy) return T.IsLava(map, cx, cy) end), 2)
    elseif T.IsWater(map, x, y) then
        T.Apply(tex, T.Mask(map, x, y, function(cx, cy) return T.IsWater(map, cx, cy) end), 1)
    elseif coll == "o" then
        T.Apply(tex, T.Mask(map, x, y, function(cx, cy) return T.IsPit(map, cx, cy) end), 4)
    else
        T.Apply(tex, floorCol(gch, x, y), 5)
    end

    if coll ~= "#" and coll ~= "o" then
        local sm = T.Mask(map, x, y, function(cx, cy) return T.IsWall(map, cx, cy) end)
        if sm > 0 then
            local sh = acquire(parent, "BORDER")
            T.Place(sh, parent, x, y, ts)
            T.Apply(sh, sm, 3)
        end
    end

    local och = Ser().GetCell(map.layers.overlay, x, y)
    local oc = OVERLAY_COL[och]
    if oc then
        local ot = acquire(parent, "ARTWORK")
        T.Place(ot, parent, x, y, ts)
        T.Apply(ot, oc, 6)
    elseif och ~= "." then
        local oi = AN.TD_Catalog.Overlay(och)
        local ot = acquire(parent, "ARTWORK")
        T.Place(ot, parent, x, y, ts)
        T.ClearColor(ot)
        ot:SetVertexColor(oi.r, oi.g, oi.b, 0.85)
    end

    if opts.collisionTint and coll ~= "." then
        local ci = AN.TD_Catalog.COLLISION[coll]
        if ci then
            local ct = acquire(parent, "OVERLAY")
            T.Place(ct, parent, x, y, ts)
            T.ClearColor(ct)
            ct:SetVertexColor(ci.r, ci.g, ci.b, opts.collisionTint)
        end
    end
end

function T.PaintEntity(tex, parent, e, ts, opened)
    ts = ts or T.TILE
    local col = ENTITY_COL[e.type]
    if not col then return false end
    if opened and (e.type == "chest" or e.type == "door" or e.type == "switch") then
        col = col + 1
    end
    T.Place(tex, parent, e.x, e.y, ts)
    T.Apply(tex, col, 7)
    return true
end

function T.PaintPlayer(tex, parent, x, y, ts)
    T.Place(tex, parent, x, y, ts or T.TILE)
    T.Apply(tex, 8, 7)
end
