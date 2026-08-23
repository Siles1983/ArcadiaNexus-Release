--[[
    ArcadiaNexus – Barrel Brawl
    UI/GameSettings/BarrelBrawl_SettingsPanel.lua
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
]]

local GS = ArcadiaNexus.GameSettings

local function BuildBarrelBrawlSettingsPanel(parent)
    local S = ArcadiaNexus.BRB_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("BARREL_BRAWL")

    GS.Build(parent, {
        settings = S,
        locale   = L,
        layout   = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnScore", label = L.sound_score },
                { key = "soundOnHit",   label = L.sound_hit   },
                { key = "soundOnWin",   label = L.sound_win   },
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_controls", "guide_barrels",
                    "guide_jump", "guide_bonus", "guide_levels", "guide_diff",
                }),
            },
        },
        rebuild = BuildBarrelBrawlSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["BARREL_BRAWL"] = BuildBarrelBrawlSettingsPanel
