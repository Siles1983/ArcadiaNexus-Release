--[[
    ArcadiaNexus – Dev/LevelEditor/Serialize.lua
    Grid <-> AA-kompatibler Level-Eintrag / Lua-Text.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LevelEditorSerialize = {}
local Ser = ArcadiaNexus.LevelEditorSerialize

local function Rep(ch, n)
    return string.rep(ch, n)
end

local function SetChar(row, col, ch)
    local w = #row
    if col < 1 or col > w then return row end
    return row:sub(1, col - 1) .. ch .. row:sub(col + 1)
end

function Ser.Blank(w, h)
    w = math.max(20, math.floor(w or 80))
    h = math.max(8, math.floor(h or 24))
    local rows = {}
    for r = 1, h do
        if r == h then
            rows[r] = Rep(".", w)
        elseif r == h - 1 then
            rows[r] = Rep("#", w)
        else
            rows[r] = Rep(".", w)
        end
    end
    local play = h - 2
    rows[play] = SetChar(rows[play], 3, "P")
    rows[play] = SetChar(rows[play], w - 2, "G")
    return {
        name = "Draft",
        width = w,
        height = h,
        theme = "day",
        parallax = "theme",
        game = "AZEROTH_ASCENT",
        rows = rows,
        blocks = {},
        pipes = {},
        mobs = {},
        props = {},
    }
end

local function BlockKey(col, row)
    return tostring(col) .. ":" .. tostring(row)
end

function Ser.NormalizeBlocks(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local function accept(col, row, contents)
        col, row = tonumber(col), tonumber(row)
        if not col or not row then return end
        if not contents or contents == "" or (Cat and not Cat.IsQBlockContents(contents)) then
            contents = "random"
        end
        out[BlockKey(col, row)] = { col = col, row = row, contents = contents }
    end
    if raw[1] then
        for i = 1, #raw do
            local b = raw[i]
            if type(b) == "table" then
                accept(b.col, b.row, b.contents or "random")
            end
        end
    else
        for _, b in pairs(raw) do
            if type(b) == "table" then
                accept(b.col, b.row, b.contents or "random")
            end
        end
    end
    return out
end

function Ser.BlocksList(draft)
    local list = {}
    for _, b in pairs(draft.blocks or {}) do
        if type(b) == "table" then
            list[#list + 1] = b
        end
    end
    table.sort(list, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return list
end

function Ser.GetBlockContents(draft, col, row)
    local b = draft.blocks and draft.blocks[BlockKey(col, row)]
    return (b and b.contents) or "random"
end

function Ser.SetBlockContents(draft, col, row, contents)
    draft.blocks = draft.blocks or {}
    if Ser.Get(draft, col, row) ~= "?" then
        draft.blocks[BlockKey(col, row)] = nil
        return
    end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    if not contents or contents == "" or (Cat and not Cat.IsQBlockContents(contents)) then
        contents = "random"
    end
    draft.blocks[BlockKey(col, row)] = { col = col, row = row, contents = contents }
end

function Ser.PruneBlocks(draft)
    draft.blocks = draft.blocks or {}
    local drop = {}
    for key, b in pairs(draft.blocks) do
        if type(b) ~= "table" or Ser.Get(draft, b.col, b.row) ~= "?" then
            drop[#drop + 1] = key
        end
    end
    for i = 1, #drop do
        draft.blocks[drop[i]] = nil
    end
end

function Ser.NormalizePipes(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local function accept(col, row, pair)
        col, row = tonumber(col), tonumber(row)
        if not col or not row then return end
        pair = Cat and Cat.NormalizePipePair(pair) or 1
        out[BlockKey(col, row)] = { col = col, row = row, pair = pair }
    end
    if raw[1] then
        for i = 1, #raw do
            local p = raw[i]
            if type(p) == "table" then
                accept(p.col, p.row, p.pair)
            end
        end
    else
        for _, p in pairs(raw) do
            if type(p) == "table" then
                accept(p.col, p.row, p.pair)
            end
        end
    end
    return out
end

function Ser.PipesList(draft)
    local list = {}
    for _, p in pairs(draft.pipes or {}) do
        if type(p) == "table" then
            list[#list + 1] = p
        end
    end
    table.sort(list, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return list
end

function Ser.GetPipePair(draft, col, row)
    local p = draft.pipes and draft.pipes[BlockKey(col, row)]
    return (p and p.pair) or 1
end

function Ser.SetPipePair(draft, col, row, pair)
    draft.pipes = draft.pipes or {}
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local ch = Ser.Get(draft, col, row)
    if not (Cat and Cat.IsPairChar(ch, draft.game)) then
        draft.pipes[BlockKey(col, row)] = nil
        return
    end
    pair = Cat.NormalizePipePair(pair) or 1
    draft.pipes[BlockKey(col, row)] = { col = col, row = row, pair = pair }
end

function Ser.PrunePipes(draft)
    draft.pipes = draft.pipes or {}
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local drop = {}
    for key, p in pairs(draft.pipes) do
        local ch = type(p) == "table" and Ser.Get(draft, p.col, p.row)
        if type(p) ~= "table" or not (Cat and Cat.IsPairChar(ch, draft.game)) then
            drop[#drop + 1] = key
        end
    end
    for i = 1, #drop do
        draft.pipes[drop[i]] = nil
    end
end

function Ser.NormalizeMobs(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local function accept(m)
        if type(m) ~= "table" then return end
        local col, row = tonumber(m.col), tonumber(m.row)
        if not col or not row then return end
        local patrol = Cat and Cat.NormalizePatrol(m.patrol) or 4
        local behavior = Cat and Cat.NormalizeMobBehavior(m.behavior) or "turn"
        out[BlockKey(col, row)] = {
            col = col, row = row, patrol = patrol, behavior = behavior,
        }
    end
    if raw[1] then
        for i = 1, #raw do accept(raw[i]) end
    else
        for _, m in pairs(raw) do accept(m) end
    end
    return out
end

function Ser.MobsList(draft)
    local list = {}
    for _, m in pairs(draft.mobs or {}) do
        if type(m) == "table" then list[#list + 1] = m end
    end
    table.sort(list, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return list
end

function Ser.GetMob(draft, col, row)
    local m = draft.mobs and draft.mobs[BlockKey(col, row)]
    return m or { patrol = 4, behavior = "turn" }
end

function Ser.SetMob(draft, col, row, opts)
    draft.mobs = draft.mobs or {}
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local ch = Ser.Get(draft, col, row)
    if not (Cat and Cat.IsMobChar(ch, draft.game)) then
        draft.mobs[BlockKey(col, row)] = nil
        return
    end
    draft.mobs[BlockKey(col, row)] = {
        col = col, row = row,
        patrol = Cat.NormalizePatrol(opts and opts.patrol),
        behavior = Cat.NormalizeMobBehavior(opts and opts.behavior),
    }
end

function Ser.PruneMobs(draft)
    draft.mobs = draft.mobs or {}
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local drop = {}
    for key, m in pairs(draft.mobs) do
        local ch = type(m) == "table" and Ser.Get(draft, m.col, m.row)
        if type(m) ~= "table" or not (Cat and Cat.IsMobChar(ch, draft.game)) then
            drop[#drop + 1] = key
        end
    end
    for i = 1, #drop do
        draft.mobs[drop[i]] = nil
    end
end

local function PropKey(col, row)
    return tostring(col) .. ":" .. tostring(row)
end

function Ser.NormalizeProps(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local function accept(p)
        local col, row = tonumber(p.col), tonumber(p.row)
        local kind = p.kind
        if not col or not row then return end
        if Cat and not Cat.IsPropKind(kind) then return end
        local rec = { col = col, row = row, kind = kind }
        if kind == "mover" or kind == "wind" then
            rec.axis = Cat and Cat.NormalizeMoverAxis(p.axis) or (p.axis == "v" and "v" or "h")
            rec.span = Cat and Cat.NormalizeMoverSpan(p.span) or 4
            rec.period = tonumber(p.period) or 3
        elseif kind == "spinner" then
            rec.spin = Cat and Cat.NormalizeSpin(p.spin) or "90"
        elseif kind == "camlock" then
            rec.cam = Cat and Cat.NormalizeCamLock(p.cam) or "xy"
            rec.span = Cat and Cat.NormalizeMoverSpan(p.span) or 4
        elseif kind == "lavaemit" or kind == "waterarc" then
            rec.dir = Cat and Cat.NormalizeEmitDir(p.dir) or "r"
        end
        out[PropKey(col, row)] = rec
    end
    if raw[1] then
        for i = 1, #raw do
            local p = raw[i]
            if type(p) == "table" then
                accept(p)
            end
        end
    else
        for _, p in pairs(raw) do
            if type(p) == "table" then
                accept(p)
            end
        end
    end
    return out
end

function Ser.PropsList(draft)
    local list = {}
    for _, p in pairs(draft.props or {}) do
        if type(p) == "table" then
            list[#list + 1] = p
        end
    end
    table.sort(list, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row < b.row
    end)
    return list
end

function Ser.GetProp(draft, col, row)
    local p = draft.props and draft.props[PropKey(col, row)]
    return p and p.kind or nil
end

function Ser.GetPropRecord(draft, col, row)
    return draft.props and draft.props[PropKey(col, row)] or nil
end

function Ser.ClearProp(draft, col, row)
    if not draft.props then return false end
    local key = PropKey(col, row)
    if not draft.props[key] then return false end
    draft.props[key] = nil
    return true
end

function Ser.SetProp(draft, col, row, kind, opts)
    if row < 1 or row > draft.height or col < 1 or col > draft.width then
        return false
    end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    if Cat and not Cat.IsPropKind(kind) then return false end
    draft.props = draft.props or {}
    local item = Cat and Cat.ByPropKind(kind)
    if item and item.unique then
        local drop = {}
        for key, p in pairs(draft.props) do
            if p.kind == kind and (p.col ~= col or p.row ~= row) then
                drop[#drop + 1] = key
            end
        end
        for i = 1, #drop do
            draft.props[drop[i]] = nil
        end
    end
    local rec = { col = col, row = row, kind = kind }
    if kind == "mover" or kind == "wind" then
        rec.axis = Cat and Cat.NormalizeMoverAxis(opts and opts.axis) or "h"
        rec.span = Cat and Cat.NormalizeMoverSpan(opts and opts.span) or 4
        rec.period = tonumber(opts and opts.period) or 3
    elseif kind == "spinner" then
        rec.spin = Cat and Cat.NormalizeSpin(opts and opts.spin) or "90"
    elseif kind == "camlock" then
        rec.cam = Cat and Cat.NormalizeCamLock(opts and opts.cam) or "xy"
        rec.span = Cat and Cat.NormalizeMoverSpan(opts and opts.span) or 4
    elseif kind == "lavaemit" or kind == "waterarc" then
        rec.dir = Cat and Cat.NormalizeEmitDir(opts and opts.dir) or "r"
    end
    local prev = draft.props[PropKey(col, row)]
    if prev and prev.kind == kind then
        if kind == "mover" or kind == "wind" then
            if prev.axis == rec.axis and prev.span == rec.span and prev.period == rec.period then
                return false
            end
        elseif kind == "spinner" then
            if prev.spin == rec.spin then return false end
        elseif kind == "camlock" then
            if prev.cam == rec.cam and prev.span == rec.span then return false end
        elseif kind == "lavaemit" or kind == "waterarc" then
            if prev.dir == rec.dir then return false end
        else
            return false
        end
    end
    draft.props[PropKey(col, row)] = rec
    return true
end

function Ser.PruneProps(draft)
    draft.props = draft.props or {}
    local drop = {}
    for key, p in pairs(draft.props) do
        local col = type(p) == "table" and tonumber(p.col)
        local row = type(p) == "table" and tonumber(p.row)
        if not col or not row or col < 1 or row < 1
            or col > draft.width or row > draft.height then
            drop[#drop + 1] = key
        end
    end
    for i = 1, #drop do
        draft.props[drop[i]] = nil
    end
end

function Ser.FromMapString(entry)
    local rows = {}
    local map = entry.map or ""
    for row in string.gmatch(map, "[^|]+") do
        rows[#rows + 1] = row
    end
    local h = entry.height or #rows
    local w = entry.width or (rows[1] and #rows[1] or 0)
    for r = 1, h do
        local line = rows[r] or ""
        if #line < w then
            line = line .. Rep(".", w - #line)
        elseif #line > w then
            line = line:sub(1, w)
        end
        rows[r] = line
    end
    return {
        name = entry.name or "Draft",
        width = w,
        height = h,
        theme = entry.theme or "day",
        parallax = ArcadiaNexus.LevelEditorCatalog
            and ArcadiaNexus.LevelEditorCatalog.NormalizeParallax(entry.parallax)
            or "theme",
        boss = entry.boss,
        game = ArcadiaNexus.LevelEditorCatalog
            and ArcadiaNexus.LevelEditorCatalog.NormalizeGame(entry.game)
            or "AZEROTH_ASCENT",
        rows = rows,
        blocks = Ser.NormalizeBlocks(entry.blocks),
        pipes = Ser.NormalizePipes(entry.pipes),
        mobs = Ser.NormalizeMobs(entry.mobs),
        props = Ser.NormalizeProps(entry.props),
    }
end

function Ser.Get(draft, col, row)
    local line = draft.rows[row]
    if not line then return "." end
    local ch = line:sub(col, col)
    if ch == "" then return "." end
    return ch
end

function Ser.Set(draft, col, row, ch, opts)
    if row < 1 or row > draft.height or col < 1 or col > draft.width then
        return false
    end
    local Cat = ArcadiaNexus.LevelEditorCatalog
    local item = Cat and Cat.ByChar(ch, draft.game)
    if item and item.overlay then
        return Ser.SetProp(draft, col, row, item.propKind or item.id, opts)
    end
    if item and item.unique then
        for r = 1, draft.height do
            for c = 1, draft.width do
                if Ser.Get(draft, c, r) == ch and (c ~= col or r ~= row) then
                    draft.rows[r] = SetChar(draft.rows[r], c, ".")
                end
            end
        end
    end
    draft.rows[row] = SetChar(draft.rows[row], col, ch)
    if ch == "?" then
        local contents = (opts and opts.contents) or Ser.GetBlockContents(draft, col, row)
        Ser.SetBlockContents(draft, col, row, contents)
    else
        Ser.PruneBlocks(draft)
    end
    if Cat and Cat.IsPairChar(ch, draft.game) then
        local pair = (opts and opts.pair) or Ser.GetPipePair(draft, col, row)
        Ser.SetPipePair(draft, col, row, pair)
    else
        Ser.PrunePipes(draft)
    end
    if Cat and Cat.IsMobChar(ch, draft.game) then
        Ser.SetMob(draft, col, row, opts or Ser.GetMob(draft, col, row))
    else
        Ser.PruneMobs(draft)
    end
    if ch == "B" and Cat and Cat.NormalizeGame(draft.game) == Cat.GAME_AA then
        draft.boss = Cat.NormalizeBoss((opts and opts.boss) or draft.boss)
    end
    return true
end

Ser.MIN_W, Ser.MAX_W = 20, 160
Ser.MIN_H, Ser.MAX_H = 8, 64

local function RemapBlocks(draft, dCol, dRow, maxW, maxH)
    local nb = {}
    for _, b in pairs(draft.blocks or {}) do
        if type(b) == "table" then
            local col = b.col + (dCol or 0)
            local row = b.row + (dRow or 0)
            if col >= 1 and row >= 1 and col <= maxW and row <= maxH then
                b.col, b.row = col, row
                nb[tostring(col) .. ":" .. tostring(row)] = b
            end
        end
    end
    draft.blocks = nb
end

local function RemapPipes(draft, dCol, dRow, maxW, maxH)
    local np = {}
    for _, p in pairs(draft.pipes or {}) do
        if type(p) == "table" then
            local col = p.col + (dCol or 0)
            local row = p.row + (dRow or 0)
            if col >= 1 and row >= 1 and col <= maxW and row <= maxH then
                p.col, p.row = col, row
                np[tostring(col) .. ":" .. tostring(row)] = p
            end
        end
    end
    draft.pipes = np
end

local function RemapMobs(draft, dCol, dRow, maxW, maxH)
    local nm = {}
    for _, m in pairs(draft.mobs or {}) do
        if type(m) == "table" then
            local col = m.col + (dCol or 0)
            local row = m.row + (dRow or 0)
            if col >= 1 and row >= 1 and col <= maxW and row <= maxH then
                m.col, m.row = col, row
                nm[tostring(col) .. ":" .. tostring(row)] = m
            end
        end
    end
    draft.mobs = nm
end

local function RemapProps(draft, dCol, dRow, maxW, maxH)
    local np = {}
    for _, p in pairs(draft.props or {}) do
        if type(p) == "table" then
            local col = p.col + (dCol or 0)
            local row = p.row + (dRow or 0)
            if col >= 1 and row >= 1 and col <= maxW and row <= maxH then
                p.col, p.row = col, row
                np[tostring(col) .. ":" .. tostring(row)] = p
            end
        end
    end
    draft.props = np
end

--- Groesse aendern. Mehr Hoehe wird oben angefuegt (Boden bleibt unten).
function Ser.Resize(draft, newW, newH)
    if not draft then return false end
    newW = math.max(Ser.MIN_W, math.min(Ser.MAX_W, math.floor(tonumber(newW) or draft.width)))
    newH = math.max(Ser.MIN_H, math.min(Ser.MAX_H, math.floor(tonumber(newH) or draft.height)))
    local oldW, oldH = draft.width, draft.height
    if newH ~= oldH then
        local rows = {}
        if newH > oldH then
            local add = newH - oldH
            for i = 1, add do
                rows[i] = Rep(".", oldW)
            end
            for r = 1, oldH do
                rows[add + r] = draft.rows[r]
            end
            RemapBlocks(draft, 0, add, oldW, newH)
            RemapPipes(draft, 0, add, oldW, newH)
            RemapMobs(draft, 0, add, oldW, newH)
            RemapProps(draft, 0, add, oldW, newH)
        else
            local drop = oldH - newH
            for r = drop + 1, oldH do
                rows[#rows + 1] = draft.rows[r]
            end
            RemapBlocks(draft, 0, -drop, oldW, newH)
            RemapPipes(draft, 0, -drop, oldW, newH)
            RemapMobs(draft, 0, -drop, oldW, newH)
            RemapProps(draft, 0, -drop, oldW, newH)
        end
        draft.rows = rows
        draft.height = newH
    end
    if newW ~= oldW then
        for r = 1, draft.height do
            local line = draft.rows[r] or ""
            if #line < newW then
                line = line .. Rep(".", newW - #line)
            elseif #line > newW then
                line = line:sub(1, newW)
            end
            draft.rows[r] = line
        end
        if newW < oldW then
            RemapBlocks(draft, 0, 0, newW, draft.height)
            RemapPipes(draft, 0, 0, newW, draft.height)
            RemapMobs(draft, 0, 0, newW, draft.height)
            RemapProps(draft, 0, 0, newW, draft.height)
        end
        draft.width = newW
    end
    Ser.PruneBlocks(draft)
    Ser.PrunePipes(draft)
    Ser.PruneMobs(draft)
    Ser.PruneProps(draft)
    return true
end

local STAND_CH = {
    ["#"] = true, ["e"] = true, ["X"] = true, ["?"] = true, ["b"] = true,
    ["I"] = true, ["*"] = true, ["~"] = true, ["="] = true, [">"] = true,
    ["<"] = true, ["j"] = true, ["D"] = true,
}
local SLOPE_CH = {
    ["/"] = true, ["\\"] = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true,
}

local function HasSpawnFooting(draft, col, row)
    local here = Ser.Get(draft, col, row)
    if SLOPE_CH[here] then return true end
    if row >= draft.height then return false end
    local below = Ser.Get(draft, col, row + 1)
    return STAND_CH[below] == true or SLOPE_CH[below] == true
end

--- Prueft den Draft auf haeufige Export-Fehler.
--- Rueckgabe: { ok, errors, warns, issues = { { sev, code, msg, col, row } } }
function Ser.Validate(draft)
    local issues = {}
    local function Loc(key, fallback, ...)
        local Cat = ArcadiaNexus.LevelEditorCatalog
        local s = (Cat and Cat.L and Cat.L(key, fallback)) or fallback or key
        if select("#", ...) > 0 then
            return string.format(s, ...)
        end
        return s
    end
    local function add(sev, code, msg, col, row)
        issues[#issues + 1] = {
            sev = sev, code = code, msg = msg,
            col = col, row = row,
        }
    end

    if type(draft) ~= "table" or type(draft.rows) ~= "table" then
        add("error", "empty", Loc("val_empty", "Kein Draft geladen."))
        return { ok = false, errors = 1, warns = 0, issues = issues }
    end

    local Cat = ArcadiaNexus.LevelEditorCatalog
    local game = Cat and Cat.NormalizeGame(draft.game) or "AZEROTH_ASCENT"
    local isAA = (not Cat) or (game == Cat.GAME_AA)

    local spawns, goals, bosses = {}, {}, {}
    local pipes, doors, switches, keys = {}, {}, {}, {}

    for r = 1, draft.height do
        for c = 1, draft.width do
            local ch = Ser.Get(draft, c, r)
            if ch == "P" then
                spawns[#spawns + 1] = { col = c, row = r }
            elseif ch == "G" then
                goals[#goals + 1] = { col = c, row = r }
            elseif ch == "B" then
                bosses[#bosses + 1] = { col = c, row = r }
            elseif ch == "I" then
                local pair = Ser.GetPipePair(draft, c, r)
                pipes[pair] = pipes[pair] or {}
                pipes[pair][#pipes[pair] + 1] = { col = c, row = r }
            elseif isAA and ch == "D" then
                local pair = Ser.GetPipePair(draft, c, r)
                doors[pair] = doors[pair] or {}
                doors[pair][#doors[pair] + 1] = { col = c, row = r }
            elseif isAA and ch == "s" then
                local pair = Ser.GetPipePair(draft, c, r)
                switches[pair] = switches[pair] or {}
                switches[pair][#switches[pair] + 1] = { col = c, row = r }
            elseif isAA and ch == "U" then
                local pair = Ser.GetPipePair(draft, c, r)
                keys[pair] = keys[pair] or {}
                keys[pair][#keys[pair] + 1] = { col = c, row = r }
            end
        end
    end

    if #spawns == 0 then
        add("error", "no_spawn", Loc("val_no_spawn", "Spawn (P) fehlt."))
    else
        if #spawns > 1 then
            add("error", "extra_spawn",
                Loc("val_extra_spawn", "Mehr als ein Spawn (%d).", #spawns),
                spawns[2].col, spawns[2].row)
        end
        local s = spawns[1]
        if not HasSpawnFooting(draft, s.col, s.row) then
            add("error", "spawn_air",
                Loc("val_spawn_air", "Spawn bei %d,%d steht nicht auf Boden.", s.col, s.row),
                s.col, s.row)
        end
    end

    if #goals == 0 then
        add("error", "no_goal", Loc("val_no_goal", "Ziel (G) fehlt."))
    elseif #goals > 1 then
        add("error", "extra_goal",
            Loc("val_extra_goal", "Mehr als ein Ziel (%d).", #goals),
            goals[2].col, goals[2].row)
    end

    for pair, list in pairs(pipes) do
        local n = #list
        local at = list[1]
        if n == 1 then
            add("error", "pipe_orphan",
                Loc("val_pipe_orphan", "Rohr-Paar %d hat nur 1 Roehre.", pair),
                at.col, at.row)
        elseif n > 2 then
            add("warn", "pipe_many",
                Loc("val_pipe_many", "Rohr-Paar %d hat %d Roehren (erwartet 2).", pair, n),
                at.col, at.row)
        end
    end

    if isAA then
        local seen = {}
        local function mark(t)
            for pair in pairs(t) do seen[pair] = true end
        end
        mark(doors)
        mark(switches)
        mark(keys)
        for pair in pairs(seen) do
            local d = doors[pair] or {}
            local sw = switches[pair] or {}
            local k = keys[pair] or {}
            local openers = #sw + #k
            if #d > 0 and openers == 0 then
                add("error", "door_no_key",
                    Loc("val_door_no_key", "Tuer-Paar %d ohne Schalter oder Schluessel.", pair),
                    d[1].col, d[1].row)
            elseif openers > 0 and #d == 0 then
                local src = (#sw > 0) and sw[1] or k[1]
                add("warn", "key_no_door",
                    Loc("val_key_no_door", "Schalter/Schluessel-Paar %d ohne Tuer.", pair),
                    src.col, src.row)
            end
        end

        if #bosses == 0 and draft.boss then
            add("error", "boss_no_marker",
                Loc("val_boss_no_marker", "Boss-Typ gesetzt, aber kein Marker B (Flagge bleibt zu)."))
        elseif #bosses > 0 and not draft.boss then
            add("warn", "marker_no_boss",
                Loc("val_marker_no_boss", "Boss-Marker ohne Typ – Export setzt Golem."),
                bosses[1].col, bosses[1].row)
        end
    end

    table.sort(issues, function(a, b)
        if a.sev ~= b.sev then return a.sev == "error" end
        if (a.row or 0) == (b.row or 0) then
            return (a.col or 0) < (b.col or 0)
        end
        return (a.row or 0) < (b.row or 0)
    end)

    local errors, warns = 0, 0
    for i = 1, #issues do
        if issues[i].sev == "error" then
            errors = errors + 1
        else
            warns = warns + 1
        end
    end
    return {
        ok = errors == 0,
        errors = errors,
        warns = warns,
        issues = issues,
    }
end

function Ser.ToMapString(draft)
    return table.concat(draft.rows, "|")
end

function Ser.ToEntry(draft)
    Ser.PruneBlocks(draft)
    Ser.PrunePipes(draft)
    Ser.PruneMobs(draft)
    Ser.PruneProps(draft)
    return {
        name = draft.name or "Draft",
        width = draft.width,
        height = draft.height,
        theme = draft.theme or "day",
        parallax = ArcadiaNexus.LevelEditorCatalog
            and ArcadiaNexus.LevelEditorCatalog.NormalizeParallax(draft.parallax)
            or (draft.parallax or "theme"),
        boss = draft.boss,
        game = draft.game or "AZEROTH_ASCENT",
        map = Ser.ToMapString(draft),
        blocks = Ser.BlocksList(draft),
        pipes = Ser.PipesList(draft),
        mobs = Ser.MobsList(draft),
        props = Ser.PropsList(draft),
    }
end

local function EscapeLua(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\"")
    return s
end

function Ser.ToLua(draft)
    Ser.PruneBlocks(draft)
    Ser.PrunePipes(draft)
    Ser.PruneMobs(draft)
    Ser.PruneProps(draft)
    local lines = {}
    lines[#lines + 1] = "-- Level-Editor Export (Phase 15)"
    lines[#lines + 1] = "{"
    lines[#lines + 1] = string.format('    name = "%s", width = %d, height = %d, boss = %s, theme = "%s", parallax = "%s", game = "%s",',
        EscapeLua(draft.name or "Draft"),
        draft.width, draft.height,
        draft.boss and string.format('"%s"', draft.boss) or "nil",
        EscapeLua(draft.theme or "day"),
        EscapeLua(ArcadiaNexus.LevelEditorCatalog
            and ArcadiaNexus.LevelEditorCatalog.NormalizeParallax(draft.parallax)
            or (draft.parallax or "theme")),
        EscapeLua(draft.game or "AZEROTH_ASCENT"))
    lines[#lines + 1] = "    map = M({"
    for r = 1, draft.height do
        lines[#lines + 1] = string.format('        "%s",', EscapeLua(draft.rows[r]))
    end
    lines[#lines + 1] = "    }),"
    local blocks = Ser.BlocksList(draft)
    if #blocks == 0 then
        lines[#lines + 1] = "    blocks = {},"
    else
        lines[#lines + 1] = "    blocks = {"
        for i = 1, #blocks do
            local b = blocks[i]
            lines[#lines + 1] = string.format(
                '        { col = %d, row = %d, contents = "%s" },',
                b.col, b.row, EscapeLua(b.contents or "random"))
        end
        lines[#lines + 1] = "    },"
    end
    local pipes = Ser.PipesList(draft)
    if #pipes == 0 then
        lines[#lines + 1] = "    pipes = {},"
    else
        lines[#lines + 1] = "    pipes = {"
        for i = 1, #pipes do
            local p = pipes[i]
            lines[#lines + 1] = string.format(
                '        { col = %d, row = %d, pair = %d },',
                p.col, p.row, tonumber(p.pair) or 1)
        end
        lines[#lines + 1] = "    },"
    end
    local mobs = Ser.MobsList(draft)
    if #mobs == 0 then
        lines[#lines + 1] = "    mobs = {},"
    else
        lines[#lines + 1] = "    mobs = {"
        for i = 1, #mobs do
            local m = mobs[i]
            lines[#lines + 1] = string.format(
                '        { col = %d, row = %d, patrol = %d, behavior = "%s" },',
                m.col, m.row, tonumber(m.patrol) or 4, EscapeLua(m.behavior or "turn"))
        end
        lines[#lines + 1] = "    },"
    end
    local props = Ser.PropsList(draft)
    if #props == 0 then
        lines[#lines + 1] = "    props = {},"
    else
        lines[#lines + 1] = "    props = {"
        for i = 1, #props do
            local p = props[i]
            if p.kind == "mover" or p.kind == "wind" then
                lines[#lines + 1] = string.format(
                    '        { col = %d, row = %d, kind = "%s", axis = "%s", span = %d },',
                    p.col, p.row, EscapeLua(p.kind), EscapeLua(p.axis or "h"), tonumber(p.span) or 4)
            elseif p.kind == "spinner" then
                lines[#lines + 1] = string.format(
                    '        { col = %d, row = %d, kind = "spinner", spin = "%s" },',
                    p.col, p.row, EscapeLua(p.spin or "90"))
            elseif p.kind == "camlock" then
                lines[#lines + 1] = string.format(
                    '        { col = %d, row = %d, kind = "camlock", cam = "%s", span = %d },',
                    p.col, p.row, EscapeLua(p.cam or "xy"), tonumber(p.span) or 4)
            elseif p.kind == "lavaemit" or p.kind == "waterarc" then
                lines[#lines + 1] = string.format(
                    '        { col = %d, row = %d, kind = "%s", dir = "%s" },',
                    p.col, p.row, EscapeLua(p.kind), EscapeLua(p.dir or "r"))
            else
                lines[#lines + 1] = string.format(
                    '        { col = %d, row = %d, kind = "%s" },',
                    p.col, p.row, EscapeLua(p.kind))
            end
        end
        lines[#lines + 1] = "    },"
    end
    lines[#lines + 1] = "},"
    return table.concat(lines, "\n")
end

function Ser.CloneDraft(draft)
    return Ser.FromMapString(Ser.ToEntry(draft))
end

function Ser.CopyRect(draft, c0, r0, c1, r1)
    if c1 < c0 then c0, c1 = c1, c0 end
    if r1 < r0 then r0, r1 = r1, r0 end
    c0 = math.max(1, c0)
    r0 = math.max(1, r0)
    c1 = math.min(draft.width, c1)
    r1 = math.min(draft.height, r1)
    local w, h = c1 - c0 + 1, r1 - r0 + 1
    local cells = {}
    for r = r0, r1 do
        cells[#cells + 1] = Ser.Get(draft, c0, r) and draft.rows[r]:sub(c0, c1) or string.rep(".", w)
    end
    local function collect(list)
        local out = {}
        for i = 1, #(list or {}) do
            local it = list[i]
            if it.col >= c0 and it.col <= c1 and it.row >= r0 and it.row <= r1 then
                local copy = {}
                for k, v in pairs(it) do copy[k] = v end
                copy.col = it.col - c0 + 1
                copy.row = it.row - r0 + 1
                out[#out + 1] = copy
            end
        end
        return out
    end
    return {
        w = w, h = h, cells = cells,
        blocks = collect(Ser.BlocksList(draft)),
        pipes = collect(Ser.PipesList(draft)),
        mobs = collect(Ser.MobsList(draft)),
        props = collect(Ser.PropsList(draft)),
    }
end

function Ser.PasteRect(draft, col, row, clip)
    if not clip or not clip.cells then return false end
    col = math.max(1, col or 1)
    row = math.max(1, row or 1)
    for r = 1, clip.h do
        local line = clip.cells[r] or ""
        for c = 1, clip.w do
            local ch = line:sub(c, c)
            if ch == "" then ch = "." end
            local dc, dr = col + c - 1, row + r - 1
            if dc <= draft.width and dr <= draft.height then
                draft.rows[dr] = SetChar(draft.rows[dr], dc, ch)
            end
        end
    end
    local function stamp(src, setter)
        for i = 1, #(src or {}) do
            local it = src[i]
            local dc, dr = col + it.col - 1, row + it.row - 1
            if dc >= 1 and dr >= 1 and dc <= draft.width and dr <= draft.height then
                setter(it, dc, dr)
            end
        end
    end
    stamp(clip.blocks, function(it, dc, dr)
        Ser.SetBlockContents(draft, dc, dr, it.contents)
    end)
    stamp(clip.pipes, function(it, dc, dr)
        Ser.SetPipePair(draft, dc, dr, it.pair)
    end)
    stamp(clip.mobs, function(it, dc, dr)
        Ser.SetMob(draft, dc, dr, it)
    end)
    stamp(clip.props, function(it, dc, dr)
        Ser.SetProp(draft, dc, dr, it.kind, it)
    end)
    Ser.PruneBlocks(draft)
    Ser.PrunePipes(draft)
    Ser.PruneMobs(draft)
    Ser.PruneProps(draft)
    return true
end
