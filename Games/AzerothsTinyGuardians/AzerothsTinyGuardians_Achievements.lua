--[[
    ArcadiaNexus
    Games/AzerothsTinyGuardians/AzerothsTinyGuardians_Achievements.lua
    Achievements fuer Azeroth's Tiny Guardians (Kategorie: IDLE)
    Registriert via ArcadiaNexus.RegisterAchievements({...}).
]]

local ArcadiaNexus = _G.ArcadiaNexus

local GAME_ID = "AZEROTHTINYGUARDIANS"

local function getGS(db)
    return db and db.gameSettings and db.gameSettings[GAME_ID]
end

local function iterPets(db)
    local gs = getGS(db)
    if gs and type(gs.pets) == "table" and #gs.pets > 0 then
        return gs.pets
    end
    local out = {}
    if gs and gs.activePet then out[#out + 1] = gs.activePet end
    if gs and type(gs.stall) == "table" then
        for _, e in ipairs(gs.stall) do
            out[#out + 1] = e
        end
    end
    return out
end

local function collectionCount(db)
    return #iterPets(db)
end

local function retiredCount(db)
    local n = 0
    for _, p in ipairs(iterPets(db)) do
        if p.status == "retired" or (not p.status and p.retiredAt) then
            n = n + 1
        end
    end
    local gs = getGS(db)
    if gs and type(gs.stall) == "table" then
        n = math.max(n, #gs.stall)
    end
    return n
end

local function stallCount(db)
    return collectionCount(db)
end

local function adoptionCount(db)
    local gs = getGS(db)
    local st = gs and gs.stats
    if st and (st.adoptions or 0) >= 1 then return st.adoptions end
    return collectionCount(db) >= 1 and 1 or 0
end

local function adultCount(db)
    local gs = getGS(db)
    local st = gs and gs.stats
    if st and (st.adults or 0) >= 1 then return st.adults end
    for _, p in ipairs(iterPets(db)) do
        if p.stage == "ADULT" or p.status == "retired" or p.retiredAt then
            return 1
        end
    end
    return 0
end

local function uniqueStallTypes(db)
    local seen = {}
    local n = 0
    for _, e in ipairs(iterPets(db)) do
        if e.petType and not seen[e.petType] then
            seen[e.petType] = true
            n = n + 1
        end
    end
    return n
end

local function hasBalancedAdult(db)
    local gs = getGS(db)
    if not gs then return 0 end
    if gs.stats and gs.stats.balancedAdult then return 1 end
    for _, p in ipairs(iterPets(db)) do
        if p.traits then
            for _, t in ipairs(p.traits) do
                if t == "BALANCED" then return 1 end
            end
        end
    end
    return 0
end

ArcadiaNexus.RegisterAchievements({

    {
        id       = "ATG_FIRST_ADOPT",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "Erste Adoption",
        title_en = "First Adoption",
        desc_de  = "Adoptiere dein erstes Haustier.",
        desc_en  = "Adopt your first pet.",
        icon     = 656556, -- INV_Pet_BabyMurlocs_Blue
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return adoptionCount(db) >= 1 and 1 or 0
        end,
        tiers = {
            { id = "ATG_FIRST_ADOPT_BRONZE", tierName = "Bronze", target = 1, xp = 15,
              desc_de = "Erstes Pet adoptiert.", desc_en = "Adopted first pet." },
        },
    },

    {
        id       = "ATG_FIRST_ADULT",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "Erwachsen geworden",
        title_en = "All Grown Up",
        desc_de  = "Ziehe dein erstes Pet bis ADULT auf.",
        desc_en  = "Raise your first pet to ADULT.",
        icon     = "Interface\\Icons\\Achievement_Character_Nightelf_Female",
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return adultCount(db) >= 1 and 1 or 0
        end,
        tiers = {
            { id = "ATG_FIRST_ADULT_BRONZE", tierName = "Bronze", target = 1, xp = 20,
              desc_de = "Erstes Pet erreicht ADULT.", desc_en = "First pet reached ADULT." },
        },
    },

    {
        id       = "ATG_FIRST_RETIRE",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "In den Stall",
        title_en = "To the Barn",
        desc_de  = "Schicke dein erstes Pet in den Stall.",
        desc_en  = "Retire your first pet to the stall.",
        icon     = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Stack_01",
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return retiredCount(db)
        end,
        tiers = {
            { id = "ATG_FIRST_RETIRE_BRONZE", tierName = "Bronze", target = 1, xp = 25,
              desc_de = "Erstes Pet im Stall.", desc_en = "First pet in the stall." },
        },
    },

    {
        id       = "ATG_COLLECTOR_6",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "Sammler",
        title_en = "Collector",
        desc_de  = "Habe alle 6 Pet-Arten mindestens einmal im Stall.",
        desc_en  = "Have all 6 pet types in the stall at least once.",
        icon     = "Interface\\Icons\\INV_Misc_Pet_01",
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return uniqueStallTypes(db)
        end,
        tiers = {
            { id = "ATG_COLLECTOR_6_BRONZE", tierName = "Bronze", target = 6, xp = 50,
              desc_de = "Alle 6 Arten im Stall.", desc_en = "All 6 types in the stall." },
        },
    },

    {
        id       = "ATG_BALANCED",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "Ausgewogen",
        title_en = "Balanced Soul",
        desc_de  = "Ziehe ein Pet mit dem Trait BALANCED als ADULT auf.",
        desc_en  = "Raise a pet with the BALANCED trait to ADULT.",
        icon     = "Interface\\Icons\\Ability_Druid_BalanceofPower",
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return hasBalancedAdult(db)
        end,
        tiers = {
            { id = "ATG_BALANCED_BRONZE", tierName = "Bronze", target = 1, xp = 30,
              desc_de = "BALANCED-Pet als ADULT.", desc_en = "BALANCED pet as ADULT." },
        },
    },

    {
        id       = "ATG_STALL_10",
        gameId   = GAME_ID,
        category = "IDLE",
        title_de = "Tierhalter",
        title_en = "Keeper",
        desc_de  = "Habe 10 Pets im Stall.",
        desc_en  = "Have 10 pets in the stall.",
        icon     = "Interface\\Icons\\INV_Misc_Basket_01",
        condition = function(data, db)
            if data.gameId ~= GAME_ID then return 0 end
            return stallCount(db)
        end,
        tiers = {
            { id = "ATG_STALL_10_BRONZE", tierName = "Bronze", target = 10, xp = 60,
              desc_de = "10 Pets im Stall.", desc_en = "10 pets in the stall." },
        },
    },
})
