-- Additive regular solo coverage. Frozen Knowledge v10 remains the reference.
local A = ArcadiaNexus
local Base, K = A.SI7_Knowledge, {}
A.SI7_RestraintKnowledge = K
K.VERSION = 1
local extra = {
    absorption = { deDE="ABSORPTION", enUS="ABSORPTION", weights={VALANYR=100,PRIEST=100,MAGE=85,PALADIN=85,WARLOCK=75} },
    maiev = { deDE="MAIEV", enUS="MAIEV", weights={ILLIDAN=100,TYRANDE=85,MALFURION=80,DEMONHUNTER=80,BLACKTEMPLE=85} },
    algalon = { deDE="ALGALON", enUS="ALGALON", weights={ULDUAR=100,VALANYR=85,YOGGSARON=80} },
}
function K.GetConceptIds()
    local ids = Base.GetConceptIds()
    for _, id in ipairs({"absorption", "maiev", "algalon"}) do ids[#ids+1] = id end
    return ids
end
function K.Clue(concept, locale)
    return extra[concept] and extra[concept][locale] or Base.Clue(concept, locale)
end
function K.Weight(word, concept)
    return extra[concept] and (extra[concept].weights[word] or 0) or Base.Weight(word, concept)
end
function K.Resolve(text, locale)
    local result = Base.Resolve(text, locale)
    for _, concept in ipairs({"absorption", "maiev", "algalon"}) do
        if A.SI7_Clues.Normalize(text) == extra[concept][locale] then result[#result+1] = concept end
    end
    return result
end
