-- Regular M6 solo AI. Private search stays internal; key only in the human spy view.
local A = ArcadiaNexus
local E, L, AI = A.SI7_Engine, A.SI7_Logic, A.SI7_AI
local EnemyAI = A.SI7_RestraintAI
local run, loop
local nextRunId = 0
local oldStart, oldStop, oldView = E.StartGame, E.StopGame, E.GetView
local oldGuess, oldPass, oldClue, oldSeat = E.Guess, E.Pass, E.SubmitClue, E.SetViewSeat

local function Render()
    local R = A.SI7_Renderer
    if R then R:Render() end
end

local function Cancel()
    if loop then loop:Stop() end
    run = nil
end

local function Fail(r)
    r.blocked, r.job, r.notice = true, nil, "solo_blocked"
    loop:Stop()
    Render()
end

local function Apply(r, action, seat)
    if run ~= r or E.state ~= "PLAYING" or not A.GameSession:IsSession(E, r.sid)
        or A.GameSession:GetStatus() ~= "PLAYING" then return false end
    if not L.Apply(r.pub, r.key, action, seat) then return false end
    local team, spy = L.Role(seat)
    if team ~= r.humanTeam and spy and action.kind == "CLUE" then r.attempts = 0 end
    if team ~= r.humanTeam and not spy and action.kind == "GUESS" then r.attempts = r.attempts + 1 end
    r.job, r.delay, r.notice = nil, 0.8, nil
    if A.SI7_Settings:Get("soundEnabled") then PlaySound(action.kind == "GUESS" and 847 or 857) end
    if L.IsFinished(r.pub) then
        -- Session bleibt bis zum tatsächlichen Verlassen gültig, damit der
        -- Ergebnisdialog über den vorhandenen StopGame-Pfad aufgeräumt wird.
        E.state = "FINISHED"
        loop:Stop()
        Render()
        E:MaybeShowResult()
    else
        Render()
    end
    return true
end

local function Tick(r, dt)
    local own = r.pub.turn == r.humanTeam
    if own and ((r.role == "agent" and r.pub.phase == "G") or (r.role == "spy" and r.pub.phase == "C")) then return end
    r.delay = math.max(0, r.delay - dt)
    local profile = own and "partner" or r.profile
    local spyAI = own and AI or EnemyAI
    local action
    if r.pub.phase == "C" then
        if not r.job then
            r.job = spyAI.NewSpySearch(AI.Observe(r.pub, r.locale), r.key, profile)
            if not r.job then Fail(r) return end
        end
        local done, clue = spyAI.StepSpy(r.job, 4)
        if done == nil or (done and not clue) then Fail(r) return end
        if not done or r.delay > 0 then return end
        action = clue
    else
        if r.delay > 0 then return end
        local reason
        if own then action, reason = AI.Agent(AI.Observe(r.pub, r.locale), "partner")
        else action, reason = EnemyAI.Agent(AI.Observe(r.pub, r.locale), {attempts=r.attempts}, profile) end
        if not action then Fail(r) return end
        r.reason = action.kind == "PASS" and reason or nil
    end
    local seat = (r.pub.turn == "R" and 1 or 3) + (r.pub.phase == "G" and 1 or 0)
    if not Apply(r, action, seat) then Fail(r) end
end

function E:StartGame(config)
    config = config or {}
    if config.mode ~= "solo_ai" then
        Cancel()
        local result = oldStart(self, config)
        if config.mode == "hotseat" and config.team and config.role then
            self:SetViewSeat((config.team == "B" and 3 or 1) + (config.role == "agent" and 1 or 0))
        end
        return result
    end
    local locale = config.locale or A.SI7_Settings:Get("puzzleLocale")
    if locale ~= "deDE" and locale ~= "enUS" then locale = "enUS" end
    A.SI7_Settings:Set("wordSet", "AZEROTH")
    local profile = config.profile == "easy" and "easy" or "normal"
    local humanTeam = config.team == "B" and "B" or "R"
    local role = config.role == "spy" and "spy" or "agent"
    local humanSeat = (humanTeam == "R" and 1 or 3) + (role == "agent" and 1 or 0)
    -- Deal from the covered corpus, independently of color allocation. Never redraw.
    local ids, indices = A.SI7_Knowledge.GetIds(), {}
    for i, id in ipairs(A.SI7_Words) do indices[id] = i end
    A.ArrayUtils.Shuffle(ids)
    local pub, colors = L.EmptyPublic(), {}
    for i = 1, 25 do
        pub.ids[i] = assert(indices[ids[i]])
        colors[i] = i <= 9 and "R" or i <= 17 and "B" or i <= 24 and "N" or "X"
    end
    A.ArrayUtils.Shuffle(colors)
    if self.match and not self.match._closed then return false end
    local previous = self._sessionId
    self._sessionId = A.Lifecycle:RestartGame("SI7", self._sessionId)
    if not self._sessionId then self._sessionId = previous; return false end
    Cancel()
    self:StopMatchQuiet()
    self.mode, self.state, self.viewSeat = "solo_ai", "PLAYING", humanSeat
    self.public, self.key, self._notice = nil, nil, nil
    nextRunId = nextRunId + 1
    run = { id=nextRunId, pub=pub, key=table.concat(colors), locale=locale, profile=profile,
        sid=self._sessionId, delay=0.8, attempts=0, humanTeam=humanTeam, role=role, seat=humanSeat }
    local r = run
    loop = loop or A.GameLoop.Create("ArcadiaNexus_SI7_SoloLoop")
    loop:Start(function(dt) Tick(r, dt) end, { stateCheck=function()
        return run == r and E.state == "PLAYING" and A.GameSession:IsSession(E, r.sid)
            and A.GameSession:GetStatus() == "PLAYING"
    end })
    local rnd = A.SI7_Renderer
    -- Erst nach gültigem neuen Lauf: eine noch offene Navigationsbestätigung
    -- gehört zur vorherigen Partie und darf einen Fehlstart nicht mitnehmen.
    if rnd and rnd.ReleaseNavigationChrome then rnd:ReleaseNavigationChrome() end
    if rnd and rnd.HideOwnResultDialog then rnd:HideOwnResultDialog() end
    Render()
    return true
end

function E:GetView()
    if self.mode ~= "solo_ai" or not run then return oldView(self) end
    local pub = {}
    for k, v in pairs(run.pub) do
        if k == "ids" then
            pub.ids = {}
            for i, id in ipairs(v) do pub.ids[i] = id end
        else pub[k] = v end
    end
    local active = self.state == "PLAYING" and not run.blocked
        and A.GameSession:IsSession(E, run.sid) and A.GameSession:GetStatus() == "PLAYING"
    return { state=self.state, mode=self.mode, pub=pub, seat=run.seat, team=run.humanTeam, spy=run.role=="spy",
        key=run.role=="spy" and run.key or nil,
        canClue=active and run.role=="spy" and pub.turn==run.humanTeam and pub.phase=="C",
        canGuess=active and run.role=="agent" and pub.turn==run.humanTeam and pub.phase=="G",
        mp=false, ownedSeats={run.seat}, duo=false, locale=run.locale, profile=run.profile, role=run.role,
        runId=run.id, notice=run.notice or (self.state == "PLAYING" and "solo_ai" or nil), aiReason=run.reason }

end

function E:Guess(i)
    if self.mode ~= "solo_ai" then return oldGuess(self, i) end
    if not run or not self:GetView().canGuess or not A.SI7_Clues.IsInteger(i, 1, 25) then return end
    Apply(run, {kind="GUESS", i=i}, run.seat)
end

function E:Pass()
    if self.mode ~= "solo_ai" then return oldPass(self) end
    if run and self:GetView().canGuess then Apply(run, {kind="PASS"}, run.seat) end
end

function E:SubmitClue(word, n)
    if self.mode ~= "solo_ai" then return oldClue(self, word, n) end
    if not run or not self:GetView().canClue then return false end
    local action, reason = AI.CheckHumanClue(AI.Observe(run.pub, run.locale), word, n)
    if not action then run.notice=reason Render() return false end
    return Apply(run, action, run.seat)
end

function E:SetViewSeat(seat)
    if self.mode ~= "solo_ai" then return oldSeat(self, seat) end
end

function E:StopGame()
    Cancel()
    return oldStop(self)
end
