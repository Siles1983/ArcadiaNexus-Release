--[[
    Games/Chess/Engine.lua
    Spiele-Tab: vs. KI. MP nur über HasMultiplayer() + Match-Runtime (6×6, 2 Sitze).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Chess_Engine = {}
local E = ArcadiaNexus.Chess_Engine

E._sessionId = nil
E.activeGame = nil
E.activeConfig = nil
E.aiPending = false
E.state = "IDLE"
E.mode = "hotseat"
E.match = nil
E._resultEmitted = false
E._moveCount = 0
E._mpSel = nil
E._mpLegal = nil

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local SOUNDS = {
    move         = 774,
    captureEnemy = 1115,
    captureOwn   = 8959,
    check        = 847,
    win          = 888,
    loss         = 847,
}

local SOUND_KEYS = {
    captureEnemy = "soundOnCaptureEnemy",
    captureOwn   = "soundOnCaptureOwn",
    win          = "soundOnWin",
    loss         = "soundOnLoss",
}

local function PlayGameSound(event)
    local S = ArcadiaNexus.Chess_Settings
    if not S or not S:Get("soundEnabled") then return end
    local settingKey = SOUND_KEYS[event]
    if settingKey and not S:Get(settingKey) then return end
    local id = SOUNDS[event]
    if id then PlaySound(id, "SFX") end
end

local function Logic()
    return ArcadiaNexus.Chess_Logic
end

local function Notify()
    local R = ArcadiaNexus.Chess_Renderer
    local M = ArcadiaNexus.Match
    if M and M.NotifyGameView then
        M.NotifyGameView(E, "CHESS", function()
            if R and R.Render then R:Render() end
        end)
        return
    end
    if R and R.Render then R:Render() end
end

local function MatchOpts(engine)
    return Logic().MatchOpts(engine)
end

local function MyColor()
    local seat = E.match and E.match.seat or 1
    return (seat == 1) and "white" or "black"
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then M.HandleGamePublic(self) end
    if self._mpSel then
        local st = self:GetBoardState()
        if not st or st.phase ~= "PLAYING" or st.turn ~= MyColor() then
            self._mpSel = nil
            self._mpLegal = {}
        end
    end
    Notify()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then
        M.HandleGameState(self, "CHESS", st, {
            onPlaying = function()
                self._mpSel = nil
                self._mpLegal = {}
            end,
        })
    end
    Notify()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then M.HandleGameReject(self, "CHESS", f) end
    Notify()
end

function E:OnMatchResult(node, resultId)
    if self.match ~= node or not self._sessionId or node:GetState() ~= "FINISHED" then return end
    if self._resultEmitted then return end
    self._resultEmitted = true
    local board = self:GetBoardState()
    local result = (board and board.localResult) or "DRAW"
    local score = 0
    if result == "WIN" then score = 150
    elseif result == "DRAW" then score = 50 end
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "CHESS",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "normal",
        score = score,
        result = result,
        stats = { moveCount = board and board.moveCount or 0, vsHuman = 1 },
    })
    self:MaybeShowResult(board)
end

function E:MaybeShowResult(board)
    local R = ArcadiaNexus.Chess_Renderer
    if R and R.OnGameOver then R:OnGameOver(board or self:GetBoardState()) end
end

function E:StartGame(config)
    config = config or {}
    self._mpSel = nil
    self._mpLegal = {}
    self.aiPending = false
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            Notify()
            return
        end
        M.BeginNetworkedGame(self, "CHESS", config, Notify, MatchOpts, {
            onBefore = function()
                if self.activeGame then
                    self.activeGame = nil
                    self.activeConfig = nil
                end
            end,
        })
        return
    end
    self.mode = mode
    self._resultEmitted = false
    self._notice = nil

    self:StopMatchQuiet()
    if self.activeGame then
        self:StopGame()
    end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("CHESS", E._sessionId)
    local S = ArcadiaNexus.Chess_Settings
    local cfg = {
        difficulty = (config and config.difficulty)
            or (S and S:Get("difficulty"))
            or "easy",
    }
    local instance = ArcadiaNexus.Chess_Game:New()
    instance:Init(cfg)
    self.activeGame = instance
    self.activeConfig = cfg
    self._moveCount = 0
    self.state = "PLAYING"
    self.mode = "hotseat"

    ArcadiaNexus.Engine:Emit("CHE_GAME_STARTED", instance:GetBoardState())
end

function E:SetReady(ready)
    local M = ArcadiaNexus.Match
    if M and M.SetEngineReady then M.SetEngineReady(self, ready) end
    Notify()
end

function E:TryStartMatch()
    local M = ArcadiaNexus.Match
    if M and M.TryEngineStart then M.TryEngineStart(self) end
    Notify()
end

function E:GetBoardState()
    if self.mode ~= "hotseat" and self.match then
        local seat = self.match.seat or 1
        local st = Logic().BoardStateFromPublic(self.match:GetPublicState(), seat)
        if self._mpSel then
            st.selected = self._mpSel
            st.legalMoves = self._mpLegal or {}
        end
        return st
    end
    if self.activeGame then
        return self.activeGame:GetBoardState()
    end
    return nil
end

function E:HandleCellClick(r, c)
    if self.mode ~= "hotseat" and self.match then
        if self.state ~= "PLAYING" then return end
        local st = self:GetBoardState()
        if not st or st.phase ~= "PLAYING" then return end
        local myColor = MyColor()
        if st.turn ~= myColor then return end
        local L = Logic()
        local piece = L:GetPieceAt(st.board, r, c)
        if self._mpSel then
            local from = self._mpSel
            if piece and piece.color == myColor and not (from.r == r and from.c == c) then
                self._mpSel = { r = r, c = c }
                self._mpLegal = L:GetLegalMoves(st.board, r, c)
                Notify()
                return
            end
            if from.r == r and from.c == c then
                self._mpSel = nil
                self._mpLegal = {}
                Notify()
                return
            end
            local legal = false
            for _, m in ipairs(self._mpLegal or {}) do
                if m.toR == r and m.toC == c then
                    legal = true
                    break
                end
            end
            if not legal then
                self._mpSel = nil
                self._mpLegal = {}
                Notify()
                return
            end
            self.match:SendIntent("MOVE", { i = L.Cell(from.r, from.c), n = L.Cell(r, c) })
            self._mpSel = nil
            self._mpLegal = {}
            Notify()
            return
        end
        if piece and piece.color == myColor then
            self._mpSel = { r = r, c = c }
            self._mpLegal = L:GetLegalMoves(st.board, r, c)
            Notify()
        end
        return
    end

    if not self.activeGame then return end
    if self.aiPending then return end

    local game = self.activeGame
    local state = game:GetBoardState()
    if state.phase ~= "PLAYING" then return end

    if state.selected then
        local result = game:MoveSelected(r, c)
        local newState = game:GetBoardState()

        if result == "moved" or result == "captured" or result == "check" then
            PlayGameSound(result == "captured" and "captureEnemy" or "move")
            self._moveCount = (self._moveCount or 0) + 1
            ArcadiaNexus.Engine:Emit("CHE_MOVE_MADE", newState, result)
            self:ScheduleAIMove()

        elseif result == "checkmate" or result == "stalemate" then
            PlayGameSound("win")
            ArcadiaNexus.Engine:Emit("CHE_MOVE_MADE", newState, result)
            ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", newState)
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            local scoreMap = { easy = 100, normal = 150, hard = 200 }
            local gr = (result == "stalemate") and "DRAW" or "WIN"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId     = "CHESS",
                difficulty = diff,
                score      = (gr == "WIN") and (scoreMap[diff] or 100) or 50,
                result     = gr,
                stats      = { moveCount = self._moveCount or 0 },
            })

        elseif result == "selected" then
            ArcadiaNexus.Engine:Emit("CHE_PIECE_SELECTED", newState)

        else
            ArcadiaNexus.Engine:Emit("CHE_PIECE_DESELECTED", newState)
        end
    else
        local result = game:SelectPiece(r, c)
        local newState = game:GetBoardState()
        if result == "selected" then
            ArcadiaNexus.Engine:Emit("CHE_PIECE_SELECTED", newState)
        elseif result == "deselected" then
            ArcadiaNexus.Engine:Emit("CHE_PIECE_DESELECTED", newState)
        end
    end
end

function E:ScheduleAIMove()
    if self.mode ~= "hotseat" then return end
    if not self.activeGame then return end
    if self.aiPending then return end
    self.aiPending = true

    local sid = E._sessionId
    _timerGuard:After(0.4, function()
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then
            E.aiPending = false
            return
        end
        if not self.activeGame then
            self.aiPending = false
            return
        end
        local result = self.activeGame:DoAIMove()
        self.aiPending = false
        local newState = self.activeGame:GetBoardState()

        if result == "checkmate" or result == "stalemate" then
            PlayGameSound("loss")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
            ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", newState)
            local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
            local gr = (result == "stalemate") and "DRAW" or "LOSS"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId     = "CHESS",
                difficulty = diff,
                score      = 0,
                result     = gr,
                stats      = { moveCount = self._moveCount or 0 },
            })
        elseif result == "check" then
            PlayGameSound("check")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        elseif result == "captured" then
            PlayGameSound("captureOwn")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        else
            PlayGameSound("move")
            ArcadiaNexus.Engine:Emit("CHE_AI_MOVE", newState, result)
        end
    end)
end

function E:HandleResign()
    if self.mode ~= "hotseat" and self.match then
        if self.state ~= "PLAYING" then return end
        self.match:SendIntent("RESIGN", {})
        Notify()
        return
    end
    if not self.activeGame then return end
    self.aiPending = false
    self.activeGame:Resign()
    local state = self.activeGame:GetBoardState()
    ArcadiaNexus.Engine:Emit("CHE_GAME_OVER", state)
    local diff = (self.activeConfig and self.activeConfig.difficulty) or "easy"
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId     = "CHESS",
        difficulty = diff,
        score      = 0,
        result     = "LOSS",
        stats      = { moveCount = self._moveCount or 0 },
    })
end

function E:GetView()
    local lobbyPlayers = {}
    local pub
    local seat = 1
    if self.mode ~= "hotseat" and self.match then
        pub = self.match:GetPublicState() or Logic().EmptyPublic()
        seat = self.match.seat or 1
        if self.state == "LOBBY" then
            local seats = self.match.seats or {}
            local ready = self.match.ready or {}
            local seen = {}
            for i = 1, 2 do
                local k = seats[i]
                if k and k ~= "" and not seen[k] then
                    seen[k] = true
                    lobbyPlayers[#lobbyPlayers + 1] = {
                        key = k,
                        name = k:match("^([^-]+)") or k,
                        ready = ready[i] and true or false,
                        self = k == self.match.playerKey,
                    }
                end
            end
        end
    end
    return {
        state = self.state,
        mode = self.mode,
        pub = pub,
        seat = seat,
        mp = self.mode ~= "hotseat",
        isHost = self.match and self.match.isHost,
        matchState = self.match and self.match:GetState(),
        notice = self._notice,
        lobbyPlayers = lobbyPlayers,
    }
end

function E:HideView()
    local M = ArcadiaNexus.Match
    if M and M.HideEngineView then M.HideEngineView(self) end
end

function E:StopMatchQuiet()
    local M = ArcadiaNexus.Match
    if M and M.StopEngineMatch then M.StopEngineMatch(self) end
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("CHESS", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    _timerGuard:Cancel()
    self.aiPending = false
    self.activeGame = nil
    self.activeConfig = nil
    self._mpSel = nil
    self._mpLegal = {}
    self.state = "IDLE"
    self.mode = "hotseat"
    ArcadiaNexus.Engine:Emit("CHE_GAME_STOPPED")
    Notify()
end

function E:Pause()
end

function E:Resume()
end

function E:EnterIdleState()
    local rnd = ArcadiaNexus.Chess_Renderer
    if rnd and rnd.EnterIdleState then
        rnd:EnterIdleState()
    end
end

function E:SaveState()
end
