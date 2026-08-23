-- ============================================================
--  Azeroth Jewels – PowerUps.lua
--  Reine Effekt- und Auflade-Logik. KEIN UI, KEIN CreateFrame,
--  KEINE Timer (GDD §6, §10.2).
--
--  5 PowerUps (GDD §6.2):
--    fire  – Feuernova:      Kreuz aus 5 Feldern        · lädt: Combo ×3
--    frost – Frost Nova:     ganze Reihe oder Spalte    · lädt: Combo ×4
--    chain – Kettenblitz:    alle Gems gleicher Farbe   · lädt: Combo ×5
--    bomb  – Goblin-Bombe:   3×3 Explosion              · lädt: 500 Punkte
--    holy  – Heiliger Strahl: 3 zufällige → Wildcard    · lädt: 1000 Punkte
--
--  Inventar: max. 3 pro Typ.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_PowerUps = {}
local P = ArcadiaNexus.AJ_PowerUps

P.MAX_INVENTORY = 3

-- Reihenfolge für UI-Leiste
P.ORDER = { "fire", "frost", "chain", "bomb", "holy" }

-- chargeType "combo": Zähler = erreichte Combo-Stufen (jede Kaskaden-Stufe ab ×2 zählt 1)
-- chargeType "score": Zähler = verdiente Punkte
P.DEFS = {
    fire  = { chargeType = "combo", chargeTarget = 3,    needsTarget = true  },
    frost = { chargeType = "combo", chargeTarget = 4,    needsTarget = true  },
    chain = { chargeType = "combo", chargeTarget = 5,    needsTarget = true  },
    bomb  = { chargeType = "score", chargeTarget = 500,  needsTarget = true  },
    holy  = { chargeType = "score", chargeTarget = 1000, needsTarget = false },
}

-- ============================================================
-- Auflade-State
-- ============================================================
function P:NewState(inventory, progress)
    local pu = { inv = {}, progress = {} }
    for _, id in ipairs(P.ORDER) do
        pu.inv[id]      = math.min(P.MAX_INVENTORY, (inventory and inventory[id]) or 0)
        pu.progress[id] = (progress and progress[id]) or 0
    end
    return pu
end

function P:GetProgressFraction(pu, id)
    local def = P.DEFS[id]
    if not def then return 0 end
    return math.min(1, (pu.progress[id] or 0) / def.chargeTarget)
end

function P:CanUse(pu, id)
    return (pu.inv[id] or 0) > 0
end

-- Interner Helfer: Fortschritt hinzufügen, volle Ladungen ins Inventar
local function AddProgress(pu, id, amount, charged)
    local def = P.DEFS[id]
    pu.progress[id] = (pu.progress[id] or 0) + amount
    while pu.progress[id] >= def.chargeTarget do
        if (pu.inv[id] or 0) >= P.MAX_INVENTORY then
            -- Inventar voll: Fortschritt am Maximum deckeln
            pu.progress[id] = def.chargeTarget
            return
        end
        pu.progress[id] = pu.progress[id] - def.chargeTarget
        pu.inv[id] = (pu.inv[id] or 0) + 1
        charged[#charged+1] = id
    end
end

--- Nach einer Kaskaden-Stufe aufrufen: comboDepth = state.comboCount nach dem Match.
--- Jede Stufe ab ×2 (comboDepth >= 2) zählt +1 für alle Combo-PowerUps.
--- Rückgabe: Liste neu aufgeladener PowerUp-IDs.
function P:OnComboStep(pu, comboDepth)
    local charged = {}
    if comboDepth >= 2 then
        for _, id in ipairs(P.ORDER) do
            if P.DEFS[id].chargeType == "combo" then
                AddProgress(pu, id, 1, charged)
            end
        end
    end
    return charged
end

--- Nach Punktegewinn aufrufen. Rückgabe: Liste neu aufgeladener IDs.
function P:OnScoreGained(pu, points)
    local charged = {}
    if points > 0 then
        for _, id in ipairs(P.ORDER) do
            if P.DEFS[id].chargeType == "score" then
                AddProgress(pu, id, points, charged)
            end
        end
    end
    return charged
end

--- Sofortige volle Ladung (5er+-Match, GDD §3.1). Lädt das erste
--- Combo-PowerUp mit Platz im Inventar voll auf.
function P:OnFivePlusMatch(pu)
    for _, id in ipairs(P.ORDER) do
        local def = P.DEFS[id]
        if def.chargeType == "combo" and (pu.inv[id] or 0) < P.MAX_INVENTORY then
            pu.inv[id] = (pu.inv[id] or 0) + 1
            return { id }
        end
    end
    return {}
end

--- Verbraucht eine Ladung. Rückgabe: true bei Erfolg.
function P:Consume(pu, id)
    if not P:CanUse(pu, id) then return false end
    pu.inv[id] = pu.inv[id] - 1
    return true
end

-- ============================================================
-- Ziel-Berechnung (für Hover-Highlight UND Ausführung)
-- ============================================================
-- target = { row=N, col=N, axis="row"|"col" (nur frost) }
-- Rückgabe: Zell-Liste { {r,c}, … } (LOCKED wird von Logic ignoriert)
function P:GetTargetCells(state, id, target)
    local cells = {}
    if id == "fire" then
        local r, c = target.row, target.col
        cells = { {r,c}, {r-1,c}, {r+1,c}, {r,c-1}, {r,c+1} }
    elseif id == "frost" then
        if target.axis == "col" then
            for r = 1, state.rows do cells[#cells+1] = { r, target.col } end
        else
            for c = 1, state.cols do cells[#cells+1] = { target.row, c } end
        end
    elseif id == "chain" then
        local Logic = ArcadiaNexus.AJ_Logic
        local gem = state.board[target.row] and state.board[target.row][target.col]
        if gem and gem > 0 and gem ~= Logic.WILD then
            for r = 1, state.rows do
                for c = 1, state.cols do
                    if state.board[r][c] == gem then
                        cells[#cells+1] = { r, c }
                    end
                end
            end
        end
    elseif id == "bomb" then
        for dr = -1, 1 do
            for dc = -1, 1 do
                cells[#cells+1] = { target.row + dr, target.col + dc }
            end
        end
    end
    return cells
end

--- Prüft ob target für das PowerUp gültig ist.
function P:IsValidTarget(state, id, target)
    if not target then return false end
    local r, c = target.row, target.col
    if not r or not c or r < 1 or r > state.rows or c < 1 or c > state.cols then
        return false
    end
    if id == "chain" then
        local Logic = ArcadiaNexus.AJ_Logic
        local gem = state.board[r][c]
        return gem and gem > 0 and gem ~= Logic.WILD
            and not Logic:IsBlocked(state, r, c)
    end
    return true
end

-- ============================================================
-- Ausführung
-- ============================================================
-- Wendet das PowerUp auf den Logic-State an (ohne Inventar-Abzug,
-- den macht die Engine via Consume).
-- Rückgabe: result = {
--   removedKeys = {key=true} | nil,   – zerstörte Zellen (Animation)
--   converted   = { {r,c}, … } | nil, – Wildcard-Zellen (holy)
--   gainedScore = N,
-- }
function P:Apply(state, id, target)
    local Logic = ArcadiaNexus.AJ_Logic
    state.stats.powerUpsUsed = state.stats.powerUpsUsed + 1

    if id == "holy" then
        local converted = Logic:ConvertRandomToWild(state, 3)
        return { converted = converted, gainedScore = 0 }
    end

    local cells = self:GetTargetCells(state, id, target)
    local _, gained, removedKeys = Logic:RemoveCellsForPowerUp(state, cells)
    return { removedKeys = removedKeys, gainedScore = gained }
end
