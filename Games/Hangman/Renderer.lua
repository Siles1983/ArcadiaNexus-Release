-- ============================================================
--  ArcadiaNexus
--  Games/Hangman/Renderer.lua
--  Version: 2.0.0  (Blueprint v3 Typ-3 + Background/Border/Logo)
--
--  Layout:
--    - _fieldFrame als CENTER-Anker (kein bgFile)
--    - Background / Border / Logo via CFG
--    - _leftPanel  (Runenkreis) haengt an _fieldFrame
--    - _rightPanel (Spielbereich) haengt an _fieldFrame
--    - Controls: CreateGameControlsBar "narrow"
--        Seg.1: DD Kategorie + DD Schwierigkeit
--        Seg.2: Toggle Neues Raetsel / Beenden
--    - Spielfeld erst sichtbar nach Spielstart
--    - Popup: goldener Rahmen, UI.CreateArcadiaButton
-- ============================================================

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.HGM_Renderer = {}
local R = ArcadiaNexus.HGM_Renderer
R.state = "IDLE"

local Engine   = ArcadiaNexus.HGM_Engine
local Settings = ArcadiaNexus.HGM_Settings

local RUNE_ICONS = {
    "Interface\\Icons\\INV_Misc_Rune_01",
    "Interface\\Icons\\INV_Misc_Rune_02",
    "Interface\\Icons\\INV_Misc_Rune_03",
    "Interface\\Icons\\INV_Misc_Rune_04",
    "Interface\\Icons\\INV_Misc_Rune_05",
    "Interface\\Icons\\INV_Misc_Rune_06",
    "Interface\\Icons\\INV_Misc_Rune_07",
    "Interface\\Icons\\INV_Misc_Rune_08",
    "Interface\\Icons\\Spell_Shadow_RaiseDead",
    "Interface\\Icons\\Spell_Deathknight_ClassSymbol",
}
local RUNE_COLOR_START = {r=0.3, g=0.0, b=0.5}
local RUNE_COLOR_END   = {r=1.0, g=0.1, b=0.0}

local KEYBOARD_ROWS = {
    {"Q","W","E","R","T","Y","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"Z","X","C","V","B","N","M"},
}
local BTN_SIZE = 28
local BTN_GAP  = 3

-- ============================================================
-- CFG – alle Layout-Konstanten zentral, unabhaengig positionierbar
-- ============================================================
local CFG = {
    -- _fieldFrame (gemeinsamer CENTER-Anker, kein bgFile)
    field_w      = 500,
    field_h      = 400,
    field_ofs_x  = 0,
    field_ofs_y  = 10,

    -- Hintergrund-Textur (relativ zu _fieldFrame CENTER)
    bg_w         = 790,
    bg_h         = 550,
    bg_ofs_x     = 0,
    bg_ofs_y     = 10,
    bg_alpha     = 1.0,

    -- Border-Textur (relativ zu _fieldFrame CENTER)
    border_w     = 790,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 5,

    -- Logo-Textur (relativ zu _fieldFrame CENTER)
    logo_w       = 280,
    logo_h       = 220,
    logo_ofs_x   = 0,
    logo_ofs_y   = 50,

    -- Linkes Panel (Runenkreis) relativ zu _fieldFrame TOPLEFT
    left_w       = 190,   -- ca. 42% von field_w
    left_ofs_x   = 145,
    left_ofs_y   = 15,

    -- Runenkreis-Radius-Faktor (relativ zu left_w)
    circle_r_fac = 0.32,
    circle_ofs_y = 10,   -- Versatz Mittelpunkt Y

    -- Rechtes Panel relativ zu _fieldFrame TOPLEFT
    right_ofs_x  = 200,   -- = left_w + 6px Luecke
    right_pad_r  = 10,

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- Kategorie-Anzeige (relativ zu gameArea TOPLEFT)
    cat_ofs_x    = 0,     -- X-Versatz vom gameArea TOPLEFT
    cat_ofs_y    = 0,   -- Y-Versatz vom gameArea TOPLEFT

    -- Hinweis-Box (relativ zu gameArea TOPLEFT)
    hint_w       = 260,   -- Breite der Hinweis-Box
    hint_h       = 52,    -- Hoehe der Hinweis-Box
    hint_ofs_x   = -90,     -- X-Versatz vom gameArea CENTER
    hint_ofs_y   = -260,  -- Y-Versatz vom gameArea TOP

    -- Virtuelle Tastatur (relativ zu gameArea BOTTOM)
    kb_w         = 290,   -- Breite des Tastatur-Containers
    kb_h         = 100,   -- Hoehe des Tastatur-Containers (3 Zeilen BTN_SIZE+BTN_GAP)
    kb_ofs_x     = -90,     -- X-Versatz vom gameArea BOTTOM CENTER
    kb_ofs_y     = -15,     -- Y-Versatz (Abstand vom unteren Rand)

    -- Portal-Titel + Fehler-Label (gemeinsamer Container, relativ zu leftPanel TOP)
    lbl_w        = 200,   -- Breite des Label-Containers
    lbl_h        = 50,    -- Hoehe des Label-Containers (Titel + Fehler-Label)
    lbl_ofs_x    = 0,     -- X-Versatz vom leftPanel CENTER
    lbl_ofs_y    = -70,   -- Y-Versatz vom leftPanel TOP

    -- Popup (GameOver)
    ov_w         = 380,
    ov_h         = 210,
    ov_ofs_x     = 0,
    ov_ofs_y     = 0,
    ov_title_y   = 60,
    ov_word_gap  = -12,
    ov_stats_gap = -10,
    ov_btn_gap   = -18,
    ov_btn_w     = 140,
    ov_btn_h     = 30,
    ov_btn_space = 80,    -- Abstand der 2 Buttons von Mitte
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local HGM_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\Hangman\\assets\\background\\bg_hgm",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\Hangman\\assets\\border\\border_hgm",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Hangman\\assets\\logo\\logo_hgm",
}

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    if self._initialized then return end
    self._initialized = true

    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateLeftPanel()
    self:_CreateRightPanel()
    self:_CreateKeyboardInput()
    self:_CreateControls()
    self:EnterIdleState()
end

-- ============================================================
-- MAIN FRAME
-- ============================================================
function R:_CreateMainFrame()
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_HGM_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._hangmanContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("HANGMAN", ArcadiaNexus.HGM_Engine, function(E)
            E:StopGame()
        end)
    end)
end

-- ============================================================
-- FIELD FRAME (CENTER-Anker, kein bgFile)
-- ============================================================
function R:_CreateFieldFrame()
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
    tex:SetTexture(HGM_ASSETS.bg)
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
    tex:SetTexture(HGM_ASSETS.border)
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
        HGM_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- LINKES PANEL (Runenkreis)
-- ============================================================
function R:_CreateLeftPanel()
    local ff = self._fieldFrame

    local leftPanel = CreateFrame("Frame", nil, ff)
    leftPanel:SetSize(CFG.left_w, CFG.field_h)
    leftPanel:SetPoint("TOPLEFT", ff, "TOPLEFT", CFG.left_ofs_x, CFG.left_ofs_y)
    self._leftPanel = leftPanel

    -- Portal-Titel + Fehler-Label: gemeinsamer Container
    local lblContainer = CreateFrame("Frame", nil, leftPanel)
    lblContainer:SetSize(CFG.lbl_w, CFG.lbl_h)
    lblContainer:SetPoint("TOP", leftPanel, "TOP", CFG.lbl_ofs_x, CFG.lbl_ofs_y)
    self._lblContainer = lblContainer

    local portalTitle = lblContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    portalTitle:SetPoint("TOP", lblContainer, "TOP", 0, 0)
    portalTitle:SetWidth(CFG.lbl_w)
    portalTitle:SetText(ArcadiaNexus.GetLocaleTable("HANGMAN")["portal_title"])
    portalTitle:SetFont("Fonts\\MORPHEUS.TTF", 15, "OUTLINE")
    portalTitle:SetJustifyH("CENTER")
    self._portalTitle = portalTitle

    local errorLabel = lblContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    errorLabel:SetPoint("TOP", portalTitle, "BOTTOM", 0, -5)
    errorLabel:SetWidth(CFG.lbl_w)
    errorLabel:SetTextColor(0.8, 0.6, 0.2)
    errorLabel:SetJustifyH("CENTER")
    self._errorLabel = errorLabel

    -- Runenkreis: 10 Frames ohne feste Winkelposition (wird in _resetRunes gesetzt)
    local circleR = CFG.left_w * CFG.circle_r_fac
    self._runeFrames = {}
    for i = 1, 10 do
        local runeFrame = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
        runeFrame:SetSize(44, 44)
        runeFrame:SetPoint("CENTER", leftPanel, "CENTER", 0, CFG.circle_ofs_y)
        runeFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left=1, right=1, top=1, bottom=1 },
        })
        runeFrame:SetBackdropColor(0.05, 0.0, 0.1, 0.9)
        runeFrame:SetBackdropBorderColor(0.3, 0.0, 0.5, 0.6)

        local runeTex = runeFrame:CreateTexture(nil, "ARTWORK")
        runeTex:SetPoint("TOPLEFT",     runeFrame, "TOPLEFT",     2, -2)
        runeTex:SetPoint("BOTTOMRIGHT", runeFrame, "BOTTOMRIGHT", -2,  2)
        runeTex:SetTexture(RUNE_ICONS[i] or RUNE_ICONS[1])
        runeTex:SetAlpha(0.0)
        runeFrame._tex = runeTex

        self._runeFrames[i] = runeFrame
    end

    -- Portal-Kern
    local coreFrame = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    coreFrame:SetSize(56, 56)
    coreFrame:SetPoint("CENTER", leftPanel, "CENTER", 0, CFG.circle_ofs_y)
    coreFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 2,
        insets = { left=2, right=2, top=2, bottom=2 },
    })
    coreFrame:SetBackdropColor(0.1, 0.0, 0.2, 0.95)
    coreFrame:SetBackdropBorderColor(0.6, 0.2, 1.0, 0.8)

    local coreTex = coreFrame:CreateTexture(nil, "ARTWORK")
    coreTex:SetPoint("TOPLEFT",     coreFrame, "TOPLEFT",     3, -3)
    coreTex:SetPoint("BOTTOMRIGHT", coreFrame, "BOTTOMRIGHT", -3,  3)
    coreTex:SetTexture("Interface\\Icons\\Spell_Shadow_SummonVoidWalker")
    coreTex:SetAlpha(0.7)
    self._coreFrame = coreFrame
    self._coreTex   = coreTex

    local victoryTex = coreFrame:CreateTexture(nil, "OVERLAY")
    victoryTex:SetAllPoints(coreTex)
    victoryTex:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
    victoryTex:SetAlpha(0.0)
    self._victoryTex = victoryTex
end

-- ============================================================
-- RECHTES PANEL (Spielbereich)
-- ============================================================
function R:_CreateRightPanel()
    local ff    = self._fieldFrame
    local rightW = CFG.field_w - CFG.right_ofs_x - CFG.right_pad_r

    local rightPanel = CreateFrame("Frame", nil, ff)
    rightPanel:SetPoint("TOPLEFT",    ff, "TOPLEFT",    CFG.right_ofs_x, 0)
    rightPanel:SetPoint("BOTTOMRIGHT",ff, "BOTTOMRIGHT", -CFG.right_pad_r, 0)
    self._rightPanel = rightPanel

    -- Spielbereich (gameArea) – innerhalb rightPanel, unterhalb Controls
    local gameArea = CreateFrame("Frame", nil, rightPanel)
    gameArea:SetPoint("TOPLEFT",    rightPanel, "TOPLEFT",    0,  0)
    gameArea:SetPoint("BOTTOMRIGHT",rightPanel, "BOTTOMRIGHT",0,  0)
    self._gameArea = gameArea

    -- Kategorie-Anzeige (relativ zu gameArea TOPLEFT via CFG.cat_*)
    local catDisplay = gameArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catDisplay:SetPoint("TOPLEFT", gameArea, "TOPLEFT", CFG.cat_ofs_x, CFG.cat_ofs_y)
    catDisplay:SetTextColor(0.6, 0.8, 1.0)
    catDisplay:SetText("Kategorie: -")
    self._catDisplay = catDisplay

    -- Wort-Display
    local wordDisplay = gameArea:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    wordDisplay:SetPoint("TOP", catDisplay, "BOTTOM", 0, -8)
    wordDisplay:SetWidth(rightW - 10)
    wordDisplay:SetFont("Fonts\\MORPHEUS.TTF", 22, "OUTLINE")
    wordDisplay:SetTextColor(0.95, 0.85, 0.4)
    wordDisplay:SetText("")
    wordDisplay:SetJustifyH("CENTER")
    self._wordDisplay = wordDisplay

    -- Trennlinie
    local sep = gameArea:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  wordDisplay, "BOTTOMLEFT",  0, -8)
    sep:SetPoint("TOPRIGHT", wordDisplay, "BOTTOMRIGHT", 0, -8)
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(0.4, 0.2, 0.7, 0.6)

    -- Hinweis-Box (relativ zu gameArea TOP via CFG.hint_*, unabhaengig von catDisplay/sep)
    local hintBox = CreateFrame("Frame", nil, gameArea, "BackdropTemplate")
    hintBox:SetSize(CFG.hint_w, CFG.hint_h)
    hintBox:SetPoint("TOP", gameArea, "TOP", CFG.hint_ofs_x, CFG.hint_ofs_y)
    hintBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    hintBox:SetBackdropColor(0.08, 0.04, 0.15, 0.9)
    hintBox:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.5)

    local hintIcon = hintBox:CreateTexture(nil, "ARTWORK")
    hintIcon:SetSize(24, 24)
    hintIcon:SetPoint("TOPLEFT", hintBox, "TOPLEFT", 6, -6)
    hintIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")

    local hintTitle = hintBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintTitle:SetPoint("TOPLEFT", hintBox, "TOPLEFT", 36, -8)
    hintTitle:SetText(ArcadiaNexus.GetLocaleTable("HANGMAN")["hint_label"])

    local hintText = hintBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("TOPLEFT",  hintTitle, "BOTTOMLEFT", 0, -2)
    hintText:SetPoint("TOPRIGHT", hintBox,   "TOPRIGHT",  -6, -8)
    hintText:SetJustifyH("LEFT")
    hintText:SetWordWrap(true)
    hintText:SetTextColor(0.85, 0.75, 0.95)
    self._hintText = hintText

    -- Tastatur (zentriert via CFG.kb_*)
    local kbAnchor = CreateFrame("Frame", nil, gameArea)
    kbAnchor:SetSize(CFG.kb_w, CFG.kb_h)
    kbAnchor:SetPoint("BOTTOM", gameArea, "BOTTOM", CFG.kb_ofs_x, CFG.kb_ofs_y)
    self._kbAnchor = kbAnchor

    self._letterBtns = {}
    for row = 1, #KEYBOARD_ROWS do
        local letters  = KEYBOARD_ROWS[row]
        local rowWidth = #letters * BTN_SIZE + (#letters - 1) * BTN_GAP
        local startX   = math.floor((CFG.kb_w - rowWidth) / 2)
        for col = 1, #letters do
            local letter = letters[col]
            local bx = startX + (col - 1) * (BTN_SIZE + BTN_GAP)
            local by = -(row - 1) * (BTN_SIZE + BTN_GAP)

            local btn = CreateFrame("Button", nil, kbAnchor, "BackdropTemplate")
            btn:SetSize(BTN_SIZE, BTN_SIZE)
            btn:SetPoint("TOPLEFT", kbAnchor, "TOPLEFT", bx, by)
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, edgeSize = 1,
                insets = { left=1, right=1, top=1, bottom=1 },
            })
            btn:SetBackdropColor(0.12, 0.06, 0.22, 0.95)
            btn:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.7)

            local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetAllPoints()
            lbl:SetText(letter)
            lbl:SetTextColor(0.9, 0.8, 1.0)
            btn._label = lbl

            local cap = letter
            btn:SetScript("OnClick", function() Engine:GuessLetter(cap) end)
            btn:SetScript("OnEnter", function(s) if not s._used then s:SetBackdropBorderColor(0.8, 0.5, 1.0, 1.0) end end)
            btn:SetScript("OnLeave", function(s) if not s._used then s:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.7) end end)
            self._letterBtns[letter] = btn
        end
    end

    -- Fehlversuche-Header + Text (über Tastatur)
    local wrongHeader = gameArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wrongHeader:SetPoint("BOTTOM", kbAnchor, "TOP", 0, 6)
    wrongHeader:SetWidth(rightW)
    wrongHeader:SetJustifyH("CENTER")
    wrongHeader:SetText("")
    self._wrongHeader = wrongHeader

    local wrongText = gameArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wrongText:SetPoint("BOTTOM", wrongHeader, "TOP", 0, 2)
    wrongText:SetWidth(rightW)
    wrongText:SetJustifyH("CENTER")
    wrongText:SetTextColor(1.0, 0.3, 0.3)
    wrongText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    wrongText:SetText("")
    self._wrongText = wrongText
end

-- ============================================================
-- KEYBOARD INPUT FRAME
-- ============================================================
function R:_CreateKeyboardInput()
    local f = self.frame
    local kf = CreateFrame("Frame", nil, f)
    kf:SetAllPoints(f)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        if #key == 1 then
            local upper = string.upper(key)
            if upper:match("[A-Z]") then Engine:GuessLetter(upper) end
        end
    end)
    self._keyFrame = kf
end

-- ============================================================
-- CONTROLS – CreateGameControlsBar "narrow"
-- DD Kategorie + DD Schwierigkeit in Segment 1 / Start in Segment 2
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("HANGMAN")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Segment 1: Kategorie + Schwierigkeit nebeneinander
    local _cats   = ArcadiaNexus.HGM_Logic:GetCategories()
    local catOpts = {}
    for _, cat in ipairs(_cats) do
        catOpts[#catOpts + 1] = { key = cat.id, label = cat.label }
    end
    local DIFFICULTIES = {
        { key = "Easy",   label = L["diff_easy"]   },
        { key = "Normal", label = L["diff_normal"]  },
        { key = "Hard",   label = L["diff_hard"]    },
    }

    local ddGap = 10
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(CFG.dd_w * 2 + ddGap, CFG.btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddCatAnchor = CreateFrame("Frame", nil, pair)
    ddCatAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddCatAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)
    UI.CreateSimpleDropdown(ddCatAnchor, 0, 0, CFG.dd_w, "", catOpts,
        function() return Settings:Get("category") end,
        function(value) Settings:Set("category", value) end
    )

    local ddDiffAnchor = CreateFrame("Frame", nil, pair)
    ddDiffAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddDiffAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    UI.CreateSimpleDropdown(ddDiffAnchor, 0, 0, CFG.dd_w, "", DIFFICULTIES,
        function() return Settings:Get("difficulty") end,
        function(value) Settings:Set("difficulty", value) end
    )

    -- Segment 2: Toggle-Button
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.HGM_Engine
        if not Eng then return end
        if R.state == "PLAYING" then
            ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
            Eng:StopGame()
        else
            Eng:StartGame()
        end
    end)
    self._startBtn = startBtn
end

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================
function R:_resetKeyboard()
    if not self._letterBtns then return end
    for _, btn in pairs(self._letterBtns) do
        btn._used = false
        btn:SetBackdropColor(0.12, 0.06, 0.22, 0.95)
        btn:SetBackdropBorderColor(0.5, 0.3, 0.8, 0.7)
        btn._label:SetTextColor(0.9, 0.8, 1.0)
        btn:Enable()
    end
end

function R:_resetRunes(maxSlots)
    if not self._runeFrames then return end
    maxSlots = maxSlots or 6
    local circleR = CFG.left_w * CFG.circle_r_fac
    for i = 1, 10 do
        local rf = self._runeFrames[i]
        if i <= maxSlots then
            -- 360°-Verteilung: Winkel gleichmaessig auf maxSlots aufteilen
            -- Start oben (-pi/2), gleichmaessige Schritte
            local angle = ((i - 1) / maxSlots) * (2 * math.pi) - math.pi / 2
            local px    = math.floor(math.cos(angle) * circleR)
            local py    = math.floor(math.sin(angle) * circleR)
            rf:ClearAllPoints()
            rf:SetPoint("CENTER", self._leftPanel, "CENTER", px, py + CFG.circle_ofs_y)
            rf:Show()
            rf._tex:SetAlpha(0.0)
            rf._tex:SetVertexColor(1, 1, 1)
            rf:SetBackdropBorderColor(0.3, 0.0, 0.5, 0.5)
            rf:SetBackdropColor(0.05, 0.0, 0.1, 0.9)
        else
            rf:Hide()
        end
    end
    if self._coreFrame then
        self._coreFrame:SetBackdropBorderColor(0.6, 0.2, 1.0, 0.8)
        self._coreFrame:SetBackdropColor(0.1, 0.0, 0.2, 0.95)
    end
    if self._coreTex    then self._coreTex:SetAlpha(0.7)  end
    if self._victoryTex then self._victoryTex:SetAlpha(0.0) end
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    if self._keyFrame  then self._keyFrame:EnableKeyboard(false) end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._leftPanel then self._leftPanel:Hide() end
    if self._gameArea  then self._gameArea:Hide() end
    if self._logoTex   then self._logoTex:Show()  end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("HANGMAN")["btn_start"])
    end
    self:_resetKeyboard()
    self:_resetRunes(Settings and Settings:GetMaxErrors() or 6)
end

-- ============================================================
-- BOARD RENDERN (Spielstart + Updates)
-- ============================================================
function R:RenderBoard(board)
    if not board then return end

    -- Beim ersten Aufruf (Spielstart) Spielfeld einblenden
    if self.state ~= "PLAYING" then
        self.state = "PLAYING"
        if self._logoTex   then self._logoTex:Hide()  end
        if self._leftPanel then self._leftPanel:Show() end
        if self._gameArea  then self._gameArea:Show()  end
        if self._keyFrame  then self._keyFrame:EnableKeyboard(true) end
        if self._startBtn  then
            self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("HANGMAN")["btn_exit"])
        end
        self:_resetKeyboard()
        self:_resetRunes(board.maxErrors)
    end

    -- Kategorie-Anzeige
    if self._catDisplay then
        self._catDisplay:SetText(
            string.format(ArcadiaNexus.GetLocaleTable("HANGMAN")["cat_display"], board.category or "?"))
    end

    -- Wort-Display
    if self._wordDisplay then
        self._wordDisplay:SetText(ArcadiaNexus.HGM_Logic:GetDisplayWord(board))
    end

    -- Hinweis
    if self._hintText then
        self._hintText:SetText(board.hint or "")
    end

    -- Fehler-Label
    local maxErr = board.maxErrors
    local errors = board.errors
    if self._errorLabel then
        local col = errors == 0 and "|cff44ff44" or
                    (errors >= maxErr - 1 and "|cffff2222" or "|cffff8822")
        self._errorLabel:SetText(
            string.format(ArcadiaNexus.GetLocaleTable("HANGMAN")["error_label"], col, errors, maxErr))
    end

    -- Runen
    for i = 1, 10 do
        local rf = self._runeFrames[i]
        if i <= maxErr then
            rf:Show()
            if i <= errors then
                local t = errors > 1 and ((i-1)/(errors-1)) or 1
                local r2 = RUNE_COLOR_START.r + (RUNE_COLOR_END.r - RUNE_COLOR_START.r) * t
                local g2 = RUNE_COLOR_START.g + (RUNE_COLOR_END.g - RUNE_COLOR_START.g) * t
                local b2 = RUNE_COLOR_START.b + (RUNE_COLOR_END.b - RUNE_COLOR_START.b) * t
                rf._tex:SetAlpha(0.95)
                rf._tex:SetVertexColor(r2, g2, b2)
                rf:SetBackdropBorderColor(r2, g2, b2, 1.0)
                rf:SetBackdropColor(r2*0.2, g2*0.2, b2*0.2, 0.95)
            else
                rf._tex:SetAlpha(0.0)
                rf._tex:SetVertexColor(1, 1, 1)
                rf:SetBackdropBorderColor(0.3, 0.0, 0.5, 0.5)
                rf:SetBackdropColor(0.05, 0.0, 0.1, 0.9)
            end
        else
            rf:Hide()
        end
    end

    -- Portal-Kern
    if self._coreFrame then
        local danger = maxErr > 0 and (errors / maxErr) or 0
        self._coreFrame:SetBackdropBorderColor(0.4 + danger*0.6, 0.1, 1.0 - danger*0.7, 0.9)
        self._coreFrame:SetBackdropColor(0.1 + danger*0.4, 0.0, 0.3 - danger*0.25, 0.95)
    end

    -- Falsche Buchstaben
    if self._wrongText then
        local wrong = ArcadiaNexus.HGM_Logic:GetWrongLetters(board)
        if #wrong > 0 then
            if self._wrongHeader then self._wrongHeader:SetText(ArcadiaNexus.GetLocaleTable("HANGMAN")["wrong_header"]) end
            self._wrongText:SetText(table.concat(wrong, "  "))
        else
            if self._wrongHeader then self._wrongHeader:SetText("") end
            self._wrongText:SetText("")
        end
    end

    -- Buchstaben-Buttons
    if self._letterBtns then
        for letter, btn in pairs(self._letterBtns) do
            if board.guessed[letter] and not btn._used then
                btn._used = true
                btn:Disable()
                local inWord = false
                for i = 1, #board.word do
                    if board.word:sub(i,i) == letter then inWord = true; break end
                end
                if inWord then
                    btn:SetBackdropColor(0.0, 0.25, 0.05, 0.9)
                    btn:SetBackdropBorderColor(0.2, 0.8, 0.3, 0.9)
                    btn._label:SetTextColor(0.4, 1.0, 0.5)
                else
                    btn:SetBackdropColor(0.25, 0.03, 0.03, 0.9)
                    btn:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.9)
                    btn._label:SetTextColor(1.0, 0.3, 0.3)
                end
            end
        end
    end
end

-- ============================================================
-- GAME OVER POPUP
-- ============================================================
function R:ShowGameOver(won, board)
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    local field  = self._fieldFrame
    if not field then return end
    local L      = ArcadiaNexus.GetLocaleTable("HANGMAN")
    local UI     = ArcadiaNexus.UI
    local wins   = Settings:Get("wins")
    local losses = Settings:Get("losses")

    if self._startBtn then
        self._startBtn:SetLabel(L["btn_start"])
    end
    self.state = "IDLE"

    if won then
        if self._victoryTex then self._victoryTex:SetAlpha(0.9) end
    else
        if self._wordDisplay then self._wordDisplay:SetText(board.word) end
        for i = 1, board.maxErrors do
            local rf = self._runeFrames[i]
            if rf then
                rf._tex:SetAlpha(0.95)
                rf._tex:SetVertexColor(1.0, 0.1, 0.0)
                rf:SetBackdropBorderColor(1.0, 0.1, 0.0, 1.0)
                rf:SetBackdropColor(0.3, 0.0, 0.0, 0.95)
            end
        end
        if self._coreFrame then
            self._coreFrame:SetBackdropBorderColor(1.0, 0.1, 0.0, 1.0)
            self._coreFrame:SetBackdropColor(0.4, 0.0, 0.0, 0.95)
        end
    end

    UI.ShowArcadeResult(field, {
        title      = won and L["go_win_title"] or L["go_loss_title"],
        titleColor = won and { 1, 0.84, 0 } or { 1, 0.3, 0.3 },
        gameId     = "HANGMAN",
        result     = won and "WIN" or "LOSS",
        lines      = {
            string.format(L["go_word"], won and "88ff88" or "ff8844", board.word),
            string.format(L["go_stats"], wins, losses),
        },
        L = L,
        onRetry = function()
            local Eng = ArcadiaNexus.HGM_Engine
            if Eng then Eng:StartGame() end
        end,
        onExit = function()
            local Eng = ArcadiaNexus.HGM_Engine
            if Eng then Eng:StopGame() end
        end,
    })
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
ArcadiaNexus.RegisterGame({
    id        = "HANGMAN",
    label     = "Hangman",
    renderer  = "HGM_Renderer",
    engine    = "HGM_Engine",
    container = "_hangmanContainer",
    category  = "WORT",
})
