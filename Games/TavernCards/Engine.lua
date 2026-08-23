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
end

function E:_SetState(newState)
    E.state = newState
    local R = ArcadiaNexus.TC_Renderer
    if R and R.OnStateChanged then R:OnStateChanged(newState) end
end

function E:_NotifyBoard()
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

function E:StartGame(config)
    self:_InvalidateTimers()
    local S = ArcadiaNexus.TC_Settings
    if S then S:ClearPausedState() end
    local cfg = self:_BuildConfig(config or {})
    if cfg.aiCount < 1 or cfg.aiCount > 3 then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame("TAVERNCARDS", E._sessionId)
    local Logic = ArcadiaNexus.TC_Logic
    E.gameState = Logic:NewGameState(cfg)
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
    self:_InvalidateTimers()

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

    if gs.forceDrawPlayer and gs.forceDrawPlayer == gs.currentPlayer then
        self:_DrawPenaltyCards(gs.pendingDraw or 4)
        gs.forceDrawPlayer = nil
        gs.pendingDraw = 0
        gs.pendingType = nil
        self:_AdvanceTurn()
        return
    end

    if gs.wild4Challengable and gs.currentPlayer ~= gs.wild4PlayedBy then
        if player.isAI then
            _timerGuard:After(ArcadiaNexus.TC_AI:GetDelay(gs.difficulty, "think"), function()
                if not E.gameState then return end
                if ArcadiaNexus.TC_AI:ShouldChallengeWild4(gs) then
                    E:_ResolveChallenge(true)
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
    local gs = E.gameState
    if not gs or E.state ~= "PLAYING" then return end
    if gs.players[gs.currentPlayer].isAI then return end
    if gs.pendingColorPick or gs.unoWindow then return end
    self:_ExecutePlay(gs.currentPlayer, handIndex, wildColor)
end

function E:PlayerPassAfterDraw()
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
    self:_ResolveChallenge(ArcadiaNexus.TC_Rules:PlayerHadPlayableBeforeWild4(E.gameState, E.gameState.wild4PlayedBy))
end

function E:PlayerAcceptWild4()
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

function E:_DrawPenaltyCards(n)
    ArcadiaNexus.TC_Logic:DrawCardsForPlayer(E.gameState, E.gameState.currentPlayer, n)
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
