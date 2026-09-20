--[[
    ArcadiaNexus – Bubble Shooter
    UI/GameSettings/BubbleShooter_SettingsPanel.lua
    Layout: Sound | Visuals + Theme + Guide (wie BlockBreaker)
]]

local GS = ArcadiaNexus.GameSettings

local function BuildBubbleShooterSettingsPanel(parent)
    local S = ArcadiaNexus.BS_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("BUBBLESHOOTER")

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 24,
            items = {
                { key = "soundOnShoot",      label = L.sound_shoot },
                { key = "soundOnPop",        label = L.sound_pop },
                { key = "soundOnDrop",       label = L.sound_drop },
                { key = "soundOnPower",      label = L.sound_power },
                { key = "soundOnOvercharge", label = L.sound_overcharge },
                { key = "soundOnWin",        label = L.sound_win },
                { key = "soundOnLose",       label = L.sound_lose },
            },
        },
        visuals = {
            items = {
                { key = "screenFlash", label = L.lbl_screen_flash },
                { key = "colorblind",  label = L.lbl_colorblind },
            },
        },
        theme = {
            height = 88,
            dropdown = {
                label = L.box_theme or "",
                key   = "theme",
                options = {
                    { key = "energies",   label = L.theme_energies },
                    { key = "raidmarker", label = L.theme_raidmarker },
                    { key = "gems",       label = L.theme_gems },
                },
                onChange = function()
                    local R = ArcadiaNexus.BS_Renderer
                    local E = ArcadiaNexus.BS_Engine
                    if R and E and E.gameState and R.SyncBoard then
                        R:SyncBoard(E.gameState)
                    end
                end,
            },
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_aim", "guide_modes", "guide_combo",
                    "guide_power", "guide_over", "guide_drop", "guide_color", "guide_slots",
                }),
            },
        },
        rebuild = BuildBubbleShooterSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["BUBBLESHOOTER"] = BuildBubbleShooterSettingsPanel
