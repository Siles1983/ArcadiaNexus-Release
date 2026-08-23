--[[
    Nonogram – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildNonogramSettingsPanel(parent)
    local S = ArcadiaNexus.NON_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("NONOGRAM")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            title       = L.box_sound,
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnFill",  label = L.sound_fill  },
                { key = "soundOnMark",  label = L.sound_mark  },
                { key = "soundOnError", label = L.sound_error },
                { key = "soundOnWin",   label = L.sound_win   },
                { key = "soundOnLose",  label = L.sound_lose  },
            },
        },
        guide = {
            title = L.box_guide,
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                    "guide_5", "guide_6", "guide_7", "guide_8",
                }),
            },
        },
        rebuild = BuildNonogramSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["NONOGRAM"] = BuildNonogramSettingsPanel
