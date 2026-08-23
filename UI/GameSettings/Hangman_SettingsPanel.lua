--[[
    Hangman – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildHangmanSettingsPanel(parent)
    local S = ArcadiaNexus.HGM_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("HANGMAN")

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
                    "guide_goal", "guide_input", "guide_error",
                    "guide_lose", "guide_hint",
                }),
            },
        },
        rebuild = BuildHangmanSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["HANGMAN"] = BuildHangmanSettingsPanel
