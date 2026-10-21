-- M6 pure prototype. No Engine, Match, timers, UI or hidden agent state.
local A = _G.ArcadiaNexus
local AI = { VERSION = 1 }
A.SI7_AI = AI
local C, K = A.SI7_Clues, A.SI7_Knowledge
local profiles = {
    easy = { minimum=65, margin=15, group=2 },
    normal = { minimum=55, margin=10, group=3 },
    partner = { minimum=55, margin=10, group=3 },
}

local function CopyObservation(obs)
    if type(obs) ~= "table" or type(obs.ids) ~= "table" or #obs.ids ~= 25
        or (obs.locale ~= "deDE" and obs.locale ~= "enUS")
        or (obs.team ~= "R" and obs.team ~= "B")
        or type(obs.mask) ~= "string" or #obs.mask ~= 25 or obs.mask:find("[^.RBNX]")
        or (obs.phase ~= "C" and obs.phase ~= "G" and obs.phase ~= "O")
        or type(obs.clue) ~= "string" or not C.IsInteger(obs.n, 0, 9) then
        return nil, "observation_invalid"
    end
    local copy = { ids={}, locale=obs.locale, team=obs.team, mask=obs.mask,
        phase=obs.phase, clue=obs.clue, n=obs.n }
    local seen = {}
    for i = 1, 25 do
        local id = obs.ids[i]
        if type(id) ~= "string" or seen[id] or not A.HGM_Words:GetLocalizedWord(id, obs.locale) then
            return nil, "observation_invalid"
        end
        copy.ids[i], seen[id] = id, true
    end
    return copy
end

-- Explicit public allowlist. Ignore all extra fields including accidentally added key/plan.
function AI.Observe(pub, locale)
    if type(pub) ~= "table" or pub.wordSet ~= "AZEROTH" or type(pub.ids) ~= "table" or #pub.ids ~= 25 then
        return nil, "wordset_unsupported"
    end
    local stable = A.SI7_Words
    local obs = { ids={}, mask=pub.mask, team=pub.turn, phase=pub.phase,
        clue=pub.clue, n=pub.n, locale=locale }
    for i = 1, 25 do
        local index = pub.ids[i]
        if not C.IsInteger(index, 1, #stable) then return nil, "observation_invalid" end
        obs.ids[i] = stable[index]
    end
    return CopyObservation(obs)
end

local function Rank(obs, text)
    local meanings, ranked = K.Resolve(text, obs.locale), {}
    for i = 1, 25 do
        if obs.mask:sub(i, i) == "." then
            local weight = 0
            for _, concept in ipairs(meanings) do weight = math.max(weight, K.Weight(obs.ids[i], concept)) end
            ranked[#ranked + 1] = { i=i, weight=weight }
        end
    end
    table.sort(ranked, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.i < b.i -- stable public tie break, no private seed
    end)
    return ranked, #meanings > 0
end

function AI.Agent(observation, profile)
    local obs, reason = CopyObservation(observation)
    local policy = profiles[profile or "partner"]
    if not obs then return nil, reason end
    if not policy then return nil, "profile_invalid" end
    if obs.phase ~= "G" then return nil, "phase_invalid" end
    local ranked, known = Rank(obs, obs.clue)
    if not known then return { kind="PASS" }, "unknown_clue" end
    local first = ranked[1]
    if not first or first.weight < policy.minimum then return { kind="PASS" }, "weak_association" end
    -- A numbered group may contain equally plausible cards. Only its boundary
    -- needs a margin; zero is conservative and treats the next guess individually.
    local group = obs.n == 0 and 1 or math.min(obs.n, #ranked)
    local boundary, nextCard = ranked[group], ranked[group + 1]
    if not boundary or boundary.weight < policy.minimum
        or (nextCard and boundary.weight - nextCard.weight < policy.margin) then
        return { kind="PASS" }, "ambiguous_clue"
    end
    return { kind="GUESS", i=first.i }, "word_association"
end

function AI.NewSpySearch(observation, key, profile)
    local obs, reason = CopyObservation(observation)
    local policy = profiles[profile or "partner"]
    if not obs then return nil, reason end
    if not policy then return nil, "profile_invalid" end
    if obs.phase ~= "C" then return nil, "phase_invalid" end
    if type(key) ~= "string" or #key ~= 25 or key:find("[^RBNX]") then return nil, "key_invalid" end
    local counts = { R=0, B=0, N=0, X=0 }
    for i = 1, 25 do local color = key:sub(i, i); counts[color] = counts[color] + 1 end
    if counts.R ~= 9 or counts.B ~= 8 or counts.N ~= 7 or counts.X ~= 1 then return nil, "key_invalid" end
    for i = 1, 25 do
        if not K.HasWord(obs.ids[i]) then return nil, "word_uncovered" end
        local revealed = obs.mask:sub(i, i)
        if revealed ~= "." and revealed ~= key:sub(i, i) then return nil, "key_invalid" end
    end
    return { observation=obs, key=key, profile=profile or "partner", cursor=1,
        forbidden=assert(C.PrepareBoard(obs.ids)),
        candidates=K.GetConceptIds(), evaluated=0, done=false }
end

local function Evaluate(job, text)
    local obs, policy = job.observation, profiles[job.profile]
    local clue = C.ValidatePrepared(job.forbidden, text)
    if not clue then return end
    local ranked = Rank(obs, clue)
    local own, weight = 0, 0
    local assassin, wrong = 0, 0
    for _, card in ipairs(ranked) do
        local color = job.key:sub(card.i, card.i)
        if color == "X" then assassin = math.max(assassin, card.weight)
        elseif color ~= obs.team then wrong = math.max(wrong, card.weight) end
    end
    for n = 1, math.min(policy.group, #ranked) do
        local card = ranked[n]
        if job.key:sub(card.i, card.i) ~= obs.team or card.weight < policy.minimum then break end
        own, weight = own + 1, weight + card.weight
        local nextCard = ranked[n + 1]
        if not nextCard or card.weight - nextCard.weight >= policy.margin then
            -- Reward useful groups; prefer distance from dangerous alternate readings.
            local utility = own * 100 + weight - wrong * 0.6 - assassin * 1.5
            if not job.utility or utility > job.utility then
                job.utility = utility
                job.best = { kind="CLUE", c=clue, n=n }
            end
        end
    end
end

-- Each step has a strict operation bound. Engine may later schedule these steps.
-- Search owns private state; only its public action may be given to the Agent.
function AI.StepSpy(job, candidateBudget)
    if type(job) ~= "table" or not profiles[job.profile] or type(job.observation) ~= "table"
        or type(job.key) ~= "string" or #job.key ~= 25 or type(job.candidates) ~= "table"
        or type(job.forbidden) ~= "table"
        or not C.IsInteger(job.cursor, 1, #job.candidates + 1) then
        return nil, nil, "job_invalid"
    end
    local budget = candidateBudget or 4
    if not C.IsInteger(budget, 1, 8) then return nil, nil, "budget_invalid" end
    if not job.done then
        for _ = 1, budget do
            local concept = job.candidates[job.cursor]
            if not concept then job.done = true break end
            Evaluate(job, K.Clue(concept, job.observation.locale))
            job.cursor, job.evaluated = job.cursor + 1, job.evaluated + 1
        end
        if job.cursor > #job.candidates then job.done = true end
    end
    if not job.done then return false end
    if not job.best then return true, nil, "no_safe_clue" end
    -- Return a fresh action, never job.best or private diagnostics by reference.
    return true, { kind="CLUE", c=job.best.c, n=job.best.n }
end

function AI.CheckHumanClue(observation, text, number)
    local obs, reason = CopyObservation(observation)
    if not obs then return nil, reason end
    if obs.phase ~= "C" then return nil, "phase_invalid" end
    local clue, invalid = C.Validate(obs.ids, text)
    if not clue then return nil, invalid end
    if not C.IsInteger(number, 0, 9) then return nil, "clue_number" end
    if #K.Resolve(clue, obs.locale) == 0 then return nil, "unknown_clue" end
    return { kind="CLUE", c=clue, n=number }
end
