--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Engine.lua

    State: IDLE → AIMING ⇄ FLYING → RESOLVE → AIMING
                              ↘ LEVELWIN / GAMEOVER → IDLE
    GameLoop während AIMING/FLYING/RESOLVE (Zeit + Overcharge + Flug).
    TimerGuard für Pop-/Drop-Sequenzen.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BS_Engine = {}
local E = ArcadiaNexus.BS_Engine

local GAME_ID = "BUBBLESHOOTER"

E._sessionId = nil
E.state      = "IDLE"
E.gameState  = nil
E.activeSlot = 1

local _gameLoop   = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BS_LoopFrame")
local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard = _timerGuard

local function PlayBS(event)
    local Sound = ArcadiaNexus.BS_Sound
    if Sound and Sound.Play then
        Sound.Play(event)
    end
end

function E:_StartLoop()
    _gameLoop:Start(function(dt) E:_Tick(dt) end, {
        stateCheck = function()
            return E.state == "AIMING" or E.state == "FLYING" or E.state == "RESOLVE"
        end,
    })
end

function E:_StopLoop()
    _timerGuard:Cancel()
    _gameLoop:Stop()
end

function E:_ThemeKey()
    local S = ArcadiaNexus.BS_Settings
    return (S and S:Get("theme")) or "energies"
end

function E:_Notify(fnName, ...)
    local R = ArcadiaNexus.BS_Renderer
    if R and R[fnName] then
        R[fnName](R, ...)
    end
end

function E:_ScoreDifficulty(gs)
    local Logic = ArcadiaNexus.BS_Logic
    return Logic.ScoreKey(gs.mode, gs.difficulty)
end

function E:_SaveShotProgress()
    local gs, S = self.gameState, ArcadiaNexus.BS_Settings
    if not gs or not S or gs.mode ~= "shot" then return end
    if gs.won or gs.lost then return end
    local Logic = ArcadiaNexus.BS_Logic
    if Logic and not Logic:GridHasBubbles(gs.grid) then return end
    S:SetActiveSlot(self.activeSlot)
    local previous = S:LoadSlot(self.activeSlot)
    S:SaveSlot(self.activeSlot, S:PackProgress(gs, {
        paused = true,
        stars = previous and previous.stars or {},
        levelBests = previous and previous.levelBests,
        campaignVersion = S.CAMPAIGN_VERSION,
        clearedLevel = previous and previous.clearedLevel or 0,
    }))
end

-- Seal before synchronous notifications. A failed transaction remains queued
-- outside the playable slot and can be retried without losing the result.
function E:_BookTerminal(result, reason)
    local gs,S = self.gameState,ArcadiaNexus.BS_Settings
    if not gs or gs.terminal then return end
    gs.terminal=result; gs.reason=reason
    gs.won=result=="WIN"; gs.lost=result=="LOSS"
    if (gs.shotsUsed or 0)>0 then
        local payload={gameId=GAME_ID,runId=gs.runId,ruleVersion=3,
            difficulty=self:_ScoreDifficulty(gs),aiDifficulty=gs.difficulty,playMode=gs.mode,
            slot=self.activeSlot,levelIndex=gs.levelIndex,score=gs.score or 0,result=result,
            stars=result=="WIN" and gs.mode=="shot" and ArcadiaNexus.BS_Logic:GradeCampaignStars(gs) or 0,
            reason=reason,stats={levelReached=gs.levelIndex,shotsUsed=gs.shotsUsed,
                maxCombo=gs.stats.maxCombo,maxDrop=gs.stats.maxDrop,
                powerUsed=gs.stats.powerUsed,overchargeCount=gs.stats.overchargeCount}}
        gs.resultPayload=payload; gs.lastStars=payload.stars
        S:QueueResult(payload)
        if gs.mode=="shot" then
            -- Even failed progression commits must never leave a playable
            -- pre-terminal projectile behind. The sealed payload is retryable.
            local saved=S:LoadSlot(self.activeSlot)
            if saved then saved.midGame=nil; saved.runId=nil; saved.paused=false; saved.score=0 end
        end
        S:FlushResults()
        if self.gameState~=gs then return end
        local saved=S:LoadSlot(self.activeSlot)
        gs.bestStars=saved and saved.stars and saved.stars[gs.levelIndex] or gs.lastStars
    end
    _gameLoop:Stop()
end

function E:_PresentTerminal(gs)
    if not gs or not gs.terminal or self.gameState~=gs or gs.presented then return end
    gs.presented=true
    local isNew=gs.resultPayload and gs.resultPayload.newHighscore==true
    if gs.terminal=="WIN" then
        PlayBS("win")
        if gs.mode=="shot" and gs.levelIndex<100 then
            self.state="LEVELWIN"; self:_Notify("ShowLevelWin",gs,isNew); return
        end
    else PlayBS("lose") end
    self.state="GAMEOVER"
    if self._sessionId then ArcadiaNexus.Lifecycle:EndGame(GAME_ID,self._sessionId); self._sessionId=nil end
    self:_Notify(gs.terminal=="WIN" and (gs.mode=="shot" and "ShowFinalWin" or "ShowArcadeWin") or "ShowLoss",gs,isNew)
end

function E:_FinishWin()
    local gs=self.gameState
    self:_BookTerminal("WIN"); self:_PresentTerminal(gs)
end
function E:_FinishLoss(reason)
    local gs=self.gameState
    _timerGuard:Cancel()
    self:_BookTerminal("LOSS",reason or "rules"); self:_PresentTerminal(gs)
end

-- Timer deadlines use monotonic wall time, including nonterminal effects.
-- Simulation retains bounded substeps; a stalled client cannot extend its timer.
function E:_AdvanceClock()
    local now=GetTime(); local elapsed=math.max(0,now-(self._clock or now)); self._clock=now
    local gs=self.gameState
    if gs and not gs.terminal then ArcadiaNexus.BS_Logic:TickTimers(gs,elapsed) end
    if gs and gs.lost and not gs.terminal then self:_FinishLoss("timeout") end
    return elapsed
end

function E:_BeginResolve(landEvent)
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    if not gs or not Logic or gs.terminal or not gs.shot or not gs.shot.landed then return end
    self.state = "RESOLVE"
    self:_AdvanceClock()
    if self.gameState~=gs or gs.terminal then return end

    local result = Logic:ResolveLanding(gs)
    if result.win or result.loss then self:_BookTerminal(result.win and "WIN" or "LOSS") end
    if self.gameState~=gs then return end
    self:_Notify("OnShotLanded", gs, result, landEvent)
    if self.gameState~=gs or self.state~="RESOLVE" then return end

    local steps = {}
    if result.placed then
        steps[#steps + 1] = { delay = 0.02, fn = function()
            self:_Notify("OnPlaced", gs, result)
        end }
    end
    local popN = #(result.destroyed or {}) + #(result.popped or {})
    if popN > 0 then
        PlayBS("pop")
        steps[#steps + 1] = { delay = 0.02, fn = function()
            self:_Notify("OnPopped", gs, result)
        end }
    end
    if #(result.dropped or {}) > 0 then
        PlayBS("drop")
        steps[#steps + 1] = { delay = 0.22 + math.min(8, popN) * 0.045, fn = function()
            self:_Notify("OnDropped", gs, result)
        end }
    end
    if result.fanfare then
        steps[#steps + 1] = { delay = 0.05, fn = function()
            self:_Notify("OnFanfare", gs, result)
        end }
    end
    if result.powerGranted then
        PlayBS("power")
        steps[#steps + 1] = { delay = 0.05, fn = function()
            self:_Notify("OnPowerGranted", gs, result.powerGranted)
        end }
    end
    if result.overchargeStarted then
        PlayBS("overcharge")
        steps[#steps + 1] = { delay = 0.02, fn = function()
            self:_Notify("OnOvercharge", gs)
        end }
    end
    if result.rowSpawned then
        steps[#steps + 1] = { delay = 0.12, fn = function()
            self:_Notify("OnRowSpawned", gs)
        end }
    end
    if result.placed or popN > 0 or #(result.dropped or {}) > 0 then
        local wait = 0.08
        if popN > 0 then wait = 0.26 + math.min(10, popN) * 0.045 end
        if #(result.dropped or {}) > 0 then wait = wait + 0.22 end
        steps[#steps + 1] = { delay = wait, fn = function() end }
    end

    local sid=self._sessionId
    local function AfterResolve()
        if self.gameState~=gs or self._sessionId~=sid or self.state~="RESOLVE" then return end
        self:_AdvanceClock()
        if self.gameState~=gs or self.state~="RESOLVE" then return end
        self:_Notify("SyncBoard", self.gameState)
        self:_Notify("UpdateHUD", self.gameState)
        if result.win then
            self:_PresentTerminal(gs)
        elseif result.loss or gs.lost then
            self:_PresentTerminal(gs)
        else
            self.state = "AIMING"
            self:_SaveShotProgress()
            self:_StartLoop()
            self:_Notify("OnAiming", self.gameState)
        end
    end

    for _,step in ipairs(steps) do
        local fn=step.fn
        step.fn=function() if self.gameState==gs and self._sessionId==sid and self.state=="RESOLVE" then fn() end end
    end
    if #steps == 0 then
        AfterResolve()
    else
        _timerGuard:RunSequence(steps, AfterResolve)
    end
end

function E:_Tick(dt)
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    if not gs or not Logic then return end
    local elapsed=self:_AdvanceClock()
    if self.gameState~=gs or gs.terminal then return end
    dt=math.min(elapsed,0.1)
    self:_Notify("OnFrame", gs, dt)
    if self.gameState~=gs or gs.terminal then return end

    if gs.lost then
        self:_FinishLoss()
        return
    end

    if self.state == "FLYING" then
        local ev = Logic:TickShot(gs, dt)
        if ev == "bounce" or ev == "bounce_landed" then
            PlayBS("bounce")
            self:_Notify("OnWallBounce", gs)
        end
        self:_Notify("OnShotMoved", gs)
        if ev == "landed" or ev == "bounce_landed" then
            self:_BeginResolve(ev)
        elseif not gs.shot or not gs.shot.active then
            self.state = "AIMING"
            self:_StartLoop()
            self:_Notify("OnAiming", gs)
        end
    end
end

function E:StartGame(config)
    local S = ArcadiaNexus.BS_Settings
    local Logic = ArcadiaNexus.BS_Logic
    if not Logic then return end
    config = config or {}

    local mode = config.playMode or config.gameMode or (S and S:Get("mode")) or "endless"
    local difficulty = config.difficulty or (S and S:Get("difficulty")) or "easy"
    local slot = config.slot or (S and S:GetActiveSlot()) or 1
    local startMode = config.mode or "new"
    local previous=self.gameState
    local writeNew
    local cfg = {
        mode       = mode,
        difficulty = difficulty,
        levelIndex = config.levelIndex or 1,
    }

    if mode == "shot" and startMode == "continue" and S then
        local saved = S:LoadSlot(slot)
        if saved then
            cfg.mode = "shot"
            cfg.difficulty = saved.diff or difficulty
            cfg.levelIndex = saved.currentLevel or 1
            cfg.score = 0
            local mid = saved.midGame
            if mid and not ArcadiaNexus.LocalResults:GetSerial(GAME_ID,mid.runId) then mid=nil end
            if saved.layoutVersion~=S.CAMPAIGN_VERSION or mid and mid.snapshotVersion~=Logic.SNAPSHOT_VERSION then
                mid=nil
            end
            if mid and Logic:GridHasBubbles(mid.grid) then
                cfg.midGame = mid
            else
                cfg.midGame=nil
            end
        end
    elseif mode == "shot" and startMode == "new" then
        cfg.levelIndex = config.levelIndex or 1
        if S then
            local kept = config.preserveProgress and S:LoadSlot(slot)
            writeNew = S:PackProgress(nil, {
                paused = false,
                currentLevel = cfg.levelIndex,
                score = 0,
                diff = difficulty,
                midGame = nil,
                stars = kept and kept.stars or {},
                levelBests = kept and kept.levelBests,
                campaignVersion = S.CAMPAIGN_VERSION,
                clearedLevel = kept and kept.clearedLevel or 0,
            })
        end
    end

    local gs = Logic:NewState(cfg)
    if not gs then return end

    local sid = ArcadiaNexus.Lifecycle:ClaimRestart(GAME_ID, E._sessionId)
    if not sid then return false end
    if previous and not previous.terminal and previous.mode~="shot" then
        self:_BookTerminal("LOSS","restart")
        if self.gameState~=previous then return end
    end
    if S and writeNew then S:SaveSlot(slot, writeNew) end
    if S then
        S:FlushResults()
        if self.gameState and self.gameState~=previous then return end
        S:Set("mode", mode)
        S:Set("difficulty", difficulty)
        S:SetActiveSlot(slot)
    end
    self.activeSlot = slot
    _timerGuard:Cancel()
    _gameLoop:Stop()
    E._sessionId = sid
    gs.runId=gs.runId or ArcadiaNexus.LocalResults:NewRun(GAME_ID)
    local receipt=ArcadiaNexus.LocalResults:GetReceipt(gs.runId)
    if receipt then cfg.midGame=nil; gs=Logic:NewState(cfg); gs.runId=ArcadiaNexus.LocalResults:NewRun(GAME_ID) end
    if S then S:Set("mode",gs.mode); S:Set("difficulty",gs.difficulty) end
    self.gameState = gs
    self.state = gs.shot and gs.shot.active and "FLYING" or "AIMING"
    self._clock=GetTime()
    self:_SaveShotProgress()
    PlayBS("start")
    self:_Notify("OnGameStarted", gs)
    self:_StartLoop()
end

function E:ContinueToNextLevel()
    local gs = self.gameState
    if self.state ~= "LEVELWIN" or not gs then return end
    self:StartGame({
        playMode   = "shot",
        difficulty = gs.difficulty,
        slot       = self.activeSlot,
        mode       = "continue",
    })
end

function E:RetryLevel()
    local gs = self.gameState
    local idx = gs and gs.levelIndex or 1
    local diff = gs and gs.difficulty or "easy"
    local mode = gs and gs.mode or "shot"
    self:StartGame({
        playMode   = mode,
        difficulty = diff,
        slot       = self.activeSlot,
        mode       = "new",
        levelIndex = idx,
        preserveProgress = mode == "shot",
    })
end

-- Campaign map is an engine state, but intentionally has no active game
-- session. It can therefore be opened from a save slot without starting a
-- board, timer, or renderer loop.
function E:OpenCampaignMap(slot, focusLevel)
    local S = ArcadiaNexus.BS_Settings
    local Levels = ArcadiaNexus.BS_Levels
    local CP = ArcadiaNexus.CampaignProgress
    if not S or not Levels or not CP then return end
    slot = tonumber(slot) or self.activeSlot or 1
    local previous=self.gameState
    if previous and not previous.terminal then
        if self.gameState.mode=="shot" then self:_SaveShotProgress() else self:_BookTerminal("LOSS","exit") end
        if self.gameState~=previous then return end
    end
    self:_StopLoop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self.activeSlot = slot
    S:SetActiveSlot(slot)
    local progress = S:LoadSlot(slot)
    if not progress then
        progress = S:PackProgress(nil, { currentLevel = 1, paused = false })
    end
    CP.Normalize(progress, { levelCount = Levels.COUNT, maxStars = 3 })
    S:SaveSlot(slot, progress)
    self.gameState = nil
    self.state = "MAP"
    self:_Notify("ShowCampaignMap", progress, focusLevel or progress.currentLevel)
end

function E:SelectCampaignLevel(level)
    if self.state ~= "MAP" then return end
    local S = ArcadiaNexus.BS_Settings
    local Levels = ArcadiaNexus.BS_Levels
    local CP = ArcadiaNexus.CampaignProgress
    if not S or not Levels or not CP then return end
    local progress = S:LoadSlot(self.activeSlot)
    if not CP.IsLevelUnlocked(progress, level, { levelCount = Levels.COUNT }) then return end
    self:StartGame({
        playMode = "shot",
        difficulty = progress.diff or S:Get("difficulty") or "easy",
        slot = self.activeSlot,
        mode = "new",
        levelIndex = level,
        preserveProgress = true,
    })
end

function E:Fire()
    if self.state ~= "AIMING" then return end
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    local R = ArcadiaNexus.BS_Renderer
    if not gs or not Logic then return end
    self:_AdvanceClock()
    if gs.terminal or self.gameState~=gs or self.state~="AIMING" then return end
    if gs.pendingPower == "joker" then
        self:_Notify("OnJokerHint", gs)
        return
    end
    local angle = (R and R.GetAimAngle and R:GetAimAngle()) or (-math.pi / 2)
    gs.aimAngle=angle
    if not Logic:Fire(gs, angle, gs.pendingPower) then return end
    PlayBS("shoot")
    self.state = "FLYING"
    self:_SaveShotProgress()
    self:_Notify("OnShotFired", gs)
end

function E:UseJoker(color)
    if self.state ~= "AIMING" then return end
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    self:_AdvanceClock()
    if gs and not gs.terminal and Logic and Logic:SetJokerColor(gs, color) then
        self:_Notify("OnJokerUsed", gs, color)
        self:_Notify("UpdateHUD", gs)
    end
end

function E:CycleJokerColor()
    local gs=self.gameState
    if self.state~="AIMING" or not gs or gs.pendingPower~="joker" then return false end
    local colors=ArcadiaNexus.BS_Logic:ColorsOnBoard(gs)
    self._jokerIndex=((self._jokerIndex or 0)%math.max(1,#colors))+1
    gs.jokerChoice=colors[self._jokerIndex]
    self:_Notify("OnJokerChoice",gs,gs.jokerChoice)
    return true
end
function E:ConfirmJokerColor()
    local gs=self.gameState
    if not gs or not gs.jokerChoice then return end
    self:UseJoker(gs.jokerChoice)
end

function E:SaveAndPause(reason)
    if reason=="exit" and self.gameState and self.gameState.mode~="shot" then self:StopGame(); return end
    local previous=self.gameState
    self:_AdvanceClock()
    if self.gameState~=previous then return end
    local gs=self.gameState
    if gs and gs.mode~="shot" and not gs.terminal then
        self:_BookTerminal("LOSS","hide")
        if self.gameState~=gs then return end
    end
    if self.state == "AIMING" or self.state == "FLYING" or self.state == "RESOLVE" then
        self:_SaveShotProgress()
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame(GAME_ID, E._sessionId)
    end
    self:_StopLoop()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self.state = "IDLE"
    self.gameState = nil
    self:_Notify("EnterIdleState")
end

function E:StopGame()
    local ended=self.gameState
    self:_AdvanceClock()
    if self.gameState~=ended then return end
    if ended and ended.mode~="shot" and not ended.terminal then self:_BookTerminal("LOSS","exit") end
    if self.gameState~=ended then return end
    if self.state == "AIMING" or self.state == "FLYING" or self.state == "RESOLVE" then
        self:_SaveShotProgress()
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self:_StopLoop()
    self.state = "IDLE"
    self.gameState = nil
    local Sound = ArcadiaNexus.BS_Sound
    if Sound and Sound.Stop then Sound.Stop() end
    self:_Notify("EnterIdleState")
    if ended and ended.reason=="exit" and ended.resultPayload then self:_Notify("ShowLoss",ended,false) end
end
