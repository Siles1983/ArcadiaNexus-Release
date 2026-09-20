--[[
    Darkmoon Pinball – Settings Panel
    Sound | Visuals + Guide
]]

local GS = ArcadiaNexus.GameSettings

local function BuildDarkmoonPinballSettingsPanel(parent)
    local S = ArcadiaNexus.DMP_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("DARKMOON_PINBALL")

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 22,
            items = {
                { key = "soundOnBumper",  label = L.sound_bumper  },
                { key = "soundOnFlipper", label = L.sound_flipper },
                { key = "soundOnDrain",   label = L.sound_drain   },
                { key = "soundOnLaunch",  label = L.sound_launch  },
                { key = "soundOnPlunger", label = L.sound_plunger },
                { key = "soundOnKickback", label = L.sound_kickback },
                { key = "soundOnTilt",    label = L.sound_tilt    },
                { key = "soundOnTarget",  label = L.sound_target  },
                { key = "soundOnSling",   label = L.sound_sling   },
                { key = "soundOnMission", label = L.sound_mission },
                { key = "soundOnJackpot", label = L.sound_jackpot },
                { key = "soundOnMultiball", label = L.sound_multiball },
                { key = "soundOnSave",    label = L.sound_save    },
            },
        },
        visuals = {
            items = {
                { key = "screenFlash",   label = L.lbl_screen_flash },
                { key = "reducedMotion", label = L.lbl_reduced_motion },
                { key = "debugOverlay",  label = L.lbl_debug },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5", "guide_6", "guide_7", "guide_8", "guide_9", "guide_10",
                }),
            },
        },
        rebuild = BuildDarkmoonPinballSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["DARKMOON_PINBALL"] = BuildDarkmoonPinballSettingsPanel
