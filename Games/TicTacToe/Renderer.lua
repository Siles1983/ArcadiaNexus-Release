-- ============================================================
--  ArcadiaNexus
--  Games/TicTacToe/Renderer.lua
--  Version: 3.0.0  (Blueprint v2 – nach Match-3/Memory-Muster)
--
--  Layout-Strategie:
--    - self.frame bleibt der panelgroße Lifecycle-Container
--    - Alle Layout-Elemente sitzen auf einem zentrierten 600x498-Canvas
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD (Zug-Anzeige) über dem Spielfeld
--    - Controls-Leiste am BOTTOM des Canvas
--      Links:  Dropdown Grid-Größe
--      Mitte:  Start / Beenden Button (togglend)
--      Rechts: Dropdown Schwierigkeit
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--
--  Spielstart:
--    Auswahl über Dropdowns (Grid-Größe + Schwierigkeit),
--    dann explizit über Start-Button. Kein Auto-Start mehr.
--
--  Unverändert übernommen:
--    ApplySymbol, RenderBoard, UpdateBoard,
--    HighlightWinningLine, ShowGameOver
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TTT_Renderer = {}
local R = ArcadiaNexus.TTT_Renderer

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "TicTacToe.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            text:SetPoint("CENTER")
            btn.text = text
            local atlTex = btn:CreateTexture(nil, "ARTWORK")
            atlTex:Hide()
            btn.atlTex = atlTex
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:Enable()
            btn:SetScript("OnClick", nil)
            btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btn:SetAlpha(1)
            btn:SetScale(1)
            btn._gridX = nil
            btn._gridY = nil
            if btn.text then btn.text:SetText("") end
            if btn.atlTex then
                btn.atlTex:Hide()
                btn.atlTex:SetTexture(nil)
                btn.atlTex:SetTexCoord(0, 1, 0, 1)
                btn.atlTex:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    board_size   = 430,
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
    logo_w       = 321,
    logo_h       = 333,
    logo_ofs_x   = 0,
    logo_ofs_y   = 15,
    hud_y        = 0,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    sound_win    = 888,
    sound_draw   = 8959,
    sound_loss   = 847,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local TTT_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\TicTacToe\\assets\\background\\background_tictactoe",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\TicTacToe\\assets\\logo\\logo_tictactoe",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\TicTacToe\\assets\\border\\border_tictactoe",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================



-- HUD (Zug-Anzeige) – relativ zum Canvas-CENTER

-- ============================================================
-- SOUNDS
-- ============================================================

local function PlayGameSound(result)
    local S = ArcadiaNexus.TicTacToeSettings
    if not S or not S:Get("soundEnabled") then return end
    if result == "WIN"  and S:Get("soundOnWin")  then PlaySound(CFG.sound_win,  "SFX") end
    if result == "DRAW" and S:Get("soundOnDraw") then PlaySound(CFG.sound_draw, "SFX") end
    if result == "LOSS" and S:Get("soundOnLoss") then PlaySound(CFG.sound_loss, "SFX") end
end

-- ============================================================
-- STATE
-- ============================================================
R.frame         = nil
R._canvas       = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"

-- Spielfeld-Daten
R.buttons         = {}
R.boardSize       = 3
R.boardPixelSize  = 0
R.boardStartX     = 0
R.boardStartY     = 0
R.winLineFrame    = nil
R.winLineTexture  = nil
R.lastResult      = nil

-- Controls
R._startBtn       = nil
R._hintFS         = nil
R._hudFS          = nil

-- Dropdown-State (persistiert zwischen Runden)
R._lastGridSize   = 3
R._lastDifficulty = "easy"

-- ============================================================
-- SYMBOL-HELPER (unverändert)
-- ============================================================
local function ApplySymbol(btn, symbolDef)
    if not symbolDef then
        btn.text:SetText("")
        btn.atlTex:Hide()
        return
    end
    if symbolDef.mode == "TEXT" then
        btn.atlTex:Hide()
        btn.text:SetText(symbolDef.text or "")
        btn.text:SetTextColor(symbolDef.r or 1, symbolDef.g or 1, symbolDef.b or 1, 1)
    elseif symbolDef.mode == "SPRITE" then
        btn.text:SetText("")
        btn.atlTex:SetTexture(symbolDef.path)
        btn.atlTex:SetTexCoord(symbolDef.left, symbolDef.right, symbolDef.top, symbolDef.bottom)
        btn.atlTex:Show()
    else
        btn.text:SetText("")
        btn.atlTex:Hide()
    end
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
    self:_CreateHUD()
    self:_CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine

    Engine:On("GAME_STARTED", function(board)
        R.state = "PLAYING"
        R:OnGameStarted(board)
    end)

    Engine:On("BOARD_UPDATED", function()
        R:UpdateBoard()
    end)

    Engine:On("GAME_OVER", function(result)
        R:ShowGameOver(result)
    end)

    Engine:On("WIN_LINE", function(line)
        R:HighlightWinningLine(line)
    end)

    Engine:On("GAME_STOPPED", function()
        R:EnterIdleState()
    end)
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
        outerName = "ArcadiaNexus_TTT_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._tttContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("TICTACTOE", ArcadiaNexus.TTT_Engine, function(E)
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
    ff:SetSize(CFG.board_size, CFG.board_size)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(TTT_ASSETS.bg)
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
    tex:SetTexture(TTT_ASSETS.border)
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
        TTT_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- HUD (Zug-Anzeige)
-- ============================================================
function R:_CreateHUD()
    local canvas = self._canvas

    local hudFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hudFS:SetPoint("CENTER", canvas, "CENTER", 0, CFG.hud_y)
    hudFS:SetJustifyH("CENTER")
    hudFS:SetText("")
    hudFS:Hide()
    self._hudFS = hudFS

    local hintFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_UpdateHUD(text, color)
    if not self._hudFS then return end
    if text then
        self._hudFS:SetText(text)
        if color then
            self._hudFS:SetTextColor(color[1], color[2], color[3])
        else
            self._hudFS:SetTextColor(1, 1, 1)
        end
        self._hudFS:Show()
    else
        self._hudFS:Hide()
    end
end

-- ============================================================
-- CONTROLS (zwei Dropdowns + Start/Beenden + Neues Spiel)
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- ── Segment 1: Grid-Größe + Schwierigkeit nebeneinander ──
    local ddGap = 10
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(CFG.dd_w * 2 + ddGap, CFG.btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddGridAnchor = CreateFrame("Frame", nil, pair)
    ddGridAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddGridAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)

    UI.CreateSimpleDropdown(
        ddGridAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "3", label = L["size_3x3"] or "3 x 3" },
            { key = "4", label = L["size_4x4"] or "4 x 4" },
            { key = "5", label = L["size_5x5"] or "5 x 5" },
        },
        function()
            return tostring(R._lastGridSize or 3)
        end,
        function(key)
            R._lastGridSize = tonumber(key) or 3
        end
    )

    local ddDiffAnchor = CreateFrame("Frame", nil, pair)
    ddDiffAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddDiffAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)

    UI.CreateSimpleDropdown(
        ddDiffAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]  or "Einfach" },
            { key = "normal", label = L["diff_normal"] or "Normal"  },
            { key = "hard",   label = L["diff_hard"]   or "Schwer"  },
        },
        function()
            return R._lastDifficulty or "easy"
        end,
        function(key)
            R._lastDifficulty = key
        end
    )

    -- ── Segment 2: Toggle-Button Start / Beenden (x = 0) ──
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.TTT_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            local gs = R._lastGridSize or 3
            E:StartGame({
                boardSize    = gs,
                winLength    = gs,
                aiDifficulty = R._lastDifficulty or "easy",
            })
        end
    end)
    self._startBtn = startBtn
end

function R:_EnsureCellPool()
    if not self._cellPool then
        self._cellPool = CreateCellPool()
    end
end

function R:_ClearBoardCells()
    self:_EnsureCellPool()
    self._cellPool:ReleaseAll()
    self.buttons = {}
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"

    self:_ClearBoardCells()

    self:ClearWinningLine()

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hudFS       then self._hudFS:Hide()       end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end
    if self._goldGrid    then self._goldGrid:Hide()    end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("TICTACTOE")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText("")
        self._hintFS:Hide()
    end
end

-- ============================================================
-- EVENT-HANDLER: Spiel gestartet
-- ============================================================
function R:OnGameStarted(board)
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._goldGrid then self._goldGrid:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("TICTACTOE")["btn_exit"])
    end

    self:RenderBoard(board)
    self:_UpdateHUD(ArcadiaNexus.GetLocaleTable("TICTACTOE")["lbl_your_turn"])
end

-- ============================================================
-- BOARD RENDERN (Kernlogik unverändert)
-- ============================================================
function R:ClearWinningLine()
    if self.winLineTexture then
        if self.winLineTexture.pulseAnim then
            self.winLineTexture.pulseAnim:Stop()
        end
        self.winLineTexture:Hide()
    end
end

function R:RenderBoard(board)
    self:ClearWinningLine()

    self.boardSize = board.size
    self:_ClearBoardCells()

    local cellSize = CFG.board_size / self.boardSize
    self.boardPixelSize = CFG.board_size
    self:_EnsureCellPool()

    for y = 1, self.boardSize do
        for x = 1, self.boardSize do
            local btn = self._cellPool:Acquire({})
            btn:SetParent(self._fieldFrame)
            btn:SetSize(cellSize - 4, cellSize - 4)
            btn:SetPoint("TOPLEFT", self._fieldFrame, "TOPLEFT",
                (x - 1) * cellSize + 2,
                -((y - 1) * cellSize + 2))
            btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btn._gridX = x
            btn._gridY = y
            btn:SetScript("OnClick", function()
                ArcadiaNexus.TTT_Engine:HandlePlayerMove(btn._gridX, btn._gridY)
            end)

            local atlasPad = math.floor(cellSize * 0.12)
            btn.atlTex:ClearAllPoints()
            btn.atlTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",      atlasPad, -atlasPad)
            btn.atlTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -atlasPad,  atlasPad)
            btn.atlTex:Hide()
            btn.text:SetText("")
            btn:Enable()
            btn:Show()

            table.insert(self.buttons, btn)
        end
    end

    self:UpdateBoard()
end

-- ============================================================
-- BOARD AKTUALISIEREN (unverändert)
-- ============================================================
function R:UpdateBoard()
    local board = ArcadiaNexus.TTT_Engine.activeGame
        and ArcadiaNexus.TTT_Engine.activeGame:GetBoardState()
    if not board then return end

    local symbols = { player1 = nil, player2 = nil }
    if ArcadiaNexus.TicTacToeSymbolResolver then
        symbols = ArcadiaNexus.TicTacToeSymbolResolver:Resolve()
    else
        symbols.player1 = { mode = "TEXT", text = "X", r = 0.20, g = 0.60, b = 1.00 }
        symbols.player2 = { mode = "TEXT", text = "O", r = 1.00, g = 0.25, b = 0.25 }
    end

    local index = 1
    for y = 1, board.size do
        for x = 1, board.size do
            local value = board.cells[y][x]
            local btn   = self.buttons[index]
            if btn then
                if value == 1 then
                    ApplySymbol(btn, symbols.player1)
                elseif value == 2 then
                    ApplySymbol(btn, symbols.player2)
                else
                    btn.text:SetText("")
                    btn.atlTex:Hide()
                end
            end
            index = index + 1
        end
    end
end

-- ============================================================
-- GAME OVER
-- ============================================================
function R:ShowGameOver(result)
    local L  = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local UI = ArcadiaNexus.UI
    self.state      = "GAMEOVER"
    self.lastResult = result

    for _, btn in ipairs(self.buttons) do btn:Disable() end

    if self._startBtn then
        self._startBtn:SetLabel(L["btn_start"])
    end
    if self._hudFS then self._hudFS:Hide() end

    UI.ShowArcadeResult(self._fieldFrame, {
        gameId     = "TICTACTOE",
        difficulty = self._lastDifficulty or "easy",
        result     = result,
        titleKeys  = {
            WIN  = { "lbl_win" },
            LOSS = { "lbl_loss" },
            DRAW = { "lbl_draw" },
        },
        titleFallbacks = {
            WIN  = "Sieg!",
            LOSS = "Niederlage!",
            DRAW = "Unentschieden!",
        },
        L = L,
        onRetry = function()
            local E = ArcadiaNexus.TTT_Engine
            if not E then return end
            local gs = R._lastGridSize or 3
            E:StartGame({
                boardSize    = gs,
                winLength    = gs,
                aiDifficulty = R._lastDifficulty or "easy",
            })
        end,
        onExit = function()
            local E = ArcadiaNexus.TTT_Engine
            if E then E:StopGame() end
        end,
    })
    PlayGameSound(result)
end

-- ============================================================
-- GEWINNLINIE (unverändert, Anker auf _fieldFrame angepasst)
-- ============================================================
function R:HighlightWinningLine(line)
    if not line or #line < 2 then return end

    local cellSize = CFG.board_size / self.boardSize
    local p1 = line[1]
    local p2 = line[#line]

    -- Koordinaten relativ zu _fieldFrame TOPLEFT
    local startX  = (p1.x - 0.5) * cellSize
    local startY  = (p1.y - 0.5) * cellSize
    local endX    = (p2.x - 0.5) * cellSize
    local endY    = (p2.y - 0.5) * cellSize

    local dx      = endX - startX
    local dy      = startY - endY
    local length  = math.sqrt(dx * dx + dy * dy)
    local centerX = (startX + endX) / 2
    local centerY = (startY + endY) / 2
    local angle   = math.atan2(dy, dx)

    if not self.winLineFrame then
        local frame = CreateFrame("Frame", nil, self._fieldFrame)
        frame:SetAllPoints(self._fieldFrame)
        frame:SetFrameLevel(self._fieldFrame:GetFrameLevel() + 20)
        self.winLineFrame = frame

        local tex = frame:CreateTexture(nil, "OVERLAY")
        self.winLineTexture = tex

        local pulse = tex:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.4)
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

    tex:SetSize(length, 6)
    tex:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", centerX, -centerY)
    tex:SetRotation(angle)
    tex:SetAlpha(1)
    tex:Show()
    tex.pulseAnim:Play()
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "TICTACTOE",
    label     = "Tic Tac Toe",
    renderer  = "TTT_Renderer",
    engine    = "TTT_Engine",
    container = "_tttContainer",
    category  = "GESCHICK",
})
