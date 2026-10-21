-- Codebreaker: frozen rules, persistent guesses and one local result per run.
local A = _G.ArcadiaNexus
local E = {state="IDLE"}
A.CB_Engine = E

local function Sound(key)
    local S=A.CB_Settings
    if S:Get("soundEnabled") and S:Get("soundOn"..key) then
        PlaySound(({Place=774,Submit=857,Win=888,Lose=847})[key], "SFX")
    end
end

function E:_Snapshot()
    if not self.activeGame then return true end
    return A.CB_Settings:SaveGame(self.activeGame:Snapshot())
end

function E:_EndSession(paused)
    if self._sessionId then
        if paused then A.Lifecycle:PauseGame("CODEBREAKER",self._sessionId) end
        A.Lifecycle:EndGame("CODEBREAKER",self._sessionId)
        self._sessionId=nil
    end
end

function E:CanContinueSave(save)
    if not A.CB_Logic:ValidateSave(save) or (save.phase~="PLAYING" and not save.resultPending) then return false end
    local serial=A.LocalResults:GetSerial("CODEBREAKER",save.runId)
    if not serial then return false end
    local j,receipt=A.LocalResults:GetJournal(),A.LocalResults:GetReceipt(save.runId)
    if not receipt and not j.issued[save.runId] and serial<=j.retiredThrough then return false end
    if receipt and (save.phase=="PLAYING" or receipt.difficulty~=save.difficulty
        or receipt.result~=(save.phase=="WON" and "WIN" or "LOSS")) then return false end
    return true
end

function E:StartGame(config)
    if self.activeGame then return false end
    config=type(config)=="table" and config or {}
    local S=A.CB_Settings
    local mode=config.mode
    if mode~=nil and mode~="new" and mode~="continue" then return false end
    local save=S:LoadSave()
    if mode==nil then
        mode=(not config.overwrite and self:CanContinueSave(save)) and "continue" or "new"
    end
    local game=A.CB_Game:New()
    if mode=="continue" then
        if not self:CanContinueSave(save) or not game:Load(save) then return false end
    else
        local diff,theme=config.difficulty or S:Get("difficulty"),config.theme or S:Get("theme")
        if not A.CB_Logic.CONFIGS[diff] or not A.CB_Themes.THEMES[theme] then return false end
        if self:CanContinueSave(save) and not config.overwrite then return false end
        game:Init({difficulty=diff,theme=theme})
    end
    local sid=A.Lifecycle:ClaimRestart("CODEBREAKER",self._sessionId)
    if not sid then return false end
    if mode~="continue" then game.runId=A.LocalResults:NewRun("CODEBREAKER") end
    self.activeGame,self.activeSlot=game,1
    self.activeConfig={difficulty=game.board.difficulty,theme=game.board.theme}
    self._lastResult=nil
    self._sessionId=sid
    self.state=game.board.phase=="PLAYING" and "PLAYING" or "RESULT_PENDING"
    self:_Snapshot()
    A.Engine:Emit("CB_GAME_STARTED",game:GetBoardState())
    if self.state=="RESULT_PENDING" then self:RetryResult() end
    A.LocalResults:Prune()
    return true
end

function E:_Edit(action,...)
    if self.state~="PLAYING" or not self.activeGame then return false end
    local result=A.CB_Logic[action](A.CB_Logic,self.activeGame.board,...)
    if result~="ok" then return false end
    self:_Snapshot()
    if action=="SetSlot" then Sound("Place") end
    A.Engine:Emit("CB_INPUT_UPDATED",self.activeGame:GetBoardState(),action)
    return true
end
function E:HandleSetSlot(slot,symbol) return self:_Edit("SetSlot",slot,symbol) end
function E:HandleClearSlot(slot) return self:_Edit("ClearSlot",slot) end
function E:HandleClearGuess() return self:_Edit("ClearGuess") end
function E:HandleCopyPrevious() return self:_Edit("CopyPrevious") end

function E:_Result()
    local game=self.activeGame
    local state=game:GetBoardState()
    local data={gameId="CODEBREAKER",difficulty=state.difficulty,runId=game.runId,
        result=state.phase=="WON" and "WIN" or "LOSS",score=state.score,
        stats={attemptCount=state.attemptCount}}
    A.Engine:Emit("GAME_RESULT",data)
    if not data.processed then
        game.resultPending=true
        self.state="RESULT_PENDING"
        self:_Snapshot()
        A.Engine:Emit("CB_RESULT_FAILED")
        return false
    end
    game.resultPending=nil
    self._lastResult=data
    self.state=state.phase
    self:_Snapshot()
    -- Session bleibt bis SaveAndPause/StopGame, damit Tabwechsel und Hub-Hide
    -- den Ergebnisdialog über HandleRendererHide aufräumen.
    if not data.localReplay then Sound(state.phase=="WON" and "Win" or "Lose") end
    A.Engine:Emit(state.phase=="WON" and "CB_GAME_WON" or "CB_GAME_LOST",game:GetBoardState(),data)
    return true
end

function E:HandleSubmit()
    if self.state~="PLAYING" or not self.activeGame then return false end
    local result=self.activeGame:SubmitGuess()
    if result=="incomplete" then A.Engine:Emit("CB_INCOMPLETE"); return false end
    if result=="game_over" then return false end
    if result=="won" or result=="lost" then self.activeGame.resultPending=true end
    self:_Snapshot()
    if result=="won" or result=="lost" then
        self.state="RESULT_PENDING"
        return self:_Result()
    end
    Sound("Submit")
    A.Engine:Emit("CB_BOARD_UPDATED",self.activeGame:GetBoardState())
    return true
end

function E:RetryResult()
    if self.state~="RESULT_PENDING" or not self.activeGame then return false end
    return self:_Result()
end

function E:SaveAndPause()
    if not self.activeGame then return true end
    if self:_Snapshot()==false then return false end
    self:_EndSession(true)
    self.activeGame,self.activeSlot,self.activeConfig,self._lastResult=nil,nil,nil,nil
    self.state="IDLE"
    A.Engine:Emit("CB_GAME_STOPPED")
    return true
end
function E:StopGame() return self:SaveAndPause() end
