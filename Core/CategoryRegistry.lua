--[[
    ArcadiaNexus – Core/CategoryRegistry.lua

    Zentrale Registry für Hub-Kategorien (Sidebar-SubTabs).
    Kategorien erscheinen nur, wenn sichtbare Spiele zugeordnet sind
    (Filter in CategoryBuilder / GetCategoryGroups).

    Öffentliche API:
        ArcadiaNexus.RegisterCategory(info)     – Facade (Bootstrap.lua)
        ArcadiaNexus.CategoryRegistry.Register(info)
        ArcadiaNexus.CategoryRegistry.GetById(id)
        ArcadiaNexus.CategoryRegistry.GetDefs()
        ArcadiaNexus.CategoryRegistry.GetLabel(id, localeFn)
        ArcadiaNexus.CategoryRegistry.ResolveId(raw)  – DE/EN ID, Alias oder Label → kanonische ID
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CategoryRegistry = {}
local CR = ArcadiaNexus.CategoryRegistry

local registry = {}   -- geordnete Liste { id, label?, order? }
local byId     = {}   -- id → entry
local seq      = 0    -- Registrierungsreihenfolge (Fallback-Sortierung)

-- Normalisiert IDs und Labels für DE/EN-Vergleich (Umlaute, Satzzeichen, Groß/Klein).
local function NormalizeKey(s)
    if not s or s == "" then return "" end
    s = tostring(s)
    s = s:gsub("\195\132", "AE"):gsub("\195\164", "AE") -- Ä ä
    s = s:gsub("\195\150", "OE"):gsub("\195\182", "OE") -- Ö ö
    s = s:gsub("\195\156", "UE"):gsub("\195\188", "UE") -- Ü ü
    s = s:gsub("\195\159", "SS")                         -- ß
    s = string.upper(s)
    s = s:gsub("[^A-Z0-9]", "")
    return s
end

-- Feste Aliase: englische IDs, DE/EN-Anzeigenamen (Language.lua lädt nach den Spielen).
local STATIC_ALIASES = {
    DENKSPIELE        = "DENKSPIELE",
    STRATEGY          = "DENKSPIELE",
    THINKING          = "DENKSPIELE",
    BRAIN             = "DENKSPIELE",
    KARTEN            = "KARTEN",
    KARTENGLUECK      = "KARTEN",
    CARDS             = "KARTEN",
    CARDSLUCK         = "KARTEN",
    CARDSANDLUCK      = "KARTEN",
    LUCK              = "KARTEN",
    GESCHICK          = "GESCHICK",
    GESCHICKTIMING    = "GESCHICK",
    SKILL             = "GESCHICK",
    SKILLTIMING       = "GESCHICK",
    SKILLANDTIMING    = "GESCHICK",
    TIMING            = "GESCHICK",
    ARCADE            = "ARCADE",
    STRATEGIE         = "STRATEGIE",
    STRATEGYGAMES     = "STRATEGIE",
    STRATEGYANDGAMES  = "STRATEGIE",
    WORT              = "WORT",
    WORTWISSEN        = "WORT",
    WORD              = "WORT",
    WORDKNOWLEDGE     = "WORT",
    WORDANDKNOWLEDGE  = "WORT",
    KNOWLEDGE         = "WORT",
    RAETSEL           = "RAETSEL",
    RAETSELLOGIK      = "RAETSEL",
    PUZZLE            = "RAETSEL",
    PUZZLES           = "RAETSEL",
    PUZZLESLOGIC      = "RAETSEL",
    PUZZLESANDLOGIC   = "RAETSEL",
    RIDDLES           = "RAETSEL",
    LOGIC             = "RAETSEL",
    IDLE              = "IDLE",
    IDLECASUAL        = "IDLE",
    CASUAL            = "IDLE",
    SONSTIGE          = "SONSTIGE",
    OTHER             = "SONSTIGE",
    MISC              = "SONSTIGE",
    MISCELLANEOUS     = "SONSTIGE",
}

--- Löst deutsche/englische Kategorie-IDs, Aliase und Anzeigenamen auf.
--- Unbekannte Werte werden unverändert zurückgegeben (eigene RegisterCategory-IDs).
--- @param raw string|nil
--- @return string|nil
function CR.ResolveId(raw)
    if not raw or raw == "" then
        return nil
    end
    raw = tostring(raw)

    if byId[raw] then
        return raw
    end
    local upper = string.upper(raw)
    if byId[upper] then
        return upper
    end

    local key = NormalizeKey(raw)
    local static = STATIC_ALIASES[key]
    if static then
        return static
    end

    for _, entry in ipairs(registry) do
        if NormalizeKey(entry.id) == key then
            return entry.id
        end
        if entry.label and NormalizeKey(entry.label) == key then
            return entry.id
        end
        if type(entry.aliases) == "table" then
            for _, alias in ipairs(entry.aliases) do
                if NormalizeKey(alias) == key then
                    return entry.id
                end
            end
        end
    end

    local locales = ArcadiaNexus._locales and ArcadiaNexus._locales["UI"]
    if locales then
        for _, loc in pairs(locales) do
            if type(loc) == "table" then
                for locKey, locVal in pairs(loc) do
                    if type(locKey) == "string" and locKey:sub(1, 4) == "cat_"
                        and type(locVal) == "string" and NormalizeKey(locVal) == key then
                        local catId = locKey:sub(5)
                        if byId[catId] or catId == "SONSTIGE" then
                            return catId
                        end
                    end
                end
            end
        end
    end

    return raw
end

--- @param info table  { id, label?, order?, aliases? }
--- @return boolean
function CR.Register(info)
    if not info or not info.id then
        return false
    end

    if byId[info.id] then
        GH_LogWarn("CategoryRegistry", "Kategorie bereits registriert: " .. tostring(info.id))
        return false
    end

    seq = seq + 1
    local entry = {
        id      = info.id,
        label   = info.label,
        order   = info.order,
        aliases = info.aliases,
        _seq    = seq,
    }
    table.insert(registry, entry)
    byId[info.id] = entry
    local UI = ArcadiaNexus.UI
    if UI and UI.OnHubRegistryChanged then
        pcall(UI.OnHubRegistryChanged)
    end
    return true
end

--- @return table|nil
function CR.GetById(id)
    if not id then return nil end
    return byId[id]
end

--- @return table[]  sortiert nach order, dann Registrierungsreihenfolge
function CR.GetDefs()
    local sorted = {}
    for _, entry in ipairs(registry) do
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b)
        local oa = a.order or 1000
        local ob = b.order or 1000
        if oa ~= ob then
            return oa < ob
        end
        return (a._seq or 0) < (b._seq or 0)
    end)
    return sorted
end

--- labelFn optional: function(key) → string (z. B. UI-Locale L("cat_ID"))
--- @return string
function CR.GetLabel(id, labelFn)
    local entry = CR.GetById(id)
    if entry and entry.label then
        return entry.label
    end
    if labelFn then
        local fromLocale = labelFn("cat_" .. id)
        if fromLocale and fromLocale ~= "[cat_" .. id .. "]" then
            return fromLocale
        end
    end
    return id or "–"
end

--- Fortschrittsüberblick + konsistente Kategorie-Reihenfolge (ALLGEMEIN, dann Registry).
--- @param labelFn function|nil  function(key) → string
--- @return table[]  { id, label }
function CR.GetProgressCategories(labelFn)
    local cats = {
        { id = "ALLGEMEIN", label = CR.GetLabel("ALLGEMEIN", labelFn) },
    }
    for _, def in ipairs(CR.GetDefs()) do
        cats[#cats + 1] = {
            id    = def.id,
            label = CR.GetLabel(def.id, labelFn),
        }
    end
    return cats
end

-- ── Standard-Kategorien (ehemals Bootstrap._categoryDefs) ─────────────
local DEFAULT_CATEGORIES = {
    { id = "DENKSPIELE", order = 10 },
    { id = "KARTEN",     order = 20 },
    { id = "GESCHICK",   order = 30 },
    { id = "ARCADE",     order = 40 },
    { id = "STRATEGIE",  order = 50 },
    { id = "WORT",       order = 60 },
    { id = "RAETSEL",    order = 70 },
    { id = "IDLE",       order = 80 },
}

for _, cat in ipairs(DEFAULT_CATEGORIES) do
    CR.Register(cat)
end
