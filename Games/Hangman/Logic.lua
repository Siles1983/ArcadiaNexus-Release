-- Hangman Logic.lua
-- Pure game logic. No UI, no frames.
-- Hinweise und Kategorie-Namen werden ueber Language.lua (HANGMAN_HINTS) lokalisiert.

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.HGM_Logic = {}
local L = ArcadiaNexus.HGM_Logic

-- ============================================================
-- WORTLISTE
-- Jeder Eintrag hat:
--   fallback  = Wort (immer UPPERCASE, nur A-Z und Leerzeichen)
--   hintKey   = Key in HANGMAN_HINTS-Locale fuer den Hinweis
--   catKey    = Key in HANGMAN_HINTS-Locale fuer den Kategorienamen
--   catID     = interner Bezeichner fuer Filterung (unveraendert)
-- ============================================================
L.WORD_LIST = {
    -- CHARAKTERE
    { fallback="ARTHAS",        hintKey="hint_ARTHAS",       catKey="cat_chars",     catID="chars" },
    { fallback="SYLVANAS",      hintKey="hint_SYLVANAS",     catKey="cat_chars",     catID="chars" },
    { fallback="THRALL",        hintKey="hint_THRALL",       catKey="cat_chars",     catID="chars" },
    { fallback="ILLIDAN",       hintKey="hint_ILLIDAN",      catKey="cat_chars",     catID="chars" },
    { fallback="JAINA",         hintKey="hint_JAINA",        catKey="cat_chars",     catID="chars" },
    { fallback="ANDUIN",        hintKey="hint_ANDUIN",       catKey="cat_chars",     catID="chars" },
    { fallback="BOLVAR",        hintKey="hint_BOLVAR",       catKey="cat_chars",     catID="chars" },
    { fallback="TYRANDE",       hintKey="hint_TYRANDE",      catKey="cat_chars",     catID="chars" },
    { fallback="MALFURION",     hintKey="hint_MALFURION",    catKey="cat_chars",     catID="chars" },
    { fallback="MAGNI",         hintKey="hint_MAGNI",        catKey="cat_chars",     catID="chars" },
    { fallback="KHADGAR",       hintKey="hint_KHADGAR",      catKey="cat_chars",     catID="chars" },
    { fallback="VARIAN",        hintKey="hint_VARIAN",       catKey="cat_chars",     catID="chars" },
    { fallback="GARROSH",       hintKey="hint_GARROSH",      catKey="cat_chars",     catID="chars" },
    { fallback="GULDAN",        hintKey="hint_GULDAN",       catKey="cat_chars",     catID="chars" },
    { fallback="MEDIVH",        hintKey="hint_MEDIVH",       catKey="cat_chars",     catID="chars" },
    { fallback="DEATHWING",     hintKey="hint_DEATHWING",    catKey="cat_chars",     catID="chars" },
    { fallback="ALEXSTRASZA",   hintKey="hint_ALEXSTRASZA",  catKey="cat_chars",     catID="chars" },
    { fallback="YSERA",         hintKey="hint_YSERA",        catKey="cat_chars",     catID="chars" },
    { fallback="NOZDORMU",      hintKey="hint_NOZDORMU",     catKey="cat_chars",     catID="chars" },
    { fallback="KALECGOS",      hintKey="hint_KALECGOS",     catKey="cat_chars",     catID="chars" },
    { fallback="XAVIUS",        hintKey="hint_XAVIUS",       catKey="cat_chars",     catID="chars" },
    { fallback="AZSHARA",       hintKey="hint_AZSHARA",      catKey="cat_chars",     catID="chars" },
    { fallback="SARGERAS",      hintKey="hint_SARGERAS",     catKey="cat_chars",     catID="chars" },
    { fallback="ARCHIMONDE",    hintKey="hint_ARCHIMONDE",   catKey="cat_chars",     catID="chars" },
    { fallback="KILJAEDEN",     hintKey="hint_KILJAEDEN",    catKey="cat_chars",     catID="chars" },
    { fallback="CENARIUS",      hintKey="hint_CENARIUS",     catKey="cat_chars",     catID="chars" },
    { fallback="RAGNAROS",      hintKey="hint_RAGNAROS",     catKey="cat_chars",     catID="chars" },
    { fallback="NEFARIAN",      hintKey="hint_NEFARIAN",     catKey="cat_chars",     catID="chars" },
    { fallback="CTHUN",         hintKey="hint_CTHUN",        catKey="cat_chars",     catID="chars" },
    { fallback="YOGGSARON",     hintKey="hint_YOGGSARON",    catKey="cat_chars",     catID="chars" },

    -- ORTE
    { fallback="STORMWIND",     hintKey="hint_STORMWIND",    catKey="cat_places",    catID="places" },
    { fallback="ORGRIMMAR",     hintKey="hint_ORGRIMMAR",    catKey="cat_places",    catID="places" },
    { fallback="DALARAN",       hintKey="hint_DALARAN",      catKey="cat_places",    catID="places" },
    { fallback="IRONFORGE",     hintKey="hint_IRONFORGE",    catKey="cat_places",    catID="places" },
    { fallback="DARNASSUS",     hintKey="hint_DARNASSUS",    catKey="cat_places",    catID="places" },
    { fallback="UNDERCITY",     hintKey="hint_UNDERCITY",    catKey="cat_places",    catID="places" },
    { fallback="THUNDERBLUFF",  hintKey="hint_THUNDERBLUFF", catKey="cat_places",    catID="places" },
    { fallback="SILVERMOON",    hintKey="hint_SILVERMOON",   catKey="cat_places",    catID="places" },
    { fallback="EXODAR",        hintKey="hint_EXODAR",       catKey="cat_places",    catID="places" },
    { fallback="ICECROWN",      hintKey="hint_ICECROWN",     catKey="cat_places",    catID="places" },
    { fallback="BLACKROCK",     hintKey="hint_BLACKROCK",    catKey="cat_places",    catID="places" },
    { fallback="KARAZHAN",      hintKey="hint_KARAZHAN",     catKey="cat_places",    catID="places" },
    { fallback="ULDUAR",        hintKey="hint_ULDUAR",       catKey="cat_places",    catID="places" },
    { fallback="NAXXRAMAS",     hintKey="hint_NAXXRAMAS",    catKey="cat_places",    catID="places" },
    { fallback="STRATHOLME",    hintKey="hint_STRATHOLME",   catKey="cat_places",    catID="places" },
    { fallback="LORDAERON",     hintKey="hint_LORDAERON",    catKey="cat_places",    catID="places" },
    { fallback="OUTLAND",       hintKey="hint_OUTLAND",      catKey="cat_places",    catID="places" },
    { fallback="NORTHREND",     hintKey="hint_NORTHREND",    catKey="cat_places",    catID="places" },
    { fallback="PANDARIA",      hintKey="hint_PANDARIA",     catKey="cat_places",    catID="places" },
    { fallback="ZANDALAR",      hintKey="hint_ZANDALAR",     catKey="cat_places",    catID="places" },

    -- LEGENDAERE WAFFEN
    { fallback="FROSTMOURNE",   hintKey="hint_FROSTMOURNE",  catKey="cat_weapons",   catID="weapons" },
    { fallback="ASHBRINGER",    hintKey="hint_ASHBRINGER",   catKey="cat_weapons",   catID="weapons" },
    { fallback="THUNDERFURY",   hintKey="hint_THUNDERFURY",  catKey="cat_weapons",   catID="weapons" },
    { fallback="SHADOWMOURNE",  hintKey="hint_SHADOWMOURNE", catKey="cat_weapons",   catID="weapons" },
    { fallback="SULFURAS",      hintKey="hint_SULFURAS",     catKey="cat_weapons",   catID="weapons" },
    { fallback="VALANYR",       hintKey="hint_VALANYR",      catKey="cat_weapons",   catID="weapons" },
    { fallback="DOOMHAMMER",    hintKey="hint_DOOMHAMMER",   catKey="cat_weapons",   catID="weapons" },
    { fallback="TAESHALACH",    hintKey="hint_TAESHALACH",   catKey="cat_weapons",   catID="weapons" },
    { fallback="ATIESH",        hintKey="hint_ATIESH",       catKey="cat_weapons",   catID="weapons" },
    { fallback="XALATATH",      hintKey="hint_XALATATH",     catKey="cat_weapons",   catID="weapons" },
    { fallback="THORIIDAL",     hintKey="hint_THORIIDAL",    catKey="cat_weapons",   catID="weapons" },
    { fallback="SHALAMAYNE",    hintKey="hint_SHALAMAYNE",   catKey="cat_weapons",   catID="weapons" },

    -- RAIDS & INSTANZEN (separate hintKeys fuer Duplikate wie KARAZHAN/ULDUAR)
    { fallback="MOLTENCORE",    hintKey="hint_MOLTENCORE",     catKey="cat_instances", catID="instances" },
    { fallback="KARAZHAN",      hintKey="hint_KARAZHAN_INST",  catKey="cat_instances", catID="instances" },
    { fallback="NAXXRAMAS",     hintKey="hint_NAXXRAMAS_INST", catKey="cat_instances", catID="instances" },
    { fallback="ULDUAR",        hintKey="hint_ULDUAR_INST",    catKey="cat_instances", catID="instances" },
    { fallback="ICECROWN",      hintKey="hint_ICECROWN_INST",  catKey="cat_instances", catID="instances" },
    { fallback="SUNWELLPLATEAU",hintKey="hint_SUNWELLPLATEAU", catKey="cat_instances", catID="instances" },
    { fallback="BLACKTEMPLE",   hintKey="hint_BLACKTEMPLE",    catKey="cat_instances", catID="instances" },
    { fallback="AHNQIRAJ",      hintKey="hint_AHNQIRAJ",       catKey="cat_instances", catID="instances" },

    -- KLASSEN & VOELKER
    { fallback="PALADIN",       hintKey="hint_PALADIN",      catKey="cat_classes",   catID="classes" },
    { fallback="DRUID",         hintKey="hint_DRUID",        catKey="cat_classes",   catID="classes" },
    { fallback="SHAMAN",        hintKey="hint_SHAMAN",       catKey="cat_classes",   catID="classes" },
    { fallback="WARLOCK",       hintKey="hint_WARLOCK",      catKey="cat_classes",   catID="classes" },
    { fallback="DEATHKNIGHT",   hintKey="hint_DEATHKNIGHT",  catKey="cat_classes",   catID="classes" },
    { fallback="ROGUE",         hintKey="hint_ROGUE",        catKey="cat_classes",   catID="classes" },
    { fallback="HUNTER",        hintKey="hint_HUNTER",       catKey="cat_classes",   catID="classes" },
    { fallback="MAGE",          hintKey="hint_MAGE",         catKey="cat_classes",   catID="classes" },
    { fallback="PRIEST",        hintKey="hint_PRIEST",       catKey="cat_classes",   catID="classes" },
    { fallback="WARRIOR",       hintKey="hint_WARRIOR",      catKey="cat_classes",   catID="classes" },
    { fallback="WORGEN",        hintKey="hint_WORGEN",       catKey="cat_classes",   catID="classes" },
    { fallback="GOBLIN",        hintKey="hint_GOBLIN",       catKey="cat_classes",   catID="classes" },
    { fallback="PANDAREN",      hintKey="hint_PANDAREN",     catKey="cat_classes",   catID="classes" },
    { fallback="DRAENEI",       hintKey="hint_DRAENEI",      catKey="cat_classes",   catID="classes" },
}

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

-- Interne catID-Liste (sprachunabhaengig)
local CAT_IDS = { "all", "chars", "places", "weapons", "instances", "classes" }

-- Wortliste nach catID filtern
function L:GetWordsForCategory(catID)
    if catID == "all" then return L.WORD_LIST end
    local result = {}
    for _, entry in ipairs(L.WORD_LIST) do
        if entry.catID == catID then
            result[#result+1] = entry
        end
    end
    return result
end

-- Lokalisierte Kategorie-Namen fuer Dropdown
-- Gibt Liste von { id=catID, label=lokalisierterName } zurueck
function L:GetCategories()
    local HL = ArcadiaNexus.GetLocaleTable("HANGMAN_HINTS")
    return {
        { id="all",       label = HL["cat_all"]       },
        { id="chars",     label = HL["cat_chars"]     },
        { id="places",    label = HL["cat_places"]    },
        { id="weapons",   label = HL["cat_weapons"]   },
        { id="instances", label = HL["cat_instances"] },
        { id="classes",   label = HL["cat_classes"]   },
    }
end

-- Zufaelliges Wort aus Kategorie waehlen (catID = interner Key)
function L:PickWord(catID)
    local pool = L:GetWordsForCategory(catID or "all")
    if #pool == 0 then pool = L.WORD_LIST end
    local entry = pool[math.random(#pool)]

    -- Versuche API-Abfrage (optional, Midnight-Fallback)
    local name = entry.fallback
    if entry.id and entry.type == "item" then
        local itemName = GetItemInfo(entry.id)
        if itemName and itemName ~= "" then
            name = string.upper(itemName)
        end
    end

    -- Bereinigung: nur A-Z und Leerzeichen
    name = string.upper(name)
    name = name:gsub("[^A-Z ]", "")
    name = name:match("^%s*(.-)%s*$")  -- trim

    -- Hinweis und Kategorie-Label aus Locale holen
    local HL  = ArcadiaNexus.GetLocaleTable("HANGMAN_HINTS")
    local hint = HL[entry.hintKey] or ""
    local catLabel = HL[entry.catKey] or entry.catID

    return {
        word     = name,
        hint     = hint,
        category = catLabel,
        catID    = entry.catID,
    }
end

-- ============================================================
-- Board-Objekt (Spielzustand)
-- ============================================================

function L:NewBoard(wordEntry, maxErrors)
    local board = {
        word        = wordEntry.word,
        hint        = wordEntry.hint,
        category    = wordEntry.category,
        catID       = wordEntry.catID,
        maxErrors   = maxErrors,
        errors      = 0,
        guessed     = {},
        revealed    = {},
        won         = false,
        lost        = false,
    }

    -- revealed vorinitialisieren (Leerzeichen immer aufgedeckt)
    for i = 1, #board.word do
        local ch = board.word:sub(i,i)
        board.revealed[i] = (ch == " ")
    end

    return board
end

-- Buchstaben raten; gibt true zurueck wenn Buchstabe im Wort
function L:GuessLetter(board, letter)
    letter = string.upper(letter)
    if board.guessed[letter] then return false end
    if board.won or board.lost then return false end

    board.guessed[letter] = true

    local found = false
    for i = 1, #board.word do
        if board.word:sub(i,i) == letter then
            board.revealed[i] = true
            found = true
        end
    end

    if not found then
        board.errors = board.errors + 1
        if board.errors >= board.maxErrors then
            board.lost = true
        end
    end

    -- Gewinn pruefen
    if not board.lost then
        local allRevealed = true
        for i = 1, #board.word do
            if not board.revealed[i] then
                allRevealed = false
                break
            end
        end
        if allRevealed then board.won = true end
    end

    return found
end

-- Gibt den aktuellen Anzeigestring zurueck: "A R T _ A _"
function L:GetDisplayWord(board)
    local parts = {}
    for i = 1, #board.word do
        local ch = board.word:sub(i,i)
        if ch == " " then
            parts[#parts+1] = "  "
        elseif board.revealed[i] then
            parts[#parts+1] = ch
        else
            parts[#parts+1] = "_"
        end
    end
    return table.concat(parts, " ")
end

-- Welche Buchstaben wurden falsch geraten
function L:GetWrongLetters(board)
    local wrong = {}
    for letter, _ in pairs(board.guessed) do
        if letter ~= " " then
            local inWord = false
            for i = 1, #board.word do
                if board.word:sub(i,i) == letter then inWord = true; break end
            end
            if not inWord then wrong[#wrong+1] = letter end
        end
    end
    table.sort(wrong)
    return wrong
end
