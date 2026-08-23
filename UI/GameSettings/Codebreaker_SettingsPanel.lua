--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    UI/GameSettings/Codebreaker_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local ICON_SIZE = 28
local ICON_GAP  = 4

local function BuildCodebreakerSettingsPanel(parent)
    local S = ArcadiaNexus.CB_Settings
    local T = ArcadiaNexus.CB_Themes
    if not S or not T then return end
    local L = ArcadiaNexus.GetLocaleTable("CODEBREAKER")

    local previewTexs = {}

    local function UpdateThemePreview()
        local theme = T:GetTheme(S:Get("theme"))
        for i = 1, 6 do
            local sym = theme.symbols[i]
            local tex = previewTexs[i]
            if sym and tex then
                tex:SetTexture(sym.icon)
                tex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
            end
        end
    end

    local themeOpts = {}
    for _, t in ipairs(T:GetThemeList()) do
        themeOpts[#themeOpts + 1] = { key = t.key, label = t.name }
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnPlace",  label = L.sound_place  },
                { key = "soundOnSubmit", label = L.sound_submit },
                { key = "soundOnWin",    label = L.sound_win    },
                { key = "soundOnLose",   label = L.sound_lose   },
            },
        },
        theme = {
            minHeight = 200,
            dropdown = {
                label   = L.label_theme,
                key     = "theme",
                options = themeOpts,
                onChange = function(key)
                    if ArcadiaNexus.CB_Renderer then
                        ArcadiaNexus.CB_Renderer.selectedTheme = key
                    end
                    UpdateThemePreview()
                end,
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                if measureOnly then return 110 end

                local prevLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                prevLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 4))
                prevLbl:SetText(L.label_preview)
                prevLbl:SetTextColor(0.75, 0.70, 0.55)

                local iconY = yOff + 22
                for i = 1, 6 do
                    local bx = (i - 1) * (ICON_SIZE + ICON_GAP)
                    local border = c:CreateTexture(nil, "BACKGROUND")
                    border:SetTexture("Interface\\Buttons\\WHITE8X8")
                    border:SetPoint("TOPLEFT", c, "TOPLEFT", bx, -iconY)
                    border:SetSize(ICON_SIZE, ICON_SIZE)
                    border:SetVertexColor(0.30, 0.26, 0.14, 1)
                    local tex = c:CreateTexture(nil, "ARTWORK")
                    tex:SetPoint("TOPLEFT", c, "TOPLEFT", bx + 2, -(iconY + 2))
                    tex:SetSize(ICON_SIZE - 4, ICON_SIZE - 4)
                    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    previewTexs[i] = tex
                end

                local pegY = iconY + ICON_SIZE + 8
                local pegLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                pegLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -pegY)
                pegLbl:SetText(L.peg_exact)
                local pegLbl2 = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                pegLbl2:SetPoint("TOPLEFT", pegLbl, "BOTTOMLEFT", 0, -4)
                pegLbl2:SetText(L.peg_partial)

                UpdateThemePreview()
                return 110
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_input", "guide_submit",
                    "guide_exact", "guide_partial", "guide_hint",
                }),
            },
        },
        rebuild = BuildCodebreakerSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["CODEBREAKER"] = BuildCodebreakerSettingsPanel
