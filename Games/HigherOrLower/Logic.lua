-- ============================================================
--  HigherOrLower – Logic.lua
--  Reine Spielregeln: Deck, Karten-Werte, Auswertung, Streak.
--  KEIN UI-Code hier.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HOL_Logic = {}
local Logic = ArcadiaNexus.HOL_Logic

-- ── Konstanten ────────────────────────────────────────────────
local SUITS = { "herz", "karo", "kreuz", "pik" }
local RANKS = { "2","3","4","5","6","7","8","9","10","J","Q","K","A" }

-- Streak-Multiplikator-Tabelle
local STREAK_MULTIPLIER = {
    [1]  = 1.0,
    [2]  = 1.2,
    [3]  = 1.5,
    [4]  = 2.0,
    [5]  = 2.5,
    [6]  = 3.0,
    [7]  = 4.0,
    [8]  = 5.0,
    [9]  = 7.0,
    [10] = 10.0,
}

-- Difficulty-Modifier für Cash-Out
local DIFFICULTY = {
    easy   = { modifier = 1.0  },
    normal = { modifier = 1.25 },
    hard   = { modifier = 2.0  },
}

-- ── Karten-Wert ───────────────────────────────────────────────
-- difficulty: "easy" (Ass=1), "normal"/"hard" (Ass=1 oder 14, zufällig beim Mischen)
-- Karten-Wertigkeit (von niedrig nach hoch, alle Schwierigkeitsgrade):
--   2=2, 3=3, ..., 10=10, J=11, Q=12, K=13, A=14 (höchste Karte)
-- PUSH tritt auf wenn zwei Karten denselben Wert haben (z.B. zwei Damen).
-- Der difficulty-Parameter bleibt für API-Kompatibilität erhalten.
function Logic:RankValue(rank, difficulty)
    if rank == "A"  then return 14 end
    if rank == "K"  then return 13 end
    if rank == "Q"  then return 12 end
    if rank == "J"  then return 11 end
    return tonumber(rank) or 0
end

-- ── Deck-System ───────────────────────────────────────────────
function Logic:NewDeck(difficulty)
    local deck = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            table.insert(deck, {
                suit  = suit,
                rank  = rank,
                value = self:RankValue(rank, difficulty),
            })
        end
    end
    -- Schwer: 2 Joker hinzufügen
    if difficulty == "hard" then
        table.insert(deck, { suit="X", rank="JOKER", value=-1, isJoker=true })
        table.insert(deck, { suit="X", rank="JOKER", value=-1, isJoker=true })
    end
    return self:Shuffle(deck)
end

function Logic:Shuffle(deck)
    return ArcadiaNexus.ArrayUtils.Shuffle(deck)
end

-- ── Tipp-Auswertung ───────────────────────────────────────────
-- guess: "HIGHER" | "LOWER"
-- Rückgabe: "WIN" | "LOSS" | "PUSH"
function Logic:Evaluate(currentCard, nextCard, guess)
    -- Joker: immer Verlust
    if nextCard.isJoker then return "LOSS" end

    local curr = currentCard.value
    local next = nextCard.value

    if next > curr then
        return guess == "HIGHER" and "WIN" or "LOSS"
    elseif next < curr then
        return guess == "LOWER"  and "WIN" or "LOSS"
    else
        return "PUSH"  -- Gleichstand: Unentschieden
    end
end

-- ── Streak & Multiplikator ────────────────────────────────────
function Logic:GetMultiplier(streak)
    return STREAK_MULTIPLIER[math.min(streak, 10)] or 10.0
end

-- Aufgelaufenen Gewinn berechnen (vor Difficulty-Bonus)
-- pendingWin = floor(bet * multiplier * diffModifier)
function Logic:CalcCashOut(bet, streak, difficulty)
    local mult    = self:GetMultiplier(streak)
    local diffMod = (DIFFICULTY[difficulty] or DIFFICULTY.easy).modifier
    return math.floor(bet * mult * diffMod)
end

-- ── Neuen Game-State erstellen ────────────────────────────────
function Logic:NewGameState(difficulty, startChips, startBet)
    return {
        difficulty  = difficulty or "easy",
        deck        = self:NewDeck(difficulty or "easy"),
        deckIndex   = 1,
        currentCard = nil,
        nextCard    = nil,
        streak      = 0,
        bet         = startBet or 25,
        chips       = startChips or 100,
        pendingWin  = 0,
        roundsPlayed = 0,
        maxStreak    = 0,   -- höchste Streak dieser Session
        maxMultiplier = 0,
        cashouts     = 0,   -- wie oft Cash Out getätigt
        _gameOverFired = false,
    }
end

-- ── Nächste Karte aus Deck ziehen ────────────────────────────
-- Gibt nil zurück wenn Deck leer
function Logic:DrawNext(gs)
    if gs.deckIndex > #gs.deck then return nil end
    local card     = gs.deck[gs.deckIndex]
    gs.deckIndex   = gs.deckIndex + 1
    return card
end

-- Prüft ob noch mindestens eine weitere Karte im Deck liegt
function Logic:HasNextCard(gs)
    return gs.deckIndex <= #gs.deck
end

-- ── Runde starten ─────────────────────────────────────────────
-- Zieht erste Karte (currentCard) und bereitet nextCard vor
-- Gibt false zurück wenn Deck leer
function Logic:StartRound(gs)
    local card = self:DrawNext(gs)
    if not card then return false end
    gs.currentCard = card
    gs.nextCard    = nil
    gs.streak      = 0
    gs.pendingWin  = 0
    return true
end

-- ── Tipp verarbeiten ─────────────────────────────────────────
-- Zieht nextCard, wertet Tipp aus
-- Rückgabe: { result="WIN"|"LOSS"|"PUSH", nextCard=card, deckEmpty=bool }
function Logic:ProcessGuess(gs, guess)
    local nextCard = self:DrawNext(gs)
    if not nextCard then
        -- Deck leer während Spieler tippt – automatischer Cash Out
        return { result="DECK_EMPTY", nextCard=nil, deckEmpty=true }
    end

    gs.nextCard = nextCard
    local result = self:Evaluate(gs.currentCard, nextCard, guess)

    if result == "WIN" then
        gs.streak    = gs.streak + 1
        gs.pendingWin = self:CalcCashOut(gs.bet, gs.streak, gs.difficulty)
        -- Höchste Streak tracken
        if gs.streak > (gs.maxStreak or 0) then gs.maxStreak = gs.streak end
        local mult = self:GetMultiplier(gs.streak)
        if mult > (gs.maxMultiplier or 0) then gs.maxMultiplier = mult end
    elseif result == "LOSS" then
        -- Einsatz verloren, pendingWin zurücksetzen (wird in Engine verbucht)
        gs.streak    = 0
        gs.pendingWin = 0
    end
    -- PUSH: streak und pendingWin bleiben unverändert

    -- currentCard vorrücken (nextCard wird neue currentCard)
    gs.currentCard = nextCard
    gs.nextCard    = nil

    -- Deck nach Zug leer?
    local deckEmpty = not self:HasNextCard(gs)

    return { result=result, nextCard=nextCard, deckEmpty=deckEmpty }
end

-- ── Cash Out verarbeiten ──────────────────────────────────────
-- Addiert pendingWin zu chips, setzt streak zurück
-- Rückgabe: Gewinnbetrag
function Logic:DoCashOut(gs)
    local win    = gs.pendingWin
    gs.chips     = gs.chips + win
    gs.streak    = 0
    gs.pendingWin = 0
    gs.roundsPlayed = (gs.roundsPlayed or 0) + 1
    gs.cashouts  = (gs.cashouts or 0) + 1
    return win
end

-- ── Verlust verarbeiten ───────────────────────────────────────
-- Zieht bet von chips ab, setzt streak zurück
-- Rückgabe: Verlustetrag
function Logic:DoLoss(gs)
    local loss   = gs.bet
    gs.chips     = math.max(0, gs.chips - loss)
    gs.streak    = 0
    gs.pendingWin = 0
    gs.roundsPlayed = (gs.roundsPlayed or 0) + 1
    return loss
end

-- ── Bankrott-Prüfung ──────────────────────────────────────────
-- Spieler ist bankrott wenn Kapital < Mindesteinsatz (25g)
function Logic:IsBankrupt(gs)
    return gs.chips < 25
end
