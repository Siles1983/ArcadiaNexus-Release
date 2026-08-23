--[[
    Azeroth Words – Settings Panel
    UI/GameSettings/AzerothWords_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local PREVIEW_STATES = { "CORRECT", "PRESENT", "ABSENT" }
local THEMES_LOCAL = {
    classic = {
        CORRECT = { 0.20, 0.60, 0.20 },
        PRESENT = { 0.65, 0.55, 0.05 },
        ABSENT  = { 0.22, 0.22, 0.22 },
    },
    wow = {
        CORRECT = { 0.75, 0.60, 0.00 },
        PRESENT = { 0.50, 0.50, 0.52 },
        ABSENT  = { 0.12, 0.12, 0.14 },
    },
}

local function BuildAzerothWordsSettingsPanel(parent)
    local S = ArcadiaNexus.WRD_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")

    local previewFrames = {}

    local function UpdatePreview(theme)
        local td = THEMES_LOCAL[theme] or THEMES_LOCAL.classic
        for _, pf in ipairs(previewFrames) do
            if pf.state and td[pf.state] then
                local c = td[pf.state]
                pf:SetBackdropColor(c[1], c[2], c[3], 1)
            end
        end
        local R = ArcadiaNexus.WRD_Renderer
        if R and R._kbButtons then
            local gs = ArcadiaNexus.WRD_Engine and ArcadiaNexus.WRD_Engine._gameState
            if gs then R:UpdateKeyboard(gs) end
        end
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnReveal",  label = L.sound_reveal  },
                { key = "soundOnCorrect", label = L.sound_correct },
                { key = "soundOnWin",     label = L.sound_win     },
                { key = "soundOnLose",    label = L.sound_lose    },
            },
        },
        theme = {
            minHeight = 120,
            dropdown = {
                label   = L.box_theme,
                key     = "theme",
                options = {
                    { key = "classic", label = L.theme_classic },
                    { key = "wow",     label = L.theme_wow     },
                },
                onChange = UpdatePreview,
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                if measureOnly then return 84 end

                local previewLabels = {
                    L.theme_preview_correct or "Richtig",
                    L.theme_preview_present or "Enthalten",
                    L.theme_preview_absent  or "Fehlt",
                }
                for i, st in ipairs(PREVIEW_STATES) do
                    local rowY = (yOff or 0) + (i - 1) * 26
                    local pf = CreateFrame("Frame", nil, c, "BackdropTemplate")
                    pf:SetSize(18, 18)
                    pf:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -rowY)
                    pf:SetBackdrop({
                        bgFile   = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile     = false,
                        edgeSize = 8,
                        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
                    })
                    pf.state = st
                    local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    lbl:SetPoint("LEFT", pf, "RIGHT", 6, 0)
                    lbl:SetText(previewLabels[i])
                    lbl:SetTextColor(0.80, 0.75, 0.60)
                    previewFrames[#previewFrames + 1] = pf
                end
                UpdatePreview(S:Get("theme"))
                return 84
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4", "guide_5", "guide_6" }),
            },
        },
        rebuild = BuildAzerothWordsSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["AZEROTHWORDS"] = BuildAzerothWordsSettingsPanel
