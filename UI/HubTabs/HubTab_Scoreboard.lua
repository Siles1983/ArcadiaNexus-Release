--[[
    UI/HubTabs/HubTab_Scoreboard.lua
    Registriert den SCOREBOARD Bottom-Tab.
]]

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id          = "SCOREBOARD",
    labelKey    = "tab_scoreboard",
    order       = 20,
    hasSidebar  = true,
    contentKey  = "scoreboard",
    sidebarKey  = "lbCatPanel",

    getContentLabel = function(state)
        local scoreCatID = state.activeScoreGame
        local GR = ArcadiaNexus.GameRegistry
        local scoreLabel = GR and GR.GetLabel(scoreCatID) or scoreCatID
        return scoreLabel or L("tab_scoreboard")
    end,
})
