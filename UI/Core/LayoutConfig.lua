--[[
    ArcadiaNexus – LayoutConfig
    Single source of truth for shell dimensions and anchor offsets.

    Content-first: frame size is derived from content (800×600).
]]

local Layout = {}

-- ============================================================
-- BASE CONSTANTS
-- ============================================================

Layout.header = {
    height = 40,
}

Layout.tabs = {
    height      = 32,
    buttonWidth = 125,
    spacing     = 4,
}

Layout.padding = 8

Layout.sidebar = {
    width      = 196,
    left       = 22,
    bottomLeft = 9,
    scrollChildWidthOffset = 30,
}

Layout.content = {
    width              = 800,
    height             = 600,
    gapFromSidebar     = 8,
    rightInset         = 22,
    bottomExtra        = 2,
    leftWithoutSidebar = 9,
    gamesPanelTopInset = 42,
}

-- Fixed coordinate space used by production game renderers. The canvas is
-- centered inside the larger games panel; games keep their local coordinates.
Layout.gameDesign = {
    width  = 600,
    height = 498,
}

-- Bottom controls strip on the games panel (not on the design canvas).
-- Chrome is sliced from the same UI-Tooltip-Border atlas as NexusContentPanel.
Layout.gameControls = {
    height   = 52,
    inset    = 4,
    edgeSize = 16,
    -- Post length vs the T rail / content bottom. Higher = shorter line.
    joinTop    = 3,
    joinBottom = 3,
    -- T-rail inset from the content L/R. Higher = ends further inside.
    joinLeft   = 2,
    joinRight  = 3,
    -- Dropdown CENTER y vs bar middle. Codebreaker-tuned.
    dropdownOfsY = -3,
    gold     = { 0.90, 0.75, 0.30, 1 },
    texEdge  = "Interface\\Tooltips\\UI-Tooltip-Border",
}

-- Filled by ComputeFrameSize() below
Layout.frame = {
    width  = 0,
    height = 0,
}

-- ============================================================
-- FRAME SIZE (derived from content)
-- ============================================================

local function ComputeFrameSize()
    Layout.frame.width = Layout.sidebar.left
        + Layout.sidebar.width
        + Layout.content.gapFromSidebar
        + Layout.content.width
        + Layout.content.rightInset

    Layout.frame.height = Layout.header.height
        + Layout.padding
        + Layout.content.height
        + Layout.tabs.height
        + Layout.padding
        + Layout.content.bottomExtra
end

-- ============================================================
-- DERIVED HELPERS
-- ============================================================

function Layout.GetTopContentOffset()
    return Layout.header.height + Layout.padding
end

function Layout.GetBottomContentOffset()
    return Layout.tabs.height + Layout.padding + Layout.content.bottomExtra
end

function Layout.GetSidebarHeight()
    return Layout.content.height
end

function Layout.GetMetalBorderHeight()
    return Layout.frame.height - 60
end

function Layout.GetContentLeft(hasSidebar)
    if hasSidebar then
        return Layout.sidebar.left + Layout.sidebar.width + Layout.content.gapFromSidebar
    end
    return Layout.padding + Layout.content.leftWithoutSidebar
end

function Layout.GetContentTop()
    return -Layout.GetTopContentOffset()
end

function Layout.GetContentRightInset()
    return Layout.content.rightInset
end

function Layout.GetContentBottomInset()
    return Layout.GetBottomContentOffset()
end

---@param hasSidebar boolean
---@return number width, number height
function Layout.GetContentSize(hasSidebar)
    if hasSidebar then
        return Layout.content.width, Layout.content.height
    end
    local w = Layout.frame.width
        - Layout.GetContentLeft(false)
        - Layout.content.rightInset
    return w, Layout.content.height
end

--- Games panel inside NexusContentPanel (TOPLEFT 0,-42 → BOTTOMRIGHT 0,0).
---@return number width, number height
function Layout.GetGamesPanelSize()
    local w, h = Layout.GetContentSize(true)
    return w, h - Layout.content.gamesPanelTopInset
end

---@return number width, number height
function Layout.GetGameDesignSize()
    return Layout.gameDesign.width, Layout.gameDesign.height
end

---@param hasSidebar boolean
---@return number x, number y
function Layout.GetContentTopLeft(hasSidebar)
    return Layout.GetContentLeft(hasSidebar), Layout.GetContentTop()
end

---@return number topLeftX, number topLeftY, number bottomRightX, number bottomRightY
function Layout.GetFullWidthPanelAnchors()
    return Layout.padding + Layout.content.leftWithoutSidebar,
        -Layout.GetTopContentOffset(),
        -Layout.content.rightInset,
        Layout.GetBottomContentOffset()
end

---@return number topLeftX, number topLeftY, number bottomLeftX, number bottomLeftY
function Layout.GetSidebarAnchors()
    return Layout.sidebar.left,
        -Layout.GetTopContentOffset(),
        Layout.sidebar.bottomLeft,
        Layout.GetBottomContentOffset()
end

-- ============================================================
-- VALIDATION
-- ============================================================

function Layout.Validate()
    local top    = Layout.GetTopContentOffset()
    local bottom = Layout.GetBottomContentOffset()
    local sideH  = Layout.GetSidebarHeight()

    assert(sideH == Layout.content.height,
        string.format("Layout: sidebar height must equal content height (%d vs %d)",
            sideH, Layout.content.height))

    local contentW, contentH = Layout.GetContentSize(true)
    assert(contentW == Layout.content.width and contentH == Layout.content.height,
        string.format("Layout: content size mismatch (expected %dx%d, got %dx%d)",
            Layout.content.width, Layout.content.height, contentW, contentH))

    local gamesW, gamesH = Layout.GetGamesPanelSize()
    assert(gamesW > 0 and gamesH > 0,
        string.format("Layout: games panel size must be positive (got %dx%d)", gamesW, gamesH))

    local expectedFrameW = Layout.GetContentLeft(true) + contentW + Layout.content.rightInset
    assert(expectedFrameW == Layout.frame.width,
        string.format("Layout: frame width mismatch (expected %d, got %d)",
            expectedFrameW, Layout.frame.width))

    local expectedFrameH = top + contentH + bottom
    assert(expectedFrameH == Layout.frame.height,
        string.format("Layout: frame height mismatch (expected %d, got %d)",
            expectedFrameH, Layout.frame.height))

    return true
end

-- ============================================================
-- INIT
-- ============================================================

ComputeFrameSize()

Layout.MAIN_W   = Layout.frame.width
Layout.MAIN_H   = Layout.frame.height
Layout.CAT_W    = Layout.sidebar.width
Layout.HEADER_H = Layout.header.height
Layout.TAB_H    = Layout.tabs.height
Layout.PAD      = Layout.padding

ArcadiaNexus.Layout = Layout

return Layout
