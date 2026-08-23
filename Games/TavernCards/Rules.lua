-- ============================================================
--  Tavern Cards – Rules.lua
--  UNO-Regelprüfung, Sonderkarten, Stapeln, Punkte.
--  Kein UI, kein Timer.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Rules = {}
local R = ArcadiaNexus.TC_Rules

function R:GetTopCard(gs)
    return gs.discardPile[#gs.discardPile]
end

function R:GetActiveColor(gs)
    return gs.activeColor or (self:GetTopCard(gs) and self:GetTopCard(gs).color)
end

function R:IsWildType(card)
    return card and (card.type == "WILD" or card.type == "WILD4")
end

function R:CanPlay(card, gs)
    if not card or not gs then return false end
    local top = self:GetTopCard(gs)
    if not top then return true end

    if gs.pendingDraw and gs.pendingDraw > 0 then
        if gs.pendingType == "DRAW2" then
            return gs.rules.stackDraw2 and card.type == "DRAW2"
        end
        if gs.pendingType == "WILD4" then
            return gs.rules.stackDraw4 and card.type == "WILD4"
        end
        return false
    end

    if self:IsWildType(card) then return true end

    local active = self:GetActiveColor(gs)
    if card.color == active then return true end
    if card.type == top.type and card.type ~= "NUMBER" then return true end
    if card.type == "NUMBER" and top.type == "NUMBER" and card.value == top.value then
        return true
    end
    return false
end

function R:GetPlayableCards(hand, gs)
    local list = {}
    for i, card in ipairs(hand) do
        if self:CanPlay(card, gs) then
            list[#list + 1] = { index = i, card = card }
        end
    end
    return list
end

function R:HasPlayableCard(hand, gs)
    return #self:GetPlayableCards(hand, gs) > 0
end

function R:HandPoints(hand)
    local total = 0
    for _, card in ipairs(hand) do
        total = total + (card.points or 0)
    end
    return total
end

function R:ApplyCardEffect(gs, card, chosenColor)
    gs.lastPlayedBy = gs.currentPlayer

    if card.type == "NUMBER" then
        gs.activeColor = card.color
    elseif card.type == "DRAW2" then
        gs.activeColor = card.color
        gs.pendingDraw = (gs.pendingDraw or 0) + 2
        gs.pendingType = "DRAW2"
    elseif card.type == "SKIP" then
        gs.activeColor = card.color
        gs.skipNext = (gs.skipNext or 0) + 1
    elseif card.type == "REVERSE" then
        gs.activeColor = card.color
        if gs.playerCount == 2 then
            gs.skipNext = (gs.skipNext or 0) + 1
        else
            gs.direction = -(gs.direction or 1)
        end
    elseif card.type == "WILD" then
        if chosenColor then gs.activeColor = chosenColor end
    elseif card.type == "WILD4" then
        if chosenColor then gs.activeColor = chosenColor end
        if chosenColor then
            gs.pendingDraw = (gs.pendingDraw or 0) + 4
            gs.pendingType = "WILD4"
            gs.wild4PlayedBy = gs.currentPlayer
            gs.wild4Challengable = gs.rules.challengeDraw4
        end
    end

    gs.stats = gs.stats or {}
    if card.type == "WILD4" and gs.currentPlayer == 1 then
        gs.stats.wild4Played = (gs.stats.wild4Played or 0) + 1
    end
end

function R:PlayerHadPlayableBeforeWild4(gs, playerIndex)
    local ctx = gs.wild4Context
    if not ctx or ctx.playerIndex ~= playerIndex then return false end
    for _, card in ipairs(ctx.handSnapshot or {}) do
        if card.color == ctx.activeColorBefore and not self:IsWildType(card) then
            return true
        end
        if card.type == "NUMBER" and ctx.topCard
        and ctx.topCard.type == "NUMBER" and card.value == ctx.topCard.value then
            return true
        end
        if ctx.topCard and card.type == ctx.topCard.type and card.type ~= "NUMBER" then
            return true
        end
    end
    return false
end

function R:ResolveChallenge(gs, challengerWins)
    local drawer = gs.wild4PlayedBy
    local challenger = gs.currentPlayer
    if challengerWins then
        gs.pendingDraw = 4
        gs.pendingType = "PENALTY"
        gs.forceDrawPlayer = drawer
    else
        gs.pendingDraw = 6
        gs.pendingType = "PENALTY"
        gs.forceDrawPlayer = challenger
    end
    gs.wild4Challengable = false
    gs.wild4Context = nil
end

function R:NextPlayerIndex(gs, steps)
    steps = steps or 1
    local n = gs.playerCount
    local idx = gs.currentPlayer
    local dir = gs.direction or 1
    for _ = 1, steps do
        idx = idx + dir
        if idx > n then idx = 1 end
        if idx < 1 then idx = n end
    end
    return idx
end
