--[[
    ArcadiaNexus – GamesPanel: Leaderboard-Kategorie-Panel
    UI/GamesPanel/GamesPanel_Leaderboard.lua

    Enthält:
        - BuildLeaderboardCategoryPanel (Sidebar für den Bestenliste-Tab)

    Abhängigkeiten:
        UI/GamesPanel/GamesPanel_Core.lua → ArcadiaNexus.UI.BuildSidebarPanel,
                                            ArcadiaNexus.UI.GetGamesPanelFrameRefs
]]

local function BuildLeaderboardCategoryPanel(parent)
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs()

    local function ActivateScoreGame(catID)
        NexusTabState.activeScoreGame = catID
        for _, b in ipairs(F.lbCatBtns) do b.Refresh() end
        NexusTabs.RefreshPanelVisibility()
        if ArcadiaNexus.LB and ArcadiaNexus.LB.ShowGame then
            ArcadiaNexus.LB.ShowGame(catID)
        end
    end

    local cp = ArcadiaNexus.UI.BuildSidebarPanel(parent, {
        frameName        = "NexusLBCategoryPanel",
        scrollName       = "NexusLeaderboardCatScroll",
        groupStatePrefix = "lb_",
        includeGeneral   = false,
        arrowKey         = "_lbArrow",
        hdrKey           = "_lbHeaderBtn",
        grpFramePrefix   = "NexusLBCatGrp_",
        btnPrefix        = "NexusLBCatBtn_",
        gameBtnsKey      = "_lbGameBtns",
        emptyHintKey     = "_emptyHint",
        favBtnPrefix     = "NexusLBBtnFav_",
        btnListRef       = F.lbCatBtns,
        getActiveId      = function() return NexusTabState.activeScoreGame end,
        setActiveId      = function(id) NexusTabState.activeScoreGame = id end,
        activateCallback = ActivateScoreGame,
        withSearchBar    = true,
        relayoutKey      = "LBPanelRelayout",
    })
    F.lbCatPanel = cp
    return cp
end

ArcadiaNexus.UI.BuildLeaderboardCategoryPanel = BuildLeaderboardCategoryPanel
