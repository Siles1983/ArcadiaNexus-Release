-- Games/AzerothWords/Logic.lua

ArcadiaNexus.WRD_Logic = {}
local Logic = ArcadiaNexus.WRD_Logic

-- Schwierigkeits-Konfiguration
Logic.DiffConfig = {
    easy   = { wordLength=5, maxAttempts=8, scoreFactor=1.0, showCategory=true  },
    normal = { wordLength=6, maxAttempts=6, scoreFactor=1.5, showCategory=true  },
    hard   = { wordLength=7, maxAttempts=5, scoreFactor=2.5, showCategory=false },
}

-- ── Wort auswählen ───────────────────────────────────────────
function Logic:PickWord(difficulty)
    local WL     = ArcadiaNexus.WRD_WordList
    local locale = GetLocale()
    -- Fallback auf enUS wenn deDE nicht verfügbar
    local list = (WL[locale] and WL[locale][self.DiffConfig[difficulty].wordLength])
              or (WL["enUS"] and WL["enUS"][self.DiffConfig[difficulty].wordLength])
    if not list or #list == 0 then
        -- Notfall-Fallback
        return { word="PALADIN", cat="CLASSES" }
    end
    return list[math.random(#list)]
end

-- ── Neuer Spiel-State ─────────────────────────────────────────
function Logic:NewState(difficulty)
    local cfg    = self.DiffConfig[difficulty]
    local entry  = self:PickWord(difficulty)
    return {
        difficulty   = difficulty,
        wordLength   = cfg.wordLength,
        maxAttempts  = cfg.maxAttempts,
        scoreFactor  = cfg.scoreFactor,
        showCategory = cfg.showCategory,
        target       = entry.word,
        category     = entry.cat,
        guesses      = {},         -- Array abgeschlossener Versuche: { guess, result }
        currentGuess = "",
        keyboard     = {},         -- key=Buchstabe, value="CORRECT"|"PRESENT"|"ABSENT"
        won          = false,
        attemptsUsed = 0,
        score        = 0,
    }
end

-- ── Feedback-Berechnung (Wordle-Standard) ───────────────────
-- Gibt pro Position zurück: "CORRECT" | "PRESENT" | "ABSENT"
function Logic:CheckGuess(guess, target)
    local result = {}
    local used   = {}

    -- Pass 1: Korrekte Position
    for i = 1, #target do
        if guess:sub(i,i) == target:sub(i,i) then
            result[i] = "CORRECT"
            used[i]   = true
        end
    end

    -- Pass 2: Falscher Platz / Nicht enthalten
    for i = 1, #guess do
        if not result[i] then
            local found = false
            for j = 1, #target do
                if not used[j] and guess:sub(i,i) == target:sub(j,j) then
                    result[i] = "PRESENT"
                    used[j]   = true
                    found      = true
                    break
                end
            end
            if not found then result[i] = "ABSENT" end
        end
    end

    return result
end

-- ── Tastatur-Status aktualisieren ───────────────────────────
local STATUS_RANK = { CORRECT=3, PRESENT=2, ABSENT=1 }

function Logic:UpdateKeyboard(state, guess, result)
    local kb = state.keyboard
    for i = 1, #guess do
        local letter = guess:sub(i,i)
        local new    = result[i]
        local cur    = kb[letter]
        if not cur or (STATUS_RANK[new] or 0) > (STATUS_RANK[cur] or 0) then
            kb[letter] = new
        end
    end
end

-- ── Eingabe-Validierung gegen WordList ──────────────────────
function Logic:IsValidWord(word, wordLength)
    local WL     = ArcadiaNexus.WRD_WordList
    local VW     = ArcadiaNexus.WRD_ValidWords
    local locale = GetLocale()
    -- Prüfe zuerst aktuelle Locale, dann enUS als Fallback
    if VW[locale] and VW[locale][wordLength] and VW[locale][wordLength][word] then
        return true
    end
    if VW["enUS"] and VW["enUS"][wordLength] and VW["enUS"][wordLength][word] then
        return true
    end
    return false
end

-- ── Score-Formel ─────────────────────────────────────────────
function Logic:CalcScore(attemptsUsed, maxAttempts, difficulty)
    local remaining = maxAttempts - attemptsUsed
    local base      = 100 + (remaining * 50)
    local factors   = { easy=1.0, normal=1.5, hard=2.5 }
    return math.floor(base * (factors[difficulty] or 1.0))
end

-- ── Kategorie-Label ──────────────────────────────────────────
function Logic:GetCategoryLabel(catId)
    local L = ArcadiaNexus.GetLocaleTable("AZEROTHWORDS")
    local map = {
        PLACES   = L["cat_places"]   or "Orte",
        CLASSES  = L["cat_classes"]  or "Klassen",
        RACES    = L["cat_races"]    or "Völker",
        SPELLS   = L["cat_spells"]   or "Zauber",
        NPCS     = L["cat_npcs"]     or "Bosse & NPCs",
        CRAFTING = L["cat_crafting"] or "Berufe & Gegenstände",
    }
    return map[catId] or catId
end
