-- Pure rules. Money is stored in exact integer half-chip units.
local A=_G.ArcadiaNexus
local L={}; A.HOL_Logic=L
local SUITS={"herz","karo","kreuz","pik"}
local RANKS={"2","3","4","5","6","7","8","9","10","J","Q","K","A"}
local FACTORS={10,12,15,20,25,30,40,50,70,100}
-- Confirmed 03.10.2026: identical net-profit factors in Standard and Joker; stake returned separately.
local LIMIT=2147483647
local PHASES={BETTING=true,PLAYING=true,REVEALING=true,RESULT_PENDING=true,ROUND_RESULT=true,GAMEOVER=true}
local function Int(n,max) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=(max or LIMIT) end
function L:Copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=self:Copy(v) end; return out
end
function L:RankValue(rank) return ({A=14,K=13,Q=12,J=11})[rank] or tonumber(rank) or 0 end
function L:IsVariant(variant) return variant=="standard" or variant=="joker" end
function L:Shuffle(deck) return A.ArrayUtils.Shuffle(deck) end
function L:NewDeck(variant)
    local deck={}
    for _,suit in ipairs(SUITS) do for _,rank in ipairs(RANKS) do
        deck[#deck+1]={suit=suit,rank=rank,value=self:RankValue(rank)}
    end end
    if variant=="joker" then for i=1,2 do deck[#deck+1]={suit="X",rank="JOKER",value=-1,isJoker=true} end end
    return self:Shuffle(deck)
end
function L:GetMultiplier(series,variant)
    if series<=0 then return 0 end
    return FACTORS[math.min(series,10)]/10
end
function L:CalcCashOut(bet,series,variant)
    if series<=0 then return 0 end
    return bet+bet*self:GetMultiplier(series,variant)
end
function L:Sync(gs) gs.chips=gs.chips2/2; gs.bet=gs.bet2/2; gs.pendingWin=gs.payout2/2; gs.difficulty=gs.variant end
function L:ResetRound(gs)
    gs.phase="BETTING"; gs.bet2=0; gs.streak=0; gs.payout2=0; gs.roundBest=0
    gs.currentCard=nil; gs.previousCard=nil; gs.nextCard=nil; gs.guess=nil; gs.lastOutcome=nil
    gs.roundStartIndex=nil; gs.startChips2=nil; gs.return2=nil; gs.net2=nil; gs.reason=nil; gs.settled=nil; gs.resultPending=nil
    self:Sync(gs)
end
function L:NewGameState(variant,chips)
    local gs={variant=variant or "standard",ruleVersion=2,saveVersion=2,chips2=(chips or 100)*2,
        deck=self:NewDeck(variant or "standard"),deckIndex=1,roundNo=0}
    self:ResetRound(gs); return gs
end
function L:AdjustBet(gs,delta)
    if gs.phase~="BETTING" or type(delta)~="number" or delta%25~=0 then return false end
    local amount=gs.bet2+delta*2
    -- Reserve enough numeric range for the largest possible cashout.
    if amount<0 or amount>gs.chips2 or gs.chips2+amount*20>LIMIT then return false end
    gs.bet2=amount; self:Sync(gs); return true
end
function L:HasNextCard(gs) return gs.deckIndex<=#gs.deck end
function L:DrawNext(gs)
    local card=gs.deck[gs.deckIndex]; if card then gs.deckIndex=gs.deckIndex+1 end; return card
end
function L:StartRound(gs)
    if gs.phase~="BETTING" or gs.bet2<50 or gs.bet2>gs.chips2 then return false end
    -- Rebuild only between rounds if the remaining deck cannot start a guess.
    -- A start Joker is moved to the unconsumed tail, never discarded.
    local normal=0; for i=gs.deckIndex,#gs.deck do if not gs.deck[i].isJoker then normal=normal+1 end end
    if normal==0 or #gs.deck-gs.deckIndex+1<2 then gs.deck=self:NewDeck(gs.variant); gs.deckIndex=1 end
    if gs.deck[gs.deckIndex].isJoker then
        local idx=gs.deckIndex+1; while gs.deck[idx].isJoker do idx=idx+1 end
        gs.deck[gs.deckIndex],gs.deck[idx]=gs.deck[idx],gs.deck[gs.deckIndex]
    end
    gs.roundStartIndex=gs.deckIndex; gs.startChips2=gs.chips2; gs.chips2=gs.chips2-gs.bet2; gs.roundNo=gs.roundNo+1
    gs.currentCard=self:DrawNext(gs); gs.phase="PLAYING"; self:Sync(gs); return true
end
function L:Evaluate(current,nextCard,guess)
    if guess~="HIGHER" and guess~="LOWER" then return nil end
    if nextCard.isJoker then return "LOSS" end
    if nextCard.value==current.value then return "PUSH" end
    return ((nextCard.value>current.value)==(guess=="HIGHER")) and "WIN" or "LOSS"
end
function L:QueueGuess(gs,guess)
    if gs.phase~="PLAYING" or (guess~="HIGHER" and guess~="LOWER") or not self:HasNextCard(gs) then return false end
    gs.guess=guess; gs.phase="REVEALING"; return true
end
function L:ResolveGuess(gs)
    if gs.phase~="REVEALING" then return false end
    local card=self:DrawNext(gs); local result=self:Evaluate(gs.currentCard,card,gs.guess)
    gs.previousCard=gs.currentCard; gs.currentCard=card; gs.lastOutcome=result; gs.guess=nil
    if result=="WIN" then
        gs.streak=gs.streak+1; gs.roundBest=math.max(gs.roundBest,gs.streak)
        gs.payout2=self:CalcCashOut(gs.bet2,gs.streak,gs.variant)
    end
    gs.phase="PLAYING"
    if result=="LOSS" then self:Settle(gs,"LOSS")
    elseif not self:HasNextCard(gs) then self:Settle(gs,"DECK_EMPTY") end
    self:Sync(gs); return result
end
function L:Settle(gs,reason)
    if gs.phase~="PLAYING" or gs.settled then return false end
    if reason~="LOSS" and reason~="CASHOUT" and reason~="DECK_EMPTY" then return false end
    if reason=="CASHOUT" and gs.streak==0 then return false end
    gs.return2=reason=="LOSS" and 0 or (gs.streak>0 and gs.payout2 or gs.bet2)
    if reason=="LOSS" then gs.streak=0; gs.payout2=0 end
    gs.net2=gs.return2-gs.bet2; gs.chips2=gs.chips2+gs.return2
    gs.reason=reason; gs.settled=true; gs.resultPending=true; gs.phase="RESULT_PENDING"
    self:Sync(gs); return true
end
function L:IsBankrupt(gs) return gs.chips2<50 end
local function CardOK(card)
    if type(card)~="table" then return false end
    if card.isJoker then return card.rank=="JOKER" and card.suit=="X" and card.value==-1 end
    local suit=false; for _,s in ipairs(SUITS) do if card.suit==s then suit=true end end
    local rank=false; for _,r in ipairs(RANKS) do if card.rank==r then rank=true end end
    return suit and rank and card.value==L:RankValue(card.rank)
end
function L:ValidateSave(gs)
    if type(gs)~="table" or gs.saveVersion~=2 or gs.ruleVersion~=2 or not self:IsVariant(gs.variant)
        or not PHASES[gs.phase] or not Int(gs.chips2) or not Int(gs.bet2) or gs.bet2%50~=0
        or not Int(gs.roundNo) or not Int(gs.streak,53) or not Int(gs.roundBest,53) or gs.roundBest<gs.streak
        or not Int(gs.payout2) or type(gs.deck)~="table" or #gs.deck~=(gs.variant=="joker" and 54 or 52)
        or not Int(gs.deckIndex,#gs.deck+1) or gs.deckIndex<1 or type(gs.runId)~="string" or type(gs.tableId)~="string" then return false end
    local seen={}
    for _,card in ipairs(gs.deck) do
        if not CardOK(card) then return false end
        local key=card.suit..card.rank; seen[key]=(seen[key] or 0)+1
        if seen[key]>(card.isJoker and gs.variant=="joker" and 2 or 1) then return false end
    end
    if gs.chips~=gs.chips2/2 or gs.bet~=gs.bet2/2 or gs.pendingWin~=gs.payout2/2 or gs.difficulty~=gs.variant then return false end
    local terminal=gs.phase=="RESULT_PENDING" or gs.phase=="ROUND_RESULT" or gs.phase=="GAMEOVER"
    if gs.phase=="BETTING" or (gs.phase=="GAMEOVER" and gs.legacyCapital and gs.roundNo==0) then
        return gs.bet2<=gs.chips2 and gs.streak==0 and gs.roundBest==0 and gs.payout2==0 and not gs.currentCard and not gs.settled
    end
    if not Int(gs.roundStartIndex,#gs.deck) or gs.roundStartIndex<1 or gs.deckIndex<=gs.roundStartIndex
        or gs.roundBest>gs.deckIndex-gs.roundStartIndex-1 or gs.bet2<50 or gs.roundNo<1 or not Int(gs.startChips2) or gs.startChips2<gs.bet2
        or not CardOK(gs.currentCard) or gs.deckIndex<2 then return false end
    local last=gs.deck[gs.deckIndex-1]
    if gs.currentCard.suit~=last.suit or gs.currentCard.rank~=last.rank or gs.currentCard.value~=last.value then return false end
    if gs.previousCard then
        if gs.deckIndex<3 or not CardOK(gs.previousCard) then return false end
        local prev=gs.deck[gs.deckIndex-2]
        if prev.suit~=gs.previousCard.suit or prev.rank~=gs.previousCard.rank or prev.value~=gs.previousCard.value then return false end
    end
    if gs.payout2~=self:CalcCashOut(gs.bet2,gs.streak,gs.variant) or gs.streak>gs.deckIndex-2 then return false end
    if gs.phase=="REVEALING" then
        if (gs.guess~="HIGHER" and gs.guess~="LOWER") or not self:HasNextCard(gs) then return false end
    elseif gs.guess then return false end
    if terminal then
        if not gs.settled or not Int(gs.return2) then return false end
        local expected=gs.reason=="LOSS" and 0 or (gs.streak>0 and gs.payout2 or gs.bet2)
        if gs.reason~="LOSS" and gs.reason~="CASHOUT" and gs.reason~="DECK_EMPTY" then return false end
        if gs.reason=="CASHOUT" and gs.streak==0 or gs.reason=="DECK_EMPTY" and self:HasNextCard(gs) then return false end
        if gs.return2~=expected or gs.net2~=gs.return2-gs.bet2 or gs.chips2~=gs.startChips2+gs.net2 then return false end
        if gs.phase=="RESULT_PENDING" and not gs.resultPending or gs.phase~="RESULT_PENDING" and gs.resultPending then return false end
        if gs.phase=="GAMEOVER" and gs.chips2>=50 or gs.phase=="ROUND_RESULT" and gs.chips2<50 then return false end
    elseif not self:HasNextCard(gs) or gs.settled or gs.chips2~=gs.startChips2-gs.bet2 or gs.currentCard.isJoker then return false end
    return true
end
