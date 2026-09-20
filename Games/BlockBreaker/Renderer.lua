-- ============================================================
--  BlockBreaker – Renderer.lua  (v40 – AD-Blueprint)
--  Reine Darstellung. Schreibt NIEMALS in den Game-State.
--
--  Struktur 1:1 nach AlienDefense-Blueprint:
--    _contentFrame  – zentrierter Wrapper
--    _fieldFrame    – Spielfeld (565x370)
--    _logoTex       – Logo (IDLE)
--    _keyFrame      – Tastatur-Input (am fieldFrame)
--    _flashFrame    – Screen-Flash
--    _diffContainer – Controls-Leiste (Dropdown + Buttons)
--    _pauseOverlay  – Pause
-- ============================================================

ArcadiaNexus.BB_Renderer = {}
local R = ArcadiaNexus.BB_Renderer

-- ── CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60) ─
local CFG = {
    -- Asset-Pfad (Kurzreferenz)
    white8x8     = "Interface\\Buttons\\WHITE8X8",

    -- Logo
    logo_w       = 356,
    logo_h       = 356,
    logo_x       = 0,
    logo_y       = 0,

    -- Border (eigener Frame, FrameLevel +10 über _fieldFrame)
    border_w     = 795,
    border_h     = 550,
    border_x     = 0,
    border_y     = 0,
    border_alpha = 1.0,

    -- Spielfeld
    field_w      = 695,
    field_h      = 480,
    field_ofs_x      = 0,
    field_ofs_y      = 45,

    content_h    = 420,
    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- HUD-Boxen (relativ zu Canvas CENTER)
    hud_y          =  -207,
    hud_l_x        = -210,
    hud_c_x        =    0,
    hud_r_x        =  210,
    hud_time_w     = 140,
    hud_time_h     = 28,
    hud_time_alpha = 0.75,
    hud_score_w    = 220,
    hud_score_h    = 28,
    hud_score_alpha = 0.75,
    hud_lives_w    = 140,
    hud_lives_h    = 28,
    hud_lives_alpha = 0.75,

    -- Power-Up-Statusbox (relativ zu Canvas CENTER; Frame über dem Spielfeld)
    hud_pu_x       = -210,
    hud_pu_y       =  199,
    hud_pu_w       =  160,
    hud_pu_h       =   28,
    hud_pu_alpha   = 0.75,
    hud_pu_bar_w   =  100,
    hud_pu_bar_h   =    4,
    hud_pu_bar_x   =    0,    -- relativ zur PU-Box CENTER
    hud_pu_bar_y   =  -14,
    hud_pu_stack   =  32,   -- Abstand zwischen gestapelten PU-Timer-Boxen
    hud_pu_slots   =   3,

    -- Fallende Power-Up-Drops (Offset relativ zur Logic-Position)
    pu_drop_w      = 96,
    pu_drop_h      = 26,
    pu_drop_ofs_x  =  0,
    pu_drop_ofs_y  =  0,

    -- Wand-Hit / Endgame-Glow (px relativ zum Feldrand)
    -- x/y verschieben die Leiste, pad kürzt sie an den Enden, thick = Breite.
    -- left_x + nach innen, right_x − nach innen, top_y − nach unten.
    edge_thick        = 6,
    edge_cap_overlap  = 0.45,
    edge_left_x       = 3,
    edge_left_y       = 0,
    edge_left_pad     = 3,
    edge_right_x      = -3,
    edge_right_y      = 0,
    edge_right_pad    = 3,
    edge_top_x        = 0,
    edge_top_y        = -3,
    edge_top_pad      = 3,

    -- Spielfeld-Objekte (Layout-Quelle: BB_Logic, Werte hier als Fallback)
    block_w      = 28,
    block_h      = 16,
    field_cols   = 20,
    paddle_w     = 80,
    paddle_h     = 22,
    ball_size    = 12,
    block_top_pad = 20,
    block_ox     = 2,
}
local function SyncPlayfieldLayout()
    local L = ArcadiaNexus.BB_Logic
    if not L then return end
    if L.RefreshBlockMetrics then L:RefreshBlockMetrics() end
    CFG.field_w       = L.FIELD_W
    CFG.field_h       = L.FIELD_H
    CFG.block_w       = L.BLOCK_W
    CFG.block_h       = L.BLOCK_H
    CFG.field_cols    = L.FIELD_COLS
    CFG.block_top_pad = L.BLOCK_TOP_PAD
    CFG.block_ox      = L.BLOCK_OX
end
SyncPlayfieldLayout()
-- Abgeleitete Konstante
CFG.content_w = CFG.field_w + CFG.field_ofs_x + CFG.field_ofs_x

-- ── Tabellen (je 1 Upvalue) ───────────────────────────────────
local BB_ASSETS = {
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\logo\\logo_blockbreaker",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\border\\border_blockbreaker",
}

local PU_TIMER_DEF = {
    big      = { r=0.3,  g=0.8,  b=1.0,  max=10 },
    fast     = { r=1.0,  g=0.5,  b=0.1,  max=8  },
    slow     = { r=0.4,  g=0.9,  b=0.4,  max=8  },
    small    = { r=1.0,  g=0.2,  b=0.2,  max=8  },
    strength = { r=1.0,  g=0.85, b=0.0,  max=8  },
}

local BLOCK_TILES = {
    "red", "blue", "green", "yellow", "violett",
    "orange", "light_blue", "light_green", "brown", "grey",
}

local THEME_COLORS = { "blue", "green", "red", "violett", "yellow" }

local PU_FOLDER = {
    lives    = "bonus_lives",
    score250 = "bonus_250",
    score500 = "bonus_500",
    big      = "bonus_big",
    bullet   = "bonus_bullet",
    fast     = "bonus_fast",
    slow     = "bonus_slow",
    small    = "bonus_small",
    strength = "bonus_strength",
}

-- ── Pfad-Konstanten (Strings, je 1 Upvalue) ──────────────────
local BLOCK_PATH    = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\tile\\blocks\\"
local THEME_PATH    = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\tile\\theme\\"
local PU_ASSET_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\tile\\ui\\"
local HEART_PATH    = PU_ASSET_PATH .. "heart"

-- ── Theme-Hilfsfunktionen ─────────────────────────────────────
local _activeThemeColor = nil

local function GetThemeColor()
    return _activeThemeColor or "blue"
end

local function ResolveTheme()
    local S     = ArcadiaNexus.BB_Settings
    local theme = (S and S:Get("theme")) or "random"
    if theme == "random" then
        _activeThemeColor = THEME_COLORS[math.random(#THEME_COLORS)]
    else
        _activeThemeColor = theme
    end
end

local function GetPUTexPath(puType)
    local folder = PU_FOLDER[puType]
    if not folder then return nil end
    local color  = GetThemeColor()
    return PU_ASSET_PATH .. folder .. "\\" .. folder .. "_" .. color
end

local function CreateBlockPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "BlockBreaker.Blocks",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Frame", nil, poolParent)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(f)
            f._tex = tex
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            f._row = nil
            f._col = nil
            f._colorIdx = nil
            f._blockType = nil
            if f._tex then
                f._tex:SetTexture(nil)
                f._tex:SetTexCoord(0, 1, 0, 1)
                f._tex:SetVertexColor(1, 1, 1)
                f._tex:SetAlpha(1)
                f._tex:SetDesaturated(false)
            end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

local function CreateExtraBallPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "BlockBreaker.ExtraBalls",
        create = function(poolParent)
            poolParentRef = poolParent
            local bf = CreateFrame("Frame", nil, poolParent)
            bf:SetSize(CFG.ball_size, CFG.ball_size)
            local bft = bf:CreateTexture(nil, "ARTWORK")
            bft:SetAllPoints(bf)
            bf._tex = bft
            return bf
        end,
        onRelease = function(bf)
            bf:Hide()
            bf:ClearAllPoints()
            if bf._tex then
                bf._tex:SetTexture(nil)
                bf._tex:SetTexCoord(0, 1, 0, 1)
                bf._tex:SetVertexColor(1, 1, 1)
                bf._tex:SetAlpha(1)
            end
            if poolParentRef then bf:SetParent(poolParentRef) end
        end,
    })
end

-- ── State ─────────────────────────────────────────────────────
R.frame          = nil
R._canvas        = nil
R._contentFrame  = nil
R._logoTex       = nil
R._fieldFrame    = nil
R._keyFrame      = nil
R._flashFrame    = nil
R._flashTex      = nil
R._pauseOverlay  = nil
R._diffContainer = nil
R._exitBtn       = nil
R._pauseBtn      = nil
R._resumeBtn     = nil
R._savedHintFS   = nil
R._diffDropdown  = nil

R._ballFrame    = nil
R._paddleFrame  = nil
R._extraBalls   = {}
R._blockFrames  = {}
R._blockPool    = nil
R._extraBallPool = nil
R._fxLayer      = nil
R._trailDots    = {}
R._mainTrail    = {}
R._extraTrails  = {}
R._shards       = {}
R._pops         = {}
R._popFS        = {}
R._paddleSquashT = 0
R._comboFlashT  = 0
R._comboFlashFS = nil
R._puDropFrame  = nil
R._flashFrame   = nil
R._puBar        = nil
R._puBox        = nil
R._puListBox    = nil
R._puSlots      = nil

R._scoreFS      = nil
R._levelFS      = nil
R._livesFS      = nil
R._timeFS       = nil
R._endlessFS    = nil
R._puTimerFS    = nil   -- Label: PU-Name + verbleibende Zeit
R._puTimerBg    = nil   -- Balken-Hintergrund
R._puTimerFill  = nil   -- Balken-Füllstand

R._lastDiff = "easy"
R.state     = "IDLE"

R._flashR, R._flashG, R._flashB = 1, 0.2, 0.2

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "BLOCKBREAKER",
    label     = "BlockBreaker",
    category  = "ARCADE",
    renderer  = "BB_Renderer",
    engine    = "BB_Engine",
    container = "_bbContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\BlockBreaker\\assets\\logo\\logo_blockbreaker",
    xp        = 10,
})

-- ══════════════════════════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════════════════════════

function R:Init()
    local S = ArcadiaNexus.BB_Settings
    self._lastDiff = (S and S:Get("difficulty")) or "easy"

    self:_CreateMainFrame()
    if not self.frame then return end
    self:_CreateContentFrame()
    self:_CreateHUD()
    self:_CreateFieldFrame()
    self:_CreateLogo()
    self:_CreateBallAndPaddle()
    self:_CreateFlash()
    self:_CreateFx()
    self:_CreatePUBar()
    self:_CreateKeyFrame()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreatePauseOverlay()
    self:_CreateDevOverlay()
    self:EnterIdleState()
end

-- ── _CreateMainFrame ──────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_BB_Container",
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    local inner = CreateFrame("Frame", nil, self._canvas)
    inner:SetSize(CFG.content_w, CFG.content_h)
    inner:SetPoint("CENTER", self._canvas, "CENTER", 0, 0)
    self._contentFrame = inner
    ArcadiaNexus._bbContainer = f
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("BLOCKBREAKER", ArcadiaNexus.BB_Engine, function(E)
            if E.state == "PLAYING" then
                E:SaveAndPause()
            end
        end)
    end)
end

-- ── _CreateContentFrame ───────────────────────────────────────
function R:_CreateContentFrame()
    -- Inner wrapper sits on the games canvas; controls live on the panel footer.
end

-- ── HUD ───────────────────────────────────────────────────────
function R:_CreateHUD()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._timeBox, self._timeFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_l_x, y = CFG.hud_y,
        alpha = CFG.hud_time_alpha,
        shown = false,
    })
    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_c_x, y = CFG.hud_y,
        alpha = CFG.hud_score_alpha,
        shown = false,
    })
    self._livesBox, self._livesFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_lives_w, h = CFG.hud_lives_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_r_x, y = CFG.hud_y,
        alpha = CFG.hud_lives_alpha,
        shown = false,
    })

    local endlessFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    endlessFS:SetPoint("CENTER", canvas, "CENTER", CFG.hud_c_x, CFG.hud_y - 22)
    endlessFS:SetTextColor(1, 0.85, 0)
    endlessFS:SetText("")
    self._endlessFS = endlessFS
end

function R:_RaiseHudOverField()
    local field = self._fieldFrame
    if not field then return end
    local hudLvl = field:GetFrameLevel() + 25
    local boxes = {
        self._timeBox, self._scoreBox, self._livesBox,
    }
    for i = 1, #(self._puSlots or {}) do
        boxes[#boxes + 1] = self._puSlots[i].box
    end
    for i = 1, #boxes do
        local b = boxes[i]
        if b then b:SetFrameLevel(hudLvl) end
    end
end

function R:_IsDevMode()
    return ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() == true
end

function R:_DevOverlayOn()
    if not self:_IsDevMode() then return false end
    local S = ArcadiaNexus.BB_Settings
    if S then return S:Get("debugOverlay") ~= false end
    return true
end

function R:RefreshDevOverlay()
    local on = self:_DevOverlayOn()
    if self._devOverlay then
        if on then self._devOverlay:Show() else self._devOverlay:Hide() end
    end
    if self.state == "IDLE" then
        if on then
            self:_ApplyDevHudPreview()
        else
            self:_SetHudShown(false)
            if self._puBar       then self._puBar:SetText("") end
            self:_HidePuSlots()
        end
    end
    if self._keyFrame then
        local play = self.state == "PLAYING" or self.state == "PAUSED"
        self._keyFrame:EnableKeyboard(play)
    end
end

-- Dummy-Inhalt für PU-Boxen (Stack + Countdown), damit Layout ohne aktives PU sichtbar ist.
function R:_HidePuSlots()
    for i = 1, #(self._puSlots or {}) do
        local s = self._puSlots[i]
        s.box:Hide()
        if s.fs   then s.fs:SetText("") end
        if s.bg   then s.bg:Hide() end
        if s.fill then s.fill:Hide() end
    end
end

function R:_FillDevPuPreview()
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local demo = {
        { key = "big",      t = 8 },
        { key = "fast",     t = 5 },
        { key = "strength", t = 3 },
    }
    for i = 1, #(self._puSlots or {}) do
        local s = self._puSlots[i]
        local d = demo[i]
        if d then
            local def = PU_TIMER_DEF[d.key]
            s.fs:SetText((L["pu_" .. d.key] or d.key) .. " " .. d.t .. "s")
            if def then s.fs:SetTextColor(def.r, def.g, def.b) end
            s.box:Show()
            if s.bg then s.bg:Show() end
            if s.fill and def then
                s.fill:SetWidth(math.max(1, CFG.hud_pu_bar_w * (d.t / def.max)))
                s.fill:SetColorTexture(def.r, def.g, def.b, 1)
                s.fill:Show()
            end
        else
            s.box:Hide()
        end
    end
end

function R:_ApplyDevHudPreview()
    if not self:_DevOverlayOn() or self.state ~= "IDLE" then return false end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    if self._timeBox  then self._timeBox:Show()  end
    if self._scoreBox then self._scoreBox:Show() end
    if self._livesBox then self._livesBox:Show() end
    if self._goldGrid then self._goldGrid:Show() end
    if self._timeFS then
        self._timeFS:SetText((L["lbl_time"] or "Zeit") .. ": 01:23")
    end
    if self._scoreFS then
        self._scoreFS:SetText(
            (L["lbl_level"] or "Level") .. ": 4   " ..
            (L["lbl_score"] or "Punkte") .. ": 12500")
    end
    if self._livesFS then
        local hearts = ""
        for _ = 1, 3 do
            hearts = hearts .. "|T" .. HEART_PATH .. ":14:14|t"
        end
        self._livesFS:SetText(hearts)
    end
    self:_FillDevPuPreview()
    self:_RaiseHudOverField()
    return true
end

function R:_SetHudShown(shown)
    local vis = shown or (self.state == "IDLE" and self:_DevOverlayOn())
    local boxes = { self._timeBox, self._scoreBox, self._livesBox, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if vis then b:Show() else b:Hide() end
        end
    end
    if not vis then
        self:_HidePuSlots()
    end
end

-- ── _CreateFieldFrame ─────────────────────────────────────────
function R:_CreateFieldFrame()
    local cf = self._contentFrame
    local field = CreateFrame("Frame", nil, cf, "BackdropTemplate")
    field:SetSize(CFG.field_w, CFG.field_h)
    field:SetPoint("TOPLEFT", cf, "TOPLEFT", CFG.field_ofs_x, CFG.field_ofs_y)
    field:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileEdge=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    field:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
    field:SetBackdropBorderColor(0.6, 0.5, 0.2, 0)
    self._fieldFrame = field

    -- Border-Frame: eigener Frame mit FrameLevel +10 über dem Spielfeld.
    -- Liegt garantiert über allen Block-, Ball- und Paddle-Frames.
    -- Größe und Position über BORDER_* Konstanten am Dateianfang anpassen.
    local borderFrame = CreateFrame("Frame", nil, cf)
    borderFrame:SetFrameLevel(field:GetFrameLevel() + 10)
    if CFG.border_w > 0 and CFG.border_h > 0 then
        borderFrame:SetSize(CFG.border_w, CFG.border_h)
        borderFrame:SetPoint("CENTER", field, "CENTER", CFG.border_x, CFG.border_y)
    else
        borderFrame:SetAllPoints(field)
    end
    local borderTex = borderFrame:CreateTexture(nil, "OVERLAY")
    borderTex:SetAllPoints(borderFrame)
    borderTex:SetTexture(BB_ASSETS.border)
    borderTex:SetAlpha(CFG.border_alpha)
    self._borderFrame = borderFrame

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, field)
    end
    self:_RaiseHudOverField()
end

-- ── _CreateLogo ───────────────────────────────────────────────
function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        BB_ASSETS.logo,
        { w=CFG.logo_w, h=CFG.logo_h, x=CFG.logo_x, y=CFG.logo_y }
    )
end

-- ── Ball + Paddle + PU-Drop ───────────────────────────────────
function R:_CreateBallAndPaddle()
    local field = self._fieldFrame
    if not field then return end

    -- Ball: Textur-Frame
    local ball = CreateFrame("Frame", nil, field)
    ball:SetSize(CFG.ball_size, CFG.ball_size)
    local ballTex = ball:CreateTexture(nil, "ARTWORK")
    ballTex:SetAllPoints(ball)
    ball._tex = ballTex
    ball:Hide()
    self._ballFrame = ball

    -- Paddle: Textur-Frame
    local paddle = CreateFrame("Frame", nil, field)
    paddle:SetSize(CFG.paddle_w, CFG.paddle_h)
    local paddleTex = paddle:CreateTexture(nil, "ARTWORK")
    paddleTex:SetAllPoints(paddle)
    paddle._tex = paddleTex
    paddle:Hide()
    self._paddleFrame = paddle

    -- Power-Up-Drop: wird als Pool verwaltet (siehe _puDropPool)
    -- Einzel-Frame nicht mehr verwendet — Pool wird in UpdatePhysics aufgebaut
    self._puDropPool  = {}   -- { frame, _tex } Pool für mehrere gleichzeitige Drops
    self._puDropFrame = nil  -- Legacy-Referenz, nicht mehr genutzt
end

-- ── ApplyTheme ────────────────────────────────────────────────
-- Setzt Ball- und Paddle-Texturen anhand des aktiven Themes.
-- Wird beim Spielstart und aus dem SettingsPanel aufgerufen.
function R:ApplyTheme()
    local color = GetThemeColor()
    if self._ballFrame and self._ballFrame._tex then
        self._ballFrame._tex:SetTexture(THEME_PATH .. "bullet\\bullet_" .. color)
        self._ballFrame._tex:SetVertexColor(1, 1, 1)
    end
    if self._paddleFrame and self._paddleFrame._tex then
        self._paddleFrame._tex:SetTexture(THEME_PATH .. "capsule\\capsule_" .. color)
        self._paddleFrame._tex:SetVertexColor(1, 1, 1)
    end
    -- Extra-Bälle (Multiball) ebenfalls aktualisieren
    for _, bf in ipairs(self._extraBalls) do
        if bf._tex then
            bf._tex:SetTexture(THEME_PATH .. "bullet\\bullet_" .. color)
            bf._tex:SetVertexColor(1, 1, 1)
        end
    end
end

-- ── _CreateFlash ──────────────────────────────────────────────
function R:_CreateFlash()
    local field = self._fieldFrame
    local flash = CreateFrame("Frame", nil, field)
    flash:SetAllPoints(field)
    flash:SetFrameStrata("HIGH")
    local ft = flash:CreateTexture(nil, "OVERLAY")
    ft:SetAllPoints(flash)
    ft:SetTexture(CFG.white8x8)
    ft:SetVertexColor(1, 1, 1, 0)
    flash:SetScript("OnUpdate", function(self, dt)
        local a = select(4, ft:GetVertexColor())
        if a and a > 0.001 then
            ft:SetVertexColor(R._flashR, R._flashG, R._flashB, math.max(0, a - dt * 4))
        end
    end)
    self._flashFrame = flash
    self._flashTex   = ft
end

function R:_CreateFx()
    local field = self._fieldFrame
    if not field then return end
    local layer = CreateFrame("Frame", nil, field)
    layer:SetAllPoints(field)
    layer:SetFrameLevel(field:GetFrameLevel() + 6)
    self._fxLayer = layer

    local comboFS = field:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    comboFS:SetPoint("CENTER", field, "TOP", 0, -36)
    comboFS:SetTextColor(1, 0.82, 0.2)
    comboFS:SetText("")
    comboFS:Hide()
    self._comboFlashFS = comboFS

    self._trailDots = {}
    self._mainTrail = {}
    self._extraTrails = {}
    self._shards = {}
    self._pops = {}
    self._popFS = {}
    self._paddleSquashT = 0
    self._comboFlashT = 0
    self._serveHintArmed = false
    self._edgeFlashT = { left = 0, right = 0, top = 0 }

    local edgeParent = self._borderFrame or field
    local edgeFrame = CreateFrame("Frame", nil, edgeParent)
    edgeFrame:SetAllPoints(field)
    local edgeLvl = (self._borderFrame and self._borderFrame:GetFrameLevel() or field:GetFrameLevel()) + 3
    edgeFrame:SetFrameLevel(edgeLvl)
    self._edgeFrame = edgeFrame

    local thick = CFG.edge_thick or 12
    local capOver = CFG.edge_cap_overlap or 0.45
    local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local function makePart(w, h, rounded)
        local tex = edgeFrame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(CFG.white8x8)
        tex:SetBlendMode("ADD")
        tex:SetSize(w, h)
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(0)
        tex:Hide()
        if rounded and edgeFrame.CreateMaskTexture and tex.AddMaskTexture then
            local mask = edgeFrame:CreateMaskTexture()
            mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            tex:AddMaskTexture(mask)
        end
        return tex
    end
    local function packBar(thickW, thickH, barPoint, barRel, ox, oy, pad, vertical)
        local cap = thick
        local bar
        if vertical then
            bar = makePart(thick, math.max(8, CFG.field_h - pad * 2 - cap), false)
        else
            bar = makePart(math.max(8, CFG.field_w - pad * 2 - cap), thick, false)
        end
        bar:SetPoint(barPoint, field, barRel or barPoint, ox, oy)
        local capA = makePart(cap, cap, true)
        local capB = makePart(cap, cap, true)
        if vertical then
            capA:SetPoint("BOTTOM", bar, "TOP", 0, -cap * capOver)
            capB:SetPoint("TOP", bar, "BOTTOM", 0, cap * capOver)
        else
            capA:SetPoint("RIGHT", bar, "LEFT", cap * capOver, 0)
            capB:SetPoint("LEFT", bar, "RIGHT", -cap * capOver, 0)
        end
        return { bar = bar, capA = capA, capB = capB }
    end
    self._edgeTex = {
        left  = packBar(thick, nil, "LEFT",  "LEFT",
            CFG.edge_left_x or 14, CFG.edge_left_y or 0, CFG.edge_left_pad or 14, true),
        right = packBar(thick, nil, "RIGHT", "RIGHT",
            CFG.edge_right_x or -14, CFG.edge_right_y or 0, CFG.edge_right_pad or 14, true),
        top   = packBar(nil, thick, "TOP",   "TOP",
            CFG.edge_top_x or 0, CFG.edge_top_y or -14, CFG.edge_top_pad or 14, false),
    }

    local hint = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetTextColor(1, 0.85, 0.35)
    hint:Hide()
    self._serveHintFS = hint
end

function R:_ReducedMotion()
    local S = ArcadiaNexus.BB_Settings
    return S and S:Get("reducedMotion") == true
end

function R:_ClearFx()
    self._mainTrail = {}
    self._extraTrails = {}
    self._shards = {}
    self._pops = {}
    self._paddleSquashT = 0
    self._comboFlashT = 0
    self._edgeFlashT = { left = 0, right = 0, top = 0 }
    if self._comboFlashFS then
        self._comboFlashFS:SetText("")
        self._comboFlashFS:Hide()
    end
    if self._serveHintFS then self._serveHintFS:Hide() end
    if self._edgeTex then
        for _, pack in pairs(self._edgeTex) do
            for _, tex in pairs(pack) do
                if tex and tex.SetAlpha then
                    tex:SetAlpha(0)
                    tex:Hide()
                end
            end
        end
    end
    for i = 1, #(self._trailDots or {}) do
        self._trailDots[i]:Hide()
    end
    for i = 1, #(self._shardDots or {}) do
        self._shardDots[i]:Hide()
    end
    for i = 1, #(self._popFS or {}) do
        self._popFS[i]:Hide()
    end
end

function R:_AcquireTrailDot(i)
    local f = self._trailDots[i]
    if f then return f end
    local parent = self._fxLayer or self._fieldFrame
    f = CreateFrame("Frame", nil, parent)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    f._tex = tex
    self._trailDots[i] = f
    return f
end

function R:_SpawnPop(x, y, text, r, g, b)
    local Fx = ArcadiaNexus.BB_Fx
    if not Fx then return end
    self._pops[#self._pops + 1] = Fx.Popup(x, y, text, r, g, b)
end

function R:_SpawnShards(x, y, r, g, b, n)
    if self:_ReducedMotion() then return end
    local Fx = ArcadiaNexus.BB_Fx
    if not Fx then return end
    n = n or 5
    for i = 1, n do
        self._shards[#self._shards + 1] = Fx.Shard(x, y, r, g, b)
    end
end

function R:_BlockCenter(row, col)
    local cx = CFG.block_ox + (col - 0.5) * CFG.block_w
    local cy = CFG.block_top_pad + (row - 0.5) * CFG.block_h
    return cx, cy
end

function R:_TickFx(gs, dt)
    local Fx = ArcadiaNexus.BB_Fx
    local field = self._fieldFrame
    if not Fx or not field then return end
    dt = dt or 0
    local reduced = self:_ReducedMotion()

    if gs.ballDocked or not gs.ballActive then
        self._mainTrail = {}
    elseif not reduced then
        self._mainTrail = Fx.PushTrail(self._mainTrail, gs.ballX, gs.ballY, Fx.TrailMax(gs, false))
    else
        self._mainTrail = {}
    end

    self._extraTrails = self._extraTrails or {}
    if reduced then
        self._extraTrails = {}
    else
        local extraMax = Fx.TrailMax(gs, true)
        for i = 1, #(gs.balls or {}) do
            local b = gs.balls[i]
            self._extraTrails[i] = Fx.PushTrail(self._extraTrails[i] or {}, b.x, b.y, extraMax)
        end
        for i = #(gs.balls or {}) + 1, #self._extraTrails do
            self._extraTrails[i] = nil
        end
    end

    Fx.TickList(self._shards, dt)
    Fx.TickList(self._pops, dt)

    if self._comboFlashT and self._comboFlashT > 0 then
        self._comboFlashT = self._comboFlashT - dt
        if self._comboFlashT <= 0 and self._comboFlashFS then
            self._comboFlashFS:Hide()
        end
    end

    local tr, tg, tb = Fx.ThemeRGB(GetThemeColor())
    self._edgeFlashT = self._edgeFlashT or { left = 0, right = 0, top = 0 }
    local flashTtl = Fx.EDGE_FLASH_TTL or 0.14
    for side, t in pairs(self._edgeFlashT) do
        if t > 0 then
            self._edgeFlashT[side] = math.max(0, t - dt)
        end
    end
    local endgame = (gs.blocksLeft or 99) <= (Fx.ENDGAME_BLOCKS or 5) and (gs.blocksLeft or 0) > 0
    local pulse = 0
    if endgame and not reduced then
        pulse = 0.35 + 0.30 * (0.5 + 0.5 * math.sin((gs.elapsedSecs or 0) * 6))
    elseif endgame then
        pulse = 0.28
    end
    if self._edgeTex then
        for side, pack in pairs(self._edgeTex) do
            local hit = 0
            local remain = self._edgeFlashT[side] or 0
            if remain > 0 then hit = remain / flashTtl end
            local a = math.max(hit, pulse)
            for _, tex in pairs(pack) do
                if tex and tex.SetVertexColor then
                    if a > 0.02 then
                        tex:SetVertexColor(tr, tg, tb)
                        tex:SetAlpha(a)
                        tex:Show()
                    else
                        tex:SetAlpha(0)
                        tex:Hide()
                    end
                end
            end
        end
    end
    local used = 0
    local function drawTrail(trail, alphaMul, sizeMul)
        if not trail then return end
        local n = #trail
        for i = 1, n do
            used = used + 1
            local p = trail[i]
            local u = i / n
            local f = self:_AcquireTrailDot(used)
            local sz = CFG.ball_size * (0.35 + u * 0.45) * (sizeMul or 1)
            f:SetParent(self._fxLayer or field)
            f:SetFrameLevel((self._fxLayer and self._fxLayer:GetFrameLevel() or field:GetFrameLevel()) + 1)
            f:SetSize(sz, sz)
            f:ClearAllPoints()
            f:SetPoint("CENTER", field, "TOPLEFT", p.x, -p.y)
            if f._tex then
                f._tex:SetTexture(THEME_PATH .. "bullet\\bullet_" .. GetThemeColor())
                f._tex:SetVertexColor(tr, tg, tb)
                f._tex:SetAlpha(u * 0.45 * (alphaMul or 1))
            end
            f:Show()
        end
    end
    drawTrail(self._mainTrail, 1.0, 1.0)
    for i = 1, #(self._extraTrails or {}) do
        drawTrail(self._extraTrails[i], 0.55, 0.85)
    end
    for i = used + 1, #(self._trailDots or {}) do
        self._trailDots[i]:Hide()
    end

    self:_EnsureBlockPools()
    self._shardDots = self._shardDots or {}
    local su = 0
    if not reduced then
        for i = 1, #self._shards do
            local s = self._shards[i]
            su = su + 1
            local f = self._shardDots[su]
            if not f then
                f = CreateFrame("Frame", nil, self._fxLayer or field)
                local tex = f:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints(f)
                tex:SetColorTexture(1, 1, 1, 1)
                f._tex = tex
                self._shardDots[su] = f
            end
            f:SetParent(self._fxLayer or field)
            f:SetFrameLevel((self._fxLayer and self._fxLayer:GetFrameLevel() or field:GetFrameLevel()) + 2)
            f:SetSize(s.w or 5, s.h or 4)
            f:ClearAllPoints()
            f:SetPoint("CENTER", field, "TOPLEFT", s.x, -s.y)
            local a = math.max(0, (s.t or 0) / Fx.SHARD_TTL)
            if f._tex then f._tex:SetVertexColor(s.r, s.g, s.b, a) end
            f:Show()
        end
    end
    for i = su + 1, #self._shardDots do
        self._shardDots[i]:Hide()
    end

    for i = 1, #self._pops do
        local p = self._pops[i]
        local fs = self._popFS[i]
        if not fs then
            fs = (self._fxLayer or field):CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self._popFS[i] = fs
        end
        local u = (p.t or 0) / Fx.POP_TTL
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", field, "TOPLEFT", p.x, -p.y)
        fs:SetText(p.text or "")
        fs:SetTextColor(p.r, p.g, p.b, u)
        fs:Show()
    end
    for i = #self._pops + 1, #(self._popFS or {}) do
        self._popFS[i]:Hide()
    end
end

-- ── Power-Up-Status-Bar ───────────────────────────────────────
function R:_CreatePUBar()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end
    self._puSlots = {}
    local n = CFG.hud_pu_slots or 3
    for i = 1, n do
        local box, fs = UI.CreateHudStatBox(canvas, {
            w = CFG.hud_pu_w, h = CFG.hud_pu_h,
            point = "CENTER", relativePoint = "CENTER",
            x = CFG.hud_pu_x,
            y = CFG.hud_pu_y - (i - 1) * CFG.hud_pu_stack,
            alpha = CFG.hud_pu_alpha,
            font = "GameFontNormalSmall",
            shown = false,
        })
        local bg, fill
        if box then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", box, "CENTER", 0, 3)
            bg = box:CreateTexture(nil, "ARTWORK")
            bg:SetSize(CFG.hud_pu_bar_w, CFG.hud_pu_bar_h)
            bg:SetPoint("CENTER", box, "CENTER", CFG.hud_pu_bar_x, CFG.hud_pu_bar_y)
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            bg:Hide()
            fill = box:CreateTexture(nil, "ARTWORK", nil, 1)
            fill:SetHeight(CFG.hud_pu_bar_h)
            fill:SetPoint("LEFT", bg, "LEFT", 0, 0)
            fill:SetColorTexture(1, 0.85, 0, 1)
            fill:Hide()
        end
        self._puSlots[i] = { box = box, fs = fs, bg = bg, fill = fill }
    end
    if self._puSlots[1] then
        self._puBox = self._puSlots[1].box
        self._puTimerFS = self._puSlots[1].fs
        self._puTimerBg = self._puSlots[1].bg
        self._puTimerFill = self._puSlots[1].fill
    end
    self:_RaiseHudOverField()
end

function R:_UpdatePUBar(gs)
    if not gs then return end
    if self.state == "IDLE" and self:_DevOverlayOn() then
        self:_FillDevPuPreview()
        return
    end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local active = {}
    local timerFields = {
        { field="bigTimer",      key="big"      },
        { field="fastTimer",     key="fast"     },
        { field="slowTimer",     key="slow"     },
        { field="smallTimer",    key="small"    },
        { field="strengthTimer", key="strength" },
    }
    for i = 1, #timerFields do
        local entry = timerFields[i]
        local t = gs[entry.field]
        if t and t > 0 then
            active[#active + 1] = { key = entry.key, t = t, def = PU_TIMER_DEF[entry.key] }
        end
    end
    table.sort(active, function(a, b) return a.t < b.t end)
    local slots = self._puSlots or {}
    for i = 1, #slots do
        local s = slots[i]
        local pu = active[i]
        if pu and pu.def then
            local secs = math.ceil(pu.t)
            s.fs:SetText((L["pu_" .. pu.key] or pu.key) .. " " .. secs .. "s")
            s.fs:SetTextColor(pu.def.r, pu.def.g, pu.def.b)
            s.box:Show()
            if s.bg then s.bg:Show() end
            if s.fill then
                local frac = math.max(0, math.min(1, pu.t / pu.def.max))
                s.fill:SetWidth(math.max(1, CFG.hud_pu_bar_w * frac))
                s.fill:SetColorTexture(pu.def.r, pu.def.g, pu.def.b, 1)
                s.fill:Show()
            end
        else
            s.box:Hide()
            if s.fs then s.fs:SetText("") end
            if s.bg then s.bg:Hide() end
            if s.fill then s.fill:Hide() end
        end
    end
end

-- ── _CreateKeyFrame ───────────────────────────────────────────
function R:_CreateKeyFrame()
    local field = self._fieldFrame
    -- Unbenannt: benannte Frames + SetPropagateKeyboardInput im Handler tainten.
    local kf = CreateFrame("Frame", nil, field)
    kf:SetAllPoints(field)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local E = ArcadiaNexus.BB_Engine
        if not E then return end
        if key == "F8" then
            E:HandleKey("DEBUG")
        elseif key == "A" or key == "LEFT" then
            E:HandleKey("LEFT_DOWN")
        elseif key == "D" or key == "RIGHT" then
            E:HandleKey("RIGHT_DOWN")
        elseif key == "SPACE" then
            local gs = E.gameState
            if E.state == "PLAYING" and gs and gs.ballDocked then
                E:HandleKey("LAUNCH")
            else
                E:HandleKey("PAUSE")
            end
        elseif key == "P" then
            E:HandleKey("PAUSE")
        end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local E = ArcadiaNexus.BB_Engine
        if not E then return end
        if key == "A" or key == "LEFT" then
            E:HandleKey("LEFT_UP")
        elseif key == "D" or key == "RIGHT" then
            E:HandleKey("RIGHT_UP")
        end
    end)
    self._keyFrame = kf
end

-- ── _CreateControls ───────────────────────────────────────────
-- Blueprint 1:1 nach AlienDefense:
--   Divider H   @ TOPLEFT (CFG.field_ofs_x, -364)   CFG.field_w x 2
--   Dropdown    @ ctrl LEFT+16
--   Divider V   @ x=160, 352, 528 relativ zu cf
--   Start-Btn   @ ctrl LEFT+176
--   Pause-Btn   @ ctrl LEFT+352  (nur PLAYING)
function R:_CreateControls()
    local UI = ArcadiaNexus.UI
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf
    self._controlsY = bar.y
    local L  = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")

    -- Dummy-Container (für _diffContainer-Checks)
    local ctrl = CreateFrame("Frame", nil, cf)
    ctrl:SetSize(1, 1)
    ctrl:SetPoint("BOTTOM", cf, "BOTTOM", 0, bar.y.button)
    self._diffContainer = ctrl

    -- Difficulty-Dropdown (Segment 1)
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    local diffOptions = {
        { key = "easy",   label = L["diff_easy"]   or "Einfach" },
        { key = "normal", label = L["diff_normal"] or "Normal"  },
        { key = "hard",   label = L["diff_hard"]   or "Schwer"  },
    }
    local dd = UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, CFG.dd_w, "",
        diffOptions,
        function()
            local S = ArcadiaNexus.BB_Settings
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            local S = ArcadiaNexus.BB_Settings
            if S then S:Set("difficulty", key) end
            self._lastDiff = key
        end
    )
    self._diffDropdown = dd

    -- Start (IDLE) / Beenden (Menü + Spiel)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._startBtn = startBtn

    local exitBtn = UI.CreateArcadiaButton(cf, L["btn_exit"] or "Beenden", CFG.btn_w, CFG.btn_h)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    exitBtn:SetScript("OnClick", function()
        if R.state == "MENU" then
            R:EnterIdleState()
            return
        end
        local E = ArcadiaNexus.BB_Engine
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

    -- Pause-Button
    local pauseBtn = UI.CreateArcadiaButton(cf, L["btn_pause"] or "Pause", CFG.btn_w, CFG.btn_h)
    pauseBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    pauseBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BB_Engine
        if not E then return end
        if E.state == "PLAYING" then
            E:Pause()
        elseif E.state == "PAUSED" then
            E:Resume()
        end
    end)
    pauseBtn:Hide()
    self._pauseBtn = pauseBtn
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local S  = ArcadiaNexus.BB_Settings
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
            return string.format(loc.slot_info or "Level %d · %s", save.level or 1, score)
        end,
        isPaused      = function() return true end,
        onNewGame     = function(slot)
            local E = ArcadiaNexus.BB_Engine
            if E then E:StartGame({ slot = slot, mode = "new" }) end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.BB_Engine
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

-- ── _CreatePauseOverlay ───────────────────────────────────────
function R:_CreatePauseOverlay()
    local field = self._fieldFrame
    local L     = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local ovl = CreateFrame("Frame", nil, field, "BackdropTemplate")
    ovl:SetAllPoints(field)
    ovl:SetFrameStrata("DIALOG")
    ovl:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileEdge=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    ovl:SetBackdropColor(0, 0, 0, 0.70)
    ovl:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local fs = ovl:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER", ovl, "CENTER", 0, 0)
    fs:SetText("|cffffd700" .. (L["state_paused"] or "Pause") .. "|r")
    ovl:Hide()
    self._pauseOverlay = ovl
end

function R:_CreateDevOverlay()
    local field = self._fieldFrame
    if not field then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local Logic = ArcadiaNexus.BB_Logic
    local types = (Logic and Logic.PU_TYPES) or {
        "lives", "score250", "score500", "big", "bullet", "fast", "slow", "small", "strength",
    }

    local panel = CreateFrame("Frame", nil, field, "BackdropTemplate")
    panel:SetSize(96, 22 + (#types * 18) + 8)
    panel:SetPoint("TOPRIGHT", field, "TOPRIGHT", -6, -8)
    panel:SetFrameStrata("DIALOG")
    local pauseLvl = self._pauseOverlay and self._pauseOverlay:GetFrameLevel() or field:GetFrameLevel()
    panel:SetFrameLevel(pauseLvl + 5)
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.02, 0.02, 0.04, 0.82)
    panel:SetBackdropBorderColor(0.85, 0.7, 0.2, 0.9)
    panel:EnableMouse(true)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", panel, "TOP", 0, -5)
    title:SetTextColor(1, 0.82, 0)
    title:SetText(L["dev_pu_title"] or "F8  PUs")

    local function makeBtn(puType, index)
        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(88, 16)
        btn:SetPoint("TOP", panel, "TOP", 0, -20 - (index - 1) * 18)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(0.9, 0.9, 0.85)
        fs:SetText(L["dev_pu_" .. puType] or puType)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
        btn:SetScript("OnClick", function()
            local E = ArcadiaNexus.BB_Engine
            if E and E.DevDropPowerUp then E:DevDropPowerUp(puType) end
        end)
        btn:SetScript("OnEnter", function() fs:SetTextColor(1, 0.95, 0.4) end)
        btn:SetScript("OnLeave", function() fs:SetTextColor(0.9, 0.9, 0.85) end)
        return btn
    end

    for i = 1, #types do
        makeBtn(types[i], i)
    end
    self._devOverlay = panel
end

-- ══════════════════════════════════════════════════════════════
--  ZUSTANDSÜBERGÄNGE
-- ══════════════════════════════════════════════════════════════

function R:EnterIdleState()
    self.state = "IDLE"

    self:_ClearBlocks()
    self:_ClearExtraBalls()
    if self._ballFrame   then self._ballFrame:Hide()   end
    if self._paddleFrame then self._paddleFrame:Hide() end
    for _, pf in ipairs(self._puDropPool or {}) do pf:Hide() end
    self:_ClearFx()

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._logoTex      then self._logoTex:Show()      end
    if self._diffContainer then self._diffContainer:Show() end
    if self._puBar        then self._puBar:SetText("")   end
    self:_HidePuSlots()
    if self._slotMenu     then self._slotMenu:Hide()     end

    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
        self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
        self._startBtn:Show()
    end
    if self._exitBtn then self._exitBtn:Hide() end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._resumeBtn then self._resumeBtn:Hide() end

    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._diffDropdown then self._diffDropdown:SetEnabled(true) end

    -- HUD leeren
    self:_SetHudShown(false)
    if self._scoreFS   then self._scoreFS:SetText("")   end
    if self._levelFS   then self._levelFS:SetText("")   end
    if self._livesFS   then self._livesFS:SetText("")   end
    if self._timeFS    then self._timeFS:SetText("")    end
    if self._endlessFS then self._endlessFS:SetText("") end
    self:RefreshDevOverlay()
end

function R:OnGameStarted(gs)
    self.state = "PLAYING"
    self._lastDiff = gs.difficulty

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._logoTex      then self._logoTex:Hide()      end
    if self._slotMenu     then self._slotMenu:Hide()     end
    if self._diffContainer then self._diffContainer:Show() end
    if self._resumeBtn    then self._resumeBtn:Hide()    end

    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._pauseBtn  then self._pauseBtn:Show()  end
    if self._keyFrame  then self._keyFrame:EnableKeyboard(true) end
    if self._diffDropdown then self._diffDropdown:SetEnabled(false) end

    if self._ballFrame   then self._ballFrame:Show()   end
    if self._paddleFrame then self._paddleFrame:Show() end
    self:_SetHudShown(true)

    -- Theme auflösen und anwenden (random = neues Würfeln pro Spiel)
    ResolveTheme()
    self:ApplyTheme()

    self:_BuildBlocks(gs)
    self._serveHintArmed = true
    self:UpdateHUD(gs)
    self:UpdatePhysics(gs)
    self:RefreshDevOverlay()
end

function R:OnLevelAdvanced(gs)
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    self:_ClearExtraBalls()
    -- KeyFrame reaktivieren — wurde in ShowLevelWin deaktiviert
    if self._keyFrame then self._keyFrame:EnableKeyboard(true) end
    self:_BuildBlocks(gs)
    self:UpdateHUD(gs)
    self:UpdatePhysics(gs)
end

-- ══════════════════════════════════════════════════════════════
--  BLÖCKE
-- ══════════════════════════════════════════════════════════════

function R:_EnsureBlockPools()
    if not self._blockPool then self._blockPool = CreateBlockPool() end
    if not self._extraBallPool then self._extraBallPool = CreateExtraBallPool() end
end

function R:_BuildBlocks(gs)
    SyncPlayfieldLayout()
    self:_ClearBlocks()
    self:_EnsureBlockPools()
    local field = self._fieldFrame
    if not field then return end
    self._blockFrames = {}
    for row = 1, (gs.levelRows or 16) do
        self._blockFrames[row] = {}
        if gs.grid[row] then
            for col = 1, CFG.field_cols do
                local typ = gs.grid[row][col]
                if typ and typ > 0 then
                    local bf = self:_MakeBlockFrame(field, row, col, typ)
                    self._blockFrames[row][col] = bf
                end
            end
        end
    end
end

function R:_MakeBlockFrame(parent, row, col, typ)
    self:_EnsureBlockPools()
    local bx = CFG.block_ox + (col-1) * CFG.block_w
    local by = -(CFG.block_top_pad + (row-1) * CFG.block_h)
    local f = self._blockPool:Acquire({})
    f:SetParent(parent)
    -- Gleicher impliziter Child-Offset wie der ursprüngliche CreateFrame-am-Field-Pfad
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    f:SetSize(CFG.block_w - 1, CFG.block_h - 1)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", bx, by)
    f._row = row
    f._col = col
    f._blockType = typ
    f._colorIdx = ((row - 1) % #BLOCK_TILES) + 1
    self:_ApplyBlockStyle(f, typ)
    return f
end

function R:_ApplyBlockStyle(f, typ)
    if typ == 0 then f:Hide(); return end
    f:Show()
    local tex = f._tex
    if not tex then return end

    local colorName = BLOCK_TILES[f._colorIdx or 1] or "blue"

    if typ == 1 then
        -- Normal: farbige Textur
        tex:SetTexture(BLOCK_PATH .. colorName)
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(1)
    elseif typ == 2 then
        -- Gepanzert (noch nicht angeschlagen): normale Textur, leicht aufgehellt
        tex:SetTexture(BLOCK_PATH .. colorName)
        tex:SetVertexColor(1.15, 1.15, 1.15)
        tex:SetAlpha(1)
    elseif typ == 5 then
        -- Angeschlagen (nach 1. Treffer): _broken Textur
        tex:SetTexture(BLOCK_PATH .. colorName .. "_broken")
        tex:SetVertexColor(1, 1, 1)
        tex:SetAlpha(1)
    elseif typ == 3 then
        -- Unzerstörbar: grey Textur, abgedunkelt
        tex:SetTexture(BLOCK_PATH .. "grey")
        tex:SetVertexColor(0.5, 0.5, 0.5)
        tex:SetAlpha(1)
    elseif typ == 4 then
        -- Power-Up-Block: yellow Textur, goldener Schimmer
        tex:SetTexture(BLOCK_PATH .. "yellow")
        tex:SetVertexColor(1.0, 0.85, 0.2)
        tex:SetAlpha(1)
    end
end

function R:_ClearBlocks()
    if self._blockPool then self._blockPool:ReleaseAll() end
    self._blockFrames = {}
end

function R:_ClearExtraBalls()
    if self._extraBallPool then self._extraBallPool:ReleaseAll() end
    self._extraBalls = {}
end

-- ══════════════════════════════════════════════════════════════
--  PHYSICS UPDATE
-- ══════════════════════════════════════════════════════════════

function R:UpdatePhysics(gs, dt)
    if not gs or not self._fieldFrame then return end
    local field = self._fieldFrame
    local L     = ArcadiaNexus.BB_Logic

    -- Hauptball
    if self._ballFrame then
        if gs.ballActive then
            self._ballFrame:ClearAllPoints()
            self._ballFrame:SetPoint("CENTER", field, "TOPLEFT", gs.ballX, -gs.ballY)
            self._ballFrame:Show()
        else
            self._ballFrame:Hide()
        end
    end

    -- Paddle
    if self._paddleFrame then
        local squash = 0
        if self._paddleSquashT and self._paddleSquashT > 0 then
            local Fx = ArcadiaNexus.BB_Fx
            local maxT = (Fx and Fx.PADDLE_SQUASH) or 0.12
            squash = 0.22 * (self._paddleSquashT / maxT)
            self._paddleSquashT = math.max(0, self._paddleSquashT - (dt or 0))
        end
        local ph = CFG.paddle_h * (1 - squash)
        self._paddleFrame:SetSize(gs.paddleW or CFG.paddle_w, ph)
        local py = L and L.PADDLE_Y or 345
        self._paddleFrame:ClearAllPoints()
        self._paddleFrame:SetPoint("TOPLEFT", field, "TOPLEFT", gs.paddleX, -py)
        local pt = self._paddleFrame._tex
        if pt then
            if gs.strengthTimer and gs.strengthTimer > 0 then
                pt:SetVertexColor(1.00, 0.85, 0.20)
            elseif gs.fastTimer and gs.fastTimer > 0 then
                pt:SetVertexColor(1.00, 0.55, 0.18)
            elseif gs.bigTimer and gs.bigTimer > 0 then
                pt:SetVertexColor(0.45, 0.85, 1.00)
            else
                pt:SetVertexColor(1, 1, 1)
            end
        end
        if self._serveHintFS then
            if gs.ballDocked and self._serveHintArmed then
                local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
                self._serveHintFS:SetText(L["hint_serve"] or "Leertaste")
                self._serveHintFS:ClearAllPoints()
                self._serveHintFS:SetPoint("BOTTOM", self._paddleFrame, "TOP", 0, 15)
                self._serveHintFS:Show()
            else
                self._serveHintFS:Hide()
            end
        end
    elseif self._serveHintFS then
        self._serveHintFS:Hide()
    end

    -- Extra-Bälle (Multiball)
    self:_EnsureBlockPools()
    while #self._extraBalls > #gs.balls do
        local bf = table.remove(self._extraBalls)
        if bf then self._extraBallPool:Release(bf) end
    end
    while #self._extraBalls < #gs.balls do
        local bf = self._extraBallPool:Acquire({})
        bf:SetParent(field)
        -- Gleicher Offset wie Hauptball/Paddle (CreateFrame-Kinder von _fieldFrame)
        bf:SetFrameLevel(field:GetFrameLevel() + 1)
        bf:SetSize(CFG.ball_size, CFG.ball_size)
        if bf._tex then
            bf._tex:SetTexture(THEME_PATH .. "bullet\\bullet_" .. GetThemeColor())
            bf._tex:SetTexCoord(0, 1, 0, 1)
            bf._tex:SetVertexColor(1, 1, 1)
            bf._tex:SetAlpha(1)
        end
        bf:Show()
        self._extraBalls[#self._extraBalls+1] = bf
    end
    for i, ball in ipairs(gs.balls) do
        local bf = self._extraBalls[i]
        if bf then
            bf:ClearAllPoints()
            bf:SetPoint("CENTER", field, "TOPLEFT", ball.x, -ball.y)
            bf:Show()
        end
    end

    -- Fallende Power-Up-Drops (mehrere gleichzeitig möglich)
    -- Pool bei Bedarf erweitern
    local drops = gs.droppedPUs or {}
    while #self._puDropPool < #drops do
            local pf = CreateFrame("Frame", nil, field)
        pf:SetSize(CFG.pu_drop_w, CFG.pu_drop_h)
        pf:SetFrameLevel(field:GetFrameLevel() + 12)
        local pt = pf:CreateTexture(nil, "ARTWORK")
        pt:SetAllPoints(pf)
        pf._tex = pt
        pf:Hide()
        self._puDropPool[#self._puDropPool+1] = pf
    end
    for i, pf in ipairs(self._puDropPool) do
        if i <= #drops then
            local pu = drops[i]
            local path = GetPUTexPath(pu.type)
            if path and pf._tex then pf._tex:SetTexture(path) end
            pf:SetFrameLevel(field:GetFrameLevel() + 12)
            pf:ClearAllPoints()
            pf:SetPoint("CENTER", field, "TOPLEFT",
                pu.x + CFG.pu_drop_ofs_x, -(pu.y) + CFG.pu_drop_ofs_y)
            pf:Show()
        else
            pf:Hide()
        end
    end

    self:_UpdatePUBar(gs)
    self:_TickFx(gs, dt)
end

-- ══════════════════════════════════════════════════════════════
--  HUD UPDATE
-- ══════════════════════════════════════════════════════════════

function R:UpdateHUD(gs)
    if not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")

    if self._scoreFS then
        local comboTxt = ""
        if (gs.comboCount or 0) >= 2 then
            comboTxt = "  |cffffd200x" .. tostring(gs.comboCount) .. "|r"
        end
        self._scoreFS:SetText(
            (L["lbl_level"] or "Level") .. ": " .. tostring(gs.level) ..
            "   " ..
            (L["lbl_score"] or "Punkte") .. ": " .. tostring(gs.score) ..
            comboTxt)
    end

    if self._endlessFS then
        if gs.endlessMode then
            self._endlessFS:SetText("|cff999999(" .. (L["lbl_endless"] or "Endlos") .. ")|r")
        else
            self._endlessFS:SetText("")
        end
    end

    if self._livesFS then
        local hearts = ""
        for i = 1, gs.lives do
            hearts = hearts .. "|T" .. HEART_PATH .. ":14:14|t"
        end
        if gs.lives == 0 then hearts = "|cffff44440|r" end
        self._livesFS:SetText(hearts)
    end

    if self._timeFS then
        self._timeFS:SetText(
            (L["lbl_time"] or "Zeit") .. ": " ..
            ArcadiaNexus.Format.SecondsMMSS(gs.elapsedSecs or 0))
    end
end

-- ══════════════════════════════════════════════════════════════
--  BLOCK-EVENTS
-- ══════════════════════════════════════════════════════════════

function R:OnBlockBroken(row, col, blockType, gs, points)
    local bf = self._blockFrames[row] and self._blockFrames[row][col]
    local tile = BLOCK_TILES[(bf and bf._colorIdx) or 1] or "blue"
    if bf then
        if self._blockPool then self._blockPool:Release(bf) end
        self._blockFrames[row][col] = nil
    end
    local cx, cy = self:_BlockCenter(row, col)
    local Fx = ArcadiaNexus.BB_Fx
    local r, g, b = 1, 0.85, 0.3
    if Fx then r, g, b = Fx.TileRGB(tile) end
    self:_SpawnShards(cx, cy, r, g, b, 6)
    if points and points > 0 then
        self:_SpawnPop(cx, cy, "+" .. tostring(points), 1, 0.92, 0.45)
    end
    local combo = gs and gs.comboCount or 0
    if combo >= 3 then
        self:_SpawnPop(cx, cy - 14, "x" .. tostring(combo), 1, 0.75, 0.2)
    end
    if combo == 5 or combo == 10 or combo == 15 or combo == 20 then
        local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
        if self._comboFlashFS then
            self._comboFlashFS:SetText((L["lbl_combo"] or "Combo") .. " x" .. tostring(combo))
            self._comboFlashFS:Show()
            self._comboFlashT = (Fx and Fx.COMBO_FLASH_TTL) or 0.85
        end
    end
end

function R:OnBlockDamaged(row, col, newTyp, gs)
    local bf = self._blockFrames[row] and self._blockFrames[row][col]
    if not bf then return end
    self:_ApplyBlockStyle(bf, newTyp)
    local cx, cy = self:_BlockCenter(row, col)
    local tile = BLOCK_TILES[bf._colorIdx or 1] or "grey"
    local Fx = ArcadiaNexus.BB_Fx
    local r, g, b = 0.8, 0.8, 0.8
    if Fx then r, g, b = Fx.TileRGB(tile) end
    self:_SpawnShards(cx, cy, r, g, b, 2)
end

function R:OnPaddleHit(gs)
    local Fx = ArcadiaNexus.BB_Fx
    self._paddleSquashT = (Fx and Fx.PADDLE_SQUASH) or 0.12
end

function R:OnBallLaunched(gs)
    if not gs then return end
    self._serveHintArmed = false
    if self._serveHintFS then self._serveHintFS:Hide() end
    local Fx = ArcadiaNexus.BB_Fx
    local r, g, b = 0.4, 0.7, 1
    if Fx then r, g, b = Fx.ThemeRGB(GetThemeColor()) end
    self:_SpawnShards(gs.ballX, gs.ballY, r, g, b, 7)
    self._mainTrail = {}
end

function R:OnWallHit(side, gs)
    if not side then return end
    self._edgeFlashT = self._edgeFlashT or { left = 0, right = 0, top = 0 }
    local Fx = ArcadiaNexus.BB_Fx
    self._edgeFlashT[side] = (Fx and Fx.EDGE_FLASH_TTL) or 0.14
end

function R:OnLevelClear(gs)
    local Fx = ArcadiaNexus.BB_Fx
    local r, g, b = 1, 0.85, 0.3
    if Fx then r, g, b = Fx.ThemeRGB(GetThemeColor()) end
    local cx = CFG.field_w / 2
    local cy = CFG.field_h / 2
    local n = (Fx and Fx.CLEAR_BURST) or 16
    self:_SpawnShards(cx, cy, r, g, b, n)
    self._edgeFlashT = { left = 0.35, right = 0.35, top = 0.35 }
    local S = ArcadiaNexus.BB_Settings
    if S and S:Get("screenFlash") then
        self:FlashScreen(r, g, b, 0.35)
    end
end

-- ══════════════════════════════════════════════════════════════
--  POWER-UP-EVENTS
-- ══════════════════════════════════════════════════════════════

function R:OnPowerUpDropped(puType, x, y, gs)   end
function R:OnPowerUpCollected(puType, gs)
    if not gs or not puType then return end
    local Fx = ArcadiaNexus.BB_Fx
    local r, g, b = 1, 0.85, 0.3
    if Fx and Fx.PURGB then r, g, b = Fx.PURGB(puType) end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local label = (L and L["pu_" .. puType]) or puType
    local px = (gs.paddleX or 0) + (gs.paddleW or 80) / 2
    local Logic = ArcadiaNexus.BB_Logic
    local py = (Logic and Logic.PADDLE_Y or 425) - 18
    self:_SpawnShards(px, py, r, g, b, 8)
    self:_SpawnPop(px, py, label, r, g, b)
end
function R:OnPowerUpExpired(puType, gs)           end

-- ══════════════════════════════════════════════════════════════
--  OVERLAY-EVENTS
-- ══════════════════════════════════════════════════════════════

function R:ShowPause()
    if self._pauseOverlay then self._pauseOverlay:Show() end
    if self._keyFrame     then self._keyFrame:EnableKeyboard(true) end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    if self._pauseBtn then self._pauseBtn:SetLabel(L["btn_continue"] or "Weiter") end
end

function R:HidePause()
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    if self._pauseBtn then self._pauseBtn:SetLabel(L["btn_pause"] or "Pause") end
end

function R:ShowGameOver(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local UI = ArcadiaNexus.UI
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._diffDropdown then self._diffDropdown:SetEnabled(true) end
    if self._pauseBtn  then self._pauseBtn:Hide()  end
    if self._resumeBtn then self._resumeBtn:Hide() end
    if self._startBtn  then self._startBtn:Hide()  end
    if self._exitBtn   then self._exitBtn:Show()   end
    UI.ShowArcadeResult(field, {
        title      = L["state_gameover"] or "Spiel vorbei!",
        titleColor = { 1, 0.27, 0.27 },
        score      = gs.score,
        gameId     = "BLOCKBREAKER",
        difficulty = gs.difficulty or self._lastDiff,
        result     = "LOSS",
        lines      = { (L["lbl_level"] or "Level") .. ": " .. tostring(gs.level) },
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.BB_Engine
            if E then E:StartGame({ mode = "new", difficulty = R._lastDiff }) end
        end,
        onExit = function()
            local E = ArcadiaNexus.BB_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:ShowLevelWin(gs)
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")
    local UI = ArcadiaNexus.UI
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._pauseBtn then self._pauseBtn:Hide() end
    UI.ShowArcadeResult(field, {
        title      = L["state_win"] or "Level geschafft!",
        titleColor = { 0, 1, 0 },
        score      = gs.score,
        gameId     = "BLOCKBREAKER",
        difficulty = gs.difficulty or self._lastDiff,
        result     = "WIN",
        lines      = { (L["lbl_level"] or "Level") .. ": " .. tostring(gs.level) },
        L          = L,
        buttons    = {
            {
                label = L["btn_next_level"] or "Nächstes Level",
                onClick = function()
                    local E = ArcadiaNexus.BB_Engine
                    if E then E:ContinueToNextLevel() end
                end,
            },
            {
                label = L["btn_replay_level"] or "Wiederholen",
                onClick = function()
                    local E = ArcadiaNexus.BB_Engine
                    if E then E:RetryLevel() end
                end,
            },
            {
                label = L["btn_exit"] or "Beenden",
                onClick = function()
                    local E = ArcadiaNexus.BB_Engine
                    if E then E:StopGame() end
                end,
            },
        },
    })
end

function R:FlashScreen(r, g, b, alpha)
    if not self._flashTex then return end
    self._flashR = r or 1
    self._flashG = g or 1
    self._flashB = b or 1
    self._flashTex:SetVertexColor(r or 1, g or 1, b or 1, alpha or 0.6)
end
