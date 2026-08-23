--[[
    Gaming Hub
    Games/AzerothConquest/Game.lua
    Version: 1.0.0

    Phasen:
      PLACEMENT  – Spieler platziert Schiffe (oder klickt "Zufällig")
      BATTLE     – Abwechselnd: Spieler schießt, dann KI
      GAMEOVER   – Alle Schiffe einer Seite versenkt

    Config:
      size         – Grid-Größe (8|10|12)
      aiDifficulty – "easy"|"normal"|"hard"

    Board-Konvention:
      self.playerBoard – Schiffe des Spielers
      self.aiBoard     – Schiffe der KI (unsichtbar für Renderer bis versenkt)
]]

local ArcadiaNexus = _G.ArcadiaNexus

local BSGame = {}
BSGame.__index = BSGame
ArcadiaNexus.AC_Game = BSGame

function BSGame:New()
    return setmetatable({}, self)
end

function BSGame:Init(config)
    self.config       = config or {}
    self.logic        = ArcadiaNexus.AC_Logic
    self.ai           = ArcadiaNexus.AC_AI

    local size           = self.config.size or 10
    self.aiDifficulty    = self.config.aiDifficulty or "easy"
    self.phase           = "PLACEMENT"

    -- Boards
    self.playerBoard = self.logic:CreateBoard(size)
    self.aiBoard     = self.logic:CreateBoard(size)

    -- KI-Board sofort zufällig befüllen
    self.logic:PlaceShipsRandom(self.aiBoard)

    -- Placement-State
    self.shipQueue       = self:_BuildShipQueue(size)  -- Schiffe die noch platziert werden müssen
    self.currentShipIdx  = 1
    self.placementHoriz  = true   -- aktuelle Ausrichtung
    self.lastShot        = nil
    self.lastAiShot      = nil
    self.gameOver        = false
    self.result          = nil
    self.sunkByPlayer    = {}  -- Liste versenkter KI-Schiffe (für Renderer)
    self.sunkByAI        = {}  -- Liste versenkter Spieler-Schiffe
end

-- ============================================================
-- Schiff-Queue aufbauen (flache Liste aller zu platzierenden Schiffe)
-- ============================================================

function BSGame:_BuildShipQueue(size)
    local defs  = self.logic:GetShipDefinitions(size)
    local queue = {}
    for _, def in ipairs(defs) do
        for _ = 1, def.count do
            table.insert(queue, {
                name   = def.name,
                length = def.length,
                icon   = def.icon,
            })
        end
    end
    return queue
end

-- ============================================================
-- GetCurrentShip – das Schiff das gerade platziert werden soll
-- ============================================================

function BSGame:GetCurrentShip()
    return self.shipQueue[self.currentShipIdx]
end

-- ============================================================
-- ToggleOrientation – R-Taste
-- ============================================================

function BSGame:ToggleOrientation()
    self.placementHoriz = not self.placementHoriz
end

-- ============================================================
-- PlaceShip – Spieler platziert ein Schiff auf (r, c)
-- Gibt true zurück wenn erfolgreich
-- ============================================================

function BSGame:PlaceShip(r, c)
    if self.phase ~= "PLACEMENT" then return false end

    local shipDef = self:GetCurrentShip()
    if not shipDef then return false end

    local ship = self.logic:PlaceShip(
        self.playerBoard, shipDef, r, c, self.placementHoriz
    )

    if not ship then return false end  -- ungültige Position

    self.currentShipIdx = self.currentShipIdx + 1

    -- Alle Schiffe platziert?
    if self.currentShipIdx > #self.shipQueue then
        self.phase = "BATTLE"
    end

    return true
end

-- ============================================================
-- PlaceAllRandom – Spieler klickt "Zufällig"
-- ============================================================

function BSGame:PlaceAllRandom()
    self.logic:PlaceShipsRandom(self.playerBoard)
    self.currentShipIdx = #self.shipQueue + 1
    self.phase          = "BATTLE"
end

-- ============================================================
-- HandleShot – Spieler schießt auf KI-Board bei (r, c)
-- ============================================================

function BSGame:HandleShot(r, c)
    if self.phase ~= "BATTLE" or self.gameOver then return end

    -- FIX: lastShot immer zuerst zurücksetzen.
    -- So bleibt es nil wenn ALREADY_SHOT/INVALID → Engine erkennt "kein gültiger Schuss"
    self.lastShot   = nil
    self.lastAiShot = nil

    local result = self.logic:Shoot(self.aiBoard, r, c)

    if result == "ALREADY_SHOT" or result == "INVALID" then return end

    self.lastShot = { r = r, c = c, result = result }
    self.totalShots = (self.totalShots or 0) + 1
    if result == "MISS" then
        self.totalMisses = (self.totalMisses or 0) + 1
    end

    if result == "SUNK" then
        local ship = self.logic:GetShipAt(self.aiBoard, r, c)
        if ship then
            table.insert(self.sunkByPlayer, ship)
        end
    end

    -- Spieler hat gewonnen?
    if self.logic:AllShipsSunk(self.aiBoard) then
        self.gameOver = true
        self.result   = "WIN"
        return
    end

    -- KI-Zug
    self:_DoAIShot()
end

-- ============================================================
-- KI-Zug
-- ============================================================

function BSGame:_DoAIShot()
    local target = self.ai:GetBestMove(self.playerBoard, self.aiDifficulty)
    if not target then return end

    local result = self.logic:Shoot(self.playerBoard, target.r, target.c)
    self.lastAiShot = { r = target.r, c = target.c, result = result }

    if result == "SUNK" then
        local ship = self.logic:GetShipAt(self.playerBoard, target.r, target.c)
        if ship then
            table.insert(self.sunkByAI, ship)
        end
    end

    -- KI hat gewonnen?
    if self.logic:AllShipsSunk(self.playerBoard) then
        self.gameOver = true
        self.result   = "LOSS"
    end
end

-- ============================================================
-- Reset
-- ============================================================

function BSGame:Reset()
    self:Init(self.config)
end

-- ============================================================
-- GetBoardState
-- ============================================================

function BSGame:GetBoardState()
    return {
        size          = self.playerBoard.size,
        phase         = self.phase,
        gameOver      = self.gameOver,
        result        = self.result,

        -- Spieler
        playerBoard   = self.playerBoard,
        lastAiShot    = self.lastAiShot,
        sunkByAI      = self.sunkByAI,

        -- KI (nur Treffer/Misses sichtbar, keine Schiffspositionen)
        aiBoard       = self.aiBoard,
        lastShot      = self.lastShot,
        sunkByPlayer  = self.sunkByPlayer,

        -- Placement
        currentShip   = self:GetCurrentShip(),
        placementHoriz = self.placementHoriz,
        shipsPlaced    = self.currentShipIdx - 1,
        totalShips     = #self.shipQueue,

        -- Stats für Achievements
        totalShots    = self.totalShots or 0,
        totalMisses   = self.totalMisses or 0,
    }
end
