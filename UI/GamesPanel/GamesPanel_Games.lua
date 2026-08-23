--[[
    ArcadiaNexus – GamesPanel: Spiele-Kategorie-Panel
    UI/GamesPanel/GamesPanel_Games.lua

    Enthält:
        - BuildCategoryPanel (Sidebar für den Spiele-Tab)
        - Chromie's Gambit Shuffle-Button

    Abhängigkeiten:
        UI/GamesPanel/GamesPanel_Core.lua → ArcadiaNexus.UI.BuildSidebarPanel,
                                            ArcadiaNexus.UI.GetGamesPanelFrameRefs
]]

local function BuildCategoryPanel(parent)
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs()

    local function ActivateGame(catID)
        NexusTabState.activeCategory = catID
        for _, b in ipairs(F.catBtns) do b.Refresh() end
        NexusTabs.RefreshPanelVisibility()
        if ArcadiaNexus and ArcadiaNexus.GameRegistry then
            local GR = ArcadiaNexus.GameRegistry
            GR.HideAllContainers()
            NexusTabs.StopAllGames()
            local info = GR.GetById(catID)
            if info then
                GR.ShowContainer(catID)
                local rnd = GR.GetRenderer(catID)
                local eng = GR.GetEngine(catID)
                local engRunning = eng and eng.state and eng.state ~= "IDLE"
                if rnd and rnd.EnterIdleState and not engRunning then
                    rnd:EnterIdleState()
                end
            end
        end
        local fpr = _G["NexusFeedPanel_Real"]
        if fpr and fpr.OnCategoryChange then fpr:OnCategoryChange(catID) end
        -- Willkommens-Panel ausblenden wenn ein Spiel aktiviert wird
        if ArcadiaNexus.UI.WelcomePanel then
            ArcadiaNexus.UI.WelcomePanel:Hide()
        end
    end
    -- Export damit WelcomePanel den GOTD-Button verknüpfen kann
    ArcadiaNexus.UI._ActivateGameFn = ActivateGame

    --- Overlay-GOTD: Spiel öffnen, ohne den Spiele-Tab-Klick (Willkommen) auszulösen.
    function ArcadiaNexus.UI.OpenGameFromOverlay(gameId)
        if not gameId then return end
        local main = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF().main
        if main and not main:IsShown() then
            if ArcadiaNexus.UI.UpdateBadge then ArcadiaNexus.UI.UpdateBadge() end
            main:Show()
        end
        if not (_G.NexusTabs and NexusTabs.GetActive) or NexusTabs.GetActive() == "GAMES" then
            ActivateGame(gameId)
            return
        end
        ArcadiaNexus.UI._pendingGameOpen = gameId
        NexusTabs.SetActive("GAMES")
    end

    local cp = ArcadiaNexus.UI.BuildSidebarPanel(parent, {
        frameName        = "NexusCategoryPanel",
        scrollName       = "NexusGameCatScroll",
        groupStatePrefix = "",
        includeGeneral   = false,
        arrowKey         = "_arrow",
        hdrKey           = "_headerBtn",
        grpFramePrefix   = "NexusCatGrp_",
        btnPrefix        = "NexusCategoryBtn_",
        gameBtnsKey      = "_gameBtns",
        emptyHintKey     = "_emptyHint",
        favBtnPrefix     = "NexusCategoryBtnFav_",
        btnListRef       = F.catBtns,
        getActiveId      = function() return NexusTabState.activeCategory end,
        setActiveId      = function(id) NexusTabState.activeCategory = id end,
        activateCallback = ActivateGame,
        onEnterTooltipKey = function(id) return "TOOLTIP_CATEGORY_" .. id .. "_BODY" end,
        initialHide      = false,   -- Spiele-Panel startet sichtbar
        withSearchBar    = true,
        relayoutKey      = "GamesPanelRelayout",

        afterBuild = function(cp, sf, sc, groups, RelayoutAll)
            -- Chromie's Gambit: fest unten verankert, scrollt nicht mit
            local SHUFFLE_H     = 30
            local SHUFFLE_INSET = 7

            -- sf unten kuerzen damit Platz fuer den Button bleibt
            sf:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -28, SHUFFLE_H + 10)

            -- Scrollbar ebenfalls anpassen
            C_Timer.After(0, function()
                if sf.ScrollBar then
                    sf.ScrollBar:ClearAllPoints()
                    sf.ScrollBar:SetPoint("TOPRIGHT",    cp, "TOPRIGHT",    -10, -(18 + 28))
                    sf.ScrollBar:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT",  -6,  SHUFFLE_H + 10)
                end
            end)

            local shuffleBtn, reused = ArcadiaNexus.UI.AcquireNamedFrame(
                "Button", "NexusShuffleBtn", cp, "BackdropTemplate")
            shuffleBtn:SetPoint("BOTTOMLEFT",  cp, "BOTTOMLEFT",  SHUFFLE_INSET, 7)
            shuffleBtn:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -SHUFFLE_INSET, 7)
            shuffleBtn:SetHeight(SHUFFLE_H)

            if not reused then
                -- Trennlinie ueber dem Button
                local div = cp:CreateTexture(nil, "ARTWORK", nil, 0)
                div:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
                div:SetPoint("BOTTOMLEFT",  cp, "BOTTOMLEFT",  10, SHUFFLE_H + 8)
                div:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -10, SHUFFLE_H + 8)
                div:SetHeight(8); div:SetHorizTile(true)

                shuffleBtn:SetBackdrop({
                    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileEdge = true, tileSize = 16, edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 },
                })
                shuffleBtn:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
                shuffleBtn:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

                -- Icon links
                local icon = shuffleBtn:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", shuffleBtn, "LEFT", 6, 0)
                icon:SetTexture(1500865)

                -- Label
                local lbl = shuffleBtn:CreateFontString(nil, "OVERLAY")
                lbl:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                lbl:SetPoint("LEFT",  icon,        "RIGHT", 5, 0)
                lbl:SetPoint("RIGHT", shuffleBtn, "RIGHT", -6, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetTextColor(1, 0.82, 0)
                lbl:SetShadowOffset(1, -1)
                lbl:SetShadowColor(0, 0, 0, 1)
                lbl:SetText("Chromie's Gambit")

                -- Hover
                local hl = shuffleBtn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
                hl:SetTexCoord(0, 0.6640625, 0, 1)
                hl:SetBlendMode("ADD")
            end

            -- Klick: zufälliges sichtbares Spiel (hiddenGames werden nicht durchlaufen)
            shuffleBtn:SetScript("OnClick", function()
                local GR = ArcadiaNexus.GameRegistry
                if not GR then return end
                local current = NexusTabState and NexusTabState.activeCategory
                local filter = {
                    includeDevOnly   = GR.FILTER_SIDEBAR.includeDevOnly,
                    respectHidden    = true,
                    requireContainer = true,
                    excludeId        = current,
                }
                local pick = GR.GetRandom(filter)
                if not pick then
                    filter.excludeId = nil
                    pick = GR.GetRandom(filter)
                end
                if pick and pick.id and ActivateGame then
                    ActivateGame(pick.id)
                end
            end)
        end,
    })
    F.catPanel = cp
    if not cp._hubWelcomeScheduled then
        cp._hubWelcomeScheduled = true
        C_Timer.After(0, function()
            local wp = ArcadiaNexus.UI.WelcomePanel
            if wp and F.content then
                if not wp._frame then wp:Build(F.content) end
                wp:Show()
            end
        end)
    end
    return cp
end

ArcadiaNexus.UI.BuildCategoryPanel = BuildCategoryPanel
