--[[
    NEXUS GAMING HUB
    Modul: TabsController
    Verantwortlich für: Tab-State, Tab-API, Tab-Button-Bau, Panel-Sichtbarkeit

    Abhängigkeiten (müssen vor diesem Modul geladen sein):
        Core/TabRegistry.lua
        UI/HubTabs/*.lua              (RegisterHubTab)
        UI/UIHelpers.lua
        UI/LayoutConfig.lua

    Öffentliche API:
        NexusTabState
        NexusTabs.SetActive(id)
        NexusTabs.GetActive()
        NexusTabs.IsActive(id)
        NexusTabs.OnTabChanged(cb)
        NexusTabs.RefreshPanelVisibility()
        NexusTabs.RefreshTabButtons()
        NexusTabs.RebuildBottomTabs()
        NexusTabs.SetFrameRefs(F)
        BuildBottomTabs(parent)
]]

local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

local Layout = ArcadiaNexus.Layout

-- ============================================================
-- STATE
-- ============================================================
NexusTabState = {
    activeTab              = "GAMES",
    activeCategory         = nil,
    activeSettingsCategory = nil,
    activeScoreGame        = "TICTACTOE",
    activeAchCategory      = "ZUSAMMENFASSUNG",
}

local tabCBs = {}
local F = {}

-- ============================================================
-- TAB-API
-- ============================================================
NexusTabs = {}

function NexusTabs.SetFrameRefs(refs)
    F = refs
    F.tabBtns = F.tabBtns or {}
end

local function StopAllGames()
    if not _G.ArcadiaNexus then return end
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.StopActiveGame then
        GR.StopActiveGame()
    end
end
NexusTabs.StopAllGames = StopAllGames

local function ResolveTabLabel(tab)
    if tab.labelKey then
        return L(tab.labelKey) or tab.labelFallback or tab.id
    end
    return tab.label or tab.id
end

local function DefaultRefreshVisibility(tab, active)
    if tab.contentKey and F[tab.contentKey] then
        if active then F[tab.contentKey]:Show() else F[tab.contentKey]:Hide() end
    end
    if tab.sidebarKey and F[tab.sidebarKey] then
        if active then F[tab.sidebarKey]:Show() else F[tab.sidebarKey]:Hide() end
    end
    if tab.externalPanelKey and F[tab.externalPanelKey] then
        if active then F[tab.externalPanelKey]:Show() else F[tab.externalPanelKey]:Hide() end
    end
end

function NexusTabs.SetActive(id)
    local TR = ArcadiaNexus.TabRegistry
    local tab = TR and TR.GetById(id)
    if not tab then return end

    if NexusTabState.activeTab == id and not tab.alwaysActivate then return end

    local prevId = NexusTabState.activeTab
    local prevTab = TR.GetById(prevId)

    if tab.onBeforeSelect then
        pcall(tab.onBeforeSelect, tab, prevTab)
    end

    if prevTab and prevTab.onDeselect and prevId ~= id then
        pcall(prevTab.onDeselect, prevTab, tab)
    end

    NexusTabState.activeTab = id
    NexusTabs.RefreshPanelVisibility()
    NexusTabs.RefreshTabButtons()

    for _, cb in ipairs(tabCBs) do
        cb(id, prevId)
    end

    if tab.onSelect then
        pcall(tab.onSelect, tab, prevTab)
    end
end

function NexusTabs.GetActive()  return NexusTabState.activeTab end
function NexusTabs.IsActive(id) return NexusTabState.activeTab == id end
function NexusTabs.OnTabChanged(cb)
    if type(cb) == "function" then table.insert(tabCBs, cb) end
end

-- ============================================================
-- PANEL-SICHTBARKEIT
-- ============================================================
function NexusTabs.RefreshPanelVisibility()
    local TR = ArcadiaNexus.TabRegistry
    if not TR then return end

    local activeId = NexusTabState.activeTab
    local activeTab = TR.GetById(activeId)

    for _, tab in ipairs(TR.GetAll()) do
        local active = tab.id == activeId
        if tab.refreshVisibility then
            pcall(tab.refreshVisibility, active, F, NexusTabState)
        else
            DefaultRefreshVisibility(tab, active)
        end
    end

    if F.content then
        F.content:ClearAllPoints()
        local hasSidebar = activeTab and activeTab.hasSidebar
        local x, y = Layout.GetContentTopLeft(hasSidebar)
        F.content:SetPoint("TOPLEFT", F.main, "TOPLEFT", x, y)
        F.content:SetPoint("BOTTOMRIGHT", F.main, "BOTTOMRIGHT",
            -Layout.content.rightInset, Layout.GetBottomContentOffset())
    end

    if F.contentLabelFS and activeTab and activeTab.getContentLabel then
        local ok, label = pcall(activeTab.getContentLabel, NexusTabState)
        if ok and label then
            F.contentLabelFS:SetText(label)
        end
    end
end

-- ============================================================
-- TAB-BUTTON REFRESH
-- ============================================================
function NexusTabs.RefreshTabButtons()
    for _, btn in ipairs(F.tabBtns or {}) do
        local active = btn.tabID == NexusTabState.activeTab

        if btn.tLeftA  then btn.tLeftA:SetShown(active)     end
        if btn.tMidA   then btn.tMidA:SetShown(active)      end
        if btn.tRightA then btn.tRightA:SetShown(active)    end
        if btn.tLeft   then btn.tLeft:SetShown(not active)  end
        if btn.tMid    then btn.tMid:SetShown(not active)   end
        if btn.tRight  then btn.tRight:SetShown(not active) end
        if btn.shadow  then btn.shadow:SetShown(active)     end

        if btn.hl  then btn.hl:SetShown(not active)  end
        if btn.hlR then btn.hlR:SetShown(not active) end
        if btn.hlM then btn.hlM:SetShown(not active) end

        if btn.labelFS then
            if active then
                btn.labelFS:SetTextColor(1.00, 0.82, 0.00)
                btn.labelFS:SetFontObject("GameFontNormal")
            else
                btn.labelFS:SetTextColor(0.60, 0.50, 0.35)
                btn.labelFS:SetFontObject("GameFontNormalSmall")
            end
        end
    end
end

-- ============================================================
-- TAB-BUTTON-BAU
-- ============================================================
local function CreateTabButton(parent, tab, tabW, spacing, index, startX)
    local btn, reused = ArcadiaNexus.UI.AcquireNamedFrame("Button", "NexusTabBtn_" .. tab.id, parent)
    btn:SetSize(tabW, Layout.tabs.height)
    btn:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", startX + (index - 1) * (tabW + spacing), 15)
    btn.tabID = tab.id
    btn:SetFrameStrata(parent:GetFrameStrata())
    btn:SetFrameLevel(parent:GetFrameLevel() + 7)

    if reused then
        if btn.labelFS then
            btn.labelFS:SetText(ResolveTabLabel(tab))
        end
        return btn
    end

    local shadow = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    shadow:SetPoint("TOPLEFT",  btn, "BOTTOMLEFT",  6, 2)
    shadow:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", -6, 2)
    shadow:SetHeight(6)
    shadow:SetVertexColor(0, 0, 0, 0.35)
    btn.shadow = shadow

    local tLeftA = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    tLeftA:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tLeftA:SetSize(21, 59); tLeftA:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 0)
    tLeftA:SetTexCoord(0.47265625, 0.513671875, 0.76953125, 1.0); tLeftA:Hide()
    btn.tLeftA = tLeftA

    local tRightA = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    tRightA:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tRightA:SetSize(18, 59); tRightA:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 4, 0)
    tRightA:SetTexCoord(0.685546875, 0.720703125, 0.76953125, 1.0); tRightA:Hide()
    btn.tRightA = tRightA

    local tMidA = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    tMidA:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tMidA:SetPoint("TOPLEFT",  tLeftA,  "TOPRIGHT", 0, 0)
    tMidA:SetPoint("TOPRIGHT", tRightA, "TOPLEFT",  0, 0)
    tMidA:SetHeight(59)
    tMidA:SetTexCoord(0.513671875, 0.685546875, 0.76953125, 1.0); tMidA:Hide()
    btn.tMidA = tMidA

    local tLeft = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    tLeft:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tLeft:SetSize(21, 49); tLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 0)
    tLeft:SetTexCoord(0.47265625, 0.513671875, 0.76953125, 1.0)
    tLeft:SetVertexColor(0.6, 0.6, 0.6); btn.tLeft = tLeft

    local tRight = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    tRight:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tRight:SetSize(18, 49); tRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 4, 0)
    tRight:SetTexCoord(0.685546875, 0.720703125, 0.76953125, 1.0)
    tRight:SetVertexColor(0.6, 0.6, 0.6); btn.tRight = tRight

    local tMid = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    tMid:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tMid:SetPoint("TOPLEFT",  tLeft,  "TOPRIGHT", 0, 0)
    tMid:SetPoint("TOPRIGHT", tRight, "TOPLEFT",  0, 0)
    tMid:SetHeight(49)
    tMid:SetTexCoord(0.513671875, 0.685546875, 0.76953125, 1.0)
    tMid:SetVertexColor(0.6, 0.6, 0.6); btn.tMid = tMid

    local tHL = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    btn.hl = tHL
    tHL:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tHL:SetSize(32, 49)
    tHL:SetPoint("TOPLEFT", tLeft, "TOPLEFT", -3, 0)
    tHL:SetTexCoord(0.720703125, 0.783203125, 0.76953125, 1.0)
    tHL:SetBlendMode("ADD")

    local tHL_R = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    btn.hlR = tHL_R
    tHL_R:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tHL_R:SetSize(18, 49)
    tHL_R:SetPoint("TOPRIGHT", tRight, "TOPRIGHT", 0, 0)
    tHL_R:SetTexCoord(0.923828125, 0.986328125, 0.76953125, 1.0)
    tHL_R:SetBlendMode("ADD")

    local tHL_M = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    btn.hlM = tHL_M
    tHL_M:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Header")
    tHL_M:SetHeight(49)
    tHL_M:SetPoint("LEFT",  tHL,   "RIGHT", 0, 0)
    tHL_M:SetPoint("RIGHT", tHL_R, "LEFT",  0, 0)
    tHL_M:SetTexCoord(0.783203125, 0.923828125, 0.76953125, 1.0)
    tHL_M:SetBlendMode("ADD")

    local labelFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelFS:SetPoint("CENTER", btn, "CENTER", 0, -3)
    labelFS:SetText(ResolveTabLabel(tab))
    labelFS:SetTextColor(0.60, 0.50, 0.35)
    btn.labelFS = labelFS

    btn:SetScript("OnEnter", function(self)
        if NexusTabs.IsActive(self.tabID) then return end
        if NexusTooltip_Show then
            NexusTooltip_Show(self,
                "TOOLTIP_TAB_" .. self.tabID .. "_TITLE",
                "TOOLTIP_TAB_" .. self.tabID .. "_BODY")
        end
    end)

    btn:SetScript("OnLeave", function()
        if NexusTooltip_Hide then NexusTooltip_Hide() end
    end)

    btn:SetScript("OnClick", function(self)
        NexusTabs.SetActive(self.tabID)
    end)

    return btn
end

function BuildBottomTabs(parent)
    F.tabBtns = F.tabBtns or {}

    local TR = ArcadiaNexus.TabRegistry
    local tabs = TR and TR.GetAll() or {}
    local tabW = Layout.tabs.buttonWidth
    local spacing = Layout.tabs.spacing
    local totalWidth = (#tabs * tabW) + ((#tabs - 1) * spacing)
    local startX = (parent:GetWidth() - totalWidth) / 2

    for i, tab in ipairs(tabs) do
        local btn = CreateTabButton(parent, tab, tabW, spacing, i, startX)
        table.insert(F.tabBtns, btn)
    end

    NexusTabs.RefreshTabButtons()
end

function NexusTabs.RebuildBottomTabs()
    if not F.main then return end

    for _, btn in ipairs(F.tabBtns or {}) do
        btn:Hide()
    end
    F.tabBtns = {}

    BuildBottomTabs(F.main)
end
