-- ============================================================
--  ArcadiaNexus
--  Games/ArcadiasEcho/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach Sudoku-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD: Thema links, Runde rechts (über dem Spielfeld)
--    - Controls-Leiste am BOTTOM: Dropdown Schwierigkeit + Start/Beenden
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--
--  Board-Aufbau (unverändert):
--    BuildGrid / ClearGrid / FlashSymbol / SetButtonsEnabled
--    Direktaufruf vom Engine (zeitkritisch, kein Event-Umweg)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AE_Renderer = {}
local R = ArcadiaNexus.AE_Renderer
local _viewGuard = ArcadiaNexus.TimerGuard.New()

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_size   = 400,
    field_ofs_x  = 0,
    field_ofs_y  = 15,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,
    border_w     = 795,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 0,
    logo_w       = 328,
    logo_h       = 306,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    hud_y        = 226,
    hud_r_x      = 190,
    hud_box_w    = 180,
    hud_box_h    = 38,
    hud_box_alpha = 0.75,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    grid_gap     = 0,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local AE_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiasEcho\\assets\\background\\background_ac",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiasEcho\\assets\\logo\\logo_arcadias_echo",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiasEcho\\assets\\border\\border_arcadias_echo",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================



-- HUD – relativ zu self.frame CENTER

-- Grid-Interna (unverändert)

-- ============================================================
-- HILFSFUNKTIONEN (unverändert)
-- ============================================================
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function ApplySymbolTexture(tex, sym)
    tex:SetTexture(nil)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    if sym.isAtlas then
        tex:SetAtlas(sym.atlas, false)
    else
        tex:SetTexture(sym.icon)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        tex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
    end
end

local function MakeRoundIcon(parent, size, layer)
    layer = layer or "ARTWORK"
    local tex = parent:CreateTexture(nil, layer)
    tex:SetSize(size, size)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if parent.CreateMaskTexture then
        local mask = parent:CreateMaskTexture()
        mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetSize(size, size)
        tex:AddMaskTexture(mask)
        return tex, mask
    end
    return tex, nil
end

local SYMBOL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false,
    edgeSize = 3,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function CreateSymbolCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiasEcho.SymbolCells",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            btn:SetBackdrop(SYMBOL_BACKDROP)
            local iconTex, maskTex = MakeRoundIcon(btn, 32, "ARTWORK")
            btn.iconTex = iconTex
            btn.maskTex = maskTex
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:SetScript("OnClick", nil)
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn.sym = nil
            btn._glow = nil
            btn._symIdx = nil
            if btn.iconTex then
                btn.iconTex:Hide()
                btn.iconTex:SetTexture(nil)
                btn.iconTex:SetAlpha(1)
                btn.iconTex:SetVertexColor(1, 1, 1, 1)
            end
            if btn.maskTex then btn.maskTex:Hide() end
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================
R.frame         = nil
R._canvas       = nil
R._controlsFrame = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"

-- Grid
R._boardHolder  = nil
R.symbolBtns    = {}
R._layout       = nil

-- HUD
R._statusBox    = nil
R._statusFS     = nil
R._statusLbl    = nil
R._hintFS       = nil

-- Controls
R._startBtn     = nil
R._lastDiff     = nil

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateControls()
    self:EnterIdleState()

    local Eng = ArcadiaNexus.Engine
    Eng:On("AE_GAME_STARTED", function(b) R:OnGameStarted(b) end)
    Eng:On("AE_GAME_STOPPED", function()  R:EnterIdleState() end)
end

-- ============================================================
-- FRAME-AUFBAU
-- ============================================================
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AE_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._aeContainer = f
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(frame, key)
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        local handled = not focus and R:HandleKey(key)
        frame:SetPropagateKeyboardInput(not handled)
    end)

    f:SetScript("OnHide", function()
        _viewGuard:Cancel()
        ArcadiaNexus.GameSession:HandleRendererHide("ARCADIASECHO", ArcadiaNexus.AE_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

function R:UpdateFocus()
    local btn = self.symbolBtns[self._focusSymbol or 1]
    if not btn or self.state ~= "PLAYING" or ArcadiaNexus.AE_Engine._inputBlock then
        if self._focusFrame then self._focusFrame:Hide() end
        return
    end
    if not self._focusFrame then
        self._focusFrame = CreateFrame("Frame", nil, self._boardHolder, "BackdropTemplate")
        self._focusFrame:EnableMouse(false)
        self._focusFrame:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
        self._focusFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    self._focusFrame:ClearAllPoints()
    self._focusFrame:SetAllPoints(btn)
    self._focusFrame:SetFrameLevel(btn:GetFrameLevel()+5)
    self._focusFrame:Show()
end

function R:HandleKey(key)
    local E = ArcadiaNexus.AE_Engine
    if self.state ~= "PLAYING" or not E.activeGame or E._inputBlock
        or not ArcadiaNexus.GameSession:IsSession(E, E._sessionId) then return false end
    local board = E.activeGame.board
    local index = self._focusSymbol or 1
    local row, col = math.floor((index-1)/board.grid), (index-1)%board.grid
    if key == "LEFT" then col=math.max(0,col-1)
    elseif key == "RIGHT" then col=math.min(board.grid-1,col+1)
    elseif key == "UP" then row=math.max(0,row-1)
    elseif key == "DOWN" then row=math.min(board.grid-1,row+1)
    elseif key == "SPACE" or key == "ENTER" then return E:HandleInput(index)
    else return false end
    self._focusSymbol = row*board.grid+col+1
    self:UpdateFocus()
    return true
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local f  = self._canvas
    local ff = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ff:SetSize(CFG.field_size, CFG.field_size)
    ff:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(AE_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(AE_ASSETS.border)
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
        AE_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- HUD (Runde)
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")

    -- Runden-Status: Box mit dunklem Hintergrund und goldenem Rahmen (wie Blackjack)
    local statusBox = ArcadiaNexus.UI.CreateHudStatBox(f, {
        w=CFG.hud_box_w, h=CFG.hud_box_h, point="CENTER", relativePoint="CENTER",
        x=CFG.hud_r_x, y=CFG.hud_y, alpha=CFG.hud_box_alpha, shown=false,
    })
    statusBox:SetSize(CFG.hud_box_w, CFG.hud_box_h)
    statusBox:SetPoint("CENTER", f, "CENTER", CFG.hud_r_x, CFG.hud_y)
    statusBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    statusBox:SetBackdropColor(0.05, 0.05, 0.05, CFG.hud_box_alpha)
    statusBox:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    statusBox:Hide()
    self._statusBox = statusBox

    local statusLbl = statusBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLbl:SetPoint("TOP", statusBox, "TOP", 0, -4)
    statusLbl:SetTextColor(0.75, 0.70, 0.55)
    statusLbl:SetText("|cffffd700" .. (L["lbl_round"] or "Runde") .. "|r")
    self._statusLbl = statusLbl

    local statusFS = statusBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusFS:SetPoint("BOTTOM", statusBox, "BOTTOM", 0, 4)
    statusFS:SetText("")
    self._statusFS = statusFS

    self._lengthBox, self._lengthFS = ArcadiaNexus.UI.CreateHudStatBox(f, {
        w=CFG.hud_box_w, h=CFG.hud_box_h, point="CENTER", relativePoint="CENTER",
        x=-CFG.hud_r_x, y=CFG.hud_y, alpha=CFG.hud_box_alpha, shown=false,
    })
    self._bestBox, self._bestFS = ArcadiaNexus.UI.CreateHudStatBox(f, {
        w=CFG.hud_box_w, h=CFG.hud_box_h, point="CENTER", relativePoint="CENTER",
        x=0, y=CFG.hud_y, alpha=CFG.hud_box_alpha, shown=false,
    })

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:UpdateStatus(board)
    local L = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")

    if self._statusFS then
        if board.round == 0 then
            self._statusFS:SetText(L["status_ready"] or "")
        else
            self._statusFS:SetText(tostring(board.round))
        end
        self._statusFS:Show()
    end
    if self._statusLbl then self._statusLbl:Show() end
    if self._statusBox then self._statusBox:Show() end
    if self._lengthFS then self._lengthFS:SetText(string.format(L.hud_length, board.round)) end
    if self._bestFS then self._bestFS:SetText(string.format(L.hud_best, ArcadiaNexus.AE_Logic:GetScore(board))) end
    if self._lengthBox then self._lengthBox:Show() end
    if self._bestBox then self._bestBox:Show() end
    if self._statusLbl then
        self._statusLbl:SetText(board.state == "input" and L.phase_input or L.phase_showing)
    end
    if self._statusFS then
        self._statusFS:SetText(board.state == "input" and string.format(L.hud_progress, board.inputPos, board.round) or "")
    end
end

function R:RefreshConfiguration()
    if self._difficultyDD then
        local E = ArcadiaNexus.AE_Engine
        self._difficultyDD:SetEnabled(not E.activeGame or E.state == "IDLE")
        self._difficultyDD:RefreshDisplay()
    end
end

-- ============================================================
-- CONTROLS (Dropdown + Start/Beenden)
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (linkes Segment)
    local S = ArcadiaNexus.AE_Settings

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    self._difficultyDD = UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]   },
            { key = "normal", label = L["diff_normal"]  },
            { key = "hard",   label = L["diff_hard"]    },
        },
        function()
            local E = ArcadiaNexus.AE_Engine
            return E.activeGame and E.activeGame.board.difficulty or (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            if ArcadiaNexus.AE_Engine.activeGame then return end
            if S then S:Set("difficulty", key) end
        end
    )

    -- Start / Beenden Button (mittleres Segment)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AE_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:EndAttempt()
        else
            R:_StartNewGame()
        end
    end)
    self._startBtn = startBtn
end

function R:_StartNewGame()
    local S = ArcadiaNexus.AE_Settings
    ArcadiaNexus.AE_Engine:StartGame({
        difficulty = (S and S:Get("difficulty")) or "easy",
        theme      = (S and S:Get("theme")) or "runes",
    })
end

function R:ShowOverlay(board)
    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")
    local parent = self._fieldFrame
    local E = ArcadiaNexus.AE_Engine
    local game = E.activeGame
    if not game or game.board ~= board then return end
    if not game.resultCommitted and not E:FinishRun(game.resultData and game.resultData.reason or "error") then
        self:ScheduleResult(board)
        return
    end
    local score = ArcadiaNexus.AE_Logic:GetScore(board)
    local data = game.resultData
    local neutral = data.reason ~= "error"

    UI.ShowArcadeResult(parent, {
        title      = neutral and L.result_exit_title or L.result_loss_title,
        titleColor = neutral and {0.85, 0.85, 0.85} or {1, 0.3, 0.3},
        subtitle   = string.format(L.result_mastered, score),
        gameId     = "ARCADIASECHO",
        result     = "LOSS",
        difficulty = board.difficulty,
        score = score, xp = data.awardedXP, gold = data.awardedGold,
        newHighscore = data.newHighscore,
        highscore = ArcadiaNexus.ScoreManager:GetBestScore("ARCADIASECHO", board.difficulty),
        L          = L,
        onRetry    = function() R:_StartNewGame() end,
        onExit     = function() ArcadiaNexus.AE_Engine:StopGame() end,
    })
end

-- ============================================================
-- GRID – Größenberechnung
-- ============================================================
function R:_ComputeLayout(gridSize)
    local avail    = CFG.field_size
    local cellSize = math.floor((avail - (gridSize - 1) * CFG.grid_gap) / gridSize)
    cellSize = math.max(60, cellSize)
    local totalW   = gridSize * cellSize + (gridSize - 1) * CFG.grid_gap
    local totalH   = totalW
    return {
        cellSize = cellSize,
        gap      = CFG.grid_gap,
        totalW   = totalW,
        totalH   = totalH,
        gridSize = gridSize,
    }
end

-- ============================================================
-- GRID – Aufbauen (Kern unverändert, Anker auf _fieldFrame)
-- ============================================================
function R:_EnsureSymbolCellPool()
    if not self._symbolCellPool then
        self._symbolCellPool = CreateSymbolCellPool()
    end
end

function R:BuildGrid(board)
    self:ClearGrid()

    local T       = ArcadiaNexus.AE_Themes
    local symbols = T:GetSymbolsForDiff(board.theme, board.difficulty)
    local L       = self:_ComputeLayout(board.grid)
    self._layout  = L

    local holder = self._boardHolder
    if not holder then
        holder = CreateFrame("Frame", nil, self._fieldFrame)
        self._boardHolder = holder
    end
    holder:SetParent(self._fieldFrame)
    holder:SetSize(L.totalW, L.totalH)
    holder:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    holder:Show()

    self.symbolBtns = {}
    self:_EnsureSymbolCellPool()

    for idx, sym in ipairs(symbols) do
        local row = math.floor((idx - 1) / L.gridSize)
        local col = (idx - 1) % L.gridSize

        local bx = col * (L.cellSize + L.gap)
        local by = row * (L.cellSize + L.gap)

        local btn = self._symbolCellPool:Acquire({})
        btn:SetParent(holder)
        btn:SetSize(L.cellSize, L.cellSize)
        btn:SetPoint("TOPLEFT", holder, "TOPLEFT", bx, -by)
        btn:SetBackdropColor(
            sym.color[1] * 0.12,
            sym.color[2] * 0.12,
            sym.color[3] * 0.12, 1)
        btn:SetBackdropBorderColor(
            sym.color[1] * 0.40,
            sym.color[2] * 0.40,
            sym.color[3] * 0.40, 1)

        local iconSize = L.cellSize - 16
        btn.iconTex:SetSize(iconSize, iconSize)
        btn.iconTex:SetPoint("CENTER")
        if btn.maskTex then
            btn.maskTex:SetSize(iconSize, iconSize)
            btn.maskTex:SetPoint("CENTER")
            btn.maskTex:Show()
        end
        ApplySymbolTexture(btn.iconTex, sym)
        if sym.isAtlas then
            btn.iconTex:SetAlpha(0.55)
        else
            btn.iconTex:SetVertexColor(sym.color[1] * 0.6, sym.color[2] * 0.6, sym.color[3] * 0.6)
        end
        btn.iconTex:Show()

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(sym.name, sym.color[1], sym.color[2], sym.color[3])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn._symIdx = idx
        btn:SetScript("OnClick", function()
            ArcadiaNexus.AE_Engine:HandleInput(btn._symIdx)
        end)

        btn.sym     = sym
        btn._glow   = false
        btn:Show()

        self.symbolBtns[idx] = btn
    end
end

function R:ClearGrid()
    if self._focusFrame then self._focusFrame:Hide() end
    if self._symbolCellPool and self.symbolBtns then
        for _, btn in pairs(self.symbolBtns) do
            self._symbolCellPool:Release(btn)
        end
    end
    self.symbolBtns = {}
    self._layout    = nil
    if self._boardHolder then self._boardHolder:Hide() end
end

-- ============================================================
-- FLASH / BUTTONS (unverändert)
-- ============================================================
function R:FlashSymbol(symIdx, on)
    local btn = self.symbolBtns[symIdx]
    if not btn then return end
    btn._glow = on
    local sym = btn.sym
    if on then
        btn:SetBackdropColor(sym.color[1] * 0.55, sym.color[2] * 0.55, sym.color[3] * 0.55, 1)
        btn:SetBackdropBorderColor(sym.color[1], sym.color[2], sym.color[3], 1)
        if sym.isAtlas then
            btn.iconTex:SetAlpha(1.0)
        else
            btn.iconTex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
        end
    else
        btn:SetBackdropColor(sym.color[1] * 0.12, sym.color[2] * 0.12, sym.color[3] * 0.12, 1)
        btn:SetBackdropBorderColor(sym.color[1] * 0.40, sym.color[2] * 0.40, sym.color[3] * 0.40, 1)
        if sym.isAtlas then
            btn.iconTex:SetAlpha(0.55)
        else
            btn.iconTex:SetVertexColor(sym.color[1] * 0.6, sym.color[2] * 0.6, sym.color[3] * 0.6)
        end
    end
end

function R:SetButtonsEnabled(enabled)
    for _, btn in ipairs(self.symbolBtns) do
        btn:SetEnabled(enabled)
        btn:SetAlpha(enabled and 1.0 or 0.75)
    end
    self:UpdateFocus()
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(board)
    _viewGuard:Cancel()
    self.state     = "PLAYING"
    self._lastDiff = board.difficulty
    self._focusSymbol = 1

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._goldGrid then self._goldGrid:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIASECHO")["btn_exit"])
    end

    self:BuildGrid(board)
    self:SetButtonsEnabled(false)
    self:UpdateStatus(board)
    self:RefreshConfiguration()
end

function R:OnNewRound(board)
    _viewGuard:Cancel()
    self:SetButtonsEnabled(false)
    self:UpdateStatus(board)
    for idx in ipairs(self.symbolBtns) do self:FlashSymbol(idx, false) end
end

function R:OnSequenceDone(board)
    self:SetButtonsEnabled(true)
    self:UpdateStatus(board)
end

function R:OnInputCorrect(board)
    self:UpdateStatus(board)
end

function R:OnRoundComplete(board)
    self:SetButtonsEnabled(false)
    self:UpdateStatus(board)
    for idx in ipairs(self.symbolBtns) do self:FlashSymbol(idx, false) end
    if self._statusLbl then self._statusLbl:SetText(ArcadiaNexus.GetLocaleTable("ARCADIASECHO").phase_complete) end
    if self._statusFS then
        self._statusFS:SetText(string.format(
            ArcadiaNexus.GetLocaleTable("ARCADIASECHO")["status_round_ok"], board.round))
    end
end

function R:ScheduleResult(board)
    _viewGuard:Cancel()
    local E = ArcadiaNexus.AE_Engine
    local sid, game = E._sessionId, E.activeGame
    _viewGuard:After(0.8, function()
        if not ArcadiaNexus.GameSession:IsSession(E, sid) or E.activeGame ~= game
            or not game or game.board ~= board or self.state ~= "FINISHED" then return end
        self:ShowOverlay(board)
    end)
end

function R:OnGameFinished(board)
    self.state = "FINISHED"
    self:SetButtonsEnabled(false)
    self:UpdateStatus(board)
    local L = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")
    for idx in ipairs(self.symbolBtns) do self:FlashSymbol(idx, false) end
    local game = ArcadiaNexus.AE_Engine.activeGame
    if game and game.resultData and game.resultData.reason == "error" then
        local chosen, expected = self.symbolBtns[board.chosenSymbol], self.symbolBtns[board.expectedSymbol]
        if chosen then chosen:SetBackdropBorderColor(1, 0.1, 0.1, 1) end
        if expected then expected:SetBackdropBorderColor(0.2, 1, 0.2, 1) end
        if self._hintFS and chosen and expected then
            self._hintFS:SetPoint("CENTER", self._canvas, "CENTER", 0, -220)
            self._hintFS:SetWidth(560)
            self._hintFS:SetText(string.format(L.error_symbols, chosen.sym.name, expected.sym.name))
            self._hintFS:Show()
        end
    end
    if self._statusLbl then self._statusLbl:SetText(L.result_exit_title) end
    self:ScheduleResult(board)
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIASECHO")["btn_start"])
    end
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    _viewGuard:Cancel()
    self.state = "IDLE"
    self:ClearGrid()

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._statusBox    then self._statusBox:Hide()    end
    if self._statusLbl    then self._statusLbl:Hide()    end
    if self._statusFS     then self._statusFS:Hide()     end
    if self._lengthBox then self._lengthBox:Hide() end
    if self._bestBox then self._bestBox:Hide() end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end
    if self._goldGrid    then self._goldGrid:Hide()    end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIASECHO")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:Hide()
    end
    self:RefreshConfiguration()
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "ARCADIASECHO",
    label     = "Arcadia's Echo",
    renderer  = "AE_Renderer",
    engine    = "AE_Engine",
    container = "_aeContainer",
    category  = "GESCHICK",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiasEcho\\assets\\logo\\logo_arcadias_echo",
    xp        = 10,
})
