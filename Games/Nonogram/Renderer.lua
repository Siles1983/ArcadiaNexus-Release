-- Games/Nonogram/Renderer.lua

local ArcadiaNexus = _G.ArcadiaNexus
local R = {}
ArcadiaNexus.NON_Renderer = R

local CFG = {
    field_w      = 560,
    field_h      = 560,
    field_ofs_x  = 25,
    field_ofs_y  = -10,
    bg_w         = 700,
    bg_h         = 480,
    bg_ofs_x     = -20,
    bg_ofs_y     = 10,
    bg_alpha     = 1,
    border_w     = 790,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 15,
    logo_w       = 544,
    logo_h       = 163,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    chk_size     = 20,
    board_size   = 310,--Grid size
    board_hold_w = 600,
    board_hold_h = 560,
    board_ofs_x  = 0,
    board_ofs_y  = 0,
    gold_pad_left   = 90,
    gold_pad_top    = 90,
    gold_pad_right  = 6,
    gold_pad_bottom = 6,
    gold_ofs_x      = 0,
    gold_ofs_y      = 0,
    hud_puzzle_w     = 200,
    hud_puzzle_h     = 28,
    hud_puzzle_x     = -120,
    hud_puzzle_y     = 200,
    hud_puzzle_alpha = 0.75,
    hud_mode_w       = 160,
    hud_mode_h       = 28,
    hud_mode_x       = 95,
    hud_mode_y       = 200,
    hud_mode_alpha   = 0.75,
    hud_errors_w     = 160,
    hud_errors_h     = 28,
    hud_errors_x     = 0,
    hud_errors_y     = 0,
    hud_errors_alpha = 0.75,
    hud_timer_w      = 160,
    hud_timer_h      = 28,
    hud_timer_x      = 0,
    hud_timer_y      = 0,
    hud_timer_alpha  = 0.75,
    hud_score_w      = 160,
    hud_score_h      = 28,
    hud_score_x      = 95,
    hud_score_y      = 195,
    hud_score_alpha  = 0.75,
    hud_input_w      = 160,
    hud_input_h      = 28,
    hud_input_x      = 0,
    hud_input_y      = 0,
    hud_input_alpha  = 0.75,
    hud_row_gap      = 10,
    hud_row_ofs_y    = -8,
    ov_w         = 320,
    ov_h         = 200,
    ov_ofs_x     = 0,
    ov_ofs_y     = 0,
    ov_title_y   = 50,
    ov_sub_gap   = -14,
    ov_btn_gap   = -20,
    ov_btn_w     = 160,
    ov_btn_h     = 30,
}

-- State-Felder
R.frame          = nil
R.state          = "IDLE"
R._fieldFrame    = nil
R._borderFrame   = nil
R._logo          = nil
R._controlsFrame = nil
R._startBtn      = nil
R._resumeBtn     = nil
R._strictChk     = nil
R.timerFS        = nil
R.scoreFS        = nil
R.puzzleFS       = nil
R.errorsFS       = nil
R.modeFS         = nil
R.inputModeFS    = nil
R._cells         = {}
R._boardHolder   = nil
R._rowClueFS     = {}
R._colClueFS     = {}
R._cursorFrame   = nil
R._cellPool      = nil
R._clueFSPool    = nil

-- Farben
local CLR_CELL_EMPTY  = { 0.12, 0.12, 0.15, 1.00 }
local CLR_CELL_FILLED = { 0.95, 0.95, 1.00, 1.00 }
local CLR_CELL_MARKED = { 0.90, 0.20, 0.20, 0.70 }
local CLR_CURSOR      = { 1.00, 0.85, 0.00, 0.90 }
local CLR_CLUE_NORMAL = { 0.70, 0.70, 0.70, 1.00 }
local CLR_CLUE_SOLVED = { 0.20, 0.90, 0.20, 1.00 }
local CLR_GOLD        = { 1.00, 0.85, 0.10, 1.00 }
local CLR_RED         = { 0.95, 0.20, 0.20, 1.00 }
local CELL_GAP        = 2

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Nonogram.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local cell = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            cell:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, edgeSize = 1,
                insets = {left=1,right=1,top=1,bottom=1},
            })
            local markTex = cell:CreateTexture(nil, "OVERLAY")
            markTex:SetAllPoints(cell)
            markTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            markTex:Hide()
            local markFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            markFS:SetAllPoints(cell)
            markFS:SetJustifyH("CENTER")
            markFS:SetJustifyV("MIDDLE")
            markFS:SetText("x")
            markFS:Hide()
            cell._markTex = markTex
            cell._markFS  = markFS
            return cell
        end,
        onRelease = function(cell)
            cell:Hide()
            cell:ClearAllPoints()
            cell:Enable()
            cell:SetScript("OnMouseDown", nil)
            cell:SetScript("OnEnter", nil)
            cell:SetScript("OnLeave", nil)
            cell._gridR = nil
            cell._gridC = nil
            cell:SetBackdropColor(CLR_CELL_EMPTY[1], CLR_CELL_EMPTY[2], CLR_CELL_EMPTY[3], CLR_CELL_EMPTY[4])
            cell:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.80)
            if cell._markTex then cell._markTex:Hide() end
            if cell._markFS  then cell._markFS:Hide() end
            if poolParentRef then cell:SetParent(poolParentRef) end
        end,
    })
end

local function CreateClueFSPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Nonogram.ClueFS",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Frame", nil, poolParent)
            wrap:SetSize(1, 1)
            local fs = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            wrap._fs = fs
            return wrap
        end,
        onRelease = function(wrap)
            wrap:Hide()
            wrap:ClearAllPoints()
            if wrap._fs then
                wrap._fs:ClearAllPoints()
                wrap._fs:SetText("")
            end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

local ADDON_PATH = "Interface\\AddOns\\ArcadiaNexus\\"

-- ============================================================
-- REGISTRIERUNG
-- ============================================================
ArcadiaNexus.RegisterGame({
    id        = "NONOGRAM",
    label     = "Nonogram",
    category  = "RAETSEL",
    renderer  = "NON_Renderer",
    engine    = "NON_Engine",
    container = "_nonContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\Nonogram\\assets\\logo\\logo_nonogram",
    xp        = 16,
})

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateBoardArea()
    self:_CreateStatusBar()
    self:_CreateControls()
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
        outerName = "ArcadiaNexus_NON_Container",
        designW   = 600,
        designH   = 560,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._nonContainer = f

    f:EnableKeyboard(false)
    f:SetScript("OnKeyDown", function(frame, key)
        local E=ArcadiaNexus.NON_Engine
        if not E or E.state~="PLAYING" and E.state~="TUTORIAL" then frame:SetPropagateKeyboardInput(true); return end
        local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus and focus~=frame then frame:SetPropagateKeyboardInput(true); return end
        local recognized=key=="UP" or key=="DOWN" or key=="LEFT" or key=="RIGHT" or key=="SPACE" or key=="M" or key=="TAB"
        frame:SetPropagateKeyboardInput(not recognized)
        if     key == "UP"    then E:MoveCursor(-1,  0)
        elseif key == "DOWN"  then E:MoveCursor( 1,  0)
        elseif key == "LEFT"  then E:MoveCursor( 0, -1)
        elseif key == "RIGHT" then E:MoveCursor( 0,  1)
        elseif key == "SPACE" then E:HandleKeyAction("FILL")
        elseif key == "M"     then E:HandleKeyAction("MARK")
        elseif key == "TAB"   then E:HandleKeyAction("TOGGLE_MODE")
        end
    end)

    f:SetScript("OnHide", function()
        local E=ArcadiaNexus.NON_Engine
        ArcadiaNexus.GameSession:HandleRendererHide("NONOGRAM", ArcadiaNexus.NON_Engine, function(E)
            E:SaveAndPause()
        end)
        if not E._sessionId and E.state~="IDLE" then E:StopGame() end
        R:EnterIdleState()
    end)
end

-- ============================================================
-- FIELD FRAME
-- ============================================================
function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local ff = CreateFrame("Frame", nil, self._canvas)
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = ff
end

-- ============================================================
-- BACKGROUND
-- ============================================================
function R:_CreateBackground()
    if not self._fieldFrame then return end
    local bg = self._fieldFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(CFG.bg_w, CFG.bg_h)
    bg:SetPoint("CENTER", self._fieldFrame, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    bg:SetTexture(ADDON_PATH .. "Games\\Nonogram\\assets\\background\\bg_nonogram")
    bg:SetAlpha(CFG.bg_alpha)
end

-- ============================================================
-- BORDER FRAME
-- ============================================================
function R:_CreateBorderFrame()
    if self._borderFrame then return end
    local bf = CreateFrame("Frame", nil, self._canvas)
    bf:SetSize(CFG.border_w, CFG.border_h)
    bf:SetPoint("CENTER", self._canvas, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    bf:SetFrameLevel(self._fieldFrame:GetFrameLevel() + 10)
    local tex = bf:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(bf)
    tex:SetTexture(ADDON_PATH .. "Games\\Nonogram\\assets\\border\\border_nonogram")
    self._borderFrame = bf
end

-- ============================================================
-- LOGO
-- ============================================================
function R:_CreateLogo()
    if self._logo then return end
    local UI = ArcadiaNexus.UI
    self._logo = UI.CreateGameLogo(
        self._fieldFrame,
        ADDON_PATH .. "Games\\Nonogram\\assets\\logo\\logo_nonogram",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- BOARD-BEREICH
-- ============================================================
function R:_CreateBoardArea()
    if self._boardHolder then return end
    local holder = CreateFrame("Frame", nil, self._fieldFrame)
    holder:SetSize(CFG.board_hold_w, CFG.board_hold_h)
    holder:SetPoint("CENTER", self._canvas, "CENTER", CFG.board_ofs_x or 0, CFG.board_ofs_y or 0)
    self._boardHolder = holder
    holder:Hide()

    local goldAnchor = CreateFrame("Frame", nil, holder)
    goldAnchor:SetSize(1, 1)
    goldAnchor:SetPoint("CENTER", holder, "CENTER", 0, 0)
    self._goldAnchor = goldAnchor

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, goldAnchor)
    end
end

-- ============================================================
-- STATUS-BAR
-- ============================================================
function R:_CreateStatusBar()
    if self._puzzleBox then return end
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._puzzleBox, self.puzzleFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_puzzle_w, h = CFG.hud_puzzle_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_puzzle_x, y = CFG.hud_puzzle_y,
        alpha = CFG.hud_puzzle_alpha, shown = false,
    })
    self._modeBox, self.modeFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_mode_w, h = CFG.hud_mode_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_mode_x, y = CFG.hud_mode_y,
        alpha = CFG.hud_mode_alpha, shown = false,
    })
    self._errorsBox, self.errorsFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_errors_w, h = CFG.hud_errors_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_errors_x, y = CFG.hud_errors_y,
        alpha = CFG.hud_errors_alpha, shown = false,
    })
    self._timerBox, self.timerFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_timer_w, h = CFG.hud_timer_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_timer_x, y = CFG.hud_timer_y,
        alpha = CFG.hud_timer_alpha, shown = false,
    })
    self._scoreBox, self.scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha, shown = false,
    })
    self._inputBox, self.inputModeFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_input_w, h = CFG.hud_input_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_input_x, y = CFG.hud_input_y,
        alpha = CFG.hud_input_alpha, shown = false,
    })
end

function R:_SetHudShown(shown)
    local boxes = {
        self._puzzleBox, self._modeBox, self._errorsBox,
        self._timerBox, self._scoreBox, self._inputBox, self._goldGrid,
    }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

-- ============================================================
-- CONTROLS – CreateGameControlsBar "wide"
-- ============================================================
function R:_CreateControls()
    if self._controlsFrame then return end
    local L  = ArcadiaNexus.GetLocaleTable("NONOGRAM")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.NON_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Segment 1: Dropdown Schwierigkeit (x = -195)
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local diffOptions = {
        { label = L["diff_easy"]   or "Einfach", key = "easy"   },
        { label = L["diff_normal"] or "Normal",  key = "normal" },
        { label = L["diff_hard"]   or "Schwer",  key = "hard"   },
    }
    self._diffDropdown=UI.CreateSimpleDropdown(ddAnchor, 0, 0, CFG.dd_w, "",
        diffOptions,
        function()
            local gs=ArcadiaNexus.NON_Engine._gameState
            return gs and gs.difficulty or S and S:Get("difficulty") or "easy"
        end,
        function(val)
            if S then S:Set("difficulty", val) end
        end
    )

    -- Segment 2: Start/Beenden Toggle-Button (x = 0)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E=ArcadiaNexus.NON_Engine
        if E.state=="IDLE" or E.state=="SLOT_MENU" then E:ShowSlots() else E:SaveAndPause() end
    end)
    self._startBtn = startBtn

    -- Segment 3: Weiterspielen/Neues Puzzle Toggle-Button (x = +170)
    local resumeBtn = UI.CreateArcadiaButton(cf, L["btn_resume"] or "Weiterspielen", CFG.btn_w, CFG.btn_h)
    resumeBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    resumeBtn:SetScript("OnClick", function() ArcadiaNexus.NON_Engine:StartTutorial() end)
    resumeBtn:Hide()
    self._resumeBtn = resumeBtn

    -- Segment 4: Strenger Modus Checkbox
    local chkHolder, chk = UI.CreateBarCheckbox(cf, L["mode_strict"] or "Streng", { w = 120, h = 36, size = CFG.chk_size })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)
    chk:SetScript("OnShow", function()
        chk:SetChecked(S and (S:Get("defaultMode") == "strict") or false)
    end)
    chk:SetScript("OnClick", function()
        local val = chk:GetChecked() and "strict" or "free"
        if S then S:Set("defaultMode", val) end
    end)
    self._strictChk = chk
end

-- ============================================================
-- TOGGLE-BUTTON LABELS
-- ============================================================
function R:_UpdateControlLabels()
    local loc=ArcadiaNexus.GetLocaleTable("NONOGRAM"); local E=ArcadiaNexus.NON_Engine
    local locked=E:IsConfigLocked()
    if self._startBtn then self._startBtn:SetLabel(locked and loc.btn_stop or loc.btn_start) end
    if self._resumeBtn then self._resumeBtn:SetLabel(loc.btn_learn); self._resumeBtn:SetEnabled(E.state~="RESULT_PENDING"); self._resumeBtn:Show() end
    if self._diffDropdown then self._diffDropdown:SetEnabled(not locked); self._diffDropdown:RefreshDisplay() end
    if self._strictChk then self._strictChk:SetEnabled(not locked); local gs=E._gameState; self._strictChk:SetChecked((gs and gs.mode or ArcadiaNexus.NON_Settings:Get("defaultMode"))=="strict") end
end

-- ============================================================
-- BOARD AUFBAUEN
-- ============================================================
function R:_EnsureBoardPools()
    if not self._cellPool then self._cellPool = CreateCellPool() end
    if not self._clueFSPool then self._clueFSPool = CreateClueFSPool() end
end

function R:BuildBoard(gs)
    self:_ClearBoard()
    self:_EnsureBoardPools()
    local size   = gs.gridSize
    local gap    = CELL_GAP
    local cellSz = math.floor((CFG.board_size - (size - 1) * gap) / size)
    local holder = self._boardHolder
    local half   = CFG.board_size / 2

    self._cells = {}
    for r = 1, size do
        self._cells[r] = {}
        for c = 1, size do
            local px = -half + (c-1) * (cellSz + gap)
            local py = -( (r-1) * (cellSz + gap) )

            local cell = self._cellPool:Acquire({})
            cell:SetParent(holder)
            cell:SetSize(cellSz, cellSz)
            cell:SetPoint("TOPLEFT", holder, "TOP", px, py)
            cell:SetBackdropColor(CLR_CELL_EMPTY[1], CLR_CELL_EMPTY[2], CLR_CELL_EMPTY[3], CLR_CELL_EMPTY[4])
            cell:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.80)
            cell._markTex:SetVertexColor(CLR_CELL_MARKED[1], CLR_CELL_MARKED[2], CLR_CELL_MARKED[3], CLR_CELL_MARKED[4])
            cell._markTex:Hide()
            cell._markFS:SetTextColor(1, 1, 1, 1)
            cell._markFS:Hide()

            cell._gridR = r
            cell._gridC = c
            cell:SetScript("OnMouseDown", function(s, btn)
                if btn == "LeftButton" then
                    ArcadiaNexus.NON_Engine:HandleClick(s._gridR, s._gridC, "PRIMARY")
                elseif btn == "RightButton" then
                    ArcadiaNexus.NON_Engine:HandleClick(s._gridR, s._gridC, "MARK")
                end
            end)
            cell:SetScript("OnEnter", function(s)
                local E=ArcadiaNexus.NON_Engine
                if E.state=="PLAYING" or E.state=="TUTORIAL" then E._gameState.cursorR=s._gridR; E._gameState.cursorC=s._gridC; R:UpdateCursor(E._gameState) end
                R:ShowClueTooltip(s)
            end)
            cell:SetScript("OnLeave", function(s)
                GameTooltip:Hide()
            end)
            cell:Enable()
            cell:Show()

            self._cells[r][c] = { frame=cell, markTex=cell._markTex, markFS=cell._markFS }
        end
    end

    -- Cursor
    if not self._cursorFrame then
        self._cursorFrame = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        self._cursorFrame:SetFrameLevel(15)
        self._cursorFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile=false, edgeSize=2,
            insets={left=0,right=0,top=0,bottom=0},
        })
        self._cursorFrame:SetBackdropColor(0,0,0,0)
        self._cursorFrame:SetBackdropBorderColor(CLR_CURSOR[1], CLR_CURSOR[2], CLR_CURSOR[3], CLR_CURSOR[4])
    end
    self._cursorFrame:SetSize(cellSz + 4, cellSz + 4)

    -- Zeilen-Clues
    self._rowClueFS = {}
    for r = 1, size do
        local refCell = self._cells[r][1].frame
        local clueWrap = self._clueFSPool:Acquire({})
        clueWrap:SetParent(holder)
        local fs = clueWrap._fs
        fs:SetPoint("RIGHT", refCell, "LEFT", -4, 0)
        fs:SetJustifyH("RIGHT")
        fs:SetTextColor(CLR_CLUE_NORMAL[1], CLR_CLUE_NORMAL[2], CLR_CLUE_NORMAL[3])
        if gs.rowClues[r] then
            fs:SetText(table.concat(gs.rowClues[r], " "))
        else
            fs:SetText("")
        end
        clueWrap:Show()
        self._rowClueFS[r] = fs
    end

    -- Spalten-Clues
    self._colClueFS = {}
    for c = 1, size do
        local refCell = self._cells[1][c].frame
        local clueWrap = self._clueFSPool:Acquire({})
        clueWrap:SetParent(holder)
        local fs = clueWrap._fs
        fs:SetPoint("BOTTOM", refCell, "TOP", 0, 4)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(CLR_CLUE_NORMAL[1], CLR_CLUE_NORMAL[2], CLR_CLUE_NORMAL[3])
        if gs.colClues[c] then
            fs:SetText(table.concat(gs.colClues[c], "\n"))
        else
            fs:SetText("")
        end
        clueWrap:Show()
        self._colClueFS[c] = fs
    end

    holder:Show()
    self:_LayoutBlock(gs,cellSz,gap)
    self:UpdateBoard(gs)

    local gridPx = size * cellSz + (size - 1) * gap
    local first  = self._cells[1] and self._cells[1][1] and self._cells[1][1].frame
    local ga     = self._goldAnchor
    if first and ga then
        ga:ClearAllPoints()
        ga:SetSize(
            gridPx + self._hintLeft + CFG.gold_pad_right,
            gridPx + self._hintTop + CFG.gold_pad_bottom)
        ga:SetPoint("TOPLEFT", first, "TOPLEFT",
            -self._hintLeft + (CFG.gold_ofs_x or 0),
            self._hintTop + (CFG.gold_ofs_y or 0))
        ga:Show()
        local UI = ArcadiaNexus.UI
        if self._goldGrid and UI and UI.FitGoldGridFrame then
            UI.FitGoldGridFrame(self._goldGrid, ga)
        end
    end
end

function R:_ClearBoard()
    if self._cellPool then self._cellPool:ReleaseAll() end
    if self._clueFSPool then self._clueFSPool:ReleaseAll() end
    self._cells       = {}
    self._rowClueFS   = {}
    self._colClueFS   = {}
    if self._cursorFrame then self._cursorFrame:Hide() end
    if self._boardHolder then self._boardHolder:Hide() end
end

-- ============================================================
-- BOARD UPDATE
-- ============================================================
function R:UpdateBoard(gs)
    if not gs then return end
    local Logic = ArcadiaNexus.NON_Logic
    if not Logic then return end

    local rowSolved, colSolved = Logic:CalcSolved(gs)

    for r = 1, gs.gridSize do
        for c = 1, gs.gridSize do
            local cellData = self._cells[r] and self._cells[r][c]
            if cellData then
                local cell    = cellData.frame
                local markTex = cellData.markTex
                local markFS  = cellData.markFS
                local val     = gs.grid[r][c]

                if val == Logic.CELL_FILLED then
                    cell:SetBackdropColor(CLR_CELL_FILLED[1], CLR_CELL_FILLED[2], CLR_CELL_FILLED[3], CLR_CELL_FILLED[4])
                    markTex:Hide(); markFS:Hide()
                elseif val == Logic.CELL_MARKED then
                    cell:SetBackdropColor(CLR_CELL_EMPTY[1], CLR_CELL_EMPTY[2], CLR_CELL_EMPTY[3], CLR_CELL_EMPTY[4])
                    markTex:Show(); markFS:Show()
                else
                    cell:SetBackdropColor(CLR_CELL_EMPTY[1], CLR_CELL_EMPTY[2], CLR_CELL_EMPTY[3], CLR_CELL_EMPTY[4])
                    markTex:Hide(); markFS:Hide()
                end
            end
        end
    end

    for r = 1, gs.gridSize do
        local fs = self._rowClueFS[r]
        if fs then
            if rowSolved and rowSolved[r] then
                fs:SetTextColor(CLR_CLUE_SOLVED[1], CLR_CLUE_SOLVED[2], CLR_CLUE_SOLVED[3])
            else
                fs:SetTextColor(CLR_CLUE_NORMAL[1], CLR_CLUE_NORMAL[2], CLR_CLUE_NORMAL[3])
            end
        end
    end
    for c = 1, gs.gridSize do
        local fs = self._colClueFS[c]
        if fs then
            if colSolved and colSolved[c] then
                fs:SetTextColor(CLR_CLUE_SOLVED[1], CLR_CLUE_SOLVED[2], CLR_CLUE_SOLVED[3])
            else
                fs:SetTextColor(CLR_CLUE_NORMAL[1], CLR_CLUE_NORMAL[2], CLR_CLUE_NORMAL[3])
            end
        end
    end

    self:UpdateCursor(gs)
end

-- ============================================================
-- CURSOR UPDATE
-- ============================================================
function R:UpdateCursor(gs)
    if not gs or not self._cursorFrame then return end
    local cellData = self._cells[gs.cursorR] and self._cells[gs.cursorR][gs.cursorC]
    if not cellData then return end
    self._cursorFrame:ClearAllPoints()
    self._cursorFrame:SetPoint("CENTER", cellData.frame, "CENTER", 0, 0)
    self._cursorFrame:Show()
    self:_HighlightLines(gs)
end

-- ============================================================
-- HUD UPDATE
-- ============================================================
function R:UpdateHUD(gs)
    if not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("NONOGRAM")

    if self.timerFS then
        self.timerFS:SetText(string.format("%s: %s",
            L["lbl_timer"] or "Zeit",
            ArcadiaNexus.Format.SecondsMMSS(math.floor((gs.elapsedMs or 0)/1000))))
    end

    if self._scoreBox then self._scoreBox:Hide() end
    if self.puzzleFS then
        self.puzzleFS:SetText(string.format("%s: %d | %s",
            L["lbl_puzzle"] or "Puzzle", gs.puzzleIndex, rawget(L, "puzzle_name_" .. (gs.puzzleName or "")) or gs.puzzleName or ""))
        if ArcadiaNexus.NON_Engine.state=="TUTORIAL" then self.puzzleFS:SetText(L.btn_learn) end
        if self._puzzleBox and self._modeBox then
            local w=math.min(396,math.max(CFG.hud_puzzle_w,math.ceil(self.puzzleFS:GetStringWidth())+12))
            local total=w+CFG.hud_mode_w+12
            self._puzzleBox:SetWidth(w); self._puzzleBox:ClearAllPoints(); self._puzzleBox:SetPoint("CENTER",self._canvas,"CENTER",-total/2+w/2,CFG.hud_puzzle_y)
            self._modeBox:ClearAllPoints(); self._modeBox:SetPoint("CENTER",self._canvas,"CENTER",total/2-CFG.hud_mode_w/2,CFG.hud_mode_y)
        end
    end

    if self.modeFS then
        local modeLabel = gs.mode == "strict"
            and (L["mode_strict"] or "Strenger Modus")
            or  (L["mode_free"]   or "Freies Lösen")
        self.modeFS:SetText(modeLabel)
    end

    if self.errorsFS then
        if gs.mode == "strict" then
            self.errorsFS:SetText(string.format("%s: %d",L["lbl_errors"],gs.errorLimit-gs.errors))
            if self._errorsBox then self._errorsBox:Show() else self.errorsFS:Show() end
        else
            if self._errorsBox then self._errorsBox:Hide() else self.errorsFS:Hide() end
        end
    end
    self:_PlaceHudRow(gs)
end

function R:UpdateInputModeLabel(gs)
    if not gs or not self.inputModeFS then return end
    local L = ArcadiaNexus.GetLocaleTable("NONOGRAM")
    if gs.inputMode == "fill" then
        self.inputModeFS:SetText("|cff00ff00" .. (L["lbl_input_fill"] or "Füllen") .. "|r [Tab]")
    else
        self.inputModeFS:SetText("|cffff4444" .. (L["lbl_input_mark"] or "Markieren") .. "|r [Tab]")
    end
end

-- ============================================================
-- ZUSTANDS-UEBERGAENGE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:_HidePlayingElements()
    self:_ClearBoard()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logo   then self._logo:Show()   end

    if self._slotMenu then self._slotMenu:Hide() end
    if self._tutorialHelp then self._tutorialHelp:Hide() end
    local S = ArcadiaNexus.NON_Settings
    if self._strictChk and S then
        self._strictChk:SetChecked(S:Get("defaultMode") == "strict")
    end

    self:_UpdateControlLabels()
end

function R:ShowPlaying(gs)
    self.state = "PLAYING"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logo   then self._logo:Hide()   end
    self:_SetHudShown(true)

    if self.frame then self.frame:EnableKeyboard(true) end

    self:BuildBoard(gs)
    self:UpdateHUD(gs)
    self:UpdateInputModeLabel(gs)
    self:_UpdateControlLabels()
end

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================
function R:_HidePlayingElements()
    self:_SetHudShown(false)
    if self.frame       then self.frame:EnableKeyboard(false) end
end
-- Grid+clues centered on the holder; HUD row sits under the measured block.
function R:_LayoutBlock(gs, cellSz, gap)
    local left, top = 0, 0
    for _, fs in ipairs(self._rowClueFS) do left = math.max(left, fs:GetStringWidth()) end
    for _, fs in ipairs(self._colClueFS) do top = math.max(top, fs:GetStringHeight()) end
    left = math.ceil(left) + 8
    top = math.ceil(top) + 8
    self._hintLeft, self._hintTop = left, top
    local grid = gs.gridSize * cellSz + (gs.gridSize - 1) * gap
    local blockW, blockH = grid + left, grid + top
    local firstX = -blockW / 2 + left
    local firstY = blockH / 2 - top
    for r = 1, gs.gridSize do
        for c = 1, gs.gridSize do
            local f = self._cells[r][c].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", self._boardHolder, "CENTER",
                firstX + (c - 1) * (cellSz + gap),
                firstY - (r - 1) * (cellSz + gap))
        end
    end
    if not self._quietBlock then
        self._quietBlock = self._boardHolder:CreateTexture(nil, "BACKGROUND")
        self._quietBlock:SetColorTexture(0, 0, 0, 0.72)
    end
    self._quietBlock:ClearAllPoints()
    self._quietBlock:SetPoint("TOPLEFT", self._cells[1][1].frame, "TOPLEFT", -left, top)
    self._quietBlock:SetSize(blockW + 6, blockH + 6)
    self._quietBlock:Show()
    self._separators = self._separators or {}
    for _, t in ipairs(self._separators) do t:Hide() end
    local count = 0
    for i = 5, gs.gridSize - 1, 5 do
        for axis = 1, 2 do
            count = count + 1
            local t = self._separators[count]
            if not t then
                t = self._boardHolder:CreateTexture(nil, "OVERLAY")
                t:SetColorTexture(0.85, 0.68, 0.2, 0.9)
                self._separators[count] = t
            end
            t:ClearAllPoints()
            if axis == 1 then
                t:SetPoint("TOPLEFT", self._cells[1][i].frame, "TOPRIGHT", 1, 0)
                t:SetSize(1, grid)
            else
                t:SetPoint("TOPLEFT", self._cells[i][1].frame, "BOTTOMLEFT", 0, -1)
                t:SetSize(grid, 1)
            end
            t:Show()
        end
    end
    self._layout = {
        left = left, top = top, grid = grid,
        width = blockW + 6, height = blockH + 6,
        firstY = firstY, bottomY = firstY - grid,
    }
    self:_PlaceHudRow(gs)
end

function R:_PlaceHudRow(gs)
    local timer, errors, input = self._timerBox, self._errorsBox, self._inputBox
    if not timer or not input then return end
    local anchor = self._quietBlock or self._boardHolder
    local gap = CFG.hud_row_gap or 10
    local ofsY = CFG.hud_row_ofs_y or -8
    local items = {
        { box = timer, w = CFG.hud_timer_w, h = CFG.hud_timer_h, x = CFG.hud_timer_x, y = CFG.hud_timer_y },
    }
    if errors and (not gs or gs.mode == "strict") then
        items[#items + 1] = {
            box = errors, w = CFG.hud_errors_w, h = CFG.hud_errors_h,
            x = CFG.hud_errors_x, y = CFG.hud_errors_y,
        }
    end
    items[#items + 1] = {
        box = input, w = CFG.hud_input_w, h = CFG.hud_input_h,
        x = CFG.hud_input_x, y = CFG.hud_input_y,
    }
    local total = 0
    for i = 1, #items do
        total = total + items[i].w
        if i > 1 then total = total + gap end
    end
    local x = -total / 2
    for i = 1, #items do
        local it = items[i]
        it.box:ClearAllPoints()
        it.box:SetSize(it.w, it.h)
        it.box:SetPoint("TOP", anchor, "BOTTOM", x + it.w / 2 + (it.x or 0), ofsY + (it.y or 0))
        x = x + it.w + gap
    end
end
function R:_HighlightLines(gs)
    for r,row in ipairs(self._cells) do for c,data in ipairs(row) do
        if r==gs.cursorR or c==gs.cursorC then data.frame:SetBackdropBorderColor(1,.8,.25,.95)
        else data.frame:SetBackdropBorderColor(.30,.30,.35,.8) end
    end end
    self._lineFocus=self._lineFocus or {}
    for axis=1,2 do
        local t=self._lineFocus[axis]
        if not t then t=self._boardHolder:CreateTexture(nil,'BACKGROUND'); t:SetColorTexture(.8,.65,.2,.20); self._lineFocus[axis]=t end
        t:ClearAllPoints()
        if axis==1 then t:SetPoint('TOPLEFT',self._cells[gs.cursorR][1].frame,'TOPLEFT',-self._hintLeft,0); t:SetSize(self._layout.grid+self._hintLeft,self._cells[1][1].frame:GetHeight())
        else t:SetPoint('TOPLEFT',self._cells[1][gs.cursorC].frame,'TOPLEFT',0,self._hintTop); t:SetSize(self._cells[1][1].frame:GetWidth(),self._layout.grid+self._hintTop) end t:Show()
    end
end
function R:ShowClueTooltip(cell)
    local gs=ArcadiaNexus.NON_Engine._gameState; if not gs then return end
    local loc=ArcadiaNexus.GetLocaleTable('NONOGRAM')
    GameTooltip:SetOwner(cell,'ANCHOR_RIGHT'); GameTooltip:SetText(loc.clue_title)
    GameTooltip:AddLine(loc.clue_row..': '..table.concat(gs.rowClues[cell._gridR],' '),1,1,1,true)
    GameTooltip:AddLine(loc.clue_col..': '..table.concat(gs.colClues[cell._gridC],' '),1,1,1,true); GameTooltip:Show()
end
function R:ShowSlotMenu()
    local A=ArcadiaNexus; local S=A.NON_Settings; local loc=A.GetLocaleTable('NONOGRAM')
    if self._logo then self._logo:Hide() end
    if not self._slotMenu then self._slotMenu=A.UI.CreateSaveSlotMenu({parent=self._canvas,maxSlots=3,L=loc,
        loadSlot=function(slot)
            local raw=S:LoadSlot(slot); if not raw then return end
            if type(raw)~='table' then return {invalid=true} end local copy=A.NON_Logic:Copy(raw)
            if not A.NON_Logic:Int(copy.timestamp,2147483647) then copy.timestamp=nil end return copy
        end,
        deleteSlot=function(slot) S:DeleteSlot(slot) end,
        isPaused=function(save) return not save.completed end,canContinue=function(save) return not save.completed end,
        formatInfo=function(save)
            local gs=save.gameState
            if type(gs)~='table' or not A.NON_Logic.DiffConfig[gs.difficulty] or gs.mode~='free' and gs.mode~='strict' then return loc.msg_invalid_save end
            return loc['diff_'..gs.difficulty]..' / '..loc['mode_'..gs.mode]
        end,
        formatPaused=function(save) local gs=save.gameState; return type(gs)=='table' and A.NON_Logic:Int(gs.elapsedMs) and A.Format.SecondsMMSS(math.floor(gs.elapsedMs/1000)) or loc.msg_invalid_save end,
        onNewGame=function(slot) A.NON_Engine:StartGame({slot=slot,action='new'}) end,
        onContinue=function(slot) A.NON_Engine:StartGame({slot=slot,action='continue'}) end,
        onCancel=function() A.NON_Engine:StopGame() end}) end
    self._slotMenu:Show()
end
function R:HideSlotMenu() if self._slotMenu then self._slotMenu:Hide() end if self._feedback then self._feedback:Hide() end end
function R:ShowFeedback(key)
    if not self._feedback then self._feedback=self._canvas:CreateFontString(nil,'OVERLAY','GameFontNormal'); self._feedback:SetPoint('TOP',self._canvas,'TOP',0,-50); self._feedback:SetSize(520,48) end
    self._feedback:SetText(ArcadiaNexus.GetLocaleTable('NONOGRAM')[key]); self._feedback:Show()
end
function R:ShowTutorial()
    if not self._tutorialHelp then self._tutorialHelp=self._canvas:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); self._tutorialHelp:SetPoint('BOTTOM',self._canvas,'BOTTOM',0,70); self._tutorialHelp:SetSize(550,74) end
    self._tutorialHelp:SetText(ArcadiaNexus.GetLocaleTable('NONOGRAM').tutorial_text); self._tutorialHelp:Show()
end
function R:ShowTutorialDone()
    local A=ArcadiaNexus; local loc=A.GetLocaleTable('NONOGRAM'); local E=A.NON_Engine
    self:_UpdateControlLabels(); if self.frame then self.frame:EnableKeyboard(false) end
    A.UI.ShowArcadeResult(self._fieldFrame,{title=loc.tutorial_done,subtitle=loc.tutorial_unrated,result='WIN',xp=0,hideHighscore=true,L=loc,
        onRetry=function() E:StartTutorial() end,onExit=function() E:StopGame() end,isCurrent=function() return E.state=='TUTORIAL_DONE' end})
end
function R:ShowPending(data)
    local A=ArcadiaNexus; local loc=A.GetLocaleTable('NONOGRAM'); local E=A.NON_Engine
    self:_UpdateControlLabels(); if self.frame then self.frame:EnableKeyboard(false) end
    A.UI.ShowArcadeResult(self._fieldFrame,{title=loc.msg_pending,result='LOSS',xp=0,hideHighscore=true,L=loc,
        onRetry=function() E:RetryResult() end,onExit=function() E:StopGame() end,isCurrent=function() return E._runId==data.runId and E.state=='RESULT_PENDING' end})
end
function R:ShowResult(data)
    local A=ArcadiaNexus; local loc=A.GetLocaleTable('NONOGRAM'); local E=A.NON_Engine
    self.state=E.state; self:_UpdateControlLabels(); if self.frame then self.frame:EnableKeyboard(false) end
    local lines={loc['mode_'..data.stats.mode],string.format(loc.result_time,A.Format.SecondsMMSS(math.floor(data.stats.elapsedMs/1000)))}
    local best=A.NON_Settings:GetBest(data.gameState.puzzleId,data.stats.mode)
    if best then lines[#lines+1]=string.format(loc.result_best,A.Format.SecondsMMSS(math.floor(best.elapsedMs/1000))) end
    A.UI.ShowArcadeResult(self._fieldFrame,{gameId='NONOGRAM',difficulty=data.difficulty,result=data.result,score=data.score,xp=data.awardedXP,
        gold=data.awardedGold,newHighscore=data.newHighscore,lines=lines,L=loc,
        isCurrent=function() return E._runId==data.runId and (E.state=='WIN' or E.state=='GAMEOVER') end,
        buttons={{label=loc.btn_retry,onClick=function() E:RetryPuzzle() end},{label=loc.btn_next,onClick=function() E:RetryPuzzle(true) end},{label=loc.btn_stop,onClick=function() E:StopGame() end}}})
end
