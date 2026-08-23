-- ============================================================
--  ArcadiaNexus
--  Games/ReactionStrike/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach WhackAMole-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD: Score links, Reaktionszeit rechts (über Spielfeld)
--    - Controls-Leiste am BOTTOM: Dropdown Schwierigkeit + Start/Beenden
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--    - Overlay auf _fieldFrame
--
--  Spielfeld-Logik (unverändert):
--    Orb-Frame, Glow, PulseFrame, KeyFrame,
--    ShowSignal/ShowFakeout/ShowResult/ShowPenalty
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.RS_Renderer = {}
local R = ArcadiaNexus.RS_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_size   = 440,
    field_ofs_x  = 0,
    field_ofs_y  = 15,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1,
    border_w     = 800,
    border_h     = 553,
    border_ofs_x = 0,
    border_ofs_y = 0,
    logo_w       = 494,
    logo_h       = 237,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    hud_score_w     = 140,
    hud_score_h     = 28,
    hud_score_x     = -250,
    hud_score_y     = -195,
    hud_score_alpha = 0.75,
    hud_ms_w        = 140,
    hud_ms_h        = 28,
    hud_ms_x        = 250,
    hud_ms_y        = -195,
    hud_ms_alpha    = 0.75,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    orb_size     = 64,
    orb_glow_size = 96,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local RS_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\ReactionStrike\\assets\\background\\background_rs",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\ReactionStrike\\assets\\logo\\logo_reaktionstrike",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\ReactionStrike\\assets\\border\\border_reaktionstrike",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================



-- HUD – relativ zu self.frame CENTER

-- Orb-Konstanten (unverändert)
local ICON_SIGNAL   = "Interface\\Icons\\Spell_Arcane_ArcaneBolt"
local ICON_FAKEOUT  = "Interface\\Icons\\Spell_Fire_FlameBolt"
local ICON_PULSE    = "Interface\\Icons\\Spell_Arcane_Teleport"

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
R.overlay       = nil
R.state         = "IDLE"

-- Spielfeld
R._orbFrame     = nil
R._orbGlow      = nil
R._pulseFrame   = nil
R._pulseGen     = 0
R._waitHintFS   = nil
R._keyFrame     = nil

-- HUD
R._scoreLbl     = nil
R._scoreFS      = nil
R._reactionLbl  = nil
R._reactionFS   = nil
R._statusFS     = nil
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
    self:_CreateField()
    self:_CreateHUD()
    self:_CreateControls()
    self:_CreateOverlay()
    self:_SetupKeyboard()
    self:EnterIdleState()

    -- Spielfeld-Dimensionen an Logic übergeben
    local Logic = ArcadiaNexus.RS_Logic
    if Logic then
        Logic.FIELD_W  = CFG.field_size
        Logic.FIELD_H  = CFG.field_size
        Logic.ORB_SIZE = CFG.orb_size
    end
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
        outerName = "ArcadiaNexus_RS_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._rsContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("REACTIONSTRIKE", ArcadiaNexus.RS_Engine, function(E)
            E:StopGame()
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_size, CFG.field_size)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = false, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    ff:SetBackdropColor(0.04, 0.02, 0.10, 0)
    ff:SetBackdropBorderColor(0.40, 0.20, 0.70, 0)
    self._fieldFrame = ff

    -- Klick auf Spielfeld
    ff:EnableMouse(true)
    ff:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            local E = ArcadiaNexus.RS_Engine
            if E then E:HandleInput("STRIKE") end
        end
    end)
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(RS_ASSETS.bg)
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
    tex:SetTexture(RS_ASSETS.border)
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        RS_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- SPIELFELD-ELEMENTE (Orb, Glow, Pulse, WaitHint)
-- ============================================================
function R:_CreateField()
    local field = self._fieldFrame

    -- Warte-Puls
    local pulseFrame = CreateFrame("Frame", nil, field)
    pulseFrame:SetSize(24, 24)
    pulseFrame:SetPoint("CENTER", field, "CENTER", 0, 0)
    pulseFrame:SetAlpha(0)
    pulseFrame:Hide()
    local pulseTex = pulseFrame:CreateTexture(nil, "OVERLAY")
    pulseTex:SetAllPoints()
    pulseTex:SetTexture(ICON_PULSE)
    pulseTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    self._pulseFrame = pulseFrame

    -- Orb-Glow
    local glow = field:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(CFG.orb_glow_size, CFG.orb_glow_size)
    glow:SetPoint("CENTER", field, "TOPLEFT", 0, 0)
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.3)
    glow:Hide()
    self._orbGlow = glow

    -- Orb (Button für direkten Klick)
    local orb = CreateFrame("Button", nil, field)
    orb:SetSize(CFG.orb_size, CFG.orb_size)
    orb:SetPoint("CENTER", field, "TOPLEFT", 0, 0)
    orb:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            local E = ArcadiaNexus.RS_Engine
            if E then E:HandleInput("STRIKE") end
        end
    end)
    local orbTex = orb:CreateTexture(nil, "ARTWORK")
    orbTex:SetAllPoints()
    orbTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    orb._tex = orbTex
    orb:Hide()
    self._orbFrame = orb

    -- Warte-Hinweis im Spielfeld
    local waitHintFS = field:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    waitHintFS:SetPoint("BOTTOM", field, "BOTTOM", 0, 40)
    waitHintFS:SetJustifyH("CENTER")
    waitHintFS:SetTextColor(0.80, 0.75, 0.60)
    waitHintFS:Hide()
    self._waitHintFS = waitHintFS
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Score") .. ": 0",
        shown = false,
    })
    self._msBox, self._reactionFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_ms_w, h = CFG.hud_ms_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_ms_x, y = CFG.hud_ms_y,
        alpha = CFG.hud_ms_alpha,
        text = (L["lbl_ms"] or "ms") .. ": --",
        shown = false,
    })
    self._scoreLbl, self._reactionLbl = nil, nil

    -- Bestzeit / letzter Versuch (unter HUD)
    local statusFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("CENTER", f, "CENTER", 0, CFG.hud_score_y + 30)
    statusFS:SetJustifyH("CENTER")
    statusFS:SetTextColor(0.90, 0.85, 0.70)
    statusFS:Hide()
    self._statusFS = statusFS

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_RefreshStatus(diff)
    local S = ArcadiaNexus.RS_Settings
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    if not self._statusFS or not S then return end
    local d    = diff or self._lastDiff or "normal"
    local best = S:GetBestMs(d)
    local last = S:GetLastMs(d)
    local txt  = ""
    if last then
        txt = (L["lbl_lasttime"] or "Letzter") .. ": " .. last .. " " .. (L["lbl_ms"] or "ms")
    end
    if best then
        if txt ~= "" then txt = txt .. "   " end
        txt = txt .. (L["lbl_besttime"] or "Bestzeit") .. ": " .. best .. " " .. (L["lbl_ms"] or "ms")
    end
    if txt ~= "" then
        self._statusFS:SetText(txt)
        self._statusFS:Show()
    else
        self._statusFS:Hide()
    end
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (linkes Segment)
    local S = ArcadiaNexus.RS_Settings

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "easy",   label = L["diff_easy"]   },
            { key = "normal", label = L["diff_normal"]  },
            { key = "hard",   label = L["diff_hard"]    },
        },
        function()
            return (S and S:Get("difficulty")) or "normal"
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
        local E = ArcadiaNexus.RS_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            local diff = R._lastDiff
                or (ArcadiaNexus.RS_Settings and ArcadiaNexus.RS_Settings:Get("difficulty"))
                or "normal"
            E:StartGame(diff)
        end
    end)
    self._startBtn = startBtn

    -- Punkte / MS in der Controls-Leiste (rechtes Segment, x=+170)
    local hudCtrlFS = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hudCtrlFS:SetPoint("CENTER", cf, "CENTER", bar.segX[3], 0)
    hudCtrlFS:SetJustifyH("CENTER")
    hudCtrlFS:SetTextColor(1, 0.84, 0)
    hudCtrlFS:SetText("")
    self._hudCtrlFS = hudCtrlFS
end

-- ============================================================
-- OVERLAY
-- ============================================================
function R:_CreateOverlay()
    if self.overlay then return end
    local f  = self._canvas
    local L  = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    local UI = ArcadiaNexus.UI

    -- Klickblocker ohne Abdunklung (wie GameResult OVERLAY_A = 0).
    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints(self._fieldFrame)
    ov:SetFrameLevel(self._fieldFrame:GetFrameLevel() + 8)
    ov:EnableMouse(true)
    ov:Hide()

    local panel = CreateFrame("Frame", nil, ov, "BackdropTemplate")
    panel:SetSize(320, 160)
    panel:SetPoint("CENTER", ov, "CENTER", 0, 0)
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
    panel:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    ov.panel = panel

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("CENTER", panel, "CENTER", 0, 28)
    ov.titleFS = titleFS

    local subFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subFS:SetPoint("TOP", titleFS, "BOTTOM", 0, -10)
    subFS:SetJustifyH("CENTER")
    ov.subFS = subFS

    local sub2FS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub2FS:SetPoint("TOP", subFS, "BOTTOM", 0, -6)
    sub2FS:SetJustifyH("CENTER")
    sub2FS:SetTextColor(0.90, 0.85, 0.70)
    ov.sub2FS = sub2FS

    local retryBtn = UI.CreateArcadiaButton(panel, L["btn_retry"] or "Nochmal", 130, 30)
    retryBtn:SetPoint("BOTTOM", panel, "BOTTOM", -70, 14)
    retryBtn:SetScript("OnClick", function()
        ov:Hide()
        local E = ArcadiaNexus.RS_Engine
        if E then E:Retry() end
    end)
    ov.retryBtn = retryBtn

    local exitBtn = UI.CreateArcadiaButton(panel, L["btn_exit"] or "Beenden", 110, 30)
    exitBtn:SetPoint("BOTTOM", panel, "BOTTOM", 70, 14)
    exitBtn:SetScript("OnClick", function()
        ov:Hide()
        local E = ArcadiaNexus.RS_Engine
        if E then E:StopGame() end
    end)
    ov.exitBtn = exitBtn

    self.overlay = ov
end

-- ============================================================
-- KEYBOARD
-- ============================================================
function R:_SetupKeyboard()
    if self._keyFrame then return end
    local kf = CreateFrame("Frame", "ArcadiaNexus_RS_KeyFrame", self._canvas)
    kf:SetAllPoints(self._canvas)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        if key == "SPACE" then
            local E = ArcadiaNexus.RS_Engine
            if E then E:HandleInput("STRIKE") end
        end
    end)
    self._keyFrame = kf
end

function R:_EnableKeyboard(enable)
    if self._keyFrame then self._keyFrame:EnableKeyboard(enable) end
end

-- ============================================================
-- PULS-ANIMATION (unverändert)
-- ============================================================
function R:_StartPulse()
    local pulse = self._pulseFrame
    if not pulse then return end
    pulse:Show()
    pulse:SetAlpha(0.4)
    self._pulseGen = (self._pulseGen or 0) + 1
    local gen      = self._pulseGen
    local accum    = 0
    local speed    = 1.5
    pulse:SetScript("OnUpdate", function(_, dt)
        if (self._pulseGen or 0) ~= gen then return end
        accum = accum + dt * speed
        local a = 0.2 + 0.3 * math.abs(math.sin(accum * math.pi))
        pulse:SetAlpha(a)
    end)
end

function R:_StopPulse()
    self._pulseGen = (self._pulseGen or 0) + 1
    if self._pulseFrame then
        self._pulseFrame:SetScript("OnUpdate", nil)
        self._pulseFrame:Hide()
    end
end

-- ============================================================
-- ORB POSITIONIEREN (unverändert)
-- ============================================================
function R:_PlaceOrb(gs)
    local orb  = self._orbFrame
    local glow = self._orbGlow
    if not orb then return end
    local x = gs.orb.x + CFG.orb_size / 2
    local y = -(gs.orb.y + CFG.orb_size / 2)
    orb:ClearAllPoints()
    orb:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", x, y)
    if glow then
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", x, y)
    end
end

function R:UpdateOrbPosition(gs)
    self:_PlaceOrb(gs)
end

function R:_ShowOrb(gs, orbType)
    local orb  = self._orbFrame
    local glow = self._orbGlow
    if not orb then return end
    if orbType == "SIGNAL" then
        orb._tex:SetTexture(ICON_SIGNAL)
        if glow then glow:SetVertexColor(0.20, 0.40, 1.00, 1) end
    else
        orb._tex:SetTexture(ICON_FAKEOUT)
        if glow then glow:SetVertexColor(1.00, 0.20, 0.10, 1) end
    end
    self:_PlaceOrb(gs)
    orb:SetAlpha(0); orb:Show()
    UIFrameFadeIn(orb, 0.1, 0, 1)
    if glow then glow:Show() end
end

function R:_HideOrb()
    if self._orbFrame then self._orbFrame:Hide() end
    if self._orbGlow  then self._orbGlow:Hide()  end
end

-- ============================================================
-- STATE-ANZEIGEN (aufgerufen vom Engine)
-- ============================================================
function R:OnGameStarted(gs)
    self.state     = "PLAYING"
    self._lastDiff = gs.difficulty

    if self.overlay      then self.overlay:Hide()      end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")["btn_exit"])
    end

    -- HUD einblenden
    if self._scoreBox then self._scoreBox:Show() end
    if self._msBox    then self._msBox:Show()    end
    if self._scoreFS then
        local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
        self._scoreFS:SetText((L["lbl_score"] or "Score") .. ": " .. tostring(gs.score or 0))
    end
    if self._reactionFS then
        local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
        self._reactionFS:SetText((L["lbl_ms"] or "ms") .. ": --")
    end

    self:_EnableKeyboard(true)
    self:_RefreshStatus(gs.difficulty)
end

function R:ShowWaiting(gs)
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    self:_HideOrb()
    self:_StartPulse()
    self:_EnableKeyboard(true)
    if self.overlay then self.overlay:Hide() end
    if self._waitHintFS then
        self._waitHintFS:SetText(L["state_waiting"] or "Warte auf den Orb...")
        self._waitHintFS:Show()
    end
end

function R:ShowSignal(gs)
    self:_StopPulse()
    self:_EnableKeyboard(true)
    if self._waitHintFS then self._waitHintFS:Hide() end
    self:_ShowOrb(gs, "SIGNAL")
end

function R:ShowFakeout(gs)
    self:_StopPulse()
    self:_EnableKeyboard(true)
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    if self._waitHintFS then
        self._waitHintFS:SetText("|cffff4444" .. (L["state_fakeout_hint"] or "Roter Orb = NICHT klicken!") .. "|r")
        self._waitHintFS:Show()
    end
    self:_ShowOrb(gs, "FAKEOUT")
end

function R:ShowFakeoutSurvived(gs)
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    self:_HideOrb()
    self:_StopPulse()
    local ov = self.overlay
    if not ov then return end
    ov.titleFS:SetText("|cff00ff88" .. (L["fakeout_survived"] or "Nicht getäuscht!") .. "|r")
    ov.titleFS:SetTextColor(0.20, 1.00, 0.50)
    ov.subFS:SetText("")
    ov.sub2FS:SetText("")
    if ov.retryBtn then ov.retryBtn:Hide() end
    if ov.exitBtn  then ov.exitBtn:Hide()  end
    ov:SetAlpha(0); ov:Show()
    UIFrameFadeIn(ov, 0.3, 0, 0.70)
end

function R:ShowResult(gs)
    local L     = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    local UI    = ArcadiaNexus.UI
    local Logic = ArcadiaNexus.RS_Logic

    self:_HideOrb()
    self:_StopPulse()
    self:_EnableKeyboard(false)
    if self._waitHintFS then self._waitHintFS:Hide() end

    local ms = gs.reactionMs or 0
    if self._reactionFS then
        self._reactionFS:SetText((L["lbl_ms"] or "ms") .. ": " .. tostring(ms))
    end
    if self._scoreFS then
        self._scoreFS:SetText((L["lbl_score"] or "Score") .. ": " .. tostring(gs.score or 0))
    end
    self:_RefreshStatus(gs.difficulty)

    local label, color = Logic:GetResultLabel(ms)

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = label,
        titleColor = color,
        subtitle   = ms .. " " .. (L["lbl_ms"] or "ms"),
        score      = gs.score,
        gameId     = "REACTIONSTRIKE",
        difficulty = gs.difficulty,
        L          = L,
        onRetry    = function()
            local E = ArcadiaNexus.RS_Engine
            if E then E:Retry() end
        end,
        onExit = function()
            local E = ArcadiaNexus.RS_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:ShowPenalty(gs, duration)
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    self:_HideOrb()
    self:_StopPulse()
    if self._waitHintFS then self._waitHintFS:Hide() end

    local penaltyText
    if gs.penaltyType == "EARLYCLICK" then
        penaltyText = L["penalty_early"] or "Zu früh!"
    elseif gs.penaltyType == "FAKEOUT" then
        penaltyText = L["penalty_fakeout"] or "Falscher Orb!"
    else
        penaltyText = "|cffff4444X|r"
    end

    local ov = self.overlay
    if not ov then return end
    ov.titleFS:SetText("|cffff4444" .. penaltyText .. "|r")
    ov.titleFS:SetTextColor(1, 0.3, 0.3)
    ov.subFS:SetText((L["penalty_wait"] or "Warte") .. " " .. string.format("%.1f", duration) .. "s...")
    ov.subFS:SetTextColor(0.80, 0.75, 0.60)
    ov.sub2FS:SetText("")
    if ov.retryBtn then ov.retryBtn:Hide() end
    if ov.exitBtn  then ov.exitBtn:Hide()  end
    ov:SetAlpha(0); ov:Show()
    UIFrameFadeIn(ov, 0.2, 0, 0.88)
end

function R:UpdatePenaltyCountdown(remaining)
    local L  = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")
    local ov = self.overlay
    if not ov then return end
    local secs = math.max(0, remaining)
    ov.subFS:SetText((L["penalty_wait"] or "Warte") .. " " .. string.format("%.1f", secs) .. "s...")
    if secs <= 0 then ov:Hide() end
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:_HideOrb()
    self:_StopPulse()
    self:_EnableKeyboard(false)

    if self.overlay      then self.overlay:Hide()      end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._scoreBox then self._scoreBox:Hide() end
    if self._msBox    then self._msBox:Hide()    end
    if self._statusFS    then self._statusFS:Hide()    end
    if self._waitHintFS  then self._waitHintFS:Hide()  end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")["state_idle"] or "")
        self._hintFS:Show()
    end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "REACTIONSTRIKE",
    label     = "Reaction Strike",
    category  = "GESCHICK",
    renderer  = "RS_Renderer",
    engine    = "RS_Engine",
    container = "_rsContainer",
})
