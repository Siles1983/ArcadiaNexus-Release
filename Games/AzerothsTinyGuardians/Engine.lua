-- ============================================================
--  Azeroth's Tiny Guardians – Engine.lua
--  Lifecycle, Hub/Stall, Pflege, Offline-Catchup — kein C_Timer
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_Engine = {}
local E = ArcadiaNexus.ATG_Engine

E._sessionId = nil

E.state        = "IDLE"
E.phase        = "IDLE"
E.gameState    = nil
E._returnToCare = false

local _gameLoop   = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_ATG_LoopFrame")
local _timerGuard = ArcadiaNexus.TimerGuard.New()
E._timerGuard     = _timerGuard

E._needsAccum  = 0
E._sleepAccum  = 0
E._sleepReason = nil
E._evolveAccum = 0
E._commentAccum = 0
E._commentNext  = 45

local NEEDS_INTERVAL  = 60
local EXHAUSTED_REGEN = 2
local EVOLVE_DURATION = 2
local GAME_ID         = "AZEROTHTINYGUARDIANS"

local SND_INTERACT = 774
local SND_EVOLVE   = SOUNDKIT and SOUNDKIT.UI_ACHIEVEMENT_TOAST_SPARK or 888

local function GetLogic()    return ArcadiaNexus.ATG_Logic end
local function GetRenderer() return ArcadiaNexus.ATG_Renderer end
local function GetSettings() return ArcadiaNexus.ATG_Settings end

local function EmitAdoptionStats(recordPlayed)
    local S = GetSettings()
    if not S or not ArcadiaNexus.Engine or not ArcadiaNexus.Engine.Emit then return end
    local st = S.EnsureStats and S:EnsureStats()
    ArcadiaNexus.Engine:Emit("GAME_RESULT", {
        gameId       = GAME_ID,
        difficulty   = "default",
        result       = "STATS",
        recordPlayed = recordPlayed == true,
        score        = 0,
        stats        = {
            adoptions = (st and st.adoptions) or 0,
        },
    })
end

function E:PlaySoundEvent(event)
    local S = GetSettings()
    if not S or not S:Get("soundEnabled") then return end
    if event == "interact" and S:Get("soundOnInteract") then
        PlaySound(SND_INTERACT, "Master")
    elseif event == "evolve" and S:Get("soundOnEvolve") then
        PlaySound(SND_EVOLVE, "Master")
    elseif event == "comment" and S:Get("soundOnComment") then
        PlaySound(SND_INTERACT, "Master")
    end
end

local function ScheduleNextComment()
    E._commentAccum = 0
    E._commentNext  = 30 + math.random() * 30
end

local function UpdateRendererComm(dt, gs, phase)
    local R = GetRenderer()
    if R and R.UpdateComm then R:UpdateComm(dt, gs, phase) end
end

local function CheckATGAchievements()
    local AM = ArcadiaNexus and ArcadiaNexus.AchievementManager
    if not AM or not AM.HandleGameResult then return end
    pcall(AM.HandleGameResult, AM, {
        gameId = GAME_ID,
        result = "WIN",
    })
end

function E:_SetPhase(newPhase)
    E.phase = newPhase
    local R = GetRenderer()
    if R and R.OnPhaseChanged then R:OnPhaseChanged(newPhase) end
end

function E:_StartTick()
    _gameLoop:Start(function(dt) E:_Tick(dt) end)
end

function E:_StopTick()
    _gameLoop:Stop()
end

-- Catch-up nur beim Öffnen/Start (kein Hintergrund-Tick bei geschlossenem UI).
function E:_ApplyCatchup(gs)
    local Logic = GetLogic()
    if not Logic or not gs then return gs end
    local elapsed = Logic:GetOfflineElapsed(gs)
    if elapsed > 0 then
        Logic:ApplyOfflineTime(gs, elapsed)
    end
    Logic:EnsureStageFromXp(gs)
    gs.lastPausedAt = time()
    return gs
end

function E:_CatchupAllLiving()
    local S = GetSettings()
    local Logic = GetLogic()
    if not S or not Logic then return end
    local pets = S:GetPets() or {}
    for _, pet in ipairs(pets) do
        if pet.status ~= "retired" then
            self:_ApplyCatchup(pet)
            S:UpsertPet(pet)
        end
    end
end

function E:_ParkActivePet()
    local gs = E.gameState
    if not gs then return end
    gs.lastPausedAt = time()
    gs.status = gs.status or "living"
    local S = GetSettings()
    if S then S:SaveLivingPet(gs) end
    E.gameState = nil
end

function E:_ResetCareTimers()
    E._needsAccum  = 0
    E._sleepAccum  = 0
    E._sleepReason = nil
    E._evolveAccum = 0
    ScheduleNextComment()
end

function E:_BeginCare(gs)
    local Logic = GetLogic()
    self:_ApplyCatchup(gs)
    E.gameState    = gs
    E.state        = "PLAYING"
    E._returnToCare = false
    self:_ResetCareTimers()

    if Logic and Logic:NeedsForcedRest(gs) then
        E.phase = "SLEEPING"
        E._sleepReason = "exhausted"
    else
        E.phase = "ACTIVE"
        E._sleepReason = nil
    end

    local S = GetSettings()
    if S then
        S:SaveLivingPet(gs)
        S:SetActivePetId(gs.id)
    end

    local R = GetRenderer()
    if R and R.OnPetStarted then R:OnPetStarted(gs) end
    if E.phase ~= "ACTIVE" and R and R.OnPhaseChanged then
        R:OnPhaseChanged(E.phase)
    end
    self:_RefreshUI()
    self:_StartTick()
    CheckATGAchievements()
end

function E:_BeginSleep(duration, reason)
    E._sleepReason = reason or "action"
    E._sleepAccum  = duration or 20
    E:_SetPhase("SLEEPING")
end

function E:_WakeFromSleep()
    E._sleepReason = nil
    E._sleepAccum  = 0
    E:_SetPhase("ACTIVE")
end

function E:_BeginEvolving(duration)
    E._evolveAccum = duration or EVOLVE_DURATION
    E:_SetPhase("EVOLVING")
end

function E:_EndEvolving()
    E._evolveAccum = 0
    E:_SetPhase("ACTIVE")
end

function E:_RefreshUI()
    local gs = E.gameState
    local R  = GetRenderer()
    if not R or not gs then return end
    if R.RefreshHUD then R:RefreshHUD(gs) end
    if R.RefreshActionButtons then R:RefreshActionButtons(gs, E.phase) end
end

function E:_Tick(dt)
    if E.state ~= "PLAYING" then return end
    local gs = E.gameState
    local Logic = GetLogic()
    if not gs or not Logic then return end
    if E.phase ~= "ACTIVE" and E.phase ~= "SLEEPING" and E.phase ~= "EVOLVING" then
        return
    end

    Logic:TickCooldowns(gs, dt)

    if E.phase == "SLEEPING" then
        if E._sleepReason == "exhausted" then
            Logic:RegenEnergy(gs, EXHAUSTED_REGEN * dt)
            if Logic:ForcedRestComplete(gs) then
                E:_WakeFromSleep()
            end
        else
            E._sleepAccum = E._sleepAccum - dt
            if E._sleepAccum <= 0 then
                E:_WakeFromSleep()
            end
        end
        E:_RefreshUI()
        UpdateRendererComm(dt, gs, E.phase)
        return
    end

    if E.phase == "EVOLVING" then
        Logic:TickCooldowns(gs, dt)
        E._evolveAccum = E._evolveAccum - dt
        local R = GetRenderer()
        if R and R.UpdateEvolutionAnim then R:UpdateEvolutionAnim(dt) end
        if E._evolveAccum <= 0 then
            E:_EndEvolving()
        end
        E:_RefreshUI()
        UpdateRendererComm(dt, gs, E.phase)
        return
    end

    UpdateRendererComm(dt, gs, E.phase)

    E._commentAccum = E._commentAccum + dt
    if E._commentAccum >= E._commentNext then
        ScheduleNextComment()
        local mood = Logic:GetCriticalMood(gs, E.phase)
        if mood then
            local R = GetRenderer()
            if R and R.ShowComment then R:ShowComment(gs, mood) end
        end
    end

    if Logic:NeedsForcedRest(gs) then
        E:_BeginSleep(0, "exhausted")
        E:_RefreshUI()
        return
    end

    E._needsAccum = E._needsAccum + dt
    if E._needsAccum >= NEEDS_INTERVAL then
        E._needsAccum = E._needsAccum - NEEDS_INTERVAL
        Logic:TickNeeds(gs)
        E:_RefreshUI()
    else
        local R = GetRenderer()
        if R and R.RefreshActionButtons then
            R:RefreshActionButtons(gs, E.phase)
        end
    end
end

function E:DoAction(action)
    if E.state ~= "PLAYING" or E.phase ~= "ACTIVE" then return end
    local Logic = GetLogic()
    local S     = GetSettings()
    local gs    = E.gameState
    if not Logic or not S or not gs then return end

    local ok = Logic:CanPerformAction(gs, action, E.phase)
    if not ok then return end

    local result = Logic:ApplyAction(gs, action)
    local evolved = Logic:GainXP(gs, action)
    S:SaveLivingPet(gs)

    if evolved then
        if evolved == "ADULT" then
            S:RecordAdultReached(gs)
            CheckATGAchievements()
        end
        local R = GetRenderer()
        if R and R.OnEvolved then R:OnEvolved(gs) end
        E:_BeginEvolving(EVOLVE_DURATION)
        self:PlaySoundEvent("evolve")
    else
        self:PlaySoundEvent("interact")
        local R = GetRenderer()
        if R and R.OnAction then R:OnAction(action, gs) end
        if result.startsSleep then
            E:_BeginSleep(result.sleepDur or 20, "action")
        end
    end

    E:_RefreshUI()
end

function E:DevAdvanceStage()
    if not (ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode()) then return end
    if E.state ~= "PLAYING" or not E.gameState then return end
    if E.phase ~= "ACTIVE" and E.phase ~= "SLEEPING" then return end

    local Logic = GetLogic()
    local S     = GetSettings()
    local gs    = E.gameState
    if not Logic or not S or not Logic.DevAdvanceStage then return end

    local newStage = Logic:DevAdvanceStage(gs)
    if not newStage then return end
    S:SaveLivingPet(gs)

    local R = GetRenderer()
    if R then R._appliedModelKey = nil end

    if newStage == "YOUTH" or newStage == "ADULT" then
        if R and R.OnEvolved then R:OnEvolved(gs) end
        E:_BeginEvolving(EVOLVE_DURATION)
        self:PlaySoundEvent("evolve")
    else
        E:_SetPhase("ACTIVE")
        self:_RefreshUI()
    end
end

function E:CanRetire()
    local Logic = GetLogic()
    return Logic and Logic:CanRetire(E.gameState, E.phase)
end

function E:BeginRetire()
    if not E:CanRetire() then return end
    E:_SetPhase("RETIRING")
end

function E:CancelRetire()
    if E.phase ~= "RETIRING" then return end
    E:_SetPhase("ACTIVE")
end

function E:ConfirmRetire()
    if E.phase ~= "RETIRING" then return end
    E:Retire()
end

function E:Retire()
    local gs = E.gameState
    local Logic = GetLogic()
    local S = GetSettings()
    if E.state ~= "PLAYING" or not gs or not Logic or not S then return end
    if gs.stage ~= "ADULT" then return end

    local entry = Logic:BuildStallEntry(gs)
    if not entry then return end

    S:RetirePet(gs.id, entry)
    S:ClearActivePet()

    if ArcadiaNexus.Engine and ArcadiaNexus.Engine.Emit then
        local st = S.EnsureStats and S:EnsureStats()
        ArcadiaNexus.Engine:Emit("GAME_RESULT", {
            gameId     = GAME_ID,
            difficulty = "default",
            result     = "WIN",
            score      = 0,
            stats      = {
                adoptions = (st and st.adoptions) or 0,
            },
        })
    end

    E:_StopTick()
    E.gameState = nil
    E._returnToCare = false
    CheckATGAchievements()
    E:EnterHub()
end

function E:_EnsureSession()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:ResumeGame(GAME_ID, E._sessionId)
        return
    end
    E._sessionId = ArcadiaNexus.Lifecycle:RestartGame(GAME_ID, E._sessionId)
end

function E:StartGame()
    if E.state == "PLAYING" then return end
    _timerGuard:Cancel()
    self:_EnsureSession()
    E.state = "PLAYING"
    self:EnterHub()
end

function E:EnterHub()
    self:_StopTick()
    self:_ParkActivePet()
    self:_CatchupAllLiving()
    E.state = "PLAYING"
    E.phase = "HUB"
    E._returnToCare = false
    local R = GetRenderer()
    local S = GetSettings()
    if R and R.HideComm then R:HideComm() end
    if S and S:HasAnyPets() then
        if R and R.OpenStall then R:OpenStall() end
    else
        if R and R.EnterAdopting then R:EnterAdopting() end
    end
    CheckATGAchievements()
end

function E:TryEnterAdopting()
    local S = GetSettings()
    if S and S.IsPetLimitReached and S:IsPetLimitReached() then
        local R = GetRenderer()
        if R and R.ShowPetLimitPopup then R:ShowPetLimitPopup() end
        return
    end
    self:EnterAdopting()
end

function E:ReleasePet(petId)
    local S = GetSettings()
    if not S or not petId then return end
    if E.gameState and E.gameState.id == petId then
        self:_StopTick()
        E.gameState = nil
        E._returnToCare = false
    end
    S:RemovePet(petId)
    local R = GetRenderer()
    if R and R.HideStallDetail then R:HideStallDetail() end
    if R and R.RefreshStallList then R:RefreshStallList() end
end

function E:EnterAdopting()
    local S = GetSettings()
    if S and S.IsPetLimitReached and S:IsPetLimitReached() then
        local R = GetRenderer()
        if R and R.ShowPetLimitPopup then R:ShowPetLimitPopup() end
        return
    end
    self:_StopTick()
    if E.state == "PLAYING" then
        self:_ParkActivePet()
        E.phase = "ADOPTING"
        local R = GetRenderer()
        if R and R.HideComm then R:HideComm() end
        if R and R.EnterAdopting then R:EnterAdopting() end
        return
    end
    E.gameState = nil
    E.state = "IDLE"
    E.phase = "IDLE"
    local R = GetRenderer()
    if R and R.EnterIdleState then R:EnterIdleState() end
end

function E:OpenStall()
    if E.state ~= "PLAYING" then
        self:StartGame()
        return
    end
    local hadCare = E.gameState ~= nil
    self:_StopTick()
    self:_ParkActivePet()
    self:_CatchupAllLiving()
    E._returnToCare = hadCare
    E.phase = "HUB"
    local R = GetRenderer()
    if R and R.HideComm then R:HideComm() end
    if R and R.OpenStall then R:OpenStall() end
end

function E:CloseStall()
    local R = GetRenderer()
    local S = GetSettings()
    if E._returnToCare then
        local id = S and S:GetActivePetId()
        local pet = id and S:GetPet(id)
        if pet and pet.status ~= "retired" then
            self:_BeginCare(pet)
            return
        end
    end
    E.phase = "ADOPTING"
    if R and R.EnterAdopting then R:EnterAdopting() end
end

function E:ResumePet(petId)
    local S = GetSettings()
    if not S then return end
    local pet = S:GetPet(petId)
    if not pet or pet.status == "retired" then return end
    self:_StopTick()
    self:_ParkActivePet()
    self:_BeginCare(pet)
end

function E:AdoptPet(petType, name)
    local Logic = GetLogic()
    local S = GetSettings()
    if not Logic or not S then return end
    if E.state ~= "PLAYING" then
        self:_EnsureSession()
        E.state = "PLAYING"
    end

    if S.IsPetLimitReached and S:IsPetLimitReached() then
        local R = GetRenderer()
        if R and R.ShowPetLimitPopup then R:ShowPetLimitPopup() end
        return
    end

    local gs = Logic:NewPetState(petType, name)
    if not gs then return end

    S:SaveLivingPet(gs)
    S:RecordAdoption()
    EmitAdoptionStats(false)
    CheckATGAchievements()
    self:_BeginCare(gs)
end

function E:SaveAndPause()
    _timerGuard:Cancel()
    self:_StopTick()
    self:_ParkActivePet()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:PauseGame(GAME_ID, E._sessionId)
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    E.phase = "IDLE"
    E._returnToCare = false
end

function E:QuitToIdle()
    self:SaveAndPause()
    local R = GetRenderer()
    if R and R.HideComm then R:HideComm() end
    if R and R.EnterIdleState then R:EnterIdleState() end
end

function E:StopGame()
    _timerGuard:Cancel()
    self:_StopTick()
    self:_ParkActivePet()
    if E._sessionId then
        ArcadiaNexus.Lifecycle:EndGame(GAME_ID, E._sessionId)
        E._sessionId = nil
    end
    E.state = "IDLE"
    E.phase = "IDLE"
    E._returnToCare = false
    local R = GetRenderer()
    if R and R.HideComm then R:HideComm() end
    if R and R.EnterIdleState then R:EnterIdleState() end
end
