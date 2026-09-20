--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Themes.lua

    Sechs Azeroth-Energien. type=color nutzt WHITE8X8 + VertexColor.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Themes = {}
local T = ArcadiaNexus.BS_Themes

T.Themes = {
    energies = {
        name = "energies",
        gems = {
            { type = "color", color = { 0.62, 0.28, 0.95 }, label = "Ley" },
            { type = "color", color = { 0.35, 0.90, 0.22 }, label = "Fel" },
            { type = "color", color = { 1.00, 0.88, 0.28 }, label = "Light" },
            { type = "color", color = { 0.35, 0.78, 1.00 }, label = "Frost" },
            { type = "color", color = { 1.00, 0.42, 0.12 }, label = "Ember" },
            { type = "color", color = { 0.42, 0.18, 0.58 }, label = "Void" },
        },
    },
    raidmarker = {
        name = "raidmarker",
        gems = {
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", color = { 1.00, 0.85, 0.00 }, label = "Stern" },
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", color = { 1.00, 0.50, 0.00 }, label = "Kreis" },
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", color = { 0.70, 0.30, 0.90 }, label = "Diamant" },
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", color = { 0.20, 0.80, 0.20 }, label = "Dreieck" },
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", color = { 0.90, 0.90, 1.00 }, label = "Mond" },
            { type = "icon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", color = { 0.20, 0.50, 1.00 }, label = "Quadrat" },
        },
    },
    gems = {
        name = "gems",
        gems = {
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",  color = { 0.70, 0.30, 0.90 }, label = "Amethyst" },
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",   color = { 0.20, 0.80, 0.20 }, label = "Smaragd" },
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_01",     color = { 1.00, 0.84, 0.20 }, label = "Topas" },
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",  color = { 0.20, 0.50, 1.00 }, label = "Saphir" },
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",      color = { 0.90, 0.20, 0.20 }, label = "Rubin" },
            { type = "icon", icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_01",     color = { 0.55, 0.35, 0.70 }, label = "Perle" },
        },
    },
}

function T:GetTheme(themeKey)
    return self.Themes[themeKey] or self.Themes.energies
end

function T:GetGemCount(themeKey)
    return #self:GetTheme(themeKey).gems
end

function T:GetGem(themeKey, gemType)
    local theme = self:GetTheme(themeKey)
    if not gemType or gemType < 1 or gemType > #theme.gems then return nil end
    return theme.gems[gemType]
end

function T:GetPreviewIcons(themeKey)
    local theme = self:GetTheme(themeKey)
    local result = {}
    for i = 1, math.min(6, #theme.gems) do
        result[i] = theme.gems[i]
    end
    return result
end
