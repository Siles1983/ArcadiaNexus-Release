--[[
    Reaction Strike – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildReactionStrikeSettingsPanel(parent)
    local S = ArcadiaNexus.RS_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("REACTIONSTRIKE")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnSignal",  label = L.sound_signal  },
                { key = "soundOnStrike",  label = L.sound_strike  },
                { key = "soundOnPenalty", label = L.sound_penalty },
                { key = "soundOnResult",  label = L.sound_result  },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4", "guide_5" }),
            },
        },
        rebuild = BuildReactionStrikeSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["REACTIONSTRIKE"] = BuildReactionStrikeSettingsPanel
