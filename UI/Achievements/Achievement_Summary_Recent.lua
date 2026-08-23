--[[
    ArcadiaNexus – Achievement_Summary_Recent
    UI/Achievement_Summary_Recent.lua

    Block 1 der Zusammenfassung: "Neueste Erfolge".
    1:1 Nachbau des Blizzard SummaryAchievementTemplate / ComparisonPlayerTemplate.
    + Hover-Effekt (UI-Character-ReputationBar-Highlight, ADD)
    + Klick navigiert direkt zur Achievement-Kategorie des Spiels

    Blizzard XML-Maße (aus ComparisonPlayerTemplate + SummaryAchievementTemplate):
      Frame:      498x50  (BackdropTemplate, ACHIEVEMENT_RED_BORDER_COLOR a=0.5)
      Background: UI-Achievement-Parchment-Horizontal, inset 3px, TexCoord 0,1,0,0.25
      TitleBar:   UI-Achievement-Borders, H=20, +5,-4/-5,-4, TexCoord 0,0.9765625,0.66015625,0.73828125, a=0.8
      Glow:       UI-Achievement-Borders, TOPLEFT@TitleBar.BOTTOMLEFT 0,+2, TexCoord 0,1,0.00390625,0.25390625
      Label:      GameFontHighlightMedium, 260x20, TOP@TitleBar.TOP
      Date:       GameFontHighlightSmall, TOPRIGHT -63,-8, 100x14
      Desc:       GameFontNormalSmall, TOP 0,-30, 380x13 (Tier + XP)
      Icon:       48x48 TOPLEFT+3,-3; tex 36x36 CENTER 0,+3; frame 46x46 CENTER-1,+2
      Shield:     48x48 TOPRIGHT-10,-4; tex 48x48; points CENTER 0,+3
      Highlight:  UI-Character-ReputationBar-Highlight ADD, Ecken 16x16
    Hover: Highlight:Show() / Hide()
    Klick: entry.gameId → ArcadiaNexus.UI.ActivateAchCategory(gameId)

    API:
        AchSumRecent.Build(parent, yOff, maxEntries) → blockH
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AchSumRecent = {}
local REC = ArcadiaNexus.AchSumRecent

local ROW_H      = 50
local ROW_GAP    = 3
local HDR_H      = 20
local HDR_GAP    = 2
local ROW_INDENT = 18

local function H()  return ArcadiaNexus.AchUI_H end
local function SH() return ArcadiaNexus.AchSumH end

-- ============================================================
-- Hover-Overlay: UI-Character-ReputationBar-Highlight (ADD)
-- ============================================================
local function BuildHighlight(parent)
    local hl = CreateFrame("Frame", nil, parent)
    hl:SetAllPoints(parent)
    hl:Hide()

    local tex = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar-Highlight"

    local tTL = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tTL:SetTexture(tex); tTL:SetBlendMode("ADD")
    tTL:SetSize(16, 16); tTL:SetPoint("TOPLEFT", hl, "TOPLEFT", -1, 2)
    tTL:SetTexCoord(0.06640625, 0, 0.4375, 0.65625)

    local tBL = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tBL:SetTexture(tex); tBL:SetBlendMode("ADD")
    tBL:SetSize(16, 16); tBL:SetPoint("BOTTOMLEFT", hl, "BOTTOMLEFT", -1, -2)
    tBL:SetTexCoord(0.06640625, 0, 0.65625, 0.4375)

    local tTR = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tTR:SetTexture(tex); tTR:SetBlendMode("ADD")
    tTR:SetSize(16, 16); tTR:SetPoint("TOPRIGHT", hl, "TOPRIGHT", 1, 2)
    tTR:SetTexCoord(0, 0.06640625, 0.4375, 0.65625)

    local tBR = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tBR:SetTexture(tex); tBR:SetBlendMode("ADD")
    tBR:SetSize(16, 16); tBR:SetPoint("BOTTOMRIGHT", hl, "BOTTOMRIGHT", 1, -2)
    tBR:SetTexCoord(0, 0.06640625, 0.65625, 0.4375)

    local tTop = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tTop:SetTexture(tex); tTop:SetBlendMode("ADD")
    tTop:SetPoint("TOPLEFT",     tTL, "TOPRIGHT",  0, 0)
    tTop:SetPoint("BOTTOMRIGHT", tTR, "BOTTOMLEFT", 0, 0)
    tTop:SetTexCoord(0, 0.015, 0.4375, 0.65625)

    local tBot = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tBot:SetTexture(tex); tBot:SetBlendMode("ADD")
    tBot:SetPoint("TOPLEFT",     tBL, "TOPRIGHT",  0, 0)
    tBot:SetPoint("BOTTOMRIGHT", tBR, "BOTTOMLEFT", 0, 0)
    tBot:SetTexCoord(0, 0.015, 0.65625, 0.4375)

    local tL = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tL:SetTexture(tex); tL:SetBlendMode("ADD")
    tL:SetPoint("TOPLEFT",     tTL, "BOTTOMLEFT", 0, 0)
    tL:SetPoint("BOTTOMRIGHT", tBL, "TOPRIGHT",   0, 0)
    tL:SetTexCoord(0.06640625, 0, 0.65625, 0.6)

    local tR = hl:CreateTexture(nil, "OVERLAY", nil, 2)
    tR:SetTexture(tex); tR:SetBlendMode("ADD")
    tR:SetPoint("TOPLEFT",     tTR, "BOTTOMLEFT", 0, 0)
    tR:SetPoint("BOTTOMRIGHT", tBR, "TOPRIGHT",   0, 0)
    tR:SetTexCoord(0, 0.06640625, 0.65625, 0.6)

    return hl
end

local _recentRowPool = nil
local _recentHdr     = nil
local _emptyHint     = nil

local function EnsureRecentHeader(parent, W, yOff, labelText)
    if not _recentHdr then
        local hdr = CreateFrame("Frame", nil, parent)
        hdr._bg = hdr:CreateTexture(nil, "BACKGROUND", nil, 0)
        hdr._bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-RecentHeader")
        hdr._bg:SetTexCoord(0, 1, 0, 0.71875)
        hdr._lbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr._lbl:SetPoint("CENTER", hdr, "CENTER", 0, 0)
        _recentHdr = hdr
    end
    local hdr = _recentHdr
    hdr:SetParent(parent)
    hdr:SetSize(W, HDR_H)
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOff)
    hdr._bg:ClearAllPoints()
    hdr._bg:SetPoint("TOPLEFT",     hdr, "TOPLEFT",     -20, 0)
    hdr._bg:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT",  20, 0)
    hdr._lbl:SetText(labelText)
    hdr:Show()
    return hdr
end

local function EnsureEmptyHint(parent, yPos, text)
    if not _emptyHint then
        _emptyHint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    _emptyHint:SetParent(parent)
    _emptyHint:ClearAllPoints()
    _emptyHint:SetPoint("TOP", parent, "TOP", 0, -yPos)
    _emptyHint:SetText(text)
    _emptyHint:Show()
end

local function GetRecentRowPool()
    if not _recentRowPool then
        local poolParentRef = nil
        _recentRowPool = ArcadiaNexus.UI.FramePool.New({
            name = "Achievement.SummaryRecent",
            create = function(poolParent)
                poolParentRef = poolParent
                local row = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
                row:SetBackdrop({
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 },
                })
                row:SetBackdropBorderColor(0.7, 0.15, 0.05, 0.5)

                row._bg = row:CreateTexture(nil, "BACKGROUND", nil, 0)
                row._bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
                row._bg:SetPoint("TOPLEFT",     row, "TOPLEFT",      3, -3)
                row._bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3,  3)
                row._bg:SetTexCoord(0, 1, 0, 0.25)

                row._titleBar = row:CreateTexture(nil, "ARTWORK", nil, 0)
                row._titleBar:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Borders")
                row._titleBar:SetHeight(20)
                row._titleBar:SetPoint("TOPLEFT",  row, "TOPLEFT",  5, -4)
                row._titleBar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -4)
                row._titleBar:SetTexCoord(0, 0.9765625, 0.66015625, 0.73828125)
                row._titleBar:SetAlpha(0.8)

                row._glow = row:CreateTexture(nil, "ARTWORK", nil, -1)
                row._glow:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Borders")
                row._glow:SetPoint("TOPLEFT",  row._titleBar, "BOTTOMLEFT",  0, 2)
                row._glow:SetPoint("TOPRIGHT", row._titleBar, "BOTTOMRIGHT", 0, 2)
                row._glow:SetTexCoord(0, 1, 0.00390625, 0.25390625)
                row._glow:SetVertexColor(0.22, 0.17, 0.13)

                local iconHolder = CreateFrame("Frame", nil, row)
                iconHolder:SetSize(48, 48)
                iconHolder:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)

                row._iconTex = iconHolder:CreateTexture(nil, "ARTWORK", nil, 0)
                row._iconTex:SetSize(36, 36)
                row._iconTex:SetPoint("CENTER", iconHolder, "CENTER", 0, 3)

                local iconFrame = iconHolder:CreateTexture(nil, "OVERLAY", nil, 1)
                iconFrame:SetSize(46, 46)
                iconFrame:SetPoint("CENTER", iconHolder, "CENTER", -1, 2)
                iconFrame:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
                iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625)

                row._label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
                row._label:SetHeight(20)
                row._label:SetPoint("TOP", row._titleBar, "TOP", 0, 0)
                row._label:SetJustifyH("LEFT")
                row._label:SetWordWrap(false)

                row._dateLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row._dateLbl:SetSize(100, 14)
                row._dateLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -63, -8)
                row._dateLbl:SetJustifyH("RIGHT")
                row._dateLbl:SetTextColor(1.00, 0.82, 0.00)

                row._desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row._desc:SetHeight(13)
                row._desc:SetPoint("TOP", row, "TOP", 0, -30)
                row._desc:SetJustifyH("LEFT")

                local shieldHolder = CreateFrame("Frame", nil, row)
                shieldHolder:SetSize(48, 48)
                shieldHolder:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -4)

                row._shieldIcon = shieldHolder:CreateTexture(nil, "BACKGROUND", nil, 0)
                row._shieldIcon:SetSize(48, 48)
                row._shieldIcon:SetPoint("TOPRIGHT", shieldHolder, "TOPRIGHT", 0, 0)
                row._shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
                row._shieldIcon:SetTexCoord(0, 0.5, 0, 0.5)

                row._shieldPts = shieldHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row._shieldPts:SetSize(40, 26)
                row._shieldPts:SetPoint("CENTER", shieldHolder, "CENTER", 0, 3)
                row._shieldPts:SetJustifyH("CENTER")

                row._check = row:CreateTexture(nil, "OVERLAY", nil, 2)
                row._check:SetSize(14, 14)
                row._check:SetPoint("TOPRIGHT", row, "TOPRIGHT", -48, -9)
                row._check:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Criteria-Check")
                row._check:SetTexCoord(0, 0.625, 0, 1)

                row._hl = BuildHighlight(row)
                return row
            end,
            onRelease = function(row)
                row:Hide()
                row:ClearAllPoints()
                row:SetScript("OnClick", nil)
                row:SetScript("OnEnter", nil)
                row:SetScript("OnLeave", nil)
                if row._hl then row._hl:Hide() end
                if poolParentRef then row:SetParent(poolParentRef) end
            end,
        })
    end
    return _recentRowPool
end

function REC.ReleaseAll()
    if _recentRowPool then _recentRowPool:ReleaseAll() end
    if _recentHdr then _recentHdr:Hide() end
    if _emptyHint then _emptyHint:Hide() end
end

-- ============================================================
-- Einzelne Achievement-Zeile
-- ============================================================
local function ConfigureRecentRow(row, entry, parent, yOff, rowW)
    local TC = (H() and H().TIER_COLOR) or {
        Bronze = { 0.80, 0.50, 0.20 },
        Silber = { 0.78, 0.78, 0.82 },
        Silver = { 0.78, 0.78, 0.82 },
        Gold   = { 1.00, 0.82, 0.00 },
    }

    row:SetParent(parent)
    row:SetSize(rowW, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_INDENT, -yOff)
    row._glow:SetHeight(34)
    row._label:SetWidth(rowW - 160)
    row._desc:SetWidth(rowW - 120)

    H().ApplyAchievementIcon(row._iconTex, entry.groupIcon)
    row._label:SetText(entry.groupTitle)

    if entry.timestamp and entry.timestamp > 0 then
        local d = date("*t", entry.timestamp)
        row._dateLbl:SetText(string.format("%02d.%02d.%02d", d.day, d.month, d.year % 100))
        row._dateLbl:Show()
    else
        row._dateLbl:Hide()
    end

    local tc = TC[entry.tierName] or { 0.70, 0.70, 0.70 }
    local tierColor = string.format("|cff%02x%02x%02x",
        math.floor(tc[1] * 255), math.floor(tc[2] * 255), math.floor(tc[3] * 255))
    row._desc:SetText(H().TierIconMarkup(entry.tierName, 14) .. " " ..
        tierColor .. entry.tierName .. "|r  |cff00cc55+" .. entry.tierXP .. " XP|r")
    row._shieldPts:SetText(tostring(entry.tierXP))

    row:SetScript("OnEnter", function() row._hl:Show() end)
    row:SetScript("OnLeave", function() row._hl:Hide() end)

    local targetId = entry.gameId
    if targetId then
        row:SetScript("OnClick", function()
            local activate = ArcadiaNexus.UI and ArcadiaNexus.UI.ActivateAchCategory
            if activate then activate(targetId) end
        end)
    else
        row:SetScript("OnClick", nil)
    end

    row:Show()
end

local function BuildRecentRow(parent, entry, yOff, fullW)
    local rowW = fullW - (ROW_INDENT * 2)
    local row = GetRecentRowPool():Acquire({})
    ConfigureRecentRow(row, entry, parent, yOff, rowW)
    return row
end

-- ============================================================
-- Block bauen
-- ============================================================
function REC.Build(parent, yOff, maxEntries)
    REC.ReleaseAll()

    local SHm = SH()
    if not SHm then return 0 end

    local L       = ArcadiaNexus.GetLocaleTable("UI")
    local entries = SHm.GetRecentUnlocks(maxEntries or 4)
    local W       = parent:GetWidth() or 488
    local blockH  = 0

    -- Header
    EnsureRecentHeader(parent, W, yOff, L["summary_recent"] or "Neueste Erfolge")

    blockH = blockH + HDR_H + HDR_GAP

    if #entries == 0 then
        EnsureEmptyHint(parent, yOff + blockH + 30, L["summary_no_recent"] or "Noch keine Erfolge freigeschaltet.")
        blockH = blockH + 60
        return blockH
    end

    if _emptyHint then _emptyHint:Hide() end

    for _, entry in ipairs(entries) do
        BuildRecentRow(parent, entry, yOff + blockH, W)
        blockH = blockH + ROW_H + ROW_GAP
    end

    return blockH
end
