-- Hangman puzzle registry, validation and repeat-safe selection.

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.HGM_Words = {}
local W = ArcadiaNexus.HGM_Words

W.CATEGORIES = {
    "chars", "places", "weapons", "raids", "dungeons", "classes",
    "races", "bosses", "factions", "creatures", "professions",
}

local CATEGORY_SET = {}
for _, id in ipairs(W.CATEGORIES) do CATEGORY_SET[id] = true end

local DIFFICULTY_SET = { easy=true, normal=true, hard=true }
local entries, entriesByCategory = {}, {}
local localeData, bags, lastPicked = {}, {}, {}

for _, id in ipairs(W.CATEGORIES) do entriesByCategory[id] = {} end

local function AddMany(category, difficulty, ids)
    assert(CATEGORY_SET[category], "Unknown Hangman category: " .. tostring(category))
    assert(DIFFICULTY_SET[difficulty], "Unknown Hangman difficulty: " .. tostring(difficulty))
    for _, id in ipairs(ids) do
        local entry = { id=id, category=category, difficulty=difficulty }
        entries[#entries+1] = entry
        entriesByCategory[category][#entriesByCategory[category]+1] = entry
    end
end

-- Stable puzzle IDs. Localized answers and clues live in Words_deDE/enUS.lua.
AddMany("chars", "easy", {
    "ARTHAS", "THRALL", "JAINA", "ANDUIN", "BOLVAR", "MAGNI", "VARIAN",
    "YSERA", "XAVIUS", "AZSHARA",
})
AddMany("chars", "normal", {
    "SYLVANAS", "ILLIDAN", "TYRANDE", "KHADGAR", "GARROSH", "GULDAN",
    "MEDIVH", "KALECGOS", "SARGERAS", "CENARIUS", "RAGNAROS", "NEFARIAN",
})
AddMany("chars", "hard", {
    "MALFURION", "DEATHWING", "ALEXSTRASZA", "NOZDORMU", "ARCHIMONDE",
    "KILJAEDEN", "CTHUN", "YOGGSARON",
})

AddMany("places", "easy", {
    "DALARAN", "EXODAR", "PANDARIA", "ZANDALAR",
})
AddMany("places", "normal", {
    "STORMWIND", "ORGRIMMAR", "DARNASSUS", "UNDERCITY", "SILVERMOON",
    "ICECROWN", "BLACKROCK", "STRATHOLME", "LORDAERON", "OUTLAND", "NORTHREND",
})
AddMany("places", "hard", {
    "IRONFORGE", "THUNDERBLUFF",
})

AddMany("weapons", "easy", {
    "SULFURAS", "VALANYR", "ATIESH", "XALATATH",
})
AddMany("weapons", "normal", {
    "FROSTMOURNE", "ASHBRINGER", "THUNDERFURY", "TAESHALACH", "THORIIDAL", "SHALAMAYNE",
})
AddMany("weapons", "hard", {
    "SHADOWMOURNE", "DOOMHAMMER",
})

AddMany("raids", "easy", { "KARAZHAN", "NAXXRAMAS", "ULDUAR", "AHNQIRAJ" })
AddMany("raids", "normal", { "MOLTENCORE", "BLACKTEMPLE" })
AddMany("raids", "hard", { "ICECROWNCITADEL", "SUNWELLPLATEAU" })

AddMany("classes", "easy", { "PALADIN", "DRUID", "SHAMAN", "ROGUE", "MAGE", "MONK", "EVOKER" })
AddMany("classes", "normal", { "WARLOCK", "HUNTER", "PRIEST", "WARRIOR" })
AddMany("classes", "hard", { "DEATHKNIGHT", "DEMONHUNTER" })

AddMany("races", "easy", { "WORGEN", "GOBLIN", "PANDAREN", "DRAENEI" })

-- Extended full-game catalog.
AddMany("chars", "easy", { "BAINE", "VELEN", "VOLJIN", "MURADIN", "REXXAR", "UTHER", "TIRION" })
AddMany("chars", "normal", { "GREYMANE", "TURALYON", "ALLERIA", "LORTHEMAR", "GALLYWIX", "MATHIAS", "MAIEV" })
AddMany("chars", "hard", { "AKAMA", "KAELTHAS", "VASHJ", "NATHANOS", "ORWEYNA", "MAYLA", "THALYSSRA" })

AddMany("places", "easy", { "SHATTRATH", "SURAMAR", "GILNEAS", "KEZAN", "TANARIS", "BORALUS" })
AddMany("places", "normal", { "KULTIRAS", "DAZARALOR", "REVENDRETH", "BASTION", "MALDRAXXUS", "ARDENWEALD" })
AddMany("places", "hard", { "DRAGONISLES", "BROKENISLES", "SHADOWLANDS", "DRAGONBLIGHT", "TELDRASSIL" })

AddMany("weapons", "easy", { "GOREHOWL", "GORSHALACH", "ASHKANDI", "SHADOWFANG" })
AddMany("weapons", "normal", { "SCYTHEOFELUNE", "FEARBREAKER", "DRAGONWRATH", "QUELDELAR", "APOCALYPSE" })
AddMany("weapons", "hard", { "WARGLAIVES", "KINGSMOURNE", "HAMMEROFNAARU", "FANGSOFTHEFATHER" })

AddMany("raids", "easy", { "FIRELANDS", "NIGHTHOLD", "ANTORUS", "NYALOTHA" })
AddMany("raids", "normal", { "BLACKWINGLAIR", "TEMPESTKEEP", "DRAGONSOUL", "CASTLENATHRIA" })
AddMany("raids", "hard", { "MOUNTHYJAL", "SERPENTSHRINE", "TRIALOFTHECRUSADER", "SIEGEORGRIMMAR" })

AddMany("dungeons", "easy", { "DEADMINES", "STOCKADE", "ULDAMAN", "MARADON", "MECHAGON", "GRIMBATOL" })
AddMany("dungeons", "normal", { "SHADOWFANGKEEP", "SCARLETMONASTERY", "DIREMAUL", "MAGISTERSTERRACE", "THEOCULUS", "FREEHOLD", "NECROTICWAKE" })
AddMany("dungeons", "hard", { "WAILINGCAVERNS", "RAZORFENDOWNS", "BLACKROCKDEPTHS", "AUCHENAICRYPTS", "VIOLETHOLD", "WAYCRESTMANOR", "DAWNOFTHEINFINITE" })

AddMany("races", "easy", { "HUMANS", "DWARVES", "GNOMES", "ORCS", "UNDEAD", "TAUREN", "TROLLS", "VULPERA", "EARTHEN", "HARANIR" })
AddMany("races", "normal", { "NIGHTELVES", "DRACTHYR", "BLOODELVES", "VOIDELVES", "KULTIRANS", "MECHAGNOMES", "NIGHTBORNE" })
AddMany("races", "hard", { "LIGHTFORGED", "DARKIRONDWARVES", "HIGHMOUNTAINTAUREN", "MAGHARORCS", "ZANDALARITROLLS" })

AddMany("bosses", "easy", { "ONYXIA", "MALYGOS", "GRUUL", "MAGTHERIDON", "HOGGER", "MANNOROTH", "ODYN", "ARGUS", "DENATHRIUS", "FYRAKK", "DIMENSIUS" })
AddMany("bosses", "normal", { "KELTHUZAD", "ANUBARAK", "LEOTHERAS", "PATCHWERK", "SUPREMUS", "MIMIRON", "ALGALON", "LEISHEN", "BLACKHAND", "KROSUS", "RAZAGETH", "ANSUREK" })
AddMany("bosses", "hard", { "CHOGALL", "IMPERATORMARGOK", "KAZZAK", "BRUTALLUS", "NZOTH", "RYGELON", "JAILER", "KILROGG", "ZAQUL", "THELICHKING", "THOK", "URSOC" })

AddMany("factions", "easy", { "ALLIANCE", "HORDE", "KIRINTOR", "ILLIDARI", "ARGENTDAWN", "EARTHENRING" })
AddMany("factions", "normal", { "SILVERHAND", "EBONBLADE", "CENARIONCIRCLE", "BILGEWATERCARTEL", "STEAMWHEEDLE", "WARDENS", "VALARJAR" })
AddMany("factions", "hard", { "BURNINGLEGION", "TWILIGHTSHAMMER", "SCARLETCRUSADE", "DRAGONASPECTS", "SHATTEREDSUN", "BLACKDRAGONFLIGHT", "EXPLORERSLEAGUE" })

AddMany("creatures", "easy", { "MURLOC", "KOBOLD", "GNOLL", "HARPY", "QUILBOAR", "OGRE", "DRAGON", "BASILISK" })
AddMany("creatures", "normal", { "NERUBIAN", "GRONN", "NAGA", "TOLVIR" })
AddMany("creatures", "hard", { "MAGNATAUR", "ELEMENTAL", "DREADLORD" })

AddMany("professions", "easy", { "MINING", "HERBALISM", "SKINNING", "COOKING", "FISHING" })
AddMany("professions", "normal", { "ALCHEMY", "BLACKSMITHING", "ENCHANTING", "ENGINEERING", "INSCRIPTION" })
AddMany("professions", "hard", { "LEATHERWORKING", "TAILORING", "JEWELCRAFTING", "ARCHAEOLOGY", "FIRSTAID" })

function W:RegisterLocale(locale, data)
    localeData[locale] = data
    ArcadiaNexus.RegisterLocale("HANGMAN_WORDS", locale, data)
end

function W:IsValidCategory(category)
    return category == "all" or CATEGORY_SET[category] == true
end

function W:GetCategories()
    local CL = ArcadiaNexus.GetLocaleTable("HANGMAN_CATEGORIES")
    local result = { { id="all", label=CL.cat_all } }
    for _, id in ipairs(W.CATEGORIES) do
        result[#result+1] = { id=id, label=CL["cat_" .. id] }
    end
    return result
end

function W:GetEntries(category, difficulty)
    category = W:IsValidCategory(category) and category or "all"
    difficulty = DIFFICULTY_SET[difficulty] and difficulty or "normal"
    local source = category == "all" and entries or entriesByCategory[category]
    local result = {}
    for _, entry in ipairs(source) do
        if entry.difficulty == difficulty then result[#result+1] = entry end
    end
    -- Small specialist categories may not cover every tier yet.
    if #result == 0 then
        for _, entry in ipairs(source) do result[#result+1] = entry end
    end
    return result
end

local function Resolve(entry)
    local L = ArcadiaNexus.GetLocaleTable("HANGMAN_WORDS")
    local data = L[entry.id]
    if type(data) ~= "table" then return nil end
    return {
        id=entry.id, word=data.word, hint=data.hint,
        category=ArcadiaNexus.GetLocaleTable("HANGMAN_CATEGORIES")["cat_" .. entry.category],
        catID=entry.category, difficulty=entry.difficulty,
    }
end

function W:Pick(category, difficulty)
    local activeLocale = ArcadiaNexus.ActiveLocale or "enUS"
    local key = table.concat({ activeLocale, category or "all", difficulty or "normal" }, ":")
    local bag = bags[key]
    if not bag or bag.index > #bag.pool then
        local pool = W:GetEntries(category, difficulty)
        ArcadiaNexus.ArrayUtils.Shuffle(pool)
        if #pool > 1 and lastPicked[key] == pool[1].id then
            pool[1], pool[#pool] = pool[#pool], pool[1]
        end
        bag = { pool=pool, index=1 }
        bags[key] = bag
    end
    local entry = ArcadiaNexus.LevelPool.GetEntry({ active=bag.pool }, "active", bag.index)
    if not entry then return nil end
    bag.index = bag.index + 1
    lastPicked[key] = entry.id
    return Resolve(entry)
end

function W:Validate()
    local errors, seenIDs = {}, {}
    local seenWords = { deDE={}, enUS={} }
    for _, entry in ipairs(entries) do
        if seenIDs[entry.id] then errors[#errors+1] = "duplicate id: " .. entry.id end
        seenIDs[entry.id] = true
        for _, locale in ipairs({ "deDE", "enUS" }) do
            local data = localeData[locale] and localeData[locale][entry.id]
            if type(data) ~= "table" then
                errors[#errors+1] = locale .. " missing: " .. entry.id
            else
                if type(data.word) ~= "string" or data.word == "" then
                    errors[#errors+1] = locale .. " word missing: " .. entry.id
                elseif data.word:find("[^A-Z '%-]") then
                    errors[#errors+1] = locale .. " unplayable word: " .. entry.id
                elseif seenWords[locale][data.word] then
                    errors[#errors+1] = locale .. " duplicate word: " .. data.word
                else
                    seenWords[locale][data.word] = entry.id
                end
                if type(data.hint) ~= "string" or data.hint == "" then
                    errors[#errors+1] = locale .. " hint missing: " .. entry.id
                end
            end
        end
    end
    for _, category in ipairs(W.CATEGORIES) do
        for _, difficulty in ipairs({ "easy", "normal", "hard" }) do
            local found = false
            for _, entry in ipairs(entriesByCategory[category]) do
                if entry.difficulty == difficulty then found = true; break end
            end
            if not found then
                errors[#errors+1] = "empty pool: " .. category .. "/" .. difficulty
            end
        end
    end
    W.validationErrors = errors
    W.entryCount = #entries
    return #errors == 0, errors
end
