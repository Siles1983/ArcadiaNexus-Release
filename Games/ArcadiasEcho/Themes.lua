--[[
    Gaming Hub – Simon Says: Oger-Runen Edition
    Games/ArcadiasEcho/Themes.lua

    Nur Interface\Icons\ und TargetingFrame-Dateien – keine HUD-Atlanten.
    Midnight (Interface 120000) hat UI-HUD-Specialization-* / UI-WorldMarker*
    und readycheck-waiting als Atlas entfernt bzw. umbenannt.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AE_Themes = {}
local T = ArcadiaNexus.AE_Themes

T.THEMES = {

    -- ──────────────────────────────────────────────────────────
    -- 1. Oger-Magi Runen
    -- 01–09: INV_Misc_Rune. Hard: Spell-Icons (rune_10+ und alte DK-IDs fehlen).
    -- ──────────────────────────────────────────────────────────
    runes = {
        name = "Oger-Magi Runen",
        symbols = {
            -- Easy (1-4)
            { name="Rune I",     icon="Interface\\Icons\\INV_Misc_Rune_01", color={0.9,0.7,1.0} },
            { name="Rune II",    icon="Interface\\Icons\\INV_Misc_Rune_02", color={1.0,0.5,0.1} },
            { name="Rune III",   icon="Interface\\Icons\\INV_Misc_Rune_03", color={0.3,0.8,1.0} },
            { name="Rune IV",    icon="Interface\\Icons\\INV_Misc_Rune_04", color={0.2,1.0,0.3} },
            -- Normal (5-9)
            { name="Rune V",     icon="Interface\\Icons\\INV_Misc_Rune_05", color={0.7,0.1,1.0} },
            { name="Rune VI",    icon="Interface\\Icons\\INV_Misc_Rune_06", color={1.0,1.0,0.3} },
            { name="Rune VII",   icon="Interface\\Icons\\INV_Misc_Rune_07", color={1.0,0.9,0.1} },
            { name="Rune VIII",  icon="Interface\\Icons\\INV_Misc_Rune_08", color={1.0,0.4,0.4} },
            { name="Rune IX",    icon="Interface\\Icons\\INV_Misc_Rune_09", color={0.2,0.6,1.0} },
            -- Hard (10-16): nur Icons, die im Addon bereits genutzt werden
            { name="Unheilig",   icon="Interface\\Icons\\Spell_Shadow_RaiseDead",         color={0.9,0.5,1.0} },
            { name="Todesspiral",icon="Interface\\Icons\\Spell_Shadow_DeathCoil",         color={0.5,0.9,1.0} },
            { name="Blut-Rune",  icon="Interface\\Icons\\Spell_Shadow_LifeDrain",         color={0.9,0.1,0.1} },
            { name="Frost-Rune", icon="Interface\\Icons\\Spell_Frost_FrostNova",          color={0.4,0.8,1.0} },
            { name="Tod-Rune",   icon="Interface\\Icons\\Spell_Shadow_ShadowForm",        color={0.5,0.0,0.8} },
            { name="Chaos-Rune", icon="Interface\\Icons\\Spell_Shadow_SummonVoidWalker",  color={0.7,0.2,1.0} },
            { name="Arkan-Rune", icon="Interface\\Icons\\Spell_Arcane_Blast",             color={0.6,0.4,1.0} },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 2. Raid-Marker (E-Sport/Training)
    -- Icons: Interface\TargetingFrame\ sind direkte Dateipfade (kein Atlas!)
    -- ──────────────────────────────────────────────────────────
    raidmarker = {
        name = "Raid-Marker",
        symbols = {
            -- Easy (1-4)
            { name="Stern",      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", color={1.0,0.95,0.1} },
            { name="Kreis",      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", color={1.0,0.5,0.0}  },
            { name="Diamant",    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", color={0.8,0.2,1.0}  },
            { name="Dreieck",    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", color={0.2,0.9,0.2}  },
            -- Normal (5-9)
            { name="Mond",       icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", color={0.4,0.6,1.0}  },
            { name="Quadrat",    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", color={0.6,0.4,1.0}  },
            { name="Kreuz",      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", color={1.0,0.2,0.2}  },
            { name="Totenkopf",  icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", color={0.7,0.7,0.7}  },
            { name="Markieren",  icon="Interface\\Icons\\Ability_Hunter_AimedShot",        color={0.8,0.8,0.5}  },
            -- Hard (10-16)
            { name="Wache",      icon="Interface\\Icons\\Ability_TownWatch",               color={1.0,0.9,0.2}  },
            { name="Horde",      icon="Interface\\Icons\\INV_BannerPVP_01",                color={1.0,0.5,0.1}  },
            { name="Allianz",    icon="Interface\\Icons\\INV_BannerPVP_02",                color={0.3,0.8,1.0}  },
            { name="Karte",      icon="Interface\\Icons\\INV_Misc_Map_01",                 color={0.2,0.9,0.2}  },
            { name="Bombe",      icon="Interface\\Icons\\INV_Misc_Bomb_02",                color={0.8,0.3,1.0}  },
            { name="Ziel",       icon="Interface\\Icons\\Ability_Hunter_SniperShot",       color={1.0,0.2,0.2}  },
            { name="Schild",     icon="Interface\\Icons\\INV_Shield_06",                   color={0.6,0.6,0.6}  },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 3. Elementare Mächte (Natur/Schamanisch)
    -- Alle Icons in WotLK verifiziert
    -- ──────────────────────────────────────────────────────────
    elements = {
        name = "Elementare Mächte",
        symbols = {
            -- Easy (1-4)
            { name="Feuer",      icon="Interface\\Icons\\Spell_Fire_Fire",              color={1.0,0.3,0.0} },
            { name="Frost",      icon="Interface\\Icons\\Spell_Frost_Frost",            color={0.3,0.7,1.0} },
            { name="Erde",       icon="Interface\\Icons\\Spell_Nature_Earthquake",      color={0.8,0.6,0.2} },
            { name="Luft",       icon="Interface\\Icons\\Spell_Nature_Cyclone",         color={0.7,0.9,1.0} },
            -- Normal (5-9)
            { name="Blitz",      icon="Interface\\Icons\\Spell_Nature_Lightning",       color={1.0,0.9,0.1} },
            { name="Lava",       icon="Interface\\Icons\\Spell_Shaman_LavaBurst",       color={1.0,0.5,0.1} },
            { name="Natur",      icon="Interface\\Icons\\Spell_Nature_Rejuvenation",    color={0.2,0.9,0.2} },
            { name="Eis",        icon="Interface\\Icons\\Spell_Frost_FrostArmor02",     color={0.5,0.85,1.0} },
            { name="Geist",      icon="Interface\\Icons\\Spell_Nature_SpiritWolf",      color={0.8,0.7,1.0} },
            -- Hard (10-16)
            { name="Sturm",      icon="Interface\\Icons\\Spell_Nature_LightningOverload", color={0.6,0.8,1.0} },
            { name="Knall",      icon="Interface\\Icons\\Spell_Nature_WispSplode",      color={0.9,1.0,0.5} },
            { name="Donner",     icon="Interface\\Icons\\Spell_Nature_ThunderClap",     color={0.7,0.7,1.0} },
            { name="Eis-Schock", icon="Interface\\Icons\\Spell_Frost_FrostShock",       color={0.3,0.6,1.0} },
            { name="Flamme",     icon="Interface\\Icons\\Spell_Fire_Fireball02",        color={1.0,0.4,0.0} },
            { name="Kette",      icon="Interface\\Icons\\Spell_Nature_ChainLightning",  color={0.9,0.9,0.3} },
            { name="Totem",      icon="Interface\\Icons\\Spell_Nature_StoneSkinTotem",  color={0.6,0.5,0.3} },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 4. Licht & Leere
    -- Spec-Spell-Icons statt UI-HUD-Specialization-Atlanten (Midnight).
    -- ──────────────────────────────────────────────────────────
    lightandshadow = {
        name = "Licht & Leere",
        symbols = {
            -- Easy (1-4) – Spell-Icons statt HUD-Atlanten (Midnight)
            { name="Heilig-Paladin",    icon="Interface\\Icons\\Spell_Holy_HolyBolt",           color={1.0,0.9,0.3} },
            { name="Schatten-Priester", icon="Interface\\Icons\\Spell_Shadow_ShadowWordPain",   color={0.6,0.0,0.9} },
            { name="Gleichgewicht",     icon="Interface\\Icons\\Spell_Nature_StarFall",         color={0.5,0.5,1.0} },
            { name="Arkan-Magier",      icon="Interface\\Icons\\Spell_Arcane_Blast",            color={0.8,0.4,1.0} },
            -- Normal (5-9)
            { name="Heilig-Priester",   icon="Interface\\Icons\\Spell_Holy_Heal",               color={1.0,1.0,0.7} },
            { name="Heimsuchung",       icon="Interface\\Icons\\Spell_Shadow_DeathCoil",        color={0.4,0.8,0.3} },
            { name="Frost-Magier",      icon="Interface\\Icons\\Spell_Frost_FrostBolt02",       color={0.4,0.7,1.0} },
            { name="Feuer-Magier",      icon="Interface\\Icons\\Spell_Fire_Fireball02",         color={1.0,0.4,0.1} },
            { name="Disziplin",         icon="Interface\\Icons\\Spell_Holy_PowerWordShield",    color={0.9,0.7,1.0} },
            -- Hard (10-16)
            { name="Vergeltung",        icon="Interface\\Icons\\Spell_Holy_AuraOfLight",        color={1.0,0.6,0.1} },
            { name="Zerstörung",        icon="Interface\\Icons\\Spell_Shadow_RainOfFire",       color={0.9,0.2,0.2} },
            { name="Blut-DK",           icon="Interface\\Icons\\Spell_Shadow_LifeDrain",        color={0.8,0.1,0.1} },
            { name="Frost-DK",          icon="Interface\\Icons\\Spell_Frost_FrostNova",         color={0.5,0.8,1.0} },
            { name="Unheilig-DK",       icon="Interface\\Icons\\Spell_Shadow_Possession",       color={0.3,0.7,0.2} },
            { name="Wiederherst.",      icon="Interface\\Icons\\Spell_Nature_HealingTouch",     color={0.2,0.9,0.4} },
            { name="Schutz-Paladin",    icon="Interface\\Icons\\Spell_Holy_DevotionAura",       color={0.6,0.7,1.0} },
        },
    },
}

-- ============================================================
-- Schwierigkeits-Konfiguration
-- ============================================================
T.DIFFICULTY = {
    easy   = { grid = 2, startLen = 3, label = "Easy",   maxSpeed = 0.4 },
    normal = { grid = 3, startLen = 3, label = "Normal", maxSpeed = 0.3 },
    hard   = { grid = 4, startLen = 3, label = "Hard",   maxSpeed = 0.2 },
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================
function T:GetTheme(key)
    return self.THEMES[key] or self.THEMES.runes
end

function T:GetSymbolsForDiff(themeKey, diffKey)
    local theme  = self:GetTheme(themeKey)
    local diff   = self.DIFFICULTY[diffKey] or self.DIFFICULTY.easy
    local count  = diff.grid * diff.grid
    local result = {}
    for i = 1, count do
        result[i] = theme.symbols[i] or theme.symbols[#theme.symbols]
    end
    return result
end

function T:GetDiff(diffKey)
    return self.DIFFICULTY[diffKey] or self.DIFFICULTY.easy
end

function T:GetThemeList()
    return {
        { key="runes",          name=self.THEMES.runes.name          },
        { key="raidmarker",     name=self.THEMES.raidmarker.name     },
        { key="elements",       name=self.THEMES.elements.name       },
        { key="lightandshadow", name=self.THEMES.lightandshadow.name },
    }
end
