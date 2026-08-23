--[[
    ArcadiaNexus - GameViewport
    Shared outer-container and centered fixed-canvas construction for games.

    The outer frame always fills the games panel and remains the lifecycle
    container registered in GameRegistry. The canvas supplies a stable local
    coordinate space without scaling gameplay, hit regions, or pixel assets.
]]

ArcadiaNexus.UI = ArcadiaNexus.UI or {}
local UI = ArcadiaNexus.UI

---@class ArcadiaGameViewportOptions
---@field outerName? string
---@field designW? number
---@field designH? number
---@field offsetX? number
---@field offsetY? number
---@field outer? Frame

---@class ArcadiaGameViewport
---@field outer Frame
---@field canvas Frame
---@field designW number
---@field designH number

---Create or attach a panel-sized game container with a centered design canvas.
---@param parent Frame
---@param opts? ArcadiaGameViewportOptions
---@return ArcadiaGameViewport
function UI.CreateGameViewport(parent, opts)
    assert(parent, "CreateGameViewport: parent is required")
    opts = opts or {}

    local layoutW, layoutH = ArcadiaNexus.Layout.GetGameDesignSize()
    local designW = opts.designW or layoutW
    local designH = opts.designH or layoutH
    assert(designW > 0 and designH > 0, "CreateGameViewport: design size must be positive")

    local outer = opts.outer or CreateFrame("Frame", opts.outerName, parent)
    outer:ClearAllPoints()
    outer:SetAllPoints(parent)

    local canvas = CreateFrame("Frame", nil, outer)
    canvas:SetSize(designW, designH)
    canvas:SetPoint("CENTER", outer, "CENTER", opts.offsetX or 0, opts.offsetY or 0)

    local viewport = {
        outer   = outer,
        canvas  = canvas,
        designW = designW,
        designH = designH,
        offsetX = opts.offsetX or 0,
        offsetY = opts.offsetY or 0,
    }
    outer._gameViewport = viewport
    return viewport
end

---Attach a centered canvas to an already-created lifecycle container.
---@param outer Frame
---@param opts? ArcadiaGameViewportOptions
---@return Frame canvas, ArcadiaGameViewport viewport
function UI.AttachGameCanvas(outer, opts)
    opts = opts or {}
    opts.outer = outer
    local viewport = UI.CreateGameViewport(outer:GetParent(), opts)
    return viewport.canvas, viewport
end

