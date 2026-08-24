--[[
    NEXUS GAMING HUB
    Modul: MainFrame
    Verantwortlich für: Root-Frame-Bau, Toggle/Slash, Init-Sequenz,
                        Event-Frames (SafeMode/Tick), Public API, Minimap-Button

    Abhängigkeiten (müssen vor diesem Modul geladen sein):
        UI/TabsController.lua   (NexusTabs, NexusTabState, BuildBottomTabs)
        UI/GamesPanel/            (modulares Sidebar-Panel, GamesPanel_*.lua)
]]

local Layout = ArcadiaNexus.Layout

-- Über typische Addon-UI (MEDIUM/HIGH), unter Nexus-eigenen Dialogen (200+)
local MAIN_FRAME_STRATA = "DIALOG"
local MAIN_FRAME_LEVEL  = 100

-- F-Referenz (lebt in ArcadiaNexus_UI.lua, wird per GetF() abgerufen)
-- Lazy: erst nach Init() von ArcadiaNexus_UI verfügbar
local function F() return ArcadiaNexus.UI.GetF() end

local function BuildMainFrame()
    local f = CreateFrame("Frame", "NexusMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(Layout.frame.width, Layout.frame.height)
    -- Durchgehender äußerer Holzrahmen wie beim nativen AchievementFrame.
    -- Die separaten WoodBorder-Corner weiter unten bilden dessen Zierecken.
    f:SetBackdrop({
        edgeFile = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
        edgeSize = 64,
        tileEdge = true,
    })
    -- Position aus DB wiederherstellen, sonst Standard-Center
    -- ArcadiaNexusDB ist zu diesem Zeitpunkt (PLAYER_ENTERING_WORLD) bereits geladen
    local pos = ArcadiaNexusDB and ArcadiaNexusDB.windowPos
    if pos and pos.x and pos.y then
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end
    f:SetFrameStrata(MAIN_FRAME_STRATA)
    f:SetFrameLevel(MAIN_FRAME_LEVEL)
    f:SetMovable(true)
    -- Drag-Lock aus DB laden
    if ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.lockUI then
        f:SetMovable(false)
    end
    -- UI-Scale aus DB laden
    local initScale = ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.uiScale
    if initScale and initScale ~= 1.0 then
        f:SetScale(initScale)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Position in DB speichern
        local db = ArcadiaNexusDB
        if db then
            local point, _, relPoint, x, y = self:GetPoint(1)
            db.windowPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- verhindert dass das Fenster aus dem Bildschirm gezogen wird
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, 0, 0, 0)

    -- Haupt-BG: AchievementBackground, nur obere Hälfte (TexCoord 0,1,0,0.5)
    local mainBG = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    mainBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-AchievementBackground")
    -- mainBG: BOTTOMRIGHT fest, TOPLEFT wird nach BuildHeader gesetzt
    mainBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    f._mainBG = mainBG
    mainBG:SetTexCoord(0, 1, 0, 0.5)

    -- Black Cover a=0.75 (macht BG sehr dunkel wie Original)
    local blackCover = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    blackCover:SetTexture("Interface\\Buttons\\WHITE8X8")
    blackCover:SetPoint("TOPLEFT",     mainBG, "TOPLEFT")
    blackCover:SetPoint("BOTTOMRIGHT", mainBG, "BOTTOMRIGHT")
    blackCover:SetVertexColor(0, 0, 0, 0.75)

    -- Metallband Links (16x auto)
    local metalH = Layout.GetMetalBorderHeight()
    local mL = f:CreateTexture(nil, "ARTWORK", nil, 0)
    mL:SetTexture("Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Left")
    mL:SetSize(16, metalH); mL:SetPoint("LEFT", f, "LEFT", 14, 0)
    mL:SetTexCoord(0, 1, 0, 0.87)

    -- Metallband Rechts (gespiegelt)
    local mR = f:CreateTexture(nil, "ARTWORK", nil, 0)
    mR:SetTexture("Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Left")
    mR:SetSize(16, metalH); mR:SetPoint("RIGHT", f, "RIGHT", -13, 0)
    mR:SetTexCoord(1, 0, 0.87, 0)

    -- Metallband Oben
    local mT = f:CreateTexture(nil, "ARTWORK", nil, 0)
    mT:SetTexture("Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Top")
    mT:SetHeight(16)
    mT:SetPoint("TOPLEFT",  f, "TOPLEFT",  28, -12)
    mT:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -12)
    mT:SetTexCoord(0.87, 0, 0, 1)

    -- Metallband Unten
    local mB = f:CreateTexture(nil, "ARTWORK", nil, 0)
    mB:SetTexture("Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Top")
    mB:SetHeight(16)
    mB:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  28, 13)
    mB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 13)
    mB:SetTexCoord(0, 0.87, 1.0, 0)

    -- Metallecken (Joint 32x32)
    local function MakeJoint(pt, tx, ty, l, r, t, b)
        local j = f:CreateTexture(nil, "OVERLAY", nil, 1)
        j:SetTexture("Interface\\AchievementFrame\\UI-Achievement-MetalBorder-Joint")
        j:SetSize(32, 32); j:SetPoint(pt, f, pt, tx, ty)
        j:SetTexCoord(l, r, t, b)
    end
    MakeJoint("TOPLEFT",      9,  -7,  1, 0, 1, 0)
    MakeJoint("TOPRIGHT",    -8,  -7,  0, 1, 1, 0)
    MakeJoint("BOTTOMLEFT",   9,   8,  1, 0, 0, 1)
    MakeJoint("BOTTOMRIGHT", -8,   8,  0, 1, 0, 1)

    -- Holzecken (WoodBorder-Corner 64x64, gespiegelt nach Blizzard-XML)
    local function MakeCorner(pt, tx, ty, l, r, t, b)
        local c = f:CreateTexture(nil, "OVERLAY", nil, 2)
        c:SetTexture("Interface\\AchievementFrame\\UI-Achievement-WoodBorder-Corner")
        c:SetSize(64, 64); c:SetPoint(pt, f, pt, tx, ty)
        c:SetTexCoord(l, r, t, b)
    end
    MakeCorner("TOPLEFT",      4,  -2,  0, 1, 0, 1)
    MakeCorner("TOPRIGHT",    -4,  -2,  1, 0, 0, 1)
    MakeCorner("BOTTOMLEFT",   4,   3,  0, 1, 1, 0)
    MakeCorner("BOTTOMRIGHT", -4,   3,  1, 0, 1, 0)

    -- Close-Button
    local cb = CreateFrame("Button", "NexusCloseBtn", f, "UIPanelCloseButton")
    cb:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    cb:SetScript("OnClick", function() f:Hide() end)

    -- Escape
    f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false); self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Beim Öffnen über andere Addon-Frames in derselben Strata-Ebene
    f:SetScript("OnShow", function(self)
        self:Raise()
    end)

    -- Beim Schließen des UI: alle laufenden Spiele stoppen
    f:SetScript("OnHide", function()
        NexusTabs.StopAllGames()
    end)

    f:Hide()
    F().main = f
    return f
end

-- ============================================================
-- HEADER
-- Blizzard-Struktur (aus XML):
--   Header-Frame: 726x106 (skaliert: 812x135)
--   Anker: BOTTOMLEFT → Frame.TOPLEFT  x=+29  y=-49
--   → Header ragt 87px ÜBER den Frame hinaus
--   Textur Links:  512x106, BOTTOMLEFT, TexCoords 0,1,0,0.4140625
--   Textur Rechts: 215x100, BOTTOMLEFT von Links+BOTTOMRIGHT, y=-6
--                  TexCoords 0,0.419921875,0.4140625,0.8046875

-- ============================================================
-- TOGGLE / SLASH
-- ============================================================
local function Toggle()
    if not F().main then return end
    if F().main:IsShown() then
        F().main:Hide()
    else
        ArcadiaNexus.UI.UpdateBadge()
        F().main:Show()
    end
end

local oldSlash = SlashCmdList["NEXUS"]
SlashCmdList["NEXUS"] = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "ui" then Toggle()
    elseif oldSlash then oldSlash(msg) end
end



local evFrame = CreateFrame("Frame", "NexusUIEvFrame")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local tickAcc = 0
local tickF = CreateFrame("Frame", "NexusUITickFrame")
tickF:SetScript("OnUpdate", function(_,e)
    if not F().main or not F().main:IsShown() then return end
    tickAcc = tickAcc + e
    if tickAcc >= 2.0 then tickAcc=0; ArcadiaNexus.UI.UpdateBadge() end
end)

-- ============================================================
-- INITIALISIERUNG
-- ============================================================
local function Init()
    Layout.Validate()
    local main = BuildMainFrame()
    ArcadiaNexus.UI.BuildHeader(main)
    -- FIX: mainBG TOPLEFT erst NACH BuildHeader() setzen,
    -- damit F().headerBG existiert (ChatGPT-Fix gegen Header-Überlapp)
    if main._mainBG and F().headerBG then
        main._mainBG:SetPoint("TOPLEFT", main, "TOPLEFT", 16, -16)
    end
    ArcadiaNexus.UI.SetGamesPanelFrameRefs(F())  -- Dependency Injection: F an GamesPanel übergeben
    ArcadiaNexus.UI.BuildCategoryPanel(main)
    ArcadiaNexus.UI.BuildSettingsCategoryPanel(main)
    ArcadiaNexus.UI.BuildLeaderboardCategoryPanel(main)
    ArcadiaNexus.UI.BuildAchievementCategoryPanel(main)
    ArcadiaNexus.UI.BuildContentPanel(main)
    NexusTabs.SetFrameRefs(F())
    ArcadiaNexus.TabRegistry.InvokeOnBuild(main, F())
    BuildBottomTabs(main)

    NexusTabs.RefreshPanelVisibility()
    NexusTabs.RefreshTabButtons()
    ArcadiaNexus.UI.UpdateBadge()

    -- Ab hier ist der Core-Hub vollständig aufgebaut. Spiel-Renderer sind
    -- optionale Module und werden anschließend einzeln fehlerisoliert gestartet.
    ArcadiaNexus.UI._hubUiInitialized = true

    -- Event-Listener fuer Streak/Gold im Header
    ArcadiaNexus.Engine:On("STREAK_UPDATED", function() pcall(ArcadiaNexus.UI.UpdateBadge) end)
    ArcadiaNexus.Engine:On("GOLD_UPDATED",   function() pcall(ArcadiaNexus.UI.UpdateBadge) end)

    ArcadiaNexus.UI.CreateMinimapButton()

    -- GOTD-Badge aufbauen (braucht DB)
    pcall(ArcadiaNexus.UI.BuildGotdBadge)
    pcall(ArcadiaNexus.UI.UpdateBadge)

    -- Optionale Spielmodule bewusst zuletzt starten. Ihre Fehlergrenze liegt
    -- in GameRegistry.InitRenderer; der Core-Hub ist zu diesem Zeitpunkt fertig.
    local GR = ArcadiaNexus.GameRegistry
    if GR then
        local summary = GR.InitRenderers()
        GR.SetupInitialContainers()
        if summary.failed > 0 then
            GH_LogWarn("MainFrame", tostring(summary.failed)
                .. " Spiel-Renderer konnten nicht initialisiert werden; der Hub bleibt verfügbar.")
        end
    end
end

local initF = CreateFrame("Frame", "NexusUIInitFrame")
initF:RegisterEvent("PLAYER_ENTERING_WORLD")
initF:SetScript("OnEvent", function(self, e)
    if e == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Init()
    end
end)

-- ============================================================
-- UI SCALING
-- ============================================================
-- Skaliert NexusMainFrame. Toast + GOTD sind auf UIParent verankert
-- und skalieren nicht mit → nach Scale-Wechsel Anker neu setzen.
local function ApplyScale(scale)
    scale = scale or 1.0
    -- Clamp auf erlaubte Stufen
    if scale < 1.0 then scale = 1.0 end
    if scale > 1.5 then scale = 1.5 end

    local main = F().main
    if main then main:SetScale(scale) end

    -- DB speichern
    if not ArcadiaNexusDB.settings then ArcadiaNexusDB.settings = {} end
    ArcadiaNexusDB.settings.uiScale = scale

    -- Toast-Anker neu positionieren (UIParent-verankert, skaliert nicht mit)
    local TM = ArcadiaNexus.ToastManager
    if TM and TM.UpdateAnchor then pcall(function() TM:UpdateAnchor() end) end

    -- GOTD-Badge neu positionieren
    local db    = ArcadiaNexusDB.gotdAnchor
    local badge = _G["NexusGotdBadge"]
    if badge and db then
        badge:ClearAllPoints()
        badge:SetPoint("TOP", UIParent, "TOP", db.x or 0, db.y or -57)
    end

    GH_LogInfo("MainFrame", "UI Scale gesetzt: " .. tostring(scale))
end
ArcadiaNexus.UI.ApplyScale = ApplyScale

-- ============================================================
-- PUBLIC API
-- ============================================================
_G.NexusTabs     = NexusTabs
_G.NexusTabState = NexusTabState
_G.NexusTheme    = NexusTheme

_G.Nexus_UI = {
    Toggle       = Toggle,
    SetTab       = NexusTabs.SetActive,
    GetTab       = NexusTabs.GetActive,
    IsTabActive  = NexusTabs.IsActive,
    OnTabChanged = NexusTabs.OnTabChanged,
}
_G.ArcadiaNexusUI = {
    GetMainFrame         = function() return F().main end,
    GetGamesPanel        = function() return F().games end,
    GetSettingsPanel     = function() return F().settings end,
    GetScoreboardPanel   = function() return F().scoreboard end,
    GetActiveSettingsCat = function() return NexusTabState.activeSettingsCategory end,
    GetContentLabelFS    = function() return F().contentLabelFS end,
}

print("[Nexus UI] MainFrame geladen")

-- MinimapButton → UI/MinimapButton.lua (ArcadiaNexus.UI.CreateMinimapButton)
