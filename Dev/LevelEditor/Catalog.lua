--[[
    ArcadiaNexus – Dev/LevelEditor/Catalog.lua
    Phase 15: Erde, Treppen, Lava-/Wasser-Emitter.

    Neue Tiles: Catalog.Register({ ... }) – Palette und Export lesen
    nur Eintraege mit placeable == true und phase <= CURRENT_PHASE.
    Texturen: Shared/Platformer zuerst, Fallback auf das Ursprungsspiel.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LevelEditorCatalog = {}
local Catalog = ArcadiaNexus.LevelEditorCatalog

Catalog.CURRENT_PHASE = 15
Catalog.TILE = 32
Catalog.GAME_AA = "AZEROTH_ASCENT"
Catalog.GAME_TR = "TINKERSREVENGE"
Catalog.DEFAULT_GAME = Catalog.GAME_AA

local G_AA   = { [Catalog.GAME_AA] = true }
local G_TR   = { [Catalog.GAME_TR] = true }
local G_BOTH = { [Catalog.GAME_AA] = true, [Catalog.GAME_TR] = true }

local ADDON = "Interface\\AddOns\\ArcadiaNexus\\"
Catalog.SHARED = ADDON .. "Shared\\Platformer\\sprites\\"
Catalog.SHARED_PARALLAX = ADDON .. "Shared\\Platformer\\parallax\\"
Catalog.AA_SPRITES = ADDON .. "Games\\AzerothAscent\\assets\\sprites\\"
Catalog.AA_PARALLAX = ADDON .. "Games\\AzerothAscent\\assets\\parallax\\"
Catalog.TR_SPRITES = ADDON .. "Games\\TinkersRevenge\\assets\\sprites\\"

local ITEMS = {}
local BY_CHAR = {}
local BY_ID = {}

local function Sprite(name)
    return { primary = Catalog.SHARED .. name, fallback = Catalog.AA_SPRITES .. name }
end

local function TRSprite(name)
    return { primary = Catalog.SHARED .. name, fallback = Catalog.TR_SPRITES .. name }
end

local function Parallax(name)
    return {
        primary = Catalog.SHARED_PARALLAX .. name,
        fallback = Catalog.AA_PARALLAX .. name,
    }
end

function Catalog.NormalizeGame(game)
    if game == Catalog.GAME_TR or game == "TR" or game == "TINKERS_REVENGE" then
        return Catalog.GAME_TR
    end
    return Catalog.GAME_AA
end

function Catalog.Allowed(item, game)
    if not item then return false end
    game = Catalog.NormalizeGame(game)
    local g = item.games or G_AA
    return g[game] == true
end

function Catalog.Register(item)
    assert(item and item.id and item.ch, "Catalog.Register: id und ch sind Pflicht")
    item.games = item.games or G_AA
    ITEMS[#ITEMS + 1] = item
    BY_ID[item.id] = item
    for gameId in pairs(item.games) do
        BY_CHAR[gameId] = BY_CHAR[gameId] or {}
        BY_CHAR[gameId][item.ch] = item
    end
    return item
end

function Catalog.Get(id) return BY_ID[id] end

function Catalog.ByChar(ch, game)
    game = Catalog.NormalizeGame(game)
    local m = BY_CHAR[game]
    return m and m[ch]
end

function Catalog.ItemTex(item, game)
    if not item then return nil end
    game = Catalog.NormalizeGame(game)
    if item.texByGame and item.texByGame[game] then
        return item.texByGame[game]
    end
    return item.tex
end

function Catalog.L(key, fallback)
    local locales = ArcadiaNexus._locales and ArcadiaNexus._locales.LEVELEDITOR
    local lang = ArcadiaNexus.ActiveLocale or "enUS"
    local s = locales and (
        (locales[lang] and locales[lang][key])
        or (locales.enUS and locales.enUS[key])
    )
    if type(s) == "string" and s ~= "" then return s end
    return fallback or key
end

function Catalog.ItemLabel(item)
    if not item then return "" end
    return Catalog.L("tile_" .. tostring(item.id), item.label)
end

function Catalog.LocalizedOptions(list, prefix, sharedTipKey)
    local out = {}
    for i = 1, #(list or {}) do
        local e = list[i]
        local tipKey = sharedTipKey or (prefix .. tostring(e.key) .. "_tip")
        out[i] = {
            key = e.key,
            label = Catalog.L(prefix .. tostring(e.key), e.label),
            tooltip = Catalog.L(tipKey, e.tooltip),
        }
    end
    return out
end

Catalog.GROUP_LABELS = {
    terrain = "Terrain",
    hazard  = "Gefahren",
    block   = "Bloecke",
    marker  = "Marker",
    pickup  = "Sammeln",
    enemy   = "Gegner",
    decor   = "Deko",
}

Catalog.QBLOCK_CONTENTS = {
    { key = "random", label = "Zufall", tooltip = "Beim Aufschlag ein zufaelliges Power-Up oder eine Muenze." },
    { key = "heart",  label = "Herz", tooltip = "Extra-Leben, wenn du den ?-Block von unten triffst." },
    { key = "shield", label = "Schild", tooltip = "Ein Treffer wird abgefangen." },
    { key = "speed",  label = "Tempo", tooltip = "Kurz schneller laufen." },
    { key = "jump",   label = "Sprung", tooltip = "Doppelsprung fuer kurze Zeit." },
    { key = "coin",   label = "Muenze", tooltip = "Gibt eine Muenze statt eines Power-Ups." },
}

Catalog.MOVER_AXES = {
    { key = "h", label = "Horizontal", tooltip = "Fahrstuhl links/rechts. Beim Wind-Overlay: Schub nach rechts." },
    { key = "v", label = "Vertikal", tooltip = "Fahrstuhl hoch/runter. Beim Wind-Overlay: Schub nach oben." },
}
Catalog.MOVER_SPANS = {
    { key = "3", label = "3 Tiles", tooltip = "Kurze Strecke (3 Kacheln). Bei Kamera/Wind: kleine Zone." },
    { key = "4", label = "4 Tiles", tooltip = "Standard-Strecke (4 Kacheln)." },
    { key = "6", label = "6 Tiles", tooltip = "Lange Strecke (6 Kacheln). Bei Kamera/Wind: grosse Zone." },
}

function Catalog.NormalizeMoverAxis(v)
    if v == "v" then return "v" end
    return "h"
end

function Catalog.NormalizeMoverSpan(v)
    v = tonumber(v) or 4
    if v == 3 or v == 6 then return v end
    return 4
end

Catalog.PIPE_PAIRS = {
    { key = "1", label = "Paar 1", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "2", label = "Paar 2", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "3", label = "Paar 3", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "4", label = "Paar 4", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "5", label = "Paar 5", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "6", label = "Paar 6", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "7", label = "Paar 7", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
    { key = "8", label = "Paar 8", tooltip = "Gleiche Nummer verbindet zwei Roehren oder Schalter, Tuer und Schluessel." },
}

Catalog.SPIN_MODES = {
    { key = "90",  label = "90 Grad", tooltip = "Kippt um 90 Grad, haelt kurz, kippt zurueck." },
    { key = "360", label = "360 Grad", tooltip = "Dreht sich dauernd im Kreis." },
}

function Catalog.NormalizeSpin(v)
    if v == "360" or v == 360 or v == "full" then return "360" end
    return "90"
end

Catalog.ENEMY_PATROLS = {
    { key = "2", label = "Patrol 2", tooltip = "Wendet nach etwa 2 Kacheln um den Spawnpunkt." },
    { key = "4", label = "Patrol 4", tooltip = "Standard: etwa 4 Kacheln um den Spawnpunkt." },
    { key = "6", label = "Patrol 6", tooltip = "Weiterer Weg, etwa 6 Kacheln um den Spawnpunkt." },
    { key = "0", label = "Frei", tooltip = "Kein Distanz-Limit. Walker bis zur Wand, Flieger weit." },
}
Catalog.CAM_LOCKS = {
    { key = "none", label = "Frei", tooltip = "Kamera folgt dem Spieler wie sonst." },
    { key = "x", label = "Lock X", tooltip = "Kein horizontales Scrollen. Gut fuer hohe Schaechte." },
    { key = "y", label = "Lock Y", tooltip = "Kein vertikales Scrollen." },
    { key = "xy", label = "Lock XY", tooltip = "Kamera steht fest. Boss-Arena oder einzelner Raum." },
}

function Catalog.NormalizePatrol(v)
    v = math.floor(tonumber(v) or 4)
    if v == 0 or v == 2 or v == 6 then return v end
    return 4
end

function Catalog.NormalizeCamLock(v)
    if v == "x" or v == "y" or v == "xy" then return v end
    return "none"
end

function Catalog.NormalizePipePair(v)
    v = math.floor(tonumber(v) or 1)
    if v < 1 then v = 1 end
    if v > 8 then v = 8 end
    return v
end

function Catalog.IsPairChar(ch, game)
    if ch == "I" then return true end
    if Catalog.NormalizeGame(game) ~= Catalog.GAME_AA then return false end
    return ch == "D" or ch == "s" or ch == "U"
end

function Catalog.IsMobChar(ch, game)
    if Catalog.NormalizeGame(game) ~= Catalog.GAME_AA then return false end
    return ch == "E" or ch == "K" or ch == "F" or ch == "R"
end

Catalog.BOSS_TYPES = {
    { key = "golem", label = "Golem", tooltip = "Bodenboss, stampft. Marker B plus dieser Typ." },
    { key = "wisp", label = "Wisp", tooltip = "Flugboss, schwerer zu stompen." },
    { key = "troll", label = "Troll", tooltip = "Bodenboss mit mehr Leben." },
    { key = "sentinel", label = "Sentinel", tooltip = "Teleportiert auf dem Boden." },
    { key = "guardian", label = "Guardian", tooltip = "Endboss, hoechste Leben." },
}

function Catalog.NormalizeBoss(v)
    if v == "wisp" or v == "troll" or v == "sentinel" or v == "guardian" then
        return v
    end
    return "golem"
end

Catalog.MOB_BEHAVIORS = {
    { key = "turn", label = "An Kante drehen", tooltip = "Kehrt um vor Abgrund, Wand oder Gefahr." },
    { key = "wait", label = "Warten, dann drehen", tooltip = "Kurze Pause an der Kante, dann umdrehen." },
    { key = "noedge", label = "Kante ignorieren", tooltip = "Faellt die Kante runter, dreht nur an Waenden." },
}

function Catalog.NormalizeMobBehavior(v)
    if v == "wait" or v == "noedge" then return v end
    return "turn"
end

Catalog.EMIT_DIRS = {
    { key = "u", label = "Senkrecht", tooltip = "Schuss geht hoch und faellt an derselben Stelle zurueck." },
    { key = "r", label = "Bogen rechts", tooltip = "Schuss geht hoch und faellt nach rechts." },
    { key = "l", label = "Bogen links", tooltip = "Schuss geht hoch und faellt nach links." },
}

function Catalog.NormalizeEmitDir(v)
    if v == "l" or v == "left" or v == -1 then return "l" end
    if v == "u" or v == "up" or v == 0 then return "u" end
    return "r"
end

function Catalog.IsEmitArcChar(ch)
    return ch == "h" or ch == "v"
end

function Catalog.IsEmitArcItem(item)
    return item and (item.propKind == "lavaemit" or item.propKind == "waterarc")
end

--- Zelle darueber verdeckt den Boden: Gras wird zur Erde.
function Catalog.CoversGround(ch)
    return ch == "#" or ch == "e" or ch == "X" or ch == "?" or ch == "b"
        or ch == "I" or ch == "*" or ch == "D" or ch == "~"
        or ch == "/" or ch == "\\" or ch == "1" or ch == "2" or ch == "3" or ch == "4"
end

function Catalog.IsWaterChar(ch)
    return ch == "w" or ch == "W" or ch == "i" or ch == "N"
end

function Catalog.IsLavaChar(ch)
    return ch == "L" or ch == "l"
end

Catalog.PARALLAX_PRESETS = {
    { key = "theme", label = "Theme" },
    { key = "clear", label = "Klar" },
    { key = "cave",  label = "Hoehle" },
    { key = "lava",  label = "Lava" },
    { key = "storm", label = "Sturm" },
}

function Catalog.NormalizeParallax(v)
    if type(v) == "table" then v = v.preset or v.sky end
    for i = 1, #Catalog.PARALLAX_PRESETS do
        if Catalog.PARALLAX_PRESETS[i].key == v then return v end
    end
    return "theme"
end

function Catalog.ParallaxLabel(v)
    v = Catalog.NormalizeParallax(v)
    local fallback = "Theme"
    for i = 1, #Catalog.PARALLAX_PRESETS do
        if Catalog.PARALLAX_PRESETS[i].key == v then
            fallback = Catalog.PARALLAX_PRESETS[i].label
            break
        end
    end
    return Catalog.L("px_" .. v, fallback)
end

function Catalog.NextParallax(v)
    v = Catalog.NormalizeParallax(v)
    local list = Catalog.PARALLAX_PRESETS
    for i = 1, #list do
        if list[i].key == v then
            return list[(i % #list) + 1].key
        end
    end
    return "theme"
end

Catalog.QBLOCK_MARK = {
    random = "?",
    heart  = "H",
    shield = "S",
    speed  = "T",
    jump   = "J",
    coin   = "C",
}

function Catalog.GroupLabel(group)
    return Catalog.L("group_" .. tostring(group), Catalog.GROUP_LABELS[group] or group)
end

function Catalog.IsQBlockContents(key)
    if not key then return false end
    for i = 1, #Catalog.QBLOCK_CONTENTS do
        if Catalog.QBLOCK_CONTENTS[i].key == key then return true end
    end
    return false
end

function Catalog.Palette(game)
    local out = {}
    for i = 1, #ITEMS do
        local it = ITEMS[i]
        local phase = it.phase or 1
        if it.placeable ~= false and phase <= Catalog.CURRENT_PHASE then
            if not game or Catalog.Allowed(it, game) then
                out[#out + 1] = it
            end
        end
    end
    return out
end

--- Nach _tools/sync_platformer_assets.py: Shared/Platformer bevorzugen.
Catalog.USE_SHARED = true

function Catalog.ApplyTexture(tex, rec)
    if not tex or not rec then return end
    if type(rec) == "string" then
        tex:SetTexture(rec)
        return
    end
    if Catalog.USE_SHARED and rec.primary then
        tex:SetTexture(rec.primary)
    elseif rec.fallback then
        tex:SetTexture(rec.fallback)
    else
        tex:SetTexture(rec.primary)
    end
end

-- Terrain / Gefahren / Bloecke
Catalog.Register({
    id = "empty", ch = ".", label = "Leer", group = "terrain",
    collision = "none", tex = nil, placeable = true, phase = 1, games = G_BOTH,
})
Catalog.Register({
    id = "ground", ch = "#", label = "Boden", group = "terrain",
    collision = "solid", tex = Sprite("tile_ground"), placeable = true, phase = 1, games = G_BOTH,
})
Catalog.Register({
    id = "dirt", ch = "e", label = "Erde", group = "terrain",
    collision = "solid", tex = Sprite("tile_dirt"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "block", ch = "X", label = "Steinblock", group = "terrain",
    collision = "solid", tex = Sprite("tile_block"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "platform", ch = "=", label = "Plattform", group = "terrain",
    collision = "oneway", tex = Sprite("tile_platform"), placeable = true, phase = 1, games = G_BOTH,
})
Catalog.Register({
    id = "bridge", ch = "~", label = "Bruecke", group = "terrain",
    collision = "solid", tex = Sprite("tile_bridge"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "ladder", ch = "H", label = "Leiter", group = "terrain",
    collision = "ladder", tex = Sprite("tile_ladder"), placeable = true, phase = 3,
})
Catalog.Register({
    id = "pipe", ch = "I", label = "Roehre", group = "terrain",
    collision = "solid", tex = Sprite("tile_pipe"), placeable = true, phase = 10,
    hasPipePair = true, games = G_AA,
})
Catalog.Register({
    id = "slope_up", ch = "/", label = "Rampe auf", group = "terrain",
    collision = "slope", tex = Sprite("tile_slope_up"), placeable = true, phase = 12,
    games = G_AA,
})
Catalog.Register({
    id = "slope_down", ch = "\\", label = "Rampe ab", group = "terrain",
    collision = "slope", tex = Sprite("tile_slope_down"), placeable = true, phase = 12,
    games = G_AA,
})
Catalog.Register({
    id = "stair_stone_up", ch = "1", label = "Treppe Stein auf", group = "terrain",
    collision = "slope", tex = Sprite("tile_stair_stone_up"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "stair_stone_down", ch = "2", label = "Treppe Stein ab", group = "terrain",
    collision = "slope", tex = Sprite("tile_stair_stone_down"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "stair_wood_up", ch = "3", label = "Treppe Holz auf", group = "terrain",
    collision = "slope", tex = Sprite("tile_stair_wood_up"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "stair_wood_down", ch = "4", label = "Treppe Holz ab", group = "terrain",
    collision = "slope", tex = Sprite("tile_stair_wood_down"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "climbwall", ch = "*", label = "Kletterwand", group = "terrain",
    collision = "solid", tex = Sprite("tile_climbwall"), placeable = true, phase = 12,
    games = G_AA,
})
Catalog.Register({
    id = "swim", ch = "w", label = "Schwimmen oben", group = "terrain",
    collision = "none", tex = Sprite("tile_water_1"), placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "swim_deep", ch = "i", label = "Schwimmen tief", group = "terrain",
    collision = "none", tex = Sprite("tile_water_fill"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "convey_r", ch = ">", label = "Foerderband R", group = "terrain",
    collision = "oneway", tex = Sprite("tile_platform"), placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "convey_l", ch = "<", label = "Foerderband L", group = "terrain",
    collision = "oneway", tex = Sprite("tile_platform"), placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "trampoline", ch = "j", label = "Trampolin", group = "terrain",
    collision = "oneway", tex = Sprite("tile_platform"), placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "door", ch = "D", label = "Tuer", group = "block",
    collision = "solid", tex = Sprite("tile_block"), placeable = true, phase = 14,
    hasPipePair = true, games = G_AA,
})
Catalog.Register({
    id = "switch", ch = "s", label = "Schalter", group = "block",
    collision = "none", tex = Sprite("tile_question"), placeable = true, phase = 14,
    hasPipePair = true, games = G_AA,
})
Catalog.Register({
    id = "key", ch = "U", label = "Schluessel", group = "pickup",
    collision = "none", tex = Sprite("pu_shield"), placeable = true, phase = 14,
    hasPipePair = true, games = G_AA,
})
Catalog.Register({
    id = "spike", ch = "^", label = "Stachel", group = "hazard",
    collision = "hazard", tex = Sprite("tile_spike"), placeable = true, phase = 1, games = G_BOTH,
})
Catalog.Register({
    id = "lava", ch = "L", label = "Lava oben", group = "hazard",
    collision = "hazard", tex = Sprite("tile_lava"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "lava_deep", ch = "l", label = "Lava tief", group = "hazard",
    collision = "hazard", tex = Sprite("tile_lava_fill"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "water", ch = "W", label = "Wasser oben", group = "hazard",
    collision = "hazard", tex = Sprite("tile_water_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "water_deep", ch = "N", label = "Wasser tief", group = "hazard",
    collision = "hazard", tex = Sprite("tile_water_fill"), placeable = true, phase = 15,
    games = G_AA,
})
Catalog.Register({
    id = "qblock", ch = "?", label = "?-Block", group = "block",
    collision = "solid", tex = Sprite("tile_question"), placeable = true, phase = 1,
    hasContents = true,
})
Catalog.Register({
    id = "breakable", ch = "b", label = "Brechbar", group = "block",
    collision = "breakable", tex = Sprite("tile_break_1"), placeable = true, phase = 4,
    states = 3,
})
Catalog.Register({
    id = "mover", ch = "m", label = "Fahrstuhl", group = "terrain",
    collision = "oneway", tex = Sprite("tile_platform"), placeable = true, phase = 7,
    overlay = true, propKind = "mover", drawW = 64, drawH = 12, anchor = "foot",
    games = G_AA,
})
Catalog.Register({
    id = "crate", ch = "d", label = "Kiste", group = "terrain",
    collision = "solid", tex = Sprite("tile_crate"), placeable = true, phase = 13,
    overlay = true, propKind = "crate", drawW = 28, drawH = 28, anchor = "foot",
    games = G_AA,
})
Catalog.Register({
    id = "fallplat", ch = "a", label = "Fall-Plattform", group = "terrain",
    collision = "oneway", tex = Sprite("tile_fallplat"), placeable = true, phase = 13,
    overlay = true, propKind = "fallplat", drawW = 64, drawH = 12, anchor = "foot",
    games = G_AA,
})
Catalog.Register({
    id = "spinner", ch = "r", label = "Dreh-Plattform", group = "terrain",
    collision = "oneway", tex = Sprite("tile_spinplat"), placeable = true, phase = 13,
    overlay = true, propKind = "spinner", drawW = 64, drawH = 12, anchor = "center",
    games = G_AA,
})
Catalog.Register({
    id = "wind", ch = "y", label = "Wind", group = "terrain",
    collision = "none", tex = Sprite("tile_platform"), placeable = true, phase = 14,
    overlay = true, propKind = "wind", drawW = 96, drawH = 48, anchor = "center",
    games = G_AA,
})
Catalog.Register({
    id = "camlock", ch = "Z", label = "Kamera-Zone", group = "marker",
    collision = "none", tex = Sprite("tile_block"), placeable = true, phase = 14,
    overlay = true, propKind = "camlock", drawW = 96, drawH = 96, anchor = "center",
    games = G_AA,
})
Catalog.Register({
    id = "lavaemit", ch = "h", label = "Lava-Schuss (toetet)", group = "hazard",
    collision = "none", tex = Sprite("overlay_lavaemit"), placeable = true, phase = 15,
    overlay = true, propKind = "lavaemit", drawW = 24, drawH = 24, anchor = "center",
    games = G_AA,
})
Catalog.Register({
    id = "fountain", ch = "f", label = "Wasserfontaene", group = "terrain",
    collision = "none", tex = Sprite("fx_fountain"), placeable = true, phase = 15,
    overlay = true, propKind = "fountain", drawW = 24, drawH = 32, anchor = "foot",
    games = G_AA,
})
Catalog.Register({
    id = "waterarc", ch = "v", label = "Wasser-Schuss (stosst)", group = "terrain",
    collision = "none", tex = Sprite("overlay_wateremit"), placeable = true, phase = 15,
    overlay = true, propKind = "waterarc", drawW = 24, drawH = 24, anchor = "center",
    games = G_AA,
})

-- Marker (werden beim Parse aus dem Grid genommen)
Catalog.Register({
    id = "spawn", ch = "P", label = "Spawn", group = "marker",
    collision = "none", tex = Sprite("player_idle"), unique = true, placeable = true, phase = 1,
    games = G_BOTH,
    texByGame = { [Catalog.GAME_TR] = TRSprite("player_goblin_tinker_idle") },
})
Catalog.Register({
    id = "goal", ch = "G", label = "Ziel", group = "marker",
    collision = "none", tex = Sprite("flag"), unique = true, placeable = true, phase = 1,
    games = G_BOTH,
    texByGame = { [Catalog.GAME_TR] = TRSprite("goal") },
})
Catalog.Register({
    id = "aa_checkpoint", ch = "k", label = "Checkpoint", group = "marker",
    collision = "none", tex = Sprite("flag_check"), placeable = true, phase = 9,
    games = G_AA,
})
Catalog.Register({
    id = "coin", ch = "C", label = "Muenze", group = "pickup",
    collision = "none", tex = Sprite("coin_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "secret", ch = "z", label = "Geheim-Muenze", group = "pickup",
    collision = "none", tex = Sprite("coin_1"), placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "aa_boss", ch = "B", label = "Boss-Marker", group = "marker",
    collision = "none", tex = Sprite("boss_golem"), unique = true, placeable = true, phase = 14,
    games = G_AA,
})
Catalog.Register({
    id = "walker", ch = "E", label = "Walker", group = "enemy",
    collision = "none", tex = Sprite("enemy_walker_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "turtle", ch = "K", label = "Schildkroete", group = "enemy",
    collision = "none", tex = Sprite("enemy_turtle_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "flyer", ch = "F", label = "Flieger", group = "enemy",
    collision = "none", tex = Sprite("enemy_flyer_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "shooter", ch = "R", label = "Schuetze", group = "enemy",
    collision = "none", tex = Sprite("enemy_shooter_1"), placeable = true, phase = 8,
    games = G_AA,
})
Catalog.Register({
    id = "tree1", ch = "t", label = "Baum S", group = "decor",
    collision = "none", tex = Parallax("tree_1"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "tree2", ch = "T", label = "Baum M", group = "decor",
    collision = "none", tex = Parallax("tree_2"), placeable = true, phase = 1,
})
Catalog.Register({
    id = "tree3", ch = "u", label = "Baum L", group = "decor",
    collision = "none", tex = Parallax("tree_3"), placeable = true, phase = 1,
})
-- Overlay: liegt auf dem Grid, ersetzt kein Tile.
Catalog.Register({
    id = "grass", ch = "g", label = "Gras", group = "decor",
    collision = "none", tex = Sprite("decor_grass"), placeable = true, phase = 5,
    overlay = true, propKind = "grass", drawW = 32, drawH = 18, anchor = "foot", games = G_BOTH,
})
Catalog.Register({
    id = "cloud1", ch = "c", label = "Wolke S", group = "decor",
    collision = "none", tex = Parallax("cloud_1"), placeable = true, phase = 5,
    overlay = true, propKind = "cloud1", drawW = 128, drawH = 48, anchor = "center", games = G_BOTH,
})
Catalog.Register({
    id = "cloud2", ch = "o", label = "Wolke M", group = "decor",
    collision = "none", tex = Parallax("cloud_2"), placeable = true, phase = 5,
    overlay = true, propKind = "cloud2", drawW = 96, drawH = 40, anchor = "center", games = G_BOTH,
})
Catalog.Register({
    id = "cloud3", ch = "n", label = "Wolke L", group = "decor",
    collision = "none", tex = Parallax("cloud_3"), placeable = true, phase = 5,
    overlay = true, propKind = "cloud3", drawW = 160, drawH = 56, anchor = "center", games = G_BOTH,
})
Catalog.Register({
    id = "sun", ch = "S", label = "Sonne", group = "decor",
    collision = "none", tex = Parallax("sun"), placeable = true, phase = 5,
    overlay = true, propKind = "sun", drawW = 96, drawH = 96, anchor = "center", unique = true, games = G_BOTH,
})
Catalog.Register({
    id = "moon", ch = "M", label = "Mond", group = "decor",
    collision = "none", tex = Parallax("moon"), placeable = true, phase = 5,
    overlay = true, propKind = "moon", drawW = 40, drawH = 40, anchor = "center", unique = true, games = G_BOTH,
})

-- Tinker's Revenge (eigene Zeichen: K=Checkpoint, t=Turm, nicht AA-Schildkroete/Baum)
Catalog.Register({
    id = "lethal", ch = "L", label = "Toedlich", group = "hazard",
    collision = "hazard", tex = TRSprite("tile_lethal"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "checkpoint", ch = "K", label = "Checkpoint", group = "marker",
    collision = "none", tex = TRSprite("goal"), unique = true, placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_boss", ch = "B", label = "Boss-Spawn", group = "marker",
    collision = "none", tex = TRSprite("boss_goblin_bulwark"), unique = true, placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_scout", ch = "s", label = "Scout", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_scout"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_ranger", ch = "r", label = "Ranger", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_ranger"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_flyer", ch = "f", label = "Flieger", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_flyer"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_turret", ch = "t", label = "Turm", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_turret"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_warder", ch = "w", label = "Warder", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_warder"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_bird", ch = "v", label = "Vogel", group = "enemy",
    collision = "none", tex = TRSprite("enemy_goblin_flyer"), placeable = true, phase = 6, games = G_TR,
})
Catalog.Register({
    id = "tr_pickup", ch = "U", label = "Pickup", group = "pickup",
    collision = "none", tex = TRSprite("pu_flask"), placeable = true, phase = 6, games = G_TR,
})

Catalog.PROP_KINDS = {
    grass = true, cloud1 = true, cloud2 = true, cloud3 = true, sun = true, moon = true,
    mover = true, crate = true, fallplat = true, spinner = true,
    wind = true, camlock = true, lavaemit = true, fountain = true, waterarc = true,
}

function Catalog.IsPropKind(kind)
    return kind and Catalog.PROP_KINDS[kind] == true
end

function Catalog.ByPropKind(kind)
    if not kind then return nil end
    for i = 1, #ITEMS do
        if ITEMS[i].propKind == kind then return ITEMS[i] end
    end
    return nil
end

function Catalog.IsOverlayChar(ch)
    local it = BY_CHAR[ch]
    return it and it.overlay == true
end

Catalog.WATER_FRAMES = {
    Sprite("tile_water_1"), Sprite("tile_water_2"),
    Sprite("tile_water_3"), Sprite("tile_water_4"),
}
Catalog.LAVA_FRAMES = {
    Sprite("tile_lava_1"), Sprite("tile_lava_2"),
    Sprite("tile_lava_3"), Sprite("tile_lava_4"),
}
Catalog.BREAK_FRAMES = {
    Sprite("tile_break_1"), Sprite("tile_break_2"), Sprite("tile_break_3"),
}

Catalog.WATER_FILL = Sprite("tile_water_fill")
Catalog.LAVA_FILL = Sprite("tile_lava_fill")

function Catalog.AnimFrame(phase01, n)
    n = n or 4
    return (math.floor((phase01 or 0) * n) % n) + 1
end

function Catalog.WaterTex(phase01)
    return Catalog.WATER_FRAMES[Catalog.AnimFrame(phase01, 4)]
end

function Catalog.LavaTex(phase01)
    return Catalog.LAVA_FRAMES[Catalog.AnimFrame(phase01, 4)]
end

--- hp 3 = intakt (Frame 1), hp 1 = fast kaputt (Frame 3).
function Catalog.BreakTex(hp)
    hp = tonumber(hp) or 3
    if hp < 1 then hp = 1 end
    if hp > 3 then hp = 3 end
    return Catalog.BREAK_FRAMES[4 - hp]
end
