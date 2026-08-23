--[[
    NEXUS GAMING HUB
    Modul: ArcadiaNexus_UI (Bootstrap / Frame-Registry)

    Definiert: F-Tabelle + ArcadiaNexus.UI.GetF()
    Alle funktionalen Blöcke in Submodulen:
      UI/TabsController.lua   – Tab-State, NexusTabs, BuildBottomTabs
      UI/ContentPanel.lua     – SolidTex, CreateNexusScrollbar, BuildHeader,
                                BuildGotdBadge, BuildContentPanel
      UI/GamesPanel/            – FavMgr, GetCategoryGroups, BuildCategoryPanel,
                                BuildSettingsCategoryPanel,
                                BuildLeaderboardCategoryPanel,
                                BuildAchievementCategoryPanel (modular)
      UI/HUD.lua              – UpdateBadge, Engine-Events
      UI/MainFrame.lua        – BuildMainFrame, Toggle, Init, Public API
      UI/MinimapButton.lua    – CreateMinimapButton
]]

local UI_VERSION = "0.9.8"
NexusTheme = "CLASSIC"

-- Shell-Dimensionen: UI/Core/LayoutConfig.lua (ArcadiaNexus.Layout)

local F = {
    main=nil, titleFS=nil, badgeFS=nil, badgePctFS=nil, badgeBar=nil,
    catPanel=nil, catBtns={},
    settingsCatPanel=nil, settingsCatBtns={},
    lbCatPanel=nil, lbCatBtns={},
    achCatPanel=nil, achCatBtns={},
    content=nil, feed=nil, profile=nil, settings=nil,
    profil=nil,
    streakFS=nil, goldFS=nil, gotdBox=nil,
    tabBtns={}, contentLabelFS=nil,
}

ArcadiaNexus.UI.GetF = function() return F end
