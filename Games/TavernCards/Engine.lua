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
    if self._resultEmitted then return true end
    if self.match ~= node or not self._sessionId or node:GetState() ~= "FINISHED" then return end
    local board = self:GetBoardState()
    local result = (board and board.result) or "LOSS"
    local payload = {
        gameId = "TAVERNCARDS",
        resultId = resultId,
        matchHost = node.hostKey,
        difficulty = "match",
        score = 0,
        result = result,
        stats = (function() local st=board and board.stats or {}; st.vsHuman=1; return st end)(),
    }
    ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
    if payload.matchBooked ~= true then return false end
    self._resultEmitted = true
    local R = ArcadiaNexus.TC_Renderer
    if R and R.ShowMatchResult then
        R:ShowMatchResult(result, board)
    end
    return true
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

function E:CanContinueSave(gs)
    if not ArcadiaNexus.TC_Logic:ValidateSave(gs) or gs.phase=="FINISHED" then return false end
    local LR=ArcadiaNexus.LocalResults; local serial=LR:GetSerial("TAVERNCARDS",gs.runId)
    if not serial then return false end
    local j,r=LR:GetJournal(),LR:GetReceipt(gs.runId)
    if not r and not j.issued[gs.runId] and serial<=j.retiredThrough then return false end
    if r and (gs.phase~="RESULT_PENDING" or r.result~=gs.result or r.difficulty~="solo_"..gs.difficulty) then return false end
    if r then
        if r.roundsPlayed~=gs.roundsPlayed or r.gameMode~=gs.gameMode then return false end
        local own=ArcadiaNexus.TC_Logic:PersonalStats(gs,1)
        for _,key in ipairs({"unosCalled","unosMissed","unosCaught","wild4Played"}) do
            if (r.personalStats and r.personalStats[key] or 0)~=(own[key] or 0) then return false end
        end
    end
    return true
end
function E:_Save()
    if self.mode=="hotseat" and self.gameState then ArcadiaNexus.TC_Settings:SaveGame(self.gameState) end
end
function E:StartGame(config)
    config=config or {}; local mode=config.mode or "new"
    if mode=="host" or mode=="join" or mode=="rejoin" then
        local M=ArcadiaNexus.Match
        if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() or not M or not M.BeginNetworkedGame then self._notice="nomp"; return false end
        M.BeginNetworkedGame(self,"TAVERNCARDS",config,function() self:_NotifyBoard() end,MatchOpts,{
            onBefore=function() self:_InvalidateTimers(); self.gameState=nil
                self._mpChar=config.playerCharacter or (ArcadiaNexus.TC_Settings and ArcadiaNexus.TC_Settings:Get("playerCharacter")) or "thrall" end,
        }); return self.match~=nil
    end
    if self.gameState then return false end
    local S,Logic=ArcadiaNexus.TC_Settings,ArcadiaNexus.TC_Logic
    local slot=config.slot or S:GetActiveSlot(); if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>3 then return false end
    local gs
    if mode=="continue" then
        local saved=S:LoadSlot(slot); if not self:CanContinueSave(saved) then return false end
        gs=Logic:CloneGameState(saved)
    else
        if S:LoadSlot(slot) and not config.overwrite then return false end
        local cfg=self:_BuildConfig(config)
        if not Logic:IsDifficulty(cfg.difficulty) or type(cfg.aiCount)~="number" or cfg.aiCount~=math.floor(cfg.aiCount) or cfg.aiCount<1 or cfg.aiCount>3
            or cfg.gameMode~="single" and cfg.gameMode~="multi" then return false end
        cfg.pointTarget=500
        gs=Logic:NewGameState(cfg); Logic:StartRound(gs)
        gs.saveVersion=2; gs.phase="PLAYING"
    end
    if self.match and not self.match._closed then return false end
    local sid=ArcadiaNexus.Lifecycle:ClaimRestart("TAVERNCARDS",self._sessionId)
    if not sid then return false end
    if mode~="continue" then gs.runId=ArcadiaNexus.LocalResults:NewRun("TAVERNCARDS") end
    self:StopMatchQuiet(); self:_InvalidateTimers(); self.mode="hotseat"; self._resultEmitted=false; self._lastResult=nil
    self.gameState,self.activeSlot=gs,slot; S:SetActiveSlot(slot)
    self._sessionId=sid
    self:_SetState(gs.phase); self:_Save()
    local R=ArcadiaNexus.TC_Renderer; if R and R.OnGameStarted then R:OnGameStarted(gs) end
    self:_NotifyBoard()
    if gs.phase=="RESULT_PENDING" then self:RetryResult()
    elseif gs.phase=="ROUND_END" then if R and R.ShowRoundResult then R:ShowRoundResult(gs,gs.lastRoundWinner,gs.lastRoundPoints) end
    elseif mode=="continue" then self:_Drive()
    else
        self:_SetState("DEALING"); local sid=self._sessionId
        _timerGuard:After(0.5,function() if not ArcadiaNexus.GameSession:IsSession(E,sid) or E.gameState~=gs then return end; E:_SetState("PLAYING"); E:_Drive() end)
    end
    return true
end
function E:ResumeGame(slot) return self:StartGame({mode="continue",slot=slot}) end
function E:SaveAndPause()
    if self.mode~="hotseat" then self:HideView(); return true end
    local gs=self.gameState
    if gs and gs.unoWindow and self._unoDeadline then gs.unoWindow.remainingMs=math.max(0,math.floor((self._unoDeadline-GetTime())*1000)) end
    self:_InvalidateTimers(); self._unoDeadline=nil; self:_Save()
    if self._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame("TAVERNCARDS",self._sessionId)
        ArcadiaNexus.Lifecycle:EndGame("TAVERNCARDS",self._sessionId); self._sessionId=nil
    end
    self.gameState,self.activeSlot=nil,nil; self:_SetState("IDLE")
    local R=ArcadiaNexus.TC_Renderer; if R and R.OnGameStopped then R:OnGameStopped() end
    return true
end
function E:StopGame()
    if self.mode=="hotseat" then return self:SaveAndPause() end
    if self._sessionId then ArcadiaNexus.Lifecycle:EndGame("TAVERNCARDS",self._sessionId); self._sessionId=nil end
    self:StopMatchQuiet(); self:_InvalidateTimers(); self.mode="hotseat"; self.gameState=nil; self:_SetState("IDLE")
    local R=ArcadiaNexus.TC_Renderer; if R and R.OnGameStopped then R:OnGameStopped() end
end
function E:NewRound()
    local gs=self.gameState
    if not gs or gs.phase~="ROUND_END" or gs.gameMode~="multi" then return false end
    self:_InvalidateTimers(); ArcadiaNexus.TC_Logic:StartRound(gs); gs.phase="PLAYING"; self:_Save(); self:_SetState("DEALING"); self:_NotifyBoard()
    local sid=self._sessionId
    _timerGuard:After(0.4,function() if not ArcadiaNexus.GameSession:IsSession(E,sid) or E.gameState~=gs then return end; E:_SetState("PLAYING"); E:_Drive() end)
    return true
end
function E:_Action(kind,extra,seat)
    if self.mode~="hotseat" and self.match then self.match:SendIntent(kind,extra or {}); self:_NotifyBoard(); return true end
    local gs=self.gameState
    if not gs or self.state~="PLAYING" or not ArcadiaNexus.GameSession:IsSession(self,self._sessionId) then return false end
    local playedCard=kind=="PLAY" and gs.players[seat or 1].hand[extra and extra.i]
    local intent=extra or {}; intent.kind=kind
    if not ArcadiaNexus.TC_Logic.ApplyAction(gs,intent,seat or 1) then return false end
    self:_InvalidateTimers(); self._unoDeadline=nil
    PlaySoundKey(kind=="PLAY" and (ArcadiaNexus.TC_Rules:IsWildType(playedCard) and "wild" or "play") or kind=="DRAW" and "draw" or kind=="UNO" and "uno" or "wild")
    self:_Drive(); return true
end
function E:_Drive()
    local gs=self.gameState; if not gs or self.state~="PLAYING" then return end
    if gs.roundOver then return self:_EndRound(gs.lastRoundWinner) end
    self:_Save(); self:_NotifyBoard()
    local Logic,AI=ArcadiaNexus.TC_Logic,ArcadiaNexus.TC_AI
    local sid=self._sessionId; local uw=gs.unoWindow
    if uw then
        if gs.players[uw.playerIndex].isAI then return self:_Action("UNO",{},uw.playerIndex) end
        self._unoDeadline=GetTime()+(uw.remainingMs or 3000)/1000
        _timerGuard:After((uw.remainingMs or 3000)/1000,function()
            if not ArcadiaNexus.GameSession:IsSession(E,sid) or E.gameState~=gs or gs.unoWindow~=uw then return end
            local catcher=ArcadiaNexus.TC_Rules:NextPlayerIndex(gs,1)
            local caught=AI:ShouldCatchUno(gs); E:_Action(caught and "CATCH" or "UNO_EXPIRE",{},caught and catcher or 1)
        end); return
    end
    if gs.pendingColorPick then return end
    local seat=gs.currentPlayer; local p=gs.players[seat]
    if p.isAI then
        _timerGuard:After(AI:GetDelay(gs.difficulty,"think"),function()
            if not ArcadiaNexus.GameSession:IsSession(E,sid) or E.gameState~=gs or gs.currentPlayer~=seat or E.state~="PLAYING" then return end
            if gs.drawnThisTurn then
                for index,c in ipairs(p.hand) do if c.id==gs.drawnThisTurn.id then E:_Action("PLAY",{i=index,c=AI:PickWildColor(p.hand)},seat); return end end
                E:_Action("PASS",{},seat); return
            end
            local action=AI:ChooseAction(gs,seat)
            local kinds={play="PLAY",draw_penalty="DRAW",challenge="CHALLENGE",accept_draw="ACCEPT",draw="DRAW"}
            E:_Action(kinds[action.action] or "DRAW",{i=action.handIndex,c=action.wildColor},seat)
        end)
    end
end
function E:_BeginTurn() ArcadiaNexus.TC_Logic.MpBeginTurn(self.gameState); self:_Drive() end
function E:PlayerDraw(fromAI) return self:_Action("DRAW",{},fromAI and self.gameState.currentPlayer or 1) end
function E:PlayerPlayCard(index,color) return self:_Action("PLAY",{i=index,c=color}) end
function E:PlayerPassAfterDraw() return self:_Action("PASS") end
function E:PlayerPickColor(color) return self:_Action("COLOR",{c=color}) end
function E:PlayerCallUno() return self:_Action("UNO") end
function E:PlayerCatchUno() return self:_Action("CATCH") end
function E:PlayerChallengeWild4() return self:_Action("CHALLENGE") end
function E:PlayerAcceptWild4() return self:_Action("ACCEPT") end
function E:_ExecutePlay(seat,index,color) return self:_Action("PLAY",{i=index,c=color},seat) end
function E:RequestForfeit()
    if self.mode~="hotseat" or not self.gameState or self.gameState.phase=="FINISHED" or self.gameState.phase=="RESULT_PENDING" then return false end
    local R=ArcadiaNexus.TC_Renderer; if R and R.ConfirmForfeit then R:ConfirmForfeit(self._sessionId,self.gameState.runId) end; return true
end
function E:ConfirmForfeit(sid,runId)
    local gs=self.gameState
    if not gs or not ArcadiaNexus.GameSession:IsSession(self,sid) or self._sessionId~=sid or gs.runId~=runId or gs.phase=="FINISHED" or gs.phase=="RESULT_PENDING" then return false end
    self:_InvalidateTimers(); gs.forfeited=true; gs.result="LOSS"; gs.phase="RESULT_PENDING"; self:_SetState("RESULT_PENDING"); self:_Save(); return self:RetryResult()
end
function E:_EndRound(winner)
    local gs=self.gameState; local gameWinner=ArcadiaNexus.TC_Logic:CheckGameWinner(gs)
    self:_InvalidateTimers()
    if gs.gameMode=="single" or gameWinner then
        gs.result=(gameWinner or winner)==1 and "WIN" or "LOSS"; gs.phase="RESULT_PENDING"; self:_SetState("RESULT_PENDING"); self:_Save(); return self:RetryResult()
    end
    gs.phase="ROUND_END"; self:_SetState("ROUND_END"); self:_Save()
    local R=ArcadiaNexus.TC_Renderer; if R and R.ShowRoundResult then R:ShowRoundResult(gs,winner,gs.lastRoundPoints) end
end
function E:RetryResult()
    local gs=self.gameState; if not gs or gs.phase~="RESULT_PENDING" then return false end
    local data={gameId="TAVERNCARDS",difficulty="solo_"..gs.difficulty,score=0,result=gs.result,runId=gs.runId,
        stats=ArcadiaNexus.TC_Logic:PersonalStats(gs,1),roundsPlayed=gs.roundsPlayed,gameMode=gs.gameMode,skipHighscores=true}
    ArcadiaNexus.Engine:Emit("GAME_RESULT",data)
    if not data.processed then self:_Save(); local R=ArcadiaNexus.TC_Renderer; if R and R.ShowResultPending then R:ShowResultPending() end; return false end
    self._lastResult=data; gs.phase="FINISHED"; gs._gameOverFired=true; self:_SetState("FINISHED"); self:_Save()
    PlaySoundKey(gs.result=="WIN" and "win" or "lose")
    local R=ArcadiaNexus.TC_Renderer
    if R and R.ShowGameEnd then R:ShowGameEnd(gs,gs.lastRoundWinner or (gs.result=="WIN" and 1 or 2),gs.lastRoundPoints or 0,gs.result=="WIN" and 1 or 2) end
    return true
end
