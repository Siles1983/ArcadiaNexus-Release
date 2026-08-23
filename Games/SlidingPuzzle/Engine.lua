-- ============================================================
--  SlidingPuzzle – Engine.lua
--  Lifecycle, Zug-Verarbeitung, Timer, Win-Sequenz.
--
--  State-Machine:
--    IDLE → PLAYING → WIN
--
--  Regeln:
--  - GAME_RESULT nur wenn _moveCount > 0
--  - Score = 10000 - moves (weniger Züge = besser, Standard-Sort greift)
--  - TimerGuard (Core/TimerGuard) für Invalidierung; Elapsed-Ticker darüber
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SLP_Engine = {}
local E = ArcadiaNexus.SLP_Engine

E._sessionId = nil

E.state      = "IDLE"
E._moveCount = 0
E._startTime = nil
E._elapsed   = 0
E._cols      = 3
E._imageIdx  = 1
E._difficulty = "easy"

local _timerGuard = ArcadiaNexus.TimerGuard.New()

-- Shuffle-Schritte je Schwierigkeit
local SHUFFLE_STEPS = { easy=80, medium=200, hard=400 }

-- Sounds
local SND_MOVE = SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP  or 1
local SND_WIN  = SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END or 1

local function PlaySLP(key, soundId)
    local S = ArcadiaNexus.SLP_Settings
    if not S or not S:Get("soundEnabled") then return end
    if S:Get(key) then
        C_Sound.PlaySound(soundId, "Master")
    end
end

-- ── Hilfsfunktionen ───────────────────────────────────────────

local DIFF_COLS = { easy=3, medium=6, hard=8 }

function E:_InvalidateTimers()
    _timerGuard:Cancel()
end

function E:_SetState(newState)
    self.state = newState
    local R = ArcadiaNexus.SLP_Renderer
    if R and R.OnStateChanged then
        R:OnStateChanged(newState)
    end
end

-- ── Timer ─────────────────────────────────────────────────────

function E:_StartTimer()
    self._startTime = GetTime()
    _timerGuard:EveryTicker(1, function()
        if self.state ~= "PLAYING" then return end
        self._elapsed = GetTime() - self._startTime
        local R = ArcadiaNexus.SLP_Renderer
        if R then R:UpdateHUD() end
    end)
end

function E:_StopTimer()
    _timerGuard:Cancel()
    if self._startTime then
        self._elapsed = GetTime() - self._startTime
    end
end

function E:GetElapsed()
    if self._startTime and self.state == "PLAYING" then
        return GetTime() - self._startTime
    end
    return self._elapsed
end

-- ── Spiel starten ─────────────────────────────────────────────

function E:StartGame()
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("MOSAICOFAZEROTH", E._sessionId)
    self:_InvalidateTimers()
    self:_StopTimer()
    self._reshuffling = false

    local S    = ArcadiaNexus.SLP_Settings
    local diff = S:Get("difficulty") or "easy"

    self._difficulty = diff
    self._cols       = DIFF_COLS[diff] or 3
    -- imageIndex 0 = Zufällig
    local imgSetting = S:Get("imageIndex") or 0
    local img
    if imgSetting == 0 then
        img = math.random(1, 15)
    else
        img = imgSetting
    end
    self._imageIdx  = img
    self._moveCount = 0
    self._elapsed   = 0
    self._startTime = nil

    local Logic = ArcadiaNexus.SLP_Logic
    -- Init: Board im Zielzustand (gelöstes Puzzle)
    Logic:Init(self._cols)
    -- Shuffle mit History für die Animation
    local moveHistory = Logic:ShuffleWithHistory(SHUFFLE_STEPS[diff] or 80)

    S:IncrementPlayed(diff)

    local R = ArcadiaNexus.SLP_Renderer
    if R then
        -- Phase 1: Vorschau (Vollbild), dann Split, dann Shuffle-Animation
        R:StartIntroSequence(self._cols, self._imageIdx, moveHistory, function()
            -- Animation abgeschlossen → Spiel aktiv
            R:UpdateHUD()
            E:_SetState("PLAYING")
            E:_StartTimer()
        end)
    else
        self:_SetState("PLAYING")
        self:_StartTimer()
    end
end

-- ── Neu mischen (gleiches Bild, gleiche Schwierigkeit) ────────
function E:Reshuffle()
    if self.state ~= "PLAYING" or self._reshuffling then return end
    if not self._imageIdx then return end

    self._reshuffling = true
    self:_InvalidateTimers()
    self:_StopTimer()
    self._moveCount = 0
    self._elapsed   = 0
    self._startTime = nil

    local Logic = ArcadiaNexus.SLP_Logic
    Logic:Init(self._cols)
    local moveHistory = Logic:ShuffleWithHistory(SHUFFLE_STEPS[self._difficulty] or 80)

    local R = ArcadiaNexus.SLP_Renderer
    if R then
        R:StartIntroSequence(self._cols, self._imageIdx, moveHistory, function()
            self._reshuffling = false
            R:UpdateHUD()
            E:_SetState("PLAYING")
            E:_StartTimer()
        end)
    else
        self._reshuffling = false
        self:_SetState("PLAYING")
        self:_StartTimer()
    end
end

-- ── Zug-Verarbeitung ──────────────────────────────────────────

function E:OnTileClicked(tilePos)
    if self.state ~= "PLAYING" or self._reshuffling then return end

    local Logic = ArcadiaNexus.SLP_Logic
    if not Logic:CanMove(tilePos) then return end

    local moved = Logic:ExecuteMove(tilePos)
    if not moved then return end

    self._moveCount = Logic.moves
    PlaySLP("soundOnMove", SND_MOVE)

    local R = ArcadiaNexus.SLP_Renderer
    if R then
        R:MoveTile(tilePos, Logic.emptyPos)   -- animiert oder direkt
        R:UpdateHUD()
    end

    if Logic:IsSolved() then
        self:_OnWin()
    end
end

-- ── Sieg ──────────────────────────────────────────────────────

function E:_OnWin()
    self:_StopTimer()
    self:_SetState("WIN")

    local S    = ArcadiaNexus.SLP_Settings
    local diff = self._difficulty
    local moves = self._moveCount
    local elapsed = self._elapsed

    S:IncrementSolved(diff)
    S:SubmitBest(diff, moves, math.floor(elapsed))

    -- Score: weniger Züge = besser. Standard-Sort (höher = besser) greift.
    local score = math.max(0, 10000 - moves)

    PlaySLP("soundOnWin", SND_WIN)

    -- Win-Reveal-Sequenz im Renderer anstoßen.
    -- GAME_RESULT wird erst nach vollständigem Reveal emittiert (_EmitResult).
    local R = ArcadiaNexus.SLP_Renderer
    if R then
        R:StartWinReveal(function()
            E:_EmitResult(score, moves, math.floor(elapsed), diff)
            R:ShowWinResult(score, moves, math.floor(elapsed), diff)
        end)
    else
        self:_EmitResult(score, moves, math.floor(elapsed), diff)
    end
end

function E:_EmitResult(score, moves, elapsed, diff)
    if self._moveCount == 0 then return end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "MOSAICOFAZEROTH",
        difficulty = diff,
        score      = score,
        result     = "WIN",
        stats      = {
            moves      = moves,
            time       = elapsed,
            difficulty = diff,
        },
    })
end

-- ── Lifecycle ─────────────────────────────────────────────────

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("MOSAICOFAZEROTH", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()
    self:_StopTimer()
    self._reshuffling = false
    self._moveCount = 0
    self:_SetState("IDLE")
end

function E:On()
    -- Renderer zeigt Idle-State; Spiel startet erst auf Knopfdruck.
    local R = ArcadiaNexus.SLP_Renderer
    if R then R:UpdateHUD() end
    self:_SetState("IDLE")
end

function E:Off()
    self:StopGame()
end
