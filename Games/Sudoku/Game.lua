--[[
    Gaming Hub
    Games/Sudoku/Game.lua
    Version: 1.0.0

    Spielzustand:
      phase    – "PLAYING" | "COMPLETE"
      grid     – aktuelles 9×9-Grid (Spieler-Eingaben)
      fixed    – welche Felder vorgegeben sind
      solution – die vollständige Lösung
      errors   – errors[r][c] = true wenn Konflikt
      selected – { r, c } oder nil (aktuell ausgewählte Zelle)
      moves    – Anzahl gesetzter Zahlen
      mistakes – Anzahl Fehler insgesamt

    API:
      Game:Init(config)
      Game:SelectCell(r, c)     → state (für Popup-Position)
      Game:PlaceNumber(num)     → result ("ok"|"error"|"complete"|"invalid_fixed")
      Game:ClearCell(r, c)      → bool
      Game:GetBoardState()
      Game:Reset()
]]

local ArcadiaNexus = _G.ArcadiaNexus

local SudokuGame = {}
SudokuGame.__index = SudokuGame
ArcadiaNexus.SDK_Game = SudokuGame

function SudokuGame:New()
    return setmetatable({}, self)
end

-- ============================================================
-- Init
-- ============================================================

function SudokuGame:Init(config)
    self.config     = config or {}
    self.logic      = ArcadiaNexus.SDK_Logic
    self.difficulty = self.config.difficulty or "normal"

    -- Puzzle generieren
    local puzzle       = self.logic:GeneratePuzzle(self.difficulty)
    self.grid          = puzzle.grid
    self.fixed         = puzzle.fixed
    self.solution      = puzzle.solution
    self.errors        = self.logic:ValidateAll(self.grid, self.fixed)

    self.phase         = "PLAYING"
    self.selected      = nil
    self.moves         = 0
    self.mistakes      = 0
    self.highlightNum  = nil  -- aktuell hervorgehobene Zahl
    self.startTime     = nil  -- für Zeiterfassung (optional)
end

-- ============================================================
-- SelectCell
-- Wählt eine Zelle aus (für Popup-Öffnung im Renderer)
-- Gibt false zurück wenn fixed
-- ============================================================

function SudokuGame:SelectCell(r, c)
    if self.phase ~= "PLAYING" then return false end
    if self.fixed[r][c] then
        -- Feste Zelle: Highlight der Zahl, aber kein Popup
        self.highlightNum = self.grid[r][c]
        self.selected     = nil
        return false
    end
    self.selected     = { r = r, c = c }
    self.highlightNum = self.grid[r][c] ~= 0 and self.grid[r][c] or nil
    return true
end

-- ============================================================
-- PlaceNumber
-- Setzt num in die aktuell ausgewählte Zelle.
-- ============================================================

function SudokuGame:PlaceNumber(num)
    if not self.selected then return "no_selection" end
    if self.phase ~= "PLAYING" then return "game_over" end

    local r, c = self.selected.r, self.selected.c
    if self.fixed[r][c] then return "invalid_fixed" end

    -- Zahl setzen
    self.grid[r][c] = num

    -- Validierung
    local valid = self.logic:IsValidMove(self.grid, r, c, num)
    if not valid then
        self.errors[r][c] = true
        self.mistakes      = self.mistakes + 1
    else
        self.errors[r][c] = false
    end

    -- Highlight aktualisieren
    self.highlightNum = num

    -- Auswahl schließen nach Setzen
    self.selected = nil
    self.moves    = self.moves + 1

    -- Vollständig?
    if self.logic:IsBoardComplete(self.grid, self.fixed) then
        self.phase = "COMPLETE"
        return "complete"
    end

    return valid and "ok" or "error"
end

-- ============================================================
-- ClearCell – Rechtsklick löscht Spieler-Zahl
-- ============================================================

function SudokuGame:ClearCell(r, c)
    if self.phase ~= "PLAYING" then return false end
    if self.fixed[r][c] then return false end
    if self.grid[r][c] == 0 then return false end

    self.grid[r][c]   = 0
    self.errors[r][c] = false
    self.selected     = nil
    self.highlightNum = nil

    -- Fehler neu berechnen (löschen kann andere Fehler aufheben)
    self.errors = self.logic:ValidateAll(self.grid, self.fixed)

    return true
end

-- ============================================================
-- Reset
-- ============================================================

function SudokuGame:Reset()
    self:Init(self.config)
end

-- ============================================================
-- GetBoardState
-- ============================================================

function SudokuGame:GetBoardState()
    return {
        grid         = self.grid,
        fixed        = self.fixed,
        solution     = self.solution,
        errors       = self.errors,
        phase        = self.phase,
        selected     = self.selected,
        highlightNum = self.highlightNum,
        moves        = self.moves,
        mistakes     = self.mistakes,
        difficulty   = self.difficulty,
    }
end
