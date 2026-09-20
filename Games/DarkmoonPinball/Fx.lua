-- Darkmoon Pinball – FX-Hilfen ohne UI.
-- Trail, Shake, Popup-TTL. Renderer zeichnet, Engine spielt Sounds.

ArcadiaNexus.DMP_Fx = {}
local Fx = ArcadiaNexus.DMP_Fx

Fx.TRAIL_MAX = 12
Fx.POPUP_TTL = 0.75
Fx.RING_TTL = 0.28
Fx.BANNER_TTL = 1.6

function Fx.PushTrail(trail, x, y, maxN)
    trail = trail or {}
    maxN = maxN or Fx.TRAIL_MAX
    trail[#trail + 1] = { x = x, y = y }
    if #trail > maxN then
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
        if e.t > 0 then
            list[w] = e
            w = w + 1
        end
    end
    for i = w, #list do
        list[i] = nil
    end
end

function Fx.ShakeOffset(t, amp)
    if not t or t <= 0 or not amp or amp <= 0 then return 0, 0 end
    return math.sin(t * 55) * amp, math.cos(t * 41) * amp * 0.55
end

function Fx.Popup(x, y, text, r, g, b)
    return { x = x, y = y, text = text, r = r or 1, g = g or 0.85, b = b or 0.4, t = Fx.POPUP_TTL }
end

function Fx.Ring(x, y, r, g, b)
    return { x = x, y = y, r = r or 0.7, g = g or 0.4, b = b or 1, t = Fx.RING_TTL }
end
