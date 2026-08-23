-- ============================================================
--  Tavern Cards – Cards.lua
--  TGA-Pfad-Mapping für Karten und Rückseiten.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Cards = {}
local C = ArcadiaNexus.TC_Cards

local BASE = "Interface\\AddOns\\ArcadiaNexus\\Games\\TavernCards\\assets\\cards\\"

local COLOR_FOLDER = {
    GREEN  = "green",
    BLUE   = "blue",
    RED    = "red",
    YELLOW = "yellow",
}

C.BACK_THEMES = {
    neutral  = BASE .. "cardsback\\bg_neutral",
    alliance = BASE .. "cardsback\\gb_alliance",
    horde    = BASE .. "cardsback\\gb_horde",
}

C.COLOR_RGB = {
    GREEN  = { 0.2, 0.85, 0.3 },
    BLUE   = { 0.2, 0.5, 1.0 },
    RED    = { 0.95, 0.25, 0.2 },
    YELLOW = { 1.0, 0.85, 0.1 },
}

function C:GetCardTexture(card)
    if not card then return nil end
    if card.type == "WILD"  then return BASE .. "special\\wild_choice" end
    if card.type == "WILD4" then return BASE .. "special\\wild_draw4" end
    local folder = COLOR_FOLDER[card.color]
    if not folder then return nil end
    if card.type == "NUMBER"  then return BASE .. folder .. "\\" .. folder .. "_" .. card.value end
    if card.type == "DRAW2"   then return BASE .. "special\\" .. folder .. "_draw2" end
    if card.type == "SKIP"    then return BASE .. "special\\" .. folder .. "_skip" end
    if card.type == "REVERSE" then return BASE .. "special\\" .. folder .. "_reverse" end
    return nil
end

function C:GetCardBackTexture(theme)
    return self.BACK_THEMES[theme] or self.BACK_THEMES.neutral
end
