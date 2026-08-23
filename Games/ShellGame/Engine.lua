-- ============================================================
--  ShellGame – Engine.lua
--  Spielfluss, State-Machine, Runden-Verwaltung.
--
--  State-Machine:
--    IDLE → BETTING → REVEAL → SHUFFLE → GUESSING → RESULT
--                                                  ↘ GAMEOVER
--
--  Regeln:
--  - TimerGuard (Core/TimerGuard) für Reveal/Result-Delays und Sequenzen
--  - OnHide → StopGame
--  - GAME_RESULT-Event bei Bankrott oder manuellem Beenden
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SHG_Engine = {}
local E = ArcadiaNexus.SHG_Engine

E._sessionId = nil

E.state     = "IDLE"
E.gameState = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

-- ── Sound-Hilfsfunktion ───────────────────────────────────────
local SND_REVEAL   = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_SHUFFLE  = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_LIFT     = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774
local SND_WIN      = SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK      or 888
local SND_LOSE     = SOUNDKIT and SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 847
local SND_BANKRUPT = SOUNDKIT and SOUNDKIT.IG_QUEST_ABANDON                 or 847

local SND_KEYS = {
    reveal   = { key="soundOnReveal",   id=SND_REVEAL  },
    shuffle  = { key="soundOnShuffle",  id=SND_SHUFFLE },
    lift     = { key="soundOnLift",     id=SND_LIFT    },
    win      = { key="soundOnWin",      id=SND_WIN     },
    lose     = { key="soundOnLose",     id=SND_LOSE    },
    bankrupt = { key="soundOnBankrupt", id=SND_BANKRUPT},
}

local function PlaySHGSound(event)
    local S = ArcadiaNexus.SHG_Settings
    if not S or not S:Get("soundEnabled") then return end
    local entry = SND_KEYS[event]
    if entry and S:Get(entry.key) then
        PlaySound(entry.id, "Master")
    end
end

-- ── Timer-Infrastruktur ───────────────────────────────────────
function E:_InvalidateTimers()
    _timerGuard:Cancel()
end

function E:_RunSequence(steps, onDone)
    _timerGuard:RunSequence(steps, onDone)
end

-- ── State-Setter ──────────────────────────────────────────────
function E:_SetState(newState)
    E.state = newState
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnStateChanged(newState) end
end

-- ── Init / Lifecycle ──────────────────────────────────────────
function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("SHELLGAME", E._sessionId)
    self:_InvalidateTimers()

    local S     = ArcadiaNexus.SHG_Settings
    local diff  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy"
    local chips = S and S:LoadChips() or 100

    -- Einsatz immer auf 0 starten — Spieler setzt selbst
    local bet = 0

    local Logic = ArcadiaNexus.SHG_Logic
    E.gameState = Logic:NewGameState(diff, chips, bet)

    E.state = "BETTING"
    local R = ArcadiaNexus.SHG_Renderer
    if R then
        R:OnStateChanged("BETTING")
        R:OnGameStarted(E.gameState)
    end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("SHELLGAME", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()

    local S = ArcadiaNexus.SHG_Settings
    if E.gameState and S then
        S:SaveChips(E.gameState.chips)
        S:SaveBet(E.gameState.bet)
    end

    -- GAME_RESULT nur wenn mindestens eine Runde gespielt
    if E.state ~= "IDLE"
    and E.gameState
    and not E.gameState._gameOverFired
    and (E.gameState.roundsPlayed or 0) > 0 then
        local gs    = E.gameState
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "SHELLGAME",
            difficulty = gs.difficulty,
            score      = 0,
            result     = (gs.chips or 0) >= 100 and "WIN" or "LOSS",
            stats      = {
                finalChips   = gs.chips,
                roundsPlayed = gs.roundsPlayed,
                roundsWon    = gs.roundsWon,
                roundsLost   = gs.roundsLost,
            },
        })
    end

    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnGameStopped() end
    E.gameState = nil
    E.state     = "IDLE"
end

-- ── Einsatz-Verwaltung (BETTING-State, Blackjack-Pattern) ────────────
-- Chip hinzufügen (Linksklick)
function E:AddBet(amount)
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    local newBet = (gs.bet or 0) + amount
    if newBet > gs.chips then return end
    gs.bet          = newBet
    gs.betConfirmed = true
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:UpdateBetDisplay(gs) end
end

-- Chip einer Farbe entfernen (Rechtsklick)
function E:RemoveBetOfColor(color, amount)
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    local newBet = (gs.bet or 0) - amount
    if newBet < 0 then newBet = 0 end
    gs.bet = newBet
    if gs.bet == 0 then gs.betConfirmed = false end
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:UpdateBetDisplay(gs) end
end

-- ── Runde starten ─────────────────────────────────────────────
function E:StartRound()
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    if not gs.betConfirmed or (gs.bet or 0) <= 0 then return end
    if gs.chips < gs.bet then return end

    -- Einsatz abziehen
    gs.chips = gs.chips - gs.bet

    -- Neue Kugel-Position für diese Runde
    local Logic = ArcadiaNexus.SHG_Logic
    local cfg   = Logic.DIFFICULTY[gs.difficulty] or Logic.DIFFICULTY.easy
    gs.ballCup  = math.random(1, cfg.cups)
    gs.guess    = nil

    self:_SetState("REVEAL")
    self:_EnterReveal()
end

-- ── Phase 1: REVEAL ───────────────────────────────────────────
function E:_EnterReveal()
    local R = ArcadiaNexus.SHG_Renderer
    PlaySHGSound("reveal")

    _timerGuard:Cancel()

    -- Schritt 1: Ball + angehobenen Cup sofort anzeigen
    if R then R:ShowRevealOpen(E.gameState) end

    -- Schritt 2: 1.8s warten (Ball sichtbar)
    _timerGuard:After(1.8, function()
        -- Schritt 3: Cup fällt herunter, danach Shuffle
        if R then
            R:AnimateCupClose(E.gameState, function()
                self:_EnterShuffle()
            end)
        else
            self:_EnterShuffle()
        end
    end)
end

-- ── Phase 2: SHUFFLE ──────────────────────────────────────────
function E:_EnterShuffle()
    if E.state ~= "REVEAL" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.SHG_Logic
    if not gs then return end

    gs.sequence = Logic:GenerateSequence(gs.difficulty)

    self:_SetState("SHUFFLE")
    PlaySHGSound("shuffle")

    local R = ArcadiaNexus.SHG_Renderer
    if R then
        R:HideReveal()
        R:RunShuffleSequence(gs.sequence, function()
            if E.state ~= "SHUFFLE" then return end
            self:_EnterGuessing()
        end)
    else
        self:_EnterGuessing()
    end
end

-- ── Phase 3: GUESSING ─────────────────────────────────────────
function E:_EnterGuessing()
    self:_SetState("GUESSING")
    -- OnStateChanged("GUESSING") aktiviert die Becher-Buttons im Renderer
end

-- ── Spieler-Tipp ─────────────────────────────────────────────
function E:MakeGuess(cupIndex)
    if E.state ~= "GUESSING" then return end
    local gs = E.gameState
    if not gs then return end

    gs.guess = cupIndex
    self:_SetState("RESULT")
    self:_EvaluateResult()
end

-- ── Phase 4: RESULT ───────────────────────────────────────────
function E:_EvaluateResult()
    local gs    = E.gameState
    local Logic = ArcadiaNexus.SHG_Logic
    if not gs then return end

    gs.roundsPlayed = (gs.roundsPlayed or 0) + 1

    local won, payout = Logic:EvaluateGuess(gs)

    if won then
        gs.chips      = gs.chips + gs.bet + payout  -- Einsatz zurück + Gewinn
        gs.roundsWon  = (gs.roundsWon or 0) + 1
        PlaySHGSound("win")
    else
        -- Einsatz wurde bereits bei StartRound abgezogen
        gs.roundsLost = (gs.roundsLost or 0) + 1
        PlaySHGSound("lose")
    end

    -- Kapital persistieren
    local S = ArcadiaNexus.SHG_Settings
    if S then S:SaveChips(gs.chips) end

    local bankrupt = gs.chips < 25
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:ShowResult(gs, won, payout, bankrupt) end

    -- Continue-Prompt nach dem Reveal; Bankrott kommt aus ShowResult nach der Animation
    if not bankrupt then
        _timerGuard:After(2.0, function()
            if not E.gameState or E.state == "GAMEOVER" or E.state == "IDLE" then
                return
            end
            self:_EnterContinuePrompt()
        end)
    end
end

-- ── Continue-Prompt ───────────────────────────────────────────
function E:_EnterContinuePrompt()
    self:_SetState("CONTINUE_PROMPT")
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:ShowContinuePrompt(E.gameState) end
end

-- Spieler wählt: Weiter spielen
function E:ContinuePlaying()
    if E.state ~= "CONTINUE_PROMPT" then return end
    local gs = E.gameState
    if not gs then return end

    -- Einsatz für neue Runde zurücksetzen
    gs.bet          = 0
    gs.betConfirmed = false

    self:_SetState("BETTING")
    local R = ArcadiaNexus.SHG_Renderer
    if R then R:OnNewRound(gs) end
end

-- Spieler wählt: Spiel beenden
function E:EndGame()
    if E.state ~= "CONTINUE_PROMPT" then return end
    self:StopGame()
end

-- ── Bankrott ──────────────────────────────────────────────────
function E:_GameOver()
    local gs = E.gameState
    if not gs then return end

    self:_SetState("GAMEOVER")
    PlaySHGSound("bankrupt")

    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "SHELLGAME",
        difficulty = gs.difficulty,
        score      = 0,
        result     = "LOSS",
        stats      = {
            finalChips   = gs.chips,
            roundsPlayed = gs.roundsPlayed,
            roundsWon    = gs.roundsWon,
            roundsLost   = gs.roundsLost,
        },
    })
    gs._gameOverFired = true

    local S = ArcadiaNexus.SHG_Settings
    if S then S:ResetChips() end

    local R = ArcadiaNexus.SHG_Renderer
    if R then R:ShowGameOver(gs) end
end

-- ── Schwierigkeit ändern (nur IDLE / BETTING) ─────────────────
function E:SetDifficulty(diff)
    local S = ArcadiaNexus.SHG_Settings
    if S then S:Set("difficulty", diff) end
    if E.gameState and (E.state == "IDLE" or E.state == "BETTING") then
        E.gameState.difficulty = diff
        -- Becherzahl anpassen
        local Logic = ArcadiaNexus.SHG_Logic
        local cfg   = Logic.DIFFICULTY[diff] or Logic.DIFFICULTY.easy
        E.gameState.cups = cfg.cups
        local R = ArcadiaNexus.SHG_Renderer
        if R and R.UpdateCupCount then R:UpdateCupCount(E.gameState) end
    end
end
