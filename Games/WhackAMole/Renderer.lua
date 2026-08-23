-- ============================================================
--  ArcadiaNexus
--  Games/WhackAMole/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach SimonSays-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD: Score links, Zeit mittig, Verpasst rechts (über Spielfeld)
--    - Controls-Leiste am BOTTOM: Dropdown Schwierigkeit + Start/Beenden
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--    - Overlay (GameOver) auf _fieldFrame
--
--  Board-Aufbau (unverändert):
--    _buildGrid, ShowMole, HideMole, ShowHitEffect, ShowBoomEffect
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.WAM_Renderer = {}
local R = ArcadiaNexus.WAM_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_size   = 400,
    field_ofs_x  = 0,
    field_ofs_y  = 5,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 10,
    bg_alpha     = 1,
    border_w     = 800,
    border_h     = 553,
    border_ofs_x = 0,
    border_ofs_y = 10,
    logo_w       = 452,
    logo_h       = 134,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    hud_y        = 225,
    hud_x        = 0,
    hud_w        = 405,
    hud_h        = 28,
    hud_alpha    = 0.75,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local WAM_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\WhackAMole\\assets\\background\\background_wam",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\WhackAMole\\assets\\logo\\logo_whackamole",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\WhackAMole\\assets\\border\\border_whackamole",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================



-- HUD – relativ zu self.frame CENTER

-- ============================================================
-- STATE
-- ============================================================
R.frame         = nil
R._canvas       = nil
R._controlsFrame = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"

-- Grid
R._gridFrame    = nil
R._holes        = {}
R._builtGrid    = nil
R._holePool     = nil

-- HUD
R._scoreFS      = nil
R._scoreLbl     = nil
R._timerFS      = nil
R._timerLbl     = nil
R._missedFS     = nil
R._missedLbl    = nil
R._hintFS       = nil

-- Controls
R._startBtn     = nil
R._lastDiff     = nil

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

    local Eng = ArcadiaNexus.Engine
    Eng:On("WAM_GAME_STARTED",  function(b) R:OnGameStarted(b)  end)
    Eng:On("WAM_GAME_STOPPED",  function()  R:EnterIdleState()  end)
    Eng:On("WAM_TICK",          function(b) R:UpdateHUD(b)      end)
    Eng:On("WAM_GAME_OVER",     function(b, hitBomb) R:ShowGameOver(b, hitBomb) end)
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
        outerName = "ArcadiaNexus_WAM_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._wamContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("WHACKAMOLE", ArcadiaNexus.WAM_Engine, function(E)
            if E._board then
                R:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_size, CFG.field_size)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(WAM_ASSETS.bg)
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
    tex:SetTexture(WAM_ASSETS.border)
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
        WAM_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._hudBox, self._hudFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_w, h = CFG.hud_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_x, y = CFG.hud_y,
        alpha = CFG.hud_alpha,
        text = (L["lbl_score"] or "Score") .. ": 0   " ..
            (L["lbl_time"] or "Zeit") .. ": 0   " ..
            (L["lbl_missed"] or "Verpasst") .. ": 0",
        shown = false,
    })
    self._scoreFS, self._timerFS, self._missedFS = self._hudFS, self._hudFS, self._hudFS

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:UpdateHUD(board)
    if not board then return end
    local L = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
    if self._hudFS then
        self._hudFS:SetText(
            (L["lbl_score"] or "Score") .. ": " .. tostring(board.score or 0) .. "   " ..
            (L["lbl_time"] or "Zeit") .. ": " .. tostring(board.timeLeft or 0) .. "   " ..
            (L["lbl_missed"] or "Verpasst") .. ": " .. tostring(board.missed or 0)
        )
    end
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (linkes Segment)
    local S = ArcadiaNexus.WAM_Settings

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "EASY",   label = L["diff_easy"]   },
            { key = "NORMAL", label = L["diff_normal"]  },
            { key = "HARD",   label = L["diff_hard"]    },
        },
        function()
            return (S and S:Get("difficulty")) or "EASY"
        end,
        function(key)
            R._lastDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Start / Beenden Button (mittleres Segment)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.WAM_Engine
        if not E then return end
        if R.state == "PLAYING" then
            R:StopGame()
        else
            local diff = R._lastDiff
                or (ArcadiaNexus.WAM_Settings and ArcadiaNexus.WAM_Settings:Get("difficulty"))
                or "EASY"
            E:StartGame(diff)
        end
    end)
    self._startBtn = startBtn

    -- Score / Zeit / Verpasst in der Controls-Leiste (rechtes Segment, x=+170)
    local hudCtrlFS = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hudCtrlFS:SetPoint("CENTER", cf, "CENTER", bar.segX[3], 0)
    hudCtrlFS:SetJustifyH("CENTER")
    hudCtrlFS:SetTextColor(1, 0.84, 0)
    hudCtrlFS:SetText("")
    self._hudCtrlFS = hudCtrlFS
end

function R:ShowGameOver(board, hitBomb)
    self.state = "GAMEOVER"
    self._lastDiff = board.difficulty

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("WHACKAMOLE")["btn_start"])
    end

    local L  = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
    local UI = ArcadiaNexus.UI

    local title, titleColor
    if hitBomb then
        title      = L["go_title_bomb"]
        titleColor = { 1, 0.3, 0.3 }
    else
        title      = L["go_title_time"]
        titleColor = { 1, 0.84, 0 }
    end

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = title,
        titleColor = titleColor,
        score      = board.score,
        gameId     = "WHACKAMOLE",
        difficulty = board.difficulty,
        result     = "LOSS",
        lines      = {
            (L["go_missed"] or "Verpasst: ") .. tostring(board.missed or 0),
        },
        L = L,
        onRetry = function()
            local E = ArcadiaNexus.WAM_Engine
            if not E then return end
            local diff = R._lastDiff
                or (ArcadiaNexus.WAM_Settings and ArcadiaNexus.WAM_Settings:Get("difficulty"))
                or "EASY"
            E:StartGame(diff)
        end,
        onExit = function()
            R:StopGame()
        end,
    })
end

-- ============================================================
-- GRID (Kern unverändert, Anker auf _fieldFrame)
-- ============================================================

local function CreateHolePool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "WhackAMole.Holes",
        create = function(poolParent)
            poolParentRef = poolParent
            local hole = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            hole:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            hole:SetBackdropColor(0.20, 0.14, 0.08, 1)
            hole:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)

            hole._oval = hole:CreateTexture(nil, "BACKGROUND")
            hole._oval:SetTexture("Interface\\Buttons\\WHITE8X8")
            hole._oval:SetVertexColor(0.08, 0.05, 0.02, 1)

            hole._icon = hole:CreateTexture(nil, "ARTWORK")

            hole._fxFS = hole:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            hole._fxFS:SetPoint("CENTER", hole, "CENTER", 0, 10)
            hole._fxFS:Hide()

            hole:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.28, 0.20, 0.10, 1)
            end)
            hole:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.20, 0.14, 0.08, 1)
            end)
            hole:SetScript("OnClick", function(self)
                local E = ArcadiaNexus.WAM_Engine
                if E and self._wamRow and self._wamCol then
                    E:OnMoleClick(self._wamRow, self._wamCol)
                end
            end)
            return hole
        end,
        onRelease = function(hole)
            hole:Hide()
            hole:ClearAllPoints()
            hole._wamRow = nil
            hole._wamCol = nil
            hole:SetBackdropColor(0.20, 0.14, 0.08, 1)
            hole:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)
            if hole._icon then hole._icon:Hide() end
            if hole._fxFS then hole._fxFS:Hide() end
            if poolParentRef then hole:SetParent(poolParentRef) end
        end,
    })
end

local function ConfigureHole(hole, gridFrame, r, c, cs)
    hole:SetParent(gridFrame)
    hole:SetSize(cs - 6, cs - 6)
    hole:ClearAllPoints()
    hole:SetPoint("TOPLEFT", gridFrame, "TOPLEFT",
        (c - 1) * cs + 7, -((r - 1) * cs) - 7)
    hole._wamRow = r
    hole._wamCol = c
    hole._oval:SetSize(cs - 24, math.floor((cs - 24) * 0.55))
    hole._oval:ClearAllPoints()
    hole._oval:SetPoint("BOTTOM", hole, "BOTTOM", 0, 8)
    hole._icon:SetSize(cs - 22, cs - 22)
    hole._icon:ClearAllPoints()
    hole._icon:SetPoint("CENTER", hole, "CENTER", 0, 4)
    hole._icon:Hide()
    if hole._fxFS then hole._fxFS:Hide() end
    hole:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)
    hole:Show()
end

function R:_EnsureGridFrame()
    if not self._gridFrame then
        local gf = CreateFrame("Frame", nil, self._fieldFrame, "BackdropTemplate")
        gf:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        gf:SetBackdropColor(0.12, 0.09, 0.06, 1)
        gf:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)
        self._gridFrame = gf
    end
    return self._gridFrame
end

local function EnsureHoleFx(h)
    if not h.fxFS and h.frame and h.frame._fxFS then
        h.fxFS = h.frame._fxFS
    end
    if not h.fxFS then
        h.fxFS = h.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        h.fxFS:SetPoint("CENTER", h.frame, "CENTER", 0, 10)
        h.fxFS:Hide()
        h.frame._fxFS = h.fxFS
    end
    return h.fxFS
end

function R:_buildGrid(board)
    local g  = board.gridSize
    local cs = math.floor(CFG.field_size / g)

    if self._builtGrid ~= g then
        if self._holePool then self._holePool:ReleaseAll() end
        self._holes = {}
        self._builtGrid = g
    end
    if not self._holePool then self._holePool = CreateHolePool() end

    local gridFrame = self:_EnsureGridFrame()
    gridFrame:SetParent(self._fieldFrame)

    local gridW = g * cs
    local gridH = g * cs
    gridFrame:SetSize(gridW + 8, gridH + 8)
    gridFrame:ClearAllPoints()
    gridFrame:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    gridFrame:Show()

    for r = 1, g do
        if not self._holes[r] then self._holes[r] = {} end
        for c = 1, g do
            local h = self._holes[r][c]
            if not h then
                local hole = self._holePool:Acquire({})
                ConfigureHole(hole, gridFrame, r, c, cs)
                h = { frame = hole, icon = hole._icon, fxFS = hole._fxFS }
                self._holes[r][c] = h
            else
                ConfigureHole(h.frame, gridFrame, r, c, cs)
                h.icon:Hide()
                if h.fxFS then h.fxFS:Hide() end
            end
        end
    end
end

-- ============================================================
-- ShowMole / HideMole (unverändert)
-- ============================================================
function R:ShowMole(r, c, icon, isBomb)
    local h = self._holes[r] and self._holes[r][c]
    if not h then return end
    h.icon:SetTexture(icon)
    h.icon:Show()
    if isBomb then
        h.frame:SetBackdropBorderColor(1, 0.15, 0.15, 1)
    else
        h.frame:SetBackdropBorderColor(0.15, 0.85, 0.15, 1)
    end
end

function R:HideMole(r, c)
    local h = self._holes[r] and self._holes[r][c]
    if not h then return end
    h.icon:Hide()
    h.frame:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)
end

-- ============================================================
-- Effekte (unverändert)
-- ============================================================
function R:ShowHitEffect(r, c, text)
    local h = self._holes[r] and self._holes[r][c]
    if not h then return end
    local fx = EnsureHoleFx(h)
    fx:SetText("|cff00ff00" .. (text or "+10") .. "|r")
    fx:Show()
    C_Timer.After(0.5, function() if fx then fx:Hide() end end)
end

function R:ShowBoomEffect(r, c)
    local h = self._holes[r] and self._holes[r][c]
    if not h then return end
    h.frame:SetBackdropColor(0.60, 0.05, 0.05, 1)
    local fx = EnsureHoleFx(h)
    fx:SetText(ArcadiaNexus.GetLocaleTable("WHACKAMOLE")["boom_text"])
    fx:Show()
    C_Timer.After(0.7, function()
        if fx then fx:Hide() end
        if h and h.frame then h.frame:SetBackdropColor(0.20, 0.14, 0.08, 1) end
    end)
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(board)
    self.state     = "PLAYING"
    self._lastDiff = board.difficulty

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._hudBox then self._hudBox:Show() end
    if self._goldGrid then self._goldGrid:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("WHACKAMOLE")["btn_exit"])
    end

    -- HUD einblenden
    if self._hudBox then self._hudBox:Show() end

    self:_buildGrid(board)
    if self._gridFrame then self._gridFrame:Show() end
    self:UpdateHUD(board)
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"

    if self._holes then
        for _, row in pairs(self._holes) do
            for _, h in pairs(row) do
                if h then
                    if h.icon then h.icon:Hide() end
                    if h.fxFS then h.fxFS:Hide() end
                    if h.frame then
                        h.frame:SetBackdropColor(0.20, 0.14, 0.08, 1)
                        h.frame:SetBackdropBorderColor(0.35, 0.25, 0.10, 1)
                    end
                end
            end
        end
    end
    if self._holePool then self._holePool:ReleaseAll() end
    self._holes = {}
    self._builtGrid = nil
    if self._gridFrame   then self._gridFrame:Hide()   end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hudBox      then self._hudBox:Hide()      end
    if self._goldGrid    then self._goldGrid:Hide()    end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("WHACKAMOLE")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("WHACKAMOLE")["hint_start"] or "")
        self._hintFS:Show()
    end
end

-- ============================================================
-- ALIASE (Engine ruft diese direkt auf, kein Event-Bus)
-- ============================================================
-- Engine ruft R:EnterPlayState(board) direkt → weiterleiten
function R:EnterPlayState(board)
    self:OnGameStarted(board)
end

-- Wird vom Start/Beenden-Button und OnHide aufgerufen
function R:StopGame()
    local E = ArcadiaNexus.WAM_Engine
    if E then E:StopGame() end
    self:EnterIdleState()
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "WHACKAMOLE",
    label     = "Whack-a-Mole",
    renderer  = "WAM_Renderer",
    engine    = "WAM_Engine",
    container = "_wamContainer",
    category  = "GESCHICK",
})
