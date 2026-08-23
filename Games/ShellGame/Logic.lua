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
        chips       = chips or 100,
        bet         = bet   or 25,
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
        local attempts = 0
        repeat
            a = math.random(1, cupCount)
            b = math.random(1, cupCount)
            attempts = attempts + 1
        until a ~= b and not (a == lastA and b == lastB) and attempts < 20
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
-- Wird vom Renderer nach jeder echten Tausch-Animation aufgerufen.
-- SwapCups: tauscht ballCup wenn er an einem der beiden Slots steht.
-- a und b sind SLOT-Indizes (identisch zur Sequenz).
function Logic:SwapCups(gs, slotA, slotB)
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
        payout = math.floor(gs.bet * cfg.payout)
    else
        payout = -gs.bet
    end
    return won, payout
end

-- ── Score berechnen ───────────────────────────────────────────
function Logic:CalcScore(gs)
    return gs.chips - 100
end
