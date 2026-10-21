--[[
    Gaming Hub – Codebreaker: Azeroth Edition
    Games/Codebreaker/Logic.lua
    Reine Spiellogik, kein UI, kein State außer dem übergebenen Board.

    Begriffe:
      codeLength  – Anzahl Slots im geheimen Code (3-6)
      symbols     – Anzahl verfügbarer Symbole (= Anzahl im gewählten Theme, mind. 6)
      exact       – Symbol an exakt richtiger Position  (= schwarzer Stift im Original)
      partial     – Symbol vorhanden, aber falsche Position (= weißer Stift)
      duplicates  – ob dasselbe Symbol mehrfach im Code vorkommen darf
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.CB_Logic = {}
local L = ArcadiaNexus.CB_Logic
local function Integer(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- ============================================================
-- Difficulty-Konfiguration
-- ============================================================
L.CONFIGS = {
    easy   = { attempts = 10, defaultCodeLen = 3 },
    normal = { attempts = 8,  defaultCodeLen = 4 },
    hard   = { attempts = 6,  defaultCodeLen = 6 },
}

-- ============================================================
-- NewBoard – erstellt ein frisches Board
-- config = {
--   difficulty  = "easy"|"normal"|"hard"
--   codeLength / duplicates are derived from rule version 2, never overrides.
--   theme       = "gems"|"elements"|"professions"
--   themeName   = string
--   symbolCount = number  (wie viele Symbole im Theme)
-- }
-- ============================================================
function L:NewBoard(config)
    local diff       = config.difficulty or "normal"
    if not self.CONFIGS[diff] then diff = "normal" end
    local cfg        = self.CONFIGS[diff]
    local codeLen    = cfg.defaultCodeLen
    local maxAttempts= cfg.attempts
    local duplicates = true

    -- Geheimen Code generieren
    local code = self:GenerateCode(codeLen, config.symbolCount, duplicates)

    return {
        -- Konfiguration
        ruleVersion  = 2,
        difficulty   = diff,
        codeLength   = codeLen,
        maxAttempts  = maxAttempts,
        duplicates   = duplicates,
        theme        = config.theme     or "gems",
        themeName    = config.themeName or "Juwelenschleifer",
        symbolCount  = config.symbolCount or 6,

        -- Geheimer Code (1-basierte Symbol-Indices)
        secretCode   = code,

        -- Versuche: Array von { guess={}, exact=N, partial=N }
        attempts     = {},
        currentGuess = {},   -- aktueller Eingabe-Slot (1..codeLen), 0 = leer

        -- Phase: "PLAYING", "WON", "LOST"
        phase        = "PLAYING",
    }
end

-- ============================================================
-- GenerateCode
-- ============================================================
function L:GenerateCode(len, symbolCount, duplicates)
    local code = {}
    if duplicates then
        for i = 1, len do
            code[i] = math.random(1, symbolCount)
        end
    else
        -- Keine Duplikate: Fisher-Yates auf [1..symbolCount], erste len nehmen
        local pool = {}
        for i = 1, symbolCount do pool[i] = i end
        ArcadiaNexus.ArrayUtils.Shuffle(pool)
        for i = 1, len do code[i] = pool[i] end
    end
    return code
end

-- ============================================================
-- SetSlot – setzt ein Symbol in den aktuellen Guess
-- symbolIdx = 1..symbolCount,  slotIdx = 1..codeLength
-- Gibt "ok" oder "invalid" zurück
-- ============================================================
function L:SetSlot(board, slotIdx, symbolIdx)
    if board.phase ~= "PLAYING" then return "game_over" end
    if not Integer(slotIdx, 1, board.codeLength) then return "invalid" end
    if not Integer(symbolIdx, 1, board.symbolCount) then return "invalid" end
    board.currentGuess[slotIdx] = symbolIdx
    return "ok"
end

-- ============================================================
-- ClearSlot – leert einen Slot
-- ============================================================
function L:ClearSlot(board, slotIdx)
    if board.phase ~= "PLAYING" then return "game_over" end
    if not Integer(slotIdx, 1, board.codeLength) then return "invalid" end
    board.currentGuess[slotIdx] = 0
    return "ok"
end

-- ============================================================
-- IsGuessComplete – alle Slots gefüllt?
-- ============================================================
function L:IsGuessComplete(board)
    for i = 1, board.codeLength do
        if not board.currentGuess[i] or board.currentGuess[i] == 0 then
            return false
        end
    end
    return true
end

-- ============================================================
-- SubmitGuess – aktuellen Guess prüfen
-- Gibt "incomplete", "won", "lost", "continue" zurück
-- ============================================================
function L:SubmitGuess(board)
    if board.phase ~= "PLAYING" then return "game_over" end
    if not self:IsGuessComplete(board) then return "incomplete" end

    local guess = {}
    for i = 1, board.codeLength do guess[i] = board.currentGuess[i] end

    local exact, partial = self:EvaluateGuess(board.secretCode, guess, board.codeLength)

    -- Versuch speichern
    board.attempts[#board.attempts + 1] = {
        guess   = guess,
        exact   = exact,
        partial = partial,
    }

    -- currentGuess zurücksetzen
    board.currentGuess = {}
    for i = 1, board.codeLength do board.currentGuess[i] = 0 end

    -- Gewonnen?
    if exact == board.codeLength then
        board.phase = "WON"
        return "won"
    end

    -- Verloren?
    if #board.attempts >= board.maxAttempts then
        board.phase = "LOST"
        return "lost"
    end

    return "continue"
end

-- ============================================================
-- EvaluateGuess – Kernalgorithmus
-- Gibt exact, partial zurück
-- Klassischer Codebreaker-Algorithmus (kein Doppelzählen)
-- ============================================================
function L:EvaluateGuess(secret, guess, len)
    local exact   = 0
    local partial = 0

    local secretUsed = {}
    local guessUsed  = {}
    for i = 1, len do secretUsed[i] = false; guessUsed[i] = false end

    -- 1. Pass: exakte Treffer
    for i = 1, len do
        if guess[i] == secret[i] then
            exact = exact + 1
            secretUsed[i] = true
            guessUsed[i]  = true
        end
    end

    -- 2. Pass: Farbe richtig, Position falsch
    for i = 1, len do
        if not guessUsed[i] then
            for j = 1, len do
                if not secretUsed[j] and guess[i] == secret[j] then
                    partial = partial + 1
                    secretUsed[j] = true
                    guessUsed[i]  = true
                    break
                end
            end
        end
    end

    return exact, partial
end

-- ============================================================
-- GetBoardState – Snapshot (Deep Copy)
-- ============================================================
function L:GetBoardState(board)
    local attemptsCopy = {}
    for i, a in ipairs(board.attempts) do
        local guessCopy = {}
        for j, v in ipairs(a.guess) do guessCopy[j] = v end
        attemptsCopy[i] = { guess = guessCopy, exact = a.exact, partial = a.partial }
    end

    local currentGuessCopy = {}
    for i = 1, board.codeLength do
        currentGuessCopy[i] = board.currentGuess[i] or 0
    end

    local secretCopy = {}
    for i, v in ipairs(board.secretCode) do secretCopy[i] = v end

    return {
        ruleVersion   = board.ruleVersion,
        score         = self:GetScore(board),
        difficulty    = board.difficulty,
        codeLength    = board.codeLength,
        maxAttempts   = board.maxAttempts,
        duplicates    = board.duplicates,
        theme         = board.theme,
        themeName     = board.themeName,
        symbolCount   = board.symbolCount,
        secretCode    = secretCopy,
        attempts      = attemptsCopy,
        currentGuess  = currentGuessCopy,
        phase         = board.phase,
        attemptCount  = #board.attempts,
        remainingAttempts = board.maxAttempts - #board.attempts,
    }
end
-- Comfort actions edit only the unsubmitted guess.
function L:ClearGuess(board)
    if board.phase ~= "PLAYING" then return "game_over" end
    for i=1,board.codeLength do board.currentGuess[i]=0 end
    return "ok"
end

function L:CopyPrevious(board)
    if board.phase ~= "PLAYING" then return "game_over" end
    local last=board.attempts[#board.attempts]
    if not last then return "invalid" end
    for i=1,board.codeLength do board.currentGuess[i]=last.guess[i] end
    return "ok"
end

function L:GetScore(board)
    if board.phase == "LOST" then return 0 end
    local used=#board.attempts + (board.phase == "PLAYING" and 1 or 0)
    local base=({easy=50,normal=100,hard=200})[board.difficulty]
    return math.max(1,math.floor(base*(board.maxAttempts-used+1)/board.maxAttempts))
end

-- Recompute feedback and phase instead of trusting persisted outcome fields.
function L:ValidateSave(s)
    if type(s)~="table" or s.saveVersion~=1 or s.ruleVersion~=2
        or type(s.runId)~="string" or not self.CONFIGS[s.difficulty] then return false end
    local cfg=self.CONFIGS[s.difficulty]
    if s.codeLength~=cfg.defaultCodeLen or s.maxAttempts~=cfg.attempts or s.duplicates~=true
        or not ArcadiaNexus.CB_Themes.THEMES[s.theme]
        or s.symbolCount~=ArcadiaNexus.CB_Themes:GetSymbolCount(s.theme)
        or type(s.attempts)~="table" or #s.attempts>s.maxAttempts then return false end
    local function Symbols(t, empty)
        if type(t)~="table" or #t~=s.codeLength then return false end
        for k,v in pairs(t) do
            if not Integer(k,1,s.codeLength) or not Integer(v,empty and 0 or 1,s.symbolCount) then return false end
        end
        return true
    end
    if not Symbols(s.secretCode,false) or not Symbols(s.currentGuess,true) then return false end
    local phase="PLAYING"
    for k,a in pairs(s.attempts) do if not Integer(k,1,#s.attempts) or type(a)~="table" then return false end end
    for i,a in ipairs(s.attempts) do
        if phase~="PLAYING" or not Symbols(a.guess,false) then return false end
        local exact,partial=self:EvaluateGuess(s.secretCode,a.guess,s.codeLength)
        if a.exact~=exact or a.partial~=partial then return false end
        if exact==s.codeLength then phase="WON" elseif i==s.maxAttempts then phase="LOST" end
    end
    if s.phase~=phase or (s.resultPending~=nil and type(s.resultPending)~="boolean") then return false end
    if phase~="PLAYING" then for _,v in ipairs(s.currentGuess) do if v~=0 then return false end end end
    return true
end
