--[[
    ArcadiaNexus
    Games/Chess/Renderer.lua
    Version: 2.0.0

    Layout-Strategie (Blueprint v2 — identisch zu 2048 v2.1):
      - Panel-großer Lifecycle-Container mit zentriertem 600x498 Design-Canvas
      - Alle Elemente per CENTER-Ankern positioniert
      - Spielfeld oben-mittig, Controls unten in fester Leiste
      - Border einmalig als OVERLAY-Textur über dem Spielfeld
      - Logo via UI.CreateGameLogo
      - Dropdown (links): Schwierigkeit (Classic/Pro/Insane)
      - Start/Beenden-Button (mitte): Dual-Label
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_Renderer = {}
local R = ArcadiaNexus.Chess_Renderer

-- ============================================================
-- CFG – alle Layout- und Brett-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================

local CFG = {
    -- Spielfeld
    field_w      = 400,
    field_h      = 400,
    field_ofs_x  = 0,
    field_ofs_y  = 0,

    -- Border
    border_w     = 790,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 18,

    -- Hintergrund
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,

    -- Logo (IDLE)
    logo_w       = 481,
    logo_h       = 389,
    logo_ofs_x   = 0,
    logo_ofs_y   = 10,

    -- HUD: Züge / Geschlagen (Canvas, unabhängig)
    hud_moves_w      = 140,
    hud_moves_h      = 28,
    hud_moves_x      = -140,
    hud_moves_y      = 221,
    hud_moves_alpha  = 0.75,
    hud_cap_w        = 140,
    hud_cap_h        = 28,
    hud_cap_x        = 140,
    hud_cap_y        = 221,
    hud_cap_alpha    = 0.75,

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- Brett
    board_grid   = 6,
    label_w      = 18,
}
-- Abgeleitete Brett-Konstanten (benötigen CFG.board_grid / CFG.field_w)
CFG.cell_size = math.floor(CFG.field_w / CFG.board_grid)   -- 50px
CFG.board_px  = CFG.cell_size * CFG.board_grid

-- Brett-Farben (Tabellen bleiben file-level: je 1 Upvalue)
local LIGHT_FIELD  = { 0.55, 0.50, 0.40, 1 }
local DARK_FIELD   = { 0.20, 0.17, 0.13, 1 }
local CLR_SELECTED = { 0.90, 0.75, 0.10, 1 }
local CLR_LEGAL    = { 0.10, 0.65, 0.20, 1 }
local CLR_LASTMOVE = { 0.20, 0.40, 0.80, 1 }
local CLR_CHECK    = { 0.80, 0.10, 0.10, 1 }
local TINT_WHITE   = { 0.55, 0.70, 1.00 }
local TINT_BLACK   = { 1.00, 0.35, 0.35 }

-- Icon-Tabelle (1 Upvalue)
local ICONS = {
    white = {
        KING   = "Interface\\Icons\\INV_Helmet_01",
        QUEEN  = "Interface\\Icons\\INV_Jewelry_Ring_05",
        ROOK   = "Interface\\Icons\\Ability_Repair",
        KNIGHT = "Interface\\Icons\\Ability_Mount_RidingHorse",
        PAWN   = "Interface\\Icons\\INV_Shield_06",
    },
    black = {
        KING   = "Interface\\Icons\\INV_Helmet_02",
        QUEEN  = "Interface\\Icons\\INV_Jewelry_Ring_01",
        ROOK   = "Interface\\Icons\\INV_Stone_15",
        KNIGHT = "Interface\\Icons\\Ability_Mount_Raptor",
        PAWN   = "Interface\\Icons\\INV_Shield_05",
    },
}

local function GetPieceNames()
    local L = ArcadiaNexus.GetLocaleTable("CHESS")
    return {
        KING   = L["piece_king"],
        QUEEN  = L["piece_queen"],
        ROOK   = L["piece_rook"],
        KNIGHT = L["piece_knight"],
        PAWN   = L["piece_pawn"],
    }
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
R.selectedDiff  = "easy"

R.cells         = {}
R.boardHolder   = nil

R.moveFS        = nil
R.captureFS     = nil
R._moveBox      = nil
R._captureBox   = nil
R._startBtn     = nil

-- ============================================================
-- INIT
-- ============================================================

function R:Init()
    -- Schwierigkeit aus Settings laden (vor _CreateControls!)
    local S = ArcadiaNexus.Chess_Settings
    self.selectedDiff = (S and S:Get("difficulty")) or "easy"

    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateInfoBoxes()
    self:_CreateBoard()
    self:_CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine

    Engine:On("CHE_GAME_STARTED", function(s)
        R.state = "PLAYING"
        R:OnGameStarted(s)
        if R._fieldFrame and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
        end
        if R._logoTex    then R._logoTex:Hide() end
        if R._startBtn   then
            R._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("CHESS")["btn_exit"])
        end
    end)

    Engine:On("CHE_PIECE_SELECTED",   function(s)    R:OnPieceSelected(s)  end)
    Engine:On("CHE_PIECE_DESELECTED", function(s)    R:OnBoardUpdated(s)   end)
    Engine:On("CHE_MOVE_MADE",        function(s, r) R:OnMoveMade(s, r)    end)
    Engine:On("CHE_AI_MOVE",          function(s, r) R:OnAIMove(s, r)      end)

    Engine:On("CHE_GAME_OVER", function(s)
        R:OnGameOver(s)
    end)

    Engine:On("CHE_GAME_STOPPED", function()
        R:EnterIdleState()
    end)
end

-- ============================================================
-- FRAME-AUFBAU
-- ============================================================

function R:_CreateMainFrame()
    if self.frame then return end
    if _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel then
        local gamesPanel = _G.ArcadiaNexusUI.GetGamesPanel()
        local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
            outerName = "ArcadiaNexus_CHE_Container",
            designW   = 600,
            designH   = 498,
        })
        local container = viewport.outer
        container:Hide()
        self.frame = container
        self._canvas = viewport.canvas
        if _G.ArcadiaNexus then
            _G.ArcadiaNexus._cheContainer = container
        end

        container:SetScript("OnHide", function()
            ArcadiaNexus.GameSession:HandleRendererHide("CHESS", ArcadiaNexus.CHE_Engine, function(E)
                if E.activeGame then
                    E:StopGame()
                end
            end)
        end)
    end
end

function R:_CreateFieldFrame()
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

function R:_CreateBackground()
    local ff = self._fieldFrame
    if not ff then return end
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\Chess\\assets\\background\\background_chess")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderTex()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\Chess\\assets\\border\\border_mini_chess")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        "Interface\\AddOns\\ArcadiaNexus\\Games\\Chess\\assets\\logo\\logo_mini_chess",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function R:_CreateInfoBoxes()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("CHESS")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._moveBox, self.moveFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        text = (L["box_moves"] or "Züge") .. ": 0",
        shown = false,
    })
    self._captureBox, self.captureFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_cap_w, h = CFG.hud_cap_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_cap_x, y = CFG.hud_cap_y,
        alpha = CFG.hud_cap_alpha,
        text = (L["box_captured"] or "Geschlagen") .. ": 0",
        shown = false,
    })
end

function R:_CreateBoard()
    if self.boardHolder then return end
    local ff = self._fieldFrame

    -- boardHolder zentriert im _fieldFrame
    local holder = CreateFrame("Frame", nil, ff)
    holder:SetSize(CFG.label_w + CFG.board_px, CFG.board_px + CFG.label_w)
    holder:SetPoint("CENTER", ff, "CENTER", 0, 0)
    holder:SetFrameLevel(ff:GetFrameLevel() + 1)

    -- Gold-Außenrahmen
    local outerBG = holder:CreateTexture(nil, "BACKGROUND")
    outerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    outerBG:SetAllPoints(holder)
    outerBG:SetVertexColor(0.70, 0.60, 0.35, 1)
    self.boardHolder = holder

    -- Spalten-Labels (a-f)
    local colLabels = { "a","b","c","d","e","f" }
    for c = 1, 6 do
        local lbl = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetSize(CFG.cell_size, CFG.label_w)
        lbl:SetPoint("TOPLEFT", holder, "TOPLEFT",
            CFG.label_w + (c-1)*CFG.cell_size + 1,
            -(CFG.board_px + 1))
        lbl:SetText(colLabels[c])
        lbl:SetJustifyH("CENTER")
        lbl:SetTextColor(0.80, 0.72, 0.50)
    end

    -- Zeilen-Labels (6-1)
    for r = 1, 6 do
        local lbl = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetSize(CFG.label_w, CFG.cell_size)
        lbl:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -((r-1)*CFG.cell_size + 1))
        lbl:SetText(tostring(7 - r))
        lbl:SetJustifyH("CENTER")
        lbl:SetJustifyV("MIDDLE")
        lbl:SetTextColor(0.80, 0.72, 0.50)
    end

    -- 36 Felder
    for r = 1, 6 do
        self.cells[r] = {}
        for c = 1, 6 do
            local px = CFG.label_w + (c-1)*CFG.cell_size + 1
            local py = (r-1)*CFG.cell_size + 1

            local tf = CreateFrame("Button", nil, holder)
            tf:SetSize(CFG.cell_size, CFG.cell_size)
            tf:SetPoint("TOPLEFT", holder, "TOPLEFT", px, -py)
            tf:EnableMouse(true)
            tf:SetNormalTexture("Interface\\Buttons\\WHITE8X8")

            local bg = tf:GetNormalTexture()
            local isLight = (r + c) % 2 == 0
            local fc = isLight and LIGHT_FIELD or DARK_FIELD
            bg:SetVertexColor(fc[1], fc[2], fc[3], 1)

            -- Highlight-Frame
            local hlFrame = CreateFrame("Frame", nil, tf)
            hlFrame:SetAllPoints(tf)
            hlFrame:SetFrameLevel(tf:GetFrameLevel())
            hlFrame:EnableMouse(false)
            hlFrame:Hide()
            local hlTex = hlFrame:CreateTexture(nil, "OVERLAY")
            hlTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            hlTex:SetAllPoints(hlFrame)
            hlTex:SetVertexColor(0, 0, 0, 0)

            -- Figur-Icon
            local iconFrame = CreateFrame("Frame", nil, tf)
            iconFrame:SetPoint("CENTER", tf, "CENTER", 0, 0)
            iconFrame:SetSize(CFG.cell_size - 8, CFG.cell_size - 8)
            iconFrame:SetFrameLevel(tf:GetFrameLevel() + 2)
            iconFrame:EnableMouse(false)
            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints(iconFrame)
            iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            iconTex:Hide()

            -- Click-Handler
            local cr, cc = r, c
            tf:SetScript("OnClick", function()
                ArcadiaNexus.Chess_Engine:HandleCellClick(cr, cc)
            end)

            -- Tooltip
            tf:SetScript("OnEnter", function()
                if R.state == "PLAYING" then
                    local gs = ArcadiaNexus.Chess_Engine.activeGame
                        and ArcadiaNexus.Chess_Engine.activeGame:GetBoardState()
                    if gs and gs.board and gs.board[cr][cc] then
                        local piece = gs.board[cr][cc]
                        GameTooltip:SetOwner(tf, "ANCHOR_RIGHT")
                        GameTooltip:SetText(
                            (piece.color == "white" and "|cff8888ff" or "|cffff4444") ..
                            GetPieceNames()[piece.type] .. "|r"
                        )
                        GameTooltip:Show()
                    end
                end
            end)
            tf:SetScript("OnLeave", function() GameTooltip:Hide() end)

            self.cells[r][c] = {
                frame     = tf,
                bg        = bg,
                hlFrame   = hlFrame,
                hlTex     = hlTex,
                iconFrame = iconFrame,
                iconTex   = iconTex,
                isLight   = isLight,
            }
        end
    end
end

function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("CHESS")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (linkes Segment)
    local S = ArcadiaNexus.Chess_Settings
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
        0, 0, CFG.dd_w,
        "",
        ddOptions,
        function()
            return S and S:Get("difficulty") or "easy"
        end,
        function(key)
            R.selectedDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Start / Beenden-Button (mittleres Segment)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        if R.state == "PLAYING" then
            ArcadiaNexus.Chess_Engine:StopGame()
        else
            ArcadiaNexus.Chess_Engine:StartGame({ difficulty = R.selectedDiff })
        end
    end)
    self._startBtn = startBtn
end

-- ============================================================
-- IDLE STATE
-- ============================================================

function R:EnterIdleState()
    self.state = "IDLE"
    local L = ArcadiaNexus.GetLocaleTable("CHESS")

    -- Brett leeren
    for r = 1, 6 do
        for c = 1, 6 do
            local cd = self.cells[r] and self.cells[r][c]
            if cd then
                cd.iconTex:Hide()
                cd.hlFrame:Hide()
                local fc = cd.isLight and LIGHT_FIELD or DARK_FIELD
                cd.bg:SetVertexColor(fc[1], fc[2], fc[3], 1)
            end
        end
    end

    if self.boardHolder    then self.boardHolder:Hide()                  end
    if self._fieldFrame    then self._fieldFrame:SetBackdropColor(0,0,0,0) end
    if self.moveFS         then self.moveFS:SetText("0")                 end
    if self.captureFS      then self.captureFS:SetText("0")              end
    if self._moveBox       then self._moveBox:Hide()                    end
    if self._captureBox    then self._captureBox:Hide()                 end
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._logoTex       then self._logoTex:Show()                     end
    if self._borderFrame   then self._borderFrame:Show()                 end
    if self._startBtn      then self._startBtn:SetLabel(L["btn_start"])  end
end

-- ============================================================
-- RENDERBOARD
-- ============================================================

function R:RenderBoard(state)
    if self._logoTex    then self._logoTex:Hide()   end
    if self.boardHolder then self.boardHolder:Show() end
    self._fieldFrame:SetBackdropColor(0.07, 0.07, 0.12, 1)

    local board      = state.board
    local selected   = state.selected
    local legalMoves = state.legalMoves or {}
    local lastMove   = state.lastMove
    local inCheck    = state.inCheck

    -- Legale Züge als Set
    local legalSet = {}
    for _, m in ipairs(legalMoves) do
        legalSet[m.toR .. "_" .. m.toC] = true
    end

    -- König im Schach?
    local checkKingR, checkKingC
    if inCheck then
        for r = 1, 6 do
            for c = 1, 6 do
                local p = board[r][c]
                if p and p.type == "KING" and p.color == "white" then
                    checkKingR, checkKingC = r, c
                end
            end
        end
    end

    for r = 1, 6 do
        for c = 1, 6 do
            local cd    = self.cells[r][c]
            local piece = board[r][c]
            local key   = r .. "_" .. c

            -- Hintergrundfarbe
            local bgCol
            if selected and r == selected.r and c == selected.c then
                bgCol = CLR_SELECTED
            elseif legalSet[key] then
                bgCol = CLR_LEGAL
            elseif lastMove and
                ((r == lastMove.fromR and c == lastMove.fromC) or
                 (r == lastMove.toR   and c == lastMove.toC)) then
                bgCol = CLR_LASTMOVE
            elseif checkKingR and r == checkKingR and c == checkKingC then
                bgCol = CLR_CHECK
            else
                bgCol = cd.isLight and LIGHT_FIELD or DARK_FIELD
            end
            cd.bg:SetVertexColor(bgCol[1], bgCol[2], bgCol[3], 1)

            -- Highlight für legale Züge
            if legalSet[key] then
                cd.hlFrame:Show()
                if piece then
                    cd.hlTex:SetVertexColor(0.8, 0.2, 0.2, 0.5)
                else
                    cd.hlTex:SetVertexColor(0.1, 0.8, 0.2, 0.6)
                end
            else
                cd.hlFrame:Hide()
                cd.hlTex:SetVertexColor(0, 0, 0, 0)
            end

            -- Figur-Icon
            if piece then
                local iconPath = ICONS[piece.color] and ICONS[piece.color][piece.type]
                if iconPath then
                    cd.iconTex:SetTexture(iconPath)
                    local tint = piece.color == "white" and TINT_WHITE or TINT_BLACK
                    cd.iconTex:SetVertexColor(tint[1], tint[2], tint[3], 1)
                    cd.iconTex:Show()
                else
                    cd.iconTex:Hide()
                end
            else
                cd.iconTex:Hide()
            end
        end
    end
end

-- ============================================================
-- INFO-BOXEN AKTUALISIEREN
-- ============================================================

function R:UpdateInfoBoxes(state)
    local L = ArcadiaNexus.GetLocaleTable("CHESS")
    if self.moveFS then
        self.moveFS:SetText((L["box_moves"] or "Züge") .. ": " .. tostring(state.moveCount or 0))
    end
    if self.captureFS then
        local count = #(state.capturedByWhite or {}) + #(state.capturedByBlack or {})
        self.captureFS:SetText((L["box_captured"] or "Geschlagen") .. ": " .. tostring(count))
    end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================

function R:OnGameStarted(state)
    if self._moveBox    then self._moveBox:Show()    end
    if self._captureBox then self._captureBox:Show() end
    self:RenderBoard(state)
    self:UpdateInfoBoxes(state)
end

function R:OnPieceSelected(state)
    self:RenderBoard(state)
    local sel = state.selected
    if sel then
        local cd = self.cells[sel.r] and self.cells[sel.r][sel.c]
        if cd then
            cd.frame:SetAlpha(0.7)
            UIFrameFadeIn(cd.frame, 0.15, 0.7, 1)
        end
    end
end

function R:OnBoardUpdated(state)
    self:RenderBoard(state)
end

function R:OnMoveMade(state, result)
    self:RenderBoard(state)
    self:UpdateInfoBoxes(state)
end

function R:OnAIMove(state, result)
    self:RenderBoard(state)
    self:UpdateInfoBoxes(state)

    if state.lastMove then
        local m  = state.lastMove
        local cd = self.cells[m.toR] and self.cells[m.toR][m.toC]
        if cd then
            cd.frame:SetAlpha(0.4)
            UIFrameFadeIn(cd.frame, 0.3, 0.4, 1)
        end
    end
end

function R:OnGameOver(state)
    self.state = "GAMEOVER"
    self:RenderBoard(state)
    self:UpdateInfoBoxes(state)

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("CHESS")
    local parent = self._fieldFrame

    local title, titleColor, subtitle, result
    if state.result == "white_wins" then
        title      = L["result_win"]
        titleColor = {1, 0.84, 0}
        subtitle   = L["result_win_sub"] .. (state.moveCount or 0)
        result     = "WIN"
    elseif state.result == "black_wins" then
        title      = L["result_loss"]
        titleColor = {1, 0.3, 0.3}
        subtitle   = L["result_loss_sub"] .. (state.moveCount or 0)
        result     = "LOSS"
    else
        title      = L["result_draw"]
        titleColor = {0.8, 0.8, 0.8}
        subtitle   = L["result_draw_sub"]
        result     = "DRAW"
    end

    UI.ShowArcadeResult(parent, {
        title      = title,
        titleColor = titleColor,
        subtitle   = subtitle,
        gameId     = "CHESS",
        difficulty = R.selectedDiff,
        result     = result,
        L          = L,
        onRetry    = function()
            ArcadiaNexus.Chess_Engine:StartGame({ difficulty = R.selectedDiff })
        end,
        onExit     = function()
            ArcadiaNexus.Chess_Engine:StopGame()
        end,
    })

    if self._startBtn then
        self._startBtn:SetLabel(L["btn_start"])
    end
end

-- ============================================================
-- REGISTRIERUNG
-- ============================================================

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "CHESS",
    label     = "Mini-Schach",
    renderer  = "Chess_Renderer",
    engine    = "Chess_Engine",
    container = "_cheContainer",
    category  = "DENKSPIELE",
})
