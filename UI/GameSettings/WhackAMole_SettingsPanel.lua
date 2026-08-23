--[[
    Whack-a-Mole – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Maulwurf-/Bomben-Icons in der Guide-Box (keine Preview-Box mehr)
]]

local GS = ArcadiaNexus.GameSettings

local function BuildWhackAMoleSettingsPanel(parent)
    local S = ArcadiaNexus.WAM_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
    local Logic = ArcadiaNexus.WAM_Logic

    local moleIcons = Logic and Logic.MOLE_ICONS or {}
    local bombIcon  = Logic and Logic.BOMB_ICON  or ""

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            individual = true,
            rowSpacing = 26,
            items = {
                { key = "soundOnHit",  label = L.sound_hit  },
                { key = "soundOnBomb", label = L.sound_bomb },
            },
        },
        guide = {
            build = function(c, yOff, measureOnly)
                if measureOnly then return 72 end
                if not c then return 72 end

                for i, icon in ipairs(moleIcons) do
                    local f = CreateFrame("Frame", nil, c)
                    f:SetSize(30, 30)
                    f:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * 36, -(yOff + 2))
                    local tex = f:CreateTexture(nil, "ARTWORK")
                    tex:SetAllPoints(f)
                    tex:SetTexture(icon)
                end

                local bombF = CreateFrame("Frame", nil, c)
                bombF:SetSize(30, 30)
                bombF:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 40))
                local bombTex = bombF:CreateTexture(nil, "ARTWORK")
                bombTex:SetAllPoints(bombF)
                bombTex:SetTexture(bombIcon)

                local bombLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                bombLbl:SetPoint("LEFT", bombF, "RIGHT", 6, 0)
                bombLbl:SetText(L.bomb_hint)
                bombLbl:SetTextColor(0.80, 0.75, 0.60)

                return 72
            end,
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_click", "guide_points", "guide_bomb",
                    "guide_diff", "guide_missed", "guide_highscore", "guide_timer",
                }),
            },
        },
        rebuild = BuildWhackAMoleSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["WHACKAMOLE"] = BuildWhackAMoleSettingsPanel
