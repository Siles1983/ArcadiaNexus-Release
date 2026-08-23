--[[
    Azeroth's Tiny Guardians – Settings Panel
    Layout: Sound | Visuals + Guide via BuildSoundVisualGuide
]]

local GS = ArcadiaNexus.GameSettings

local function BuildATGSettingsPanel(parent)
    local S = ArcadiaNexus.ATG_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("AZEROTHTINYGUARDIANS") or {}

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnInteract", label = L.sound_interact },
                { key = "soundOnEvolve",   label = L.sound_evolve   },
                { key = "soundOnComment",  label = L.sound_comment  },
            },
        },
        visuals = {
            title = L.box_visual,
            items = {
                { key = "showSpeechBubble", label = L.lbl_show_bubbles },
                { key = "showEmotes",       label = L.lbl_show_emotes  },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4",
                    "guide_5", "guide_6", "guide_7", "guide_8",
                }),
            },
        },
        rebuild = BuildATGSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["AZEROTHTINYGUARDIANS"] = BuildATGSettingsPanel
