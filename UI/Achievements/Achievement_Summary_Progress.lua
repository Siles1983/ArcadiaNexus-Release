--[[
    ArcadiaNexus – Achievement_Summary_Progress
    UI/Achievement_Summary_Progress.lua

    Fortschrittsüberblick: 1:1 Blizzard-Layout.
    + Hover-Effekt (UI-Achievement-StatusBar-Highlight, ADD)
    + Klick navigiert zur Achievement-Kategorie

    Blizzard StatusBar-Highlight (aus XML AchievementFrameSummaryCategoryTemplate):
      Button-Frame enthält Highlight-Frame mit:
        Left:   UI-Achievement-StatusBar-Highlight ADD, 32×32, TOPLEFT -7,+8
        Right:  UI-Achievement-StatusBar-Highlight ADD, 32×32, TOPRIGHT +7,+8, gespiegelt
        Middle: gestreckt zwischen Left.TOPRIGHT und Right.BOTTOMLEFT, TexCoord 0.5,1,0,1
      OnEnter: Highlight:Show()  OnLeave: Highlight:Hide()
      OnClick: → ActivateAchCategory(catKey)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AchSumProgress = {}
local PROG = ArcadiaNexus.AchSumProgress

local STATUSBAR_W = 488
local STATUSBAR_H = 21
local CAT_W       = 234
local COL_GAP     = 20
local ROW_GAP     = 10
local HDR_H       = 23
local HDR_GAP     = 6
local BAR_GAP     = 13

local function SetBarTexture(bar)
    bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    bar:SetStatusBarColor(0, 1, 0)
end

local function AddBarDecorations(bar)
    if bar._decorated then return end
    bar._decorated = true

    local tL = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    tL:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tL:SetSize(32, 48)
    tL:SetPoint("TOPLEFT", bar, "TOPLEFT", -15, 16)
    tL:SetTexCoord(0.423828125, 0.486, 0.56640625, 0.75)

    local tR = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    tR:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tR:SetSize(32, 48)
    tR:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 15, 16)
    tR:SetTexCoord(0.486, 0.423828125, 0.56640625, 0.75)

    local tM = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    tM:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tM:SetPoint("TOPLEFT",  tL, "TOPRIGHT", 0, 0)
    tM:SetPoint("TOPRIGHT", tR, "TOPLEFT",  0, 0)
    tM:SetHeight(48)
    tM:SetTexCoord(0.486, 0.889224609375, 0.56640625, 0.75)
end

-- ============================================================
-- Hover-Highlight für StatusBar (Blizzard AchievementFrameSummaryCategoryTemplate)
-- UI-Achievement-StatusBar-Highlight: Left 32×32 -7,+8 / Right gespiegelt / Middle gestreckt
-- ============================================================
local function BuildBarHighlight(parent)
    local hl = CreateFrame("Frame", nil, parent)
    hl:SetAllPoints(parent)
    hl:Hide()

    local tex = "Interface\\AchievementFrame\\UI-Achievement-StatusBar-Highlight"

    local tL = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tL:SetTexture(tex); tL:SetBlendMode("ADD")
    tL:SetSize(32, 32)
    tL:SetPoint("TOPLEFT", parent, "TOPLEFT", -7, 8)
    tL:SetTexCoord(0, 1, 0, 1)

    local tR = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tR:SetTexture(tex); tR:SetBlendMode("ADD")
    tR:SetSize(32, 32)
    tR:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 7, 8)
    tR:SetTexCoord(1, 0, 0, 1)  -- gespiegelt

    local tM = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tM:SetTexture(tex); tM:SetBlendMode("ADD")
    tM:SetPoint("TOPLEFT",     tL, "TOPRIGHT",   0, 0)
    tM:SetPoint("BOTTOMRIGHT", tR, "BOTTOMLEFT", 0, 0)
    tM:SetTexCoord(0.5, 1, 0, 1)

    return hl
end

local _statusBarPool = nil
local _progressHdr   = nil

local function EnsureProgressHeader(parent, xC, yOff, labelText)
    if not _progressHdr then
        local hdr = CreateFrame("Frame", nil, parent)
        hdr._bg = hdr:CreateTexture(nil, "BACKGROUND", nil, 0)
        hdr._bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-RecentHeader")
        hdr._bg:SetTexCoord(0, 1, 0, 0.71875)
        hdr._lbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr._lbl:SetPoint("CENTER", hdr, "CENTER", 0, 0)
        _progressHdr = hdr
    end
    local hdr = _progressHdr
    hdr:SetParent(parent)
    hdr:SetSize(STATUSBAR_W, HDR_H)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", xC, -yOff)
    hdr._bg:ClearAllPoints()
    hdr._bg:SetPoint("TOPLEFT",     hdr, "TOPLEFT",     -20, 0)
    hdr._bg:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT",  20, 0)
    hdr._lbl:SetText(labelText)
    hdr:Show()
    return hdr
end

local function GetStatusBarPool()
    if not _statusBarPool then
        local poolParentRef = nil
        _statusBarPool = ArcadiaNexus.UI.FramePool.New({
            name = "Achievement.SummaryProgress",
            create = function(poolParent)
                poolParentRef = poolParent
                local btn = CreateFrame("Button", nil, poolParent)
                btn:SetHeight(STATUSBAR_H)

                local bar = CreateFrame("StatusBar", nil, btn)
                bar:SetAllPoints(btn)
                SetBarTexture(bar)

                local bg = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
                bg:SetTexture("Interface\\Buttons\\WHITE8X8")
                bg:SetAllPoints(bar)
                bg:SetVertexColor(0, 0, 0, 0.5)

                local lbl = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                lbl:SetPoint("LEFT", bar, "LEFT", 6, 4)

                local txt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                txt:SetPoint("RIGHT", bar, "RIGHT", -5, 3)

                AddBarDecorations(bar)

                btn._bar = bar
                btn._lbl = lbl
                btn._txt = txt
                btn._hl  = BuildBarHighlight(btn)
                return btn
            end,
            onRelease = function(btn)
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetScript("OnClick", nil)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                if btn._hl then btn._hl:Hide() end
                if poolParentRef then btn:SetParent(poolParentRef) end
            end,
        })
    end
    return _statusBarPool
end

function PROG.ReleaseAll()
    if _statusBarPool then _statusBarPool:ReleaseAll() end
    if _progressHdr then _progressHdr:Hide() end
end

-- ============================================================
-- StatusBar als klickbarer Button mit Hover
-- catKey: category-Schlüssel für Navigation (nil = Platzhalter, kein Klick)
-- ============================================================
local function ConfigureStatusBar(btn, parent, labelText, unlocked, total, w, catKey, withHover)
    if withHover == nil then withHover = true end

    btn:SetParent(parent)
    btn:SetSize(w, STATUSBAR_H)
    btn:ClearAllPoints()

    local bar = btn._bar
    bar:SetMinMaxValues(0, math.max(total, 1))
    bar:SetValue(unlocked)
    btn._lbl:SetText(labelText)
    btn._txt:SetText(unlocked .. "/" .. total)

    if withHover then
        btn:SetScript("OnEnter", function() btn._hl:Show() end)
        btn:SetScript("OnLeave", function() btn._hl:Hide() end)
    else
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        if btn._hl then btn._hl:Hide() end
    end

    if catKey then
        btn:SetScript("OnClick", function()
            local activate = ArcadiaNexus.UI and ArcadiaNexus.UI.ActivateAchCategory
            if activate then activate(catKey) end
        end)
    else
        btn:SetScript("OnClick", nil)
    end

    btn:Show()
    return btn
end

local function BuildStatusBar(parent, labelText, unlocked, total, w, catKey, withHover)
    local btn = GetStatusBarPool():Acquire({})
    return ConfigureStatusBar(btn, parent, labelText, unlocked, total, w, catKey, withHover)
end

-- Achievements nach category zählen
local function GetStatsByCategory(catKey)
    if not catKey then return 0, 0 end
    local ad = ArcadiaNexus.AchievementData or {}
    local ul = (ArcadiaNexusDB and ArcadiaNexusDB.achievements
                and ArcadiaNexusDB.achievements.unlocked) or {}
    local total, unlocked = 0, 0
    for _, group in ipairs(ad) do
        local groupCat = group.category or group.gameId
        if groupCat == catKey then
            for _, tier in ipairs(group.tiers or {}) do
                total = total + 1
                if ul[tier.id] then unlocked = unlocked + 1 end
            end
        end
    end
    return unlocked, total
end

local function GetOverallStats()
    local SHm = ArcadiaNexus.AchSumH
    if SHm and SHm.GetOverallStats then return SHm.GetOverallStats() end
    local ad = ArcadiaNexus.AchievementData or {}
    local ul = (ArcadiaNexusDB and ArcadiaNexusDB.achievements
                and ArcadiaNexusDB.achievements.unlocked) or {}
    local total, unlocked = 0, 0
    for _, group in ipairs(ad) do
        for _, tier in ipairs(group.tiers or {}) do
            total = total + 1
            if ul[tier.id] then unlocked = unlocked + 1 end
        end
    end
    return { total = total, unlocked = unlocked }
end

-- Kategorie-Mapping aus CategoryRegistry (kein hardcoded Duplicate).
local function BuildCategoryMap()
    local L = ArcadiaNexus.GetLocaleTable("UI")
    local labelFn = function(key) return L[key] end
    local CR = ArcadiaNexus.CategoryRegistry
    if CR and CR.GetProgressCategories then
        return CR.GetProgressCategories(labelFn)
    end
    return { { id = "ALLGEMEIN", label = L["cat_ALLGEMEIN"] or "Allgemein" } }
end

function PROG.Build(parent, yOff)
    PROG.ReleaseAll()

    local L    = ArcadiaNexus.GetLocaleTable("UI")
    local W    = parent:GetWidth() or STATUSBAR_W
    local xC   = math.floor((W - STATUSBAR_W) / 2)
    local cats = BuildCategoryMap()

    local blockH = 0

    -- Header
    EnsureProgressHeader(parent, xC, yOff, L["summary_progress"] or "Fortschrittsüberblick")

    blockH = blockH + HDR_H + HDR_GAP

    -- Gesamtbalken (kein Hover, kein Klick — kein sinnvolles Navigationsziel)
    local overall  = GetOverallStats()
    local totalBar = BuildStatusBar(
        parent,
        L["summary_overall"] or "Errungene Erfolge",
        overall.unlocked, overall.total,
        STATUSBAR_W, nil, false   -- withHover=false
    )
    totalBar:SetPoint("TOPLEFT", parent, "TOPLEFT", xC, -(yOff + blockH))
    blockH = blockH + STATUSBAR_H + BAR_GAP

    -- 2-Spalten-Grid (dynamisch aus CategoryRegistry)
    local catBars = {}
    local gridTop = yOff + blockH
    local numRows = math.ceil(#cats / 2)

    for i, cat in ipairs(cats) do
        local ul, tot = GetStatsByCategory(cat.id)
        catBars[i]    = BuildStatusBar(parent, cat.label, ul, tot, CAT_W, cat.id)
    end

    for row = 1, numRows do
        local iL = (row - 1) * 2 + 1
        local iR = iL + 1
        local barL = catBars[iL]
        if row == 1 then
            barL:SetPoint("TOPLEFT", parent, "TOPLEFT", xC, -gridTop)
        else
            local prevLeftIdx = (row - 2) * 2 + 1
            barL:SetPoint("TOPLEFT", catBars[prevLeftIdx], "BOTTOMLEFT", 0, -ROW_GAP)
        end
        if catBars[iR] then
            catBars[iR]:SetPoint("TOPLEFT", barL, "TOPRIGHT", COL_GAP, 0)
        end
    end

    if numRows > 0 then
        blockH = blockH + numRows * STATUSBAR_H + (numRows - 1) * ROW_GAP + ROW_GAP
    end

    return blockH
end
