--[[
    Shadows Conquest – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildShadowsConquestSettingsPanel(parent)
    local S = ArcadiaNexus.SC_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SHADOWSCONQUEST")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnToggle", label = L.sound_toggle },
                { key = "soundOnWin",    label = L.sound_win    },
                { key = "soundOnLose",   label = L.sound_lose   },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4" }),
            },
        },
        rebuild = BuildShadowsConquestSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SHADOWSCONQUEST"] = BuildShadowsConquestSettingsPanel
