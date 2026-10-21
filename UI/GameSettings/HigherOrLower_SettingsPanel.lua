--[[
    ArcadiaNexus – HigherOrLower
    UI/GameSettings/HigherOrLower_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local SHARED_BACKS = "Interface\\AddOns\\ArcadiaNexus\\Shared\\CardBacks\\"
local THEME_KEYS   = { "neutral", "alliance", "horde" }

local function BuildHigherOrLowerSettingsPanel(parent)
    local S = ArcadiaNexus.HOL_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("HIGHERORLOWER")
    if not L then return end

    local section = GS.GuideSection(nil, L, {
        "guide_1", "guide_2", "guide_3", "guide_4",
        "guide_5", "guide_6", "guide_7", "guide_8", "guide_9",
    }, 15)
    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    measure:SetWidth(GS.GetTotalWidth(parent) - UI.PAD * 2)
    measure:SetWordWrap(true)
    local guideHeight = 64
    for _, line in ipairs(section.lines) do
        measure:SetText(line)
        guideHeight = guideHeight + math.max(14, measure:GetStringHeight()) + 2
    end
    measure:Hide()

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing = 26,
            items = {
                { key = "soundOnFlip",    label = L.sound_flip    },
                { key = "soundOnCorrect", label = L.sound_correct },
                { key = "soundOnWrong",   label = L.sound_wrong   },
                { key = "soundOnCashout", label = L.sound_cashout },
                { key = "soundOnJoker",   label = L.sound_joker   },
            },
        },
        theme = {
            minHeight = 160,
            dropdown = {
                label   = L.lbl_theme,
                key     = "theme",
                options = {
                    { key = "neutral",  label = L.theme_neutral  },
                    { key = "alliance", label = L.theme_alliance },
                    { key = "horde",    label = L.theme_horde    },
                },
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                return GS.BuildCardBackPreview(c, yOff, measureOnly, {
                    label      = L.lbl_card_backs or "Kartenrückseiten:",
                    keys       = THEME_KEYS,
                    pathPrefix = SHARED_BACKS,
                    getSelected = function() return S:Get("theme") or "neutral" end,
                })
            end,
        },
        guide = { minHeight = guideHeight, sections = { section } },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["HIGHERORLOWER"] = BuildHigherOrLowerSettingsPanel
