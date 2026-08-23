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
    board_ofs_y  = -180,
    gold_pad_left   = 90,
    gold_pad_top    = 90,
    gold_pad_right  = 6,
    gold_pad_bottom = 6,
    gold_ofs_x      = 0,
    gold_ofs_y      = 0,
    hud_puzzle_w     = 200,
    hud_puzzle_h     = 28,
    hud_puzzle_x     = -120,
    hud_puzzle_y     = 225,
    hud_puzzle_alpha = 0.75,
    hud_mode_w       = 160,
    hud_mode_h       = 28,
    hud_mode_x       = 95,
    hud_mode_y       = 225,
    hud_mode_alpha   = 0.75,
    hud_errors_w     = 120,
    hud_errors_h     = 28,
    hud_errors_x     = 255,
    hud_errors_y     = -170,
    hud_errors_alpha = 0.75,
    hud_timer_w      = 200,
    hud_timer_h      = 28,
    hud_timer_x      = -120,
    hud_timer_y      = 195,
    hud_timer_alpha  = 0.75,
    hud_score_w      = 160,
    hud_score_h      = 28,
    hud_score_x      = 95,
    hud_score_y      = 195,
    hud_score_alpha  = 0.75,
    hud_input_w      = 120,
    hud_input_h      = 28,
    hud_input_x      = 255,
    hud_input_y      = -200,
    hud_input_alpha  = 0.75,
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
    f:SetScript("OnKeyDown", function(_, key)
        local E = ArcadiaNexus.NON_Engine
        if not E or E.state ~= "PLAYING" then return end
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
        ArcadiaNexus.GameSession:HandleRendererHide("NONOGRAM", ArcadiaNexus.NON_Engine, function(E)
            E:StopGame()
        end)
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
    holder:SetPoint("TOP", self._fieldFrame, "TOP", 0, CFG.board_ofs_y)
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
    UI.CreateSimpleDropdown(ddAnchor, 0, 0, CFG.dd_w, "",
        diffOptions,
        function()
            return S and S:Get("difficulty") or "easy"
        end,
        function(val)
            if S then S:Set("difficulty", val) end
        end
    )

    -- Segment 2: Start/Beenden Toggle-Button (x = 0)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.NON_Engine
        if not E then return end
        if E.state == "PLAYING" or E.state == "WIN" or E.state == "GAMEOVER" then
            E:StopGame()
            R:EnterIdleState()
        else
            local diff = S and S:Get("difficulty") or "easy"
            local mode = S and S:Get("defaultMode") or "free"
            if R._strictChk and R._strictChk:GetChecked() then
                mode = "strict"
            end
            E:StartGame(diff, mode)
        end
    end)
    self._startBtn = startBtn

    -- Segment 3: Weiterspielen/Neues Puzzle Toggle-Button (x = +170)
    local resumeBtn = UI.CreateArcadiaButton(cf, L["btn_resume"] or "Weiterspielen", CFG.btn_w, CFG.btn_h)
    resumeBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    resumeBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.NON_Engine
        if not E then return end
        if E.state == "PLAYING" then
            -- Neues Puzzle (gleiche Diff/Mode)
            local gs  = E._gameState
            local diff = gs and gs.difficulty or (S and S:Get("difficulty") or "easy")
            local mode = gs and gs.mode       or (S and S:Get("defaultMode") or "free")
            E:StartGame(diff, mode)
        elseif E.state == "WIN" or E.state == "GAMEOVER" then
            local diff = S and S:Get("difficulty") or "easy"
            local mode = S and S:Get("defaultMode") or "free"
            E:StartGame(diff, mode)
        end
    end)
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
    local L = ArcadiaNexus.GetLocaleTable("NONOGRAM")
    local E = ArcadiaNexus.NON_Engine
    if not E then return end

    if self._startBtn then
        if E.state == "PLAYING" or E.state == "WIN" or E.state == "GAMEOVER" then
            self._startBtn:SetLabel(L["btn_stop"] or "Beenden")
        else
            self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
        end
    end

    if self._resumeBtn then
        if E.state == "PLAYING" then
            self._resumeBtn:SetLabel(L["btn_new_puzzle"] or "Neues Puzzle")
            self._resumeBtn:Show()
        elseif E.state == "WIN" or E.state == "GAMEOVER" then
            self._resumeBtn:SetLabel(L["btn_resume"] or "Weiterspielen")
            self._resumeBtn:Show()
        else
            self._resumeBtn:Hide()
        end
    end
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
                    ArcadiaNexus.NON_Engine:HandleClick(s._gridR, s._gridC, "FILL")
                elseif btn == "RightButton" then
                    ArcadiaNexus.NON_Engine:HandleClick(s._gridR, s._gridC, "MARK")
                end
            end)
            cell:SetScript("OnEnter", function(s)
                s:SetBackdropBorderColor(CLR_GOLD[1], CLR_GOLD[2], CLR_GOLD[3], 0.6)
            end)
            cell:SetScript("OnLeave", function(s)
                s:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.80)
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
    self:UpdateBoard(gs)

    local gridPx = size * cellSz + (size - 1) * gap
    local first  = self._cells[1] and self._cells[1][1] and self._cells[1][1].frame
    local ga     = self._goldAnchor
    if first and ga then
        ga:ClearAllPoints()
        ga:SetSize(
            gridPx + CFG.gold_pad_left + CFG.gold_pad_right,
            gridPx + CFG.gold_pad_top + CFG.gold_pad_bottom)
        ga:SetPoint("TOPLEFT", first, "TOPLEFT",
            -CFG.gold_pad_left + (CFG.gold_ofs_x or 0),
            CFG.gold_pad_top + (CFG.gold_ofs_y or 0))
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
            ArcadiaNexus.Format.SecondsMMSS(gs.timeLeft or 0)))
    end

    if self.scoreFS then
        local Logic = ArcadiaNexus.NON_Logic
        local previewScore = Logic and Logic:CalcScore(gs) or 0
        self.scoreFS:SetText(string.format("%s: %d", L["lbl_score"] or "Punkte", previewScore))
    end

    if self.puzzleFS then
        self.puzzleFS:SetText(string.format("%s: %d | %s",
            L["lbl_puzzle"] or "Puzzle", gs.puzzleIndex, gs.puzzleName or ""))
    end

    if self.modeFS then
        local modeLabel = gs.mode == "strict"
            and (L["mode_strict"] or "Strenger Modus")
            or  (L["mode_free"]   or "Freies Lösen")
        self.modeFS:SetText(modeLabel)
    end

    if self.errorsFS then
        if gs.mode == "strict" then
            local hearts = ""
            for i = 1, gs.errorLimit do
                if i <= (gs.errorLimit - gs.errors) then
                    hearts = hearts .. "H "
                else
                    hearts = hearts .. "o "
                end
            end
            self.errorsFS:SetText(hearts)
            if self._errorsBox then self._errorsBox:Show() else self.errorsFS:Show() end
        else
            if self._errorsBox then self._errorsBox:Hide() else self.errorsFS:Hide() end
        end
    end
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

function R:ShowWin(gs)
    self.state = "WIN"
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("NONOGRAM")
    local UI = ArcadiaNexus.UI
    if self.frame then self.frame:EnableKeyboard(false) end
    self:_UpdateControlLabels()
    UI.ShowArcadeResult(field, {
        title      = L["state_win"] or "Gelöst!",
        titleColor = { 0, 1, 0 },
        score      = gs.finalScore or 0,
        gameId     = "NONOGRAM",
        difficulty = gs.difficulty,
        result     = "WIN",
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.NON_Engine
            local S = ArcadiaNexus.NON_Settings
            local diff = S and S:Get("difficulty") or "easy"
            local mode = S and S:Get("defaultMode") or "free"
            if E then E:StartGame(diff, mode) end
        end,
        onExit = function()
            local E = ArcadiaNexus.NON_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:ShowGameOver(gs, reason)
    self.state = "GAMEOVER"
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("NONOGRAM")
    local UI = ArcadiaNexus.UI
    if self.frame then self.frame:EnableKeyboard(false) end
    self:_UpdateControlLabels()
    UI.ShowArcadeResult(field, {
        title      = L["state_gameover"] or "Keine Fehler mehr!",
        titleColor = { 1, 0.13, 0.13 },
        subtitle   = L["mode_select_title"] or "Weiter spielen?",
        gameId     = "NONOGRAM",
        difficulty = gs and gs.difficulty,
        result     = "LOSS",
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.NON_Engine
            local S = ArcadiaNexus.NON_Settings
            local diff = S and S:Get("difficulty") or "easy"
            local mode = S and S:Get("defaultMode") or "free"
            if E then E:StartGame(diff, mode) end
        end,
        onExit = function()
            local E = ArcadiaNexus.NON_Engine
            if E then E:StopGame() end
        end,
    })
end

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================
function R:_HidePlayingElements()
    self:_SetHudShown(false)
    if self.frame       then self.frame:EnableKeyboard(false) end
end
