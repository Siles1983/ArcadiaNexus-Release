-- ============================================================
--  ArgusOrbitDefense – Renderer.lua
--  Nur Anzeige. Schreibt NIE in den Game-State zurück.
--
--  Fixes v33g:
--    - stars.tga sichtbar: Backdrop bgFile entfernt, nur edgeFile für Rand
--    - exhaust.tga als Schub-Asset
--    - Meteore/Hunter: WHITE8X8 + SetVertexColor (robust, keine Icon-Pfad-Abhängigkeit)
--    - kein f:Show() in EnterIdleState / OnGameStarted
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AOD_Renderer = {}
local R = ArcadiaNexus.AOD_Renderer

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "ARGUSORBDEFENSE",
    label     = "Argus Orbit Defense",
    category  = "ARCADE",
    renderer  = "AOD_Renderer",
    engine    = "AOD_Engine",
    container = "_aodContainer",
})

-- ── Asset-Pfade ───────────────────────────────────────────────
local ASSETS        = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArgusOrbitDefense\\Assets\\"
local SPRITES       = ASSETS .. "sprites\\"
local ASSET_STARS   = SPRITES .. "stars"
local ASSET_STARS2  = SPRITES .. "stars02"   -- zweites Sternenfeld für Fade-Animation
local ASSET_SHIP    = SPRITES .. "player_ship"
local ASSET_EXHAUST = SPRITES .. "exhaust"
local ASSET_ENEMY   = SPRITES .. "enemy_ship"
local WHITE         = "Interface\\Buttons\\WHITE8X8"

-- Logo, Border, Background
local ASSET_LOGO   = ASSETS .. "logo\\logo_aod"
local ASSET_BORDER = ASSETS .. "border\\border_aod"
local ASSET_BG     = ASSETS .. "background\\bg_aod"

-- ── Logo-Konstanten ───────────────────────────────────────────
local LOGO_W = 375
local LOGO_H = 350
local LOGO_X = 0
local LOGO_Y = 0

-- ── Layout-Konstanten ─────────────────────────────────────────
local FIELD_W, FIELD_H = 655, 445
local FIELD_X = -30
local FIELD_Y = -10

-- ── Background-Konstanten ─────────────────────────────────────
local BG_W     = 610
local BG_H     = 430
local BG_X     = 0
local BG_Y     = 33
local BG_ALPHA = 0

-- ── Border-Konstanten ─────────────────────────────────────────
-- border_aod.tga liegt über dem Spielfeld (OVERLAY).
-- BORDER_W/H = 0 → SetAllPoints (füllt gesamtes Spielfeld)
local BORDER_W = 790      -- Breite (0 = gesamtes Spielfeld)
local BORDER_H = 540      -- Höhe   (0 = gesamtes Spielfeld)
local BORDER_X = 2      -- X-Offset vom CENTER des Spielfelds
local BORDER_Y = 0      -- Y-Offset vom CENTER des Spielfelds

-- Power-Up Icons (Interface\Icons existieren garantiert)
local ICON_SHIELD = "Interface\\Icons\\Spell_Holy_DevineShield"
local ICON_RAPID  = "Interface\\Icons\\Ability_Marksmanship"

-- Shared PowerUp TGA-Assets (für Drop-Visuals im Spielfeld)
local PU_ASSET_WEAPON = "Interface\\AddOns\\ArcadiaNexus\\Shared\\PowerUp\\power_up_red"
local PU_ASSET_SHIELD = "Interface\\AddOns\\ArcadiaNexus\\Shared\\PowerUp\\power_up_green"
local ICON_SPREAD = "Interface\\Icons\\Ability_Hunter_MultiShot"
local ICON_BOMB   = "Interface\\Icons\\Spell_Holy_SealOfSacrifice"
local ICON_LIFE   = "Interface\\Icons\\Spell_Holy_Resurrection"

-- Rahmenfarben der Power-Up Drops (r, g, b)
local PU_COLORS = {
    SHIELD = { 1.00, 0.85, 0.00 },   -- Gelb
    RAPID  = { 1.00, 0.20, 0.20 },   -- Rot
    SPREAD = { 0.20, 0.50, 1.00 },   -- Blau
    BOMB   = { 1.00, 0.55, 0.10 },   -- Orange
    LIFE   = { 0.20, 0.90, 0.30 },   -- Grün
}

-- Meteor/Hunter: Assets
local METEOR_ASSETS = {
    SPRITES .. "meteo01",
    SPRITES .. "meteo02",
    SPRITES .. "meteo03",
}
local COL_HUNTER        = { 0.80, 0.20, 1.00 }  -- Fel-Lila

local METEOR_SIZE = { BIG=38, MEDIUM=22, SMALL=14 }

-- ── Pool-Groessen ─────────────────────────────────────────────
local POOL_METEORS   = 40
local POOL_BULLETS   = 20
local POOL_H_BULLETS = 20
local POOL_HUNTERS   = 8
local POOL_POWERUPS  = 10
local POOL_PARTICLES = 60

-- ── Renderer-State ────────────────────────────────────────────
R.frame          = nil
R._canvas        = nil
R._controlsFrame = nil
R._fieldFrame    = nil
R._keyFrame      = nil
R._shipFrame     = nil
R._shipTex       = nil
R._thrustFrame   = nil
R._thrustTex     = nil
R._stars2Tex     = nil        -- zweites Sternenfeld (Fade-Animation)
R._meteorPool    = {}
R._bulletPool    = {}
R._hBulletPool   = {}
R._hunterPool    = {}
R._hunterThrustPool = {}      -- Exhaust-Frames pro Hunter-Slot
R._puPool        = {}
R._particlePool  = {}
R._flashFrame    = nil
R._flashTex      = nil
R._pauseOverlay  = nil
R._shieldHUD     = nil
R._shieldFS      = nil
R._rapidHUD      = nil
R._rapidFS       = nil
R._scoreFS       = nil
R._waveFS        = nil
R._livesFS       = nil        -- wird nicht mehr verwendet (Texturen statt FontString)
R._livesTex      = {}         -- Pool aus Schiff-Texturen für Lebensanzeige
R._livesBox      = nil
R._scoreBox      = nil
R._waveBox       = nil
R._btnStartStop  = nil   -- Alias, bleibt für Kompatibilität
R._exitBtn       = nil
R._btnPause      = nil
R._pauseBtn      = nil
R._cbEndless     = nil
R._endlessChk    = nil
R._cbEndlessLbl  = nil
R._diffDropdown  = nil
R._logoTex       = nil
R._borderTex     = nil
R._endlessMode   = true
R._lastDiff      = "normal"
R._particleUpdateRunning = false

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateShip()
    self:_CreatePools()
    self:_CreateFlash()
    self:_CreatePauseOverlay()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreateKeyFrame()
    self:EnterIdleState()
end

-- ── Container ─────────────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AOD_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._aodContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("ARGUSORBDEFENSE", ArcadiaNexus.AOD_Engine, function(E)
            if E.state == "PLAYING" then
                E:SaveAndPause()
            end
        end)
        if R.state == "MENU" then
            R:EnterIdleState()
        end
        if R._keyFrame then R._keyFrame:EnableKeyboard(false) end
    end)
end

-- ── Spielfeld ─────────────────────────────────────────────────
function R:_CreateFieldFrame()
    local canvas = self._canvas
    if not canvas then return end

    -- Background hinter dem Spielfeld (analog AlienDefense)
    local bgTex = canvas:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetTexture(ASSET_BG)
    if BG_W > 0 and BG_H > 0 then
        bgTex:SetSize(BG_W, BG_H)
        bgTex:SetPoint("CENTER", canvas, "CENTER", BG_X, BG_Y)
    else
        bgTex:SetAllPoints(canvas)
    end
    bgTex:SetAlpha(BG_ALPHA)

    local field = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    field:SetPoint("TOPLEFT", canvas, "TOPLEFT", FIELD_X, FIELD_Y)
    field:SetSize(FIELD_W, FIELD_H)
    field:SetBackdrop({
        edgeFile = WHITE,
        edgeSize = 1,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    field:SetBackdropBorderColor(0.15, 0.15, 0.2, 1)

    -- Schwarzer Hintergrund als unterste Textur
    local blackBg = field:CreateTexture(nil, "BACKGROUND", nil, -2)
    blackBg:SetAllPoints(field)
    blackBg:SetColorTexture(0, 0, 0, 1)

    -- Sternenhintergrund (Ebene 1)
    local bg = field:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints(field)
    bg:SetTexture(ASSET_STARS)

    -- Zweites Sternenfeld (Ebene 2) — langsames Ein-/Ausblenden
    local bg2 = field:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg2:SetAllPoints(field)
    bg2:SetTexture(ASSET_STARS2)
    bg2:SetAlpha(0)
    self._stars2Tex = bg2

    -- Eigener Frame für den Fade-Loop — wird nie von particleUpdate überschrieben
    local fadeFrame = CreateFrame("Frame", "ArcadiaNexus_AOD_FadeFrame", field)
    fadeFrame:SetAllPoints(field)
    fadeFrame:EnableMouse(false)
    local _fadeDir = 1
    local _fadeVal = 0
    local _fadeSpeed = 0.12
    fadeFrame:SetScript("OnUpdate", function(_, dt)
        _fadeVal = _fadeVal + _fadeDir * _fadeSpeed * dt
        if _fadeVal >= 1 then _fadeVal = 1; _fadeDir = -1
        elseif _fadeVal <= 0 then _fadeVal = 0; _fadeDir = 1 end
        bg2:SetAlpha(_fadeVal)
    end)

    -- Border-Overlay (border_aod.tga) — eigener Frame über allen Spielobjekten
    -- fl+5 = Schiff, fl+30 = Border (über Spieler/Feinden), fl+40 = Overlay/Pause
    local borderFrame = CreateFrame("Frame", nil, canvas)
    borderFrame:SetFrameLevel(field:GetFrameLevel() + 30)
    borderFrame:EnableMouse(false)
    if BORDER_W > 0 and BORDER_H > 0 then
        borderFrame:SetSize(BORDER_W, BORDER_H)
        borderFrame:SetPoint("CENTER", field, "CENTER", BORDER_X, BORDER_Y)
    else
        borderFrame:SetAllPoints(field)
    end
    local borderTex = borderFrame:CreateTexture(nil, "OVERLAY")
    borderTex:SetAllPoints(borderFrame)
    borderTex:SetTexture(ASSET_BORDER)
    self._borderTex = borderTex

    -- Dynamische Feldgröße: Logic wird beim ersten Show() mit den realen Pixelmaßen synchronisiert
    field:SetScript("OnShow", function(frame)
        local fw, fh = frame:GetWidth(), frame:GetHeight()
        if fw and fw > 10 and fh and fh > 10 then
            local L = ArcadiaNexus.AOD_Logic
            if L and L.SetFieldSize then L:SetFieldSize(fw, fh) end
        end
    end)

    self._fieldFrame = field
end

-- ── _CreateLogo ───────────────────────────────────────────────
function R:_CreateLogo()
    if not self._fieldFrame then return end
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ASSET_LOGO,
        { w=LOGO_W, h=LOGO_H, x=LOGO_X, y=LOGO_Y }
    )
end

-- ── HUD ───────────────────────────────────────────────────────
function R:_CreateHUD()
    local f = self._canvas
    if not f then return end

    local function MakeBox(x, y, w, h, br, bg, bb, ba, er, eg, eb)
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetSize(w, h)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        box:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
        box:SetBackdropColor(br, bg, bb, ba or 0.8)
        box:SetBackdropBorderColor(er, eg, eb, 1)
        return box
    end

    -- Leben: Schiff-Texturen statt FontString (max. 5 Icons, von links aufgebaut)
    local LIFE_W, LIFE_H = 20, 20
    local LIFE_GAP       = 4
    local LIFE_MAX       = 5
    local livesBox = MakeBox(80, -32, LIFE_MAX * (LIFE_W + LIFE_GAP) - LIFE_GAP + 8, 32,
        0.05,0,0,0.8, 0.6,0.15,0.15)
    self._livesBox = livesBox
    self._livesTex = {}
    for i = 1, LIFE_MAX do
        local t = livesBox:CreateTexture(nil, "ARTWORK")
        t:SetSize(LIFE_W, LIFE_H)
        t:SetPoint("LEFT", livesBox, "LEFT", 4 + (i-1) * (LIFE_W + LIFE_GAP), 0)
        t:SetTexture(ASSET_SHIP)
        t:Hide()
        self._livesTex[i] = t
    end
    livesBox:Hide()

    -- Score (TOPLEFT +224/-32, 144x48)
    local scoreBox = MakeBox(224, -32, 144, 48, 0,0.04,0,0.8, 0.4,0.3,0.08)
    local scoreLbl = scoreBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scoreLbl:SetPoint("TOPLEFT", scoreBox, "TOPLEFT", 6, -4)
    scoreLbl:SetText("Punkte")
    scoreLbl:SetTextColor(0.6, 0.6, 0.6, 1)
    local scoreFS = scoreBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scoreFS:SetPoint("TOPLEFT", scoreBox, "TOPLEFT", 6, -20)
    scoreFS:SetTextColor(1, 0.85, 0, 1)
    self._scoreFS  = scoreFS
    self._scoreBox = scoreBox
    scoreBox:Hide()

    -- Welle (TOPLEFT +468/-32, 104x32)
    local waveBox = MakeBox(430, -32, 104, 32, 0,0,0.06,0.8, 0.2,0.35,0.7)
    local waveFS = waveBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    waveFS:SetPoint("CENTER", waveBox, "CENTER", 0, 0)
    waveFS:SetTextColor(0.4, 0.7, 1, 1)
    self._waveFS  = waveFS
    self._waveBox = waveBox
    waveBox:Hide()

    -- Schild (TOPLEFT +16/-368, 104x32) — versteckt bis aktiv
    local shieldBox = MakeBox(80, -368, 104, 32, 0,0.06,0.3,0.9, 0.3,0.5,1)
    local shIco = shieldBox:CreateTexture(nil, "ARTWORK")
    shIco:SetSize(20, 20)
    shIco:SetPoint("LEFT", shieldBox, "LEFT", 4, 0)
    shIco:SetTexture(ICON_SHIELD)
    local shFS = shieldBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shFS:SetPoint("LEFT", shieldBox, "LEFT", 28, 0)
    shFS:SetTextColor(0.4, 0.7, 1, 1)
    shieldBox:Hide()
    self._shieldHUD = shieldBox
    self._shieldFS  = shFS

    -- Schnellfeuer (TOPLEFT +472/-368, 104x32) — versteckt bis aktiv
    local rapidBox = MakeBox(430, -368, 104, 32, 0.3,0.06,0,0.9, 1,0.5,0.1)
    local rpIco = rapidBox:CreateTexture(nil, "ARTWORK")
    rpIco:SetSize(20, 20)
    rpIco:SetPoint("LEFT", rapidBox, "LEFT", 4, 0)
    rpIco:SetTexture(ICON_RAPID)
    local rpFS = rapidBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rpFS:SetPoint("LEFT", rapidBox, "LEFT", 28, 0)
    rpFS:SetTextColor(1, 0.6, 0.2, 1)
    rapidBox:Hide()
    self._rapidHUD = rapidBox
    self._rapidFS  = rpFS
end

-- ── Schiff ────────────────────────────────────────────────────
function R:_CreateShip()
    local field = self._fieldFrame
    if not field then return end
    local fl = field:GetFrameLevel()

    local sf = CreateFrame("Frame", nil, field)
    sf:SetSize(28, 28)
    sf:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
    sf:SetFrameLevel(fl + 5)
    sf:EnableMouse(false)
    local tex = sf:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(sf)
    tex:SetTexture(ASSET_SHIP)

    -- FIX: exhaust.tga als Schub-Asset
    local thrust = CreateFrame("Frame", nil, field)
    thrust:SetSize(20, 20)
    thrust:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
    thrust:SetFrameLevel(fl + 4)
    thrust:EnableMouse(false)
    local thrustTex = thrust:CreateTexture(nil, "ARTWORK")
    thrustTex:SetAllPoints(thrust)
    thrustTex:SetTexture(ASSET_EXHAUST)
    thrust:Hide()

    self._shipFrame   = sf
    self._shipTex     = tex
    self._thrustFrame = thrust
    self._thrustTex   = thrustTex
    sf:Hide()
end

-- ── Objekt-Pools ─────────────────────────────────────────────
-- FIX: Meteore/Hunter = WHITE8X8 + SetVertexColor (robust, keine Icon-Pfad-Abhängigkeit)
function R:_CreatePools()
    local field = self._fieldFrame
    if not field then return end
    local fl = field:GetFrameLevel()

    -- Meteor-Pool (texType wird in UpdatePhysics per Slot gesetzt)
    self._meteorPool = {}
    for i = 1, POOL_METEORS do
        local fr = CreateFrame("Frame", nil, field)
        fr:SetSize(38, 38)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 3)
        fr:EnableMouse(false)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(fr)
        tex:SetTexture(METEOR_ASSETS[1])
        fr._tex = tex
        fr:Hide()
        self._meteorPool[i] = { frame=fr, tex=tex, active=false }
    end

    -- Spieler-Projektile: schlanke Textur in quadratischem Frame (Rotation um die Mitte)
    self._bulletPool = {}
    for i = 1, POOL_BULLETS do
        local fr = CreateFrame("Frame", nil, field)
        fr:SetSize(12, 12)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 4)
        fr:EnableMouse(false)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetSize(4, 10)
        tex:SetPoint("CENTER", fr, "CENTER", 0, 0)
        tex:SetColorTexture(0.5, 0.85, 1, 1)
        fr._tex = tex
        fr:Hide()
        self._bulletPool[i] = { frame=fr, tex=tex, active=false }
    end

    -- Hunter-Projektile (gleiche Rotations-Logik, 4x8)
    self._hBulletPool = {}
    for i = 1, POOL_H_BULLETS do
        local fr = CreateFrame("Frame", nil, field)
        fr:SetSize(12, 12)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 4)
        fr:EnableMouse(false)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetSize(4, 8)
        tex:SetPoint("CENTER", fr, "CENTER", 0, 0)
        tex:SetColorTexture(0.8, 0.2, 1, 1)
        fr._tex = tex
        fr:Hide()
        self._hBulletPool[i] = { frame=fr, tex=tex, active=false }
    end

    -- Fel Hunter (enemy_ship.tga)
    self._hunterPool = {}
    self._hunterThrustPool = {}
    for i = 1, POOL_HUNTERS do
        local fr = CreateFrame("Frame", nil, field)
        fr:SetSize(22, 22)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 3)
        fr:EnableMouse(false)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(fr)
        tex:SetTexture(ASSET_ENEMY)
        fr._tex = tex
        fr:Hide()
        self._hunterPool[i] = { frame=fr, tex=tex, active=false }

        -- Exhaust-Frame pro Hunter-Slot
        local ef = CreateFrame("Frame", nil, field)
        ef:SetSize(14, 14)
        ef:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        ef:SetFrameLevel(fl + 2)
        ef:EnableMouse(false)
        local etex = ef:CreateTexture(nil, "ARTWORK")
        etex:SetAllPoints(ef)
        etex:SetTexture(ASSET_EXHAUST)
        ef._tex = etex
        ef:Hide()
        self._hunterThrustPool[i] = ef
    end

    -- Power-Up Drops (Icon-Textur, goldener Rand)
    local PU_ICONS = { SHIELD=ICON_SHIELD, RAPID=ICON_RAPID, SPREAD=ICON_SPREAD, BOMB=ICON_BOMB, LIFE=ICON_LIFE }
    self._puPool = {}
    for i = 1, POOL_POWERUPS do
        local fr = CreateFrame("Frame", nil, field, "BackdropTemplate")
        fr:SetSize(24, 24)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 4)
        fr:EnableMouse(false)
        fr:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=2, insets={left=2,right=2,top=2,bottom=2} })
        fr:SetBackdropColor(0, 0, 0, 0.7)
        fr:SetBackdropBorderColor(1, 0.85, 0, 1)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(fr)
        tex:SetTexture(ICON_SHIELD)
        fr._tex   = tex
        fr._icons = PU_ICONS
        fr:Hide()
        self._puPool[i] = { frame=fr, tex=tex, active=false }
    end

    -- Partikel
    self._particlePool = {}
    for i = 1, POOL_PARTICLES do
        local fr = CreateFrame("Frame", nil, field)
        fr:SetSize(4, 4)
        fr:SetPoint("CENTER", field, "BOTTOMLEFT", 0, 0)
        fr:SetFrameLevel(fl + 6)
        fr:EnableMouse(false)
        local tex = fr:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(fr)
        tex:SetColorTexture(1, 1, 1, 1)
        fr._tex = tex
        fr:Hide()
        self._particlePool[i] = { frame=fr, tex=tex, active=false,
            x=0, y=0, vx=0, vy=0, lifetime=0, maxLifetime=1, r=1, g=1, b=1 }
    end
end

-- ── Flash ─────────────────────────────────────────────────────
function R:_CreateFlash()
    local field = self._fieldFrame
    if not field then return end
    local flash = CreateFrame("Frame", nil, field)
    flash:SetAllPoints(field)
    flash:SetFrameLevel(field:GetFrameLevel() + 50)
    flash:EnableMouse(false)
    local tex = flash:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(flash)
    tex:SetColorTexture(1, 0, 0, 0)
    flash._tex = tex
    flash:Hide()
    self._flashFrame = flash
    self._flashTex   = tex
end

-- ── Pause-Overlay ─────────────────────────────────────────────
function R:_CreatePauseOverlay()
    local field = self._fieldFrame
    if not field then return end

    local ov = CreateFrame("Frame", nil, field, "BackdropTemplate")
    ov:SetSize(200, 60)
    ov:SetPoint("CENTER", field, "CENTER", 0, 0)
    ov:SetFrameLevel(field:GetFrameLevel() + 35)
    ov:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=2, insets={left=2,right=2,top=2,bottom=2} })
    ov:SetBackdropColor(0, 0, 0, 0.85)
    ov:SetBackdropBorderColor(0.4, 0.6, 1, 1)
    ov:EnableMouse(false)

    local fs = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER", ov, "CENTER", 0, 0)
    fs:SetText("Pause")
    fs:SetTextColor(0.6, 0.8, 1, 1)

    ov:Hide()
    self._pauseOverlay = ov
end

-- ── _CreateControls (AlienDefense-Blueprint) ──────────────────
function R:_CreateControls()
    if not self.frame then return end
    local UI       = ArcadiaNexus.UI
    local L        = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    local Settings = ArcadiaNexus.AOD_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    local DD_W     = 120
    local BTN_W    = 144
    local BTN_H    = 32
    local CHK_SIZE = 20

    -- Difficulty-Dropdown (Segment 1)
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(DD_W, BTN_H)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    local diffOptions = {
        { key = "easy",   label = L["diff_easy"]   or "Einfach" },
        { key = "normal", label = L["diff_normal"]  or "Normal"  },
        { key = "hard",   label = L["diff_hard"]    or "Schwer"  },
    }
    local dd = UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, DD_W, "",
        diffOptions,
        function()
            return (Settings and Settings:Get("difficulty")) or "normal"
        end,
        function(key)
            self._lastDiff = key
            if Settings then Settings:Set("difficulty", key) end
        end
    )
    self._diffDropdown = dd

    -- Start (IDLE) / Beenden (Menü + Spiel)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel Starten", BTN_W, BTN_H)
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
        local eng = ArcadiaNexus.AOD_Engine
        if not eng then return end
        if eng.state == "GAMEOVER" then
            eng:StopGame()
        elseif eng.state ~= "IDLE" then
            eng:SaveAndPause()
            R:EnterIdleState()
        end
    end)
    exitBtn:Hide()
    self._exitBtn      = exitBtn
    self._btnStartStop = exitBtn   -- Alias für bestehende Referenzen

    -- Pause-Button (Segment 3)
    local pauseBtn = UI.CreateArcadiaButton(cf, L["btn_pause"] or "Pause", BTN_W, BTN_H)
    pauseBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    pauseBtn:SetScript("OnClick", function()
        local eng = ArcadiaNexus.AOD_Engine
        if not eng then return end
        if     eng.state == "PLAYING" then eng:Pause()
        elseif eng.state == "PAUSED"  then eng:Resume()
        end
    end)
    pauseBtn:Hide()
    self._pauseBtn = pauseBtn
    self._btnPause = pauseBtn   -- Alias

    -- Endlos-Checkbox (Segment 4)
    local chkHolder = CreateFrame("Frame", nil, cf)
    chkHolder:SetSize(CHK_SIZE + 4, CHK_SIZE + 20)
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)

    -- Label zentriert über der Checkbox
    local chkLabel = chkHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkLabel:SetPoint("BOTTOM", chkHolder, "TOP", 0, -18)
    chkLabel:SetJustifyH("CENTER")
    chkLabel:SetText(L["lbl_endless"] or "Endlos")

    local chk = CreateFrame("CheckButton", nil, chkHolder, "UICheckButtonTemplate")
    chk:SetSize(CHK_SIZE, CHK_SIZE)
    chk:SetPoint("CENTER", chkHolder, "CENTER", 0, -8)
    chk:SetChecked(true)
    chk:SetScript("OnClick", function()
        R._endlessMode = chk:GetChecked() and true or false
        if Settings then Settings:Set("endlessMode", R._endlessMode) end
    end)
    self._endlessChk    = chk
    self._cbEndless     = chk      -- Alias
    self._cbEndlessLbl  = chkLabel
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE")
    local S  = ArcadiaNexus.AOD_Settings
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
            if save.mode == "endless" then
                return string.format("%s · %s", loc.mode_endless or "Endless", score)
            end
            return string.format(loc.slot_info or "Level %d · %s", save.level or 1, score)
        end,
        isPaused      = function() return true end,
        onNewGame     = function(slot)
            local eng = ArcadiaNexus.AOD_Engine
            if not eng then return end
            eng:StartGame({
                slot = slot, mode = "new",
                difficulty = R._lastDiff or (S and S:Get("difficulty")) or "normal",
                gameMode   = R._endlessMode and "endless" or "levels",
            })
        end,
        onContinue    = function(slot)
            local eng = ArcadiaNexus.AOD_Engine
            if eng then eng:StartGame({ slot = slot, mode = "continue" }) end
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
    if self._slotMenu then self._slotMenu:Show() end
end

-- ── KeyFrame ──────────────────────────────────────────────────
function R:_CreateKeyFrame()
    local field = self._fieldFrame
    if not field then return end

    local kf = CreateFrame("Frame", nil, field)
    kf:SetAllPoints(field)
    kf:SetPropagateKeyboardInput(false)
    kf:EnableKeyboard(false)

    kf:SetScript("OnKeyDown", function(_, key)
        local E = ArcadiaNexus.AOD_Engine
        if not E then return end
        if     key == "A" or key == "LEFT"  then E:HandleKey("ROTATE_LEFT",  true)
        elseif key == "D" or key == "RIGHT" then E:HandleKey("ROTATE_RIGHT", true)
        elseif key == "W" or key == "UP"    then E:HandleKey("THRUST",       true)
        elseif key == "SPACE"               then E:HandleKey("FIRE",         true)
        elseif key == "ESCAPE"              then E:HandleKey("PAUSE",        true)
        end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local E = ArcadiaNexus.AOD_Engine
        if not E then return end
        if     key == "A" or key == "LEFT"  then E:HandleKey("ROTATE_LEFT",  false)
        elseif key == "D" or key == "RIGHT" then E:HandleKey("ROTATE_RIGHT", false)
        elseif key == "W" or key == "UP"    then E:HandleKey("THRUST",       false)
        elseif key == "SPACE"               then E:HandleKey("FIRE",         false)
        end
    end)
    self._keyFrame = kf
end

-- ── Pool-Hilfsfunktionen ─────────────────────────────────────
local function GetFreeSlot(pool)
    for _, slot in ipairs(pool) do
        if not slot.active then return slot end
    end
    return nil
end

local function HideAllPool(pool)
    for _, slot in ipairs(pool) do
        slot.active = false
        slot.frame:Hide()
    end
end

-- ── Partikel ─────────────────────────────────────────────────
function R:_SpawnParticles(x, y, count, r, g, b, speed, lifetime)
    for _ = 1, count do
        local slot = GetFreeSlot(self._particlePool)
        if not slot then break end
        local ang        = math.random() * math.pi * 2
        local spd        = speed * (0.5 + math.random() * 0.8)
        slot.active      = true
        slot.x           = x;   slot.y  = y
        slot.vx          = math.cos(ang) * spd
        slot.vy          = math.sin(ang) * spd
        slot.lifetime    = lifetime * (0.7 + math.random() * 0.6)
        slot.maxLifetime = slot.lifetime
        slot.tex:SetColorTexture(r, g, b, 1)
        slot.frame:SetPoint("CENTER", self._fieldFrame, "BOTTOMLEFT", x, y)
        slot.frame:SetAlpha(1)
        slot.frame:Show()
    end
end

function R:_StartParticleUpdate()
    if self._particleUpdateRunning then return end
    self._particleUpdateRunning = true
    local field = self._fieldFrame
    local pool  = self._particlePool
    if not field then return end
    field:SetScript("OnUpdate", function(_, dt)
        for _, slot in ipairs(pool) do
            if slot.active then
                slot.x        = slot.x  + slot.vx * dt
                slot.y        = slot.y  + slot.vy * dt
                slot.lifetime = slot.lifetime - dt
                if slot.lifetime <= 0 then
                    slot.active = false
                    slot.frame:Hide()
                else
                    slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", slot.x, slot.y)
                    slot.frame:SetAlpha(math.max(0, slot.lifetime / slot.maxLifetime))
                end
            end
        end
    end)
end

-- ── UpdatePhysics ─────────────────────────────────────────────

function R:UpdatePhysics(gs)
    local field = self._fieldFrame
    if not field or not gs then return end

    -- Schiff
    local ship = gs.ship
    if ship.alive then
        self._shipFrame:SetPoint("CENTER", field, "BOTTOMLEFT", ship.x, ship.y)
        self._shipTex:SetRotation(ship.angle)
        if ship.invTimer > 0 then
            self._shipFrame:SetAlpha(math.floor(ship.invTimer / 0.15) % 2 == 0 and 0.15 or 1.0)
        else
            self._shipFrame:SetAlpha(1.0)
        end
        self._shipFrame:Show()

        -- Schub-Effekt mit exhaust.tga
        if ship.thrusting then
            local tx = ship.x - math.cos(ship.angle - math.pi/2) * 18
            local ty = ship.y - math.sin(ship.angle - math.pi/2) * 18
            self._thrustFrame:SetPoint("CENTER", field, "BOTTOMLEFT", tx, ty)
            self._thrustTex:SetRotation(ship.angle)
            self._thrustFrame:Show()
        else
            self._thrustFrame:Hide()
        end
    else
        self._shipFrame:Hide()
        self._thrustFrame:Hide()
    end

    -- Meteore (Größe + Asset per texType)
    HideAllPool(self._meteorPool)
    for i, m in ipairs(gs.meteors) do
        local slot = self._meteorPool[i]
        if slot then
            local sz    = METEOR_SIZE[m.size] or 22
            local asset = METEOR_ASSETS[m.texType or 1] or METEOR_ASSETS[1]
            slot.frame:SetSize(sz, sz)
            slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", m.x, m.y)
            slot.tex:SetTexture(asset)
            slot.tex:SetRotation(m.rotAngle)
            slot.active = true
            slot.frame:Show()
        end
    end

    -- Spieler-Projektile: Rotation = Abschusswinkel (nicht aktueller Schiffswinkel)
    HideAllPool(self._bulletPool)
    for i, b in ipairs(gs.bullets) do
        local slot = self._bulletPool[i]
        if slot then
            slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", b.x, b.y)
            if slot.tex.SetRotation then
                slot.tex:SetRotation(b.angle or 0)
            end
            slot.active = true
            slot.frame:Show()
        end
    end

    -- Hunter-Projektile: 0 = oben, Flugvektor ist Standard-atan2 (0 = rechts)
    HideAllPool(self._hBulletPool)
    for i, b in ipairs(gs.hunterBullets) do
        local slot = self._hBulletPool[i]
        if slot then
            slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", b.x, b.y)
            if slot.tex.SetRotation then
                local ang = b.angle or (math.atan2(b.vy, b.vx) + math.pi / 2)
                slot.tex:SetRotation(ang)
            end
            slot.active = true
            slot.frame:Show()
        end
    end

    -- Fel Hunter
    HideAllPool(self._hunterPool)
    -- Alle Hunter-Exhausts initial verstecken
    for _, ef in ipairs(self._hunterThrustPool) do ef:Hide() end
    for i, h in ipairs(gs.hunters) do
        local angle = math.atan2(h.vy, h.vx) + math.pi / 2
        local slot = self._hunterPool[i]
        if slot then
            slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", h.x, h.y)
            slot.tex:SetRotation(angle)
            slot.active = true
            slot.frame:Show()
        end
        -- Exhaust wenn Hunter beschleunigt (gleiche Achse wie Player-Ship)
        local ef = self._hunterThrustPool[i]
        if ef then
            if h.thrusting then
                local ex = h.x - math.cos(angle - math.pi/2) * 14
                local ey = h.y - math.sin(angle - math.pi/2) * 14
                ef:SetPoint("CENTER", field, "BOTTOMLEFT", ex, ey)
                if ef._tex then ef._tex:SetRotation(angle) end
                ef:Show()
            else
                ef:Hide()
            end
        end
    end

    -- Power-Up Drops: originale TGA-Assets, Rahmenfarbe pro Typ
    HideAllPool(self._puPool)
    for i, p in ipairs(gs.powerDrops) do
        local slot = self._puPool[i]
        if slot then
            slot.frame:SetPoint("CENTER", field, "BOTTOMLEFT", p.x, p.y)
            -- TGA-Assets: SHIELD → grünes Asset, alle anderen → rotes Asset (original)
            if p.puType == "SHIELD" then
                slot.tex:SetTexture(PU_ASSET_SHIELD)
            else
                slot.tex:SetTexture(PU_ASSET_WEAPON)
            end
            -- Rahmenfarbe pro Typ
            local col = PU_COLORS[p.puType] or PU_COLORS.SHIELD
            slot.frame:SetBackdropBorderColor(col[1], col[2], col[3], 1)
            local pulse = math.sin(p.lifetime * 4) * 2
            slot.frame:SetSize(24 + pulse, 24 + pulse)
            slot.active = true
            slot.frame:Show()
        end
    end
end

-- ── HUD ───────────────────────────────────────────────────────
function R:UpdateHUD(gs)
    if not gs then return end
    if self._scoreFS then self._scoreFS:SetText(tostring(gs.score or 0)) end
    if self._waveFS  then
        if gs.gameMode == "levels" then
            self._waveFS:SetText("Level " .. (gs.level or 1))
        else
            self._waveFS:SetText("Welle " .. (gs.wave or 1))
        end
    end
    if self._livesTex then
        local count = math.max(0, gs.lives or 0)
        for i, t in ipairs(self._livesTex) do
            if i <= count then t:Show() else t:Hide() end
        end
    end
    if self._shieldHUD then
        if gs.shieldTimer and gs.shieldTimer > 0 then
            if self._shieldFS then self._shieldFS:SetText(string.format("%.1fs", gs.shieldTimer)) end
            self._shieldHUD:Show()
        else
            self._shieldHUD:Hide()
        end
    end
    if self._rapidHUD then
        local t = math.max(gs.rapidTimer or 0, gs.spreadTimer or 0)
        if t > 0 then
            if self._rapidFS then self._rapidFS:SetText(string.format("%.1fs", t)) end
            self._rapidHUD:Show()
        else
            self._rapidHUD:Hide()
        end
    end
end

function R:UpdatePowerUpBar(gs) self:UpdateHUD(gs) end

-- ── Event-Handler ─────────────────────────────────────────────
function R:OnGameStarted(gs)
    local L = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    self.state = "PLAYING"

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._shieldHUD    then self._shieldHUD:Hide()    end
    if self._rapidHUD     then self._rapidHUD:Hide()     end
    if self._logoTex      then self._logoTex:Hide()      end
    if self._slotMenu     then self._slotMenu:Hide()     end

    if self._startBtn     then self._startBtn:Hide() end
    if self._exitBtn      then self._exitBtn:Show()  end
    if self._pauseBtn     then self._pauseBtn:Show() end
    if self._diffDropdown then self._diffDropdown:SetEnabled(false); self._diffDropdown:Hide() end
    if self._endlessChk   then self._endlessChk:Hide() end
    if self._cbEndlessLbl then self._cbEndlessLbl:Hide() end

    if self._keyFrame  then self._keyFrame:EnableKeyboard(true) end
    if self._shipFrame then self._shipFrame:Show() end

    if self._livesBox then self._livesBox:Show() end
    if self._scoreBox then self._scoreBox:Show() end
    if self._waveBox  then self._waveBox:Show()  end

    self:_StartParticleUpdate()
    self:UpdateHUD(gs)

    self._lastDiff    = gs.difficulty
    self._endlessMode = gs.gameMode == "endless"
end

function R:OnLevelAdvanced(gs)
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:UpdateHUD(gs)
end

function R:OnMeteorDestroyed(meteor, isBomb)
    if meteor then self:_SpawnParticles(meteor.x, meteor.y, isBomb and 4 or 7, 0.2, 1.0, 0.2, 80, 0.6) end
end

function R:OnHunterDestroyed(hunter, isBomb)
    if hunter then self:_SpawnParticles(hunter.x, hunter.y, isBomb and 5 or 8, 0.8, 0.2, 1.0, 90, 0.7) end
end

function R:OnBombExplode(x, y)
    self:_SpawnParticles(x, y, 20, 1, 0.9, 0.3, 150, 1.0)
end

function R:OnShipDied(gs)
    local ship = gs and gs.ship
    if ship then self:_SpawnParticles(ship.x, ship.y, 12, 0.4, 0.7, 1, 100, 1.2) end
    if self._shipFrame   then self._shipFrame:Hide()   end
    if self._thrustFrame then self._thrustFrame:Hide() end
end

function R:OnShipRespawned(gs)
    if self._shipFrame then self._shipFrame:Show() end
end

function R:OnPowerUpCollected(puType, gs) self:UpdateHUD(gs) end
function R:OnPowerUpExpired(puType, gs)   self:UpdateHUD(gs) end

function R:FlashScreen(r, g, b, duration)
    local flash = self._flashFrame
    if not flash then return end
    flash._tex:SetColorTexture(r, g, b, 0.5)
    flash:SetAlpha(1)
    flash:Show()
    local t0 = GetTime()
    flash:SetScript("OnUpdate", function(self_f, _)
        local a = 1 - (GetTime() - t0) / (duration or 0.3)
        if a <= 0 then
            self_f:Hide()
            self_f:SetScript("OnUpdate", nil)
        else
            self_f:SetAlpha(a)
        end
    end)
end

function R:ShowPause()
    if self._pauseOverlay then self._pauseOverlay:Show() end
    local L = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    if self._btnPause then self._btnPause:SetLabel(L["btn_resume"] or "Weiterspielen") end
end

function R:HidePause()
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    local L = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    if self._btnPause then self._btnPause:SetLabel(L["btn_pause"] or "Pause") end
end

function R:_RetryFromResult()
    ArcadiaNexus.AOD_Engine:StartGame({
        mode       = "new",
        difficulty = self._lastDiff,
        gameMode   = self._endlessMode and "endless" or "levels",
    })
end

function R:ShowWaveClear(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    local UI = ArcadiaNexus.UI
    local isLevel = gs.gameMode == "levels"
    local title = isLevel
        and ((L["popup_level"] or "Level:") .. " " .. gs.level .. " – " .. (L["state_wave_clear"] or "Level geschafft!"))
        or  ((L["popup_wave"] or "Welle:") .. " " .. (gs.wave or 0) .. " – " .. (L["state_wave_clear"] or "Welle geschafft!"))
    local buttons = {}
    if isLevel and (gs.level or 0) < 30 then
        buttons[#buttons + 1] = {
            label   = L["btn_continue"] or "Weiter",
            onClick = function()
                ArcadiaNexus.AOD_Engine:ContinueToNextLevel()
            end,
        }
    end
    buttons[#buttons + 1] = {
        label   = L["popup_play_again"] or "Nochmal",
        onClick = function() R:_RetryFromResult() end,
    }
    buttons[#buttons + 1] = {
        label   = L["btn_exit"] or L["popup_exit"] or "Beenden",
        onClick = function() ArcadiaNexus.AOD_Engine:StopGame() end,
    }
    UI.ShowArcadeResult(field, {
        title      = title,
        titleColor = { 0.4, 1, 0.5 },
        score      = gs.score,
        gameId     = "ARGUSORBITDEFENSE",
        difficulty = gs.difficulty or self._lastDiff,
        result     = "WIN",
        L          = L,
        buttons    = buttons,
    })
end

function R:ShowVictory(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    local UI = ArcadiaNexus.UI
    UI.ShowArcadeResult(field, {
        title      = L["state_victory"] or "Argus verteidigt!",
        titleColor = { 1, 0.84, 0 },
        score      = gs.score,
        gameId     = "ARGUSORBITDEFENSE",
        difficulty = gs.difficulty or self._lastDiff,
        result     = "WIN",
        L          = L,
        onRetry    = function() R:_RetryFromResult() end,
        onExit     = function() ArcadiaNexus.AOD_Engine:StopGame() end,
    })
end

function R:ShowGameOver(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}
    local UI = ArcadiaNexus.UI
    UI.ShowArcadeResult(field, {
        title      = L["state_gameover"] or "Schiff zerstört!",
        titleColor = { 1, 0.27, 0.27 },
        score      = gs.score,
        gameId     = "ARGUSORBITDEFENSE",
        difficulty = gs.difficulty or self._lastDiff,
        result     = "LOSS",
        L          = L,
        onRetry    = function() R:_RetryFromResult() end,
        onExit     = function() ArcadiaNexus.AOD_Engine:StopGame() end,
    })
end

function R:EnterIdleState()
    if not self.frame then return end
    self.state = "IDLE"

    HideAllPool(self._meteorPool)
    HideAllPool(self._bulletPool)
    HideAllPool(self._hBulletPool)
    HideAllPool(self._hunterPool)
    for _, ef in ipairs(self._hunterThrustPool) do ef:Hide() end
    HideAllPool(self._puPool)
    HideAllPool(self._particlePool)

    if self._shipFrame    then self._shipFrame:Hide()    end
    if self._thrustFrame  then self._thrustFrame:Hide()  end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._shieldHUD    then self._shieldHUD:Hide()    end
    if self._rapidHUD     then self._rapidHUD:Hide()     end
    if self._flashFrame   then self._flashFrame:Hide()   end
    if self._logoTex      then self._logoTex:Show()      end
    if self._slotMenu     then self._slotMenu:Hide()     end

    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end

    if self._fieldFrame then self._fieldFrame:SetScript("OnUpdate", nil) end
    self._particleUpdateRunning = false

    if self._startBtn     then self._startBtn:Show() end
    if self._exitBtn      then self._exitBtn:Hide()  end
    if self._pauseBtn     then self._pauseBtn:Hide() end
    if self._diffDropdown then self._diffDropdown:SetEnabled(true); self._diffDropdown:Show() end
    if self._endlessChk   then self._endlessChk:Show() end
    if self._cbEndlessLbl then self._cbEndlessLbl:Show() end

    if self._livesBox then self._livesBox:Hide() end
    if self._scoreBox then self._scoreBox:Hide() end
    if self._waveBox  then self._waveBox:Hide()  end
    -- KEIN f:Show() hier — Framework steuert Container-Sichtbarkeit
end
