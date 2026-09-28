--[[
    ArcadiaNexus – Core/TopDown/Catalog.lua
    Tilesets und Entity-Typen für den Top-Down-Editor (Schema v1).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TD_Catalog = {}
local Cat = ArcadiaNexus.TD_Catalog

Cat.SCHEMA_VERSION = 1
Cat.TILE = 16
Cat.MIN_SIZE = 8
Cat.MAX_SIZE = 64
Cat.MAX_MAPS = 16
Cat.DEFAULT_TILESET = "trails"
Cat.TILESETS = { trails = true, cave = true, dungeon = true }

Cat.ENTITY_WAVE1 = {
    spawn = true,
    warp = true,
    switch = true,
    door = true,
    chest = true,
}

Cat.ENTITY_RESERVED = {
    enemy = true,
    npc = true,
    trigger = true,
}

Cat.COLLISION = {
    ["."] = { id = "walk",  walk = true,  label = "Walk",  r = 0.15, g = 0.18, b = 0.14, a = 0.15 },
    ["#"] = { id = "block", walk = false, label = "Block", r = 0.85, g = 0.25, b = 0.22, a = 0.55 },
    ["~"] = { id = "water", walk = false, label = "Water", r = 0.20, g = 0.45, b = 0.90, a = 0.50 },
    ["o"] = { id = "pit",   walk = false, label = "Pit",   r = 0.05, g = 0.05, b = 0.08, a = 0.70 },
    ["^"] = { id = "tall",  walk = true,  label = "Tall",  r = 0.55, g = 0.35, b = 0.80, a = 0.35 },
}

local GROUND = {}
local OVERLAY = {}
local GROUND_LIST = {}
local OVERLAY_LIST = {}

local function AddGround(ch, id, label, r, g, b)
    local item = { ch = ch, id = id, label = label, r = r, g = g, b = b }
    GROUND[ch] = item
    GROUND_LIST[#GROUND_LIST + 1] = item
end

local function AddOverlay(ch, id, label, r, g, b)
    local item = { ch = ch, id = id, label = label, r = r, g = g, b = b }
    OVERLAY[ch] = item
    OVERLAY_LIST[#OVERLAY_LIST + 1] = item
end

AddGround(".", "grass", "Gras", 0.28, 0.58, 0.22)
AddGround("d", "dirt",  "Erde", 0.45, 0.32, 0.18)
AddGround("p", "path",  "Pfad", 0.72, 0.62, 0.38)
AddGround("s", "stone", "Stein", 0.45, 0.48, 0.52)
AddGround("w", "water", "Wasser", 0.18, 0.40, 0.72)
AddGround("c", "cave",  "Hoehle", 0.22, 0.20, 0.18)
AddGround("a", "sand",  "Sand", 0.78, 0.70, 0.42)
AddGround("l", "lava",  "Lava", 0.85, 0.32, 0.08)
AddGround("k", "crack", "Riss", 0.38, 0.36, 0.34)
AddGround("m", "moss",  "Moos", 0.22, 0.38, 0.18)

AddOverlay(".", "none", "Leer", 0, 0, 0)
AddOverlay("T", "tree", "Baum", 0.12, 0.42, 0.16)
AddOverlay("R", "roof", "Dach", 0.55, 0.22, 0.16)
AddOverlay("B", "bush", "Busch", 0.20, 0.50, 0.18)
AddOverlay("K", "rock_s", "Fels klein", 0.45, 0.38, 0.32)
AddOverlay("M", "rock_m", "Fels mittel", 0.42, 0.34, 0.28)
AddOverlay("G", "rock_l", "Fels gross", 0.38, 0.30, 0.24)
AddOverlay("Q", "rocks", "Felsgruppe", 0.40, 0.32, 0.26)
AddOverlay("P", "stalag", "Stalagmit", 0.50, 0.48, 0.46)
AddOverlay("U", "rubble", "Schutt", 0.36, 0.30, 0.26)
AddOverlay("X", "spikes", "Stacheln", 0.70, 0.30, 0.28)
AddOverlay("F", "torch", "Fackel", 0.95, 0.55, 0.15)

Cat.ENTITIES = {
    { type = "spawn",  label = "Spawn" },
    { type = "warp",   label = "Warp" },
    { type = "switch", label = "Schalter" },
    { type = "door",   label = "Tuer" },
    { type = "chest",  label = "Truhe" },
}

function Cat.ClampSize(n, fallback)
    n = math.floor(tonumber(n) or fallback or 16)
    if n < Cat.MIN_SIZE then return Cat.MIN_SIZE end
    if n > Cat.MAX_SIZE then return Cat.MAX_SIZE end
    return n
end

function Cat.IsCollision(ch)
    return Cat.COLLISION[ch] ~= nil
end

function Cat.CollisionWalkable(ch)
    local c = Cat.COLLISION[ch or "."]
    if not c then return true end
    return c.walk == true
end

function Cat.Ground(ch)
    return GROUND[ch] or GROUND["."]
end

function Cat.Overlay(ch)
    return OVERLAY[ch] or OVERLAY["."]
end

function Cat.GroundList()
    return GROUND_LIST
end

function Cat.OverlayList()
    return OVERLAY_LIST
end

function Cat.IsEntityWave1(typ)
    return Cat.ENTITY_WAVE1[typ] == true
end

function Cat.IsEntityReserved(typ)
    return Cat.ENTITY_RESERVED[typ] == true
end

function Cat.IsKnownEntity(typ)
    return Cat.IsEntityWave1(typ) or Cat.IsEntityReserved(typ)
end
