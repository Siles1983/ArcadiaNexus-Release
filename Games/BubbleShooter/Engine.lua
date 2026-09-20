--[[
    ArcadiaNexus – Bubble Shooter
    Games/BubbleShooter/Engine.lua

    State: IDLE → AIMING ⇄ FLYING → RESOLVE → AIMING
                              ↘ LEVELWIN / GAMEOVER → IDLE
    GameLoop während AIMING/FLYING (Zeit + Overcharge + Flug).
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
            return E.state == "AIMING" or E.state == "FLYING"
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
    if gs.shot then
        gs.shot.active = false
        gs.shot.landed = false
    end
    S:SetActiveSlot(self.activeSlot)
    local previous = S:LoadSlot(self.activeSlot)
    S:SaveSlot(self.activeSlot, S:PackProgress(gs, {
        paused = true,
        stars = previous and previous.stars or {},
        campaignVersion = S.CAMPAIGN_VERSION,
        clearedLevel = previous and previous.clearedLevel or 0,
    }))
end

function E:_SaveCampaignCheckpoint(levelIndex, score, difficulty)
    local S = ArcadiaNexus.BS_Settings
    if not S then return end
    S:SetActiveSlot(self.activeSlot)
    local previous = S:LoadSlot(self.activeSlot)
    S:SaveSlot(self.activeSlot, S:PackProgress(nil, {
        paused       = false,
        currentLevel = levelIndex or 1,
        score        = score or 0,
        diff         = difficulty or "easy",
        midGame      = nil,
        stars        = previous and previous.stars or {},
        campaignVersion = S.CAMPAIGN_VERSION,
        clearedLevel = previous and previous.clearedLevel or 0,
    }))
end

function E:_EmitResult(result)
    local gs = self.gameState
    if not gs then return false end
    if (gs.shotsUsed or 0) <= 0 and result ~= "WIN" then return false end
    local payload = {
        gameId     = GAME_ID,
        difficulty = self:_ScoreDifficulty(gs),
        score      = gs.score or 0,
        result     = result,
        stats      = {
            levelReached    = gs.levelIndex or 1,
            shotsUsed       = gs.shotsUsed or 0,
            maxCombo        = gs.stats.maxCombo or 1,
            maxDrop         = gs.stats.maxDrop or 0,
            powerUsed       = gs.stats.powerUsed or 0,
            overchargeCount = gs.stats.overchargeCount or 0,
        },
    }
    ArcadiaNexus.Engine:Emit("GAME_RESULT", payload)
    return payload.newHighscore == true
end

function E:_FinishWin()
    local gs = self.gameState
    if not gs then return end
    PlayBS("win")
    local isNew = self:_EmitResult("WIN")
    local S = ArcadiaNexus.BS_Settings
    if S then
        S:AddStat("totalLevels", 1)
        if (gs.stats.maxCombo or 0) >= 5 then S:AddStat("totalCombo5", 1) end
        S:AddStat("totalPowerUsed", gs.stats.powerUsed or 0)
        S:AddStat("totalOvercharge", gs.stats.overchargeCount or 0)
        if (gs.stats.maxDrop or 0) > 0 then S:AddStat("totalDrops", 1) end
    end

    if gs.mode == "shot" then
        local Levels = ArcadiaNexus.BS_Levels
        local levelCount = (Levels and Levels.COUNT) or 1
        local isFinal = gs.levelIndex >= levelCount
        local CP = ArcadiaNexus.CampaignProgress
        if S and CP then
            local progress = S:LoadSlot(self.activeSlot) or {}
            local Logic = ArcadiaNexus.BS_Logic
            local grade = Logic and Logic:GradeCampaignStars(gs) or 1
            local best, _, gained = CP.RecordLevel(progress, gs.levelIndex, grade, {
                levelCount = levelCount,
                maxStars = 3,
            })
            gs.lastStars = grade
            gs.bestStars = best
            if gained > 0 then S:AddStat("totalStars", gained) end
        end
        if isFinal then
            self.state = "GAMEOVER"
            -- Keep completed campaigns for map star display and replays.
            self:_SaveCampaignCheckpoint(gs.levelIndex, gs.score, gs.difficulty)
            if E._sessionId then
                ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
                E._sessionId = nil
            end
            self:_Notify("ShowFinalWin", gs, isNew)
        else
            self.state = "LEVELWIN"
            self:_SaveCampaignCheckpoint((gs.levelIndex or 1) + 1, gs.score, gs.difficulty)
            self:_Notify("ShowLevelWin", gs, isNew)
        end
    else
        self.state = "GAMEOVER"
        if E._sessionId then
            ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
            E._sessionId = nil
        end
        self:_Notify("ShowArcadeWin", gs, isNew)
    end
end

function E:_FinishLoss()
    local gs = self.gameState
    if not gs then return end
    PlayBS("lose")
    local isNew = self:_EmitResult("LOSS")
    self.state = "GAMEOVER"
    local S = ArcadiaNexus.BS_Settings
    if gs.mode == "shot" and S then
        -- Level bleibt spielbar; kein Slot-Reset bei Niederlage.
        self:_SaveCampaignCheckpoint(gs.levelIndex or 1, gs.score or 0, gs.difficulty)
    end
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    self:_Notify("ShowLoss", gs, isNew)
end

function E:_BeginResolve(landEvent)
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    if not gs or not Logic then return end
    self.state = "RESOLVE"
    _gameLoop:Stop()

    local result = Logic:ResolveLanding(gs)
    self:_Notify("OnShotLanded", gs, result, landEvent)

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

    local function AfterResolve()
        if not self.gameState then return end
        self:_Notify("SyncBoard", self.gameState)
        self:_Notify("UpdateHUD", self.gameState)
        if result.win then
            self:_FinishWin()
        elseif result.loss or gs.lost then
            self:_FinishLoss()
        else
            self.state = "AIMING"
            self:_StartLoop()
            self:_Notify("OnAiming", self.gameState)
        end
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
    Logic:TickTimers(gs, dt)
    self:_Notify("OnFrame", gs, dt)

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
    if S then
        S:Set("mode", mode)
        S:Set("difficulty", difficulty)
        S:SetActiveSlot(slot)
    end
    self.activeSlot = slot

    _timerGuard:Cancel()
    _gameLoop:Stop()

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
            cfg.score = saved.score or 0
            local mid = saved.midGame
            -- Levels 1–13 were regenerated for campaign version 2. A paused
            -- snapshot from their former hand-authored layouts must not resume
            -- into a board that no longer matches the selected level. Stars
            -- and unlocks remain in the slot; only that stale in-progress run
            -- is discarded.
            if (saved.campaignVersion or 1) < S.CAMPAIGN_VERSION
                and (cfg.levelIndex or 1) <= 13 then
                mid = nil
                saved.midGame = nil
                saved.paused = false
                saved.campaignVersion = S.CAMPAIGN_VERSION
                S:SaveSlot(slot, saved)
            end
            if mid and Logic:GridHasBubbles(mid.grid) then
                cfg.midGame = mid
            else
                -- Leeres Win-Snapshot (älterer Bug): nächstes Level frisch laden.
                if mid and not Logic:GridHasBubbles(mid.grid) then
                    local Levels = ArcadiaNexus.BS_Levels
                    local count = (Levels and Levels.COUNT) or 1
                    if (cfg.levelIndex or 1) < count then
                        cfg.levelIndex = (cfg.levelIndex or 1) + 1
                    end
                    cfg.midGame = nil
                end
            end
        end
    elseif mode == "shot" and startMode == "new" then
        cfg.levelIndex = config.levelIndex or 1
        if S then
            local previous = config.preserveProgress and S:LoadSlot(slot)
            S:SaveSlot(slot, S:PackProgress(nil, {
                paused = false,
                currentLevel = cfg.levelIndex,
                score = 0,
                diff = difficulty,
                midGame = nil,
                stars = previous and previous.stars or {},
                campaignVersion = S.CAMPAIGN_VERSION,
                clearedLevel = previous and previous.clearedLevel or 0,
            }))
        end
    end

    local gs = Logic:NewState(cfg)
    if not gs then return end

    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
    self.gameState = gs
    self.state = "AIMING"
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
    if gs.pendingPower == "joker" then
        self:_Notify("OnJokerHint", gs)
        return
    end
    local angle = (R and R.GetAimAngle and R:GetAimAngle()) or (-math.pi / 2)
    if not Logic:Fire(gs, angle, gs.pendingPower) then return end
    PlayBS("shoot")
    self.state = "FLYING"
    self:_Notify("OnShotFired", gs)
end

function E:UseJoker(color)
    if self.state ~= "AIMING" then return end
    local gs = self.gameState
    local Logic = ArcadiaNexus.BS_Logic
    if gs and Logic and Logic:SetJokerColor(gs, color) then
        self:_Notify("OnJokerUsed", gs, color)
        self:_Notify("UpdateHUD", gs)
    end
end

function E:SaveAndPause()
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
end

function E:StopGame()
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
end
