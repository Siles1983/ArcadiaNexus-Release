--[[
    ArcadiaNexus – GamesPanel: Settings-Kategorie-Panel
    UI/GamesPanel/GamesPanel_Settings.lua

    Enthält:
        - BuildSettingsCategoryPanel (Sidebar für den Einstellungen-Tab)

    Abhängigkeiten:
        UI/GamesPanel/GamesPanel_Core.lua → ArcadiaNexus.UI.BuildSidebarPanel,
                                            ArcadiaNexus.UI.GetGamesPanelFrameRefs
]]

local function BuildSettingsCategoryPanel(parent)
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs()

    local function ActivateSettings(catID)
        NexusTabState.activeSettingsCategory = catID
        for _, b in ipairs(F.settingsCatBtns) do b.Refresh() end
        NexusTabs.RefreshPanelVisibility()
        if ArcadiaNexus and ArcadiaNexus.SettingsPanel and ArcadiaNexus.SettingsPanel.OnCategoryChange then
            ArcadiaNexus.SettingsPanel.OnCategoryChange(catID)
        end
    end

    local cp = ArcadiaNexus.UI.BuildSidebarPanel(parent, {
        frameName        = "NexusSettingsCategoryPanel",
        scrollName       = "NexusSettingsCatScroll",
        groupStatePrefix = "settings_",
        includeGeneral   = false,
        arrowKey         = "_sArrow",
        hdrKey           = "_sHdrBtn",
        grpFramePrefix   = "NexusSettingsGrp_",
        btnPrefix        = "NexusSettingsCategoryBtn_",
        gameBtnsKey      = "_sGameBtns",
        emptyHintKey     = "_emptyHint",
        favBtnPrefix     = "NexusSettingsBtnFav_",
        btnListRef       = F.settingsCatBtns,
        getActiveId      = function() return NexusTabState.activeSettingsCategory end,
        setActiveId      = function(id) NexusTabState.activeSettingsCategory = id end,
        activateCallback = ActivateSettings,
        onEnterTooltipKey = function(id) return "TOOLTIP_SETTINGS_CATEGORY_" .. id .. "_BODY" end,
        withSearchBar    = true,
        relayoutKey      = "SettingsPanelRelayout",
    })
    F.settingsCatPanel = cp
    return cp
end

ArcadiaNexus.UI.BuildSettingsCategoryPanel = BuildSettingsCategoryPanel
