-- ============================================================
--  ArcadiaNexus
--  Games/AzerothWords/Renderer.lua
--  Version: 2.0.0  (Blueprint v3 Typ-2)
--
--  Layout-Strategie:
--    - _fieldFrame als CENTER-Anker (kein bgFile – TGA sichtbar)
--    - Background / Border / Logo via CFG-Konstanten
--    - Controls: CreateGameControlsBar "narrow"
--        Seg.1: Dropdown Schwierigkeit
--        Seg.2: Toggle-Button Spiel starten / Beenden
--        Seg.3: FontString-Box Versuche / Kategorie
--    - Grid + virtuelle Tastatur hängen an self.frame
--    - Overlay: Nonogram-Standard (goldener Rahmen, CFG-Konstanten)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.WRD_Renderer = {}
local R = ArcadiaNexus.WRD_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral
-- ============================================================
local CFG = {
    -- _fieldFrame: unsichtbarer CENTER-Anker fuer alle Kindelemente.
    -- field_ofs_x/y: verschiebt den gesamten Anker (Background + Border + Logo + Grid bewegen sich mit).
    -- Individuelle ofs-Werte der Kindelemente sind RELATIV zu _fieldFrame CENTER und unabhaengig voneinander.
    field_w      = 500,
    field_h      = 540,
    field_ofs_x  = 0,
    field_ofs_y  = 0,

    -- Hintergrund-Textur (relativ zu _fieldFrame CENTER, unabhaengig von Border/Logo)
    bg_w         = 590,
    bg_h         = 440,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,

    -- Border-Textur (relativ zu _fieldFrame CENTER, unabhaengig von Background/Logo)
    border_w     = 800,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 17,

    -- Logo-Textur (relativ zu _fieldFrame CENTER, unabhaengig von Background/Border)
    logo_w       = 446,
    logo_h       = 400,
    logo_ofs_x   = 0,
    logo_ofs_y   = 30,

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- Segment 3: Versuche/Kategorie-Box
    hud_box_w    = 165,
    hud_box_h    = 46,

    -- Grid-Container (relativ zu self.frame CENTER, unabhaengig von _fieldFrame)
    grid_w       = 400,
    grid_h       = 300,
    grid_ofs_x   = 0,
    grid_ofs_y   = 60,

    -- Tastatur-Container (relativ zu _controlsFrame BOTTOM)
    kb_ofs_x     = 0,     -- X-Versatz vom cf BOTTOM CENTER
    kb_ofs_y     = 105,    -- Y-Versatz vom cf BOTTOM nach oben
    kb_scale     = 1.0,   -- Skalierungsfaktor der Tastatur (z.B. 0.8 = 80%, 1.2 = 120%)

    -- Overlay
    ov_w         = 300,
    ov_h         = 180,
    ov_ofs_x     = 0,
    ov_ofs_y     = 60,
    ov_title_y   = 40,
    ov_sub_gap   = -14,
    ov_btn_gap   = -18,
    ov_btn_w     = 150,
    ov_btn_h     = 30,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local WRD_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothWords\\assets\\background\\background_aw",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothWords\\assets\\border\\border_aw",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothWords\\assets\\logo\\logo_aw",
}

-- ============================================================
-- THEME-FARBEN
-- ============================================================
local THEMES = {
    classic = {
        CORRECT = { bg={0.20, 0.60, 0.20}, border={0.30, 0.80, 0.30} },
        PRESENT = { bg={0.65, 0.55, 0.05}, border={0.85, 0.75, 0.15} },
        ABSENT  = { bg={0.22, 0.22, 0.22}, border={0.30, 0.30, 0.30} },
        key_unknown = { 0.35, 0.35, 0.38 },
    },
    wow = {
        CORRECT = { bg={0.75, 0.60, 0.00}, border={1.00, 0.84, 0.10} },
        PRESENT = { bg={0.50, 0.50, 0.52}, border={0.70, 0.70, 0.72} },
        ABSENT  = { bg={0.12, 0.12, 0.14}, border={0.20, 0.20, 0.22} },
        key_unknown = { 0.30, 0.28, 0.25 },
    },
}

local TILE_EMPTY_BG     = { 0.08, 0.08, 0.10 }
local TILE_EMPTY_BORDER = { 0.35, 0.35, 0.35 }
local TILE_INPUT_BORDER = { 0.85, 0.85, 0.85 }

-- Tastatur-Layout (QWERTY)
local KB_BTN = 28
local KB_GAP = 3
local KB_ROWS = {
    { "Q","W","E","R","T","Y","U","I","O","P" },
    { "A","S","D","F","G","H","J","K","L"     },
    { "Z","X","C","V","B","N","M","BACK","ENTER" },
}

local function CreateTilePool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "AzerothWords.Tiles",
        create = function(poolParent)
            poolParentRef = poolParent
            local tile = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            tile:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile=false, edgeSize=1,
                insets={left=1,right=1,top=1,bottom=1},
            })
            local fs = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetAllPoints()
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            fs:SetTextColor(1, 1, 1)
            tile._fs = fs
            return tile
        end,
        onRelease = function(tile)
            tile:Hide()
            tile:ClearAllPoints()
            if tile._fs then tile._fs:SetText("") end
            if poolParentRef then tile:SetParent(poolParentRef) end
        end,
    })
end

local function CreateKeyPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "AzerothWords.Keys",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile=false, edgeSize=1,
                insets={left=1,right=1,top=1,bottom=1},
            })
            local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetAllPoints()
            lbl:SetJustifyH("CENTER")
            lbl:SetJustifyV("MIDDLE")
            lbl:SetTextColor(0.90, 0.80, 1.00)
            btn._label = lbl
            btn._state = "unknown"
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:Enable()
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetScript("OnClick", nil)
            btn._key = nil
            btn._state = "unknown"
            if btn._label then btn._label:SetText("") end
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R.state          = "IDLE"
R._fieldFrame    = nil
R._borderFrame   = nil
R._bgTex         = nil
R._borderTex     = nil
R._logoTex       = nil
R._controlsFrame = nil
R._startBtn      = nil
R._hudBoxFS      = nil   -- FontString Versuche/Kategorie (Seg.3)
R._hudBoxFrame   = nil   -- Backdrop-Frame Seg.3
R._statusFS      = nil
R._msgFS         = nil
R._msgGen        = 0
R._shakeGen      = 0
R._keyFrame      = nil
R._tiles         = {}
R._kbButtons     = {}
R._gridHolder    = nil
R._kbHolder      = nil
R._tilePool      = nil
R._keyPool       = nil

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateStatusBar()
    self:_CreateControls()
    self:_SetupKeyboard()
    self:EnterIdleState()
end

-- ============================================================
-- MAIN FRAME
-- ============================================================
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_WRD_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._wrdContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("AZEROTHWORDS", ArcadiaNexus.WRD_Engine, function(E)
            E:StopGame()
        end)
    end)
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
    tex:SetTexture(WRD_ASSETS.bg)
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
    tex:SetTexture(WRD_ASSETS.border)
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
        WRD_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- STATUS-BAR (oben)
-- ============================================================
function R:_CreateStatusBar()
    local f = self._canvas
    self._statusFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._statusFS:SetPoint("TOP", f, "TOP", 0, -8)
    self._statusFS:SetJustifyH("CENTER")
    self._statusFS:SetTextColor(0.90, 0.85, 0.65)
    self._statusFS:Hide()

    self._msgFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self._msgFS:SetPoint("TOP", f, "TOP", 0, -12)
    self._msgFS:SetJustifyH("CENTER")
    self._msgFS:SetTextColor(1, 0.3, 0.3)
    self._msgFS:Hide()
end

-- _UpdateStatusBar entfernt: Versuche/Kategorie werden ausschliesslich
-- ueber _UpdateHUDBox in Segment 3 der Controls-Leiste angezeigt.

-- ============================================================
-- CONTROLS – CreateGameControlsBar "narrow"
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.WRD_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- ── Segment 1: Dropdown Schwierigkeit ───────
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]   or "Einfach" },
            { key = "normal", label = L["diff_normal"]  or "Normal"  },
            { key = "hard",   label = L["diff_hard"]    or "Schwer"  },
        },
        function()
            return (S and S:Get("difficulty")) or "normal"
        end,
        function(key)
            if S then S:Set("difficulty", key) end
        end
    )

    -- ── Segment 2: Toggle-Button Spiel starten / Beenden ─
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.WRD_Engine
        if not Eng then return end
        if R.state == "PLAYING" then
            Eng:StopGame()
        else
            local diff = (S and S:Get("difficulty")) or "normal"
            Eng:StartGame(diff)
        end
    end)
    self._startBtn = startBtn

    -- ── Segment 3: Versuche / Kategorie-Box ─────
    local boxFrame = CreateFrame("Frame", nil, cf, "BackdropTemplate")
    boxFrame:SetSize(CFG.hud_box_w, CFG.hud_box_h)
    boxFrame:SetPoint("CENTER", cf, "CENTER", bar.segX[3], 0)
    boxFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    boxFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
    boxFrame:SetBackdropBorderColor(0.5, 0.45, 0.2, 0.6)
    boxFrame:Hide()
    self._hudBoxFrame = boxFrame

    local boxFS = boxFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    boxFS:SetAllPoints()
    boxFS:SetJustifyH("CENTER")
    boxFS:SetJustifyV("MIDDLE")
    boxFS:SetTextColor(0.90, 0.85, 0.65)
    boxFS:SetText("")
    self._hudBoxFS = boxFS
end

-- Segment-3-Box aktualisieren (Versuche / Kategorie)
function R:_UpdateHUDBox(gs)
    if not self._hudBoxFS or not self._hudBoxFrame then return end
    local L   = ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")
    local att = math.min(gs.attemptsUsed + 1, gs.maxAttempts)
    local line = (L["lbl_attempt"] or "Versuch") .. " " .. att .. "/" .. gs.maxAttempts
    if gs.showCategory then
        local cat = ArcadiaNexus.WRD_Logic:GetCategoryLabel(gs.category)
        line = line .. "\n" .. cat
    end
    self._hudBoxFS:SetText(line)
    self._hudBoxFrame:Show()
end

-- ============================================================
-- GRID ERSTELLEN
-- ============================================================
function R:_EnsureBoardPools()
    if not self._tilePool then self._tilePool = CreateTilePool() end
    if not self._keyPool  then self._keyPool  = CreateKeyPool() end
end

function R:_ReleaseGrid()
    if self._tilePool then self._tilePool:ReleaseAll() end
    self._tiles = {}
end

function R:_ReleaseKeyboard()
    if self._keyPool then self._keyPool:ReleaseAll() end
    self._kbButtons = {}
end

function R:_BuildGrid(wordLength, maxAttempts)
    self:_ReleaseGrid()
    self:_EnsureBoardPools()

    if not self._gridHolder then
        local holder = CreateFrame("Frame", nil, self._canvas)
        holder:SetPoint("CENTER", self._canvas, "CENTER", CFG.grid_ofs_x, CFG.grid_ofs_y)
        self._gridHolder = holder
    end

    local f      = self._canvas
    local tileS  = 4
    local maxTileW = math.floor((CFG.grid_w - (wordLength-1) * tileS) / wordLength)
    local maxTileH = math.floor((CFG.grid_h - (maxAttempts-1) * tileS) / maxAttempts)
    local tileSize = math.min(maxTileW, maxTileH, 54)

    local holder = self._gridHolder
    holder:SetSize(CFG.grid_w, CFG.grid_h)
    holder:Show()

    local gridW = wordLength * (tileSize + tileS) - tileS
    local gridH = maxAttempts * (tileSize + tileS) - tileS
    local offX  = math.floor((CFG.grid_w - gridW) / 2)
    local offY  = -math.floor((CFG.grid_h - gridH) / 2)

    for row = 1, maxAttempts do
        self._tiles[row] = {}
        for col = 1, wordLength do
            local tile = self._tilePool:Acquire({})
            tile:SetParent(holder)
            tile:SetSize(tileSize, tileSize)
            tile:SetPoint("TOPLEFT", holder, "TOPLEFT",
                offX + (col-1)*(tileSize+tileS),
                offY - (row-1)*(tileSize+tileS))
            tile:SetBackdropColor(TILE_EMPTY_BG[1], TILE_EMPTY_BG[2], TILE_EMPTY_BG[3], 1)
            tile:SetBackdropBorderColor(TILE_EMPTY_BORDER[1], TILE_EMPTY_BORDER[2], TILE_EMPTY_BORDER[3], 1)
            tile._fs:SetText("")
            tile:Show()

            self._tiles[row][col] = tile
        end
    end
end

-- ============================================================
-- VIRTUELLE TASTATUR
-- ============================================================
function R:_BuildKeyboard()
    self:_ReleaseKeyboard()
    self:_EnsureBoardPools()

    if not self._kbHolder then
        local holder = CreateFrame("Frame", nil, self._canvas)
        self._kbHolder = holder
    end

    local cf    = self._controlsFrame
    local scale = CFG.kb_scale or 1.0
    local btn_s = math.floor(KB_BTN * scale)
    local gap_s = math.max(1, math.floor(KB_GAP * scale))

    local totalH = #KB_ROWS * (btn_s + gap_s)
    local maxRowKeys = 10
    local totalW = maxRowKeys * btn_s + (maxRowKeys - 1) * gap_s

    local holder = self._kbHolder
    holder:SetSize(totalW, totalH)
    holder:SetPoint("BOTTOM", cf, "BOTTOM", CFG.kb_ofs_x, CFG.kb_ofs_y)
    holder:Show()

    for rowIdx, row in ipairs(KB_ROWS) do
        local keys = {}
        for _, key in ipairs(row) do
            local w = (key == "BACK" or key == "ENTER") and math.floor(btn_s * 1.8) or btn_s
            keys[#keys+1] = { key=key, w=w }
        end

        local rowW = 0
        for _, kd in ipairs(keys) do rowW = rowW + kd.w + gap_s end
        rowW = rowW - gap_s
        local startX = math.floor((totalW - rowW) / 2)

        local cx = startX
        for _, kd in ipairs(keys) do
            local btn = self._keyPool:Acquire({})
            btn:SetParent(holder)
            btn:SetSize(kd.w, btn_s)
            btn:SetPoint("TOPLEFT", holder, "TOPLEFT",
                cx, -(rowIdx-1) * (btn_s + gap_s))
            btn:SetBackdropColor(0.10, 0.06, 0.20, 0.95)
            btn:SetBackdropBorderColor(0.45, 0.28, 0.75, 0.80)

            local label = kd.key
            if kd.key == "BACK"  then label = "<" end
            if kd.key == "ENTER" then label = "OK" end

            btn._label:SetText(label)
            btn._state = "unknown"
            btn._key = kd.key

            btn:SetScript("OnEnter", function(s)
                if s._state ~= "used" then
                    s:SetBackdropBorderColor(0.80, 0.55, 1.00, 1.00)
                end
            end)
            btn:SetScript("OnLeave", function(s)
                if s._state ~= "used" then
                    s:SetBackdropBorderColor(0.45, 0.28, 0.75, 0.80)
                end
            end)
            btn:SetScript("OnClick", function()
                local Eng = ArcadiaNexus.WRD_Engine
                if not Eng then return end
                local key = btn._key
                if key == "BACK"  then Eng:HandleInput("BACKSPACE")
                elseif key == "ENTER" then Eng:HandleInput("CONFIRM")
                else Eng:HandleInput("LETTER", key) end
            end)
            btn:Enable()
            btn:Show()

            if kd.key ~= "BACK" and kd.key ~= "ENTER" then
                self._kbButtons[kd.key] = btn
            end
            cx = cx + kd.w + gap_s
        end
    end
end

-- ============================================================
-- PHYSISCHE TASTATUR
-- ============================================================
function R:_SetupKeyboard()
    if self._keyFrame then return end
    local kf = CreateFrame("Frame", "ArcadiaNexus_WRD_KeyFrame", self.frame)
    kf:SetAllPoints(self.frame)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local Eng = ArcadiaNexus.WRD_Engine
        if not Eng then return end
        if #key == 1 and key:match("^%a$") then
            Eng:HandleInput("LETTER", key:upper())
        elseif key == "BACKSPACE" then
            Eng:HandleInput("BACKSPACE")
        elseif key == "ENTER" or key == "RETURN" then
            Eng:HandleInput("CONFIRM")
        end
    end)
    self._keyFrame = kf
end

function R:EnableKeyboard(enable)
    if self._keyFrame then self._keyFrame:EnableKeyboard(enable) end
end

-- ============================================================
-- TILE-HELPER
-- ============================================================
local function SetTileColor(tile, state, theme)
    local themeData = THEMES[theme] or THEMES.classic
    if state == "empty" then
        tile:SetBackdropColor(TILE_EMPTY_BG[1], TILE_EMPTY_BG[2], TILE_EMPTY_BG[3], 1)
        tile:SetBackdropBorderColor(TILE_EMPTY_BORDER[1], TILE_EMPTY_BORDER[2], TILE_EMPTY_BORDER[3], 1)
    elseif state == "input" then
        tile:SetBackdropColor(TILE_EMPTY_BG[1], TILE_EMPTY_BG[2], TILE_EMPTY_BG[3], 1)
        tile:SetBackdropBorderColor(TILE_INPUT_BORDER[1], TILE_INPUT_BORDER[2], TILE_INPUT_BORDER[3], 1)
    else
        local c = themeData[state]
        if c then
            tile:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], 1)
            tile:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
        end
    end
end

function R:_GetTheme()
    local S = ArcadiaNexus.WRD_Settings
    return S and S:Get("theme") or "classic"
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:EnableKeyboard(false)

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._statusFS      then self._statusFS:Hide()      end
    if self._msgFS         then self._msgFS:Hide()         end
    if self._gridHolder    then self._gridHolder:Hide()    end
    if self._kbHolder      then self._kbHolder:Hide()      end
    if self._hudBoxFrame   then self._hudBoxFrame:Hide()   end
    if self._logoTex       then self._logoTex:Show()       end
    if self._borderFrame   then self._borderFrame:Show()   end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")["btn_start"] or "Spiel starten")
    end
end

-- ============================================================
-- SPIEL GESTARTET
-- ============================================================
function R:OnGameStarted(gs)
    self.state = "PLAYING"
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._msgFS       then self._msgFS:Hide()       end
    if self._logoTex     then self._logoTex:Hide()     end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")["btn_exit"] or "Beenden")
    end

    self:_BuildGrid(gs.wordLength, gs.maxAttempts)
    self:_BuildKeyboard()
    self:_UpdateHUDBox(gs)
end

-- ============================================================
-- BOARD-UPDATE METHODEN
-- ============================================================
function R:UpdateCurrentRow(gs)
    local row   = gs.attemptsUsed + 1
    local tiles = self._tiles[row]
    local theme = self:_GetTheme()
    if not tiles then return end
    for col = 1, gs.wordLength do
        local tile = tiles[col]
        local ch   = gs.currentGuess:sub(col, col)
        tile._fs:SetText(ch)
        SetTileColor(tile, ch ~= "" and "input" or "empty", theme)
    end
end

function R:RevealTile(row, col, resultState, gs)
    local tiles = self._tiles[row]
    if not tiles or not tiles[col] then return end
    SetTileColor(tiles[col], resultState, self:_GetTheme())
end

function R:UpdateKeyboard(gs)
    local theme     = self:_GetTheme()
    local themeData = THEMES[theme] or THEMES.classic
    for letter, btn in pairs(self._kbButtons) do
        local status = gs.keyboard[letter]
        if status then
            local c = themeData[status]
            if c then
                local nt = btn:GetNormalTexture()
                if nt then nt:SetVertexColor(c.bg[1], c.bg[2], c.bg[3]) end
            end
        else
            local uk = themeData.key_unknown
            local nt = btn:GetNormalTexture()
            if nt then nt:SetVertexColor(uk[1], uk[2], uk[3]) end
        end
    end
    -- HUD-Box nach jedem Versuch aktualisieren
    self:_UpdateHUDBox(gs)
end

-- ============================================================
-- ERGEBNIS-OVERLAY
-- ============================================================
function R:ShowResult(gs)
    if not self._fieldFrame then return end
    local L      = ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")
    local UI     = ArcadiaNexus.UI
    local parent = self._fieldFrame

    self:EnableKeyboard(false)
    if self._statusFS then self._statusFS:Hide() end

    if self._startBtn then
        self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
    end
    self.state = "IDLE"

    local won = gs.won
    UI.ShowArcadeResult(parent, {
        title      = won and (L["state_win"] or "Gewonnen!") or (L["state_loss"] or "Das Wort war:"),
        titleColor = won and {0.12, 1, 0.12} or {1, 0.3, 0.3},
        subtitle   = "|cffffd700" .. gs.target .. "|r",
        score      = won and gs.score or nil,
        lines      = won and {
            (L["lbl_attempt"] or "Versuch") .. " " .. gs.attemptsUsed .. "/" .. gs.maxAttempts
            .. "   |   " .. (gs.score or 0) .. " Pts",
        } or nil,
        gameId     = "AZEROTHWORDS",
        result     = won and "WIN" or "LOSS",
        L          = L,
        buttons    = {
            {
                label   = L["btn_retry"] or "Nochmal",
                onClick = function()
                    local Eng = ArcadiaNexus.WRD_Engine
                    if Eng then Eng:Retry() end
                end,
            },
        },
    })
end

-- ============================================================
-- SCHÜTTEL-ANIMATION
-- ============================================================
function R:ShakeCurrentRow()
    local gs = ArcadiaNexus.WRD_Engine and ArcadiaNexus.WRD_Engine._gameState
    if not gs then return end
    local holder = self._gridHolder
    if not holder then return end

    self._shakeGen = (self._shakeGen or 0) + 1
    local gen      = self._shakeGen
    local accum    = 0
    local speed    = 20
    local maxCycles = 6

    holder:SetScript("OnUpdate", function(_, dt)
        if self._shakeGen ~= gen then
            holder:SetScript("OnUpdate", nil)
            holder:ClearAllPoints()
            holder:SetPoint("CENTER", self._canvas, "CENTER", CFG.grid_ofs_x, CFG.grid_ofs_y)
            return
        end
        accum = accum + dt
        local cycles = math.floor(accum * speed)
        if cycles >= maxCycles then
            holder:SetScript("OnUpdate", nil)
            holder:ClearAllPoints()
            holder:SetPoint("CENTER", self._canvas, "CENTER", CFG.grid_ofs_x, CFG.grid_ofs_y)
            return
        end
        local offset = math.sin(cycles * math.pi) * 5
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", self._canvas, "CENTER", CFG.grid_ofs_x + offset, CFG.grid_ofs_y)
    end)
end

-- ============================================================
-- MELDUNGS-TEXT
-- ============================================================
function R:ShowMessage(text)
    if not self._msgFS then return end
    self._msgFS:SetText(text)
    self._msgFS:Show()
    self._msgGen = (self._msgGen or 0) + 1
    local gen = self._msgGen
    C_Timer.After(1.5, function()
        if self._msgGen == gen and self._msgFS then
            self._msgFS:Hide()
        end
    end)
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
ArcadiaNexus.RegisterGame({
    id        = "AZEROTHWORDS",
    label     = "Azeroth Words",
    category  = "WORT",
    renderer  = "WRD_Renderer",
    engine    = "WRD_Engine",
    container = "_wrdContainer",
})
