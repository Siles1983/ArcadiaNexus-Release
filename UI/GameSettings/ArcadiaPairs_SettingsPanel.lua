--[[
    Gaming Hub – Arcadia Pairs (Memory)
    UI/GameSettings/ArcadiaPairs_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function CreateIconPreview(parent, x, y, size)
    local border = parent:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    border:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + size, -(y + size))
    border:SetVertexColor(0.5, 0.45, 0.3, 1)

    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 2, -(y + 2))
    tex:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + size - 2, -(y + size - 2))
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return tex
end

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function ThemePreviewIcons(theme)
    local Logic = ArcadiaNexus.AP_Logic
    local names = Logic and Logic.GetDeckIcons and Logic:GetDeckIcons(theme) or {}
    local out = {}
    for i = 1, 6 do
        local name = names[i]
        out[i] = name and ("Interface\\Icons\\" .. name) or FALLBACK_ICON
    end
    return out
end

local function BuildArcadiaPairsSettingsPanel(parent)
    local S  = ArcadiaNexus.AP_Settings
    local SR = ArcadiaNexus.AP_SymbolResolver
    if not S or not SR then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")

    local backPreviewTex, themePreviewTexs = nil, {}

    local deckOpts = {}
    for _, d in ipairs(S:GetDeckList()) do
        deckOpts[#deckOpts + 1] = { key = d.key, label = d.name }
    end

    local backOpts = {}
    for _, m in ipairs(SR:GetModeList()) do
        backOpts[#backOpts + 1] = { key = m.key, label = m.label }
    end

    local function UpdateBackPreview()
        if not backPreviewTex then return end
        local backData = SR:GetCardBack(S:GetAll())
        backPreviewTex:SetTexture(backData.icon)
        backPreviewTex:SetVertexColor(
            backData.tint[1], backData.tint[2], backData.tint[3], backData.tint[4])
    end

    local function UpdateThemePreview()
        local deck = ThemePreviewIcons(S:Get("theme"))
        for i, tex in ipairs(themePreviewTexs) do
            tex:SetTexture(deck[i] or "Interface\\Icons\\INV_Misc_QuestionMark")
            tex:SetVertexColor(1, 1, 1, 1)
        end
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnFlip",     label = L.sound_flip     },
                { key = "soundOnMatch",    label = L.sound_match    },
                { key = "soundOnMismatch", label = L.sound_mismatch },
                { key = "soundOnWin",      label = L.sound_win      },
                { key = "soundOnLose",     label = L.sound_lose     },
            },
        },
        theme = {
            minHeight = 255,
            dropdown = {
                label   = L.label_theme_deck,
                key     = "theme",
                options = deckOpts,
                onChange = function(key)
                    if ArcadiaNexus.AP_Renderer then
                        ArcadiaNexus.AP_Renderer.selectedTheme = key
                    end
                    UpdateThemePreview()
                end,
            },
            build = function(c, w, _settings, yOff, measureOnly)
                if measureOnly then return 148 end

                local backGet = function() return S:Get("cardBackMode") end
                local backDD = UI.CreateSimpleDropdown(c, 0, yOff + 4, w - UI.PAD * 2 - 24, L.label_card_back,
                    backOpts,
                    backGet,
                    function(key)
                        S:Set("cardBackMode", key)
                        UpdateBackPreview()
                    end
                )
                if GS.TrackDropdown then
                    GS.TrackDropdown(c, backDD, backGet, function()
                        UpdateBackPreview()
                    end)
                end

                local backLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                backLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 56))
                backLbl:SetText(L.label_back_prev)
                backLbl:SetTextColor(0.75, 0.70, 0.55)

                backPreviewTex = CreateIconPreview(c, 0, yOff + 70, 36)

                local themeLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                themeLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 104))
                themeLbl:SetText(L.label_theme_prev)
                themeLbl:SetTextColor(0.75, 0.70, 0.55)

                for i = 1, 6 do
                    themePreviewTexs[i] = CreateIconPreview(c, (i - 1) * 28, yOff + 118, 24)
                end

                UpdateBackPreview()
                UpdateThemePreview()
                return 148
            end,
            refresh = function()
                UpdateBackPreview()
                UpdateThemePreview()
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_click", "guide_match",
                    "guide_miss", "guide_timer", "guide_hint", "guide_mp",
                }),
            },
        },
        rebuild = BuildArcadiaPairsSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ARCADIAPAIRS"] = BuildArcadiaPairsSettingsPanel
