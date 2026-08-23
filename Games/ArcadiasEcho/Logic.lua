--[[
    Gaming Hub – Simon Says
    Games/ArcadiasEcho/Logic.lua

    Pure Spiellogik. Kein UI, kein State außer dem übergebenen Board.
    
    Board-Objekt:
    {
        difficulty      string   "easy"|"normal"|"hard"
        theme           string   Theme-Key
        grid            number   2|3|4
        symbolCount     number   grid*grid
        sequence        table    {symIdx, symIdx, ...} – wächst jede Runde
        round           number   aktuelle Runde (= Sequenzlänge)
        inputPos        number   nächster erwarteter Index in sequence
        speed           number   Blitz-Dauer in Sekunden (sinkt mit Runden)
        baseSpeed       number   Startgeschwindigkeit
        minSpeed        number   Mindestgeschwindigkeit
        speedStep       number   Reduktion pro Runde
        state           string   "showing"|"input"|"won"|"lost"
    }
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AE_Logic = {}
local L = ArcadiaNexus.AE_Logic

-- ============================================================
-- NewBoard – erzeugt ein frisches Board
-- ============================================================
function L:NewBoard(config)
    local T     = ArcadiaNexus.AE_Themes
    local diff  = T:GetDiff(config.difficulty)

    local board = {
        difficulty   = config.difficulty,
        theme        = config.theme,
        grid         = diff.grid,
        symbolCount  = diff.grid * diff.grid,
        sequence     = {},
        round        = 0,
        inputPos     = 0,
        -- Geschwindigkeit: startet bei 0.85s, minimum = maxSpeed aus Theme
        baseSpeed    = 0.85,
        minSpeed     = diff.maxSpeed,
        speedStep    = 0.04,
        speed        = 0.85,
        state        = "showing",
    }
    return board
end

-- ============================================================
-- NextRound – verlängert Sequenz um 1, setzt inputPos zurück
-- Gibt neuen symIdx zurück (der neue Schritt am Ende)
-- ============================================================
function L:NextRound(board)
    board.round    = board.round + 1
    -- Geschwindigkeit reduzieren
    local newSpeed = board.speed - board.speedStep
    if newSpeed < board.minSpeed then newSpeed = board.minSpeed end
    board.speed    = newSpeed
    -- Zufälligen Symbol-Index hinzufügen (1..symbolCount)
    local sym = math.random(1, board.symbolCount)
    board.sequence[board.round] = sym
    board.inputPos = 0
    board.state    = "showing"
    return sym
end

-- ============================================================
-- HandleInput – Spieler klickt ein Symbol
-- Gibt zurück: "correct"|"wrong"|"round_complete"
-- ============================================================
function L:HandleInput(board, symIdx)
    if board.state ~= "input" then return "wrong" end

    board.inputPos = board.inputPos + 1
    local expected = board.sequence[board.inputPos]

    if symIdx ~= expected then
        board.state = "lost"
        return "wrong"
    end

    if board.inputPos >= board.round then
        board.state = "showing"
        return "round_complete"
    end

    return "correct"
end

-- ============================================================
-- SetInputPhase – Engine setzt nach Sequenz-Anzeige
-- ============================================================
function L:SetInputPhase(board)
    board.inputPos = 0
    board.state    = "input"
end

-- ============================================================
-- GetHighscore – höchste erreichte Runde = board.round
-- ============================================================
function L:GetScore(board)
    return board.round
end
