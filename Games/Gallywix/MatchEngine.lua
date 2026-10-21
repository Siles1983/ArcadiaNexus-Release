-- Optional MATCH consumer. Solo methods retain their existing timelines.
local A=ArcadiaNexus
local E=A.GWX_Engine
E.mode="hotseat"
local loop=A.GameLoop.Create("ArcadiaNexus_GWX_MatchLoop")
local function networked() return E.mode~="hotseat" and E.match~=nil end
local function notify()
    local R=A.GWX_Renderer
    if E.gameState and R and R.frame then E:_Present("RenderGame",E.gameState) end
    if networked() and A.Match.NotifyGameView then A.Match.NotifyGameView(E,"GALLYWIX") end
end
local originalStart,originalStop=E.StartGame,E.StopGame
function E:StopGame()
    local wasMatch=networked()
    local stopped = originalStop(self)
    if stopped == false then return false end
    loop:Stop()
    self._mpStageKey,self._mpPuzzle,self._mpPuzzleKey,self._mpEvent,self._mpEventKey=nil,nil,nil,nil,nil
    if self.match and A.Match then A.Match.StopEngineMatch(self) end
    self.mode="hotseat"; self._mpRoster=nil
    if wasMatch and A.Match then A.Match.PresentGameView("GALLYWIX",self:GetView()) end
    return stopped
end
function E:StartGame(config)
    config=config or {}
    local mode=config.mode or "hotseat"
    if mode~="host" and mode~="join" and mode~="rejoin" then return originalStart(self,config) end
    if not A.HasMultiplayer or not A.HasMultiplayer() then self._notice="nomp"; return false end
    local settled=self.match and A.Match and A.Match.ClientSettled and A.Match.ClientSettled(self.match)
    if networked() and not settled then return false end
    if not settled and self:StopGame()==false then return false end
    A.Match.BeginNetworkedGame(self,"GALLYWIX",config,notify,A.GWX_Match.Options,{
        onHosted=function(_,node)
            local pub=node.publicState
            pub.category=A.GWX_Renderer.category or "all"
            pub.locale=A.ActiveLocale=="deDE" and "deDE" or "enUS"
            pub.gallywix=A.GWX_Settings:Get("gallywixEnabled")==true
            pub.bot="none"
            node:LobbyChanged()
        end})
    return self.state~="IDLE"
end
function E:SetReady(ready)
    if networked() then A.Match.SetEngineReady(self,ready); notify() end
end
function E:TryStartMatch()
    if not A.HasMultiplayer or not A.HasMultiplayer() then return false end
    if networked() then A.Match.TryEngineStart(self); notify() end
end
function E:SetLobbyOption(key,value)
    local node=self.match
    if not networked() or not node.isHost or self.state~="LOBBY" or key~="bot" then return false end
    if value~="none" and value~="Gazlowe" and value~="Rexxar" then return false end
    local count=0; for i=1,3 do if node.seats[i] then count=count+1 end end
    if count>=3 then return false end
    if node.publicState.bot==value then return true end
    node.publicState.bot=value
    for i=1,3 do node.ready[i]=false end
    node:LobbyChanged(); notify(); return true
end
function E:GetView()
    local node=self.match; local players={}
    -- Join is asynchronous: the client exists before WELCOME/LOBBY provides
    -- publicState. The waiting lobby must also be renderable in that interval.
    local pub=node and node.publicState
    if node then
        for i=1,3 do
            local key=node.seats[i]
            if key then players[#players+1]={key=key,name=key:match("^([^-]+)"),ready=node.ready[i]==true,self=i==node.seat} end
        end
    end
    return {state=self.state,mode=self.mode,mp=networked(),isHost=node and node.isHost,
        notice=self._notice,pub=pub,lobbyPlayers=players,seat=node and node.seat,
        lobbyOption={key="bot",labelKey="match_col_ai",value=pub and pub.bot or "none",
            options={{key="Gazlowe",label="Gazlowe"},{key="Rexxar",label="Rexxar"},{key="none",labelKey="match_ai_none"}},
            enabled=#players==2},matchState=node and node:GetState()}
end
function E:HideView() if networked() then A.Match.HideEngineView(self) end end
function E:OnMatchState(state)
    A.Match.HandleGameState(self,"GALLYWIX",state,{onAborted=function()
        loop:Stop()
        local stopped=originalStop(self)
        if stopped==false then return false end
        self.mode="hotseat"
        return stopped
    end})
    if state=="PLAYING" then
        self:OnMatchPublic()
        local sid=self._sessionId
        loop:Start(function(dt) E:_TickMatch(dt) end,{stateCheck=function()
            return networked() and E.state=="PLAYING" and A.GameSession:IsSession(E,sid)
        end})
    elseif state=="FINISHED" then loop:Stop() end
    if state=="ABORTED" then A.Match.PresentGameView("GALLYWIX",self:GetView()) end
    notify()
end
function E:OnMatchReject(fields) A.Match.HandleGameReject(self,"GALLYWIX",fields); notify() end
function E:OnMatchPublic()
    local node=self.match
    if not node then return end
    if self.state=="LOBBY" and node.isHost then
        local keys={}; local count=0
        for i=1,3 do keys[i]=node.seats[i] or ""; if node.seats[i] then count=count+1 end end
        local roster=table.concat(keys,",")
        if self._mpRoster~=roster then
            self._mpRoster=roster
            for i=1,3 do node.ready[i]=false end
            if count==3 then node.publicState.bot="none" end
            node:LobbyChanged()
        end
    end
    A.Match.HandleGamePublic(self)
    local pub=node.publicState
    local board=A.GWX_Match.Board(pub,node.seat or 1)
    if board then
        local puzzleKey=tostring(pub.round)..":"..pub.category
        if self._mpPuzzleKey==puzzleKey and self._mpPuzzle then
            for key,value in pairs(board.puzzle) do self._mpPuzzle[key]=value end
            board.puzzle=self._mpPuzzle
        else self._mpPuzzleKey=puzzleKey; self._mpPuzzle=board.puzzle end
        local accounts={}
        for i,p in ipairs(pub.players) do accounts[i]=p.bank..","..p.total..","..p.extra end
        local eventKey=table.concat({pub.round,pub.active,pub.spinId or 0,pub.mask,
            board.event.kind,board.event.letter or "",board.event.amount or 0,table.concat(accounts,";")},":")
        if self._mpEventKey==eventKey then board.event=self._mpEvent else self._mpEventKey=eventKey; self._mpEvent=board.event end
        self.gameState=board
        self:_PresentMatchStage(pub)
    end
    notify()
end
function E:_PresentMatchStage(pub)
    self._mpElapsed=pub.elapsed or 0
    local R=A.GWX_Renderer
    if not R or not R.frame then return end
    local key=tostring(pub.spinId or 0)..":"..pub.stage..":"..pub.round
    if self._mpStageKey==key then return end
    local restoring=self._mpStageKey==nil
    self._mpStageKey=key
    if pub.stage==2 or pub.stage==8 then A.GWX_Sounds:StartWheel()
    else A.GWX_Sounds:StopWheel(pub.stage==3 or pub.stage==9) end
    R:SetGallywixVisible(pub.stage==7 or pub.stage==8 or pub.stage==9)
    R:SetGallywixDancing(pub.stage==8)
    self._intervention=pub.stage>=5 and pub.stage<=9 and {} or nil
    if pub.stage==1 then R:BeginWheelMotion("expand")
    elseif pub.stage==4 then
        if restoring then R:BeginWheelMotion("expand"); R:AnimateWheel(1) end
        R:BeginWheelMotion("dock")
    elseif pub.stage==6 and self._mpElapsed<0.5 then self._laughHandle=R:PlayGallywixLaugh(false)
    elseif pub.stage==0 then
        self.rotationDegrees=pub.rotation or 0; R:SetRotation(self.rotationDegrees)
        if R._wheelSize~=R.CFG.wheel_size then R:BeginWheelMotion("dock"); R:AnimateWheel(1) end
    end
    -- Rejoining in midspin restores its large pose without restarting the spin.
    if pub.stage==2 or pub.stage==3 then R:BeginWheelMotion("expand"); R:AnimateWheel(1)
    elseif pub.stage>=5 and pub.stage<=9 then R:BeginWheelMotion("dock"); R:AnimateWheel(1) end
    if pub.stage==3 or pub.stage==4 or pub.stage==5 or pub.stage==6 or pub.stage==7 then
        self.rotationDegrees=A.GWX_Logic:GetTargetDegrees(pub.first); R:SetRotation(self.rotationDegrees)
    elseif pub.stage==9 then
        self.rotationDegrees=A.GWX_Logic:GetTargetDegrees(pub.final); R:SetRotation(self.rotationDegrees)
    end
end
function E:_TickMatch(dt)
    local node=self.match
    if not node then return end
    local pub=node.publicState; if not pub or not pub.mask then return end
    local R=A.GWX_Renderer; local stage=pub.stage
    self._mpElapsed=(self._mpElapsed or pub.elapsed or 0)+dt
    if node.isHost then pub.elapsed=self._mpElapsed end
    if R and R.frame then
        local duration=A.GWX_Match.Durations[stage] or 1
        local progress=math.min(1,self._mpElapsed/duration)
        if stage==1 or stage==4 then R:AnimateWheel(progress)
        elseif stage==2 or stage==8 then
            local target=stage==2 and pub.first or pub.final
            local start=stage==2 and (pub.rotation or 0) or A.GWX_Logic:GetTargetDegrees(pub.first)
            self.rotationDegrees=(start+A.GWX_Logic:GetSpinDistance(start,target,stage==2 and 5 or 2)*A.GWX_Logic:Ease(progress))%360
            R:SetRotation(self.rotationDegrees)
        elseif stage==10 then R:AnimateWall(dt) end
    end
    if node.isHost then
        if stage>0 and GetTime()>=node._hostHidden.deadline then node:SendIntent("STEP")
        elseif stage==0 and pub.active>pub.humans and pub.phase~="ROUND_END" and GetTime()>=node._hostHidden.aiAt then
            node:SendIntent("AI")
        end
    end
end
function E:OnMatchResult(node,id)
    if self._resultEmitted then return true end
    if self.match~=node or node:GetState()~="FINISHED" then return end
    local s=A.GWX_Match.Board(node.publicState,node.seat)
    if not s then return end
    self.gameState=s
    local games=A.ScoreManager and A.ScoreManager:GetAllGames() or {}
    local old=games.GALLYWIX and games.GALLYWIX[s.difficulty]
    local result=A.GWX_GameLogic:Result(s,node.seat)
    local before=A.ProfileStore and A.ProfileStore.Get().totalXP or 0
    local data={gameId="GALLYWIX",resultId=id,matchHost=node.hostKey,difficulty=s.difficulty,
        result=result,score=s.players[node.seat].total,stats=A.GWX_GameLogic:AchievementResult(s,old and old.customStats,node.seat),category=s.category,locale=s.locale,firstStarter=s.firstStarter}
    A.Engine:Emit("GAME_RESULT",data)
    if data.matchBooked ~= true then return false end
    self._resultEmitted=true
    data.awardedXP=math.max(0,(A.ProfileStore and A.ProfileStore.Get().totalXP or before)-before)
    if A.GWX_Renderer and A.GWX_Renderer.frame then self:_Present("ShowResult",s,result,data) end
    return true
end
for method,kind in pairs({Spin="spin",BuyVowel="vowel",GuessLetter="letter",Solve="solve",NextRound="next"}) do
    local original=E[method]
    E[method]=function(self,value,ai)
        if not networked() then return original(self,value,ai) end
        if self.state~="PLAYING" then return false end
        local c
        if kind=="letter" then c=value end
        if kind=="solve" then c=A.GWX_GameLogic:Normalize(value); if not c then return false end end
        return self.match:SendIntent(kind,{c=c})
    end
end
