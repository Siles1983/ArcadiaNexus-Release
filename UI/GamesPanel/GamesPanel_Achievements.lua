--[[
    ArcadiaNexus – GamesPanel: Achievement-Kategorie-Panel
    UI/GamesPanel/GamesPanel_Achievements.lua

    Enthält:
        - BuildAchievementCategoryPanel (Sidebar für den Erfolge-Tab)
        - Zusammenfassung-Button (sumBtn)
        - ArcadiaNexus.UI.ActivateAchCategory Export
        - ArcadiaNexus.UI.OpenAchievementFromToast

    Abhängigkeiten:
        UI/GamesPanel/GamesPanel_Core.lua → ArcadiaNexus.UI.BuildSidebarPanel,
                                            ArcadiaNexus.UI.GetGamesPanelFrameRefs
]]

local function BuildAchievementCategoryPanel(parent)
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs()

    -- Eigene Button-Liste NUR fuer den Zusammenfassung-Button
    -- (getrennt von F.achCatBtns damit er nicht in anderen Panels auftaucht)
    local sumBtns = {}

    local function ActivateAchGame(gameId)
        NexusTabState.activeAchCategory = gameId
        for _, b in ipairs(F.achCatBtns) do b.Refresh() end
        for _, b in ipairs(sumBtns)      do b.Refresh() end
        NexusTabs.RefreshPanelVisibility()
        local AUI = ArcadiaNexus and ArcadiaNexus.AchievementUI
        if AUI then
            if gameId == "ZUSAMMENFASSUNG" then
                if AUI.ShowSummary then
                    local ok, err = pcall(function() AUI:ShowSummary() end)
                    if not ok and DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444ArcadiaNexus|r AUI:ShowSummary error: " .. tostring(err))
                    end
                end
            elseif AUI.ShowGame then
                local ok, err = pcall(function() AUI:ShowGame(gameId) end)
                if not ok and DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444ArcadiaNexus|r AchUI:ShowGame error: " .. tostring(err))
                end
            end
        end
    end

    local cp = ArcadiaNexus.UI.BuildSidebarPanel(parent, {
        frameName        = "NexusAchCategoryPanel",
        scrollName       = "NexusAchCatScroll",
        groupStatePrefix = "ach_",
        includeGeneral   = true,
        arrowKey         = "_achArrow",
        hdrKey           = "_achHeaderBtn",
        grpFramePrefix   = "NexusAchCatGrp_",
        btnPrefix        = "NexusAchBtn_",
        gameBtnsKey      = "_achGameBtns",
        emptyHintKey     = "_achEmptyHint",
        favBtnPrefix     = "NexusAchBtnFav_",
        btnListRef       = F.achCatBtns,
        getActiveId      = function() return NexusTabState.activeAchCategory end,
        setActiveId      = function(id) NexusTabState.activeAchCategory = id end,
        activateCallback = ActivateAchGame,
        withSearchBar    = true,
        relayoutKey      = "AchPanelRelayout",
        afterBuild       = function(cp2, sf2, sc2, groups, RelayoutAll2)
            local L        = ArcadiaNexus.GetLocaleTable("UI")
            local Layout   = ArcadiaNexus.Layout
            local sumLabel = L["summary_title"] or "Zusammenfassung"
            local CAT_W    = Layout.sidebar.width

            -- sumBtn: 1:1 visuell wie CategoryHeader (BuildGroupHeader),
            -- aber ohne Pfeil, ohne Stern, ohne Rechtsklick
            local sumBtn, reused = ArcadiaNexus.UI.AcquireNamedFrame(
                "Button", "NexusAchSumBtn_ZUSAMMENFASSUNG", cp2)
            sumBtn:SetSize(CAT_W - 30, 24)
            sumBtn.catID = "ZUSAMMENFASSUNG"
            sumBtn._labelText = sumLabel

            if not reused then
                -- Hintergrund: identisch mit CategoryHeader (inkl. goldener Tönung)
                local catBG = sumBtn:CreateTexture(nil, "BACKGROUND", nil, 0)
                catBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background")
                catBG:SetAllPoints(sumBtn)
                catBG:SetTexCoord(0, 0.6640625, 0, 1)
                catBG:SetVertexColor(0.70, 0.60, 0.30, 1)

                -- Highlight-Textur (Hover)
                local hlTex = sumBtn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
                hlTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
                hlTex:SetAllPoints(sumBtn)
                hlTex:SetTexCoord(0, 0.6640625, 0, 1)
                hlTex:SetBlendMode("ADD")

                -- Aktiv-Highlight (manuell gesteuert)
                local activeBG = sumBtn:CreateTexture(nil, "ARTWORK", nil, 0)
                activeBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
                activeBG:SetAllPoints(sumBtn)
                activeBG:SetTexCoord(0, 0.6640625, 0, 1)
                activeBG:SetBlendMode("ADD")
                activeBG:SetAlpha(0)
                sumBtn.activeBG = activeBG

                -- Label
                local lbl = sumBtn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                lbl:SetPoint("LEFT",  sumBtn, "LEFT",  4, 0)
                lbl:SetPoint("RIGHT", sumBtn, "RIGHT", -4, 0)
                lbl:SetTextColor(1.00, 0.82, 0.00, 1)
                lbl:SetWordWrap(false)
                lbl:SetJustifyH("LEFT")
                sumBtn.lbl = lbl

                -- Trennlinie unter sumBtn
                local sep = cp2:CreateTexture(nil, "OVERLAY", nil, 7)
                sep:SetTexture("Interface\\Buttons\\WHITE8X8")
                sep:SetVertexColor(0.35, 0.28, 0.15, 0.5)
                sumBtn._sep = sep
            end

            if sumBtn.lbl then sumBtn.lbl:SetText(sumLabel) end

            -- Position: sumBtn sitzt ÜBER dem sf2, am cp2 verankert
            local SUM_BTN_Y = -35
            local SUM_SEP_Y = SUM_BTN_Y - 26   -- 26 = Btn-Höhe 24 + 2px Gap
            sumBtn:ClearAllPoints()
            sumBtn:SetPoint("TOPLEFT",  cp2, "TOPLEFT",   10, SUM_BTN_Y)
            sumBtn:SetPoint("TOPRIGHT", cp2, "TOPRIGHT",  -28, SUM_BTN_Y)
            sumBtn:Show()

            if sumBtn._sep then
                sumBtn._sep:ClearAllPoints()
                sumBtn._sep:SetPoint("TOPLEFT",  cp2, "TOPLEFT",   10, SUM_SEP_Y)
                sumBtn._sep:SetPoint("TOPRIGHT", cp2, "TOPRIGHT",  -28, SUM_SEP_Y)
                sumBtn._sep:SetHeight(1)
            end

            -- sf2 direkt unter der Trennlinie
            sf2:ClearAllPoints()
            sf2:SetPoint("TOPLEFT",     cp2, "TOPLEFT",      10, SUM_SEP_Y - 3)
            sf2:SetPoint("BOTTOMRIGHT", cp2, "BOTTOMRIGHT", -28, 6)
            if sf2.ScrollBar then
                sf2.ScrollBar:ClearAllPoints()
                sf2.ScrollBar:SetPoint("TOPRIGHT",    cp2, "TOPRIGHT",    -10, SUM_SEP_Y - 3 - 8)
                sf2.ScrollBar:SetPoint("BOTTOMRIGHT", cp2, "BOTTOMRIGHT",  -6,  18)
            end

            local function RefreshSumBtn()
                local active = NexusTabState.activeAchCategory == "ZUSAMMENFASSUNG"
                sumBtn.activeBG:SetAlpha(active and 1.0 or 0)
                sumBtn.lbl:SetTextColor(1.00, 0.82, 0.00, 1)
            end
            sumBtn.Refresh = RefreshSumBtn
            sumBtn:SetScript("OnClick", function(self) ActivateAchGame(self.catID) end)
            table.insert(sumBtns, sumBtn)
            RefreshSumBtn()
        end,
    })
    F.achCatPanel = cp
    -- Export für Summary-Navigation (Recent + Progress Klick)
    ArcadiaNexus.UI.ActivateAchCategory = ActivateAchGame

    --- Öffnet den Hub auf dem Erfolge-Tab und zeigt die passende Gruppe.
    function ArcadiaNexus.UI.OpenAchievementFromToast(ach)
        if not ach then return end
        local gameId = ach.gameId
        if not gameId and ach.groupId and ArcadiaNexus.AchievementData then
            for _, group in ipairs(ArcadiaNexus.AchievementData) do
                if group.id == ach.groupId then
                    gameId = group.gameId
                    break
                end
            end
        end
        gameId = gameId or "ALLGEMEIN"

        local main = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF().main
        if main and not main:IsShown() then
            if ArcadiaNexus.UI.UpdateBadge then ArcadiaNexus.UI.UpdateBadge() end
            main:Show()
        end

        ArcadiaNexus.UI._pendingAchNav = { gameId = gameId, groupId = ach.groupId }
        local AUI = ArcadiaNexus.AchievementUI
        if AUI then AUI._pendingFocusGroup = ach.groupId end
        if _G.NexusTabs and NexusTabs.SetActive then
            NexusTabs.SetActive("ACHIEVEMENTS")
        else
            local pending = ArcadiaNexus.UI._pendingAchNav
            ArcadiaNexus.UI._pendingAchNav = nil
            ActivateAchGame(pending.gameId)
            C_Timer.After(0.08, function()
                local AUI = ArcadiaNexus.AchievementUI
                if AUI and AUI.FocusGroup and pending.groupId then
                    AUI:FocusGroup(pending.groupId)
                end
            end)
        end
    end

    return cp
end

ArcadiaNexus.UI.BuildAchievementCategoryPanel = BuildAchievementCategoryPanel
