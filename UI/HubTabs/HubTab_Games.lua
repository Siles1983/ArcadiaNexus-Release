--[[
    UI/HubTabs/HubTab_Games.lua
    Registriert den GAMES Bottom-Tab.
]]

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id             = "GAMES",
    labelKey       = "tab_games",
    order          = 10,
    hasSidebar     = true,
    contentKey     = "games",
    sidebarKey     = "catPanel",
    alwaysActivate = true,

    getContentLabel = function(state)
        local gameCatID = state.activeCategory
        local GR = ArcadiaNexus.GameRegistry
        local gameLabel = GR and GR.GetLabel(gameCatID) or gameCatID
        return gameLabel or L("label_games")
    end,

    onSelect = function(tab, prevTab)
        local pending = ArcadiaNexus.UI and ArcadiaNexus.UI._pendingGameOpen
        if pending then
            ArcadiaNexus.UI._pendingGameOpen = nil
            local fn = ArcadiaNexus.UI._ActivateGameFn
            if fn then
                pcall(fn, pending)
            end
            return
        end
        NexusTabState.activeCategory = nil
        C_Timer.After(0, function()
            local wp = ArcadiaNexus.UI.WelcomePanel
            if wp then wp:Show() end
        end)
    end,

    onDeselect = function(tab, nextTab)
        if nextTab and nextTab.id ~= "GAMES" then
            NexusTabs.StopAllGames()
        end
        local wp = ArcadiaNexus.UI.WelcomePanel
        if wp then wp:Hide() end
    end,
})
