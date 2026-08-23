-- ============================================================
--  Match3 – Themes.lua
--  v1.1.0
--
--  Raid-Marker: type="icon" mit Interface\\TargetingFrame\\UI-RaidTargetingIcon_N
--  KEIN Atlas! Diese Icons sind direkte Dateipfade, keine Atlas-Einträge.
--  Verifiziert: Interface\\TargetingFrame\\ ist im Midnight-Client zugänglich
--  (UI-StatusBar wird von ArcadiaNexus_UI.lua erfolgreich genutzt).
--
--  Alle anderen Themes nutzen type="icon" mit vollständigen
--  Interface\\Icons\\ Pfaden (funktioniert garantiert seit Vanilla).
--
--  type="atlas" → tex:SetAtlas(name, false) direkt (kein GetAtlasInfo)
--  type="icon"  → SetTexture() direkt
--  type="color" → WHITE8X8 + SetVertexColor (Classic-Theme)
-- ============================================================

ArcadiaNexus.M3_Themes = {}
local T = ArcadiaNexus.M3_Themes

T.Themes = {

    -- ── 1. Raid-Marker ────────────────────────────────────────
    -- Zuordnung: 1=Stern, 2=Kreis, 3=Diamant, 4=Dreieck,
    --            5=Mond,  6=Quadrat, 7=Kreuz, 8=Totenkopf
raidmarker = {
        name = "raidmarker",
        gems = {
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", color={1.00,0.85,0.00}, label="Stern"     },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", color={1.00,0.50,0.00}, label="Kreis"     },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", color={0.70,0.30,0.90}, label="Diamant"   },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", color={0.20,0.80,0.20}, label="Dreieck"   },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", color={0.90,0.90,1.00}, label="Mond"      },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", color={0.20,0.50,1.00}, label="Quadrat"   },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", color={0.90,0.20,0.20}, label="Kreuz"     },
            { type="icon", icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", color={1.00,1.00,1.00}, label="Totenkopf" },
        },
    },

    -- ── 2. Berufe ─────────────────────────────────────────────
    -- type="icon" mit vollständigen Interface\\Icons\\ Pfaden
    -- Alle Trade_* Icons existieren seit Vanilla garantiert
    professions = {
        name = "professions",
        gems = {
            { type="icon", icon="Interface\\Icons\\Trade_BlackSmithing", color={0.80,0.70,0.60}, label="Schmied"  },
            { type="icon", icon="Interface\\Icons\\Trade_Alchemy",       color={0.60,0.90,0.50}, label="Alchemie" },
            { type="icon", icon="Interface\\Icons\\Trade_Engineering",   color={0.70,0.70,0.80}, label="Ingenier" },
            { type="icon", icon="Interface\\Icons\\Trade_Herbalism",     color={0.30,0.80,0.30}, label="Kräuter"  },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Food_15",    color={0.90,0.70,0.40}, label="Kochen"   },
            { type="icon", icon="Interface\\Icons\\Trade_Fishing",       color={0.40,0.70,0.90}, label="Angeln"   },
            { type="icon", icon="Interface\\Icons\\Trade_Mining",        color={0.50,0.50,0.50}, label="Bergbau"   },
            { type="icon", icon="Interface\\Icons\\Trade_LeatherWorking",color={0.60,0.40,0.20}, label="Lederer"   },
        },
    },

    -- ── 3. Ressourcen ─────────────────────────────────────────
    -- Klassische INV_Misc Icons, alle seit Vanilla vorhanden
    resources = {
        name = "resources",
        gems = {
            { type="icon", icon="Interface\\Icons\\INV_Misc_Coin_01",              color={1.00,0.85,0.00}, label="Gold"    },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Ruby_01",          color={0.90,0.20,0.20}, label="Rubin"   },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Sapphire_01",      color={0.20,0.50,1.00}, label="Saphir"  },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Emerald_01",       color={0.20,0.80,0.20}, label="Smaragd" },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Amethyst_01",      color={0.70,0.30,0.90}, label="Amethys" },
            { type="icon", icon="Interface\\Icons\\INV_Ore_Copper_01",             color={0.80,0.50,0.20}, label="Erz"     },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Diamond_01",       color={0.00,0.90,0.90}, label="Diamant"     },
            { type="icon", icon="Interface\\Icons\\INV_Misc_Gem_Pearl_01",         color={0.90,0.90,0.90}, label="Perle"     },
        },
    },

    -- ── 4. Fähigkeiten ────────────────────────────────────────
    -- Spell_* und Ability_* Icons, klassisch und stabil
    abilities = {
        name = "abilities",
        gems = {
            { type="icon", icon="Interface\\Icons\\Ability_Defend",             color={0.30,0.60,1.00}, label="Tank"   },
            { type="icon", icon="Interface\\Icons\\Spell_Holy_Heal",            color={0.20,0.90,0.40}, label="Heal"   },
            { type="icon", icon="Interface\\Icons\\Ability_Rogue_Eviscerate",   color={0.90,0.20,0.20}, label="DPS"    },
            { type="icon", icon="Interface\\Icons\\Spell_Fire_FlameBolt",       color={1.00,0.50,0.00}, label="Feuer"  },
            { type="icon", icon="Interface\\Icons\\Spell_Frost_FrostBolt02",    color={0.40,0.80,1.00}, label="Frost"  },
            { type="icon", icon="Interface\\Icons\\Spell_Shadow_DeathCoil",     color={0.60,0.20,0.80}, label="Shadow" },
            { type="icon", icon="Interface\\Icons\\Spell_Nature_Lightning",     color={1.00,0.90,0.20}, label="Natur"  },
            { type="icon", icon="Interface\\Icons\\Spell_Holy_HolyGuidance",    color={1.00,0.95,0.70}, label="Heilig"  },
        },
    },

    -- ── 5. Klassisch (farbige Zellen) ─────────────────────────
    -- Kein Icon/Atlas, nur WHITE8X8 + Farbe (immer verfügbar)
    classic = {
        name = "classic",
        gems = {
            { type="color", color={0.90, 0.20, 0.20}, label="Rot"    },
            { type="color", color={0.20, 0.80, 0.20}, label="Grün"   },
            { type="color", color={0.20, 0.50, 1.00}, label="Blau"   },
            { type="color", color={1.00, 0.85, 0.00}, label="Gelb"   },
            { type="color", color={0.80, 0.30, 0.90}, label="Lila"   },
            { type="color", color={0.20, 0.85, 0.85}, label="Cyan"   },
            { type="color", color={1.00, 0.55, 0.10}, label="Orange" },
        },
    },
}

-- ── API ──────────────────────────────────────────────────────
function T:GetTheme(themeKey)
    return self.Themes[themeKey] or self.Themes.raidmarker
end

function T:GetGemCount(themeKey)
    local theme = self:GetTheme(themeKey)
    return #theme.gems
end

function T:GetGem(themeKey, gemType)
    local theme = self:GetTheme(themeKey)
    if not gemType or gemType < 1 or gemType > #theme.gems then return nil end
    return theme.gems[gemType]
end

-- Gibt bis zu 8 Gems für SettingsPanel-Vorschau zurück
function T:GetPreviewIcons(themeKey)
    local theme = self:GetTheme(themeKey)
    local result = {}
    for i = 1, math.min(8, #theme.gems) do
        result[i] = theme.gems[i]
    end
    return result
end
