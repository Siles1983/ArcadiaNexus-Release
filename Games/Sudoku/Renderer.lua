--[[
    ArcadiaNexus
    Games/Sudoku/Renderer.lua
    Version: 2.0.0

    Layout-Strategie (Blueprint: 2048 v2.1):
      - Panel-großer Lifecycle-Container mit zentriertem 600x498 Design-Canvas
      - Alle Elemente per CENTER-Ankern positioniert
      - Spielfeld oben-mittig, Controls unten in fester Leiste
      - Border einmalig als OVERLAY-Textur über dem Spielfeld
      - Logo via UI.CreateGameLogo
      - Schwierigkeit via Dropdown (linkes Segment der Controls-Leiste)
      - Start/Beenden: Dual-Label-Button (mittleres Segment)
      - Neues Puzzle: Button rechts (nur im PLAYING-Zustand sichtbar)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SDK_Renderer = {}
local Renderer = ArcadiaNexus.SDK_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_w      = 400,
    field_h      = 400,
    field_ofs_x  = 0,
    field_ofs_y  = 5,
    border_w     = 790,
    border_h     = 545,
    border_ofs_x = -1,
    border_ofs_y = 11,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,
    logo_w       = 443,
    logo_h       = 431,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    thin_gap     = 1,
    thick_gap    = 3,
    hud_score_w     = 160,
    hud_score_h     = 28,
    hud_score_x     = -125,
    hud_score_y     = 220,
    hud_score_alpha = 0.75,
    hud_best_w      = 160,
    hud_best_h      = 28,
    hud_best_x      = 125,
    hud_best_y      = 220,
    hud_best_alpha  = 0.75,
}
-- Abgeleitete Grid-Konstanten (benötigen CFG.field_w / thin_gap / thick_gap)
CFG.cell_size = math.floor((CFG.field_w - 8 * CFG.thin_gap - 2 * (CFG.thick_gap - CFG.thin_gap)) / 9)

local function cellOffset(idx)
    local block = math.floor((idx - 1) / 3)
    return (idx - 1) * CFG.cell_size
        + (idx - 1) * CFG.thin_gap
        + block * (CFG.thick_gap - CFG.thin_gap)
end

CFG.grid_px = cellOffset(9) + CFG.cell_size


-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld

-- Border über dem Spielfeld

-- Logo im Spielfeld (IDLE-Zustand)

-- ============================================================
-- FARBEN
-- ============================================================

-- Block-Hintergründe
local BLOCK_ODD    = { 0.10, 0.10, 0.10, 1 }
local BLOCK_EVEN   = { 0.00, 0.00, 0.00, 1 }

-- Zell-Zustände (NormalTexture-Farbe)
local CLR_FIXED    = { 0.14, 0.13, 0.18, 1 }
local CLR_EMPTY    = { 0.12, 0.14, 0.20, 1 }
local CLR_PLAYER   = { 0.10, 0.18, 0.28, 1 }
local CLR_ERROR    = { 0.30, 0.06, 0.06, 1 }
local CLR_HIGHLIGHT= { 0.35, 0.32, 0.04, 1 }
local CLR_SELECTED = { 0.08, 0.32, 0.12, 1 }

-- Text-Farben
local TXT_FIXED    = { 1.00, 0.82, 0.00, 1 }
local TXT_PLAYER   = { 0.50, 0.80, 1.00, 1 }
local TXT_ERROR    = { 1.00, 0.30, 0.30, 1 }

-- Gitter-Separator-Farben
local SEP_THICK    = { 0.70, 0.60, 0.35, 1 }

-- ============================================================
-- GRID-KONSTANTEN
-- ============================================================

-- ============================================================
-- STATE
-- ============================================================

Renderer.frame          = nil
Renderer._canvas        = nil
Renderer._controlsFrame = nil
Renderer._fieldFrame    = nil
Renderer._borderFrame   = nil
Renderer._borderTex     = nil
Renderer._logoTex       = nil
Renderer.state          = "IDLE"
Renderer.selectedDiff   = "normal"

Renderer.cells          = {}
Renderer.blockFrames    = {}
Renderer.gridHolder     = nil

Renderer.popup          = nil
Renderer.popupOpen      = false
Renderer.popupTargetR   = nil
Renderer.popupTargetC   = nil

Renderer._startBtn      = nil
Renderer._newPuzzleBtn  = nil
Renderer._scoreBox      = nil
Renderer._bestBox       = nil
Renderer.scoreFS        = nil
Renderer.bestFS         = nil
Renderer._goldGrid      = nil

-- ============================================================
-- INIT
-- ============================================================

function Renderer:Init()
    -- selectedDiff aus Settings laden (verhindert Reset nach Reload)
    local S = ArcadiaNexus.SDK_Settings
    self.selectedDiff = (S and S:Get("difficulty")) or "normal"

    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateHud()
    self:_CreateGrid()
    self:_CreatePopup()
    self:_CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine
    Engine:On("SDK_GAME_STARTED",  function(s) Renderer:OnGameStarted(s)  end)
    Engine:On("SDK_CELL_SELECTED", function(s) Renderer:OnCellSelected(s) end)
    Engine:On("SDK_BOARD_UPDATED", function(s) Renderer:OnBoardUpdated(s) end)
    Engine:On("SDK_CELL_CLEARED",  function(s) Renderer:OnBoardUpdated(s) end)
    Engine:On("SDK_GAME_COMPLETE", function(s) Renderer:OnGameComplete(s) end)
    Engine:On("SDK_GAME_STOPPED",  function()  Renderer:EnterIdleState()  end)
end

-- ============================================================
-- FRAME-AUFBAU
-- ============================================================

function Renderer:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_SDK_Container",
        designW   = 600,
        designH   = 498,
    })
    local container = viewport.outer
    container:Hide()
    self.frame = container
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._sdkContainer = container end

    container:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("SUDOKU", ArcadiaNexus.SDK_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

function Renderer:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0, 0, 0, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function Renderer:_CreateBackground()
    local ff = self._fieldFrame
    if not ff then return end
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\Sudoku\\assets\\background\\background_sudoku")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function Renderer:_CreateBorderTex()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\Sudoku\\assets\\border\\border_sudoku")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

function Renderer:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        "Interface\\AddOns\\ArcadiaNexus\\Games\\Sudoku\\assets\\logo\\logo_sudoku",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- GRID AUFBAUEN (einmalig)
-- ============================================================

function Renderer:_CreateGrid()
    if #self.cells > 0 then return end
    local parent = self._fieldFrame

    -- Äußerer Grid-Container — zentriert im _fieldFrame
    local gridHolder = CreateFrame("Frame", nil, parent)
    gridHolder:SetSize(CFG.grid_px + CFG.thick_gap * 2, CFG.grid_px + CFG.thick_gap * 2)
    gridHolder:SetPoint("CENTER", parent, "CENTER", 0, 0)
    self.gridHolder = gridHolder

    -- Äußerer Rahmen (Gold)
    local outerBG = gridHolder:CreateTexture(nil, "BACKGROUND")
    outerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    outerBG:SetAllPoints(gridHolder)
    outerBG:SetVertexColor(SEP_THICK[1], SEP_THICK[2], SEP_THICK[3], 1)

    -- 9 Block-Hintergrund-Frames
    for block = 1, 9 do
        local br = math.floor((block - 1) / 3)
        local bc = (block - 1) % 3
        local bx = bc * (CFG.cell_size * 3 + CFG.thin_gap * 2 + CFG.thick_gap) + CFG.thick_gap
        local by = br * (CFG.cell_size * 3 + CFG.thin_gap * 2 + CFG.thick_gap) + CFG.thick_gap

        local bf = CreateFrame("Frame", nil, gridHolder)
        bf:SetSize(CFG.cell_size * 3 + CFG.thin_gap * 2, CFG.cell_size * 3 + CFG.thin_gap * 2)
        bf:SetPoint("TOPLEFT", gridHolder, "TOPLEFT", bx, -by)

        local bbg = bf:CreateTexture(nil, "BACKGROUND")
        bbg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bbg:SetAllPoints(bf)
        local col = (block % 2 == 1) and BLOCK_ODD or BLOCK_EVEN
        bbg:SetVertexColor(col[1], col[2], col[3], 1)
        self.blockFrames[block] = bf
    end

    -- 81 Zell-Buttons
    for r = 1, 9 do
        self.cells[r] = {}
        for c = 1, 9 do
            local px = cellOffset(c) + CFG.thick_gap
            local py = cellOffset(r) + CFG.thick_gap

            local tf = CreateFrame("Button", nil, gridHolder)
            tf:SetSize(CFG.cell_size, CFG.cell_size)
            tf:SetPoint("TOPLEFT", gridHolder, "TOPLEFT", px, -py)
            tf:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
            tf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            tf:EnableMouse(true)

            local bg = tf:GetNormalTexture()
            bg:SetVertexColor(CLR_EMPTY[1], CLR_EMPTY[2], CLR_EMPTY[3], 1)

            -- Highlight-Overlay
            local hlFrame = CreateFrame("Frame", nil, tf)
            hlFrame:SetAllPoints(tf)
            hlFrame:EnableMouse(false)
            hlFrame:Hide()
            hlFrame:SetFrameLevel(tf:GetFrameLevel())
            local hlTex = hlFrame:CreateTexture(nil, "OVERLAY")
            hlTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            hlTex:SetAllPoints(hlFrame)
            hlTex:SetVertexColor(CLR_HIGHLIGHT[1], CLR_HIGHLIGHT[2], CLR_HIGHLIGHT[3], 0.45)

            -- Zahlen-Label
            local lbl = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            lbl:SetAllPoints(tf)
            lbl:SetJustifyH("CENTER")
            lbl:SetJustifyV("MIDDLE")
            lbl:SetText("")

            local cr, cc = r, c
            tf:SetScript("OnClick", function(_, btn)
                if btn == "RightButton" then
                    Renderer:ClosePopup()
                    ArcadiaNexus.SDK_Engine:HandleCellRightClick(cr, cc)
                else
                    if Renderer.popupOpen and Renderer.popupTargetR == cr and Renderer.popupTargetC == cc then
                        Renderer:ClosePopup()
                    else
                        ArcadiaNexus.SDK_Engine:HandleCellClick(cr, cc)
                    end
                end
            end)

            self.cells[r][c] = {
                frame   = tf,
                bg      = bg,
                label   = lbl,
                hlFrame = hlFrame,
                hlTex   = hlTex,
            }
        end
    end

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, gridHolder)
    end
end

-- ============================================================
-- POPUP (3×3 Zahlen-Grid)
-- ============================================================

function Renderer:_CreatePopup()
    if self.popup then return end

    local PBTN = 36
    local PGAP = 2
    local PW   = 3 * PBTN + 2 * PGAP + 8
    local PH   = 3 * PBTN + 2 * PGAP + 8

    local pop = CreateFrame("Frame", "ArcadiaNexus_SDK_Popup", self._canvas, "BackdropTemplate")
    pop:SetSize(PW, PH)
    pop:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pop:SetBackdropColor(0.05, 0.05, 0.10, 0.97)
    pop:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    pop:SetFrameStrata("DIALOG")
    pop:SetFrameLevel(100)
    pop:Hide()
    pop:EnableMouse(true)

    pop.numBtns = {}
    for i = 1, 9 do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        local btn = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
        btn:SetSize(PBTN, PBTN)
        btn:SetPoint("TOPLEFT", pop, "TOPLEFT",
            4 + col * (PBTN + PGAP),
            -(4 + row * (PBTN + PGAP)))
        btn:SetText(tostring(i))
        btn:SetNormalFontObject("GameFontNormalLarge")
        local n = i
        btn:SetScript("OnClick", function()
            Renderer:ClosePopup()
            ArcadiaNexus.SDK_Engine:HandleNumberInput(n)
        end)
        pop.numBtns[i] = btn
    end

    self.popup = pop
end

local SDK_SCORE = { easy = 50, normal = 100, hard = 200 }

function Renderer:_CreateHud()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("SUDOKU")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self.scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["hud_score"] or "Punkte") .. ": 0",
        shown = false,
    })
    self._bestBox, self.bestFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["hud_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })
end

function Renderer:_UpdateHud(state)
    local L = ArcadiaNexus.GetLocaleTable("SUDOKU")
    local diff = (state and state.difficulty)
        or (ArcadiaNexus.SDK_Engine and ArcadiaNexus.SDK_Engine.activeConfig and ArcadiaNexus.SDK_Engine.activeConfig.difficulty)
        or self.selectedDiff
        or "normal"
    local score = SDK_SCORE[diff] or 100
    if self.scoreFS then
        self.scoreFS:SetText((L["hud_score"] or "Punkte") .. ": " .. tostring(score))
    end
    local best = 0
    local SM = ArcadiaNexus.ScoreManager
    if SM and SM.GetBestScore then
        best = SM:GetBestScore("SUDOKU", diff) or 0
    end
    if self.bestFS then
        self.bestFS:SetText((L["hud_highscore"] or "Highscore") .. ": " .. tostring(best))
    end
end

function Renderer:OpenPopup(r, c)
    local cd = self.cells[r] and self.cells[r][c]
    if not cd then return end
    self.popupOpen    = true
    self.popupTargetR = r
    self.popupTargetC = c
    self.popup:ClearAllPoints()
    self.popup:SetPoint("TOPLEFT", cd.frame, "TOPRIGHT", 4, 0)
    self.popup:Show()
    self.popup:Raise()
end

function Renderer:ClosePopup()
    self.popupOpen    = false
    self.popupTargetR = nil
    self.popupTargetC = nil
    if self.popup then self.popup:Hide() end
end

-- ============================================================
-- CONTROLS (Dropdown + Buttons + Divider)
-- ============================================================

function Renderer:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("SUDOKU")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeit-Dropdown (linkes Segment)
    local S = ArcadiaNexus.SDK_Settings
    local ddOptions = {
        { key = "easy",   label = L["diff_easy"]   },
        { key = "normal", label = L["diff_normal"]  },
        { key = "hard",   label = L["diff_hard"]    },
    }

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        ddOptions,
        function()
            return (S and S:Get("difficulty")) or "normal"
        end,
        function(key)
            Renderer.selectedDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Start / Beenden Button (mittleres Segment)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Start", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        if Renderer.state == "PLAYING" then
            ArcadiaNexus.SDK_Engine:StopGame()
        else
            ArcadiaNexus.SDK_Engine:StartGame({ difficulty = Renderer.selectedDiff })
        end
    end)
    self._startBtn = startBtn

    -- Neues Puzzle Button (rechtes Segment, nur im PLAYING-Zustand)
    local newBtn = UI.CreateArcadiaButton(cf, L["btn_new_puzzle"], CFG.btn_w, CFG.btn_h)
    newBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    newBtn:SetScript("OnClick", function()
        Renderer:ClosePopup()
        ArcadiaNexus.SDK_Engine:StartGame({ difficulty = Renderer.selectedDiff })
    end)
    newBtn:Hide()
    self._newPuzzleBtn = newBtn
end

-- ============================================================
-- IDLE STATE
-- ============================================================

function Renderer:EnterIdleState()
    self.state = "IDLE"
    Renderer:ClosePopup()

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._newPuzzleBtn  then self._newPuzzleBtn:Hide() end
    if self._fieldFrame    then self._fieldFrame:SetBackdropColor(0, 0, 0, 0) end
    if self._logoTex       then self._logoTex:Show() end
    if self._borderFrame   then self._borderFrame:Show() end
    if self.gridHolder     then self.gridHolder:Hide() end
    if self._goldGrid      then self._goldGrid:Hide() end
    if self._scoreBox      then self._scoreBox:Hide() end
    if self._bestBox       then self._bestBox:Hide()  end

    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("SUDOKU")
        self._startBtn:SetLabel(L["btn_start"] or "Start")
    end

    -- Zellen leeren
    for r = 1, 9 do
        for c = 1, 9 do
            local cd = self.cells[r] and self.cells[r][c]
            if cd then
                cd.bg:SetVertexColor(CLR_EMPTY[1], CLR_EMPTY[2], CLR_EMPTY[3], 1)
                cd.label:SetText("")
                cd.hlFrame:Hide()
                cd.frame:Enable()
            end
        end
    end
end

-- ============================================================
-- RENDERBOARD
-- ============================================================

function Renderer:RenderBoard(state)
    if self._logoTex   then self._logoTex:Hide() end
    if self.gridHolder then self.gridHolder:Show() end
    self._fieldFrame:SetBackdropColor(0.07, 0.07, 0.12, 1)

    local grid   = state.grid
    local fixed  = state.fixed
    local errors = state.errors
    local selR   = state.selected and state.selected.r
    local selC   = state.selected and state.selected.c
    local hlNum  = state.highlightNum

    local hlCells = {}
    if hlNum and hlNum ~= 0 then
        local cells = ArcadiaNexus.SDK_Logic:GetHighlightCells(grid, hlNum)
        for _, pos in ipairs(cells) do
            hlCells[pos.r .. "_" .. pos.c] = true
        end
    end

    for r = 1, 9 do
        for c = 1, 9 do
            local cd        = self.cells[r][c]
            local num       = grid[r][c]
            local isFixed   = fixed[r][c]
            local isError   = errors[r][c]
            local isSelected= (r == selR and c == selC)
            local isHL      = hlCells[r .. "_" .. c]

            -- Hintergrundfarbe
            local bgCol
            if isSelected then
                bgCol = CLR_SELECTED
            elseif isError then
                bgCol = CLR_ERROR
            elseif isFixed then
                bgCol = CLR_FIXED
            elseif num ~= 0 then
                bgCol = CLR_PLAYER
            else
                bgCol = CLR_EMPTY
            end
            cd.bg:SetVertexColor(bgCol[1], bgCol[2], bgCol[3], 1)

            -- Highlight-Overlay
            if isHL and not isSelected then
                cd.hlFrame:Show()
            else
                cd.hlFrame:Hide()
            end

            -- Zahl
            if num ~= 0 then
                cd.label:SetText(tostring(num))
                if isFixed then
                    cd.label:SetTextColor(TXT_FIXED[1], TXT_FIXED[2], TXT_FIXED[3], 1)
                    cd.label:SetFont(cd.label:GetFont(), 20, "OUTLINE")
                elseif isError then
                    cd.label:SetTextColor(TXT_ERROR[1], TXT_ERROR[2], TXT_ERROR[3], 1)
                    cd.label:SetFont(cd.label:GetFont(), 20, "")
                else
                    cd.label:SetTextColor(TXT_PLAYER[1], TXT_PLAYER[2], TXT_PLAYER[3], 1)
                    cd.label:SetFont(cd.label:GetFont(), 20, "")
                end
            else
                cd.label:SetText("")
            end

            -- Fixed Cells: Klick deaktivieren
            if isFixed then
                cd.frame:Disable()
            else
                cd.frame:Enable()
            end
        end
    end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================

function Renderer:OnGameStarted(state)
    self.state = "PLAYING"
    Renderer:ClosePopup()
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._newPuzzleBtn then self._newPuzzleBtn:Show() end
    if self._startBtn     then
        local L = ArcadiaNexus.GetLocaleTable("SUDOKU")
        self._startBtn:SetLabel(L["btn_exit"])
    end
    if self._scoreBox then self._scoreBox:Show() end
    if self._bestBox  then self._bestBox:Show()  end
    if self._goldGrid then self._goldGrid:Show() end
    self:_UpdateHud(state)
    self:RenderBoard(state)
end

function Renderer:OnCellSelected(state)
    self:RenderBoard(state)
    if state.selected then
        self:OpenPopup(state.selected.r, state.selected.c)
    end
end

function Renderer:OnBoardUpdated(state)
    Renderer:ClosePopup()
    self:RenderBoard(state)
end

function Renderer:OnGameComplete(state)
    self.state = "COMPLETE"
    Renderer:ClosePopup()
    self:RenderBoard(state)
    self:_UpdateHud(state)

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("SUDOKU")
    local parent = self._fieldFrame

    UI.ShowArcadeResult(parent, {
        title      = L["result_title"],
        titleColor = { 1, 0.84, 0 },
        subtitle   = string.format(
            L["result_sub"],
            state.moves or 0,
            state.mistakes or 0,
            state.difficulty or "?"),
        gameId     = "SUDOKU",
        difficulty = state.difficulty,
        result     = "WIN",
        L          = L,
        onRetry    = function()
            ArcadiaNexus.SDK_Engine:StartGame({ difficulty = Renderer.selectedDiff })
        end,
        onExit = function()
            ArcadiaNexus.SDK_Engine:StopGame()
        end,
    })

    if self._startBtn     then
        local L2 = ArcadiaNexus.GetLocaleTable("SUDOKU")
        self._startBtn:SetLabel(L2["btn_start"] or "Start")
    end
    if self._newPuzzleBtn then self._newPuzzleBtn:Hide() end
end

-- ============================================================
-- REGISTRIERUNG
-- ============================================================

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "SUDOKU",
    label     = "Sudoku",
    renderer  = "SDK_Renderer",
    engine    = "SDK_Engine",
    container = "_sdkContainer",
    category  = "DENKSPIELE",
})
