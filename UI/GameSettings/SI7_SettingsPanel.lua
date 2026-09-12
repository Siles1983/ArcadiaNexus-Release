--[[
    Azeroth Intelligence (SI:7) – Settings Panel
    Layout: P2 (Sound full + Guide)
]]

local GS = ArcadiaNexus.GameSettings

local function BuildSI7SettingsPanel(parent)
    local S = ArcadiaNexus.SI7_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SI7")

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            single      = true,
            masterLabel = L.sound_enabled,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_hotseat", "guide_clue",
                    "guide_guess", "guide_mp",
                }),
            },
        },
        rebuild = BuildSI7SettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SI7"] = BuildSI7SettingsPanel
