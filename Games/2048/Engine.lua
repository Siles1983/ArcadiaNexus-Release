-- 2048: persistent runs, one result at the milestone, optional continuation.
local A = _G.ArcadiaNexus
local E = { state = "IDLE", _sessionId = nil }
A.TDG_Engine = E

local function Sound(result)
    local S = A.TDG_Settings
    if S:Get("soundEnabled") and result == "LOSS" and S:Get("soundOnLoss") then PlaySound(847, "SFX") end
end

function E:_Snapshot()
    if self.activeGame then A.TDG_Settings:SaveSlot(self.activeSlot, self.activeGame:Snapshot()) end
end

function E:_EndSession(paused)
    if self._sessionId then
        if paused then A.Lifecycle:PauseGame("2048", self._sessionId) end
        A.Lifecycle:EndGame("2048", self._sessionId)
        self._sessionId = nil
    end
    self._inputAfter = nil
end

function E:_Result()
    local game = self.activeGame
    if not game or (not game.reached2048 and game.phase ~= "FINISHED") then return true end
    local state = game:GetBoardState()
    local data = { gameId = "2048", difficulty = state.difficulty, runId = game.runId,
        score = state.score, result = state.result, stats = { highestTile = state.highestTile } }
    A.Engine:Emit("GAME_RESULT", data)
    if not data.processed then
        game.resultPending = true
        self:_Snapshot()
        self.state = "RESULT_PENDING"
        self._lastResult = nil
        A.Engine:Emit("TDG_RESULT_FAILED")
        return false
    end
    game.resultPending = nil
    self:_Snapshot()
    self._lastResult = data
    game:RefreshBestScore()
    return true
end

function E:_Present()
    local game = self.activeGame
    if game.phase == "AWAITING_WIN_CHOICE" then
        self.state = "WIN_PROMPT"
        A.Engine:Emit("TDG_WIN_PROMPT", game:GetBoardState(), self._lastResult)
    elseif game.phase == "FINISHED" then
        self.state = "FINISHED"
        self:_EndSession(false)
        A.Engine:Emit("TDG_GAME_OVER", game:GetBoardState(), self._lastResult)
    else self.state = "PLAYING" end
end

function E:CanContinueSave(save)
    if not A.TDG_Logic:ValidateSave(save) or (save.phase == "FINISHED" and not save.resultPending) then return false end
    local serial = A.LocalResults:GetSerial("2048", save.runId)
    if not serial then return false end
    local journal, receipt = A.LocalResults:GetJournal(), A.LocalResults:GetReceipt(save.runId)
    if serial <= journal.retiredThrough and not journal.issued[save.runId] and not receipt then return false end
    if receipt and ((not save.reached2048 and save.phase ~= "FINISHED")
        or receipt.result ~= (save.reached2048 and "WIN" or "LOSS") or receipt.difficulty ~= save.difficulty) then return false end
    return true
end

function E:StartGame(config)
    config = type(config) == "table" and config or {}
    if self.activeGame then return false end
    local slot, mode = config.slot or 1, config.mode or "new"
    if type(slot) ~= "number" or slot < 1 or slot > A.TDG_Settings.MAX_SLOTS or slot ~= math.floor(slot) then return false end
    if mode ~= "new" and mode ~= "continue" then return false end
    local save = A.TDG_Settings:LoadSlot(slot)
    local game = A.TDG_Game:New()
    if mode == "continue" then
        if not self:CanContinueSave(save) or not game:Load(save) then return false end
    else
        if save and not config.overwrite then return false end
        local size = config.size or A.TDG_Settings:Get("boardSize")
        if not A.TDG_Logic:GetDifficulty(size) then return false end
        game:Init({ size = size })
    end
    local sid = A.Lifecycle:ClaimRestart("2048", self._sessionId)
    if not sid then return false end
    if mode ~= "continue" then game.runId = A.LocalResults:NewRun("2048") end
    self.activeGame, self.activeSlot = game, slot
    self._lastResult, self._inputAfter = nil, nil
    self._sessionId = sid
    self.state = "PLAYING"
    self:_Snapshot()
    -- Reconcile a persisted milestone before accepting input or showing a choice.
    if (game.reached2048 or game.phase == "FINISHED") and not self:_Result() then return false end
    A.Engine:Emit("TDG_GAME_STARTED", game:GetBoardState())
    self:_Present()
    A.LocalResults:Prune()
    return true
end

function E:HandlePlayerMove(direction)
    if self.state ~= "PLAYING" or not self.activeGame then return false end
    if self._inputAfter and GetTime() < self._inputAfter then return false end
    local game = self.activeGame
    if not game:HandleMove(direction) then return false end
    self._inputAfter = GetTime() + (A.TDG_Settings:Get("reducedMotion") and 0 or 0.22)
    self:_Snapshot() -- final logical board, never an animation intermediate
    if game.phase ~= "ACTIVE" then
        if not self:_Result() then return false end
        self:_Snapshot()
        if game.phase == "FINISHED" then self:_EndSession(false) end
        if self._lastResult and not self._lastResult.localReplay then Sound(game:GetBoardState().result) end
    end
    A.Engine:Emit("TDG_BOARD_UPDATED", game:GetBoardState())
    self:_Present()
    return true
end

function E:ContinueAfterWin()
    if self.state ~= "WIN_PROMPT" or not self.activeGame
        or self.activeGame.phase ~= "AWAITING_WIN_CHOICE" then return false end
    self.activeGame.phase, self.state = "ACTIVE", "PLAYING"
    self.activeGame.lastSpawn, self.activeGame.motions = nil, nil
    self._inputAfter, self._lastResult = nil, nil
    self:_Snapshot()
    A.Engine:Emit("TDG_GAME_CONTINUED", self.activeGame:GetBoardState())
    return true
end

function E:FinishRun()
    if not self.activeGame or not self.activeGame.reached2048 or self.state == "RESULT_PENDING" then return false end
    self.activeGame.phase = "FINISHED"
    self:_Snapshot()
    if not self:_Result() then return false end
    self:_EndSession(false)
    self.state = "FINISHED"
    self:StopGame()
    return true
end

function E:RetryResult()
    if self.state ~= "RESULT_PENDING" or not self.activeGame then return false end
    if not self:_Result() then return false end
    self:_Snapshot()
    A.Engine:Emit("TDG_GAME_STARTED", self.activeGame:GetBoardState())
    self:_Present()
    return true
end

function E:SaveAndPause()
    if not self.activeGame then return true end
    self:_Snapshot()
    -- A failed result stays pending in the saved gameplay phase. Resume will
    -- retry preparation; abandoning the UI must still release session ownership.
    if self.activeGame.reached2048 or self.activeGame.phase == "FINISHED" then self:_Result() end
    self:_EndSession(true)
    self.activeGame, self.activeSlot, self._lastResult = nil, nil, nil
    self.state = "IDLE"
    A.Engine:Emit("TDG_GAME_STOPPED")
    return true
end

function E:StopGame() return self:SaveAndPause() end
