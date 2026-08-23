-- Games/ShadowsConquest/Renderer.lua

local R = {}
ArcadiaNexus.SC_Renderer = R

local _flashGuard = ArcadiaNexus.TimerGuard.New()

local CFG = {
    field_w      = 520,
    field_h      = 520,
    field_ofs_x  = 0,
    field_ofs_y  = 17,
    bg_w         = 800,
    bg_h         = 545,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1, -- Transparenz
    border_w     = 800,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 17,
    logo_w       = 542,
    logo_h       = 284,
    logo_ofs_x   = 0,
    logo_ofs_y   = 15,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    chk_size     = 20,
    grid_size    = 500,
    grid_ofs_x   = 0,
    grid_ofs_y   = 0,
    gold_ofs_x   = 0,
    gold_ofs_y   = 0,
    hud_score_w     = 120,
    hud_score_h     = 28,
    hud_score_x     = -306,
    hud_score_y     = 253,
    hud_score_alpha = 0.75,
    hud_best_w      = 120,
    hud_best_h      = 28,
    hud_best_x      = 306,
    hud_best_y      = 253,
    hud_best_alpha  = 0.75,
    hud_puzzle_w    = 120,
    hud_puzzle_h    = 28,
    hud_puzzle_x    = -306,
    hud_puzzle_y    = 220,
    hud_puzzle_alpha = 0.75,
    hud_moves_w     = 120,
    hud_moves_h     = 28,
    hud_moves_x     = 306,
    hud_moves_y     = 220,
    hud_moves_alpha = 0.75,
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
R.frame           = nil
R.state           = "IDLE"
R._fieldFrame     = nil
R._borderFrame    = nil
R._logo           = nil
R._controlsFrame  = nil
R._startBtn       = nil
R._resumeBtn      = nil
R._moveLimitChk   = nil
R.scoreFS         = nil
R.puzzleFS        = nil
R.movesFS         = nil
R._cells          = {}
R._boardHolder    = nil
R._cellSize       = 0
R._cellPool       = nil

local CELL_ON_COLOR  = { 1.00, 0.95, 0.20, 1.00 }
local CELL_OFF_COLOR = { 0.15, 0.15, 0.18, 1.00 }
local GLOW_COLOR     = { 1.00, 0.90, 0.30, 0.35 }
local CELL_GAP       = 4

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ShadowsConquest.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Frame", nil, poolParent)
            local bg = wrap:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            local glow = wrap:CreateTexture(nil, "OVERLAY")
            glow:SetTexture("Interface\\Buttons\\WHITE8X8")
            glow:SetBlendMode("ADD")
            glow:Hide()
            local flash = wrap:CreateTexture(nil, "OVERLAY")
            flash:SetTexture("Interface\\Buttons\\WHITE8X8")
            flash:Hide()
            local btn = CreateFrame("Button", nil, wrap)
            wrap._bg       = bg
            wrap._glow     = glow
            wrap._flash    = flash
            wrap._flashGen = 0
            wrap._btn      = btn
            return wrap
        end,
        onRelease = function(wrap)
            wrap._flashGen = (wrap._flashGen or 0) + 1
            wrap:Hide()
            wrap:ClearAllPoints()
            wrap._btn:SetScript("OnClick", nil)
            wrap._btn._row = nil
            wrap._btn._col = nil
            wrap._btn:Enable()
            wrap._bg:Hide()
            wrap._glow:Hide()
            if wrap._flash then
                wrap._flash:Hide()
                wrap._flash:SetAlpha(1)
                wrap._flash:SetVertexColor(1, 1, 1, 1)
                wrap._flash:ClearAllPoints()
            end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

local ADDON_PATH = "Interface\\AddOns\\ArcadiaNexus\\"

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
        outerName = "ArcadiaNexus_SC_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._scContainer = f

    f:EnableKeyboard(false)

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("SHADOWSCONQUEST", ArcadiaNexus.SC_Engine, function(E)
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
    bg:SetTexture(ADDON_PATH .. "Games\\ShadowsConquest\\assets\\background\\bg_sc")
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
    tex:SetTexture(ADDON_PATH .. "Games\\ShadowsConquest\\assets\\border\\border_sc")
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
        ADDON_PATH .. "Games\\ShadowsConquest\\assets\\logo\\logo_sc",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- STATUS BAR
-- ============================================================
function R:_CreateStatusBar()
    if self._scoreBox then return end
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self.scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Punkte") .. ": 0",
        shown = false,
    })
    self._bestBox, self.bestFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["lbl_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })
    self._puzzleBox, self.puzzleFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_puzzle_w, h = CFG.hud_puzzle_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_puzzle_x, y = CFG.hud_puzzle_y,
        alpha = CFG.hud_puzzle_alpha,
        shown = false,
    })
    self._movesBox, self.movesFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        shown = false,
    })
end

function R:_SetHudShown(shown)
    local boxes = { self._scoreBox, self._bestBox, self._puzzleBox, self._movesBox, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

function R:UpdateHUD(gs)
    if not gs then
        self:_SetHudShown(false)
        return
    end
    local L = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")
    local score = gs.score or gs.finalScore or 0
    if self.scoreFS then
        self.scoreFS:SetText((L["lbl_score"] or "Punkte") .. ": " .. score)
    end
    if self.bestFS then
        local SM = ArcadiaNexus.ScoreManager
        local hs = SM and SM:GetBestScore("SHADOWSCONQUEST", gs.difficulty) or 0
        self.bestFS:SetText((L["lbl_highscore"] or "Highscore") .. ": " .. math.max(hs, score))
    end
    if self.puzzleFS then
        self.puzzleFS:SetText((L["lbl_puzzle"] or "Puzzle") .. ": " .. (gs.puzzleIndex or 1))
    end
    if self.movesFS then
        self.movesFS:SetText((L["lbl_moves"] or "Zuge") .. ": " .. (gs.moveCount or 0))
    end
    self:_SetHudShown(true)
end

function R:ShowOverlay(kind, gs)
    if kind ~= "WIN" and kind ~= "GAMEOVER_MOVES" then return end
    local field = self._fieldFrame
    if not field then return end
    local L  = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")
    local UI = ArcadiaNexus.UI
    local config = {
        title      = nil,
        titleColor = nil,
        gameId     = "SHADOWSCONQUEST",
        L          = L,
        buttons    = {
            {
                label   = L["btn_start"] or "Spiel starten",
                onClick = function()
                    local E = ArcadiaNexus.SC_Engine
                    if E then E:NextPuzzle() end
                end,
            },
        },
    }
    if kind == "WIN" then
        config.title      = L["state_win"] or "Gelöst!"
        config.titleColor = { 1, 0.84, 0 }
        config.score      = gs and gs.finalScore or 0
        config.result     = "WIN"
    else
        config.title      = L["state_gameover_moves"] or "Keine Zuge mehr!"
        config.titleColor = { 1, 0.3, 0.3 }
        config.result     = "LOSS"
    end
    UI.ShowArcadeResult(field, config)
end

-- ============================================================
-- CONTROLS – CreateGameControlsBar "wide"
-- ============================================================
function R:_CreateControls()
    if self._controlsFrame then return end
    local L  = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.SC_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Segment 1: Dropdown Schwierigkeit
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

    -- Segment 2: Start/Beenden Toggle-Button
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SC_Engine
        if not E then return end
        if E.state == "PLAYING" or E.state == "WIN" or E.state == "GAMEOVER" then
            E:StopGame()
            R:EnterIdleState()
        else
            local sv = S and S:Get("difficulty") or "easy"
            E:StartGame(sv)
        end
    end)
    self._startBtn = startBtn

    -- Segment 3: Weiterspielen/Zurücksetzen Toggle-Button
    local resumeBtn = UI.CreateArcadiaButton(cf, L["btn_resume"] or "Weiterspielen", CFG.btn_w, CFG.btn_h)
    resumeBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    resumeBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SC_Engine
        if not E then return end
        if E.state == "PLAYING" then
            E:ResetPuzzle()
        else
            E:NextPuzzle()
        end
    end)
    resumeBtn:Hide()
    self._resumeBtn = resumeBtn

    -- Segment 4: Zug-Limit Checkbox
    local chkHolder, chk = UI.CreateBarCheckbox(cf, L["lbl_moves_check"] or "Zug-Limit", { w = 130, h = 36, size = CFG.chk_size })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)
    chk:SetScript("OnShow", function()
        chk:SetChecked(S and S:Get("moveLimitActive") or false)
    end)
    chk:SetScript("OnClick", function()
        if S then S:Set("moveLimitActive", chk:GetChecked()) end
    end)
    self._moveLimitChk = chk
end

-- ============================================================
-- TOGGLE-BUTTON LABELS
-- ============================================================
function R:_UpdateControlLabels()
    local L = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")
    local E = ArcadiaNexus.SC_Engine
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
            self._resumeBtn:SetLabel(L["btn_reset"] or "Zurücksetzen")
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
-- GRID
-- ============================================================
function R:RenderGame(gs)
    self:_ShowPlayArea()
    self:_BuildGrid(gs)
    self:UpdateHUD(gs)
    self:_UpdateControlLabels()
end

function R:_EnsureCellPool()
    if not self._cellPool then self._cellPool = CreateCellPool() end
end

function R:_BuildGrid(gs)
    self:_ClearGrid()
    self:_EnsureCellPool()

    local gridSize = gs.gridSize
    local avail    = CFG.grid_size
    local cellSize = math.floor((avail - CELL_GAP * (gridSize - 1)) / gridSize)
    local total    = cellSize * gridSize + CELL_GAP * (gridSize - 1)

    local holder = self._boardHolder
    if not holder then
        holder = CreateFrame("Frame", nil, self._fieldFrame)
        self._boardHolder = holder
    end
    holder:SetParent(self._fieldFrame)
    holder:SetSize(total, total)
    holder:SetPoint("CENTER", self._fieldFrame, "CENTER", CFG.grid_ofs_x, CFG.grid_ofs_y)
    holder:Show()
    self._cells       = {}
    self._cellSize    = cellSize

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        if not self._goldGrid then
            self._goldGrid = UI.CreateGoldGridFrame(self._canvas, holder, {
                x = CFG.gold_ofs_x, y = CFG.gold_ofs_y,
            })
        elseif UI.FitGoldGridFrame then
            UI.FitGoldGridFrame(self._goldGrid, holder, {
                x = CFG.gold_ofs_x, y = CFG.gold_ofs_y,
            })
        end
    end

    for r = 1, gridSize do
        self._cells[r] = {}
        for c = 1, gridSize do
            local px = (c-1) * (cellSize + CELL_GAP)
            local py = (r-1) * (cellSize + CELL_GAP)

            local wrap = self._cellPool:Acquire({})
            wrap:SetParent(holder)
            wrap:SetSize(cellSize, cellSize)
            wrap:SetPoint("TOPLEFT", holder, "TOPLEFT", px, -py)

            wrap._bg:SetSize(cellSize, cellSize)
            wrap._bg:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
            wrap._glow:SetSize(cellSize, cellSize)
            wrap._glow:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
            wrap._btn:SetSize(cellSize, cellSize)
            wrap._btn:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
            wrap._btn._row = r
            wrap._btn._col = c
            wrap._btn:SetScript("OnClick", function(selfBtn)
                local E = ArcadiaNexus.SC_Engine
                if E then E:HandleClick(selfBtn._row, selfBtn._col) end
            end)
            wrap._btn:Enable()
            wrap._flash:ClearAllPoints()
            wrap._flash:SetSize(cellSize, cellSize)
            wrap._flash:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
            wrap._flash:SetVertexColor(1, 1, 1, 1)
            wrap._flash:SetAlpha(1)
            wrap._flash:Hide()
            wrap:Show()

            self._cells[r][c] = {
                wrap  = wrap,
                bg    = wrap._bg,
                glow  = wrap._glow,
                flash = wrap._flash,
                btn   = wrap._btn,
            }
            self:_UpdateCell(gs, r, c)
        end
    end
end

function R:_ClearGrid()
    _flashGuard:Cancel()
    if self._cellPool then self._cellPool:ReleaseAll() end
    self._cells = {}
    if self._boardHolder then self._boardHolder:Hide() end
end

function R:UpdateGrid(gs, clickedRow, clickedCol)
    if not self._cells then return end
    local gridSize = gs.gridSize
    for r = 1, gridSize do
        for c = 1, gridSize do
            if self._cells[r] and self._cells[r][c] then
                self:_UpdateCell(gs, r, c)
            end
        end
    end
    if clickedRow and clickedCol then
        local neighbors = {
            {clickedRow,   clickedCol  }, {clickedRow-1, clickedCol  },
            {clickedRow+1, clickedCol  }, {clickedRow,   clickedCol-1},
            {clickedRow,   clickedCol+1},
        }
        for _, t in ipairs(neighbors) do
            local r, c = t[1], t[2]
            if r >= 1 and r <= gridSize and c >= 1 and c <= gridSize then
                self:_FlashCell(r, c)
            end
        end
    end
end

function R:_UpdateCell(gs, r, c)
    local cell = self._cells[r] and self._cells[r][c]
    if not cell then return end
    if gs.grid[r][c] == 1 then
        cell.bg:SetVertexColor(CELL_ON_COLOR[1], CELL_ON_COLOR[2], CELL_ON_COLOR[3], CELL_ON_COLOR[4])
        cell.glow:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4])
        cell.bg:Show(); cell.glow:Show()
    else
        cell.bg:SetVertexColor(CELL_OFF_COLOR[1], CELL_OFF_COLOR[2], CELL_OFF_COLOR[3], CELL_OFF_COLOR[4])
        cell.bg:Show(); cell.glow:Hide()
    end
end

function R:_FlashCell(r, c)
    local cell = self._cells[r] and self._cells[r][c]
    if not cell or not cell.wrap or not cell.flash then return end
    local wrap  = cell.wrap
    local flash = cell.flash
    local sz    = self._cellSize or 40
    wrap._flashGen = (wrap._flashGen or 0) + 1
    local myGen = wrap._flashGen
    flash:ClearAllPoints()
    flash:SetSize(sz, sz)
    flash:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
    flash:SetVertexColor(1.00, 1.00, 1.00, 0.70)
    flash:SetAlpha(1)
    flash:Show()
    _flashGuard:After(0.12, function()
        if wrap._flashGen ~= myGen then return end
        if not R._cells or not R._cells[r] or R._cells[r][c] ~= cell then return end
        if cell.wrap ~= wrap then return end
        flash:Hide()
    end)
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:_ClearGrid()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_SetHudShown(false)

    if self._logo then self._logo:Show() end

    local S = ArcadiaNexus.SC_Settings
    if self._moveLimitChk and S then
        self._moveLimitChk:SetChecked(S:Get("moveLimitActive"))
    end

    self:_UpdateControlLabels()
end

-- ============================================================
-- PLAY-AREA SHOW
-- ============================================================
function R:_ShowPlayArea()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logo    then self._logo:Hide()    end
    if self._goldGrid then self._goldGrid:Show() end
end

-- ============================================================
-- REGISTRIERUNG
-- ============================================================
ArcadiaNexus.RegisterGame({
    id        = "SHADOWSCONQUEST",
    label     = "Shadows Conquest",
    category  = "RAETSEL",
    renderer  = "SC_Renderer",
    engine    = "SC_Engine",
    container = "_scContainer",
})
