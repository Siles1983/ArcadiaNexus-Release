--[[
    Azeroth Jewels – AzerothJewels_SettingsPanel.lua
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildAzerothJewelsSettingsPanel(parent)
    local S = ArcadiaNexus.AJ_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("AZEROTHJEWELS")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnMatch",    label = L.sound_match    },
                { key = "soundOnPowerup",  label = L.sound_powerup  },
                { key = "soundOnGameover", label = L.sound_gameover },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3",
                    "guide_4", "guide_5", "guide_6", "guide_7",
                }),
            },
        },
        onReset = function()
            local R = ArcadiaNexus.AJ_Renderer
            if R and R._timerCheckbox then
                R._timerCheckbox:SetChecked(S:Get("timerActive"))
            end
        end,
        rebuild = BuildAzerothJewelsSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["AZEROTHJEWELS"] = BuildAzerothJewelsSettingsPanel
