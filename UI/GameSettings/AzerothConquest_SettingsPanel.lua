--[[
    Azeroth Conquest – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    KI-Schwierigkeit als zweite Guide-Sektion
]]

local GS = ArcadiaNexus.GameSettings

local function BuildAzerothConquestSettingsPanel(parent)
    local S = ArcadiaNexus.AC_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            footer      = L.sound_hint,
            items = {
                { key = "soundOnHit",  label = L.sound_hit  },
                { key = "soundOnMiss", label = L.sound_miss },
                { key = "soundOnSunk", label = L.sound_sunk },
                { key = "soundOnWin",  label = L.sound_win  },
                { key = "soundOnLoss", label = L.sound_loss },
            },
        },
        guide = {
            minHeight = 220,
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                    "guide_5", "guide_6", "guide_7",
                }),
                {
                    title = L.box_difficulty,
                    lines = {
                        L.info_classic_title, L.info_classic_text, " ",
                        L.info_pro_title, L.info_pro_text1, L.info_pro_text2, L.info_pro_text3, " ",
                        L.info_insane_title, L.info_insane_text1, L.info_insane_text2,
                        L.info_insane_text3, L.info_insane_text4,
                        L.hint_diff_panel,
                    },
                    lineSpacing = 15,
                },
            },
        },
        rebuild = BuildAzerothConquestSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["AZEROTHCONQUEST"] = BuildAzerothConquestSettingsPanel
