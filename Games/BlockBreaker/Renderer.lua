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
    hud_pu_y       =  199,    -- hud_y - 16
    hud_pu_bar_w   =  100,
    hud_pu_bar_h   =    4,

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
R._puDropFrame  = nil
R._flashFrame   = nil
R._puBar        = nil

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
    self:_CreatePUBar()
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

    local puTimerFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    puTimerFS:SetPoint("CENTER", canvas, "CENTER", CFG.hud_l_x, CFG.hud_pu_y)
    puTimerFS:SetText("")
    self._puTimerFS = puTimerFS

    local puBg = canvas:CreateTexture(nil, "ARTWORK")
    puBg:SetSize(CFG.hud_pu_bar_w, CFG.hud_pu_bar_h)
    puBg:SetPoint("CENTER", canvas, "CENTER", CFG.hud_l_x, CFG.hud_pu_y - 10)
    puBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    self._puTimerBg = puBg

    local puFill = canvas:CreateTexture(nil, "ARTWORK", nil, 1)
    puFill:SetHeight(CFG.hud_pu_bar_h)
    puFill:SetPoint("LEFT", puBg, "LEFT", 0, 0)
    puFill:SetColorTexture(1, 0.85, 0, 1)
    self._puTimerFill = puFill
end

function R:_SetHudShown(shown)
    local boxes = { self._timeBox, self._scoreBox, self._livesBox, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
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

-- ── Power-Up-Status-Bar ───────────────────────────────────────
function R:_CreatePUBar()
    local cf = self._contentFrame
    if not cf then return end
    local bar = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar:SetPoint("TOPLEFT", cf, "TOPLEFT", CFG.field_ofs_x, CFG.field_ofs_y - 4)
    bar:SetTextColor(1, 0.85, 0)
    bar:SetText("")
    self._puBar = bar
end

function R:_UpdatePUBar(gs)
    if not self._puBar or not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")

    -- Bestehende Text-Bar (über Spielfeld)
    local parts = {}
    local function addTimer(field, key)
        if gs[field] and gs[field] > 0 then
            parts[#parts+1] = (L["pu_"..key] or key) .. string.format(" %.0fs", gs[field])
        end
    end
    addTimer("bigTimer",      "big")
    addTimer("fastTimer",     "fast")
    addTimer("slowTimer",     "slow")
    addTimer("smallTimer",    "small")
    addTimer("strengthTimer", "strength")
    self._puBar:SetText(table.concat(parts, "  "))

    -- PU-Timer-Anzeige unter Zeit-Label
    -- Aktives PU mit der kürzesten verbleibenden Zeit anzeigen (dringendster)
    local activePU, activeTime, activeDef = nil, math.huge, nil
    local timerFields = {
        { field="bigTimer",      key="big"      },
        { field="fastTimer",     key="fast"     },
        { field="slowTimer",     key="slow"     },
        { field="smallTimer",    key="small"    },
        { field="strengthTimer", key="strength" },
    }
    for _, entry in ipairs(timerFields) do
        local t = gs[entry.field]
        if t and t > 0 and t < activeTime then
            activeTime  = t
            activePU    = entry.key
            activeDef   = PU_TIMER_DEF[entry.key]
        end
    end

    if activePU and activeDef and self._puTimerFS then
        local label = (L["pu_"..activePU] or activePU)
        local secs  = math.ceil(activeTime)
        self._puTimerFS:SetText(label .. " " .. secs .. "s")
        self._puTimerFS:SetTextColor(activeDef.r, activeDef.g, activeDef.b)

        local frac = math.max(0, math.min(1, activeTime / activeDef.max))
        if self._puTimerBg  then self._puTimerBg:Show()  end
        if self._puTimerFill then
            self._puTimerFill:SetWidth(math.max(1, CFG.hud_pu_bar_w * frac))
            self._puTimerFill:SetColorTexture(activeDef.r, activeDef.g, activeDef.b, 1)
            self._puTimerFill:Show()
        end
    else
        -- Kein aktives PU: alles ausblenden
        if self._puTimerFS   then self._puTimerFS:SetText("") end
        if self._puTimerBg   then self._puTimerBg:Hide()      end
        if self._puTimerFill then self._puTimerFill:Hide()     end
    end
end

-- ── _CreateKeyFrame ───────────────────────────────────────────
function R:_CreateKeyFrame()
    local field = self._fieldFrame
    local kf = CreateFrame("Frame", "ArcadiaNexus_BB_KeyFrame", field)
    kf:SetAllPoints(field)
    kf:SetPropagateKeyboardInput(false)
    kf:EnableKeyboard(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local E = ArcadiaNexus.BB_Engine
        if not E then return end
        if key == "A" or key == "LEFT"  then E:HandleKey("LEFT_DOWN")  end
        if key == "D" or key == "RIGHT" then E:HandleKey("RIGHT_DOWN") end
        if key == "SPACE"               then E:HandleKey("PAUSE")      end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local E = ArcadiaNexus.BB_Engine
        if not E then return end
        if key == "A" or key == "LEFT"  then E:HandleKey("LEFT_UP")  end
        if key == "D" or key == "RIGHT" then E:HandleKey("RIGHT_UP") end
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

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._pauseOverlay then self._pauseOverlay:Hide() end
    if self._logoTex      then self._logoTex:Show()      end
    if self._diffContainer then self._diffContainer:Show() end
    if self._puBar        then self._puBar:SetText("")   end
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
    if self._puTimerFS   then self._puTimerFS:SetText("") end
    if self._puTimerBg   then self._puTimerBg:Hide()      end
    if self._puTimerFill then self._puTimerFill:Hide()     end
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
    self:UpdateHUD(gs)
    self:UpdatePhysics(gs)
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

function R:UpdatePhysics(gs)
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
        self._paddleFrame:SetSize(gs.paddleW or CFG.paddle_w, CFG.paddle_h)
        local py = L and L.PADDLE_Y or 345
        self._paddleFrame:ClearAllPoints()
        self._paddleFrame:SetPoint("TOPLEFT", field, "TOPLEFT", gs.paddleX, -py)
        -- Farbton je nach aktivem Power-Up (via SetVertexColor auf Textur)
        local pt = self._paddleFrame._tex
        if pt then
            if gs.ironTimer and gs.ironTimer > 0 then
                pt:SetVertexColor(0.50, 0.80, 1.00)
            elseif gs.enlargeTimer and gs.enlargeTimer > 0 then
                pt:SetVertexColor(0.40, 1.00, 0.40)
            else
                pt:SetVertexColor(1, 1, 1)
            end
        end
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
        pf:SetSize(96, 26)   -- 128×34 skaliert auf ~75%
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
            pf:ClearAllPoints()
            pf:SetPoint("CENTER", field, "TOPLEFT", pu.x, -pu.y)
            pf:Show()
        else
            pf:Hide()
        end
    end

    self:_UpdatePUBar(gs)
end

-- ══════════════════════════════════════════════════════════════
--  HUD UPDATE
-- ══════════════════════════════════════════════════════════════

function R:UpdateHUD(gs)
    if not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")

    if self._scoreFS then
        self._scoreFS:SetText(
            (L["lbl_level"] or "Level") .. ": " .. tostring(gs.level) ..
            "   " ..
            (L["lbl_score"] or "Punkte") .. ": " .. tostring(gs.score))
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

function R:OnBlockBroken(row, col, blockType, gs)
    local bf = self._blockFrames[row] and self._blockFrames[row][col]
    if bf then
        if self._blockPool then self._blockPool:Release(bf) end
        self._blockFrames[row][col] = nil
    end
end

function R:OnBlockDamaged(row, col, newTyp, gs)
    local bf = self._blockFrames[row] and self._blockFrames[row][col]
    if not bf then return end
    self:_ApplyBlockStyle(bf, newTyp)
end

-- ══════════════════════════════════════════════════════════════
--  POWER-UP-EVENTS
-- ══════════════════════════════════════════════════════════════

function R:OnPowerUpDropped(puType, x, y, gs)   end
function R:OnPowerUpCollected(puType, gs)         end
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
