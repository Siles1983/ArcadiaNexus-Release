-- ============================================================
--  Tavern Cards – Engine.lua
--  State-Machine, Lifecycle, TimerGuard, GAME_RESULT
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Engine = {}
local E = ArcadiaNexus.TC_Engine

E._sessionId = nil
E.state = "IDLE"
E.gameState = nil
E.mode = "hotseat"
E.match = nil
E._resultEmitted = false
E._mpChar = "thrall"

local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local SND = {
    play    = 1115, -- Karte ablegen
    draw    = 862,  -- Karte ziehen (Rucksack oeffnen)
    shuffle = 774,  -- Mischen
    uno     = 888,  -- Sonderkarte / UNO
    penalty = 847,  -- Fehlruf
    wild    = 888,  -- Wild / +4
    win     = 888,  -- LEVELUP
    lose    = 847,  -- RAID_WARNING
}

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("TAVERNCARDS")
    return (tbl and tbl[key]) or key
end

local function PlaySoundKey(key)
    local S = ArcadiaNexus.TC_Settings
    if not S or not S:Get("soundEnabled") then return end
    local map = {
        play    = "soundOnPlay",
        draw    = "soundOnDraw",
        shuffle = "soundOnDraw",
        win     = "soundOnWin",
        lose    = "soundOnLose",
        wild    = "soundOnSpecial",
        uno     = "soundOnSpecial",
        penalty = "soundOnSpecial",
    }
    local setting = map[key]
    if setting and not S:Get(setting) then return end
    local id = SND[key] or 774
    PlaySound(id, "Master")
end

function E:_InvalidateTimers()
    _timerGuard:Cancel()
    E._unoPending = false
    E._unoToken = (E._unoToken or 0) + 1
end

function E:_SetState(newState)
    E.state = newState
    local R = ArcadiaNexus.TC_Renderer
    if R and R.OnStateChanged then R:OnStateChanged(newState) end
end

function E:_NotifyBoard()
    local M = ArcadiaNexus.Match
    if E.mode ~= "hotseat" and M and M.NotifyGameView then
        M.NotifyGameView(E, "TAVERNCARDS", function()
            local R = ArcadiaNexus.TC_Renderer
            if R and R.Render then R:Render() end
        end)
        return
    end
    if E.mode ~= "hotseat" then
        local R = ArcadiaNexus.TC_Renderer
        if R and R.Render then R:Render() end
        return
    end
    local R = ArcadiaNexus.TC_Renderer
    if R and R.UpdateBoard then R:UpdateBoard(E.gameState) end
end

function E:_SetTurnNotice(played, playerIndex)
    local gs = E.gameState
    if not gs or not played then return end
    gs.turnNotice = nil
    local Rules = ArcadiaNexus.TC_Rules
    local nextIdx = Rules:NextPlayerIndex(gs, 1 + (gs.skipNext or 0))
    local pname = gs.players[playerIndex].name or "?"
    if played.type == "SKIP" and nextIdx == 1 then
        gs.turnNotice = string.format(L("notice_skip"), pname)
    elseif played.type == "DRAW2" and nextIdx == 1 then
        gs.turnNotice = string.format(L("notice_draw2"), pname)
    elseif played.type == "WILD4" and nextIdx == 1 then
        gs.turnNotice = string.format(L("notice_wild4"), pname)
    elseif played.type == "REVERSE" then
        gs.turnNotice = string.format(L("notice_reverse"), pname)
    elseif playerIndex ~= 1 then
        gs.turnNotice = string.format(L("notice_play"), pname)
    end
end

function E:_ScheduleUnoWindow(playerIndex)
    local gs = E.gameState
    local player = gs.players[playerIndex]
    if player then player.unoCalled = false end
    gs.unoWindow = { playerIndex = playerIndex, resolved = false }
    E:_NotifyBoard()
    _timerGuard:After(3, function()
        if not E.gameState or not E.gameState.unoWindow then return end
        local uw = E.gameState.unoWindow
        if uw.resolved then return end
        uw.resolved = true
        local pi = uw.playerIndex
        if not E.gameState.players[pi].unoCalled then
            if pi == 1 and ArcadiaNexus.TC_AI:ShouldCatchUno(E.gameState) then
                E.gameState.stats.unosMissed = (E.gameState.stats.unosMissed or 0) + 1
                E.gameState.stats.unosCaught = (E.gameState.stats.unosCaught or 0) + 1
                ArcadiaNexus.TC_Logic:DrawCardsForPlayer(E.gameState, pi, 2)
                PlaySoundKey("penalty")
            else
                E.gameState.players[pi].unoCalled = true
                E.gameState.stats.unosCalled = (E.gameState.stats.unosCalled or 0) + 1
            end
        end
        E.gameState.unoWindow = nil
        E:_AdvanceTurn()
    end)
end

function E:_ResolveUnoWindow(advanceTurn)
    local gs = E.gameState
    if not gs or not gs.unoWindow or gs.unoWindow.resolved then return end
    gs.unoWindow.resolved = true
    gs.unoWindow = nil
    if advanceTurn then E:_AdvanceTurn() end
end

function E:_AfterPlayVisual(playerIndex, played, continueFn)
    local gs = E.gameState
    local player = gs.players[playerIndex]
    local R = ArcadiaNexus.TC_Renderer
    self:_SetTurnNotice(played, playerIndex)
    if player.isAI and R and R.ShowPlayFeedback then
        R:ShowPlayFeedback(gs, playerIndex, played, continueFn)
    else
        self:_NotifyBoard()
        if continueFn then continueFn() end
    end
end

function E:_FinishPlayTurn(playerIndex, played)
    local gs = E.gameState
    local function cont()
        if gs.pendingDraw and gs.pendingDraw > 0 and played
        and (played.type == "DRAW2" or played.type == "WILD4") then
            E:_AdvanceTurn()
            return
        end
        E:_AdvanceTurn()
    end
    E:_AfterPlayVisual(playerIndex, played, cont)
end

function E:_BuildConfig(config)
    local S = ArcadiaNexus.TC_Settings
    local Logic = ArcadiaNexus.TC_Logic
    local playerCharacter = (config and config.playerCharacter) or S:Get("playerCharacter")
    if not (config and config.playerCharacter) and S:Get("randomPlayerCharacter") and Logic then
        playerCharacter = Logic:PickRandomPlayerCharacterKey()
    end
    return {
        difficulty      = (config and config.difficulty) or S:Get("difficulty"),
        aiCount         = (config and config.aiCount) or S:Get("aiCount"),
        gameMode        = (config and config.gameMode) or S:Get("gameMode"),
        pointTarget     = (config and config.pointTarget) or S:Get("pointTarget"),
        theme           = (config and config.theme) or S:Get("theme"),
        playerCharacter = playerCharacter,
        rules           = S:Get("rules"),
    }
end

local function MpLogic()
    return ArcadiaNexus.TC_Logic
end

local function MatchOpts(engine)
    return MpLogic().MatchOpts(engine)
end

function E:MaybeScheduleUno()
    if not self.match or not self.match.isHost then return end
    local hid = self.match._hostHidden
    if type(hid) ~= "table" or not hid.unoWindow or hid.unoWindow.resolved then
        return
    end
    if self._unoPending then return end
    self._unoPending = true
    local sid = E._sessionId
    local tok = (self._unoToken or 0) + 1
    self._unoToken = tok
    _timerGuard:After(3, function()
        if tok ~= E._unoToken then return end
        E._unoPending = false
        if not ArcadiaNexus.GameSession:IsSession(E, sid) then return end
        if not E.match or not E.match.isHost then return end
        local h = E.match._hostHidden
        if type(h) ~= "table" or not h.unoWindow or h.unoWindow.resolved then return end
        E.match:SendIntent("UNO_EXPIRE", {})
        E:_NotifyBoard()
    end)
end

function E:OnMatchPublic()
    local M = ArcadiaNexus.Match
    if M and M.HandleGamePublic then M.HandleGamePublic(self) end
    if self.match and self.match.isHost then
        local hid = self.match._hostHidden
        if type(hid) == "table" and hid.unoWindow and not hid.unoWindow.resolved then
            self:MaybeScheduleUno()
        else
            self._unoPending = false
            self._unoToken = (self._unoToken or 0) + 1
        end
    end
    self:_NotifyBoard()
end

function E:OnMatchState(st)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameState then
        M.HandleGameState(self, "TAVERNCARDS", st, {
            onPlaying = function()
                self._unoPending = false
                local R = ArcadiaNexus.TC_Renderer
                local gs = self:GetBoardState()
                if R and R.OnGameStarted then R:OnGameStarted(gs) end
            end,
        })
    end
    self:_NotifyBoard()
end

function E:OnMatchReject(f)
    local M = ArcadiaNexus.Match
    if M and M.HandleGameReject then M.HandleGameReject(self, "TAVERNCARDS", f) end
    self:_NotifyBoard()
end

function E:OnMatchResult(node, resultId)
    if self.match ~= node or not self._sessionId or node:GetState() ~= "FINISHED" then return end
    if self._resultEmitted then return end
    self._resultEmitted = true
    local board = self:GetBoardState()
    local result = (board and board.result) or "LOSS"
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId = "TAVERNCARDS",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "normal",
        score = 0,
        result = result,
        stats = { vsHuman = 1 },
    })
    local R = ArcadiaNexus.TC_Renderer
    if R and R.ShowMatchResult then
        R:ShowMatchResult(result, board)
    end
end

function E:SetReady(ready)
    local M = ArcadiaNexus.Match
    if M and M.SetEngineReady then M.SetEngineReady(self, ready) end
    self:_NotifyBoard()
end

function E:TryStartMatch()
    local M = ArcadiaNexus.Match
    if M and M.TryEngineStart then M.TryEngineStart(self) end
    self:_NotifyBoard()
end

function E:GetBoardState()
    if self.mode ~= "hotseat" and self.match then
        local priv = self.match.GetPrivateState and self.match:GetPrivateState()
        return MpLogic().BoardStateFromMatch(self.match:GetPublicState(), priv, self.match.seat or 1)
    end
    return self.gameState
end

function E:GetView()
    local lobbyPlayers = {}
    local pub
    local seat = 1
    if self.mode ~= "hotseat" and self.match then
        pub = self.match:GetPublicState() or MpLogic().EmptyPublic()
        seat = self.match.seat or 1
        if self.state == "LOBBY" then
            local seats = self.match.seats or {}
            local ready = self.match.ready or {}
            local seen = {}
            for i = 1, 4 do
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

function E:StartGame(config)
    config = config or {}
    self._unoPending = false
    local mode = config.mode or "hotseat"
    if mode == "host" or mode == "join" or mode == "rejoin" then
        local M = ArcadiaNexus.Match
        if not M or not M.BeginNetworkedGame then
            self._notice = "nomp"
            self:_NotifyBoard()
            return
        end
        M.BeginNetworkedGame(self, "TAVERNCARDS", config, function()
            self:_NotifyBoard()
        end, MatchOpts, {
            onBefore = function()
                self:_InvalidateTimers()
                self.gameState = nil
                local S = ArcadiaNexus.TC_Settings
                self._mpChar = config.playerCharacter or (S and S:Get("playerCharacter")) or "thrall"
            end,
        })
        return
    end
    self.mode = mode
    self._resultEmitted = false
    self._notice = nil

    self:StopMatchQuiet()
    self:_InvalidateTimers()
    local S = ArcadiaNexus.TC_Settings
    if S then S:ClearPausedState() end
    local cfg = self:_BuildConfig(config)
    if cfg.aiCount < 1 or cfg.aiCount > 3 then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("TAVERNCARDS", E._sessionId)
    local Logic = ArcadiaNexus.TC_Logic
    E.gameState = Logic:NewGameState(cfg)
    self.mode = "hotseat"
    E:_SetState("DEALING")
    PlaySoundKey("shuffle")

    _timerGuard:After(0.5, function()
        if not E.gameState then return end
        Logic:StartRound(E.gameState)
        E:_SetState("PLAYING")
        local R = ArcadiaNexus.TC_Renderer
        if R and R.OnGameStarted then R:OnGameStarted(E.gameState) end
        E:_BeginTurn()
    end)
end

function E:ResumeGame()
    local S = ArcadiaNexus.TC_Settings
    local saved = S and S:LoadPausedState()
    if not saved then return end
    self:_InvalidateTimers()
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("TAVERNCARDS", E._sessionId)
    E.gameState = saved
    S:ClearPausedState()
    E:_SetState("PLAYING")
    local R = ArcadiaNexus.TC_Renderer
    if R and R.OnGameStarted then R:OnGameStarted(E.gameState) end
    E:_NotifyBoard()
    E:_BeginTurn()
end

function E:StopGame()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("TAVERNCARDS", E._sessionId)
        E._sessionId = nil
    end
    self:StopMatchQuiet()
    self:_InvalidateTimers()
    self.mode = "hotseat"

    local gs = E.gameState
    local S = ArcadiaNexus.TC_Settings
    if gs and S and E.state ~= "IDLE" and not gs._gameOverFired and (gs.roundsPlayed or 0) > 0 then
        local Logic = ArcadiaNexus.TC_Logic
        local result, score = Logic:CalcGameResult(gs)
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId = "TAVERNCARDS", difficulty = gs.difficulty,
            score = 0, result = result,
            stats = gs.stats,
        })
        S:RecordGameResult(result, gs)
    end
    if S then S:ClearPausedState() end
    local R = ArcadiaNexus.TC_Renderer
    if R and R.OnGameStopped then R:OnGameStopped() end
    E.gameState = nil
    E:_SetState("IDLE")
end

function E:SaveAndPause()
    if self.mode ~= "hotseat" then
        self:HideView()
        return
    end
    local gs = E.gameState
    local S = ArcadiaNexus.TC_Settings
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("TAVERNCARDS", E._sessionId)
    end
    self:_InvalidateTimers()
    if gs and (E.state == "PLAYING" or E.state == "DEALING") then
        if S then S:SavePausedState(gs) end
    end
    E.gameState = nil
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame("TAVERNCARDS", E._sessionId)
        E._sessionId = nil
    end
    E:_SetState("IDLE")
end

function E:NewRound()
    if not E.gameState then return end
    local Logic = ArcadiaNexus.TC_Logic
    E:_SetState("DEALING")
    _timerGuard:After(0.4, function()
        if not E.gameState then return end
        Logic:StartRound(E.gameState)
        E:_SetState("PLAYING")
        E:_NotifyBoard()
        E:_BeginTurn()
    end)
end

function E:_BeginTurn()
    local gs = E.gameState
    if not gs or E.state ~= "PLAYING" then return end
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[gs.currentPlayer]

    if gs.forceDrawPlayer then
        local victim = gs.forceDrawPlayer
        self:_DrawPenaltyCards(gs.pendingDraw or 4, victim)
        gs.forceDrawPlayer = nil
        gs.pendingDraw = 0
        gs.pendingType = nil
        if victim == gs.currentPlayer then
            self:_AdvanceTurn()
            return
        end
    end

    if gs.wild4Challengable and gs.currentPlayer ~= gs.wild4PlayedBy then
        if player.isAI then
            _timerGuard:After(ArcadiaNexus.TC_AI:GetDelay(gs.difficulty, "think"), function()
                if not E.gameState then return end
                if ArcadiaNexus.TC_AI:ShouldChallengeWild4(gs) then
                    local g2 = E.gameState
                    E:_ResolveChallenge(ArcadiaNexus.TC_Rules:PlayerHadPlayableBeforeWild4(g2, g2.wild4PlayedBy))
                else
                    gs.wild4Challengable = false
                    E:_HandlePendingDrawStart()
                end
            end)
        else
            E:_NotifyBoard()
        end
        return
    end

    E:_HandlePendingDrawStart()
end

function E:_HandlePendingDrawStart()
    local gs = E.gameState
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[gs.currentPlayer]

    if gs.pendingDraw and gs.pendingDraw > 0 and gs.pendingType ~= "PENALTY" then
        if Rules:HasPlayableCard(player.hand, gs) then
            if player.isAI then
                E:_RunAITurn()
            else
                E:_NotifyBoard()
            end
            return
        end
        self:_DrawPenaltyCards(gs.pendingDraw)
        gs.pendingDraw = 0
        gs.pendingType = nil
        self:_AdvanceTurn()
        return
    end

    if player.isAI then
        E:_RunAITurn()
    else
        E:_NotifyBoard()
    end
end

function E:_RunAITurn()
    local gs = E.gameState
    if not gs then return end
    local AI = ArcadiaNexus.TC_AI
    local delay = AI:GetDelay(gs.difficulty, "think")

    _timerGuard:After(delay, function()
        if not E.gameState or E.state ~= "PLAYING" then return end
        local action = AI:ChooseAction(gs, gs.currentPlayer)
        if action.action == "play" then
            E:_ExecutePlay(gs.currentPlayer, action.handIndex, action.wildColor)
        elseif action.action == "draw_penalty" then
            E:_DrawPenaltyCards(gs.pendingDraw)
            gs.pendingDraw = 0
            gs.pendingType = nil
            E:_AdvanceTurn()
        elseif action.action == "challenge" then
            E:_ResolveChallenge(ArcadiaNexus.TC_Rules:PlayerHadPlayableBeforeWild4(gs, gs.wild4PlayedBy))
        elseif action.action == "accept_draw" then
            gs.wild4Challengable = false
            E:_HandlePendingDrawStart()
        else
            E:PlayerDraw(true)
        end
    end)
end

function E:PlayerDraw(fromAI)
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("DRAW", {})
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or E.state ~= "PLAYING" then return end
    if not fromAI and gs.players[gs.currentPlayer].isAI then return end
    if gs.pendingColorPick or gs.unoWindow then return end
    if not fromAI and (gs.hasDrawnThisTurn or gs.drawnThisTurn) then return end

    local Logic = ArcadiaNexus.TC_Logic
    if not fromAI then gs.hasDrawnThisTurn = true end
    local drawn = Logic:DrawCardsForPlayer(gs, gs.currentPlayer, 1)
    if #drawn == 0 then
        self:_AdvanceTurn()
        return
    end
    PlaySoundKey("draw")
    gs.drawnThisTurn = drawn[1]

    local function afterDraw()
        if not E.gameState then return end
        local g2 = E.gameState
        if g2.rules.playDrawn and ArcadiaNexus.TC_Rules:CanPlay(drawn[1], g2) and not fromAI then
            E:_NotifyBoard()
            return
        end
        if fromAI and g2.rules.playDrawn and ArcadiaNexus.TC_Rules:CanPlay(drawn[1], g2) then
            for i, c in ipairs(g2.players[g2.currentPlayer].hand) do
                if c.id == drawn[1].id then
                    E:_ExecutePlay(g2.currentPlayer, i, ArcadiaNexus.TC_AI:PickWildColor(g2.players[g2.currentPlayer].hand))
                    return
                end
            end
        end
        g2.drawnThisTurn = nil
        E:_AdvanceTurn()
    end

    if not fromAI then
        local R = ArcadiaNexus.TC_Renderer
        if R and R.ShowDrawnCard then
            R:ShowDrawnCard(drawn[1], gs.theme, afterDraw)
            return
        end
    end
    afterDraw()
end

function E:PlayerPlayCard(handIndex, wildColor)
    if E.mode ~= "hotseat" and E.match then
        local extra = { i = handIndex }
        if wildColor then extra.c = wildColor end
        E.match:SendIntent("PLAY", extra)
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or E.state ~= "PLAYING" then return end
    if gs.players[gs.currentPlayer].isAI then return end
    if gs.pendingColorPick or gs.unoWindow then return end
    self:_ExecutePlay(gs.currentPlayer, handIndex, wildColor)
end

function E:PlayerPassAfterDraw()
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("PASS", {})
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or not gs.drawnThisTurn then return end
    gs.drawnThisTurn = nil
    self:_AdvanceTurn()
end

function E:_ExecutePlay(playerIndex, handIndex, wildColor)
    local gs = E.gameState
    local Logic = ArcadiaNexus.TC_Logic
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[playerIndex]
    local card = player.hand[handIndex]
    if not card or not Rules:CanPlay(card, gs) then return end

    if card.type == "WILD4" then
        gs.wild4Context = {
            playerIndex = playerIndex,
            handSnapshot = {},
            activeColorBefore = Rules:GetActiveColor(gs),
            topCard = Rules:GetTopCard(gs),
        }
        for _, c in ipairs(player.hand) do
            gs.wild4Context.handSnapshot[#gs.wild4Context.handSnapshot + 1] = c
        end
    end

    local played = Logic:RemoveCardFromHand(player, handIndex)
    Logic:AddToDiscard(gs, played)
    PlaySoundKey(played.type == "WILD" or played.type == "WILD4" and "wild" or "play")
    gs.drawnThisTurn = nil

    if Rules:IsWildType(played) and not wildColor and not player.isAI then
        gs.pendingColorPick = { playerIndex = playerIndex, card = played }
        E:_NotifyBoard()
        return
    end
    if Rules:IsWildType(played) and not wildColor and player.isAI then
        wildColor = ArcadiaNexus.TC_AI:PickWildColor(player.hand)
    end
    Rules:ApplyCardEffect(gs, played, wildColor)
    gs.pendingColorPick = nil

    local winner = Logic:CheckRoundWinner(gs)
    if winner then
        self:_EndRound(winner)
        return
    end

    if #player.hand == 1 and gs.rules.unoCallRule then
        if player.isAI then
            player.unoCalled = true
            gs.stats.unosCalled = (gs.stats.unosCalled or 0) + 1
            PlaySoundKey("uno")
            E:_FinishPlayTurn(playerIndex, played)
        else
            E:_AfterPlayVisual(playerIndex, played, function()
                E:_ScheduleUnoWindow(playerIndex)
            end)
        end
        return
    end

    E:_FinishPlayTurn(playerIndex, played)
end

function E:PlayerPickColor(color)
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("COLOR", { c = color })
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or not gs.pendingColorPick then return end
    local pick = gs.pendingColorPick
    local Rules = ArcadiaNexus.TC_Rules
    Rules:ApplyCardEffect(gs, pick.card, color)
    gs.pendingColorPick = nil
    gs.currentPlayer = pick.playerIndex

    local winner = ArcadiaNexus.TC_Logic:CheckRoundWinner(gs)
    if winner then
        self:_EndRound(winner)
        return
    end
    local pi = gs.currentPlayer
    if #gs.players[pi].hand == 1 and gs.rules.unoCallRule then
        E:_AfterPlayVisual(pi, pick.card, function()
            E:_ScheduleUnoWindow(pi)
        end)
        return
    end
    E:_FinishPlayTurn(pi, pick.card)
end

function E:PlayerCallUno()
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("UNO", {})
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or not gs.unoWindow or gs.unoWindow.resolved then return end
    if gs.unoWindow.playerIndex ~= 1 then return end
    gs.players[1].unoCalled = true
    gs.stats.unosCalled = (gs.stats.unosCalled or 0) + 1
    PlaySoundKey("uno")
    E:_ResolveUnoWindow(true)
    E:_NotifyBoard()
end

function E:PlayerCatchUno()
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("CATCH", {})
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs or not gs.unoWindow or gs.unoWindow.resolved then return end
    local target = gs.unoWindow.playerIndex
    if gs.players[target].unoCalled then return end
    gs.stats.unosMissed = (gs.stats.unosMissed or 0) + 1
    gs.stats.unosCaught = (gs.stats.unosCaught or 0) + 1
    ArcadiaNexus.TC_Logic:DrawCardsForPlayer(gs, target, 2)
    PlaySoundKey("penalty")
    E:_ResolveUnoWindow(true)
    E:_NotifyBoard()
end

function E:PlayerChallengeWild4()
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("CHALLENGE", {})
        E:_NotifyBoard()
        return
    end
    self:_ResolveChallenge(ArcadiaNexus.TC_Rules:PlayerHadPlayableBeforeWild4(E.gameState, E.gameState.wild4PlayedBy))
end

function E:PlayerAcceptWild4()
    if E.mode ~= "hotseat" and E.match then
        E.match:SendIntent("ACCEPT", {})
        E:_NotifyBoard()
        return
    end
    local gs = E.gameState
    if not gs then return end
    gs.wild4Challengable = false
    E:_HandlePendingDrawStart()
end

function E:_ResolveChallenge(challengerWins)
    ArcadiaNexus.TC_Rules:ResolveChallenge(E.gameState, challengerWins)
    E.gameState.wild4Challengable = false
    E:_BeginTurn()
end

function E:_DrawPenaltyCards(n, playerIndex)
    local gs = E.gameState
    ArcadiaNexus.TC_Logic:DrawCardsForPlayer(gs, playerIndex or gs.currentPlayer, n)
    PlaySoundKey("draw")
    E:_NotifyBoard()
end

function E:_AdvanceTurn()
    local gs = E.gameState
    if not gs then return end
    gs.turnNotice = nil
    gs.drawnThisTurn = nil
    gs.hasDrawnThisTurn = false
    local Rules = ArcadiaNexus.TC_Rules
    local steps = 1 + (gs.skipNext or 0)
    gs.skipNext = 0
    gs.currentPlayer = Rules:NextPlayerIndex(gs, steps)
    E:_BeginTurn()
end

function E:_EndRound(winnerIndex)
    local gs = E.gameState
    local Logic = ArcadiaNexus.TC_Logic
    local roundPts, winner = Logic:ScoreRound(gs, winnerIndex)
    gs.lastRoundWinner = winnerIndex
    PlaySoundKey(winnerIndex == 1 and "win" or "lose")

    local gameWinner = Logic:CheckGameWinner(gs)
    if gs.gameMode == "single" or gameWinner then
        gs._gameOverFired = true
        E:_SetState("ROUND_END")
        local R = ArcadiaNexus.TC_Renderer
        if R and R.ShowGameEnd then
            R:ShowGameEnd(gs, winnerIndex, roundPts, gameWinner or winnerIndex)
        end
        if gameWinner or gs.gameMode == "single" then
            local result = (winnerIndex == 1 or gameWinner == 1) and "WIN" or "LOSS"
            ArcadiaNexus.Engine:Emit("GAME_RESULT", {
                gameId = "TAVERNCARDS", difficulty = gs.difficulty,
                score = 0, result = result, stats = gs.stats,
            })
            local S = ArcadiaNexus.TC_Settings
            if S then S:RecordGameResult(result, gs) end
        end
    else
        E:_SetState("ROUND_END")
        local R = ArcadiaNexus.TC_Renderer
        if R and R.ShowRoundResult then
            R:ShowRoundResult(gs, winnerIndex, roundPts)
        end
    end
end
