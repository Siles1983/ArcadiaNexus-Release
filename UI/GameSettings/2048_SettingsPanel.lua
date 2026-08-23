--[[
    2048 – Settings Panel
    Layout: P1 (Sound | Theme + Anleitung) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local PREVIEW_COLORS = {
    CLASSIC  = {
        bg = { {0.93,0.89,0.85},{0.95,0.69,0.47},{0.96,0.49,0.37},{0.93,0.81,0.45},{1.00,0.84,0.00} },
        fg = { {0.47,0.43,0.40},{1,1,1},{1,1,1},{1,1,1},{1,1,1} },
    },
    HORDE    = {
        bg = { {0.55,0.18,0.18},{0.78,0.28,0.18},{0.90,0.35,0.10},{0.85,0.65,0.10},{1.00,0.92,0.20} },
        fg = { {1,0.9,0.8},{1,1,1},{1,1,1},{0.2,0.08,0.08},{0.2,0.08,0.08} },
    },
    ALLIANCE = {
        bg = { {0.60,0.70,0.90},{0.35,0.50,0.88},{0.22,0.35,0.82},{0.70,0.78,0.85},{1.00,0.96,0.70} },
        fg = { {0.1,0.15,0.35},{1,1,1},{1,1,1},{0.1,0.15,0.3},{0.1,0.15,0.3} },
    },
    NIGHTELF = {
        bg = { {0.35,0.20,0.55},{0.20,0.55,0.35},{0.55,0.20,0.65},{0.20,0.75,0.45},{0.55,0.95,0.65} },
        fg = { {0.9,0.8,1},{0.9,1,0.9},{1,0.9,1},{0.05,0.15,0.1},{0.05,0.2,0.1} },
    },
    GOBLIN   = {
        bg = { {0.38,0.62,0.22},{0.55,0.78,0.10},{0.78,0.88,0.08},{0.95,0.85,0.10},{1.00,0.92,0.00} },
        fg = { {0.05,0.15,0.05},{0.05,0.15,0.05},{0.05,0.15,0.05},{0.05,0.15,0.05},{0.05,0.15,0.05} },
    },
}
local SWATCH_VALUES = { 2, 8, 32, 128, 2048 }

local function Build2048SettingsPanel(parent)
    local S = ArcadiaNexus.TDG_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("2048")

    local swatches = {}

    local function RefreshPreview(themeID)
        local p = PREVIEW_COLORS[themeID] or PREVIEW_COLORS.CLASSIC
        for i, sf in ipairs(swatches) do
            local c = p.bg[i] or { 0.5, 0.5, 0.5 }
            local f = p.fg[i] or { 1, 1, 1 }
            sf.bg:SetVertexColor(c[1], c[2], c[3], 1)
            sf.lbl:SetTextColor(f[1], f[2], f[3])
        end
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            footer      = L.sound_hint,
            items = {
                { key = "soundOnLoss", label = L.sound_loss },
            },
        },
        theme = {
            title     = L.box_theme,
            minHeight = 200,
            footer    = L.theme_hint,
            dropdown = {
                label   = L.theme_label,
                key     = "colorTheme",
                options = {
                    { key = "CLASSIC",  label = L.theme_classic  },
                    { key = "HORDE",    label = L.theme_horde    },
                    { key = "ALLIANCE", label = L.theme_alliance },
                    { key = "NIGHTELF", label = L.theme_nightelf },
                    { key = "GOBLIN",   label = L.theme_goblin   },
                },
                onChange = RefreshPreview,
            },
            build = function(c, _w, settings, yOff, measureOnly)
                if measureOnly then return 90 end

                local previewLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                previewLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 14))
                previewLabel:SetText(L.theme_preview)
                previewLabel:SetTextColor(0.80, 0.75, 0.60)

                for i, val in ipairs(SWATCH_VALUES) do
                    local sf = CreateFrame("Frame", nil, c)
                    sf:SetSize(32, 32)
                    sf:SetPoint("TOPLEFT", c, "TOPLEFT", (i - 1) * 38, -(yOff + 32))
                    local bg = sf:CreateTexture(nil, "ARTWORK")
                    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
                    bg:SetAllPoints(sf)
                    sf.bg = bg
                    local lbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    lbl:SetPoint("CENTER")
                    lbl:SetText(tostring(val))
                    sf.lbl = lbl
                    swatches[i] = sf
                end

                RefreshPreview(settings:Get("colorTheme"))
                return 90
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5",
                }),
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
if ArcadiaNexus.SettingsPanel.RegisterBuilder then
    ArcadiaNexus.SettingsPanel.RegisterBuilder("2048", Build2048SettingsPanel)
else
    ArcadiaNexus.SettingsPanel._builders["2048"] = Build2048SettingsPanel
end
