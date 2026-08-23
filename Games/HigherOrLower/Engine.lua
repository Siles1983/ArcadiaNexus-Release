-- ============================================================
--  HigherOrLower – Engine.lua
--  Spielfluss, State-Machine, Runden-Verwaltung.
--
--  State-Machine:
--    IDLE → BETTING → PLAYING → STREAK_PROMPT → PLAYING
--                             ↘ RESULT
--                                    ↘ GAMEOVER (Bankrott)
--
--  Ablauf:
--    1. "Spiel starten" → BETTING (Chips aktiv, Higher/Lower disabled)
--    2. Chip klicken   → bet > 0, "Ziehen"-Button erscheint
--    3. "Ziehen"       → erste Karte, PLAYING (Higher/Lower aktiv, Ziehen weg)
--    4. Higher/Lower   → Tipp auswerten, ggf. STREAK_PROMPT
--    5. Bei RESULT     → "Neue Runde" kehrt zu BETTING zurück
--                        (Ziehen-Button erscheint wieder für neue erste Karte)
--
--  Regeln:
--  - TimerGuard (Core/TimerGuard) für Guess-Delays und Bankrott-Timer
--  - Kein OnUpdate-Loop
--  - OnHide → SaveAndPause (Streak wird NICHT gespeichert)
--  - GAME_RESULT nur wenn roundsPlayed > 0
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HOL_Engine = {}
local E = ArcadiaNexus.HOL_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

-- ── Sound ─────────────────────────────────────────────────────
local SND_FLIP    = 774
local SND_CORRECT = 888
local SND_WRONG   = 847
local SND_CASHOUT = 878
local SND_JOKER   = 847

local SND_KEY_MAP = {
    flip    = "soundOnFlip",
    correct = "soundOnCorrect",
    wrong   = "soundOnWrong",
    cashout = "soundOnCashout",
    joker   = "soundOnJoker",
}

local function PlayHOLSound(key, soundId)
    local S = ArcadiaNexus.HOL_Settings
    if not S or not S:Get("soundEnabled") then return end
    local sk = SND_KEY_MAP[key]
    if sk and S:Get(sk) then PlaySound(soundId, "Master") end
end

-- ── Hilfsfunktionen ───────────────────────────────────────────
function E:_InvalidateTimers()
    _timerGuard:Cancel()
end

function E:_SetState(newState)
    E.state = newState
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:OnStateChanged(newState) end
end

-- ── Lifecycle ─────────────────────────────────────────────────
-- StartGame: landet direkt in BETTING (Chips aktiv, Higher/Lower + Ziehen disabled)
function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("HIGHERORLOWER", E._sessionId)
    self:_InvalidateTimers()

    local S     = ArcadiaNexus.HOL_Settings
    local Logic = ArcadiaNexus.HOL_Logic
    local diff  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy"
    local chips = S and S:LoadChips() or 100

    E.gameState     = Logic:NewGameState(diff, chips, 0)
    E.state         = "BETTING"

    local R = ArcadiaNexus.HOL_Renderer
    if R then
        R:OnStateChanged("BETTING")
        R:OnGameStarted(E.gameState)
    end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("HIGHERORLOWER", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()

    local S = ArcadiaNexus.HOL_Settings
    if E.gameState and S then
        S:SaveChips(E.gameState.chips)
        S:Set("difficulty", E.gameState.difficulty)
    end

    if E.state ~= "IDLE"
    and E.gameState
    and not E.gameState._gameOverFired
    and (E.gameState.roundsPlayed or 0) > 0 then
        local gs    = E.gameState
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "HIGHERORLOWER",
            difficulty = gs.difficulty,
            score      = 0,
            result     = (gs.chips or 0) >= 100 and "WIN" or "LOSS",
            stats      = {
                finalChips     = gs.chips,
                maxStreak      = gs.maxStreak or 0,
                maxMultiplier  = gs.maxMultiplier or 0,
                cashouts       = gs.cashouts  or 0,
            },
        })
    end

    local R = ArcadiaNexus.HOL_Renderer
    if R then R:OnGameStopped() end
    E.gameState = nil
    E.state     = "IDLE"
end

function E:SaveAndPause()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("HIGHERORLOWER", E._sessionId)
    end
    self:_InvalidateTimers()
    local S = ArcadiaNexus.HOL_Settings
    if E.gameState and S then
        S:SaveChips(E.gameState.chips)
        S:Set("difficulty", E.gameState.difficulty)
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("HIGHERORLOWER", E._sessionId)
        E._sessionId = nil
    end
    E.gameState = nil
    E.state     = "IDLE"
end

-- ── Einsatz anpassen (nur im BETTING) ─────────────────────────
function E:AdjustBet(delta)
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    local newBet = (gs.bet or 0) + delta
    newBet = math.max(0, math.min(newBet, gs.chips))
    gs.bet = newBet
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:UpdateHUD(gs) end
end

-- ── Erste Karte ziehen ("Ziehen"-Button) ──────────────────────
-- Nur aufrufbar wenn bet > 0. Zieht erste Karte, wechselt zu PLAYING.
function E:DealFirstCard()
    if E.state ~= "BETTING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.HOL_Logic
    if not gs or (gs.bet or 0) <= 0 then return end
    if gs.chips < gs.bet then return end

    gs.chips = gs.chips - gs.bet

    local ok = Logic:StartRound(gs)
    if not ok then
        gs.chips = gs.chips + gs.bet
        self:_EndResult("DECK_EMPTY", 0)
        return
    end

    local S = ArcadiaNexus.HOL_Settings
    if S then S:SaveChips(gs.chips) end

    self:_SetState("PLAYING")
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:OnRoundStarted(gs) end
end

-- ── Tipp: Higher / Lower ──────────────────────────────────────
function E:Guess(guess)
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.HOL_Logic
    if not gs then return end

    _timerGuard:Cancel()
    local R   = ArcadiaNexus.HOL_Renderer

    if R then R:_SetActionButtonsEnabled(false) end

    _timerGuard:After(0.3, function()
        local outcome = Logic:ProcessGuess(gs, guess)
        PlayHOLSound("flip", SND_FLIP)
        if R then R:ShowNextCard(outcome.nextCard or gs.currentCard) end

        _timerGuard:After(0.2, function()
            if outcome.result == "DECK_EMPTY" then
                local win = Logic:DoCashOut(gs)
                PlayHOLSound("cashout", SND_CASHOUT)
                local S = ArcadiaNexus.HOL_Settings
                if S then S:SaveChips(gs.chips) end
                self:_EndResult("CASHOUT_AUTO", win)

            elseif outcome.result == "WIN" then
                PlayHOLSound("correct", SND_CORRECT)
                if R then R:UpdateHUD(gs) end
                if outcome.deckEmpty then
                    local win = Logic:DoCashOut(gs)
                    PlayHOLSound("cashout", SND_CASHOUT)
                    local S = ArcadiaNexus.HOL_Settings
                    if S then S:SaveChips(gs.chips) end
                    self:_EndResult("CASHOUT_AUTO", win)
                else
                    self:_SetState("STREAK_PROMPT")
                    if R then R:ShowStreakPrompt(gs) end
                end

            elseif outcome.result == "LOSS" then
                if outcome.nextCard and outcome.nextCard.isJoker then
                    PlayHOLSound("joker", SND_JOKER)
                else
                    PlayHOLSound("wrong", SND_WRONG)
                end
                local loss = Logic:DoLoss(gs)
                local S = ArcadiaNexus.HOL_Settings
                if S then S:SaveChips(gs.chips) end
                self:_EndResult("LOSS", loss)

            elseif outcome.result == "PUSH" then
                if R then
                    R:ShowPushFeedback()
                    R:UpdateHUD(gs)
                    R:_SetActionButtonsEnabled(true)
                end
            end
        end)
    end)
end

-- ── Cash Out ──────────────────────────────────────────────────
function E:CashOut()
    if E.state ~= "STREAK_PROMPT" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.HOL_Logic
    if not gs then return end
    local win = Logic:DoCashOut(gs)
    PlayHOLSound("cashout", SND_CASHOUT)
    local S = ArcadiaNexus.HOL_Settings
    if S then S:SaveChips(gs.chips) end
    self:_EndResult("CASHOUT", win)
end

-- ── Weiter riskieren ──────────────────────────────────────────
function E:ContinueStreak()
    if E.state ~= "STREAK_PROMPT" then return end
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:HideStreakPrompt() end
    self:_SetState("PLAYING")
end

-- ── Runden-Ende ───────────────────────────────────────────────
function E:_EndResult(reason, amount)
    local gs = E.gameState
    if not gs then return end

    local Logic = ArcadiaNexus.HOL_Logic
    if Logic and Logic:IsBankrupt(gs) then
        self:_GameOver()
        return
    end

    self:_SetState("RESULT")
    if reason == "CASHOUT" or reason == "CASHOUT_AUTO" then
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "HIGHERORLOWER",
            difficulty = gs.difficulty,
            score      = amount or 0,
            result     = "STATS",
            recordPlayed = false,
            stats      = {
                finalChips     = gs.chips,
                maxStreak      = gs.maxStreak or 0,
                maxMultiplier  = gs.maxMultiplier or 0,
                cashouts       = gs.cashouts or 0,
            },
        })
    end
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:ShowResult(gs, reason, amount) end
end

-- ── Neue Runde (aus RESULT) ───────────────────────────────────
-- Kehrt zu BETTING zurück. Einsatz = 0. Ziehen-Button erscheint wieder.
function E:NewRound()
    if E.state ~= "RESULT" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.HOL_Logic
    if not gs then return end

    if not Logic:HasNextCard(gs) or (#gs.deck - gs.deckIndex + 1) < 10 then
        gs.deck      = Logic:NewDeck(gs.difficulty)
        gs.deckIndex = 1
    end
    gs.currentCard = nil
    gs.nextCard    = nil
    gs.streak      = 0
    gs.pendingWin  = 0
    gs.bet         = 0

    self:_SetState("BETTING")
    local R = ArcadiaNexus.HOL_Renderer
    if R then R:OnNewRound(gs) end
end

-- ── Game Over (Bankrott) ──────────────────────────────────────
function E:_GameOver()
    local gs = E.gameState
    if not gs then return end
    self:_SetState("GAMEOVER")

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "HIGHERORLOWER",
        difficulty = gs.difficulty,
        score      = 0,
        result     = "LOSS",
        stats      = {
            finalChips     = gs.chips,
            maxStreak      = gs.maxStreak or 0,
            maxMultiplier  = gs.maxMultiplier or 0,
            cashouts       = gs.cashouts  or 0,
        },
    })
    gs._gameOverFired = true

    -- Kapital auf 100g zurücksetzen (wie Blackjack)
    local S = ArcadiaNexus.HOL_Settings
    if S then S:ResetChips() end
    gs.chips = 100

    local R = ArcadiaNexus.HOL_Renderer
    if R then R:ShowGameOver(gs) end
end

-- ── Schwierigkeit ändern ──────────────────────────────────────
function E:SetDifficulty(diff)
    local S = ArcadiaNexus.HOL_Settings
    if S then S:Set("difficulty", diff) end
    if E.gameState then E.gameState.difficulty = diff end
end
