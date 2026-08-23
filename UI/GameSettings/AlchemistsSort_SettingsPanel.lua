--[[
    AlchemistsSort – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Level-Info als zweite Guide-Sektion
]]

local GS = ArcadiaNexus.GameSettings

local function BuildAlchemistsSortSettingsPanel(parent)
    local S = ArcadiaNexus.ALS_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnPour",    label = L.sound_pour    },
                { key = "soundOnWin",     label = L.sound_win     },
                { key = "soundOnInvalid", label = L.sound_invalid },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                    "guide_5", "guide_6", "guide_7",
                }),
                GS.GuideSection(L.box_level_info, L, {
                    "level_info_1", "level_info_2", "level_info_3",
                    "level_info_4", "level_info_5", "level_info_6",
                }, 15),
            },
        },
        rebuild = BuildAlchemistsSortSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ALCHEMISTSSORT"] = BuildAlchemistsSortSettingsPanel
