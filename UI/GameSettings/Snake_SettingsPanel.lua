--[[
    ArcadiaNexus – Snake
    UI/GameSettings/Snake_SettingsPanel.lua
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildSnakeSettingsPanel(parent)
    local S = ArcadiaNexus.SNK_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SNAKE")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            items = {
                { key = "soundOnEat",   label = L.sound_eat   },
                { key = "soundOnDie",   label = L.sound_die   },
                { key = "soundOnStart", label = L.sound_start },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_controls", "guide_wrap",
                    "guide_score", "guide_diff", "guide_hint",
                }),
            },
        },
        rebuild = BuildSnakeSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SNAKE"] = BuildSnakeSettingsPanel
