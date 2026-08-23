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

    -- Mischen-Button (TOPLEFT relativ zu self.frame)
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
R._animGen      = 0

-- ── Hilfsfunktion: Fade ───────────────────────────────────────

local function FadeFrame(frame, fromAlpha, toAlpha, duration, onDone, isValid)
    if type(duration) ~= "number" or duration <= 0 then duration = 0.01 end
    local elapsed = 0
    frame:SetAlpha(fromAlpha)
    frame:SetScript("OnUpdate", function(self, dt)
        if isValid and not isValid() then
            self:SetScript("OnUpdate", nil)
            return
        end
        if type(dt) ~= "number" then dt = 0 end
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        self:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * t)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            if isValid and not isValid() then return end
            if onDone then onDone() end
        end
    end)
end

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
        ArcadiaNexus.GameSession:HandleRendererHide("MOSAICOFAZEROTH", ArcadiaNexus.SLP_Engine, function(E)
            if E.state ~= "IDLE" then
                E:StopGame()
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

local function MakeInfoBox(parent, x, y, w, h, title)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(w, h)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    box:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    box:SetBackdropBorderColor(0.35, 0.30, 0.20, 0.9)

    local lbl = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
    lbl:SetTextColor(0.7, 0.65, 0.45)
    lbl:SetText(title)

    local val = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("CENTER", box, "CENTER", 0, -4)
    val:SetText("0")

    return box, val
end

function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")

    local movesBox, movesVal = MakeInfoBox(f,
        CFG.hud_ofs_x, CFG.hud_ofs_y,
        CFG.hud_w, CFG.hud_h,
        L and L.lbl_moves or "Züge")
    local timeBox, timeVal = MakeInfoBox(f,
        CFG.hud_ofs_x, CFG.hud_ofs_y + CFG.hud_gap,
        CFG.hud_w, CFG.hud_h,
        L and L.lbl_time or "Zeit")

    self.hud.movesBox = movesBox
    self.hud.timeBox  = timeBox
    self.hud.movesVal = movesVal
    self.hud.timeVal  = timeVal
    if movesBox then movesBox:Hide() end
    if timeBox  then timeBox:Hide()  end
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

    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(dd_w * 2 + dd_gap, btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddDiffAnchor = CreateFrame("Frame", nil, pair)
    ddDiffAnchor:SetSize(dd_w, btn_h)
    ddDiffAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)
    UI.CreateSimpleDropdown(ddDiffAnchor, 0, 0, dd_w, "",
        diffOptions,
        function() return ArcadiaNexus.SLP_Settings:Get("difficulty") end,
        function(val) ArcadiaNexus.SLP_Settings:Set("difficulty", val) end
    )

    local ddImgAnchor = CreateFrame("Frame", nil, pair)
    ddImgAnchor:SetSize(dd_w, btn_h)
    ddImgAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    UI.CreateSimpleDropdown(ddImgAnchor, 0, 0, dd_w, "",
        BuildImageOptions(),
        function() return ArcadiaNexus.SLP_Settings:Get("imageIndex") end,
        function(val) ArcadiaNexus.SLP_Settings:Set("imageIndex", val) end
    )

    local startBtn = UI.CreateArcadiaButton(cf,
        L and L.btn_start or "Spiel starten", btn_w, btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SLP_Engine
        if E.state == "IDLE" then
            E:StartGame()
        else
            E:StopGame()
        end
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
        L and L.btn_shuffle or "Mischen", CFG.shuffle_w, CFG.shuffle_h)
    shuffleBtn:SetPoint("TOPLEFT", self._canvas, "TOPLEFT", CFG.shuffle_ofs_x, CFG.shuffle_ofs_y)
    shuffleBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SLP_Engine
        if E.state == "PLAYING" then
            E:Reshuffle()
        end
    end)
    self.shuffleBtn = shuffleBtn
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
    FadeFrame(self._previewFrame, 0, 1, 0.3, nil)
    self.gridFrame:Hide()
end

function R:_HidePreview()
    if self._previewFrame then
        self._previewFrame:Hide()
        self._previewFrame:SetAlpha(0)
    end
end

-- ── Split-Animation ───────────────────────────────────────────

function R:PlaySplitAnimation(onDone)
    self.gridFrame:SetAlpha(0)
    self.gridFrame:Show()
    FadeFrame(self._previewFrame, 1, 0, 0.5, function()
        R:_HidePreview()
    end)
    FadeFrame(self.gridFrame, 0, 1, 0.5, function()
        if onDone then onDone() end
    end)
    C_Sound.PlaySound(SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 1, "Master")
end

-- ── Shuffle-Animation ─────────────────────────────────────────

function R:_GetShuffleDelay()
    local E = ArcadiaNexus.SLP_Engine
    local diff = E and E._difficulty or "easy"
    if diff == "hard"   then return 0.008 end
    if diff == "medium" then return 0.015 end
    return 0.025
end

function R:_GetTileOffset(pos)
    local cols  = self._cols
    local gridW = math.floor(GRID_BASE_W * CFG.grid_scale)
    local gridH = math.floor(GRID_BASE_H * CFG.grid_scale)
    local tileW = math.floor(gridW / cols)
    local tileH = math.floor(gridH / cols)
    local col   = ((pos - 1) % cols)
    local row   = math.floor((pos - 1) / cols)
    return col * tileW, -(row * tileH)
end

function R:_SwapTilePositions(posA, posB)
    local frameA = self.tileFrames[posA]
    local frameB = self.tileFrames[posB]
    if not frameA or not frameB then return end
    local axOff, ayOff = self:_GetTileOffset(posA)
    local bxOff, byOff = self:_GetTileOffset(posB)
    frameA:ClearAllPoints()
    frameA:SetPoint("TOPLEFT", self.gridFrame, "TOPLEFT", bxOff, byOff)
    frameB:ClearAllPoints()
    frameB:SetPoint("TOPLEFT", self.gridFrame, "TOPLEFT", axOff, ayOff)
    self.tileFrames[posA] = frameB
    self.tileFrames[posB] = frameA
end

function R:PlayShuffleAnimation(moveHistory, cols, imageIdx, myGen, onDone)
    local index = 1
    local delay = self:_GetShuffleDelay()
    local total = #moveHistory

    local function Step()
        if self._animGen ~= myGen then return end
        if index > total then
            self:BuildGrid(cols, imageIdx)
            if onDone then onDone() end
            return
        end
        local move = moveHistory[index]
        self:_SwapTilePositions(move.tilePos, move.emptyPos)
        index = index + 1
        C_Timer.After(delay, Step)
    end

    Step()
end

function R:StartIntroSequence(cols, imageIdx, moveHistory, onDone)
    self._animGen = self._animGen + 1
    local myGen   = self._animGen

    self:BuildGrid(cols, imageIdx)
    self:ShowPreview(self._imagePath)

    C_Timer.After(1.5, function()
        if self._animGen ~= myGen then return end
        self:PlaySplitAnimation(function()
            if self._animGen ~= myGen then return end
            self:PlayShuffleAnimation(moveHistory, cols, imageIdx, myGen, function()
                if self._animGen ~= myGen then return end
                C_Timer.After(0.3, function()
                    if self._animGen ~= myGen then return end
                    if onDone then onDone() end
                end)
            end)
        end)
    end)
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
    self:_ClearTileGrid()

    -- Reveal-Komponenten verstecken (wiederverwendbar)
    self:_HideReveal()

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

function R:MoveTile(oldTilePos, newEmptyPos)
    self:RefreshGrid()
end

-- Komplettes Grid neu zeichnen (Board-State → Frames)
function R:RefreshGrid()
    local Logic = ArcadiaNexus.SLP_Logic
    local cols  = self._cols
    local n     = cols * cols

    for pos = 1, n do
        local f   = self.tileFrames[pos]
        local tex = self.tileTex[pos]
        if not f then break end

        local tileID = Logic.board[pos]
        if tileID == 0 then
            f:SetBackdropColor(0, 0, 0, 1)
            f:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
            tex:SetAlpha(0)
        else
            f:SetBackdropColor(0.05, 0.05, 0.05, 1)
            f:SetBackdropBorderColor(0.25, 0.20, 0.12, 0.8)
            tex:SetAlpha(1)
            tex:SetTexture(self._imagePath)
            local l, r, t, b = Logic:GetTexCoord(tileID, cols)
            tex:SetTexCoord(l, r, t, b)
        end
    end
end

-- ── HUD aktualisieren ─────────────────────────────────────────

function R:UpdateHUD()
    local E = ArcadiaNexus.SLP_Engine
    local S = ArcadiaNexus.SLP_Settings

    if self.hud.movesVal then
        self.hud.movesVal:SetText(tostring(E._moveCount or 0))
    end

    local showHud = E and E.state == "PLAYING"
    if self.hud.movesBox then self.hud.movesBox:SetShown(showHud) end
    if self.hud.timeBox  then self.hud.timeBox:SetShown(showHud)  end

    if self.hud.timeVal then
        local showTimer = S:Get("timerEnabled")
        if showTimer and E.state == "PLAYING" then
            local sec = math.floor(E:GetElapsed())
            self.hud.timeVal:SetText(ArcadiaNexus.Format.SecondsMMSS(sec, false))
        elseif showTimer then
            self.hud.timeVal:SetText("--:--")
        else
            self.hud.timeVal:SetText("–")
        end
    end

    -- Start-Button Label kontextuell
    local L = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    if self._startBtn then
        if E.state == "IDLE" then
            self._startBtn:SetLabel(L and L.btn_start or "Spiel starten")
        else
            self._startBtn:SetLabel(L and L.btn_exit or "Beenden")
        end
    end

    -- Mischen-Button nur im PLAYING-State
    if self.shuffleBtn then
        self.shuffleBtn:SetShown(E.state == "PLAYING")
    end
end

-- ── EnterIdleState (Einstiegspunkt via ActivateGame) ─────────

function R:EnterIdleState()
    -- Laufende Animationen abbrechen
    self._animGen = self._animGen + 1
    self:_HidePreview()
    -- Kacheln ausblenden
    for _, f in pairs(self.tileFrames) do
        f:Hide()
    end
    self:_HideReveal()
    if self.gridFrame then self.gridFrame:SetAlpha(1) end
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    -- Logo einblenden
    if self._logoTex then self._logoTex:Show() end
    if self._goldGrid then self._goldGrid:Hide() end
    if self.hud.movesBox then self.hud.movesBox:Hide() end
    if self.hud.timeBox  then self.hud.timeBox:Hide()  end
    self:UpdateHUD()
end

-- ── State-Änderungen ──────────────────────────────────────────

function R:OnStateChanged(newState)
    self:UpdateHUD()
    if newState == "IDLE" then
        -- Laufende Intro-Animationen abbrechen
        self._animGen = self._animGen + 1
        self:_HidePreview()
        for _, f in pairs(self.tileFrames) do
            f:Hide()
        end
        self:_HideReveal()
        self.gridFrame:SetAlpha(1)
        if self._fieldFrame and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
        end
        -- Logo im IDLE-State einblenden
        if self._logoTex then self._logoTex:Show() end
        if self._goldGrid then self._goldGrid:Hide() end
        if self.hud.movesBox then self.hud.movesBox:Hide() end
        if self.hud.timeBox  then self.hud.timeBox:Hide()  end
    elseif newState == "PLAYING" then
        -- Logo beim Spielstart ausblenden
        if self._logoTex then self._logoTex:Hide() end
        if self._goldGrid then self._goldGrid:Show() end
        if self.hud.movesBox then self.hud.movesBox:Show() end
        if self.hud.timeBox  then self.hud.timeBox:Show()  end
    end
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

local function RevealStillValid(renderer, myGen, sid, expectedFrame)
    if renderer._animGen ~= myGen then return false end
    local E = ArcadiaNexus.SLP_Engine
    if not E or E.state ~= "WIN" then return false end
    if sid and ArcadiaNexus.GameSession and not ArcadiaNexus.GameSession:IsSession(E, sid) then
        return false
    end
    if expectedFrame and expectedFrame._revealGen ~= myGen then return false end
    return true
end

function R:StartWinReveal(onDone)
    self._animGen = self._animGen + 1
    local myGen = self._animGen
    local E     = ArcadiaNexus.SLP_Engine
    local sid   = E and E._sessionId

    local function stillValid(expectedFrame)
        return RevealStillValid(self, myGen, sid, expectedFrame)
    end

    local Logic  = ArcadiaNexus.SLP_Logic
    local cols   = self._cols
    local n      = cols * cols
    local lastID = n

    for _, f in pairs(self.tileFrames) do
        f:EnableMouse(false)
    end

    local emptyPos = Logic.emptyPos
    local refFrame = self.tileFrames[emptyPos]
    if not refFrame then
        self:_RevealFullImage(onDone, myGen, sid)
        return
    end

    local revTile = self:_EnsureRevealTile()
    revTile._revealGen = myGen
    revTile:SetParent(self.gridFrame)
    revTile:SetSize(refFrame:GetWidth(), refFrame:GetHeight())
    revTile:ClearAllPoints()
    revTile:SetPoint("TOPLEFT", refFrame, "TOPLEFT", 0, 0)
    revTile:SetFrameLevel(refFrame:GetFrameLevel() + 5)

    local tex = revTile._tex
    tex:SetTexture(self._imagePath)
    local l, r, t, b = Logic:GetTexCoord(lastID, cols)
    tex:SetTexCoord(l, r, t, b)

    revTile:SetAlpha(0)
    revTile:Show()

    C_Sound.PlaySound(SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 1, "Master")

    FadeFrame(revTile, 0, 1, 0.4, function()
        if not stillValid(revTile) then return end
        C_Timer.After(0.3, function()
            if not stillValid(revTile) then return end
            R:_RevealFullImage(onDone, myGen, sid)
        end)
    end, function()
        return stillValid(revTile)
    end)
end

function R:_RevealFullImage(onDone, myGen, sid)
    myGen = myGen or self._animGen
    local function stillValid(expectedFrame)
        return RevealStillValid(self, myGen, sid, expectedFrame)
    end
    if not stillValid() then return end

    local gf = self.gridFrame
    if not gf then
        return
    end

    local reveal = self:_EnsureRevealFrame()
    reveal._revealGen = myGen
    reveal:SetParent(gf)
    reveal:ClearAllPoints()
    reveal:SetAllPoints(gf)
    reveal:SetFrameLevel(gf:GetFrameLevel() + 10)
    reveal:SetAlpha(0)
    reveal:EnableMouse(false)

    local tex = reveal._tex
    tex:SetTexture(self._imagePath)
    tex:SetTexCoord(0, 1, 0, 1)

    reveal:Show()

    FadeFrame(reveal, 0, 1, 0.5, function()
        if not stillValid(reveal) then return end
        if onDone then onDone() end
    end, function()
        return stillValid(reveal)
    end)
end

function R:ShowWinResult(score, moves, elapsed, diff)
    local parent = self._fieldFrame
    if not parent then return end
    local L  = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")
    local UI = ArcadiaNexus.UI
    local timeStr = ArcadiaNexus.Format.SecondsMMSS(elapsed or 0, false)
    UI.ShowArcadeResult(parent, {
        title      = (L and L.win_title) or "Gelöst!",
        titleColor = { 1, 0.84, 0 },
        score      = score,
        gameId     = "MOSAICOFAZEROTH",
        difficulty = diff,
        result     = "WIN",
        lines      = {
            string.format((L and L.win_moves) or "Züge: %d", moves or 0),
            string.format((L and L.win_time) or "Zeit: %s", timeStr),
        },
        L          = L,
        onRetry    = function()
            local Eng = ArcadiaNexus.SLP_Engine
            if Eng then Eng:StartGame() end
        end,
        onExit     = function()
            local Eng = ArcadiaNexus.SLP_Engine
            if Eng then Eng:StopGame() end
        end,
    })
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
})
