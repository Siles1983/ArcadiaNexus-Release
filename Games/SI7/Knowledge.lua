-- Editorial prototype corpus. Weights express associations, not probabilities.
-- Catalogue plus curated lore relationships; source/quality caveats in prototype docs.
local A = _G.ArcadiaNexus
local K = { VERSION = 10 }
A.SI7_Knowledge = K
local concepts, order, links, ids = {}, {}, {}, {}

local function Concept(id, de, en, deAliases, enAliases)
    concepts[id] = { deDE = de, enUS = en, aliases = {
        deDE = deAliases or {}, enUS = enAliases or {},
    } }
    order[#order + 1] = id
end
Concept("arcane", "ARKAN", "ARCANE", { "ZAUBEREI" }, { "SORCERY" })
Concept("frost", "EIS", "ICE", { "KAELTE", "FROST" }, { "COLD", "FROST" })
Concept("fire", "FEUER", "FIRE", { "FLAMME" }, { "FLAME" })
Concept("nature", "NATUR", "NATURE", { "WALD" }, { "FOREST" })
Concept("dream", "TRAUM", "DREAM")
Concept("light", "LICHT", "LIGHT", { "HEILIG" }, { "HOLY" })
Concept("shadow", "SCHATTEN", "SHADOW", { "DUNKELHEIT" }, { "DARKNESS" })
Concept("death", "TOD", "DEATH")
Concept("plague", "SEUCHE", "PLAGUE")
Concept("demon", "DAEMON", "DEMON", { "DAEMONEN" }, { "DEMONS" })
Concept("dragon", "DRACHE", "DRAGON", { "DRACHEN" }, { "DRAGONS" })
Concept("time", "ZEIT", "TIME")
Concept("sea", "MEER", "SEA", { "OZEAN" }, { "OCEAN" })
Concept("king", "KOENIG", "KING", { "KRONE" }, { "CROWN" })
Concept("queen", "KOENIGIN", "QUEEN")
Concept("war", "KRIEG", "WAR")
Concept("orc", "ORC", "ORC")
Concept("elf", "ELF", "ELF", { "ELFEN" }, { "ELVES" })
Concept("dwarf", "ZWERG", "DWARF", { "ZWERGE" }, { "DWARVES" })
Concept("titan", "TITAN", "TITAN", { "TITANEN" }, { "TITANS" })
Concept("city", "STADT", "CITY")
Concept("island", "INSEL", "ISLAND")
Concept("mountain", "BERG", "MOUNTAIN")
Concept("portal", "PORTAL", "PORTAL")
Concept("sword", "SCHWERT", "SWORD", { "KLINGE" }, { "BLADE" })
Concept("hammer", "HAMMER", "HAMMER")
Concept("axe", "AXT", "AXE")
Concept("bow", "BOGEN", "BOW")
Concept("staff", "STAB", "STAFF")
Concept("temple", "TEMPEL", "TEMPLE")
Concept("tower", "TURM", "TOWER")
Concept("prison", "GEFAENGNIS", "PRISON")
Concept("heal", "HEILUNG", "HEALING")
Concept("hunt", "JAGD", "HUNT")
Concept("stealth", "HEIMLICH", "STEALTH")
Concept("balance", "GLEICHGEWICHT", "BALANCE")
Concept("element", "ELEMENT", "ELEMENT", { "ELEMENTE" }, { "ELEMENTS" })
Concept("prince", "PRINZ", "PRINCE")
Concept("regent", "REGENT", "REGENT")
Concept("banshee", "BANSHEE", "BANSHEE")
Concept("moon", "MOND", "MOON")
Concept("speaker", "SPRECHER", "SPEAKER")
Concept("life", "LEBEN", "LIFE")
Concept("blue", "BLAU", "BLUE")
Concept("green", "GRUEN", "GREEN")
Concept("red", "ROT", "RED")
Concept("bronze", "BRONZE", "BRONZE")
Concept("black", "SCHWARZ", "BLACK")
Concept("warchief", "KRIEGSHAEUPTLING", "WARCHIEF")
Concept("traitor", "VERRAT", "BETRAYAL")
Concept("guardian", "HUETER", "GUARDIAN")
Concept("deceiver", "TAEUSCHUNG", "DECEPTION")
Concept("demigod", "HALBGOTT", "DEMIGOD")
Concept("madness", "WAHNSINN", "MADNESS")
Concept("human", "MENSCH", "HUMAN")
Concept("flying", "FLIEGEND", "FLYING")
Concept("fortress", "FESTUNG", "FORTRESS")
Concept("tree", "BAUM", "TREE")
Concept("crypt", "GRUFT", "CRYPT")
Concept("blood", "BLUT", "BLOOD")
Concept("cliff", "KLIPPE", "CLIFF")
Concept("spaceship", "RAUMSCHIFF", "SPACESHIP")
Concept("volcano", "VULKAN", "VOLCANO")
Concept("ruin", "RUINE", "RUIN")
Concept("continent", "KONTINENT", "CONTINENT")
Concept("north", "NORDEN", "NORTH")
Concept("hidden", "VERBORGEN", "HIDDEN")
Concept("troll", "TROLL", "TROLL")
Concept("soul", "SEELE", "SOUL")
Concept("wind", "WIND", "WIND")
Concept("fragment", "SPLITTER", "FRAGMENT")
Concept("ore", "ERZ", "ORE")
Concept("destiny", "SCHICKSAL", "DESTINY")
Concept("star", "STERN", "STAR")
Concept("necropolis", "NEKROPOLE", "NECROPOLIS")
Concept("shapeshift", "FORMWANDEL", "SHAPESHIFT")
Concept("summon", "BESCHWOERUNG", "SUMMONING")
Concept("thief", "DIEB", "THIEF")
Concept("beast", "TIER", "BEAST")
Concept("harmony", "HARMONIE", "HARMONY")
Concept("corruption", "VERDERBNIS", "CORRUPTION")
Concept("glaive", "GLEVE", "GLAIVE")
-- Differentiated properties; sources and editorial caveats in the prototype report.
Concept("experiment", "EXPERIMENT", "EXPERIMENT", { "VERSUCH" }, { "TEST" })
Concept("apprentice", "LEHRLING", "APPRENTICE", { "SCHUELER" }, { "PUPIL" })
Concept("opera", "OPER", "OPERA")
Concept("horde", "HORDE", "HORDE")
Concept("kingdom", "KOENIGREICH", "KINGDOM")
Concept("glide", "GLEITEN", "GLIDE")
Concept("canal", "KANAL", "CANAL")
Concept("tundra", "TUNDRA", "TUNDRA")
Concept("hyjal", "HYJAL", "HYJAL")
Concept("purify", "REINIGUNG", "PURIFICATION")
Concept("pantheon", "PANTHEON", "PANTHEON")
Concept("charge", "ANSTURM", "CHARGE")
Concept("teleport", "TELEPORT", "TELEPORT")
Concept("hand", "HAND", "HAND")
Concept("split", "TEILUNG", "SPLIT")
Concept("theramore", "THERAMORE", "THERAMORE")
Concept("culling", "AUSMERZUNG", "CULLING")
Concept("bear", "BAER", "BEAR", { "BAEREN" }, { "BEARS" })
Concept("teldrassil", "TELDRASSIL", "TELDRASSIL")
Concept("lava", "LAVA", "LAVA", { "MAGMA" }, { "MAGMA" })
Concept("eye", "AUGE", "EYE", { "AUGEN" }, { "EYES" })
Concept("sunwell", "SONNENBRUNNEN", "SUNWELL")
Concept("eruption", "ERUPTION", "ERUPTION")
Concept("citadel", "ZITADELLE", "CITADEL")
Concept("rune", "RUNE", "RUNE", { "RUNEN" }, { "RUNES" })
Concept("runeblade", "RUNENKLINGE", "RUNEBLADE")
Concept("prayer", "GEBET", "PRAYER")
Concept("nefarian", "NEFARIAN", "NEFARIAN")
Concept("summit", "BERGSPITZE", "SUMMIT")
Concept("totem", "TOTEM", "TOTEM", { "TOTEMS" }, { "TOTEMS" })
Concept("gladiator", "GLADIATOR", "GLADIATOR")
Concept("liberator", "BEFREIER", "LIBERATOR")
Concept("durotar", "DUROTAR", "DUROTAR")
Concept("firelord", "FEUERLORD", "FIRELORD")
Concept("bamboo", "BAMBUS", "BAMBOO")
Concept("saronite", "SARONIT", "SARONITE")
Concept("trial", "PROZESS", "TRIAL")
Concept("anvil", "AMBOSS", "ANVIL")
Concept("antlers", "GEWEIH", "ANTLERS")
Concept("crusader", "KREUZFAHRER", "CRUSADER")
Concept("skull", "SCHAEDEL", "SKULL")
Concept("uther", "UTHER", "UTHER")
Concept("pacifist", "PAZIFIST", "PACIFIST")
Concept("violet", "VIOLETT", "VIOLET")
Concept("shattered", "ZERSCHMETTERT", "SHATTERED")
Concept("dracthyr", "DRACTHYR", "DRACTHYR")

local function Word(id, associations)
    assert(not links[id], "Duplicate SI7 knowledge ID: " .. id)
    links[id] = associations
    ids[#ids + 1] = id
end
-- 74 entries, crossing people, places, weapons, raids and classes.
Word("JAINA", { arcane=95, frost=85, sea=75 })
Word("KHADGAR", { arcane=95, portal=85, staff=60 })
Word("MEDIVH", { arcane=95, portal=90, tower=90, staff=80 })
Word("KALECGOS", { dragon=95, arcane=95, frost=45 })
Word("THRALL", { orc=95, element=90, hammer=85, war=55 })
Word("GARROSH", { orc=95, war=95, axe=85 })
Word("GULDAN", { orc=95, demon=90, shadow=85 })
Word("ARTHAS", { king=90, death=95, frost=85, sword=85, plague=85 })
Word("ANDUIN", { king=95, light=90, heal=80, war=45 })
Word("VARIAN", { king=95, war=90, sword=85 })
Word("BOLVAR", { king=75, death=85, fire=70, frost=60 })
Word("SYLVANAS", { queen=95, death=90, elf=85, bow=90 })
Word("TYRANDE", { elf=95, light=65, nature=65, bow=75 })
Word("MALFURION", { nature=95, dream=95, elf=95, balance=85 })
Word("MAGNI", { dwarf=95, king=85, mountain=80 })
Word("YSERA", { dragon=95, dream=95, nature=90 })
Word("ALEXSTRASZA", { dragon=95, queen=85, heal=75 })
Word("NOZDORMU", { dragon=95, time=95 })
Word("DEATHWING", { dragon=95, fire=90, mountain=65, shadow=60 })
Word("AZSHARA", { queen=95, elf=90, sea=90, arcane=85 })
Word("ILLIDAN", { demon=90, hunt=90, elf=90, sword=75 })
Word("SARGERAS", { titan=95, demon=95, fire=85, sword=75 })
Word("ARCHIMONDE", { demon=95, war=85, fire=65 })
Word("KILJAEDEN", { demon=95, shadow=80, fire=75 })
Word("CENARIUS", { nature=95, dream=80, balance=85 })
Word("RAGNAROS", { fire=100, element=95, hammer=90, mountain=60 })
Word("NEFARIAN", { dragon=95, fire=75, mountain=65 })
Word("CTHUN", { shadow=95, prison=85 })
Word("YOGGSARON", { shadow=95, prison=90, death=70 })
Word("DALARAN", { city=95, arcane=95, tower=65 })
Word("STORMWIND", { city=95, king=80, war=60 })
Word("ORGRIMMAR", { city=95, orc=95, war=75 })
Word("IRONFORGE", { city=95, dwarf=95, mountain=95, fire=65 })
Word("DARNASSUS", { city=95, elf=95, nature=90 })
Word("UNDERCITY", { city=95, death=95, plague=80 })
Word("SILVERMOON", { city=95, elf=95, arcane=85 })
Word("THUNDERBLUFF", { city=95, mountain=90, nature=65 })
Word("EXODAR", { city=90, light=75, island=65 })
Word("ICECROWN", { frost=95, death=95, king=65 })
Word("BLACKROCK", { mountain=95, fire=95, orc=70 })
Word("STRATHOLME", { city=90, plague=95, death=90, fire=75 })
Word("LORDAERON", { king=90, plague=85, death=80 })
Word("OUTLAND", { portal=95, demon=85 })
Word("NORTHREND", { frost=95, death=85 })
Word("PANDARIA", { balance=85, nature=65 })
Word("ZANDALAR", { island=95, king=75 })
Word("FROSTMOURNE", { sword=100, frost=95, death=95 })
Word("ASHBRINGER", { sword=100, light=95, war=75 })
Word("THUNDERFURY", { sword=100, element=90 })
Word("SHADOWMOURNE", { axe=100, shadow=95, death=90, frost=70 })
Word("SULFURAS", { hammer=100, fire=95 })
Word("VALANYR", { hammer=100, heal=95, titan=90 })
Word("DOOMHAMMER", { hammer=100, orc=90, element=85 })
Word("ATIESH", { staff=100, arcane=95, tower=80 })
Word("THORIIDAL", { bow=100, elf=75 })
Word("SHALAMAYNE", { sword=100, king=90, war=85 })
Word("KARAZHAN", { tower=100, arcane=90, death=55 })
Word("NAXXRAMAS", { plague=100, death=95 })
Word("ULDUAR", { titan=100, prison=95 })
Word("MOLTENCORE", { fire=100, mountain=85, element=80 })
Word("BLACKTEMPLE", { temple=100, demon=90, elf=65 })
Word("PALADIN", { light=100, heal=90, war=75, hammer=70 })
Word("DRUID", { nature=100, dream=85, balance=95, heal=75 })
Word("SHAMAN", { element=100, nature=80, heal=80 })
Word("WARLOCK", { demon=100, shadow=95, fire=85 })
Word("ROGUE", { stealth=100, shadow=80, sword=65 })
Word("HUNTER", { hunt=100, bow=95, nature=70 })
Word("MAGE", { arcane=100, frost=90, fire=90, portal=85 })
Word("PRIEST", { light=95, shadow=95, heal=100 })
Word("WARRIOR", { war=100, sword=90, axe=90 })
Word("MONK", { balance=100, heal=80, war=60 })
Word("DEATHKNIGHT", { death=100, frost=95, sword=85, plague=85 })
Word("DEMONHUNTER", { hunt=95, demon=95, sword=85 })
Word("EVOKER", { dragon=100, fire=85, heal=85, time=80 })

-- Distinctive properties and competing readings, independent of board colors.
local additional = {
    JAINA={ human=90, frost=90, teleport=80 }, KHADGAR={ guardian=85, human=85, apprentice=100, teleport=85 },
    MEDIVH={ guardian=100, human=85, corruption=70, apprentice=55, opera=80, teleport=85 }, KALECGOS={ blue=100 },
    THRALL={ warchief=95, green=85, destiny=65, horde=85 }, GARROSH={ warchief=95, blood=75, horde=85 },
    GULDAN={ traitor=95, green=80, summon=85, corruption=95 },
    ARTHAS={ prince=95, soul=80, corruption=90, north=65, kingdom=80 },
    ANDUIN={ prince=85, human=90, harmony=55, apprentice=75 }, VARIAN={ human=95, beast=65, kingdom=80 },
    BOLVAR={ regent=100, human=85, red=65 }, SYLVANAS={ banshee=100, blood=65 },
    TYRANDE={ moon=100, tree=75, hyjal=75 }, MALFURION={ shapeshift=95, tree=95, green=85, hyjal=80 },
    MAGNI={ speaker=100, ore=80 }, YSERA={ green=100, life=80 },
    ALEXSTRASZA={ red=100, life=100 }, NOZDORMU={ bronze=100, destiny=80 },
    DEATHWING={ black=100, corruption=95, volcano=80 },
    AZSHARA={ blood=55, corruption=75 }, ILLIDAN={ traitor=95, glaive=100, corruption=70, glide=65 },
    SARGERAS={ corruption=95, ruin=75, pantheon=100 }, ARCHIMONDE={ corruption=90, ruin=85, hyjal=100 },
    KILJAEDEN={ deceiver=100, corruption=90 }, CENARIUS={ demigod=100, moon=75, tree=90, hyjal=80 },
    RAGNAROS={ volcano=95, hand=70 }, NEFARIAN={ black=95, corruption=80, experiment=100 },
    CTHUN={ madness=85, hidden=85, corruption=90 }, YOGGSARON={ madness=100, corruption=95 },
    DALARAN={ flying=100, teleport=75 }, STORMWIND={ human=100, kingdom=85, canal=100 }, ORGRIMMAR={ warchief=85, horde=100 },
    IRONFORGE={ fortress=95, ore=90 }, DARNASSUS={ tree=100, moon=85 },
    UNDERCITY={ crypt=100, ruin=95, horde=80, canal=85 }, SILVERMOON={ blood=100, horde=80 },
    THUNDERBLUFF={ cliff=100, beast=55, horde=80 }, EXODAR={ spaceship=100 },
    ICECROWN={ north=90, fortress=70, tundra=60 }, BLACKROCK={ volcano=100, black=70, experiment=65 },
    STRATHOLME={ ruin=90, corruption=80 }, LORDAERON={ ruin=90, human=90, kingdom=100 },
    OUTLAND={ fragment=90, ruin=85, split=80 }, NORTHREND={ continent=100, north=100, tundra=100 },
    PANDARIA={ hidden=100, continent=95 }, ZANDALAR={ troll=100 },
    FROSTMOURNE={ soul=100, corruption=95 }, ASHBRINGER={ soul=55, purify=100 },
    THUNDERFURY={ wind=100 }, SHADOWMOURNE={ fragment=100, soul=90, split=70 },
    SULFURAS={ red=65, hand=100 }, VALANYR={ ore=100, pantheon=70 }, DOOMHAMMER={ destiny=100, horde=80 },
    ATIESH={ guardian=85 }, THORIIDAL={ star=100 }, SHALAMAYNE={ human=75, split=100 },
    KARAZHAN={ guardian=75, opera=100 }, NAXXRAMAS={ necropolis=100, flying=90 },
    ULDUAR={ fortress=100, hidden=65, pantheon=85 }, MOLTENCORE={ volcano=100, ore=65 },
    BLACKTEMPLE={ fortress=85, corruption=85 }, PALADIN={ life=70, purify=85, charge=75 },
    DRUID={ shapeshift=100, tree=85, life=85 }, SHAMAN={ wind=85 },
    WARLOCK={ summon=100, soul=85, corruption=90, experiment=70 }, ROGUE={ thief=100, hidden=95 },
    HUNTER={ beast=100, hidden=75 }, MAGE={ blue=55, teleport=100, apprentice=70, experiment=65 },
    PRIEST={ soul=90, life=80, purify=85 }, WARRIOR={ fortress=45, charge=100 },
    MONK={ harmony=100, life=65 }, DEATHKNIGHT={ corruption=95, blood=90 },
    DEMONHUNTER={ glaive=100, corruption=80, glide=100 }, EVOKER={ red=80, green=80, bronze=80, blue=80, glide=85 },
}
for id, associations in pairs(additional) do
    for concept, weight in pairs(associations) do
        if weight > 0 then links[id][concept] = weight end
    end
end

-- Place/history/form relationships, with competing public associations retained.
local refinement = {
    JAINA={theramore=100, culling=65}, THRALL={theramore=70}, GARROSH={theramore=85},
    STRATHOLME={culling=100},
    DRUID={bear=100, teldrassil=80}, MALFURION={bear=85, teldrassil=80},
    HUNTER={bear=75}, WARRIOR={bear=45}, DARNASSUS={teldrassil=100},
    CENARIUS={teldrassil=60}, SYLVANAS={teldrassil=85},
    SHAMAN={lava=75}, SULFURAS={lava=80},
    CTHUN={eye=100}, YOGGSARON={eye=70}, ILLIDAN={eye=65}, DEMONHUNTER={eye=80},
    SILVERMOON={sunwell=100}, KALECGOS={sunwell=80}, KILJAEDEN={sunwell=80},
    DEATHKNIGHT={rune=100, runeblade=85}, FROSTMOURNE={rune=85, runeblade=100},
    MAGE={rune=85}, KHADGAR={rune=80}, MEDIVH={rune=85}, VALANYR={rune=80},
    ARTHAS={culling=85, runeblade=85}, SHADOWMOURNE={rune=70},
    PRIEST={prayer=100}, PALADIN={prayer=85}, ANDUIN={prayer=85}, TYRANDE={teldrassil=80, prayer=85},
    DEATHWING={lava=80, eruption=100, nefarian=80}, BLACKROCK={lava=85, eruption=85, nefarian=100},
    MOLTENCORE={lava=100, eruption=85, nefarian=75}, RAGNAROS={lava=85, eruption=85},
    ICECROWN={citadel=100}, LORDAERON={culling=70, citadel=85},
    BLACKTEMPLE={citadel=85}, ULDUAR={citadel=85}, NAXXRAMAS={citadel=80},
    NEFARIAN={nefarian=100},
}
for id, associations in pairs(refinement) do
    for concept, weight in pairs(associations) do links[id][concept] = weight end
end
local finalRefinement = {
    BLACKROCK={summit=100}, NEFARIAN={summit=85}, IRONFORGE={summit=85},
    THUNDERBLUFF={summit=80, totem=75}, MOLTENCORE={summit=70}, DEATHWING={summit=65},
    SHAMAN={totem=100}, THRALL={totem=85, gladiator=65}, DRUID={totem=55},
    VARIAN={gladiator=100}, WARRIOR={gladiator=85}, GARROSH={gladiator=75},
}
for id, associations in pairs(finalRefinement) do
    for concept, weight in pairs(associations) do links[id][concept] = weight end
end
local history = {
    THRALL={liberator=100, durotar=90}, ORGRIMMAR={durotar=100, liberator=75},
    GARROSH={durotar=75}, VARIAN={liberator=85}, ILLIDAN={liberator=85},
    ANDUIN={liberator=75}, JAINA={durotar=55, liberator=65},
}
for id, associations in pairs(history) do
    for concept, weight in pairs(associations) do links[id][concept] = weight end
end
links.RAGNAROS.firelord, links.SULFURAS.firelord = 100, 85
links.MOLTENCORE.firelord, links.BLACKROCK.firelord = 80, 75
links.SHAMAN.firelord, links.THRALL.firelord = 65, 55
local coverage = {
    PANDARIA={bamboo=100, trial=85}, MONK={bamboo=85}, DRUID={bamboo=70}, CENARIUS={bamboo=65},
    SHADOWMOURNE={saronite=100}, YOGGSARON={saronite=100}, ULDUAR={saronite=85},
    ICECROWN={saronite=85}, NORTHREND={saronite=80}, DEATHKNIGHT={saronite=75},
    GARROSH={trial=100}, NOZDORMU={trial=85}, SYLVANAS={trial=75}, ANDUIN={trial=75},
    THRALL={trial=75}, JAINA={trial=75},
    IRONFORGE={anvil=100}, MAGNI={anvil=85}, BLACKROCK={anvil=75},
    WARRIOR={anvil=65}, VALANYR={anvil=75}, DOOMHAMMER={anvil=70},
}
for id, associations in pairs(coverage) do
    for concept, weight in pairs(associations) do links[id][concept] = weight end
end
local separation = {
    MALFURION={antlers=100}, CENARIUS={antlers=85}, DRUID={antlers=85}, HUNTER={antlers=65},
    PALADIN={crusader=100, uther=85}, ASHBRINGER={crusader=85, uther=85},
    ARTHAS={crusader=75, uther=100}, BOLVAR={crusader=85}, WARRIOR={crusader=75},
    ANDUIN={crusader=65, uther=70, pacifist=100}, THRALL={pacifist=85},
    JAINA={pacifist=80}, MONK={pacifist=85},
    GULDAN={skull=100}, ILLIDAN={skull=85}, WARLOCK={skull=85, dracthyr=65},
    DEATHKNIGHT={skull=75}, FROSTMOURNE={skull=80, shattered=85},
    DALARAN={violet=100}, KHADGAR={violet=85}, MAGE={violet=80, dracthyr=65},
    MEDIVH={violet=70}, OUTLAND={shattered=100}, SHADOWMOURNE={shattered=85},
    VALANYR={shattered=85}, MAGNI={shattered=65},
    EVOKER={dracthyr=100}, PRIEST={dracthyr=65}, ROGUE={dracthyr=65},
}
for id, associations in pairs(separation) do
    for concept, weight in pairs(associations) do links[id][concept] = weight end
end

-- Build the public language lookup once; no per-candidate dictionary scan.
local lexicon = { deDE={}, enUS={} }
for _, id in ipairs(order) do
    for _, locale in ipairs({ "deDE", "enUS" }) do
        local forms = { concepts[id][locale] }
        for _, alias in ipairs(concepts[id].aliases[locale]) do forms[#forms + 1] = alias end
        for _, form in ipairs(forms) do
            local normalized = assert(A.SI7_Clues.Normalize(form))
            local meanings = lexicon[locale][normalized] or {}
            local found = false
            for _, meaning in ipairs(meanings) do if meaning == id then found = true end end
            if not found then meanings[#meanings + 1] = id end
            lexicon[locale][normalized] = meanings
        end
    end
end

function K.GetIds()
    local result = {}
    for i, id in ipairs(ids) do result[i] = id end
    return result
end
function K.GetConceptIds()
    local result = {}
    for i, id in ipairs(order) do result[i] = id end
    return result
end
function K.Clue(id, locale) return concepts[id] and concepts[id][locale] end
function K.Weight(id, concept) return links[id] and links[id][concept] or 0 end
function K.HasWord(id) return links[id] ~= nil end

-- Resolve independently from the displayed word. Multiple meanings stay multiple.
function K.Resolve(text, locale)
    local normalized = A.SI7_Clues.Normalize(text)
    local result = {}
    if not normalized or (locale ~= "deDE" and locale ~= "enUS") then return result end
    for _, id in ipairs(lexicon[locale][normalized] or {}) do result[#result + 1] = id end
    return result
end

-- Pure dictionary assistance: never receives a board or private state.
function K.Dictionary(locale)
    local result = {}
    for _, id in ipairs(order) do
        if concepts[id][locale] then result[#result + 1] = concepts[id][locale] end
    end
    table.sort(result)
    return result
end

function K.Validate()
    local errors, catalogue = {}, {}
    for _, id in ipairs(A.HGM_Words:GetIds()) do catalogue[id] = true end
    for _, id in ipairs(ids) do
        if not catalogue[id] then errors[#errors + 1] = "unknown word: " .. id end
        for concept, weight in pairs(links[id]) do
            if not concepts[concept] or not A.SI7_Clues.IsInteger(weight, 1, 100) then
                errors[#errors + 1] = "invalid association: " .. id .. "/" .. concept
            end
        end
        for _, locale in ipairs({ "deDE", "enUS" }) do
            if not A.HGM_Words:GetLocalizedWord(id, locale) then errors[#errors + 1] = "missing word locale: " .. id end
        end
    end
    for _, id in ipairs(order) do
        for _, locale in ipairs({ "deDE", "enUS" }) do
            if not A.SI7_Clues.Normalize(concepts[id][locale]) then errors[#errors + 1] = "invalid clue: " .. id end
            for _, alias in ipairs(concepts[id].aliases[locale]) do
                if not A.SI7_Clues.Normalize(alias) then errors[#errors + 1] = "invalid alias: " .. id end
            end
        end
    end
    table.sort(errors)
    return errors
end
