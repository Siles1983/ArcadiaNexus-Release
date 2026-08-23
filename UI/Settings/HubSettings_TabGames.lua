--[[
    ArcadiaNexus – HubSettings Tab: Spiele
    UI/Settings/HubSettings_TabGames.lua

    Enthält:
        - _BuildTabGames (Dual Listbox: Spiele ausblenden / einblenden)
        - _RefreshGamesList (Breiten + Listen befüllen, OnShow)
        - _ToggleGameVisibility (Doppelklick-Handler)

    Abhängigkeiten:
        UI/Settings/HubSettings_Core.lua → ArcadiaNexus.HubSettings
]]

local UI          = ArcadiaNexus.UI
local HubSettings = ArcadiaNexus.HubSettings

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

local function CopyHiddenGames(src)
    local t = {}
    if src then
        for id, v in pairs(src) do
            if v then t[id] = true end
        end
    end
    return t
end

function HubSettings:_CopyHiddenGames(src)
    return CopyHiddenGames(src)
end

function HubSettings:_EnsurePendingHiddenGames()
    if not self._pendingHiddenGames then
        self._pendingHiddenGames = CopyHiddenGames(
            ArcadiaNexusDB and ArcadiaNexusDB.hiddenGames)
    end
end

function HubSettings:_ApplyPendingHiddenGames()
    if not ArcadiaNexusDB then return end
    self:_EnsurePendingHiddenGames()
    ArcadiaNexusDB.hiddenGames = CopyHiddenGames(self._pendingHiddenGames)
end

local function CreateGameListBtnPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "HubSettings.GameListButtons",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileEdge=true, edgeSize=10,
                insets={left=2,right=2,top=2,bottom=2},
            })
            local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT",  btn, "LEFT",  6, 0)
            lbl:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
            lbl:SetJustifyH("LEFT")
            btn._lbl = lbl
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:Enable()
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetScript("OnClick", nil)
            btn._lastClick = nil
            btn._entryID   = nil
            btn._isVisible = nil
            if btn._lbl then btn._lbl:SetText("") end
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- TAB: SPIELE – Dual Listbox
-- ============================================================

function HubSettings:_BuildTabGames(parent)
    local P = UI.BOX_PAD

    -- ── Dual Listbox ──────────────────────────────────────────
    local LIST_H = 400
    local listBox, listContent = UI.CreateBox(parent,
        L("hubsettings_games_section") or "Spiele verwalten",
        P, 0, 0, LIST_H, P)

    -- ── Buttons unter der Box ─────────────────────────────────
    local BTN_Y = LIST_H + 10

    local confirmBtn = UI.CreateButton(parent, L("hubsettings_games_confirm_btn") or "Bestätigen & Neu laden", 180, 26)
    confirmBtn:SetPoint("TOP", parent, "TOP", -94, -BTN_Y)
    confirmBtn:SetScript("OnClick", function()
        HubSettings:_EnsurePendingHiddenGames()
        HubSettings:_ShowConfirm(
            L("hubsettings_games_confirm_title") or "Änderungen übernehmen?",
            L("hubsettings_games_confirm_body")  or
                "Das Addon wird neu geladen. Versteckte Spiele werden erst danach nicht mehr angezeigt.",
            function()
                HubSettings:_ApplyPendingHiddenGames()
                ReloadUI()
            end
        )
    end)

    local resetHiddenBtn = UI.CreateButton(parent, L("hubsettings_games_reset_btn") or "Liste zurücksetzen", 180, 26)
    resetHiddenBtn:SetPoint("LEFT", confirmBtn, "RIGHT", 8, 0)
    resetHiddenBtn:SetScript("OnClick", function()
        -- Alle Spiele wieder als sichtbar markieren (wirkt erst nach Bestätigen & Reload)
        HubSettings._pendingHiddenGames = {}
        HubSettings:_RefreshGamesList()
    end)

    self._gamesListBox     = listBox
    self._gamesListContent = listContent

    -- ── Beschreibungstext ─────────────────────────────────────
    local descFS = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descFS:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, 0)
    descFS:SetPoint("RIGHT",   listContent, "RIGHT",   0, 0)
    descFS:SetJustifyH("LEFT")
    descFS:SetWordWrap(true)
    descFS:SetTextColor(0.75, 0.70, 0.55)
    descFS:SetText(
        (L("hubsettings_games_desc") or "Doppelklick auf ein Spiel zum Ausblenden oder Einblenden.") ..
        " " ..
        (L("hubsettings_games_reload_hint") or "|cffffaa00Änderungen werden erst nach /reload sichtbar.|r")
    )

    -- ── Divider unter Beschreibung ────────────────────────────
    local descDiv = listContent:CreateTexture(nil, "ARTWORK")
    descDiv:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    descDiv:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -28)
    descDiv:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -28)
    descDiv:SetHeight(8)
    descDiv:SetHorizTile(true)

    -- ── Spalten-Header ────────────────────────────────────────
    local leftHdr = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftHdr:SetText("|cffffd700" .. (L("hubsettings_games_visible") or "Sichtbar") .. "|r")
    self._gamesLeftHdr = leftHdr

    local rightHdr = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightHdr:SetJustifyH("CENTER")
    rightHdr:SetText("|cff888888" .. (L("hubsettings_games_hidden") or "Versteckt") .. "|r")
    self._gamesRightHdr = rightHdr

    -- ── Trennlinie zwischen Spalten ───────────────────────────
    local midDiv = listContent:CreateTexture(nil, "ARTWORK")
    midDiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    midDiv:SetVertexColor(0.55, 0.45, 0.20, 0.8)
    midDiv:SetWidth(2)
    self._gamesMidDiv = midDiv

    -- ── Header-Divider (unter Labels) ────────────────────────
    local hdrDiv = listContent:CreateTexture(nil, "ARTWORK")
    hdrDiv:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
    hdrDiv:SetHeight(8)
    hdrDiv:SetHorizTile(true)
    self._gamesHdrDiv = hdrDiv

    -- ── Linke ScrollFrame ─────────────────────────────────────
    local leftSF = CreateFrame("ScrollFrame", nil, listContent)
    leftSF:EnableMouseWheel(true)
    self._gamesLeftSF = leftSF

    local leftSC = CreateFrame("Frame", nil, leftSF)
    leftSC:SetHeight(1)
    leftSF:SetScrollChild(leftSC)
    self._gamesLeftSC = leftSC

    -- ── Rechte ScrollFrame ────────────────────────────────────
    local rightSF = CreateFrame("ScrollFrame", nil, listContent)
    rightSF:EnableMouseWheel(true)
    self._gamesRightSF = rightSF

    local rightSC = CreateFrame("Frame", nil, rightSF)
    rightSC:SetHeight(1)
    rightSF:SetScrollChild(rightSC)
    self._gamesRightSC = rightSC
end

-- ============================================================
-- DUAL-LISTBOX: Breiten + Listen befüllen (OnShow)
-- ============================================================

function HubSettings:_RefreshGamesList()
    local lc = self._gamesListContent
    if not lc then return end

    self:_EnsurePendingHiddenGames()

    local totalW = lc:GetWidth()
    if not totalW or totalW < 50 then
        totalW = (self._sf and self._sf:GetWidth()) or 540
    end

    local SB_W  = 16
    local GAP   = 4
    local DIV_W = 2
    local COL_OUTER_W = math.floor((totalW - DIV_W) / 2)
    local SF_W  = COL_OUTER_W - SB_W - GAP
    local HDR_Y = 38
    local SF_Y  = HDR_Y + 20

    local leftX  = 0
    local divX   = COL_OUTER_W
    local rightX = COL_OUTER_W + DIV_W

    -- ── Scrollbars initialisieren (einmalig) ──────────────────
    if not self._gamesLeftSB then
        local leftSB = CreateFrame("EventFrame", nil, lc, "MinimalScrollBar")
        leftSB:SetHideIfUnscrollable(true)
        leftSB.hideTrack = false
        leftSB.Track:SetAlpha(0.9)
        leftSB.Track:Show()
        leftSB.Track:SetWidth(8)
        local trackBGL = lc:CreateTexture(nil, "BACKGROUND", nil, -6)
        trackBGL:SetWidth(6)
        trackBGL:SetTexture("Interface\\Buttons\\WHITE8X8")
        trackBGL:SetVertexColor(0.55, 0.55, 0.55, 0.45)
        leftSB.TrackBG = trackBGL
        self._gamesLeftSB = leftSB
        self._gamesLeftSF.ScrollBar = leftSB

        self._gamesLeftSF:EnableMouseWheel(true)
        self._gamesLeftSF:SetScript("OnVerticalScroll", function(self2, offset)
            local range = self2:GetVerticalScrollRange()
            if range > 0 then
                leftSB:SetScrollPercentage(offset / range)
            else
                leftSB:SetScrollPercentage(0)
            end
        end)
        leftSB:RegisterCallback("OnScroll", function(_, pct)
            local range = self._gamesLeftSF:GetVerticalScrollRange()
            self._gamesLeftSF:SetVerticalScroll(pct * range)
        end)
        self._gamesLeftSF:SetScript("OnMouseWheel", function(self2, delta)
            local step = 20
            local new = self2:GetVerticalScroll() - delta * step
            if new < 0 then new = 0 end
            if new > self2:GetVerticalScrollRange() then new = self2:GetVerticalScrollRange() end
            self2:SetVerticalScroll(new)
        end)
    end

    if not self._gamesRightSB then
        local rightSB = CreateFrame("EventFrame", nil, lc, "MinimalScrollBar")
        rightSB:SetHideIfUnscrollable(true)
        rightSB.hideTrack = false
        rightSB.Track:SetAlpha(0.9)
        rightSB.Track:Show()
        rightSB.Track:SetWidth(8)
        local trackBGR = lc:CreateTexture(nil, "BACKGROUND", nil, -6)
        trackBGR:SetWidth(6)
        trackBGR:SetTexture("Interface\\Buttons\\WHITE8X8")
        trackBGR:SetVertexColor(0.55, 0.55, 0.55, 0.45)
        rightSB.TrackBG = trackBGR
        self._gamesRightSB = rightSB
        self._gamesRightSF.ScrollBar = rightSB

        self._gamesRightSF:EnableMouseWheel(true)
        self._gamesRightSF:SetScript("OnVerticalScroll", function(self2, offset)
            local range = self2:GetVerticalScrollRange()
            if range > 0 then
                rightSB:SetScrollPercentage(offset / range)
            else
                rightSB:SetScrollPercentage(0)
            end
        end)
        rightSB:RegisterCallback("OnScroll", function(_, pct)
            local range = self._gamesRightSF:GetVerticalScrollRange()
            self._gamesRightSF:SetVerticalScroll(pct * range)
        end)
        self._gamesRightSF:SetScript("OnMouseWheel", function(self2, delta)
            local step = 20
            local new = self2:GetVerticalScroll() - delta * step
            if new < 0 then new = 0 end
            if new > self2:GetVerticalScrollRange() then new = self2:GetVerticalScrollRange() end
            self2:SetVerticalScroll(new)
        end)
    end

    if self._gamesMidDiv then
        self._gamesMidDiv:ClearAllPoints()
        self._gamesMidDiv:SetPoint("TOPLEFT",    lc, "TOPLEFT",  divX,  -(SF_Y - 4))
        self._gamesMidDiv:SetPoint("BOTTOMLEFT", lc, "BOTTOMLEFT", divX, 0)
    end

    if self._gamesLeftHdr then
        self._gamesLeftHdr:ClearAllPoints()
        self._gamesLeftHdr:SetPoint("TOP", lc, "TOPLEFT", leftX + SF_W / 2, -(HDR_Y - 2))
        self._gamesLeftHdr:SetJustifyH("CENTER")
    end
    if self._gamesRightHdr then
        self._gamesRightHdr:ClearAllPoints()
        self._gamesRightHdr:SetPoint("TOP", lc, "TOPLEFT", rightX + SF_W / 2, -(HDR_Y - 2))
    end

    if self._gamesHdrDiv then
        self._gamesHdrDiv:ClearAllPoints()
        self._gamesHdrDiv:SetPoint("TOPLEFT",  lc, "TOPLEFT",  0, -(SF_Y - 6))
        self._gamesHdrDiv:SetPoint("TOPRIGHT", lc, "TOPRIGHT", 0, -(SF_Y - 6))
    end

    self._gamesLeftSF:ClearAllPoints()
    self._gamesLeftSF:SetPoint("TOPLEFT",    lc, "TOPLEFT",  leftX,  -SF_Y)
    self._gamesLeftSF:SetPoint("BOTTOMLEFT", lc, "BOTTOMLEFT", leftX, 0)
    self._gamesLeftSF:SetWidth(SF_W)
    self._gamesLeftSC:SetWidth(SF_W - 4)

    self._gamesLeftSB:ClearAllPoints()
    self._gamesLeftSB:SetPoint("TOPRIGHT",    lc, "TOPLEFT",  divX - GAP, -(SF_Y))
    self._gamesLeftSB:SetPoint("BOTTOMRIGHT", lc, "BOTTOMLEFT", divX - GAP, 0)
    self._gamesLeftSB.Track:ClearAllPoints()
    self._gamesLeftSB.Track:SetPoint("TOP",    self._gamesLeftSB, "TOP",    0, -16)
    self._gamesLeftSB.Track:SetPoint("BOTTOM", self._gamesLeftSB, "BOTTOM", 0,  16)
    self._gamesLeftSB.TrackBG:ClearAllPoints()
    self._gamesLeftSB.TrackBG:SetPoint("TOP",    self._gamesLeftSB, "TOP",    0, -16)
    self._gamesLeftSB.TrackBG:SetPoint("BOTTOM", self._gamesLeftSB, "BOTTOM", 0,  16)

    self._gamesRightSF:ClearAllPoints()
    self._gamesRightSF:SetPoint("TOPLEFT",    lc, "TOPLEFT",  rightX, -SF_Y)
    self._gamesRightSF:SetPoint("BOTTOMLEFT", lc, "BOTTOMLEFT", rightX, 0)
    self._gamesRightSF:SetWidth(SF_W)
    self._gamesRightSC:SetWidth(SF_W - 4)

    self._gamesRightSB:ClearAllPoints()
    self._gamesRightSB:SetPoint("TOPRIGHT",    lc, "TOPRIGHT",  -(GAP), -(SF_Y))
    self._gamesRightSB:SetPoint("BOTTOMRIGHT", lc, "BOTTOMRIGHT", -(GAP), 0)
    self._gamesRightSB.Track:ClearAllPoints()
    self._gamesRightSB.Track:SetPoint("TOP",    self._gamesRightSB, "TOP",    0, -16)
    self._gamesRightSB.Track:SetPoint("BOTTOM", self._gamesRightSB, "BOTTOM", 0,  16)
    self._gamesRightSB.TrackBG:ClearAllPoints()
    self._gamesRightSB.TrackBG:SetPoint("TOP",    self._gamesRightSB, "TOP",    0, -16)
    self._gamesRightSB.TrackBG:SetPoint("BOTTOM", self._gamesRightSB, "BOTTOM", 0,  16)

    -- ── Buttons-Listen aufräumen ──────────────────────────────
    if not self._gameListBtnPool then
        self._gameListBtnPool = CreateGameListBtnPool()
    end
    self._gameListBtnPool:ReleaseAll()
    self._gamesVisibleBtns = {}
    self._gamesHiddenBtns  = {}

    -- ── Registry aufteilen ────────────────────────────────────
    local hidden = self._pendingHiddenGames or {}
    local visible, hiddenList = {}, {}
    local GR = ArcadiaNexus and ArcadiaNexus.GameRegistry
    if GR then
        GR.Iterate(GR.FILTER_HUB_MANAGE, function(info)
            if hidden[info.id] then
                table.insert(hiddenList, { id = info.id, label = info.label })
            else
                table.insert(visible, { id = info.id, label = info.label })
            end
        end)
        if GR.SortByLabel then
            GR.SortByLabel(visible)
            GR.SortByLabel(hiddenList)
        end
    end

    local BTN_H = 22
    local BTN_GAP = 2

    local function SetupListBtn(parent, scWidth, entry, isVisible)
        local btn = self._gameListBtnPool:Acquire({})
        btn:SetParent(parent)
        btn:SetHeight(BTN_H)
        btn:SetWidth(scWidth - 4)
        btn:SetBackdropColor(0.08, 0.07, 0.04, 0.85)
        btn:SetBackdropBorderColor(0.40, 0.35, 0.15, 0.8)
        btn._lbl:SetText(entry.label)
        btn._lbl:SetTextColor(isVisible and 0.90 or 0.55,
                             isVisible and 0.85 or 0.55,
                             isVisible and 0.70 or 0.55)
        btn:SetScript("OnEnter", function(self2)
            self2:SetBackdropBorderColor(1.00, 0.82, 0.00, 1)
            self2._lbl:SetTextColor(1, 0.9, 0.4)
        end)
        btn:SetScript("OnLeave", function(self2)
            self2:SetBackdropBorderColor(0.40, 0.35, 0.15, 0.8)
            self2._lbl:SetTextColor(isVisible and 0.90 or 0.55,
                                    isVisible and 0.85 or 0.55,
                                    isVisible and 0.70 or 0.55)
        end)
        btn._lastClick = 0
        btn._entryID   = entry.id
        btn._isVisible = isVisible
        btn:SetScript("OnClick", function(self2)
            local now = GetTime()
            if now - self2._lastClick < 0.4 then
                HubSettings:_ToggleGameVisibility(self2._entryID, self2._isVisible)
            end
            self2._lastClick = now
        end)
        btn:Enable()
        btn:Show()
        return btn
    end

    local scW = self._gamesLeftSC:GetWidth()
    if scW < 10 then scW = SF_W - 4 end

    local yOff = 0
    for _, entry in ipairs(visible) do
        local btn = SetupListBtn(self._gamesLeftSC, scW, entry, true)
        btn:SetPoint("TOPLEFT", self._gamesLeftSC, "TOPLEFT", 0, -yOff)
        table.insert(self._gamesVisibleBtns, btn)
        yOff = yOff + BTN_H + BTN_GAP
    end
    self._gamesLeftSC:SetHeight(math.max(yOff, 1))
    ArcadiaNexus.UI.UpdateScrollbar(self._gamesLeftSF, self._gamesLeftSC)
    C_Timer.After(0.05, function()
        if self._gamesLeftSF then self._gamesLeftSF:SetVerticalScroll(0) end
        if self._gamesLeftSB then pcall(function() self._gamesLeftSB:SetScrollPercentage(0) end) end
    end)

    yOff = 0
    for _, entry in ipairs(hiddenList) do
        local btn = SetupListBtn(self._gamesRightSC, scW, entry, false)
        btn:SetPoint("TOPLEFT", self._gamesRightSC, "TOPLEFT", 0, -yOff)
        table.insert(self._gamesHiddenBtns, btn)
        yOff = yOff + BTN_H + BTN_GAP
    end
    self._gamesRightSC:SetHeight(math.max(yOff, 1))
    ArcadiaNexus.UI.UpdateScrollbar(self._gamesRightSF, self._gamesRightSC)
    C_Timer.After(0.05, function()
        if self._gamesRightSF then self._gamesRightSF:SetVerticalScroll(0) end
        if self._gamesRightSB then pcall(function() self._gamesRightSB:SetScrollPercentage(0) end) end
    end)
end

-- ============================================================
-- TOGGLE GAME VISIBILITY
-- ============================================================

function HubSettings:_ToggleGameVisibility(gameID, currentlyVisible)
    self:_EnsurePendingHiddenGames()
    if currentlyVisible then
        self._pendingHiddenGames[gameID] = true
    else
        self._pendingHiddenGames[gameID] = nil
    end
    self:_RefreshGamesList()
end

-- ============================================================
-- REGISTRY
-- ============================================================

ArcadiaNexus.RegisterHubSettingsTab({
    id            = "GAMES",
    labelKey      = "hubsettings_tab_games",
    labelFallback = "Spiele",
    order         = 20,
    buildContent  = function(parent)
        HubSettings:_BuildTabGames(parent)
    end,
    refreshLayout = function(hs, pw)
        if hs._RefreshGamesList then hs:_RefreshGamesList() end
    end,
    onSelect = function(hs)
        hs._pendingHiddenGames = CopyHiddenGames(
            ArcadiaNexusDB and ArcadiaNexusDB.hiddenGames)
        C_Timer.After(0, function() hs:_RefreshSettingsLayout() end)
    end,
})
