--[[
    NEXUS GAMING HUB
    UI/GamesPanel/CategoryHeader.lua
    Widget-Konstruktion: Gruppen-Header mit Pfeil, Label, optionalem Favoriten-Icon.

    Exportiert:
        ArcadiaNexus.UI.BuildGroupHeader(sc, grp, arrowKey, hdrKey, frameName)
            → hdr (Button-Frame)
]]

local Layout = ArcadiaNexus.Layout
local CAT_W = Layout.sidebar.width

function ArcadiaNexus.UI.BuildGroupHeader(sc, grp, arrowKey, hdrKey, frameName)
    local hdr, reused = ArcadiaNexus.UI.AcquireNamedFrame("Button", frameName, sc)
    hdr:SetSize(CAT_W - 30, 24)
    grp[hdrKey] = hdr
    if reused then
        grp[arrowKey] = hdr._arrow
        if hdr._lbl then hdr._lbl:SetText(grp.label) end
        return hdr
    end

    local hdrBG = hdr:CreateTexture(nil, "BACKGROUND", nil, 0)
    hdrBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background")
    hdrBG:SetAllPoints(hdr)
    hdrBG:SetTexCoord(0, 0.6640625, 0, 1)
    hdrBG:SetVertexColor(0.70, 0.60, 0.30, 1)

    local hdrHL = hdr:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hdrHL:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
    hdrHL:SetAllPoints(hdr)
    hdrHL:SetTexCoord(0, 0.6640625, 0, 1)
    hdrHL:SetBlendMode("ADD")

    local arrow = hdr:CreateTexture(nil, "OVERLAY", nil, 2)
    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    arrow:SetVertexColor(1.00, 0.82, 0.00, 1)
    hdr._arrow = arrow
    grp[arrowKey] = arrow

    local hdrLbl = hdr:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hdrLbl:SetPoint("LEFT",  hdr, "LEFT",  18, 0)
    hdrLbl:SetPoint("RIGHT", hdr, "RIGHT", grp.isFavGrp and -22 or -4, 0)
    hdrLbl:SetText(grp.label)
    hdrLbl:SetTextColor(1.00, 0.82, 0.00, 1)
    hdrLbl:SetWordWrap(false)
    hdrLbl:SetJustifyH("LEFT")
    hdr._lbl = hdrLbl

    if grp.isFavGrp then
        local favIcon = hdr:CreateTexture(nil, "OVERLAY", nil, 3)
        favIcon:SetAtlas("auctionhouse-icon-favorite", false)
        favIcon:SetSize(12, 12)
        favIcon:SetPoint("RIGHT", hdr, "RIGHT", -12, 2)
    end

    return hdr
end
