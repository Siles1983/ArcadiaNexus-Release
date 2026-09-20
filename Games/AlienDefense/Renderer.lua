-- ============================================================
--  AlienDefense – Renderer.lua
--  Reine Darstellung. Schreibt NIEMALS in den Game-State.
-- ============================================================

ArcadiaNexus.AD_Renderer = {}
local R = ArcadiaNexus.AD_Renderer

-- ── Konstanten ────────────────────────────────────────────────
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local AD_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlienDefense\\assets\\"

local AD_ASSETS = {
    player      = AD_PATH .. "sprites\\player_ship_01",
    enemy1      = AD_PATH .. "sprites\\enemy_type1",
    enemy2      = AD_PATH .. "sprites\\enemy_type2",
    enemy3      = AD_PATH .. "sprites\\enemy_type3",
    shot_player = AD_PATH .. "sprites\\player_shot_01",
    shot_laser  = AD_PATH .. "sprites\\player_shot_02",
    shot_alien  = AD_PATH .. "sprites\\enemy_shot_01",
    bg          = AD_PATH .. "background\\bg_01",
    bg_overlay  = AD_PATH .. "background\\bg_overlay",
    logo        = AD_PATH .. "logo\\logo_ad",
    border      = AD_PATH .. "border\\border_ad",
    powerup_weapon = "Interface\\AddOns\\ArcadiaNexus\\Shared\\PowerUp\\power_up_red",
    powerup_shield = "Interface\\AddOns\\ArcadiaNexus\\Shared\\PowerUp\\power_up_green",
}

-- ── CFG – Border / HUD-Boxen ──────────────────────────────────
local CFG = {
    border_w     = 795,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 0,
    border_alpha = 1.0,
    hud_time_w      = 140,
    hud_time_h      = 28,
    hud_time_x      = -210,
    hud_time_y      = 218,
    hud_time_alpha  = 0.75,
    hud_score_w     = 220,
    hud_score_h     = 28,
    hud_score_x     = 170,
    hud_score_y     = 218,
    hud_score_alpha = 0.75,
    hud_wave_w      = 220,
    hud_wave_h      = 28,
    hud_wave_x      = -210,
    hud_wave_y      = -190,
    hud_wave_alpha  = 0.75,
    hud_weapon_w    = 180,
    hud_weapon_h    = 28,
    hud_weapon_x    = 190,
    hud_weapon_y    = -190,
    hud_weapon_alpha = 0.75,
    hud_lives_w      = 150,
    hud_lives_h      = 36,
    hud_lives_x      = 0,
    hud_lives_y      = -192,
    hud_lives_alpha  = 0.75,
    hud_lives_pad    = 8,
}

-- ── Logo-Konstanten ───────────────────────────────────────────
-- Logo wird im IDLE-Zustand im Spielfeld zentriert angezeigt.
-- Beim Spielstart ausgeblendet, bei IDLE wieder eingeblendet.
-- Größe und Position hier anpassen:
local LOGO_W = 400    -- Breite des Logos
local LOGO_H = 300    -- Höhe des Logos
local LOGO_X = 0      -- X-Offset vom CENTER des Spielfelds
local LOGO_Y = 0      -- Y-Offset vom CENTER des Spielfelds

-- ── Layout-Konstanten ─────────────────────────────────────────
-- Spielfeld
local FIELD_W, FIELD_H = 560, 384

-- Spielfeld-Position relativ zum _contentFrame (nur Spielfeld verschieben, nicht Controls)
local FIELD_X =  16   -- Abstand links
local FIELD_Y = -23   -- Abstand oben (negativ = nach unten)

-- Innerer Content-Wrapper (Spielfeld + HUD). Controls sitzen am 600×498-Canvas.
local CONTENT_W = FIELD_W + FIELD_X + FIELD_X   -- 560 + 16 + 16 = 592
local CONTENT_H = 460

-- ── Background-Konstanten (Content-Bereich, hinter dem Spielfeld) ─
-- bg_overlay.tga liegt unter: Games/AlienDefense/assets/background/bg_overlay
-- Position und Größe hier anpassen:
local BG_OVERLAY_W   = 750        -- Breite der Textur (0 = gesamter Container)
local BG_OVERLAY_H   = 525        -- Höhe der Textur  (0 = gesamter Container)
local BG_OVERLAY_X   = 0          -- X-Offset vom CENTER des Containers
local BG_OVERLAY_Y   = 20          -- Y-Offset vom CENTER des Containers
local BG_OVERLAY_ALPHA = 1.0      -- Transparenz (0.0 = unsichtbar, 1.0 = voll)

-- Leben-Icons (Schiff-Texturen)
local LIFE_W, LIFE_H = 20, 30    -- Größe pro Schiff-Icon
local LIFE_GAP = 6                -- Abstand zwischen Icons
local MAX_LIVES = 5               -- Pool-Größe (mehr werden ausgeblendet)

local PLAYER_W, PLAYER_H = 50, 70
local PLAYER_Y = 306
local SHOT_W, SHOT_H = 13, 26
local ALIEN_SHOT_W, ALIEN_SHOT_H = 11, 23
local DROP_W, DROP_H = 20, 20

-- VFX (modern-retro, ohne neue Schiff-Assets)
local TEX_GLOW = "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64"
local TEX_RING = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local TEX_STAR = "Interface\\Cooldown\\star4"

local FX_POOL_SIZE     = 64
local FX_SPARKS        = 7
local HOVER_AMP        = 1.6
local HOVER_SPEED      = 7.0
-- Zwei UV-Schichten + leichter Schiff-Versatz (Tiefe, kein AOD-Flug)
local PARALLAX_FAR_U   = 0.009
local PARALLAX_FAR_V   = 0.0035
local PARALLAX_NEAR_U  = 0.026
local PARALLAX_NEAR_V  = 0.011
local PARALLAX_SHIP_FAR  = 0.016
local PARALLAX_SHIP_NEAR = 0.042
local PARALLAX_NEAR_ALPHA = 0.38
local OVERLAY_DRIFT_X  = 10
local OVERLAY_DRIFT_Y  = 6
local ALIEN_BOB_PX     = 1
local DESCENT_PULSE    = 0.20
local MUZZLE_LIFE      = 0.11
local THRUST_W, THRUST_H = 22, 26

local ALIEN_SIZES = {
    [1] = { w=32, h=24 },
    [2] = { w=24, h=20 },
    [3] = { w=48, h=40 },
}

-- ── State ─────────────────────────────────────────────────────
R.frame           = nil
R._canvas         = nil
R._contentFrame   = nil   -- innerer Wrapper über dem Design-Canvas
R._logoTex        = nil   -- Logo-Textur über contentLabelFS
R._borderFrame    = nil
R._borderTex      = nil
R._fieldFrame     = nil
R._keyFrame       = nil
R._flashFrame     = nil
R._flashTex       = nil
R._pauseOverlay   = nil
R._diffContainer  = nil
R._controlsFrame = nil
R._exitBtn        = nil
R._pauseBtn       = nil
R._resumeBtn      = nil
R._pauseBtnMode   = "pause"
R._diffDropdown   = nil

R._playerTex       = nil
R._alienFrames     = {}
R._shotFrames      = {}
R._alienShotFrames = {}
R._dropFrames      = {}

R._waveFS        = nil
R._scoreFS       = nil
R._livesTextures = {}   -- Pool aus Schiff-Texturen statt FontString
R._timeFS        = nil
R._weaponFS      = nil

R._lastDiff = "easy"
R.state     = "IDLE"

R._flashR, R._flashG, R._flashB = 1, 1, 1

R._fxPool        = {}
R._fieldBgTex    = nil
R._fieldBgNearTex = nil
R._overlayTex    = nil
R._thrustTex     = nil
R._muzzleNodes   = nil
R._muzzleWeapon  = "SINGLE"
R._vfxTime       = 0
R._bgFarU, R._bgFarV   = 0, 0
R._bgNearU, R._bgNearV = 0, 0
R._shipPar       = 0
R._muzzleT       = 0
R._alienBobPhase = 0
R._descentPulse  = 0

R._dbgPlayerBoxes = {}
R._dbgAlienBoxes  = {}
R._dbgShotBoxes   = {}
R._dbgAShortBoxes = {}

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "ALIENDEFENSE",
    label     = "Alien Defense",
    category  = "ARCADE",
    renderer  = "AD_Renderer",
    engine    = "AD_Engine",
    container = "_adContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlienDefense\\assets\\logo\\logo_ad",
    xp        = 14,
})

-- ══════════════════════════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════════════════════════

function R:Init()
    self:_CreateMainFrame()
    if not self.frame then return end
    self:_CreateContentFrame()   -- zentrierter Wrapper zuerst
    self:_CreateHUD()
    self:_CreateFieldFrame()
    self:_CreateLogo()           -- Logo im Spielfeld (IDLE-Startbildschirm)
    self:_CreatePlayerTex()
    self:_CreateFxPool()
    self:_CreateFlash()
    self:_CreateKeyFrame()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreatePauseOverlay()
    self:EnterIdleState()
end

-- ── _CreateMainFrame ──────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AD_Container",
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    local inner = CreateFrame("Frame", nil, self._canvas)
    inner:SetSize(CONTENT_W, CONTENT_H)
    inner:SetPoint("CENTER", self._canvas, "CENTER", 0, 0)
    self._contentFrame = inner
    ArcadiaNexus._adContainer = f
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("ALIENDEFENSE", ArcadiaNexus.AD_Engine, function(E)
            if E.state == "PLAYING" then
                E:SaveAndPause()
            end
        end)
    end)
end

-- ── _CreateContentFrame ───────────────────────────────────────
-- Inner 592×460 Wrapper auf dem Design-Canvas. Controls sitzen am Panel-Footer.
function R:_CreateContentFrame()
    local cf = self._contentFrame

    -- Background-Overlay: sitzt am festen Content-Canvas,
    -- hinter allen Spielelementen (BACKGROUND-Layer).
    -- Position und Größe über BG_OVERLAY_* Konstanten am Dateianfang anpassen.
    local bgTex = cf:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetTexture(AD_ASSETS.bg_overlay)
    if BG_OVERLAY_W > 0 and BG_OVERLAY_H > 0 then
        bgTex:SetSize(BG_OVERLAY_W, BG_OVERLAY_H)
        bgTex:SetPoint("CENTER", cf, "CENTER", BG_OVERLAY_X, BG_OVERLAY_Y)
    else
        bgTex:SetAllPoints(cf)
    end
    bgTex:SetAlpha(BG_OVERLAY_ALPHA)
    self._overlayTex = bgTex
end

-- ── HUD (Content-Ebene: Zeit, Score, Leben-Icons) ─────────────
-- Blueprint: Zeit @ (16,-32), Score @ (224,-32), Leben @ (480,-32)
-- Alle relativ zum _contentFrame (nicht zum rohen f-Frame).
function R:_CreateHUD()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._timeBox, self._timeFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        shown = false,
    })
    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        shown = false,
    })
    local livesFS
    self._livesBox, livesFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_lives_w, h = CFG.hud_lives_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_lives_x, y = CFG.hud_lives_y,
        alpha = CFG.hud_lives_alpha,
        shown = false,
    })
    if livesFS then livesFS:Hide() end

    self._livesTextures = {}
    local livesParent = self._livesBox or canvas
    for i = 1, MAX_LIVES do
        local t = livesParent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(AD_ASSETS.player)
        t:SetSize(LIFE_W, LIFE_H)
        t:SetPoint("LEFT", livesParent, "LEFT",
            (CFG.hud_lives_pad or 8) + (i - 1) * (LIFE_W + LIFE_GAP), 0)
        t:Hide()
        self._livesTextures[i] = t
    end

    self._waveFS   = nil
    self._weaponFS = nil
end

function R:_SetHudShown(shown)
    local boxes = { self._timeBox, self._scoreBox, self._waveBox, self._weaponBox, self._livesBox, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

-- ── _CreateFieldHUD ───────────────────────────────────────────
-- Blueprint: Welle @ (16,-368), Waffe @ (480,-368)
-- → BOTTOMLEFT / BOTTOMRIGHT des Spielfeld-Frames
function R:_CreateFieldHUD()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._waveBox, self._waveFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_wave_w, h = CFG.hud_wave_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_wave_x, y = CFG.hud_wave_y,
        alpha = CFG.hud_wave_alpha,
        shown = false,
    })
    self._weaponBox, self._weaponFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_weapon_w, h = CFG.hud_weapon_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_weapon_x, y = CFG.hud_weapon_y,
        alpha = CFG.hud_weapon_alpha,
        shown = false,
    })
end

-- ── _CreateFieldFrame ─────────────────────────────────────────
-- Blueprint: 560x384, Position über FIELD_X/FIELD_Y steuerbar.
-- Verankert am _contentFrame, nicht am rohen f-Frame.
function R:_CreateFieldFrame()
    local cf = self._contentFrame
    local field = CreateFrame("Frame", nil, cf, "BackdropTemplate")
    field:SetSize(FIELD_W, FIELD_H)
    field:SetPoint("TOPLEFT", cf, "TOPLEFT", FIELD_X, FIELD_Y)
    field:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileEdge=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    field:SetBackdropColor(0, 0, 0.04, 0.96)
    field:SetBackdropBorderColor(0.6, 0.5, 0.2, 0)

    local function MakeStarLayer(sublevel, alpha)
        local t = field:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        t:SetAllPoints(field)
        t:SetTexture(AD_ASSETS.bg, "REPEAT", "REPEAT")
        t:SetHorizTile(true)
        t:SetVertTile(true)
        t:SetAlpha(alpha)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(true) end
        if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        return t
    end
    self._fieldBgTex     = MakeStarLayer(-1, 0.85)
    self._fieldBgNearTex = MakeStarLayer( 0, PARALLAX_NEAR_ALPHA)

    self._fieldFrame = field
    self:_CreateFieldHUD()
    self:_CreateBorder()

    field:SetScript("OnShow", function(frame)
        local fw, fh = frame:GetWidth(), frame:GetHeight()
        if fw and fw > 10 and fh and fh > 10 then
            local L = ArcadiaNexus.AD_Logic
            if L and L.SetFieldSize then L:SetFieldSize(fw, fh) end
            PLAYER_Y = fh - PLAYER_H - 8
        end
    end)
end

-- ── _CreateBorder ─────────────────────────────────────────────
-- border_ad.tga über dem Spielfeld (OVERLAY).
-- Größe und Position über CFG.border_* am Dateianfang anpassen.
function R:_CreateBorder()
    if self._borderFrame then return end
    local field = self._fieldFrame
    local canvas = self._canvas
    if not field or not canvas then return end

    local borderFrame = CreateFrame("Frame", nil, canvas)
    borderFrame:SetFrameLevel(field:GetFrameLevel() + 10)
    borderFrame:EnableMouse(false)
    if CFG.border_w > 0 and CFG.border_h > 0 then
        borderFrame:SetSize(CFG.border_w, CFG.border_h)
        borderFrame:SetPoint("CENTER", field, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    else
        borderFrame:SetAllPoints(field)
    end
    local tex = borderFrame:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(borderFrame)
    tex:SetTexture(AD_ASSETS.border)
    tex:SetAlpha(CFG.border_alpha)

    self._borderFrame = borderFrame
    self._borderTex   = tex

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(canvas, field)
    end
end

-- ── _CreateLogo ───────────────────────────────────────────────
-- Nutzt UI.CreateGameLogo aus UIHelpers.lua.
-- Größe und Position über LOGO_W/H/X/Y am Dateianfang steuerbar.
function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        AD_ASSETS.logo,
        { w=LOGO_W, h=LOGO_H, x=LOGO_X, y=LOGO_Y }
    )
end

local function _MakeAddTex(parent, path, layer)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY")
    tex:SetTexture(path)
    tex:SetBlendMode("ADD")
    tex:Hide()
    return tex
end

function R:_CreatePlayerTex()
    local field = self._fieldFrame
    local t = field:CreateTexture(nil, "ARTWORK")
    t:SetTexture(AD_ASSETS.player)
    t:SetSize(PLAYER_W, PLAYER_H)
    t:SetPoint("TOPLEFT", field, "TOPLEFT", (FIELD_W - PLAYER_W) / 2, -PLAYER_Y)
    t:Hide()
    self._playerTex = t

    local thrust = _MakeAddTex(field, TEX_GLOW, "ARTWORK")
    thrust:SetSize(THRUST_W, THRUST_H)
    self._thrustTex = thrust

    self._muzzleNodes = {}
    for i = 1, 2 do
        self._muzzleNodes[i] = {
            halo = _MakeAddTex(field, TEX_GLOW, "OVERLAY"),
            core = _MakeAddTex(field, TEX_GLOW, "OVERLAY"),
            star = _MakeAddTex(field, TEX_STAR, "OVERLAY"),
        }
    end
end

function R:_CreateFxPool()
    local field = self._fieldFrame
    if not field then return end
    self._fxPool = {}
    for i = 1, FX_POOL_SIZE do
        local tex = field:CreateTexture(nil, "OVERLAY")
        tex:SetBlendMode("ADD")
        tex:Hide()
        self._fxPool[i] = {
            tex = tex, active = false,
            x = 0, y = 0, vx = 0, vy = 0,
            life = 0, max = 0.28,
            w0 = 8, h0 = 8, w1 = 16, h1 = 16,
            r = 1, g = 1, b = 1, a = 1,
            rot = 0, rotSpd = 0, midPeak = false, grav = 0,
        }
    end
end

local function _AcquireFx(pool)
    for i = 1, #pool do
        local p = pool[i]
        if not p.active then return p end
    end
    return nil
end

local function _EmitFx(pool, spec)
    local p = _AcquireFx(pool)
    if not p then return end
    p.active = true
    p.x, p.y = spec.x, spec.y
    p.vx, p.vy = spec.vx or 0, spec.vy or 0
    p.w0, p.h0 = spec.w0, spec.h0 or spec.w0
    p.w1, p.h1 = spec.w1, spec.h1 or spec.w1
    p.life, p.max = spec.life, spec.life
    p.r, p.g, p.b, p.a = spec.r, spec.g, spec.b, spec.a or 1
    p.rot = spec.rot or 0
    p.rotSpd = spec.rotSpd or 0
    p.midPeak = spec.midPeak and true or false
    p.grav = spec.grav or 0
    p.tex:SetTexture(spec.tex)
    p.tex:SetTexCoord(0, 1, 0, 1)
    if p.tex.SetRotation then p.tex:SetRotation(p.rot) end
end

function R:_SpawnExplosion(cx, cy, scale, style)
    local pool = self._fxPool
    if not pool then return end
    local s = scale or 1
    local player = (style == "player")

    -- Weißer Kernblitz
    _EmitFx(pool, {
        tex = TEX_GLOW, x = cx, y = cy,
        w0 = 14 * s, w1 = 32 * s, life = 0.10,
        r = 1.00, g = 0.98, b = 0.85, a = 1.00,
    })
    -- Feuerball
    _EmitFx(pool, {
        tex = TEX_GLOW, x = cx, y = cy,
        w0 = 20 * s, w1 = 52 * s, life = 0.32,
        r = player and 0.35 or 1.00,
        g = player and 0.85 or 0.45,
        b = player and 1.00 or 0.10,
        a = 0.95,
    })
    -- Bloom
    _EmitFx(pool, {
        tex = TEX_GLOW, x = cx, y = cy,
        w0 = 16 * s, w1 = 40 * s, life = 0.24,
        r = player and 0.55 or 0.25,
        g = player and 0.95 or 1.00,
        b = player and 1.00 or 0.30,
        a = 0.70,
    })
    -- Druckwelle
    _EmitFx(pool, {
        tex = TEX_RING, x = cx, y = cy,
        w0 = 18 * s, w1 = 72 * s, life = 0.34,
        r = 1.00, g = player and 0.95 or 0.92, b = player and 0.70 or 0.45, a = 0.90,
        midPeak = true,
    })
    -- Stern-Flash
    _EmitFx(pool, {
        tex = TEX_STAR, x = cx, y = cy,
        w0 = 18 * s, w1 = 46 * s, life = 0.16,
        r = 1.00, g = 0.95, b = 0.40, a = 0.95,
        rot = math.random() * 6.28318, rotSpd = 8,
    })
    for i = 1, FX_SPARKS do
        local ang = (i / FX_SPARKS) * 6.28318 + (math.random() - 0.5) * 0.45
        local spd = 90 + math.random() * 70
        _EmitFx(pool, {
            tex = TEX_GLOW, x = cx, y = cy,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            w0 = 11 * s, w1 = 4 * s, life = 0.26 + math.random() * 0.08,
            r = player and 0.55 or 1.00,
            g = player and (0.80 + math.random() * 0.20) or (0.55 + math.random() * 0.35),
            b = player and 1.00 or 0.12,
            a = 0.95, grav = 70,
        })
    end
end

function R:_HideMuzzle()
    local nodes = self._muzzleNodes
    if not nodes then return end
    for i = 1, #nodes do
        local n = nodes[i]
        n.halo:Hide(); n.core:Hide(); n.star:Hide()
    end
end

function R:_ClearFx()
    local pool = self._fxPool
    if pool then
        for i = 1, #pool do
            local p = pool[i]
            p.active = false
            if p.tex then p.tex:Hide() end
        end
    end
    self._muzzleT = 0
    self:_HideMuzzle()
    if self._thrustTex then self._thrustTex:Hide() end
end

function R:_TickFx(dt)
    local field = self._fieldFrame
    local pool = self._fxPool
    if not field or not pool then return end
    for i = 1, #pool do
        local p = pool[i]
        if p.active then
            p.life = p.life - dt
            if p.life <= 0 then
                p.active = false
                p.tex:Hide()
            else
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy + (p.grav or 0) * dt
                local k = p.life / p.max
                local u = 1 - k
                local w = p.w0 + (p.w1 - p.w0) * u
                local h = p.h0 + (p.h1 - p.h0) * u
                local a = p.a * k
                if p.midPeak then
                    a = p.a * (4 * k * u)
                end
                local tex = p.tex
                tex:SetSize(w, h)
                tex:SetVertexColor(p.r, p.g, p.b, a)
                tex:ClearAllPoints()
                tex:SetPoint("CENTER", field, "TOPLEFT", p.x, -p.y)
                if p.rotSpd ~= 0 and tex.SetRotation then
                    p.rot = p.rot + p.rotSpd * dt
                    tex:SetRotation(p.rot)
                end
                tex:Show()
            end
        end
    end
    if self._muzzleT and self._muzzleT > 0 then
        self._muzzleT = self._muzzleT - dt
        if self._muzzleT <= 0 then
            self:_HideMuzzle()
        end
    end
end

function R:OnPlayerShoot(weapon)
    if weapon == "LASER" then return end
    self._muzzleT = MUZZLE_LIFE
    self._muzzleWeapon = weapon or "SINGLE"
end

function R:OnPlayerHit(gs)
    if not gs then return end
    local cx = gs.playerX + PLAYER_W * 0.5
    local cy = PLAYER_Y + PLAYER_H * 0.45
    self:_SpawnExplosion(cx, cy, 1.45, "player")
    self:_HideMuzzle()
    if self._thrustTex then self._thrustTex:Hide() end
    if self._playerTex then self._playerTex:Hide() end
end

local function _PlaceMuzzleNode(node, field, x, y, k)
    local expand = 0.70 + (1 - k) * 0.90
    node.halo:SetSize(32 * expand, 32 * expand)
    node.halo:SetVertexColor(1.00, 0.32, 0.05, 0.80 * k)
    node.halo:ClearAllPoints()
    node.halo:SetPoint("CENTER", field, "TOPLEFT", x, -y)
    node.halo:Show()

    node.core:SetSize(14 + 10 * k, 14 + 10 * k)
    node.core:SetVertexColor(1.00, 0.92, 0.55, 0.95 * k)
    node.core:ClearAllPoints()
    node.core:SetPoint("CENTER", field, "TOPLEFT", x, -y)
    node.core:Show()

    local flameH = 16 + 10 * k
    node.star:SetSize(12 + 6 * k, flameH)
    node.star:SetVertexColor(1.00, 0.70, 0.15, 0.85 * k)
    node.star:ClearAllPoints()
    node.star:SetPoint("CENTER", field, "TOPLEFT", x, -(y - flameH * 0.18))
    if node.star.SetRotation then node.star:SetRotation(0) end
    node.star:Show()
end

-- ── _CreateFlash ──────────────────────────────────────────────
function R:_CreateFlash()
    local field = self._fieldFrame
    local flash = CreateFrame("Frame", nil, field)
    flash:SetAllPoints(field)
    flash:SetFrameStrata("HIGH")
    local ft = flash:CreateTexture(nil, "OVERLAY")
    ft:SetAllPoints(flash)
    ft:SetTexture(WHITE8X8)
    ft:SetVertexColor(1, 1, 1, 0)
    flash:SetScript("OnUpdate", function(_, dt)
        local a = select(4, ft:GetVertexColor())
        if a and a > 0.001 then
            ft:SetVertexColor(R._flashR, R._flashG, R._flashB, math.max(0, a - dt * 4))
        end
        R:_TickFx(dt)
    end)
    self._flashFrame = flash
    self._flashTex   = ft
end

-- ── _CreateKeyFrame ───────────────────────────────────────────
function R:_CreateKeyFrame()
    local field = self._fieldFrame
    local kf = CreateFrame("Frame", "ArcadiaNexus_AD_KeyFrame", field)
    kf:SetAllPoints(field)
    kf:SetPropagateKeyboardInput(false)
    kf:EnableKeyboard(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local E  = ArcadiaNexus.AD_Engine
        local gs = E and E.gameState
        if key == "RETURN" then
            if E and (E.state == "PLAYING" or E.state == "PAUSED") then E:TogglePause() end
            return
        end
        if not gs or E.state ~= "PLAYING" then return end
        if key == "A" or key == "LEFT"  then gs.keyLeft  = true  end
        if key == "D" or key == "RIGHT" then gs.keyRight = true  end
        if key == "SPACE"               then gs.keyFire  = true  end
        if key == "W"                   then E:CycleWeaponUp()   end
        if key == "S"                   then E:CycleWeaponDown() end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local gs = ArcadiaNexus.AD_Engine and ArcadiaNexus.AD_Engine.gameState
        if not gs then return end
        if key == "A" or key == "LEFT"  then gs.keyLeft  = false end
        if key == "D" or key == "RIGHT" then gs.keyRight = false end
        if key == "SPACE"               then gs.keyFire  = false end
    end)
    self._keyFrame = kf
end

-- ── _CreateControls ───────────────────────────────────────────
-- Blueprint (relativ zum _contentFrame / TOPLEFT):
--   Divider H   @ (16,-416)   560x2
--   Dropdown    @ (32,-432)   112x32
--   Divider V   @ (160,-424)  2x40
--   Exit-Button @ (192,-432)  144x32
--   Divider V   @ (352,-424)  2x40
--   Pause-Btn   @ (352,-432)  144x32  (zentriert zwischen x=352 und x=528)
--   Divider V   @ (528,-424)  2x40
--
-- Alle Anker am Design-Canvas (Controls-Leiste), Spielfeld bleibt am _contentFrame.
function R:_CreateControls()
    local UI = ArcadiaNexus.UI
    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf
    self._controlsY = bar.y
    local L  = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")

    local DD_W       = 120
    local BTN_W      = 144
    local BTN_H      = 32
    local CHK_SIZE   = 20

    -- Dummy-Container (für _diffContainer-Checks)
    local ctrl = CreateFrame("Frame", nil, cf)
    ctrl:SetSize(1, 1)
    ctrl:SetPoint("BOTTOM", cf, "BOTTOM", 0, bar.y.button)
    self._diffContainer = ctrl

    -- Difficulty-Dropdown (Segment 1, x=-210)
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(DD_W, BTN_H)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    local diffOptions = {
        { key = "easy",   label = L["diff_easy"]   or "Einfach" },
        { key = "normal", label = L["diff_normal"] or "Normal"  },
        { key = "hard",   label = L["diff_hard"]   or "Schwer"  },
    }
    local dd = UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, DD_W, "",
        diffOptions,
        function()
            local S = ArcadiaNexus.AD_Settings
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            local S = ArcadiaNexus.AD_Settings
            if S then S:Set("difficulty", key) end
            self._lastDiff = key
        end
    )
    self._diffDropdown = dd

    -- Start (IDLE) / Beenden (Menü + Spiel)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", BTN_W, BTN_H)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._startBtn = startBtn

    local exitBtn = UI.CreateArcadiaButton(cf, L["btn_exit"] or "Beenden", BTN_W, BTN_H)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    exitBtn:SetScript("OnClick", function()
        if R.state == "MENU" then
            R:EnterIdleState()
            return
        end
        local E = ArcadiaNexus.AD_Engine
        if not E then return end
        if E.state ~= "IDLE" then
            if E.state == "GAMEOVER" then
                E:StopGame()
            else
                E:SaveAndPause()
                R:EnterIdleState()
            end
        end
    end)
    exitBtn:Hide()
    self._exitBtn = exitBtn

    -- Pause-Button (Segment 3, x=+170)
    local pauseBtn = UI.CreateArcadiaButton(cf, L["btn_pause"] or "Pause", BTN_W, BTN_H)
    pauseBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    pauseBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AD_Engine
        if not E then return end
        local mode = R._pauseBtnMode
        if mode == "pause" then
            E:Pause()
        elseif mode == "resume" then
            E:Resume()
        end
    end)
    pauseBtn:Hide()
    self._pauseBtn     = pauseBtn
    self._pauseBtnMode = "pause"

    -- Hint-Label unter Pause-Button
    local savedHint = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    savedHint:SetPoint("TOP", pauseBtn, "BOTTOM", 0, -4)
    savedHint:SetTextColor(1, 0.85, 0)
    savedHint:SetJustifyH("CENTER")
    savedHint:SetText("")
    self._savedHintFS = savedHint

    -- Endlos-Checkbox (Segment 4), Label rechts
    local chkHolder, chk = UI.CreateBarCheckbox(cf, L["lbl_endless"] or "Endlos", {
        w = 110, h = 36, size = CHK_SIZE,
    })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)
    chk:SetScript("OnShow", function()
        local S = ArcadiaNexus.AD_Settings
        chk:SetChecked(S and S:Get("endlessMode") or false)
    end)
    chk:SetScript("OnClick", function()
        local S = ArcadiaNexus.AD_Settings
        if S then S:Set("endlessMode", chk:GetChecked()) end
    end)
    self._endlessChk = chk
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
    local S  = ArcadiaNexus.AD_Settings
    if not UI or not UI.CreateSaveSlotMenu or not self._fieldFrame then return end

    self._slotMenu = UI.CreateSaveSlotMenu({
        parent        = self._fieldFrame,
        confirmParent = self._fieldFrame,
        maxSlots      = (S and S.MAX_SLOTS) or 3,
        L             = L,
        title         = L and L.menu_title,
        loadSlot      = function(slot) return S and S:LoadSlot(slot) end,
        deleteSlot    = function(slot) if S then S:DeleteSlot(slot) end end,
        formatInfo    = function(save, loc)
            local score = (ArcadiaNexus.Format and ArcadiaNexus.Format.Score(save.score or 0))
                or tostring(save.score or 0)
            return string.format(loc.slot_info or "Welle %d · %s", save.wave or 1, score)
        end,
        isPaused      = function() return true end,
        onNewGame     = function(slot)
            local E = ArcadiaNexus.AD_Engine
            if E then E:StartGame({ slot = slot, mode = "new" }) end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.AD_Engine
            if E then E:StartGame({ slot = slot, mode = "continue" }) end
        end,
    })
end

function R:EnterSlotMenu()
    self.state = "MENU"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoTex  then self._logoTex:Hide()  end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._resumeBtn then self._resumeBtn:Hide() end
    if self._slotMenu then self._slotMenu:Show() end
end

-- Setzt den Pause-Button Label (SetLabel = ArcadiaButton API)
function R:_SetPauseMode(mode)
    self._pauseBtnMode = mode
    if not self._pauseBtn then return end
    local L = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
    if mode == "pause" then
        self._pauseBtn:SetLabel(L["btn_pause"]       or "Pause")
    elseif mode == "resume" then
        self._pauseBtn:SetLabel(L["btn_resume_game"] or "Fortsetzen")
    end
end

function R:_HighlightDiff(diff) end  -- no-op

-- ── _UpdateLivesDisplay ───────────────────────────────────────
-- Zeigt exakt `count` Schiff-Icons, blendet den Rest aus.
function R:_UpdateLivesDisplay(count)
    for i = 1, MAX_LIVES do
        local t = self._livesTextures[i]
        if t then
            if i <= count then t:Show() else t:Hide() end
        end
    end
end

-- ── Overlays ──────────────────────────────────────────────────

function R:_CreatePauseOverlay()
    local field = self._fieldFrame
    local L     = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
    local ovl = CreateFrame("Frame", nil, field, "BackdropTemplate")
    ovl:SetSize(200, 56)
    ovl:SetPoint("CENTER", field, "CENTER", 0, 0)
    ovl:SetFrameLevel(field:GetFrameLevel() + 35)
    ovl:EnableMouse(false)
    ovl:SetBackdrop({
        bgFile = WHITE8X8, edgeFile = WHITE8X8, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ovl:SetBackdropColor(0, 0, 0, 0.82)
    ovl:SetBackdropBorderColor(0.35, 0.75, 0.95, 1)
    local fs = ovl:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER", ovl, "CENTER", 0, 0)
    fs:SetText(L["state_paused"] or "Pause")
    fs:SetTextColor(0.55, 0.90, 1.00, 1)
    ovl:Hide()
    self._pauseOverlay = ovl
end

-- ══════════════════════════════════════════════════════════════
--  ZUSTANDSÜBERGÄNGE
-- ══════════════════════════════════════════════════════════════

function R:EnterIdleState()
    self.state = "IDLE"
    self:_ClearAlienFrames()
    self:_ClearShotFrames()
    self:_ClearDropFrames()
    self:_ClearDbgBoxes()

    if self._playerTex    then self._playerTex:Hide()      end
    self:_ClearFx()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide()    end
    if self._diffContainer then self._diffContainer:Show() end
    if self._logoTex      then self._logoTex:Show()         end
    if self._slotMenu     then self._slotMenu:Hide()        end

    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
        self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
        self._startBtn:Show()
    end
    if self._exitBtn then self._exitBtn:Hide() end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._resumeBtn then self._resumeBtn:Hide() end

    -- HUD leeren
    self:_SetHudShown(false)
    if self._waveFS   then self._waveFS:SetText("")   end
    if self._scoreFS  then self._scoreFS:SetText("")  end
    if self._timeFS   then self._timeFS:SetText("")   end
    if self._weaponFS then self._weaponFS:SetText("") end
    self:_UpdateLivesDisplay(0)

    if self._diffDropdown then self._diffDropdown:SetEnabled(true) end
    self:_SetPauseMode("pause")
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
end

function R:OnGameStarted(gs)
    self.state = "PLAYING"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._diffContainer then self._diffContainer:Show() end
    if self._logoTex      then self._logoTex:Hide()       end
    if self._slotMenu     then self._slotMenu:Hide()      end
    self:_SetHudShown(true)
    if self._keyFrame then self._keyFrame:EnableKeyboard(true) end

    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._resumeBtn   then self._resumeBtn:Hide()  end
    if self._pauseBtn    then self._pauseBtn:Show()   end
    if self._diffDropdown then self._diffDropdown:SetEnabled(false) end

    self:_SetPauseMode("pause")
    self:_ClearAlienFrames()
    self:_ClearShotFrames()
    self:_ClearDropFrames()
    self:_ClearFx()
    self._vfxTime = 0
    self._bgFarU, self._bgFarV = 0, 0
    self._bgNearU, self._bgNearV = 0, 0
    self._shipPar = 0
    self._alienBobPhase = 0
    self._descentPulse = 0
    self:_BuildAlienFrames(gs)

    if self._playerTex then
        self._playerTex:SetPoint("TOPLEFT", self._fieldFrame, "TOPLEFT", gs.playerX, -PLAYER_Y)
        self._playerTex:Show()
    end
    self:UpdateHUD(gs)
end

function R:OnWaveAdvanced(gs)
    self:_ClearAlienFrames()
    self:_ClearShotFrames()
    self:_ClearDropFrames()
    self:_ClearFx()
    self._alienBobPhase = 0
    self._descentPulse = 0
    self:_BuildAlienFrames(gs)
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_SetPauseMode("pause")
    if self._pauseBtn then self._pauseBtn:Show() end
    if self._keyFrame then self._keyFrame:EnableKeyboard(true) end
    if self._playerTex then
        self._playerTex:SetPoint("TOPLEFT", self._fieldFrame, "TOPLEFT", gs.playerX, -PLAYER_Y)
        self._playerTex:Show()
    end
    self:UpdateHUD(gs)
end

-- ══════════════════════════════════════════════════════════════
--  ALIEN-FRAMES
-- ══════════════════════════════════════════════════════════════

function R:_BuildAlienFrames(gs)
    local field = self._fieldFrame
    if not field then return end
    local cache = self._alienFrames
    for i, alien in ipairs(gs.aliens) do
        local t = cache[i]
        if not t then
            t = field:CreateTexture(nil, "ARTWORK")
            cache[i] = t
        end
        t:ClearAllPoints()
        if alien.alive then
            local sz    = ALIEN_SIZES[alien.typ] or ALIEN_SIZES[1]
            local asset = AD_ASSETS["enemy" .. (alien.typ or 1)] or AD_ASSETS.enemy1
            t:SetTexture(asset)
            t:SetTexCoord(0, 1, 0, 1)
            t:SetVertexColor(1, 1, 1)
            t:SetAlpha(1)
            t:SetSize(sz.w, sz.h)
            self:_PlaceAlienTex(t, field, alien)
            t:Show()
        else
            t:Hide()
        end
    end
    for i = #gs.aliens + 1, #cache do
        local t = cache[i]
        if t then t:Hide() end
    end
end

function R:_PlaceAlienTex(tex, field, alien)
    local phase = (self._alienBobPhase or 0) + (alien.row or 0)
    local oy = (phase % 2) * ALIEN_BOB_PX
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", field, "TOPLEFT", alien.x, -(alien.y + oy))
    local p = self._descentPulse or 0
    if p > 0 then
        local k = p / DESCENT_PULSE
        tex:SetVertexColor(1, 1 - 0.42 * k, 1 - 0.62 * k)
    else
        tex:SetVertexColor(1, 1, 1)
    end
end

function R:OnFormationStep()
    self._alienBobPhase = 1 - (self._alienBobPhase or 0)
end

function R:OnFormationDescent()
    self._descentPulse = DESCENT_PULSE
end

function R:_ClearAlienFrames()
    for _, t in pairs(self._alienFrames) do if t then t:Hide() end end
end

function R:OnAlienKilled(alien, gs)
    if alien then
        local sz = ALIEN_SIZES[alien.typ] or ALIEN_SIZES[1]
        local scale = (alien.typ == 3 and 1.28) or (alien.typ == 2 and 0.92) or 1.0
        self:_SpawnExplosion(alien.x + sz.w * 0.5, alien.y + sz.h * 0.5, scale)
    end
    for i, a in ipairs(gs.aliens) do
        if a == alien then
            local t = self._alienFrames[i]
            if t then t:Hide() end
            return
        end
    end
end

function R:OnDropSpawned(wtype, x, y, gs) end

function R:OnWeaponCollected(wtype, gs)
    self:UpdateHUD(gs)
    if not gs or not self._fxPool then return end
    local cx = gs.playerX + PLAYER_W * 0.5
    local cy = PLAYER_Y + 10
    _EmitFx(self._fxPool, {
        tex = TEX_GLOW, x = cx, y = cy,
        w0 = 18, w1 = 44, life = 0.26,
        r = 1.00, g = 0.86, b = 0.25, a = 0.92,
    })
    _EmitFx(self._fxPool, {
        tex = TEX_RING, x = cx, y = cy,
        w0 = 16, w1 = 50, life = 0.30,
        r = 1.00, g = 0.90, b = 0.40, a = 0.85,
        midPeak = true,
    })
end

function R:_ClearDropFrames()
    for _, t in pairs(self._dropFrames) do if t then t:Hide() end end
end

function R:_ClearShotFrames()
    for _, t in ipairs(self._shotFrames) do if t then t:Hide() end end
    for _, t in ipairs(self._alienShotFrames) do if t then t:Hide() end end
end

-- ══════════════════════════════════════════════════════════════
--  DEBUG – HITBOX-VISUALISIERUNG
-- ══════════════════════════════════════════════════════════════

local function _MakeDbgBox(parent, r, g, b)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ bgFile=WHITE8X8, edgeFile=WHITE8X8, edgeSize=1 })
    f:SetBackdropColor(r, g, b, 0.25)
    f:SetBackdropBorderColor(r, g, b, 0.9)
    f:SetFrameStrata("TOOLTIP")
    f:Hide()
    return f
end

function R:_DrawHitboxes(gs)
    if not ArcadiaNexus.IsDevMode() then self:_ClearDbgBoxes(); return end
    local field = self._fieldFrame
    local L     = ArcadiaNexus.AD_Logic
    if not field or not L then return end

    local hbs = L.PLAYER_HITBOXES
    local px, py = gs.playerX, PLAYER_Y
    while #self._dbgPlayerBoxes < #hbs do
        self._dbgPlayerBoxes[#self._dbgPlayerBoxes+1] = _MakeDbgBox(field, 0.1, 1.0, 0.1)
    end
    for i, hb in ipairs(hbs) do
        local f = self._dbgPlayerBoxes[i]
        f:SetSize(hb.w, hb.h)
        f:SetPoint("TOPLEFT", field, "TOPLEFT", px+hb.offX, -(py+hb.offY))
        f:Show()
    end
    for i = #hbs+1, #self._dbgPlayerBoxes do self._dbgPlayerBoxes[i]:Hide() end

    local nAlive = 0
    for _, alien in ipairs(gs.aliens) do if alien.alive then nAlive=nAlive+1 end end
    while #self._dbgAlienBoxes < nAlive do
        self._dbgAlienBoxes[#self._dbgAlienBoxes+1] = _MakeDbgBox(field, 1.0, 0.1, 0.1)
    end
    local idx = 0
    for _, alien in ipairs(gs.aliens) do
        if alien.alive then
            idx = idx+1
            local f = self._dbgAlienBoxes[idx]
            local hox, hoy, hw, hh = L:_AlienHB(alien.typ)
            f:SetSize(hw, hh)
            f:SetPoint("TOPLEFT", field, "TOPLEFT", alien.x+hox, -(alien.y+hoy))
            f:Show()
        end
    end
    for i = idx+1, #self._dbgAlienBoxes do self._dbgAlienBoxes[i]:Hide() end

    local nS = #gs.playerShots
    while #self._dbgShotBoxes < nS do
        self._dbgShotBoxes[#self._dbgShotBoxes+1] = _MakeDbgBox(field, 1.0, 1.0, 0.0)
    end
    for i = 1, #self._dbgShotBoxes do
        local f = self._dbgShotBoxes[i]
        if i <= nS then
            local shot = gs.playerShots[i]
            if shot.isLaser then
                f:SetSize(L.SHOT_W, shot.height or PLAYER_Y)
                f:SetPoint("TOPLEFT", field, "TOPLEFT", shot.x, 0)
            else
                f:SetSize(L.SHOT_W, L.SHOT_H)
                f:SetPoint("TOPLEFT", field, "TOPLEFT", shot.x, -shot.y)
            end
            f:Show()
        else f:Hide() end
    end

    local nA = #gs.alienShots
    while #self._dbgAShortBoxes < nA do
        self._dbgAShortBoxes[#self._dbgAShortBoxes+1] = _MakeDbgBox(field, 1.0, 0.5, 0.0)
    end
    for i = 1, #self._dbgAShortBoxes do
        local f = self._dbgAShortBoxes[i]
        if i <= nA then
            local shot = gs.alienShots[i]
            f:SetSize(L.ALIEN_SHOT_W, L.ALIEN_SHOT_H)
            f:SetPoint("TOPLEFT", field, "TOPLEFT", shot.x, -shot.y)
            f:Show()
        else f:Hide() end
    end
end

function R:_ClearDbgBoxes()
    for _, f in ipairs(self._dbgPlayerBoxes) do if f then f:Hide() end end
    for _, f in ipairs(self._dbgAlienBoxes)  do if f then f:Hide() end end
    for _, f in ipairs(self._dbgShotBoxes)   do if f then f:Hide() end end
    for _, f in ipairs(self._dbgAShortBoxes) do if f then f:Hide() end end
end

-- Clippt eine Textur an die Spielfeldgrenzen (sichtbarer Teil bleibt, Rest wird abgeschnitten).
local function PlaceClipped(tex, field, x, y, w, h, fw, fh)
    if w <= 0 or h <= 0 then tex:Hide(); return end
    local x2, y2 = x + w, y + h
    if x2 <= 0 or y2 <= 0 or x >= fw or y >= fh then
        tex:Hide()
        return
    end
    local cx  = (x  < 0)  and 0  or x
    local cy  = (y  < 0)  and 0  or y
    local cx2 = (x2 > fw) and fw or x2
    local cy2 = (y2 > fh) and fh or y2
    local visW, visH = cx2 - cx, cy2 - cy
    if visW <= 0.5 or visH <= 0.5 then
        tex:Hide()
        return
    end
    tex:SetTexCoord((cx - x) / w, (cx2 - x) / w, (cy - y) / h, (cy2 - y) / h)
    tex:SetSize(visW, visH)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", field, "TOPLEFT", cx, -cy)
    tex:Show()
end

-- ══════════════════════════════════════════════════════════════
--  PHYSICS UPDATE
-- ══════════════════════════════════════════════════════════════

function R:UpdatePhysics(gs, dt)
    if not gs or not self._fieldFrame then return end
    local field = self._fieldFrame
    local fw, fh = field:GetWidth(), field:GetHeight()
    dt = dt or 0

    if dt > 0 then
        self._vfxTime = (self._vfxTime or 0) + dt
        self._bgFarU  = (self._bgFarU  or 0) + dt * PARALLAX_FAR_U
        self._bgFarV  = (self._bgFarV  or 0) + dt * PARALLAX_FAR_V
        self._bgNearU = (self._bgNearU or 0) + dt * PARALLAX_NEAR_U
        self._bgNearV = (self._bgNearV or 0) + dt * PARALLAX_NEAR_V

        local fwMove = (fw > PLAYER_W) and (fw - PLAYER_W) or 1
        local target = ((gs.playerX or 0) / fwMove) * 2 - 1
        if target < -1 then target = -1 elseif target > 1 then target = 1 end
        local par = self._shipPar or 0
        par = par + (target - par) * math.min(1, dt * 2.4)
        self._shipPar = par

        local function Wrap01(x)
            return x - math.floor(x)
        end
        local function ScrollLayer(tex, u, v, shipAmt, vScale)
            if not tex or not tex.SetTexCoord then return end
            u = Wrap01(u + par * shipAmt)
            v = Wrap01(v)
            tex:SetTexCoord(u, u + 1, v, v + (vScale or 1))
        end
        ScrollLayer(self._fieldBgTex,     self._bgFarU,  self._bgFarV,  PARALLAX_SHIP_FAR)
        ScrollLayer(self._fieldBgNearTex, self._bgNearU, self._bgNearV, PARALLAX_SHIP_NEAR, 0.92)

        if self._overlayTex and BG_OVERLAY_W > 0 then
            local t = self._vfxTime
            self._overlayTex:ClearAllPoints()
            self._overlayTex:SetPoint("CENTER", self._contentFrame, "CENTER",
                BG_OVERLAY_X + math.sin(t * 0.11) * OVERLAY_DRIFT_X + par * 5,
                BG_OVERLAY_Y + math.cos(t * 0.08) * OVERLAY_DRIFT_Y)
        end
    end

    local boom = (gs.playerBoomT or 0) > 0
    local invuln = (gs.invulnT or 0) > 0
    local shipVisible = (not boom) and (not invuln or (math.floor((gs.invulnT or 0) * 10) % 2 == 0))

    local hover = math.sin((self._vfxTime or 0) * HOVER_SPEED) * HOVER_AMP
    local py = PLAYER_Y + hover
    if self._playerTex then
        if shipVisible then
            self._playerTex:SetPoint("TOPLEFT", field, "TOPLEFT", gs.playerX, -py)
            self._playerTex:SetAlpha(1)
            self._playerTex:Show()
        else
            self._playerTex:Hide()
        end
    end
    local moving = (not boom) and (gs.keyLeft or gs.keyRight)
    if self._thrustTex then
        if moving and shipVisible then
            local flicker = 0.45 + 0.50 * math.abs(math.sin((self._vfxTime or 0) * 28))
            self._thrustTex:SetSize(THRUST_W, THRUST_H * (0.85 + 0.25 * flicker))
            self._thrustTex:SetVertexColor(0.20, 0.75, 1.0, flicker)
            self._thrustTex:ClearAllPoints()
            self._thrustTex:SetPoint("CENTER", field, "TOPLEFT",
                gs.playerX + PLAYER_W * 0.5,
                -(py + PLAYER_H - 4))
            self._thrustTex:Show()
        else
            self._thrustTex:Hide()
        end
    end
    if (self._muzzleT or 0) > 0 and self._muzzleNodes and shipVisible then
        local k = self._muzzleT / MUZZLE_LIFE
        local noseX = gs.playerX + PLAYER_W * 0.5
        local noseY = py + 2
        if self._muzzleWeapon == "DOUBLE" then
            _PlaceMuzzleNode(self._muzzleNodes[1], field, noseX - 12, noseY, k)
            _PlaceMuzzleNode(self._muzzleNodes[2], field, noseX + 12, noseY, k)
        else
            _PlaceMuzzleNode(self._muzzleNodes[1], field, noseX, noseY, k)
            local n2 = self._muzzleNodes[2]
            n2.halo:Hide(); n2.core:Hide(); n2.star:Hide()
        end
    else
        self:_HideMuzzle()
    end

    if dt > 0 and (self._descentPulse or 0) > 0 then
        self._descentPulse = math.max(0, self._descentPulse - dt)
    end
    for i, alien in ipairs(gs.aliens) do
        local t = self._alienFrames[i]
        if alien.alive then
            if t then
                self:_PlaceAlienTex(t, field, alien)
                t:Show()
            end
        else
            if t then t:Hide() end
        end
    end

    local nS = #gs.playerShots
    while #self._shotFrames < nS do
        local t = field:CreateTexture(nil, "ARTWORK")
        t:SetSize(SHOT_W, SHOT_H); t:Hide()
        self._shotFrames[#self._shotFrames+1] = t
    end
    for i = 1, #self._shotFrames do
        local t = self._shotFrames[i]
        if i <= nS then
            local shot = gs.playerShots[i]
            t:SetVertexColor(1, 1, 1)
            t:SetAlpha(1)
            local sh = shot.isLaser and (shot.height or PLAYER_Y) or SHOT_H
            t:SetTexture(shot.isLaser and AD_ASSETS.shot_laser or AD_ASSETS.shot_player)
            PlaceClipped(t, field, shot.x, shot.y, SHOT_W, sh, fw, fh)
        else t:Hide() end
    end

    local nA = #gs.alienShots
    while #self._alienShotFrames < nA do
        local t = field:CreateTexture(nil, "ARTWORK")
        t:SetTexture(AD_ASSETS.shot_alien)
        t:SetBlendMode("ADD")
        t:SetSize(ALIEN_SHOT_W, ALIEN_SHOT_H); t:Hide()
        self._alienShotFrames[#self._alienShotFrames+1] = t
    end
    for i = 1, #self._alienShotFrames do
        local t = self._alienShotFrames[i]
        if i <= nA then
            local shot = gs.alienShots[i]
            t:SetTexture(AD_ASSETS.shot_alien)
            t:SetVertexColor(1.0, 0.42, 0.18)
            t:SetAlpha(1)
            PlaceClipped(t, field, shot.x, shot.y, ALIEN_SHOT_W, ALIEN_SHOT_H, fw, fh)
        else t:Hide() end
    end

    local nD = #gs.weaponDrops
    while #self._dropFrames < nD do
        local t = field:CreateTexture(nil, "ARTWORK")
        t:SetSize(DROP_W, DROP_H); t:Hide()
        self._dropFrames[#self._dropFrames+1] = t
    end
    for i = 1, #self._dropFrames do
        local t = self._dropFrames[i]
        if i <= nD then
            local drop = gs.weaponDrops[i]
            local pulse = 1 + 0.16 * math.abs(math.sin((self._vfxTime or 0) * 8))
            t:SetTexture(drop.wtype == "SHIELD" and AD_ASSETS.powerup_shield or AD_ASSETS.powerup_weapon)
            t:SetVertexColor(1, 0.92 + 0.08 * pulse, 0.55 + 0.45 * pulse)
            t:SetAlpha(0.72 + 0.28 * pulse)
            PlaceClipped(t, field, drop.x, drop.y, DROP_W * pulse, DROP_H * pulse, fw, fh)
        else t:Hide() end
    end

    self:_DrawHitboxes(gs)
end

-- ══════════════════════════════════════════════════════════════
--  HUD UPDATE
-- ══════════════════════════════════════════════════════════════

function R:UpdateHUD(gs)
    if not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")

    local waveStr = (L["lbl_wave"] or "Welle") .. " " .. gs.wave
    if gs.waveName and gs.waveName ~= "" then
        waveStr = waveStr .. " · " .. gs.waveName
    end
    if gs.endlessMode then
        waveStr = waveStr .. " |cff999999(" .. (L["lbl_endless"] or "Endlos") .. ")|r"
    end
    if self._waveFS then self._waveFS:SetText(waveStr) end

    if self._scoreFS then
        self._scoreFS:SetText(
            (L["lbl_score"] or "Punkte") .. ": " .. gs.score
            .. "  |cffffd700" .. (L["lbl_highscore"] or "HS") .. ": " .. (gs.highScore or 0) .. "|r")
    end

    -- Leben als Schiff-Icons
    self:_UpdateLivesDisplay(gs.lives or 0)

    if self._timeFS then
        self._timeFS:SetText((L["lbl_time"] or "Zeit") .. ": " ..
            ArcadiaNexus.Format.SecondsMMSS(gs.elapsedSecs or 0))
    end

    if self._weaponFS then
        local wname = L["weapon_" .. string.lower(gs.activeWeapon)] or gs.activeWeapon
        if gs.weaponTimer > 0 then
            self._weaponFS:SetText(
                "|cffffd700" .. (L["lbl_weapon"] or "Waffe") .. ": "
                .. wname .. " [" .. math.ceil(gs.weaponTimer) .. "s]|r")
        else
            self._weaponFS:SetText((L["lbl_weapon"] or "Waffe") .. ": " .. wname)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  OVERLAY-EVENTS
-- ══════════════════════════════════════════════════════════════

function R:ShowPause()
    if self._pauseOverlay then self._pauseOverlay:Show() end
    if self._keyFrame     then self._keyFrame:EnableKeyboard(true) end
    self:_SetPauseMode("resume")
end

function R:HidePause()
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    self:_SetPauseMode("pause")
end

function R:ShowWaveWin(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
    local UI = ArcadiaNexus.UI
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    local lines = { (L["popup_wave"] or "Welle:") .. " " .. gs.wave }
    if gs.perfectWave then
        lines[#lines + 1] = (L["popup_bonus"] or "Wellen-Bonus:") .. " +500"
    end
    UI.ShowArcadeResult(field, {
        title      = L["state_win"] or "Welle überstanden!",
        titleColor = { 0, 1, 0 },
        score      = gs.score,
        gameId     = "ALIENDEFENSE",
        difficulty = gs.difficulty,
        result     = "WIN",
        lines      = lines,
        L          = L,
        buttons    = {
            {
                label = L["btn_next_wave"] or L["popup_next_wave"] or "Nächste Welle",
                onClick = function()
                    local E = ArcadiaNexus.AD_Engine
                    if E then E:ContinueToNextWave() end
                end,
            },
            {
                label = L["btn_exit"] or "Beenden",
                onClick = function()
                    local E = ArcadiaNexus.AD_Engine
                    if E then E:StopGame() end
                end,
            },
        },
    })
end

function R:ShowGameOver(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")
    local UI = ArcadiaNexus.UI
    local reason = gs.invaded
        and (L["state_invaded"] or "Invasion!")
        or  (L["state_gameover"] or "Spiel vorbei!")
    self:_SetPauseMode("pause")
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._resumeBtn then self._resumeBtn:Hide() end
    if self._pauseBtn  then self._pauseBtn:Hide()  end
    if self._savedHintFS then self._savedHintFS:SetText("") end
    local lines = { (L["popup_wave"] or "Welle:") .. " " .. gs.wave }
    UI.ShowArcadeResult(field, {
        title      = reason,
        titleColor = { 1, 0.27, 0.27 },
        score      = gs.score,
        gameId     = "ALIENDEFENSE",
        difficulty = gs.difficulty,
        result     = "LOSS",
        lines      = lines,
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.AD_Engine
            if E then E:StartGame({ mode = "new" }) end
        end,
        onExit = function()
            local E = ArcadiaNexus.AD_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:FlashScreen(r, g, b, alpha)
    if not self._flashTex then return end
    self._flashR = r or 1
    self._flashG = g or 1
    self._flashB = b or 1
    self._flashTex:SetVertexColor(r or 1, g or 1, b or 1, alpha or 0.6)
end
