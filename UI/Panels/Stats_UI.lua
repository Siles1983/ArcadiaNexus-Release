--[[
    ArcadiaNexus – Stats_UI
    UI/Stats_UI.lua
    Spieler-Statistik Profil Panel (Profil-Tab).
    Layout: Identitätskopf + 2×2 Boxen mit horizontalem + vertikalem Divider.

    Hero                 – Portrait, Name, Titel, XP-Balken, Gold, Streak
    Box 1 (oben links)  – Nächster Titel, Gesamt-XP, beste Streak
    Box 2 (oben rechts) – Spielstatistik (Bilanz, Top-3, Kategorien, Logo-Wasserzeichen)
    Box 3 (unten links) – Challenges (GOTD, Daily/Weekly, Lifetime)
    Box 4 (unten rechts)– Titel-Katalog (Auswahl, Header-Sichtbarkeit)
]]

local Stats = {}
ArcadiaNexus.StatsUI = Stats

local UI = ArcadiaNexus.UI

local function Profile()
    local PS = ArcadiaNexus.ProfileStore
    return PS and PS.Get() or {}
end

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================
-- Panel füllt das Full-Width-Content-Maß (Layout.content.height = 600).
-- MARGIN: Abstand zum Rahmen rundum
-- GAP: zwischen den Boxen (Divider-Bereich)
local Layout = ArcadiaNexus.Layout
local PANEL_W  = 821
local PANEL_H  = (Layout and Layout.content and Layout.content.height) or 600
local MARGIN   = 5
local GAP      = 8
local HERO_H   = 86
local HERO_GAP = 8
local AVAIL_W  = PANEL_W - MARGIN * 2
local AVAIL_H  = PANEL_H - MARGIN * 2
-- Gleich große 2×2-Kacheln unter dem Identitätskopf; Divider folgen BOX_H.
local BOX_W    = math.floor((AVAIL_W - GAP) / 2) - 20
local BOX_H    = math.floor((AVAIL_H - GAP - HERO_H - HERO_GAP) / 2)
local PAD      = 8
local GRID_W   = BOX_W * 2 + GAP
local CONTENT_TOP = 32
local CONTENT_BOTTOM = 8
-- Wasserzeichen in der Spielstatistik: Quadrat, kürzere Kante der Box ~244.
local BOX2_WM_SIZE  = 200
local BOX2_WM_ALPHA = 0.18

-- ============================================================
-- BERECHNUNGS-HELPER
-- ============================================================
function Stats:GetFavoriteGame()
    local SM = ArcadiaNexus.ScoreManager
    if SM and SM.GetRankedGames then
        local top = SM:GetRankedGames()[1]
        if top then return top.gameId, top.plays end
        return nil, 0
    end
    local SS = ArcadiaNexus.StatsStore
    local lb = SS and SS.GetLeaderboard()
    if not lb then return nil, 0 end
    local best, bestCount = nil, 0
    for gameId, diffs in pairs(lb) do
        local total = 0
        for _, entry in pairs(diffs) do
            total = total + (entry.wins   or 0)
                          + (entry.losses or 0)
                          + (entry.draws  or 0)
        end
        if total > bestCount then bestCount = total; best = gameId end
    end
    return best, bestCount
end

function Stats:GetCategoryLabel(catId)
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local CR = ArcadiaNexus.CategoryRegistry
    if CR and CR.GetLabel then
        return CR.GetLabel(catId, function(key)
            return L and L[key]
        end)
    end
    return (L and L["cat_" .. tostring(catId)]) or catId or "–"
end

function Stats:GetTopCategories(limit)
    limit = limit or 3
    local SM = ArcadiaNexus.ScoreManager
    local ranked = (SM and SM.GetRankedGames) and SM:GetRankedGames() or {}
    local GR = ArcadiaNexus.GameRegistry
    local byCat = {}
    for i = 1, #ranked do
        local row = ranked[i]
        local cat = "SONSTIGE"
        if GR and GR.GetById then
            local info = GR.GetById(row.gameId)
            if info and info.category then
                cat = info.category
            end
        end
        byCat[cat] = (byCat[cat] or 0) + (row.plays or 0)
    end
    local list = {}
    for catId, plays in pairs(byCat) do
        list[#list + 1] = { catId = catId, plays = plays }
    end
    table.sort(list, function(a, b)
        if a.plays ~= b.plays then return a.plays > b.plays end
        return tostring(a.catId) < tostring(b.catId)
    end)
    if #list > limit then
        for i = #list, limit + 1, -1 do
            list[i] = nil
        end
    end
    return list
end

function Stats:GetHighestScoreEver()
    local SS = ArcadiaNexus.StatsStore
    local lb = SS and SS.GetLeaderboard()
    if not lb then return 0, nil, nil end
    local best, bestGame, bestDiff = 0, nil, nil
    for gameId, diffs in pairs(lb) do
        for diff, entry in pairs(diffs) do
            for _, hs in ipairs(entry.highscores or {}) do
                if hs > best then best = hs; bestGame = gameId; bestDiff = diff end
            end
        end
    end
    return best, bestGame, bestDiff
end

function Stats:GetWinRate()
    local PS = ArcadiaNexus.ProfileStore
    local p = PS and PS.Get()
    if not p or (p.totalGames or 0) == 0 then return 0 end
    return math.floor(((p.wins or 0) / p.totalGames) * 100)
end

function Stats:GetAchievementCount()
    local AS = ArcadiaNexus.AchievementStore
    local unlockedMap = AS and AS.GetUnlocked() or {}
    local unlocked = 0
    for _ in pairs(unlockedMap) do unlocked = unlocked + 1 end
    -- BUG-FIX: Gruppen nutzen .tiers, nicht .achievements
    local total = 0
    local AD = ArcadiaNexus.AchievementData
    if AD then
        for _, g in ipairs(AD) do
            total = total + #(g.tiers or {})
        end
    end
    return unlocked, total
end

function Stats:GetGameLabel(gameId)
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.GetLabel then
        return GR.GetLabel(gameId)
    end
    return gameId or "–"
end

function Stats:GetDiffLabel(diff)
    local L = ArcadiaNexus.GetLocaleTable("UI")
    if not diff then return "–" end
    local d = diff:lower()
    if     d == "easy"   then return L["lb_diff_easy"]    or "Einfach"
    elseif d == "normal" then return L["lb_diff_normal"]  or "Normal"
    elseif d == "hard"   then return L["lb_diff_hard"]    or "Schwer"
    end
    return diff
end

-- Gibt sortierte Liste aller freigeschalteten Titel zurück
-- { { key = "Novice of the Nexus Arcade", label = "Novice of the Nexus Arcade" }, ... }
function Stats:GetUnlockedTitles()
    local XPM    = ArcadiaNexus.XPManager
    local prof   = Profile()
    local level  = prof.level or 1
    local catalog = (XPM and XPM.GetTitleCatalog) and XPM:GetTitleCatalog() or {}
    local result = {}
    for i = 1, #catalog do
        local e = catalog[i]
        if e.level <= level then
            local label = (XPM.GetLocalizedTitle and XPM:GetLocalizedTitle(e.level)) or e.key
            result[#result + 1] = { key = e.key, label = label, level = e.level }
        end
    end
    return result
end

function Stats:GetDisplayTitle()
    local prof = Profile()
    local XPM = ArcadiaNexus.XPManager
    if prof.activeTitle and prof.activeTitle ~= "" then
        if XPM and XPM.GetLocalizedTitleForKey then
            return XPM:GetLocalizedTitleForKey(prof.activeTitle)
        end
        return prof.activeTitle
    end
    local level = prof.level or 1
    if XPM and XPM.GetLocalizedTitle then
        return XPM:GetLocalizedTitle(level)
    end
    return (XPM and XPM.GetTitle) and XPM:GetTitle(level) or "Arcade Initiate"
end

local function GetPlayerIdentity()
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local name = (L and L["stats_adventurer"]) or "Abenteurer"
    if UnitName then
        local n = UnitName("player")
        if type(n) == "string" and n ~= "" then
            name = n
        end
    end
    local className, classFile
    if UnitClass then
        className, classFile = UnitClass("player")
    end
    local color = { 1.00, 0.82, 0.00 }
    local rcc = RAID_CLASS_COLORS
    if classFile and type(rcc) == "table" and rcc[classFile] then
        local c = rcc[classFile]
        color = { c.r or color[1], c.g or color[2], c.b or color[3] }
    end
    return name, className, classFile, color
end

local function ApplyPortrait(tex, classFile)
    if not tex then return end
    tex:SetTexCoord(0, 1, 0, 1)
    if SetPortraitTexture then
        local ok = pcall(SetPortraitTexture, tex, "player")
        if ok then return end
    end
    local coords = CLASS_ICON_TCOORDS
    if classFile and type(coords) == "table" and coords[classFile] then
        local c = coords[classFile]
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        return
    end
    tex:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
end

-- ============================================================
-- PANEL AUFBAUEN
-- ============================================================
function Stats:BuildPanel(parent)
    if self._panel then return self._panel end

    local p = CreateFrame("Frame", "NexusStatsPanel", parent, "BackdropTemplate")
    p:SetAllPoints(parent)
    p:Hide()
    self._panel = p

    -- Subframes für die 4 Boxen (werden in _Rebuild befüllt)
    self._box1Content = nil
    self._box2Content = nil
    self._box3Content = nil
    self._box4Content = nil

    -- Identitätskopf + Boxen einmalig aufbauen (Struktur ist statisch)
    self:_BuildHero(p)
    self:_BuildBoxes(p)

    -- Auf relevante Events reagieren
    ArcadiaNexus.Engine:On("XP_UPDATED",     function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("GOLD_UPDATED",   function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("STREAK_UPDATED", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("GAME_RESULT",    function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("CHALLENGE_PROGRESS", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("CHALLENGE_COMPLETE", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("ACHIEVEMENT_UNLOCKED", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("ACHIEVEMENTS_REGISTERED", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)

    return p
end

-- ============================================================
-- IDENTITÄTSKOPF (einmalig)
-- ============================================================
function Stats:_BuildHero(p)
    local hero = CreateFrame("Frame", nil, p, "BackdropTemplate")
    hero:SetSize(GRID_W, HERO_H)
    hero:SetPoint("TOP", p, "TOP", 0, -MARGIN)
    hero:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    hero:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
    hero:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    self._hero = hero

    local portBox = CreateFrame("Frame", nil, hero, "BackdropTemplate")
    portBox:SetSize(68, 68)
    portBox:SetPoint("LEFT", hero, "LEFT", 10, 0)
    portBox:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    portBox:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

    local portBg = portBox:CreateTexture(nil, "BACKGROUND")
    portBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    portBg:SetVertexColor(0, 0, 0, 0.65)
    portBg:SetPoint("TOPLEFT", 4, -4)
    portBg:SetPoint("BOTTOMRIGHT", -4, 4)

    local port = portBox:CreateTexture(nil, "ARTWORK")
    port:SetPoint("TOPLEFT", 4, -4)
    port:SetPoint("BOTTOMRIGHT", -4, 4)
    if port.AddMaskTexture and hero.CreateMaskTexture then
        local mask = hero:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(port)
        port:AddMaskTexture(mask)
    end
    self._heroPortrait = port

    local nameFS = hero:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameFS:SetPoint("TOPLEFT", portBox, "TOPRIGHT", 12, -2)
    nameFS:SetWidth(GRID_W - 68 - 24 - 210)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    self._heroNameFS = nameFS

    local titleFS = hero:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -3)
    titleFS:SetWidth(GRID_W - 68 - 24 - 210)
    titleFS:SetTextColor(1.00, 0.82, 0.00)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    self._heroTitleFS = titleFS

    local levelFS = hero:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -4)
    levelFS:SetTextColor(0.85, 0.78, 0.60)
    self._heroLevelFS = levelFS

    local goldFS = hero:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldFS:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -14, -10)
    goldFS:SetJustifyH("RIGHT")
    self._heroGoldFS = goldFS

    local streakFS = hero:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    streakFS:SetPoint("TOPRIGHT", goldFS, "BOTTOMRIGHT", 0, -6)
    streakFS:SetJustifyH("RIGHT")
    self._heroStreakFS = streakFS

    local barHolder = CreateFrame("Frame", nil, hero)
    barHolder:SetHeight(14)
    barHolder:SetPoint("TOPLEFT", levelFS, "BOTTOMLEFT", 0, -6)
    barHolder:SetPoint("RIGHT", hero, "RIGHT", -14, 0)

    local barBG = barHolder:CreateTexture(nil, "BACKGROUND")
    barBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBG:SetAllPoints(barHolder)
    barBG:SetVertexColor(0, 0, 0, 0.45)

    local bar = CreateFrame("StatusBar", nil, barHolder)
    bar:SetPoint("TOPLEFT", barHolder, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", barHolder, "BOTTOMRIGHT", 0, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.00, 0.70, 0.10, 1)
    self._heroXPBar = bar

    local barBorder = CreateFrame("Frame", nil, barHolder, "BackdropTemplate")
    barBorder:SetPoint("TOPLEFT", barHolder, "TOPLEFT", -1, 1)
    barBorder:SetPoint("BOTTOMRIGHT", barHolder, "BOTTOMRIGHT", 1, -1)
    barBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    barBorder:SetBackdropBorderColor(0.42, 0.34, 0.18, 0.85)
    barBorder:SetFrameLevel(bar:GetFrameLevel() + 1)

    local xpFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpFS:SetPoint("CENTER", barHolder, "CENTER", 0, 0)
    xpFS:SetTextColor(1.00, 0.82, 0.00)
    xpFS:SetShadowOffset(1, -1)
    xpFS:SetShadowColor(0, 0, 0, 1)
    self._heroXPFS = xpFS
end

function Stats:_RefreshHero()
    if not self._hero then return end

    local L       = ArcadiaNexus.GetLocaleTable("UI")
    local profile = Profile()
    local SS      = ArcadiaNexus.StatsStore
    local streak  = (SS and SS.GetStreak()) or {}
    local gold    = (ArcadiaNexus.TavernGoldStore and ArcadiaNexus.TavernGoldStore.GetBalance()) or 0
    local XPM     = ArcadiaNexus.XPManager

    local level = profile.level or 1
    local xp    = profile.xp or 0
    local xpReq = profile.xpRequired
    if not xpReq and XPM and XPM.GetXPRequired then
        xpReq = XPM:GetXPRequired(level)
    end
    xpReq = xpReq or 93

    local name, _, classFile, color = GetPlayerIdentity()
    ApplyPortrait(self._heroPortrait, classFile)
    self._heroNameFS:SetText(name)
    self._heroNameFS:SetTextColor(color[1], color[2], color[3])
    self._heroTitleFS:SetText(self:GetDisplayTitle())
    self._heroLevelFS:SetText(string.format(L["stats_hero_level"] or "Level %d", level))

    self._heroGoldFS:SetText("|cffffd700" .. tostring(gold) .. " Gold|r")
    self._heroStreakFS:SetText("|TInterface\\Icons\\Spell_Fire_SealOfFire:14:14:0:0|t "
        .. (streak.current or 0) .. " " .. (L["stats_days"] or "Tage"))

    local maxLevel = XPM and XPM.IsMaxLevel and XPM:IsMaxLevel()
    if maxLevel or xpReq == 0 then
        self._heroXPBar:SetValue(1)
        self._heroXPFS:SetText(L["stats_max_level"] or "Max-Level")
    else
        local ratio = math.min(1, xp / xpReq)
        self._heroXPBar:SetValue(ratio)
        local pct = math.floor(ratio * 100)
        self._heroXPFS:SetText(xp .. " / " .. xpReq .. " XP  " .. pct .. "%")
    end
end

-- ============================================================
-- BOXEN BAUEN (Struktur – einmalig)
-- ============================================================
function Stats:_BuildBoxes(p)
    local L = ArcadiaNexus.GetLocaleTable("UI")

    local GRID_H = BOX_H * 2 + GAP

    -- Raster unter dem Identitätskopf, gleiche Breite
    local grid = CreateFrame("Frame", nil, p)
    grid:SetSize(GRID_W, GRID_H)
    if self._hero then
        grid:SetPoint("TOP", self._hero, "BOTTOM", 0, -HERO_GAP)
    else
        grid:SetPoint("CENTER", p, "CENTER", 0, 0)
    end
    self._grid = grid

    -- Hilfsfunktion: Box ohne CreateBox-Titel, Titel zentriert + Divider
    local function MakeBox(parent, titleText, x, y, w, h)
        -- UI.CreateBox mit echtem Titel (baut intern FontString + UI-Achievement-Divider)
        local box, content = UI.CreateBox(parent, titleText, x, y, w, h)

        -- titleFS via GetRegions() auf CENTER umanchern
        for _, region in ipairs({box:GetRegions()}) do
            if region:IsObjectType("FontString") then
                region:ClearAllPoints()
                region:SetPoint("TOP", box, "TOP", 0, -7)
                break
            end
        end

        -- Eigener Divider mit WHITE8X8 (UI-Achievement-Divider rendert hier nicht)
        local div = box:CreateTexture(nil, "OVERLAY", nil, 7)
        div:SetTexture("Interface\\Buttons\\WHITE8X8")
        div:SetVertexColor(0.35, 0.28, 0.18, 0.7)
        div:SetPoint("TOPLEFT",  box, "TOPLEFT",  20, -22)
        div:SetPoint("TOPRIGHT", box, "TOPRIGHT", -20, -22)
        div:SetHeight(2)

        -- Content unter Divider, etwas weniger Boden-Pad damit die letzte Zeile hineinpasst
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT",     box, "TOPLEFT",     UI.PAD, -CONTENT_TOP)
        content:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -UI.PAD, CONTENT_BOTTOM)
        return box, content
    end

    -- 4 Boxen relativ zum zentrierten grid-Frame
    local _, c1 = MakeBox(grid, L["stats_header_profile"] or "Spieler-Profil",
        0, 0, BOX_W, BOX_H)
    self._box1Content = c1

    local box2, c2 = MakeBox(grid, L["stats_header_games"] or "Spielstatistik",
        BOX_W + GAP, 0, BOX_W, BOX_H)
    self._box2Content = c2
    self._box2Frame   = box2
    if UI.CreateWatermarkLogo then
        local wm = UI.CreateWatermarkLogo(box2, {
            w = BOX2_WM_SIZE,
            h = BOX2_WM_SIZE,
            alpha = BOX2_WM_ALPHA,
            drawLayer = "ARTWORK",
            subLevel = 0,
        })
        if wm then
            wm:EnableMouse(false)
            if wm.SetMouseClickEnabled then wm:SetMouseClickEnabled(false) end
            local boxLevel = (box2.GetFrameLevel and box2:GetFrameLevel()) or 1
            wm:SetFrameLevel(boxLevel)
            c2:SetFrameLevel(boxLevel + 2)
            self._box2Wm = wm
        end
    end

    local _, c3 = MakeBox(grid, L["stats_header_challenges"] or "Challenges",
        0, BOX_H + GAP, BOX_W, BOX_H)
    self._box3Content = c3

    local box4, c4 = MakeBox(grid, L["stats_header_titles"] or "Titel",
        BOX_W + GAP, BOX_H + GAP, BOX_W, BOX_H)
    self._box4Content = c4
    self._box4Frame   = box4

    -- ── Horizontaler Divider (zwischen oberer und unterer Zeile) ──
    local hDiv = grid:CreateTexture(nil, "OVERLAY", nil, 7)
    hDiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    hDiv:SetVertexColor(0.35, 0.28, 0.18, 0.7)
    hDiv:SetPoint("TOPLEFT",  grid, "TOPLEFT",  10, -(BOX_H + GAP/2 - 1))
    hDiv:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -10, -(BOX_H + GAP/2 - 3))
    hDiv:SetHeight(1)

    -- ── Vertikaler Divider (20px kürzer oben+unten) ───────────
    local vDiv = grid:CreateTexture(nil, "OVERLAY", nil, 7)
    vDiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    vDiv:SetVertexColor(0.35, 0.28, 0.18, 0.7)
    vDiv:SetPoint("TOPLEFT",    grid, "TOPLEFT",    BOX_W + GAP/2 - 1, -10)
    vDiv:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", BOX_W + GAP/2 - 1,  10)
    vDiv:SetWidth(2)

    -- Initialen Inhalt befüllen
    self:_Rebuild()
end

-- ============================================================
-- REBUILD: Inhalt der 4 Boxen neu zeichnen
-- ============================================================
local ROW_H  = 20
local INDENT = 6

local function CreateStatsRowPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Stats.Rows",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Button", nil, poolParent)
            wrap:SetHeight(ROW_H)
            wrap:EnableMouse(false)
            wrap._headerFS = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            wrap._labelFS  = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            wrap._valueFS  = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            return wrap
        end,
        onRelease = function(wrap)
            wrap:Hide()
            wrap:ClearAllPoints()
            wrap._isHeader = nil
            wrap._valueColor = nil
            wrap:EnableMouse(false)
            wrap:SetScript("OnClick", nil)
            wrap:SetScript("OnEnter", nil)
            wrap:SetScript("OnLeave", nil)
            if UI.HideFrameTooltip then UI.HideFrameTooltip() end
            if wrap._headerFS then wrap._headerFS:SetText("") end
            if wrap._labelFS  then
                wrap._labelFS:SetText("")
                wrap._labelFS:SetJustifyH("LEFT")
            end
            if wrap._valueFS  then
                wrap._valueFS:SetText("")
                wrap._valueFS:SetJustifyH("LEFT")
            end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

local function CreateStatsProgressPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Stats.ProgressBars",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Frame", nil, poolParent)
            wrap._bg = wrap:CreateTexture(nil, "BACKGROUND", nil, 0)
            wrap._bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            wrap._fill = CreateFrame("StatusBar", nil, wrap)
            wrap._fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            wrap._fill:SetMinMaxValues(0, 1)
            wrap._border = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
            wrap._border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileEdge = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            wrap._border:SetBackdropBorderColor(0.42, 0.34, 0.18, 0.85)
            wrap._labelFS = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            return wrap
        end,
        onRelease = function(wrap)
            wrap:Hide()
            wrap:ClearAllPoints()
            if wrap._labelFS then wrap._labelFS:SetText("") end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

function Stats:_EnsureContentPools()
    if not self._rowPool then self._rowPool = CreateStatsRowPool() end
    if not self._progressPool then self._progressPool = CreateStatsProgressPool() end
end

function Stats:GetChallengeLabel(ch)
    if not ch then return "–" end
    local german = GetLocale and GetLocale() == "deDE"
    if german then
        return ch.title_de or ch.title_en or ch.id or "–"
    end
    return ch.title_en or ch.title_de or ch.id or "–"
end

function Stats:GetChallengeDesc(ch)
    if not ch then return "" end
    local german = GetLocale and GetLocale() == "deDE"
    if german then
        return ch.desc_de or ch.desc_en or ""
    end
    return ch.desc_en or ch.desc_de or ""
end

function Stats:GetChallengeTooltip(ch)
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local title = self:GetChallengeLabel(ch)
    local desc = self:GetChallengeDesc(ch)
    local reward = ch and ch.reward or {}
    local line = string.format(
        (L and L["stats_challenge_reward"]) or "Belohnung: %d XP, %d Gold",
        reward.xp or 0, reward.gold or 0)
    if desc ~= "" then
        return title, desc .. "\n" .. line
    end
    return title, line
end

function Stats:_OpenGame(gameId)
    local open = ArcadiaNexus.UI and ArcadiaNexus.UI.OpenGameFromOverlay
    if gameId and open then
        open(gameId)
        return
    end
    if NexusTabs and NexusTabs.SetActive then
        NexusTabs.SetActive("GAMES")
    end
end

function Stats:_OpenAchievements()
    if NexusTabs and NexusTabs.SetActive then
        NexusTabs.SetActive("ACHIEVEMENTS")
    end
end

function Stats:_BindRowClick(row, onClick, tooltipTitle, tooltipText)
    if not row then return end
    local hasClick = type(onClick) == "function"
    local hasTip = (tooltipTitle and tooltipTitle ~= "") or (tooltipText and tooltipText ~= "")
    if not hasClick and not hasTip then return end
    local labelR, labelG, labelB = row._labelFS:GetTextColor()
    row:EnableMouse(true)
    if hasClick then
        row:SetScript("OnClick", function()
            pcall(onClick)
        end)
    else
        row:SetScript("OnClick", nil)
    end
    row:SetScript("OnEnter", function(self)
        if self._labelFS then self._labelFS:SetTextColor(1.00, 0.95, 0.55) end
        if self._valueFS then self._valueFS:SetTextColor(1.00, 0.95, 0.55) end
        if self._headerFS and self._isHeader then
            self._headerFS:SetTextColor(1.00, 0.95, 0.55)
        end
        if hasTip and UI.ShowFrameTooltip then
            UI.ShowFrameTooltip(self, tooltipTitle, tooltipText)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self._labelFS then self._labelFS:SetTextColor(labelR, labelG, labelB) end
        if self._valueFS then
            local c = self._valueColor
            if c then
                self._valueFS:SetTextColor(c[1], c[2], c[3])
            else
                self._valueFS:SetTextColor(1.00, 1.00, 1.00)
            end
        end
        if self._headerFS and self._isHeader then
            self._headerFS:SetTextColor(1.00, 0.82, 0.00)
        end
        if UI.HideFrameTooltip then
            UI.HideFrameTooltip()
        end
    end)
end

function Stats:_Row(parent, yOff, labelText, valueText, isHeader, opts)
    opts = opts or {}
    local row = self._rowPool:Acquire({})
    row:SetParent(parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOff)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -yOff)
    row:SetHeight(ROW_H)
    row._isHeader = isHeader

    if isHeader then
        row._headerFS:ClearAllPoints()
        row._headerFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
        row._headerFS:SetTextColor(1.00, 0.82, 0.00)
        row._headerFS:SetText(labelText)
        row._headerFS:Show()
        row._labelFS:Hide()
        row._valueFS:Hide()
    else
        row._headerFS:Hide()
        row._labelFS:ClearAllPoints()
        row._labelFS:SetTextColor(0.85, 0.78, 0.60)
        row._labelFS:SetText(labelText)
        row._labelFS:SetWordWrap(false)
        row._labelFS:Show()
        if valueText then
            row._valueFS:ClearAllPoints()
            row._valueFS:SetTextColor(1.00, 1.00, 1.00)
            row._valueFS:SetText(valueText)
            row._valueFS:Show()
            if opts.valueRight then
                row._valueFS:SetJustifyH("RIGHT")
                row._valueFS:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -INDENT, -yOff)
                row._labelFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
                row._labelFS:SetPoint("TOPRIGHT", row._valueFS, "TOPLEFT", -8, 0)
                row._labelFS:SetJustifyH("LEFT")
            else
                row._valueFS:SetJustifyH("LEFT")
                row._labelFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
                row._valueFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, -yOff)
            end
        else
            row._labelFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
            row._labelFS:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -INDENT, -yOff)
            row._valueFS:Hide()
        end
    end
    if opts.onClick or opts.tooltipTitle or opts.tooltipText then
        self:_BindRowClick(row, opts.onClick, opts.tooltipTitle, opts.tooltipText)
    end
    if opts.valueColor and row._valueFS then
        local c = opts.valueColor
        row._valueColor = c
        row._valueFS:SetTextColor(c[1], c[2], c[3])
    end
    row:Show()
    return yOff + ROW_H, row
end

function Stats:_ProgressBar(parent, yOff, fraction, label)
    local BAR_W = math.floor(BOX_W * 0.65)
    local BAR_H = 12

    local wrap = self._progressPool:Acquire({})
    wrap:SetParent(parent)
    wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOff)
    wrap:SetSize(BAR_W + 80, BAR_H)

    wrap._bg:ClearAllPoints()
    wrap._bg:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
    wrap._bg:SetSize(BAR_W, BAR_H)
    wrap._bg:SetVertexColor(0, 0, 0, 0.45)
    wrap._bg:Show()

    wrap._fill:ClearAllPoints()
    wrap._fill:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
    wrap._fill:SetSize(BAR_W, BAR_H)
    wrap._fill:SetValue(math.min(1, fraction))
    wrap._fill:SetStatusBarColor(0.10, 0.60, 1.00, 1)
    wrap._fill:Show()

    wrap._border:ClearAllPoints()
    wrap._border:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT - 1, -(yOff - 1))
    wrap._border:SetSize(BAR_W + 2, BAR_H + 2)
    wrap._border:SetFrameLevel(wrap._fill:GetFrameLevel() + 1)
    wrap._border:Show()

    if label then
        wrap._labelFS:ClearAllPoints()
        wrap._labelFS:SetPoint("LEFT", wrap._fill, "RIGHT", 6, 0)
        wrap._labelFS:SetTextColor(0.85, 0.78, 0.60)
        wrap._labelFS:SetText(label)
        wrap._labelFS:Show()
    else
        wrap._labelFS:Hide()
    end
    wrap:Show()
    return yOff + BAR_H + 6
end

function Stats:_Rebuild()
    local L       = ArcadiaNexus.GetLocaleTable("UI")
    local profile = Profile()
    local SS      = ArcadiaNexus.StatsStore
    local streak  = (SS and SS.GetStreak()) or {}

    local totalXP = profile.totalXP    or 0
    local wins    = profile.wins       or 0
    local losses  = profile.losses     or 0
    local draws   = profile.draws      or 0
    local total   = profile.totalGames or 0
    local wr      = self:GetWinRate()
    local best    = streak.best        or 0

    local hsVal, hsGame, hsDiff   = self:GetHighestScoreEver()
    local achUnlocked, achTotal   = self:GetAchievementCount()
    local SM                      = ArcadiaNexus.ScoreManager
    local rankedGames             = (SM and SM.GetRankedGames) and SM:GetRankedGames() or {}
    local topCats                 = self:GetTopCategories(2)

    local CM        = ArcadiaNexus.ChallengeManager
    local gotd      = CM and CM.GetGameOfDay and CM:GetGameOfDay()
    local gotdLabel = gotd and self:GetGameLabel(gotd) or "–"
    local hist      = CM and CM:GetHistory() or {}

    local p = self._panel
    if not p then return end

    self:_EnsureContentPools()
    self._rowPool:ReleaseAll()
    self._progressPool:ReleaseAll()

    self:_RefreshHero()

    -- ── BOX 1: Nächster Titel + Restprofil ────────────────────
    do
        local newC = self._box1Content
        if not newC then return end

        local y = 4
        local XPM = ArcadiaNexus.XPManager
        local tp = (XPM and XPM.GetTitleProgress) and XPM:GetTitleProgress(profile) or nil

        y = self:_Row(newC, y, L["stats_next_title"] or "Nächster Titel", nil, true)
        if not tp or tp.maxed then
            y = self:_Row(newC, y, L["stats_all_titles"] or "Alle Titel erreicht.")
        else
            y = self:_Row(newC, y, (XPM and XPM.GetLocalizedTitleForKey)
                and XPM:GetLocalizedTitleForKey(tp.nextTitle) or tp.nextTitle)
            y = self:_Row(newC, y, L["stats_xp_remaining"] or "Noch nötig:",
                tostring(tp.remaining) .. " XP  ·  "
                .. string.format(L["stats_next_title_level"] or "ab Level %d", tp.nextLevel))
            local pct = math.floor((tp.fraction or 0) * 100)
            y = self:_ProgressBar(newC, y, tp.fraction or 0, pct .. "%")
        end

        y = y + 6
        y = self:_Row(newC, y, L["stats_total_xp"] or "Gesamt-XP:", tostring(totalXP))
        y = self:_Row(newC, y, L["stats_best_streak"] or "Beste Streak:",
            tostring(best) .. " " .. (L["stats_days"] or "Tage"))
    end

    -- ── BOX 2: Spielstatistik ─────────────────────────────────
    do
        local newC = self._box2Content
        if not newC then return end

        local topId = rankedGames[1] and rankedGames[1].gameId
        local GR = ArcadiaNexus.GameRegistry
        local logoPath = (topId and GR and GR.GetLogo) and GR.GetLogo(topId) or nil
        if self._box2Wm and self._box2Wm.SetLogo then
            self._box2Wm:SetLogo(logoPath)
        end

        local y = 4
        y = self:_Row(newC, y, L["stats_total_games"] or "Spiele gesamt:",
            tostring(total) .. "  (" .. wr .. "%)")
        y = self:_Row(newC, y, L["stats_record"] or "Bilanz:",
            string.format(L["stats_wld"] or "%dS / %dN / %dU", wins, losses, draws))

        if hsVal > 0 then
            local hsLabel = (self:GetGameLabel(hsGame) or "?")
                .. (hsDiff and ("  ·  " .. self:GetDiffLabel(hsDiff)) or "")
            y = self:_Row(newC, y, L["stats_top_score"] or "Höchster Score:",
                tostring(hsVal) .. "  |cff888888(" .. hsLabel .. ")|r",
                false, {
                    valueRight = true,
                    onClick = hsGame and function() Stats:_OpenGame(hsGame) end or nil,
                })
        end

        y = self:_Row(newC, y, L["stats_header_top_games"] or "Meiste Partien", nil, true)
        if #rankedGames == 0 then
            y = self:_Row(newC, y, L["stats_no_games"] or "Noch keine Partien.")
        else
            local n = math.min(3, #rankedGames)
            local playFmt = L["stats_plays_count"] or "%dx"
            for i = 1, n do
                local row = rankedGames[i]
                local gid = row.gameId
                y = self:_Row(newC, y, self:GetGameLabel(gid),
                    string.format(playFmt, row.plays), false, {
                        valueRight = true,
                        onClick = function() Stats:_OpenGame(gid) end,
                    })
            end
        end

        if #topCats > 0 then
            y = self:_Row(newC, y, L["stats_header_categories"] or "Kategorien", nil, true)
            local playFmt = L["stats_plays_count"] or "%dx"
            for i = 1, #topCats do
                local cat = topCats[i]
                y = self:_Row(newC, y, self:GetCategoryLabel(cat.catId),
                    string.format(playFmt, cat.plays), false, { valueRight = true })
            end
        end
    end

    -- ── BOX 3: Challenge-Zentrale ─────────────────────────────
    do
        local newC = self._box3Content
        if not newC then return end

        local y = 4
        local achFrac = achTotal > 0 and (achUnlocked / achTotal) or 0
        local achPct  = math.floor(achFrac * 100)
        y = self:_Row(newC, y, L["stats_header_achievements"] or "Erfolge",
            achUnlocked .. " / " .. achTotal .. "  (" .. achPct .. "%)",
            false, { onClick = function() Stats:_OpenAchievements() end })

        local gotdValue = gotd
            and (gotdLabel .. "  |cff00ff88(" .. (L["stats_gotd_bonus"] or "+25% XP") .. ")|r")
            or "–"
        y = self:_Row(newC, y, L["stats_gotd"] or "Spiel des Tages:", gotdValue, false, {
            valueRight = true,
            onClick = gotd and function() Stats:_OpenGame(gotd) end or nil,
        })

        local function addChallenge(ch)
            if not ch then return end
            local claimed = ch.claimed or ((ch.progress or 0) >= (ch.goal or 1))
            local progText
            local valueColor
            if claimed then
                progText = L["stats_challenge_done"] or "Fertig"
                valueColor = { 0.20, 1.00, 0.45 }
            else
                local cur = math.min(ch.progress or 0, ch.goal or 1)
                progText = cur .. " / " .. (ch.goal or 1)
            end
            local click
            if ch.gameId then
                click = function() Stats:_OpenGame(ch.gameId) end
            end
            local tipTitle, tipText = self:GetChallengeTooltip(ch)
            y = self:_Row(newC, y, self:GetChallengeLabel(ch), progText, false, {
                valueRight = true,
                onClick = click,
                valueColor = valueColor,
                tooltipTitle = tipTitle,
                tooltipText = tipText,
            })
        end

        y = self:_Row(newC, y, L["stats_header_daily"] or "Täglich", nil, true)
        local dailies = (CM and CM.GetDailies and CM:GetDailies()) or {}
        if #dailies == 0 then
            y = self:_Row(newC, y, "–")
        else
            for i = 1, #dailies do
                addChallenge(dailies[i])
            end
        end

        y = self:_Row(newC, y, L["stats_header_weekly"] or "Wöchentlich", nil, true)
        local weekly = (CM and CM.GetWeekly and CM:GetWeekly()) or {}
        if #weekly == 0 then
            y = self:_Row(newC, y, "–")
        else
            for i = 1, #weekly do
                addChallenge(weekly[i])
            end
        end

        y = self:_Row(newC, y, L["stats_challenges_done"] or "Abgeschlossen:",
            tostring(hist.completedTotal or 0) .. "  ·  |cffffd700"
            .. tostring(hist.goldEarned or 0) .. " Gold|r")
    end

    -- ── BOX 4: Titel-Katalog ──────────────────────────────────
    if not self._titleCB then
        self:_BuildBox4Chrome()
    else
        local prof = Profile()
        UI.SetCheckboxValue(self._titleCB, prof.titleVisible ~= false)
    end
    self:_RefreshTitleCatalog()
end

-- ============================================================
-- BOX 4: Checkbox (einmalig) + Titel-Katalog (pro Rebuild)
-- ============================================================
function Stats:_BuildBox4Chrome()
    local c4 = self._box4Content
    if not c4 then return end
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local prof = Profile()

    local cb = UI.CreateCheckbox(c4,
        L["stats_title_visible"] or "Titel im Header anzeigen",
        INDENT, 2)
    UI.SetCheckboxValue(cb, prof.titleVisible ~= false)
    cb:SetScript("OnClick", function(self_cb)
        local val = UI.GetCheckboxValue(self_cb)
        local PS = ArcadiaNexus.ProfileStore
        if PS and PS.SetTitleVisible then
            PS.SetTitleVisible(val)
        end
        if ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
            pcall(ArcadiaNexus.UI.UpdateBadge)
        end
    end)
    self._titleCB = cb
end

function Stats:_SelectTitle(key)
    local PS = ArcadiaNexus.ProfileStore
    if PS and PS.SetActiveTitle then
        PS.SetActiveTitle(key)
    end
    local vis = Profile().titleVisible ~= false
    if vis and ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
        pcall(ArcadiaNexus.UI.UpdateBadge)
    end
    if self._panel and self._panel:IsShown() then
        pcall(function() Stats:_Rebuild() end)
    end
end

function Stats:_RefreshTitleCatalog()
    local c4 = self._box4Content
    if not c4 then return end
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local XPM = ArcadiaNexus.XPManager
    local prof = Profile()
    local level = prof.level or 1
    local catalog = self:GetUnlockedTitles()
    local activeKey = prof.activeTitle
    if (not activeKey or activeKey == "") and XPM and XPM.GetTitle then
        activeKey = XPM:GetTitle(level)
    end

    local CHIP_H = 14
    local COL_GAP = 8
    local colW = math.floor((BOX_W - 36) / 2)
    local listTop = 28
    local perCol = math.ceil(#catalog / 2)

    for i = 1, #catalog do
        local entry = catalog[i]
        local active = entry.key == activeKey
        local titleLabel = entry.label
        local label = entry.level .. "  " .. titleLabel
        local unlockHint = string.format(L["stats_title_locked"] or "ab Level %d", entry.level)

        local col = (i <= perCol) and 0 or 1
        local row = (i <= perCol) and (i - 1) or (i - 1 - perCol)
        local x = INDENT + col * (colW + COL_GAP)
        local y = listTop + row * CHIP_H

        local chip = self._rowPool:Acquire({})
        chip:SetParent(c4)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", c4, "TOPLEFT", x, -y)
        chip:SetSize(colW, CHIP_H)
        chip._isHeader = false
        chip._headerFS:Hide()
        chip._valueFS:Hide()
        chip._labelFS:ClearAllPoints()
        chip._labelFS:SetPoint("LEFT", chip, "LEFT", 0, 0)
        chip._labelFS:SetPoint("RIGHT", chip, "RIGHT", 0, 0)
        chip._labelFS:SetJustifyH("LEFT")
        chip._labelFS:SetWordWrap(false)
        chip._labelFS:SetText(label)
        chip._labelFS:Show()
        if active then
            chip._labelFS:SetTextColor(1.00, 0.82, 0.00)
        else
            chip._labelFS:SetTextColor(0.85, 0.78, 0.60)
        end
        local key = entry.key
        self:_BindRowClick(chip, function() Stats:_SelectTitle(key) end, titleLabel, unlockHint)
        chip:Show()
    end
end

-- ============================================================
-- REFRESH / SHOW / HIDE (externe API)
-- ============================================================
function Stats:Refresh()
    if self._panel and self._panel:IsShown() then
        pcall(function() self:_Rebuild() end)
    end
end

function Stats:Show()
    if self._panel then
        self._panel:Show()
        pcall(function() self:_Rebuild() end)
    end
end

function Stats:Hide()
    if self._panel then self._panel:Hide() end
end
