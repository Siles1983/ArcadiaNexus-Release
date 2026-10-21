--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Themes.lua
    Alle 3 Themes + Feedback-Peg-Icons.
    Alle Icon-Pfade im Format "Interface\\Icons\\Name" (bewährt aus Memory).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Themes = {}
local T = ArcadiaNexus.CB_Themes

-- ============================================================
-- Themes
-- Jedes Symbol hat: icon, color (RGB 0-1), name
-- ============================================================
T.THEMES = {
    gems = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Juwelenschleifer" or "Jewelcrafting"),
        symbols = {
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Rubin" or "Ruby"),    icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",       color = { 1.0, 0.1, 0.1 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Saphir" or "Sapphire"),   icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",   color = { 0.1, 0.5, 1.0 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Smaragd" or "Emerald"),  icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",    color = { 0.1, 1.0, 0.2 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Topas" or "Topaz"),    icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_01",      color = { 1.0, 0.9, 0.0 } },
            { name = "Amethyst", icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",   color = { 0.8, 0.2, 1.0 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Bernstein" or "Amber"),icon = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01", color = { 1.0, 0.5, 0.0 } },
        },
    },
    elements = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Elementar" or "Elemental"),
        symbols = {
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Feuer" or "Fire"),   icon = "Interface\\Icons\\Spell_Fire_Fireball",           color = { 1.0, 0.3, 0.0 } },
            { name = "Frost",   icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",       color = { 0.3, 0.7, 1.0 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Natur" or "Nature"),   icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",  color = { 0.1, 1.0, 0.2 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Heilig" or "Holy"),  icon = "Interface\\Icons\\Spell_Holy_HolyBolt",          color = { 1.0, 1.0, 0.3 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Schatten" or "Shadow"),icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",       color = { 0.7, 0.1, 1.0 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Arkan" or "Arcane"),   icon = "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",    color = { 1.0, 0.4, 0.9 } },
        },
    },
    professions = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Berufe" or "Professions"),
        symbols = {
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Alchemie" or "Alchemy"),        icon = "Interface\\Icons\\Trade_Alchemy",         color = { 0.5, 1.0, 0.2 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Schmiedekunst" or "Blacksmithing"),   icon = "Interface\\Icons\\Trade_BlackSmithing",   color = { 0.7, 0.7, 0.8 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Ingenieurwesen" or "Engineering"),  icon = "Interface\\Icons\\Trade_Engineering",     color = { 1.0, 0.8, 0.1 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Kräuterkunde" or "Herbalism"),    icon = "Interface\\Icons\\Trade_Herbalism",       color = { 0.2, 0.9, 0.3 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Bergbau" or "Mining"),         icon = "Interface\\Icons\\Trade_Mining",          color = { 0.8, 0.5, 0.2 } },
            { name = (ArcadiaNexus.ActiveLocale == "deDE" and "Lederverarbeitung" or "Leatherworking"),icon = "Interface\\Icons\\Trade_LeatherWorking", color = { 0.9, 0.6, 0.3 } },
        },
    },
}

-- ============================================================
-- Feedback-Pegs (Treffer / Teiltreffer / Leer)
-- Exakt    = Diamant (weiß) – richtige Farbe, richtige Position
-- Partial  = Perle (grau)   – richtige Farbe, falsche Position
-- Empty    = leerer Slot
-- ============================================================
T.PEGS = {
    exact   = { icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_01", color = { 1.0, 1.0, 1.0 } },
    partial = { icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_01",   color = { 0.6, 0.6, 0.6 } },
    empty   = { icon = nil, color = { 0.2, 0.2, 0.2 } },
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================
function T:GetTheme(key)
    return self.THEMES[key] or self.THEMES.gems
end

function T:GetSymbol(themeKey, symbolIdx)
    local theme = self:GetTheme(themeKey)
    return theme.symbols[symbolIdx]
end

function T:GetSymbolCount(themeKey)
    local theme = self:GetTheme(themeKey)
    return #theme.symbols
end

function T:GetThemeList()
    return {
        { key = "gems",        name = self.THEMES.gems.name        },
        { key = "elements",    name = self.THEMES.elements.name    },
        { key = "professions", name = self.THEMES.professions.name },
    }
end
