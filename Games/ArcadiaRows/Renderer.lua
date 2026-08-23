--[[
    ArcadiaNexus
    Games/ArcadiaRows/Renderer.lua
    Version: 3.0.0

    Layout: Blueprint v1 (connect_four_bg.tga)
    Spielfeld fix: Normal (7×6) auf 560×384.
    Schwierigkeits-Auswahl via Dropdown.
    Start/Stopp via ArcadiaButton.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Renderer = {}

local Renderer = ArcadiaNexus.AR_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_ofs_x      = 16,
    field_ofs_y      = 5,
    field_w      = 560,
    field_h      = 484,
    board_cols   = 7,
    board_rows   = 6,
    cell_pad     = 0,
    grid_w       = 510,
    grid_h       = 400,
    grid_ox      = 3,
    grid_oy      = -10,
    bg_w         = 670,
    bg_h         = 540,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1,
    border_w     = 794,
    border_h     = 547,
    border_ofs_x = 0,
    border_ofs_y = 4,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    sound_win    = 888,
    sound_draw   = 8959,
    sound_loss   = 847,
    -- Logo
    logo_w       = 512,
    logo_h       = 512,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
}

-- Blueprint-Konstanten

-- Grid-Konstanten (7 Spalten × 6 Reihen)

-- ============================================================
-- Hintergrund-Größe (TGA-Anpassung)
-- Werte in Pixeln. Standard = Spielfeldgröße.
-- ============================================================

-- ============================================================
-- DEBUG: Visuelle Schichten separat ein-/ausblenden
-- true = sichtbar, false = unsichtbar
-- Spiellogik läuft in allen Kombinationen vollständig durch.
-- ============================================================
local DBG_SHOW_GRID      = true   -- Zell-Hintergründe (blaue Slots)
local DBG_SHOW_DISCS     = true   -- Spielsteine / Fraktions-Wappen
local DBG_SHOW_HIGHLIGHT = true   -- Spalten-Hover-Highlight

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaRows.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            local disc = f:CreateTexture(nil, "ARTWORK")
            f.disc = disc
            if disc.AddMaskTexture then
                local mask = f:CreateMaskTexture(nil, "ARTWORK")
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                disc:AddMaskTexture(mask)
                f.discMask = mask
            end
            local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            text:SetPoint("CENTER")
            f.text = text
            local atlTex = f:CreateTexture(nil, "OVERLAY")
            atlTex:Hide()
            if atlTex.AddMaskTexture then
                local atlMask = f:CreateMaskTexture(nil, "OVERLAY")
                atlMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                atlTex:AddMaskTexture(atlMask)
                f.atlMask = atlMask
            end
            f.atlTex = atlTex
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            if f.disc then f.disc:SetColorTexture(0.1, 0.1, 0.1, 1) end
            if f.text then f.text:SetText("") end
            if f.atlTex then f.atlTex:Hide(); f.atlTex:SetTexture(nil) end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

local function CreateColHitPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaRows.ColHits",
        create = function(poolParent)
            poolParentRef = poolParent
            local hit = CreateFrame("Button", nil, poolParent)
            hit:EnableMouse(true)
            return hit
        end,
        onRelease = function(hit)
            hit:Hide()
            hit:ClearAllPoints()
            hit:Enable()
            hit:SetScript("OnClick", nil)
            hit:SetScript("OnEnter", nil)
            hit:SetScript("OnLeave", nil)
            hit._col = nil
            if poolParentRef then hit:SetParent(poolParentRef) end
        end,
    })
end

-- SoundKitIDs

-- ============================================================
-- State
-- ============================================================

Renderer.frame         = nil   -- Container (füllt gamesPanel)
Renderer._canvas       = nil   -- zentrierter 600×498 Blueprint-Canvas
Renderer._controlsFrame = nil
Renderer.playfield     = nil   -- festes 560×384 Spielfeld-Frame
Renderer.dropdown      = nil
Renderer.startBtn      = nil

Renderer.cellButtons   = {}    -- [row][col] = Frame
Renderer.colHitFrames  = {}    -- [col] = unsichtbarer Klick-Frame

Renderer.cellW         = 0
Renderer.cellH         = 0

Renderer.state         = "IDLE"
Renderer.lastResult    = nil
Renderer.selectedDiff  = "easy"

Renderer.winLineFrame   = nil
Renderer.winLineTexture = nil
Renderer._logoTex       = nil

-- ============================================================
-- Sound
-- ============================================================

local function PlayGameSound(result)
    local S = ArcadiaNexus.AR_Settings
    if not S or not S:Get("soundEnabled") then return end
    if result == "WIN"  and S:Get("soundOnWin")  then PlaySound(CFG.sound_win,  "SFX") end
    if result == "DRAW" and S:Get("soundOnDraw") then PlaySound(CFG.sound_draw, "SFX") end
    if result == "LOSS" and S:Get("soundOnLoss") then PlaySound(CFG.sound_loss, "SFX") end
end

-- ============================================================
-- Symbol anwenden
-- ============================================================

local function ApplySymbol(btn, symbolDef)
    if not DBG_SHOW_DISCS then return end
    if not symbolDef then
        btn.disc:SetColorTexture(0.1, 0.1, 0.1, 1)
        btn.text:SetText("")
        if btn.atlTex then btn.atlTex:Hide() end
        return
    end

    if symbolDef.mode == "TEXT" then
        btn.disc:SetColorTexture(symbolDef.r or 1, symbolDef.g or 1, symbolDef.b or 1, 1)
        btn.text:SetText("")
        if btn.atlTex then btn.atlTex:Hide() end
    elseif symbolDef.mode == "SPRITE" then
        btn.disc:SetColorTexture(0.25, 0.25, 0.25, 1)
        btn.text:SetText("")
        if btn.atlTex then
            btn.atlTex:SetTexture(symbolDef.path)
            btn.atlTex:SetTexCoord(symbolDef.left, symbolDef.right, symbolDef.top, symbolDef.bottom)
            btn.atlTex:Show()
        end
    end
end

-- ============================================================
-- Logo
-- ============================================================

function Renderer:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self.playfield,
        "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\logo\\logo_ar",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- Init
-- ============================================================

function Renderer:Init()
    self:CreateMainFrame()
    self:CreatePlayfield()
    self:_CreateLogo()
    self:CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine

    Engine:On("AR_GAME_STARTED", function(board)
        Renderer.state = "PLAYING"
        if Renderer._logoTex then Renderer._logoTex:Hide() end
        Renderer:RenderBoard(board)
        Renderer:UpdateStartButton()
    end)

    Engine:On("AR_BOARD_UPDATED", function()
        Renderer:UpdateBoard()
    end)

    Engine:On("AR_GAME_OVER", function(result)
        Renderer:ShowGameOver(result)
    end)

    Engine:On("AR_WIN_LINE", function(line)
        Renderer:HighlightWinningLine(line)
    end)

    Engine:On("AR_GAME_STOPPED", function()
        Renderer:EnterIdleState()
    end)
end

-- ============================================================
-- Container-Frame (füllt gamesPanel, kein Backdrop, kein Show)
-- ============================================================

function Renderer:CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI.GetGamesPanel()
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AR_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._arContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("ARCADIAROWS", ArcadiaNexus.AR_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

-- ============================================================
-- Spielfeld (feste 560×384, TGA-Hintergrund)
-- ============================================================

function Renderer:CreatePlayfield()
    if self.playfield then return end

    local canvas = self._canvas
    local pf = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    pf:SetSize(CFG.field_w, CFG.field_h)
    -- X-zentriert im festen Blueprint-Canvas, 16px vom oberen Rand
    pf:SetPoint("TOP", canvas, "TOP", 0, CFG.field_ofs_y)
    pf:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    pf:SetBackdropBorderColor(0.2, 0.2, 0.4, 0)

    local bgTex = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetSize(CFG.bg_w, CFG.bg_h)
    bgTex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    bgTex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\background\\background_ar")
    bgTex:SetAlpha(CFG.bg_alpha)
    self._bgTex = bgTex

    -- Rahmen-TGA auf eigenem Frame vor dem Grid (transparentes Inneres).
    local borderFrame = CreateFrame("Frame", nil, pf)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", pf, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(pf:GetFrameLevel() + 100)
    borderFrame:EnableMouse(false)
    local borderTex = borderFrame:CreateTexture(nil, "ARTWORK")
    borderTex:SetAllPoints(borderFrame)
    borderTex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\border\\border_ar")
    self._borderFrame = borderFrame

    self.playfield = pf
end

-- ============================================================
-- Controls: Dropdown (Schwierigkeit) + Start/Stop-Button
-- ============================================================

function Renderer:CreateControls()
    if self.dropdown then return end

    local L  = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local options = {
        { key = "easy",   label = L["diff_easy"]   },
        { key = "normal", label = L["diff_normal"]  },
        { key = "hard",   label = L["diff_hard"]    },
    }

    self.dropdown = UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        options,
        function() return Renderer.selectedDiff end,
        function(key) Renderer.selectedDiff = key end
    )

    -- Start/Stop-Button (mittleres Segment, x=0)
    local btn = UI.CreateArcadiaButton(cf, L["btn_start"], 144, 32)
    btn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    btn:SetScript("OnClick", function()
        if Renderer.state == "PLAYING" then
            ArcadiaNexus.AR_Engine:StopGame()
        else
            ArcadiaNexus.AR_Engine:StartGame({
                cols         = CFG.board_cols,
                rows         = CFG.board_rows,
                aiDifficulty = Renderer.selectedDiff,
            })
        end
    end)
    self.startBtn = btn

    self:UpdateStartButton()
end

function Renderer:UpdateStartButton()
    if not self.startBtn then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    if self.state == "PLAYING" then
        self.startBtn:SetLabel(L["btn_exit"] or "Beenden")
    else
        self.startBtn:SetLabel(L["btn_start"] or "Spiel Starten")
    end
end

-- ============================================================
-- Idle / Clear
-- ============================================================

function Renderer:SetGridVisible(visible)
    for row = 1, #self.cellButtons do
        local rowData = self.cellButtons[row]
        if rowData then
            for col = 1, #rowData do
                local btn = rowData[col]
                if btn then
                    if visible then btn:Show() else btn:Hide() end
                end
            end
        end
    end
    for col = 1, #self.colHitFrames do
        local hit = self.colHitFrames[col]
        if hit then
            if visible then hit:Show() else hit:Hide() end
        end
    end
end

-- ============================================================
-- Idle / Clear
-- ============================================================

function Renderer:EnterIdleState()
    self.state = "IDLE"
    self:ClearBoard()
    self:ClearWinningLine()
    if self.playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self.playfield)
    end
    if self._logoTex  then self._logoTex:Show() end
    self:UpdateStartButton()
end

-- ============================================================
-- Board rendern
-- ============================================================

function Renderer:_EnsureBoardPools()
    if not self._cellPool then self._cellPool = CreateCellPool() end
    if not self._colHitPool then self._colHitPool = CreateColHitPool() end
end

function Renderer:ClearBoard()
    if self._cellPool then self._cellPool:ReleaseAll() end
    if self._colHitPool then self._colHitPool:ReleaseAll() end
    self.cellButtons = {}
    self.colHitFrames = {}
end

function Renderer:RenderBoard(board)
    self:ClearBoard()
    self:ClearWinningLine()
    if self.playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self.playfield)
    end

    -- Gesamtgröße des Grids (manuell oder Spielfeld füllen)
    local gridW = CFG.grid_w or CFG.field_w
    local gridH = CFG.grid_h or CFG.field_h
    local cellW = math.floor(gridW / board.cols)
    local cellH = math.floor(gridH / board.rows)
    self.cellW = cellW
    self.cellH = cellH

    local offX  = (CFG.field_w - gridW) / 2 + CFG.grid_ox
    local offY  = (CFG.field_h - gridH) / 2 + CFG.grid_oy
    self:_EnsureBoardPools()

    for row = 1, board.rows do
        self.cellButtons[row] = {}
        for col = 1, board.cols do
            local f = self._cellPool:Acquire({})
            f:SetParent(self.playfield)
            f:SetSize(cellW - CFG.cell_pad * 2, cellH - CFG.cell_pad * 2)
            f:SetPoint("TOPLEFT", self.playfield, "TOPLEFT",
                offX + (col - 1) * cellW + CFG.cell_pad,
                -(offY + (row - 1) * cellH + CFG.cell_pad))
            f:SetBackdropColor(0.05, 0.05, 0.20, 1)
            if not DBG_SHOW_GRID then
                f:SetBackdropColor(0, 0, 0, 0)
            end

            local pad = math.floor(math.min(cellW, cellH) * 0.08)
            f.disc:ClearAllPoints()
            f.disc:SetPoint("TOPLEFT",     f, "TOPLEFT",     pad, -pad)
            f.disc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
            f.disc:SetColorTexture(0.1, 0.1, 0.1, 1)
            if f.discMask then f.discMask:SetAllPoints(f.disc) end

            f.atlTex:ClearAllPoints()
            f.atlTex:SetPoint("TOPLEFT",     f, "TOPLEFT",     pad, -pad)
            f.atlTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
            f.atlTex:Hide()
            if f.atlMask then f.atlMask:SetAllPoints(f.atlTex) end
            f.text:SetText("")
            f:Show()

            self.cellButtons[row][col] = f
        end
    end

    for col = 1, board.cols do
        local hit = self._colHitPool:Acquire({})
        hit:SetParent(self.playfield)
        hit:SetSize(cellW, board.rows * cellH)
        hit:SetPoint("TOPLEFT", self.playfield, "TOPLEFT",
            offX + (col - 1) * cellW,
            -offY)
        hit._col = col
        hit:SetScript("OnClick", function()
            ArcadiaNexus.AR_Engine:HandlePlayerMove(hit._col)
        end)
        hit:SetScript("OnEnter", function()
            Renderer:HighlightColumn(hit._col, true)
        end)
        hit:SetScript("OnLeave", function()
            Renderer:HighlightColumn(hit._col, false)
        end)
        hit:Enable()
        hit:Show()

        self.colHitFrames[col] = hit
    end

    self:UpdateBoard()
end

-- ============================================================
-- Spalten-Highlight
-- ============================================================

function Renderer:HighlightColumn(col, on)
    if not DBG_SHOW_HIGHLIGHT then return end
    for row = 1, CFG.board_rows do
        local btn = self.cellButtons[row] and self.cellButtons[row][col]
        if btn then
            if on then
                if DBG_SHOW_GRID then
                    btn:SetBackdropColor(0.15, 0.15, 0.40, 1)
                end
            else
                if DBG_SHOW_GRID then
                    btn:SetBackdropColor(0.05, 0.05, 0.20, 1)
                end
            end
        end
    end
end

-- ============================================================
-- Board aktualisieren
-- ============================================================

function Renderer:UpdateBoard()
    local game = ArcadiaNexus.AR_Engine
        and ArcadiaNexus.AR_Engine.activeGame
    if not game then return end

    local board   = game:GetBoardState()
    local symbols = { player1 = nil, player2 = nil }

    if ArcadiaNexus.AR_SymbolResolver then
        symbols = ArcadiaNexus.AR_SymbolResolver:Resolve()
    else
        symbols.player1 = { mode="TEXT", r=1.00, g=0.85, b=0.00 }
        symbols.player2 = { mode="TEXT", r=1.00, g=0.15, b=0.15 }
    end

    for row = 1, board.rows do
        for col = 1, board.cols do
            local btn   = self.cellButtons[row] and self.cellButtons[row][col]
            local value = board.cells[row][col]
            if btn then
                if value == 1 then
                    ApplySymbol(btn, symbols.player1)
                elseif value == 2 then
                    ApplySymbol(btn, symbols.player2)
                else
                    btn.disc:SetColorTexture(0.1, 0.1, 0.1, 1)
                    btn.text:SetText("")
                    if btn.atlTex then btn.atlTex:Hide() end
                end
            end
        end
    end
end

-- ============================================================
-- Game Over
-- ============================================================

function Renderer:ShowGameOver(result)
    self.state      = "GAMEOVER"
    self.lastResult = result

    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    local UI     = ArcadiaNexus.UI
    local parent = self.playfield
    if not parent then return end

    local dialogResult = (result == "WIN" or result == "LOSS") and result or "DRAW"

    for col = 1, #self.colHitFrames do
        if self.colHitFrames[col] then self.colHitFrames[col]:Disable() end
    end

    UI.ShowArcadeResult(parent, {
        gameId   = "ARCADIAROWS",
        result   = dialogResult,
        titleKeys = {
            WIN  = { "result_win" },
            LOSS = { "result_loss" },
            DRAW = { "result_draw" },
        },
        L = L,
        onRetry = function()
            ArcadiaNexus.AR_Engine:StartGame({
                cols         = CFG.board_cols,
                rows         = CFG.board_rows,
                aiDifficulty = Renderer.selectedDiff,
            })
        end,
        onExit = function()
            ArcadiaNexus.AR_Engine:StopGame()
        end,
    })

    self:UpdateStartButton()
    PlayGameSound(result)
end

-- ============================================================
-- Winning Line
-- Goldener Content-TGA-Rahmen um die Linie (auch diagonal) ist mit
-- Backdrop/TGA nicht rotierbar — laut Spezifikation daher nicht umgesetzt.
-- ============================================================

function Renderer:ClearWinningLine()
    if self.winLineTexture then
        if self.winLineTexture.pulseAnim then
            self.winLineTexture.pulseAnim:Stop()
        end
        self.winLineTexture:Hide()
    end
end

function Renderer:HighlightWinningLine(line)
    if not line or #line < 2 then return end

    local cellW = self.cellW
    local cellH = self.cellH
    local gridW = cellW * CFG.board_cols
    local gridH = cellH * CFG.board_rows
    local offX  = (CFG.field_w - gridW) / 2 + CFG.grid_ox
    local offY  = (CFG.field_h - gridH) / 2 + CFG.grid_oy

    local p1 = line[1]
    local p2 = line[#line]

    local x1 = offX + (p1.col - 0.5) * cellW
    local y1 = offY + (p1.row - 0.5) * cellH
    local x2 = offX + (p2.col - 0.5) * cellW
    local y2 = offY + (p2.row - 0.5) * cellH

    local dx     = x2 - x1
    local dy     = y1 - y2
    local length = math.sqrt(dx*dx + dy*dy)
    local cx     = (x1 + x2) / 2
    local cy     = (y1 + y2) / 2
    local angle  = math.atan2(dy, dx)

    if not self.winLineFrame then
        local frame = CreateFrame("Frame", nil, self.playfield)
        frame:SetAllPoints(self.playfield)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(self.playfield:GetFrameLevel() + 150)
        self.winLineFrame = frame

        local tex = frame:CreateTexture(nil, "OVERLAY")
        self.winLineTexture = tex

        local pulse = tex:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.35)
        fade:SetToAlpha(1)
        fade:SetDuration(0.5)
        fade:SetSmoothing("IN_OUT")
        tex.pulseAnim = pulse
    end

    local tex = self.winLineTexture
    if tex.pulseAnim then tex.pulseAnim:Stop() end

    if self.lastResult == "LOSS" then
        tex:SetColorTexture(1, 0, 0, 0.9)
    else
        tex:SetColorTexture(0, 1, 0, 0.9)
    end

    tex:SetSize(length, 8)
    tex:SetPoint("CENTER", self.playfield, "TOPLEFT", cx, -cy)
    tex:SetRotation(angle)
    tex:SetAlpha(1)
    tex:Show()
    tex.pulseAnim:Play()
end

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "ARCADIAROWS",
    label     = "Arcadia Rows",
    renderer  = "AR_Renderer",
    engine    = "AR_Engine",
    container = "_arContainer",
    category  = "DENKSPIELE",
})
