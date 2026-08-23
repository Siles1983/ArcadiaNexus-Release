--[[
    ArcadiaNexus – Solitaire
    UI/GameSettings/Solitaire_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local BACK_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Games\\Solitaire\\Assets\\background\\cards_back\\"
local THEME_KEYS = { "neutral", "alliance", "horde" }
local BACK_FILES = { "card_back_neutral", "card_back_alliance", "card_back_horde" }

local function BuildSolitaireSettingsPanel(parent)
    local S = ArcadiaNexus.SOL_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("SOLITAIRE") or {}

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 22,
            items = {
                { key = "soundOnDeal",  label = L.sound_deal       },
                { key = "soundOnPlace", label = L.sound_place      },
                { key = "soundOnFnd",   label = L.sound_foundation },
                { key = "soundOnInval", label = L.sound_invalid    },
                { key = "soundOnWin",   label = L.sound_win        },
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
                onChange = function()
                    local R = ArcadiaNexus.SOL_Renderer
                    if R and R.RefreshBackground then R:RefreshBackground() end
                end,
            },
            build = function(c, _w, _settings, yOff, measureOnly)
                return GS.BuildCardBackPreview(c, yOff, measureOnly, {
                    label      = L.lbl_card_backs or "Kartenrückseiten:",
                    keys       = THEME_KEYS,
                    files      = BACK_FILES,
                    pathPrefix = BACK_PATH,
                    getSelected = function() return S:Get("theme") or "neutral" end,
                })
            end,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                    "guide_5", "guide_6", "guide_7", "guide_8",
                }),
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SOLITAIRE"] = BuildSolitaireSettingsPanel
