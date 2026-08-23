--[[
    ArcadiaNexus – HubSettings Core
    UI/Settings/HubSettings_Core.lua

    Enthält:
        - HubSettings Table-Deklaration + ArcadiaNexus.HubSettings Export
        - Lokale Helper: MakeBtn, L
        - HubSettings._MakeBtn / HubSettings._TabWidth (modul-interne Utilities)
        - BuildPanel (Panel + Tab-Buttons + Tab-Frames + OnShow)
        - SetActiveTab
        - Show / Hide
        - _RefreshAll, _UpdateCoordDisplay, _UpdateGotdDisplay
        - _ShowConfirm (shared Dialog-Helper)

    Ladereihenfolge: MUSS als erstes Settings-Modul geladen werden.
    Alle HubSettings_Tab*.lua schreiben danach in dieselbe HubSettings-Table.
]]

local UI = ArcadiaNexus.UI
local Layout = ArcadiaNexus.Layout

local HubSettings = {}
ArcadiaNexus.HubSettings = HubSettings

-- ============================================================
-- LOKALE HELPER (Settings-intern)
-- ============================================================

local function MakeBtn(parent, label, w, h, r, g, b, br, bg, bb)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileEdge=true, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
    })
    btn:SetBackdropColor(r, g, b, 0.9)
    btn:SetBackdropBorderColor(br, bg, bb, 1)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(btn)
    fs:SetJustifyH("CENTER")
    fs:SetText(label)
    fs:SetTextColor(br, bg, bb)
    btn._lbl = fs
    return btn
end

-- Export für Tab-Module (Settings-scope)
HubSettings._MakeBtn = MakeBtn

-- Lokaler L()-Wrapper (Language.lua lädt vor dieser Datei)
local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

local function TabWidth(parent)
    local w = parent:GetWidth()
    if not w or w < 50 then w = 700 end
    return w
end

-- Export für Tab-Module
HubSettings._TabWidth = TabWidth

local TAB_W   = 130
local TAB_H   = 24
local TAB_GAP = 4

local function ResolveTabLabel(tab)
    return L(tab.labelKey) or tab.labelFallback or tab.id
end

local function GetSettingsTabRegistry()
    return ArcadiaNexus.HubSettingsTabRegistry
end

-- ============================================================
-- TAB-BAR BAUEN (aus HubSettingsTabRegistry)
-- ============================================================

function HubSettings:_BuildSettingsTabBar(tabBar, sc)
    local HSTR = GetSettingsTabRegistry()
    if not HSTR then return end

    local oldBtns   = self._tabBtns   or {}
    local oldFrames = self._tabFrames or {}
    self._tabBtns   = {}
    self._tabFrames = {}

    for _, btn in pairs(oldBtns) do
        btn:Hide()
    end
    for _, tf in pairs(oldFrames) do
        tf:Hide()
    end

    for i, tab in ipairs(HSTR.GetAll()) do
        local btn = oldBtns[tab.id]
        if btn then
            btn:SetParent(tabBar)
            btn:ClearAllPoints()
            btn:SetSize(TAB_W, TAB_H)
            btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i - 1) * (TAB_W + TAB_GAP), 0)
            if btn._lbl then btn._lbl:SetText(ResolveTabLabel(tab)) end
            btn._tabID = tab.id
            btn:SetScript("OnClick", function() HubSettings:SetActiveTab(tab.id) end)
            btn:Show()
        else
            btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
            btn:SetSize(TAB_W, TAB_H)
            btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i - 1) * (TAB_W + TAB_GAP), 0)
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileEdge=true, edgeSize=10,
                insets={left=2,right=2,top=2,bottom=2},
            })
            btn:SetBackdropColor(0.10, 0.08, 0.04, 0.85)
            btn:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)

            local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetAllPoints(btn)
            lbl:SetJustifyH("CENTER")
            lbl:SetText(ResolveTabLabel(tab))
            lbl:SetTextColor(0.85, 0.78, 0.60)
            btn._lbl   = lbl
            btn._tabID = tab.id

            local hl = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
            hl:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
            hl:SetAllPoints(btn)
            hl:SetTexCoord(0, 0.6640625, 0, 1)
            hl:SetBlendMode("ADD")

            btn:SetScript("OnClick", function() HubSettings:SetActiveTab(tab.id) end)
        end
        self._tabBtns[tab.id] = btn

        local tf = oldFrames[tab.id]
        if tf then
            tf:SetParent(sc)
            tf:ClearAllPoints()
            tf:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
            tf:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, 0)
            tf:SetHeight(Layout.content.height)
        else
            tf = CreateFrame("Frame", nil, sc)
            tf:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
            tf:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, 0)
            tf:SetHeight(Layout.content.height)
            tf:Hide()
            pcall(tab.buildContent, tf)
        end
        self._tabFrames[tab.id] = tf
    end
end

function HubSettings:RebuildTabBar()
    if not self._tabBar or not self._sc then return end
    self:_BuildSettingsTabBar(self._tabBar, self._sc)
    if self._activeTab and self._tabBtns[self._activeTab] then
        self:SetActiveTab(self._activeTab)
    else
        local HSTR = GetSettingsTabRegistry()
        local defaultId = HSTR and HSTR.GetDefaultTabId()
        if defaultId then self:SetActiveTab(defaultId) end
    end
end

-- ============================================================
-- PANEL AUFBAUEN
-- ============================================================

function HubSettings:BuildPanel(parent)
    if self._panel then return self._panel end

    local p = CreateFrame("Frame", "NexusHubSettingsPanel", parent, "BackdropTemplate")
    p:SetAllPoints(parent)
    p:Hide()
    self._panel = p

    -- ── Divider unter Titel ───────────────────────────────────
    local div = p:CreateTexture(nil, "ARTWORK", nil, 0)
    div:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    div:SetPoint("TOPLEFT",  p, "TOPLEFT",  20, -44)
    div:SetPoint("TOPRIGHT", p, "TOPRIGHT", -20, -44)
    div:SetHeight(8); div:SetHorizTile(true)

    -- ── Sub-Reiter-Leiste ─────────────────────────────────────
    local tabBar = CreateFrame("Frame", nil, p)
    tabBar:SetPoint("TOPLEFT",  p, "TOPLEFT",  20, -56)
    tabBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -20, -56)
    tabBar:SetHeight(26)
    self._tabBar = tabBar

    -- ── Content-ScrollFrame (ein einziger, Inhalt wird pro Tab gewechselt) ──
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT",     p, "TOPLEFT",     20, -88)
    sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -20,  10)
    self._sf = sf

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(1)
    sc:SetHeight(Layout.content.height)
    sf:SetScrollChild(sc)
    self._sc = sc

    sf:SetScript("OnSizeChanged", function()
        HubSettings:_RefreshSettingsLayout()
    end)

    self:_BuildSettingsTabBar(tabBar, sc)

    -- ── OnShow ────────────────────────────────────────────────
    p:SetScript("OnShow", function()
        HubSettings:_RefreshAll()
        local HSTR = GetSettingsTabRegistry()
        local defaultId = HSTR and HSTR.GetDefaultTabId()
        if not HubSettings._activeTab then
            HubSettings:SetActiveTab(defaultId or "GENERAL")
        else
            HubSettings:SetActiveTab(HubSettings._activeTab)
        end
        HubSettings:_RefreshSettingsLayout()
        C_Timer.After(0, function()
            HubSettings:_RefreshSettingsLayout()
        end)
        C_Timer.After(0.05, function()
            HubSettings:_RefreshSettingsLayout()
        end)
    end)

    return p
end

-- ============================================================
-- TAB SWITCHING
-- ============================================================

function HubSettings:SetActiveTab(tabID)
    local HSTR = GetSettingsTabRegistry()
    local tab = HSTR and HSTR.GetById(tabID)
    if not tab then return end

    self._activeTab = tabID

    for id, btn in pairs(self._tabBtns) do
        local active = (id == tabID)
        if active then
            btn:SetBackdropColor(0.18, 0.14, 0.04, 0.95)
            btn:SetBackdropBorderColor(1.00, 0.82, 0.00, 1)
            btn._lbl:SetTextColor(1.00, 0.82, 0.00)
        else
            btn:SetBackdropColor(0.10, 0.08, 0.04, 0.85)
            btn:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
            btn._lbl:SetTextColor(0.85, 0.78, 0.60)
        end
    end

    for id, tf in pairs(self._tabFrames) do
        if id == tabID then tf:Show() else tf:Hide() end
    end

    self:_RefreshSettingsLayout()

    if tab.onSelect then
        pcall(tab.onSelect, self)
    end
end

-- ============================================================
-- LAYOUT REFRESH (ScrollChild-Breite = sichtbare ScrollFrame-Breite)
-- ============================================================

function HubSettings:_RefreshSettingsLayout()
    local pw = (self._sf and self._sf:GetWidth()) or 0
    if pw < 100 and self._panel then
        pw = (self._panel:GetWidth() or 0) - 40
    end
    if pw < 100 then return end

    if self._sc then self._sc:SetWidth(pw) end

    local HSTR = GetSettingsTabRegistry()
    local activeTab = HSTR and self._activeTab and HSTR.GetById(self._activeTab)
    if activeTab and activeTab.refreshLayout then
        pcall(activeTab.refreshLayout, self, pw)
    end
end

-- ============================================================
-- REFRESH (alle Anzeigen synchronisieren)
-- ============================================================

function HubSettings:_RefreshAll()
    self:_UpdateCoordDisplay()
    self:_UpdateGotdDisplay()
    if self._refreshScaleBtns then self._refreshScaleBtns() end
    -- DevMode CB
    if self._devModeCB then
        local val = ArcadiaNexusDB and ArcadiaNexusDB.dev and ArcadiaNexusDB.dev.devMode == true
        self._devModeCB:SetChecked(val)
    end
    -- GOTD-ShowCB
    if self._gotdShowCB then
        local showGotd = ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.showGotd
        if showGotd == nil then showGotd = true end
        self._gotdShowCB:SetChecked(showGotd)
    end
    -- Drag-Lock CB
    if self._lockCB then
        local locked = ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.lockUI == true
        self._lockCB:SetChecked(locked)
    end
end

function HubSettings:_UpdateCoordDisplay()
    if not self._coordFS then return end
    local db = ArcadiaNexusDB and ArcadiaNexusDB.toastAnchor
    local x  = db and db.x or 0
    local y  = db and db.y or -200
    self._coordFS:SetText(
        (L("hubsettings_position") or "Position:") ..
        " X=" .. math.floor(x) .. "  Y=" .. math.floor(y))
end

function HubSettings:_UpdateGotdDisplay()
    if not self._gotdNameFS then return end
    local CM = ArcadiaNexus.ChallengeManager
    if CM and CM.GetGameOfDay then
        local gotd = CM:GetGameOfDay()
        if gotd then
            local GR = ArcadiaNexus.GameRegistry
            local label = GR and GR.GetLabel(gotd) or gotd
            self._gotdNameFS:SetText(
                (L("stats_gotd") or "Spiel des Tages:") ..
                " |cff00ff88" .. label .. "|r  (+25% XP)")
        end
    end
end

-- ============================================================
-- CONFIRM-DIALOG (shared – wird von allen Tabs genutzt)
-- ============================================================

function HubSettings:_ShowConfirm(title, body, onConfirm)
    if not self._confirmDialog then
        local d = CreateFrame("Frame", "NexusSettingsConfirmDialog", UIParent, "BackdropTemplate")
        d:SetSize(380, 150)
        d:SetFrameStrata("DIALOG")
        d:SetFrameLevel(800)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=5,right=5,top=5,bottom=5},
        })
        d:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
        d:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local titleFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -14)
        titleFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -14)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(1.00, 0.82, 0.00)
        d._titleFS = titleFS

        local bodyFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bodyFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -38)
        bodyFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -38)
        bodyFS:SetJustifyH("CENTER")
        bodyFS:SetTextColor(0.85, 0.78, 0.60)
        bodyFS:SetWordWrap(true)
        d._bodyFS = bodyFS

        local confirmBtn = UI.CreateButton(d, "Bestätigen", 160, 26)
        confirmBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)
        d._confirmBtn = confirmBtn

        local cancelBtn = UI.CreateButton(d, "Abbrechen", 160, 26)
        cancelBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
        cancelBtn:SetScript("OnClick", function() d:Hide() end)

        self._confirmDialog = d
    end

    local d = self._confirmDialog
    d._titleFS:SetText(title)
    d._bodyFS:SetText(body)
    d._confirmBtn:SetScript("OnClick", function()
        d:Hide()
        if onConfirm then onConfirm() end
    end)
    d:Show()
end

-- ============================================================
-- SHOW / HIDE
-- ============================================================

function HubSettings:Show()
    if self._panel then
        self._panel:Show()
        self:_RefreshSettingsLayout()
        C_Timer.After(0, function() self:_RefreshSettingsLayout() end)
    end
end

function HubSettings:Hide()
    if self._panel then self._panel:Hide() end
    if self._anchorActive     then self:_HideAnchor() end
    if self._gotdAnchorActive then self:_HideGotdAnchor() end
end
