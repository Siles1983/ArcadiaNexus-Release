-- ============================================================
--  AlchemistsSort – Engine.lua
--  State-Machine, Undo-Stack, Zug-Ausführung, Timer-Verwaltung.
--
--  State-Machine:
--    IDLE → PLAYING → SELECTED (Sub) → POURING (Sub) → PLAYING
--                  ↘ HINT (Sub, 2s)  ↗
--                  ↘ WIN
--                  ↘ PAUSED
--
--  Regeln:
--  - Während POURING: alle Klicks ignoriert (_animating-Flag)
--  - TimerGuard (Core/TimerGuard) für Pour-Animationen; Elapsed-Ticker separat
--  - Undo-Stack: max. 3 Einträge (LIFO)
--  - Tipps: max. 3 pro Level
--  - GAME_RESULT nur wenn _moveCount > 0
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Engine = {}
local E = ArcadiaNexus.ALS_Engine

E._sessionId = nil

E.state       = "IDLE"
E._tubes      = nil      -- aktueller Tube-State (Array)
E._initTubes  = nil      -- Ausgangs-State (für Reset)
E._numTubes   = 0
E._minMoves   = 0
E._moveCount  = 0
E._undosLeft  = 3
E._hintsLeft  = 3
E._addedTube  = false    -- "Leere Röhre" bereits genutzt?
E._usedUndo   = false    -- Achievement-Tracking: Undo genutzt?
E._usedHint   = false    -- Achievement-Tracking: Tipp genutzt?
E._usedAddTube= false    -- Achievement-Tracking: Extra-Röhre genutzt?
E._animating  = false
E._undoStack  = {}
E._selected   = nil      -- Index der gewählten Quell-Röhre (nil = keine)
E._startTime  = nil
E._elapsed    = 0
E._ticker     = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

-- Sounds
local SND_BASE    = "Interface\\AddOns\\ArcadiaNexus\\Games\\AlchemistsSort\\Assets\\sounds\\"
local SND_POUR    = SND_BASE .. "flow.wav"
local SND_WIN     = SND_BASE .. "win.wav"
local SND_INVALID = SOUNDKIT and SOUNDKIT.UI_MINIMAP_PING or 1

local function PlayALSSound(key, soundId)
    local S = ArcadiaNexus.ALS_Settings
    if not S or not S:Get("soundEnabled") then return end
    if S:Get(key) then
        if type(soundId) == "string" then
            PlaySoundFile(soundId, "SFX")
        else
            C_Sound.PlaySound(soundId, "Master")
        end
    end
end

-- ── Interne Helfer ────────────────────────────────────────────

function E:_InvalidateTimers()
    _timerGuard:Cancel()
end

function E:_SetState(newState)
    self.state = newState
    local R = ArcadiaNexus.ALS_Renderer
    if R and R.OnStateChanged then
        R:OnStateChanged(newState)
    end
end

-- ── Undo-Stack ────────────────────────────────────────────────

function E:PushUndo(tubes)
    local L = ArcadiaNexus.ALS_Logic
    if #self._undoStack >= 3 then
        table.remove(self._undoStack, 1)
    end
    table.insert(self._undoStack, L:DeepCopy(tubes))
end

function E:Undo()
    if #self._undoStack == 0 or self._animating then return end
    local prev = table.remove(self._undoStack)
    self._tubes     = prev
    self._moveCount = math.max(0, self._moveCount - 1)
    self._undosLeft = self._undosLeft - 1
    self._usedUndo  = true
    self._selected  = nil

    local R = ArcadiaNexus.ALS_Renderer
    if R then
        R:RefreshAll(self._tubes)
        R:UpdateHUD()
        R:SetSelected(nil)
    end
end

-- ── Timer ─────────────────────────────────────────────────────

function E:_StartTimer(fromElapsed)
    self._elapsed   = fromElapsed or 0
    self._startTime = GetTime() - self._elapsed
    if self._ticker then self._ticker:Cancel() end
    self._ticker = C_Timer.NewTicker(1, function()
        if self.state == "IDLE" or self.state == "WIN" then return end
        self._elapsed = GetTime() - self._startTime
        local R = ArcadiaNexus.ALS_Renderer
        if R then R:UpdateHUD() end
    end)
end

function E:_StopTimer()
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    if self._startTime then
        self._elapsed = GetTime() - self._startTime
    end
end

function E:GetElapsed()
    if self._startTime and self.state ~= "IDLE" and self.state ~= "WIN" then
        return GetTime() - self._startTime
    end
    return self._elapsed
end

-- ── Level starten ─────────────────────────────────────────────

function E:StartLevel(levelNum)
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ALCHEMISTSSORT", E._sessionId)
    self:_InvalidateTimers()
    self:_StopTimer()

    local R = ArcadiaNexus.ALS_Renderer
    if R and R.ShowLoading then R:ShowLoading() end

    local Gen = ArcadiaNexus.ALS_LevelGen
    local L   = ArcadiaNexus.ALS_Logic

    -- Generierung asynchron: 1 Versuch pro WoW-Frame-Tick
    -- Verhindert Client-Freeze bei höheren Levels
    local attempt = 0
    local maxAttempts = 20
    self._genGen = (self._genGen or 0) + 1
    local myGen = self._genGen

    local function tryGenerate()
        -- Ungültig wenn inzwischen ein neues Level gestartet wurde
        if self._genGen ~= myGen then return end

        attempt = attempt + 1
        local tubes, numTubes, minMoves = Gen:GenerateSingle(levelNum)

        if tubes then
            -- Lösbar gefunden: Overlay ausblenden und Spiel starten
            if R and R.HideLoading then R:HideLoading() end

            self._tubes       = tubes
            self._initTubes   = L:DeepCopy(tubes)
            self._numTubes    = numTubes
            self._minMoves    = minMoves
            self._moveCount   = 0
            self._undosLeft   = 3
            self._hintsLeft   = 3
            self._addedTube   = false
            self._usedUndo    = false
            self._usedHint    = false
            self._usedAddTube = false
            self._undoStack   = {}
            self._selected    = nil
            self._animating   = false
            self._elapsed     = 0
            self._startTime   = nil

            ArcadiaNexus.ALS_Settings:IncrementPlayed()
            ArcadiaNexus.ALS_Settings:SetCurrentLevel(levelNum)

            if R then
                R:BuildGrid(self._tubes, numTubes)
                R:RefreshAll(self._tubes)
                R:UpdateHUD()
            end

            self:_SetState("PLAYING")
            self:_StartTimer()

        elseif attempt < maxAttempts then
            -- Nächsten Versuch im nächsten Frame
            C_Timer.After(0, tryGenerate)
        else
            -- Fallback: Overlay ausblenden, Fallback-Level laden
            if R and R.HideLoading then R:HideLoading() end
            local fbTubes, fbNumTubes, fbMoves = Gen:GenerateFallback(levelNum)
            self._tubes       = fbTubes
            self._initTubes   = L:DeepCopy(fbTubes)
            self._numTubes    = fbNumTubes
            self._minMoves    = fbMoves
            self._moveCount   = 0
            self._undosLeft   = 3
            self._hintsLeft   = 3
            self._addedTube   = false
            self._usedUndo    = false
            self._usedHint    = false
            self._usedAddTube = false
            self._undoStack   = {}
            self._selected    = nil
            self._animating   = false
            self._elapsed     = 0
            self._startTime   = nil

            ArcadiaNexus.ALS_Settings:IncrementPlayed()
            ArcadiaNexus.ALS_Settings:SetCurrentLevel(levelNum)

            if R then
                R:BuildGrid(self._tubes, fbNumTubes)
                R:RefreshAll(self._tubes)
                R:UpdateHUD()
            end

            self:_SetState("PLAYING")
            self:_StartTimer()
        end
    end

    -- Ersten Versuch im nächsten Frame starten (Overlay soll erst rendern)
    C_Timer.After(0, tryGenerate)
end

-- ── Klick-Verarbeitung ────────────────────────────────────────

function E:OnTubeClicked(tubeIdx)
    if self._animating then return end
    if self.state ~= "PLAYING" and self.state ~= "SELECTED" and self.state ~= "HINT" then return end

    local L = ArcadiaNexus.ALS_Logic
    local R = ArcadiaNexus.ALS_Renderer

    -- Kein Zug: Quell-Röhre wählen
    if self._selected == nil then
        if #self._tubes[tubeIdx] == 0 then return end
        self._selected = tubeIdx
        self:_SetState("SELECTED")
        if R then R:SetSelected(tubeIdx) end
        return
    end

    local srcIdx = self._selected

    -- Gleiche Röhre: Auswahl aufheben
    if srcIdx == tubeIdx then
        self._selected = nil
        self:_SetState("PLAYING")
        if R then R:SetSelected(nil) end
        return
    end

    local src = self._tubes[srcIdx]
    local dst = self._tubes[tubeIdx]
    local valid, count = L:IsValidMove(src, dst)

    -- Spieler-Guard: einfarbig-volle Röhre in leere verschieben bringt nichts
    if valid and count > 0 and #dst == 0
        and #src == 5 and L:TopCount(src) == 5 then
        valid = false
    end

    if not valid or count == 0 then
        PlayALSSound("soundOnInvalid", SND_INVALID)
        if R then R:ShakeTube(tubeIdx) end
        -- Neue Quell-Röhre wenn geklickt nicht leer
        if #self._tubes[tubeIdx] > 0 then
            self._selected = tubeIdx
            if R then R:SetSelected(tubeIdx) end
        else
            self._selected = nil
            self:_SetState("PLAYING")
            if R then R:SetSelected(nil) end
        end
        return
    end

    -- Gültiger Zug
    self:PushUndo(self._tubes)
    self._moveCount = self._moveCount + 1
    self._selected  = nil
    self:_SetState("POURING")
    self._animating = true

    local gen      = _timerGuard:Generation()
    local topColor = src[1]

    if R then
        R:AnimatePour(srcIdx, tubeIdx, topColor, count, function()
            if gen ~= _timerGuard:Generation() then return end
            L:ExecuteMove(src, dst)
            self._animating = false
            R:RefreshAll(self._tubes)
            R:UpdateHUD()
            R:SetSelected(nil)
            self:_CheckWinOrContinue()
        end)
    else
        L:ExecuteMove(src, dst)
        self._animating = false
        self:_CheckWinOrContinue()
    end
end

-- ── Sieg / Deadlock ───────────────────────────────────────────

function E:_CheckWinOrContinue()
    local L = ArcadiaNexus.ALS_Logic
    if L:CheckWin(self._tubes) then
        self:_OnWin()
    elseif not L:HasAnyMove(self._tubes) then
        -- Deadlock: sollte durch Generator verhindert sein, aber sicher ist sicher
        self:_SetState("PLAYING")  -- Spieler kann Reset/Undo nutzen
    else
        self:_SetState("PLAYING")
    end
end

function E:_OnWin()
    self:_StopTimer()
    self:_SetState("WIN")

    local S    = ArcadiaNexus.ALS_Settings
    local lvl  = S:GetCurrentLevel()
    local elapsed = self._elapsed

    -- Score berechnen
    local baseScore   = 1000
    local movePenalty = math.max(0, (self._moveCount - self._minMoves) * 10)
    local timeBonus   = math.max(0, 300 - math.floor(elapsed)) * 2
    local score       = math.max(0, baseScore - movePenalty + timeBonus)

    -- Statistiken
    S:IncrementSolved()
    S:SubmitScore(score)
    S:SubmitLevelBest(lvl, self._moveCount, elapsed)
    S:UnlockLevel(lvl + 1)
    S:SetCurrentLevel(lvl + 1)
    S:ClearMidGame(S:GetActiveSlot())
    S:IncrementStreak()

    PlayALSSound("soundOnWin", SND_WIN)

    -- GAME_RESULT senden
    if self._moveCount > 0 then
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = "ALCHEMISTSSORT",
            difficulty = "normal",
            score      = score,
            result     = "WIN",
            stats      = {
                levelReached = lvl,
                level        = lvl,
                moves        = self._moveCount,
                minMoves     = self._minMoves,
                time         = math.floor(elapsed),
                streak       = S:GetSessionStreak(),
                usedUndo     = self._usedUndo,
                usedHint     = self._usedHint,
                usedAddTube  = self._usedAddTube,
            },
        })
    end

    local R = ArcadiaNexus.ALS_Renderer
    if R then R:ShowWinOverlay(score, self._moveCount, elapsed) end
end

-- ── Aktionen: Reset, Tipp, Leere Röhre ───────────────────────

function E:ResetLevel()
    if self._animating then return end
    local L = ArcadiaNexus.ALS_Logic
    self:_InvalidateTimers()

    -- Confirm-Dialog über Renderer
    local R = ArcadiaNexus.ALS_Renderer
    if R then
        R:ShowConfirmReset(function()
            self._tubes     = L:DeepCopy(self._initTubes)
            self._moveCount = 0
            self._undoStack = {}
            self._selected  = nil
            self._animating = false
            -- Timer läuft weiter (kein Reset)
            if R then
                R:BuildGrid(self._tubes, self._numTubes)
                R:RefreshAll(self._tubes)
                R:UpdateHUD()
                R:SetSelected(nil)
            end
            self:_SetState("PLAYING")
        end)
    end
end

function E:RequestHint()
    if self._animating then return end
    if self._hintsLeft <= 0 then return end
    if self.state ~= "PLAYING" and self.state ~= "SELECTED" then return end

    local L = ArcadiaNexus.ALS_Logic
    local srcIdx, dstIdx = L:FindHint(self._tubes)
    if not srcIdx then
        local R = ArcadiaNexus.ALS_Renderer
        if R then R:ShowFeedback("msg_no_hint") end
        return
    end

    self._hintsLeft = self._hintsLeft - 1
    self._usedHint  = true
    self._selected  = nil
    self:_SetState("HINT")

    local R = ArcadiaNexus.ALS_Renderer
    if R then
        R:SetSelected(nil)
        R:ShowHint(srcIdx, dstIdx, function()
            if self.state == "HINT" then
                self:_SetState("PLAYING")
            end
        end)
        R:UpdateHUD()
    end
end

function E:AddEmptyTube()
    if self._addedTube then return end
    if self._animating then return end

    self._addedTube   = true
    self._usedAddTube = true
    self._numTubes  = self._numTubes + 1
    self._tubes[self._numTubes] = {}

    local R = ArcadiaNexus.ALS_Renderer
    if R then
        R:BuildGrid(self._tubes, self._numTubes)
        R:RefreshAll(self._tubes)
        R:UpdateHUD()
    end
end

-- ── Lifecycle ─────────────────────────────────────────────────

function E:ClearSelection()
    if self.state ~= "SELECTED" then return end
    self._selected = nil
    self:_SetState("PLAYING")
    local R = ArcadiaNexus.ALS_Renderer
    if R then R:SetSelected(nil) end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ALCHEMISTSSORT", E._sessionId)
        E._sessionId = nil
    end
    self:_InvalidateTimers()
    self:_StopTimer()
    self._animating = false
    self._selected  = nil
    self:_SetState("IDLE")
end

function E:_CaptureMidGame()
    local Logic = ArcadiaNexus.ALS_Logic
    if not Logic or not self._tubes then return nil end
    local undo = {}
    for i, t in ipairs(self._undoStack or {}) do
        undo[i] = Logic:DeepCopy(t)
    end
    return {
        tubes       = Logic:DeepCopy(self._tubes),
        initTubes   = Logic:DeepCopy(self._initTubes),
        numTubes    = self._numTubes,
        minMoves    = self._minMoves,
        moveCount   = self._moveCount,
        undosLeft   = self._undosLeft,
        hintsLeft   = self._hintsLeft,
        addedTube   = self._addedTube,
        usedUndo    = self._usedUndo,
        usedHint    = self._usedHint,
        usedAddTube = self._usedAddTube,
        elapsed     = self:GetElapsed(),
        undoStack   = undo,
    }
end

function E:SaveAndStop()
    local S = ArcadiaNexus.ALS_Settings
    if S and self.state ~= "IDLE" and self.state ~= "WIN" then
        S:SaveMidGame(S:GetActiveSlot(), self:_CaptureMidGame())
    end
    self:StopGame()
end

function E:ResumeMidGame(mid)
    local Logic = ArcadiaNexus.ALS_Logic
    local R     = ArcadiaNexus.ALS_Renderer
    if not mid or not Logic then
        self:StartLevel(1)
        return
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("ALCHEMISTSSORT", E._sessionId)
    self:_InvalidateTimers()
    self:_StopTimer()

    self._tubes       = Logic:DeepCopy(mid.tubes)
    self._initTubes   = Logic:DeepCopy(mid.initTubes)
    self._numTubes    = mid.numTubes or #self._tubes
    self._minMoves    = mid.minMoves or 0
    self._moveCount   = mid.moveCount or 0
    self._undosLeft   = mid.undosLeft or 0
    self._hintsLeft   = mid.hintsLeft or 0
    self._addedTube   = mid.addedTube and true or false
    self._usedUndo    = mid.usedUndo and true or false
    self._usedHint    = mid.usedHint and true or false
    self._usedAddTube = mid.usedAddTube and true or false
    self._undoStack   = {}
    for i, t in ipairs(mid.undoStack or {}) do
        self._undoStack[i] = Logic:DeepCopy(t)
    end
    self._selected  = nil
    self._animating = false

    local S = ArcadiaNexus.ALS_Settings
    if S then S:ClearMidGame(S:GetActiveSlot()) end

    if R then
        if R.HideLoading then R:HideLoading() end
        R:BuildGrid(self._tubes, self._numTubes)
        R:RefreshAll(self._tubes)
        R:UpdateHUD()
        R:SetSelected(nil)
    end

    self:_SetState("PLAYING")
    self:_StartTimer(mid.elapsed or 0)
end

function E:StartGame(config)
    local S = ArcadiaNexus.ALS_Settings
    if not S then return end
    config = config or {}
    local slot = config.slot or S:GetActiveSlot()
    if slot < 1 or slot > S.MAX_SLOTS then return end

    S:SetActiveSlot(slot)
    local mode = config.mode or "continue"
    local save = S:LoadSlot(slot)

    if mode == "new" then
        S:ResetSlot(slot)
        self:StartLevel(1)
        return
    end

    if save and save.midGame then
        self:ResumeMidGame(save.midGame)
    else
        self:StartLevel((save and save.currentLevel) or 1)
    end
end

function E:On()
end

function E:Off()
    self:SaveAndStop()
end
