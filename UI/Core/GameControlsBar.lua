--[[
    ArcadiaNexus - GameControlsBar
    Shared bottom control-bar shell for game renderers.

    Footer of the content/games panel. Chrome is sliced from the same
    UI-Tooltip-Border atlas NexusContentPanel uses (Backdrop 8-slice UVs),
    vertex-tinted with the same gold. Not the T/L mask files (opaque black)
    and not a Backdrop 9-slice mini-frame.
    Games place widgets on bar.frame. No game rules, no OnClick.
]]

ArcadiaNexus.UI = ArcadiaNexus.UI or {}
local UI = ArcadiaNexus.UI

-- Backdrop.lua textureUVs for edgeFile (1px gutter inside each 1/8 slice).
local COORD_START = 0.0625
local UV_LEFT = { 0.0078125, 0.1171875 }
local UV_TOP  = { 0.2578125, 0.3671875 }

local function ControlsLayout()
    return ArcadiaNexus.Layout.gameControls
end

local function BarH()
    return ControlsLayout().height
end

---@class ArcadiaGameControlsLayout
---@field width number
---@field vDividers number[]
---@field segX number[]

local LAYOUTS = {
    narrow = {
        width     = 500,
        vDividers = { -250, -90, 90, 250 },
        segX      = { -170, 0, 170 },
    },
    wide = {
        width     = 600,
        vDividers = { -300, -90, 90, 250, 300 },
        segX      = { -195, 0, 170, 275 },
    },
    wide5 = {
        width     = 600,
        -- Inner posts: 1/2 further X-, 3/4 further X+ so segment 3 matches
        -- the standard start slot (-90 … 90) used by narrow/wide.
        vDividers = { -300, -220, -90, 90, 220, 300 },
        segX      = { -260, -155, 0, 155, 260 },
    },
    equal4 = {
        width     = 600,
        vDividers = { -300, -150, 0, 150, 300 },
        segX      = { -225, -75, 75, 225 },
    },
}

UI.GameControlsBar = {
    LAYOUTS = LAYOUTS,
}

function UI.GameControlsBar.Height()
    return BarH()
end

local function Tint(tex)
    local c = ControlsLayout().gold
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

local function EdgeRepeat(length, edgeSize)
    return math.max(0.5, (length or edgeSize) / edgeSize)
end

-- Centers of the inner segments, from the real games-panel width.
-- Outer vDividers are ignored (content chrome is the L/R edge).
local function SegmentCenters(vDividers, barW)
    local half = (barW or 0) / 2
    if half <= 0 then return {} end
    local edges = { -half }
    for i = 2, #vDividers - 1 do
        edges[#edges + 1] = vDividers[i]
    end
    edges[#edges + 1] = half
    local centers = {}
    for i = 1, #edges - 1 do
        centers[i] = (edges[i] + edges[i + 1]) / 2
    end
    return centers
end

-- Vertical post = Backdrop LeftEdge (same pixels as the content sides).
local function ApplyLeftUVs(tex, repeatY)
    local u0, u1 = UV_LEFT[1], UV_LEFT[2]
    local cs = COORD_START
    local ry = math.max(cs + 0.01, repeatY)
    tex:SetTexCoord(u0, cs, u0, ry, u1, cs, u1, ry)
end

-- Horizontal rail = Backdrop TopEdge (3rd slice, rotated like Backdrop.lua).
local function ApplyTopUVs(tex, repeatX)
    local u0, u1 = UV_TOP[1], UV_TOP[2]
    local cs = COORD_START
    local rx = math.max(cs + 0.01, repeatX)
    tex:SetTexCoord(u0, rx, u1, rx, u0, cs, u1, cs)
end

local function CreateEdgeTexture(parent, sublevel)
    local cfg = ControlsLayout()
    local tex = parent:CreateTexture(nil, "ARTWORK", nil, sublevel or 0)
    tex:SetTexture(cfg.texEdge, "REPEAT", "REPEAT")
    Tint(tex)
    return tex
end

local function RefreshEdgeUVs(cf)
    local cfg = ControlsLayout()
    local edge = cfg.edgeSize
    local w, h = cf:GetWidth(), cf:GetHeight()
    if not w or w == 0 then return end
    if cf._rail then
        ApplyTopUVs(cf._rail, EdgeRepeat(w, edge))
    end
    local ry = EdgeRepeat(h, edge)
    if cf._posts then
        for i = 1, #cf._posts do
            ApplyLeftUVs(cf._posts[i], ry)
        end
    end
end

local function ResolveOuter(parent)
    if parent._gameViewport then
        return parent, parent._gameViewport
    end
    local p = parent:GetParent()
    if p and p._gameViewport and p._gameViewport.canvas == parent then
        return p, p._gameViewport
    end
    return parent, nil
end

local function ReserveCanvasFooter(outer, viewport)
    if not viewport or not viewport.canvas or viewport._footerReserved then return end
    local footerH = BarH() + ControlsLayout().inset
    viewport.canvas:ClearAllPoints()
    viewport.canvas:SetPoint("CENTER", outer, "CENTER",
        viewport.offsetX or 0,
        (viewport.offsetY or 0) + footerH / 2)
    viewport._footerReserved = true
end

local function RaiseContentChrome(above)
    local frames = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF()
    local chrome = frames and frames.contentChrome
    if not chrome then return end
    local want = (above:GetFrameLevel() or 1) + 2
    if (chrome:GetFrameLevel() or 0) < want then
        chrome:SetFrameLevel(want)
    end
end

---@class ArcadiaGameControlsBar
---@field frame Frame
---@field layout string
---@field width number
---@field segX number[]
---@field y { dropdown: number, button: number, checkbox: number }

---Create the shared bottom bar on the games-panel outer frame.
---@param parent Frame  viewport outer (or canvas; resolved to outer)
---@param layout "narrow"|"wide"|"wide5"|"equal4"|ArcadiaGameControlsLayout
---@return ArcadiaGameControlsBar
function UI.CreateGameControlsBar(parent, layout)
    assert(parent, "CreateGameControlsBar: parent is required")

    local spec = layout
    local layoutName = "custom"
    if type(layout) == "string" then
        spec = LAYOUTS[layout]
        layoutName = layout
        assert(spec, "CreateGameControlsBar: unknown layout '" .. tostring(layout) .. "'")
    end
    assert(spec and spec.vDividers, "CreateGameControlsBar: layout spec is invalid")

    local outer, viewport = ResolveOuter(parent)
    ReserveCanvasFooter(outer, viewport)

    local cfg = ControlsLayout()
    local barH = cfg.height
    local edge = cfg.edgeSize
    local joinTop    = cfg.joinTop or cfg.join or 4
    local joinBottom = cfg.joinBottom or 0
    local joinLeft   = cfg.joinLeft or 0
    local joinRight  = cfg.joinRight or 0

    -- Flush with the content frame so T meets L/R and the bottom edge is shared.
    local cf = CreateFrame("Frame", nil, outer)
    cf:SetHeight(barH)
    cf:SetPoint("BOTTOMLEFT",  outer, "BOTTOMLEFT",  0, 0)
    cf:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", 0, 0)
    cf:SetFrameLevel((outer:GetFrameLevel() or 1) + 20)
    cf._posts = {}

    -- Full-bleed rail: L/R ends tuck under NexusContentChrome.
    local rail = CreateEdgeTexture(cf, 1)
    rail:SetHeight(edge)
    rail:SetPoint("TOPLEFT",  cf, "TOPLEFT",  joinLeft,  0)
    rail:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -joinRight, 0)
    cf._rail = rail

    -- Inner posts only; outer V would duplicate the content frame sides.
    -- Top short of T; bottom 0 tucks under the content chrome.
    local vList = spec.vDividers
    for i = 2, #vList - 1 do
        local post = CreateEdgeTexture(cf, 0)
        post:SetWidth(edge)
        post:SetPoint("TOP",    cf, "TOP",    vList[i], -joinTop)
        post:SetPoint("BOTTOM", cf, "BOTTOM", vList[i],  joinBottom)
        cf._posts[#cf._posts + 1] = post
    end

    cf:SetScript("OnSizeChanged", RefreshEdgeUVs)
    RefreshEdgeUVs(cf)
    RaiseContentChrome(cf)

    local barW = select(1, ArcadiaNexus.Layout.GetGamesPanelSize())
    local segX = SegmentCenters(spec.vDividers, barW)
    if #segX == 0 then
        segX = spec.segX
    end

    local y = {
        dropdownOfs = cfg.dropdownOfsY or -3,
        dropdown    = 10,
        button      = 10,
        checkbox    = 12,
    }
    cf.segX = segX
    cf.barY = y

    return {
        frame  = cf,
        layout = layoutName,
        width  = barW,
        segX   = segX,
        y      = y,
    }
end
