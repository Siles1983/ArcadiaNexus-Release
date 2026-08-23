--[[
    Gaming Hub
    Games/AzerothConquest/Logic.lua
    Version: 1.0.0

    Board-Struktur:
      board.size         – Grid-Breite/Höhe (8, 10 oder 12)
      board.cells[r][c]  – 0=leer, shipID=belegt
      board.hits[r][c]   – true=beschossen
      board.ships        – { [id] = Ship }

    Ship-Struktur:
      ship.id        – eindeutige ID (1..n)
      ship.name      – WoW-Name
      ship.length    – Felder
      ship.cells     – { {r,c}, ... } – belegte Felder
      ship.hits      – Anzahl Treffer
      ship.sunk      – bool

    WoW-Schiffe:
      Fliegende Festung  – 5 Felder  (1×)
      Kriegsgaleere      – 4 Felder  (1×)
      Zeppelin           – 3 Felder  (2×)
      Kanonenboot        – 2 Felder  (1×)

    Öffentliche API:
      Logic:CreateBoard(size)
      Logic:GetShipDefinitions(size)
      Logic:IsValidPlacement(board, r, c, length, horizontal)
      Logic:PlaceShip(board, ship, r, c, horizontal)
      Logic:PlaceShipsRandom(board)
      Logic:Shoot(board, r, c)   → "HIT"|"MISS"|"SUNK"|"ALREADY_SHOT"|"INVALID"
      Logic:AllShipsSunk(board)  → bool
      Logic:GetShipAt(board, r, c) → ship or nil
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_Logic = {}
local Logic = ArcadiaNexus.AC_Logic

-- ============================================================
-- WoW-Schiff-Definitionen (skaliert nach Grid-Größe)
-- ============================================================

function Logic:GetShipDefinitions(size)
    local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
    local defs = {
        [8] = {
            { name = L["ship_fortress"], length = 4, count = 1, icon = "achievement_fleet_admiral" },
            { name = L["ship_galleon"],  length = 3, count = 1, icon = "ability_vehicle_siegeenginecannon" },
            { name = L["ship_zeppelin"],length = 2, count = 2, icon = "inv_misc_enggizmos_32" },
            { name = L["ship_gunboat"], length = 2, count = 1, icon = "inv_misc_cannon_01" },
        },
        [10] = {
            { name = L["ship_fortress"], length = 5, count = 1, icon = "achievement_fleet_admiral" },
            { name = L["ship_galleon"],  length = 4, count = 1, icon = "ability_vehicle_siegeenginecannon" },
            { name = L["ship_zeppelin"],length = 3, count = 2, icon = "inv_misc_enggizmos_32" },
            { name = L["ship_gunboat"], length = 2, count = 1, icon = "inv_misc_cannon_01" },
        },
        [12] = {
            { name = L["ship_fortress"], length = 5, count = 1, icon = "achievement_fleet_admiral" },
            { name = L["ship_galleon"],  length = 4, count = 2, icon = "ability_vehicle_siegeenginecannon" },
            { name = L["ship_zeppelin"],length = 3, count = 2, icon = "inv_misc_enggizmos_32" },
            { name = L["ship_gunboat"], length = 2, count = 2, icon = "inv_misc_cannon_01" },
        },
    }
    return defs[size] or defs[10]
end

-- ============================================================
-- CreateBoard
-- ============================================================

function Logic:CreateBoard(size)
    size = size or 10
    local board = {
        size  = size,
        cells = {},
        hits  = {},
        ships = {},
        _nextShipID = 1,
    }
    for r = 1, size do
        board.cells[r] = {}
        board.hits[r]  = {}
        for c = 1, size do
            board.cells[r][c] = 0
            board.hits[r][c]  = false
        end
    end
    return board
end

-- ============================================================
-- IsValidPlacement
-- Prüft ob ein Schiff der Länge `length` ab (r,c) passt.
-- horizontal=true → entlang Spalten, false → entlang Zeilen
-- ============================================================

function Logic:IsValidPlacement(board, r, c, length, horizontal)
    local size = board.size
    for i = 0, length - 1 do
        local tr = r + (horizontal and 0 or i)
        local tc = c + (horizontal and i or 0)
        if tr < 1 or tr > size or tc < 1 or tc > size then
            return false
        end
        if board.cells[tr][tc] ~= 0 then
            return false
        end
    end
    return true
end

-- ============================================================
-- PlaceShip
-- Platziert ein Schiff und gibt die Ship-Tabelle zurück.
-- ============================================================

function Logic:PlaceShip(board, shipDef, r, c, horizontal)
    if not self:IsValidPlacement(board, r, c, shipDef.length, horizontal) then
        return nil
    end

    local id   = board._nextShipID
    board._nextShipID = id + 1

    local ship = {
        id         = id,
        name       = shipDef.name,
        length     = shipDef.length,
        icon       = shipDef.icon,
        cells      = {},
        hits       = 0,
        sunk       = false,
        horizontal = horizontal,
        startR     = r,
        startC     = c,
    }

    for i = 0, shipDef.length - 1 do
        local tr = r + (horizontal and 0 or i)
        local tc = c + (horizontal and i or 0)
        board.cells[tr][tc] = id
        table.insert(ship.cells, { r = tr, c = tc })
    end

    board.ships[id] = ship
    return ship
end

-- ============================================================
-- PlaceShipsRandom
-- Platziert alle Schiffe zufällig auf dem Board.
-- ============================================================

function Logic:PlaceShipsRandom(board)
    local defs = self:GetShipDefinitions(board.size)

    -- Board-Zellen leeren (nur Schiff-Felder, nicht Treffer)
    for r = 1, board.size do
        for c = 1, board.size do
            board.cells[r][c] = 0
        end
    end
    board.ships      = {}
    board._nextShipID = 1

    for _, def in ipairs(defs) do
        for _ = 1, def.count do
            local placed  = false
            local attempts = 0
            while not placed and attempts < 200 do
                attempts = attempts + 1
                local r          = math.random(1, board.size)
                local c          = math.random(1, board.size)
                local horizontal = (math.random(0, 1) == 1)
                if self:IsValidPlacement(board, r, c, def.length, horizontal) then
                    self:PlaceShip(board, def, r, c, horizontal)
                    placed = true
                end
            end
        end
    end
end

-- ============================================================
-- GetShipAt
-- ============================================================

function Logic:GetShipAt(board, r, c)
    local id = board.cells[r][c]
    if id == 0 then return nil end
    return board.ships[id]
end

-- ============================================================
-- Shoot
-- Gibt zurück: "ALREADY_SHOT" | "MISS" | "HIT" | "SUNK"
-- ============================================================

function Logic:Shoot(board, r, c)
    if r < 1 or r > board.size or c < 1 or c > board.size then
        return "INVALID"
    end
    if board.hits[r][c] then
        return "ALREADY_SHOT"
    end

    board.hits[r][c] = true

    local id = board.cells[r][c]
    if id == 0 then
        return "MISS"
    end

    local ship = board.ships[id]
    ship.hits = ship.hits + 1

    if ship.hits >= ship.length then
        ship.sunk = true
        return "SUNK"
    end

    return "HIT"
end

-- ============================================================
-- AllShipsSunk
-- ============================================================

function Logic:AllShipsSunk(board)
    for _, ship in pairs(board.ships) do
        if not ship.sunk then return false end
    end
    return true
end

-- ============================================================
-- CountRemainingShips
-- ============================================================

function Logic:CountRemainingShips(board)
    local count = 0
    for _, ship in pairs(board.ships) do
        if not ship.sunk then count = count + 1 end
    end
    return count
end
