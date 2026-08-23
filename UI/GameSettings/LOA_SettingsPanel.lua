--[[
    Ludo of Azeroth – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Fraktion / KI: Control Bar im Renderer
]]

local GS = ArcadiaNexus.GameSettings

local function BuildLoaSettingsPanel(parent)
    local S = ArcadiaNexus.LOA_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("LOA")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            items = {
                { key = "soundOnRoll",    label = L.sound_roll    },
                { key = "soundOnMove",    label = L.sound_move    },
                { key = "soundOnCapture", label = L.sound_capture },
                { key = "soundOnHome",    label = L.sound_home    },
                { key = "soundOnWin",     label = L.sound_win     },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_dice", "guide_six", "guide_move",
                    "guide_capture", "guide_safe", "guide_ai", "guide_hint",
                }, 15),
            },
        },
        rebuild = BuildLoaSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["LOA"] = BuildLoaSettingsPanel
