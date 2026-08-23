-- ============================================================
--  Blackjack – Engine.lua
--  Spielfluss, State-Machine, Runden-Verwaltung.
--
--  State-Machine:
--    IDLE → BETTING → PLAYING → DEALER_TURN → ROUND_RESULT
--                                              ↘ GAMEOVER (Bankrott)
--
--  Regeln:
--  - TimerGuard (Core/TimerGuard) für Deal-Sequenzen und Delays
--  - OnHide → StopGame (kein Spiel läuft im Hintergrund)
--  - GAME_RESULT-Event bei Bankrott oder manuellem Beenden
--  - Spielregeln NUR in Logic.lua, UI NUR in Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BJ_Engine = {}
local E = ArcadiaNexus.BJ_Engine

E._sessionId = nil

E.state      = "IDLE"
E.gameState  = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

-- ── Sound-Hilfsfunktion ───────────────────────────────────────
local SND_DEAL  = 774   -- IG_MAINMENU_OPTION_CHECKBOX_ON
local SND_FLIP  = 774
local SND_WIN   = 888   -- UI_ACHIEVEMENT_TOAST_SPARK
local SND_LOSE  = 847   -- IG_QUEST_ABANDON
local SND_BUST  = 847
local SND_CHIP  = 774

local function PlayBJSound(key, soundId)
    local S = ArcadiaNexus.BJ_Settings
    if not S then return end
    if not S:Get("soundEnabled") then return end
    local keyMap = {
        deal = "soundOnDeal",
        flip = "soundOnFlip",
        win  = "soundOnWin",
        lose = "soundOnLose",
        bust = "soundOnBust",
        chip = "soundOnChip",
    }
    if keyMap[key] and S:Get(keyMap[key]) then
        PlaySound(soundId, "Master")
    end
end

-- ── Timer-Hilfsfunktionen ─────────────────────────────────────
-- Erzeugt eine generationsgesicherte Timer-Sequenz.
-- steps: { {delay, fn}, ... } – werden nacheinander ausgeführt.
function E:_RunSequence(steps, onDone)
    _timerGuard:RunSequence(steps, onDone)
end

function E:_InvalidateTimers()
    _timerGuard:Cancel()
end

-- ── State-Setter ──────────────────────────────────────────────
function E:_SetState(newState)
    E.state = newState
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:OnStateChanged(newState) end
end

-- ── Init / Lifecycle ──────────────────────────────────────────
function E:StartGame(config)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("BLACKJACK", E._sessionId)
    self:_InvalidateTimers()
    local S     = ArcadiaNexus.BJ_Settings
    local Logic = ArcadiaNexus.BJ_Logic
    local diff  = (config and config.difficulty) or (S and S:Get("difficulty")) or "easy"
    local aiCnt = (config and config.aiCount)    or (S and S:Get("aiCount"))    or 0
    -- Kapital aus Settings laden (persistent zwischen Sessions)
    local chips = S and S:LoadChips() or 100
    E.gameState = Logic:NewGameState(diff, aiCnt, chips)
    -- State setzen VOR OnGameStarted, damit UpdateActionButtons korrekte State liest
    E.state = "BETTING"
    local R = ArcadiaNexus.BJ_Renderer
    if R then
        R:OnStateChanged("BETTING")
        R:OnGameStarted(E.gameState)
    end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("BLACKJACK", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()

    local S = ArcadiaNexus.BJ_Settings
    if E.gameState and S then
        -- Kapital immer speichern — Einsatz ist bereits abgezogen wenn Runde läuft
        -- Bei Abbruch in BETTING (noch kein Abzug): Kapital unverändert speichern
        S:SaveChips(E.gameState.chips)
    end

    -- GAME_RESULT nur wenn mindestens eine Runde vollständig gespielt wurde
    if E.state ~= "IDLE"
    and E.gameState
    and not E.gameState._gameOverFired
    and (E.gameState.roundsPlayed or 0) > 0 then
        local gs    = E.gameState
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "BLACKJACK",
            difficulty = gs.difficulty,
            score      = 0,
            result     = (gs.chips or 0) >= 100 and "WIN" or "LOSS",
            stats      = {
                finalChips = gs.chips,
                blackjacks = gs.blackjacks or 0,
            },
        })
    end
    -- Renderer zurücksetzen
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:OnGameStopped() end
    E.gameState = nil
    E.state     = "IDLE"
end

-- ── Einsatz setzen (BETTING-State) ────────────────────────────
function E:SetBet(amount)
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    -- Guthaben-Check: reicht das verfügbare Kapital für diesen zusätzlichen Chip?
    local newBet = (gs.bet or 0) + amount
    if newBet > gs.chips then return end  -- nicht genug Guthaben (Gleichheit = Allin erlaubt)
    gs.bet          = newBet
    gs.betConfirmed = true
    PlayBJSound("chip", SND_CHIP)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:UpdateBetDisplay(gs) end
end

function E:RemoveLastBetOfColor(color, amount)
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    local newBet = (gs.bet or 0) - amount
    if newBet < 0 then newBet = 0 end
    gs.bet = newBet
    if gs.bet == 0 then gs.betConfirmed = false end
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:UpdateBetDisplay(gs) end
end

function E:ClearBet()
    if E.state ~= "BETTING" then return end
    local gs = E.gameState
    if not gs then return end
    gs.bet          = 0
    gs.betConfirmed = false
    local R = ArcadiaNexus.BJ_Renderer
    if R then
        R:_ClearBetChip()
        R:UpdateBetDisplay(gs)
    end
end

-- ── Runde starten (Deal) ──────────────────────────────────────
function E:StartRound()
    if E.state ~= "BETTING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end
    -- Spieler muss explizit einen Chip gesetzt haben und Einsatz > 0
    if not gs.betConfirmed or (gs.bet or 0) <= 0 then return end
    if gs.chips < gs.bet then return end

    -- Einsatz abziehen
    gs.chips     = gs.chips - gs.bet
    gs.firstAction   = true
    gs.insuranceBet  = 0
    gs.insuranceOpen = false
    gs.playerState   = "playing"
    gs.dealerState   = "waiting"
    gs.playerHands   = { {} }
    gs.activeHand    = 1
    gs.dealerHand    = {}
    for i = 1, gs.aiCount do
        gs.aiHands[i]  = {}
        gs.aiStates[i] = "playing"
    end

    -- KI-Einsätze VOR PLAYING setzen, sonst zeigt OnStateChanged leere aiBets
    local aiBets = {}
    local AI_BET_VALUES = {25, 25, 25, 50, 50, 100, 500}
    for i = 1, gs.aiCount do
        aiBets[i] = AI_BET_VALUES[ math.random(#AI_BET_VALUES) ]
    end
    gs.aiBets = aiBets

    self:_SetState("PLAYING")

    local sequence = Logic:DealInitial(gs)
    local steps    = {}
    for _, deal in ipairs(sequence) do
        local d = deal
        table.insert(steps, {
            delay = 0.3,
            fn    = function()
                PlayBJSound("deal", SND_DEAL)
                local R = ArcadiaNexus.BJ_Renderer
                if R then R:ShowDealtCard(d.target, d.card) end
            end,
        })
    end

    self:_RunSequence(steps, function()
        local R = ArcadiaNexus.BJ_Renderer
        if R then R:UpdateBoard(gs) end
        -- Insurance-Angebot?
        if gs.insuranceOpen then
            if R then R:ShowInsurancePrompt(gs) end
        else
            self:_CheckImmediateBlackjack()
        end
    end)
end

-- ── Blackjack-Check nach Deal ─────────────────────────────────
function E:_CheckImmediateBlackjack()
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end

    local playerBJ = Logic:IsBlackjack(gs.playerHands[1])
    local dealerBJ = Logic:IsBlackjack(gs.dealerHand)  -- noch verdeckt, wird intern geprüft

    if playerBJ then
        -- Direkt zu Dealer-Zug springen wenn Spieler BJ hat
        self:_StartDealerTurn()
    else
        local R = ArcadiaNexus.BJ_Renderer
        if R then R:UpdateActionButtons(gs) end
    end
end

-- ── Spieler-Aktionen ──────────────────────────────────────────
function E:PlayerHit()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs or gs.playerState ~= "playing" then return end
    gs.firstAction = false

    local card = Logic:PlayerHit(gs)
    PlayBJSound("deal", SND_DEAL)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:ShowDealtCard("player", card) end

    _timerGuard:After(0.15, function()
        if not E.gameState then return end
        if R then R:UpdateBoard(gs) end
        if gs.playerState == "bust" then
            PlayBJSound("bust", SND_BUST)
            self:_StartDealerTurn()
        elseif Logic:EvalHand(gs.playerHands[gs.activeHand or 1]) >= 21 then
            Logic:PlayerStand(gs)
            if R then R:UpdateBoard(gs) end
            if gs.playerState == "stand" then
                self:_StartDealerTurn()
            else
                if R then R:UpdateActionButtons(gs) end
            end
        else
            if R then R:UpdateActionButtons(gs) end
        end
    end)
end

function E:PlayerStand()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end
    Logic:PlayerStand(gs)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:UpdateBoard(gs) end
    if gs.playerState == "stand" then
        self:_StartDealerTurn()
    else
        -- Split: Hand 2 ist jetzt dran
        if R then R:UpdateActionButtons(gs) end
    end
end

function E:PlayerDouble()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs or not gs.firstAction then return end
    if gs.chips < gs.bet then return end

    local card = Logic:PlayerDouble(gs)
    if not card then return end
    PlayBJSound("deal", SND_DEAL)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:ShowDealtCard("player", card) end

    _timerGuard:After(0.15, function()
        if not E.gameState then return end
        if R then R:UpdateBoard(gs) end
        if gs.playerState == "bust" then
            PlayBJSound("bust", SND_BUST)
        end
        self:_StartDealerTurn()
    end)
end

function E:PlayerSplit()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs or not gs.firstAction then return end

    local ok = Logic:PlayerSplit(gs)
    if not ok then return end

    local R = ArcadiaNexus.BJ_Renderer
    if R then R:OnSplit(gs) end
    if R then R:UpdateBoard(gs) end
    if R then R:UpdateActionButtons(gs) end
end

function E:PlayerInsurance()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end

    Logic:PlayerInsurance(gs)
    PlayBJSound("chip", SND_CHIP)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:HideInsurancePrompt() end
    if R then R:UpdateBoard(gs) end
    self:_CheckImmediateBlackjack()
end

function E:DeclineInsurance()
    if E.state ~= "PLAYING" then return end
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end

    Logic:DeclineInsurance(gs)
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:HideInsurancePrompt() end
    self:_CheckImmediateBlackjack()
end

-- ── Dealer-Zug ────────────────────────────────────────────────
function E:_StartDealerTurn()
    self:_SetState("DEALER_TURN")
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end

    local sequence = Logic:DealerPlay(gs)
    local steps    = {}

    for _, deal in ipairs(sequence) do
        local d = deal
        if d.reveal then
            table.insert(steps, {
                delay = 0.4,
                fn    = function()
                    PlayBJSound("flip", SND_FLIP)
                    local R = ArcadiaNexus.BJ_Renderer
                    if R then R:FlipDealerHiddenCard(d.card) end
                end,
            })
        else
            table.insert(steps, {
                delay = 0.5,
                fn    = function()
                    PlayBJSound("deal", SND_DEAL)
                    local R = ArcadiaNexus.BJ_Renderer
                    if R then R:ShowDealtCard("dealer", d.card) end
                end,
            })
        end
    end

    -- KI-Spieler nach Dealer
    local aiSequences = Logic:AIPlay(gs)
    for i = 1, gs.aiCount do
        local aiSeq = aiSequences[i] or {}
        for _, deal in ipairs(aiSeq) do
            local d = deal
            table.insert(steps, {
                delay = 0.3,
                fn    = function()
                    PlayBJSound("deal", SND_DEAL)
                    local R = ArcadiaNexus.BJ_Renderer
                    if R then R:ShowDealtCard("ai" .. d.aiIdx, d.card) end
                end,
            })
        end
    end

    self:_RunSequence(steps, function()
        if not E.gameState then return end
        local R = ArcadiaNexus.BJ_Renderer
        if R then R:UpdateBoard(gs) end
        self:_SettleRound()
    end)
end

-- ── Runden-Abrechnung ─────────────────────────────────────────
function E:_SettleRound()
    local gs    = E.gameState
    local Logic = ArcadiaNexus.BJ_Logic
    if not gs then return end

    gs.roundsPlayed = (gs.roundsPlayed or 0) + 1

    local results = Logic:SettleRound(gs)
    local R       = ArcadiaNexus.BJ_Renderer

    -- Ergebnis-Sound
    local primaryResult = results[1] and results[1].result or "push"
    if primaryResult == "win" or primaryResult == "blackjack" then
        PlayBJSound("win", SND_WIN)
    elseif primaryResult == "lose" or primaryResult == "bust" then
        PlayBJSound("lose", SND_LOSE)
    end

    -- Kapital persistieren
    local S = ArcadiaNexus.BJ_Settings
    if S then S:SaveChips(gs.chips) end

    -- Bankrott: direkt Game-Over, kein Runden-Result das danach ersetzt wird
    if gs.chips < 25 then
        self:_GameOver()
        return
    end

    self:_SetState("ROUND_RESULT")
    if R then R:ShowRoundResult(gs, results) end
end

function E:_GameOver()
    local gs = E.gameState
    if not gs then return end
    self:_SetState("GAMEOVER")
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "BLACKJACK",
        difficulty = gs.difficulty,
        score      = 0,
        result     = "LOSS",
        stats      = {
            finalChips = gs.chips,
            blackjacks = gs.blackjacks or 0,
        },
    })
    -- Flag damit StopGame kein zweites GAME_RESULT sendet
    gs._gameOverFired = true
    -- Kapital bei Bankrott zurücksetzen
    local S = ArcadiaNexus.BJ_Settings
    if S then S:ResetChips() end
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:ShowGameOver(gs) end
end

-- ── Neue Runde ────────────────────────────────────────────────
function E:NewRound()
    if E.state ~= "ROUND_RESULT" and E.state ~= "BETTING" then return end
    local gs    = E.gameState
    if not gs then return end
    -- Reset Runden-State
    gs.playerHands   = { {} }
    gs.activeHand    = 1
    gs.dealerHand    = {}
    gs.aiHands       = {}
    gs.aiStates      = {}
    gs.firstAction   = true
    gs.insuranceBet  = 0
    gs.insuranceOpen = false
    gs.playerState   = "playing"
    gs.dealerState   = "waiting"
    gs.betConfirmed  = false
    gs.bet           = 0
    gs.aiBets        = nil
    for i = 1, gs.aiCount do
        gs.aiHands[i]  = {}
        gs.aiStates[i] = "playing"
    end
    self:_SetState("BETTING")
    local R = ArcadiaNexus.BJ_Renderer
    if R then R:OnNewRound(gs) end
end

-- ── KI-Anzahl ändern (IDLE + zwischen Runden; nicht mitten in der Hand) ──
function E:SetAICount(count)
    count = tonumber(count) or 0
    if count < 0 then count = 0 end
    if count > 2 then count = 2 end

    local S = ArcadiaNexus.BJ_Settings
    if S then S:Set("aiCount", count) end

    local gs = E.gameState
    if not gs then return end
    if E.state ~= "BETTING" and E.state ~= "ROUND_RESULT" and E.state ~= "IDLE" then
        return
    end

    gs.aiCount  = count
    gs.aiHands  = gs.aiHands or {}
    gs.aiStates = gs.aiStates or {}
    for i = 1, count do
        gs.aiHands[i]  = gs.aiHands[i] or {}
        gs.aiStates[i] = gs.aiStates[i] or "waiting"
    end

    local R = ArcadiaNexus.BJ_Renderer
    if R and R.UpdateBoard then R:UpdateBoard(gs) end
end

-- ── Schwierigkeit ändern (nur im IDLE/BETTING) ────────────────
function E:SetDifficulty(diff)
    ArcadiaNexus.BJ_Settings:Set("difficulty", diff)
    if E.gameState then
        E.gameState.difficulty = diff
    end
end
