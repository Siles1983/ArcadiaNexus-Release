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
    if type(range)=="number" then return range end
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

function AI:CountOpponentCards(gs, seat)
    seat=seat or gs.currentPlayer
    local minimum=999
    for i=1,gs.playerCount do if i~=seat then
        local p=gs.players[i]; minimum=math.min(minimum,p.handCount or #p.hand)
    end end
    return minimum
end

function AI:EasyPick(hand, gs)
    local Rules = ArcadiaNexus.TC_Rules
    local playable = Rules:GetPlayableCards(hand, gs)
    if #playable == 0 then return nil end
    return playable[math.random(#playable)]
end

function AI:_RankedPick(hand, gs, hard)
    local Rules=ArcadiaNexus.TC_Rules
    local playable=Rules:GetPlayableCards(hand,gs); if #playable==0 then return nil end
    local nextSeat=Rules:NextPlayerIndex(gs,1)
    local nextPlayer=gs.players[nextSeat]
    local threat=(nextPlayer.handCount or #nextPlayer.hand)<=2
    local counts={}; for _,card in ipairs(hand) do counts[card.color]=(counts[card.color] or 0)+1 end
    local best, bestScore=nil,-math.huge
    for _,entry in ipairs(playable) do
        local card=entry.card; local wild=Rules:IsWildType(card)
        local color=wild and self:PickWildColor(hand) or card.color
        local score=(counts[color] or 0)*(hard and 5 or 2)+(card.points or 0)*0.2
        if wild then score=score-(hard and 18 or 10) end -- preserve flexible cards
        if threat and (card.type=="SKIP" or card.type=="DRAW2" or card.type=="WILD4" or card.type=="REVERSE" and gs.playerCount==2) then score=score+(hard and 45 or 25) end
        if hard and card.type=="REVERSE" and gs.playerCount>2 then
            local opposite=(gs.currentPlayer-(gs.direction or 1)-1)%gs.playerCount+1
            local target=gs.players[opposite]; local n=target.handCount or #target.hand
            score=score+((nextPlayer.handCount or #nextPlayer.hand)-n)*-2
        end
        if card.type=="WILD4" and gs.rules.challengeDraw4 then
            for _,other in ipairs(hand) do if other.color==Rules:GetActiveColor(gs) and not Rules:IsWildType(other) then score=score-(hard and 60 or 25); break end end
        end
        if hard then
            local connected=0
            for i,other in ipairs(hand) do if i~=entry.index and (other.color==color or Rules:IsWildType(other) or other.type==card.type and other.type~="NUMBER" or other.type=="NUMBER" and card.type=="NUMBER" and other.value==card.value) then connected=connected+1 end end
            score=score+connected*3
        end
        if score>bestScore then best,bestScore=entry,score end
    end
    return best
end
function AI:NormalPick(hand,gs) return self:_RankedPick(hand,gs,false) end
function AI:HardPick(hand,gs) return self:_RankedPick(hand,gs,true) end

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
    local p=gs.players[gs.wild4PlayedBy or 1]
    local n=p and (p.handCount or #p.hand) or 0
    local probability=gs.difficulty=="hard" and math.min(0.5,0.12+n*0.025) or gs.difficulty=="normal" and 0.2 or 0.1
    return math.random()<probability
end

function AI:ChooseAction(gs, playerIndex)
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[playerIndex]
    local hand = player.hand

    if gs.wild4Challengable and gs.currentPlayer == playerIndex then
        if self:ShouldChallengeWild4(gs) then
            return { action = "challenge" }
        end
        if not gs.closingWinner and gs.rules.stackDraw4 then
            for index,card in ipairs(hand) do if card.type=="WILD4" then return {action="play",handIndex=index,wildColor=self:PickWildColor(hand)} end end
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
