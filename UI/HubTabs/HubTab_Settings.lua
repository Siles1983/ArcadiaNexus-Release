--[[
    UI/HubTabs/HubTab_Settings.lua
    Registriert den SETTINGS Bottom-Tab (HubSettings + Spiel-Settings).
]]

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id             = "SETTINGS",
    labelKey       = "tab_settings",
    order          = 50,
    hasSidebar     = true,
    contentKey     = "settings",
    sidebarKey     = "settingsCatPanel",
    alwaysActivate = true,

    onBeforeSelect = function(tab, prevTab)
        NexusTabState.activeSettingsCategory = nil
    end,

    getContentLabel = function(state)
        return L("tab_settings") or "Einstellungen"
    end,

    onBuild = function(main, F)
        local HS = ArcadiaNexus.HubSettings
        if HS and HS.BuildPanel and F.content then
            HS:BuildPanel(F.content)
        end
    end,

    refreshVisibility = function(active, F, state)
        if F.settingsCatPanel then
            if active then F.settingsCatPanel:Show() else F.settingsCatPanel:Hide() end
        end

        if not active then
            if F.settings then F.settings:Hide() end
            local HS = ArcadiaNexus.HubSettings
            if HS and HS.Hide then pcall(function() HS:Hide() end) end
            return
        end

        local hasCat = state.activeSettingsCategory ~= nil
        if F.settings then
            if hasCat then F.settings:Show() else F.settings:Hide() end
        end

        local HS = ArcadiaNexus.HubSettings
        if not HS then return end
        if hasCat then
            if HS.Hide then pcall(function() HS:Hide() end) end
        else
            if HS.Show then pcall(function() HS:Show() end) end
        end
    end,

    onSelect = function(tab, prevTab)
        local HS = ArcadiaNexus.HubSettings
        if HS and HS.Show then
            pcall(function() HS:Show() end)
        end
    end,

    onDeselect = function(tab, nextTab)
        local HS = ArcadiaNexus.HubSettings
        if HS and HS.Hide then
            pcall(function() HS:Hide() end)
        end
    end,
})
