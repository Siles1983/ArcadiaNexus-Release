--[[
    NEXUS GAMING HUB
    Modul: ContentPanel
    Verantwortlich für: SolidTex, CreateNexusScrollbar, BuildHeader,
                        BuildGotdBadge, BuildContentPanel

    Abhängigkeiten:
        UI/ArcadiaNexus_UI.lua  (F via ArcadiaNexus.UI.GetF(), Dimensionen)
        UI/TabsController.lua (NexusTabs, NexusTabState)

    Exportiert (via ArcadiaNexus.UI.*):
        ArcadiaNexus.UI.BuildHeader
        ArcadiaNexus.UI.BuildGotdBadge
        ArcadiaNexus.UI.BuildContentPanel
        CreateNexusScrollbar  (global, wird von GamesPanel verwendet)
]]

local Layout = ArcadiaNexus.Layout

-- F-Accessor
local function F() return ArcadiaNexus.UI.GetF() end

-- L lazy
local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

-- ============================================================
-- PANEL-SICHTBARKEIT
-- ============================================================
-- HILFSFUNKTION: solide Textur
-- ============================================================
local function SolidTex(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(r, g, b, a or 1)
    return t
end

-- ============================================================
-- Dragonflight / Midnight Scrollbar Helper
-- ============================================================

function CreateNexusScrollbar(scrollFrame, parent)

    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")

    scrollBar:SetHideIfUnscrollable(false)

    -- Track sichtbar machen (Questlog Style)
    scrollBar.hideTrack = false
    scrollBar.Track:SetAlpha(0.9)
    scrollBar.Track:Show()

    scrollBar.Track:ClearAllPoints()
    scrollBar.Track:SetPoint("TOP", scrollBar, "TOP", 0, -16) -- Erster Wert: Pillenform X-Achse -- Zweiter Wert: Länge der Pillen Form von oben nach unten
    scrollBar.Track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 16)-- Erster Wert: Keine Auswirkung -- Zweiter Wert: Länge der Pillen Form von unten nach oben
    scrollBar.Track:SetWidth(8)
	
	-- eigener Scrollbar Track (Questlog Style)
local trackBG = parent:CreateTexture(nil, "BACKGROUND", nil, -6)
scrollBar.TrackBG = trackBG

trackBG:SetPoint("TOP", scrollBar, "TOP", 0, -16)
trackBG:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 16)
trackBG:SetWidth(6)

trackBG:SetTexture("Interface\\Buttons\\WHITE8X8")
trackBG:SetVertexColor(0.55, 0.55, 0.55, 0.45)

    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -18)-- Erster Wert: Gesamte Scrollbar X-Achse -- Zweiter Wert: Gesamt länge der Scrollbar von oben nach unten
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 18)-- Erster Wert: Keine Auswirkung -- Zweiter Wert: Gesamt länge der Scrollbar von unten nach oben

    scrollFrame:EnableMouseWheel(true)

    -- ScrollFrame -> Scrollbar
scrollFrame:SetScript("OnVerticalScroll", function(self, offset)

    local range = self:GetVerticalScrollRange()

    if range > 0 then
        scrollBar:SetScrollPercentage(offset / range)
    else
        scrollBar:SetScrollPercentage(0)
    end

end)

    -- Scrollbar -> ScrollFrame
    scrollBar:RegisterCallback("OnScroll", function(_, percentage)
        local range = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(percentage * range)
    end)

    -- Mousewheel
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)

        local step = 40 -- Scrollgeschwindigkeit (Pixel pro Mausrad-Tick)
        local new = self:GetVerticalScroll() - delta * step

        if new < 0 then new = 0 end
        if new > self:GetVerticalScrollRange() then
            new = self:GetVerticalScrollRange()
        end

        self:SetVerticalScroll(new)
    end)

    scrollFrame.ScrollBar = scrollBar

    return scrollBar
end

-- ============================================================
-- HAUPTFRAME
-- ============================================================
-- ============================================================
-- BUILD MAIN FRAME → UI/MainFrame.lua
-- ============================================================
-- ============================================================
local function BuildHeader(parent)
    -- ── HEADER-FRAME (sitzt physisch ÜBER dem Hauptframe!) ──
    -- Blizzard: BOTTOMLEFT→TOPLEFT  x=26 y=-38  (skaliert: x=29 y=-49)
    local header = CreateFrame("Frame", "NexusHeaderFrame", parent)
    header:SetSize(812, 135)
    header:SetPoint("BOTTOM", parent, "TOP", 0, -39)
    header:SetFrameLevel(parent:GetFrameLevel() + 4)

    -- ── TEXTUR LINKS (512x106 → 573x135) ──
    -- TexCoords: 0,1,0,0.4140625
    local hLeft = header:CreateTexture(nil, "BACKGROUND", nil, 0)
    hLeft:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    hLeft:SetSize(573, 135)
    hLeft:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    hLeft:SetTexCoord(0, 1, 0, 0.4140625)
    F().headerBG = hLeft   -- Referenz für mainBG-Anker

    -- ── TEXTUR RECHTS (215x100 → 240x128) ──
    -- TexCoords: 0,0.419921875,0.4140625,0.8046875
    -- Anchor: BOTTOMLEFT von hLeft.BOTTOMRIGHT, y=-6 (skaliert: -8)
    local hRight = header:CreateTexture(nil, "BACKGROUND", nil, 0)
    hRight:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    hRight:SetSize(240, 128)
    hRight:SetPoint("BOTTOMLEFT", hLeft, "BOTTOMRIGHT", 0, -8)
    hRight:SetTexCoord(0, 0.419921875, 0.4140625, 0.8046875)

    -- ── PUNKTERAHMEN (PointBorder, 133x39 → 148x49) ──
    -- Anchor: BOTTOM +22,+20 (skaliert: +25,+26)
    local pBorder = header:CreateTexture(nil, "BORDER", nil, 0)
    pBorder:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    pBorder:SetSize(148, 49)
    pBorder:SetPoint("BOTTOM", header, "BOTTOM", 25, 26)
    pBorder:SetTexCoord(0.419921875, 0.6796875, 0.4140625, 0.56640625)

    -- ── TITEL: Nur Titel zentriert über der XP-Bar ──
    -- Wird nach barHolder verankert (der nach pBorder gebaut wird).
    -- Vorläufiger Anchor auf pBorder – wird nach barHolder-Bau korrigiert (siehe unten).
    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", pBorder, "TOP", 0, 12)
    -- Initialer Text: nur Titel ohne Level-Präfix
    titleFS:SetText("Arcade Initiate")
    titleFS:SetTextColor(1.00, 0.82, 0.00)
    F().titleFS = titleFS

-- Level-Up Glow Effekt – liegt auf der XP-Bar (barHolder wird später verankert)
local levelGlow = header:CreateTexture(nil, "OVERLAY", nil, 2)
levelGlow:SetTexture("Interface\\Cooldown\\star4")
levelGlow:SetBlendMode("ADD")
levelGlow:SetSize(160, 160)
-- Vorläufiger Anchor auf pBorder – wird nach barHolder-Bau auf barHolder umgesetzt
levelGlow:SetPoint("CENTER", pBorder, "CENTER", 0, 0)
levelGlow:SetVertexColor(1, 0.85, 0.2, 0.9)
levelGlow:SetAlpha(0)
F().levelGlow = levelGlow

-- Animation erstellen
local glowAG = levelGlow:CreateAnimationGroup()

local scale = glowAG:CreateAnimation("Scale")
scale:SetScale(1.6, 1.6)
scale:SetDuration(0.5)
scale:SetOrder(1)

local fade = glowAG:CreateAnimation("Alpha")
fade:SetFromAlpha(0.9)
fade:SetToAlpha(0)
fade:SetDuration(0.5)
fade:SetOrder(1)

-- OnFinished: Alpha hard auf 0 setzen damit Glow garantiert verschwindet
glowAG:SetScript("OnFinished", function()
    levelGlow:SetAlpha(0)
end)

F().levelGlowAG = glowAG

    -- ── PROGRESS BAR — im Schild zentriert, 120x15px ──
    local barHolder = CreateFrame("Frame", nil, header)
    barHolder:SetSize(120, 20)
    -- Positiv Y-Offset: Bar liegt INNERHALB des pBorder (nicht darunter)
    barHolder:SetPoint("TOP", pBorder, "TOP", 0, -14)

    -- Dunkler Hintergrund
    local barBG = barHolder:CreateTexture(nil, "BACKGROUND", nil, 0)
    barBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBG:SetAllPoints(barHolder)
    barBG:SetVertexColor(0, 0, 0, 0.55)

    -- Rand links
    local bBL = barHolder:CreateTexture(nil, "ARTWORK", nil, 1)
    bBL:SetTexture("Interface\\AchievementFrame\\UI-Achievement-ProgressBar-Border")
    bBL:SetSize(16, 0)
    bBL:SetPoint("TOPLEFT",    barHolder, "TOPLEFT",    -6,  5)
    bBL:SetPoint("BOTTOMLEFT", barHolder, "BOTTOMLEFT", -6, -5)
    bBL:SetTexCoord(0, 0.0625, 0, 0.75)

    -- Rand rechts
    local bBR = barHolder:CreateTexture(nil, "ARTWORK", nil, 1)
    bBR:SetTexture("Interface\\AchievementFrame\\UI-Achievement-ProgressBar-Border")
    bBR:SetSize(16, 0)
    bBR:SetPoint("TOPRIGHT",    barHolder, "TOPRIGHT",    6,  5)
    bBR:SetPoint("BOTTOMRIGHT", barHolder, "BOTTOMRIGHT", 6, -5)
    bBR:SetTexCoord(0.812, 0.8745, 0, 0.75)

    -- Rand Mitte
    local bBC = barHolder:CreateTexture(nil, "ARTWORK", nil, 1)
    bBC:SetTexture("Interface\\AchievementFrame\\UI-Achievement-ProgressBar-Border")
    bBC:SetPoint("TOPLEFT",     bBL, "TOPRIGHT")
    bBC:SetPoint("BOTTOMRIGHT", bBR, "BOTTOMLEFT")
    bBC:SetTexCoord(0.0625, 0.812, 0, 0.75)

-- StatusBar (füllt sich dynamisch per ratio 0-1)
local bar = CreateFrame("StatusBar", "NexusXPBar", barHolder)
bar:SetPoint("TOPLEFT",     barHolder, "TOPLEFT",      0, -2.9)
bar:SetPoint("BOTTOMRIGHT", barHolder, "BOTTOMRIGHT",  -0, 1)
bar:SetFrameLevel(barHolder:GetFrameLevel() + 1)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.00, 0.70, 0.10, 1)

-- leichter Blizzard-Gradient auf der XP-Bar
local barHighlight = bar:CreateTexture(nil, "OVERLAY", nil, 1)
barHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")

barHighlight:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
barHighlight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
barHighlight:SetHeight(3)

barHighlight:SetVertexColor(0.8, 1, 0.8, 0.22)

F().barHighlight = barHighlight

-- XP Gain Sweep Effekt
local sweep = bar:CreateTexture(nil, "OVERLAY", nil, 3)
sweep:SetTexture("Interface\\Buttons\\WHITE8X8")

sweep:SetSize(14, bar:GetHeight())
sweep:SetVertexColor(0.9, 1, 0.9, 0.65)

sweep:SetBlendMode("ADD")
sweep:SetAlpha(0)
sweep:Hide()

F().barSweep = sweep

-- Animation erstellen
local sweepAG = sweep:CreateAnimationGroup()

local trans = sweepAG:CreateAnimation("Translation")
trans:SetDuration(0.45)
trans:SetOrder(1)

local fade = sweepAG:CreateAnimation("Alpha")
fade:SetFromAlpha(0.7)
fade:SetToAlpha(0)
fade:SetDuration(0.45)
fade:SetOrder(1)

F().barSweepAG = sweepAG
sweepAG:SetScript("OnFinished", function()
    sweep:SetAlpha(0)
    sweep:Hide()
end)

-- ============================================================
-- Blizzard-style XP Animation
-- ============================================================
bar._targetValue = 0
bar._animating = false

bar:SetScript("OnUpdate", function(self, elapsed)
    if not self._animating then return end

    local current = self:GetValue()
    local target = self._targetValue

    local speed = 2.5 -- Geschwindigkeit der Animation

    local diff = target - current
    local step = diff * elapsed * speed

    if math.abs(diff) < 0.002 then
        self:SetValue(target)
        self._animating = false
        return
    end

    self:SetValue(current + step)
end)

-- überschreibt SetValue → startet Animation
function bar:SetAnimatedValue(v)

    local old = self._targetValue or 0

    self._targetValue = math.max(0, math.min(1, v))
    self._animating = true

-- Pulse aktivieren wenn XP >= 90%
if F().barPulseAG then
    if v >= 0.9 then
        if not F().barPulseAG:IsPlaying() then
            F().barPulseAG:Play()
        end
    else
        if F().barPulseAG:IsPlaying() then
            F().barPulseAG:Stop()
            bar:SetAlpha(1)
        end
    end
end

    -- Sweep Effekt wenn XP steigt
    if v > old and F().barSweep then

        local tex = self:GetStatusBarTexture()

        F().barSweep:ClearAllPoints()
        F().barSweep:SetPoint("LEFT", tex, "LEFT", -14, 0)
        F().barSweep:SetPoint("TOP", tex, "TOP")
        F().barSweep:SetPoint("BOTTOM", tex, "BOTTOM")

        local width = tex:GetWidth()

        local anim = F().barSweepAG:GetAnimations()

        for _, a in ipairs({F().barSweepAG:GetAnimations()}) do
            if a.SetOffset then
                a:SetOffset(width + 28, 0)
            end
        end

        F().barSweep:Show()
        F().barSweep:SetAlpha(0.7)
        F().barSweepAG:Play()
    end
end

F().badgeBar = bar

-- Titel-Anchor auf barHolder setzen (barHolder erst hier verfügbar)
if F().titleFS then
    F().titleFS:ClearAllPoints()
    F().titleFS:SetPoint("BOTTOM", barHolder, "TOP", 0, 4)
end

-- LevelGlow-Anchor auf barHolder setzen (direkt auf der XP-Bar)
if F().levelGlow then
    F().levelGlow:ClearAllPoints()
    F().levelGlow:SetPoint("CENTER", barHolder, "CENTER", 0, 0)
end

-- Gloss-Effekt (nur über gefülltem Bereich)
local barGlow = bar:CreateTexture(nil, "OVERLAY", nil, 2)
barGlow:SetTexture("Interface\\Buttons\\WHITE8X8")

barGlow:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPLEFT", 0, 0)
barGlow:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)

barGlow:SetHeight(4)
barGlow:SetVertexColor(0.65, 1.0, 0.65, 0.45)

F().barGlow = barGlow

    -- ── BADGE-ZEILE: XP-Text ÜBER der Bar (OVERLAY-Layer) ──
    -- Sitzt auf dem barHolder, damit er optisch über dem grünen Balken liegt
    local badgeFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeFS:SetPoint("CENTER", barHolder, "CENTER", 0, 0)
    badgeFS:SetWidth(110)
    badgeFS:SetJustifyH("CENTER")
    badgeFS:SetWordWrap(false)

    badgeFS:SetText("0 / 93 XP  0%")
    badgeFS:SetTextColor(1.00, 0.82, 0.00)
    badgeFS:SetShadowOffset(1, -1)
    badgeFS:SetShadowColor(0, 0, 0, 1)
    F().badgeFS  = badgeFS
    F().badgePctFS = nil  -- nicht mehr separat

    -- Pulse-Animation auf dem Gloss (leichtes Aufleuchten)
    local glowAG = barGlow:CreateAnimationGroup()
    glowAG:SetLooping("REPEAT")
    local glowIn = glowAG:CreateAnimation("Alpha")
    glowIn:SetFromAlpha(0.15)
    glowIn:SetToAlpha(0.55)
    glowIn:SetDuration(1.2)
    glowIn:SetOrder(1)
    local glowOut = glowAG:CreateAnimation("Alpha")
    glowOut:SetFromAlpha(0.55)
    glowOut:SetToAlpha(0.15)
    glowOut:SetDuration(1.2)
    glowOut:SetOrder(2)
    glowAG:Play()
    F().barGlowAG = glowAG

-- XP Pulse Animation (aktiv ab 90%)
    local pulseAG = bar:CreateAnimationGroup()

    local pulseIn = pulseAG:CreateAnimation("Alpha")
    pulseIn:SetFromAlpha(1.0)
    pulseIn:SetToAlpha(0.75)
    pulseIn:SetDuration(0.4)
    pulseIn:SetOrder(1)

    local pulseOut = pulseAG:CreateAnimation("Alpha")
    pulseOut:SetFromAlpha(0.75)
    pulseOut:SetToAlpha(1.0)
    pulseOut:SetDuration(0.4)
    pulseOut:SetOrder(2)

    pulseAG:SetLooping("REPEAT")

    F().barPulseAG = pulseAG

    -- ── TRENNLINIE (Divider) zwischen Header und Content ──
    -- Sitzt im Parent (Hauptframe), nicht im Header-Frame
    local hDiv = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    hDiv:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    hDiv:SetPoint("TOPLEFT",  parent, "TOPLEFT",  30, -(Layout.header.height + 2))
    hDiv:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -(Layout.header.height + 2))
    hDiv:SetHeight(8); hDiv:SetHorizTile(true)

    -- GOTD-Badge: Toast-Chrome in UIParent (BuildGotdBadge)
    -- streakFS/gotdFS werden dort angelegt
    F().gotdFS  = nil
    F().gotdBox = nil
    F().gotdBtn = nil

    F().headerFrame = header
    return header
end

local function SetAtlasSafe(tex, atlasName)
    local info = C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName)
    if info and info.file then
        tex:SetTexture(info.file)
        tex:SetTexCoord(info.leftTexCoord, info.rightTexCoord,
                        info.topTexCoord,  info.bottomTexCoord)
        if info.width  and info.width  > 0 then tex:SetWidth(info.width)   end
        if info.height and info.height > 0 then tex:SetHeight(info.height) end
        return true
    end
    return false
end

local function BuildGotdBadge()
    local db  = ArcadiaNexusDB and ArcadiaNexusDB.gotdAnchor
    local dbx = (db and db.x) or 0
    local dby = (db and db.y) or -57

    -- Achievement-Toast-Maße (AlertFrameSystems: 300×101)
    local box = CreateFrame("Button", "NexusGotdBadge", UIParent)
    box:SetSize(300, 101)
    box:SetFrameStrata("MEDIUM")
    box:SetFrameLevel(20)
    box:SetPoint("TOP", UIParent, "TOP", dbx, dby)
    box:Hide()
    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")

    local bg = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("CENTER", box, "CENTER", 0, 0)
    if not SetAtlasSafe(bg, "ui-achievement-alert-background") then
        bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Toast-Glow")
        bg:SetAllPoints(box)
    end

    local iconHolder = CreateFrame("Frame", nil, box)
    iconHolder:SetSize(78, 75)
    iconHolder:SetPoint("TOPLEFT", box, "TOPLEFT", -4, -15)

    local iconTex = iconHolder:CreateTexture(nil, "ARTWORK", nil, 0)
    iconTex:SetSize(52, 52)
    iconTex:SetPoint("CENTER", iconHolder, "CENTER", 0, 0)
    local AI = ArcadiaNexus.AchievementIcons
    if AI and AI.ApplyToTexture then
        AI:ApplyToTexture(iconTex, "Interface\\Icons\\INV_Misc_PocketWatch_01")
    else
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    end

    local iconOverlay = iconHolder:CreateTexture(nil, "OVERLAY", nil, 1)
    iconOverlay:SetPoint("CENTER", iconHolder, "CENTER", -1, 1)
    if not SetAtlasSafe(iconOverlay, "ui-achievement-iconframe") then
        iconOverlay:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
        iconOverlay:SetTexCoord(0, 0.5625, 0, 0.5625)
        iconOverlay:SetSize(60, 60)
    end

    local shieldHolder = CreateFrame("Frame", nil, box)
    shieldHolder:SetSize(64, 64)
    shieldHolder:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -15)

    local shieldIcon = shieldHolder:CreateTexture(nil, "BACKGROUND", nil, 0)
    shieldIcon:SetPoint("TOPRIGHT", shieldHolder, "TOPRIGHT", 1, -6)
    if not SetAtlasSafe(shieldIcon, "ui-achievement-shield-2") then
        shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
        shieldIcon:SetTexCoord(0, 0.5, 0, 0.5)
        shieldIcon:SetSize(48, 48)
    end

    local shieldPts = shieldHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shieldPts:SetPoint("CENTER", shieldHolder, "CENTER", 2, -2)
    shieldPts:SetJustifyH("CENTER")
    shieldPts:SetText("25%")
    shieldPts:SetVertexColor(0.00, 1.00, 0.53)

    -- Zwei Zeilen, vertikal mittig und eng beieinander
    local function MakeLine(anchorY, font)
        local fs = box:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT",  box, "TOPLEFT",  72, anchorY)
        fs:SetPoint("TOPRIGHT", box, "TOPRIGHT", -68, anchorY)
        fs:SetHeight(18)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(false)
        fs:SetText("")
        return fs
    end

    local streakFS = MakeLine(-34)
    streakFS:SetTextColor(1.00, 0.82, 0.00)
    local gotdFS = MakeLine(-52, "GameFontHighlight")
    gotdFS:SetTextColor(1, 1, 1)

    box:SetScript("OnEnter", function()
        gotdFS:SetTextColor(1.00, 0.95, 0.55)
    end)
    box:SetScript("OnLeave", function()
        gotdFS:SetTextColor(1, 1, 1)
    end)
    box:SetScript("OnClick", function(self)
        local gameId = self._gameId
        if not gameId then return end
        local open = ArcadiaNexus.UI.OpenGameFromOverlay
        if open then
            open(gameId)
            return
        end
        local fn = ArcadiaNexus.UI._ActivateGameFn
        if fn then fn(gameId) end
    end)

    F().streakFS = streakFS
    F().goldFS   = nil
    F().gotdFS   = gotdFS
    F().gotdBtn  = box
    F().gotdBox  = box
end

-- ============================================================
-- GAMES-PANEL (FavMgr, GetCategoryGroups, MakeStarButton, BuildCategoryPanel)
-- → UI/GamesPanel/ (modulares Sidebar-Panel)
-- ============================================================
-- SETTINGS/LEADERBOARD/ACHIEVEMENT KATEGORIE-PANELS
-- → UI/GamesPanel/ (modulares Sidebar-Panel)
-- ============================================================
local function BuildContentPanel(parent)
    local cp = CreateFrame("Frame", "NexusContentPanel", parent)
    F().content = cp

    -- BG: AchievementBackground TexCoords 0,1,0,0.5 (wie Blizzard XML)
    local cpBG = cp:CreateTexture(nil, "BACKGROUND", nil, 0)
    cpBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-AchievementBackground")
    cpBG:SetPoint("TOPLEFT",     cp, "TOPLEFT",     3, -3)
    cpBG:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -3, 3)
    cpBG:SetTexCoord(0, 1, 0, 0.5)

    -- Black Cover a=0.75 (Blizzard macht Content ebenfalls dunkel)
    local blackCover = cp:CreateTexture(nil, "BACKGROUND", nil, 1)
    blackCover:SetTexture("Interface\\Buttons\\WHITE8X8")
    blackCover:SetPoint("TOPLEFT",     cpBG, "TOPLEFT")
    blackCover:SetPoint("BOTTOMRIGHT", cpBG, "BOTTOMRIGHT")
    blackCover:SetVertexColor(0, 0, 0, 0.75)

    -- Content-Label (dauerhaft ausgeblendet — durch spielspezifische Logos ersetzt)
    local clFS = cp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    clFS:SetPoint("TOP", cp, "TOP", 0, -10)
    clFS:SetText("")
    clFS:SetAlpha(0)
    clFS:Hide()
    F().contentLabelFS = clFS

    -- Divider
    local clDiv = cp:CreateTexture(nil, "ARTWORK", nil, 1)
    clDiv:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    clDiv:SetPoint("TOPLEFT",  cp, "TOPLEFT",  4, -30)
    clDiv:SetPoint("TOPRIGHT", cp, "TOPRIGHT", -4, -30)
    clDiv:SetHeight(8); clDiv:SetHorizTile(true)

    -- Panel-Slots
    local function MakePanel(name)
        local p = CreateFrame("Frame", name, cp)
        p:SetPoint("TOPLEFT",     cp, "TOPLEFT",     0, -Layout.content.gamesPanelTopInset)
        p:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT",  0,  0)
        p:Hide()
        return p
    end
    F().games      = MakePanel("ArcadiaNexusGamesPanel")
    F().scoreboard = MakePanel("ArcadiaNexusScorePanel")
    F().settings   = MakePanel("ArcadiaNexusSettingsPanel")
    F().achievements = MakePanel("ArcadiaNexusAchievementsPanel")

    -- Border as a high child so games/controls chrome tucks under L/R/B.
    local chrome = CreateFrame("Frame", "NexusContentChrome", cp, "BackdropTemplate")
    chrome:SetAllPoints(cp)
    chrome:SetBackdrop({
        bgFile   = nil,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileEdge = true, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    chrome:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    chrome:EnableMouse(false)
    if chrome.SetMouseClickEnabled then chrome:SetMouseClickEnabled(false) end
    chrome:SetFrameLevel((F().games:GetFrameLevel() or 1) + 80)
    F().contentChrome = chrome

    -- Achievement-UI initialisieren (falls Modul geladen)
    if ArcadiaNexus.AchievementUI and ArcadiaNexus.AchievementUI.Attach then
        local ok, err = pcall(function()
            ArcadiaNexus.AchievementUI:Attach(F().achievements)
        end)
        if not ok then
            -- stiller Ausfall — Rest des Addons läuft unberührt
        end
    end

    return cp
end

-- ============================================================
-- BOTTOM TABS (exakt nach AchievementFrameTabButtonTemplate)
-- ============================================================

-- ============================================================

-- ============================================================
-- EXPORTS für MainFrame.lua und ArcadiaNexus_UI.lua
-- ============================================================
ArcadiaNexus.UI.BuildHeader       = BuildHeader
ArcadiaNexus.UI.BuildGotdBadge    = BuildGotdBadge
ArcadiaNexus.UI.BuildContentPanel = BuildContentPanel
-- CreateNexusScrollbar bleibt global (bereits als function, nicht local)
