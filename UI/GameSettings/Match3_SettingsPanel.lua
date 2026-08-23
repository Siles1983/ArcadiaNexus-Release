-- ============================================================
--  Match3 – Match3_SettingsPanel.lua
--  Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
--
--  Schwierigkeit und Timer-Checkbox: Renderer (unter Spielfeld).
-- ============================================================

local GS = ArcadiaNexus.GameSettings

local function CreateGemPreview(parent, x, y, size)
    local border = parent:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetPoint("TOPLEFT",     parent, "TOPLEFT", x,      -y)
    border:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + size, -(y + size))
    border:SetVertexColor(0.3, 0.28, 0.20, 1)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     parent, "TOPLEFT", x + 2,      -(y + 2))
    tex:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + size - 2, -(y + size - 2))
    tex._border = border
    return tex
end

local function ApplyPreviewGem(tex, gemDef)
    if not gemDef then tex:SetTexture(nil); return end
    tex:SetTexture(nil)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    if gemDef.type == "atlas" then
        tex:SetAtlas(gemDef.atlas, false)
    elseif gemDef.type == "icon" then
        tex:SetTexture(gemDef.icon)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(gemDef.color[1], gemDef.color[2], gemDef.color[3], 1)
    end
    if tex._border then
        tex._border:SetVertexColor(
            gemDef.color[1] * 0.5, gemDef.color[2] * 0.5, gemDef.color[3] * 0.5, 1)
    end
end

local PREVIEW_SIZE = 30
local PREVIEW_GAP  = 4

local function BuildMatch3SettingsPanel(parent)
    local S  = ArcadiaNexus.M3_Settings
    local TH = ArcadiaNexus.M3_Themes
    if not S or not TH then return end
    local L = ArcadiaNexus.GetLocaleTable("MATCH3")

    local previewTexs = {}

    local function UpdateThemePreview()
        local gems = TH:GetPreviewIcons(S:Get("theme"))
        for i, tex in ipairs(previewTexs) do
            ApplyPreviewGem(tex, gems[i])
        end
    end

    local function OnThemeChange(key)
        local E = ArcadiaNexus.M3_Engine
        if E and E.gameState then
            E.gameState.theme    = key
            E.gameState.gemCount = TH:GetGemCount(key)
            if ArcadiaNexus.M3_Renderer then
                ArcadiaNexus.M3_Renderer:_DrawGrid(E.gameState)
            end
        end
        UpdateThemePreview()
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            items = {
                { key = "soundOnMatch",    label = L.sound_match    or "Match-Sound" },
                { key = "soundOnMove",     label = L.sound_move     or "Zug-Sound"  },
                { key = "soundOnCombo",    label = L.sound_combo    or "Combo-Sound"},
                { key = "soundOnGameover", label = L.sound_gameover or "Spielende"  },
            },
        },
        theme = {
            minHeight = 140,
            dropdown = {
                label   = L.box_theme or "Thema",
                key     = "theme",
                options = {
                    { key = "raidmarker",  label = L.theme_raidmarker  or "Raid-Marker" },
                    { key = "professions", label = L.theme_professions or "Berufe"      },
                    { key = "resources",   label = L.theme_resources   or "Ressourcen"  },
                    { key = "abilities",   label = L.theme_abilities   or "Fähigkeiten" },
                    { key = "classic",     label = L.theme_classic     or "Klassisch"   },
                },
                onChange = OnThemeChange,
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                if measureOnly then return 64 end
                local prevLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                prevLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(yOff + 4))
                prevLbl:SetText(L.lbl_theme_prev or "Vorschau:")
                prevLbl:SetTextColor(0.75, 0.70, 0.55)
                for i = 1, 8 do
                    previewTexs[i] = CreateGemPreview(
                        c, (i - 1) * (PREVIEW_SIZE + PREVIEW_GAP), yOff + 20, PREVIEW_SIZE)
                end
                UpdateThemePreview()
                return 64
            end,
            refresh = UpdateThemePreview,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3",
                    "guide_4", "guide_5", "guide_6",
                }, 15),
            },
        },
        onReset = function()
            local R = ArcadiaNexus.M3_Renderer
            if R and R._timerCheckbox then
                R._timerCheckbox:SetChecked(S:Get("timerActive"))
            end
        end,
        rebuild = BuildMatch3SettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["MATCH3"] = BuildMatch3SettingsPanel
