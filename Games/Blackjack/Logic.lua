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

-- ── Auszahlung ────────────────────────────────────────────────
-- Gibt Gewinn/Verlust zurück (positiv = Gewinn, negativ = Verlust)
-- bet: Einsatz des Spielers
function Logic:CalcPayout(playerHand, dealerHand, bet, insuranceBet, dealerBJ)
    local playerVal  = self:EvalHand(playerHand)
    local dealerVal  = self:EvalHand(dealerHand)
    local playerBJ   = self:IsBlackjack(playerHand)
    local playerBust = self:IsBust(playerHand)
    local dealerBust = self:IsBust(dealerHand)

    local payout = 0

    -- Insurance-Auflösung
    if insuranceBet and insuranceBet > 0 then
        if dealerBJ then
            payout = payout + insuranceBet * 2  -- zahlt 2:1
        else
            payout = payout - insuranceBet
        end
    end

    -- Haupt-Einsatz
    if playerBust then
        payout = payout - bet
    elseif dealerBust then
        payout = payout + bet
    elseif playerBJ and not dealerBJ then
        payout = payout + math.floor(bet * 1.5)  -- 3:2
    elseif playerBJ and dealerBJ then
        -- Push: kein Gewinn, kein Verlust
    elseif dealerBJ and not playerBJ then
        payout = payout - bet
    elseif playerVal > dealerVal then
        payout = payout + bet
    elseif playerVal < dealerVal then
        payout = payout - bet
    end
    -- playerVal == dealerVal → Push (0)

    return payout
end

-- ── Split-Prüfung ─────────────────────────────────────────────
function Logic:CanSplit(hand)
    return #hand == 2 and hand[1].rank == hand[2].rank
end

-- ── Dealer-Logik ──────────────────────────────────────────────
-- Dealer zieht bis 17 (Soft 17 = Stand bei allen Varianten hier)
function Logic:DealerShouldHit(hand)
    return self:EvalHand(hand) < 17
end

-- ── KI-Strategien ─────────────────────────────────────────────

-- Einfach: Dealer-Logik (Hit < 17)
function Logic:AIDecideEasy(hand)
    if self:EvalHand(hand) < 17 then return "HIT" end
    return "STAND"
end

-- Normal: Basic Strategy (vereinfacht, Hard/Soft Hände)
function Logic:AIDecideNormal(hand, dealerUpcard)
    local total    = self:EvalHand(hand)
    local isSoft   = self:IsSoftHand(hand)
    local upVal    = self:CardValue(dealerUpcard)

    if isSoft then
        -- Soft-Hand-Regeln
        if total <= 17 then return "HIT" end
        if total == 18 then
            if upVal == 2 or upVal == 7 or upVal == 8 then return "STAND" end
            return "HIT"
        end
        return "STAND"  -- Soft 19+
    else
        -- Hard-Hand-Regeln
        if total <= 8  then return "HIT" end
        if total >= 17 then return "STAND" end
        if total >= 12 and total <= 16 then
            if upVal >= 2 and upVal <= 6 then return "STAND" end
            return "HIT"
        end
        if total == 11 then
            if upVal < 11 then return "DOUBLE" end  -- Double wenn Dealer kein Ass
            return "HIT"
        end
        if total == 10 then
            if upVal < 10 then return "DOUBLE" end
            return "HIT"
        end
        if total == 9 then
            if upVal >= 3 and upVal <= 6 then return "DOUBLE" end
            return "HIT"
        end
        return "HIT"
    end
end

-- Schwer: Basic Strategy + Hi-Lo Count
function Logic:AIDecideHard(hand, dealerUpcard, trueCount)
    local base = self:AIDecideNormal(hand, dealerUpcard)
    -- Anpassung basierend auf True Count
    if trueCount and trueCount >= 2 then
        -- Deck ist reich an hohen Karten → aggressiver Doppeln
        local total = self:EvalHand(hand)
        if total == 10 or total == 11 then return "DOUBLE" end
    elseif trueCount and trueCount <= -2 then
        -- Deck arm an hohen Karten → konservativer
        if base == "DOUBLE" then return "HIT" end
    end
    return base
end

-- Hi-Lo Kartenzählen
function Logic:HiLoValue(card)
    local r = card.rank
    if r == "2" or r == "3" or r == "4" or r == "5" or r == "6" then
        return 1
    elseif r == "7" or r == "8" or r == "9" then
        return 0
    else
        return -1  -- 10, J, Q, K, A
    end
end

function Logic:UpdateCount(card, state)
    local val = self:HiLoValue(card)
    state.runningCount = (state.runningCount or 0) + val
    local decksLeft = math.max(1, #state.deck / 52)
    state.trueCount = state.runningCount / decksLeft
end

-- ── Neues Spiel initialisieren ────────────────────────────────
-- Gibt vollständigen Game-State zurück
function Logic:NewGameState(difficulty, aiCount, startChips)
    local deckCount = (difficulty == "hard") and 4 or 1
    local gs = {
        difficulty    = difficulty,
        aiCount       = aiCount or 0,
        chips         = startChips or 100,
        bet           = 0,
        betConfirmed  = false,
        insuranceBet  = 0,
        deck          = self:NewDeck(deckCount),
        deckCount     = deckCount,
        playerHands   = { {} },  -- [1] = Haupthand, [2] = Split-Hand (optional)
        activeHand    = 1,       -- welche Hand gerade dran ist (bei Split)
        dealerHand    = {},
        aiHands       = {},      -- [i] = Hand für KI-Spieler i
        aiStates      = {},      -- [i] = "playing"|"stand"|"bust"
        playerState   = "playing",  -- "playing"|"stand"|"bust"|"blackjack"
        dealerState   = "waiting",  -- "waiting"|"playing"|"stand"|"bust"|"blackjack"
        firstAction   = true,    -- für Double/Split/Insurance-Validierung
        insuranceOpen = false,   -- Insurance-Angebot aktiv?
        runningCount  = 0,
        trueCount     = 0,
        cardsDealt    = 0,
        reshuffleAt   = math.floor(deckCount * 52 * 0.75),
        blackjacks    = 0,   -- Achievement-Tracking BJ_BLACKJACK
    }
    -- KI-Hände initialisieren
    for i = 1, aiCount do
        gs.aiHands[i]  = {}
        gs.aiStates[i] = "playing"
    end
    return gs
end

-- ── Deal-Phase ────────────────────────────────────────────────
-- Gibt Karten-Sequenz zurück: { {target, card}, ... }
-- target: "player" | "dealer" | "ai1" | "ai2"
function Logic:DealInitial(gs)
    local sequence = {}
    -- Klassische Reihenfolge: Spieler, Dealer, Spieler, Dealer (verdeckt)
    -- + KI-Spieler erhalten je 2 Karten nach Dealer
    local function deal(target)
        local card = self:DrawCard(gs.deck)
        gs.cardsDealt = gs.cardsDealt + 1
        if gs.difficulty == "hard" then self:UpdateCount(card, gs) end
        table.insert(sequence, { target = target, card = card })
        return card
    end

    -- Runde 1: alle offen
    table.insert(gs.playerHands[1], deal("player"))
    table.insert(gs.dealerHand, deal("dealer_open"))
    for i = 1, gs.aiCount do
        table.insert(gs.aiHands[i], deal("ai" .. i))
    end
    -- Runde 2
    table.insert(gs.playerHands[1], deal("player"))
    local dealerCard2 = deal("dealer_hidden")  -- verdeckt bis DEALER_TURN
    dealerCard2.hidden = true
    table.insert(gs.dealerHand, dealerCard2)
    for i = 1, gs.aiCount do
        table.insert(gs.aiHands[i], deal("ai" .. i))
    end

    -- Insurance-Check: Dealer-Upcard = Ass?
    if gs.dealerHand[1].rank == "A" then
        gs.insuranceOpen = true
    end

    return sequence
end

-- ── Spieler-Aktion: Hit ───────────────────────────────────────
function Logic:PlayerHit(gs)
    local hand = gs.playerHands[gs.activeHand]
    local card = self:DrawCard(gs.deck)
    gs.cardsDealt = gs.cardsDealt + 1
    if gs.difficulty == "hard" then self:UpdateCount(card, gs) end
    table.insert(hand, card)
    gs.firstAction = false
    if self:IsBust(hand) then
        gs.playerState = "bust"
    end
    return card
end

-- ── Spieler-Aktion: Stand ─────────────────────────────────────
function Logic:PlayerStand(gs)
    -- Wenn Split-Hand vorhanden und Hand 1 aktiv → zu Hand 2 wechseln
    if gs.activeHand == 1 and gs.playerHands[2] then
        gs.activeHand  = 2
        gs.firstAction = true
    else
        gs.playerState = "stand"
    end
end

-- ── Spieler-Aktion: Double Down ───────────────────────────────
-- Gibt gezogene Karte zurück, nil wenn nicht erlaubt
function Logic:PlayerDouble(gs)
    if not gs.firstAction then return nil end
    if gs.chips < gs.bet then return nil end
    gs.chips = gs.chips - gs.bet
    gs.bet   = gs.bet * 2
    local card = self:PlayerHit(gs)
    -- Erzwinge Stand nach Double
    if gs.playerState ~= "bust" then
        gs.playerState = "stand"
    end
    return card
end

-- ── Spieler-Aktion: Split ─────────────────────────────────────
function Logic:PlayerSplit(gs)
    if not gs.firstAction             then return false end
    if not self:CanSplit(gs.playerHands[1]) then return false end
    if gs.chips < gs.bet              then return false end
    -- Zweiten Einsatz abziehen
    gs.chips = gs.chips - gs.bet
    -- Hand aufteilen
    local hand1 = gs.playerHands[1]
    local hand2 = { hand1[2] }
    hand1[2]    = nil
    -- Neue Karten je Hand
    local c1 = self:DrawCard(gs.deck)
    gs.cardsDealt = gs.cardsDealt + 1
    table.insert(hand1, c1)
    local c2 = self:DrawCard(gs.deck)
    gs.cardsDealt = gs.cardsDealt + 1
    table.insert(hand2, c2)
    gs.playerHands[2] = hand2
    gs.firstAction    = true
    return true
end

-- ── Spieler-Aktion: Insurance ─────────────────────────────────
function Logic:PlayerInsurance(gs)
    if not gs.insuranceOpen then return false end
    local maxIns = math.floor(gs.bet / 2)
    if gs.chips < maxIns then return false end
    gs.chips        = gs.chips - maxIns
    gs.insuranceBet = maxIns
    gs.insuranceOpen = false
    return true
end

function Logic:DeclineInsurance(gs)
    gs.insuranceOpen = false
end

-- ── Dealer-Zug ────────────────────────────────────────────────
-- Gibt Sequenz gezogener Karten zurück
function Logic:DealerPlay(gs)
    local sequence = {}
    -- Verdeckte Karte aufdecken
    if gs.dealerHand[2] then
        gs.dealerHand[2].hidden = false
        table.insert(sequence, { reveal = true, card = gs.dealerHand[2] })
    end
    -- Dealer zieht bis 17
    while self:DealerShouldHit(gs.dealerHand) do
        local card = self:DrawCard(gs.deck)
        gs.cardsDealt = gs.cardsDealt + 1
        if gs.difficulty == "hard" then self:UpdateCount(card, gs) end
        table.insert(gs.dealerHand, card)
        table.insert(sequence, { card = card })
    end
    if self:IsBust(gs.dealerHand) then
        gs.dealerState = "bust"
    elseif self:IsBlackjack(gs.dealerHand) then
        gs.dealerState = "blackjack"
    else
        gs.dealerState = "stand"
    end
    return sequence
end

-- ── KI-Spieler ziehen ────────────────────────────────────────
-- Gibt für jede KI eine Karten-Sequenz zurück
function Logic:AIPlay(gs)
    local allSequences = {}
    local dealerUp = gs.dealerHand[1]
    for i = 1, gs.aiCount do
        local seq = {}
        while gs.aiStates[i] == "playing" do
            local decision
            if gs.difficulty == "easy" then
                decision = self:AIDecideEasy(gs.aiHands[i])
            elseif gs.difficulty == "normal" then
                decision = self:AIDecideNormal(gs.aiHands[i], dealerUp)
            else
                decision = self:AIDecideHard(gs.aiHands[i], dealerUp, gs.trueCount)
            end
            if decision == "HIT" or decision == "DOUBLE" then
                local card = self:DrawCard(gs.deck)
                gs.cardsDealt = gs.cardsDealt + 1
                if gs.difficulty == "hard" then self:UpdateCount(card, gs) end
                table.insert(gs.aiHands[i], card)
                table.insert(seq, { aiIdx = i, card = card })
                if self:IsBust(gs.aiHands[i]) then
                    gs.aiStates[i] = "bust"
                end
                if decision == "DOUBLE" then
                    gs.aiStates[i] = "stand"
                end
            else
                gs.aiStates[i] = "stand"
            end
        end
        allSequences[i] = seq
    end
    return allSequences
end

-- ── Runden-Abrechnung ─────────────────────────────────────────
-- Gibt { payout, result, insuranceResult } zurück
function Logic:SettleRound(gs)
    local dealerBJ = self:IsBlackjack(gs.dealerHand)
    local results  = {}

    for hi = 1, #gs.playerHands do
        local hand = gs.playerHands[hi]
        if hand and #hand > 0 then
            local ins = (hi == 1) and gs.insuranceBet or 0
            local bet = (hi == 1) and gs.bet or (gs.bet / 2)  -- Split: halber Einsatz je Hand (bereits verbucht)
            -- Bei Split wurde bei PlayerSplit bereits der zweite Einsatz abgezogen,
            -- daher verwenden wir immer gs.bet als Einsatz je Hand
            if hi == 2 then bet = math.floor(gs.bet / 2) end  -- ursprünglicher Einsatz war gs.bet/2 je Hand
            local payout = self:CalcPayout(hand, gs.dealerHand, gs.bet, ins, dealerBJ)
            -- Korrekt: bei Split hat jede Hand den ursprünglichen bet als Einsatz
            -- (gs.bet wurde bei Double bereits verdoppelt – hier zählt der Einsatz pro Hand)
            gs.chips = gs.chips + gs.bet + payout  -- Einsatz zurück + Gewinn/Verlust

            local result = "push"
            if self:IsBust(hand) then
                result = "bust"
            elseif dealerBJ and not self:IsBlackjack(hand) then
                result = "lose"
            elseif self:IsBlackjack(hand) and not dealerBJ then
                result = "blackjack"
                gs.blackjacks = (gs.blackjacks or 0) + 1
            elseif payout > 0 then
                result = "win"
            elseif payout < 0 then
                result = "lose"
            end

            table.insert(results, { payout = payout, result = result, handIdx = hi })
        end
    end

    -- Reshuffle bei 75% (alle Modi)
    if gs.cardsDealt >= gs.reshuffleAt then
        gs.deck         = self:NewDeck(gs.deckCount)
        gs.runningCount = 0
        gs.trueCount    = 0
        gs.cardsDealt   = 0
    end

    return results
end
