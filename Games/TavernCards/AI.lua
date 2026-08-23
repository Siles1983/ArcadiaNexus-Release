-- ============================================================
--  Tavern Cards – AI.lua
--  Easy / Normal / Hard KI — keine UI, kein Timer.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_AI = {}
local AI = ArcadiaNexus.TC_AI

local COLORS = { "GREEN", "BLUE", "RED", "YELLOW" }

local TIMING = {
    easy   = { think = { 0.5, 1.0 }, play = 0.3, draw = 0.4 },
    normal = { think = { 0.8, 1.5 }, play = 0.3, draw = 0.5 },
    hard   = { think = { 1.5, 2.5 }, play = 0.3, draw = 0.5 },
}

function AI:GetDelay(difficulty, phase)
    local t = TIMING[difficulty] or TIMING.normal
    local range = t[phase] or { 0.5, 1.0 }
    return range[1] + math.random() * (range[2] - range[1])
end

function AI:PickWildColor(hand)
    local counts = { GREEN = 0, BLUE = 0, RED = 0, YELLOW = 0 }
    for _, card in ipairs(hand) do
        if counts[card.color] then counts[card.color] = counts[card.color] + 1 end
    end
    local best, bestN = "GREEN", -1
    for _, col in ipairs(COLORS) do
        if counts[col] > bestN then best, bestN = col, counts[col] end
    end
    return best
end

function AI:CountOpponentCards(gs)
    local min = 999
    for i = 2, gs.playerCount do
        local n = #gs.players[i].hand
        if n < min then min = n end
    end
    return min
end

function AI:EasyPick(hand, gs)
    local Rules = ArcadiaNexus.TC_Rules
    local playable = Rules:GetPlayableCards(hand, gs)
    if #playable == 0 then return nil end
    return playable[math.random(#playable)]
end

function AI:NormalPick(hand, gs)
    local Rules = ArcadiaNexus.TC_Rules
    local playable = Rules:GetPlayableCards(hand, gs)
    if #playable == 0 then return nil end
    local oppCards = self:CountOpponentCards(gs)

    local priority = {
        WILD4 = 1, DRAW2 = 2, SKIP = 3, REVERSE = 4, NUMBER = 5, WILD = 6,
    }
    table.sort(playable, function(a, b)
        local pa = priority[a.card.type] or 9
        local pb = priority[b.card.type] or 9
        if pa ~= pb then return pa < pb end
        if a.card.type == "NUMBER" and b.card.type == "NUMBER" then
            return (a.card.value or 0) > (b.card.value or 0)
        end
        return false
    end)

    if oppCards <= 2 then
        for _, entry in ipairs(playable) do
            if entry.card.type == "DRAW2" or entry.card.type == "SKIP" or entry.card.type == "WILD4" then
                return entry
            end
        end
    end
    return playable[1]
end

function AI:EvaluateHand(hand)
    return #hand
end

function AI:HardPick(hand, gs)
    local Rules = ArcadiaNexus.TC_Rules
    local playable = Rules:GetPlayableCards(hand, gs)
    if #playable == 0 then return nil end

    local start = debugprofilestop and debugprofilestop() or 0
    local bestEntry, bestScore = playable[1], -9999

    for _, entry in ipairs(playable) do
        local simHand = {}
        for i, c in ipairs(hand) do
            if i ~= entry.index then simHand[#simHand + 1] = c end
        end
        local score = -self:EvaluateHand(simHand) * 10
        if entry.card.type == "DRAW2" or entry.card.type == "SKIP" then
            score = score + 5
        end
        if entry.card.type == "WILD4" then score = score + 8 end
        if score > bestScore then
            bestScore = score
            bestEntry = entry
        end
    end

    if debugprofilestop then
        local elapsed = debugprofilestop() - start
        if elapsed > 100 then
            return self:NormalPick(hand, gs)
        end
    end
    return bestEntry
end

function AI:PickCard(hand, gs)
    local diff = gs.difficulty or "easy"
    if diff == "hard" then return self:HardPick(hand, gs) end
    if diff == "normal" then return self:NormalPick(hand, gs) end
    return self:EasyPick(hand, gs)
end

function AI:ShouldCallUno()
    return true
end

function AI:ShouldCatchUno(gs)
    if not gs.rules.unoCallRule then return false end
    return math.random() < 0.7
end

function AI:ShouldChallengeWild4(gs)
    if not gs.rules.challengeDraw4 then return false end
    return math.random() < 0.25
end

function AI:ChooseAction(gs, playerIndex)
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[playerIndex]
    local hand = player.hand

    if gs.wild4Challengable and gs.currentPlayer == playerIndex then
        if self:ShouldChallengeWild4(gs) then
            return { action = "challenge" }
        end
        return { action = "accept_draw" }
    end

    if gs.pendingDraw and gs.pendingDraw > 0 then
        local pick = self:PickCard(hand, gs)
        if pick then
            return { action = "play", handIndex = pick.index, card = pick.card,
                wildColor = self:PickWildColor(hand) }
        end
        return { action = "draw_penalty" }
    end

    local pick = self:PickCard(hand, gs)
    if pick then
        return { action = "play", handIndex = pick.index, card = pick.card,
            wildColor = self:PickWildColor(hand) }
    end
    return { action = "draw" }
end
