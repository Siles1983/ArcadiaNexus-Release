-- ============================================================
--  Azeroth Jewels – Renderer.lua
--  UI, Input, Animationen, Slot-Menü, PowerUp-Leiste, Dialoge.
--  KEINE Spielregeln (Logic), KEIN Lifecycle (Engine).
--
--  Layout:
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (nur IDLE, voll sichtbar)
--    - Controls-Leiste am BOTTOM (Blueprint Match-3):
--      Dropdown Schwierigkeit + Spiel starten / Beenden + Zeitmodus-Checkbox
--    - Alle Positionen/Größen in der CFG-Tabelle justierbar
--
--  Gem-Grafik: AUSSCHLIESSLICH Custom-TGAs aus assets/gems/
--  (Phase-0-Pipeline). KEINE WoW-Icon-Fallbacks für Board-Gems.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_Renderer = {}
local R = ArcadiaNexus.AJ_Renderer

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\"

-- Gem-Texturen (Pflicht, kein Fallback – GDD §5)
local AJ_GEM_TEXTURES = {
    [1] = ASSETS .. "gems\\gem_red",
    [2] = ASSETS .. "gems\\gem_green",
    [3] = ASSETS .. "gems\\gem_blue",
    [4] = ASSETS .. "gems\\gem_yellow",
    [5] = ASSETS .. "gems\\gem_purple",
    [6] = ASSETS .. "gems\\gem_white",
    [7] = ASSETS .. "gems\\gem_cyan",
}

local AJ_OB_TEXTURES = {
    ICE    = ASSETS .. "obstacles\\ice",
    STONE  = ASSETS .. "obstacles\\stone",
    LOCKED = ASSETS .. "obstacles\\locked",
}

-- PowerUp-Leisten-Icons (UI-Elemente, keine Board-Gems)
local POWERUP_ICONS = {
    fire  = "Interface\\Icons\\Spell_Fire_SealOfFire",
    frost = "Interface\\Icons\\Spell_Frost_FrostNova",
    chain = "Interface\\Icons\\Spell_Nature_ChainLightning",
    bomb  = "Interface\\Icons\\INV_Misc_Bomb_02",
    holy  = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

-- ============================================================
-- CFG – Layout-Konstanten (händisch nachjustierbar)
-- Alle x/y-Werte sind Offsets relativ zur Panel-Mitte (CENTER),
-- sofern nicht anders kommentiert.
-- ============================================================
local CFG = {
    -- Spielfeld
    board_size    = 320,
    field_ofs_x   = 0,
    field_ofs_y   = 30,
    cell_min      = 24,

    -- Border (aj_border.tga, 512x512) – eigener Frame (FrameLevel +10),
    -- liegt als OVERLAY über dem Spielfeld. Größe/Position hier justieren.
    border_w      = 798,--795
    border_h      = 550,--550
    border_ofs_x  = 0,      -- relativ zum Spielfeld-CENTER
    border_ofs_y  = -15,

    -- Hintergrund (relativ zu _fieldFrame CENTER)
    bg_w          = 740,
    bg_h          = 500,
    bg_ofs_x      = 0,
    bg_ofs_y      = -5,
    bg_alpha      = 1.0,

    -- Logo (aj_logo.tga, 512x512) – nur im IDLE-Screen sichtbar.
    -- Offsets relativ zum Spielfeld-CENTER, alpha für Deckkraft.
    logo_w        = 312,
    logo_h        = 312,
    logo_ofs_x    = 0,
    logo_ofs_y    = -15,
    logo_alpha    = 1.00,

    -- HUD über dem Board (eigene Boxen, unabhängig)
    hud_level_w      = 140,
    hud_level_h      = 28,
    hud_level_x      = -260,
    hud_level_y      = -75,
    hud_level_alpha  = 0.75,
    hud_score_w      = 150,
    hud_score_h      = 28,
    hud_score_x      = -94,
    hud_score_y      = 210,
    hud_score_alpha  = 0.75,
    hud_moves_w      = 140,
    hud_moves_h      = 28,
    hud_moves_x      = -260,
    hud_moves_y      = -100,
    hud_moves_alpha  = 0.75,
    hud_time_w       = 140,
    hud_time_h       = 28,
    hud_time_x       = -260,
    hud_time_y       = -125,
    hud_time_alpha   = 0.75,
    hud_best_w       = 150,
    hud_best_h       = 28,
    hud_best_x       = 94,
    hud_best_y       = 210,
    hud_best_alpha   = 0.75,

    -- Ziel-Zeile (Punkte-/Sammelziel) unter dem Board
    goal_y        = -150,
    hint_ofs_y    = -30,    -- Hint-Text, relativ zu goal_y
    collect_item_w = 64,
    collect_bar_h  = 3,

    -- PowerUp-Leiste (unter der Ziel-Zeile)
    pu_bar_y      = -182,
    pu_icon       = 32,
    pu_gap        = 14,
    -- Ein Goldrahmen um Ziel-Zeile + PowerUp-Leiste (Position wie bisher)
    goal_pu_w     = 336,
    goal_pu_h     = 70,
    goal_pu_x     = 0,
    goal_pu_y     = -170,
    goal_pu_alpha = 0.75,

    -- Levelkarte (10 Kacheln, 2×5) + Goldrahmen wie HUD
    map_tile_w      = 54,
    map_tile_h      = 62,
    map_gap_x       = 8,
    map_gap_y       = 10,
    map_panel_w     = 348,
    map_panel_h     = 268,
    map_panel_alpha = 0.75,
    map_pad         = 10,
    map_header_h    = 58,

    -- Combo-Anzeige (über dem Board)
    combo_y       = 190,

    -- Controls-Widgets
    dd_w          = 120,
    chk_size      = 26,
    btn_w         = 144,
    btn_h         = 32,
}

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._fieldFrame    = nil
R._controlsFrame = nil
R._bgTex         = nil
R._borderFrame   = nil
R._borderTex     = nil
R._logoTex       = nil
R._timerCheckbox = nil
R._startBtn      = nil
R._exitBtn       = nil
R.state          = "IDLE"

R._board         = nil
R._cells         = {}
R._pool          = {}
R._cellSize      = 40
R._cols          = 0
R._rows          = 0
R._selected      = nil
R._drag          = nil
R._gsRef         = nil

R._targeting     = nil    -- PowerUp-ID im Targeting-Modus
R._highlighted   = {}     -- aktuell hervorgehobene Zellen
R._hintCells     = {}     -- Idle-Hilfe: funkelnde Match-Zellen

R._puButtons     = {}
R._slotMenu      = nil

local _fxGuard = ArcadiaNexus.TimerGuard.New()
local _animLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AJ_Renderer_AnimLoop")
local _hintLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AJ_Renderer_HintLoop")

local function StartAnimLoop(tickFn)
    _animLoop:Stop()
    _animLoop:Start(tickFn, { maxDt = 0.1 })
end

local function StopAnimLoop()
    _animLoop:Stop()
end

local function Loc()
    return ArcadiaNexus.GetLocaleTable("AZEROTHJEWELS")
end

local function Logic()
    return ArcadiaNexus.AJ_Logic
end

function R:_ReducedMotion()
    local S = ArcadiaNexus.AJ_Settings
    return S and S:Get("reducedMotion") == true
end

function R:_ImpactFxEnabled()
    if self:_ReducedMotion() then return false end
    local S = ArcadiaNexus.AJ_Settings
    return not S or S:Get("impactFx") ~= false
end

function R:_RestoreBoardPoint()
    local board = self._board
    if not board or not self._fieldFrame then return end
    board:ClearAllPoints()
    board:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
end

function R:_StopImpactFx()
    self._shakeT = 0
    self._shakeAmp = 0
    self:_RestoreBoardPoint()
    for _, fs in ipairs(self._floatPool or {}) do
        fs:Hide()
        fs._live = false
    end
    if self._impactWatch then
        self._impactWatch:SetScript("OnUpdate", nil)
    end
end

function R:_EnsureImpactWatch()
    local board = self._board
    if not board then return end
    if not self._impactWatch then
        self._impactWatch = CreateFrame("Frame", nil, board)
    else
        self._impactWatch:SetParent(board)
    end
    self._impactWatch:SetScript("OnUpdate", function(_, dt)
        R:_TickImpact(dt or 0.016)
    end)
end

function R:_TickImpact(dt)
    local active = false
    if (self._shakeT or 0) > 0 then
        active = true
        self._shakeT = self._shakeT - dt
        if self._shakeT <= 0 then
            self._shakeT = 0
            self._shakeAmp = 0
            self:_RestoreBoardPoint()
        else
            local t = self._shakeT
            local amp = (self._shakeAmp or 0) * (t / 0.16)
            local ox = math.sin(t * 62) * amp
            local oy = math.cos(t * 51) * amp * 0.55
            local board = self._board
            if board and self._fieldFrame then
                board:ClearAllPoints()
                board:SetPoint("CENTER", self._fieldFrame, "CENTER", ox, oy)
            end
        end
    end
    for _, fs in ipairs(self._floatPool or {}) do
        if fs._live then
            active = true
            fs._t = (fs._t or 0) + dt
            local u = fs._t / 0.70
            if u >= 1 then
                fs._live = false
                fs:Hide()
            else
                local rise = 28 * u
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", self._board, "TOPLEFT", fs._x, fs._y + rise)
                fs:SetAlpha(1 - u * u)
            end
        end
    end
    if not active and self._impactWatch then
        self._impactWatch:SetScript("OnUpdate", nil)
        self:_RestoreBoardPoint()
    end
end

function R:_MatchCentroid(keys)
    local n, sr, sc = 0, 0, 0
    if keys then
        for key in pairs(keys) do
            local r, c = key:match("(%d+),(%d+)")
            r, c = tonumber(r), tonumber(c)
            if r and c then
                sr, sc, n = sr + r, sc + c, n + 1
            end
        end
    end
    local cs = self._cellSize or 32
    if n == 0 then
        local bw = (self._board and self._board:GetWidth()) or 160
        return bw * 0.5, -bw * 0.5
    end
    return (sc / n - 0.5) * cs, -(sr / n - 0.5) * cs
end

function R:_SpawnFloatScore(gained, combo, keys)
    if not self._board or not gained or gained <= 0 then return end
    self._floatPool = self._floatPool or {}
    local fs
    for i = 1, #self._floatPool do
        if not self._floatPool[i]._live then
            fs = self._floatPool[i]
            break
        end
    end
    if not fs then
        if #self._floatPool >= 8 then
            fs = self._floatPool[1]
        else
            fs = self._board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            self._floatPool[#self._floatPool + 1] = fs
        end
    end
    local Format = ArcadiaNexus.Format
    local x, y = self:_MatchCentroid(keys)
    fs._live, fs._t, fs._x, fs._y = true, 0, x, y
    fs:SetParent(self._board)
    fs:SetText("+" .. (Format and Format.Score(gained) or tostring(gained)))
    if (combo or 1) >= 3 then
        fs:SetTextColor(1, 0.55, 0.15)
    else
        fs:SetTextColor(1, 0.85, 0.25)
    end
    fs:SetAlpha(1)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", self._board, "TOPLEFT", x, y)
    fs:Show()
end

function R:_ShakeBoard(amp)
    self._shakeAmp = math.max(self._shakeAmp or 0, amp or 2)
    self._shakeT = 0.16
end

function R:ShowImpactFx(gained, combo, keys)
    if not self:_ImpactFxEnabled() then return end
    if (gained or 0) > 0 then
        self:_SpawnFloatScore(gained, combo, keys)
    end
    if (combo or 1) >= 2 or (gained or 0) >= 400 then
        self:_ShakeBoard(2 + math.min(4, combo or 1))
    end
    self:_EnsureImpactWatch()
end

-- ============================================================
-- GEM-VISUAL – nur Custom-TGAs
-- ============================================================
local function ApplyGemVisual(tex, gemType)
    tex:SetTexture(nil)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    local L = Logic()
    if gemType == L.WILD then
        -- Wildcard: weißer Kristall mit goldenem Schimmer
        tex:SetTexture(AJ_GEM_TEXTURES[6])
        tex:SetVertexColor(1, 0.82, 0.25, 1)
    elseif AJ_GEM_TEXTURES[gemType] then
        tex:SetTexture(AJ_GEM_TEXTURES[gemType])
    end
end

-- ============================================================
-- CELL-FRAME / POOL
-- ============================================================
local function MakeCell(parent, size)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    f:SetBackdropColor(0.10, 0.10, 0.14, 0.35)
    f:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
    f._tex = tex

    -- Eis-Überzug
    local ice = f:CreateTexture(nil, "OVERLAY", nil, 1)
    ice:SetAllPoints(f)
    ice:SetTexture(AJ_OB_TEXTURES.ICE)
    ice:SetVertexColor(1, 1, 1, 0)
    f._ice = ice

    -- Auswahl-/Highlight-Glow
    local glow = f:CreateTexture(nil, "OVERLAY", nil, 2)
    glow:SetAllPoints(f)
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetVertexColor(1, 0.9, 0.1, 0)
    glow:SetBlendMode("ADD")
    f._glow = glow

    f:Hide()
    return f
end

local function AcquireCell(parent, size)
    local f
    if #R._pool > 0 then
        f = table.remove(R._pool)
        f:SetParent(parent)
        f:SetSize(size, size)
    else
        f = MakeCell(parent, size)
    end
    f._tex:SetVertexColor(1, 1, 1, 1)
    f._tex:SetAlpha(1)
    f._ice:SetTexture(AJ_OB_TEXTURES.ICE)
    f._ice:SetVertexColor(1, 1, 1, 0)
    f._glow:SetVertexColor(1, 0.9, 0.1, 0)
    f:SetAlpha(1)
    f:SetScale(1)
    f:SetScript("OnClick", nil)
    f:SetScript("OnMouseDown", nil)
    f:SetScript("OnMouseUp", nil)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    if f.animTick then f.animTick:SetScript("OnUpdate", nil); f.animTick = nil end
    f:Show()
    return f
end

local function ReleaseCell(f)
    f:Hide()
    local poolRoot = ArcadiaNexus.UI and ArcadiaNexus.UI.FramePool and ArcadiaNexus.UI.FramePool.GetRoot
        and ArcadiaNexus.UI.FramePool.GetRoot()
    if poolRoot then
        f:SetParent(poolRoot)
    end
    f:SetScale(1)
    f:SetAlpha(1)
    f:SetScript("OnClick", nil)
    f:SetScript("OnMouseDown", nil)
    f:SetScript("OnMouseUp", nil)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    if f._tex  then f._tex:SetTexture(nil); f._tex:SetAlpha(1); f._tex:SetVertexColor(1,1,1,1) end
    if f._ice  then f._ice:SetTexture(AJ_OB_TEXTURES.ICE); f._ice:SetVertexColor(1, 1, 1, 0) end
    if f._glow then f._glow:SetVertexColor(1, 0.9, 0.1, 0) end
    if f.animTick then f.animTick:SetScript("OnUpdate", nil); f.animTick = nil end
    table.insert(R._pool, f)
end

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    if not self.frame then return end
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorder()
    self:_CreateLogo()
    self:_CreateBoard()
    self:_CreateHUD()
    self:_CreatePowerUpBar()
    self:_CreateSlotMenu()
    self:_CreateLevelMap()
    self:_CreateControls()
    self:_CreateKeyFrame()
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AJ_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._ajContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("AZEROTHJEWELS", ArcadiaNexus.AJ_Engine, function(E)
            if E.state ~= "IDLE" then
                E:SaveAndPause()
            end
        end)
        if R.state == "MENU" or R.state == "MAP" then
            R:EnterIdleState()
        end
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local ff = CreateFrame("Frame", nil, self._canvas, "BackdropTemplate")
    ff:SetSize(CFG.board_size + 16, CFG.board_size + 16)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ff:SetBackdropColor(0.07, 0.07, 0.10, 0)
    ff:SetBackdropBorderColor(0.55, 0.45, 0.18, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(ASSETS .. "background\\background_aj")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- Border-Frame: eigener Frame eine Ebene über _fieldFrame (Muster GoblinBlast).
-- Da OVERLAY-Texturen am FrameLevel des Frames hängen, braucht der Border
-- einen eigenen Frame mit explizit höherem FrameLevel.
function R:_CreateBorder()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(ASSETS .. "border\\aj_border")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, ff)
    end
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ASSETS .. "logo\\aj_logo",
        {
            w     = CFG.logo_w,
            h     = CFG.logo_h,
            x     = CFG.logo_ofs_x,
            y     = CFG.logo_ofs_y,
            alpha = CFG.logo_alpha,
        }
    )
end

function R:_CreateBoard()
    local board = CreateFrame("Frame", nil, self._fieldFrame)
    board:SetSize(CFG.board_size, CFG.board_size)
    board:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    self._board = board
end

-- ESC bricht Targeting ab (nur im Targeting-Modus aktiv)
function R:_CreateKeyFrame()
    local kf = CreateFrame("Frame", nil, self._canvas)
    kf:SetAllPoints(self._canvas)
    kf:EnableKeyboard(false)
    kf:SetScript("OnKeyDown", function(frame, key)
        if key == "ESCAPE" and R._targeting then
            frame:SetPropagateKeyboardInput(false)
            local E = ArcadiaNexus.AJ_Engine
            if E then E:CancelTargeting() end
        else
            frame:SetPropagateKeyboardInput(true)
        end
    end)
    self._keyFrame = kf
end

-- ============================================================
-- HUD
-- ============================================================
local function MakeHudPair(f, x, label)
    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER", f, "CENTER", x, CFG.hud_lbl_y)
    lbl:SetTextColor(0.75, 0.70, 0.55)
    lbl:SetText("|cffffd700" .. label .. "|r")
    local val = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    val:SetPoint("CENTER", f, "CENTER", x, CFG.hud_val_y)
    val:SetText("--")
    return lbl, val
end

function R:_CreateHUD()
    local f = self._canvas
    local L = Loc()
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._levelBox, self._levelFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_level_w, h = CFG.hud_level_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_level_x, y = CFG.hud_level_y,
        alpha = CFG.hud_level_alpha,
        text = (L["lbl_level"] or "Level") .. ": --",
        shown = false,
    })
    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Punkte") .. ": --",
        shown = false,
    })
    self._movesBox, self._movesFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        text = (L["lbl_moves"] or "Züge") .. ": --",
        shown = false,
    })
    self._timeBox, self._timeFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        text = (L["lbl_time"] or "Zeit") .. ": --",
        shown = false,
    })
    self._bestBox, self._subFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["lbl_highscore"] or "Highscore") .. ": --",
        shown = false,
    })
    self._timeLbl = nil
    self._levelLbl, self._scoreLbl, self._movesLbl = nil, nil, nil

    -- Ziel-Zeile (unter dem Board)
    local goalFrame = CreateFrame("Frame", nil, f)
    goalFrame:SetSize(CFG.board_size, 28)
    goalFrame:SetPoint("CENTER", f, "CENTER", 0, CFG.goal_y)
    self._goalFrame = goalFrame

    local goalFS = goalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goalFS:SetPoint("CENTER", goalFrame, "CENTER", 0, 0)
    goalFS:SetTextColor(0.9, 0.85, 0.6)
    self._goalFS = goalFS

    -- Collect-Ziel-Items (Gem-Icon + Zähler + Balken)
    self._goalItems = {}
    for i = 1, 7 do
        local item = CreateFrame("Frame", nil, goalFrame)
        item:SetSize(CFG.collect_item_w or 64, 26)
        local tex = item:CreateTexture(nil, "ARTWORK")
        tex:SetSize(18, 18)
        tex:SetPoint("LEFT", item, "LEFT", 0, 2)
        local fs = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", tex, "RIGHT", 3, 2)
        local barBg = item:CreateTexture(nil, "BACKGROUND")
        barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        barBg:SetVertexColor(0.12, 0.12, 0.14, 0.9)
        barBg:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 1)
        barBg:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 1)
        barBg:SetHeight(CFG.collect_bar_h or 3)
        local bar = item:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetVertexColor(0.85, 0.70, 0.22, 1)
        bar:SetPoint("BOTTOMLEFT", barBg, "BOTTOMLEFT", 0, 0)
        bar:SetHeight(CFG.collect_bar_h or 3)
        bar:SetWidth(1)
        local flash = item:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints(item)
        flash:SetTexture("Interface\\Buttons\\WHITE8X8")
        flash:SetVertexColor(1, 0.92, 0.35, 0)
        item._tex, item._fs, item._bar, item._barBg, item._flash = tex, fs, bar, barBg, flash
        item:Hide()
        self._goalItems[i] = item
    end

    -- Combo
    local comboFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    comboFS:SetPoint("CENTER", f, "CENTER", 0, CFG.combo_y)
    comboFS:SetTextColor(1, 0.85, 0)
    comboFS:Hide()
    self._comboFS = comboFS

    -- Hint (IDLE + Spielhinweise)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", 0, CFG.goal_y + CFG.hint_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    self._hintFS = hintFS
end

function R:_SetHudShown(shown)
    local boxes = {
        self._levelBox, self._scoreBox, self._movesBox, self._bestBox,
        self._goalFrame, self._goalPuBox,
    }
    for _, w in ipairs(boxes) do
        if w then if shown then w:Show() else w:Hide() end end
    end
    if shown then
        if self._goldGrid then self._goldGrid:Show() end
    else
        if self._timeBox then self._timeBox:Hide() end
        if self._goldGrid then self._goldGrid:Hide() end
        if self._comboFS then self._comboFS:Hide() end
    end
end

function R:UpdateHUD(gs)
    if not gs then return end
    local L      = Loc()
    local Format = ArcadiaNexus.Format
    local Levels = ArcadiaNexus.AJ_Levels
    local E      = ArcadiaNexus.AJ_Engine

    if self._levelFS then
        local txt
        if gs.endless then
            txt = (L["lbl_endless"] or "Endlos") .. ": " .. tostring(gs.endlessWave or 1)
        else
            txt = (L["lbl_level"] or "Level") .. ": " .. gs.level .. "/" .. Levels.COUNT
            if (gs.mapBestStars or 0) > 0 then
                txt = txt .. "  " .. string.rep("*", gs.mapBestStars)
            end
        end
        self._levelFS:SetText(txt)
    end
    if self._scoreFS then
        self._scoreFS:SetText((L["lbl_score"] or "Punkte") .. ": " .. Format.Score(gs.score))
    end
    if self._movesFS then
        local mv = gs.movesLeft
        local prefix = (L["lbl_moves"] or "Züge") .. ": "
        if mv <= 3 then
            self._movesFS:SetText(prefix .. "|cffff4444" .. mv .. "|r")
        elseif mv <= 7 then
            self._movesFS:SetText(prefix .. "|cffffff00" .. mv .. "|r")
        else
            self._movesFS:SetText(prefix .. tostring(mv))
        end
    end
    if gs.timerActive and self._timeFS then
        if self._timeBox then self._timeBox:Show() end
        local text, level, r, g, b = Format.SecondsWithUrgency(math.ceil(gs.timeLeft), {
            warn = 20, crit = 10, padMinutes = false,
        })
        if level ~= "normal" then
            text = string.format("|cff%02x%02x%02x%s|r",
                math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
        end
        self._timeFS:SetText((L["lbl_time"] or "Zeit") .. ": " .. text)
    elseif self._timeBox then
        self._timeBox:Hide()
    end
    if self._subFS then
        self._subFS:SetText(string.format("%s: %s",
            L["lbl_highscore"], Format.Score(gs.highScore or 0)))
    end

    self:_UpdateGoalDisplay(gs)
end

function R:_UpdateGoalDisplay(gs)
    local L      = Loc()
    local Format = ArcadiaNexus.Format

    for _, item in ipairs(self._goalItems) do item:Hide() end

    if gs.goalType == "SCORE" then
        self._goalFS:SetText(string.format(L["goal_score"],
            Format.Score(gs.score), Format.Score(gs.goalScore or 0)))
        self._goalFS:Show()
    else
        self._goalFS:Hide()
        local goals = gs.goalCollect or {}
        local n = #goals
        local itemW, gap = CFG.collect_item_w or 64, 8
        local totalW = n * itemW + math.max(0, n - 1) * gap
        local prev = self._collectShown or {}
        local shown = {}
        for i, g in ipairs(goals) do
            local item = self._goalItems[i]
            if item then
                item:ClearAllPoints()
                item:SetPoint("LEFT", self._goalFrame, "CENTER",
                    -totalW / 2 + (i - 1) * (itemW + gap), 0)
                ApplyGemVisual(item._tex, g.gemType)
                local raw = gs.collected[g.gemType] or 0
                local have = math.min(raw, g.amount)
                shown[g.gemType] = raw
                local frac = (g.amount > 0) and math.min(1, have / g.amount) or 0
                if item._bar then
                    local bw = math.max(1, itemW * frac)
                    item._bar:SetWidth(bw)
                    if have >= g.amount then
                        item._bar:SetVertexColor(0.30, 0.85, 0.40, 1)
                    else
                        item._bar:SetVertexColor(0.85, 0.70, 0.22, 1)
                    end
                end
                if have >= g.amount then
                    item._fs:SetText("|cff44ff44" .. have .. "/" .. g.amount .. "|r")
                else
                    item._fs:SetText(have .. "/" .. g.amount)
                end
                item:Show()
                if raw > (prev[g.gemType] or 0) then
                    self:_PulseGoalItem(item)
                end
            end
        end
        self._collectShown = shown
    end
end

function R:_PulseGoalItem(item)
    if self:_ReducedMotion() then return end
    if not item or not item._flash then return end
    local elapsed = 0
    local DUR = 0.40
    if not item._pulseTick then
        item._pulseTick = CreateFrame("Frame", nil, item)
    end
    item._pulseTick:SetScript("OnUpdate", function(f, dt)
        elapsed = elapsed + (dt or 0.016)
        local t = math.min(elapsed / DUR, 1)
        local a = 0.55 * (1 - t)
        item._flash:SetVertexColor(1, 0.92, 0.35, a)
        if t >= 1 then
            f:SetScript("OnUpdate", nil)
            item._flash:SetVertexColor(1, 0.92, 0.35, 0)
        end
    end)
end

-- ============================================================
-- POWERUP-LEISTE (GDD §6.4)
-- ============================================================
function R:_CreatePowerUpBar()
    local f  = self._canvas
    local PU = ArcadiaNexus.AJ_PowerUps
    local L  = Loc()

    local bar = CreateFrame("Frame", nil, f)
    local n = #PU.ORDER
    bar:SetSize(n * CFG.pu_icon + (n - 1) * CFG.pu_gap, CFG.pu_icon)
    bar:SetPoint("CENTER", f, "CENTER", 0, CFG.pu_bar_y)
    self._puBar = bar

    self._puButtons = {}
    for i, id in ipairs(PU.ORDER) do
        local btn = CreateFrame("Button", nil, bar, "BackdropTemplate")
        btn:SetSize(CFG.pu_icon, CFG.pu_icon)
        btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * (CFG.pu_icon + CFG.pu_gap), 0)
        btn:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        btn:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        icon:SetTexture(POWERUP_ICONS[id])
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetDesaturated(true)
        btn._icon = icon

        -- Fortschrittsring (WoW-Cooldown-Stil, Clockwise-Sweep)
        local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        cd:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        cd:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(true)
        cd:EnableMouse(false)
        btn._cd = cd

        -- Inventar-Zähler
        local count = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        count:SetText("")
        btn._count = count

        -- Glow bei Aufladung
        local glow = btn:CreateTexture(nil, "OVERLAY", nil, 3)
        glow:SetAllPoints(btn)
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetVertexColor(1, 0.9, 0.2, 0)
        glow:SetBlendMode("ADD")
        btn._glowTex = glow

        btn._puId = id
        btn:SetScript("OnClick", function(b)
            local E = ArcadiaNexus.AJ_Engine
            if E then E:OnPowerUpClick(b._puId) end
        end)
        btn:SetScript("OnEnter", function(b)
            b._tipOn = true
            R:_ShowPowerUpTip(b)
        end)
        btn:SetScript("OnLeave", function(b)
            b._tipOn = false
            GameTooltip:Hide()
        end)

        self._puButtons[id] = btn
    end

    bar:Hide()

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateHudStatBox and not self._goalPuBox then
        local wrap, wrapFS = UI.CreateHudStatBox(f, {
            w = CFG.goal_pu_w, h = CFG.goal_pu_h,
            point = "CENTER", relativePoint = "CENTER",
            x = CFG.goal_pu_x, y = CFG.goal_pu_y,
            alpha = CFG.goal_pu_alpha,
            shown = false,
        })
        if wrapFS then wrapFS:Hide() end
        if wrap then
            wrap:SetFrameLevel(f:GetFrameLevel() + 8)
            self._goalPuBox = wrap
            if self._goalFrame then
                self._goalFrame:SetFrameLevel(wrap:GetFrameLevel() + 2)
            end
            bar:SetFrameLevel(wrap:GetFrameLevel() + 2)
        end
    end
end

function R:_ShowPowerUpTip(btn)
    if not btn or not GameTooltip then return end
    local loc = Loc()
    local id = btn._puId
    local name = loc["powerup_" .. id] or id
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    GameTooltip:SetText(name, 1, 0.82, 0)
    GameTooltip:AddLine(loc["powerup_" .. id .. "_desc"] or "", 0.9, 0.9, 0.9, true)

    local PU = ArcadiaNexus.AJ_PowerUps
    local E  = ArcadiaNexus.AJ_Engine
    local info = PU and E and E.powerUps and PU:GetChargeInfo(E.powerUps, id)
    if info then
        local Format = ArcadiaNexus.Format
        if info.chargeType == "combo" then
            GameTooltip:AddLine(string.format(loc["powerup_charge_combo"],
                info.progress, info.target), 0.75, 0.75, 0.70)
        else
            GameTooltip:AddLine(string.format(loc["powerup_charge_score"],
                Format.Score(info.progress), Format.Score(info.target)), 0.75, 0.75, 0.70)
        end
        if info.full then
            GameTooltip:AddLine(loc["powerup_full"], 1, 0.82, 0.2)
        elseif info.chargeType == "combo" then
            GameTooltip:AddLine(string.format(loc["powerup_until_combo"], info.remain, name),
                0.45, 0.85, 1)
        else
            GameTooltip:AddLine(string.format(loc["powerup_until_score"],
                Format.Score(info.remain), name), 0.45, 0.85, 1)
        end
        GameTooltip:AddLine(string.format(loc["powerup_inv"], info.inv), 0.7, 0.7, 0.7)
        if info.inv > 0 then
            GameTooltip:AddLine(loc["powerup_ready"], 0.3, 1, 0.3)
            if info.needsTarget then
                GameTooltip:AddLine(loc["powerup_use_target"], 0.55, 0.9, 0.55)
            else
                GameTooltip:AddLine(loc["powerup_use_instant"], 0.55, 0.9, 0.55)
            end
        end
    end
    GameTooltip:Show()
end

local RING_DUR = 100
local function SetRingFraction(cd, frac)
    if frac <= 0 or frac >= 1 then
        cd:Clear()
        return
    end
    cd:SetCooldown(GetTime() - frac * RING_DUR, RING_DUR)
    cd:Pause()
end

function R:UpdatePowerUpBar(pu)
    if not pu then return end
    local PU = ArcadiaNexus.AJ_PowerUps
    for id, btn in pairs(self._puButtons) do
        local inv  = pu.inv[id] or 0
        local frac = PU:GetProgressFraction(pu, id)
        if inv > 0 then
            btn:SetBackdropBorderColor(1, 0.82, 0.1, 1)   -- gold = bereit
            btn._icon:SetDesaturated(false)
            btn._count:SetText("|cffffd700" .. inv .. "|r")
        else
            btn:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)
            btn._icon:SetDesaturated(true)
            btn._count:SetText("")
        end
        if inv >= PU.MAX_INVENTORY then
            btn._cd:Clear()
        else
            SetRingFraction(btn._cd, frac)
        end
        if btn._tipOn then
            self:_ShowPowerUpTip(btn)
        end
    end
end

--- Kurzer Glow wenn ein PowerUp voll aufgeladen wurde.
function R:OnPowerUpCharged(id)
    if self:_ReducedMotion() then return end
    local btn = self._puButtons[id]
    if not btn then return end
    btn._glowTex:SetVertexColor(1, 0.9, 0.2, 0.65)
    _fxGuard:After(0.5, function()
        btn._glowTex:SetVertexColor(1, 0.9, 0.2, 0)
    end)
end

-- ============================================================
-- TARGETING-MODUS
-- ============================================================
function R:EnterTargetingMode(id)
    self._targeting = id
    local L = Loc()
    self:ShowHint(id == "frost" and L["hint_targeting_frost"] or L["hint_targeting"])
    if self._keyFrame then self._keyFrame:EnableKeyboard(true) end
    local btn = self._puButtons[id]
    if btn then btn:SetBackdropBorderColor(0.3, 1, 0.3, 1) end
end

function R:ExitTargetingMode()
    self._targeting = nil
    self:_ClearHighlights()
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    local E = ArcadiaNexus.AJ_Engine
    if E then self:UpdatePowerUpBar(E.powerUps) end
    self:ShowHint(Loc()["hint_select"])
end

function R:_ClearHighlights()
    for _, cell in ipairs(self._highlighted) do
        if cell._glow then cell._glow:SetVertexColor(1, 0.9, 0.1, 0) end
    end
    self._highlighted = {}
    self:DrawGrid(self._gsRef)
end

function R:_ClearDragHover()
    local h = self._dragHover
    self._dragHover = nil
    if not h then return end
    local cell = self._cells[h.row] and self._cells[h.row][h.col]
    if cell and cell._glow and not (self._selected and self._selected.row == h.row and self._selected.col == h.col) then
        cell._glow:SetVertexColor(1, 0.9, 0.1, 0)
    end
end

function R:_ShowDragHover(row, col)
    local d = self._drag
    if not d then return end
    local prev = self._dragHover
    if prev and prev.row == row and prev.col == col then return end
    self:_ClearDragHover()
    local L = Logic()
    if not L or not L:IsAdjacent(d.row, d.col, row, col) then return end
    local cell = self._cells[row] and self._cells[row][col]
    if not cell or not cell._glow then return end
    cell._glow:SetVertexColor(0.45, 1, 0.55, 0.40)
    self._dragHover = { row = row, col = col }
end

function R:_StopDragWatch()
    if self._dragWatch then self._dragWatch:SetScript("OnUpdate", nil) end
end

-- Nachbarzelle unter dem Cursor. Nicht btn._row: WoW liefert MouseUp
-- an die Startzelle (Capture), nicht an das Ziel.
function R:CellAtCursor()
    local board, cs = self._board, self._cellSize
    if not board or not cs or cs <= 0 then return nil end
    local scale = board:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local left, top = board:GetLeft(), board:GetTop()
    if not left or not top then return nil end
    local col = math.floor((x - left) / cs) + 1
    local row = math.floor((top - y) / cs) + 1
    if row < 1 or row > (self._rows or 0) or col < 1 or col > (self._cols or 0) then
        return nil
    end
    return row, col
end

function R:_FinishGemDrag()
    local d = self._drag
    if not d then return end
    self._drag = nil
    self:_StopDragWatch()
    self:_ClearDragHover()
    local r2, c2 = self:CellAtCursor()
    if not r2 or (r2 == d.row and c2 == d.col) then return end
    self._skipClick = true
    local E = ArcadiaNexus.AJ_Engine
    if E and E.OnCellDrag then
        E:OnCellDrag(d.row, d.col, r2, c2)
    end
end

function R:_BeginGemDrag(row, col)
    self._skipClick = false
    self._drag = { row = row, col = col }
    local E = ArcadiaNexus.AJ_Engine
    if E and E._CancelIdleHint then E:_CancelIdleHint() end
    local board = self._board
    if not board then return end
    if not self._dragWatch then
        self._dragWatch = CreateFrame("Frame", nil, board)
    else
        self._dragWatch:SetParent(board)
    end
    self._dragWatch:SetScript("OnUpdate", function()
        local d = R._drag
        if not d then
            R:_StopDragWatch()
            return
        end
        if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            local r, c = R:CellAtCursor()
            if r then R:_ShowDragHover(r, c) else R:_ClearDragHover() end
            return
        end
        R:_FinishGemDrag()
    end)
end

function R:_ShowTargetPreview(row, col)
    if not self._targeting then return end
    local E = ArcadiaNexus.AJ_Engine
    if not E then return end
    self:_ClearHighlights()
    local cells = E:GetPowerUpPreview(row, col, IsShiftKeyDown())
    if not cells then return end
    for _, rc in ipairs(cells) do
        local cell = self._cells[rc[1]] and self._cells[rc[1]][rc[2]]
        if cell then
            cell._glow:SetVertexColor(1, 0.5, 0.1, 0.45)
            self._highlighted[#self._highlighted + 1] = cell
        end
    end
end

-- ============================================================
-- BOARD
-- ============================================================
function R:_BuildBoard(gs)
    self:_ClearBoard()
    self._cols = gs.cols
    self._rows = gs.rows
    self._cellSize = math.max(CFG.cell_min, math.floor(CFG.board_size / math.max(gs.cols, gs.rows)))

    local cs    = self._cellSize
    local board = self._board
    board:SetSize(cs * gs.cols, cs * gs.rows)
    board:ClearAllPoints()
    board:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)

    self._cells = {}
    for r = 1, gs.rows do
        self._cells[r] = {}
        for c = 1, gs.cols do
            local cell = AcquireCell(board, cs)
            cell:SetPoint("TOPLEFT", board, "TOPLEFT", (c - 1) * cs, -(r - 1) * cs)
            cell._row = r
            cell._col = c
            cell:SetScript("OnMouseDown", function(btn, mouseButton)
                if mouseButton ~= "LeftButton" then return end
                if R._targeting then return end
                R:_BeginGemDrag(btn._row, btn._col)
            end)
            cell:SetScript("OnMouseUp", function(_, mouseButton)
                if mouseButton ~= "LeftButton" then return end
                R:_FinishGemDrag()
            end)
            cell:SetScript("OnClick", function(btn, mouseButton)
                if R._skipClick then
                    R._skipClick = false
                    return
                end
                local E = ArcadiaNexus.AJ_Engine
                if E then
                    E:OnCellClick(btn._row, btn._col, mouseButton, IsShiftKeyDown())
                end
            end)
            cell:SetScript("OnEnter", function(btn)
                if R._drag then
                    R:_ShowDragHover(btn._row, btn._col)
                    return
                end
                R:_ShowTargetPreview(btn._row, btn._col)
            end)
            cell:SetScript("OnLeave", function()
                if R._targeting then R:_ClearHighlights() end
            end)
            self._cells[r][c] = cell
        end
    end
    self:DrawGrid(gs)
end

function R:_ClearBoard()
    for r = 1, #self._cells do
        for c = 1, (self._cells[r] and #self._cells[r] or 0) do
            local cell = self._cells[r][c]
            if cell then ReleaseCell(cell) end
        end
    end
    self._cells = {}
    self._drag = nil
    self._dragHover = nil
    self:_StopDragWatch()
end

function R:DrawGrid(gs)
    if not gs then return end
    local L = Logic()
    for r = 1, gs.rows do
        for c = 1, gs.cols do
            local cell = self._cells[r] and self._cells[r][c]
            if cell then
                cell._row = r
                cell._col = c
                cell:SetAlpha(1)
                cell:SetScale(1)
                local ob = gs.obstacles[r] and gs.obstacles[r][c]
                local gemType = gs.board[r] and gs.board[r][c] or 0

                if ob == "STONE" then
                    cell._tex:SetTexture(AJ_OB_TEXTURES.STONE)
                    cell._tex:SetTexCoord(0, 1, 0, 1)
                    cell._tex:SetVertexColor(1, 1, 1, 1)
                    cell._tex:SetAlpha(1)
                    cell._ice:SetVertexColor(1, 1, 1, 0)
                    cell:SetBackdropColor(0.12, 0.11, 0.10, 0.9)
                    cell:SetBackdropBorderColor(0.45, 0.40, 0.32, 1)
                elseif ob == "LOCKED" then
                    cell._tex:SetTexture(AJ_OB_TEXTURES.LOCKED)
                    cell._tex:SetTexCoord(0, 1, 0, 1)
                    cell._tex:SetVertexColor(1, 1, 1, 1)
                    cell._tex:SetAlpha(1)
                    cell._ice:SetVertexColor(1, 1, 1, 0)
                    cell:SetBackdropColor(0.04, 0.03, 0.06, 1)
                    cell:SetBackdropBorderColor(0.28, 0.20, 0.38, 1)
                    cell:SetAlpha(1)
                else
                    cell:SetBackdropColor(0.10, 0.10, 0.14, 0.35)
                    if gemType and gemType > 0 then
                        ApplyGemVisual(cell._tex, gemType)
                        cell._tex:SetAlpha(1)
                    else
                        cell._tex:SetTexture(nil)
                        cell:SetAlpha(0.15)
                    end
                    if ob == "ICE" then
                        cell._ice:SetTexture(AJ_OB_TEXTURES.ICE)
                        cell._ice:SetVertexColor(1, 1, 1, 1)
                        cell:SetBackdropBorderColor(0.55, 0.82, 1, 1)
                    else
                        cell._ice:SetVertexColor(1, 1, 1, 0)
                        cell:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)
                    end
                end

                -- Auswahl-Glow
                local hintKey = r .. "," .. c
                if self._selected and self._selected.row == r and self._selected.col == c then
                    cell._glow:SetVertexColor(1, 0.9, 0.1, 0.40)
                    cell:SetBackdropBorderColor(1, 0.9, 0.1, 1)
                elseif self._hintCells and self._hintCells[hintKey] then
                    cell._glow:SetVertexColor(0.55, 0.95, 1, 0.35)
                else
                    cell._glow:SetVertexColor(1, 0.9, 0.1, 0)
                end
            end
        end
    end
end

-- ============================================================
-- AUSWAHL / HINT / COMBO
-- ============================================================
function R:SetSelection(row, col)
    self._selected = { row = row, col = col }
    self:DrawGrid(self._gsRef)
end

function R:ClearSelection()
    self._selected = nil
    self:DrawGrid(self._gsRef)
end

function R:ShowHint(text)
    if self._hintFS then self._hintFS:SetText(text or "") end
end

function R:ClearMoveHint()
    _hintLoop:Stop()
    self._hintCells = {}
    if self._gsRef then
        -- Glow zurücksetzen, ohne Board neu aufzubauen
        for r = 1, (self._rows or 0) do
            for c = 1, (self._cols or 0) do
                local cell = self._cells[r] and self._cells[r][c]
                if cell and cell._glow and not (self._selected and self._selected.row == r and self._selected.col == c) then
                    cell._glow:SetVertexColor(1, 0.9, 0.1, 0)
                end
            end
        end
    end
end

function R:ShowMoveHint(hint)
    self:ClearMoveHint()
    if not hint then return end
    local keys = {}
    keys[hint.r1 .. "," .. hint.c1] = true
    keys[hint.r2 .. "," .. hint.c2] = true
    for _, rc in ipairs(hint.matchCells or {}) do
        keys[rc[1] .. "," .. rc[2]] = true
    end
    self._hintCells = keys
    if self:_ReducedMotion() then
        for key in pairs(keys) do
            local r, c = key:match("(%d+),(%d+)")
            r, c = tonumber(r), tonumber(c)
            local cell = self._cells[r] and self._cells[r][c]
            if cell and cell._glow then
                cell._glow:SetVertexColor(0.55, 0.95, 1, 0.35)
            end
        end
        return
    end
    local elapsed = 0
    _hintLoop:Start(function(dt)
        elapsed = elapsed + dt
        local a = 0.20 + 0.32 * (0.5 + 0.5 * math.sin(elapsed * 7))
        for key in pairs(R._hintCells or {}) do
            local r, c = key:match("(%d+),(%d+)")
            r, c = tonumber(r), tonumber(c)
            local cell = R._cells[r] and R._cells[r][c]
            if cell and cell._glow then
                cell._glow:SetVertexColor(0.55, 0.95, 1, a)
            end
        end
    end, { maxDt = 0.1 })
end

function R:ShowCombo(count)
    if not self._comboFS then return end
    self._comboFS:SetText(Loc()["combo_prefix"] .. tostring(count))
    self._comboFS:SetAlpha(1)
    if self:_ReducedMotion() then
        self._comboFS:SetTextHeight(18)
    else
        self._comboFS:SetTextHeight(20 + math.min(10, (count or 1) * 2))
    end
    self._comboFS:Show()
    local tok = {}
    self._comboToken = tok
    local hold = self:_ReducedMotion() and 0.8 or 1.5
    _fxGuard:After(hold, function()
        if self._comboToken ~= tok then return end
        if R:_ReducedMotion() then
            self._comboFS:Hide()
            self._comboFS:SetTextHeight(18)
            self._comboToken = nil
            return
        end
        UIFrameFadeOut(self._comboFS, 0.5, 1, 0)
        _fxGuard:After(0.5, function()
            if self._comboToken ~= tok then return end
            self._comboFS:Hide()
            self._comboFS:SetTextHeight(18)
            self._comboToken = nil
        end)
    end)
end

function R:HideCombo()
    self._comboToken = nil
    if self._comboFS then self._comboFS:Hide() end
end

-- ============================================================
-- SLOT-MENÜ (nach „Spiel starten“) – gemeinsamer Helper
-- ============================================================
function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = Loc()
    local S  = ArcadiaNexus.AJ_Settings
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
            local diffLabel = loc["diff_" .. (save.difficulty or "easy")] or ""
            local score = (ArcadiaNexus.Format and ArcadiaNexus.Format.Score(save.totalScore or 0))
                or tostring(save.totalScore or 0)
            local stars = (S and S:SumStars(save)) or 0
            local info = string.format(loc.slot_info or "Level %d · %s", save.level or 1, score)
            if (save.clearedLevel or 0) >= 100 and (save.endlessWave or 0) > 0 then
                info = info .. " · " .. string.format(loc.slot_endless or "Endlos %d", save.endlessWave)
            end
            if stars > 0 then
                info = info .. " · " .. string.format(loc.slot_stars or "%d★", stars)
            end
            if diffLabel ~= "" then
                info = info .. " · " .. diffLabel
            end
            return info
        end,
        isPaused      = function(save) return save.midLevel ~= nil end,
        formatPaused  = function(save, loc)
            local lvl = save.midLevel and save.midLevel.logic and save.midLevel.logic.level
                or save.level or 1
            return string.format(loc.slot_paused or "Level %d läuft", lvl)
        end,
        onNewGame     = function(slot)
            local E = ArcadiaNexus.AJ_Engine
            if E then E:StartGame({ slot = slot, mode = "new" }) end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.AJ_Engine
            local save = S and S:LoadSlot(slot)
            if save and save.midLevel then
                if E then E:StartGame({ slot = slot, mode = "continue" }) end
            elseif E then
                E:OpenMap(slot)
            end
        end,
    })
end

local MAP_PAGE_SIZE = 10

local function StarGlyphs(n)
    n = math.max(0, math.min(3, tonumber(n) or 0))
    if n <= 0 then return "—" end
    return string.rep("*", n)
end

function R:_CreateLevelMap()
    if self._mapFrame or not self._fieldFrame then return end
    local UI = ArcadiaNexus.UI
    local f = CreateFrame("Frame", nil, self._fieldFrame)
    f:SetAllPoints(self._fieldFrame)
    f:Hide()
    self._mapFrame = f

    local panel = CreateFrame("Frame", nil, f)
    panel:SetSize(CFG.map_panel_w, CFG.map_panel_h)
    panel:SetPoint("CENTER", f, "CENTER", 0, 8)
    self._mapPanel = panel

    if UI and UI.CreateGoldGridFrame then
        self._mapGold = UI.CreateGoldGridFrame(f, panel, {
            w         = CFG.map_panel_w,
            h         = CFG.map_panel_h,
            pad       = CFG.map_pad,
            fillAlpha = CFG.map_panel_alpha,
            levelAdd  = 1,
        })
        panel:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetTextColor(1, 0.85, 0.35)
    self._mapTitleFS = title

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.80, 0.80, 0.70)
    self._mapSubFS = sub

    self._mapTiles = {}
    local tw, th = CFG.map_tile_w, CFG.map_tile_h
    local gx, gy = CFG.map_gap_x, CFG.map_gap_y
    local cols = 5
    local totalW = cols * tw + (cols - 1) * gx
    local padX = math.floor((CFG.map_panel_w - totalW) / 2)
    local topY = -(CFG.map_header_h or 58)

    for i = 1, MAP_PAGE_SIZE do
        local col = ((i - 1) % cols)
        local row = math.floor((i - 1) / cols)
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(tw, th)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT",
            padX + col * (tw + gx), topY - row * (th + gy))
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        num:SetPoint("CENTER", btn, "CENTER", 0, 8)
        local stars = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        stars:SetPoint("CENTER", btn, "CENTER", 0, -12)
        stars:SetTextColor(1, 0.82, 0.2)
        btn._numFS = num
        btn._starFS = stars
        btn:SetScript("OnClick", function(selfBtn)
            if selfBtn._locked then return end
            local E = ArcadiaNexus.AJ_Engine
            if E and E.SelectMapLevel then E:SelectMapLevel(selfBtn._level) end
        end)
        self._mapTiles[i] = btn
    end

    self._mapPrev = UI.CreateArcadiaButton(panel, "<", 36, 28)
    self._mapPrev:SetPoint("BOTTOM", panel, "BOTTOM", -90, 12)
    self._mapPrev:SetScript("OnClick", function()
        R._mapPage = math.max(1, (R._mapPage or 1) - 1)
        R:_RefreshLevelMap()
    end)
    self._mapNext = UI.CreateArcadiaButton(panel, ">", 36, 28)
    self._mapNext:SetPoint("BOTTOM", panel, "BOTTOM", 90, 12)
    self._mapNext:SetScript("OnClick", function()
        local pages = R:_MapPageCount()
        R._mapPage = math.min(pages, (R._mapPage or 1) + 1)
        R:_RefreshLevelMap()
    end)
    self._mapPageFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self._mapPageFS:SetPoint("BOTTOM", panel, "BOTTOM", 0, 18)
    self._mapPageFS:SetTextColor(0.80, 0.80, 0.70)

    self._mapEndless = UI.CreateArcadiaButton(f, Loc()["btn_endless"] or "Endlos", 110, 28)
    self._mapEndless:SetPoint("TOP", panel, "BOTTOM", 0, -8)
    self._mapEndless:SetScript("OnClick", function()
        local E = ArcadiaNexus.AJ_Engine
        if E and E.SelectEndless then E:SelectEndless() end
    end)
    self._mapEndless:Hide()
end

function R:_MapPageCount()
    local Levels = ArcadiaNexus.AJ_Levels
    local count = (Levels and Levels.COUNT) or 100
    return math.max(1, math.ceil(count / MAP_PAGE_SIZE))
end

function R:_HideLevelMap()
    if self._mapFrame then self._mapFrame:Hide() end
    if self._mapGold then self._mapGold:Hide() end
end

function R:ShowLevelMap(save, focusLevel)
    self:_ClearBoard()
    self:_SetHudShown(false)
    if self._puBar then self._puBar:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end
    if self._logoTex then self._logoTex:Hide() end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn then self._exitBtn:Show() end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self.state = "MAP"
    self._mapSave = save
    local Levels = ArcadiaNexus.AJ_Levels
    local count = (Levels and Levels.COUNT) or 100
    local focus = math.max(1, math.min(focusLevel or (save and save.level) or 1, count))
    self._mapPage = math.ceil(focus / MAP_PAGE_SIZE)
    if self._mapFrame then self._mapFrame:Show() end
    if self._mapGold then self._mapGold:Show() end
    if self._hintFS then
        self._hintFS:Show()
        self:ShowHint(Loc()["hint_select_level"] or "")
    end
    self:_RefreshLevelMap()
end

function R:_RefreshLevelMap()
    local S = ArcadiaNexus.AJ_Settings
    local Levels = ArcadiaNexus.AJ_Levels
    local L = Loc()
    local save = self._mapSave
    local count = (Levels and Levels.COUNT) or 100
    local pages = self:_MapPageCount()
    local page = math.max(1, math.min(self._mapPage or 1, pages))
    self._mapPage = page
    local first = (page - 1) * MAP_PAGE_SIZE + 1
    local last = math.min(count, page * MAP_PAGE_SIZE)
    if self._mapTitleFS then
        self._mapTitleFS:SetText(string.format(L["map_title"] or "Level %d–%d", first, last))
    end
    if self._mapSubFS then
        local sum = S and S:SumStars(save) or 0
        self._mapSubFS:SetText(string.format(L["map_stars_total"] or "%d / %d", sum, count * 3))
    end
    if self._mapPageFS then
        self._mapPageFS:SetText(string.format("%d / %d", page, pages))
    end
    if self._mapEndless then
        local unlocked = save and (save.clearedLevel or 0) >= count
        if unlocked then self._mapEndless:Show() else self._mapEndless:Hide() end
    end
    local cursor = save and (save.level or 1) or 1
    for i = 1, MAP_PAGE_SIZE do
        local btn = self._mapTiles and self._mapTiles[i]
        local level = first + i - 1
        if btn then
            if level > count then
                btn:Hide()
            else
                btn:Show()
                btn._level = level
                local unlocked = S and S:IsLevelUnlocked(save, level, count)
                btn._locked = not unlocked
                btn._numFS:SetText(tostring(level))
                if not unlocked then
                    btn:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
                    btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
                    btn._numFS:SetTextColor(0.45, 0.45, 0.48)
                    btn._starFS:SetText(L["map_locked"] or "—")
                    btn._starFS:SetTextColor(0.40, 0.40, 0.42)
                else
                    local isCurrent = (level == math.min(cursor, count))
                    if isCurrent then
                        btn:SetBackdropColor(0.18, 0.14, 0.06, 0.95)
                        btn:SetBackdropBorderColor(1, 0.84, 0.2, 1)
                        btn._numFS:SetTextColor(1, 0.90, 0.40)
                    else
                        btn:SetBackdropColor(0.10, 0.12, 0.16, 0.90)
                        btn:SetBackdropBorderColor(0.55, 0.50, 0.32, 1)
                        btn._numFS:SetTextColor(0.90, 0.88, 0.80)
                    end
                    local st = S:GetStar(save, level)
                    btn._starFS:SetText(StarGlyphs(st))
                    btn._starFS:SetTextColor(1, 0.82, 0.2)
                end
            end
        end
    end
    if self._mapPrev then
        if page <= 1 then self._mapPrev:Disable() else self._mapPrev:Enable() end
    end
    if self._mapNext then
        if page >= pages then self._mapNext:Disable() else self._mapNext:Enable() end
    end
end

-- ============================================================
-- CONTROLS (untere Leiste, Blueprint Match-3)
-- Links: Schwierigkeits-Dropdown · Mitte: Spiel starten / Beenden ·
-- Rechts: Zeitmodus-Checkbox. Dropdown/Checkbox gelten für
-- NEUE Spielstände (Schwierigkeit ist pro Slot fixiert).
-- ============================================================
function R:_CreateControls()
    local UI = ArcadiaNexus.UI
    local L  = Loc()
    local S  = ArcadiaNexus.AJ_Settings
    if not self.frame or not UI then return end

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]   },
            { key = "normal", label = L["diff_normal"] },
            { key = "hard",   label = L["diff_hard"]   },
        },
        function()
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            if S then S:Set("difficulty", key) end
        end
    )

    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._startBtn = startBtn

    local exitBtn = UI.CreateArcadiaButton(cf, L["btn_exit"], CFG.btn_w, CFG.btn_h)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    exitBtn:SetScript("OnClick", function()
        if R.state == "MENU" then
            R:EnterIdleState()
            return
        end
        if R.state == "MAP" then
            local E = ArcadiaNexus.AJ_Engine
            if E and E.MapBackToSlots then E:MapBackToSlots() else R:EnterSlotMenu() end
            return
        end
        local E = ArcadiaNexus.AJ_Engine
        if not E then return end
        if E.state ~= "IDLE" then
            if E.gameState and not E.gameState.gameOver then
                E:SaveAndPause()
                R:EnterIdleState()
            else
                E:StopGame()
            end
        end
    end)
    exitBtn:Hide()
    self._exitBtn = exitBtn

    local chkSize = CFG.chk_size or 20
    local chkHolder = CreateFrame("Frame", nil, cf)
    chkHolder:SetSize(chkSize + 8 + 80, math.max(32, chkSize))
    chkHolder:SetPoint("CENTER", cf, "CENTER", bar.segX[3], 0)

    local cb = CreateFrame("CheckButton", nil, chkHolder, "UICheckButtonTemplate")
    cb:SetSize(chkSize, chkSize)
    cb:SetPoint("LEFT", chkHolder, "LEFT", 0, 0)
    cb:SetScript("OnShow", function()
        cb:SetChecked(S and S:Get("timerActive") or false)
    end)
    cb:SetScript("OnClick", function()
        if S then S:Set("timerActive", cb:GetChecked()) end
    end)
    self._timerCheckbox = cb

    local chkLabel = chkHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    chkLabel:SetJustifyH("LEFT")
    chkLabel:SetText(L["lbl_timer_on"] or "Zeitmodus")
end

-- ============================================================
-- IDLE STATE (Logo)
-- ============================================================
function R:EnterIdleState()
    StopAnimLoop()
    _hintLoop:Stop()
    self.state     = "IDLE"
    self._gsRef    = nil
    self._selected = nil
    self._targeting = nil
    self._highlighted = {}
    self._hintCells = {}
    _fxGuard:Cancel()
    self:_StopImpactFx()

    self:_ClearBoard()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    ArcadiaNexus.UI.HideChoicePopup(self._fieldFrame)

    self:_SetHudShown(false)
    if self._puBar    then self._puBar:Hide()    end
    if self._slotMenu then self._slotMenu:Hide() end
    self:_HideLevelMap()
    if self._exitBtn  then self._exitBtn:Hide()  end
    if self._startBtn then self._startBtn:Show() end
    if self._logoTex  then self._logoTex:Show()  end
    if self._hintFS   then self._hintFS:Hide()   end
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    self:HideCombo()
end

-- ============================================================
-- SLOT-MENÜ (nach „Spiel starten“)
-- ============================================================
function R:EnterSlotMenu()
    self.state = "MENU"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    ArcadiaNexus.UI.HideChoicePopup(self._fieldFrame)

    if self._logoTex  then self._logoTex:Hide()  end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._hintFS   then self._hintFS:Show()   end
    if self._slotMenu then self._slotMenu:Show() end
    self:_HideLevelMap()
    self:ShowHint(Loc()["hint_select_slot"])
end

-- ============================================================
-- SPIELSTART
-- ============================================================
function R:OnGameStarted(gs)
    self.state  = "PLAYING"
    self._gsRef = gs
    self._selected = nil
    self._drag = nil
    self._dragHover = nil
    self._targeting = nil
    self._collectShown = {}
    if gs.collected then
        for k, v in pairs(gs.collected) do
            self._collectShown[k] = v
        end
    end
    self:ClearMoveHint()

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    ArcadiaNexus.UI.HideChoicePopup(self._fieldFrame)
    if self._slotMenu then self._slotMenu:Hide() end
    self:_HideLevelMap()
    self:_StopImpactFx()

    self:_SetHudShown(true)
    if self._puBar    then self._puBar:Show()    end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._logoTex  then self._logoTex:Hide()  end
    if self._hintFS   then self._hintFS:Show()   end

    if self._timeLbl and self._timeFS then
        if gs.timerActive then
            self._timeLbl:Show()
            self._timeFS:Show()
        else
            self._timeLbl:Hide()
            self._timeFS:Hide()
        end
    end

    self:_BuildBoard(gs)
    self:UpdateHUD(gs)
    local E = ArcadiaNexus.AJ_Engine
    if E then self:UpdatePowerUpBar(E.powerUps) end
    self:ShowHint(Loc()["hint_select"])
end

-- ============================================================
-- RESULT-DIALOGE
-- ============================================================
local function ResultLines(gs, totalScore)
    local L      = Loc()
    local Format = ArcadiaNexus.Format
    local lines = {}
    if gs.endless then
        table.insert(lines, string.format(L["result_endless_wave"], gs.endlessWave or 1))
        table.insert(lines, string.format(L["result_endless_run"], Format.Score(gs.endlessRunScore or gs.score)))
    else
        table.insert(lines, string.format(L["result_level"], gs.level))
    end
    table.insert(lines, string.format(L["result_level_score"], Format.Score(gs.score)))
    table.insert(lines, string.format(L["result_total_score"], Format.Score(totalScore)))
    if (gs.lastStars or 0) > 0 then
        table.insert(lines, string.format(L["result_stars"], gs.lastStars, gs.bestStars or gs.lastStars))
    end
    if (gs.maxCombo or 0) > 1 then
        table.insert(lines, string.format(L["result_max_combo"], gs.maxCombo))
    end
    if (gs.stats.powerUpsUsed or 0) > 0 then
        table.insert(lines, string.format(L["result_powerups"], gs.stats.powerUpsUsed))
    end
    return lines
end

--- Level 1–49 geschafft: Weiter / Level neu starten / Beenden
function R:ShowLevelWin(gs, totalScore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "LEVELWIN"

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = L["result_level_win_title"],
        titleColor = { 0.3, 1, 0.3 },
        score      = gs.score,
        gameId     = "AZEROTHJEWELS",
        difficulty = gs.difficulty,
        result     = "WIN",
        lines      = ResultLines(gs, totalScore),
        L          = L,
        buttons    = UI.ResultDialogButtons.Level(L,
            function() ArcadiaNexus.AJ_Engine:ContinueToNextLevel() end,
            function() ArcadiaNexus.AJ_Engine:RestartLevel() end,
            function() ArcadiaNexus.AJ_Engine:StopGame() end
        ),
    })
end

--- Level 50 geschafft: Neu / Beenden
function R:ShowFinalWin(gs, totalScore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "WON"

    local buttons = UI.ResultDialogButtons.Arcade(L,
        function() ArcadiaNexus.AJ_Engine:RestartLevel() end,
        function() ArcadiaNexus.AJ_Engine:StopGame() end
    )
    local Levels = ArcadiaNexus.AJ_Levels
    if Levels and gs.level >= Levels.COUNT then
        table.insert(buttons, 1, {
            label = L["btn_endless"] or "Endlos",
            onClick = function()
                ArcadiaNexus.AJ_Engine:StartEndless({ skipMid = true, resetRun = true })
            end,
        })
    elseif Levels and gs.level < Levels.COUNT then
        table.insert(buttons, 1, {
            label = L["btn_continue_campaign"] or L["btn_next_level"],
            onClick = function() ArcadiaNexus.AJ_Engine:ContinueCampaign() end,
        })
    end

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = L["result_final_win_title"],
        titleColor = { 1, 0.84, 0 },
        score      = gs.score,
        gameId     = "AZEROTHJEWELS",
        difficulty = gs.difficulty,
        result     = "WIN",
        lines      = ResultLines(gs, totalScore),
        L          = L,
        buttons    = buttons,
    })
end

--- Endlos-Welle geschafft: nächste Welle / Welle neu / Beenden
function R:ShowEndlessWaveWin(gs, totalScore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "LEVELWIN"

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = L["result_endless_win_title"] or L["result_level_win_title"],
        titleColor = { 0.45, 0.85, 1 },
        score      = gs.score,
        gameId     = "AZEROTHJEWELS",
        difficulty = gs.difficulty,
        result     = "WIN",
        lines      = ResultLines(gs, totalScore),
        L          = L,
        buttons    = UI.ResultDialogButtons.Level(L,
            function() ArcadiaNexus.AJ_Engine:ContinueToNextLevel() end,
            function() ArcadiaNexus.AJ_Engine:RestartLevel() end,
            function() ArcadiaNexus.AJ_Engine:StopGame() end
        ),
    })
end

--- Game Over: Retry / Exit (Standard-Arcade-Flow)
function R:ShowGameOver(gs)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    local E  = ArcadiaNexus.AJ_Engine
    self.state = "GAMEOVER"

    local opts = {
        gameId     = "AZEROTHJEWELS",
        difficulty = gs.difficulty,
        result     = "LOSS",
        score      = gs.score,
        lines      = ResultLines(gs, (E and E.totalScore or 0)),
        L          = L,
        onRetry    = function()
            ArcadiaNexus.AJ_Engine:RestartLevel()
        end,
        onExit     = function()
            ArcadiaNexus.AJ_Engine:StopGame()
        end,
    }
    if gs.timedOut then
        opts.title      = L["state_timeout"]
        opts.titleColor = { 1, 0.4, 0 }
    end
    UI.ShowArcadeResult(self._fieldFrame, opts)
end

-- ============================================================
-- ANIMATIONEN
-- ============================================================
local function EaseInOut(t)
    return t < 0.5 and (2 * t * t) or (1 - (-2 * t + 2) ^ 2 / 2)
end

function R:AnimateSwap(r1, c1, r2, c2, gs, onDone)
    local cell1 = self._cells[r1] and self._cells[r1][c1]
    local cell2 = self._cells[r2] and self._cells[r2][c2]
    if not cell1 or not cell2 then
        if onDone then onDone() end
        return
    end
    if self:_ReducedMotion() then
        self:DrawGrid(gs)
        if onDone then onDone() end
        return
    end
    local cs = self._cellSize
    local sx1, sy1 = (c1 - 1) * cs, -(r1 - 1) * cs
    local sx2, sy2 = (c2 - 1) * cs, -(r2 - 1) * cs
    local dx, dy   = sx2 - sx1, sy2 - sy1
    local DURATION = 0.2
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / DURATION, 1)
        local fr = EaseInOut(t)
        cell1:ClearAllPoints()
        cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx1 + dx * fr, sy1 + dy * fr)
        cell2:ClearAllPoints()
        cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx2 - dx * fr, sy2 - dy * fr)
        if t >= 1 then
            StopAnimLoop()
            cell1:ClearAllPoints(); cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx1, sy1)
            cell2:ClearAllPoints(); cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx2, sy2)
            R:DrawGrid(gs)
            if onDone then onDone() end
        end
    end)
end

function R:AnimateInvalidSwap(r1, c1, r2, c2, onDone)
    local cell1 = self._cells[r1] and self._cells[r1][c1]
    if not cell1 then
        if onDone then onDone() end
        return
    end
    if self:_ReducedMotion() then
        if onDone then onDone() end
        return
    end
    local cs = self._cellSize
    local ox1, oy1 = (c1 - 1) * cs, -(r1 - 1) * cs
    local cell2    = self._cells[r2] and self._cells[r2][c2]
    local ox2, oy2 = cell2 and (c2 - 1) * cs or ox1, cell2 and -(r2 - 1) * cs or oy1
    local DURATION = 0.18
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / DURATION, 1)
        local shake = math.sin(t * math.pi * 6) * (1 - t) * cs * 0.18
        cell1:ClearAllPoints()
        cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox1 + shake, oy1)
        if cell2 then
            cell2:ClearAllPoints()
            cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox2 - shake, oy2)
        end
        if t >= 1 then
            StopAnimLoop()
            cell1:ClearAllPoints(); cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox1, oy1)
            if cell2 then
                cell2:ClearAllPoints(); cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox2, oy2)
            end
            if onDone then onDone() end
        end
    end)
end

-- Gemeinsame Pulse+Fade-Animation für Match- und PowerUp-Entfernung.
-- keys = { ["r,c"] = beliebig }
function R:_AnimateRemoval(keys, gs, onDone, fx)
    fx = fx or {}
    local cells = {}
    for key in pairs(keys) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        local cell = self._cells[r] and self._cells[r][c]
        if cell then
            cells[#cells + 1] = cell
            cell._glow:SetVertexColor(1, 0.9, 0.1, 0.5)
        end
    end
    local iceCells = {}
    for key in pairs(fx.iceKeys or {}) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        local cell = self._cells[r] and self._cells[r][c]
        if cell and cell._ice then
            iceCells[#iceCells + 1] = cell
        end
    end
    if #cells == 0 and #iceCells == 0 then
        if onDone then onDone() end
        return
    end
    local function finish()
        StopAnimLoop()
        for _, c in ipairs(cells) do
            c._tex:SetTexture(nil)
            c:SetAlpha(1)
            c:SetScale(1)
            c._glow:SetVertexColor(1, 0.9, 0.1, 0)
        end
        for _, c in ipairs(iceCells) do
            c._ice:SetVertexColor(1, 1, 1, 0)
        end
        if onDone then onDone() end
    end
    if self:_ReducedMotion() then
        finish()
        return
    end
    local combo = math.max(1, fx.combo or 1)
    local pulseAmp = 0.18 + math.min(0.22, (combo - 1) * 0.06)
    local PULSE, FADE = 0.12 + math.min(0.10, combo * 0.02), 0.18
    local elapsed, phase = 0, "pulse"
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        if phase == "pulse" then
            local t = math.min(elapsed / PULSE, 1)
            local sc = 1 + pulseAmp * math.sin(t * math.pi)
            local glowA = 0.45 + 0.25 * math.sin(t * math.pi)
            local cr = math.min(1, 0.7 + combo * 0.08)
            local cg = math.max(0.35, 0.95 - combo * 0.08)
            for _, c in ipairs(cells) do
                c:SetScale(sc)
                c._glow:SetVertexColor(cr, cg, 0.15, glowA)
            end
            local iceA = 0.55 + 0.45 * math.sin(t * math.pi)
            for _, c in ipairs(iceCells) do
                c._ice:SetVertexColor(1, 1, 1, iceA)
            end
            if t >= 1 then phase = "fade"; elapsed = 0 end
        else
            local t = math.min(elapsed / FADE, 1)
            local a = 1 - t
            for _, c in ipairs(cells) do
                c:SetAlpha(a)
                c._glow:SetVertexColor(1, 0.9, 0.1, a * 0.5)
            end
            for _, c in ipairs(iceCells) do
                c._ice:SetVertexColor(1, 1, 1, (1 - t) * 1)
            end
            if t >= 1 then
                finish()
            end
        end
    end)
end

function R:AnimatePulseAndFade(matches, gs, onDone, fx)
    self:_AnimateRemoval(matches, gs, onDone, fx)
end

function R:AnimatePowerUpRemoval(removedKeys, gs, onDone)
    self:_AnimateRemoval(removedKeys, gs, onDone)
end

--- Heiliger Strahl: kurzes Gold-Aufleuchten auf den Wildcard-Zellen.
function R:AnimateWildcardConversion(cellList, gs, onDone)
    local cells = {}
    for _, rc in ipairs(cellList) do
        local cell = self._cells[rc[1]] and self._cells[rc[1]][rc[2]]
        if cell then cells[#cells + 1] = cell end
    end
    self:DrawGrid(gs)
    if #cells == 0 or self:_ReducedMotion() then
        if onDone then onDone() end
        return
    end
    local DURATION = 0.5
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / DURATION, 1)
        local a = math.sin(t * math.pi) * 0.7
        for _, c in ipairs(cells) do
            c._glow:SetVertexColor(1, 0.85, 0.2, a)
        end
        if t >= 1 then
            StopAnimLoop()
            for _, c in ipairs(cells) do
                c._glow:SetVertexColor(1, 0.85, 0.2, 0)
            end
            if onDone then onDone() end
        end
    end)
end

function R:AnimateFall(fallInfo, gs, onDone)
    if not fallInfo or not gs or self:_ReducedMotion() then
        self:DrawGrid(gs)
        if onDone then onDone() end
        return
    end
    local cs = self._cellSize

    local fallers = {}
    local maxDist = 0

    for c = 1, gs.cols do
        local col = fallInfo[c]
        if col then
            for _, fInfo in ipairs(col) do
                local cell = self._cells[fInfo.toRow] and self._cells[fInfo.toRow][c]
                if cell then
                    ApplyGemVisual(cell._tex, fInfo.gemType)
                    cell._tex:SetAlpha(1)
                    cell:SetAlpha(1)
                    cell:SetScale(1)

                    local toY   = -(fInfo.toRow - 1) * cs
                    local fromY = -(fInfo.fromRow - 1) * cs
                    local isNew = fInfo.fromRow <= 0

                    if isNew then cell:SetAlpha(0) end

                    if fromY ~= toY then
                        cell:ClearAllPoints()
                        cell:SetPoint("TOPLEFT", R._board, "TOPLEFT", (c - 1) * cs, fromY)
                        local dist = math.abs(toY - fromY)
                        if dist > maxDist then maxDist = dist end
                        fallers[#fallers + 1] = {
                            cell  = cell,
                            fromY = fromY,
                            toY   = toY,
                            col   = c,
                            dist  = dist,
                            delay = (gs.rows - fInfo.toRow) * 0.012,
                            isNew = isNew,
                        }
                        if isNew then cell:SetScale(0.2) end
                    end
                end
            end
        end
    end

    if #fallers == 0 then
        self:DrawGrid(gs)
        if onDone then onDone() end
        return
    end

    local FALL_DUR = 0.22
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local allDone = true

        for _, fl in ipairs(fallers) do
            local localElapsed = elapsed - fl.delay
            if localElapsed >= 0 then
                local dur  = FALL_DUR * math.max(0.3, fl.dist / maxDist)
                local t    = math.min(localElapsed / dur, 1)
                local curY = fl.fromY + (fl.toY - fl.fromY) * (t * t)
                fl.cell:ClearAllPoints()
                fl.cell:SetPoint("TOPLEFT", R._board, "TOPLEFT", (fl.col - 1) * cs, curY)
                if fl.isNew then
                    fl.cell:SetAlpha(curY <= 0 and 1 or 0)
                    fl.cell:SetScale(0.2 + 0.8 * t)
                end
                if t < 1 then allDone = false end
            else
                allDone = false
            end
        end

        if allDone then
            StopAnimLoop()
            R:DrawGrid(gs)
            if onDone then onDone() end
        end
    end)
end

-- ============================================================
-- SLASH-BEFEHL
-- ============================================================
SLASH_ARCADIAAZEROTHJEWELS1 = "/azerothjewels"
SLASH_ARCADIAAZEROTHJEWELS2 = "/ajewels"
SlashCmdList["ARCADIAAZEROTHJEWELS"] = function()
    local main = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetMainFrame
        and _G.ArcadiaNexusUI.GetMainFrame()
    if main and not main:IsShown() and _G.Nexus_UI and _G.Nexus_UI.Toggle then
        _G.Nexus_UI.Toggle()
    end
    if _G.Nexus_UI and _G.Nexus_UI.SetTab then
        _G.Nexus_UI.SetTab("GAMES")
    end
    local fn = ArcadiaNexus.UI and ArcadiaNexus.UI._ActivateGameFn
    if fn then fn("AZEROTHJEWELS") end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "AZEROTHJEWELS",
    label     = "Azeroth Jewels",
    category  = "DENKSPIELE",
    renderer  = "AJ_Renderer",
    engine    = "AJ_Engine",
    container = "_ajContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothJewels\\assets\\logo\\aj_logo",
    xp        = 10,
})
