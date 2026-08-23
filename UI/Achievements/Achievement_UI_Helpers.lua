--[[
    ArcadiaNexus – Achievement_UI_Helpers
    UI/Achievement_UI_Helpers.lua

    Wiederverwendbare Render-Bausteine für das Achievement-Panel.
    Kein State, keine Abhängigkeit zu _sc/_sf/_panel.

    API (auf ArcadiaNexus.AchUI_H):
        H.TIER_COLOR          – Farb-Tabelle Bronze/Silber/Gold
        H.TIER_ICON           – Blizzard-Münztexturen pro Tier
        H.TierIconMarkup(name, size)
        H.ROW_H               – Standard-Zeilenhöhe (collapsed)
        H.ROW_H_EXPANDED      – Zeilenhöhe aufgeklappt (Basis + Tiers)
        H.PAD
        H.ICON_FRAME_SZ
        H.SHIELD_SPACE
        H.loc(de, en)
        H.ApplyAchievementIcon(texture, icon)
        H.SetParchment(row, anyUnlocked, allUnlocked)
        H.BuildShield(row, tier, isUnlocked, isPartial)
        H.BuildTitleBar(row, group, textX, textW, anyUnlocked, allUnlocked)
        H.BuildProgressBar(row, group, textX, textW, progress)
        H.BuildExpandedTiers(row, group, textX, textW, unlocked, progress)
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.AchUI_H = {}
local H = ArcadiaNexus.AchUI_H

-- ============================================================
-- Konstanten (einmal definiert, überall referenzierbar)
-- ============================================================
H.TIER_COLOR = {
    Bronze = { 0.80, 0.50, 0.20 },
    Silber = { 0.78, 0.78, 0.82 },
    Silver = { 0.78, 0.78, 0.82 },
    Gold   = { 1.00, 0.82, 0.00 },
}

H.TIER_ICON = {
    Bronze = "Interface\\MoneyFrame\\UI-CopperIcon",
    Silber = "Interface\\MoneyFrame\\UI-SilverIcon",
    Silver = "Interface\\MoneyFrame\\UI-SilverIcon",
    Gold   = "Interface\\MoneyFrame\\UI-GoldIcon",
}

function H.TierIconMarkup(tierName, size)
    local path = H.TIER_ICON[tierName]
    if not path then return "" end
    local iconSize = size or 14
    return string.format("|T%s:%d:%d|t", path, iconSize, iconSize)
end

H.ROW_H          = 84   -- Blizzard ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT
H.PAD            = 8
H.ICON_FRAME_SZ  = 60
H.SHIELD_SPACE   = 76    -- Platz für Shield rechts (inkl. Puffer)
H.PROGRESS_H     = 8
H.TIER_ROW_H     = 22    -- Höhe einer aufgeklappten Tier-Zeile
H.TIER_PADDING   = 28   -- Abstand von Container-Top: überbrückt ProgressBar (20px+8px Höhe)

-- ============================================================
-- Lokalisierung
-- ============================================================
function H.loc(de, en)
    return (ArcadiaNexus.ActiveLocale == "deDE") and de or en
end

function H.ApplyAchievementIcon(texture, icon)
    local AI = ArcadiaNexus.AchievementIcons
    if AI and AI.ApplyToTexture then
        AI:ApplyToTexture(texture, icon)
        return
    end
    if not texture or not texture.SetTexture then return end
    local path = type(icon) == "string" and icon:gsub("\\", "/") or nil
    local ok = texture:SetTexture(path or 134400)
    if (ok == nil or ok == false) and not texture:GetTexture() then
        texture:SetTexture(134400)
    end
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    texture:Show()
end

-- ============================================================
-- Blizzard-Farben: completed=rot(0.7,0.15,0.05), gesperrt=grau(0.5,0.5,0.5)
-- ============================================================
function H.SetParchment(row, anyUnlocked, allUnlocked)
    if not row._achBg then
        row._achBg = row:CreateTexture(nil, "BACKGROUND", nil, 0)
        row._achBg:SetAllPoints(row)
        row._achGlow = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row._achGlow:SetAllPoints(row)
        row._achGlow:SetBlendMode("ADD")
        row._achBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
        row._achBorder:SetAllPoints(row)
        row._achBorder:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        row._achBorder:SetBackdropColor(0, 0, 0, 0)
        row._achBorder:SetFrameLevel(row:GetFrameLevel() + 2)
    end

    if anyUnlocked then
        row._achBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
        row._achBg:SetAlpha(allUnlocked and 0.9 or 0.55)
    else
        row._achBg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated")
        row._achBg:SetAlpha(0.5)
    end
    row._achBg:Show()

    if allUnlocked then
        row._achGlow:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Highlight")
        row._achGlow:SetAlpha(0.25)
        row._achGlow:Show()
    else
        row._achGlow:Hide()
    end

    if anyUnlocked then
        row._achBorder:SetBackdropBorderColor(0.7, 0.15, 0.05, 0.9)
    else
        row._achBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.6)
    end
    row._achBorder:Show()
end

-- ============================================================
-- TitleBar-Hintergrund (goldener Balken hinter dem Titel)
-- Blizzard: UI-Achievement-Borders, TexCoords 0,1, 0.66015625,0.73828125
-- ============================================================
function H.BuildTitleBar(row, textX, textW, anyUnlocked, allUnlocked)
    local titleBarH = 20
    if not row._achTitleBar then
        row._achTitleBar = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row._achTitleBar:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Borders")
        row._achTitleBar:SetTexCoord(0, 0.9765625, 0.66015625, 0.73828125)
        row._achTitleBar:SetPoint("TOPLEFT",  row, "TOPLEFT",  2,               -4)
        row._achTitleBar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(H.SHIELD_SPACE - 4), -4)
        row._achTitleBar:SetHeight(titleBarH)
    end
    local bar = row._achTitleBar
    if allUnlocked then
        bar:SetAlpha(0.85)
        bar:SetDesaturated(false)
    elseif anyUnlocked then
        bar:SetAlpha(0.55)
        bar:SetDesaturated(false)
    else
        bar:SetAlpha(0.30)
        bar:SetDesaturated(true)
    end
    bar:Show()
end

-- ============================================================
-- Shield rechts
-- Blizzard-XML: Shield Button TOPRIGHT x=-6 y=0, Size 64x64
-- Icon-Texture TOPRIGHT x=0 y=-6 auf Shield, TexCoords completed=(0,0.5,0,0.5)
-- DateCompleted: TOP relativePoint=BOTTOM x=-2 y=6 auf Shield, Size 100x14, CENTER
-- Gibt shieldFrame zurück (für externen Datum-Anchor falls nötig)
-- ============================================================
function H.BuildShield(row, tier, isUnlocked, isPartial, dateStr)
    local SHIELD_W = 64
    local SHIELD_H = 64

    if not row._achShieldFrame then
        local shieldFrame = CreateFrame("Frame", nil, row)
        shieldFrame:SetSize(SHIELD_W, SHIELD_H)
        shieldFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, 0)

        local shieldTex = shieldFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
        shieldTex:SetSize(66, SHIELD_H)
        shieldTex:SetPoint("TOPRIGHT", shieldFrame, "TOPRIGHT", 0, -6)
        shieldTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")

        local pts = shieldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pts:SetSize(42, 16)
        pts:SetPoint("TOPRIGHT", shieldFrame, "TOPRIGHT", -13, -26)
        pts:SetJustifyH("CENTER")

        local dateLbl = shieldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dateLbl:SetSize(100, 14)
        dateLbl:SetPoint("TOP", shieldFrame, "BOTTOM", -2, 6)
        dateLbl:SetJustifyH("CENTER")
        dateLbl:SetTextColor(1.00, 0.82, 0.00)

        row._achShieldFrame = shieldFrame
        row._achShieldTex   = shieldTex
        row._achShieldPts   = pts
        row._achShieldDate  = dateLbl
    end

    local shieldFrame = row._achShieldFrame
    local shieldTex   = row._achShieldTex
    local pts         = row._achShieldPts
    local dateLbl     = row._achShieldDate

    if isUnlocked or isPartial then
        shieldTex:SetTexCoord(0, 0.5, 0, 0.5)
        shieldTex:SetDesaturated(false)
        shieldTex:SetAlpha(1)
    else
        shieldTex:SetTexCoord(0.5, 1, 0, 0.5)
        shieldTex:SetDesaturated(true)
        shieldTex:SetAlpha(0.6)
    end

    pts:SetText(tostring(tier.xp or 0))
    pts:SetTextColor(
        (isUnlocked or isPartial) and 1.0 or 0.5,
        (isUnlocked or isPartial) and 1.0 or 0.5,
        (isUnlocked or isPartial) and 1.0 or 0.5
    )

    if dateStr and dateStr ~= "" then
        dateLbl:SetText(dateStr)
    else
        dateLbl:SetText("")
    end
    shieldFrame:Show()

    return shieldFrame
end

-- ============================================================
-- ProgressBar (zentriert unter Titel+Desc, links ausgerichtet)
-- ============================================================
function H.BuildProgressBar(row, textX, textW, nextTier, current)
    if not nextTier then
        if row._achProgressFrame then row._achProgressFrame:Hide() end
        return
    end

    local tc      = H.TIER_COLOR[nextTier.tierName] or { 0.7, 0.7, 0.7 }
    local target  = nextTier.target or 1
    local pct     = math.min(1.0, current / math.max(target, 1))
    local BAR_W   = math.min(math.floor(textW * 0.6), 200)

    if not row._achProgressFrame then
        local container = CreateFrame("Frame", nil, row)
        local barBg = container:CreateTexture(nil, "ARTWORK", nil, 1)
        barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        local barFill = container:CreateTexture(nil, "ARTWORK", nil, 2)
        barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local barBorder = CreateFrame("Frame", nil, container, "BackdropTemplate")
        barBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        local progLbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        progLbl:SetTextColor(0.68, 0.62, 0.50)

        row._achProgressFrame  = container
        row._achProgressBg     = barBg
        row._achProgressFill   = barFill
        row._achProgressBorder = barBorder
        row._achProgressLbl    = progLbl
    end

    local container = row._achProgressFrame
    container:SetSize(BAR_W + 100, H.PROGRESS_H + 4)
    container:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", textX, 20)

    row._achProgressBg:SetSize(BAR_W, H.PROGRESS_H)
    row._achProgressBg:SetPoint("LEFT", container, "LEFT", 0, 0)
    row._achProgressBg:SetVertexColor(0.12, 0.10, 0.06, 0.80)

    if pct > 0 then
        row._achProgressFill:SetSize(math.max(2, BAR_W * pct), H.PROGRESS_H)
        row._achProgressFill:SetPoint("LEFT", row._achProgressBg, "LEFT", 0, 0)
        row._achProgressFill:SetVertexColor(tc[1] * 0.85, tc[2] * 0.85, tc[3] * 0.85, 0.95)
        row._achProgressFill:Show()
    else
        row._achProgressFill:Hide()
    end

    row._achProgressBorder:SetPoint("TOPLEFT",     row._achProgressBg, "TOPLEFT",    -1,  1)
    row._achProgressBorder:SetPoint("BOTTOMRIGHT", row._achProgressBg, "BOTTOMRIGHT", 1, -1)
    row._achProgressBorder:SetBackdropBorderColor(tc[1] * 0.6, tc[2] * 0.6, tc[3] * 0.6, 0.7)
    row._achProgressBorder:SetFrameLevel(row:GetFrameLevel() + 3)

    row._achProgressLbl:SetPoint("LEFT", row._achProgressBg, "RIGHT", 6, 0)
    row._achProgressLbl:SetText(
        math.min(current, target) .. "/" .. target ..
        "  |cff" ..
        string.format("%02x%02x%02x",
            math.floor(tc[1] * 255),
            math.floor(tc[2] * 255),
            math.floor(tc[3] * 255)) ..
        H.TierIconMarkup(nextTier.tierName, 14) .. " " .. nextTier.tierName .. "|r"
    )
    container:Show()
end

-- ============================================================
-- Aufgeklappter Bereich: Tier-Zeilen
-- Wird NACH row:SetSize aufgerufen wenn row bereits expanded ist.
-- ============================================================

local function EnsureTierRowSkeleton(container, index)
    container._achTierRows = container._achTierRows or {}
    local row = container._achTierRows[index]
    if row then return row end

    row = {}
    row.tierIcon = container:CreateTexture(nil, "ARTWORK", nil, 2)
    row.tierIcon:SetSize(14, 14)
    row.tierIcon:Hide()

    row.tierLbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tierDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tierDesc:SetWordWrap(false)

    row.prgLbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.prgLbl:SetJustifyH("RIGHT")
    row.prgLbl:Hide()

    container._achTierRows[index] = row
    return row
end

function H.ResetExpandedTiers(container)
    if not container or not container._achTierRows then return end
    for _, row in ipairs(container._achTierRows) do
        row.tierIcon:Hide()
        row.tierLbl:Hide()
        row.tierDesc:Hide()
        row.prgLbl:Hide()
        row.tierLbl:SetText("")
        row.tierDesc:SetText("")
        row.prgLbl:SetText("")
    end
end

function H.BuildExpandedTiers(container, group, textX, unlocked, progress)
    local tiers = group.tiers or {}
    local prog  = progress[group.id]

    H.ResetExpandedTiers(container)

    for i, tier in ipairs(tiers) do
        local isUL = unlocked[tier.id] ~= nil
        local tc   = H.TIER_COLOR[tier.tierName] or { 0.7, 0.7, 0.7 }
        local yOff = -(H.TIER_PADDING + (i - 1) * H.TIER_ROW_H)
        local row  = EnsureTierRowSkeleton(container, i)

        row.tierIcon:ClearAllPoints()
        row.tierIcon:SetPoint("TOPLEFT", container, "TOPLEFT", textX, yOff - 4)
        row.tierIcon:SetTexture(H.TIER_ICON[tier.tierName] or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.tierIcon:SetDesaturated(not isUL)
        row.tierIcon:SetAlpha(isUL and 1 or 0.45)
        row.tierIcon:Show()

        row.tierLbl:ClearAllPoints()
        row.tierLbl:SetPoint("TOPLEFT", container, "TOPLEFT", textX + 18, yOff)
        row.tierLbl:SetText(tier.tierName)
        row.tierLbl:SetTextColor(tc[1], tc[2], tc[3])
        row.tierLbl:Show()

        local descStr = H.loc(tier.desc_de, tier.desc_en) or ""
        row.tierDesc:ClearAllPoints()
        row.tierDesc:SetPoint("TOPLEFT",  container, "TOPLEFT",  textX + 60, yOff)
        row.tierDesc:SetPoint("TOPRIGHT", container, "TOPRIGHT", -(H.SHIELD_SPACE + 60), yOff)
        row.tierDesc:SetText(descStr)
        row.tierDesc:SetTextColor(
            isUL and 1.00 or 0.45,
            isUL and 1.00 or 0.42,
            isUL and 1.00 or 0.35
        )
        row.tierDesc:Show()

        if not isUL then
            local current = (prog and prog.current) or 0
            local target  = tier.target or 1
            row.prgLbl:ClearAllPoints()
            row.prgLbl:SetPoint("TOPRIGHT", container, "TOPRIGHT", -(H.SHIELD_SPACE + 2), yOff)
            row.prgLbl:SetText(math.min(current, target) .. "/" .. target)
            row.prgLbl:SetTextColor(0.55, 0.52, 0.45)
            row.prgLbl:Show()
        else
            row.prgLbl:Hide()
            row.prgLbl:SetText("")
        end
    end
end
