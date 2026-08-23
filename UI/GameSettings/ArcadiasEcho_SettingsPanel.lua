--[[
    Gaming Hub – Simon Says (Arcadia's Echo)
    UI/GameSettings/ArcadiasEcho_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local ICON_SIZE = 32
local ICON_GAP  = 6

local function BuildArcadiasEchoSettingsPanel(parent)
    local S = ArcadiaNexus.AE_Settings
    local T = ArcadiaNexus.AE_Themes
    if not S or not T then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")

    local previewTexs = {}

    local function UpdateThemePreview()
        local syms = T:GetSymbolsForDiff(S:Get("theme"), "easy")
        for i = 1, 4 do
            local sym = syms[i]
            local tex = previewTexs[i]
            if sym and tex then
                tex:SetTexture(nil)
                tex:SetTexCoord(0, 1, 0, 1)
                tex:SetVertexColor(1, 1, 1, 1)
                if sym.isAtlas then
                    tex:SetAtlas(sym.atlas, false)
                else
                    tex:SetTexture(sym.icon)
                    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    tex:SetVertexColor(sym.color[1], sym.color[2], sym.color[3])
                end
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
                { key = "soundOnFlash", label = L.sound_flash },
                { key = "soundOnInput", label = L.sound_input },
                { key = "soundOnWin",   label = L.sound_win   },
                { key = "soundOnLose",  label = L.sound_lose  },
            },
        },
        theme = {
            minHeight = 160,
            dropdown = {
                label   = L.label_theme,
                key     = "theme",
                options = themeOpts,
                onChange = function(key)
                    if ArcadiaNexus.AE_Renderer then
                        ArcadiaNexus.AE_Renderer._currentTheme = key
                    end
                    UpdateThemePreview()
                end,
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                if measureOnly then return 70 end

                local prevLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                prevLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 4))
                prevLbl:SetText(L.label_preview)
                prevLbl:SetTextColor(0.75, 0.70, 0.55)

                local iconY = yOff + 22
                for i = 1, 4 do
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
                UpdateThemePreview()
                return 70
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_flow", "guide_diff",
                    "guide_seq", "guide_fail", "guide_tip",
                }),
            },
        },
        rebuild = BuildArcadiasEchoSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ARCADIASECHO"] = BuildArcadiasEchoSettingsPanel
