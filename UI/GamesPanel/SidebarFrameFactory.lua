--[[
    NEXUS GAMING HUB
    UI/GamesPanel/SidebarFrameFactory.lua
    Reine UI-Konstruktion: Scrollbar-Update und Panel-Frame-Erstellung.

    Exportiert:
        ArcadiaNexus.UI.UpdateScrollbar(sf, sc)
        ArcadiaNexus.UI.BuildCategoryPanelFrame(parent, frameName, scrollName)
            → cp, sf, sc

    Abhängigkeiten:
        UI/ContentPanel.lua  → CreateNexusScrollbar
]]

local Layout = ArcadiaNexus.Layout

-- ============================================================
-- UpdateScrollbar
-- ============================================================
function ArcadiaNexus.UI.UpdateScrollbar(sf, sc)
    C_Timer.After(0, function()
        if not sf or not sf:IsShown() then return end
        local range   = sf:GetVerticalScrollRange()
        local offset  = sf:GetVerticalScroll()
        if offset > range then sf:SetVerticalScroll(range) end
        local contentH = sc:GetHeight()
        local viewH    = sf:GetHeight()
        if sf.ScrollBar then
            sf.ScrollBar.visibleExtentPercentage = viewH / math.max(contentH, 1)
            if contentH <= viewH then
                sf.ScrollBar:Hide()
                -- Thumb explizit verstecken (MinimalScrollBar rendert ihn separat)
                if sf.ScrollBar.Thumb then sf.ScrollBar.Thumb:Hide() end
                if sf.ScrollBar.Track then sf.ScrollBar.Track:Hide() end
                if sf.ScrollBar.TrackBG then sf.ScrollBar.TrackBG:Hide() end
            else
                sf.ScrollBar:Show()
                if sf.ScrollBar.Thumb then sf.ScrollBar.Thumb:Show() end
                if sf.ScrollBar.Track then sf.ScrollBar.Track:Show() end
                if sf.ScrollBar.TrackBG then sf.ScrollBar.TrackBG:Show() end
            end
        end
    end)
end

-- ============================================================
-- BuildCategoryPanelFrame
-- ============================================================
function ArcadiaNexus.UI.BuildCategoryPanelFrame(parent, frameName, scrollName)
    local Acquire = ArcadiaNexus.UI.AcquireNamedFrame
    local cp, reused = Acquire("Frame", frameName, parent, "BackdropTemplate")
    local sx, sy, sbx, sby = Layout.GetSidebarAnchors()
    cp:SetPoint("TOPLEFT",    parent, "TOPLEFT",    sx, sy)
    cp:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", sbx, sby)
    cp:SetWidth(Layout.sidebar.width)

    if reused then
        local sf = cp._sf or (scrollName and _G[scrollName])
        local sc = cp._sc
        if sf then
            sf:SetParent(cp)
            sf:Show()
        end
        if sc then sc:Show() end
        return cp, sf, sc
    end

    cp:SetBackdrop({
        bgFile   = nil,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileEdge = true, edgeSize = 16,
        insets   = {left=4, right=4, top=4, bottom=4},
    })
    cp:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

    local cpBG = cp:CreateTexture(nil, "BACKGROUND", nil, -1)
    cpBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment")
    cpBG:SetPoint("TOPLEFT",     cp, "TOPLEFT",      5, -5)
    cpBG:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -5,  5)
    cpBG:SetTexCoord(0, 0.5, 0, 1)
    cpBG:SetVertTile(false)

    local sf = Acquire("ScrollFrame", scrollName, cp)
    sf:SetPoint("TOPLEFT",     cp, "TOPLEFT",      5,  -8)
    sf:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -28,  6)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(Layout.sidebar.width - Layout.sidebar.scrollChildWidthOffset)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    CreateNexusScrollbar(sf, cp)

    cp._sf = sf
    cp._sc = sc
    return cp, sf, sc
end
