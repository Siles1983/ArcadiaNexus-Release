--[[
    ArcadiaNexus
    Games/Minesweeper/Renderer.lua
    Version: 2.0.0  (Blueprint v2 – nach 2048-Muster)

    Layout-Strategie:
      - Panel-großer Lifecycle-Container mit zentriertem 600x498 Design-Canvas
      - CENTER-Ankern für Spielfeld, Border, Logo, Score
      - Controls-Leiste am BOTTOM des Design-Canvas (1:1 wie 2048)
      - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
      - Logo via UI.CreateGameLogo
      - Spielfeld dynamisch: 9x9 / 12x12 / 16x16

    Zell-Zustände:
      Verdeckt  → Zahnrad-Icon  (INV_Misc_Gear_01), mittleres Grau
      Flagge    → Warnschild    (Ability_TownWatch), orange Hintergrund
      Mine      → Goblin-Bombe  (INV_Misc_Bomb_03), roter Hintergrund
      Aufgedeckt leer  → heller Hintergrund, kein Icon
      Aufgedeckt Zahl  → heller Hintergrund, farbige Zahl

    Zahlenfarben (klassisch):
      1 → Blau      2 → Grün   3 → Rot    4 → Dunkelblau
      5 → Maroon    6 → Türkis 7 → Schwarz 8 → Grau

    Schachbrettmuster:
      (r+c) gerade  → dunkel   { 0.18, 0.18, 0.18 }
      (r+c) ungerade → heller  { 0.24, 0.24, 0.24 }
    Aufgedeckt:
      (r+c) gerade  → { 0.62, 0.58, 0.48 }
      (r+c) ungerade→ { 0.72, 0.68, 0.56 }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MS_Renderer = {}
local R = ArcadiaNexus.MS_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_w      = 450,
    field_h      = 450,
    field_ofs_x  = 0,
    field_ofs_y  = 5,
    border_w     = 790,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 10,
    logo_w       = 487,
    logo_h       = 332,
    logo_ofs_x   = 0,
    logo_ofs_y   = 30,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,
    hud_mine_w      = 180,
    hud_mine_h      = 28,
    hud_mine_x      = -135,
    hud_mine_y      = 241,
    hud_mine_alpha  = 0.75,
    hud_flag_w      = 180,
    hud_flag_h      = 28,
    hud_flag_x      = 135,
    hud_flag_y      = 241,
    hud_flag_alpha  = 0.75,
    min_icon_size = 16,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local MS_ASSETS = {
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Minesweeper\\assets\\logo\\logo_minesweeper",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\Minesweeper\\assets\\border\\border_minesweeper",
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\Minesweeper\\assets\\background\\background_minesweeper",
}

local ICON_HIDDEN = "Interface\\Icons\\INV_Misc_Gear_01"
local ICON_FLAG   = "Interface\\Icons\\Ability_TownWatch"
local ICON_MINE   = "Interface\\Icons\\INV_Misc_Bomb_03"

-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld (maximale Größe; Zellgröße dynamisch berechnet)

-- Border über dem Spielfeld

-- Logo im Spielfeld (IDLE-Zustand)

-- Statusbar (Minen-/Flaggen-Anzeige)

-- Zelleigenschaften

-- ============================================================
-- FARBEN
-- ============================================================
local NUMBER_COLORS = {
    [1] = { 0.26, 0.26, 1.00 },
    [2] = { 0.13, 0.67, 0.13 },
    [3] = { 1.00, 0.20, 0.20 },
    [4] = { 0.00, 0.00, 0.55 },
    [5] = { 0.55, 0.00, 0.00 },
    [6] = { 0.00, 0.55, 0.55 },
    [7] = { 0.13, 0.13, 0.13 },
    [8] = { 0.55, 0.55, 0.55 },
}

local CLR_HIDDEN_EVEN = { 0.18, 0.18, 0.18, 1 }
local CLR_HIDDEN_ODD  = { 0.24, 0.24, 0.24, 1 }
local CLR_OPEN_EVEN   = { 0.62, 0.58, 0.48, 1 }
local CLR_OPEN_ODD    = { 0.72, 0.68, 0.56, 1 }
local CLR_FLAG        = { 0.70, 0.40, 0.05, 1 }
local CLR_MINE        = { 0.70, 0.08, 0.08, 1 }
local CLR_MINE_HIT    = { 1.00, 0.10, 0.10, 1 }

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Minesweeper.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local tf = CreateFrame("Button", nil, poolParent)
            tf:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
            tf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            tf:EnableMouse(true)

            local iconFrame = CreateFrame("Frame", nil, tf)
            iconFrame:EnableMouse(false)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints(iconFrame)
            iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            local lbl = tf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetAllPoints(tf)
            lbl:SetJustifyH("CENTER")
            lbl:SetJustifyV("MIDDLE")

            tf._iconFrame = iconFrame
            tf._iconTex   = iconTex
            tf._label     = lbl
            return tf
        end,
        onRelease = function(tf)
            tf:Hide()
            tf:ClearAllPoints()
            tf:SetScript("OnClick", nil)
            tf._gridR = nil
            tf._gridC = nil
            tf._isEven = nil
            local bg = tf:GetNormalTexture()
            if bg then bg:SetVertexColor(1, 1, 1, 1) end
            if tf._iconTex then
                tf._iconTex:SetTexture(ICON_HIDDEN)
                tf._iconTex:SetVertexColor(1, 1, 1, 1)
                tf._iconTex:Show()
            end
            if tf._label then tf._label:SetText("") end
            if poolParentRef then tf:SetParent(poolParentRef) end
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
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"
R.selectedDiff  = nil

R.cells         = {}
R.boardHolder   = nil
R.currentSize   = 0
R._cellPool     = nil

R._startBtn     = nil
R._newGameBtn   = nil
R._mineBox      = nil
R._flagBox      = nil
R._mineCountFS  = nil
R._flagCountFS  = nil
R._goldGrid     = nil
R._hintFS       = nil

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    local S = ArcadiaNexus.MS_Settings
    self.selectedDiff = (S and S:Get("difficulty")) or "easy"

    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateStatusBar()
    self:_CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine
    Engine:On("MS_GAME_STARTED",  function(s) R:OnGameStarted(s)  end)
    Engine:On("MS_CELL_REVEALED", function(s) R:OnBoardUpdated(s) end)
    Engine:On("MS_FLAG_TOGGLED",  function(s) R:OnBoardUpdated(s) end)
    Engine:On("MS_GAME_WON",      function(s) R:OnGameWon(s)      end)
    Engine:On("MS_GAME_LOST",     function(s) R:OnGameLost(s)     end)
    Engine:On("MS_GAME_STOPPED",  function()  R:EnterIdleState()  end)
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
        outerName = "ArcadiaNexus_MS_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._msContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("MINESWEEPER", ArcadiaNexus.MS_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.12, 0.12, 0.12, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff = self._fieldFrame
    if not ff then return end
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(MS_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    -- Eigener Frame mit FrameLevel +10 → liegt garantiert über allen Zell-Frames
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(MS_ASSETS.border)
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
        MS_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function R:_CreateStatusBar()
    if self._mineBox then return end
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._mineBox, self._mineCountFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_mine_w, h = CFG.hud_mine_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_mine_x, y = CFG.hud_mine_y,
        alpha = CFG.hud_mine_alpha,
        text = (L["hud_mines"] or "Dynamit") .. ": 0",
        shown = false,
    })
    self._flagBox, self._flagCountFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_flag_w, h = CFG.hud_flag_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_flag_x, y = CFG.hud_flag_y,
        alpha = CFG.hud_flag_alpha,
        text = (L["hud_flags"] or "Gesetzt") .. ": 0",
        shown = false,
    })
end

function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (linkes Segment)
    local S = ArcadiaNexus.MS_Settings
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
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            R.selectedDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Start / Beenden Button (mittleres Segment, CENTER)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        if R.state == "PLAYING" then
            ArcadiaNexus.MS_Engine:StopGame()
        else
            ArcadiaNexus.MS_Engine:StartGame({ difficulty = R.selectedDiff })
        end
    end)
    self._startBtn = startBtn

    -- Neues Spiel Button (rechtes Segment, CENTER+180)
    local newGameBtn = UI.CreateArcadiaButton(cf, L["btn_new_game"], CFG.btn_w, CFG.btn_h)
    newGameBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    newGameBtn:SetScript("OnClick", function()
        ArcadiaNexus.MS_Engine:StartGame({ difficulty = R.selectedDiff })
    end)
    newGameBtn:Hide()
    self._newGameBtn = newGameBtn
end

-- ============================================================
-- BOARD AUFBAUEN
-- ============================================================
-- BOARD AUFBAUEN
-- ============================================================
function R:_EnsureCellPool()
    if not self._cellPool then self._cellPool = CreateCellPool() end
end

function R:BuildBoard(size)
    self:ClearBoard()
    self.currentSize = size

    local cellSize = math.floor(CFG.field_w / size)
    local boardPx  = cellSize * size
    local parent   = self._fieldFrame

    -- Board-Holder zentriert im Spielfeld
    local holder = self.boardHolder
    if not holder then
        holder = CreateFrame("Frame", nil, parent)
        self.boardHolder = holder
    end
    holder:SetParent(parent)
    holder:SetSize(boardPx, boardPx)
    holder:SetPoint("CENTER", parent, "CENTER", 0, 0)
    holder:Show()

    local iconSize = math.max(CFG.min_icon_size, cellSize - 6)
    self:_EnsureCellPool()

    for r = 1, size do
        self.cells[r] = {}
        for c = 1, size do
            local px = (c-1) * cellSize
            local py = (r-1) * cellSize

            local tf = self._cellPool:Acquire({})
            tf:SetParent(holder)
            tf:SetSize(cellSize, cellSize)
            tf:SetPoint("TOPLEFT", holder, "TOPLEFT", px, -py)

            local bg      = tf:GetNormalTexture()
            local isEven  = (r + c) % 2 == 0
            local hiddenC = isEven and CLR_HIDDEN_EVEN or CLR_HIDDEN_ODD
            bg:SetVertexColor(hiddenC[1], hiddenC[2], hiddenC[3], 1)

            tf._iconFrame:SetSize(iconSize, iconSize)
            tf._iconFrame:SetPoint("CENTER", tf, "CENTER", 0, 0)
            tf._iconFrame:SetFrameLevel(tf:GetFrameLevel() + 2)
            tf._iconTex:SetTexture(ICON_HIDDEN)
            tf._iconTex:Show()

            local fontSize = math.max(10, cellSize - 16)
            tf._label:SetFont(tf._label:GetFont(), fontSize, "OUTLINE")
            tf._label:SetText("")

            tf._gridR = r
            tf._gridC = c
            tf._isEven = isEven
            tf:SetScript("OnClick", function(selfBtn, btn)
                if btn == "RightButton" then
                    ArcadiaNexus.MS_Engine:HandleFlag(selfBtn._gridR, selfBtn._gridC)
                else
                    ArcadiaNexus.MS_Engine:HandleReveal(selfBtn._gridR, selfBtn._gridC)
                end
            end)
            tf:Show()

            self.cells[r][c] = {
                frame     = tf,
                bg        = bg,
                iconFrame = tf._iconFrame,
                iconTex   = tf._iconTex,
                label     = tf._label,
                isEven    = isEven,
            }
        end
    end
end

function R:ClearBoard()
    if self._cellPool then self._cellPool:ReleaseAll() end
    self.cells = {}
    if self.boardHolder then self.boardHolder:Hide() end
    self.currentSize = 0
end

-- ============================================================
-- ZELLE RENDERN
-- ============================================================
function R:RenderCell(r, c, cell)
    local cd = self.cells[r] and self.cells[r][c]
    if not cd then return end

    local isEven = cd.isEven

    if not cell.revealed then
        if cell.flagged then
            cd.bg:SetVertexColor(CLR_FLAG[1], CLR_FLAG[2], CLR_FLAG[3], 1)
            cd.iconTex:SetTexture(ICON_FLAG)
            cd.iconTex:SetVertexColor(1, 1, 1, 1)
            cd.iconTex:Show()
            cd.label:SetText("")
        else
            local col = isEven and CLR_HIDDEN_EVEN or CLR_HIDDEN_ODD
            cd.bg:SetVertexColor(col[1], col[2], col[3], 1)
            cd.iconTex:SetTexture(ICON_HIDDEN)
            cd.iconTex:SetVertexColor(0.65, 0.65, 0.65, 1)
            cd.iconTex:Show()
            cd.label:SetText("")
        end
    else
        if cell.isMine then
            cd.bg:SetVertexColor(CLR_MINE[1], CLR_MINE[2], CLR_MINE[3], 1)
            cd.iconTex:SetTexture(ICON_MINE)
            cd.iconTex:SetVertexColor(1, 1, 1, 1)
            cd.iconTex:Show()
            cd.label:SetText("")
        else
            local col = isEven and CLR_OPEN_EVEN or CLR_OPEN_ODD
            cd.bg:SetVertexColor(col[1], col[2], col[3], 1)
            cd.iconTex:Hide()
            if cell.neighbors > 0 then
                local nc = NUMBER_COLORS[cell.neighbors] or { 0, 0, 0 }
                cd.label:SetText(tostring(cell.neighbors))
                cd.label:SetTextColor(nc[1], nc[2], nc[3], 1)
            else
                cd.label:SetText("")
            end
        end
    end
end

function R:RenderAll(state)
    for r = 1, state.size do
        for c = 1, state.size do
            self:RenderCell(r, c, state.cells[r][c])
        end
    end
    self:UpdateStatusBar(state)
end

-- ============================================================
-- STATUS-BAR
-- ============================================================
function R:UpdateStatusBar(state)
    local L = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
    local remaining = state.remaining or (state.mineCount - state.flagCount)
    if self._mineCountFS then
        self._mineCountFS:SetText((L["hud_mines"] or "Dynamit") .. ": " .. tostring(remaining))
    end
    if self._flagCountFS then
        self._flagCountFS:SetText((L["hud_flags"] or "Gesetzt") .. ": " .. tostring(state.flagCount or 0))
    end
end

-- ============================================================
-- EXPLOSION-EFFEKT
-- ============================================================
function R:PlayExplosionEffect(state)
    if not state.minePositions then return end
    for _, pos in ipairs(state.minePositions) do
        local cd = self.cells[pos.r] and self.cells[pos.r][pos.c]
        if cd then
            cd.bg:SetVertexColor(CLR_MINE_HIT[1], CLR_MINE_HIT[2], CLR_MINE_HIT[3], 1)
            cd.iconTex:SetTexture(ICON_MINE)
            cd.iconTex:SetVertexColor(1, 1, 1, 1)
            cd.iconTex:Show()
            cd.label:SetText("")
        end
    end
    C_Timer.After(0.3, function()
        for _, pos in ipairs(state.minePositions or {}) do
            local cd = self.cells[pos.r] and self.cells[pos.r][pos.c]
            if cd then
                cd.bg:SetVertexColor(CLR_MINE[1], CLR_MINE[2], CLR_MINE[3], 1)
            end
        end
    end)
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:ClearBoard()

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._mineCountFS then self._mineCountFS:Hide() end
    if self._mineBox     then self._mineBox:Hide()     end
    if self._flagBox     then self._flagBox:Hide()     end
    if self._newGameBtn  then self._newGameBtn:Hide()  end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end
    if self._goldGrid    then self._goldGrid:Hide()    end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MINESWEEPER")["btn_start"])
        self._startBtn:Show()
    end

    -- Hint-Text (einmalig erstellen)
    if not self._hintFS then
        self._hintFS = self._canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self._hintFS:SetPoint("CENTER", self._canvas, "CENTER", 0, CFG.field_ofs_y)
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("MINESWEEPER")["hint_start"])
        self._hintFS:SetJustifyH("CENTER")
    end
    self._hintFS:Show()
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(state)
    self.state        = "PLAYING"
    self.selectedDiff = state.difficulty or self.selectedDiff

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._hintFS  then self._hintFS:Hide()   end
    if self._logoTex then self._logoTex:Hide()  end
    if self._mineCountFS then self._mineCountFS:Show() end
    if self._mineBox     then self._mineBox:Show()     end
    if self._flagBox     then self._flagBox:Show()     end
    if self._goldGrid    then self._goldGrid:Show()    end
    if self._newGameBtn  then self._newGameBtn:Show()  end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MINESWEEPER")["btn_exit"])
    end

    self:BuildBoard(state.size)
    self:RenderAll(state)
end

function R:OnBoardUpdated(state)
    self:RenderAll(state)
end

function R:OnGameWon(state)
    self.state = "WON"
    self:RenderAll(state)

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
    local parent = self._fieldFrame

    UI.ShowArcadeResult(parent, {
        title      = L["result_win_title"],
        titleColor = { 1, 0.84, 0 },
        subtitle   = string.format(L["result_win_sub"],
            state.mineCount, state.difficulty:upper(), state.revealCount),
        gameId     = "MINESWEEPER",
        difficulty = state.difficulty,
        result     = "WIN",
        L          = L,
        onRetry    = function()
            ArcadiaNexus.MS_Engine:StartGame({ difficulty = R.selectedDiff })
        end,
        onExit = function()
            ArcadiaNexus.MS_Engine:StopGame()
        end,
    })

    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn   then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MINESWEEPER")["btn_start"])
    end
end

function R:OnGameLost(state)
    self.state = "LOST"
    self:PlayExplosionEffect(state)

    C_Timer.After(0.5, function()
        self:RenderAll(state)
        if not self._fieldFrame then return end
        local UI     = ArcadiaNexus.UI
        local L      = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
        local parent = self._fieldFrame

        UI.ShowArcadeResult(parent, {
            title      = L["result_loss_title"],
            titleColor = { 1, 0.2, 0.2 },
            subtitle   = string.format(L["result_loss_sub"],
                state.revealCount, state.size * state.size - state.mineCount),
            gameId     = "MINESWEEPER",
            difficulty = state.difficulty,
            result     = "LOSS",
            L          = L,
            onRetry    = function()
                ArcadiaNexus.MS_Engine:StartGame({ difficulty = R.selectedDiff })
            end,
            onExit = function()
                ArcadiaNexus.MS_Engine:StopGame()
            end,
        })

        if self._newGameBtn then self._newGameBtn:Hide() end
        if self._startBtn   then
            self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MINESWEEPER")["btn_start"])
        end
    end)
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "MINESWEEPER",
    label     = "Minesweeper",
    renderer  = "MS_Renderer",
    engine    = "MS_Engine",
    container = "_msContainer",
    category  = "DENKSPIELE",
})
