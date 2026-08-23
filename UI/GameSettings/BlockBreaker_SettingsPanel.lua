--[[
    BlockBreaker – Settings Panel
    Layout: Sound | Visuals + Theme-Zeile + Guide via BuildSoundVisualGuide
]]

local GS = ArcadiaNexus.GameSettings

local function BuildBlockBreakerSettingsPanel(parent)
    local S = ArcadiaNexus.BB_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("BLOCKBREAKER")

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnBounce",   label = L.sound_bounce   },
                { key = "soundOnBreak",    label = L.sound_break    },
                { key = "soundOnPowerUp",  label = L.sound_powerup  },
                { key = "soundOnLifeLost", label = L.sound_lifelost },
                { key = "soundOnWin",      label = L.sound_win      },
                { key = "soundOnLose",     label = L.sound_lose     },
            },
        },
        visuals = {
            items = {
                { key = "screenFlash", label = L.lbl_screen_flash },
            },
        },
        theme = {
            height = 80,
            dropdown = {
                label   = "",
                key     = "theme",
                options = {
                    { key = "random",  label = L.theme_random  },
                    { key = "blue",    label = L.theme_blue    },
                    { key = "green",   label = L.theme_green   },
                    { key = "red",     label = L.theme_red     },
                    { key = "violett", label = L.theme_violett },
                    { key = "yellow",  label = L.theme_yellow  },
                },
                onChange = function()
                    local R = ArcadiaNexus.BB_Renderer
                    if R and R.ApplyTheme then R:ApplyTheme() end
                end,
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_4", "guide_5", "guide_6" }),
            },
        },
        rebuild = BuildBlockBreakerSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["BLOCKBREAKER"] = BuildBlockBreakerSettingsPanel
