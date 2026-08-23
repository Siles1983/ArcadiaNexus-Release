--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Renderer.lua  v2.0

    FIXES v2:
    - Adaptives Layout: alles wird aus verfügbarem Panel-Raum berechnet
    - Pegs: Anzahl = codeLength (nicht fix 4), Layout ceil(codeLen/2) × 2
    - Runde Icons: SetTexCoord(0.08,0.92,0.08,0.92) + Circular Mask via
      Interface\CHARACTERFRAME\TempPortraitAlphaMask
    - Palette passt sich Panelbreite an (Symbole nie > Panel)
    - Settings: Vorschau-Label über den Icons (kein Überlappen)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Renderer = {}
local R = ArcadiaNexus.CB_Renderer

-- Runde Maske – Standard WoW circular alpha mask
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- ============================================================
-- CFG – Layout-Konstanten
-- ============================================================
local CFG = {
    -- _fieldFrame (CENTER-Anker, kein bgFile)
    field_w      = 560,
    field_h      = 580,
    field_ofs_x  = 0,
    field_ofs_y  = 20,

    -- Hintergrund (relativ zu _fieldFrame CENTER)
    bg_w         = 670,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1,

    -- Border (relativ zu _fieldFrame CENTER)
    border_w     = 800,
    border_h     = 553,
    border_ofs_x = 0,
    border_ofs_y = -2,

    -- Logo (relativ zu _fieldFrame CENTER)
    logo_w       = 447,
    logo_h       = 411,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,

    -- Board (boardHolder, relativ zu _fieldFrame BOTTOMLEFT)
    -- board_ofs_y: positiver Wert = Abstand vom unteren Rand nach oben
    board_ofs_x  = 0,
    board_ofs_y  = -140,
    board_scale  = 0.8,   -- Skalierungsfaktor fuer slotSize (z.B. 0.8 = 80%)

    -- Palette (palFrame, relativ zu _fieldFrame BOTTOM CENTER)
    pal_ofs_x    = 8,     -- X-Rand links/rechts
    pal_ofs_y    = 65,    -- Y-Versatz vom _fieldFrame BOTTOM
    pal_scale    = 0.78,   -- Skalierungsfaktor fuer palSize (z.B. 0.9 = 90%)

    -- Eingabezeile (_inputFrame, relativ zu _fieldFrame BOTTOM)
    -- Wird dynamisch als pal_ofs_y + palSize + 8 berechnet

    -- HUD (Canvas, unabhängig)
    hud_score_w     = 140,
    hud_score_h     = 28,
    hud_score_x     = 0,
    hud_score_y     = -450,
    hud_score_alpha = 0.75,
    hud_best_w      = 140,
    hud_best_h      = 28,
    hud_best_x      = 0,
    hud_best_y      = -450,
    hud_best_alpha  = 0.75,

    -- Popup (relativ zu _fieldFrame CENTER)
    ov_w         = 360,
    ov_h         = 220,
    ov_ofs_x     = 0,
    ov_ofs_y     = 0,
    ov_title_y   = 60,
    ov_sub_gap   = -14,
    ov_btn_gap   = -20,
    ov_btn_w     = 160,
    ov_btn_h     = 30,

    -- Pruefen-Button
    submit_btn_w = 80,
    submit_btn_h = 28,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local CB_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\Codebreaker\\assets\\background\\background_cb",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\Codebreaker\\assets\\border\\border_cb",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Codebreaker\\assets\\logo\\logo_cb",
}

-- State
R.frame           = nil
R.state           = "IDLE"
R.selectedDiff    = nil
R.selectedSlot    = 1
R.attemptRows     = {}
R.inputSlots      = {}
R.paletteButtons  = {}
R.submitButton    = nil
R.boardHolder     = nil
R.diffContainer   = nil
R.diffBtns        = {}
R.dupCheckbox     = nil
R.codeLenDropdown = nil
R.exitButton      = nil
R.newGameButton   = nil
R.statusFS        = nil
R.hintFS          = nil
R.divLine         = nil
R._palFrame       = nil
R._inputFrame     = nil
R._inputDivLine   = nil
R._attemptSlotPool = nil
R._attemptPegPool  = nil
R._inputSlotPool   = nil
R._paletteBtnPool  = nil

-- ============================================================
-- Runde Textur-Hilfsfunktion
-- Erstellt eine Textur mit kreisförmigem Clip via Mask
-- ============================================================
local function MakeRoundIcon(parent, size, layer)
    layer = layer or "ARTWORK"

    -- Icon-Textur
    local tex = parent:CreateTexture(nil, layer)
    tex:SetSize(size, size)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Runde Maske via CreateMaskTexture (Retail + Midnight)
    -- Fallback: falls API nicht verfügbar, kein Crash
    local maskTex = nil
    if parent.CreateMaskTexture then
        maskTex = parent:CreateMaskTexture()
        maskTex:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        maskTex:SetSize(size, size)
        tex:AddMaskTexture(maskTex)
    end

    return tex, maskTex
end

local function CreateAttemptSlotPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Codebreaker.AttemptSlots",
        create = function(poolParent)
            poolParentRef = poolParent
            local slotFrame = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            slotFrame:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
            local iconTex, maskTex = MakeRoundIcon(slotFrame, 32, "ARTWORK")
            iconTex:SetPoint("CENTER")
            if maskTex then maskTex:SetPoint("CENTER") end
            iconTex:Hide()
            if maskTex then maskTex:Hide() end
            slotFrame.icon    = iconTex
            slotFrame.maskTex = maskTex
            return slotFrame
        end,
        onRelease = function(slotFrame)
            slotFrame:Hide()
            slotFrame:ClearAllPoints()
            if slotFrame.icon then
                slotFrame.icon:Hide()
                slotFrame.icon:SetTexture(nil)
            end
            if slotFrame.maskTex then slotFrame.maskTex:Hide() end
            if poolParentRef then slotFrame:SetParent(poolParentRef) end
        end,
    })
end

local function CreateAttemptPegPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Codebreaker.AttemptPegs",
        create = function(poolParent)
            poolParentRef = poolParent
            local peg = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            peg:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
            local pegTex, pegMaskTex = MakeRoundIcon(peg, 16, "ARTWORK")
            pegTex:SetPoint("CENTER")
            if pegMaskTex then pegMaskTex:SetPoint("CENTER") end
            pegTex:Hide()
            if pegMaskTex then pegMaskTex:Hide() end
            peg.icon    = pegTex
            peg.maskTex = pegMaskTex
            return peg
        end,
        onRelease = function(peg)
            peg:Hide()
            peg:ClearAllPoints()
            if peg.icon then
                peg.icon:Hide()
                peg.icon:SetTexture(nil)
            end
            if peg.maskTex then peg.maskTex:Hide() end
            if poolParentRef then peg:SetParent(poolParentRef) end
        end,
    })
end

local function CreateInputSlotPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Codebreaker.InputSlots",
        create = function(poolParent)
            poolParentRef = poolParent
            local slot = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            slot:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 2,
                insets = { left=2, right=2, top=2, bottom=2 },
            })
            slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local iconTex, maskTex = MakeRoundIcon(slot, 32, "ARTWORK")
            iconTex:SetPoint("CENTER")
            if maskTex then maskTex:SetPoint("CENTER") end
            iconTex:Hide()
            if maskTex then maskTex:Hide() end
            slot.icon    = iconTex
            slot.maskTex = maskTex
            return slot
        end,
        onRelease = function(slot)
            slot:Hide()
            slot:ClearAllPoints()
            slot:Enable()
            slot:SetScript("OnClick", nil)
            slot:SetScript("OnEnter", nil)
            slot:SetScript("OnLeave", nil)
            slot._slotIdx = nil
            if slot.icon then
                slot.icon:Hide()
                slot.icon:SetTexture(nil)
            end
            if slot.maskTex then slot.maskTex:Hide() end
            if poolParentRef then slot:SetParent(poolParentRef) end
        end,
    })
end

local function CreatePaletteBtnPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Codebreaker.PaletteButtons",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 2,
                insets = { left=2, right=2, top=2, bottom=2 },
            })
            local iconTex, maskTex = MakeRoundIcon(btn, 32, "ARTWORK")
            iconTex:SetPoint("CENTER")
            if maskTex then maskTex:SetPoint("CENTER") end
            btn._iconTex = iconTex
            btn._maskTex = maskTex
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:Enable()
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetScript("OnClick", nil)
            btn._symIdx = nil
            btn._symName = nil
            btn._symColor = nil
            if btn._iconTex then
                btn._iconTex:Hide()
                btn._iconTex:SetTexture(nil)
            end
            if btn._maskTex then btn._maskTex:Hide() end
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- Init
-- ============================================================
function R:Init()
    self:CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:CreateStatusBar()
    self:_CreateControls()
    self:EnterIdleState()

    self.frame:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("CODEBREAKER", ArcadiaNexus.CB_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)

    local Engine = ArcadiaNexus.Engine
    Engine:On("CB_GAME_STARTED", function(s) R:OnGameStarted(s) end)
    Engine:On("CB_GAME_WON",     function(s) R:OnGameWon(s)     end)
    Engine:On("CB_GAME_LOST",    function(s) R:OnGameLost(s)    end)
    Engine:On("CB_GAME_STOPPED", function()  R:EnterIdleState() end)
end

-- ============================================================
-- Main Frame
-- ============================================================
function R:CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_CB_Container",
        designW   = 600,
        designH   = 580,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    self._fieldFrame = nil
    self._bgTex      = nil
    self._borderFrame= nil
    self._borderTex  = nil
    self._logoTex    = nil
    if _G.ArcadiaNexus then _G.ArcadiaNexus._cbContainer = f end
end

-- ============================================================
-- FIELD FRAME (CENTER-Anker, kein bgFile)
-- ============================================================
function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas)
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = ff
end

-- ============================================================
-- BACKGROUND
-- ============================================================
function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(CB_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- ============================================================
-- BORDER FRAME
-- ============================================================
function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)
    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(CB_ASSETS.border)
    tex:SetAllPoints(borderFrame)
    self._borderFrame = borderFrame
    self._borderTex   = tex
end

-- ============================================================
-- LOGO
-- ============================================================
function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        CB_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- ComputeLayout – berechnet alle Größen aus Panelgröße
-- Gibt eine layout-Tabelle zurück
-- ============================================================
function R:ComputeLayout(codeLen, maxAttempts)
    local ff     = self._fieldFrame
    local panelW = (ff and ff:GetWidth())  or CFG.field_w
    local panelH = (ff and ff:GetHeight()) or CFG.field_h
    if panelW < 100 then panelW = CFG.field_w end
    if panelH < 100 then panelH = CFG.field_h end

    -- Reservierte Höhe: Statuszeile (28) + pal + input + Padding
    local reservedH = 28 + 20

    -- Palette-Zeile (46px) + Eingabezeile + Trennlinie (2px) + Padding
    local inputZoneH = 52 + 2 + 8   -- Eingabe + Prüfen-Button-Höhe
    local palZoneH   = 50

    local availH = panelH - reservedH - inputZoneH - palZoneH
    if availH < 100 then availH = 100 end

    -- Slot-Größe aus verfügbarer Höhe ableiten, dann mit board_scale skalieren
    local slotSize = math.floor(availH / maxAttempts) - 4
    slotSize = math.max(22, math.min(slotSize, 44))
    slotSize = math.max(10, math.floor(slotSize * (CFG.board_scale or 1.0)))

    local slotGap = math.max(2, math.floor(slotSize * 0.08))
    local rowH    = slotSize + slotGap

    -- Peg-Größe: abhängig von rowH
    local pegCols  = math.ceil(codeLen / 2)   -- Spalten im Peg-Grid
    local pegRows  = 2                          -- immer 2 Zeilen
    local pegSize  = math.max(8, math.floor((rowH - slotGap) / pegRows) - 2)
    local pegGap   = 2

    -- Maximal verfügbare Breite (Padding von 8px je Seite)
    local maxW = panelW - 16

    -- Pegs-Bereich: feste Breite basierend auf codeLen
    local pegsW = pegCols * pegSize + (pegCols - 1) * pegGap + 4

    -- Verfügbare Breite für Slots (nach Pegs + Abstand)
    local slotsMaxW = maxW - pegsW - 14
    -- SlotSize aus Breite begrenzen falls nötig
    local slotSizeByW = math.floor((slotsMaxW - (codeLen-1) * slotGap) / codeLen)
    if slotSizeByW < slotSize then
        slotSize = math.max(20, slotSizeByW)
        slotGap  = math.max(2, math.floor(slotSize * 0.08))
        rowH     = slotSize + slotGap
    end

    local slotsW = codeLen * slotSize + (codeLen - 1) * slotGap
    local rowW   = slotsW + 14 + pegsW

    -- Palette: 6 Symbole gleichmäßig auf Panel-Breite verteilen
    local palMax  = 6
    local palSize = math.max(24, math.floor((maxW - (palMax-1)*8) / palMax))
    palSize = math.min(palSize, 44)
    palSize = math.max(10, math.floor(palSize * (CFG.pal_scale or 1.0)))
    -- Gesamtbreite der Palette berechnen für Zentrierung
    local palTotalW = palMax * palSize + (palMax-1) * 8
    local palGap  = 8  -- fixer Gap zwischen Palette-Buttons

    -- Board horizontal zentriert (wird nicht mehr als boardOffX zurueckgegeben –
    -- Position via CFG.board_ofs_x/y, stabil unabhaengig von Schwierigkeit)

    return {
        slotSize   = slotSize,
        slotGap    = slotGap,
        rowH       = rowH,
        pegSize    = pegSize,
        pegGap     = pegGap,
        pegCols    = pegCols,
        pegRows    = pegRows,
        slotsW     = slotsW,
        pegsW      = pegsW,
        rowW       = rowW,
        palSize    = palSize,
        palGap     = palGap,
        palTotalW  = palTotalW,
        boardH     = maxAttempts * rowH,
        availH     = availH,
        panelW     = panelW,
    }
end

-- ============================================================
-- BuildBoard
-- ============================================================
function R:_EnsureBoardPools()
    if not self._attemptSlotPool then self._attemptSlotPool = CreateAttemptSlotPool() end
    if not self._attemptPegPool  then self._attemptPegPool  = CreateAttemptPegPool() end
    if not self._inputSlotPool   then self._inputSlotPool   = CreateInputSlotPool() end
    if not self._paletteBtnPool  then self._paletteBtnPool  = CreatePaletteBtnPool() end
end

function R:_EnsureBoardSkeleton()
    local ff = self._fieldFrame
    if not ff then return end

    if not self.boardHolder then
        self.boardHolder = CreateFrame("Frame", nil, ff)
    end

    if not self.divLine then
        local div = self.boardHolder:CreateTexture(nil, "ARTWORK")
        div:SetTexture("Interface\\Buttons\\WHITE8X8")
        div:SetHeight(1)
        div:SetVertexColor(0.7, 0.6, 0.25, 0.9)
        self.divLine = div
    end

    if not self._palFrame then
        self._palFrame = CreateFrame("Frame", nil, ff)
    end

    if not self._inputFrame then
        self._inputFrame = CreateFrame("Frame", nil, ff)
        local div2 = self._inputFrame:CreateTexture(nil, "ARTWORK")
        div2:SetTexture("Interface\\Buttons\\WHITE8X8")
        div2:SetHeight(1)
        div2:SetVertexColor(0.7, 0.6, 0.25, 0.9)
        self._inputDivLine = div2
    end

    if not self.submitButton then
        local UI = ArcadiaNexus.UI
        self.submitButton = UI.CreateArcadiaButton(
            self._inputFrame,
            ArcadiaNexus.GetLocaleTable("CODEBREAKER")["btn_submit"],
            CFG.submit_btn_w, CFG.submit_btn_h
        )
        self.submitButton:SetScript("OnClick", function()
            ArcadiaNexus.CB_Engine:HandleSubmit()
        end)
    end
end

function R:BuildBoard(state)
    self:ClearBoard()
    self:_EnsureBoardPools()
    self:_EnsureBoardSkeleton()

    local codeLen    = state.codeLength
    local maxAttempts= state.maxAttempts
    local T          = ArcadiaNexus.CB_Themes
    local L          = self:ComputeLayout(codeLen, maxAttempts)

    local holder = self.boardHolder
    holder:SetParent(self._fieldFrame)
    holder:SetPoint("BOTTOM", self._fieldFrame, "CENTER", CFG.board_ofs_x, CFG.board_ofs_y)
    holder:SetSize(L.rowW + 10, L.boardH)
    holder:Show()
    self._layout = L

    self.divLine:ClearAllPoints()
    self.divLine:SetPoint("BOTTOMLEFT",  holder, "BOTTOMLEFT",  0, -2)
    self.divLine:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, -2)
    self.divLine:Show()

    -- Versuchszeilen: Reihe 1 (neuste Eingabe) unten, letzte Reihe oben
    -- i=1 → unterste Zeile, i=maxAttempts → oberste Zeile
    self.attemptRows = {}
    for i = 1, maxAttempts do
        local rowY = (maxAttempts - i) * L.rowH
        local row  = self:CreateAttemptRow(holder, codeLen, L, rowY)
        self:RenderAttemptRowEmpty(row, codeLen)
        self.attemptRows[i] = row
    end

    -- Trennlinie direkt unter dem Board (am BOTTOMLEFT des holders)
    -- (divLine ist Teil des persistenten Skeletts)

    -- Eingabezeile: temporäre Platzhalter – werden nach _inputFrame-Erstellung gesetzt
    -- (Slots werden in der Palette-Sektion ans _inputFrame gehängt, nach holder)
    self.inputSlots   = {}
    self.selectedSlot = 1

    self.paletteButtons = {}
    local symbols    = T:GetTheme(state.theme).symbols
    local palFrame   = self._palFrame
    palFrame:SetParent(self._fieldFrame)
    palFrame:ClearAllPoints()
    palFrame:SetPoint("BOTTOMLEFT",  self._fieldFrame, "BOTTOMLEFT",  CFG.pal_ofs_x, CFG.pal_ofs_y)
    palFrame:SetPoint("BOTTOMRIGHT", self._fieldFrame, "BOTTOMRIGHT", -CFG.pal_ofs_x, CFG.pal_ofs_y)
    palFrame:SetHeight(L.palSize + 4)
    palFrame:Show()

    -- Palette gleichmäßig zentriert auf Panel-Breite verteilen
    local nSym = #symbols
    local palStartX = math.floor((L.panelW - 16 - L.palTotalW) / 2)
    if palStartX < 0 then palStartX = 0 end
    for i, sym in ipairs(symbols) do
        local btn = self._paletteBtnPool:Acquire({})
        btn:SetParent(palFrame)
        btn:SetSize(L.palSize, L.palSize)
        local bx = palStartX + (i-1) * (L.palSize + L.palGap)
        btn:SetPoint("LEFT", palFrame, "LEFT", bx, 0)
        btn:SetBackdropColor(0.05, 0.05, 0.08, 1)
        btn:SetBackdropBorderColor(sym.color[1]*0.55, sym.color[2]*0.55, sym.color[3]*0.55, 1)

        local iconSize = L.palSize - 8
        btn._iconTex:SetSize(iconSize, iconSize)
        if btn._maskTex then btn._maskTex:SetSize(iconSize, iconSize) end
        btn._iconTex:SetTexture(sym.icon)
        btn._iconTex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
        btn._iconTex:Show()
        if btn._maskTex then btn._maskTex:Show() end

        btn._symIdx = i
        btn._symName = sym.name
        btn._symColor = sym.color
        btn:SetScript("OnEnter", function(selfBtn)
            local c = selfBtn._symColor
            selfBtn:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
            GameTooltip:SetText(selfBtn._symName, c[1], c[2], c[3])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            local c = selfBtn._symColor
            selfBtn:SetBackdropBorderColor(c[1]*0.55, c[2]*0.55, c[3]*0.55, 1)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function(selfBtn)
            local slot = R.selectedSlot or 1
            ArcadiaNexus.CB_Engine:HandleSetSlot(slot, selfBtn._symIdx)
            R:AdvanceToNextEmptySlot()
        end)
        btn:Enable()
        btn:Show()
        self.paletteButtons[i] = btn
    end

    -- Eingabe + Prüfen-Button Frame (über Palette)
    local inputBottomY = CFG.pal_ofs_y + L.palSize + 8
    local inputFrame = self._inputFrame
    inputFrame:SetParent(self._fieldFrame)
    inputFrame:ClearAllPoints()
    inputFrame:SetPoint("BOTTOMLEFT",  self._fieldFrame, "BOTTOMLEFT",  8, inputBottomY)
    inputFrame:SetPoint("BOTTOMRIGHT", self._fieldFrame, "BOTTOMRIGHT", -8, inputBottomY)
    inputFrame:SetHeight(L.slotSize + 4)
    inputFrame:Show()

    self._inputDivLine:ClearAllPoints()
    self._inputDivLine:SetPoint("TOPLEFT",  inputFrame, "TOPLEFT",  0, 2)
    self._inputDivLine:SetPoint("TOPRIGHT", inputFrame, "TOPRIGHT", 0, 2)
    self._inputDivLine:Show()

    -- Gesamtbreite der Eingabegruppe berechnen (Slots + Gap + Prüfen-Button)
    local submitW    = CFG.submit_btn_w
    local submitGap  = 8
    local slotsRowW  = codeLen * L.slotSize + (codeLen - 1) * L.slotGap
    local totalInputW = slotsRowW + submitGap + submitW
    -- Startoffset so dass die gesamte Gruppe zentriert ist
    local inputGroupX = math.floor(((L.panelW - 16) - totalInputW) / 2)
    if inputGroupX < 0 then inputGroupX = 0 end

    -- Eingabe-Slots
    for i = 1, codeLen do
        local sx   = inputGroupX + (i-1) * (L.slotSize + L.slotGap)
        local slot = self:CreateInputSlot(inputFrame, i, L, sx, 2)
        self.inputSlots[i] = slot
    end

    local sub = self.submitButton
    sub:SetParent(inputFrame)
    sub:SetLabel(ArcadiaNexus.GetLocaleTable("CODEBREAKER")["btn_submit"])
    sub:ClearAllPoints()
    sub:SetPoint("LEFT", inputFrame, "LEFT", inputGroupX + slotsRowW + submitGap, 0)
    sub:Show()

    self:HighlightInputSlot(1)
end

-- ============================================================
-- CreateAttemptRow
-- Pegs: codeLen Pegs in 2 Reihen à ceil(codeLen/2) Spalten
-- ============================================================
function R:CreateAttemptRow(parent, codeLen, L, offsetY)
    local slots = {}
    local pegs  = {}
    local iconPad = L.slotSize - 6
    local pegPad  = L.pegSize - 3

    for i = 1, codeLen do
        local sx = (i-1) * (L.slotSize + L.slotGap)

        local slotFrame = self._attemptSlotPool:Acquire({})
        slotFrame:SetParent(parent)
        slotFrame:SetSize(L.slotSize, L.slotSize)
        slotFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", sx, -(offsetY + 1))
        slotFrame:SetBackdropColor(0.10, 0.10, 0.13, 1)
        slotFrame:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)
        slotFrame.icon:SetSize(iconPad, iconPad)
        if slotFrame.maskTex then slotFrame.maskTex:SetSize(iconPad, iconPad) end
        slotFrame.icon:Hide()
        if slotFrame.maskTex then slotFrame.maskTex:Hide() end
        slotFrame:Show()
        slots[i] = slotFrame
    end

    local pegBaseX = codeLen * (L.slotSize + L.slotGap) + 8
    local pegIdx   = 0
    for pr = 1, L.pegRows do
        for pc = 1, L.pegCols do
            pegIdx = pegIdx + 1
            if pegIdx <= codeLen then
                local px = pegBaseX + (pc-1) * (L.pegSize + L.pegGap)
                local py = offsetY + 2 + (pr-1) * (L.pegSize + L.pegGap)

                local peg = self._attemptPegPool:Acquire({})
                peg:SetParent(parent)
                peg:SetSize(L.pegSize, L.pegSize)
                peg:SetPoint("TOPLEFT", parent, "TOPLEFT", px, -py)
                peg:SetBackdropColor(0.13, 0.13, 0.16, 1)
                peg:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
                peg.icon:SetSize(pegPad, pegPad)
                if peg.maskTex then peg.maskTex:SetSize(pegPad, pegPad) end
                peg.icon:Hide()
                if peg.maskTex then peg.maskTex:Hide() end
                peg:Show()
                pegs[pegIdx] = peg
            end
        end
    end

    return { slots = slots, pegs = pegs, pegCount = codeLen }
end

-- ============================================================
-- CreateInputSlot (rund, Button)
-- ============================================================
function R:CreateInputSlot(parent, slotIdx, L, offsetX, offsetY)
    local slot = self._inputSlotPool:Acquire({})
    slot:SetParent(parent)
    slot:SetSize(L.slotSize, L.slotSize)
    slot:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, -offsetY)
    slot:SetBackdropColor(0.15, 0.18, 0.30, 1)
    slot:SetBackdropBorderColor(0.30, 0.35, 0.60, 1)

    local iconSize = L.slotSize - 8
    slot.icon:SetSize(iconSize, iconSize)
    if slot.maskTex then slot.maskTex:SetSize(iconSize, iconSize) end
    slot.icon:Hide()
    if slot.maskTex then slot.maskTex:Hide() end

    slot._slotIdx = slotIdx
    slot:SetScript("OnClick", function(selfBtn, button)
        if button == "RightButton" then
            ArcadiaNexus.CB_Engine:HandleClearSlot(selfBtn._slotIdx)
        end
        R:HighlightInputSlot(selfBtn._slotIdx)
    end)
    slot:SetScript("OnEnter", function(selfBtn)
        if selfBtn._slotIdx ~= R.selectedSlot then
            selfBtn:SetBackdropBorderColor(0.60, 0.65, 0.90, 1)
        end
    end)
    slot:SetScript("OnLeave", function(selfBtn)
        if selfBtn._slotIdx ~= R.selectedSlot then
            local hasIcon = selfBtn.icon and selfBtn.icon:IsShown()
            selfBtn:SetBackdropBorderColor(hasIcon and 0.45 or 0.30, hasIcon and 0.40 or 0.35, hasIcon and 0.20 or 0.60, 1)
        end
    end)
    slot:Enable()
    slot:Show()
    return slot
end

-- ============================================================
-- CreatePaletteButton (rund)
-- ============================================================
function R:CreatePaletteButton(parent, symIdx, sym, L, offsetX, offsetY)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(L.palSize, L.palSize)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, -offsetY)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 2,
        insets = { left=2, right=2, top=2, bottom=2 },
    })
    btn:SetBackdropColor(0.05, 0.05, 0.08, 1)
    btn:SetBackdropBorderColor(sym.color[1]*0.55, sym.color[2]*0.55, sym.color[3]*0.55, 1)

    local iconTex, maskTex = MakeRoundIcon(btn, L.palSize - 8, "ARTWORK")
    iconTex:SetPoint("CENTER")
    if maskTex then maskTex:SetPoint("CENTER") end
    iconTex:SetTexture(sym.icon)
    iconTex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
    iconTex:Show()
    if maskTex then maskTex:Show() end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropBorderColor(sym.color[1], sym.color[2], sym.color[3], 1)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText(sym.name, sym.color[1], sym.color[2], sym.color[3])
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropBorderColor(sym.color[1]*0.55, sym.color[2]*0.55, sym.color[3]*0.55, 1)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        local slot = R.selectedSlot or 1
        ArcadiaNexus.CB_Engine:HandleSetSlot(slot, symIdx)
        R:AdvanceToNextEmptySlot()
    end)
    return btn
end

-- ============================================================
-- HighlightInputSlot
-- ============================================================
function R:HighlightInputSlot(idx)
    self.selectedSlot = idx
    for i, slot in ipairs(self.inputSlots) do
        if i == idx then
            slot:SetBackdropBorderColor(1.0, 0.85, 0.0, 1)
            slot:SetBackdropColor(0.20, 0.22, 0.38, 1)
        else
            local hasIcon = slot.icon and slot.icon:IsShown()
            if hasIcon then
                slot:SetBackdropBorderColor(0.50, 0.45, 0.20, 1)
                slot:SetBackdropColor(0.12, 0.14, 0.22, 1)
            else
                slot:SetBackdropBorderColor(0.30, 0.35, 0.60, 1)
                slot:SetBackdropColor(0.15, 0.18, 0.30, 1)
            end
        end
    end
end

-- ============================================================
-- AdvanceToNextEmptySlot
-- ============================================================
function R:AdvanceToNextEmptySlot()
    local board = ArcadiaNexus.CB_Engine.activeGame and ArcadiaNexus.CB_Engine.activeGame.board
    if not board then return end
    for i = self.selectedSlot + 1, board.codeLength do
        if not board.currentGuess[i] or board.currentGuess[i] == 0 then
            self:HighlightInputSlot(i); return
        end
    end
    for i = 1, self.selectedSlot do
        if not board.currentGuess[i] or board.currentGuess[i] == 0 then
            self:HighlightInputSlot(i); return
        end
    end
end

-- ============================================================
-- UpdateInputRow
-- ============================================================
function R:UpdateInputRow()
    local board = ArcadiaNexus.CB_Engine.activeGame and ArcadiaNexus.CB_Engine.activeGame.board
    if not board then return end
    local T = ArcadiaNexus.CB_Themes
    for i = 1, board.codeLength do
        local slot   = self.inputSlots[i]
        local symIdx = board.currentGuess[i] or 0
        if slot then
            if symIdx > 0 then
                local sym = T:GetSymbol(board.theme, symIdx)
                if sym then
                    slot.icon:SetTexture(sym.icon)
                    slot.icon:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
                    slot.icon:Show()
                    if slot.maskTex then slot.maskTex:Show() end
                end
            else
                slot.icon:Hide()
                if slot.maskTex then slot.maskTex:Hide() end
            end
        end
    end
    self:HighlightInputSlot(self.selectedSlot)
end

-- ============================================================
-- UpdateBoard
-- ============================================================
function R:UpdateBoard()
    local board = ArcadiaNexus.CB_Engine.activeGame and ArcadiaNexus.CB_Engine.activeGame.board
    if not board then return end

    for i, attempt in ipairs(board.attempts) do
        local row = self.attemptRows[i]
        if row then self:RenderAttemptRow(row, attempt, board.theme, board.codeLength) end
    end
    for i = #board.attempts + 1, board.maxAttempts do
        local row = self.attemptRows[i]
        if row then self:RenderAttemptRowEmpty(row, board.codeLength) end
    end

    self.selectedSlot = 1
    self:UpdateInputRow()
    self:HighlightInputSlot(1)
    self:UpdateStatus(board)
end

-- ============================================================
-- RenderAttemptRow
-- ============================================================
function R:RenderAttemptRow(row, attempt, themeKey, codeLen)
    local T    = ArcadiaNexus.CB_Themes
    local PEGS = ArcadiaNexus.CB_Themes.PEGS

    for i = 1, codeLen do
        local slot   = row.slots[i]
        local symIdx = attempt.guess[i]
        if slot and symIdx then
            local sym = T:GetSymbol(themeKey, symIdx)
            if sym then
                slot.icon:SetTexture(sym.icon)
                slot.icon:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
                slot.icon:Show()
                if slot.maskTex then slot.maskTex:Show() end
                slot:SetBackdropColor(0.16, 0.14, 0.10, 1)
                slot:SetBackdropBorderColor(sym.color[1]*0.5, sym.color[2]*0.5, sym.color[3]*0.5, 1)
            end
        end
    end

    -- Pegs: exact (Diamant) zuerst, dann partial (Perle)
    local pegIdx = 0
    for _ = 1, attempt.exact do
        pegIdx = pegIdx + 1
        local peg = row.pegs[pegIdx]
        if peg then
            peg.icon:SetTexture(PEGS.exact.icon)
            peg.icon:SetVertexColor(1.0, 1.0, 1.0)
            peg.icon:Show()
            if peg.maskTex then peg.maskTex:Show() end
            peg:SetBackdropBorderColor(0.85, 0.85, 0.6, 1)
        end
    end
    for _ = 1, attempt.partial do
        pegIdx = pegIdx + 1
        local peg = row.pegs[pegIdx]
        if peg then
            peg.icon:SetTexture(PEGS.partial.icon)
            peg.icon:SetVertexColor(0.6, 0.6, 0.6)
            peg.icon:Show()
            if peg.maskTex then peg.maskTex:Show() end
            peg:SetBackdropBorderColor(0.4, 0.4, 0.42, 1)
        end
    end
    -- Leere Pegs ausblenden
    for j = pegIdx + 1, row.pegCount do
        local peg = row.pegs[j]
        if peg then
            peg.icon:Hide()
            peg:SetBackdropColor(0.10, 0.10, 0.13, 1)
            peg:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
        end
    end
end

-- ============================================================
-- RenderAttemptRowEmpty
-- ============================================================
function R:RenderAttemptRowEmpty(row, codeLen)
    for i = 1, codeLen do
        local slot = row.slots[i]
        if slot then
            slot.icon:Hide()
            slot:SetBackdropColor(0.10, 0.10, 0.13, 1)
            slot:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
        end
    end
    for j = 1, (row.pegCount or 4) do
        local peg = row.pegs[j]
        if peg then
            peg.icon:Hide()
            peg:SetBackdropColor(0.10, 0.10, 0.13, 1)
            peg:SetBackdropBorderColor(0.20, 0.20, 0.23, 1)
        end
    end
end

-- ============================================================
-- FlashIncomplete
-- ============================================================
function R:FlashIncomplete()
    local board = ArcadiaNexus.CB_Engine.activeGame and ArcadiaNexus.CB_Engine.activeGame.board
    if not board then return end
    for i = 1, board.codeLength do
        local slot   = self.inputSlots[i]
        local symIdx = board.currentGuess[i] or 0
        if slot and symIdx == 0 then
            slot:SetBackdropBorderColor(1, 0.1, 0.1, 1)
        end
    end
    C_Timer.After(0.4, function() R:HighlightInputSlot(R.selectedSlot) end)
end

-- ============================================================
-- ClearBoard
-- ============================================================
function R:ClearBoard()
    if self._attemptSlotPool then self._attemptSlotPool:ReleaseAll() end
    if self._attemptPegPool  then self._attemptPegPool:ReleaseAll() end
    if self._inputSlotPool   then self._inputSlotPool:ReleaseAll() end
    if self._paletteBtnPool  then self._paletteBtnPool:ReleaseAll() end
    self.attemptRows    = {}
    self.inputSlots     = {}
    self.paletteButtons = {}
    self._layout        = nil
    if self.submitButton then self.submitButton:Hide() end
    if self.divLine      then self.divLine:Hide() end
    if self._inputDivLine then self._inputDivLine:Hide() end
    if self._palFrame    then self._palFrame:Hide() end
    if self._inputFrame  then self._inputFrame:Hide() end
    if self.boardHolder  then self.boardHolder:Hide() end
end

-- ============================================================
-- Status Bar
-- ============================================================
function R:CreateStatusBar()
    if self._scoreBox then return end
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("CODEBREAKER")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self.scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "TOPLEFT", relativePoint = "TOPLEFT",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["hud_score"] or "Punkte") .. ": 0",
        shown = false,
    })
    self._bestBox, self.bestFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "TOPRIGHT", relativePoint = "TOPRIGHT",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["hud_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })
end

local CB_SCORE = { easy = 50, normal = 100, hard = 200 }

function R:UpdateStatus(board)
    local L = ArcadiaNexus.GetLocaleTable("CODEBREAKER")
    local diff = (ArcadiaNexus.CB_Engine and ArcadiaNexus.CB_Engine.activeConfig and ArcadiaNexus.CB_Engine.activeConfig.difficulty)
        or self.selectedDiff or "normal"
    local maxA = math.max(1, (board and board.maxAttempts) or 1)
    local used = math.min(maxA, math.max(1, (board and #board.attempts) or 1))
    local base = CB_SCORE[diff] or 100
    local score = math.max(1, math.floor(base * (maxA - used + 1) / maxA))
    if self.scoreFS then
        self.scoreFS:SetText((L["hud_score"] or "Punkte") .. ": " .. tostring(score))
    end
    local best = 0
    local SM = ArcadiaNexus.ScoreManager
    if SM and SM.GetBestScore then
        best = SM:GetBestScore("CODEBREAKER", diff) or 0
    end
    if self.bestFS then
        self.bestFS:SetText((L["hud_highscore"] or "Highscore") .. ": " .. tostring(best))
    end
    if self._scoreBox then self._scoreBox:Show() end
    if self._bestBox  then self._bestBox:Show()  end
end

-- ============================================================
-- Controls – 3 Segmente (narrow): DD+DD | Start | Checkbox
-- ============================================================
local CODE_LENGTHS = { 3, 4, 5, 6 }

function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("CODEBREAKER")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.CB_Settings

    local CFG_dd_w   = 120
    local CFG_dd_gap = 10
    local CFG_btn_w  = 144
    local CFG_btn_h  = 32

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local DIFFS = {
        { key = "easy",   label = L["diff_easy"]   or "Einfach" },
        { key = "normal", label = L["diff_normal"]  or "Normal"  },
        { key = "hard",   label = L["diff_hard"]    or "Schwer"  },
    }
    local lenOpts = {}
    for _, v in ipairs(CODE_LENGTHS) do
        lenOpts[#lenOpts + 1] = { key = v, label = tostring(v) }
    end

    -- Segment 1: beide Dropdowns nebeneinander, Gruppe mittig
    local pairW = CFG_dd_w * 2 + CFG_dd_gap
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(pairW, CFG_btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddDiffAnchor = CreateFrame("Frame", nil, pair)
    ddDiffAnchor:SetSize(CFG_dd_w, CFG_btn_h)
    ddDiffAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)
    UI.CreateSimpleDropdown(ddDiffAnchor, 0, 0, CFG_dd_w, "", DIFFS,
        function() return S:Get("difficulty") end,
        function(key) S:Set("difficulty", key) end
    )

    local ddLenAnchor = CreateFrame("Frame", nil, pair)
    ddLenAnchor:SetSize(CFG_dd_w, CFG_btn_h)
    ddLenAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    UI.CreateSimpleDropdown(ddLenAnchor, 0, 0, CFG_dd_w, "", lenOpts,
        function() return S:Get("codeLength") end,
        function(key) S:Set("codeLength", key) end
    )

    -- Segment 2: Start / Beenden, mittig
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG_btn_w, CFG_btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.CB_Engine
        if not Eng then return end
        if R.state == "PLAYING" then
            Eng:StopGame()
        else
            R:StartNewGame()
        end
    end)
    self._startBtn = startBtn

    -- Segment 3: Duplikate, Label rechts neben der Checkbox
    local chkHolder, chk = UI.CreateBarCheckbox(cf, L["dup_label"] or "Duplikate", { w = 130, h = 36, size = 20 })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.checkbox)
    chk:SetScript("OnShow", function()
        chk:SetChecked(S and S:Get("duplicates") or false)
    end)
    chk:SetScript("OnClick", function()
        if S then S:Set("duplicates", chk:GetChecked()) end
    end)
    self.dupCheckbox = chk
end

function R:StartNewGame()
    local S = ArcadiaNexus.CB_Settings
    ArcadiaNexus.CB_Engine:StartGame({
        difficulty = S:Get("difficulty"),
        theme      = S:Get("theme"),
        codeLength = S:Get("codeLength"),
        duplicates = self.dupCheckbox and self.dupCheckbox:GetChecked() or S:Get("duplicates"),
    })
end

local function SecretCodeLine(state)
    local T   = ArcadiaNexus.CB_Themes
    local parts = {}
    for i = 1, state.codeLength do
        local sym = T:GetSymbol(state.theme, state.secretCode[i])
        parts[#parts + 1] = sym and sym.name or "?"
    end
    return table.concat(parts, "  ")
end

function R:ShowOverlay(won, state)
    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("CODEBREAKER")
    local parent = self._fieldFrame

    local lines
    if not won then
        lines = { SecretCodeLine(state) }
    end

    UI.ShowArcadeResult(parent, {
        title      = won and L["result_win_title"] or L["result_loss_title"],
        titleColor = won and {1, 0.85, 0.1} or {1, 0.3, 0.3},
        subtitle   = won and string.format(L["result_win_sub"], state.attemptCount, state.maxAttempts)
                     or L["result_loss_sub"],
        lines      = lines,
        gameId     = "CODEBREAKER",
        result     = won and "WIN" or "LOSS",
        L          = L,
        onRetry    = function() R:StartNewGame() end,
        onExit     = function()
            local Eng = ArcadiaNexus.CB_Engine
            if Eng then Eng:StopGame() end
        end,
    })
end

-- ============================================================
-- Idle State
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:ClearBoard()
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._hudFrame then self._hudFrame:Hide() end
    if self._scoreBox then self._scoreBox:Hide() end
    if self._bestBox  then self._bestBox:Hide()  end
    if self.statusFS then self.statusFS:Hide()  end
    if self._logoTex then self._logoTex:Show()  end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("CODEBREAKER")["btn_start"] or "Spiel starten")
    end

    if not self.hintFS then
        self.hintFS = self._canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.hintFS:SetPoint("CENTER", self._canvas, "CENTER", 0, 40)
        self.hintFS:SetText(ArcadiaNexus.GetLocaleTable("CODEBREAKER")["hint_start"])
        self.hintFS:SetJustifyH("CENTER")
    end
    self.hintFS:Show()
end

-- ============================================================
-- Event Handler
-- ============================================================
function R:OnGameStarted(state)
    self.state         = "PLAYING"
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self.hintFS   then self.hintFS:Hide()   end
    if self._logoTex then self._logoTex:Hide() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("CODEBREAKER")["btn_exit"] or "Beenden")
    end

    self:BuildBoard(state)
    self:UpdateStatus(ArcadiaNexus.CB_Engine.activeGame.board)
end

function R:OnGameWon(state)
    self.state = "WON"
    self:ShowOverlay(true, state)
end

function R:OnGameLost(state)
    self.state = "LOST"
    self:UpdateBoard()
    self:ShowOverlay(false, state)
end

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "CODEBREAKER",
    label     = "Codebreaker",
    renderer  = "CB_Renderer",
    engine    = "CB_Engine",
    container = "_cbContainer",
    category  = "DENKSPIELE",
})
