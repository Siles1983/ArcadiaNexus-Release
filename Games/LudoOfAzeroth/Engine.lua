--[[
    Ludo of Azeroth – Engine.lua

    Events (LOA_ Prefix):
      LOA_GAME_STARTED(game)
      LOA_DICE_ROLLED(game, value)
      LOA_PIECE_MOVED(game, playerID, pieceIdx, result)
      LOA_TURN_CHANGED(game)
      LOA_NO_MOVE(game)
      LOA_GAME_WON(game, winnerID)
      LOA_GAME_STOPPED()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Engine = {}
local E = ArcadiaNexus.LOA_Engine

E._sessionId = nil

E.activeGame    = nil
E._running      = false
E.AI_DELAY      = 1.2
E.AI_MOVE_DELAY = 0.8

local SAVE_KEY = "saveState"

local function GetDB()
    return ArcadiaNexus.Persistence:GetGameSettings("LOA")
end

local function PlayLoa(event)
    local S = ArcadiaNexus.LOA_Settings
    if not S or not S:Get("soundEnabled") then return end
    if event == "roll" and S:Get("soundOnRoll") then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 774, "SFX")
    elseif event == "move" and S:Get("soundOnMove") then
        PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN or 847, "SFX")
    elseif event == "capture" and S:Get("soundOnCapture") then
        PlaySound(SOUNDKIT.IG_QUEST_ABANDON or 847, "SFX")
    elseif event == "home" and S:Get("soundOnHome") then
        PlaySound(SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 888, "SFX")
    elseif event == "win" and S:Get("soundOnWin") then
        PlaySound(SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or 888, "SFX")
    end
end

function E:HasSave()
    return GetDB()[SAVE_KEY] ~= nil
end

function E:ClearSave()
    GetDB()[SAVE_KEY] = nil
end

function E:SaveGame()
    local game = self.activeGame
    if not game or not self._running then return end
    local data = ArcadiaNexus.LOA_Logic:Serialize(game)
    if data then
        GetDB()[SAVE_KEY] = data
    end
end

function E:ResumeGame()
    local data = GetDB()[SAVE_KEY]
    if not data then return end

    local game = ArcadiaNexus.LOA_Logic:Deserialize(data)
    if not game then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("LOA", E._sessionId)
    self.activeGame = game
    self._running   = true

    local R = ArcadiaNexus.LOA_Renderer
    if R then R:OnGameStarted(game) end
    ArcadiaNexus.Engine:Emit("LOA_GAME_STARTED", game)

    self:SaveGame()

    local L = ArcadiaNexus.LOA_Logic

    if game.phase == "move" and game.rolled then
        if game.current == game.humanID then
            if R then
                R:UpdateStatus(game)
                R:ShowValidMoveHighlights(game)
            end
        else
            C_Timer.After(self.AI_MOVE_DELAY, function()
                if not self._running or self.activeGame ~= game then return end
                local best = L:AIPickMove(game)
                if best then
                    self:DoMove(game, best.pieceIdx)
                else
                    L:NextTurn(game)
                    self:StartTurn(game)
                end
            end)
        end
    elseif self:IsAITurn(game) then
        self:StartTurn(game)
    end
end

function E:IsAITurn(game)
    return game and game.current ~= game.humanID
end

function E:StartGame(config)
    self:StopGame(true)

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("LOA", E._sessionId)

    local S   = ArcadiaNexus.LOA_Settings
    local cfg = {
        humanColor = tonumber(config and config.humanColor) or tonumber(S:Get("playerColor")) or 1,
        aiCount    = tonumber(config and config.aiCount)    or tonumber(S:Get("aiCount"))    or 1,
    }

    self:ClearSave()

    local game     = ArcadiaNexus.LOA_Logic:NewGame(cfg)
    self.activeGame = game
    self._running   = true

    local R = ArcadiaNexus.LOA_Renderer
    if R then R:OnGameStarted(game) end
    ArcadiaNexus.Engine:Emit("LOA_GAME_STARTED", game)

    self:SaveGame()
    self:StartTurn(game)
end

function E:StartTurn(game)
    if not self._running then return end
    local R = ArcadiaNexus.LOA_Renderer

    if R then R:OnTurnStart(game) end
    ArcadiaNexus.Engine:Emit("LOA_TURN_CHANGED", game)
    self:SaveGame()

    if self:IsAITurn(game) and game.phase == "roll" then
        C_Timer.After(self.AI_DELAY, function()
            if not self._running then return end
            if self.activeGame ~= game then return end
            self:DoRoll(game)
        end)
    end
end

function E:HandleRollClick()
    local game = self.activeGame
    if not game or not self._running then return end
    if game.phase ~= "roll" then return end
    if game.current ~= game.humanID then return end
    self:DoRoll(game)
end

function E:DoRoll(game)
    if not self._running then return end
    local L   = ArcadiaNexus.LOA_Logic
    local val = L:RollDice(game)

    PlayLoa("roll")
    self:SaveGame()

    self._rollContinueGame = game
    self._rollContinueFn = function()
        self:_ContinueAfterRoll(game)
    end

    ArcadiaNexus.Engine:Emit("LOA_DICE_ROLLED", game, val)
end

function E:_ContinueAfterRoll(game)
    if not self._running or self.activeGame ~= game then return end
    local L = ArcadiaNexus.LOA_Logic
    local R = ArcadiaNexus.LOA_Renderer
    local moves = L:GetValidMoves(game)

    if #moves == 0 then
        if L:CanReroll(game) then
            if R then R:OnRollAgain(game) end
            if self:IsAITurn(game) then
                C_Timer.After(self.AI_DELAY, function()
                    if not self._running then return end
                    if self.activeGame ~= game then return end
                    if game.phase ~= "roll" then return end
                    self:DoRoll(game)
                end)
            end
            return
        end
        ArcadiaNexus.Engine:Emit("LOA_NO_MOVE", game)
        C_Timer.After(1.0, function()
            if not self._running then return end
            if self.activeGame ~= game then return end
            L:NextTurn(game)
            self:StartTurn(game)
        end)
        return
    end

    if self:IsAITurn(game) then
        C_Timer.After(self.AI_MOVE_DELAY, function()
            if not self._running then return end
            if self.activeGame ~= game then return end
            local best = L:AIPickMove(game)
            if best then self:DoMove(game, best.pieceIdx) end
        end)
    end
end

function E:HandlePieceClick(pieceIdx)
    local game = self.activeGame
    if not game or not self._running then return end
    if game.phase ~= "move" then return end
    if game.current ~= game.humanID then return end

    local L     = ArcadiaNexus.LOA_Logic
    local moves = L:GetValidMoves(game)
    local valid = false
    for _, m in ipairs(moves) do
        if m.pieceIdx == pieceIdx then valid = true; break end
    end
    if not valid then return end

    self:DoMove(game, pieceIdx)
end

function E:DoMove(game, pieceIdx)
    if not self._running then return end
    local L      = ArcadiaNexus.LOA_Logic
    local R      = ArcadiaNexus.LOA_Renderer
    local result = L:ApplyMove(game, pieceIdx)

    if result == "captured" then PlayLoa("capture")
    elseif result == "finished" then PlayLoa("home")
    elseif result == "win" then PlayLoa("win")
    else PlayLoa("move") end

    if R then R:OnPieceMoved(game, game.current, pieceIdx, result) end
    ArcadiaNexus.Engine:Emit("LOA_PIECE_MOVED", game, game.current, pieceIdx, result)

    if result == "win" then
        self:ClearSave()
        if R then R:OnGameWon(game, game.winner) end
        ArcadiaNexus.Engine:Emit("LOA_GAME_WON", game, game.winner)
        local playerResult = (game.winner == game.humanID) and "WIN" or "LOSS"
        local figuresHome = 0
        local humanPlayer = game.players and game.players[game.humanID]
        if humanPlayer then
            figuresHome = L:CountHomePieces(humanPlayer)
        end
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "LOA", difficulty = nil, score = 0, result = playerResult,
            stats  = { figuresHome = figuresHome },
        })
        return
    end

    self:SaveGame()

    C_Timer.After(0.5, function()
        if not self._running then return end
        if self.activeGame ~= game then return end
        L:NextTurn(game)
        self:StartTurn(game)
    end)
end

function E:StopGame(skipSave)
    if not skipSave and self.activeGame and self._running then
        self:SaveGame()
    end
    self._rollContinueFn   = nil
    self._rollContinueGame = nil
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("LOA", E._sessionId)
        E._sessionId = nil
    end
    self._running   = false
    self.activeGame = nil
    ArcadiaNexus.Engine:Emit("LOA_GAME_STOPPED")
end
