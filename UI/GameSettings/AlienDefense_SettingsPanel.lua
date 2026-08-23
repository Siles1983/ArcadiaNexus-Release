--[[
    Alien Defense – Settings Panel
    Layout: Sound (individual) | Visuals + Guide via BuildSoundVisualGuide
]]

local GS = ArcadiaNexus.GameSettings

local function BuildAlienDefenseSettingsPanel(parent)
    local S = ArcadiaNexus.AD_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("ALIENDEFENSE")

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            individual = true,
            rowSpacing = 26,
            items = {
                { key = "soundOnShoot",      label = L.sound_shoot      },
                { key = "soundOnAlienDeath", label = L.sound_aliendeath },
                { key = "soundOnPlayerHit",  label = L.sound_playerhit  },
                { key = "soundOnWeaponDrop", label = L.sound_weapondrop },
                { key = "soundOnWin",        label = L.sound_win        },
                { key = "soundOnLose",       label = L.sound_lose       },
            },
        },
        visuals = {
            items = {
                { key = "screenFlash", label = L.lbl_screen_flash },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4", "guide_5", "guide_6", "guide_7" }),
            },
        },
        rebuild = BuildAlienDefenseSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ALIENDEFENSE"] = BuildAlienDefenseSettingsPanel
