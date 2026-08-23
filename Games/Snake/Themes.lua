--[[
    ArcadiaNexus – Snake
    Games/Snake/Themes.lua
    Version: 2.0.0

    Einziges Theme: "tiles"
    Schlangenkörper wird über das Tile-System im Renderer gezeichnet
    (GetSegmentTexture). Das Theme definiert nur noch das Futter-Icon.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Themes = {}
local T = ArcadiaNexus.SNK_Themes

T.THEMES = {
    tiles = {
        name = "Snake",
        -- Kopf und Körper werden vom Tile-System gezeichnet,
        -- head/body werden nicht mehr für Texturen genutzt.
        head = { icon = nil, color = {1, 1, 1} },
        body = { icon = nil, color = {1, 1, 1} },
        -- Futter bleibt Icon-basiert
        food = {
            icon  = "Interface\\Icons\\inv_misc_food_65",
            color = {0.9, 0.5, 0.2},
        },
        eatSound = "earth",
        dieSound = "roar",
    },
}

-- ============================================================
-- Schwierigkeits-Konfiguration (unverändert)
-- ============================================================
T.DIFFICULTY = {
    easy = {
        label      = "Easy",
        gridSize   = 20,
        cellSize   = 20,
        tickRate   = 0.18,
        multiplier = 1,
    },
    normal = {
        label      = "Normal",
        gridSize   = 16,
        cellSize   = 25,
        tickRate   = 0.12,
        multiplier = 2,
    },
    hard = {
        label      = "Hard",
        gridSize   = 10,
        cellSize   = 40,
        tickRate   = 0.07,
        multiplier = 4,
    },
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================
function T:GetTheme(key)
    return self.THEMES["tiles"]  -- immer tiles zurückgeben
end

function T:GetDiff(diffKey)
    return self.DIFFICULTY[diffKey] or self.DIFFICULTY.easy
end

function T:GetThemeList()
    return {
        { key = "tiles", name = self.THEMES.tiles.name },
    }
end
