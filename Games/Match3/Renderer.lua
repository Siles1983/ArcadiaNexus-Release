-- ============================================================
--  ArcadiaNexus
--  Games/Match3/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach 2048-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD (Score, Züge, Timer) über dem Spielfeld
--    - Controls-Leiste am BOTTOM von self.frame (1:1 wie 2048)
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo
--    - Combo-Anzeige über dem Spielfeld
--
--  Animationen (unverändert):
--    Swap:        0.2s EaseInOut via OnUpdate
--    Pulse+Fade:  Match-Icons 1→1.2 scale, dann Fade
--    Fall:        Quadratische Beschleunigung (Gravitation)
--    InvalidSwap: Shake-Feedback
--
--  Object-Pooling: _pool für Icon-Frames
--  Spielfeld: variabel 8×8 / 10×10 / 12×12 in BOARD_SIZE
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.M3_Renderer = {}
local R = ArcadiaNexus.M3_Renderer

local _animLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_M3_AnimLoop")

local function StartAnimLoop(tickFn)
    _animLoop:Stop()
    _animLoop:Start(tickFn, { maxDt = 0.1 })
end

local function StopAnimLoop()
    _animLoop:Stop()
end

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local M3_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\Match3\\assets\\background\\backgound_match3",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Match3\\assets\\logo\\logo_match3",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\Match3\\assets\\border\\border_match3",
}

-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld (Zellgröße dynamisch berechnet)
local BOARD_SIZE   = 480
local FIELD_OFS_X  = 0       -- Spielfeld horizontal verschieben (0 = mittig)
local FIELD_OFS_Y  = -5      -- Spielfeld vertikal verschieben (positiv = nach oben)

-- Hintergrund (relativ zu _fieldFrame CENTER)
local CFG = {
    bg_w     = 790,
    bg_h     = 530,
    bg_ofs_x = 0,
    bg_ofs_y = 15,
    bg_alpha = 1,
    hud_score_w     = 150,
    hud_score_h     = 28,
    hud_score_x     = -165,
    hud_score_y     = 250,
    hud_score_alpha = 0.75,
    hud_moves_w     = 130,
    hud_moves_h     = 28,
    hud_moves_x     = 0,
    hud_moves_y     = 250,
    hud_moves_alpha = 0.75,
    hud_best_w      = 160,
    hud_best_h      = 28,
    hud_best_x      = 160,
    hud_best_y      = 250,
    hud_best_alpha  = 0.75,
}

-- Border über dem Spielfeld
local BORDER_W     = 795     -- größer als Spielfeld → überstehender Rahmen
local BORDER_H     = 550
local BORDER_OFS_X = 0       -- Offset vom Spielfeld-CENTER
local BORDER_OFS_Y = 20

-- Logo im Spielfeld (IDLE-Zustand)
local LOGO_W       = 512
local LOGO_H       = 200
local LOGO_OFS_X   = 0
local LOGO_OFS_Y   = 0

-- HUD (Score, Züge, Timer) – relativ zu self.frame CENTER
local HUD_Y        = -240     -- Y-Offset nach oben vom CENTER
local HUD_L_X      = -140    -- Score: links
local HUD_C_X      = 0       -- Züge: mittig
local HUD_R_X      = 140     -- Timer: rechts

-- Highscore-Zeile (unter dem HUD)
local HS_Y         = 250     -- Y-Offset nach oben vom CENTER

-- Combo-Anzeige (über dem Spielfeld, unter dem HUD)
local COMBO_Y      = 230     -- Y-Offset nach oben vom CENTER

-- Controls-Widgets
local DD_W         = 120
local CHK_SIZE     = 20    -- CheckButton Größe

local BTN_W        = 144
local BTN_H        = 32

-- Zelleigenschaften
local CELL_MIN     = 24

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._fieldFrame    = nil
R._bgTex         = nil
R._borderFrame   = nil
R._borderTex     = nil
R._logoTex       = nil
R._controlsFrame = nil
R.state          = "IDLE"
R._lastDiff      = nil

R._board        = nil
R._cells        = {}
R._pool         = {}
R._cellSize     = 40
R._cols         = 0
R._rows         = 0
R._selected     = nil
R._gsRef        = nil

-- HUD
R._scoreFS      = nil
R._movesFS      = nil
R._timeFS       = nil
R._timeLbl      = nil
R._hsFS         = nil
R._comboFS      = nil
R._comboToken   = nil
R._hintFS       = nil
R._scoreBox     = nil
R._movesBox     = nil
R._bestBox      = nil
R._goldGrid     = nil

-- Controls
R._startBtn       = nil
R._newGameBtn     = nil
R._timerCheckbox  = nil

-- ============================================================
-- GEM-VISUAL (unverändert)
-- ============================================================
local function ApplyGemVisual(tex, gemDef)
    if not gemDef then return end
    tex:SetTexture(nil)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    if gemDef.type == "icon" then
        tex:SetTexture(gemDef.icon)
        tex:SetTexCoord(0, 1, 0, 1)
    elseif gemDef.type == "atlas" then
        tex:SetAtlas(gemDef.atlas, false)
    else -- "color"
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(gemDef.color[1], gemDef.color[2], gemDef.color[3], 1)
    end
end

-- ============================================================
-- CELL-FRAME / POOL (unverändert)
-- ============================================================
local function MakeCell(parent, size)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile=false, edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1},
    })
    f:SetBackdropColor(0.10, 0.10, 0.14, 0)
    f:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
    f._tex = tex
    local glow = f:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(f)
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetVertexColor(1, 0.9, 0.1, 0)
    glow:SetBlendMode("ADD")
    f._glow = glow
    f:Hide()
    return f
end

local function AcquireCell(parent, size)
    if #R._pool > 0 then
        local f = table.remove(R._pool)
        f:SetParent(parent)
        f:SetSize(size, size)
        f._tex:SetVertexColor(1,1,1,1)
        f._tex:SetAlpha(1)
        f._glow:SetVertexColor(1,0.9,0.1,0)
        f:SetAlpha(1)
        f:SetScale(1)
        f:SetScript("OnClick", nil)
        if f.animTick then f.animTick:SetScript("OnUpdate", nil); f.animTick = nil end
        f:Show()
        return f
    end
    local f = MakeCell(parent, size)
    f:Show()
    return f
end

local function ReleaseCell(f)
    f:Hide()
    f:SetScale(1)
    f:SetAlpha(1)
    f:SetScript("OnClick", nil)
    if f._tex  then f._tex:SetAlpha(1); f._tex:SetVertexColor(1,1,1,1) end
    if f._glow then f._glow:SetVertexColor(1,0.9,0.1,0) end
    if f.animTick then f.animTick:SetScript("OnUpdate", nil); f.animTick = nil end
    table.insert(R._pool, f)
end

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateBoard()
    self:_CreateHUD()
    self:_CreateControls()
    self:EnterIdleState()
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
        outerName = "ArcadiaNexus_M3_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._m3Container = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("MATCH3", ArcadiaNexus.M3_Engine, function(E)
            if E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local f  = self._canvas
    local ff = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ff:SetSize(BOARD_SIZE, BOARD_SIZE)
    ff:SetPoint("CENTER", f, "CENTER", FIELD_OFS_X, FIELD_OFS_Y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(M3_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    -- Eigener Frame mit FrameLevel +10 → liegt garantiert über allen Zell-Frames
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(BORDER_W, BORDER_H)
    borderFrame:SetPoint("CENTER", ff, "CENTER", BORDER_OFS_X, BORDER_OFS_Y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(M3_ASSETS.border)
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
        M3_ASSETS.logo,
        { w = LOGO_W, h = LOGO_H, x = LOGO_OFS_X, y = LOGO_OFS_Y }
    )
end

function R:_CreateBoard()
    -- Board-Frame wird innerhalb des _fieldFrame zentriert
    local ff = self._fieldFrame
    if not ff then return end
    local board = CreateFrame("Frame", nil, ff)
    board:SetSize(BOARD_SIZE, BOARD_SIZE)
    board:SetPoint("CENTER", ff, "CENTER", 0, 0)
    self._board = board
end

function R:_CreateHUD()
    local f  = self._canvas
    local L  = ArcadiaNexus.GetLocaleTable("MATCH3")
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Punkte") .. ": 0",
        shown = false,
    })
    self._movesBox, self._movesFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        text = (L["lbl_moves"] or "Züge") .. ": --",
        shown = false,
    })
    self._bestBox, self._hsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["lbl_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })

    local timeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLbl:SetPoint("CENTER", f, "CENTER", HUD_R_X, HUD_Y + 10)
    timeLbl:SetTextColor(0.75, 0.70, 0.55)
    timeLbl:SetText("|cffffd700" .. (L["lbl_time"] or "Zeit") .. "|r")
    timeLbl:Hide()

    local timeFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timeFS:SetPoint("CENTER", f, "CENTER", HUD_R_X, HUD_Y - 8)
    timeFS:SetText("--:--")
    timeFS:Hide()

    self._timeLbl = timeLbl
    self._timeFS  = timeFS

    local comboFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    comboFS:SetPoint("CENTER", f, "CENTER", 0, COMBO_Y)
    comboFS:SetTextColor(1, 0.85, 0)
    comboFS:SetText("")
    comboFS:Hide()
    self._comboFS = comboFS

    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", FIELD_OFS_X, FIELD_OFS_Y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("MATCH3")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    local S = ArcadiaNexus.M3_Settings
    local ddOptions = {
        { key = "easy",   label = L["diff_easy"]   },
        { key = "normal", label = L["diff_normal"]  },
        { key = "hard",   label = L["diff_hard"]    },
    }

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(DD_W, BTN_H)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        DD_W,
        "",
        ddOptions,
        function()
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            R._lastDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Timer-Checkbox (Segment 4)
    local chkHolder = CreateFrame("Frame", nil, cf)
    chkHolder:SetSize(CHK_SIZE + 4, CHK_SIZE + 20)
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)

    local chkLabel = chkHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkLabel:SetPoint("BOTTOM", chkHolder, "TOP", 0, -18)
    chkLabel:SetJustifyH("CENTER")
    chkLabel:SetText(L["lbl_timer_on"] or "Timer")

    local cb = CreateFrame("CheckButton", nil, chkHolder, "UICheckButtonTemplate")
    cb:SetSize(CHK_SIZE, CHK_SIZE)
    cb:SetPoint("CENTER", chkHolder, "CENTER", 0, -8)
    cb:SetScript("OnShow", function()
        local S2 = ArcadiaNexus.M3_Settings
        cb:SetChecked(S2 and S2:Get("timerActive") or false)
    end)
    cb:SetScript("OnClick", function()
        local S2 = ArcadiaNexus.M3_Settings
        if S2 then S2:Set("timerActive", cb:GetChecked()) end
    end)
    self._timerCheckbox = cb

    -- Start / Beenden Button (Segment 2)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], BTN_W, BTN_H)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.M3_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            local diff = R._lastDiff
                or (ArcadiaNexus.M3_Settings and ArcadiaNexus.M3_Settings:Get("difficulty"))
                or "easy"
            E:StartGame(diff)
        end
    end)
    self._startBtn = startBtn

    -- Neues Spiel Button (Segment 3)
    local newGameBtn = UI.CreateArcadiaButton(cf, L["btn_new_game"], BTN_W, BTN_H)
    newGameBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    newGameBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.M3_Engine
        if not E then return end
        local diff = R._lastDiff
            or (ArcadiaNexus.M3_Settings and ArcadiaNexus.M3_Settings:Get("difficulty"))
            or "easy"
        E:StartGame(diff)
    end)
    newGameBtn:Hide()
    self._newGameBtn = newGameBtn
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    StopAnimLoop()
    self.state    = "IDLE"
    self._gsRef   = nil
    self._selected = nil

    self:_ClearBoard()

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._comboFS     then self._comboFS:Hide()     end
    if self._newGameBtn  then self._newGameBtn:Hide()  end
    if self._timeLbl     then self._timeLbl:Hide()     end
    if self._timeFS      then self._timeFS:Hide()      end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MATCH3")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("MATCH3")["state_idle"] or "")
        self._hintFS:Show()
    end

    if self._scoreFS  then self._scoreFS:SetText("0")     end
    if self._movesFS  then self._movesFS:SetText("--")    end
    if self._hsFS     then self._hsFS:SetText("")         end
    if self._scoreBox then self._scoreBox:Hide() end
    if self._movesBox then self._movesBox:Hide() end
    if self._bestBox  then self._bestBox:Hide()  end
    if self._goldGrid then self._goldGrid:Hide() end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(gs)
    self.state    = "PLAYING"
    self._gsRef   = gs
    self._lastDiff = gs.difficulty
    self._cols    = gs.cols
    self._rows    = gs.rows
    self._cellSize = math.max(CELL_MIN, math.floor(BOARD_SIZE / math.max(gs.cols, gs.rows)))

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._comboFS then self._comboFS:Hide() end
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._newGameBtn then self._newGameBtn:Show() end
    if self._scoreBox then self._scoreBox:Show() end
    if self._movesBox then self._movesBox:Show() end
    if self._bestBox  then self._bestBox:Show()  end
    if self._goldGrid then self._goldGrid:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MATCH3")["btn_exit"])
    end

    -- Timer-Anzeige
    if self._timeLbl then
        if gs.timerActive then self._timeLbl:Show() else self._timeLbl:Hide() end
    end
    if self._timeFS then
        if gs.timerActive then
            self._timeFS:Show()
            self:_UpdateTimeDisplay(gs.timeLeft)
        else
            self._timeFS:Hide()
        end
    end

    self:_BuildBoard(gs)
    self:UpdateHUD(gs)
end

-- ============================================================
-- BOARD
-- ============================================================
function R:_BuildBoard(gs)
    self:_ClearBoard()
    local cs    = self._cellSize
    local board = self._board
    if not board then return end

    -- Board zentriert in _fieldFrame skalieren
    local actualW = cs * gs.cols
    local actualH = cs * gs.rows
    board:SetSize(actualW, actualH)
    board:ClearAllPoints()
    board:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)

    self._cells = {}
    for r = 1, gs.rows do
        self._cells[r] = {}
        for c = 1, gs.cols do
            local cell = AcquireCell(board, cs)
            cell:SetPoint("TOPLEFT", board, "TOPLEFT", (c-1)*cs, -(r-1)*cs)
            cell._row = r
            cell._col = c
            cell:SetScript("OnClick", function(self)
                local E = ArcadiaNexus.M3_Engine
                if E then E:OnCellClick(self._row, self._col) end
            end)
            self._cells[r][c] = cell
        end
    end
    self:_DrawGrid(gs)
end

function R:_ClearBoard()
    for r = 1, #self._cells do
        for c = 1, self._cells[r] and #self._cells[r] or 0 do
            local cell = self._cells[r][c]
            if cell then ReleaseCell(cell) end
        end
    end
    self._cells = {}
end

function R:_DrawGrid(gs)
    if not gs then return end
    local T = ArcadiaNexus.M3_Themes
    for r = 1, gs.rows do
        for c = 1, gs.cols do
            local cell = self._cells[r] and self._cells[r][c]
            if cell then
                cell._row = r
                cell._col = c
                local gemType = gs.grid[r] and gs.grid[r][c]
                if gemType and gemType > 0 then
                    local gemDef = T:GetGem(gs.theme, gemType)
                    ApplyGemVisual(cell._tex, gemDef)
                    cell._tex:SetAlpha(1)
                    cell:SetAlpha(1)
                    cell:Show()
                else
                    cell._tex:SetTexture(nil)
                    cell:SetAlpha(0.15)
                end
                -- Auswahl-Glow
                if self._selected and
                   self._selected.row == r and self._selected.col == c then
                    cell._glow:SetVertexColor(1, 0.9, 0.1, 0.40)
                    cell:SetBackdropBorderColor(1, 0.9, 0.1, 1)
                else
                    cell._glow:SetVertexColor(1, 0.9, 0.1, 0)
                    cell:SetBackdropBorderColor(0.22, 0.22, 0.28, 1)
                end
            end
        end
    end
end

-- ============================================================
-- HUD UPDATE
-- ============================================================
function R:UpdateHUD(gs)
    if not gs then return end
    local L = ArcadiaNexus.GetLocaleTable("MATCH3")

    if self._scoreFS then
        self._scoreFS:SetText((L["lbl_score"] or "Punkte") .. ": " .. tostring(gs.score))
    end

    if self._movesFS then
        local mv = gs.movesLeft
        local prefix = (L["lbl_moves"] or "Züge") .. ": "
        if mv <= 3 then
            self._movesFS:SetText(prefix .. "|cffff4444" .. mv .. "|r")
        elseif mv <= 7 then
            self._movesFS:SetText(prefix .. "|cffffff00" .. mv .. "|r")
        else
            self._movesFS:SetText(prefix .. tostring(mv))
        end
    end

    if gs.timerActive and self._timeFS then
        self:_UpdateTimeDisplay(gs.timeLeft)
    end

    if self._hsFS then
        self._hsFS:SetText((L["lbl_highscore"] or "Highscore") ..
            ": " .. tostring(gs.highScore or 0))
    end
end

function R:_UpdateTimeDisplay(secs)
    local text, level, r, g, b = ArcadiaNexus.Format.SecondsWithUrgency(secs, {
        warn = 60, crit = 30, padMinutes = false,
    })
    if level ~= "normal" then
        text = string.format("|cff%02x%02x%02x%s|r",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
    end
    self._timeFS:SetText(text)
end

-- ============================================================
-- AUSWAHL
-- ============================================================
function R:SetSelection(row, col)
    self._selected = { row = row, col = col }
    self:_DrawGrid(self._gsRef)
end

function R:ClearSelection()
    self._selected = nil
    self:_DrawGrid(self._gsRef)
end

-- ============================================================
-- HINT + COMBO
-- ============================================================
function R:ShowHint(text)
    if self._hintFS then self._hintFS:SetText(text or "") end
end

function R:ShowCombo(count)
    if not self._comboFS then return end
    local L = ArcadiaNexus.GetLocaleTable("MATCH3")
    self._comboFS:SetText((L["combo_prefix"] or "Combo x") .. tostring(count))
    self._comboFS:SetAlpha(1)
    self._comboFS:Show()
    local tok = {}
    self._comboToken = tok
    C_Timer.After(1.5, function()
        if self._comboToken ~= tok then return end
        UIFrameFadeOut(self._comboFS, 0.5, 1, 0)
        C_Timer.After(0.5, function()
            if self._comboToken ~= tok then return end
            self._comboFS:Hide()
            self._comboToken = nil
        end)
    end)
end

function R:HideCombo()
    self._comboToken = nil
    if self._comboFS then self._comboFS:Hide() end
end

-- ============================================================
-- GAME OVER
-- ============================================================
function R:ShowGameOver(gs)
    self.state    = "GAMEOVER"
    self._lastDiff = gs.difficulty
    if self._newGameBtn then self._newGameBtn:Hide() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("MATCH3")["btn_start"])
    end

    local L  = ArcadiaNexus.GetLocaleTable("MATCH3")
    local UI = ArcadiaNexus.UI

    local title, titleColor, result
    if gs.timedOut then
        title      = L["state_timeout"] or "Zeit abgelaufen!"
        titleColor = { 1, 0.4, 0 }
        result     = "LOSS"
    elseif gs.won then
        title      = L["state_gameover_win"] or "Gewonnen!"
        titleColor = { 0, 1, 0 }
        result     = "WIN"
    else
        title      = L["state_gameover_loss"] or "Keine Züge!"
        titleColor = { 1, 0.27, 0.27 }
        result     = "LOSS"
    end

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = title,
        titleColor = titleColor,
        score      = gs.score,
        highscore  = gs.highScore,
        gameId     = "MATCH3",
        difficulty = gs.difficulty,
        result     = result,
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.M3_Engine
            if E and R._lastDiff then E:StartGame(R._lastDiff) end
        end,
        onExit = function()
            local E = ArcadiaNexus.M3_Engine
            if E then E:StopGame() end
        end,
    })
end

-- ============================================================
-- ANIMATIONEN (inhaltlich unverändert, Anker-Frames identisch)
-- ============================================================

local function EaseInOut(t)
    return t < 0.5 and (2*t*t) or (1 - (-2*t+2)^2/2)
end

function R:AnimateSwap(r1, c1, r2, c2, gs, onDone)
    local cell1 = self._cells[r1] and self._cells[r1][c1]
    local cell2 = self._cells[r2] and self._cells[r2][c2]
    if not cell1 or not cell2 then
        if onDone then onDone() end; return
    end
    local cs = self._cellSize
    local sx1, sy1 = (c1-1)*cs, -(r1-1)*cs
    local sx2, sy2 = (c2-1)*cs, -(r2-1)*cs
    local dx, dy   = sx2-sx1, sy2-sy1
    local DURATION = 0.2
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / DURATION, 1)
        local f = EaseInOut(t)
        cell1:ClearAllPoints()
        cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx1 + dx*f, sy1 + dy*f)
        cell2:ClearAllPoints()
        cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx2 - dx*f, sy2 - dy*f)
        if t >= 1 then
            StopAnimLoop()
            cell1:ClearAllPoints(); cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx1, sy1)
            cell2:ClearAllPoints(); cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", sx2, sy2)
            R:_DrawGrid(gs)
            if onDone then onDone() end
        end
    end)
end

function R:AnimateInvalidSwap(r1, c1, r2, c2, onDone)
    local cell1 = self._cells[r1] and self._cells[r1][c1]
    if not cell1 then if onDone then onDone() end; return end
    local cs = self._cellSize
    local ox1, oy1 = (c1-1)*cs, -(r1-1)*cs
    local cell2    = self._cells[r2] and self._cells[r2][c2]
    local ox2, oy2 = cell2 and (c2-1)*cs or ox1, cell2 and -(r2-1)*cs or oy1
    local DURATION = 0.18
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / DURATION, 1)
        local shake = math.sin(t * math.pi * 6) * (1-t) * cs * 0.18
        if cell1 then
            cell1:ClearAllPoints()
            cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox1 + shake, oy1)
        end
        if cell2 then
            cell2:ClearAllPoints()
            cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox2 - shake, oy2)
        end
        if t >= 1 then
            StopAnimLoop()
            if cell1 then cell1:ClearAllPoints(); cell1:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox1, oy1) end
            if cell2 then cell2:ClearAllPoints(); cell2:SetPoint("TOPLEFT", R._board, "TOPLEFT", ox2, oy2) end
            if onDone then onDone() end
        end
    end)
end

function R:AnimatePulseAndFade(matches, gs, onDone)
    local cells = {}
    for key in pairs(matches) do
        local r, c = key:match("(%d+),(%d+)")
        r, c = tonumber(r), tonumber(c)
        local cell = self._cells[r] and self._cells[r][c]
        if cell then
            cells[#cells+1] = cell
            cell._glow:SetVertexColor(1, 0.9, 0.1, 0.5)
        end
    end
    if #cells == 0 then if onDone then onDone() end; return end
    local PULSE = 0.15; local FADE = 0.20
    local elapsed = 0; local phase = "pulse"
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        if phase == "pulse" then
            local t = math.min(elapsed / PULSE, 1)
            local sc = 1 + 0.2 * math.sin(t * math.pi)
            for _, c in ipairs(cells) do c:SetScale(sc) end
            if t >= 1 then phase="fade"; elapsed=0 end
        else
            local t = math.min(elapsed / FADE, 1)
            local a = 1 - t
            for _, c in ipairs(cells) do
                c:SetAlpha(a)
                c._glow:SetVertexColor(1,0.9,0.1,a*0.5)
            end
            if t >= 1 then
                StopAnimLoop()
                for _, c in ipairs(cells) do
                    c._tex:SetTexture(nil)
                    c:SetAlpha(1); c:SetScale(1)
                    c._glow:SetVertexColor(1,0.9,0.1,0)
                end
                if onDone then onDone() end
            end
        end
    end)
end

function R:AnimateFall(fallInfo, gs, onDone)
    if not fallInfo or not gs then
        self:_DrawGrid(gs)
        if onDone then onDone() end; return
    end
    local cs = self._cellSize
    local T  = ArcadiaNexus.M3_Themes

    local fallers = {}
    local maxDist = 0

    for c = 1, gs.cols do
        local col = fallInfo[c]
        if col then
            for _, info in ipairs(col) do
                local cell = self._cells[info.toRow] and self._cells[info.toRow][c]
                if cell then
                    -- Textur IMMER setzen (nicht nur isNew):
                    -- nach dem Fade zeigen Zellen noch die alten Icons.
                    local gemDef = T:GetGem(gs.theme, info.gemType)
                    ApplyGemVisual(cell._tex, gemDef)
                    cell._tex:SetAlpha(1)
                    cell:SetAlpha(1)
                    cell:SetScale(1)

                    local toY   = -(info.toRow - 1) * cs
                    local fromY = -(info.fromRow - 1) * cs
                    local isNew = info.fromRow <= 0

                    -- Neue Gems: unsichtbar starten, erst beim Eintreten ins Board einblenden
                    if isNew then cell:SetAlpha(0) end

                    if fromY ~= toY then
                        cell:ClearAllPoints()
                        cell:SetPoint("TOPLEFT", R._board, "TOPLEFT", (c-1)*cs, fromY)
                        local dist = math.abs(toY - fromY)
                        if dist > maxDist then maxDist = dist end
                        local rowDelay = (gs.rows - info.toRow) * 0.012
                        fallers[#fallers+1] = {
                            cell  = cell,
                            fromY = fromY,
                            toY   = toY,
                            col   = c,
                            dist  = dist,
                            delay = rowDelay,
                            isNew = isNew,
                        }
                    end
                end
            end
        end
    end

    if #fallers == 0 then
        self:_DrawGrid(gs)
        if onDone then onDone() end; return
    end

    local FALL_DUR = 0.22   -- Basis-Fallzeit für eine Zelle
    local elapsed  = 0
    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local allDone = true

        for _, fl in ipairs(fallers) do
            local localElapsed = elapsed - fl.delay

            if localElapsed >= 0 then
                local dur  = FALL_DUR * math.max(0.3, fl.dist / maxDist)
                local t    = math.min(localElapsed / dur, 1)
                local curY = fl.fromY + (fl.toY - fl.fromY) * (t * t)
                fl.cell:ClearAllPoints()
                fl.cell:SetPoint("TOPLEFT", R._board, "TOPLEFT", (fl.col-1)*cs, curY)
                -- Neue Gems: einblenden sobald sie die obere Board-Kante erreichen (curY <= 0)
                if fl.isNew then
                    fl.cell:SetAlpha(curY <= 0 and 1 or 0)
                end
                if t < 1 then allDone = false end
            else
                allDone = false
            end
        end

        if allDone then
            StopAnimLoop()
            R:_DrawGrid(gs)
            if onDone then onDone() end
        end
    end)
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "MATCH3",
    label     = "Match-3",
    category  = "DENKSPIELE",
    renderer  = "M3_Renderer",
    engine    = "M3_Engine",
    container = "_m3Container",
})
