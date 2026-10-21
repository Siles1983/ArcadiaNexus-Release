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
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\assets\\logo\\logo_as",
    xp        = 10,
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
    hud_alpha = 0.75,
    help_size = 32, help_icon = 24, help_y = -389, help_left = 92, help_right = 436,
    anim_left = 16, anim_right = 584, anim_top = 50, anim_bottom = 368,
    anim_duration = 0.7, anim_angle = 1.05,
    pour_drop_w = 16, pour_drop_h = 32, pour_drop_reach = 28,
    btn_w        = 96,
    btn_h        = 32,

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
    drop   = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\tiles\\pour_drop",
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
R._hintGuard    = ArcadiaNexus.TimerGuard.New()
R._feedbackGuard = ArcadiaNexus.TimerGuard.New()
R._hintToken    = 0
R._hintFrames   = nil
R._controlsFrame = nil
R._slotMenu      = nil
R._exitBtn       = nil
R._levelSelect   = nil

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateSlotMenu()
    self:_CreateLevelSelect()
    self:_CreateControls()
    self:_CreateOverlays()
    self:EnterIdle()
end

-- ── Hauptframe ────────────────────────────────────────────────
function R:HandleViewHide()
    -- Terminal runs already released their session; cancel their presentation explicitly.
    local E=ArcadiaNexus.ALS_Engine
    if not E._sessionId and E._result and (E.state=="WIN" or E.state=="RESULT_PENDING") then
        E:StopGame()
    end
    if ArcadiaNexus.ALS_Engine.state == "LEVEL_SELECT" then
        ArcadiaNexus.ALS_Engine:SaveAndStop()
    end
    ArcadiaNexus.GameSession:HandleRendererHide("ALCHEMISTSSORT", ArcadiaNexus.ALS_Engine, function(E)
        if E.state ~= "IDLE" then
            E:SaveAndStop()
        end
    end)
    if R._slotMenu and R._slotMenu:IsShown() then R:EnterIdle() end
end

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

    f:SetScript("OnHide", function() R:HandleViewHide() end)


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
    local UI,L=ArcadiaNexus.UI,ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local function box(key,label,x)
        local frame,value=UI.CreateHudStatBox(self._canvas,{w=80,h=40,x=x,y=-385,alpha=CFG.hud_alpha,shown=false})
        value:ClearAllPoints(); value:SetPoint("BOTTOM",frame,"BOTTOM",0,4)
        local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        title:SetPoint("TOP",frame,"TOP",0,-4); title:SetText(label)
        self._hud[key]=value; return frame
    end
    self._hud.timerBox=box("timer",L.lbl_time,180)
    self._hud.cntBox=box("moves",L.lbl_moves,340)
    local lvl=CreateFrame("Button",nil,self._canvas,"BackdropTemplate")
    lvl:SetSize(80,40); lvl:SetPoint("TOPLEFT",self._canvas,"TOPLEFT",260,-385)
    UI.StyleHudStatFrame(lvl,CFG.hud_alpha); lvl:SetFrameLevel(self._hud.timerBox:GetFrameLevel())
    lvl:RegisterForClicks("LeftButtonUp"); lvl:SetScript("OnClick",function() ArcadiaNexus.ALS_Engine:OpenLevelSelect() end)
    local title=lvl:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); title:SetPoint("TOP",lvl,"TOP",0,-4); title:SetText(L.lbl_choose_level)
    local value=lvl:CreateFontString(nil,"OVERLAY","GameFontNormal"); value:SetPoint("BOTTOM",lvl,"BOTTOM",0,4)
    self._hud.level,self._hud.levelBox=value,lvl
    local fb=self._canvas:CreateFontString(nil,"OVERLAY","GameFontNormal")
    fb:SetPoint("TOP",self._playfield,"TOP",0,-8); fb:SetWidth(560); fb:SetTextColor(1,0.7,0.3); fb:Hide()
    self._feedbackFS=fb
end

-- ── Controls (wide5) ─────────────────────────────────────────
function R:_CreateControls()
    if self._controlsFrame then return end
    local A=ArcadiaNexus; local UI,L=A.UI,A.GetLocaleTable("ALCHEMISTSSORT")
    local bar=UI.CreateGameControlsBar(self._container,"wide5"); local cf=bar.frame; self._controlsFrame=cf
    local function symbol(key,icon,x,action,tip)
        local b=CreateFrame("Button",nil,self._canvas,"BackdropTemplate")
        b:SetSize(CFG.help_size,CFG.help_size); b:SetPoint("TOPLEFT",self._canvas,"TOPLEFT",x,CFG.help_y)
        UI.StyleHudStatFrame(b,CFG.hud_alpha); b:SetFrameLevel(self._hud.levelBox:GetFrameLevel()+1)
        local tex=b:CreateTexture(nil,"ARTWORK"); tex:SetSize(CFG.help_icon,CFG.help_icon); tex:SetPoint("CENTER")
        tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\icons\\"..icon)
        b._icon=tex; b._count=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b._count:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-1,0)
        b:SetScript("OnClick",function() if b._available then action(A.ALS_Engine) end end)
        -- Keep the button focusable even when exhausted: guards and dimming disable the action,
        -- while ConsolePort's cursor and mouse can still explain it through OnEnter.
        b:SetScript("OnEnter",function()
            local L=A.GetLocaleTable("ALCHEMISTSSORT")
            if not GameTooltip then return end
            GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText(L[key])
            GameTooltip:AddLine(string.format(L[tip],b._remaining or 0),1,1,1,true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        function b:SetAvailable(yes,count)
            self._available=yes; self._remaining=count
            self._icon:SetAlpha(yes and 1 or 0.35); self._count:SetText(count and tostring(count) or "")
        end
        b:Hide(); return b
    end
    self._btnReset=symbol("btn_reset","reset",CFG.help_left,function(E) E:ResetLevel() end,"tip_reset")
    self._btnUndo=symbol("btn_undo","undo",CFG.help_left+40,function(E) E:Undo() end,"tip_undo")
    self._btnHint=symbol("btn_hint","hint",CFG.help_right,function(E) E:RequestHint() end,"tip_hint")
    self._btnAdd=symbol("btn_add_tube","bottle_plus",CFG.help_right+40,function(E) E:AddEmptyTube() end,"tip_add")
    local start=UI.CreateArcadiaButton(cf,L.btn_start,144,32)
    start:SetPoint("BOTTOM",cf,"BOTTOM",bar.segX[3],bar.y.button); start:SetScript("OnClick",function() R:EnterSlotMenu() end); self._btnStart=start
    local exit=UI.CreateArcadiaButton(cf,L.btn_exit,144,32)
    exit:SetPoint("BOTTOM",cf,"BOTTOM",bar.segX[3],bar.y.button)
    exit:SetScript("OnClick",function() if R._slotMenu and R._slotMenu:IsShown() then R:EnterIdle() else A.ALS_Engine:SaveAndStop() end end)
    exit:Hide(); self._exitBtn=exit
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
    confText:SetWidth(230)
    confText:SetWordWrap(true)
    confText:SetText(L and L.confirm_reset or "Level neu starten?")
    confText:SetTextColor(0.9, 0.85, 0.65)
    self._confirmText = confText

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
        tf._layoutX,tf._layoutY=posX,posY
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

    tf._layers = {}
    tf._mask=tf:CreateMaskTexture(nil,"ARTWORK")
    tf._mask:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\tiles\\fill_mask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    tf._mask:SetAllPoints(tf)
    for i=1,5 do
        local layer=tf:CreateTexture(nil,"BACKGROUND")
        layer:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\tiles\\fill_"..i)
        layer:SetAllPoints(tf); layer:AddMaskTexture(tf._mask); layer:Hide(); tf._layers[i]=layer
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

    self:_DrawTube(tf,tube)
end

function R:_DrawTube(tf,tube)
    for _,layer in ipairs(tf._layers) do layer:SetAlpha(1) end
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

function R:AnimatePour(srcIdx,dstIdx,color,count,onDone,before,after)
    self:CancelPour()
    local src,dst=self._tubeFrames[srcIdx],self._tubeFrames[dstIdx]
    if not src or not dst or not before or not after then if onDone then onDone() end; return end
    local p=self._pourProxy
    if not p then
        p=self:_CreateTubeFrame(0); p:EnableMouse(false); self._pourProxy=p
        local drop=self._playfield:CreateTexture(nil,"OVERLAY")
        drop:SetTexture(ASSETS.drop); drop:SetSize(CFG.pour_drop_w,CFG.pour_drop_h); drop:Hide()
        self._pourDrop=drop
        self._pourLoop=ArcadiaNexus.GameLoop.Create("ArcadiaNexus_ALS_Pour")
    end
    p:SetFrameLevel(self._playfield:GetFrameLevel()+15)
    self:_DrawTube(p,before[srcIdx]); self:_PoseBottle(p,0)
    p:ClearAllPoints(); p:SetPoint("CENTER",self._playfield,"TOPLEFT",src._layoutX+24,-src._layoutY-64)
    p:Show(); src:SetAlpha(0)
    self._pourSource=src; self._pourToken=(self._pourToken or 0)+1; local token=self._pourToken
    local c=ArcadiaNexus.ALS_Colors:Get(color); self._pourDrop:SetVertexColor(c[1],c[2],c[3],0.95)
    local sx,sy=src._layoutX+24,src._layoutY+64
    local tx,ty=dst._layoutX+24,dst._layoutY+12
    -- Screen-left tilt uses a positive angle (SetVertexOffset, y-up). Left half
    -- pours left, right half pours right. A centre destination still receives the
    -- source, which then tilts inward (left source to the right, right source to the left).
    local mid=CFG.field_w/2
    local function half(x) return x<mid and 1 or x>mid and -1 or 0 end
    local destHalf=half(tx)
    local sign
    if destHalf==0 then
        local srcHalf=half(sx)
        sign=srcHalf~=0 and -srcHalf or (tx<sx and 1 or -1)
    else
        sign=destHalf
    end
    local pourX=destHalf==0 and tx or (sign>0 and math.min(sx,tx) or math.max(sx,tx))
    local elapsed=0
    local S=ArcadiaNexus.ALS_Settings
    if S:Get("soundEnabled") and S:Get("soundOnPour") then PlaySoundFile("Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\sounds\\flow.wav","SFX") end
    self._pourLoop:Start(function(dt)
        if self._pourToken~=token then return end
        elapsed=elapsed+dt; local t=math.min(1,elapsed/CFG.anim_duration)
        local blend=t<0.28 and t/0.28 or t>0.75 and (1-t)/0.25 or 1
        local angle=sign*CFG.anim_angle*blend
        local halfW=math.abs(24*math.cos(angle))+math.abs(64*math.sin(angle))
        local halfH=math.abs(64*math.cos(angle))+math.abs(24*math.sin(angle))
        local x=sx+(pourX-sx)*0.72*blend; local y=sy+(ty+halfH-sy-12)*blend
        x=math.max(CFG.anim_left+halfW,math.min(CFG.anim_right-halfW,x))
        y=math.max(CFG.anim_top+halfH,math.min(CFG.anim_bottom-halfH,y))
        self._lastPourBounds={left=x-halfW,right=x+halfW,top=y-halfH,bottom=y+halfH}
        p:ClearAllPoints(); p:SetPoint("CENTER",self._playfield,"TOPLEFT",x,-y)
        self:_PoseBottle(p,angle)
        local filling=t>0.28 and t<0.75
        if filling then
            local poured=math.min(count,math.floor((t-0.28)/0.47*count)+1)
            local remaining={}; for i=poured+1,#before[srcIdx] do remaining[#remaining+1]=before[srcIdx][i] end
            self:_DrawTube(p,remaining)
            local target=ArcadiaNexus.ALS_Logic:DeepCopy({before[dstIdx]})[1]
            for _=1,poured do table.insert(target,1,color) end
            self:_DrawTube(dst,target)
            local mouthX=x-52*math.sin(angle); local mouthY=y-52*math.cos(angle)
            self:_PoseDrop(self._pourDrop,mouthX,mouthY,angle)
            self._pourDrop:Show()
        else self._pourDrop:Hide(); if t>0.75 then self:_DrawTube(p,after[srcIdx]); self:_DrawTube(dst,after[dstIdx]) end end
        if t>=1 then self:CancelPour(); if onDone then onDone() end end
    end)
end
-- Rotate the actual quad rather than its UVs: the tall bottle cannot be clipped
-- inside an unchanged 48x128 sampling rectangle. All masks/bands share its pivot.
function R:_PoseBottle(p,angle)
    local regions={p._bottleTex,p._mask}
    for _,layer in ipairs(p._layers) do regions[#regions+1]=layer end
    local corners={{-24,64},{-24,-64},{24,64},{24,-64}}
    local c,s=math.cos(angle),math.sin(angle)
    for i,pt in ipairs(corners) do
        local x,y=pt[1],pt[2]; local ox,oy=x*c-y*s-x,x*s+y*c-y
        for _,region in ipairs(regions) do region:SetVertexOffset(i,ox,oy) end
    end
    p._angle=angle
end
function R:_PoseDrop(drop,mouthX,mouthY,angle)
    local hw,hh=CFG.pour_drop_w/2,CFG.pour_drop_h/2
    local reach=CFG.pour_drop_reach
    local cx=mouthX-reach*math.sin(angle)
    local cy=mouthY-reach*math.cos(angle)
    drop:ClearAllPoints(); drop:SetPoint("CENTER",self._playfield,"TOPLEFT",cx,-cy)
    local corners={{-hw,hh},{-hw,-hh},{hw,hh},{hw,-hh}}
    local c,s=math.cos(angle),math.sin(angle)
    for i,pt in ipairs(corners) do
        local x,y=pt[1],pt[2]
        drop:SetVertexOffset(i,x*c-y*s-x,x*s+y*c-y)
    end
end
function R:CancelPour()
    self._pourToken=(self._pourToken or 0)+1
    if self._pourLoop then self._pourLoop:Stop() end
    if self._pourSource then self._pourSource:SetAlpha(1); self._pourSource=nil end
    if self._pourDrop then self._pourDrop:Hide() end
    if self._pourStream then self._pourStream:Hide() end
    local p=self._pourProxy
    if p then
        self:_PoseBottle(p,0)
        for _,layer in ipairs(p._layers) do layer:SetAlpha(1) end
        p:Hide()
    end
end

-- ── Shake (ungültiger Zug) ────────────────────────────────────

local function IsCurrentSession(sid)
    local E = ArcadiaNexus.ALS_Engine
    return sid and E and E._sessionId == sid
        and ArcadiaNexus.GameSession:IsSession(E, sid)
end

function R:_ClearHint()
    for _, tf in ipairs(self._hintFrames or {}) do
        if tf._selTex then tf._selTex:Hide() end
    end
    self._hintFrames = nil
end

function R:CancelTransientEffects()
    self:CancelPour()
    self._hintGuard:Cancel()
    self._feedbackGuard:Cancel()
    self._hintToken = self._hintToken + 1
    self:_ClearHint()
    if self._feedbackFS then self._feedbackFS:Hide() end
    for _, tf in ipairs(self._tubeFrames) do
        if tf._shakeGuard then tf._shakeGuard:Cancel() end
        if tf._shakeOrigin then
            tf:ClearAllPoints()
            tf:SetPoint("TOPLEFT", self._playfield, "TOPLEFT",
                tf._shakeOrigin.x, tf._shakeOrigin.y)
            tf._shakeOrigin = nil
        end
    end
end

function R:ShakeTube(tubeIdx)
    local tf = self._tubeFrames[tubeIdx]
    if not tf then return end

    tf._shakeGuard = tf._shakeGuard or ArcadiaNexus.TimerGuard.New()
    tf._shakeGuard:Cancel()
    if tf._shakeOrigin then
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", self._playfield, "TOPLEFT",
            tf._shakeOrigin.x, tf._shakeOrigin.y)
    end
    local sid = ArcadiaNexus.ALS_Engine._sessionId
    if not IsCurrentSession(sid) then return end

    local origOffX = tf:GetLeft() - self._playfield:GetLeft()
    local origOffY = tf:GetTop()  - self._playfield:GetTop()
    tf._shakeOrigin = { x=origOffX, y=origOffY }

    local offsets = { 5, -5, 4, -4, 2, -2, 1, 0 }
    local step    = 0

    local function DoShake()
        if not IsCurrentSession(sid) or self._tubeFrames[tubeIdx] ~= tf then return end
        step = step + 1
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", self._playfield, "TOPLEFT",
            origOffX + offsets[step], origOffY)
        if step < #offsets then
            tf._shakeGuard:After(0.04, DoShake)
        else
            tf._shakeOrigin = nil
        end
    end
    DoShake()
end

-- ── Tipp-Highlight ────────────────────────────────────────────

function R:ShowHint(srcIdx, dstIdx, onDone)
    self._hintGuard:Cancel()
    self._hintToken = self._hintToken + 1
    self:_ClearHint()
    local token = self._hintToken
    local sid = ArcadiaNexus.ALS_Engine._sessionId
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
    self._hintFrames = { srcTF, dstTF }

    self._hintGuard:After(2.0, function()
        if token ~= self._hintToken or not IsCurrentSession(sid) then return end
        self:_ClearHint()
        if onDone then onDone() end
    end)
end

-- ── Feedback-Meldung ──────────────────────────────────────────

function R:ShowFeedback(msgKey)
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
    local msg = L and L[msgKey] or msgKey
    if not self._feedbackFS then return end
    self._feedbackGuard:Cancel()
    local sid = ArcadiaNexus.ALS_Engine._sessionId
    self._feedbackFS:SetText(msg)
    self._feedbackFS:Show()
    self._feedbackGuard:After(1.5, function()
        if not IsCurrentSession(sid) then return end
        if self._feedbackFS then self._feedbackFS:Hide() end
    end)
end

-- ── HUD aktualisieren ─────────────────────────────────────────

function R:UpdateHUD()
    local E=ArcadiaNexus.ALS_Engine
    if self._hud.level then self._hud.level:SetText(tostring(E._level or ArcadiaNexus.ALS_Settings:GetCurrentLevel())) end
    if self._hud.timer then self._hud.timer:SetText(ArcadiaNexus.Format.SecondsMMSS(math.floor(E:GetElapsed()),false)) end
    if self._hud.moves then self._hud.moves:SetText(tostring(E._moveCount or 0)) end
    local active=E:CanAct()
    if self._btnReset then self._btnReset:SetAvailable(active) end
    if self._btnUndo then self._btnUndo:SetAvailable(active and E._undosLeft>0 and #E._undoStack>0,E._undosLeft) end
    if self._btnHint then self._btnHint:SetAvailable(active and E._hintsLeft>0,E._hintsLeft) end
    if self._btnAdd then self._btnAdd:SetAvailable(active and not E._addedTube,E._addedTube and 0 or 1) end
end

-- ── Win-Overlay ───────────────────────────────────────────────

function R:ShowWinOverlay(data)
    local A=ArcadiaNexus; local UI,L=A.UI,A.GetLocaleTable("ALCHEMISTSSORT"); local E=A.ALS_Engine
    local stats=data.stats; local lines={string.format(L.result_stars,stats.stars,data.bestStars or stats.stars),
        string.format(L.win_moves,stats.moves),string.format(L.win_time,A.Format.SecondsMMSS(math.floor(stats.elapsedMs/1000),false))}
    if data.newMetricRecords and not data.localReplay then
        if data.newMetricRecords.moves then lines[#lines+1]=L.record_moves end
        if data.newMetricRecords.time then lines[#lines+1]=L.record_time end
    end
    if data.minimum.kind=="exact" and not stats.usedAddTube then lines[#lines+1]=string.format(L.minimum_exact,data.minimum.moves) end
    local function go(fn)
        return function() UI.HideResultDialog(self._playfield); fn() end
    end
    UI.ShowResultDialog({parent=self._playfield,title=L.state_win,result="WIN",gameId="ALCHEMISTSSORT",difficulty="normal",
        hideHighscore=true,xp=data.awardedXP or 0,gold=data.awardedGold or 0,lines=lines,
        buttons=UI.ResultDialogButtons.Campaign(L,
            go(function() E:StartLevel(data.level+1) end),
            go(function() E:OpenLevelSelect() end),
            go(function() E:StartLevel(data.level) end),
            go(function() E:SaveAndStop() end))})
end
function R:ShowPendingResult()
    local A=ArcadiaNexus; local L=A.GetLocaleTable("ALCHEMISTSSORT")
    A.UI.ShowResultDialog({parent=self._playfield,title=L.msg_result_pending,xp=0,hideHighscore=true,
        lines={L.pending_help},buttons={{label=L.btn_retry_result,onClick=function() A.ALS_Engine:RetryResult() end},
            {label=L.btn_exit,onClick=function() A.ALS_Engine:SaveAndStop() end}}})
end

-- ── Confirm-Reset ─────────────────────────────────────────────

function R:ShowConfirmReset(onConfirm,onCancel)
    if self._confirmText then
        local L=ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
        self._confirmText:SetText(L and L.confirm_reset or "Level neu starten?")
    end
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
            if onCancel then onCancel() end
        end)
    end
end

function R:ShowConfirmLeave(onYes, onNo)
    local co=self._confirmFrame
    if not co then
        if onNo then onNo() end
        return
    end
    if self._confirmText then
        local L=ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")
        self._confirmText:SetText(L and L.confirm_leave_level or "Laufendes Level verwerfen?")
    end
    co:Show()
    if self._confirmYes then
        self._confirmYes:SetScript("OnClick", function()
            co:Hide()
            if onYes then onYes() end
        end)
    end
    if self._confirmNo then
        self._confirmNo:SetScript("OnClick", function()
            co:Hide()
            if onNo then onNo() end
        end)
    end
end

-- ── Levelauswahl ──────────────────────────────────────────────

function R:_CreateLevelSelect()
    if self._levelSelect or not self._canvas then return end
    self._levelSelect = ArcadiaNexus.UI.CreateCampaignMap({
        parent = self._canvas,
        getView = function()
            local S = ArcadiaNexus.ALS_Settings
            local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT") or {}
            local unlocked = math.max(1, tonumber(S:GetUnlockedLevel()) or 1)
            local catalog = ArcadiaNexus.ALS_Catalog
            local catalogCount = type(catalog) == "table" and #catalog or 1000
            local save = S:LoadSlot(S:GetActiveSlot())
            return {
                levelCount = math.max(catalogCount, unlocked),
                currentLevel = S:GetCurrentLevel(),
                titleFormat = L.map_title,
                subtitle = string.format(L.map_progress or "Frei bis %d · Sterne: %d", unlocked, S:SumStars(save)),
                lockedText = L.map_locked or "—",
                actionLabel = save and save.midGame and (L.btn_resume_level or "Fortsetzen") or nil,
                getLevel = function(level)
                    local classes,legacy = S:GetLevelBests(level)
                    local best = nil
                    local stars = S:GetStar(save, level)
                    local moves = best and best.moves and string.format(L.level_best_moves or "%d Züge", best.moves)
                    local elapsed = best and best.time and string.format(L.level_best_time or "%s",
                        ArcadiaNexus.Format.SecondsMMSS(math.floor(best.time), false))
                    local details={string.format(L.level_stars or "Sterne: %d / 3",stars),L.best_independent}
                    for _,aid in ipairs({"unassisted","hint_or_undo","extra_bottle"}) do
                        local b=classes[aid]
                        if b then details[#details+1]=string.format(L.map_best_class,L["aid_"..aid],b.moves,
                            ArcadiaNexus.Format.SecondsMMSS(math.floor(b.elapsedMs/1000),false)) end
                    end
                    if legacy then details[#details+1]=string.format(L.map_legacy,legacy.moves or 0,
                        ArcadiaNexus.Format.SecondsMMSS(math.floor(legacy.time or 0),false)) end
                    return {
                        unlocked = level <= unlocked,
                        text = stars > 0 and string.rep("*", stars) or "—",
                        tooltipTitle = (L.lbl_level or "Level") .. " " .. level,
                        tooltipText = table.concat(details,"\n"),
                    }
                end,
            }
        end,
        onSelect = function(level) ArcadiaNexus.ALS_Engine:SelectLevel(level) end,
        onAction = function() ArcadiaNexus.ALS_Engine:ResumeSelectedLevel() end,
    })
end

function R:ShowLevelSelect(save)
    if self._levelSelect then self._levelSelect:Show(save and save.currentLevel or 1) end
end

function R:HideLevelSelect()
    if self._levelSelect then self._levelSelect:Hide() end
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
            return string.format(loc.slot_info_unlocked or "L%d · frei bis %d · %d Sterne",
                save.currentLevel or 1, save.unlockedLevel or save.currentLevel or 1, S:SumStars(save))
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

function R:OnStateChanged(state)
    if state=="IDLE" then self:EnterIdle(); return end
    local board=state~="LEVEL_SELECT" and state~="GENERATING"
    if state~="WIN" then ArcadiaNexus.UI.HideResultDialog(self._playfield) end
    if not board then for _,tf in ipairs(self._tubeFrames) do tf:Hide() end end
    for _,box in pairs({self._hud.levelBox,self._hud.timerBox,self._hud.cntBox}) do box:SetShown(board) end
    for _,btn in pairs({self._btnReset,self._btnUndo,self._btnHint,self._btnAdd}) do btn:SetShown(board) end
    if self._logoTex then self._logoTex:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end
    if self._btnStart then self._btnStart:Hide() end
    if self._exitBtn then self._exitBtn:Show() end
    if state=="PLAYING" then self:HideLevelSelect() end
    self:UpdateHUD()
end

function R:EnterIdle()
    self:CancelTransientEffects()
    self:HideLevelSelect()
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
