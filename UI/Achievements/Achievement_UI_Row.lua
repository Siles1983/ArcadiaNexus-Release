--[[
    ArcadiaNexus – Achievement_UI_Row
    UI/Achievement_UI_Row.lua

    Baut eine einzelne Achievement-Gruppen-Zeile inkl. Klapp-Logik.
    Abhängig von: Achievement_UI_Helpers.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.AUI_Row = {}
local R = ArcadiaNexus.AUI_Row

local _rowPool = nil

local function BuildHoverHighlight(row)
    local hlTex = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar-Highlight"
    local hl = CreateFrame("Frame", nil, row)
    hl:SetAllPoints(row)
    hl:Hide()

    local function MakeHLTex(l, r, t, b, pt, ox, oy)
        local tx = hl:CreateTexture(nil, "OVERLAY", nil, 2)
        tx:SetTexture(hlTex); tx:SetBlendMode("ADD")
        tx:SetSize(16, 16); tx:SetPoint(pt, hl, pt, ox, oy)
        tx:SetTexCoord(l, r, t, b)
    end

    MakeHLTex(0.06640625, 0,          0.4375,  0.65625, "TOPLEFT",     -1,  2)
    MakeHLTex(0.06640625, 0,          0.65625, 0.4375,  "BOTTOMLEFT",  -1, -2)
    MakeHLTex(0,          0.06640625, 0.4375,  0.65625, "TOPRIGHT",     1,  2)
    MakeHLTex(0,          0.06640625, 0.65625, 0.4375,  "BOTTOMRIGHT",  1, -2)

    local tTL = hl:CreateTexture(nil, "OVERLAY", nil, 2); tTL:SetTexture(hlTex); tTL:SetBlendMode("ADD"); tTL:SetSize(16, 16); tTL:SetPoint("TOPLEFT", hl, "TOPLEFT", -1, 2)
    local tTR = hl:CreateTexture(nil, "OVERLAY", nil, 2); tTR:SetTexture(hlTex); tTR:SetBlendMode("ADD"); tTR:SetSize(16, 16); tTR:SetPoint("TOPRIGHT", hl, "TOPRIGHT", 1, 2)
    local tBL = hl:CreateTexture(nil, "OVERLAY", nil, 2); tBL:SetTexture(hlTex); tBL:SetBlendMode("ADD"); tBL:SetSize(16, 16); tBL:SetPoint("BOTTOMLEFT", hl, "BOTTOMLEFT", -1, -2)
    local tBR = hl:CreateTexture(nil, "OVERLAY", nil, 2); tBR:SetTexture(hlTex); tBR:SetBlendMode("ADD"); tBR:SetSize(16, 16); tBR:SetPoint("BOTTOMRIGHT", hl, "BOTTOMRIGHT", 1, -2)
    tTL:SetTexCoord(0.06640625, 0, 0.4375, 0.65625)
    tTR:SetTexCoord(0, 0.06640625, 0.4375, 0.65625)
    tBL:SetTexCoord(0.06640625, 0, 0.65625, 0.4375)
    tBR:SetTexCoord(0, 0.06640625, 0.65625, 0.4375)

    local tTop = hl:CreateTexture(nil, "OVERLAY", nil, 2); tTop:SetTexture(hlTex); tTop:SetBlendMode("ADD")
    tTop:SetPoint("TOPLEFT", tTL, "TOPRIGHT", 0, 0); tTop:SetPoint("BOTTOMRIGHT", tTR, "BOTTOMLEFT", 0, 0)
    tTop:SetTexCoord(0, 0.015, 0.4375, 0.65625)

    local tBot = hl:CreateTexture(nil, "OVERLAY", nil, 2); tBot:SetTexture(hlTex); tBot:SetBlendMode("ADD")
    tBot:SetPoint("TOPLEFT", tBL, "TOPRIGHT", 0, 0); tBot:SetPoint("BOTTOMRIGHT", tBR, "BOTTOMLEFT", 0, 0)
    tBot:SetTexCoord(0, 0.015, 0.65625, 0.4375)

    local tLft = hl:CreateTexture(nil, "OVERLAY", nil, 2); tLft:SetTexture(hlTex); tLft:SetBlendMode("ADD")
    tLft:SetPoint("TOPLEFT", tTL, "BOTTOMLEFT", 0, 0); tLft:SetPoint("BOTTOMRIGHT", tBL, "TOPRIGHT", 0, 0)
    tLft:SetTexCoord(0.06640625, 0, 0.65625, 0.6)

    local tRgt = hl:CreateTexture(nil, "OVERLAY", nil, 2); tRgt:SetTexture(hlTex); tRgt:SetBlendMode("ADD")
    tRgt:SetPoint("TOPLEFT", tTR, "BOTTOMLEFT", 0, 0); tRgt:SetPoint("BOTTOMRIGHT", tBR, "TOPRIGHT", 0, 0)
    tRgt:SetTexCoord(0, 0.06640625, 0.65625, 0.6)

    return hl
end

local function EnsureSkeleton(row, textX, textW)
    if row._achSkeleton then return end
    row._achSkeleton = true

    local H = ArcadiaNexus.AchUI_H
    local ICON_BORDER_SZ = 72

    local iconHolder = CreateFrame("Frame", nil, row)
    iconHolder:SetSize(H.ICON_FRAME_SZ, H.ICON_FRAME_SZ)
    iconHolder:SetPoint("TOPLEFT", row, "TOPLEFT", H.PAD, -6)

    local iconTex = iconHolder:CreateTexture(nil, "ARTWORK", nil, 0)
    iconTex:SetSize(H.ICON_FRAME_SZ - 8, H.ICON_FRAME_SZ - 8)
    iconTex:SetPoint("CENTER", iconHolder, "CENTER", 0, 0)

    local iconBorder = iconHolder:CreateTexture(nil, "OVERLAY", nil, 1)
    iconBorder:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    iconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
    iconBorder:SetSize(ICON_BORDER_SZ, ICON_BORDER_SZ)
    iconBorder:SetPoint("CENTER", iconHolder, "CENTER", -1, 2)

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -8)
    title:SetWidth(math.max(textW, 10))
    title:SetWordWrap(false)
    title:SetJustifyH("CENTER")

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -30)
    desc:SetWidth(math.max(textW, 10))
    desc:SetWordWrap(true)
    desc:SetJustifyH("CENTER")
    desc:SetTextColor(0.68, 0.62, 0.50)

    local sep = row:CreateTexture(nil, "OVERLAY", nil, 7)
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(0.35, 0.28, 0.15, 0.45)
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  1, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 0)
    sep:SetHeight(1)

    local pmTex = row:CreateTexture(nil, "OVERLAY", nil, 3)
    pmTex:SetSize(15, 15)
    pmTex:SetPoint("TOPLEFT", row, "TOPLEFT", textX - 10, -10)
    pmTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-PlusMinus")

    local tierContainer = CreateFrame("Frame", nil, row)
    tierContainer:Hide()

    row._achIconTex       = iconTex
    row._achTitle         = title
    row._achDesc          = desc
    row._achPmTex         = pmTex
    row._achTierContainer = tierContainer
    row._achHl            = BuildHoverHighlight(row)
end

local function GetRowPool()
    if not _rowPool then
        local poolParentRef = nil
        _rowPool = ArcadiaNexus.UI.FramePool.New({
            name = "Achievement.Rows",
            create = function(poolParent)
                poolParentRef = poolParent
                local row = CreateFrame("Frame", nil, poolParent)
                row:SetClipsChildren(true)
                return row
            end,
            onRelease = function(row)
                if row._achCollapse then row._achCollapse() end
                row:Hide()
                row:ClearAllPoints()
                row:SetScript("OnMouseDown", nil)
                row:SetScript("OnEnter", nil)
                row:SetScript("OnLeave", nil)
                row._achIsExpanded = false
                row._achTierBuilt  = false
                if row._achTierContainer then
                    ArcadiaNexus.AchUI_H.ResetExpandedTiers(row._achTierContainer)
                    row._achTierContainer:Hide()
                end
                if row._achHl then row._achHl:Hide() end
                if poolParentRef then row:SetParent(poolParentRef) end
            end,
        })
    end
    return _rowPool
end

function R.ReleaseAll()
    if _rowPool then _rowPool:ReleaseAll() end
end

function R.Make(group, parentFrame, W, yOff, onHeightChanged)
    local H        = ArcadiaNexus.AchUI_H
    local unlocked = (ArcadiaNexusDB.achievements and ArcadiaNexusDB.achievements.unlocked) or {}
    local progress = (ArcadiaNexusDB.achievements and ArcadiaNexusDB.achievements.progress) or {}
    local tiers    = group.tiers or {}

    local highestIdx = 0
    for i, tier in ipairs(tiers) do
        if unlocked[tier.id] then highestIdx = i end
    end

    local anyUnlocked = (highestIdx > 0)
    local allUnlocked = (highestIdx == #tiers)

    local collapsedH = H.ROW_H
    local expandedH  = H.ROW_H + H.TIER_PADDING + #tiers * H.TIER_ROW_H + H.TIER_PADDING
    local textX      = H.PAD + H.ICON_FRAME_SZ + 12
    local textW      = W - textX - H.SHIELD_SPACE

    local row = GetRowPool():Acquire({})
    row:SetParent(parentFrame)
    row:SetSize(W, collapsedH)
    row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, yOff)
    row._achCollapsedH = collapsedH
    row._achExpandedH  = expandedH
    row._achGroup      = group
    row._achOnHeightChanged = onHeightChanged
    row._achIsExpanded = false
    row._achTierBuilt  = false

    EnsureSkeleton(row, textX, textW)

    H.SetParchment(row, anyUnlocked, allUnlocked)
    H.BuildTitleBar(row, textX, textW, anyUnlocked, allUnlocked)

    local titleColorCollapsed = anyUnlocked and { 1.00, 1.00, 1.00 }
        or { 0.55, 0.52, 0.45 }
    local descColorCollapsed  = anyUnlocked and { 1.00, 1.00, 1.00 }
        or { 0.68, 0.62, 0.50 }

    local titleStr = H.loc(group.title_de, group.title_en) or "???"
    row._achTitle:SetText(titleStr)
    row._achTitle:SetTextColor(titleColorCollapsed[1], titleColorCollapsed[2], titleColorCollapsed[3])

    row._achDesc:SetText(H.loc(group.desc_de, group.desc_en) or "")
    row._achDesc:SetTextColor(descColorCollapsed[1], descColorCollapsed[2], descColorCollapsed[3])
    H.ApplyAchievementIcon(row._achIconTex, group.icon)
    if not anyUnlocked then
        row._achIconTex:SetDesaturated(true)
        row._achIconTex:SetAlpha(0.40)
    else
        row._achIconTex:SetDesaturated(false)
        row._achIconTex:SetAlpha(1)
    end

    local nextTierIdx = highestIdx + 1
    if nextTierIdx <= #tiers then
        local nextTier = tiers[nextTierIdx]
        local prog     = progress[group.id]
        local current  = (prog and prog.current) or 0
        H.BuildProgressBar(row, textX, textW, nextTier, current)
    else
        H.BuildProgressBar(row, textX, textW, nil, 0)
    end

    local dateStr = ""
    if allUnlocked then
        local lastTier = tiers[highestIdx]
        local ts = lastTier and unlocked[lastTier.id]
        if ts and ts > 0 then
            local d = date("*t", ts)
            dateStr = string.format("%02d.%02d.%02d", d.day, d.month, d.year % 100)
        end
    end

    local shieldTierIdx = allUnlocked and #tiers or (highestIdx > 0 and highestIdx or 1)
    local shieldTier    = tiers[shieldTierIdx]
    if shieldTier then
        H.BuildShield(row, shieldTier, allUnlocked, anyUnlocked and not allUnlocked, dateStr)
    elseif row._achShieldFrame then
        row._achShieldFrame:Hide()
    end

    row._achTierContainer:ClearAllPoints()
    row._achTierContainer:SetPoint("TOPLEFT",  row, "TOPLEFT",  0, -collapsedH)
    row._achTierContainer:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -collapsedH)
    row._achTierContainer:SetHeight(expandedH - collapsedH)

    local function SetPM(expanded)
        local lx = anyUnlocked and 0 or 0.5
        local rx = anyUnlocked and 0.5 or 1
        if expanded then
            row._achPmTex:SetTexCoord(lx, rx, 0.25, 0.50)
        else
            row._achPmTex:SetTexCoord(lx, rx, 0, 0.25)
        end
    end

    local function Expand()
        if row._achIsExpanded then return end
        row._achIsExpanded = true
        SetPM(true)
        row._achTitle:SetTextColor(titleColorCollapsed[1], titleColorCollapsed[2], titleColorCollapsed[3])
        row._achDesc:SetTextColor(descColorCollapsed[1], descColorCollapsed[2], descColorCollapsed[3])
        row:SetHeight(expandedH)
        row._achTierContainer:Show()
        if not row._achTierBuilt then
            H.BuildExpandedTiers(row._achTierContainer, group, textX, unlocked, progress)
            row._achTierBuilt = true
        end
        if onHeightChanged then onHeightChanged(expandedH - collapsedH) end
    end

    local function Collapse()
        if not row._achIsExpanded then return end
        row._achIsExpanded = false
        SetPM(false)
        row._achTitle:SetTextColor(titleColorCollapsed[1], titleColorCollapsed[2], titleColorCollapsed[3])
        row._achDesc:SetTextColor(descColorCollapsed[1], descColorCollapsed[2], descColorCollapsed[3])
        row:SetHeight(collapsedH)
        row._achTierContainer:Hide()
        if onHeightChanged then onHeightChanged(collapsedH - expandedH) end
    end

    row._achExpand   = Expand
    row._achCollapse = Collapse
    SetPM(false)

    row:EnableMouse(true)
    row:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            if row._achIsExpanded then Collapse() else Expand() end
        end
    end)

    row:SetScript("OnEnter", function(self)
        row._achHl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(H.loc(group.title_de, group.title_en), 1, 0.82, 0)
        for _, tier in ipairs(tiers) do
            local isUL = unlocked[tier.id] ~= nil
            local tc   = H.TIER_COLOR[tier.tierName] or { 0.7, 0.7, 0.7 }
            local pre  = H.TierIconMarkup(tier.tierName, 14) .. " "
            GameTooltip:AddLine(
                pre .. tier.tierName .. " – " .. (H.loc(tier.desc_de, tier.desc_en) or ""),
                tc[1], tc[2], tc[3], true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        row._achHl:Hide()
        GameTooltip:Hide()
    end)

    row:Show()
    return row
end
