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
        wordId      = wordEntry.id,
        word        = wordEntry.word,
        hint        = wordEntry.hint,
        category    = wordEntry.category,
        catID       = wordEntry.catID,
        maxErrors   = maxErrors,
        errors      = 0,
        guessed     = {},
        guesses     = {},
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
    if type(board) ~= "table" or type(letter) ~= "string" or not letter:match("^[a-zA-Z]$") then return nil end
    letter = string.upper(letter)
    if board.guessed[letter] or board.won or board.lost then return nil end

    board.guessed[letter] = true
    board.guesses[#board.guesses+1] = letter

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

function L:Copy(value)
    if type(value) ~= "table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=self:Copy(v) end; return out
end
function L:Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not self:Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function L:Int(n,max)
    return type(n)=="number" and n>=0 and n==math.floor(n) and n<=(max or 2147483647)
end
L.ERRORS={easy=8,normal=6,hard=4}
L.SCORES={easy=100,normal=150,hard=200}
function L:ValidateBoard(board)
    if type(board)~="table" or not self.ERRORS[board.difficulty] or board.maxErrors~=self.ERRORS[board.difficulty]
        or not Words:IsValidCategory(board.selectedCategory) or board.locale~="deDE" and board.locale~="enUS"
        or type(board.petId)~="string" or type(board.guesses)~="table" then return nil end
    local entry=Words:ResolveId(board.wordId,board.locale)
    if not entry or board.word~=entry.word or board.hint~=entry.hint or board.catID~=entry.catID
        or type(board.category)~="string" then return nil end
    local allowed=false
    for _,e in ipairs(Words:GetEntries(board.selectedCategory,board.difficulty)) do if e.id==board.wordId then allowed=true; break end end
    if not allowed then return nil end
    local copy=self:NewBoard(entry,board.maxErrors)
    copy.category=board.category; copy.difficulty=board.difficulty; copy.selectedCategory=board.selectedCategory; copy.locale=board.locale; copy.petId=board.petId
    local n=0
    for k in pairs(board.guesses) do if not self:Int(k,26) or k<1 then return nil end; n=n+1 end
    if n~=#board.guesses then return nil end
    for _,letter in ipairs(board.guesses) do
        if type(letter)~="string" or not letter:match("^[A-Z]$") or self:GuessLetter(copy,letter)==nil then return nil end
    end
    if board.errors~=copy.errors or board.won~=copy.won or board.lost~=copy.lost
        or not self:Same(board.guessed,copy.guessed) or not self:Same(board.revealed,copy.revealed) then return nil end
    return copy
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
