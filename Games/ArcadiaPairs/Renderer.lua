-- ============================================================
--  ArcadiaNexus
--  Games/Memory/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach Match-3/2048-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD (Züge, Paare, Timer) über dem Spielfeld
--    - Controls-Leiste am BOTTOM von self.frame (1:1 wie Match-3)
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--    - Dropdown (Schwierigkeit) + Timer-Checkbox + Start/Beenden + Neues Spiel
--
--  Board-Aufbau (unverändert):
--    Karte = Button + BackdropTemplate
--    card.icon     = Textur (ARTWORK), beginnt Hidden
--    card.backIcon = Fraktions-Icon (ARTWORK), beginnt Shown
--    UpdateBoard() synchron nach HandleFlip
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Renderer = {}
local R = ArcadiaNexus.AP_Renderer

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local AP_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\background\\background_ap",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\logo\\logo_arcadia_pairs",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\border\\border_arcadia_pairs",
}

-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld (Karten-Größe dynamisch berechnet)
local BOARD_SIZE   = 450
local FIELD_OFS_X  = 0       -- Spielfeld horizontal (0 = mittig)
local FIELD_OFS_Y  = 15      -- Spielfeld vertikal (positiv = nach oben)

-- Hintergrund (relativ zu _fieldFrame CENTER)
local CFG = {
    bg_w     = 750,
    bg_h     = 530,
    bg_ofs_x = 0,
    bg_ofs_y = -10,
    bg_alpha = 1,
    hud_moves_w     = 140,
    hud_moves_h     = 28,
    hud_moves_x     = -155,
    hud_moves_y     = 251,
    hud_moves_alpha = 0.75,
    hud_pairs_w     = 140,
    hud_pairs_h     = 28,
    hud_pairs_x     = 155,
    hud_pairs_y     = 251,
    hud_pairs_alpha = 0.75,
    hud_time_w      = 140,
    hud_time_h      = 28,
    hud_time_x      = 0,
    hud_time_y      = 251,
    hud_time_alpha  = 0.75,
}

-- Border über dem Spielfeld
local BORDER_W     = 792
local BORDER_H     = 550
local BORDER_OFS_X = 0
local BORDER_OFS_Y = 0

-- Logo im Spielfeld (IDLE-Zustand)
local LOGO_W       = 445
local LOGO_H       = 206
local LOGO_OFS_X   = 0
local LOGO_OFS_Y   = 0

-- HUD (Züge, Paare, Timer) – relativ zu self.frame CENTER
local HUD_Y        = -170
local HUD_L_X      = -150    -- Züge: links
local HUD_C_X      = 0       -- Paare: mittig
local HUD_R_X      = 150     -- Timer: rechts

-- Controls-Widgets
local DD_W         = 120
local CHK_SIZE     = 20    -- CheckButton Größe

-- Buttons
local BTN_W        = 144
local BTN_H        = 32

-- Karten-Farben
local CLR_HIDDEN   = { 0.20, 0.30, 0.50, 1 }
local CLR_FLIPPED  = { 0.80, 0.80, 0.80, 1 }
local CLR_MATCHED  = { 0.15, 0.50, 0.15, 1 }
local CLR_MISMATCH = { 0.60, 0.15, 0.15, 1 }
local CLR_HOVER    = { 0.30, 0.40, 0.60, 1 }

local CARD_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false,
    edgeSize = 2,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function CreateCardPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaPairs.Cards",
        create = function(poolParent)
            poolParentRef = poolParent
            local card = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            card:SetBackdrop(CARD_BACKDROP)
            local iconTex = card:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("CENTER")
            iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            iconTex:Hide()
            card.icon = iconTex
            local backIcon = card:CreateTexture(nil, "ARTWORK")
            backIcon:SetPoint("CENTER")
            backIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            card.backIcon = backIcon
            return card
        end,
        onRelease = function(card)
            card:Hide()
            card:ClearAllPoints()
            card:Enable()
            card:SetScript("OnClick", nil)
            card:SetScript("OnEnter", nil)
            card:SetScript("OnLeave", nil)
            card._cardIdx = nil
            card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], CLR_HIDDEN[4])
            card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
            if card.icon then
                card.icon:Hide()
                card.icon:SetTexture(nil)
                card.icon:SetVertexColor(1, 1, 1, 1)
            end
            if card.backIcon then
                card.backIcon:Hide()
                card.backIcon:SetTexture(nil)
                card.backIcon:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then card:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._controlsFrame = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"
R._lastDiff     = nil

-- Karten-Board
R._boardHolder  = nil
R._cards        = {}

-- HUD
R._movesFS      = nil
R._movesLbl     = nil
R._pairsFS      = nil
R._pairsLbl     = nil
R._timeFS       = nil
R._timeLbl      = nil
R._hintFS       = nil

-- Controls
R._startBtn     = nil
R._newGameBtn   = nil
R._timerCheckbox = nil

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
    Engine:On("AP_GAME_STARTED",  function(s) R:OnGameStarted(s)  end)
    Engine:On("AP_TIMER_TICK",    function(s) R:OnTimerTick(s)    end)
    Engine:On("AP_GAME_WON",      function(s) R:OnGameWon(s)      end)
    Engine:On("AP_GAME_LOST",     function(s) R:OnGameLost(s)     end)
    Engine:On("AP_GAME_STOPPED",  function()  R:EnterIdleState()  end)
    -- Flip/Match/Mismatch: UpdateBoard() direkt vom Engine aufgerufen (kein Event-Delay)
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
        outerName = "ArcadiaNexus_AP_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._apContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("ARCADIAPAIRS", ArcadiaNexus.AP_Engine, function(E)
            if E.activeGame then
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
    tex:SetTexture(AP_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(BORDER_W, BORDER_H)
    borderFrame:SetPoint("CENTER", ff, "CENTER", BORDER_OFS_X, BORDER_OFS_Y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(AP_ASSETS.border)
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
        AP_ASSETS.logo,
        { w = LOGO_W, h = LOGO_H, x = LOGO_OFS_X, y = LOGO_OFS_Y }
    )
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._movesBox, self._movesFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        text = (L["lbl_moves"] or "Züge") .. ": 0",
        shown = false,
    })
    self._pairsBox, self._pairsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_pairs_w, h = CFG.hud_pairs_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_pairs_x, y = CFG.hud_pairs_y,
        alpha = CFG.hud_pairs_alpha,
        text = (L["lbl_pairs"] or "Paare") .. ": 0/0",
        shown = false,
    })
    self._timeBox, self._timeFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        text = (L["lbl_time"] or "Zeit") .. ": --:--",
        shown = false,
    })
    self._movesLbl, self._pairsLbl, self._timeLbl = nil, nil, nil
    self:_RaiseHudAboveField()

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", FIELD_OFS_X, FIELD_OFS_Y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_UpdateHUD(board)
    if not board then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")

    if self._movesFS then
        self._movesFS:SetText((L["lbl_moves"] or "Züge") .. ": " .. tostring(board.moves or 0))
    end
    if self._pairsFS then
        self._pairsFS:SetText((L["lbl_pairs"] or "Paare") .. ": " ..
            tostring(board.matchedPairs or 0) .. "/" .. tostring(board.pairs or 0))
    end
    if board.timerActive and self._timeFS then
        self:_UpdateTimeDisplay(board.timerLeft or 0)
    end
end

function R:_RaiseHudAboveField()
    local base = 1
    if self._borderFrame and self._borderFrame.GetFrameLevel then
        base = self._borderFrame:GetFrameLevel()
    elseif self._fieldFrame and self._fieldFrame.GetFrameLevel then
        base = self._fieldFrame:GetFrameLevel()
    end
    local level = base + 20
    for _, box in ipairs({ self._movesBox, self._pairsBox, self._timeBox }) do
        if box and box.SetFrameLevel then box:SetFrameLevel(level) end
    end
end

function R:_UpdateTimeDisplay(secs)
    if not self._timeFS then return end
    self._timeFS:Show()
    local text, level, r, g, b = ArcadiaNexus.Format.SecondsWithUrgency(secs or 0, {
        warn = 60, crit = 30, padMinutes = false,
    })
    if level ~= "normal" then
        text = string.format("|cff%02x%02x%02x%s|r",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
    end
    self._timeFS:SetText((ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["lbl_time"] or "Zeit") .. ": " .. text)
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (Segment 1)
    local S = ArcadiaNexus.AP_Settings
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

    -- Timer-Checkbox (Segment 4), Label rechts
    local chkHolder, cb = UI.CreateBarCheckbox(cf, L["timer_label"] or "Timer", { w = 110, h = 36, size = CHK_SIZE })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)
    cb:SetScript("OnShow", function()
        local S2 = ArcadiaNexus.AP_Settings
        cb:SetChecked(S2 and S2:Get("timerActive") or false)
    end)
    cb:SetScript("OnClick", function()
        local S2 = ArcadiaNexus.AP_Settings
        if S2 then S2:Set("timerActive", cb:GetChecked() and true or false) end
    end)
    self._timerCheckbox = cb

    -- Start / Beenden Button (Segment 2)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], BTN_W, BTN_H)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AP_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            local diff   = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
            local theme  = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
            local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
            E:StartGame({ difficulty = diff, theme = theme, timerActive = timer })
        end
    end)
    self._startBtn = startBtn

    -- Neues Spiel Button (Segment 3)
    local newGameBtn = UI.CreateArcadiaButton(cf, L["btn_new_game"], BTN_W, BTN_H)
    newGameBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    newGameBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AP_Engine
        if not E then return end
        local diff   = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
        local theme  = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
        local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
        E:StartGame({ difficulty = diff, theme = theme, timerActive = timer })
    end)
    newGameBtn:Hide()
    self._newGameBtn = newGameBtn
end

-- ============================================================
-- BOARD-AUFBAU (unverändert – Kernlogik Memory)
-- ============================================================
function R:_EnsureCardPool()
    if not self._cardPool then
        self._cardPool = CreateCardPool()
    end
end

function R:BuildBoard(state)
    self:ClearBoard()

    local grid     = state.grid
    local gap      = 4
    local cellSize = math.floor((BOARD_SIZE - gap * (grid - 1)) / grid)
    local total    = cellSize * grid + gap * (grid - 1)

    local holder = self._boardHolder
    if not holder then
        holder = CreateFrame("Frame", nil, self._fieldFrame)
        self._boardHolder = holder
    end
    holder:SetParent(self._fieldFrame)
    holder:SetSize(total, total)
    holder:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    holder:Show()

    local SR       = ArcadiaNexus.AP_SymbolResolver
    local S        = ArcadiaNexus.AP_Settings
    local backData = SR:GetCardBack(S:GetAll())
    self:_EnsureCardPool()

    for idx = 1, state.totalCards do
        local row = math.floor((idx - 1) / grid)
        local col = (idx - 1) % grid
        local px  = col * (cellSize + gap)
        local py  = row * (cellSize + gap)

        local card = self._cardPool:Acquire({})
        card:SetParent(holder)
        card:SetSize(cellSize - 2, cellSize - 2)
        card:SetPoint("TOPLEFT", holder, "TOPLEFT", px + 1, -(py + 1))
        card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], CLR_HIDDEN[4])
        card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)

        local texSize = cellSize - 14
        card.icon:SetSize(texSize, texSize)
        card.backIcon:SetSize(texSize, texSize)
        card.backIcon:SetTexture(backData.icon)
        card.backIcon:SetVertexColor(backData.tint[1], backData.tint[2], backData.tint[3], 1)
        card.backIcon:Show()
        card.icon:Hide()

        card._cardIdx = idx
        card:SetScript("OnClick", function(self)
            ArcadiaNexus.AP_Engine:HandleFlip(self._cardIdx)
        end)
        card:SetScript("OnEnter", function(self)
            local board = ArcadiaNexus.AP_Engine.activeGame and ArcadiaNexus.AP_Engine.activeGame.board
            local cardData = board and board.cards[self._cardIdx]
            if cardData and cardData.state == "HIDDEN" then
                self:SetBackdropColor(CLR_HOVER[1], CLR_HOVER[2], CLR_HOVER[3], 1)
            end
        end)
        card:SetScript("OnLeave", function(self)
            local board = ArcadiaNexus.AP_Engine.activeGame and ArcadiaNexus.AP_Engine.activeGame.board
            local cardData = board and board.cards[self._cardIdx]
            if cardData and cardData.state == "HIDDEN" then
                self:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], 1)
            end
        end)
        card:Show()

        self._cards[idx] = card
    end
end

function R:ClearBoard()
    if self._cardPool then
        self._cardPool:ReleaseAll()
    end
    self._cards = {}
    if self._boardHolder then self._boardHolder:Hide() end
end

-- ============================================================
-- BOARD UPDATE (synchron, direkt vom Engine aufgerufen)
-- ============================================================
function R:UpdateBoard()
    local game = ArcadiaNexus.AP_Engine.activeGame
    if not game then return end
    local board = game.board

    for idx = 1, board.totalCards do
        local card     = self._cards[idx]
        local cardData = board.cards[idx]
        if card and cardData then
            if cardData.state == "MATCHED" then
                card:SetBackdropColor(CLR_MATCHED[1], CLR_MATCHED[2], CLR_MATCHED[3], 1)
                card:SetBackdropBorderColor(0.2, 0.7, 0.2, 1)
                card.icon:SetTexture("Interface\\Icons\\" .. cardData.icon)
                card.icon:Show()
                card.backIcon:Hide()
            elseif cardData.state == "FLIPPED" then
                card:SetBackdropColor(CLR_FLIPPED[1], CLR_FLIPPED[2], CLR_FLIPPED[3], 1)
                card:SetBackdropBorderColor(0.9, 0.8, 0.4, 1)
                card.icon:SetTexture("Interface\\Icons\\" .. cardData.icon)
                card.icon:Show()
                card.backIcon:Hide()
            else -- HIDDEN
                card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], 1)
                card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
                card.icon:Hide()
                card.backIcon:Show()
            end
        end
    end

    self:_UpdateHUD(board)
end

-- ============================================================
-- MISMATCH-FLASH (direkt vom Engine aufgerufen)
-- ============================================================
function R:FlashMismatch(i1, i2)
    local c1 = self._cards[i1]
    local c2 = self._cards[i2]
    if c1 then c1:SetBackdropColor(CLR_MISMATCH[1], CLR_MISMATCH[2], CLR_MISMATCH[3], 1) end
    if c2 then c2:SetBackdropColor(CLR_MISMATCH[1], CLR_MISMATCH[2], CLR_MISMATCH[3], 1) end
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
    if self._newGameBtn  then self._newGameBtn:Hide()  end
    if self._movesBox    then self._movesBox:Hide()    end
    if self._pairsBox    then self._pairsBox:Hide()    end
    if self._timeBox     then self._timeBox:Hide()     end
    if self._goldGrid    then self._goldGrid:Hide()    end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["hint_start"] or "")
        self._hintFS:Show()
    end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(state)
    self.state    = "PLAYING"
    self._lastDiff = state.difficulty

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._newGameBtn then self._newGameBtn:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_exit"])
    end

    if self._movesBox then self._movesBox:Show() end
    if self._pairsBox then self._pairsBox:Show() end
    if self._goldGrid then self._goldGrid:Show() end
    self:_RaiseHudAboveField()

    if state.timerActive then
        if self._timeBox then self._timeBox:Show() end
        if self._timeFS then self._timeFS:Show() end
    else
        if self._timeBox then self._timeBox:Hide() end
    end

    self:BuildBoard(state)
    self:UpdateBoard()
    self:_UpdateHUD(state)
end

function R:OnTimerTick(state)
    if state then
        self:_UpdateHUD(state)
        return
    end
    local game = ArcadiaNexus.AP_Engine.activeGame
    if game then self:_UpdateHUD(game.board) end
end

function R:_StartNewGameFromResult()
    local E = ArcadiaNexus.AP_Engine
    if not E then return end
    local diff  = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
    local theme = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
    local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
    E:StartGame({ difficulty = diff, theme = theme, timerActive = timer })
end

function R:OnGameWon(state)
    self.state = "WON"
    self:UpdateBoard()
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
    end

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local parent = self._fieldFrame

    local timeStr = ""
    if state.timerActive and state.timerLeft then
        timeStr = string.format(
            L["result_win_time"] or "\nZeit: %s",
            ArcadiaNexus.Format.SecondsMMSS(state.timerLeft, false))
    end

    UI.ShowArcadeResult(parent, {
        title      = L["result_win_title"] or "|cffffd700Alle Paare gefunden!|r",
        titleColor = {1, 0.84, 0},
        subtitle   = string.format(
            L["result_win_sub"] or "Züge: %d  Paare: %d",
            state.moves, state.pairs) .. timeStr,
        gameId     = "ARCADIAPAIRS",
        result     = "WIN",
        L          = L,
        onRetry    = function() R:_StartNewGameFromResult() end,
        onExit     = function()
            local E = ArcadiaNexus.AP_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:OnGameLost(state)
    self.state = "LOST"
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
    end

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local parent = self._fieldFrame

    UI.ShowArcadeResult(parent, {
        title      = L["result_lose_title"] or "|cffff4444Zeit abgelaufen!|r",
        titleColor = {1, 0.3, 0.3},
        subtitle   = string.format(
            L["result_lose_sub"] or "Paare: %d/%d  Züge: %d",
            state.matchedPairs, state.pairs, state.moves),
        gameId     = "ARCADIAPAIRS",
        result     = "LOSS",
        L          = L,
        onRetry    = function() R:_StartNewGameFromResult() end,
        onExit     = function()
            local E = ArcadiaNexus.AP_Engine
            if E then E:StopGame() end
        end,
    })
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "ARCADIAPAIRS",
    label     = "Arcadia Pairs",
    category  = "KARTEN",
    renderer  = "AP_Renderer",
    engine    = "AP_Engine",
    container = "_apContainer",
})
