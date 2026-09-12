--[[
    UI/HubTabs/HubTab_Match.lua
    Mehrspieler: Sidebar (MP-Titel) + Sitzung/Lobby/Canvas.
]]

if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then
    return
end

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id               = "MATCH",
    labelKey         = "tab_match",
    order            = 15,
    hasSidebar       = true,
    sidebarKey       = "matchSidebar",
    externalPanelKey = "matchBrowser",

    getContentLabel = function()
        local Shell = ArcadiaNexus.MatchShell
        local gid = Shell and Shell.selectedGameId
        if gid then
            local GR = ArcadiaNexus.GameRegistry
            return (GR and GR.GetLabel and GR.GetLabel(gid)) or gid
        end
        return L("tab_match") or "Mehrspieler"
    end,

    onBuild = function(main, F)
        local MB = ArcadiaNexus.MatchBrowserUI
        if not MB then return end
        if MB.BuildSidebar then
            F.matchSidebar = MB.BuildSidebar(main)
        end
        local parent = F.content or main
        if MB.BuildPanel then
            F.matchBrowser = MB.BuildPanel(parent)
        end
    end,

    onSelect = function()
        local MB = ArcadiaNexus.MatchBrowserUI
        if MB and MB.OnTabSelect then
            MB.OnTabSelect()
        elseif MB and MB.Refresh then
            MB.Refresh()
        end
        if MB and MB.RefreshSidebar then
            MB.RefreshSidebar()
        end
    end,
})
