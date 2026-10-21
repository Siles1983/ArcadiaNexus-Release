-- ============================================================
--  SlidingPuzzle – Renderer.lua
--  Spielfeld-Aufbau, Kachel-Buttons, HUD, Win-Reveal.
--
--  Controls: CreateGameControlsBar "narrow"
--    Seg.1 DD Schwierigkeit + DD Bild
--    Seg.2 Toggle Start/Stop
--    Seg.3 Checkbox Timer
--
--  _fieldFrame (CENTER-Anker, 560×384):
--    Grid (inner):    CFG.grid_ofs_x / CFG.grid_ofs_y, skalierbar
--    Sidebar (rechts): CFG.hud_ofs_x / CFG.hud_ofs_y
--    Mischen-Button:  CFG.shuffle_ofs_x / CFG.shuffle_ofs_y
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SLP_Renderer = {}
local R = ArcadiaNexus.SLP_Renderer

-- ============================================================
-- CFG – Layout-Konstanten
-- ============================================================
local CFG = {
    -- _fieldFrame = nur Grid (CENTER-Anker auf Grid-Zentrum, kein bgFile)
    -- grid_scale: prozentualer Faktor auf GRID_BASE_W/H (1.0 = 368×368)
    field_ofs_x  = 0,   -- Grid-Zentrum liegt links der Panel-Mitte (Sidebar rechts)
    field_ofs_y  = 10,
    grid_scale   = 1.15,
    gold_ofs_x   = 0,
    gold_ofs_y   = 0,

    -- Hintergrund (relativ zu self.frame CENTER)
    bg_w         = 700,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,

    -- Border (relativ zu self.frame CENTER)
    border_w     = 790,
    border_h     = 540,
    border_ofs_x = 0,
    border_ofs_y = 20,

    -- Logo (relativ zu _fieldFrame CENTER — liegt im Grid-Bereich)
    logo_w       = 300,
    logo_h       = 300,
    logo_ofs_x   = 0,
    logo_ofs_y   = 20,

    -- Sidebar HUD-Boxen (TOPLEFT relativ zu self.frame)
    hud_ofs_x    = 525,
    hud_ofs_y    = -176,
    hud_w        = 72,
    hud_h        = 44,
    hud_gap      = -48,   -- Y-Abstand zwischen Moves- und Time-Box

    preview_w=160, preview_header=24, preview_min=96, preview_grip=18,
    preview_chrome_inset=5, slide_duration=0.16,
    -- Preview button (TOPLEFT relative to canvas)
    shuffle_ofs_x = 0,
    shuffle_ofs_y = -210,
    shuffle_w     = 75,
    shuffle_h     = 32,
}

-- Basis-Gridgröße (unveränderlich, scale wirkt darauf)
local GRID_BASE_W = 368
local GRID_BASE_H = 368

local TILE_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function CreateTilePool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "SlidingPuzzle.Tiles",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            f:SetBackdrop(TILE_BACKDROP)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
            tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
            f._tex = tex
            f._number=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            f._number:SetPoint("TOPLEFT",f,"TOPLEFT",4,-4)
            f._number:SetTextColor(1,0.88,0.55)
            f:RegisterForClicks("LeftButtonUp")
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            f:SetScript("OnClick", nil)
            f:SetScript("OnEnter", nil)
            f:SetScript("OnLeave", nil)
            f._tilePos = nil
            f:SetBackdropColor(0.05, 0.05, 0.05, 1)
            f:SetBackdropBorderColor(0.25, 0.20, 0.12, 0.8)
            if f._tex then
                f._tex:SetTexture(nil)
                f._tex:SetTexCoord(0, 1, 0, 1)
                f._tex:SetAlpha(1)
            end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\SlidingPuzzle\\assets\\background\\bg_moa",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\SlidingPuzzle\\assets\\border\\border_moa",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\SlidingPuzzle\\assets\\logo\\logo_moa",
}

-- Bilder-Auswahl
local NUM_IMAGES = 19
local IMAGE_PATH = "Interface\\AddOns\\ArcadiaNexus\\Shared\\Puzzle\\"

-- ── State ─────────────────────────────────────────────────────
R.frame         = nil
R._canvas       = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._logoTex      = nil
R.gridFrame     = nil
R.tileFrames    = {}   -- [pos] = Frame
R.tileTex       = {}   -- [pos] = Texture
R.hud           = {}
R._startBtn     = nil
R.shuffleBtn    = nil
R._controlsFrame = nil
R._cols         = 3
R._imageIdx     = 1
R._imagePath    = IMAGE_PATH .. "01"
R._revealFrame  = nil
R._previewFrame = nil
R._previewTex   = nil
R._animPos      = {}

-- ── Hilfsfunktion: Fade ───────────────────────────────────────

local presentation=ArcadiaNexus.GameLoop.Create("ArcadiaNexus_Mosaic_Presentation")

-- ── Image-Pfad aus Index ──────────────────────────────────────

local function GetImagePath(idx)
    if idx <= 9 then
        return IMAGE_PATH .. "0" .. idx
    else
        return IMAGE_PATH .. "0" .. idx
    end
end

-- Alle Bilder als Dropdown-Optionen (0 = Zufällig)
local function BuildImageOptions()
    local L = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    local opts = {
        { label = L and L.img_random or "Zufällig", key = 0 },
    }
    for i = 1, NUM_IMAGES do
        opts[#opts + 1] = { label = (L and L.img_prefix or "Bild ") .. i, key = i }
    end
    return opts
end

-- ── Container-Frame ───────────────────────────────────────────

function R:CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI.GetGamesPanel()
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_SLP_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._slpContainer = f

    f:SetScript("OnHide", function()
        local E=ArcadiaNexus.SLP_Engine
        if not E._sessionId and (E.state=="WIN" or E.state=="RESULT_PENDING") then E:StopGame() end
        if E.state=="SLOT_MENU" then E:StopGame() end
        R:CancelPresentation()
        ArcadiaNexus.GameSession:HandleRendererHide("MOSAICOFAZEROTH", ArcadiaNexus.SLP_Engine, function(E)
            if E.state ~= "IDLE" then
                E:SaveAndPause()
            end
        end)
    end)
end

-- ── Field-Frame (CENTER-Anker, kein bgFile) ───────────────────

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local gridW = math.floor(GRID_BASE_W * CFG.grid_scale)
    local gridH = math.floor(GRID_BASE_H * CFG.grid_scale)
    local ff = CreateFrame("Frame", nil, self._canvas)
    ff:SetSize(gridW, gridH)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = ff
end

-- ── Background ────────────────────────────────────────────────

function R:_CreateBackground()
    local f   = self._canvas
    local tex = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", f, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- ── Border ────────────────────────────────────────────────────

function R:_CreateBorderFrame()
    local f           = self._canvas
    local borderFrame = CreateFrame("Frame", nil, f)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", f, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(f:GetFrameLevel() + 10)
    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(ASSETS.border)
    tex:SetAllPoints(borderFrame)
    self._borderFrame = borderFrame
    self._borderTex   = tex

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(f, self._fieldFrame, {
            x = CFG.gold_ofs_x, y = CFG.gold_ofs_y,
        })
    end
end

-- ── Logo ──────────────────────────────────────────────────────

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ── Grid-Frame (Kacheln leben hier) ──────────────────────────

function R:_CreateGridFrame()
    if self.gridFrame then return end
    -- _fieldFrame hat exakt Grid-Größe → gridFrame deckungsgleich
    local gf = CreateFrame("Frame", nil, self._fieldFrame)
    gf:SetAllPoints(self._fieldFrame)
    self.gridFrame = gf
end

-- ── HUD-Boxen ─────────────────────────────────────────────────

function R:_CreateHUD()
    local L=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    for _,info in ipairs({{"moves",L.lbl_moves,CFG.hud_ofs_y},{"time",L.lbl_time,CFG.hud_ofs_y+CFG.hud_gap}}) do
        local f,v=ArcadiaNexus.UI.CreateHudStatBox(self._canvas,{w=CFG.hud_w,h=CFG.hud_h,x=CFG.hud_ofs_x,y=info[3],alpha=.85,shown=false})
        v:ClearAllPoints(); v:SetPoint("BOTTOM",f,"BOTTOM",0,5)
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); title:SetPoint("TOP",f,"TOP",0,-4); title:SetText(info[2])
        self.hud[info[1].."Box"]=f; self.hud[info[1].."Val"]=v
    end
end

-- ── Controls – 3 Segmente (narrow): DD+DD | Start | Checkbox
-- ============================================================
function R:_CreateControls()
    if self._startBtn then return end

    local L  = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.SLP_Settings

    local dd_w  = 120
    local dd_gap = 10
    local btn_w = 144
    local btn_h = 32

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local diffOptions = {
        { label = L and L.diff_easy   or "Einfach", key = "easy"   },
        { label = L and L.diff_medium or "Normal",  key = "medium" },
        { label = L and L.diff_hard   or "Schwer",  key = "hard"   },
    }
    self._diffOptions=diffOptions
    self._imageOptions=BuildImageOptions()

    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(dd_w * 2 + dd_gap, btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddDiffAnchor = CreateFrame("Frame", nil, pair)
    ddDiffAnchor:SetSize(dd_w, btn_h)
    ddDiffAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)
    self._diffDropdown=UI.CreateSimpleDropdown(ddDiffAnchor, 0, 0, dd_w, "",
        diffOptions,
        function() local E=ArcadiaNexus.SLP_Engine; return E:IsConfigLocked() and E._difficulty or ArcadiaNexus.SLP_Settings:Get("difficulty") end,
        function(val) ArcadiaNexus.SLP_Settings:Set("difficulty", val) end
    )

    local ddImgAnchor = CreateFrame("Frame", nil, pair)
    ddImgAnchor:SetSize(dd_w, btn_h)
    ddImgAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    self._imageDropdown=UI.CreateSimpleDropdown(ddImgAnchor, 0, 0, dd_w, "",
        self._imageOptions,
        function() local E=ArcadiaNexus.SLP_Engine; return E:IsConfigLocked() and E._imageIdx or ArcadiaNexus.SLP_Settings:Get("imageIndex") end,
        function(val) ArcadiaNexus.SLP_Settings:Set("imageIndex", val) end
    )

    local startBtn = UI.CreateArcadiaButton(cf,
        L and L.btn_start or "Spiel starten", btn_w, btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SLP_Engine
        if E.state=="IDLE" then E:ShowSlots()
        elseif E.state=="INTRO" then E:SkipIntro()
        else E:SaveAndPause() end
    end)
    self._startBtn = startBtn

    local chkHolder, chk = UI.CreateBarCheckbox(cf, L and L.lbl_timer or "Timer", { w = 110, h = 36, size = 20 })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.checkbox)
    chk:SetScript("OnShow", function()
        chk:SetChecked(S and S:Get("timerEnabled") or true)
    end)
    chk:SetScript("OnClick", function()
        if S then S:Set("timerEnabled", chk:GetChecked()) end
        R:UpdateHUD()
    end)
    self._timerChk = chk

    -- Mischen-Button (playfield UI, bleibt am Canvas)
    local shuffleBtn = UI.CreateArcadiaButton(self._canvas,
        L and L.btn_preview or "Preview", CFG.shuffle_w, CFG.shuffle_h)
    shuffleBtn:SetPoint("TOPLEFT", self._canvas, "TOPLEFT", CFG.shuffle_ofs_x, CFG.shuffle_ofs_y)
    shuffleBtn:SetFrameLevel(self._canvas:GetFrameLevel() + 20)
    shuffleBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SLP_Engine
        if E.state=="PLAYING" or E.state=="SLIDING" then R:ToggleReference() end
    end)
    self.shuffleBtn = shuffleBtn
    shuffleBtn:SetScript("OnEnter",function()
        local loc=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
        ArcadiaNexus.UI.ShowFrameTooltip(shuffleBtn,R._referenceFrame and R._referenceFrame:IsShown() and loc.preview_hide or loc.preview_show,loc.preview_tip)
    end)
    shuffleBtn:SetScript("OnLeave",function() ArcadiaNexus.UI.HideFrameTooltip() end)
end

-- ── Vorschau (Vollbild über dem Grid) ────────────────────────

function R:_EnsurePreviewFrame()
    if self._previewFrame then return end
    -- _fieldFrame hat exakt Grid-Größe → Preview deckungsgleich
    local pf = CreateFrame("Frame", nil, self._fieldFrame)
    pf:SetAllPoints(self._fieldFrame)
    pf:SetAlpha(0)
    pf:Hide()
    local tex = pf:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(pf)
    tex:SetTexCoord(0, 1, 0, 1)
    self._previewFrame = pf
    self._previewTex   = tex
end

function R:ShowPreview(imagePath)
    self:_EnsurePreviewFrame()
    self._previewTex:SetTexture(imagePath)
    self._previewFrame:SetAlpha(0)
    self._previewFrame:Show()
    self._previewFrame:SetAlpha(1)
    self.gridFrame:Hide()
end

function R:_HidePreview()
    if self._previewFrame then
        self._previewFrame:Hide()
        self._previewFrame:SetAlpha(0)
    end
end

-- ── Split-Animation ───────────────────────────────────────────

function R:_GetTileOffset(pos)
    local size=math.floor(GRID_BASE_W*CFG.grid_scale/self._cols)
    return ((pos-1)%self._cols)*size,-math.floor((pos-1)/self._cols)*size
end
function R:_SwapTilePositions(a,b)
    local fa,fb=self.tileFrames[a],self.tileFrames[b]
    local ax,ay=self:_GetTileOffset(a); local bx,by=self:_GetTileOffset(b)
    fa:ClearAllPoints(); fa:SetPoint("TOPLEFT",self.gridFrame,"TOPLEFT",bx,by)
    fb:ClearAllPoints(); fb:SetPoint("TOPLEFT",self.gridFrame,"TOPLEFT",ax,ay)
    self.tileFrames[a],self.tileFrames[b]=fb,fa
end
function R:StartIntroSequence(cols,img,history,done)
    self:CancelPresentation()
    local goal=ArcadiaNexus.SLP_Logic:GoalBoard(cols)
    self:_PaintBoard(goal); self:ShowPreview(self._imagePath)
    local elapsed,index,splitSound=0,1,false
    local run,rev=ArcadiaNexus.SLP_Engine._runId,ArcadiaNexus.SLP_Engine._revision
    presentation:Start(function(dt)
        local E=ArcadiaNexus.SLP_Engine
        if E._runId~=run or E._revision~=rev or E.state~="INTRO" then R:CancelPresentation(); return end
        elapsed=elapsed+dt
        if elapsed<1 then return end
        if not splitSound then E:PlayEffect("soundOnMove",SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK); splitSound=true end
        if elapsed<1.4 then
            R.gridFrame:Show(); R.gridFrame:SetAlpha((elapsed-1)/.4); R._previewFrame:SetAlpha(1-(elapsed-1)/.4); return
        end
        R.gridFrame:SetAlpha(1)
        R:_HidePreview(); R.gridFrame:Show()
        local target=math.min(#history,math.floor((elapsed-1.4)/.75*#history)+1)
        local work=0
        while index<=target and work<16 do
            local m=history[index]; R:_SwapTilePositions(m.tilePos,m.emptyPos); index=index+1; work=work+1
        end
        if index>#history then presentation:Stop(); R:RefreshGrid(); if done then done() end end
    end)
end
local PREVIEW_GRIP = "Interface\\AddOns\\ArcadiaNexus\\UI\\Assets\\Icons\\resize"

function R:_PreviewHost()
    return self.frame or self._canvas
end

function R:_PreviewClampFrame()
    local ui = ArcadiaNexus.UI
    local refs = ui and ui.GetF and ui.GetF()
    if refs and refs.content then return refs.content end
    return self:_PreviewHost()
end

function R:_PreviewInnerRect()
    local host = self:_PreviewClampFrame()
    if not host or not host.GetLeft then return nil end
    local l, b, r, t = host:GetLeft(), host:GetBottom(), host:GetRight(), host:GetTop()
    if not (l and b and r and t) then return nil end
    local inset = CFG.preview_chrome_inset
    return l + inset, b + inset, r - inset, t - inset
end

function R:_RaiseReference()
    local f, parent = self._referenceFrame, self:_PreviewHost()
    if not f or not parent then return end
    if f.SetParent then f:SetParent(parent) end
    local level = (parent:GetFrameLevel() or 1) + 90
    local ui = ArcadiaNexus.UI
    local refs = ui and ui.GetF and ui.GetF()
    local chrome = refs and refs.contentChrome
    if chrome and chrome.GetFrameLevel then
        level = math.max(level, (chrome:GetFrameLevel() or 0) + 2)
    end
    f:SetFrameLevel(level)
end

function R:_LayoutReference(imageW)
    local f = self._referenceFrame
    if not f then return end
    local header, grip = CFG.preview_header, CFG.preview_grip
    f._imageW = imageW
    f:SetSize(imageW, imageW + header)
    if f._head then f._head:SetSize(imageW, header) end
    if f._tex then f._tex:SetSize(imageW, imageW) end
    if f._grip then f._grip:SetSize(grip, grip) end
end

function R:_PlaceReference(screenLeft, screenBottom, imageW, keepTopLeft)
    local f, parent = self._referenceFrame, self:_PreviewHost()
    if not f or not parent then return end
    local header = CFG.preview_header
    imageW = imageW or f._imageW or CFG.preview_w
    if screenLeft == nil and f.GetLeft then screenLeft = f:GetLeft() end
    if screenBottom == nil and f.GetBottom then screenBottom = f:GetBottom() end
    local inner = {self:_PreviewInnerRect()}
    if inner[1] and screenLeft and screenBottom then
        local l, b, r, t = inner[1], inner[2], inner[3], inner[4]
        local maxBox = math.max(CFG.preview_min, math.min(r - l, (t - b) - header))
        if keepTopLeft then
            local top = (screenBottom or b) + imageW + header
            if f._resizeTop then top = f._resizeTop end
            local maxW = math.max(CFG.preview_min, math.min(maxBox, r - (screenLeft or l), top - b - header))
            imageW = math.max(CFG.preview_min, math.min(imageW, maxW))
            screenLeft = screenLeft or l
            screenBottom = top - imageW - header
            if screenLeft < l then screenLeft = l end
        else
            imageW = math.max(CFG.preview_min, math.min(imageW, maxBox))
            local h = imageW + header
            if screenLeft + imageW > r then screenLeft = r - imageW end
            if screenBottom + h > t then screenBottom = t - h end
            if screenLeft < l then screenLeft = l end
            if screenBottom < b then screenBottom = b end
        end
    end
    self:_LayoutReference(imageW)
    local pl = parent.GetLeft and parent:GetLeft()
    local pb = parent.GetBottom and parent:GetBottom()
    f:ClearAllPoints()
    if screenLeft and screenBottom and pl and pb then
        f:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", screenLeft - pl, screenBottom - pb)
    elseif self.gridFrame then
        f:SetPoint("TOPRIGHT", self.gridFrame, "TOPLEFT", -8, 0)
    else
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    end
end

function R:_EndReferenceInteract()
    local f = self._referenceFrame
    if not f then return end
    f.moving, f.resizing = nil, nil
    f._dragOffX, f._dragOffY, f._resizeW, f._resizeLeft, f._resizeTop = nil, nil, nil, nil, nil
    if f.SetScript then f:SetScript("OnUpdate", nil) end
end

function R:_TickReferenceInteract()
    local f = self._referenceFrame
    if not f or not GetCursorPosition then return end
    local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
    if scale == 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    if f.moving then
        self:_PlaceReference(cx - (f._dragOffX or 0), cy - (f._dragOffY or 0), f._imageW)
    elseif f.resizing then
        local dw = cx - (f._resizeCursorX or cx)
        local dh = (f._resizeCursorY or cy) - cy
        local nextW = (f._resizeW or f._imageW or CFG.preview_w) + math.max(dw, dh)
        self:_PlaceReference(f._resizeLeft, (f._resizeTop or cy) - (nextW + CFG.preview_header), nextW, true)
    end
end

function R:_BeginReferenceMove()
    local f = self._referenceFrame
    if not f then return end
    f.moving, f.resizing = true, nil
    if GetCursorPosition and f.GetLeft and f.GetBottom then
        local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        if scale == 0 then scale = 1 end
        local cx, cy = GetCursorPosition()
        f._dragOffX = cx / scale - f:GetLeft()
        f._dragOffY = cy / scale - f:GetBottom()
    end
    f:SetScript("OnUpdate", function() R:_TickReferenceInteract() end)
end

function R:_BeginReferenceResize()
    local f = self._referenceFrame
    if not f then return end
    f.resizing, f.moving = true, nil
    f._resizeW = f._imageW or CFG.preview_w
    f._resizeLeft = f.GetLeft and f:GetLeft()
    f._resizeTop = f.GetTop and f:GetTop()
    if GetCursorPosition then
        local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
        if scale == 0 then scale = 1 end
        local cx, cy = GetCursorPosition()
        f._resizeCursorX, f._resizeCursorY = cx / scale, cy / scale
    end
    f:SetScript("OnUpdate", function() R:_TickReferenceInteract() end)
end

function R:_EnsureReferenceFrame()
    if self._referenceFrame then return self._referenceFrame end
    local parent = self:_PreviewHost()
    if not parent then return nil end
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(TILE_BACKDROP)
    f:SetBackdropColor(.04, .04, .04, .98)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(false) end
    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT")
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() R:_BeginReferenceMove() end)
    head:SetScript("OnDragStop", function() R:_EndReferenceInteract(); R:_PlaceReference() end)
    f._head = head
    local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("CENTER", head, "CENTER")
    f._title = title
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
    f._tex = tex
    local grip = CreateFrame("Button", nil, f)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() R:_BeginReferenceResize() end)
    grip:SetScript("OnDragStop", function() R:_EndReferenceInteract(); R:_PlaceReference() end)
    local gtex = grip:CreateTexture(nil, "ARTWORK")
    gtex:SetAllPoints()
    gtex:SetTexture(PREVIEW_GRIP)
    gtex:SetVertexColor(0.90, 0.75, 0.30, 1)
    grip._tex = gtex
    f._grip = grip
    f:SetScript("OnHide", function() R:_EndReferenceInteract() end)
    self._referenceFrame = f
    self:_LayoutReference(CFG.preview_w)
    return f
end

function R:ToggleReference()
    if self._referenceFrame and self._referenceFrame:IsShown() then self._referenceFrame:Hide(); return end
    local f = self:_EnsureReferenceFrame()
    if not f then return end
    self:_RaiseReference()
    local loc = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    f._title:SetText(loc.preview_drag)
    f._tex:SetTexture(self._imagePath)
    f._tex:SetTexCoord(0, 1, 0, 1)
    if not f._placed then
        f:ClearAllPoints()
        if self.gridFrame then
            f:SetPoint("TOPRIGHT", self.gridFrame, "TOPLEFT", -8, 0)
        else
            f:SetPoint("TOPLEFT", self:_PreviewHost(), "TOPLEFT", 8, -8)
        end
        f._placed = true
    end
    f:Show()
    if f.GetLeft and f:GetLeft() then self:_PlaceReference() end
end
function R:CancelSlide()
    if self._slideFrame then
        local f=self._slideFrame; local x,y=self:_GetTileOffset(f._tilePos)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",self.gridFrame,"TOPLEFT",x,y); f:SetFrameLevel(self.gridFrame:GetFrameLevel()+1); self._slideFrame=nil
    end
end
function R:CancelPresentation()
    presentation:Stop(); self:CancelSlide(); self:_HidePreview(); self:_HideReveal()
    if self.gridFrame then self.gridFrame:SetAlpha(1) end
    if self._referenceFrame then self._referenceFrame:Hide() end
end

-- ── Grid aufbauen (Kachel-Buttons) ───────────────────────────

function R:_EnsureTilePool()
    if not self._tilePool then
        self._tilePool = CreateTilePool()
    end
end

function R:_ClearTileGrid()
    self:_EnsureTilePool()
    self._tilePool:ReleaseAll()
    self.tileFrames = {}
    self.tileTex    = {}
end

function R:BuildGrid(cols, imageIdx)
    self:CancelPresentation()
    self:_ClearTileGrid()

    -- Reveal-Komponenten verstecken (wiederverwendbar)
    self:_HideReveal()

    self:CancelPresentation()
    self._cols      = cols
    self._imageIdx  = imageIdx
    self._imagePath = GetImagePath(imageIdx)

    local Logic = ArcadiaNexus.SLP_Logic
    local n     = cols * cols
    local gridW = math.floor(GRID_BASE_W * CFG.grid_scale)
    local gridH = math.floor(GRID_BASE_H * CFG.grid_scale)
    local tileW = math.floor(gridW / cols)
    local tileH = math.floor(gridH / cols)
    local gf    = self.gridFrame
    self:_EnsureTilePool()

    for pos = 1, n do
        local tileID = Logic.board[pos]

        local col = ((pos - 1) % cols)
        local row = math.floor((pos - 1) / cols)
        local px  = col * tileW
        local py  = -(row * tileH)

        local f = self._tilePool:Acquire({})
        f:SetParent(gf)
        f:SetSize(tileW, tileH)
        f:SetPoint("TOPLEFT", gf, "TOPLEFT", px, py)
        f:SetBackdropColor(0.05, 0.05, 0.05, 1)
        f:SetBackdropBorderColor(0.25, 0.20, 0.12, 0.8)

        local tex = f._tex
        if tileID == 0 then
            f:SetBackdropColor(0, 0, 0, 1)
            tex:SetAlpha(0)
        else
            tex:SetTexture(self._imagePath)
            local l, r, t, b = Logic:GetTexCoord(tileID, cols)
            tex:SetTexCoord(l, r, t, b)
            tex:SetAlpha(1)
        end

        f._tilePos = pos
        f._tileID=tileID
        f:SetScript("OnClick", function(self)
            ArcadiaNexus.SLP_Engine:OnTileClicked(self._tilePos)
        end)
        f:SetScript("OnEnter", function(self2)
            local eng = ArcadiaNexus.SLP_Engine
            if eng.state ~= "PLAYING" then return end
            local log = ArcadiaNexus.SLP_Logic
            if log:CanMove(self2._tilePos) then
                self2:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
            end
        end)
        f:SetScript("OnLeave", function(self2)
            self2:SetBackdropBorderColor(0.25, 0.20, 0.12, 0.8)
        end)
        f:Show()

        self.tileFrames[pos] = f
        self.tileTex[pos]    = tex
    end

    self:RefreshNumbers()
    local UI = ArcadiaNexus.UI
    if self._goldGrid and UI and UI.FitGoldGridFrame and gf then
        UI.FitGoldGridFrame(self._goldGrid, gf, {
            w = tileW * cols,
            h = tileH * cols,
            x = CFG.gold_ofs_x,
            y = CFG.gold_ofs_y,
        })
    end
end

-- ── Kachel verschieben ────────────────────────────────────────

function R:MoveTile(source,target,done,before)
    presentation:Stop(); self:_PaintBoard(before)
    local f=self.tileFrames[source]; local sx,sy=self:_GetTileOffset(source); local tx,ty=self:_GetTileOffset(target)
    f:SetFrameLevel(self.gridFrame:GetFrameLevel()+5)
    self._slideFrame=f; local elapsed=0; local run,rev=ArcadiaNexus.SLP_Engine._runId,ArcadiaNexus.SLP_Engine._revision
    presentation:Start(function(dt)
        local E=ArcadiaNexus.SLP_Engine
        if E._runId~=run or E._revision~=rev then R:CancelSlide(); presentation:Stop(); return end
        elapsed=elapsed+dt; local t=math.min(1,elapsed/CFG.slide_duration)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",R.gridFrame,"TOPLEFT",sx+(tx-sx)*t,sy+(ty-sy)*t)
        if t==1 then presentation:Stop(); R:CancelSlide(); R:RefreshGrid(); if done then done() end end
    end)
end
function R:_PaintBoard(board)
    local L=ArcadiaNexus.SLP_Logic
    for pos=1,self._cols*self._cols do
        local f=self.tileFrames[pos]; if not f then return end
        local id=board[pos]; f._tileID=id; f._tilePos=pos
        local x,y=self:_GetTileOffset(pos); f:ClearAllPoints(); f:SetPoint("TOPLEFT",self.gridFrame,"TOPLEFT",x,y)
        f:SetBackdropColor(id==0 and 0 or .05,id==0 and 0 or .05,id==0 and 0 or .05,1)
        f._tex:SetTexture(self._imagePath); f._tex:SetAlpha(id==0 and 0 or 1)
        if id~=0 then f._tex:SetTexCoord(L:GetTexCoord(id,self._cols)) end
    end
    self:RefreshNumbers()
end
function R:RefreshGrid() self:_PaintBoard(ArcadiaNexus.SLP_Logic.board) end
function R:RefreshNumbers()
    local show=ArcadiaNexus.SLP_Settings:Get("showNumbers")
    for _,f in pairs(self.tileFrames) do
        if f._number then f._number:SetText(f._tileID~=0 and tostring(f._tileID or "") or ""); f._number:SetShown(show and f._tileID~=0) end
    end
end

-- ── HUD aktualisieren ─────────────────────────────────────────

function R:UpdateHUD()
    local E,S=ArcadiaNexus.SLP_Engine,ArcadiaNexus.SLP_Settings
    local L=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    if self._diffOptions then for _,opt in ipairs(self._diffOptions) do opt.label=L["diff_"..opt.key] end end
    if self._imageOptions then for _,opt in ipairs(self._imageOptions) do opt.label=opt.key==0 and L.img_random or L.img_prefix..opt.key end end
    local hud=E.state=="PLAYING" or E.state=="SLIDING" or E.state=="WIN" or E.state=="RESULT_PENDING"
    if self.hud.movesVal then self.hud.movesVal:SetText(tostring(E._moveCount or 0)); self.hud.movesBox:SetShown(hud) end
    if self.hud.timeVal then self.hud.timeVal:SetText(S:Get("timerEnabled") and ArcadiaNexus.Format.SecondsMMSS(math.floor(E:GetElapsed()),false) or "--"); self.hud.timeBox:SetShown(hud) end
    if self._startBtn then
        self._startBtn:SetLabel(E.state=="IDLE" and L.btn_start or E.state=="INTRO" and L.btn_skip or L.btn_exit)
        self._startBtn:SetEnabled(E.state~="GENERATING")
    end
    if self.shuffleBtn then self.shuffleBtn:SetShown(E.state=="PLAYING" or E.state=="SLIDING") end
    for _,dd in ipairs({self._diffDropdown,self._imageDropdown}) do dd:SetEnabled(not E:IsConfigLocked()); dd:RefreshDisplay() end
    if self._timerChk then self._timerChk:SetChecked(S:Get("timerEnabled")) end
    if self._timerChk and self._timerChk._label then self._timerChk._label:SetText(L.lbl_timer) end
    if self.shuffleBtn then self.shuffleBtn:SetLabel(L.btn_preview) end
end
function R:EnterIdleState()
    self:CancelPresentation(); self:HideSlotMenu()
    if self._feedback then self._feedback:Hide() end
    for _,f in pairs(self.tileFrames) do f:Hide() end
    if self._logoTex then self._logoTex:Show() end
    if self._goldGrid then self._goldGrid:Hide() end
    if self._fieldFrame then ArcadiaNexus.UI.HideResultDialog(self._fieldFrame) end
    self:UpdateHUD()
end
function R:OnStateChanged(state)
    if state=="IDLE" then self:EnterIdleState(); return end
    if self._logoTex then self._logoTex:Hide() end
    if self._feedback then self._feedback:Hide() end
    local grid=state~="SLOT_MENU" and state~="GENERATING"
    if self._goldGrid then self._goldGrid:SetShown(grid) end
    if self.gridFrame then self.gridFrame:SetShown(grid) end
    for _,f in pairs(self.tileFrames) do f:SetShown(grid) end
    self:UpdateHUD()
end
function R:ShowSlotMenu()
    if not self._slotMenu then
        local S=ArcadiaNexus.SLP_Settings; local loc=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
        self._slotMenu=ArcadiaNexus.UI.CreateSaveSlotMenu({parent=self._canvas,maxSlots=3,L=loc,
            loadSlot=function(slot)
                local raw=S:LoadSlot(slot); if not raw then return nil end
                if type(raw)~="table" then return {invalid=true} end
                local L=ArcadiaNexus.SLP_Logic; local display=L:Copy(raw)
                if not L:Int(display.timestamp,2147483647) then display.timestamp=nil end
                return display
            end,
            deleteSlot=function(slot) if not S:GetPending(slot) then S:DeleteSlot(slot) end end,
            isPaused=function(save) return not save.completed end,
            canContinue=function(save) return not save.completed end,
            formatInfo=function(save)
                local p=save.puzzle; local L=ArcadiaNexus.SLP_Logic
                return type(p)=="table" and L:Int(p.cols,5) and p.cols>=3 and L:Int(p.imageIndex,19) and p.imageIndex>0
                    and string.format(loc.slot_info,p.cols,p.cols,p.imageIndex) or loc.msg_invalid_save
            end,
            formatPaused=function(save)
                if not ArcadiaNexus.SLP_Logic:Int(save.moves) then return loc.msg_invalid_save end
                return string.format(loc.slot_moves,save.moves)
            end,
            onNewGame=function(slot) ArcadiaNexus.SLP_Engine:StartGame({slot=slot,mode="new"}) end,
            onContinue=function(slot) ArcadiaNexus.SLP_Engine:StartGame({slot=slot,mode="continue"}) end,
            onCancel=function() ArcadiaNexus.SLP_Engine:StopGame() end})
    end
    if self._logoTex then self._logoTex:Hide() end
    self._slotMenu:Show()
end
function R:HideSlotMenu() if self._slotMenu then self._slotMenu:Hide() end end
function R:ShowFeedback(key)
    if not self._feedback then self._feedback=self._canvas:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); self._feedback:SetPoint("TOP",self._canvas,"TOP",0,-50); self._feedback:SetSize(560,40) end
    self._feedback:SetText(ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")[key]); self._feedback:Show()
end

-- ── Win-Reveal-Sequenz ────────────────────────────────────────

function R:_EnsureRevealTile()
    if not self._revealTile then
        local revTile = CreateFrame("Frame", nil, self.gridFrame, "BackdropTemplate")
        revTile:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        revTile:SetBackdropColor(0.05, 0.05, 0.05, 1)
        local tex = revTile:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT",     revTile, "TOPLEFT",     1, -1)
        tex:SetPoint("BOTTOMRIGHT", revTile, "BOTTOMRIGHT", -1, 1)
        revTile._tex = tex
        self._revealTile = revTile
    end
    return self._revealTile
end

function R:_EnsureRevealFrame()
    if not self._revealFrame then
        local reveal = CreateFrame("Frame", nil, self.gridFrame, "BackdropTemplate")
        reveal:EnableMouse(false)
        local tex = reveal:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(reveal)
        reveal._tex = tex
        self._revealFrame = reveal
    end
    return self._revealFrame
end

function R:_HideReveal()
    if self._revealTile then
        self._revealTile:SetScript("OnUpdate", nil)
        self._revealTile:Hide()
        self._revealTile:SetAlpha(0)
    end
    if self._revealFrame then
        self._revealFrame:SetScript("OnUpdate", nil)
        self._revealFrame:Hide()
        self._revealFrame:SetAlpha(0)
    end
end

function R:StartWinReveal(done)
    ArcadiaNexus.SLP_Engine:PlayEffect("soundOnWin",SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK)
    presentation:Stop(); if self._referenceFrame then self._referenceFrame:Hide() end
    local f=self:_EnsureRevealFrame(); f:SetAllPoints(self.gridFrame); f:SetFrameLevel(self.gridFrame:GetFrameLevel()+10)
    f._tex:SetTexture(self._imagePath); f._tex:SetTexCoord(0,1,0,1); f:SetAlpha(0); f:Show()
    local elapsed=0; local run=ArcadiaNexus.SLP_Engine._runId
    presentation:Start(function(dt)
        local E=ArcadiaNexus.SLP_Engine
        if E._runId~=run or E._revision~=rev or E.state~="WIN" then R:CancelPresentation(); return end
        elapsed=elapsed+dt; f:SetAlpha(math.min(1,elapsed/.9))
        if elapsed>=.9 then presentation:Stop(); if done then done() end end
    end)
end
function R:ShowWinResult(data)
    local L=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH"); local run=data.runId
    local lines={string.format(L.win_moves,data.stats.moves),string.format(L.win_time,ArcadiaNexus.Format.SecondsMMSS(data.stats.time,false)),L.records_independent}
    local S=ArcadiaNexus.SLP_Settings; local best=S:GetPuzzleBest(data.puzzle.puzzleId)
    if best then
        lines[#lines+1]=string.format(L.puzzle_best_moves,best.moves)
        lines[#lines+1]=string.format(L.puzzle_best_time,ArcadiaNexus.Format.SecondsMMSS(best.elapsedMs/1000,false))
    end
    local oldMoves,oldTime,oldSize=S:GetLegacyBests(data.stats.difficulty)
    if oldMoves>0 then lines[#lines+1]=string.format(L.legacy_best_moves,oldSize,oldSize,oldMoves) end
    if oldTime>0 then lines[#lines+1]=string.format(L.legacy_best_time,oldSize,oldSize,ArcadiaNexus.Format.SecondsMMSS(oldTime,false)) end
    if data.newMetricRecords.moves then lines[#lines+1]=L.record_moves end
    if data.newMetricRecords.time then lines[#lines+1]=L.record_time end
    ArcadiaNexus.UI.ShowArcadeResult(self._fieldFrame,{gameId="MOSAICOFAZEROTH",difficulty=data.difficulty,result="WIN",
        title=L.win_title,xp=data.awardedXP,gold=data.awardedGold,hideHighscore=true,lines=lines,L=L,
        isCurrent=function() return ArcadiaNexus.SLP_Engine._runId==run and ArcadiaNexus.SLP_Engine.state=="WIN" end,
        onRetry=function() ArcadiaNexus.SLP_Engine:RetryPuzzle() end,onExit=function() ArcadiaNexus.SLP_Engine:StopGame() end})
end
function R:ShowPendingResult()
    local E=ArcadiaNexus.SLP_Engine; local run=E._runId; local L=ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    ArcadiaNexus.UI.ShowArcadeResult(self._fieldFrame,{title=L.result_pending,xp=0,hideHighscore=true,lines={L.result_pending_tip},L=L,
        isCurrent=function() return E._runId==run and E.state=="RESULT_PENDING" end,
        onRetry=function() E:RetryResult() end,onExit=function() E:StopGame() end})
end

-- ── Init ──────────────────────────────────────────────────────

function R:Init()
    self:CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateGridFrame()
    self:_CreateHUD()
    self:_CreateControls()
    self:UpdateHUD()
end

-- ── RegisterGame ──────────────────────────────────────────────

ArcadiaNexus.RegisterGame({
    id        = "MOSAICOFAZEROTH",
    label     = "Mosaic of Azeroth",
    category  = "RAETSEL",
    renderer  = "SLP_Renderer",
    engine    = "SLP_Engine",
    container = "_slpContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\SlidingPuzzle\\assets\\logo\\logo_moa",
    xp        = 10,
})
