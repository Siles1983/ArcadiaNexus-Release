-- ============================================================
--  Azeroth's Tiny Guardians – Logic.lua
--  Bedürfnis-System, Interaktionen, XP (rein — kein UI, kein DB)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_Logic = {}
local L = ArcadiaNexus.ATG_Logic

local MIN_HEALTH = 5

local DECAY = {
    hunger    = 3,
    happiness = 2,
    energy    = 2,
    hygiene   = 1.5,
}

L.BASE_XP = {
    feed  = 8,
    sleep = 10,
    wash  = 6,
    train = 12,
    heal  = 7,
    pet   = 5,
}

L.ACTION_META = {
    feed  = { cd = 30,  trait = "fed" },
    sleep = { cd = 120, trait = "slept", startsSleep = true, sleepDur = 20 },
    wash  = { cd = 45,  trait = "washed" },
    train = { cd = 60,  trait = "trained" },
    heal  = { cd = 90,  trait = "healed" },
    pet   = { cd = 15,  trait = "petted" },
}

L.ACTION_ORDER = { "feed", "pet", "sleep", "wash", "train", "heal" }

L.STAGE_XP = {
    BABY  = 200,
    YOUTH = 600,
    ADULT = nil,
}

L.TRAIT_RULES = {
    { id = "GREEDY",        counter = "fed",     min = 20 },
    { id = "PICKY",         counter = "washed",  min = 20 },
    { id = "WARRIOR",       counter = "trained", min = 20 },
    { id = "CLINGY",        counter = "petted",  min = 25 },
    { id = "HYPOCHONDRIAC", counter = "healed",  min = 15 },
    { id = "LAZY",          counter = "slept",   min = 18 },
}

L.BALANCED_MAX_COUNTER = 15
L.NEEDS_INTERVAL = 60
L.OFFLINE_MAX_SEC = 3600

local function ClampNeed(val)
    if val < 0 then return 0 end
    if val > 100 then return 100 end
    return val
end

function L:HasTrait(state, traitId)
    if not state or not state.traits then return false end
    for _, t in ipairs(state.traits) do
        if t == traitId then return true end
    end
    return false
end

function L:GetDominantTrait(state)
    if not state or not state.traitCounters then return nil end
    local c = state.traitCounters
    local bestId, bestVal = nil, 0
    for _, rule in ipairs(self.TRAIT_RULES) do
        if self:HasTrait(state, rule.id) then
            local v = c[rule.counter] or 0
            if v > bestVal then
                bestVal = v
                bestId = rule.id
            end
        end
    end
    if bestId then return bestId end
    if self:HasTrait(state, "BALANCED") then return "BALANCED" end
    return nil
end

function L:BuildTitle(state)
    if not state then return nil end
    local P = ArcadiaNexus.ATG_PetData
    if not P then return state.name end
    local dominant = self:GetDominantTrait(state)
    return P:GetTitle(state.petType, dominant)
end

function L:_IsBalanced(counters)
    for _, rule in ipairs(self.TRAIT_RULES) do
        if (counters[rule.counter] or 0) > self.BALANCED_MAX_COUNTER then
            return false
        end
    end
    return true
end

function L:_RecalcPersonality(state)
    if not state or not state.traitCounters then return end
    local c = state.traitCounters
    local traits = {}

    for _, rule in ipairs(self.TRAIT_RULES) do
        if (c[rule.counter] or 0) > rule.min then
            traits[#traits + 1] = rule.id
        end
    end
    if self:_IsBalanced(c) then
        traits[#traits + 1] = "BALANCED"
    end

    state.traits = traits
    state.dominantTrait = self:GetDominantTrait(state)
    if state.stage == "ADULT" then
        state.title = self:BuildTitle(state)
    else
        state.title = nil
    end
end

function L:_GetDecayRate(state, needKey)
    local rate = DECAY[needKey] or 0
    if needKey == "hunger" and self:HasTrait(state, "GREEDY") then
        rate = rate * 1.5
    elseif needKey == "hygiene" and self:HasTrait(state, "PICKY") then
        rate = rate * 1.3
    elseif needKey == "energy" then
        if self:HasTrait(state, "WARRIOR") then
            rate = rate * 1.3
        elseif self:HasTrait(state, "LAZY") then
            rate = rate * 0.6
        end
    elseif needKey == "happiness" and self:HasTrait(state, "CLINGY") then
        rate = rate * 1.5
    end
    return rate
end

function L:BuildStallEntry(state)
    if not state then return nil end
    self:_RecalcPersonality(state)
    local traitsCopy = {}
    if state.traits then
        for i, t in ipairs(state.traits) do
            traitsCopy[i] = t
        end
    end
    local ts = time()
    return {
        id            = state.id,
        petType       = state.petType,
        name          = state.name,
        title         = state.title or self:BuildTitle(state),
        stage         = state.stage or "ADULT",
        traits        = traitsCopy,
        dominantTrait = state.dominantTrait,
        xp            = state.xp,
        traitCounters = self:_DeepCopyCounters(state.traitCounters),
        status        = "retired",
        retiredAt     = ts,
        retiredAtText = date and date("%d.%m.%Y", ts) or tostring(ts),
    }
end

function L:CanRetire(state, phase)
    return state and state.stage == "ADULT" and phase == "ACTIVE"
end

function L:_DeepCopyCounters(counters)
    if not counters then return {} end
    return {
        fed = counters.fed or 0,
        washed = counters.washed or 0,
        trained = counters.trained or 0,
        petted = counters.petted or 0,
        healed = counters.healed or 0,
        slept = counters.slept or 0,
    }
end

local function TrimName(name)
    if type(name) ~= "string" then return "" end
    return (name:gsub("^%s+", ""):gsub("%s+$", ""))
end

function L:NewPetId()
    return string.format("atg-%d-%04d", time(), math.random(0, 9999))
end

function L:NewPetState(petType, name)
    local P = ArcadiaNexus.ATG_PetData
    if not P or not P:IsValidType(petType) then return nil end
    local defaultName = P:GetDefaultName(petType)
    local petName = TrimName(name)
    if petName == "" then petName = defaultName end
    return {
        id            = self:NewPetId(),
        status        = "living",
        petType       = petType,
        name          = petName,
        stage         = "BABY",
        xp            = 0,
        needs = {
            hunger    = 80,
            happiness = 70,
            energy    = 90,
            health    = 100,
            hygiene   = 100,
        },
        traitCounters = {
            fed = 0, washed = 0, trained = 0,
            petted = 0, healed = 0, slept = 0,
        },
        traits    = {},
        cooldowns = {
            feed = 0, sleep = 0, wash = 0,
            train = 0, heal = 0, pet = 0,
        },
        lastPausedAt = time(),
    }
end

function L:GetOfflineElapsed(state)
    local t = state and state.lastPausedAt
    if type(t) ~= "number" or t < 1000000000 then return 0 end
    return math.max(0, time() - t)
end

function L:ApplyOfflineTime(state, elapsedSec)
    if not state or not state.needs then return 0 end
    if state.status == "retired" then return 0 end
    elapsedSec = tonumber(elapsedSec) or 0
    if elapsedSec < 0 then elapsedSec = 0 end
    if elapsedSec > self.OFFLINE_MAX_SEC then
        elapsedSec = self.OFFLINE_MAX_SEC
    end
    local ticks = math.floor(elapsedSec / self.NEEDS_INTERVAL)
    for _ = 1, ticks do
        self:TickNeeds(state)
    end
    self:TickCooldowns(state, elapsedSec)
    return elapsedSec
end

function L:GetXpProgress(state)
    if not state then return 0, 1, 0 end
    local xp = state.xp or 0
    if state.stage == "BABY" then
        return xp, self.STAGE_XP.BABY, xp / self.STAGE_XP.BABY
    elseif state.stage == "YOUTH" then
        local base = self.STAGE_XP.BABY
        return xp - base, self.STAGE_XP.YOUTH - base, (xp - base) / (self.STAGE_XP.YOUTH - base)
    end
    return 1, 1, 1
end

function L:_HappinessMultiplier(happiness)
    happiness = happiness or 0
    if happiness >= 80 then return 1.5 end
    if happiness >= 50 then return 1.0 end
    if happiness >= 20 then return 0.6 end
    return 0.3
end

function L:GainXP(state, action)
    if not state then return nil end
    local base = self.BASE_XP[action] or 5
    local mult = self:_HappinessMultiplier(state.needs and state.needs.happiness)
    local xp = math.floor(base * mult)
    if self:HasTrait(state, "BALANCED") then
        xp = math.floor(xp * 1.1)
    end
    if action == "train" and self:HasTrait(state, "LAZY") then
        xp = math.floor(xp * 0.7)
    end
    state.xp = (state.xp or 0) + xp
    return self:_CheckEvolution(state)
end

function L:EnsureStageFromXp(state)
    if not state then return end
    local xp = state.xp or 0
    if xp >= self.STAGE_XP.YOUTH then
        state.stage = "ADULT"
    elseif xp >= self.STAGE_XP.BABY then
        state.stage = "YOUTH"
    else
        state.stage = "BABY"
    end
    self:_RecalcPersonality(state)
end

function L:_CheckEvolution(state)
    if not state then return nil end
    if state.stage == "BABY" and (state.xp or 0) >= self.STAGE_XP.BABY then
        return self:_Evolve(state, "YOUTH")
    end
    if state.stage == "YOUTH" and (state.xp or 0) >= self.STAGE_XP.YOUTH then
        return self:_Evolve(state, "ADULT")
    end
    return nil
end

function L:_Evolve(state, newStage)
    state.stage = newStage
    self:_RecalcPersonality(state)
    if ArcadiaNexus.Engine and ArcadiaNexus.Engine.Emit then
        ArcadiaNexus.Engine:Emit("ATG_EVOLVED", {
            stage   = newStage,
            petType = state.petType,
            xp      = state.xp,
        })
    end
    return newStage
end

function L:CanPerformAction(state, action, phase)
    if not state or not self.ACTION_META[action] then
        return false, "invalid"
    end
    if phase == "SLEEPING" then
        return false, "sleeping"
    end
    if phase ~= "ACTIVE" then
        return false, "busy"
    end
    local cd = state.cooldowns and state.cooldowns[action] or 0
    if cd > 0 then
        return false, "cooldown"
    end
    if action == "train" then
        local happy = state.needs and state.needs.happiness or 0
        if happy < 15 then
            return false, "train_sad"
        end
        local energy = state.needs and state.needs.energy or 0
        if energy < 10 then
            return false, "too_tired"
        end
    end
    return true
end

function L:ApplyAction(state, action)
    local meta = self.ACTION_META[action]
    local n = state.needs
    if action == "feed" then
        n.hunger    = ClampNeed(n.hunger + 35)
        n.happiness = ClampNeed(n.happiness + 5)
        n.energy    = ClampNeed(n.energy - 5)
        if self:HasTrait(state, "GREEDY") then
            n.happiness = ClampNeed(n.happiness + 5)
        end
    elseif action == "sleep" then
        n.energy    = ClampNeed(n.energy + 50)
        n.happiness = ClampNeed(n.happiness + 10)
    elseif action == "wash" then
        n.hygiene   = ClampNeed(n.hygiene + 60)
        n.happiness = ClampNeed(n.happiness + 8)
    elseif action == "train" then
        n.energy    = ClampNeed(n.energy - 20)
        n.happiness = ClampNeed(n.happiness + 15)
        n.health    = ClampNeed(n.health + 5)
    elseif action == "heal" then
        n.health = ClampNeed(n.health + 40)
        if self:HasTrait(state, "HYPOCHONDRIAC") then
            n.happiness = ClampNeed(n.happiness + 15)
        elseif self:HasTrait(state, "PICKY") then
            n.happiness = ClampNeed(n.happiness - 10)
        else
            n.happiness = ClampNeed(n.happiness - 5)
        end
    elseif action == "pet" then
        n.happiness = ClampNeed(n.happiness + 20)
    end

    if meta.trait and state.traitCounters then
        state.traitCounters[meta.trait] = (state.traitCounters[meta.trait] or 0) + 1
    end

    local cd = meta.cd
    if action == "train" and self:HasTrait(state, "WARRIOR") then
        cd = math.floor(cd * 0.7)
    end
    state.cooldowns[action] = cd

    if state.stage == "YOUTH" or state.stage == "ADULT" then
        self:_RecalcPersonality(state)
    end

    return {
        startsSleep = meta.startsSleep,
        sleepDur    = meta.sleepDur,
    }
end

function L:TickNeeds(state)
    if not state or not state.needs then return end
    local n = state.needs

    n.hunger    = ClampNeed(n.hunger    - self:_GetDecayRate(state, "hunger"))
    n.happiness = ClampNeed(n.happiness - self:_GetDecayRate(state, "happiness"))
    n.energy    = ClampNeed(n.energy    - self:_GetDecayRate(state, "energy"))
    n.hygiene   = ClampNeed(n.hygiene   - self:_GetDecayRate(state, "hygiene"))

    if n.hunger < 20 then
        n.health = ClampNeed(n.health - 1)
    end
    if self:HasTrait(state, "HYPOCHONDRIAC") and n.health > MIN_HEALTH and n.health < 50 then
        n.health = ClampNeed(n.health - 1)
    end
    if n.hygiene < 15 then
        n.happiness = ClampNeed(n.happiness - 2)
    end
    if n.health < 20 then
        n.happiness = ClampNeed(n.happiness - 3)
    end

    if n.health < MIN_HEALTH then
        n.health = MIN_HEALTH
    end
end

function L:TickCooldowns(state, dt)
    if not state or not state.cooldowns then return end
    for k, v in pairs(state.cooldowns) do
        if v > 0 then
            state.cooldowns[k] = math.max(0, v - dt)
        end
    end
end

function L:RegenEnergy(state, amount)
    if not state or not state.needs then return end
    state.needs.energy = ClampNeed(state.needs.energy + amount)
end

function L:NeedsForcedRest(state)
    return state and state.needs and state.needs.energy < 10
end

function L:ForcedRestComplete(state)
    return state and state.needs and state.needs.energy >= 30
end

function L:GetCriticalMood(state, phase)
    if not state or not state.needs then return nil end
    local n = state.needs
    if phase == "SLEEPING" then return "tired" end
    if (n.health or 100) < 25 then return "sick" end
    if (n.hunger or 100) < 30 then return "hungry" end
    if (n.hygiene or 100) < 20 then return "dirty" end
    if (n.happiness or 100) < 20 then return "angry" end
    if (n.energy or 100) < 20 then return "tired" end
    return nil
end

function L:GetMoodEmote(state, phase, lastAction)
    if lastAction == "pet" then return "hearts" end
    if lastAction == "sleep" then return "sleep" end
    if lastAction == "train" then return "hearts" end

    if not state or not state.needs then return nil end
    local n = state.needs
    if phase == "SLEEPING" or (n.energy or 100) < 20 then return "sleep" end
    if (n.health or 100) < 25 then return "sick" end
    if (n.hunger or 100) < 30 then return "question" end
    if (n.happiness or 100) < 20 then return "anger" end
    if (n.happiness or 100) > 80 then return "hearts" end
    return nil
end
