-- ============================================================
--  AlchemistsSort – Renderer.lua
--  UI: Grid, Flaschen, Layer, Animation Phase-1, Overlays, HUD.
--  KEINE Spiellogik hier.
--
--  Controls: CreateGameControlsBar "wide5"
--    Seg.1 Reset | Seg.2 Undo | Seg.3 Start/Beenden | Seg.4 Tipp | Seg.5 +Röhre
--  Save-Slots: „Spiel starten“ → UI.CreateSaveSlotMenu (Logo aus, Slot-Menü ein)
--
--  Flaschen-Layout:
--    Immer 2 Reihen. Reihe 1: ceil(N/2) Flaschen, Reihe 2: rest.
--    Flasche: 48×128 px (Blueprint). Gap dynamisch berechnet.
--
--  Schicht-Aufbau pro Flasche:
--    _layers[1..5]: WHITE8X8-Texturen (unten→oben), Farbe via SetVertexColor
--    _bottleTex:    bottle.tga als OVERLAY (Glas-Effekt)
--    _selTex:       Highlight-Textur für Auswahl
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Renderer = {}
local R = ArcadiaNexus.ALS_Renderer

-- ── Registrierung ─────────────────────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "ALCHEMISTSSORT",
    label     = "Alchemist's Sort",
    category  = "RAETSEL",
    renderer  = "ALS_Renderer",
    engine    = "ALS_Engine",
    container = "_alsContainer",
})

-- ============================================================
-- CFG – alle Layout-Konstanten zentral
-- ============================================================
local CFG = {
    -- Spielfeld (_playfield, TOPLEFT-Anker)
    field_ofs_x  = 0,
    field_ofs_y  = 20,
    field_w      = 600,
    field_h      = 424,

    -- Hintergrund (relativ zu _playfield TOPLEFT)
    bg_w         = 660,
    bg_h         = 484,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,

    -- Border (relativ zu _container CENTER)
    border_w     = 795,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 16,

    -- Logo (relativ zu _playfield CENTER)
    logo_w       = 320,
    logo_h       = 320,
    logo_ofs_x   = 0,
    logo_ofs_y   = -30,

    -- HUD – Level-Label (TOPLEFT relativ zu _container)
    hud_level_x  = 260,
    hud_level_y  = -385,
    hud_level_w  = 80,
    hud_level_h  = 40,

    -- HUD – Timer-Box (TOPLEFT relativ zu _container)
    hud_timer_x  = 180,
    hud_timer_y  = -385,
    hud_timer_w  = 80,
    hud_timer_h  = 40,

    -- HUD – Counter-Box (TOPRIGHT relativ zu _container)
    hud_cnt_x    = -180,   -- TOPRIGHT-Offset (negativ = von rechts)
    hud_cnt_y    = -385,
    hud_cnt_w    = 80,
    hud_cnt_h    = 40,

    -- Lade-Overlay
    loading_w    = 280,
    loading_h    = 80,
    loading_ofs_x = 0,
    loading_ofs_y = -25,
    loading_title_y = 0,
    loading_dots_y  = -14,

    -- Controls-Widgets
    btn_w        = 96,
    btn_h        = 32,

    -- Slot-Menü
    slot_row_w   = 320,
    slot_row_h   = 52,
    slot_row_gap = 60,
    slot_row_x   = 0,
    slot_title_y = -120,
    slot_first_y = -150,
    slot_btn_y   = 18,

    -- Win-Overlay (Nonogram-Muster)
    ov_w         = 320,
    ov_h         = 200,
    ov_ofs_x     = 0,
    ov_ofs_y     = 0,
    ov_title_y   = 55,
    ov_sub_gap   = -14,
    ov_btn_gap   = -20,
    ov_btn_w     = 160,
    ov_btn_h     = 30,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local ASSETS = {
    bottle = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\tiles\\bottle",
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\assets\\background\\bg_as",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\assets\\border\\border_as",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\assets\\logo\\logo_as",
}

-- ── Flaschen-Konstanten ────────────────────────────────────────
local TUBE_CAPACITY = 5
local BOTTLE_W  = 48
local BOTTLE_H  = 128
local ROW_GAP   = 24
local LAYER_PAD = 2
local FILL_MAX_Y = BOTTLE_H - 25

-- Animations-Konstanten
local ANIM_STEPS    = 8
local ANIM_INTERVAL = 0.04

-- ── Frames / State ────────────────────────────────────────────
R._container    = nil
R._canvas       = nil
R._playfield    = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R._tubeFrames   = {}
R._selected     = nil
R._hud          = {}
R._confirmFrame   = nil
R._loadingOverlay = nil
R._loadingFS      = nil
R._loadingDotsFS  = nil
R._loadingDotTimer= nil
R._loadingDotTick = 0
R._feedbackFS   = nil
R._feedbackTimer = 0
R._controlsFrame = nil
R._slotMenu      = nil
R._exitBtn       = nil

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateSlotMenu()
    self:_CreateControls()
    self:_CreateOverlays()
    self:EnterIdle()
end

-- ── Hauptframe ────────────────────────────────────────────────
function R:_CreateMainFrame()
    if self._container then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_ALS_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self._container = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._alsContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("ALCHEMISTSSORT", ArcadiaNexus.ALS_Engine, function(E)
            if E.state ~= "IDLE" then
                E:SaveAndStop()
            end
        end)
        if R._slotMenu and R._slotMenu:IsShown() then
            R:EnterIdle()
        end
    end)

    -- Spielfeld-Subframe (alle Flaschen hängen hier)
    local pf = CreateFrame("Frame", nil, self._canvas)
    pf:SetPoint("TOPLEFT", self._canvas, "TOPLEFT", CFG.field_ofs_x, CFG.field_ofs_y)
    pf:SetSize(CFG.field_w, CFG.field_h)
    self._playfield = pf

    -- Unsichtbarer Button über dem Spielfeld: Rechtsklick hebt Auswahl auf
    local pfBtn = CreateFrame("Button", nil, pf)
    pfBtn:SetAllPoints(pf)
    pfBtn:SetFrameLevel(pf:GetFrameLevel() + 1)
    pfBtn:EnableMouse(true)
    pfBtn:RegisterForClicks("RightButtonUp")
    pfBtn:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            ArcadiaNexus.ALS_Engine:ClearSelection()
        end
    end)

    -- Spielfeld-Hintergrund
    local bgTex = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetSize(CFG.bg_w, CFG.bg_h)
    bgTex:SetPoint("TOPLEFT", pf, "TOPLEFT", CFG.bg_ofs_x, -CFG.bg_ofs_y)
    bgTex:SetTexture(ASSETS.bg)
    bgTex:SetAlpha(CFG.bg_alpha)
    self._bgTex = bgTex
end

-- ── Border ────────────────────────────────────────────────────
function R:_CreateBorderFrame()
    local canvas      = self._canvas
    local borderFrame = CreateFrame("Frame", nil, canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", canvas, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(canvas:GetFrameLevel() + 10)
    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(ASSETS.border)
    tex:SetAllPoints(borderFrame)
    self._borderFrame = borderFrame
    self._borderTex   = tex
end

-- ── Logo ──────────────────────────────────────────────────────
function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._playfield,
        ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ── HUD (Timer, Züge, Level) ──────────────────────────────────
function R:_CreateHUD()
    local canvas = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    -- Level-Box (identisches Styling wie Timer- und Counter-Box)
    local lvlBox = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    lvlBox:SetSize(CFG.hud_level_w, CFG.hud_level_h)
    lvlBox:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.hud_level_x, CFG.hud_level_y)
    lvlBox:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    lvlBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    lvlBox:SetBackdropBorderColor(0.3, 0.25, 0.1, 1)

    local lvlLbl = lvlBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lvlLbl:SetPoint("TOP", lvlBox, "TOP", 0, -4)
    lvlLbl:SetText(L and L.lbl_level or "Level")
    lvlLbl:SetTextColor(0.7, 0.65, 0.5)
    local lvlVal = lvlBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lvlVal:SetPoint("BOTTOM", lvlBox, "BOTTOM", 0, 4)
    lvlVal:SetText("1")
    self._hud.level    = lvlVal
    self._hud.levelBox = lvlBox

    -- Timer-Box
    local timerBox = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    timerBox:SetSize(CFG.hud_timer_w, CFG.hud_timer_h)
    timerBox:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.hud_timer_x, CFG.hud_timer_y)
    timerBox:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    timerBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    timerBox:SetBackdropBorderColor(0.3, 0.25, 0.1, 1)

    local timerLbl = timerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerLbl:SetPoint("TOP", timerBox, "TOP", 0, -4)
    timerLbl:SetText(L and L.lbl_time or "Zeit")
    timerLbl:SetTextColor(0.7, 0.65, 0.5)
    local timerVal = timerBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerVal:SetPoint("BOTTOM", timerBox, "BOTTOM", 0, 4)
    timerVal:SetText("0:00")
    self._hud.timer    = timerVal
    self._hud.timerBox = timerBox

    -- Counter-Box (Züge)
    local cntBox = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    cntBox:SetSize(CFG.hud_cnt_w, CFG.hud_cnt_h)
    cntBox:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", CFG.hud_cnt_x, CFG.hud_cnt_y)
    cntBox:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    cntBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    cntBox:SetBackdropBorderColor(0.3, 0.25, 0.1, 1)

    local cntLbl = cntBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("TOP", cntBox, "TOP", 0, -4)
    cntLbl:SetText(L and L.lbl_moves or "Züge")
    cntLbl:SetTextColor(0.7, 0.65, 0.5)
    local cntVal = cntBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cntVal:SetPoint("BOTTOM", cntBox, "BOTTOM", 0, 4)
    cntVal:SetText("0")
    self._hud.moves  = cntVal
    self._hud.cntBox = cntBox

    -- Feedback-FontString (temporäre Meldungen)
    local fbFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fbFS:SetPoint("TOP", self._playfield, "TOP", 0, -8)
    fbFS:SetTextColor(1, 0.3, 0.3)
    fbFS:Hide()
    self._feedbackFS = fbFS
end

-- ── Controls (wide5) ─────────────────────────────────────────
function R:_CreateControls()
    if self._controlsFrame then return end

    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    local btn_w = CFG.btn_w
    local btn_h = CFG.btn_h

    local bar = UI.CreateGameControlsBar(self._container, "wide5")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Segment 1: Reset (nur während des Spiels)
    local btnReset = UI.CreateArcadiaButton(cf, L and L.btn_reset or "Reset", btn_w, btn_h)
    btnReset:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[1], bar.y.button)
    btnReset:SetScript("OnClick", function()
        ArcadiaNexus.ALS_Engine:ResetLevel()
    end)
    self._btnReset = btnReset

    -- Segment 2: Undo
    local btnUndo = UI.CreateArcadiaButton(cf, L and L.lbl_undo_left:format(3) or "Undo(3)", btn_w, btn_h)
    btnUndo:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    btnUndo:SetScript("OnClick", function()
        ArcadiaNexus.ALS_Engine:Undo()
    end)
    self._btnUndo = btnUndo

    -- Segment 3: Start (IDLE) / Beenden (Menü + Spiel)
    local btnStart = UI.CreateArcadiaButton(cf, L and L.btn_start or "Spiel starten", 144, btn_h)
    btnStart:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    btnStart:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._btnStart = btnStart

    local btnExit = UI.CreateArcadiaButton(cf, L and L.btn_exit or "Beenden", 144, btn_h)
    btnExit:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    btnExit:SetScript("OnClick", function()
        if R._slotMenu and R._slotMenu:IsShown() then
            R:EnterIdle()
            return
        end
        local E = ArcadiaNexus.ALS_Engine
        if E then E:SaveAndStop() end
    end)
    btnExit:Hide()
    self._exitBtn = btnExit

    -- Segment 4: Tipp
    local btnHint = UI.CreateArcadiaButton(cf, L and L.lbl_hint_left:format(3) or "Tipp(3)", btn_w, btn_h)
    btnHint:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.button)
    btnHint:SetScript("OnClick", function()
        ArcadiaNexus.ALS_Engine:RequestHint()
    end)
    self._btnHint = btnHint

    -- Segment 5: + Röhre
    local btnAdd = UI.CreateArcadiaButton(cf, L and L.btn_add_tube or "+ Röhre", btn_w, btn_h)
    btnAdd:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[5], bar.y.button)
    btnAdd:SetScript("OnClick", function()
        ArcadiaNexus.ALS_Engine:AddEmptyTube()
    end)
    self._btnAdd = btnAdd
end

-- ── Overlays ──────────────────────────────────────────────────
function R:_CreateOverlays()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    -- Lade-Overlay (asynchrone Level-Generierung)
    local lo = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    lo:SetSize(CFG.loading_w, CFG.loading_h)
    lo:SetPoint("CENTER", self._playfield, "CENTER", CFG.loading_ofs_x, CFG.loading_ofs_y)
    lo:SetFrameLevel(canvas:GetFrameLevel() + 40)
    lo:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    lo:SetBackdropColor(0.04, 0.03, 0.02, 0.92)
    lo:SetBackdropBorderColor(0.50, 0.42, 0.18, 0.9)
    lo:Hide()
    self._loadingOverlay = lo

    local loadingFS = lo:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    loadingFS:SetPoint("CENTER", lo, "CENTER", 0, CFG.loading_title_y)
    loadingFS:SetTextColor(0.85, 0.75, 0.40)
    loadingFS:SetText("")
    self._loadingFS = loadingFS

    local loadingDots = lo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingDots:SetPoint("CENTER", lo, "CENTER", 0, CFG.loading_dots_y)
    loadingDots:SetTextColor(0.55, 0.50, 0.35)
    loadingDots:SetText("")
    self._loadingDotsFS = loadingDots

    -- Confirm-Overlay (Reset)
    local co = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    co:SetSize(260, 80)
    co:SetPoint("CENTER", self._playfield, "CENTER", 0, 0)
    co:SetFrameLevel(canvas:GetFrameLevel() + 30)
    co:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    co:SetBackdropColor(0.08, 0.06, 0.04, 0.95)
    co:SetBackdropBorderColor(0.5, 0.4, 0.15, 1)
    co:Hide()
    self._confirmFrame = co

    local confText = co:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confText:SetPoint("TOP", co, "TOP", 0, -12)
    confText:SetText(L and L.confirm_reset or "Level neu starten?")
    confText:SetTextColor(0.9, 0.85, 0.65)

    local btnYes = UI.CreateArcadiaButton(co, L and L.confirm_yes or "Ja", 80, 28)
    btnYes:SetPoint("BOTTOMLEFT", co, "BOTTOMLEFT", 20, 10)
    local btnNo = UI.CreateArcadiaButton(co, L and L.confirm_no or "Nein", 80, 28)
    btnNo:SetPoint("BOTTOMRIGHT", co, "BOTTOMRIGHT", -20, 10)
    self._confirmYes = btnYes
    self._confirmNo  = btnNo
end

-- ── Lade-Overlay ──────────────────────────────────────────────

function R:ShowLoading()
    if not self._loadingOverlay then return end
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local baseText = (L and L.lbl_loading) or "Bereite Rätsel vor"
    self._loadingFS:SetText(baseText)
    self._loadingDotsFS:SetText("")
    self._loadingOverlay:Show()

    self._loadingDotTick = 0
    self._loadingDotTimer = C_Timer.NewTicker(0.4, function()
        if not self._loadingOverlay or not self._loadingOverlay:IsShown() then return end
        self._loadingDotTick = (self._loadingDotTick or 0) + 1
        local dots = string.rep(".", (self._loadingDotTick % 4))
        self._loadingDotsFS:SetText(dots ~= "" and dots or " ")
    end)
end

function R:HideLoading()
    if not self._loadingOverlay then return end
    if self._loadingDotTimer then
        self._loadingDotTimer:Cancel()
        self._loadingDotTimer = nil
    end
    self._loadingOverlay:Hide()
end

-- ── Grid aufbauen ─────────────────────────────────────────────

function R:BuildGrid(tubes, numTubes)
    for i, tf in ipairs(self._tubeFrames) do
        if i <= numTubes then
            tf:Show()
        else
            tf:Hide()
        end
    end

    local row1Count = math.ceil(numTubes / 2)
    local row2Count = numTubes - row1Count

    local avail = CFG.field_w - 32
    local function CalcLayout(count)
        if count == 0 then return 0, 0 end
        local totalW = count * BOTTLE_W
        local gap    = count > 1 and math.floor((avail - totalW) / (count - 1)) or 0
        local startX = math.floor((CFG.field_w - (count * BOTTLE_W + (count - 1) * gap)) / 2)
        return startX, gap
    end

    local r1StartX, r1Gap = CalcLayout(row1Count)
    local r2StartX, r2Gap = CalcLayout(row2Count)

    local totalRowH = BOTTLE_H * 2 + ROW_GAP
    local r1Y = math.floor((CFG.field_h - totalRowH) / 2)
    local r2Y = r1Y + BOTTLE_H + ROW_GAP

    for i = 1, numTubes do
        local row    = i <= row1Count and 1 or 2
        local col    = row == 1 and i or (i - row1Count)
        local startX = row == 1 and r1StartX or r2StartX
        local gap    = row == 1 and r1Gap    or r2Gap
        local posY   = row == 1 and r1Y      or r2Y
        local posX   = startX + (col - 1) * (BOTTLE_W + gap)

        local tf = self._tubeFrames[i]
        if not tf then
            tf = self:_CreateTubeFrame(i)
            self._tubeFrames[i] = tf
        end

        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", self._playfield, "TOPLEFT", posX, -posY)
        tf:SetSize(BOTTLE_W, BOTTLE_H)
        tf:Show()
        tf:SetFrameLevel(self._playfield:GetFrameLevel() + 2 + row)
    end
end

-- ── Flasche erstellen ─────────────────────────────────────────

function R:_CreateTubeFrame(idx)
    local pf = self._playfield
    local tf = CreateFrame("Button", nil, pf, "BackdropTemplate")
    tf:SetSize(BOTTLE_W, BOTTLE_H)
    tf:SetFrameLevel(pf:GetFrameLevel() + 2)
    tf:RegisterForClicks("LeftButtonUp")

    tf:SetScript("OnClick", function()
        ArcadiaNexus.ALS_Engine:OnTubeClicked(idx)
    end)

    local fillHeight = FILL_MAX_Y - LAYER_PAD
    local layerH     = math.floor(fillHeight / TUBE_CAPACITY)
    tf._layers = {}
    for i = 1, TUBE_CAPACITY do
        local layer = tf:CreateTexture(nil, "BACKGROUND")
        layer:SetTexture("Interface\\Buttons\\WHITE8X8")
        layer:SetHeight(layerH)
        local yOff = LAYER_PAD + (i - 1) * layerH
        layer:SetPoint("BOTTOMLEFT",  tf, "BOTTOMLEFT",  LAYER_PAD,  yOff)
        layer:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -LAYER_PAD, yOff)
        layer:Hide()
        tf._layers[i] = layer
    end

    local bottleTex = tf:CreateTexture(nil, "OVERLAY")
    bottleTex:SetTexture(ASSETS.bottle)
    bottleTex:SetAllPoints(tf)
    bottleTex:SetAlpha(ArcadiaNexus.ALS_Colors.NORMAL_ALPHA)
    tf._bottleTex = bottleTex

    local selH = math.floor((FILL_MAX_Y - LAYER_PAD) / TUBE_CAPACITY) * TUBE_CAPACITY
    local selTex = tf:CreateTexture(nil, "BORDER")
    selTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    selTex:SetPoint("BOTTOMLEFT",  tf, "BOTTOMLEFT",  LAYER_PAD,  LAYER_PAD)
    selTex:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -LAYER_PAD, LAYER_PAD)
    selTex:SetHeight(selH)
    selTex:SetVertexColor(1, 1, 0.3, 0.25)
    selTex:Hide()
    tf._selTex = selTex

    tf._idx = idx
    return tf
end

-- ── Flasche aktualisieren ─────────────────────────────────────

function R:RefreshTube(tubeIdx)
    local tf   = self._tubeFrames[tubeIdx]
    local tube = ArcadiaNexus.ALS_Engine._tubes and ArcadiaNexus.ALS_Engine._tubes[tubeIdx]
    if not tf or not tube then return end

    local Colors = ArcadiaNexus.ALS_Colors
    local filled = #tube

    for i = 1, TUBE_CAPACITY do
        local layer = tf._layers[i]
        if i <= filled then
            local tIdx = filled + 1 - i
            local c = Colors:Get(tube[tIdx])
            layer:SetVertexColor(c[1], c[2], c[3], 1)
            layer:Show()
        else
            layer:Hide()
        end
    end

    local Logic = ArcadiaNexus.ALS_Logic
    if #tube == TUBE_CAPACITY and Logic:TopCount(tube) == TUBE_CAPACITY then
        tf._bottleTex:SetAlpha(Colors.SOLVED_ALPHA)
    else
        tf._bottleTex:SetAlpha(Colors.NORMAL_ALPHA)
    end
end

function R:RefreshAll(tubes)
    for i = 1, #self._tubeFrames do
        if self._tubeFrames[i]:IsShown() then
            self:RefreshTube(i)
        end
    end
end

-- ── Auswahl-Highlight ─────────────────────────────────────────

function R:SetSelected(tubeIdx)
    for i, tf in ipairs(self._tubeFrames) do
        if tf._selTex then
            if i == tubeIdx then
                tf._selTex:Show()
                tf._bottleTex:SetAlpha(ArcadiaNexus.ALS_Colors.SELECTED_ALPHA)
            else
                tf._selTex:Hide()
            end
        end
    end
end

-- ── Animation Phase 1 (Füllstand) ────────────────────────────

function R:AnimatePour(srcIdx, dstIdx, topColor, layers, onDone)
    local srcTF = self._tubeFrames[srcIdx]
    local dstTF = self._tubeFrames[dstIdx]
    if not srcTF or not dstTF then
        if onDone then onDone() end
        return
    end

    local E      = ArcadiaNexus.ALS_Engine
    local srcTube = E._tubes[srcIdx]
    local dstTube = E._tubes[dstIdx]

    local srcStart = #srcTube
    local dstStart = #dstTube

    local Colors = ArcadiaNexus.ALS_Colors
    local c      = Colors:Get(topColor)
    local gen    = E._timerGuard:Generation()

    local STEP_TIME = 0.08

    local function DoneAll()
        for _, lyr in ipairs(srcTF._layers) do lyr:SetAlpha(1) end
        for _, lyr in ipairs(dstTF._layers) do lyr:SetAlpha(1) end
        if onDone then onDone() end
    end

    local function FillDst(step)
        if gen ~= E._timerGuard:Generation() then return end
        local layerI = dstStart + step
        local layer  = dstTF._layers[layerI]
        if layer then
            layer:SetTexture("Interface\\Buttons\\WHITE8X8")
            layer:SetVertexColor(c[1], c[2], c[3], 1)
            layer:Show()
            layer:SetAlpha(1)
        end
        if step < layers then
            E._timerGuard:After(STEP_TIME, function() FillDst(step + 1) end)
        else
            DoneAll()
        end
    end

    local function DrainSrc(step)
        if gen ~= E._timerGuard:Generation() then return end
        local layerI = srcStart - step + 1
        local layer  = srcTF._layers[layerI]
        if layer then
            layer:SetAlpha(0)
        end
        if step < layers then
            E._timerGuard:After(STEP_TIME, function() DrainSrc(step + 1) end)
        else
            E._timerGuard:After(STEP_TIME * 0.5, function()
                if gen ~= E._timerGuard:Generation() then return end
                FillDst(1)
            end)
        end
    end

    local S = ArcadiaNexus.ALS_Settings
    if S and S:Get("soundEnabled") and S:Get("soundOnPour") then
        PlaySoundFile("Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\sounds\\flow.wav", "SFX")
    end
    DrainSrc(1)
end

-- ── Shake (ungültiger Zug) ────────────────────────────────────

function R:ShakeTube(tubeIdx)
    local tf = self._tubeFrames[tubeIdx]
    if not tf then return end

    local origOffX = tf:GetLeft() - self._playfield:GetLeft()
    local origOffY = tf:GetTop()  - self._playfield:GetTop()

    local offsets = { 5, -5, 4, -4, 2, -2, 1, 0 }
    local step    = 0

    local function DoShake()
        step = step + 1
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", self._playfield, "TOPLEFT",
            origOffX + offsets[step], origOffY)
        if step < #offsets then
            C_Timer.After(0.04, DoShake)
        end
    end
    DoShake()
end

-- ── Tipp-Highlight ────────────────────────────────────────────

function R:ShowHint(srcIdx, dstIdx, onDone)
    local srcTF = self._tubeFrames[srcIdx]
    local dstTF = self._tubeFrames[dstIdx]
    if not srcTF or not dstTF then
        if onDone then onDone() end
        return
    end

    local Colors = ArcadiaNexus.ALS_Colors
    local function Highlight(tf, on)
        if tf._selTex then
            if on then
                tf._selTex:SetVertexColor(Colors.HINT_COLOR[1], Colors.HINT_COLOR[2], Colors.HINT_COLOR[3], Colors.HINT_ALPHA)
                tf._selTex:Show()
            else
                tf._selTex:SetVertexColor(1, 1, 0.3, 0.25)
                tf._selTex:Hide()
            end
        end
    end

    Highlight(srcTF, true)
    Highlight(dstTF, true)

    C_Timer.After(2.0, function()
        Highlight(srcTF, false)
        Highlight(dstTF, false)
        if onDone then onDone() end
    end)
end

-- ── Feedback-Meldung ──────────────────────────────────────────

function R:ShowFeedback(msgKey)
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local msg = L and L[msgKey] or msgKey
    if not self._feedbackFS then return end
    self._feedbackFS:SetText(msg)
    self._feedbackFS:Show()
    C_Timer.After(1.5, function()
        if self._feedbackFS then self._feedbackFS:Hide() end
    end)
end

-- ── HUD aktualisieren ─────────────────────────────────────────

function R:UpdateHUD()
    local E = ArcadiaNexus.ALS_Engine
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    if self._hud.level then
        local lvl = ArcadiaNexus.ALS_Settings:GetCurrentLevel()
        self._hud.level:SetText(tostring(lvl))
    end

    if self._hud.timer then
        local sec = math.floor(E:GetElapsed())
        self._hud.timer:SetText(ArcadiaNexus.Format.SecondsMMSS(sec, false))
    end

    if self._hud.moves then
        self._hud.moves:SetText(tostring(E._moveCount or 0))
    end

    if self._btnUndo and L then
        local u = E._undosLeft or 0
        if u > 0 then
            self._btnUndo:SetLabel(L.lbl_undo_left:format(u))
            self._btnUndo:SetEnabled(true)
        else
        self._btnUndo:SetLabel(L.lbl_undo_none or "Undo")
            self._btnUndo:SetEnabled(false)
        end
    end

    if self._btnHint and L then
        local h = E._hintsLeft or 0
        if h > 0 then
            self._btnHint:SetLabel(L.lbl_hint_left:format(h))
            self._btnHint:SetEnabled(true)
        else
        self._btnHint:SetLabel(L.lbl_hint_none or "Tipp")
            self._btnHint:SetEnabled(false)
        end
    end

    if self._btnAdd then
        self._btnAdd:SetEnabled(not E._addedTube)
    end
end

-- ── Win-Overlay ───────────────────────────────────────────────

function R:ShowWinOverlay(score, moves, elapsed)
    local parent = self._playfield
    if not parent then return end
    local L  = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local UI = ArcadiaNexus.UI
    local sec     = math.floor(elapsed)
    local timeStr = ArcadiaNexus.Format.SecondsMMSS(sec, false)
    local lines = {}
    if L and L.win_moves then
        lines[#lines + 1] = string.format(L.win_moves, moves)
    else
        lines[#lines + 1] = "Züge: " .. tostring(moves)
    end
    if L and L.win_time then
        lines[#lines + 1] = string.format(L.win_time, timeStr)
    else
        lines[#lines + 1] = timeStr
    end
    UI.ShowArcadeResult(parent, {
        title      = L and L.state_win or "Gelöst!",
        titleColor = { 1, 0.85, 0.1 },
        score      = score,
        gameId     = "ALCHEMISTSSORT",
        result     = "WIN",
        lines      = lines,
        L          = L,
        buttons    = {
            {
                label   = L and L.btn_next_level or "Nächstes Level",
                onClick = function()
                    local E = ArcadiaNexus.ALS_Engine
                    if E then E:StartLevel(ArcadiaNexus.ALS_Settings:GetCurrentLevel()) end
                end,
            },
        },
    })
end

-- ── Confirm-Reset ─────────────────────────────────────────────

function R:ShowConfirmReset(onConfirm)
    local co = self._confirmFrame
    if not co then
        if onConfirm then onConfirm() end
        return
    end

    co:Show()
    if self._confirmYes then
        self._confirmYes:SetScript("OnClick", function()
            co:Hide()
            if onConfirm then onConfirm() end
        end)
    end
    if self._confirmNo then
        self._confirmNo:SetScript("OnClick", function()
            co:Hide()
        end)
    end
end

-- ── Slot-Menü ─────────────────────────────────────────────────

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local S  = ArcadiaNexus.ALS_Settings
    if not UI or not UI.CreateSaveSlotMenu or not self._playfield then return end

    self._slotMenu = UI.CreateSaveSlotMenu({
        parent        = self._playfield,
        confirmParent = self._playfield,
        maxSlots      = (S and S.MAX_SLOTS) or 3,
        L             = L,
        title         = L and L.menu_title,
        loadSlot      = function(slot) return S and S:LoadSlot(slot) end,
        deleteSlot    = function(slot) if S then S:DeleteSlot(slot) end end,
        formatInfo    = function(save, loc)
            return string.format(loc.slot_info or "Level %d", save.currentLevel or 1)
        end,
        isPaused      = function(save) return save.midGame ~= nil end,
        formatPaused  = function(save, loc)
            return string.format(loc.slot_paused or "Level %d läuft", save.currentLevel or 1)
        end,
        onNewGame     = function(slot)
            local E = ArcadiaNexus.ALS_Engine
            if E then E:StartGame({ slot = slot, mode = "new" }) end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.ALS_Engine
            if E then E:StartGame({ slot = slot, mode = "continue" }) end
        end,
        layout = {
            rowW    = CFG.slot_row_w,
            rowH    = CFG.slot_row_h,
            rowGap  = CFG.slot_row_gap,
            rowOfsX = CFG.slot_row_x,
            titleY  = CFG.slot_title_y,
            firstY  = CFG.slot_first_y,
            btnY    = CFG.slot_btn_y,
            btnW    = 144,
            btnH    = CFG.btn_h,
        },
    })
end

function R:EnterSlotMenu()
    ArcadiaNexus.UI.HideResultDialog(self._playfield)
    if self._logoTex  then self._logoTex:Hide()  end
    if self._btnStart then self._btnStart:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._slotMenu then self._slotMenu:Show() end
end

-- ── State-Changes ─────────────────────────────────────────────

function R:OnStateChanged(newState)
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    if newState ~= "WIN" then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end

    if newState == "PLAYING" then
        if self._logoTex then self._logoTex:Hide() end
        if self._hud.levelBox then self._hud.levelBox:Show() end
        if self._hud.timerBox then self._hud.timerBox:Show() end
        if self._hud.cntBox   then self._hud.cntBox:Show()   end
        if self._slotMenu then self._slotMenu:Hide() end
        if self._btnStart then self._btnStart:Hide() end
        if self._exitBtn  then self._exitBtn:Show()  end
        if self._btnReset then self._btnReset:SetShown(true) end
        if self._btnUndo  then self._btnUndo:SetShown(true)  end
        if self._btnHint  then self._btnHint:SetShown(true)  end
        if self._btnAdd   then self._btnAdd:SetShown(true)   end
    end

    if newState == "IDLE" then
        self:EnterIdle()
        return
    end

    if self._btnStart then self._btnStart:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end

    local locked = (newState == "POURING")
    if self._btnReset then self._btnReset:SetEnabled(not locked) end
    if self._btnUndo  then
        local u = ArcadiaNexus.ALS_Engine._undosLeft or 0
        self._btnUndo:SetEnabled(not locked and u > 0)
    end
    if self._btnHint  then
        local h = ArcadiaNexus.ALS_Engine._hintsLeft or 0
        self._btnHint:SetEnabled(not locked and h > 0)
    end
    if self._btnAdd then
        self._btnAdd:SetEnabled(not locked and not ArcadiaNexus.ALS_Engine._addedTube)
    end
end

function R:EnterIdle()
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    -- Flaschen ausblenden
    for _, tf in ipairs(self._tubeFrames) do
        tf:Hide()
    end
    -- HUD-Boxen ausblenden
    if self._hud.levelBox then self._hud.levelBox:Hide() end
    if self._hud.timerBox then self._hud.timerBox:Hide() end
    if self._hud.cntBox   then self._hud.cntBox:Hide()   end
    -- Overlays zurücksetzen
    ArcadiaNexus.UI.HideResultDialog(self._playfield)
    if ArcadiaNexus.UI.HideChoicePopup then
        ArcadiaNexus.UI.HideChoicePopup(self._playfield)
    end
    if self._confirmFrame then self._confirmFrame:Hide() end
    if self._feedbackFS   then self._feedbackFS:Hide()   end
    self:HideLoading()
    -- Logo einblenden
    if self._logoTex then self._logoTex:Show() end
    if self._slotMenu then self._slotMenu:Hide() end
    if self._btnStart then
        self._btnStart:SetLabel(L and L.btn_start or "Spiel starten")
        self._btnStart:Show()
    end
    if self._exitBtn then self._exitBtn:Hide() end
    if self._btnReset then self._btnReset:SetShown(false) end
    if self._btnUndo  then self._btnUndo:SetShown(false)  end
    if self._btnHint  then self._btnHint:SetShown(false)  end
    if self._btnAdd   then self._btnAdd:SetShown(false)   end
end
