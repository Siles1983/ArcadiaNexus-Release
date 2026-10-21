-- ============================================================
--  Blackjack – Logic.lua
--  Reine Spielregeln: Deck, Hand-Bewertung, Aktionen, KI.
--  KEIN UI-Code hier.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BJ_Logic = {}
local Logic = ArcadiaNexus.BJ_Logic

-- ── Kartendefinition ──────────────────────────────────────────
-- Farben: intern englische Keys, Renderer mappt auf Asset-Pfade
local SUITS = { "herz", "karo", "kreuz", "pik" }
-- Ränge: intern englische Keys (2–10, J, Q, K, A)
-- Renderer mappt J→b, Q→q, K→k, A→a für Asset-Dateinamen
local RANKS = { "2","3","4","5","6","7","8","9","10","J","Q","K","A" }

-- Kartenwert (numerisch) – Asse werden in EvalHand dynamisch behandelt
function Logic:CardValue(rank)
    if rank == "A"  then return 11 end
    if rank == "J" or rank == "Q" or rank == "K" then return 10 end
    return tonumber(rank) or 0
end

-- ── Deck-System ───────────────────────────────────────────────
function Logic:NewDeck(deckCount)
    deckCount = deckCount or 1
    local deck = {}
    for _ = 1, deckCount do
        for _, suit in ipairs(SUITS) do
            for _, rank in ipairs(RANKS) do
                table.insert(deck, { suit = suit, rank = rank })
            end
        end
    end
    return Logic:Shuffle(deck)
end

function Logic:Shuffle(deck)
    return ArcadiaNexus.ArrayUtils.Shuffle(deck)
end

function Logic:DrawCard(deck)
    return table.remove(deck)
end

-- ── Hand-Bewertung ────────────────────────────────────────────
function Logic:EvalHand(hand)
    local total = 0
    local aces  = 0
    for _, card in ipairs(hand) do
        local v = self:CardValue(card.rank)
        if card.rank == "A" then aces = aces + 1 end
        total = total + v
    end
    -- Asse auf 1 reduzieren wenn Bust
    while total > 21 and aces > 0 do
        total = total - 10
        aces  = aces - 1
    end
    return total
end

function Logic:IsBust(hand)
    return self:EvalHand(hand) > 21
end

function Logic:IsBlackjack(hand)
    return #hand == 2 and self:EvalHand(hand) == 21
end

function Logic:IsSoftHand(hand)
    -- Prüft ob eine der Asse als 11 zählt (Soft Hand)
    local total = 0
    local aces  = 0
    for _, card in ipairs(hand) do
        local v = self:CardValue(card.rank)
        if card.rank == "A" then aces = aces + 1 end
        total = total + v
    end
    -- wenn nach Reduzierung immer noch >= 1 Ass als 11 zählt
    local reduced = 0
    while total > 21 and reduced < aces do
        total   = total - 10
        reduced = reduced + 1
    end
    return (aces - reduced) > 0
end


-- Fixed table v2. All money is stored as integer half-chip units.
Logic.RULE_PROFILE="table"
function Logic:Sync(gs)
    gs.chips,gs.bet,gs.insuranceBet=gs.chips2/2,gs.bet2/2,gs.insurance2/2
    local i=gs.activeHand or 1
    gs.playerState=gs.handStates[i] or "stand"
    gs.firstAction=gs.playerHands[i] and #gs.playerHands[i]==2 or false
end
function Logic:Copy(v)
    if type(v)~="table" then return v end
    local t={}; for k,x in pairs(v) do t[k]=self:Copy(x) end; return t
end
function Logic:NewGameState(_,aiCount,startChips)
    local gs={saveVersion=2,ruleVersion=2,difficulty="table",phase="BETTING",aiCount=aiCount or 0,
        chips2=(startChips or 100)*2,bet2=0,insurance2=0,deck=self:NewDeck(4),deckCount=4,
        cardsDealt=0,reshuffleAt=156,roundsPlayed=0,roundNo=0,blackjacks=0}
    self:ResetRound(gs); return gs
end
function Logic:ResetRound(gs)
    gs.phase="BETTING"; gs.bet2=0; gs.betConfirmed=false; gs.insurance2=0; gs.insuranceOpen=false
    gs.playerHands={{}}; gs.handBets2={}; gs.handStates={}; gs.handOrigins={}
    gs.activeHand=1; gs.dealerHand={}; gs.dealerState="waiting"; gs.aiHands={}; gs.aiStates={}; gs.aiBets={}
    gs.dealStep=0; gs.aiTurn=1; gs.dealerRevealed=false; gs.settled=false; gs.results=nil; gs.resultPending=nil
    gs.net2=nil; gs.return2=nil; gs.stake2=nil; gs.roundBlackjacks=0
    for i=1,gs.aiCount do gs.aiHands[i]={}; gs.aiStates[i]="playing"; gs.aiBets[i]=25 end
    self:Sync(gs)
end
function Logic:SetBet(gs,amount)
    if gs.phase~="BETTING" or type(amount)~="number" or amount~=math.floor(amount) or amount%25~=0 then return false end
    local n=gs.bet2+amount*2
    if n<0 or n>gs.chips2 then return false end
    gs.bet2=n; gs.betConfirmed=n>=50; self:Sync(gs); return true
end
function Logic:BeginRound(gs)
    if gs.phase~="BETTING" or gs.bet2<50 or gs.bet2>gs.chips2 then return false end
    if gs.cardsDealt>=156 or #gs.deck<80 then gs.deck=self:NewDeck(4); gs.cardsDealt=0 end
    gs.startChips2=gs.chips2; gs.chips2=gs.chips2-gs.bet2
    gs.handBets2={gs.bet2}; gs.handOrigins={"original"}; gs.handStates={"playing"}
    gs.roundNo=gs.roundNo+1; gs.phase="DEALING"; self:Sync(gs); return true
end
function Logic:Draw(gs,hand,hidden)
    local card=self:DrawCard(gs.deck)
    assert(card,"Blackjack shoe exhausted")
    card.hidden=hidden or nil; hand[#hand+1]=card; gs.cardsDealt=gs.cardsDealt+1; return card
end
-- One stable draw per animation step; resume never draws visible cards again.
function Logic:DealStep(gs)
    if gs.phase~="DEALING" then return false end
    local seats=2+gs.aiCount
    local idx=gs.dealStep%seats+1; local second=gs.dealStep>=seats
    local hand=idx==1 and gs.playerHands[1] or idx==2 and gs.dealerHand or gs.aiHands[idx-2]
    self:Draw(gs,hand,idx==2 and second); gs.dealStep=gs.dealStep+1
    if gs.dealStep==seats*2 then
        gs.phase="PLAYING"
        gs.insuranceOpen=gs.dealerHand[1].rank=="A"
    end
    self:Sync(gs); return true
end
function Logic:IsNatural(gs,idx) return gs.handOrigins[idx]=="original" and self:IsBlackjack(gs.playerHands[idx]) end
function Logic:CanSplit(hand) return #hand==2 and hand[1].rank==hand[2].rank end
function Logic:ActionBlockReason(gs,action)
    if gs.phase~="PLAYING" then return "action_phase" end
    if action=="insurance" then
        if not gs.insuranceOpen then return "action_insurance_closed" end
        if gs.chips2<gs.bet2/2 then return "action_capital" end
        return nil
    end
    if gs.insuranceOpen then return "action_insurance_open" end
    if gs.handStates[gs.activeHand]~="playing" or self:IsBlackjack(gs.dealerHand) or self:IsNatural(gs,1) then return "action_finished_hand" end
    local h=gs.playerHands[gs.activeHand]; local bet=gs.handBets2[gs.activeHand]
    if action=="stand" then return nil end
    if action=="hit" then return self:EvalHand(h)>=21 and "action_finished_hand" or nil end
    if action=="double" then
        if #h~=2 then return "action_two_cards" end
        if gs.handOrigins[gs.activeHand]=="split" and h[1].rank=="A" then return "action_split_aces" end
        if gs.chips2<bet then return "action_capital" end
        return nil
    end
    if action=="split" then
        if #gs.playerHands~=1 then return "action_split_once" end
        if not self:CanSplit(h) then return "action_pair" end
        if gs.chips2<bet then return "action_capital" end
        return nil
    end
    return "action_unavailable"
end
function Logic:CanAction(gs,action) return self:ActionBlockReason(gs,action)==nil end
function Logic:AdvanceHand(gs)
    for i=1,#gs.playerHands do
        if gs.handStates[i]=="playing" then gs.activeHand=i; self:Sync(gs); return end
    end
    gs.phase="DEALER_TURN"; self:Sync(gs)
end
function Logic:PlayerHit(gs)
    if not self:CanAction(gs,"hit") then return false end
    local i=gs.activeHand; self:Draw(gs,gs.playerHands[i])
    local v=self:EvalHand(gs.playerHands[i])
    if v>=21 then gs.handStates[i]=v>21 and "bust" or "stand"; self:AdvanceHand(gs) end
    self:Sync(gs); return true
end
function Logic:PlayerStand(gs)
    if not self:CanAction(gs,"stand") then return false end
    gs.handStates[gs.activeHand]="stand"; self:AdvanceHand(gs); return true
end
function Logic:PlayerDouble(gs)
    local i=gs.activeHand
    if not self:CanAction(gs,"double") or gs.chips2<gs.handBets2[i] then return false end
    gs.chips2=gs.chips2-gs.handBets2[i]; gs.handBets2[i]=gs.handBets2[i]*2
    self:Draw(gs,gs.playerHands[i]); gs.handStates[i]=self:IsBust(gs.playerHands[i]) and "bust" or "stand"
    self:AdvanceHand(gs); return true
end
function Logic:PlayerSplit(gs)
    if not self:CanAction(gs,"split") then return false end
    local h=gs.playerHands[1]; local ace=h[1].rank=="A"
    gs.chips2=gs.chips2-gs.handBets2[1]; gs.playerHands[2]={h[2]}; h[2]=nil
    gs.handBets2[2]=gs.handBets2[1]; gs.handOrigins={"split","split"}; gs.handStates={"playing","playing"}
    self:Draw(gs,h); self:Draw(gs,gs.playerHands[2])
    for i=1,2 do if ace or self:EvalHand(gs.playerHands[i])==21 then gs.handStates[i]="stand" end end
    self:AdvanceHand(gs); return true
end
function Logic:PlayerInsurance(gs)
    if not self:CanAction(gs,"insurance") then return false end
    gs.insurance2=gs.bet2/2; gs.chips2=gs.chips2-gs.insurance2; gs.insuranceOpen=false; self:Sync(gs); return true
end
function Logic:DeclineInsurance(gs)
    if gs.phase~="PLAYING" or not gs.insuranceOpen then return false end
    gs.insuranceOpen=false; return true
end
function Logic:CheckPeek(gs)
    if gs.phase~="PLAYING" or gs.insuranceOpen then return end
    if self:IsBlackjack(gs.dealerHand) or self:IsNatural(gs,1) then
        gs.handStates[1]="stand"; gs.phase="DEALER_TURN"
    end
    self:Sync(gs)
end
function Logic:DealerShouldHit(hand) return self:EvalHand(hand)<17 end
function Logic:AIDecideNormal(hand,upcard)
    local v=self:EvalHand(hand); local up=self:CardValue(type(upcard)=="table" and upcard.rank or upcard)
    if self:IsSoftHand(hand) then return (v<18 or v==18 and up>=9) and "HIT" or "STAND" end
    if v>=17 or v>=12 and up>=2 and up<=6 then return "STAND" end
    if #hand==2 and (v==11 and up<11 or v==10 and up<10 or v==9 and up>=3 and up<=6) then return "DOUBLE" end
    return "HIT"
end
function Logic:DealerStep(gs)
    if gs.phase~="DEALER_TURN" then return false end
    local dealerBJ=self:IsBlackjack(gs.dealerHand)
    if not gs.dealerRevealed then gs.dealerHand[2].hidden=nil; gs.dealerRevealed=true; return true end
    while gs.aiTurn<=gs.aiCount and not dealerBJ do
        local i=gs.aiTurn; local h=gs.aiHands[i]
        local action=self:AIDecideNormal(h,gs.dealerHand[1])
        if action~="STAND" and not self:IsBust(h) then
            self:Draw(gs,h)
            if action=="DOUBLE" then gs.aiBets[i]=gs.aiBets[i]*2 end
            if action=="DOUBLE" or self:EvalHand(h)>=21 then
                gs.aiStates[i]=self:IsBust(h) and "bust" or "stand"; gs.aiTurn=i+1
            end
            return true
        end
        gs.aiStates[i]=self:IsBust(h) and "bust" or "stand"; gs.aiTurn=i+1
    end
    if not dealerBJ and self:DealerShouldHit(gs.dealerHand) then self:Draw(gs,gs.dealerHand); return true end
    gs.dealerState=self:IsBust(gs.dealerHand) and "bust" or dealerBJ and "blackjack" or "stand"
    return false
end
-- Main hand returns and insurance returns are separate; stakes already deducted.
function Logic:HandReturn(hand,dealer,bet2,natural)
    local dealerBJ=self:IsBlackjack(dealer); local v=self:EvalHand(hand); local dv=self:EvalHand(dealer)
    if v>21 then return 0,"bust" end
    if dealerBJ then return natural and bet2 or 0,natural and "push" or "lose" end
    if natural then return bet2*5/2,"blackjack" end
    if dv>21 or v>dv then return bet2*2,"win" end
    if v==dv then return bet2,"push" end
    return 0,"lose"
end
function Logic:SettleRound(gs)
    if gs.settled or gs.phase~="DEALER_TURN" then return false end
    local results,returns,stakes,bj={},0,gs.insurance2,0
    for i,h in ipairs(gs.playerHands) do
        local natural=self:IsNatural(gs,i); local bet=gs.handBets2[i]
        local ret,result=self:HandReturn(h,gs.dealerHand,bet,natural)
        results[i]={handIdx=i,bet2=bet,return2=ret,net2=ret-bet,payout=(ret-bet)/2,result=result}
        returns=returns+ret; stakes=stakes+bet; if natural then bj=bj+1 end
    end
    local insReturn=self:IsBlackjack(gs.dealerHand) and gs.insurance2*3 or 0
    gs.insuranceReturn2=insReturn; returns=returns+insReturn
    gs.chips2=gs.chips2+returns; gs.net2=returns-stakes; gs.return2=returns; gs.stake2=stakes
    gs.roundBlackjacks=bj; gs.blackjacks=gs.blackjacks+bj; gs.roundsPlayed=gs.roundsPlayed+1
    gs.results=results; gs.settled=true; gs.resultPending=true; gs.phase="RESULT_PENDING"
    self:Sync(gs); return results
end
local function int(n,max) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=(max or 2147483647) end
function Logic:ValidateSave(gs)
    if type(gs)~="table" or gs.saveVersion~=2 or gs.ruleVersion~=2 or gs.difficulty~="table"
        or not int(gs.aiCount,2) or not int(gs.chips2) or not int(gs.bet2) or gs.bet2%50~=0
        or not int(gs.insurance2) or not int(gs.cardsDealt,208) or gs.deckCount~=4
        or not int(gs.roundNo) or not int(gs.roundsPlayed) or not int(gs.blackjacks)
        or not int(gs.activeHand,2) or gs.activeHand<1 or not int(gs.dealStep,8)
        or not int(gs.aiTurn,3) or gs.aiTurn<1 or type(gs.runId)~="string" or type(gs.tableId)~="string" then return false end
    if not ({BETTING=true,DEALING=true,PLAYING=true,DEALER_TURN=true,RESULT_PENDING=true,ROUND_RESULT=true,GAMEOVER=true})[gs.phase] then return false end
    local counts,total={},0
    local function cards(t,max)
        if type(t)~="table" or #t>max then return false end
        for _,c in ipairs(t) do
            if type(c)~="table" or not self:CardValue(c.rank) or self:CardValue(c.rank)==0 then return false end
            local validSuit=false; for _,s in ipairs(SUITS) do if s==c.suit then validSuit=true end end
            local validRank=false; for _,r in ipairs(RANKS) do if r==c.rank then validRank=true end end
            if not validSuit or not validRank or c.hidden~=nil and c.hidden~=true then return false end
            local key=c.suit..c.rank; counts[key]=(counts[key] or 0)+1; total=total+1
            if counts[key]>4 then return false end
        end
        return true
    end
    if not cards(gs.deck,208) or not cards(gs.dealerHand,22) or type(gs.playerHands)~="table"
        or #gs.playerHands<1 or #gs.playerHands>2 or type(gs.handBets2)~="table" or type(gs.handStates)~="table"
        or type(gs.handOrigins)~="table" or type(gs.aiHands)~="table" or type(gs.aiStates)~="table" or type(gs.aiBets)~="table" then return false end
    for i,h in ipairs(gs.playerHands) do
        if not cards(h,22) then return false end
        if gs.phase~="BETTING" and not (gs.phase=="GAMEOVER" and gs.roundNo==0) then
            if not int(gs.handBets2[i]) or gs.handBets2[i]<50 or gs.handBets2[i]%50~=0
                or not ({playing=true,stand=true,bust=true})[gs.handStates[i]]
                or not ({original=true,split=true})[gs.handOrigins[i]] then return false end
        end
    end
    for i=1,gs.aiCount do if not cards(gs.aiHands[i],22) or not int(gs.aiBets[i]) or not gs.aiStates[i] then return false end end
    if total>208 or #gs.deck+gs.cardsDealt~=208 or gs.activeHand>#gs.playerHands or gs.chips~=gs.chips2/2 or gs.bet~=gs.bet2/2 or gs.insuranceBet~=gs.insurance2/2 then return false end
    if gs.phase=="BETTING" or gs.phase=="GAMEOVER" and gs.roundNo==0 and gs.chips2<50 then return gs.bet2<=gs.chips2 and not gs.settled and #gs.dealerHand==0 end
    if not int(gs.startChips2) or gs.insurance2>gs.bet2/2 or #gs.handBets2~=#gs.playerHands then return false end
    local terminal=gs.phase=="RESULT_PENDING" or gs.phase=="ROUND_RESULT" or gs.phase=="GAMEOVER"
    if terminal~=(gs.settled==true) then return false end
    if gs.phase=="RESULT_PENDING" and gs.resultPending~=true then return false end
    if gs.phase~="RESULT_PENDING" and gs.resultPending then return false end
    if gs.roundNo~=gs.roundsPlayed+(gs.settled and 0 or 1) then return false end
    if gs.phase=="DEALING" then
        local seats=gs.aiCount+2
        if #gs.playerHands~=1 or gs.dealStep>=seats*2 or gs.insuranceOpen then return false end
        local expectedPlayer=gs.dealStep>0 and (gs.dealStep>seats and 2 or 1) or 0
        local expectedDealer=gs.dealStep>=2 and (gs.dealStep>=seats+2 and 2 or 1) or 0
        if #gs.playerHands[1]~=expectedPlayer or #gs.dealerHand~=expectedDealer then return false end
    elseif #gs.dealerHand<2 then return false end
    if gs.insuranceOpen and (gs.phase~="PLAYING" or gs.dealerHand[1].rank~="A" or gs.insurance2~=0) then return false end
    if gs.phase=="PLAYING" and (gs.handStates[gs.activeHand]~="playing" or #gs.playerHands[gs.activeHand]<2) then return false end
    if gs.phase=="DEALER_TURN" then
        for _,state in ipairs(gs.handStates) do if state=="playing" then return false end end
    end
    local stakes=gs.insurance2; for _,v in ipairs(gs.handBets2) do stakes=stakes+v end
    if gs.settled then
        if not int(gs.return2) or type(gs.net2)~="number" or gs.net2~=gs.return2-stakes
            or gs.stake2~=stakes or gs.chips2~=gs.startChips2+gs.net2 or not int(gs.roundBlackjacks,1)
            or type(gs.results)~="table" or #gs.results~=#gs.playerHands then return false end
        local returns=0
        for i,h in ipairs(gs.playerHands) do
            local ret,result=self:HandReturn(h,gs.dealerHand,gs.handBets2[i],self:IsNatural(gs,i))
            local r=gs.results[i]
            if type(r)~="table" or r.bet2~=gs.handBets2[i] or r.return2~=ret or r.net2~=ret-r.bet2 or r.result~=result then return false end
            returns=returns+ret
        end
        local ins=self:IsBlackjack(gs.dealerHand) and gs.insurance2*3 or 0
        if gs.insuranceReturn2~=ins or gs.return2~=returns+ins then return false end
    elseif gs.chips2~=gs.startChips2-stakes then return false end
    return true
end
