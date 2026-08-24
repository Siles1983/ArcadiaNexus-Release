-- Hangman pure game logic. Puzzle data and selection live in Words.lua.

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.HGM_Logic = {}
local L = ArcadiaNexus.HGM_Logic
local Words = ArcadiaNexus.HGM_Words

function L:IsValidCategory(category)
    return Words and Words:IsValidCategory(category)
end
function L:GetCategories()
    return Words and Words:GetCategories() or {}
end

function L:GetWordsForCategory(category, difficulty)
    return Words and Words:GetEntries(category, difficulty) or {}
end

function L:PickWord(category, difficulty)
    return Words and Words:Pick(category, difficulty) or nil
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

    -- Nur A-Z werden geraten; Trennzeichen sind immer sichtbar.
    for i = 1, #board.word do
        local ch = board.word:sub(i,i)
        board.revealed[i] = not ch:match("[A-Z]")
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
    local separator = #board.word <= 16 and " " or ""
    for i = 1, #board.word do
        local ch = board.word:sub(i,i)
        if ch == " " then
            parts[#parts+1] = "  "
        elseif not ch:match("[A-Z]") then
            parts[#parts+1] = ch
        elseif board.revealed[i] then
            parts[#parts+1] = ch
        else
            parts[#parts+1] = "_"
        end
    end
    return table.concat(parts, separator)
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
