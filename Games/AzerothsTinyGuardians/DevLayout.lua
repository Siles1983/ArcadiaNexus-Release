-- ============================================================
--  Azeroth's Tiny Guardians – DevLayout.lua
--  Zeigt im DevMode alle layout-relevanten Boxen gleichzeitig,
--  damit Positionen ohne Spielablauf justiert werden können.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_DevLayout = {}
local D = ArcadiaNexus.ATG_DevLayout

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function IsDevMode()
    return ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() == true
end

local function AddGhost(layer, spec, label, r, g, b)
    if not spec then return end
    local f = CreateFrame("Frame", nil, layer, "BackdropTemplate")
    f:SetSize(spec.w or 80, spec.h or 24)
    f:SetPoint(spec.point or "TOP", layer, spec.relativePoint or spec.point or "TOP", spec.x or 0, spec.y or 0)
    f:SetBackdrop({
        bgFile   = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
    })
    f:SetBackdropColor(r, g, b, 0.18)
    f:SetBackdropBorderColor(r, g, b, 0.95)
    f:EnableMouse(false)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    fs:SetTextColor(r, g, b, 1)
    fs:SetText(label or "")
    return f
end

function D:Attach(renderer)
    self._renderer = renderer
    if not renderer or not renderer._fieldFrame then return end
    if self._layer then
        self:Refresh()
        return
    end

    local pf = renderer._fieldFrame
    local layer = CreateFrame("Frame", nil, pf)
    layer:SetAllPoints(pf)
    layer:SetFrameLevel(pf:GetFrameLevel() + 60)
    layer:EnableMouse(false)
    self._layer = layer
    self._ghosts = {}

    local CFG = renderer.CFG
    if not CFG then
        layer:Hide()
        return
    end

    local ghosts = self._ghosts
    if CFG.adopt_boxes then
        for i, spec in ipairs(CFG.adopt_boxes) do
            ghosts[#ghosts + 1] = AddGhost(layer, spec, "adopt_" .. i, 0.95, 0.82, 0.35)
        end
    end
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_list, "stall_list", 0.45, 0.78, 0.95)

    ghosts[#ghosts + 1] = AddGhost(layer, CFG.play_model, "play_model", 0.55, 0.95, 0.55)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.play_needs, "play_needs", 0.95, 0.55, 0.35)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_model, "stall_model", 0.75, 0.55, 0.95)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_name, "stall_name", 0.95, 0.90, 0.45)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_detail, "stall_detail", 0.90, 0.70, 0.40)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_btn_care, "btn_care", 0.80, 0.80, 0.80)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_btn_new, "btn_new", 0.80, 0.80, 0.80)
    ghosts[#ghosts + 1] = AddGhost(layer, CFG.stall_btn_back, "btn_back", 0.80, 0.80, 0.80)

    local hint = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", layer, "BOTTOM", 0, 8)
    hint:SetTextColor(0.95, 0.85, 0.40, 1)
    hint:SetText("DevMode layout")
    self._hintFS = hint

    self:Refresh()
end

function D:Refresh()
    if not self._layer then return end
    if IsDevMode() then
        self._layer:Show()
        if self._hintFS then
            local loc = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("AZEROTHTINYGUARDIANS")
            self._hintFS:SetText((loc and loc.dev_layout_hint) or "DevMode: Layout frames")
        end
    else
        self._layer:Hide()
    end
end
