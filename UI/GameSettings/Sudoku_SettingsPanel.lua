--[[
    Sudoku – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Schwierigkeits-Info ist der Guide-Inhalt (kein separates Spielanleitungs-Box)
]]

local GS = ArcadiaNexus.GameSettings

local function BuildSudokuSettingsPanel(parent)
    local S = ArcadiaNexus.SDK_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SUDOKU")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            footer      = L.sound_hint,
            items = {
                { key = "soundOnPlace",    label = L.sound_place    },
                { key = "soundOnError",    label = L.sound_error    },
                { key = "soundOnComplete", label = L.sound_complete },
            },
        },
        guide = {
            title     = L.box_difficulty,
            minHeight = 200,
            sections = {
                {
                    lines = {
                        L.info_easy_title, L.info_easy_text1, L.info_easy_text2, " ",
                        L.info_normal_title, L.info_normal_text1, L.info_normal_text2, " ",
                        L.info_hard_title, L.info_hard_text1, L.info_hard_text2, L.info_hard_text3,
                    },
                    lineSpacing = 15,
                },
            },
        },
        rebuild = BuildSudokuSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SUDOKU"] = BuildSudokuSettingsPanel
