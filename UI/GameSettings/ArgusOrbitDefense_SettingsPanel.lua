--[[
    Argus Orbit Defense – Settings Panel
    Layout: Sound | Visuals + Guide via BuildSoundVisualGuide
]]

local GS = ArcadiaNexus.GameSettings

local function BuildArgusOrbitDefenseSettingsPanel(parent)
    local S = ArcadiaNexus.AOD_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("ARGUSORBDEFENSE") or {}

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_master,
            rowSpacing  = 26,
            items = {
                { key = "soundOnShoot",         label = L.sound_shoot          },
                { key = "soundOnExplode",       label = L.sound_explode        },
                { key = "soundOnPowerUpBomb",   label = L.sound_powerup_bomb   },
                { key = "soundOnPowerUpLife",   label = L.sound_powerup_life   },
                { key = "soundOnPowerUpShield", label = L.sound_powerup_shield },
                { key = "soundOnEngine",        label = L.sound_engine         },
                { key = "soundOnWaveClear",     label = L.sound_waveclear      },
                { key = "soundOnWin",           label = L.sound_win            },
                { key = "soundOnLose",          label = L.sound_lose           },
            },
        },
        visuals = {
            items = {
                { key = "screenFlash", label = L.lbl_screen_flash },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5",
                    "guide_6", "guide_7", "guide_8", "guide_9",
                }),
            },
        },
        rebuild = BuildArgusOrbitDefenseSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ARGUSORBDEFENSE"] = BuildArgusOrbitDefenseSettingsPanel
