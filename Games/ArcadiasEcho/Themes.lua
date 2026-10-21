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
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Oger-Magi Runen" or "Ogre-Mage Runes"),
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
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Unheilig" or "Unholy"),   icon="Interface\\Icons\\Spell_Shadow_RaiseDead",         color={0.9,0.5,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Todesspiral" or "Death Coil"),icon="Interface\\Icons\\Spell_Shadow_DeathCoil",         color={0.5,0.9,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Blut-Rune" or "Blood Rune"),  icon="Interface\\Icons\\Spell_Shadow_LifeDrain",         color={0.9,0.1,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Frost-Rune" or "Frost Rune"), icon="Interface\\Icons\\Spell_Frost_FrostNova",          color={0.4,0.8,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Tod-Rune" or "Death Rune"),   icon="Interface\\Icons\\Spell_Shadow_ShadowForm",        color={0.5,0.0,0.8} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Chaos-Rune" or "Chaos Rune"), icon="Interface\\Icons\\Spell_Shadow_SummonVoidWalker",  color={0.7,0.2,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Arkan-Rune" or "Arcane Rune"), icon="Interface\\Icons\\Spell_Arcane_Blast",             color={0.6,0.4,1.0} },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 2. Raid-Marker (E-Sport/Training)
    -- Icons: Interface\TargetingFrame\ sind direkte Dateipfade (kein Atlas!)
    -- ──────────────────────────────────────────────────────────
    raidmarker = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Raid-Marker" or "Raid Markers"),
        symbols = {
            -- Easy (1-4)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Stern" or "Star"),      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", color={1.0,0.95,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Kreis" or "Circle"),      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", color={1.0,0.5,0.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Diamant" or "Diamond"),    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", color={0.8,0.2,1.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Dreieck" or "Triangle"),    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", color={0.2,0.9,0.2}  },
            -- Normal (5-9)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Mond" or "Moon"),       icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", color={0.4,0.6,1.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Quadrat" or "Square"),    icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", color={0.6,0.4,1.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Kreuz" or "Cross"),      icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", color={1.0,0.2,0.2}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Totenkopf" or "Skull"),  icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", color={0.7,0.7,0.7}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Markieren" or "Mark"),  icon="Interface\\Icons\\Ability_Hunter_AimedShot",        color={0.8,0.8,0.5}  },
            -- Hard (10-16)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Wache" or "Guard"),      icon="Interface\\Icons\\Ability_TownWatch",               color={1.0,0.9,0.2}  },
            { name="Horde",      icon="Interface\\Icons\\INV_BannerPVP_01",                color={1.0,0.5,0.1}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Allianz" or "Alliance"),    icon="Interface\\Icons\\INV_BannerPVP_02",                color={0.3,0.8,1.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Karte" or "Map"),      icon="Interface\\Icons\\INV_Misc_Map_01",                 color={0.2,0.9,0.2}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Bombe" or "Bomb"),      icon="Interface\\Icons\\INV_Misc_Bomb_02",                color={0.8,0.3,1.0}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Ziel" or "Target"),       icon="Interface\\Icons\\Ability_Hunter_SniperShot",       color={1.0,0.2,0.2}  },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Schild" or "Shield"),     icon="Interface\\Icons\\INV_Shield_06",                   color={0.6,0.6,0.6}  },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 3. Elementare Mächte (Natur/Schamanisch)
    -- Alle Icons in WotLK verifiziert
    -- ──────────────────────────────────────────────────────────
    elements = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Elementare Mächte" or "Elemental Powers"),
        symbols = {
            -- Easy (1-4)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Feuer" or "Fire"),      icon="Interface\\Icons\\Spell_Fire_Fire",              color={1.0,0.3,0.0} },
            { name="Frost",      icon="Interface\\Icons\\Spell_Frost_Frost",            color={0.3,0.7,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Erde" or "Earth"),       icon="Interface\\Icons\\Spell_Nature_Earthquake",      color={0.8,0.6,0.2} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Luft" or "Air"),       icon="Interface\\Icons\\Spell_Nature_Cyclone",         color={0.7,0.9,1.0} },
            -- Normal (5-9)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Blitz" or "Lightning"),      icon="Interface\\Icons\\Spell_Nature_Lightning",       color={1.0,0.9,0.1} },
            { name="Lava",       icon="Interface\\Icons\\Spell_Shaman_LavaBurst",       color={1.0,0.5,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Natur" or "Nature"),      icon="Interface\\Icons\\Spell_Nature_Rejuvenation",    color={0.2,0.9,0.2} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Eis" or "Ice"),        icon="Interface\\Icons\\Spell_Frost_FrostArmor02",     color={0.5,0.85,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Geist" or "Spirit"),      icon="Interface\\Icons\\Spell_Nature_SpiritWolf",      color={0.8,0.7,1.0} },
            -- Hard (10-16)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Sturm" or "Storm"),      icon="Interface\\Icons\\Spell_Nature_LightningOverload", color={0.6,0.8,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Knall" or "Blast"),      icon="Interface\\Icons\\Spell_Nature_WispSplode",      color={0.9,1.0,0.5} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Donner" or "Thunder"),     icon="Interface\\Icons\\Spell_Nature_ThunderClap",     color={0.7,0.7,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Eis-Schock" or "Frost Shock"), icon="Interface\\Icons\\Spell_Frost_FrostShock",       color={0.3,0.6,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Flamme" or "Flame"),     icon="Interface\\Icons\\Spell_Fire_Fireball02",        color={1.0,0.4,0.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Kette" or "Chain"),      icon="Interface\\Icons\\Spell_Nature_ChainLightning",  color={0.9,0.9,0.3} },
            { name="Totem",      icon="Interface\\Icons\\Spell_Nature_StoneSkinTotem",  color={0.6,0.5,0.3} },
        },
    },

    -- ──────────────────────────────────────────────────────────
    -- 4. Licht & Leere
    -- Spec-Spell-Icons statt UI-HUD-Specialization-Atlanten (Midnight).
    -- ──────────────────────────────────────────────────────────
    lightandshadow = {
        name = (ArcadiaNexus.ActiveLocale == "deDE" and "Licht & Leere" or "Light & Void"),
        symbols = {
            -- Easy (1-4) – Spell-Icons statt HUD-Atlanten (Midnight)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Heilig-Paladin" or "Holy Paladin"),    icon="Interface\\Icons\\Spell_Holy_HolyBolt",           color={1.0,0.9,0.3} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Schatten-Priester" or "Shadow Priest"), icon="Interface\\Icons\\Spell_Shadow_ShadowWordPain",   color={0.6,0.0,0.9} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Gleichgewicht" or "Balance"),     icon="Interface\\Icons\\Spell_Nature_StarFall",         color={0.5,0.5,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Arkan-Magier" or "Arcane Mage"),      icon="Interface\\Icons\\Spell_Arcane_Blast",            color={0.8,0.4,1.0} },
            -- Normal (5-9)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Heilig-Priester" or "Holy Priest"),   icon="Interface\\Icons\\Spell_Holy_Heal",               color={1.0,1.0,0.7} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Heimsuchung" or "Affliction"),       icon="Interface\\Icons\\Spell_Shadow_DeathCoil",        color={0.4,0.8,0.3} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Frost-Magier" or "Frost Mage"),      icon="Interface\\Icons\\Spell_Frost_FrostBolt02",       color={0.4,0.7,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Feuer-Magier" or "Fire Mage"),      icon="Interface\\Icons\\Spell_Fire_Fireball02",         color={1.0,0.4,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Disziplin" or "Discipline"),         icon="Interface\\Icons\\Spell_Holy_PowerWordShield",    color={0.9,0.7,1.0} },
            -- Hard (10-16)
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Vergeltung" or "Retribution"),        icon="Interface\\Icons\\Spell_Holy_AuraOfLight",        color={1.0,0.6,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Zerstörung" or "Destruction"),        icon="Interface\\Icons\\Spell_Shadow_RainOfFire",       color={0.9,0.2,0.2} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Blut-DK" or "Blood DK"),           icon="Interface\\Icons\\Spell_Shadow_LifeDrain",        color={0.8,0.1,0.1} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Frost-DK" or "Frost DK"),          icon="Interface\\Icons\\Spell_Frost_FrostNova",         color={0.5,0.8,1.0} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Unheilig-DK" or "Unholy DK"),       icon="Interface\\Icons\\Spell_Shadow_Possession",       color={0.3,0.7,0.2} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Wiederherst." or "Restoration"),      icon="Interface\\Icons\\Spell_Nature_HealingTouch",     color={0.2,0.9,0.4} },
            { name=(ArcadiaNexus.ActiveLocale == "deDE" and "Schutz-Paladin" or "Protection Paladin"),    icon="Interface\\Icons\\Spell_Holy_DevotionAura",       color={0.6,0.7,1.0} },
        },
    },
}

-- ============================================================
-- Schwierigkeits-Konfiguration
-- ============================================================
T.DIFFICULTY = {
    easy   = { grid = 2, startLen = 1, label = "Easy",   maxSpeed = 0.4 },
    normal = { grid = 3, startLen = 1, label = "Normal", maxSpeed = 0.3 },
    hard   = { grid = 4, startLen = 1, label = "Hard",   maxSpeed = 0.2 },
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
