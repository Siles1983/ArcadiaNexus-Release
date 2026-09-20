-- BlockBreaker – FX-Hilfen ohne UI.
-- Trail-Länge, Shard-/Popup-TTL. Renderer zeichnet.

ArcadiaNexus.BB_Fx = {}
local Fx = ArcadiaNexus.BB_Fx

Fx.TRAIL_MAX       = 8
Fx.TRAIL_MAX_FAST  = 10
Fx.TRAIL_MAX_SLOW  = 4
Fx.TRAIL_MAX_EXTRA = 5
Fx.SHARD_TTL       = 0.32
Fx.POP_TTL         = 0.55
Fx.COMBO_FLASH_TTL = 0.85
Fx.PADDLE_SQUASH   = 0.12
Fx.EDGE_FLASH_TTL  = 0.28
Fx.ENDGAME_BLOCKS  = 5
Fx.CLEAR_BURST     = 16

Fx.THEME_RGB = {
    blue    = { 0.35, 0.62, 1.00 },
    green   = { 0.30, 0.90, 0.42 },
    red     = { 1.00, 0.32, 0.26 },
    violett = { 0.78, 0.40, 1.00 },
    yellow  = { 1.00, 0.86, 0.28 },
}

Fx.TILE_RGB = {
    red         = { 0.95, 0.28, 0.22 },
    blue        = { 0.28, 0.52, 0.95 },
    green       = { 0.28, 0.82, 0.38 },
    yellow      = { 0.95, 0.82, 0.22 },
    violett     = { 0.72, 0.38, 0.92 },
    orange      = { 1.00, 0.55, 0.18 },
    light_blue  = { 0.45, 0.78, 1.00 },
    light_green = { 0.55, 0.95, 0.50 },
    brown       = { 0.62, 0.42, 0.22 },
    grey        = { 0.62, 0.62, 0.65 },
}

Fx.PU_RGB = {
    lives     = { 1.00, 0.35, 0.40 },
    score250  = { 1.00, 0.82, 0.25 },
    score500  = { 1.00, 0.70, 0.15 },
    big       = { 0.35, 0.80, 1.00 },
    bullet    = { 0.70, 0.85, 1.00 },
    fast      = { 1.00, 0.50, 0.15 },
    slow      = { 0.40, 0.90, 0.40 },
    small     = { 1.00, 0.25, 0.25 },
    strength  = { 1.00, 0.85, 0.10 },
}

function Fx.ThemeRGB(color)
    local c = Fx.THEME_RGB[color] or Fx.THEME_RGB.blue
    return c[1], c[2], c[3]
end

function Fx.PURGB(puType)
    local c = Fx.PU_RGB[puType] or Fx.THEME_RGB.yellow
    return c[1], c[2], c[3]
end

function Fx.TileRGB(tileName)
    local c = Fx.TILE_RGB[tileName] or Fx.TILE_RGB.blue
    return c[1], c[2], c[3]
end

function Fx.TrailMax(gs, isExtra)
    if isExtra then return Fx.TRAIL_MAX_EXTRA end
    if gs and gs.fastTimer and gs.fastTimer > 0 then return Fx.TRAIL_MAX_FAST end
    if gs and gs.slowTimer and gs.slowTimer > 0 then return Fx.TRAIL_MAX_SLOW end
    return Fx.TRAIL_MAX
end

function Fx.PushTrail(trail, x, y, maxN)
    trail = trail or {}
    maxN = maxN or Fx.TRAIL_MAX
    trail[#trail + 1] = { x = x, y = y }
    while #trail > maxN do
        table.remove(trail, 1)
    end
    return trail
end

function Fx.TickList(list, dt)
    if not list then return end
    local w = 1
    for i = 1, #list do
        local e = list[i]
        e.t = (e.t or 0) - dt
        if e.vx then e.x = (e.x or 0) + e.vx * dt end
        if e.vy then e.y = (e.y or 0) + e.vy * dt end
        if e.t > 0 then
            list[w] = e
            w = w + 1
        end
    end
    for i = w, #list do
        list[i] = nil
    end
end

function Fx.Popup(x, y, text, r, g, b)
    return {
        x = x, y = y, text = text,
        r = r or 1, g = g or 0.85, b = b or 0.4,
        t = Fx.POP_TTL, vy = -48,
    }
end

function Fx.Shard(x, y, r, g, b)
    local ang = math.random() * math.pi * 2
    local spd = 70 + math.random() * 110
    return {
        x = x, y = y,
        vx = math.cos(ang) * spd,
        vy = math.sin(ang) * spd,
        r = r, g = g, b = b,
        t = Fx.SHARD_TTL,
        w = 4 + math.random(4),
        h = 3 + math.random(3),
    }
end

function Fx.Burst(x, y, r, g, b, n)
    local out = {}
    n = n or 6
    for i = 1, n do
        out[i] = Fx.Shard(x, y, r, g, b)
        out[i].t = Fx.SHARD_TTL * 0.7
    end
    return out
end
