--[[
    Minesweeper – Settings Panel
    Layout: Sound | Schwierigkeit + Anleitung (volle Breite)
]]

local GS = ArcadiaNexus.GameSettings

local ICON_SIZE = 20

local function BuildMinesweeperSettingsPanel(parent)
    local S = ArcadiaNexus.MS_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("MINESWEEPER")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnReveal",  label = L.sound_reveal  },
                { key = "soundOnFlag",    label = L.sound_flag    },
                { key = "soundOnExplode", label = L.sound_explode },
                { key = "soundOnWin",     label = L.sound_win     },
            },
        },
        theme = {
            title     = L.box_difficulty,
            minHeight = 180,
            build = function(cB, _w, _settings, yOff, measureOnly)
                if measureOnly then return 150 end
                local lines = {
                    L.info_easy_title   .. "   " .. L.info_easy_sub,
                    L.info_easy_text,
                    " ",
                    L.info_normal_title .. " "  .. L.info_normal_sub,
                    L.info_normal_text,
                    " ",
                    L.info_hard_title   .. "   " .. L.info_hard_sub,
                    L.info_hard_text,
                    " ",
                    L.info_tip,
                }
                local prev = nil
                for _, line in ipairs(lines) do
                    local fs = cB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    if prev then
                        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
                    else
                        fs:SetPoint("TOPLEFT", cB, "TOPLEFT", 0, -(yOff or 0))
                    end
                    fs:SetText(line)
                    fs:SetTextColor(0.85, 0.80, 0.65)
                    fs:SetJustifyH("LEFT")
                    prev = fs
                end
                return 150
            end,
        },
        guide = {
            build = function(cA, yOff, measureOnly)
                if measureOnly then return 200 end
                if not cA then return 200 end

                local iconRows = {
                    { icon = "Interface\\Icons\\INV_Misc_Gear_01",    tint = { 0.65, 0.65, 0.65 },
                      title = L.guide_hidden_title, text = L.guide_hidden_text },
                    { icon = "Interface\\Icons\\Ability_TownWatch", tint = { 1, 0.7, 0.2 },
                      title = L.guide_flag_title,   text = L.guide_flag_text },
                    { icon = "Interface\\Icons\\INV_Misc_Bomb_03",    tint = { 1, 0.3, 0.3 },
                      title = L.guide_mine_title,   text = L.guide_mine_text },
                }

                local prevFrame = nil
                for _, row in ipairs(iconRows) do
                    local rowFrame = CreateFrame("Frame", nil, cA)
                    rowFrame:SetHeight(44)
                    if prevFrame then
                        rowFrame:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -6)
                    else
                        rowFrame:SetPoint("TOPLEFT", cA, "TOPLEFT", 0, -(yOff or 0))
                    end
                    rowFrame:SetPoint("RIGHT", cA, "RIGHT", 0, 0)

                    local iconF = CreateFrame("Frame", nil, rowFrame)
                    iconF:SetSize(ICON_SIZE, ICON_SIZE)
                    iconF:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, -2)
                    local tex = iconF:CreateTexture(nil, "ARTWORK")
                    tex:SetAllPoints(iconF)
                    tex:SetTexture(row.icon)
                    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    tex:SetVertexColor(row.tint[1], row.tint[2], row.tint[3])

                    local fs = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    fs:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", ICON_SIZE + 6, 0)
                    fs:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
                    fs:SetText(row.title .. "\n" .. row.text)
                    fs:SetTextColor(0.85, 0.80, 0.65)
                    fs:SetJustifyH("LEFT")
                    prevFrame = rowFrame
                end

                local numFrame = CreateFrame("Frame", nil, cA)
                numFrame:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -10)
                numFrame:SetPoint("RIGHT", cA, "RIGHT", 0, 0)
                numFrame:SetHeight(20)

                local numTitle = numFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                numTitle:SetPoint("TOPLEFT", numFrame, "TOPLEFT", 0, 0)
                numTitle:SetText(L.guide_numbers)
                numTitle:SetTextColor(0.85, 0.80, 0.65)

                local numColors = {
                    { n = 1, r = 0.26, g = 0.26, b = 1.00 }, { n = 2, r = 0.13, g = 0.67, b = 0.13 },
                    { n = 3, r = 1.00, g = 0.20, b = 0.20 }, { n = 4, r = 0.00, g = 0.00, b = 0.55 },
                    { n = 5, r = 0.55, g = 0.00, b = 0.00 }, { n = 6, r = 0.00, g = 0.55, b = 0.55 },
                    { n = 7, r = 0.40, g = 0.40, b = 0.40 }, { n = 8, r = 0.65, g = 0.65, b = 0.65 },
                }

                local numRow = CreateFrame("Frame", nil, cA)
                numRow:SetPoint("TOPLEFT", numFrame, "BOTTOMLEFT", 0, -4)
                numRow:SetHeight(20)
                numRow:SetPoint("RIGHT", cA, "RIGHT", 0, 0)

                for i, col in ipairs(numColors) do
                    local nfs = numRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    nfs:SetPoint("LEFT", numRow, "LEFT", (i - 1) * 22, 0)
                    nfs:SetText(tostring(col.n))
                    nfs:SetTextColor(col.r, col.g, col.b)
                    nfs:SetFont(nfs:GetFont(), 14, "OUTLINE")
                end
                return 200
            end,
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["MINESWEEPER"] = BuildMinesweeperSettingsPanel
