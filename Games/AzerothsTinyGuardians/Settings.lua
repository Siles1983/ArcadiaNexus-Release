-- ============================================================
--  Azeroth's Tiny Guardians – Settings.lua
--  Defaults + SavedVariables (pets collection, activePetId)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_Settings = {}
local S = ArcadiaNexus.ATG_Settings

S.Defaults = {
    soundEnabled     = true,
    soundOnInteract  = true,
    soundOnEvolve    = true,
    soundOnComment   = true,
    showSpeechBubble = true,
    showEmotes       = true,
}

local DB_KEY = "AZEROTHTINYGUARDIANS"

local function NewPetId()
    local Logic = ArcadiaNexus.ATG_Logic
    if Logic and Logic.NewPetId then return Logic:NewPetId() end
    return string.format("atg-%d-%04d", time(), math.random(0, 9999))
end

function S:_DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:_DeepCopy(v)
    end
    return copy
end

local function MigratePets(db)
    if db._petsMigrated then
        db.pets = db.pets or {}
        return
    end
    db.pets = db.pets or {}

    if db.activePet and db.activePet.petType then
        local p = S:_DeepCopy(db.activePet)
        p.id = p.id or NewPetId()
        p.status = p.status or "living"
        if type(p.lastPausedAt) ~= "number" or p.lastPausedAt < 1000000000 then
            p.lastPausedAt = time()
        end
        table.insert(db.pets, p)
        db.activePetId = db.activePetId or p.id
    end

    if type(db.stall) == "table" then
        for _, entry in ipairs(db.stall) do
            local p = S:_DeepCopy(entry)
            p.id = p.id or NewPetId()
            p.status = "retired"
            p.stage = p.stage or "ADULT"
            table.insert(db.pets, p)
        end
    end

    db.activePet = nil
    db.stall = nil
    db._petsMigrated = true
end

local function EnsureDB()
    if not _G.ArcadiaNexusDB then _G.ArcadiaNexusDB = {} end
    _G.ArcadiaNexusDB.gameSettings = _G.ArcadiaNexusDB.gameSettings or {}
    if not _G.ArcadiaNexusDB.gameSettings[DB_KEY] then
        _G.ArcadiaNexusDB.gameSettings[DB_KEY] = {}
    end
    local db = _G.ArcadiaNexusDB.gameSettings[DB_KEY]
    MigratePets(db)
    return db
end

function S:Get(key)
    local db = EnsureDB()
    if db[key] ~= nil then return db[key] end
    return self.Defaults[key]
end

function S:Set(key, value)
    EnsureDB()[key] = value
end

function S:Reset()
    local db = EnsureDB()
    for k in pairs(self.Defaults) do db[k] = nil end
end

function S:GetAll()
    local r = {}
    for k in pairs(self.Defaults) do r[k] = self:Get(k) end
    return r
end

function S:GetPets()
    return self:_DeepCopy(EnsureDB().pets or {})
end

function S:HasAnyPets()
    local pets = EnsureDB().pets
    return pets ~= nil and #pets > 0
end

function S:HasLivingPets()
    local pets = EnsureDB().pets or {}
    for _, p in ipairs(pets) do
        if p.status ~= "retired" then return true end
    end
    return false
end

function S:_FindPetIndex(id)
    if not id then return nil end
    local pets = EnsureDB().pets or {}
    for i, p in ipairs(pets) do
        if p.id == id then return i, p end
    end
    return nil
end

function S:GetPet(id)
    local _, pet = self:_FindPetIndex(id)
    return pet and self:_DeepCopy(pet) or nil
end

function S:UpsertPet(state)
    if not state or not state.petType then return end
    if not state.id then state.id = NewPetId() end
    state.status = state.status or "living"
    local db = EnsureDB()
    local idx = self:_FindPetIndex(state.id)
    local copy = self:_DeepCopy(state)
    if idx then
        db.pets[idx] = copy
    else
        table.insert(db.pets, copy)
    end
end

function S:SaveLivingPet(state)
    self:UpsertPet(state)
    EnsureDB().activePetId = state and state.id or nil
end

function S:RetirePet(id, entry)
    if not entry then return end
    local db = EnsureDB()
    entry.status = "retired"
    entry.id = entry.id or id
    local idx = self:_FindPetIndex(id or entry.id)
    local copy = self:_DeepCopy(entry)
    if idx then
        db.pets[idx] = copy
    else
        table.insert(db.pets, copy)
    end
    if db.activePetId == (id or entry.id) then
        db.activePetId = nil
    end
end

function S:SetActivePetId(id)
    EnsureDB().activePetId = id
end

function S:GetActivePetId()
    return EnsureDB().activePetId
end

function S:ClearActivePet()
    EnsureDB().activePetId = nil
end

-- Legacy wrappers (Engine/Renderer during migration)
function S:SaveActivePet(state)
    self:SaveLivingPet(state)
end

function S:LoadActivePet()
    local id = self:GetActivePetId()
    if id then
        local pet = self:GetPet(id)
        if pet and pet.status ~= "retired" then return pet end
    end
    local pets = EnsureDB().pets or {}
    for i = #pets, 1, -1 do
        if pets[i].status ~= "retired" then
            return self:_DeepCopy(pets[i])
        end
    end
    return nil
end

function S:HasActivePet()
    return self:LoadActivePet() ~= nil
end

function S:AppendToStall(entry)
    if not entry then return end
    self:RetirePet(entry.id, entry)
end

function S:GetStall()
    local retired = {}
    for _, p in ipairs(EnsureDB().pets or {}) do
        retired[#retired + 1] = self:_DeepCopy(p)
    end
    return retired
end

function S:GetRetiredPets()
    local retired = {}
    for _, p in ipairs(EnsureDB().pets or {}) do
        if p.status == "retired" then
            retired[#retired + 1] = self:_DeepCopy(p)
        end
    end
    return retired
end

function S:EnsureStats()
    local db = EnsureDB()
    if not db.stats then db.stats = {} end
    return db.stats
end

function S:RecordAdoption()
    local st = self:EnsureStats()
    st.adoptions = (st.adoptions or 0) + 1
end

function S:RecordAdultReached(state)
    local st = self:EnsureStats()
    st.adults = (st.adults or 0) + 1
    local Logic = ArcadiaNexus and ArcadiaNexus.ATG_Logic
    if state and Logic and Logic.HasTrait and Logic:HasTrait(state, "BALANCED") then
        st.balancedAdult = true
    end
end
