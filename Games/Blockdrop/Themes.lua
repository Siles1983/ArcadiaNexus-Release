-- Blockdrop – Games/Blockdrop/Themes.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.BLD_Themes = {}
local T = ArcadiaNexus.BLD_Themes

-- ============================================================
-- THEME 1: Klassisch
-- ============================================================
T["CLASSIC"] = {
    I = { r=0.00, g=0.90, b=0.90 },
    O = { r=0.90, g=0.90, b=0.00 },
    T = { r=0.70, g=0.00, b=0.90 },
    L = { r=0.90, g=0.50, b=0.00 },
    J = { r=0.00, g=0.20, b=0.90 },
    S = { r=0.00, g=0.80, b=0.10 },
    Z = { r=0.90, g=0.10, b=0.10 },
}

-- ============================================================
-- THEME 2: Klassen-Farben
-- ============================================================
T["CLASSCOLORS"] = {
    I = { r=0.247, g=0.780, b=0.922 },  -- Magier
    O = { r=0.780, g=0.612, b=0.431 },  -- Krieger
    T = { r=0.529, g=0.529, b=0.929 },  -- Hexenmeister
    L = { r=0.961, g=0.549, b=0.729 },  -- Paladin
    J = { r=0.000, g=0.439, b=0.871 },  -- Schamane
    S = { r=1.000, g=0.490, b=0.039 },  -- Druide
    Z = { r=1.000, g=0.961, b=0.412 },  -- Schurke
}

-- ============================================================
-- THEME 3: Raid-Marker (direkte Icon-Pfade – kein Atlas!)
-- Interface\TargetingFrame\ ist zugänglich seit Vanilla
-- ============================================================
T["RAIDMARKER"] = {
    I = { r=1.00, g=0.92, b=0.05, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },  -- Stern
    O = { r=1.00, g=0.50, b=0.00, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },  -- Kreis
    T = { r=0.80, g=0.20, b=1.00, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },  -- Diamant
    L = { r=0.20, g=0.90, b=0.20, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },  -- Dreieck
    J = { r=0.40, g=0.60, b=1.00, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },  -- Mond
    S = { r=1.00, g=0.20, b=0.20, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },  -- Kreuz
    Z = { r=0.70, g=0.70, b=0.70, icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },  -- Totenkopf
}

-- ============================================================
-- THEME 4: Berufe / Reagents & Crafting
-- ============================================================
T["REAGENTS"] = {
    I = { r=0.75, g=0.75, b=0.80, icon="Interface\\Icons\\INV_Ore_Thorium_01"      },
    O = { r=0.85, g=0.60, b=0.10, icon="Interface\\Icons\\INV_Ingot_09"             },
    T = { r=0.60, g=0.85, b=0.40, icon="Interface\\Icons\\INV_Misc_Herb_16"         },
    L = { r=0.50, g=0.30, b=0.15, icon="Interface\\Icons\\INV_Misc_LeatherScrap_02" },
    J = { r=0.20, g=0.70, b=0.90, icon="Interface\\Icons\\INV_Potion_92"            },
    S = { r=0.90, g=0.20, b=0.20, icon="Interface\\Icons\\INV_Misc_Gem_Ruby_01"     },
    Z = { r=0.90, g=0.85, b=0.10, icon="Interface\\Icons\\INV_Misc_Gem_Topaz_01"   },
}

-- ============================================================
-- Theme-Liste fuer Dropdown
-- ============================================================
T.LIST = {
    { id="CLASSIC",     label="Klassisch"         },
    { id="CLASSCOLORS", label="Klassen-Farben"    },
    { id="RAIDMARKER",  label="Raid-Marker"       },
    { id="REAGENTS",    label="Berufe / Reagents" },
}

function T:Get(themeID)
    return self[themeID] or self["CLASSIC"]
end

-- Gibt true zurueck wenn Theme Icon- oder Atlas-Rendering nutzt
function T:HasIcons(themeID)
    local theme = self:Get(themeID)
    for _, v in pairs(theme) do
        if type(v) == "table" and (v.icon or v.atlas) then return true end
    end
    return false
end
