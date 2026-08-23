--[[
    UI/HubTabs/HubTab_Achievements.lua
    Registriert den ACHIEVEMENTS Bottom-Tab.
]]

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id             = "ACHIEVEMENTS",
    labelKey       = "tab_achievements",
    order          = 30,
    hasSidebar     = true,
    contentKey     = "achievements",
    sidebarKey     = "achCatPanel",
    alwaysActivate = true,

    onBeforeSelect = function(tab, prevTab)
        if ArcadiaNexus.UI and ArcadiaNexus.UI._pendingAchNav then
            return
        end
        NexusTabState.activeAchCategory = "ZUSAMMENFASSUNG"
    end,

    getContentLabel = function(state)
        local achGameId = state.activeAchCategory
        if achGameId == "ZUSAMMENFASSUNG" then
            return L("tab_achievements") or "Erfolge"
        end
        local GR = ArcadiaNexus.GameRegistry
        local achLabel = GR and GR.GetLabel(achGameId) or achGameId
        return achLabel or L("tab_achievements") or "Erfolge"
    end,

    onSelect = function(tab, prevTab)
        local pending = ArcadiaNexus.UI and ArcadiaNexus.UI._pendingAchNav
        if pending then
            ArcadiaNexus.UI._pendingAchNav = nil
            local fn = ArcadiaNexus.UI.ActivateAchCategory
            if fn then
                pcall(fn, pending.gameId)
            end
            C_Timer.After(0.08, function()
                local AUI = ArcadiaNexus.AchievementUI
                if AUI and AUI.FocusGroup and pending.groupId then
                    pcall(function() AUI:FocusGroup(pending.groupId) end)
                end
            end)
            if ArcadiaNexus.UI and ArcadiaNexus.UI.AchPanelRelayout then
                pcall(ArcadiaNexus.UI.AchPanelRelayout)
            end
            return
        end
        local AUI = ArcadiaNexus.AchievementUI
        if AUI and AUI.ShowSummary then
            pcall(function() AUI:ShowSummary() end)
        end
        if ArcadiaNexus.UI and ArcadiaNexus.UI.AchPanelRelayout then
            pcall(ArcadiaNexus.UI.AchPanelRelayout)
        end
    end,
})
