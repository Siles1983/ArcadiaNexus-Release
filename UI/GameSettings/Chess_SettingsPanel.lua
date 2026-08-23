--[[
    Chess – Settings Panel
    Layout: Sound | Figuren-Übersicht + Anleitung (KI)
]]

local GS = ArcadiaNexus.GameSettings

local PIECE_ICONS = {
    { iconW = "Interface\\Icons\\INV_Helmet_01",            iconB = "Interface\\Icons\\INV_Helmet_02",        nameKey = "piece_king",   descKey = "piece_king_desc"   },
    { iconW = "Interface\\Icons\\INV_Jewelry_Ring_05",      iconB = "Interface\\Icons\\INV_Jewelry_Ring_01",    nameKey = "piece_queen",  descKey = "piece_queen_desc"  },
    { iconW = "Interface\\Icons\\Ability_Repair",           iconB = "Interface\\Icons\\INV_Stone_15",         nameKey = "piece_rook",   descKey = "piece_rook_desc"   },
    { iconW = "Interface\\Icons\\Ability_Mount_RidingHorse", iconB = "Interface\\Icons\\Ability_Mount_Raptor", nameKey = "piece_knight", descKey = "piece_knight_desc" },
    { iconW = "Interface\\Icons\\INV_Shield_06",            iconB = "Interface\\Icons\\INV_Shield_05",        nameKey = "piece_pawn",   descKey = "piece_pawn_desc"   },
}

local ICON_SIZE = 28
local ROW_H     = 52

local function BuildChessSettingsPanel(parent)
    local S = ArcadiaNexus.Chess_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("CHESS")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnCaptureEnemy", label = L.sound_capture_enemy },
                { key = "soundOnCaptureOwn",   label = L.sound_capture_own   },
                { key = "soundOnWin",          label = L.sound_win           },
                { key = "soundOnLoss",         label = L.sound_loss          },
            },
        },
        theme = {
            title     = L.box_legend,
            minHeight = 280,
            build = function(cA, innerW, _settings, yOff, measureOnly)
                local h = #PIECE_ICONS * ROW_H
                if measureOnly then return h end

                for i, entry in ipairs(PIECE_ICONS) do
                    local rowY = (yOff or 0) + (i - 1) * ROW_H

                    local iconWFrame = CreateFrame("Frame", nil, cA)
                    iconWFrame:SetSize(ICON_SIZE, ICON_SIZE)
                    iconWFrame:SetPoint("TOPLEFT", cA, "TOPLEFT", 0, -rowY)
                    local iconW = iconWFrame:CreateTexture(nil, "ARTWORK")
                    iconW:SetAllPoints(iconWFrame)
                    iconW:SetTexture(entry.iconW)
                    iconW:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    iconW:SetVertexColor(0.55, 0.70, 1.00)

                    local iconBFrame = CreateFrame("Frame", nil, cA)
                    iconBFrame:SetSize(ICON_SIZE, ICON_SIZE)
                    iconBFrame:SetPoint("TOPLEFT", cA, "TOPLEFT", ICON_SIZE + 4, -rowY)
                    local iconB = iconBFrame:CreateTexture(nil, "ARTWORK")
                    iconB:SetAllPoints(iconBFrame)
                    iconB:SetTexture(entry.iconB)
                    iconB:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    iconB:SetVertexColor(1.00, 0.35, 0.35)

                    local nameFS = cA:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    nameFS:SetPoint("TOPLEFT", cA, "TOPLEFT", ICON_SIZE * 2 + 10, -rowY)
                    nameFS:SetText("|cffffff00" .. L[entry.nameKey] .. "|r")

                    local descFS = cA:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    descFS:SetPoint("TOPLEFT", cA, "TOPLEFT", ICON_SIZE * 2 + 10, -(rowY + 16))
                    descFS:SetWidth(innerW - ICON_SIZE * 2 - 20)
                    descFS:SetText(L[entry.descKey])
                    descFS:SetTextColor(0.80, 0.75, 0.60)
                    descFS:SetJustifyH("LEFT")
                end
                return h
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                }),
                GS.GuideSection(L.box_ki, L, {
                    "info_classic_title", "info_classic_text", "info_classic_text2",
                    "info_pro_title", "info_pro_text1", "info_pro_text2",
                    "info_insane_title", "info_insane_text1", "info_insane_text2",
                    "info_diff_hint",
                }, 15),
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["CHESS"] = BuildChessSettingsPanel
