--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Renderer.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Renderer = {}
local R = ArcadiaNexus.BS_Renderer

local GAME_ID = "BUBBLESHOOTER"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\BubbleShooter\\assets"
local CFG = {
    field_ofs_x = 0,
    field_ofs_y = 14,
    -- Skaliert Grid + Goldrahmen relativ zu Logic.FIELD_W/H (1 = 100 %).
    field_scale = 1.00,
    bg_path = ASSETS .. "\\background\\background_ab.png",
    -- Games-Panel 800×558 minus Controlsleiste (52+4) → 800×502
    bg_w = 750, bg_h = 500, bg_ofs_x = 0, bg_ofs_y = 15, bg_alpha = 1,
    ambient_line_alpha = 0.15,
    ambient_line_w = 2,
    ambient_mote_alpha = 0.52,
    ambient_mote_size = 7,
    border_path = ASSETS .. "\\border\\border_ab.png",
    border_w = 795, border_h = 550, border_ofs_x = 0, border_ofs_y = 15,
    logo_path = ASSETS .. "\\logo\\logo_ab.png",
    logo_w = 340, logo_h = 340, logo_ofs_x = 0, logo_ofs_y = 16, logo_alpha = 1,
    hint_ofs_y = -168,
    dd_w = 118, btn_w = 144, btn_h = 32,
    hud_side_w = 118, hud_side_h = 44, hud_gap = 10,
    hud_score_alpha = 0.75,
    hud_combo_alpha = 0.75,
    hud_stats_alpha = 0.75,
    gold_ofs_x = 0, gold_ofs_y = 0, gold_pad = 8,
    gold_side_extend = 5,
    cannon_base_path = ASSETS .. "\\cannon\\base.png",
    cannon_base_w = 106, cannon_base_h = 74, cannon_base_scale = 1,
    cannon_base_ofs_x = 0, cannon_base_ofs_y = 10,
    cannon_barrel_path = ASSETS .. "\\cannon\\barrel.png",
    cannon_barrel_w = 58, cannon_barrel_h = 106, cannon_barrel_scale = 1,
    cannon_barrel_ofs_x = 5, cannon_barrel_ofs_y = -8,
    cannon_loaded_ofs_x = 0, cannon_loaded_ofs_y = -40,
    cannon_loaded_aim_distance = 10,
    cannon_next_socket_path = ASSETS .. "\\cannon\\next_socket.png",
    cannon_next_socket_w = 50, cannon_next_socket_h = 48, cannon_next_socket_scale = 1,
    cannon_next_ofs_x = 70, cannon_next_ofs_y = 9.5,
    cannon_next_bubble_scale = 0.7, cannon_next_bubble_ofs_x = 0, cannon_next_bubble_ofs_y = 1,
    cannon_next_label_ofs_x = 0, cannon_next_label_ofs_y = 5,
    cannon_overcharge_aura_size = 78,
    cannon_overcharge_rune_size = 6,
    pip_size = 10,
    aim_dot = 5,
    power_focus_h = 52,
    power_focus_core = 24,
    power_focus_pip = 7,
    float_ofs_y = 22,
    combo_burst_scale = 1.35,
    combo_burst_rise = 34,
    drop_wobble = 4,
    drop_shake_medium = 3,
    drop_shake_large = 5,
}

local CB_MARK = { "–", "+", "▲", "■", "●", "×" }

local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local _animLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BS_AnimFrame")
local _ambientLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BS_AmbientFrame")

function R:_Loc()
    return ArcadiaNexus.GetLocaleTable(GAME_ID)
end

local function FieldScale()
    return CFG.field_scale or 1
end

-- The visible gold border follows the play area's collision boundary.  A small
-- visual overscan keeps the round aim dots inside the frame at bounce points.
local function GoldGridLayout()
    local Logic = ArcadiaNexus.BS_Logic
    local scale = FieldScale()
    local minX, maxX = Logic:CollisionBounds()
    local pad = CFG.gold_pad or 0
    local sideExtend = CFG.gold_side_extend or 0
    return {
        w = (maxX - minX) * scale - pad * 2 + sideExtend * 2,
        h = Logic.FIELD_H * scale,
        pad = pad,
        x = (CFG.gold_ofs_x or 0) + minX * scale + pad - sideExtend,
        y = CFG.gold_ofs_y or 0,
        fillAlpha = 0,
        levelAdd = -2,
    }
end

local function ThemeKey()
    local S = ArcadiaNexus.BS_Settings
    return (S and S:Get("theme")) or "energies"
end

local function AttachCircleMask(parent, tex)
    if not tex or not parent or not parent.CreateMaskTexture or not tex.AddMaskTexture then
        return nil
    end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return mask
end

local function PaintGem(tex, bg, gem)
    if not tex then return end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if gem and gem.type == "icon" and gem.icon then
        tex:SetTexture(gem.icon)
        tex:SetVertexColor(1, 1, 1, 1)
        if bg and gem.color then
            bg:SetVertexColor(gem.color[1], gem.color[2], gem.color[3], 0.85)
        end
    else
        local c = (gem and gem.color) or { 0.7, 0.7, 0.7 }
        tex:SetTexture(WHITE)
        tex:SetVertexColor(c[1], c[2], c[3], 1)
        if bg then
            bg:SetVertexColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1)
        end
    end
end

local POWER_ICON = {
    joker      = "Interface\\Icons\\INV_Misc_Gem_Pearl_06",
    bomb       = "Interface\\Icons\\INV_Misc_Bomb_04",
    lightning  = "Interface\\Icons\\Spell_Nature_ChainLightning",
    dragonfire = "Interface\\Icons\\Spell_Fire_Fireball02",
}
local POWER_GLOW = {
    joker      = { 0.95, 0.45, 1.00 },
    bomb       = { 1.00, 0.32, 0.08 },
    lightning  = { 0.45, 0.85, 1.00 },
    dragonfire = { 1.00, 0.50, 0.08 },
}

local function ApplyPowerLook(f, power)
    if not f then return end
    f._power = power
    local glow = power and POWER_GLOW[power]
    if f._ring then
        if glow then
            f._ring:SetVertexColor(glow[1], glow[2], glow[3], 0.85)
        else
            f._ring:SetVertexColor(1, 1, 1, 0)
        end
    end
    if f._badge then
        local icon = power and POWER_ICON[power]
        if icon then
            f._badge:SetTexture(icon)
            f._badge:Show()
        else
            f._badge:Hide()
            f._badge:SetTexture(nil)
        end
    end
end

local function ColorblindOn()
    local S = ArcadiaNexus.BS_Settings
    return S and S:Get("colorblind") == true
end

local function ApplyColorMark(f, color)
    if not f or not f._markFS then return end
    if ColorblindOn() and color and color > 0 then
        f._markFS:SetText(CB_MARK[((color - 1) % 6) + 1])
        f._markFS:Show()
    else
        f._markFS:SetText("")
        f._markFS:Hide()
    end
end

local function CursorInCircle(frame)
    if not frame or not frame:IsShown() then return false end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local right, top = frame:GetRight(), frame:GetTop()
    if not left or not bottom or not right or not top then return false end
    local scale = frame:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    local mx, my = cx / scale, cy / scale
    local ox, oy = (left + right) * 0.5, (bottom + top) * 0.5
    local r = (right - left) * 0.5
    local dx, dy = mx - ox, my - oy
    return (dx * dx + dy * dy) <= (r * r)
end

local function CreateBubblePool()
    local poolParentRef
    return ArcadiaNexus.UI.FramePool.New({
        name = "BubbleShooter.Orbs",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Button", nil, poolParent)
            f:RegisterForClicks("LeftButtonUp")
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(f)
            bg:SetTexture(WHITE)
            f._bg = bg
            f._bgMask = AttachCircleMask(f, bg)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
            f._tex = tex
            f._texMask = AttachCircleMask(f, tex)
            local shine = f:CreateTexture(nil, "OVERLAY")
            shine:SetTexture(WHITE)
            shine:SetVertexColor(1, 1, 1, 0.38)
            shine:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -4)
            shine:SetPoint("BOTTOMRIGHT", f, "CENTER", -1, 2)
            f._shine = shine
            f._shineMask = AttachCircleMask(f, shine)
            local ring = f:CreateTexture(nil, "BORDER")
            ring:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
            ring:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
            ring:SetTexture(WHITE)
            ring:SetVertexColor(1, 1, 1, 0)
            f._ring = ring
            f._ringMask = AttachCircleMask(f, ring)
            local badge = f:CreateTexture(nil, "OVERLAY", nil, 2)
            badge:SetSize(14, 14)
            badge:SetPoint("CENTER", f, "CENTER", 0, 0)
            badge:Hide()
            f._badge = badge
            local mark = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mark:SetPoint("CENTER", f, "CENTER", 0, 0)
            mark:SetTextColor(1, 1, 1, 0.95)
            mark:Hide()
            f._markFS = mark
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            f:SetScript("OnClick", nil)
            f:EnableMouse(false)
            f:SetScale(1)
            f:SetAlpha(1)
            f._row, f._col, f._color, f._kind, f._animating, f._power = nil, nil, nil, nil, nil, nil
            if f._tex then
                f._tex:SetTexture(nil)
                f._tex:SetVertexColor(1, 1, 1, 1)
                f._tex:SetAlpha(1)
            end
            if f._bg then f._bg:SetVertexColor(1, 1, 1, 1) end
            if f._shine then f._shine:SetAlpha(0.38) end
            if f._ring then f._ring:SetVertexColor(1, 1, 1, 0) end
            if f._badge then f._badge:Hide(); f._badge:SetTexture(nil) end
            if f._markFS then f._markFS:Hide(); f._markFS:SetText("") end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

local function CreateDotPool()
    local poolParentRef
    return ArcadiaNexus.UI.FramePool.New({
        name = "BubbleShooter.AimDots",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Frame", nil, poolParent)
            f:SetSize(CFG.aim_dot, CFG.aim_dot)
            local tex = f:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(f)
            tex:SetTexture(WHITE)
            f._tex = tex
            f._texMask = AttachCircleMask(f, tex)
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            if f._tex then f._tex:SetVertexColor(1, 1, 1, 0.7) end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

R.frame = nil
R._canvas = nil
R._aimAngle = -math.pi / 2

function R:Init()
    self:_CreateMainFrame()
    if not self.frame then return end
    self._bubblePool = self._bubblePool or CreateBubblePool()
    self._dotPool = self._dotPool or CreateDotPool()
    self._boardBubbles = {}
    self:_CreateFieldFrame()
    self:_CreateCannon()
    self:_CreateBackground()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreateCampaignMap()
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_BS_Container",
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._bsContainer = f
    local function TryFire()
        local E = ArcadiaNexus.BS_Engine
        if E and E.state == "AIMING" then E:Fire() end
    end
    -- Zielen/Schießen über die ganze Viewport-Fläche, nicht nur im Goldrahmen.
    if viewport.canvas then
        viewport.canvas:EnableMouse(true)
        viewport.canvas:SetScript("OnMouseUp", TryFire)
    end
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", TryFire)
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide(GAME_ID, ArcadiaNexus.BS_Engine, function(eng)
            if eng.state ~= "IDLE" then
                eng:SaveAndPause()
            end
        end)
        if R.state == "MENU" or R.state == "PLAYING" then
            R:EnterIdleState()
        end
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local Logic = ArcadiaNexus.BS_Logic
    local fieldW = Logic.FIELD_W
    local fieldH = Logic.FIELD_H
    local scale = FieldScale()
    local ff = CreateFrame("Frame", nil, self._canvas, "BackdropTemplate")
    ff:SetSize((fieldW + 12) * scale, (fieldH + 12) * scale)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = WHITE })
    ff:SetBackdropColor(0, 0, 0, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    ff:EnableMouse(true)
    ff:SetScript("OnMouseUp", function()
        local E = ArcadiaNexus.BS_Engine
        if E and E.state == "AIMING" then E:Fire() end
    end)
    self._fieldFrame = ff

    local holder = CreateFrame("Frame", nil, ff)
    holder:SetSize(fieldW, fieldH)
    holder:SetScale(scale)
    holder:SetPoint("CENTER", ff, "CENTER", 0, 0)
    holder:Hide()
    self._gridHolder = holder

    -- Dedicated text layer above all pooled board orbs. Combo bursts must remain
    -- legible even when their impact point is covered by a dense cluster.
    local comboLayer = CreateFrame("Frame", nil, holder)
    comboLayer:SetAllPoints(holder)
    comboLayer:SetFrameLevel((holder:GetFrameLevel() or 1) + 40)
    comboLayer:EnableMouse(false)
    self._comboFloatLayer = comboLayer

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, holder, GoldGridLayout())
    end

    -- Effect layer follows the actual playfield, not the larger interaction
    -- frame.  This clips every flash exactly to the visible gold-grid area.
    local flashLayer = CreateFrame("Frame", nil, holder)
    flashLayer:SetAllPoints(holder)
    flashLayer:SetFrameLevel((holder:GetFrameLevel() or 1) + 35)
    flashLayer:EnableMouse(false)
    self._flashLayer = flashLayer
    local flash = flashLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    flash:SetAllPoints(flashLayer)
    flash:SetTexture(WHITE)
    flash:SetVertexColor(1, 0.85, 0.2, 0)
    flash:Hide()
    self._flashTex = flash

    local fan = ff:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    fan:SetPoint("CENTER", ff, "CENTER", 0, 20)
    fan:SetText("")
    self._fanfareFS = fan

    local nextFS = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextFS:SetTextColor(0.85, 0.75, 0.35)
    nextFS:Hide()
    self._nextFS = nextFS
end

-- The socket is static, while the barrel follows the already-computed aim angle.
-- Loaded and flying bubbles remain pooled game tokens, so themes and power-ups retain
-- their existing visuals and behaviour.
function R:_CreateCannon()
    if self._cannonBase or not self._gridHolder then return end
    local Logic = ArcadiaNexus.BS_Logic
    local holder = self._gridHolder
    local level = (holder:GetFrameLevel() or 1) + 1

    local base = CreateFrame("Frame", nil, holder)
    base:SetSize(CFG.cannon_base_w, CFG.cannon_base_h)
    base:SetScale(CFG.cannon_base_scale)
    base:SetPoint("CENTER", holder, "TOPLEFT", Logic.SHOOTER_X + CFG.cannon_base_ofs_x,
        -(Logic.SHOOTER_Y + CFG.cannon_base_ofs_y))
    base:SetFrameLevel(level)
    base:EnableMouse(false)
    local baseTex = base:CreateTexture(nil, "ARTWORK")
    baseTex:SetAllPoints(base)
    baseTex:SetTexture(CFG.cannon_base_path)
    self._cannonBase = base
    self._cannonBaseTex = baseTex

    local aura = CreateFrame("Frame", nil, holder)
    aura:SetSize(CFG.cannon_overcharge_aura_size, CFG.cannon_overcharge_aura_size)
    aura:SetPoint("CENTER", holder, "TOPLEFT", Logic.SHOOTER_X + CFG.cannon_base_ofs_x,
        -(Logic.SHOOTER_Y + CFG.cannon_base_ofs_y))
    aura:SetFrameLevel(math.max(holder:GetFrameLevel() or 1, level - 1))
    aura:EnableMouse(false)
    local halo = aura:CreateTexture(nil, "ARTWORK", nil, 0)
    halo:SetSize(CFG.cannon_overcharge_aura_size * 0.72, CFG.cannon_overcharge_aura_size * 0.72)
    halo:SetPoint("CENTER", aura, "CENTER", 0, 0)
    halo:SetTexture(WHITE)
    halo:SetBlendMode("ADD")
    AttachCircleMask(aura, halo)
    aura._halo = halo
    aura._runes = {}
    for i = 1, 6 do
        local rune = aura:CreateTexture(nil, "OVERLAY", nil, 1)
        rune:SetSize(CFG.cannon_overcharge_rune_size, CFG.cannon_overcharge_rune_size)
        rune:SetTexture(WHITE)
        rune:SetBlendMode("ADD")
        AttachCircleMask(aura, rune)
        aura._runes[i] = rune
    end
    aura:Hide()
    self._overchargeAura = aura

    -- A square holder gives the upright barrel enough room when it turns toward a wall.
    local barrel = CreateFrame("Frame", nil, holder)
    barrel:SetSize(CFG.cannon_barrel_h, CFG.cannon_barrel_h)
    barrel:SetScale(CFG.cannon_barrel_scale)
    barrel:SetPoint("CENTER", holder, "TOPLEFT", Logic.SHOOTER_X + CFG.cannon_barrel_ofs_x,
        -(Logic.SHOOTER_Y + CFG.cannon_barrel_ofs_y))
    barrel:SetFrameLevel(level + 1)
    barrel:EnableMouse(false)
    local barrelTex = barrel:CreateTexture(nil, "ARTWORK")
    barrelTex:SetSize(CFG.cannon_barrel_w, CFG.cannon_barrel_h)
    barrelTex:SetPoint("CENTER", barrel, "CENTER", 0, 0)
    barrelTex:SetTexture(CFG.cannon_barrel_path)
    self._cannonBarrel = barrel
    self._cannonBarrelTex = barrelTex

    local nextSocket = CreateFrame("Frame", nil, holder)
    nextSocket:SetSize(CFG.cannon_next_socket_w, CFG.cannon_next_socket_h)
    nextSocket:SetScale(CFG.cannon_next_socket_scale)
    nextSocket:SetPoint("CENTER", holder, "TOPLEFT",
        Logic.SHOOTER_X + CFG.cannon_next_ofs_x, -(Logic.SHOOTER_Y + CFG.cannon_next_ofs_y))
    nextSocket:SetFrameLevel(level + 5)
    nextSocket:EnableMouse(false)
    local nextSocketTex = nextSocket:CreateTexture(nil, "ARTWORK")
    nextSocketTex:SetAllPoints(nextSocket)
    nextSocketTex:SetTexture(CFG.cannon_next_socket_path)
    nextSocket:Hide()
    self._nextSocket = nextSocket
    self._nextSocketTex = nextSocketTex

    local nextLabel = CreateFrame("Frame", nil, holder)
    nextLabel:SetAllPoints(nextSocket)
    nextLabel:SetFrameLevel(level + 6)
    nextLabel:EnableMouse(false)
    self._nextLabelFrame = nextLabel
    if self._nextFS then self._nextFS:SetParent(nextLabel) end
    self:_UpdateCannonAim()
end

function R:_UpdateCannonAim()
    local tex = self._cannonBarrelTex
    if not tex or not tex.SetRotation then return end
    -- The source barrel points straight up; aim angles use -pi/2 for that direction.
    tex:SetRotation(-((self._aimAngle or (-math.pi / 2)) + math.pi / 2))
end

function R:_UpdateOverchargeAura(gs)
    local aura = self._overchargeAura
    local active = gs and (gs.overchargeLeft or 0) > 0
    if not aura then return end
    if not active then
        aura:Hide()
        return
    end
    local now = GetTime and GetTime() or 0
    local pulse = 0.45 + 0.55 * math.abs(math.sin(now * 3.4))
    if aura._halo then
        aura._halo:SetVertexColor(0.76, 0.38, 1.00, 0.12 + 0.18 * pulse)
        aura._halo:SetAlpha(pulse)
    end
    for i, rune in ipairs(aura._runes or {}) do
        local a = now * 0.9 + (i - 1) * (math.pi * 2 / 6)
        rune:ClearAllPoints()
        rune:SetPoint("CENTER", aura, "CENTER", math.cos(a) * 27, math.sin(a) * 27)
        rune:SetVertexColor(0.84, 0.54, 1.00, 0.55 + 0.4 * pulse)
    end
    aura:Show()
end

local function PanelFooterLift()
    local Layout = ArcadiaNexus.Layout
    local gc = Layout and Layout.gameControls
    if not gc then return 28 end
    return ((gc.height or 52) + (gc.inset or 4)) * 0.5
end

function R:_PlaceDecor(frame, w, h, ox, oy)
    local outer = self.frame
    if not outer or not frame then return end
    frame:SetParent(outer)
    frame:ClearAllPoints()
    frame:SetSize(w, h)
    frame:SetPoint("CENTER", outer, "CENTER", ox or 0, (oy or 0) + PanelFooterLift())
    frame:EnableMouse(false)
end

function R:_RaisePlayLayer()
    local outer = self.frame
    if not outer then return end
    local base = outer:GetFrameLevel() or 1
    if self._bgFrame then self._bgFrame:SetFrameLevel(base + 1) end
    if self._borderFrame then self._borderFrame:SetFrameLevel(base + 2) end
    if self._canvas then self._canvas:SetFrameLevel(base + 3) end
end

function R:_CreateBackground()
    local outer = self.frame
    if not outer then return end
    local bgFrame = CreateFrame("Frame", nil, outer)
    self:_PlaceDecor(bgFrame, CFG.bg_w, CFG.bg_h, CFG.bg_ofs_x, CFG.bg_ofs_y)
    local tex = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(CFG.bg_path)
    tex:SetAllPoints(bgFrame)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgFrame = bgFrame
    self._bgTex = tex
    self:_CreateAmbientFX()
end

-- Quiet, theme-tinted ley lines.  They are intentionally behind the canvas:
-- gameplay sprites, aim dots and the cannon always remain the focal point.
function R:_CreateAmbientFX()
    if self._ambientFX or not self._bgFrame then return end
    local fx = CreateFrame("Frame", nil, self._bgFrame)
    fx:SetAllPoints(self._bgFrame)
    fx:EnableMouse(false)
    fx:Hide()

    local paths = {
        { x1 = 0.10, y1 = 0.76, x2 = 0.39, y2 = 0.49, speed = 0.048 },
        { x1 = 0.60, y1 = 0.16, x2 = 0.85, y2 = 0.38, speed = 0.036 },
        { x1 = 0.23, y1 = 0.21, x2 = 0.49, y2 = 0.30, speed = 0.030 },
        { x1 = 0.58, y1 = 0.68, x2 = 0.84, y2 = 0.60, speed = 0.042 },
    }
    for i, path in ipairs(paths) do
        local dx, dy = path.x2 - path.x1, path.y2 - path.y1
        local line = fx:CreateTexture(nil, "BACKGROUND", nil, 0)
        line:SetTexture(WHITE)
        line:SetSize(math.sqrt(dx * dx + dy * dy) * CFG.bg_w, CFG.ambient_line_w or 2)
        line:SetPoint("CENTER", fx, "TOPLEFT", (path.x1 + path.x2) * CFG.bg_w * 0.5, -(path.y1 + path.y2) * CFG.bg_h * 0.5)
        line:SetRotation(-math.atan2(dy, dx))
        line:SetBlendMode("ADD")
        path.line = line
        path.motes = {}
        for n = 1, 3 do
            local moteFrame = CreateFrame("Frame", nil, fx)
            moteFrame:SetSize(CFG.ambient_mote_size, CFG.ambient_mote_size)
            moteFrame:EnableMouse(false)
            local mote = moteFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            mote:SetTexture(WHITE)
            mote:SetAllPoints(moteFrame)
            mote:SetBlendMode("ADD")
            AttachCircleMask(moteFrame, mote)
            path.motes[n] = { frame = moteFrame, tex = mote, phase = (i - 1) * 0.31 + (n - 1) / 3 }
        end
    end
    self._ambientFX = { frame = fx, paths = paths, time = 0 }
    self:_RefreshAmbientFX()
end

function R:_RefreshAmbientFX()
    local fx = self._ambientFX
    if not fx then return end
    local TH = ArcadiaNexus.BS_Themes
    local primary = TH and TH:GetGem(ThemeKey(), 1)
    local secondary = TH and TH:GetGem(ThemeKey(), 4)
    local c1 = (primary and primary.color) or { 0.62, 0.28, 0.95 }
    local c2 = (secondary and secondary.color) or { 0.35, 0.78, 1.00 }
    for i, path in ipairs(fx.paths) do
        local c = (i % 2 == 0) and c2 or c1
        path.color = c
        path.line:SetVertexColor(c[1], c[2], c[3], CFG.ambient_line_alpha)
        for _, mote in ipairs(path.motes) do
            mote.tex:SetVertexColor(c[1], c[2], c[3], CFG.ambient_mote_alpha)
        end
    end
end

function R:_TickAmbientFX(dt)
    local fx = self._ambientFX
    if not fx or self.state ~= "PLAYING" then
        self:_StopAmbientFX()
        return
    end
    fx.time = (fx.time or 0) + dt
    for i, path in ipairs(fx.paths) do
        local pulse = 0.55 + 0.45 * math.sin(fx.time * 0.72 + i)
        path.line:SetAlpha((CFG.ambient_line_alpha or 0.09) * pulse)
        for _, mote in ipairs(path.motes) do
            local u = (fx.time * path.speed + mote.phase) % 1
            local x = (path.x1 + (path.x2 - path.x1) * u) * CFG.bg_w
            local y = (path.y1 + (path.y2 - path.y1) * u) * CFG.bg_h
            local shimmer = 0.45 + 0.55 * math.sin(fx.time * 2.1 + mote.phase * math.pi * 2)
            mote.frame:ClearAllPoints()
            mote.frame:SetPoint("CENTER", fx.frame, "TOPLEFT", x, -y)
            mote.frame:SetAlpha((CFG.ambient_mote_alpha or 0.52) * shimmer)
        end
    end
end

function R:_StartAmbientFX()
    self:_CreateAmbientFX()
    local fx = self._ambientFX
    if not fx or self._ambientRunning then return end
    fx.time = 0
    self:_RefreshAmbientFX()
    fx.frame:Show()
    self._ambientRunning = true
    _ambientLoop:Start(function(dt) R:_TickAmbientFX(dt) end, { maxDt = 0.05 })
end

function R:_StopAmbientFX()
    _ambientLoop:Stop()
    self._ambientRunning = false
    if self._ambientFX and self._ambientFX.frame then self._ambientFX.frame:Hide() end
end

function R:_CreateBorderTex()
    local outer = self.frame
    if not outer then return end
    local borderFrame = CreateFrame("Frame", nil, outer)
    self:_PlaceDecor(borderFrame, CFG.border_w, CFG.border_h, CFG.border_ofs_x, CFG.border_ofs_y)
    local tex = borderFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    tex:SetTexture(CFG.border_path)
    tex:SetAllPoints(borderFrame)
    self._borderFrame = borderFrame
    self._borderTex = tex
    self:_RaisePlayLayer()
end

function R:_CreateLogo()
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGameLogo then
        self._logoTex = UI.CreateGameLogo(self._fieldFrame, CFG.logo_path, {
            w = CFG.logo_w, h = CFG.logo_h,
            x = CFG.logo_ofs_x, y = CFG.logo_ofs_y,
            alpha = CFG.logo_alpha,
        })
    end
    local fs = self._fieldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    fs:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, CFG.logo_ofs_y)
    fs:SetText(L["game_title"] or "Arcane Barrage")
    fs:SetTextColor(0.85, 0.72, 0.35)
    if self._logoTex then fs:Hide() end
    self._logoFS = fs

    local hint = self._fieldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, CFG.hint_ofs_y)
    hint:SetWidth(360)
    hint:SetJustifyH("CENTER")
    hint:Hide()
    self._hintFS = hint
end

function R:_CreateHUD()
    local f = self._canvas
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox or not self._fieldFrame then return end
    local side = self._fieldFrame
    local g = CFG.hud_gap
    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_side_w, h = CFG.hud_side_h,
        point = "TOPRIGHT", relativePoint = "TOPLEFT", relativeTo = side,
        x = -g, y = 0, alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Score") .. ": 0",
        shown = false,
    })
    self._comboBox, self._comboFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_side_w, h = CFG.hud_side_h,
        point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", relativeTo = self._scoreBox,
        x = 0, y = -g, alpha = CFG.hud_combo_alpha,
        shown = false,
    })
    self._statsBox, self._statsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_side_w, h = 78,
        point = "TOPLEFT", relativePoint = "TOPRIGHT", relativeTo = side,
        x = g, y = 0, alpha = CFG.hud_stats_alpha,
        shown = false,
    })
    self:_CreatePips()
    self:_CreatePowerFocus()
end

function R:_CreatePips()
    self._pips = {}
    local parent = self._canvas
    for i = 1, 6 do
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetSize(CFG.pip_size, CFG.pip_size)
        t:SetTexture(WHITE)
        t:SetVertexColor(0.3, 0.3, 0.3, 0.8)
        t:Hide()
        if parent.CreateMaskTexture and t.AddMaskTexture then
            local mask = parent:CreateMaskTexture()
            mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(t)
            t:AddMaskTexture(mask)
        end
        self._pips[i] = t
    end
end

function R:_CreatePowerFocus()
    local parent = self._canvas
    local focus = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    focus:SetSize(CFG.hud_side_w, CFG.power_focus_h)
    if self._comboBox then
        focus:SetPoint("TOPRIGHT", self._comboBox, "BOTTOMRIGHT", 0, -CFG.hud_gap)
    elseif self._fieldFrame then
        focus:SetPoint("BOTTOMRIGHT", self._fieldFrame, "BOTTOMLEFT", -CFG.hud_gap, 8)
    end
    focus:SetBackdrop({
        bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    focus:SetBackdropColor(0.05, 0.04, 0.10, 0.88)
    focus:SetBackdropBorderColor(0.55, 0.35, 0.95, 0.9)

    local halo = focus:CreateTexture(nil, "ARTWORK", nil, 0)
    halo:SetSize(CFG.power_focus_core * 2, CFG.power_focus_core * 2)
    halo:SetPoint("CENTER", focus, "CENTER", 0, 5)
    halo:SetTexture(WHITE)
    halo:SetBlendMode("ADD")
    AttachCircleMask(focus, halo)
    focus._halo = halo

    local core = focus:CreateTexture(nil, "ARTWORK", nil, 1)
    core:SetSize(CFG.power_focus_core, CFG.power_focus_core)
    core:SetPoint("CENTER", focus, "CENTER", 0, 5)
    core:SetTexture(WHITE)
    core:SetBlendMode("ADD")
    AttachCircleMask(focus, core)
    focus._core = core

    focus._runes = {}
    for i = 1, 5 do
        local a = -math.pi / 2 + (i - 1) * (math.pi * 2 / 5)
        local rune = focus:CreateTexture(nil, "OVERLAY", nil, 1)
        rune:SetSize(CFG.power_focus_pip, CFG.power_focus_pip)
        rune:SetPoint("CENTER", focus, "CENTER", math.cos(a) * 20, 5 + math.sin(a) * 20)
        rune:SetTexture(WHITE)
        rune:SetBlendMode("ADD")
        AttachCircleMask(focus, rune)
        focus._runes[i] = rune
    end

    local lab = focus:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lab:SetPoint("BOTTOM", focus, "BOTTOM", 0, 3)
    lab:SetTextColor(0.95, 0.85, 0.4)
    lab:SetText("")
    focus._label = lab
    focus:Hide()
    self._powerFocus = focus
end

function R:_SetHudShown(shown)
    local boxes = { self._scoreBox, self._comboBox, self._statsBox, self._powerFocus, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
    if not shown and self._pips then
        for i = 1, #self._pips do self._pips[i]:Hide() end
    end
end

function R:_CreateControls()
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    local S = ArcadiaNexus.BS_Settings
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf
    self._bar = bar

    local modeAnchor = CreateFrame("Frame", nil, cf)
    modeAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    modeAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[3], bar.y.dropdownOfs)
    UI.CreateSimpleDropdown(modeAnchor, 0, 0, CFG.dd_w, "", {
        { key = "endless", label = L["mode_endless"] },
        { key = "time",    label = L["mode_time"] },
        { key = "shot",    label = L["mode_shot"] },
    }, function() return (S and S:Get("mode")) or "endless" end, function(key)
        if S then S:Set("mode", key) end
        R._lastMode = key
    end)
    self._modeAnchor = modeAnchor

    local diffAnchor = CreateFrame("Frame", nil, cf)
    diffAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    diffAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    UI.CreateSimpleDropdown(diffAnchor, 0, 0, CFG.dd_w, "", {
        { key = "easy",   label = L["diff_easy"] },
        { key = "normal", label = L["diff_normal"] },
        { key = "hard",   label = L["diff_hard"] },
    }, function() return (S and S:Get("difficulty")) or "easy" end, function(key)
        if S then S:Set("difficulty", key) end
        R._lastDiff = key
    end)
    self._diffAnchor = diffAnchor

    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function() R:_OnStartClicked() end)
    self._startBtn = startBtn
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L = self:_Loc()
    local S = ArcadiaNexus.BS_Settings
    if not UI or not UI.CreateSaveSlotMenu or not self._fieldFrame then return end
    self._slotMenu = UI.CreateSaveSlotMenu({
        parent = self._fieldFrame,
        maxSlots = (S and S.MAX_SLOTS) or 3,
        L = L,
        title = L.menu_title,
        loadSlot = function(slot) return S and S:LoadSlot(slot) end,
        deleteSlot = function(slot) if S then S:DeleteSlot(slot) end end,
        formatInfo = function(save, loc)
            local score = (ArcadiaNexus.Format and ArcadiaNexus.Format.Score(save.score or 0))
                or tostring(save.score or 0)
            return string.format(loc.slot_info or "Level %d · %s", save.currentLevel or 1, score)
        end,
        isPaused = function(save)
            local Logic = ArcadiaNexus.BS_Logic
            return save and save.paused == true
                and Logic and Logic:GridHasBubbles(save.midGame and save.midGame.grid)
        end,
        onNewGame = function(slot)
            local E = ArcadiaNexus.BS_Engine
            if E then E:OpenCampaignMap(slot, 1) end
        end,
        onContinue = function(slot)
            local E = ArcadiaNexus.BS_Engine
            local save = S and S:LoadSlot(slot)
            if E and save and save.paused then
                E:StartGame({ slot = slot, mode = "continue", playMode = "shot" })
            elseif E then
                E:OpenCampaignMap(slot, save and save.currentLevel or 1)
            end
        end,
    })
end

function R:_CreateCampaignMap()
    if self._campaignMapFrame or not self._fieldFrame then return end
    local UI = ArcadiaNexus.UI
    local f = CreateFrame("Frame", nil, self._fieldFrame, "BackdropTemplate")
    f:SetAllPoints(self._fieldFrame)
    f:SetFrameLevel((self._fieldFrame:GetFrameLevel() or 1) + 20)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.015, 0.025, 0.09, 0.38)
    f:SetBackdropBorderColor(0.64, 0.50, 0.12, 0.9)
    f:Hide()
    self._campaignMapFrame = f

    local art = f:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints(f)
    art:SetAlpha(0.88)
    art:Hide()
    self._campaignMapArt = art

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetTextColor(0.95, 0.80, 0.28)
    self._campaignMapTitle = title
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.60, 0.78, 1.00)
    self._campaignMapSub = sub

    self._campaignPaths = {}
    for i = 1, 9 do
        local line = f:CreateTexture(nil, "ARTWORK", nil, 1)
        line:SetTexture(WHITE)
        line:SetBlendMode("ADD")
        line:SetVertexColor(0.23, 0.57, 1.00, 0.52)
        self._campaignPaths[i] = line
    end

    self._campaignNodes = {}
    for i = 1, 10 do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(38, 38)
        btn:SetFrameLevel((f:GetFrameLevel() or 1) + 3)
        local ring = btn:CreateTexture(nil, "BACKGROUND")
        ring:SetTexture(WHITE)
        ring:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
        ring:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        btn._ring = ring
        btn._ringMask = AttachCircleMask(btn, ring)
        local bg = btn:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(WHITE)
        bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn._bg = bg
        btn._bgMask = AttachCircleMask(btn, bg)
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("CENTER", btn, "CENTER", 0, 0)
        local starHolder = CreateFrame("Frame", nil, f)
        starHolder:SetSize(42, 14)
        starHolder:SetPoint("TOP", btn, "BOTTOM", 0, -1)
        starHolder:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
        btn._starTexs = {}
        for starIndex = 1, 3 do
            local star = starHolder:CreateTexture(nil, "OVERLAY")
            star:SetAtlas("auctionhouse-icon-favorite", false)
            star:SetSize(12, 12)
            star:SetPoint("CENTER", starHolder, "LEFT", 7 + (starIndex - 1) * 14, 0)
            btn._starTexs[starIndex] = star
        end
        btn._numFS, btn._starHolder = num, starHolder
        btn:SetScript("OnClick", function(node)
            if node._locked then return end
            local E = ArcadiaNexus.BS_Engine
            if E then E:SelectCampaignLevel(node._level) end
        end)
        self._campaignNodes[i] = btn
    end

    self._campaignPrev = UI.CreateArcadiaButton(f, "<", 34, 24)
    self._campaignPrev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    self._campaignPrev:SetScript("OnClick", function()
        R._campaignPage = math.max(1, (R._campaignPage or 1) - 1)
        R:_RefreshCampaignMap()
    end)
    self._campaignNext = UI.CreateArcadiaButton(f, ">", 34, 24)
    self._campaignNext:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    self._campaignNext:SetScript("OnClick", function()
        local Map = ArcadiaNexus.BS_CampaignMap
        R._campaignPage = math.min(#(Map and Map.PAGES or {}), (R._campaignPage or 1) + 1)
        R:_RefreshCampaignMap()
    end)
    self._campaignPageBox, self._campaignPageFS = UI.CreateHudStatBox(f, {
        w = 72, h = 24,
        point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 12,
        alpha = 0.94,
        font = "GameFontNormalSmall",
        textColor = { 1.00, 0.82, 0.00 },
    })
end

function R:_HideCampaignMap()
    if self._campaignMapFrame then self._campaignMapFrame:Hide() end
end

function R:ShowCampaignMap(progress, focusLevel)
    local Map = ArcadiaNexus.BS_CampaignMap
    local CP = ArcadiaNexus.CampaignProgress
    if not Map or not CP or not self._campaignMapFrame then return end
    self.state = "MAP"
    self:_ReleaseBoard()
    self:_SetHudShown(false)
    self:_StopAmbientFX()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._slotMenu then self._slotMenu:Hide() end
    if self._logoTex then self._logoTex:Hide() end
    if self._logoFS then self._logoFS:Hide() end
    if self._hintFS then self._hintFS:Hide() end
    if self._gridHolder then self._gridHolder:Hide() end
    if self._modeAnchor then self._modeAnchor:Hide() end
    if self._diffAnchor then self._diffAnchor:Hide() end
    self._campaignProgress = progress
    local _, page = Map:GetPage(focusLevel or progress.currentLevel)
    self._campaignPage = page
    self._campaignMapFrame:Show()
    self:_SetStartBtnStatus()
    self:_RefreshCampaignMap()
end

function R:_RefreshCampaignMap()
    local Map = ArcadiaNexus.BS_CampaignMap
    local CP = ArcadiaNexus.CampaignProgress
    local Levels = ArcadiaNexus.BS_Levels
    if not Map or not CP or not Levels then return end
    local pages = #Map.PAGES
    local pageIndex = math.max(1, math.min(self._campaignPage or 1, pages))
    self._campaignPage = pageIndex
    local def = Map.PAGES[pageIndex]
    local progress = self._campaignProgress or {}
    local L = self:_Loc()
    if self._campaignMapArt then
        if def.asset then
            self._campaignMapArt:SetTexture(def.asset)
            self._campaignMapArt:Show()
        else
            self._campaignMapArt:Hide()
        end
    end
    local first = (pageIndex - 1) * Map.PAGE_SIZE + 1
    if self._campaignMapTitle then
        self._campaignMapTitle:SetText(string.format(L["map_title"] or "%s · Level %d–%d",
            L[def.nameKey] or "", first, math.min(Levels.COUNT, first + 9)))
    end
    if self._campaignMapSub then
        self._campaignMapSub:SetText(string.format(L["map_stars_total"] or "Sterne: %d / %d", CP.TotalStars(progress), Levels.COUNT * 3))
    end
    if self._campaignPageFS then
        self._campaignPageFS:SetText(string.format("%d / %d", pageIndex, pages))
    end

    local w, h = self._campaignMapFrame:GetWidth(), self._campaignMapFrame:GetHeight()
    for i = 1, 9 do
        local a, b = def.nodes[i], def.nodes[i + 1]
        local x1, y1, x2, y2 = a[1] * w, a[2] * h, b[1] * w, b[2] * h
        local dx, dy = x2 - x1, y2 - y1
        local line = self._campaignPaths[i]
        line:ClearAllPoints()
        line:SetSize(math.sqrt(dx * dx + dy * dy), 2)
        line:SetPoint("CENTER", self._campaignMapFrame, "TOPLEFT", (x1 + x2) * 0.5, -(y1 + y2) * 0.5)
        line:SetRotation(math.atan2(-dy, dx))
        line:Show()
    end
    for i = 1, 10 do
        local node, pos = self._campaignNodes[i], def.nodes[i]
        local level = first + i - 1
        node:ClearAllPoints()
        node:SetPoint("CENTER", self._campaignMapFrame, "TOPLEFT", pos[1] * w, -pos[2] * h)
        node._level = level
        local unlocked = level <= Levels.COUNT and CP.IsLevelUnlocked(progress, level, { levelCount = Levels.COUNT })
        local stars = CP.GetStars(progress, level)
        node._locked = not unlocked
        node._numFS:SetText(tostring(level))
        if not unlocked then
            node._bg:SetVertexColor(0.08, 0.08, 0.11, 0.95)
            node._ring:SetVertexColor(0.28, 0.28, 0.33, 1)
            node._numFS:SetTextColor(0.45, 0.45, 0.50)
        elseif level == math.min(progress.currentLevel or 1, Levels.COUNT) then
            node._bg:SetVertexColor(0.18, 0.12, 0.03, 0.98)
            node._ring:SetVertexColor(1, 0.82, 0.22, 1)
            node._numFS:SetTextColor(1, 0.92, 0.44)
        else
            node._bg:SetVertexColor(0.08, 0.17, 0.32, 0.94)
            node._ring:SetVertexColor(0.35, 0.65, 1, 0.9)
            node._numFS:SetTextColor(0.83, 0.91, 1)
        end
        for starIndex = 1, 3 do
            local star = node._starTexs[starIndex]
            if unlocked and starIndex <= stars then
                star:SetVertexColor(1.00, 0.82, 0.00, 1)
            elseif unlocked then
                star:SetVertexColor(0.45, 0.45, 0.48, 0.72)
            else
                star:SetVertexColor(0.28, 0.28, 0.33, 0.72)
            end
        end
        node:Show()
    end
    if self._campaignPrev then
        if pageIndex <= 1 then self._campaignPrev:Disable() else self._campaignPrev:Enable() end
    end
    if self._campaignNext then
        if pageIndex >= pages then self._campaignNext:Disable() else self._campaignNext:Enable() end
    end
end

function R:_SetStartBtnStatus()
    if not self._startBtn then return end
    local L = self:_Loc()
    if self.state == "PLAYING" or self.state == "MENU" or self.state == "MAP" then
        self._startBtn:SetLabel(L["btn_exit"])
    else
        self._startBtn:SetLabel(L["btn_start"])
    end
    self._startBtn:Show()
end

function R:_OnStartClicked()
    if self.state == "PLAYING" then
        local E = ArcadiaNexus.BS_Engine
        if E then E:StopGame() end
        return
    end
    if self.state == "MENU" then
        self:EnterIdleState()
        return
    end
    if self.state == "MAP" then
        local E = ArcadiaNexus.BS_Engine
        if E then E:StopGame() end
        return
    end
    local S = ArcadiaNexus.BS_Settings
    local mode = (S and S:Get("mode")) or "endless"
    self._lastMode = mode
    self._lastDiff = (S and S:Get("difficulty")) or "easy"
    if mode == "shot" then
        self:EnterSlotMenu()
        return
    end
    local E = ArcadiaNexus.BS_Engine
    if E then
        E:StartGame({ playMode = mode, difficulty = self._lastDiff, mode = "new" })
    end
end

function R:EnterSlotMenu()
    self.state = "MENU"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoFS then self._logoFS:Hide() end
    if self._logoTex then self._logoTex:Hide() end
    if self._hintFS then self._hintFS:Hide() end
    self:_HideCampaignMap()
    self:_SetStartBtnStatus()
    if self._slotMenu then self._slotMenu:Show() end
end

function R:_ReleaseBoard()
    self:_StopAnims()
    if self._bubblePool then self._bubblePool:ReleaseAll() end
    if self._dotPool then self._dotPool:ReleaseAll() end
    self._boardBubbles = {}
    self._shotBubble = nil
    self._queueBubbles = {}
    if self._nextFS then self._nextFS:Hide() end
end

function R:_StopAnims()
    for _, a in ipairs(self._anims or {}) do
        if a.kind == "float" and a.fs then
            a.fs:Hide()
            a.fs:SetText("")
            a.fs:SetScale(1)
            a.fs._busy = nil
        elseif a.kind == "bolt" and a.tex then
            a.tex:Hide()
            a.tex._busy = nil
        elseif a.kind == "flash" and a.tex then
            a.tex:Hide()
            a.tex:SetVertexColor(1, 1, 1, 0)
        end
    end
    self._anims = {}
    self:_SetFieldShake(0, 0)
    _animLoop:Stop()
    self._animRunning = false
end

function R:_TickAnims(dt)
    local list = self._anims
    if not list or #list == 0 then
        _animLoop:Stop()
        self._animRunning = false
        return
    end
    local Logic = ArcadiaNexus.BS_Logic
    local i = 1
    while i <= #list do
        local a = list[i]
        if a.kind == "bolt" then
            a.t = (a.t or 0) + dt
            local u = a.t / (a.dur or 0.18)
            if u >= 1 or not a.tex then
                if a.tex then
                    a.tex:Hide()
                    a.tex._busy = nil
                end
                table.remove(list, i)
            else
                a.tex:SetAlpha(1 - u)
                i = i + 1
            end
        elseif a.kind == "flash" then
            a.t = (a.t or 0) + dt
            local u = a.t / (a.dur or 0.18)
            if u >= 1 or not a.tex or a.serial ~= self._flashSerial then
                if a.tex and a.serial == self._flashSerial then
                    a.tex:Hide()
                    a.tex:SetVertexColor(1, 1, 1, 0)
                end
                table.remove(list, i)
            else
                a.tex:SetVertexColor(a.r, a.g, a.b, (a.alpha or 0.45) * (1 - u))
                i = i + 1
            end
        elseif a.kind == "float" then
            a.t = (a.t or 0) + dt
            local u = a.t / (a.dur or 0.7)
            if u < 0 then u = 0 end
            if u >= 1 or not a.fs then
                if a.fs then
                    a.fs:Hide()
                    a.fs:SetText("")
                    a.fs:SetScale(1)
                    a.fs._busy = nil
                end
                table.remove(list, i)
            else
                a.fs:ClearAllPoints()
                a.fs:SetPoint("CENTER", self._gridHolder, "TOPLEFT", a.x, -(a.y - (a.rise or CFG.float_ofs_y or 22) * u))
                a.fs:SetAlpha(1 - u * u)
                i = i + 1
            end
        elseif a.kind == "shake" then
            a.t = (a.t or 0) + dt
            local u = a.t / (a.dur or 0.22)
            if u >= 1 then
                self:_SetFieldShake(0, 0)
                table.remove(list, i)
            else
                local fade = 1 - u
                local wave = math.sin(u * math.pi * 8)
                local amp = (a.amplitude or 0) * fade
                self:_SetFieldShake(wave * amp, math.cos(u * math.pi * 6) * amp * 0.35)
                i = i + 1
            end
        elseif (a.wait or 0) > 0 then
            a.wait = a.wait - dt
            i = i + 1
        else
            if a.kind == "pop" and not a._burst and a.x and a.y then
                a._burst = true
                self:_SpawnShards(a.x, a.y, a.color)
            end
            a.t = (a.t or 0) + dt
            local u = a.t / (a.dur or 0.2)
            if u < 0 then u = 0 end
            local f = a.frame
            if u >= 1 or not f then
                if a.kind == "place" and f then
                    f:SetScale(1)
                    f:SetAlpha(1)
                else
                    if f and self._bubblePool then
                        self._bubblePool:Release(f)
                    end
                    if a.key and self._boardBubbles then
                        self._boardBubbles[a.key] = nil
                    end
                end
                table.remove(list, i)
            else
                if a.kind == "pop" then
                    local sc = 1 + 0.55 * math.sin(math.min(u, 1) * math.pi)
                    f:SetScale(sc)
                    f:SetAlpha(1 - u * u)
                elseif a.kind == "fall" then
                    local ny = a.y0 + (Logic.FIELD_H - a.y0 + 36) * (u * u)
                    local sway = math.sin(u * math.pi * 3) * (a.wobble or 0) * (1 - u) * (a.swayDir or 1)
                    self:_PlaceOrb(f, a.x + sway, ny)
                    f:SetAlpha(1 - u)
                elseif a.kind == "place" then
                    f:SetScale(1)
                    f:SetAlpha(1)
                elseif a.kind == "trail" then
                    local size = 10 * (1 - u * 0.6)
                    f:SetSize(size, size)
                    self:_PlaceOrb(f, a.x, a.y)
                    f:SetSize(size, size)
                    f:SetAlpha(1 - u)
                elseif a.kind == "shard" or a.kind == "spark" then
                    local nx = a.x + a.vx * a.t
                    local ny = a.y + a.vy * a.t + 90 * a.t * a.t
                    local size = (Logic.CELL or 32) * (0.28 - 0.16 * u)
                    f:SetSize(size, size)
                    self:_PlaceOrb(f, nx, ny)
                    f:SetSize(size, size)
                    f:SetAlpha(1 - u)
                end
                i = i + 1
            end
        end
    end
end

function R:_SpawnShards(x, y, color)
    local Logic = ArcadiaNexus.BS_Logic
    local TH = ArcadiaNexus.BS_Themes
    local gem = TH and TH:GetGem(ThemeKey(), color or 1)
    local n = 4
    for s = 1, n do
        local f = self._bubblePool:Acquire({ parent = self._gridHolder })
        local size = (Logic.CELL or 32) * 0.28
        f:EnableMouse(false)
        f:SetScript("OnClick", nil)
        f:SetParent(self._gridHolder)
        f:SetSize(size, size)
        PaintGem(f._tex, f._bg, gem)
        if f._shine then f._shine:SetAlpha(0.15) end
        local ang = (s - 1) * (math.pi * 2 / n) + 0.35
        local spd = 70 + math.random() * 50
        self:_PlaceOrb(f, x, y)
        f:SetSize(size, size)
        f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 24)
        self:_PushAnim({
            kind = "shard", frame = f, t = 0, dur = 0.26,
            x = x, y = y,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd - 20,
        })
    end
end

function R:_StartAnims()
    if self._animRunning then return end
    self._animRunning = true
    _animLoop:Start(function(dt) R:_TickAnims(dt) end, { maxDt = 0.05 })
end

function R:_PushAnim(anim)
    self._anims = self._anims or {}
    self._anims[#self._anims + 1] = anim
    self:_StartAnims()
end

function R:_AcquireFloatFS()
    self._floatPool = self._floatPool or {}
    for i = 1, #self._floatPool do
        local fs = self._floatPool[i]
        if fs and not fs._busy then return fs end
    end
    local parent = self._gridHolder or self._fieldFrame
    if not parent then return nil end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetJustifyH("CENTER")
    self._floatPool[#self._floatPool + 1] = fs
    return fs
end

function R:_FloatText(x, y, text, r, g, b, opts)
    local fs = self:_AcquireFloatFS()
    if not fs or not text then return end
    opts = opts or {}
    fs._busy = true
    fs:SetParent((opts.topLayer and self._comboFloatLayer) or self._gridHolder or fs:GetParent())
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", self._gridHolder, "TOPLEFT", x, -y)
    fs:SetTextColor(r or 1, g or 0.85, b or 0.2)
    fs:SetText(text)
    fs:SetScale(opts.scale or 1)
    fs:SetAlpha(1)
    fs:Show()
    self:_PushAnim({
        kind = "float", fs = fs, t = 0, dur = opts.dur or 0.72,
        x = x, y = y, rise = opts.rise,
    })
end

function R:_SetFieldShake(x, y)
    if not self._fieldFrame or not self._canvas then return end
    self._fieldFrame:ClearAllPoints()
    self._fieldFrame:SetPoint("CENTER", self._canvas, "CENTER",
        (CFG.field_ofs_x or 0) + (x or 0), (CFG.field_ofs_y or 0) + (y or 0))
end

function R:_ShakeField(amplitude, duration)
    if not amplitude or amplitude <= 0 then return end
    self:_PushAnim({ kind = "shake", t = 0, dur = duration or 0.22, amplitude = amplitude })
end

function R:_ShowComboBurst(x, y, combo)
    combo = combo or 1
    if combo < 2 then return end
    local L = self:_Loc()
    local text, r, g, b
    if combo >= 5 then
        text, r, g, b = string.format(L["combo_barrage"] or "ARCANE BARRAGE x%d", combo), 0.82, 0.52, 1
    elseif combo == 4 then
        text, r, g, b = string.format(L["combo_surge"] or "LEY SURGE x%d", combo), 0.36, 0.78, 1
    elseif combo == 3 then
        text, r, g, b = string.format(L["combo_arcane"] or "ARCANE COMBO x%d", combo), 0.72, 0.42, 1
    else
        text, r, g, b = string.format(L["combo_basic"] or "COMBO x%d", combo), 1, 0.86, 0.25
    end
    self:_FloatText(x, y, text, r, g, b, {
        scale = CFG.combo_burst_scale or 1.35,
        rise = CFG.combo_burst_rise or 34,
        dur = 0.92,
        topLayer = true,
    })
    if combo >= 4 then self:FlashScreen(r, g, b, 0.18) end
end

function R:_SpawnTrail(gs)
    local shot = gs and gs.shot
    if not shot or not shot.active or not shot.power then return end
    local glow = POWER_GLOW[shot.power] or { 1, 0.8, 0.3 }
    local f = self._bubblePool:Acquire({ parent = self._gridHolder })
    local size = shot.power == "dragonfire" and 16 or 10
    f:EnableMouse(false)
    f:SetScript("OnClick", nil)
    f:SetSize(size, size)
    if f._tex then
        f._tex:SetTexture(WHITE)
        f._tex:SetVertexColor(glow[1], glow[2], glow[3], 0.8)
    end
    if f._bg then f._bg:SetVertexColor(glow[1], glow[2], glow[3], 0.45) end
    if f._shine then f._shine:SetAlpha(0.2) end
    ApplyPowerLook(f, nil)
    ApplyColorMark(f, nil)
    self:_PlaceOrb(f, shot.x, shot.y)
    f:SetSize(size, size)
    f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 16)
    self:_PushAnim({
        kind = "trail", frame = f, t = 0, dur = shot.power == "dragonfire" and 0.24 or 0.18,
        x = shot.x, y = shot.y, vx = 0, vy = 0,
    })
end

function R:_AcquireBoltTex()
    self._boltPool = self._boltPool or {}
    for _, tex in ipairs(self._boltPool) do
        if not tex._busy then return tex end
    end
    local tex = self._gridHolder:CreateTexture(nil, "OVERLAY", nil, 6)
    tex:SetTexture(WHITE)
    tex:SetBlendMode("ADD")
    tex:Hide()
    self._boltPool[#self._boltPool + 1] = tex
    return tex
end

function R:_SpawnBoltSegment(x1, y1, x2, y2)
    local tex = self:_AcquireBoltTex()
    if not tex then return end
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    tex._busy = true
    tex:ClearAllPoints()
    tex:SetSize(len, 2)
    tex:SetPoint("CENTER", self._gridHolder, "TOPLEFT", (x1 + x2) * 0.5, -(y1 + y2) * 0.5)
    tex:SetRotation(-math.atan2(dy, dx))
    tex:SetVertexColor(0.42, 0.86, 1.00, 0.95)
    tex:SetAlpha(1)
    tex:Show()
    self:_PushAnim({ kind = "bolt", tex = tex, t = 0, dur = 0.16 })
end

function R:_SpawnLightningArc(x1, y1, x2, y2)
    local wobble = 5 + math.abs(math.sin((x1 + y2) * 0.07)) * 5
    local mx = (x1 + x2) * 0.5 + math.sin((x2 - y1) * 0.11) * wobble
    local my = (y1 + y2) * 0.5 + math.cos((x1 + y2) * 0.09) * wobble
    self:_SpawnBoltSegment(x1, y1, mx, my)
    self:_SpawnBoltSegment(mx, my, x2, y2)
end

function R:_SpawnPowerBurst(x, y, power, count)
    local color = POWER_GLOW[power] or { 1, 0.82, 0.25 }
    for i = 1, count or 6 do
        local f = self._bubblePool:Acquire({ parent = self._gridHolder })
        local size = 7 + (i % 3) * 2
        f:EnableMouse(false)
        f:SetScript("OnClick", nil)
        f:SetSize(size, size)
        if f._tex then
            f._tex:SetTexture(WHITE)
            f._tex:SetVertexColor(color[1], color[2], color[3], 0.95)
        end
        if f._bg then f._bg:SetVertexColor(color[1], color[2], color[3], 0.45) end
        if f._shine then f._shine:SetAlpha(0.15) end
        ApplyPowerLook(f, nil)
        ApplyColorMark(f, nil)
        local a = (i - 1) * (math.pi * 2 / (count or 6))
        local speed = 55 + i * 9
        self:_PlaceOrb(f, x, y)
        f:SetSize(size, size)
        f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 26)
        self:_PushAnim({ kind = "spark", frame = f, t = 0, dur = 0.28, x = x, y = y,
            vx = math.cos(a) * speed, vy = math.sin(a) * speed })
    end
end

function R:_ShowPowerImpact(gs, result)
    local power = result and result.power
    if not power or not gs or not gs.shot then return end
    local x, y = gs.shot.x, gs.shot.y
    if power == "lightning" then
        local Logic = ArcadiaNexus.BS_Logic
        for _, cell in ipairs(result.destroyed or {}) do
            local tx, ty = Logic:HexToPixel(cell[1], cell[2])
            self:_SpawnLightningArc(x, y, tx, ty)
        end
        self:_SpawnPowerBurst(x, y, power, 4)
    elseif power == "bomb" then
        self:_SpawnPowerBurst(x, y, power, 10)
        self:FlashScreen(1, 0.35, 0.08, 0.24)
    elseif power == "dragonfire" then
        self:_SpawnPowerBurst(x, y, power, 7)
    end
end

function R:OnWallBounce(gs)
    local shot = gs and gs.shot
    if not shot then return end
    local x, y = shot.x, shot.y
    for s = 1, 5 do
        local f = self._bubblePool:Acquire({ parent = self._gridHolder })
        local size = 6
        f:EnableMouse(false)
        f:SetScript("OnClick", nil)
        f:SetSize(size, size)
        if f._tex then
            f._tex:SetTexture(WHITE)
            f._tex:SetVertexColor(1, 0.92, 0.55, 1)
        end
        if f._bg then f._bg:SetVertexColor(1, 0.8, 0.3, 0.6) end
        if f._shine then f._shine:SetAlpha(0.5) end
        ApplyPowerLook(f, nil)
        ApplyColorMark(f, nil)
        local ang = (s - 1) * (math.pi * 2 / 5)
        local spd = 55 + s * 8
        self:_PlaceOrb(f, x, y)
        f:SetSize(size, size)
        f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 26)
        self:_PushAnim({
            kind = "spark", frame = f, t = 0, dur = 0.22,
            x = x, y = y,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
        })
    end
end

function R:_HideFlying()
    if self._shotBubble and self._bubblePool then
        self._bubblePool:Release(self._shotBubble)
    end
    self._shotBubble = nil
end

function R:_OrbAt(row, col, color)
    local key = row * 100 + col
    local f = self._boardBubbles[key]
    if f then return f, key end
    if not color or color <= 0 then return nil, key end
    f = self:_AcquireBoardOrb(row, col, color, false)
    self._boardBubbles[key] = f
    return f, key
end

function R:_PlaceOrb(frame, x, y)
    local Logic = ArcadiaNexus.BS_Logic
    frame:SetParent(self._gridHolder)
    frame:ClearAllPoints()
    frame:SetSize(Logic.CELL, Logic.CELL)
    frame:SetPoint("CENTER", self._gridHolder, "TOPLEFT", x, -y)
    frame:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 5)
    frame:Show()
end

function R:_AcquireBoardOrb(row, col, color, clickable)
    local f = self._bubblePool:Acquire({ parent = self._gridHolder })
    local Logic = ArcadiaNexus.BS_Logic
    local TH = ArcadiaNexus.BS_Themes
    local x, y = Logic:HexToPixel(row, col)
    self:_PlaceOrb(f, x, y)
    f._row, f._col, f._color = row, col, color
    PaintGem(f._tex, f._bg, TH and TH:GetGem(ThemeKey(), color))
    ApplyColorMark(f, color)
    f:EnableMouse(clickable == true)
    if clickable then
        f:SetScript("OnClick", function(btn)
            if not CursorInCircle(btn) then return end
            local E = ArcadiaNexus.BS_Engine
            if E then E:UseJoker(color) end
        end)
    else
        f:SetScript("OnClick", nil)
    end
    return f
end

function R:SyncBoard(gs)
    if not gs or not self._gridHolder then return end
    self:_StopAnims()
    self._bubblePool:ReleaseAll()
    self._boardBubbles = {}
    self._shotBubble = nil
    self._queueBubbles = {}
    local joker = gs.pendingPower == "joker"
    for r = 1, gs.rows do
        for c = 1, gs.cols do
            local color = gs.grid[r][c]
            if color and color > 0 then
                local f = self:_AcquireBoardOrb(r, c, color, joker)
                self._boardBubbles[r * 100 + c] = f
            end
        end
    end
    self:_SyncQueue(gs)
    self:_SyncFlying(gs)
    if self._goldGrid and ArcadiaNexus.UI.FitGoldGridFrame then
        ArcadiaNexus.UI.FitGoldGridFrame(self._goldGrid, self._gridHolder, GoldGridLayout())
    end
end

function R:_SyncQueue(gs)
    local Logic = ArcadiaNexus.BS_Logic
    local TH = ArcadiaNexus.BS_Themes
    local L = self:_Loc()
    local theme = ThemeKey()
    local flying = gs.shot and gs.shot.active
    local current = (not flying) and gs.queue and gs.queue[1]
    local upcoming = flying and (gs.queue and gs.queue[1]) or (gs.queue and gs.queue[2])
    if current and current > 0 then
        local f = self._bubblePool:Acquire({ parent = self._gridHolder })
        f:SetParent(self._gridHolder)
        f:ClearAllPoints()
        f:SetSize(Logic.CELL, Logic.CELL)
        self:_PlaceLoadedBubble(f)
        PaintGem(f._tex, f._bg, TH and TH:GetGem(theme, current))
        ApplyPowerLook(f, gs.pendingPower)
        ApplyColorMark(f, current)
        f:EnableMouse(false)
        f:Show()
        self._queueBubbles[1] = f
    end
    if upcoming and upcoming > 0 then
        local f = self._bubblePool:Acquire({ parent = self._gridHolder })
        f:SetParent(self._gridHolder)
        f:ClearAllPoints()
        f:SetSize(Logic.CELL * CFG.cannon_next_bubble_scale, Logic.CELL * CFG.cannon_next_bubble_scale)
        self:_PlaceNextBubble(f)
        PaintGem(f._tex, f._bg, TH and TH:GetGem(theme, upcoming))
        ApplyPowerLook(f, nil)
        ApplyColorMark(f, upcoming)
        f:EnableMouse(false)
        f:Show()
        self._queueBubbles[2] = f
        if self._nextSocket then self._nextSocket:Show() end
        if self._nextFS then
            self._nextFS:ClearAllPoints()
            self._nextFS:SetPoint("BOTTOM", self._nextLabelFrame or f, "TOP",
                CFG.cannon_next_label_ofs_x or 0, CFG.cannon_next_label_ofs_y or 0)
            self._nextFS:SetText(L["lbl_next"] or "NEXT")
            self._nextFS:Show()
        end
    else
        if self._nextFS then self._nextFS:Hide() end
        if self._nextSocket then self._nextSocket:Hide() end
    end
end

function R:_PlaceNextBubble(frame)
    if not frame then return end
    if self._nextSocket then
        frame:SetPoint("CENTER", self._nextSocket, "CENTER",
            CFG.cannon_next_bubble_ofs_x or 0, CFG.cannon_next_bubble_ofs_y or 0)
        frame:SetFrameLevel(math.max(1, (self._nextSocket:GetFrameLevel() or 2) - 1))
    else
        local Logic = ArcadiaNexus.BS_Logic
        frame:SetPoint("CENTER", self._gridHolder, "TOPLEFT",
            Logic.SHOOTER_X + CFG.cannon_next_ofs_x, -(Logic.SHOOTER_Y + CFG.cannon_next_ofs_y))
    end
end

function R:_PlaceLoadedBubble(frame)
    if not frame or not self._gridHolder then return end
    local Logic = ArcadiaNexus.BS_Logic
    local angle = self._aimAngle or (-math.pi / 2)
    local distance = CFG.cannon_loaded_aim_distance or 0
    local pivotX = Logic.SHOOTER_X + (CFG.cannon_barrel_ofs_x or 0)
    local pivotY = Logic.SHOOTER_Y + (CFG.cannon_barrel_ofs_y or 0)
    -- Rotate the configured idle position around the barrel's actual pivot.  Keeping
    -- this baseline means the loaded bubble traces the same radius as the muzzle.
    local baseX = (CFG.cannon_loaded_ofs_x or 0) - (CFG.cannon_barrel_ofs_x or 0)
    local baseY = (CFG.cannon_loaded_ofs_y or 0) - (CFG.cannon_barrel_ofs_y or 0) - distance
    local turn = angle + math.pi / 2
    local cosTurn, sinTurn = math.cos(turn), math.sin(turn)
    local x = pivotX + baseX * cosTurn - baseY * sinTurn
    local y = pivotY + baseX * sinTurn + baseY * cosTurn
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", self._gridHolder, "TOPLEFT", x, -y)
    -- Keep the loaded projectile above both cannon layers, regardless of pool reuse.
    frame:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 12)
end

function R:_SyncFlying(gs)
    local shot = gs.shot
    if not shot or not shot.active then return end
    local Logic = ArcadiaNexus.BS_Logic
    local TH = ArcadiaNexus.BS_Themes
    local f = self._bubblePool:Acquire({ parent = self._gridHolder })
    self:_PlaceOrb(f, shot.x, shot.y)
    PaintGem(f._tex, f._bg, TH and TH:GetGem(ThemeKey(), shot.color or 1))
    ApplyPowerLook(f, shot.power)
    ApplyColorMark(f, shot.color or 1)
    self._shotBubble = f
end

function R:GetAimAngle()
    return self._aimAngle or (-math.pi / 2)
end

function R:SetPadAim(x, y)
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    if (x * x + y * y) < 0.12 then
        return
    end
    local ang = math.atan2(-y, x)
    if ang > -0.18 then
        ang = -0.18
    elseif ang < (-math.pi + 0.18) then
        ang = -math.pi + 0.18
    end
    self._padAim = true
    self._aimAngle = ang
end

function R:ClearPadAim()
    self._padAim = false
end

function R:_CursorGrid()
    local holder = self._gridHolder
    if not holder then return nil, nil end
    local left, bottom = holder:GetLeft(), holder:GetBottom()
    if not left or not bottom then return nil, nil end
    local scale = holder:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    local Logic = ArcadiaNexus.BS_Logic
    local gx = cx / scale - left
    local gy = Logic.FIELD_H - (cy / scale - bottom)
    return gx, gy
end

function R:UpdateAim(gs)
    local Logic = ArcadiaNexus.BS_Logic
    if not gs or not Logic then return end
    if not self._padAim then
        local gx, gy = self:_CursorGrid()
        if gx then
            local dx = gx - Logic.SHOOTER_X
            local dy = gy - Logic.SHOOTER_Y
            local ang = math.atan2(dy, dx)
            if dy > -8 then
                ang = (dx >= 0) and -0.18 or (-math.pi + 0.18)
            end
            self._aimAngle = ang
        end
    end
    self:_UpdateCannonAim()
    self:_PlaceLoadedBubble(self._queueBubbles and self._queueBubbles[1])
    self._dotPool:ReleaseAll()
    local points = Logic:AimPreview(gs, self._aimAngle, gs.difficulty)
    local gem = ArcadiaNexus.BS_Themes and ArcadiaNexus.BS_Themes:GetGem(ThemeKey(), gs.queue[1] or 1)
    local col = (gem and gem.color) or { 1, 1, 1 }
    local step = 2
    for i = 1, #points, step do
        local p = points[i]
        local d = self._dotPool:Acquire({ parent = self._gridHolder })
        d:SetParent(self._gridHolder)
        d:ClearAllPoints()
        d:SetPoint("CENTER", self._gridHolder, "TOPLEFT", p[1], -p[2])
        if d._tex then d._tex:SetVertexColor(col[1], col[2], col[3], 0.75) end
        d:Show()
    end
end

function R:UpdateHUD(gs)
    if not gs then return end
    local L = self:_Loc()
    local Logic = ArcadiaNexus.BS_Logic
    if self._scoreFS then
        self._scoreFS:SetJustifyH("CENTER")
        self._scoreFS:SetText(string.format("%s\n%s",
            L["lbl_score"] or "Score", tostring(gs.score or 0)))
    end
    if self._comboFS then
        local oc = (gs.overchargeLeft or 0) > 0
            and string.format("\n|cffffcc00%s %.0fs|r", L["lbl_overcharge"] or "OC", gs.overchargeLeft)
            or ""
        self._comboFS:SetJustifyH("CENTER")
        self._comboFS:SetText(string.format("%s x%d%s", L["lbl_combo"] or "Combo", gs.combo or 1, oc))
    end
    if self._statsFS then
        local bits = {}
        if gs.mode == "shot" then
            local Levels = ArcadiaNexus.BS_Levels
            bits[#bits + 1] = string.format("%s %d/%d", L["lbl_level"] or "Level", gs.levelIndex or 1, Levels and Levels.COUNT or 10)
            local def = Levels and Levels.Get and Levels:Get(gs.levelIndex)
            if def then
                local name
                if def.nameKey == "lvl_gen" then
                    name = string.format(L["lvl_gen"] or "Barrage %d", gs.levelIndex or 1)
                elseif def.nameKey then
                    name = L[def.nameKey]
                end
                if name and name ~= "" then
                    bits[#bits + 1] = name
                end
            end
            local left = (gs.shotLimit or 0) - (gs.shotsUsed or 0)
            bits[#bits + 1] = string.format("%s %d", L["lbl_shots"] or "Shots", math.max(0, left))
        elseif gs.mode == "time" then
            local t = math.max(0, math.floor(gs.timeLeft or 0))
            bits[#bits + 1] = string.format("%s %s", L["lbl_time"] or "Time",
                ArcadiaNexus.Format and ArcadiaNexus.Format.SecondsMMSS(t, false) or tostring(t))
        else
            bits[#bits + 1] = L["mode_endless"] or "Endless"
        end
        if gs.pendingPower then
            local pk = "power_" .. gs.pendingPower
            bits[#bits + 1] = string.format(L["hint_power"] or "%s", L[pk] or gs.pendingPower)
        end
        self._statsFS:SetJustifyH("CENTER")
        self._statsFS:SetText(table.concat(bits, "\n"))
    end
    if self._powerFocus then
        local focus = self._powerFocus
        local ready = gs.pendingPower ~= nil
        local overcharge = (gs.overchargeLeft or 0) > 0
        local frac = ready and 1 or math.min(1, (gs.energy or 0) / (Logic.POWER_MAX or 100))
        local color = overcharge and { 0.78, 0.42, 1.00 }
            or (ready and (POWER_GLOW[gs.pendingPower] or { 1.00, 0.82, 0.25 })
            or { 0.55, 0.35, 0.95 })
        local now = (GetTime and GetTime() or 0)
        local pulse = (ready or overcharge) and (0.62 + 0.38 * math.abs(math.sin(now * 5))) or 1
        if focus._core then
            focus._core:SetVertexColor(color[1], color[2], color[3], 0.22 + 0.78 * frac)
            focus._core:SetAlpha(pulse)
        end
        if focus._halo then
            focus._halo:SetVertexColor(color[1], color[2], color[3], 0.16 + 0.24 * frac)
            focus._halo:SetAlpha(pulse)
        end
        for i, rune in ipairs(focus._runes or {}) do
            local threshold = i / #(focus._runes or {})
            local lit = ready or frac >= threshold
            rune:SetVertexColor(color[1], color[2], color[3], lit and pulse or 0.16)
        end
        if focus._label then
            if overcharge then
                focus._label:SetText(string.format("%s %.0fs", L["lbl_overcharge"] or "OVERCHARGE", gs.overchargeLeft or 0))
            elseif ready then
                local pk = "power_" .. gs.pendingPower
                focus._label:SetText(L[pk] or gs.pendingPower)
            else
                focus._label:SetText(string.format("%s %d%%", L["lbl_power"] or "Macht", math.floor(frac * 100 + 0.5)))
            end
            focus._label:SetTextColor(color[1], color[2], color[3])
        end
        focus:SetBackdropBorderColor(color[1], color[2], color[3], 0.58 + 0.42 * pulse)
        focus:Show()
    end
    local showPips = gs.mode == "endless"
    local limit = showPips and Logic:MissLimit(gs) or 0
    local pipAnchor = self._statsBox or self._fieldFrame
    for i = 1, 6 do
        local pip = self._pips[i]
        if not pip then break end
        if showPips and i <= limit then
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", pipAnchor, "BOTTOMLEFT", 8 + (i - 1) * 16, -CFG.hud_gap)
            local used = i <= (gs.misses or 0)
            if used then
                pip:SetVertexColor(0.9, 0.25, 0.2, 1)
            else
                pip:SetVertexColor(0.35, 0.7, 0.35, 0.9)
            end
            pip:Show()
        else
            pip:Hide()
        end
    end
    if self._hintFS and gs.pendingPower == "joker" then
        self._hintFS:SetText(L["hint_joker"] or "")
        self._hintFS:Show()
    elseif self.state == "PLAYING" and self._hintFS then
        self._hintFS:Hide()
    end
    self:_UpdateOverchargeAura(gs)
end

function R:FlashScreen(r, g, b, alpha)
    local S = ArcadiaNexus.BS_Settings
    if S and S:Get("screenFlash") == false then return end
    if not self._flashTex then return end
    self._flashSerial = (self._flashSerial or 0) + 1
    local flashAlpha = alpha or 0.45
    self._flashTex:SetVertexColor(r or 1, g or 0.85, b or 0.2, flashAlpha)
    self._flashTex:Show()
    -- This must not use Engine._timerGuard: RunSequence cancels that guard at
    -- the start of every resolve animation, which previously left flashes on
    -- screen permanently.  Renderer FX are owned by the renderer animation
    -- loop instead.
    self:_PushAnim({
        kind = "flash",
        tex = self._flashTex,
        r = r or 1, g = g or 0.85, b = b or 0.2,
        alpha = flashAlpha,
        serial = self._flashSerial,
        t = 0, dur = 0.18,
    })
end

function R:OnFanfare(gs, result)
    local L = self:_Loc()
    local key = result.fanfare
    local text
    if key == "arcane" then text = L["drop_arcane"]
    elseif key == "massive" then text = L["drop_massive"]
    elseif key == "chain" then text = L["drop_chain"]
    else text = L["drop_small"] end
    if self._fanfareFS then
        self._fanfareFS:SetText(text or "")
        if key == "arcane" then self._fanfareFS:SetTextColor(0.75, 0.45, 1)
        elseif key == "massive" then self._fanfareFS:SetTextColor(1, 0.55, 0.15)
        elseif key == "chain" then self._fanfareFS:SetTextColor(1, 0.85, 0.2)
        else self._fanfareFS:SetTextColor(0.9, 0.9, 0.9) end
    end
    if key == "chain" or key == "massive" or key == "arcane" then
        self:FlashScreen(1, 0.7, 0.2, 0.4)
    end
    local guard = ArcadiaNexus.BS_Engine and ArcadiaNexus.BS_Engine._timerGuard
    if guard then
        guard:After(1.1, function()
            if R._fanfareFS then R._fanfareFS:SetText("") end
        end)
    end
end

function R:OnFrame(gs, dt)
    local E = ArcadiaNexus.BS_Engine
    if E and E.state == "AIMING" then
        self:UpdateAim(gs)
        local cb = ColorblindOn()
        if cb ~= self._cbOn then
            self._cbOn = cb
            if gs then self:SyncBoard(gs) end
        end
        local q = self._queueBubbles and self._queueBubbles[1]
        if q and q._power and q._ring then
            local a = 0.45 + 0.5 * math.abs(math.sin((GetTime and GetTime() or 0) * 5))
            local g = POWER_GLOW[q._power]
            if g then q._ring:SetVertexColor(g[1], g[2], g[3], a) end
        end
        if gs and gs.pendingPower then
            self:UpdateHUD(gs)
        end
    end
    if gs and (gs.overchargeLeft or 0) > 0 and self._comboFS then
        self:UpdateHUD(gs)
    end
    if gs and gs.mode == "time" then
        self:UpdateHUD(gs)
    end
end

function R:OnShotMoved(gs)
    if self._shotBubble and gs.shot then
        self:_PlaceOrb(self._shotBubble, gs.shot.x, gs.shot.y)
        if gs.shot.power then
            self._trailAcc = (self._trailAcc or 0) + 1
            local cadence = gs.shot.power == "dragonfire" and 1 or 2
            if self._trailAcc >= cadence then
                self._trailAcc = 0
                self:_SpawnTrail(gs)
            end
        end
    elseif gs.shot and gs.shot.active then
        self:_SyncFlying(gs)
    end
end

function R:OnShotFired(gs)
    if self._dotPool then self._dotPool:ReleaseAll() end
    self._trailAcc = 0
    self:SyncBoard(gs)
    self:UpdateHUD(gs)
end

function R:OnShotLanded(gs, result)
    if self._dotPool then self._dotPool:ReleaseAll() end
    self:_ShowPowerImpact(gs, result)
    local p = result and result.placed
    if p and self._shotBubble then
        local f = self._shotBubble
        self._shotBubble = nil
        local Logic = ArcadiaNexus.BS_Logic
        local x, y = Logic:HexToPixel(p[1], p[2])
        self:_PlaceOrb(f, x, y)
        f:SetScale(1)
        f:SetAlpha(1)
        f._row, f._col, f._color = p[1], p[2], p[3]
        ApplyPowerLook(f, nil)
        local key = p[1] * 100 + p[2]
        self._boardBubbles[key] = f
    else
        self:_HideFlying()
    end
end

function R:OnPlaced(gs, result)
    local p = result and result.placed
    if not p then return end
    local key = p[1] * 100 + p[2]
    if not (self._boardBubbles and self._boardBubbles[key]) then
        self:_OrbAt(p[1], p[2], p[3])
    end
    self:UpdateHUD(gs)
end

function R:OnPopped(gs, result)
    local Logic = ArcadiaNexus.BS_Logic
    local seen = {}
    local cells = {}
    local function add(cell)
        if not cell then return end
        local r, c = cell[1], cell[2]
        local key = r * 100 + c
        if seen[key] then return end
        seen[key] = true
        cells[#cells + 1] = cell
    end
    for _, cell in ipairs((result and result.popped) or {}) do add(cell) end
    for _, cell in ipairs((result and result.destroyed) or {}) do add(cell) end
    local ox, oy = 0, 0
    if result and result.snapRow then
        ox, oy = Logic:HexToPixel(result.snapRow, result.snapCol)
    elseif cells[1] then
        ox, oy = Logic:HexToPixel(cells[1][1], cells[1][2])
    end
    table.sort(cells, function(a, b)
        local ax, ay = Logic:HexToPixel(a[1], a[2])
        local bx, by = Logic:HexToPixel(b[1], b[2])
        local da = (ax - ox) * (ax - ox) + (ay - oy) * (ay - oy)
        local db = (bx - ox) * (bx - ox) + (by - oy) * (by - oy)
        return da < db
    end)
    for i = 1, #cells do
        local cell = cells[i]
        local r, c, color = cell[1], cell[2], cell[3]
        local key = r * 100 + c
        local f = self._boardBubbles[key]
        if not f then
            f = self:_OrbAt(r, c, color)
        end
        if f then
            f:EnableMouse(false)
            f._animating = true
            f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 20)
            local x, y = Logic:HexToPixel(r, c)
            self._boardBubbles[key] = nil
            self:_PushAnim({
                kind = "pop", frame = f, key = key, t = 0, dur = 0.20,
                wait = (i - 1) * 0.045, x = x, y = y, color = color,
            })
        end
    end
    if (result.popScore or 0) > 0 then
        self:_FloatText(ox, oy, "+" .. tostring(result.popScore), 1, 0.9, 0.25)
    end
    self:_ShowComboBurst(ox, oy, result and result.combo)
    self:UpdateHUD(gs)
end

function R:OnDropped(gs, result)
    local Logic = ArcadiaNexus.BS_Logic
    local dropped = (result and result.dropped) or {}
    local dropN = #dropped
    for i, cell in ipairs(dropped) do
        local r, c, color = cell[1], cell[2], cell[3]
        local f, key = self:_OrbAt(r, c, color)
        if f then
            f:EnableMouse(false)
            f._animating = true
            local x, y = Logic:HexToPixel(r, c)
            f:SetFrameLevel((self._gridHolder:GetFrameLevel() or 1) + 18)
            self:_PushAnim({
                kind = "fall", frame = f, key = key, t = 0, dur = 0.46, x = x, y0 = y,
                wobble = CFG.drop_wobble or 4, swayDir = (i % 2 == 0) and -1 or 1,
            })
            self._boardBubbles[key] = nil
        end
    end
    if dropN >= 8 then
        self:_ShakeField(CFG.drop_shake_large or 5, 0.26)
    elseif dropN >= 4 then
        self:_ShakeField(CFG.drop_shake_medium or 3, 0.20)
    end
    if (result.dropScore or 0) > 0 then
        local cell = result.dropped[1]
        local x, y = Logic.SHOOTER_X, Logic.SHOOTER_Y * 0.35
        if cell then x, y = Logic:HexToPixel(cell[1], cell[2]) end
        self:_FloatText(x, y + 12, "+" .. tostring(result.dropScore), 1, 0.55, 0.2)
    end
    self:UpdateHUD(gs)
end
function R:OnPowerGranted(gs, power)
    self:SyncBoard(gs)
    self:UpdateHUD(gs)
    self:FlashScreen(1, 0.82, 0.25, 0.4)
    if self._fanfareFS then
        local L = self:_Loc()
        local pk = power and ("power_" .. power)
        self._fanfareFS:SetTextColor(1, 0.84, 0.25)
        self._fanfareFS:SetText((pk and L[pk]) or L["lbl_power"] or "Macht")
        local guard = ArcadiaNexus.BS_Engine and ArcadiaNexus.BS_Engine._timerGuard
        if guard then
            guard:After(0.9, function()
                if R._fanfareFS then R._fanfareFS:SetText("") end
            end)
        end
    end
end
function R:OnOvercharge(gs)
    self:FlashScreen(0.7, 0.4, 1, 0.5)
    self:UpdateHUD(gs)
    if self._fanfareFS then
        local L = self:_Loc()
        self._fanfareFS:SetTextColor(0.85, 0.55, 1)
        self._fanfareFS:SetText(L["lbl_overcharge"] or "OVERCHARGE")
        local guard = ArcadiaNexus.BS_Engine and ArcadiaNexus.BS_Engine._timerGuard
        if guard then
            guard:After(1.0, function()
                if R._fanfareFS then R._fanfareFS:SetText("") end
            end)
        end
    end
end
function R:OnRowSpawned(gs) self:SyncBoard(gs) self:UpdateHUD(gs) end
function R:OnJokerHint(gs) self:UpdateHUD(gs) self:SyncBoard(gs) end
function R:OnJokerUsed(gs, color)
    local Logic = ArcadiaNexus.BS_Logic
    self:_SpawnPowerBurst(Logic.SHOOTER_X, Logic.SHOOTER_Y - 28, "joker", 6)
    self:SyncBoard(gs)
    self:UpdateHUD(gs)
end
function R:OnAiming(gs)
    self:SyncBoard(gs)
    self:UpdateHUD(gs)
    self:UpdateAim(gs)
end

function R:OnGameStarted(gs)
    self.state = "PLAYING"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoFS then self._logoFS:Hide() end
    if self._logoTex then self._logoTex:Hide() end
    if self._hintFS then self._hintFS:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end
    self:_HideCampaignMap()
    self:_SetStartBtnStatus()
    if self._modeAnchor then self._modeAnchor:Hide() end
    if self._diffAnchor then self._diffAnchor:Hide() end
    if self._gridHolder then self._gridHolder:Show() end
    self:_SetHudShown(true)
    self:_StartAmbientFX()
    self:SyncBoard(gs)
    self:UpdateHUD(gs)
end

local function ResultLines(gs, L)
    local lines = {
        string.format(L["result_shots"] or "Shots: %d", gs.shotsUsed or 0),
        string.format(L["result_combo"] or "Combo x%d", gs.stats.maxCombo or 1),
        string.format(L["result_drop"] or "Drop %d", gs.stats.maxDrop or 0),
    }
    if gs.mode == "shot" then
        table.insert(lines, 1, string.format(L["result_level"] or "Level %d", gs.levelIndex or 1))
    end
    return lines
end

function R:ShowLevelWin(gs, isNew)
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    local E = ArcadiaNexus.BS_Engine
    UI.ShowArcadeResult(self._fieldFrame, {
        title = L["result_level_win_title"],
        titleColor = { 0.3, 1, 0.3 },
        score = gs.score,
        gameId = GAME_ID,
        difficulty = ArcadiaNexus.BS_Logic.ScoreKey(gs.mode, gs.difficulty),
        result = "WIN",
        newHighscore = isNew,
        lines = ResultLines(gs, L),
        L = L,
        buttons = UI.ResultDialogButtons.Level(L,
            function() if E then E:ContinueToNextLevel() end end,
            function() if E then E:RetryLevel() end end,
            function() if E then E:OpenCampaignMap(E.activeSlot, (gs.levelIndex or 1) + 1) end end
        ),
    })
end

function R:ShowFinalWin(gs, isNew)
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    local E = ArcadiaNexus.BS_Engine
    UI.ShowArcadeResult(self._fieldFrame, {
        title = L["result_final_win_title"],
        titleColor = { 1, 0.84, 0 },
        score = gs.score,
        gameId = GAME_ID,
        difficulty = ArcadiaNexus.BS_Logic.ScoreKey(gs.mode, gs.difficulty),
        result = "WIN",
        newHighscore = isNew,
        lines = ResultLines(gs, L),
        L = L,
        onRetry = function() if E then E:RetryLevel() end end,
        onExit = function() if E then E:OpenCampaignMap(E.activeSlot, gs.levelIndex or 1) end end,
    })
end

function R:ShowArcadeWin(gs, isNew)
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    local E = ArcadiaNexus.BS_Engine
    UI.ShowArcadeResult(self._fieldFrame, {
        title = L["result_level_win_title"],
        titleColor = { 0.3, 1, 0.3 },
        score = gs.score,
        gameId = GAME_ID,
        difficulty = ArcadiaNexus.BS_Logic.ScoreKey(gs.mode, gs.difficulty),
        result = "WIN",
        newHighscore = isNew,
        lines = ResultLines(gs, L),
        L = L,
        onRetry = function()
            if E then
                E:StartGame({ playMode = gs.mode, difficulty = gs.difficulty, mode = "new" })
            end
        end,
        onExit = function() if E then E:StopGame() end end,
    })
end

function R:ShowLoss(gs, isNew)
    local L = self:_Loc()
    local UI = ArcadiaNexus.UI
    local E = ArcadiaNexus.BS_Engine
    local title = L["result_loss_title"]
    if gs.mode == "time" and (gs.timeLeft or 1) <= 0 then
        title = L["result_time_title"]
    end
    UI.ShowArcadeResult(self._fieldFrame, {
        title = title,
        titleColor = { 1, 0.3, 0.3 },
        score = gs.score,
        gameId = GAME_ID,
        difficulty = ArcadiaNexus.BS_Logic.ScoreKey(gs.mode, gs.difficulty),
        result = "LOSS",
        newHighscore = isNew,
        lines = ResultLines(gs, L),
        L = L,
        onRetry = function()
            if E then
                E:StartGame({
                    playMode = gs.mode, difficulty = gs.difficulty, mode = "new",
                    levelIndex = gs.levelIndex or 1, slot = E.activeSlot,
                    preserveProgress = gs.mode == "shot",
                })
            end
        end,
        onExit = function()
            if E and gs.mode == "shot" then
                E:OpenCampaignMap(E.activeSlot, gs.levelIndex or 1)
            elseif E then
                E:StopGame()
            end
        end,
    })
end

function R:EnterIdleState()
    self.state = "IDLE"
    self._padAim = false
    self:_StopAmbientFX()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_ReleaseBoard()
    if self._gridHolder then self._gridHolder:Hide() end
    if self._overchargeAura then self._overchargeAura:Hide() end
    self:_SetHudShown(false)
    if self._logoTex then self._logoTex:Show() end
    if self._logoFS and not self._logoTex then self._logoFS:Show() end
    if self._hintFS then self._hintFS:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end
    self:_HideCampaignMap()
    if self._fanfareFS then self._fanfareFS:SetText("") end
    if self._flashTex then self._flashTex:Hide() end
    self:_SetStartBtnStatus()
    if self._modeAnchor then self._modeAnchor:Show() end
    if self._diffAnchor then self._diffAnchor:Show() end
end

SLASH_ARCADIABUBBLESHOOTER1 = "/bubbleshooter"
SLASH_ARCADIABUBBLESHOOTER2 = "/bshooter"
SLASH_ARCADIABUBBLESHOOTER3 = "/arcanebarrage"
SLASH_ARCADIABUBBLESHOOTER4 = "/abarrage"
SlashCmdList["ARCADIABUBBLESHOOTER"] = function()
    local main = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetMainFrame
        and _G.ArcadiaNexusUI.GetMainFrame()
    if main and not main:IsShown() and _G.Nexus_UI and _G.Nexus_UI.Toggle then
        _G.Nexus_UI.Toggle()
    end
    if _G.Nexus_UI and _G.Nexus_UI.SetTab then
        _G.Nexus_UI.SetTab("GAMES")
    end
    local fn = ArcadiaNexus.UI and ArcadiaNexus.UI._ActivateGameFn
    if fn then fn(GAME_ID) end
end

ArcadiaNexus.RegisterGame({
    id        = GAME_ID,
    label     = "Arcane Barrage",
    renderer  = "BS_Renderer",
    engine    = "BS_Engine",
    container = "_bsContainer",
    category  = "ARCADE",
    matchSeats = 0,
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\BubbleShooter\\assets\\logo\\logo_ab.png",
    xp        = 12,
})
