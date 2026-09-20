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
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btn:SetAlpha(1)
            btn:SetScale(1)
            if btn._popAnim then
                btn._popAnim:Stop()
            end
            btn._gridX = nil
            btn._gridY = nil
            btn._hovering = nil
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
    hud_turn_w     = 200,
    hud_turn_h     = 26,
    hud_turn_x     = -150,
    hud_turn_y     = 228,
    hud_turn_alpha = 0.75,
    hud_series_w     = 124,
    hud_series_h     = 26,
    hud_series_x     = 196,
    hud_series_y     = 228,
    hud_series_alpha = 0.75,
    dd_w         = 110,
    btn_w        = 144,
    btn_h        = 32,
    sound_win    = 888,
    sound_draw   = 8959,
    sound_loss   = 847,
    sound_place  = 856,
    text_symbol_fill = 0.70,
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



-- ============================================================
-- SOUNDS
-- ============================================================

local function PlayGameSound(result)
    local S = ArcadiaNexus.TicTacToeSettings
    if not S or not S:Get("soundEnabled") then return end
    if result == "PLACE" and S:Get("soundOnPlace") then PlaySound(CFG.sound_place, "SFX") end
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
R._lastWinLength  = 3
R._lastDifficulty = "easy"
R._lastStarter    = "you"

-- ============================================================
-- SYMBOL-HELPER (unverändert)
-- ============================================================
local function ApplySymbol(btn, symbolDef, alpha)
    alpha = alpha or 1
    if not symbolDef then
        btn.text:SetText("")
        btn.atlTex:Hide()
        return
    end
    if symbolDef.mode == "TEXT" then
        btn.atlTex:Hide()
        local h = btn:GetHeight() or 40
        local size = math.floor(h * (CFG.text_symbol_fill or 0.70))
        if size < 22 then size = 22 end
        local path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        btn.text:SetFont(path, size, "OUTLINE")
        btn.text:SetText(symbolDef.text or "")
        btn.text:SetTextColor(symbolDef.r or 1, symbolDef.g or 1, symbolDef.b or 1, alpha)
    elseif symbolDef.mode == "SPRITE" then
        btn.text:SetText("")
        btn.atlTex:SetTexture(symbolDef.path)
        btn.atlTex:SetTexCoord(symbolDef.left, symbolDef.right, symbolDef.top, symbolDef.bottom)
        btn.atlTex:SetVertexColor(1, 1, 1, alpha)
        btn.atlTex:Show()
    else
        btn.text:SetText("")
        btn.atlTex:Hide()
    end
end

local function ResolveSymbols()
    if ArcadiaNexus.TicTacToeSymbolResolver then
        return ArcadiaNexus.TicTacToeSymbolResolver:Resolve()
    end
    return {
        player1 = { mode = "TEXT", text = "X", r = 0.20, g = 0.60, b = 1.00 },
        player2 = { mode = "TEXT", text = "O", r = 1.00, g = 0.25, b = 0.25 },
    }
end

local function CellCanPlay(board, x, y)
    local E = ArcadiaNexus.TTT_Engine
    if not board or board.gameOver then return false end
    if not E then return false end
    if board.cells[y] and board.cells[y][x] ~= 0 then return false end
    local mp = E.mode and E.mode ~= "hotseat"
    local myTurn = (board.turn or 1) == (board.localSeat or 1)
    local thinking = (not mp) and E._busy
    return myTurn and not thinking
end

local function HoverSymbol(board)
    local symbols = ResolveSymbols()
    local seat = board and board.localSeat or 1
    if seat == 2 then
        return symbols.player2
    end
    return symbols.player1
end

local function PlayCellPop(btn)
    if not btn then return end
    if btn._popAnim then
        btn._popAnim:Stop()
    else
        local ag = btn:CreateAnimationGroup()
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.45)
        fade:SetToAlpha(1)
        fade:SetDuration(0.18)
        fade:SetSmoothing("OUT")
        btn._popAnim = ag
    end
    btn:SetAlpha(1)
    btn._popAnim:Play()
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
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then
            return
        end
        ArcadiaNexus.GameSession:HandleRendererHide("TICTACTOE", ArcadiaNexus.TTT_Engine, function(E)
            if E.mode ~= "hotseat" and (E.state == "PLAYING" or E.state == "LOBBY" or E.state == "FINISHED") then
                E:HideView()
            elseif E.state ~= "IDLE" or E.activeGame then
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
    if self._turnBox then return end
    local UI = ArcadiaNexus.UI
    local canvas = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("TICTACTOE")

    local hintFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS

    if not UI or not UI.CreateHudStatBox then return end
    self._turnBox, self._hudFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_turn_w, h = CFG.hud_turn_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_turn_x, y = CFG.hud_turn_y,
        alpha = CFG.hud_turn_alpha,
        text = L["lbl_your_turn"] or "Du bist dran",
        shown = false,
    })
    self._seriesBox, self._seriesFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_series_w, h = CFG.hud_series_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_series_x, y = CFG.hud_series_y,
        alpha = CFG.hud_series_alpha,
        text = "0 : 0",
        shown = false,
    })
end

function R:_SetHudVisible(visible)
    if self._turnBox then
        if visible then self._turnBox:Show() else self._turnBox:Hide() end
    end
    local E = ArcadiaNexus.TTT_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    if self._seriesBox then
        if visible and not mp then self._seriesBox:Show() else self._seriesBox:Hide() end
    end
end

function R:_RefreshSeriesHud()
    local E = ArcadiaNexus.TTT_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    if not self._seriesBox then return end
    if mp or not E or not E.GetSeries then
        self._seriesBox:Hide()
        return
    end
    local s = E:GetSeries()
    if self._seriesFS and s then
        self._seriesFS:SetText(string.format("%d : %d", s.you or 0, s.opp or 0))
    end
    self._seriesBox:Show()
end

function R:_RefreshTurnHud(board)
    local L = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local E = ArcadiaNexus.TTT_Engine
    self:_RefreshSeriesHud()
    if not self._hudFS then return end
    if not board or board.gameOver then
        if self._turnBox then self._turnBox:Hide() end
        return
    end
    local mp = E and E.mode and E.mode ~= "hotseat"
    if self._turnBox then self._turnBox:Show() end
    local myTurn = board.turn == (board.localSeat or 1)
    if myTurn and not (not mp and E and E._busy) then
        self._hudFS:SetText(L["lbl_your_turn"] or "Du bist dran")
    elseif mp then
        self._hudFS:SetText(L["lbl_opp_turn"] or "Gegner ist dran")
    else
        self._hudFS:SetText(L["lbl_ai_turn"] or "KI denkt nach...")
    end
end

-- ============================================================
-- CONTROLS (Größe, Gewinnlänge, Start, Schwierigkeit, Starter)
-- ============================================================
local function ClearOpts(opts)
    for i = #opts, 1, -1 do
        opts[i] = nil
    end
end

-- Name folgt der Match-Konvention (lokales KI-Spiel). Kein 2P-Hotseat.
function R:_HotseatConfig(extra)
    local Logic = ArcadiaNexus.TicTacToeLogic
    local gs = self._lastGridSize or 3
    local wl = gs
    if Logic and Logic.ClampWinLength then
        wl = Logic.ClampWinLength(gs, self._lastWinLength or gs)
    end
    local cfg = {
        boardSize    = gs,
        winLength    = wl,
        aiDifficulty = self._lastDifficulty or "easy",
        firstPlayer  = self._lastStarter or "you",
        mode         = "hotseat",
    }
    if extra then
        for k, v in pairs(extra) do
            cfg[k] = v
        end
    end
    return cfg
end

function R:_SyncWinLengthOptions()
    local L = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local Logic = ArcadiaNexus.TicTacToeLogic
    local size = self._lastGridSize or 3
    local opts = self._winOpts
    if not opts then
        opts = {}
        self._winOpts = opts
    end
    ClearOpts(opts)
    for n = 3, size do
        opts[#opts + 1] = {
            key = tostring(n),
            label = L["win_" .. n] or tostring(n),
            tooltip = L["tip_win_" .. n] or "",
        }
    end
    if Logic and Logic.ClampWinLength then
        self._lastWinLength = Logic.ClampWinLength(size, self._lastWinLength or size)
    elseif (self._lastWinLength or 3) > size then
        self._lastWinLength = size
    end
    if self._ddWin and self._ddWin.RefreshDisplay then
        self._ddWin:RefreshDisplay()
    end
    if self._ddWin and self._ddWin.SetEnabled then
        self._ddWin:SetEnabled(size > 3)
    end
end

function R:_SetSetupVisible(visible)
    local frames = self._setupFrames
    if not frames then return end
    for i = 1, #frames do
        local f = frames[i]
        if f then
            if visible then f:Show() else f:Hide() end
        end
    end
end

function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "wide5")
    local cf = bar.frame
    self._controlsFrame = cf

    local function DdAnchor(seg)
        local anchor = CreateFrame("Frame", nil, cf)
        anchor:SetSize(CFG.dd_w, CFG.btn_h)
        anchor:SetPoint("CENTER", cf, "CENTER", bar.segX[seg], bar.y.dropdownOfs)
        return anchor
    end

    local ddGridAnchor = DdAnchor(1)
    UI.CreateSimpleDropdown(
        ddGridAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "3", label = L["size_3x3"] or "3 x 3", tooltip = L["tip_size_3"] },
            { key = "4", label = L["size_4x4"] or "4 x 4", tooltip = L["tip_size_4"] },
            { key = "5", label = L["size_5x5"] or "5 x 5", tooltip = L["tip_size_5"] },
        },
        function()
            return tostring(R._lastGridSize or 3)
        end,
        function(key)
            R._lastGridSize = tonumber(key) or 3
            R:_SyncWinLengthOptions()
        end,
        { title = L["tip_size_title"] or L["lbl_board_size"], text = L["tip_size"] }
    )

    local ddWinAnchor = DdAnchor(2)
    self._winOpts = {
        { key = "3", label = L["win_3"] or "3", tooltip = L["tip_win_3"] },
    }
    self._ddWin = UI.CreateSimpleDropdown(
        ddWinAnchor,
        0, 0,
        CFG.dd_w,
        "",
        self._winOpts,
        function()
            return tostring(R._lastWinLength or 3)
        end,
        function(key)
            R._lastWinLength = tonumber(key) or 3
        end,
        { title = L["tip_win_title"] or L["lbl_win_length"], text = L["tip_win"] }
    )
    self:_SyncWinLengthOptions()

    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.TTT_Engine
        if not E then return end
        if R.state == "PLAYING" and E.mode and E.mode ~= "hotseat" then
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.ShowEndRoundConfirm then
                Shell.ShowEndRoundConfirm(function()
                    ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
                    E:StopGame()
                end, R._fieldFrame)
                return
            end
        end
        if R.state == "PLAYING" or R.state == "LOBBY" or R.state == "FINISHED" or R.state == "GAMEOVER" then
            E:StopGame()
        else
            E:StartGame(R:_HotseatConfig())
        end
    end)
    self._startBtn = startBtn

    local ddDiffAnchor = DdAnchor(4)
    UI.CreateSimpleDropdown(
        ddDiffAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]   or "Einfach", tooltip = L["tip_diff_easy"] },
            { key = "normal", label = L["diff_normal"] or "Normal",  tooltip = L["tip_diff_normal"] },
            { key = "hard",   label = L["diff_hard"]   or "Schwer",  tooltip = L["tip_diff_hard"] },
        },
        function()
            return R._lastDifficulty or "easy"
        end,
        function(key)
            R._lastDifficulty = key
        end,
        { title = L["tip_diff_title"] or L["lbl_difficulty"], text = L["tip_diff"] }
    )

    local ddStarterAnchor = DdAnchor(5)
    UI.CreateSimpleDropdown(
        ddStarterAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "you",    label = L["start_you"]    or "Du zuerst", tooltip = L["tip_start_you"] },
            { key = "ai",     label = L["start_ai"]     or "KI zuerst", tooltip = L["tip_start_ai"] },
            { key = "random", label = L["start_random"] or "Zufall",    tooltip = L["tip_start_random"] },
        },
        function()
            return R._lastStarter or "you"
        end,
        function(key)
            R._lastStarter = key
        end,
        { title = L["tip_start_title"], text = L["tip_start"] }
    )

    self._setupFrames = { ddGridAnchor, ddWinAnchor, ddDiffAnchor, ddStarterAnchor }
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
    self:_SetHudVisible(false)
    self._seenMoveKey = nil
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end
    if self._goldGrid    then self._goldGrid:Hide()    end

    self:_SetSetupVisible(true)
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("TICTACTOE")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText("")
        self._hintFS:Hide()
    end
end

function R:Render()
    local E = ArcadiaNexus.TTT_Engine
    if not E or E.mode == "hotseat" then return end
    local v = E:GetView()
    if not v then return end
    if v.state == "IDLE" or v.state == "ABORTED" then
        self:EnterIdleState()
        return
    end
    local loc = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    self:_SetSetupVisible(false)
    if self._startBtn then
        self._startBtn:SetLabel(loc["btn_exit"] or "Beenden")
        self._startBtn:Show()
    end
    if v.state == "LOBBY" then
        self.state = "LOBBY"
        self:_ClearBoardCells()
        self:ClearWinningLine()
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
        self:_SetHudVisible(false)
        if self._logoTex then self._logoTex:Show() end
        if self._goldGrid then self._goldGrid:Hide() end
        return
    end
    if v.state == "PLAYING" or v.state == "FINISHED" then
        local board = E:GetBoardState()
        if not board then return end
        if self.state ~= "PLAYING" and self.state ~= "GAMEOVER" and self.state ~= "FINISHED" then
            self.state = "PLAYING"
            self:OnGameStarted(board)
        else
            self:UpdateBoard()
        end
        self:_RefreshTurnHud(board)
        if board.gameOver and board.winningLine then
            self.lastResult = board.result
            self:HighlightWinningLine(board.winningLine)
        end
        if v.state == "FINISHED" then
            self.state = "FINISHED"
        end
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

    self._seenMoveKey = nil
    self:RenderBoard(board)
    self:_RefreshTurnHud(board)
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
            btn:SetScript("OnEnter", function(self)
                local E = ArcadiaNexus.TTT_Engine
                local board = E and E.GetBoardState and E:GetBoardState()
                if not CellCanPlay(board, self._gridX, self._gridY) then return end
                self._hovering = true
                ApplySymbol(self, HoverSymbol(board), 0.38)
            end)
            btn:SetScript("OnLeave", function(self)
                self._hovering = nil
                local E = ArcadiaNexus.TTT_Engine
                local board = E and E.GetBoardState and E:GetBoardState()
                if board and board.cells[self._gridY] and board.cells[self._gridY][self._gridX] == 0 then
                    ApplySymbol(self, nil)
                end
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
    local E = ArcadiaNexus.TTT_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    if not board then return end

    local symbols = ResolveSymbols()

    local mp = E.mode and E.mode ~= "hotseat"
    local myTurn = (board.turn or 1) == (board.localSeat or 1)
    local thinking = (not mp) and E._busy
    local lm = board.lastMove
    local lastKey = nil
    if lm and lm.x and lm.y then
        lastKey = tostring(lm.x) .. ":" .. tostring(lm.y) .. ":" .. tostring(board.moveCount or 0)
    end
    local popCell = nil
    if lastKey and lastKey ~= self._seenMoveKey then
        self._seenMoveKey = lastKey
        popCell = lastKey
        PlayGameSound("PLACE")
    end

    local winSet = {}
    if board.gameOver and board.winningLine then
        for i = 1, #board.winningLine do
            local p = board.winningLine[i]
            if p and p.x and p.y then
                winSet[p.x .. ":" .. p.y] = true
            end
        end
    end
    local winColor = { 0.12, 0.42, 0.18, 1 }
    if board.result == "LOSS" then
        winColor = { 0.48, 0.12, 0.12, 1 }
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
                elseif btn._hovering and CellCanPlay(board, x, y) then
                    ApplySymbol(btn, HoverSymbol(board), 0.38)
                else
                    ApplySymbol(btn, nil)
                end
                local key = x .. ":" .. y
                local isWin = winSet[key]
                local isLast = lm and lm.x == x and lm.y == y
                if isWin then
                    btn:SetBackdropColor(winColor[1], winColor[2], winColor[3], winColor[4])
                    btn:SetAlpha(1)
                    if popCell and isLast then
                        PlayCellPop(btn)
                    end
                elseif isLast then
                    btn:SetBackdropColor(0.42, 0.34, 0.12, 1)
                    btn:SetAlpha(1)
                    if popCell then
                        PlayCellPop(btn)
                    end
                else
                    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
                    if board.gameOver and value ~= 0 then
                        btn:SetAlpha(0.55)
                    else
                        btn:SetAlpha(1)
                    end
                end
                local occupied = value ~= 0
                local canPlay = not board.gameOver
                    and not occupied
                    and myTurn
                    and not thinking
                if canPlay then btn:Enable() else btn:Disable() end
            end
            index = index + 1
        end
    end

    if board.gameOver then
        self.lastResult = board.result
        if board.winningLine then
            self:HighlightWinningLine(board.winningLine)
        end
    end
    self:_RefreshTurnHud(board)
end

-- ============================================================
-- GAME OVER
-- ============================================================
function R:ShowGameOver(result)
    local L  = ArcadiaNexus.GetLocaleTable("TICTACTOE")
    local UI = ArcadiaNexus.UI
    local E  = ArcadiaNexus.TTT_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    self.state      = "GAMEOVER"
    self.lastResult = result

    for _, btn in ipairs(self.buttons) do btn:Disable() end

    if self._startBtn then
        self._startBtn:SetLabel(L["btn_start"])
    end
    if self._turnBox then self._turnBox:Hide() end
    self:_RefreshSeriesHud()

    local dialogResult = result
    local titleKeys = {
        WIN  = { "lbl_win" },
        LOSS = { "lbl_loss" },
        DRAW = { "lbl_draw" },
    }
    local lines
    local buttons = mp and {
        {
            label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_new_game or L["btn_new_game"],
            onClick = function()
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("TICTACTOE") end
            end,
        },
        {
            label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_exit or L["btn_exit"],
            onClick = function()
                if E then E:StopGame() end
            end,
        },
    } or nil

    local seriesOver = false
    if not mp and E and E.GetSeries then
        local s = E:GetSeries()
        seriesOver = E:IsSeriesOver()
        if seriesOver then
            local seriesWin = (s.you or 0) > (s.opp or 0)
            dialogResult = seriesWin and "WIN" or "LOSS"
            titleKeys = {
                WIN  = { "result_series_win", "lbl_win" },
                LOSS = { "result_series_loss", "lbl_loss" },
                DRAW = { "result_series_loss", "lbl_draw" },
            }
            lines = {
                L["result_series_bestof"] or "Best of 3",
                string.format("%d : %d", s.you or 0, s.opp or 0),
            }
        else
            lines = {
                string.format(L["hud_series"] or "Serie %d : %d", s.you or 0, s.opp or 0),
            }
            local UILoc = ArcadiaNexus.GetLocaleTable("UI") or {}
            buttons = {
                {
                    label = L["btn_next_round"] or UILoc.btn_next_round or "Nächste Runde",
                    onClick = function()
                        E:StartGame(R:_HotseatConfig({ seriesContinue = true }))
                    end,
                },
                {
                    label = L["btn_exit"] or UILoc.btn_exit or "Beenden",
                    onClick = function()
                        E:StopGame()
                    end,
                },
            }
        end
    end

    UI.ShowArcadeResult(self._fieldFrame, {
        gameId     = "TICTACTOE",
        difficulty = mp and "normal" or (self._lastDifficulty or "easy"),
        result     = dialogResult,
        lines      = lines,
        titleKeys  = titleKeys,
        titleFallbacks = {
            WIN  = "Sieg!",
            LOSS = "Niederlage!",
            DRAW = "Unentschieden!",
        },
        L = L,
        onRetry = function()
            if not E then return end
            if mp then
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("TICTACTOE") end
                return
            end
            E:StartGame(R:_HotseatConfig({ seriesContinue = not seriesOver }))
        end,
        onExit = function()
            if E then E:StopGame() end
        end,
        buttons = buttons,
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

    local result = self.lastResult
    if not result then
        local E = ArcadiaNexus.TTT_Engine
        local board = E and E.GetBoardState and E:GetBoardState()
        result = board and board.result
    end
    if result == "LOSS" then
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
    matchSeats = 2,
    logo      = TTT_ASSETS.logo,
    xp        = 8,
})
