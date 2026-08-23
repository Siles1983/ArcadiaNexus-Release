-- ============================================================
--  Tavern Cards – Deck.lua
--  108-Karten-UNO-Deck, Mischen, Ziehen.
--  Kein UI, kein Timer.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Deck = {}
local D = ArcadiaNexus.TC_Deck

local COLORS = { "GREEN", "BLUE", "RED", "YELLOW" }
local _nextId = 0

local function NewCard(color, cardType, value, points)
    _nextId = _nextId + 1
    return {
        id     = _nextId,
        color  = color,
        type   = cardType,
        value  = value,
        points = points or 0,
    }
end

function D:ResetIdCounter()
    _nextId = 0
end

function D:BuildDeck()
    self:ResetIdCounter()
    local deck = {}

    for _, color in ipairs(COLORS) do
        table.insert(deck, NewCard(color, "NUMBER", 0, 0))
        for n = 1, 9 do
            table.insert(deck, NewCard(color, "NUMBER", n, n))
            table.insert(deck, NewCard(color, "NUMBER", n, n))
        end
        table.insert(deck, NewCard(color, "DRAW2",    nil, 20))
        table.insert(deck, NewCard(color, "DRAW2",    nil, 20))
        table.insert(deck, NewCard(color, "SKIP",     nil, 20))
        table.insert(deck, NewCard(color, "SKIP",     nil, 20))
        table.insert(deck, NewCard(color, "REVERSE",  nil, 20))
        table.insert(deck, NewCard(color, "REVERSE",  nil, 20))
    end

    for _ = 1, 4 do
        table.insert(deck, NewCard("WILD", "WILD",  nil, 50))
        table.insert(deck, NewCard("WILD", "WILD4", nil, 50))
    end

    return deck
end

function D:Shuffle(deck)
    return ArcadiaNexus.ArrayUtils.Shuffle(deck)
end

function D:Draw(deck)
    if not deck or #deck == 0 then return nil end
    return table.remove(deck, 1)
end

function D:DrawN(deck, n)
    local drawn = {}
    for _ = 1, n do
        local c = self:Draw(deck)
        if not c then break end
        drawn[#drawn + 1] = c
    end
    return drawn
end

function D:RecycleDiscardIntoDraw(drawPile, discardPile, keepTop)
    if #drawPile > 0 or #discardPile <= 1 then return end
    local top = keepTop or discardPile[#discardPile]
    while #discardPile > 1 do
        table.insert(drawPile, table.remove(discardPile, 1))
    end
    self:Shuffle(drawPile)
end
