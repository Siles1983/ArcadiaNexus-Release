-- Regular solo difficulty. Exact reference AI and human partner remain untouched.
local A = ArcadiaNexus
local Ref, C, K = A.SI7_AI, A.SI7_Clues, A.SI7_RestraintKnowledge
local AI = { VERSION=1 }
A.SI7_RestraintAI = AI
local policies = {
    easy={ minimum=65, margin=15, group=2, cap=1 },
    normal={ minimum=55, margin=10, group=3, cap=2 },
}

local function Rank(obs, clue)
    local meanings, ranked = K.Resolve(clue, obs.locale), {}
    for i=1,25 do
        if obs.mask:sub(i,i) == "." then
            local weight = 0
            for _, concept in ipairs(meanings) do weight = math.max(weight,K.Weight(obs.ids[i],concept)) end
            ranked[#ranked+1] = { i=i, weight=weight }
        end
    end
    table.sort(ranked,function(a,b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.i < b.i
    end)
    return ranked, #meanings > 0
end

function AI.Agent(observation, context, profile)
    -- Reuse the reference's explicit allowlist validator. Its decision is discarded.
    local validated, reason = Ref.Agent(observation, profile)
    if not validated then return nil, reason end
    local policy = policies[profile]
    if not policy then return nil, "profile_invalid" end
    if type(context) ~= "table" or not C.IsInteger(context.attempts,0,9) then return nil,"context_invalid" end
    local attempts = context.attempts -- sole public context field; ignore private extras
    if attempts >= policy.cap then return {kind="PASS"},"attempt_limit" end
    local ranked, known = Rank(observation, observation.clue)
    if not known then return {kind="PASS"},"unknown_clue" end
    if not ranked[1] or ranked[1].weight < policy.minimum then return {kind="PASS"},"weak_association" end
    local n = observation.n == 0 and 1 or math.min(observation.n,#ranked)
    if not ranked[n] or ranked[n].weight < policy.minimum
        or (ranked[n+1] and ranked[n].weight-ranked[n+1].weight < policy.margin) then
        return {kind="PASS"},"ambiguous_clue"
    end
    return {kind="GUESS",i=ranked[1].i},"word_association"
end

function AI.NewSpySearch(observation,key,profile)
    if not policies[profile] then return nil,"profile_invalid" end
    -- Reference constructor validates and copies public observation/private key.
    local job, reason = Ref.NewSpySearch(observation,key,profile)
    if not job then return nil,reason end
    job.candidates = K.GetConceptIds()
    return job
end

local function Evaluate(job,text)
    local obs, policy = job.observation, policies[job.profile]
    local clue = C.ValidatePrepared(job.forbidden,text)
    if not clue then return end
    local ranked = Rank(obs,clue)
    local wrong, assassin, total = 0,0,0
    for _, card in ipairs(ranked) do
        local color = job.key:sub(card.i,card.i)
        if color == "X" then assassin = math.max(assassin,card.weight)
        elseif color ~= obs.team then wrong = math.max(wrong,card.weight) end
    end
    -- Full exact semantics. Does not invoke Agent, inspect attempts or simulate caps.
    for n=1,math.min(policy.group,#ranked) do
        local card = ranked[n]
        if job.key:sub(card.i,card.i) ~= obs.team or card.weight < policy.minimum then break end
        total = total + card.weight
        if not ranked[n+1] or card.weight-ranked[n+1].weight >= policy.margin then
            local utility = n*100+total-wrong*.6-assassin*1.5
            if not job.utility or utility > job.utility then
                job.utility, job.best = utility, {kind="CLUE",c=clue,n=n}
            end
        end
    end
end

function AI.StepSpy(job,budget)
    if type(job) ~= "table" or not policies[job.profile] or type(job.observation) ~= "table"
        or type(job.key) ~= "string" or #job.key ~= 25 or type(job.candidates) ~= "table"
        or type(job.forbidden) ~= "table" or not C.IsInteger(job.cursor,1,#job.candidates+1) then
        return nil,nil,"job_invalid"
    end
    budget = budget or 4
    if not C.IsInteger(budget,1,8) then return nil,nil,"budget_invalid" end
    if not job.done then
        for _=1,budget do
            local concept = job.candidates[job.cursor]
            if not concept then job.done=true break end
            Evaluate(job,K.Clue(concept,job.observation.locale))
            job.cursor,job.evaluated = job.cursor+1,job.evaluated+1
        end
        if job.cursor > #job.candidates then job.done=true end
    end
    if not job.done then return false end
    if not job.best then return true,nil,"no_safe_clue" end
    return true,{kind="CLUE",c=job.best.c,n=job.best.n}
end
