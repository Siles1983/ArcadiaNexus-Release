--[[
    ArcadiaNexus – Goblin Blast
    UI/GameSettings/GoblinBlast_SettingsPanel.lua
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildGoblinBlastSettingsPanel(parent)
    local S = ArcadiaNexus.GB_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("GOBLINBLAST")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnExplode", label = L.sound_explode },
                { key = "soundOnPowerup", label = L.sound_powerup },
                { key = "soundOnDie",     label = L.sound_die     },
                { key = "soundOnWin",     label = L.sound_win     },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_controls", "guide_bombs",
                    "guide_powerups", "guide_levels", "guide_timer",
                    "guide_score", "guide_diff", "guide_hint",
                }),
            },
        },
        rebuild = BuildGoblinBlastSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["GOBLINBLAST"] = BuildGoblinBlastSettingsPanel
