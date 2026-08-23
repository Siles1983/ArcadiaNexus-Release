--[[
    Mosaic of Azeroth (Sliding Puzzle) – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Schwierigkeits-Info als zweite Guide-Sektion
]]

local GS = ArcadiaNexus.GameSettings

local function BuildSlidingPuzzleSettingsPanel(parent)
    local S = ArcadiaNexus.SLP_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("MOSAICOFAZEROTH")

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnMove", label = L.sound_move },
                { key = "soundOnWin",  label = L.sound_win  },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3",
                    "guide_4", "guide_5", "guide_6",
                }),
                GS.GuideSection(L.box_difficulty, L, {
                    "diff_info_1", "diff_info_2", "diff_info_3", "diff_info_4",
                }, 15),
            },
        },
        rebuild = BuildSlidingPuzzleSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["MOSAICOFAZEROTH"] = BuildSlidingPuzzleSettingsPanel
