-- ============================================================
--  AlchemistsSort – Colors.lua
--  Farb-Definitionen: ID → { r, g, b }
--  Kein Atlas – reine SetVertexColor-Farben auf WHITE8X8-Layern.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Colors = {}
local C = ArcadiaNexus.ALS_Colors

-- Geordnete Palette (Index = Reihenfolge der Einführung je Level-Bereich)
C.PALETTE = { "RED", "BLUE", "GREEN", "YELLOW", "PURPLE", "ORANGE", "CYAN", "PINK" }

-- RGB-Tabellen
C.RED    = { 0.90, 0.15, 0.15 }
C.BLUE   = { 0.15, 0.40, 0.90 }
C.GREEN  = { 0.15, 0.75, 0.25 }
C.YELLOW = { 0.95, 0.85, 0.10 }
C.PURPLE = { 0.65, 0.15, 0.85 }
C.ORANGE = { 0.95, 0.50, 0.10 }
C.CYAN   = { 0.10, 0.85, 0.90 }
C.PINK   = { 0.95, 0.40, 0.70 }

-- Highlight-Farbe (ausgewählte Flasche, aufgehellte Version)
C.SELECTED_ALPHA   = 0.85   -- Bottle-Overlay Alpha wenn ausgewählt
C.NORMAL_ALPHA     = 0.55   -- Bottle-Overlay Alpha normal
C.SOLVED_ALPHA     = 0.70   -- Bottle-Overlay Alpha wenn gelöst

-- Shade-Farbe für Tipp-Highlight
C.HINT_COLOR = { 1.0, 1.0, 0.0 }  -- gelb
C.HINT_ALPHA = 0.60

-- Shake-Farbe für ungültigen Zug
C.SHAKE_COLOR = { 1.0, 0.2, 0.2 }  -- rot

-- Lookup: colorID → RGB
function C:Get(colorID)
    return C[colorID] or { 0.5, 0.5, 0.5 }
end

-- Anzahl Farben für einen Level-Bereich
function C:GetColorCount(levelNum)
    if levelNum <= 5  then return 3
    elseif levelNum <= 15 then return 4
    elseif levelNum <= 30 then return 5
    elseif levelNum <= 50 then return 6
    elseif levelNum <= 75 then return 7
    else                       return 8
    end
end

-- Farb-Subset für gegebene Anzahl (ersten N aus Palette)
function C:GetPalette(n)
    local result = {}
    for i = 1, math.min(n, #C.PALETTE) do
        result[i] = C.PALETTE[i]
    end
    return result
end
