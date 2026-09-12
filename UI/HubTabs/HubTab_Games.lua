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
        local UI = ArcadiaNexus.UI
        local pendingRun = UI and UI._presentRunningGame
        if pendingRun then
            UI._presentRunningGame = nil
            if UI.RevealRunningGame then
                pcall(UI.RevealRunningGame, pendingRun)
            end
            return
        end
        local pending = UI and UI._pendingGameOpen
        if pending then
            UI._pendingGameOpen = nil
            local fn = UI._ActivateGameFn
            if fn then
                pcall(fn, pending)
            end
            return
        end
        local GR = ArcadiaNexus.GameRegistry
        local cat = NexusTabState.activeCategory
        local eng = cat and GR and GR.GetEngine and GR.GetEngine(cat)
        if eng and eng.state and eng.state ~= "IDLE" and eng.mode == "hotseat" then
            local wp = UI and UI.WelcomePanel
            if wp then wp:Hide() end
            if GR.HideAllContainers then GR.HideAllContainers() end
            if GR.ShowContainer then GR.ShowContainer(cat) end
            return
        end
        NexusTabState.activeCategory = nil
        C_Timer.After(0, function()
            local wp = ArcadiaNexus.UI.WelcomePanel
            if wp then wp:Show() end
        end)
    end,

    onDeselect = function(tab, nextTab)
        if nextTab and nextTab.id ~= "GAMES" and nextTab.id ~= "MATCH" then
            NexusTabs.StopAllGames()
        end
        local wp = ArcadiaNexus.UI.WelcomePanel
        if wp then wp:Hide() end
    end,
})
