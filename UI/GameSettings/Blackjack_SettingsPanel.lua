--[[
    ArcadiaNexus – Blackjack
    UI/GameSettings/Blackjack_SettingsPanel.lua
    Layout: P1 (Sound | Theme + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local SHARED_BACKS = "Interface\\AddOns\\ArcadiaNexus\\Shared\\CardBacks\\"
local THEME_KEYS   = { "neutral", "alliance", "horde" }

local function BuildBlackjackSettingsPanel(parent)
    local S = ArcadiaNexus.BJ_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("BLACKJACK") or {}

    local function OnThemeChange()
        local R = ArcadiaNexus.BJ_Renderer
        if R and R.RefreshCardBacks then
            R:RefreshCardBacks()
        end
    end

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "standard",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 22,
            items = {
                { key = "soundOnDeal", label = L.sound_deal },
                { key = "soundOnFlip", label = L.sound_flip },
                { key = "soundOnWin",  label = L.sound_win  },
                { key = "soundOnLose", label = L.sound_lose },
                { key = "soundOnBust", label = L.sound_bust },
                { key = "soundOnChip", label = L.sound_chip },
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
                onChange = OnThemeChange,
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
        guide = {
            minHeight = 140,
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5",
                    "guide_6", "guide_7", "guide_8", "guide_9",
                }, 15),
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["BLACKJACK"] = BuildBlackjackSettingsPanel
