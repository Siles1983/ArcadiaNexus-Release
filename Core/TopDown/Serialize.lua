--[[
    ArcadiaNexus – Core/TopDown/Serialize.lua
    World/Map encode, Blank, Validate, Lua-Export (Schema v1).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TD_Serialize = {}
local Ser = ArcadiaNexus.TD_Serialize

local function Cat()
    return ArcadiaNexus.TD_Catalog
end

local function Rep(ch, n)
    return string.rep(ch, n)
end

local function PadRow(row, w, fill)
    row = tostring(row or "")
    if #row < w then
        return row .. Rep(fill, w - #row)
    end
    if #row > w then
        return row:sub(1, w)
    end
    return row
end

local function LayerRows(w, h, fill, border)
    local rows = {}
    for y = 1, h do
        if border and (y == 1 or y == h) then
            rows[y] = Rep(border, w)
        else
            local mid = Rep(fill, math.max(0, w - 2))
            rows[y] = (border or fill) .. mid .. (border or fill)
            if w == 1 then
                rows[y] = border or fill
            end
        end
        rows[y] = PadRow(rows[y], w, fill)
    end
    return rows
end

function Ser.GetCell(rows, x, y)
    local row = rows and rows[y]
    if type(row) ~= "string" then return "." end
    local ch = row:sub(x, x)
    if ch == "" then return "." end
    return ch
end

function Ser.SetCell(rows, x, y, ch, w)
    if not rows or not rows[y] then return false end
    local row = rows[y]
    if x < 1 or x > (w or #row) then return false end
    ch = tostring(ch or "."):sub(1, 1)
    local newRow = row:sub(1, x - 1) .. ch .. row:sub(x + 1)
    if newRow == row then return false end
    rows[y] = newRow
    return true
end

function Ser.FindMap(world, mapId)
    if type(world) ~= "table" or type(world.maps) ~= "table" then return nil end
    for i = 1, #world.maps do
        local m = world.maps[i]
        if m and m.id == mapId then
            return m, i
        end
    end
    return nil
end

function Ser.FindEntity(map, pred)
    if type(map) ~= "table" or type(map.entities) ~= "table" then return nil end
    for i = 1, #map.entities do
        local e = map.entities[i]
        if e and pred(e, i) then
            return e, i
        end
    end
    return nil
end

function Ser.EntityAt(map, x, y)
    return Ser.FindEntity(map, function(e)
        return e.x == x and e.y == y
    end)
end

function Ser.FindSpawn(map, spawnId)
    spawnId = spawnId or "start"
    local named = Ser.FindEntity(map, function(e)
        return e.type == "spawn" and e.id == spawnId
    end)
    if named then return named end
    return Ser.FindEntity(map, function(e)
        return e.type == "spawn"
    end)
end

local function NormalizeLayer(raw, w, h, fill)
    local rows = {}
    if type(raw) ~= "table" then
        for y = 1, h do
            rows[y] = Rep(fill, w)
        end
        return rows
    end
    for y = 1, h do
        rows[y] = PadRow(raw[y], w, fill)
    end
    return rows
end

local function CopyEntity(e)
    if type(e) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(e) do
        if type(v) ~= "table" then
            out[k] = v
        end
    end
    out.type = tostring(e.type or "")
    out.x = math.floor(tonumber(e.x) or 1)
    out.y = math.floor(tonumber(e.y) or 1)
    return out
end

function Ser.NormalizeMap(raw, worldId)
    local C = Cat()
    raw = raw or {}
    local w = C.ClampSize(raw.width, 16)
    local h = C.ClampSize(raw.height, 12)
    local layers = raw.layers or {}
    local map = {
        id = tostring(raw.id or worldId or "map"),
        name = tostring(raw.name or raw.id or "Map"),
        width = w,
        height = h,
        camera = (raw.camera == "room") and "room" or "follow",
        tileset = tostring(raw.tileset or C.DEFAULT_TILESET),
        layers = {
            ground = NormalizeLayer(layers.ground, w, h, "."),
            collision = NormalizeLayer(layers.collision, w, h, "."),
            overlay = NormalizeLayer(layers.overlay, w, h, "."),
        },
        entities = {},
    }
    local ents = raw.entities
    if type(ents) == "table" then
        for i = 1, #ents do
            local e = CopyEntity(ents[i])
            if e and e.type ~= "" then
                e.x = math.max(1, math.min(w, e.x))
                e.y = math.max(1, math.min(h, e.y))
                map.entities[#map.entities + 1] = e
            end
        end
    end
    return map
end

function Ser.NormalizeWorld(raw)
    local C = Cat()
    raw = raw or {}
    local world = {
        schemaVersion = C.SCHEMA_VERSION,
        id = tostring(raw.id or "draft"),
        tileSize = C.TILE,
        start = {
            map = tostring((raw.start and raw.start.map) or "overworld"),
            spawn = tostring((raw.start and raw.start.spawn) or "start"),
        },
        maps = {},
    }
    local maps = raw.maps
    if type(maps) ~= "table" or #maps == 0 then
        world.maps[1] = Ser.BlankMap("overworld", "Overworld", 16, 12)
        world.start.map = "overworld"
        return world
    end
    local n = math.min(#maps, C.MAX_MAPS)
    for i = 1, n do
        world.maps[i] = Ser.NormalizeMap(maps[i])
    end
    if not Ser.FindMap(world, world.start.map) then
        world.start.map = world.maps[1].id
    end
    return world
end

function Ser.BlankMap(id, name, w, h, opts)
    local C = Cat()
    w = C.ClampSize(w, 16)
    h = C.ClampSize(h, 12)
    opts = opts or {}
    local fill = opts.fill or "."
    local wall = opts.wall or "#"
    local groundFill = opts.ground or (id == "cave" and "c" or ".")
    local map = {
        id = id or "overworld",
        name = name or "Overworld",
        width = w,
        height = h,
        camera = "follow",
        tileset = C.DEFAULT_TILESET,
        layers = {
            ground = LayerRows(w, h, groundFill, "s"),
            collision = LayerRows(w, h, ".", wall),
            overlay = LayerRows(w, h, ".", nil),
        },
        entities = {
            { id = opts.spawnId or "start", type = "spawn", x = 3, y = math.floor(h / 2) },
        },
    }
    map.layers.overlay = NormalizeLayer(map.layers.overlay, w, h, ".")
    if map.entities[1].x > w then map.entities[1].x = 2 end
    if map.entities[1].y > h then map.entities[1].y = 2 end
    return map
end

function Ser.BlankWorld()
    local C = Cat()
    return {
        schemaVersion = C.SCHEMA_VERSION,
        id = "draft",
        tileSize = C.TILE,
        start = { map = "overworld", spawn = "start" },
        maps = { Ser.BlankMap("overworld", "Overworld", 16, 12) },
    }
end

function Ser.ResizeMap(map, dw, dh)
    local C = Cat()
    if not map then return false end
    local nw = C.ClampSize(map.width + (dw or 0), map.width)
    local nh = C.ClampSize(map.height + (dh or 0), map.height)
    if nw == map.width and nh == map.height then return false end
    map.layers.ground = NormalizeLayer(map.layers.ground, nw, nh, ".")
    map.layers.collision = NormalizeLayer(map.layers.collision, nw, nh, ".")
    map.layers.overlay = NormalizeLayer(map.layers.overlay, nw, nh, ".")
    -- Keep border walls if the old map had them on the last row/col.
    if dw ~= 0 or dh ~= 0 then
        for y = 1, nh do
            Ser.SetCell(map.layers.collision, 1, y, "#", nw)
            Ser.SetCell(map.layers.collision, nw, y, "#", nw)
        end
        for x = 1, nw do
            Ser.SetCell(map.layers.collision, x, 1, "#", nw)
            Ser.SetCell(map.layers.collision, x, nh, "#", nw)
        end
    end
    map.width, map.height = nw, nh
    local keep = {}
    for i = 1, #map.entities do
        local e = map.entities[i]
        if e.x >= 1 and e.x <= nw and e.y >= 1 and e.y <= nh then
            keep[#keep + 1] = e
        end
    end
    map.entities = keep
    return true
end

function Ser.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = Ser.DeepCopy(v)
    end
    return out
end

local function EscapeLua(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n")
    return s
end

local function DumpScalar(v)
    local tv = type(v)
    if tv == "number" then
        return tostring(v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif v == nil then
        return "nil"
    end
    return '"' .. EscapeLua(v) .. '"'
end

local function DumpEntity(e, indent)
    local keys = {}
    for k in pairs(e) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local order = { type = 1, id = 2, x = 3, y = 4 }
        local oa, ob = order[a] or 50, order[b] or 50
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        local v = e[k]
        if type(v) ~= "table" then
            parts[#parts + 1] = string.format("%s = %s", k, DumpScalar(v))
        end
    end
    return indent .. "{ " .. table.concat(parts, ", ") .. " },"
end

local function DumpLayer(name, rows, indent)
    local lines = { indent .. name .. " = {" }
    for y = 1, #rows do
        lines[#lines + 1] = indent .. '    "' .. EscapeLua(rows[y]) .. '",'
    end
    lines[#lines + 1] = indent .. "},"
    return lines
end

function Ser.MapToLuaLines(map, indent)
    indent = indent or ""
    map = Ser.NormalizeMap(map)
    local lines = {
        indent .. "{",
    }
    local inner = indent .. "    "
    lines[#lines + 1] = string.format(
        '%sid = "%s", name = "%s", width = %d, height = %d, camera = "%s", tileset = "%s",',
        inner, EscapeLua(map.id), EscapeLua(map.name), map.width, map.height,
        EscapeLua(map.camera), EscapeLua(map.tileset))
    lines[#lines + 1] = inner .. "layers = {"
    local ground = DumpLayer("ground", map.layers.ground, inner .. "    ")
    local coll = DumpLayer("collision", map.layers.collision, inner .. "    ")
    local over = DumpLayer("overlay", map.layers.overlay, inner .. "    ")
    for i = 1, #ground do lines[#lines + 1] = ground[i] end
    for i = 1, #coll do lines[#lines + 1] = coll[i] end
    for i = 1, #over do lines[#lines + 1] = over[i] end
    lines[#lines + 1] = inner .. "},"
    lines[#lines + 1] = inner .. "entities = {"
    for i = 1, #map.entities do
        lines[#lines + 1] = DumpEntity(map.entities[i], inner .. "    ")
    end
    lines[#lines + 1] = inner .. "},"
    lines[#lines + 1] = indent .. "}"
    return lines
end

function Ser.ToLuaMap(map)
    local lines = { "-- TopDown Editor Map Export (schema v1)" }
    local body = Ser.MapToLuaLines(map, "")
    for i = 1, #body do
        lines[#lines + 1] = body[i]
    end
    return table.concat(lines, "\n")
end

function Ser.ToLuaWorld(world)
    world = Ser.NormalizeWorld(world)
    local lines = {
        "-- TopDown Editor World Export (schema v1)",
        "{",
        string.format('    schemaVersion = %d, id = "%s", tileSize = %d,',
            world.schemaVersion, EscapeLua(world.id), world.tileSize),
        string.format('    start = { map = "%s", spawn = "%s" },',
            EscapeLua(world.start.map), EscapeLua(world.start.spawn)),
        "    maps = {",
    }
    for i = 1, #world.maps do
        local body = Ser.MapToLuaLines(world.maps[i], "        ")
        body[#body] = body[#body] .. ","
        for j = 1, #body do
            lines[#lines + 1] = body[j]
        end
    end
    lines[#lines + 1] = "    },"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

--- Prueft World auf Export-Fehler.
--- @return { ok, errors, warns, issues }
function Ser.Validate(world)
    local C = Cat()
    local issues = {}
    local function add(sev, code, msg, mapId, x, y)
        issues[#issues + 1] = { sev = sev, code = code, msg = msg, mapId = mapId, x = x, y = y }
    end

    if type(world) ~= "table" or type(world.maps) ~= "table" or #world.maps == 0 then
        add("error", "empty", "Keine World / keine Maps.")
        return { ok = false, errors = 1, warns = 0, issues = issues }
    end

    world = Ser.NormalizeWorld(world)

    if #world.maps > C.MAX_MAPS then
        add("error", "too_many_maps", "Mehr als " .. C.MAX_MAPS .. " Maps.")
    end

    local startMap = Ser.FindMap(world, world.start.map)
    if not startMap then
        add("error", "bad_start_map", "Start-Map fehlt: " .. tostring(world.start.map))
    else
        local sp = Ser.FindSpawn(startMap, world.start.spawn)
        if not sp then
            add("error", "no_spawn", "Start-Spawn fehlt auf Map " .. startMap.id .. ".", startMap.id)
        end
    end

    local mapIds = {}
    for i = 1, #world.maps do
        local map = world.maps[i]
        if mapIds[map.id] then
            add("error", "dup_map", "Doppelte Map-ID: " .. map.id, map.id)
        end
        mapIds[map.id] = map

        for y = 1, map.height do
            for _, layerName in ipairs({ "ground", "collision", "overlay" }) do
                local row = map.layers[layerName][y]
                if type(row) ~= "string" or #row ~= map.width then
                    add("error", "layer_len",
                        string.format("Layer %s Zeile %d hat Laenge %s, erwartet %d.",
                            layerName, y, type(row) == "string" and tostring(#row) or "nil", map.width),
                        map.id, 1, y)
                    break
                end
            end
            for x = 1, map.width do
                local ch = Ser.GetCell(map.layers.collision, x, y)
                if not C.IsCollision(ch) then
                    add("error", "bad_col",
                        string.format("Unbekanntes Collision-Zeichen '%s' bei %d,%d.", ch, x, y),
                        map.id, x, y)
                end
            end
        end

        local spawns = 0
        for ei = 1, #map.entities do
            local e = map.entities[ei]
            if e.type == "spawn" then
                spawns = spawns + 1
            end
            if not C.IsKnownEntity(e.type) then
                add("error", "bad_ent",
                    string.format("Unbekannter Entity-Typ '%s' bei %d,%d.", tostring(e.type), e.x, e.y),
                    map.id, e.x, e.y)
            elseif C.IsEntityReserved(e.type) then
                add("warn", "reserved_ent",
                    string.format("Reserviert (Welle 2, ignoriert): %s bei %d,%d.", e.type, e.x, e.y),
                    map.id, e.x, e.y)
            end
            if e.type == "warp" then
                if not e.targetMap or e.targetMap == "" then
                    add("error", "warp_no_map",
                        string.format("Warp bei %d,%d ohne targetMap.", e.x, e.y), map.id, e.x, e.y)
                end
            end
            if (e.type == "switch" or e.type == "door" or e.type == "chest") and (not e.flag or e.flag == "") then
                add("error", "no_flag",
                    string.format("%s bei %d,%d ohne flag.", e.type, e.x, e.y), map.id, e.x, e.y)
            end
        end
        if spawns == 0 then
            add("warn", "map_no_spawn", "Map ohne Spawn: " .. map.id, map.id)
        end
    end

    for i = 1, #world.maps do
        local map = world.maps[i]
        for ei = 1, #map.entities do
            local e = map.entities[ei]
            if e.type == "warp" and e.targetMap and e.targetMap ~= "" then
                local dest = mapIds[e.targetMap]
                if not dest then
                    add("error", "warp_missing_map",
                        string.format("Warp bei %s %d,%d zeigt auf unbekannte Map '%s'.",
                            map.id, e.x, e.y, tostring(e.targetMap)),
                        map.id, e.x, e.y)
                else
                    local sp = Ser.FindSpawn(dest, e.targetSpawn or "start")
                    if not sp then
                        add("error", "warp_missing_spawn",
                            string.format("Warp-Ziel-Spawn '%s' fehlt auf Map '%s'.",
                                tostring(e.targetSpawn or "start"), dest.id),
                            map.id, e.x, e.y)
                    end
                end
            end
        end
    end

    local errors, warns = 0, 0
    for i = 1, #issues do
        if issues[i].sev == "error" then
            errors = errors + 1
        else
            warns = warns + 1
        end
    end
    return { ok = errors == 0, errors = errors, warns = warns, issues = issues }
end
