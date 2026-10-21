--[[
    Gaming Hub – Simon Says
    Games/ArcadiasEcho/Engine.lua

    Events (AE_ Prefix):
      AE_GAME_STARTED(board)
      AE_SEQUENCE_SHOW(board, seqStep)   – welcher Schritt gerade leuchtet (1-basiert)
      AE_SEQUENCE_DONE(board)            – Sequenz fertig, Spieler ist dran
      AE_INPUT_CORRECT(board)            – Spieler hat richtig geklickt
      AE_INPUT_WRONG(board, symIdx)      – falsches Symbol
      AE_ROUND_COMPLETE(board)           – Runde geschafft → nächste startet
      AE_GAME_STOPPED()

    Renderer direkt aufrufen für zeitkritische Darstellung (Glow/Flash).
    Events nur für Zustandsübergänge.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AE_Engine = {}
local E = ArcadiaNexus.AE_Engine

E._sessionId = nil

E.activeGame  = nil
E._inputBlock = false

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

local GAME_ID = "ARCADIASECHO"

local function CopyResult(data)
    if type(data) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(data) do
        if type(value) == "table" then
            local inner = {}
            for innerKey, innerValue in pairs(value) do
                if type(innerValue) ~= "table" and type(innerValue) ~= "function" then
                    inner[innerKey] = innerValue
                end
            end
            copy[key] = inner
        elseif type(value) ~= "function" then
            copy[key] = value
        end
    end
    return copy
end

local function ValidRunId(runId)
    return type(runId) == "string" and runId ~= ""
end

local function Receipt(runId)
    local LR = ArcadiaNexus.LocalResults
    if not LR or not ValidRunId(runId) then return nil end
    return LR:GetReceipt(runId)
end

local function CopyValue(value)
    if type(value) ~= "table" then
        if type(value) == "function" then return nil end
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = CopyValue(inner)
    end
    return copy
end

local function ApplyBookingFields(target, payload)
    if type(target) ~= "table" or type(payload) ~= "table" then return end
    if not ValidRunId(target.runId) or target.runId ~= payload.runId then return end
    for _, key in ipairs({ "newHighscore", "newMetricRecords", "awardedXP", "awardedGold" }) do
        if payload[key] ~= nil then
            target[key] = CopyValue(payload[key])
        end
    end
end

-- pendingResults[runId] ist die von LocalResults:Prune gelesene Form.
-- Ein Reset der Defaults lässt diese Tabelle stehen.
-- nil ist leer. Ein anderer Typ bleibt stehen und blockiert.
local function InspectPending()
    local db = ArcadiaNexus.Persistence:GetGameSettings(GAME_ID)
    local bucket = db.pendingResults
    if bucket == nil then return nil, false end
    if type(bucket) ~= "table" then return nil, true end
    local open, blocked = nil, false
    for id, row in pairs(bucket) do
        local runId = type(row) == "table" and row.runId or nil
        if ValidRunId(id) and ValidRunId(runId) and id == runId and Receipt(id) then
            bucket[id] = nil
        elseif open or type(row) ~= "table" or not ValidRunId(runId) or id ~= runId then
            blocked = true
        else
            open = row
        end
    end
    if blocked then return nil, true end
    if not next(bucket) then db.pendingResults = nil end
    return open, false
end

local function StorePending(data)
    local copy = CopyResult(data)
    if not copy or copy.gameId ~= GAME_ID or not ValidRunId(copy.runId) then
        return false
    end
    local open, blocked = InspectPending()
    if blocked then return false end
    if open then return open.runId == copy.runId end
    local db = ArcadiaNexus.Persistence:GetGameSettings(GAME_ID)
    if db.pendingResults == nil then
        db.pendingResults = {}
    elseif type(db.pendingResults) ~= "table" then
        return false
    end
    db.pendingResults[copy.runId] = copy
    return true
end

local function Bookable(row)
    return type(row) == "table" and row.gameId == GAME_ID and type(row.runId) == "string"
        and (row.result == "WIN" or row.result == "LOSS")
        and type(row.score) == "number" and row.score >= 0 and row.score == row.score and row.score < math.huge
end

local function BookOpenPending()
    local open, blocked = InspectPending()
    if blocked then return false end
    if not open then return true end
    if not Bookable(open) then return false end
    if not Receipt(open.runId) then
        local payload = CopyResult(open)
        pcall(function() ArcadiaNexus.Engine:Emit("GAME_RESULT", payload) end)
    end
    if not Receipt(open.runId) then return false end
    InspectPending()
    return true
end

-- ============================================================
-- Sound
-- ============================================================
local function PlaySS(event)
    local S = ArcadiaNexus.AE_Settings
    if not S or not S:Get("soundEnabled") then return end
    -- Nur Fallback-IDs nutzen die sicher in WotLK/Midnight existieren
    if event == "flash" and S:Get("soundOnFlash") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "input" and S:Get("soundOnInput") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "win" and S:Get("soundOnWin") then
        PlaySound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or 888, "SFX")
    elseif event == "lose" and S:Get("soundOnLose") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    end
end

-- ============================================================
-- CancelTimers – bricht alle laufenden Sequenz-Timer ab
-- ============================================================
function E:CancelTimers()
    _timerGuard:Cancel()
    self._running = false
end

-- ============================================================
-- StartGame
-- ============================================================
function E:StartGame(config)
    local S = ArcadiaNexus.AE_Settings
    local cfg = {
        difficulty = (config and config.difficulty) or S:Get("difficulty"),
        theme = (config and config.theme) or S:Get("theme"),
    }
    if not ArcadiaNexus.AE_Themes.DIFFICULTY[cfg.difficulty]
        or not ArcadiaNexus.AE_Themes.THEMES[cfg.theme] then return false end
    if self.activeGame and not self:FinishRun("restart") then return false end
    if not BookOpenPending() then return false end
    local GS = ArcadiaNexus.GameSession
    if E._sessionId and GS and GS.ResumeSaveBlocked and GS:ResumeSaveBlocked(E._sessionId) then
        local game = self.activeGame
        local runId = game and (game.runId or (game.resultData and game.resultData.runId))
        if not (game and game.resultCommitted and runId and Receipt(runId)) then return false end
        GS:ReleaseResumeFailure()
    end
    local sid = ArcadiaNexus.Lifecycle:RestartGame("ARCADIASECHO", E._sessionId)
    if not sid then return false end
    E._sessionId = sid
    self:CancelTimers()
    self._inputBlock = true

    local board    = ArcadiaNexus.AE_Logic:NewBoard(cfg)
    self.activeGame = { board = board, runId = ArcadiaNexus.LocalResults:NewRun("ARCADIASECHO") }
    self.activeConfig = cfg
    self._flashes = {}
    self._running   = true
    self.state = "PLAYING"

    ArcadiaNexus.Engine:Emit("AE_GAME_STARTED", board)

    -- Kurze Pause, dann erste Runde starten
    _timerGuard:After(0.6, function()
        if not self._running then return end
        self:StartNextRound()
    end)
    return true
end

-- A completed attempt always uses LOSS in the existing statistics contract.
-- hide, exit and restart are a voluntary abort until a result already exists.
local function IsVoluntaryAbort(reason)
    return reason == "hide" or reason == "exit" or reason == "restart"
end

function E:FinishRun(reason)
    local game = self.activeGame
    if not game or game.resultCommitted then return true end
    self:CancelTimers()
    self._inputBlock = true
    if not game.resultData and IsVoluntaryAbort(reason) then
        return true
    end
    self.state = "FINISHED"
    local board = game.board
    board.state = "lost"
    if not game.resultData then
        local score = ArcadiaNexus.AE_Logic:GetScore(board)
        game.resultData = {
            gameId = "ARCADIASECHO", difficulty = board.difficulty,
            runId = game.runId, result = "LOSS", score = score,
            ruleVersion = 2, reason = reason,
            stats = { maxSequence = score },
        }
    end
    if not Bookable(game.resultData) or not StorePending(game.resultData) then return false end
    local open = InspectPending()
    if not open or open.runId ~= game.runId or not Bookable(open) then return false end
    if not Receipt(game.runId) then
        local payload = CopyResult(open)
        pcall(function() ArcadiaNexus.Engine:Emit("GAME_RESULT", payload) end)
        if Receipt(game.runId) and game.resultData.runId == game.runId then
            ApplyBookingFields(game.resultData, payload)
        end
    end
    if not Receipt(game.runId) or game.resultData.runId ~= game.runId then return false end
    InspectPending()
    game.resultData.processed = true
    game.resultCommitted = true
    return true
end

function E:EndAttempt()
    if not self.activeGame then return false end
    local game = self.activeGame
    local board = game.board
    if not self:FinishRun("exit") then return false end
    if not game.resultCommitted then
        return self:StopGame() ~= false
    end
    local R = ArcadiaNexus.AE_Renderer
    if R then R:OnGameFinished(board) end
    return true
end

-- ============================================================
-- StartNextRound – verlängert Sequenz, spielt sie ab
-- ============================================================
function E:StartNextRound()
    if not self.activeGame or not self._running then return end
    self._inputBlock = true
    self._flashes = {}

    local board = self.activeGame.board
    ArcadiaNexus.AE_Logic:NextRound(board)

    -- Renderer informieren (Runde aktualisieren)
    local R = ArcadiaNexus.AE_Renderer
    if R then R:OnNewRound(board) end

    -- Sequenz schrittweise abspielen
    self:PlaySequence(board, 1)
end

-- ============================================================
-- PlaySequence – rekursive Sequenz-Anzeige
-- ============================================================
function E:PlaySequence(board, step)
    if not self._running or not self.activeGame or self.activeGame.board ~= board then return end
    if step > board.round then
        -- Alle Schritte gezeigt → Spieler ist dran
        ArcadiaNexus.AE_Logic:SetInputPhase(board)
        self._inputBlock = false
        local R = ArcadiaNexus.AE_Renderer
        if R then R:OnSequenceDone(board) end
        ArcadiaNexus.Engine:Emit("AE_SEQUENCE_DONE", board)
        return
    end

    local symIdx  = board.sequence[step]
    local flashOn = board.speed * 0.55   -- Zeit AN
    local flashOff= board.speed * 0.45  -- Zeit AUS (Pause zwischen Symbolen)

    -- Symbol aufleuchten lassen
    local R = ArcadiaNexus.AE_Renderer
    if R then R:FlashSymbol(symIdx, true) end
    ArcadiaNexus.Engine:Emit("AE_SEQUENCE_SHOW", board, step)
    PlaySS("flash")

    _timerGuard:After(flashOn, function()
        if not self._running then return end
        -- Symbol ausschalten
        if R then R:FlashSymbol(symIdx, false) end

        _timerGuard:After(flashOff, function()
            if not self._running then return end
            -- Nächster Schritt
            self:PlaySequence(board, step + 1)
        end)
    end)
end

-- ============================================================
-- HandleInput – Spieler klickt auf Symbol
-- ============================================================
function E:HandleInput(symIdx)
    if not self.activeGame or self._inputBlock or not self._running then return false end
    local board = self.activeGame.board
    if board.state ~= "input" or type(symIdx) ~= "number" or symIdx ~= math.floor(symIdx)
        or symIdx < 1 or symIdx > board.symbolCount then return false end

    local R = ArcadiaNexus.AE_Renderer

    -- Kurzes Aufleuchten als Feedback
    if R then R:FlashSymbol(symIdx, true) end
    local flash = {}
    self._flashes[symIdx] = flash
    _timerGuard:After(0.18, function()
        if not self._running or not self.activeGame or self.activeGame.board ~= board
            or self._flashes[symIdx] ~= flash then return end
        if R then R:FlashSymbol(symIdx, false) end
    end)

    local result = ArcadiaNexus.AE_Logic:HandleInput(board, symIdx)

    if result == "wrong" then
        PlaySS("lose")
        self:FinishRun("error")
        if R then R:OnGameFinished(board) end
        ArcadiaNexus.Engine:Emit("AE_INPUT_WRONG", board, symIdx)

    elseif result == "correct" then
        PlaySS("input")
        if R then R:OnInputCorrect(board) end
        ArcadiaNexus.Engine:Emit("AE_INPUT_CORRECT", board)

    elseif result == "round_complete" then
        self._flashes = {}
        PlaySS("win")
        self._inputBlock = true
        if R then R:OnRoundComplete(board) end
        ArcadiaNexus.Engine:Emit("AE_ROUND_COMPLETE", board)
        -- Kurze Pause, dann nächste Runde
        _timerGuard:After(1.2, function()
            if not self._running then return end
            self:StartNextRound()
        end)
    end
    return true
end

-- ============================================================
-- StopGame
-- ============================================================
function E:StopGame()
    if self.activeGame and not self:FinishRun("hide") then return false end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("ARCADIASECHO", E._sessionId)
        E._sessionId = nil
    end
    self:CancelTimers()
    self.activeGame  = nil
    self.activeConfig = nil
    self.state = "IDLE"
    self._inputBlock = true
    ArcadiaNexus.Engine:Emit("AE_GAME_STOPPED")
    return true
end
