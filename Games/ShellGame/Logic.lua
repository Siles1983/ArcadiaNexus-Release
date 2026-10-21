-- ============================================================
--  ShellGame – Logic.lua
--  Reine Spielregeln: Sequenzgenerierung, Fake-Moves,
--  Becher-State, Auswertung.
--  KEIN UI-Code hier.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SHG_Logic = {}
local Logic = ArcadiaNexus.SHG_Logic

-- ── Schwierigkeitskonfiguration ───────────────────────────────
Logic.DIFFICULTY = {
    easy = {
        cups         = 3,
        swaps        = 5,
        swapDuration = 0.45,
        swapPause    = 0.20,
        fakes        = 0,
        payout       = 1.0,
        scoreFactor  = 1.0,
    },
    normal = {
        cups         = 3,
        swaps        = 9,
        swapDuration = 0.28,
        swapPause    = 0.12,
        fakes        = 0,
        payout       = 1.5,
        scoreFactor  = 1.5,
    },
    hard = {
        cups         = 4,
        swaps        = 14,
        swapDuration = 0.18,
        swapPause    = 0.06,
        fakes        = 4,
        payout       = 2.0,
        scoreFactor  = 2.0,
    },
}

-- ── Neues Spiel-State ─────────────────────────────────────────
function Logic:NewGameState(difficulty, chips, bet)
    local cfg = self.DIFFICULTY[difficulty] or self.DIFFICULTY.easy
    return {
        difficulty  = difficulty,
        cups        = cfg.cups,
        ballCup     = math.random(1, cfg.cups),  -- welcher Becher hat die Kugel (1-basiert)
        sequence    = {},
        guess       = nil,
        chips2      = (chips or 100) * 2,
        bet2        = (bet or 0) * 2,
        chips       = chips or 100,
        bet         = bet or 0,
        phase       = "BETTING",
        saveVersion = 2,
        roundNo     = 0,
        cupAtSlot   = {},
        roundsPlayed  = 0,
        roundsWon     = 0,
        roundsLost    = 0,
        _gameOverFired = false,
    }
end

-- ── Misch-Sequenz generieren ──────────────────────────────────
-- Gibt eine Liste von Tausch-Schritten zurück.
-- Fake-Schritt: b == nil, aktualisiert ballCup NICHT.
function Logic:GenerateSequence(difficulty)
    local cfg = self.DIFFICULTY[difficulty] or self.DIFFICULTY.easy
    local cupCount = cfg.cups
    local seq = {}

    -- Echte Tausche
    local lastA, lastB = -1, -1
    for _ = 1, cfg.swaps do
        local a, b
        for attempt = 1, 20 do
            a = math.random(1, cupCount)
            b = math.random(1, cupCount)
            if a ~= b and not (a == lastA and b == lastB) then break end
        end
        if a == b or (a == lastA and b == lastB) then
            -- Deterministic bounded fallback, even with a degenerate RNG.
            for x = 1, cupCount do
                for y = 1, cupCount do
                    if x ~= y and not (x == lastA and y == lastB) then a,b=x,y; break end
                end
                if a ~= b and not (a == lastA and b == lastB) then break end
            end
        end
        lastA, lastB = a, b
        table.insert(seq, {
            a        = a,
            b        = b,
            duration = cfg.swapDuration,
            pause    = cfg.swapPause,
            fake     = false,
        })
    end

    -- Fake-Moves auf Schwer einfügen (an zufälligen Positionen)
    if difficulty == "hard" then
        for _ = 1, cfg.fakes do
            local pos = math.random(1, #seq)
            table.insert(seq, pos, {
                a        = math.random(1, cupCount),
                b        = nil,
                duration = cfg.swapDuration * 0.5,
                pause    = cfg.swapPause    * 0.5,
                fake     = true,
            })
        end
    end

    return seq
end

-- ── Becher tauschen (State aktualisieren) ─────────────────────
-- Only Logic/Engine apply steps; Renderer reports animation completion.
-- SwapCups: tauscht ballCup wenn er an einem der beiden Slots steht.
-- a und b sind SLOT-Indizes (identisch zur Sequenz).
function Logic:SwapCups(gs, slotA, slotB)
    gs.cupAtSlot[slotA], gs.cupAtSlot[slotB] = gs.cupAtSlot[slotB], gs.cupAtSlot[slotA]
    if gs.ballCup == slotA then
        gs.ballCup = slotB
    elseif gs.ballCup == slotB then
        gs.ballCup = slotA
    end
end

-- ── Tipp auswerten ────────────────────────────────────────────
-- Gibt { won, payout } zurück.
-- payout ist positiv bei Gewinn, negativ bei Verlust.
function Logic:EvaluateGuess(gs)
    local cfg = self.DIFFICULTY[gs.difficulty] or self.DIFFICULTY.easy
    local won = (gs.guess == gs.ballCup)
    local payout
    if won then
        payout = gs.bet2 * cfg.payout
    else
        payout = -gs.bet2
    end
    return won, payout
end

-- ── Score berechnen ───────────────────────────────────────────
function Logic:CalcScore(gs)
    return 0
end

function Logic:IsDifficulty(diff) return self.DIFFICULTY[diff] ~= nil end
function Logic:IsUnits(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
function Logic:Copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=self:Copy(v) end; return out
end
function Logic:SyncAmounts(gs) gs.chips,gs.bet=gs.chips2/2,gs.bet2/2 end
function Logic:AdjustBet(gs,delta2)
    if gs.phase~="BETTING" or type(delta2)~="number" or delta2~=math.floor(delta2)
        or delta2==0 or delta2%50~=0 then return false end
    local nextBet=gs.bet2+delta2
    if nextBet<0 or nextBet>gs.chips2 then return false end
    gs.bet2=nextBet; gs.betConfirmed=nextBet>=50; self:SyncAmounts(gs); return true
end
function Logic:ResetBet(gs)
    if gs.phase~="BETTING" then return false end
    gs.bet2=0; gs.betConfirmed=false; self:SyncAmounts(gs); return true
end
function Logic:BeginRound(gs)
    if gs.phase~="BETTING" or gs.chips2<50 or gs.bet2<50 or gs.bet2%50~=0 or gs.bet2>gs.chips2 then return false end
    if gs.chips2+gs.bet2*self.DIFFICULTY[gs.difficulty].payout>2147483647 then return false end
    gs.roundNo=gs.roundNo+1; gs.startChips2=gs.chips2; gs.chips2=gs.chips2-gs.bet2
    gs.ballCup=math.random(1,gs.cups); gs.guess=nil; gs.settled=false
    gs.return2,gs.net2,gs.reason,gs.resultData=nil,nil,nil,nil
    gs.cupAtSlot={}; for i=1,gs.cups do gs.cupAtSlot[i]=i end
    gs.phase="REVEAL"; self:SyncAmounts(gs); return true
end
function Logic:ApplyStep(gs,step)
    if gs.phase~="SHUFFLE" then return false end
    if not step.fake then self:SwapCups(gs,step.a,step.b) end
    return true
end
function Logic:Settle(gs,guess,reason)
    if gs.settled or (gs.phase~="REVEAL" and gs.phase~="SHUFFLE" and gs.phase~="GUESSING") then return false end
    if reason~="ABORT" and (gs.phase~="GUESSING" or not self:IsUnits(guess) or guess<1 or guess>gs.cups) then return false end
    gs.guess=guess; gs.reason=reason
    local won=reason~="ABORT" and guess==gs.ballCup
    gs.return2=won and gs.bet2*(1+self.DIFFICULTY[gs.difficulty].payout) or 0
    gs.net2=gs.return2-gs.bet2; gs.chips2=gs.chips2+gs.return2
    gs.roundsPlayed=gs.roundsPlayed+1
    gs.roundsWon=gs.roundsWon+(won and 1 or 0); gs.roundsLost=gs.roundsLost+(won and 0 or 1)
    gs.settled=true; gs.phase="RESULT_PENDING"; gs.sequence={}; self:SyncAmounts(gs); return true
end
function Logic:ResetRound(gs)
    if gs.phase~="RESULT" or gs.chips2<50 then return false end
    gs.phase="BETTING"; gs.bet2=0; gs.betConfirmed=false; gs.settled=nil
    gs.guess,gs.return2,gs.net2,gs.startChips2,gs.reason,gs.resultData=nil,nil,nil,nil,nil,nil,nil
    gs.sequence={}; gs.cupAtSlot={}; self:SyncAmounts(gs); return true
end
function Logic:ValidateSave(gs)
    if type(gs)~="table" or gs.saveVersion~=2 or not self:IsDifficulty(gs.difficulty)
        or gs.cups~=self.DIFFICULTY[gs.difficulty].cups or not self:IsUnits(gs.chips2) or not self:IsUnits(gs.bet2)
        or gs.bet2%50~=0 or gs.chips~=gs.chips2/2 or gs.bet~=gs.bet2/2
        or type(gs.tableId)~="string" or type(gs.runId)~="string" then return false end
    for _,key in ipairs({"roundNo","roundsPlayed","roundsWon","roundsLost"}) do if not self:IsUnits(gs[key]) then return false end end
    if gs.roundsPlayed~=gs.roundsWon+gs.roundsLost then return false end
    if gs.phase=="BETTING" then return gs.bet2<=gs.chips2 and gs.chips2>=50 and gs.roundNo==gs.roundsPlayed end
    if gs.phase=="GAMEOVER" and gs.roundNo==0 then return gs.legacyCapital==true and gs.chips2<50 and gs.bet2==0 and gs.roundsPlayed==0 end
    if gs.phase~="RESULT" and gs.phase~="GAMEOVER" and gs.phase~="RESULT_PENDING"
        and gs.phase~="REVEAL" and gs.phase~="SHUFFLE" and gs.phase~="GUESSING" then return false end
    if gs.roundNo<1 or gs.bet2<50 or not self:IsUnits(gs.startChips2) or gs.startChips2<gs.bet2
        or not self:IsUnits(gs.ballCup) or gs.ballCup<1 or gs.ballCup>gs.cups then return false end
    if type(gs.cupAtSlot)~="table" or #gs.cupAtSlot~=gs.cups then return false end
    local seen={}
    for _,index in ipairs(gs.cupAtSlot) do
        if not self:IsUnits(index) or index<1 or index>gs.cups or seen[index] then return false end
        seen[index]=true
    end
    if gs.phase=="REVEAL" or gs.phase=="SHUFFLE" or gs.phase=="GUESSING" then
        return not gs.settled and gs.chips2==gs.startChips2-gs.bet2 and gs.roundsPlayed==gs.roundNo-1
    end
    if not gs.settled or gs.roundsPlayed~=gs.roundNo or not self:IsUnits(gs.return2)
        or gs.net2~=gs.return2-gs.bet2 or gs.chips2~=gs.startChips2+gs.net2
        or (gs.reason~="GUESS" and gs.reason~="ABORT") then return false end
    if gs.reason=="GUESS" and (not self:IsUnits(gs.guess) or gs.guess<1 or gs.guess>gs.cups) then return false end
    local expected=gs.reason=="GUESS" and gs.guess==gs.ballCup and gs.bet2*(1+self.DIFFICULTY[gs.difficulty].payout) or 0
    return gs.return2==expected and (gs.phase=="RESULT_PENDING" or (gs.phase=="GAMEOVER")== (gs.chips2<50))
end
