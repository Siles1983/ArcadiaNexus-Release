-- ============================================================
--  AlchemistsSort – Logic.lua
--  Reine Spielregeln: Zug-Validierung, Ausführung, Sieg-Prüfung,
--  Hint-Suche, DeepCopy.
--  KEINE UI, KEINE Timer, KEINE Engine-Aufrufe hier.
--
--  Datenstruktur Röhre:
--    tube[1] = oben (sichtbar / wird zuerst übertragen)
--    tube[N] = unten
--    Kapazität: 5 Schichten
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ALS_Logic = {}
local L = ArcadiaNexus.ALS_Logic

local TUBE_CAPACITY = 5

-- ── Hilfsfunktionen ───────────────────────────────────────────

-- Tiefe Kopie des gesamten Tubes-Arrays
function L:DeepCopy(tubes)
    local copy = {}
    for i, tube in ipairs(tubes) do
        copy[i] = {}
        for j, c in ipairs(tube) do
            copy[i][j] = c
        end
    end
    return copy
end

-- Oberste Farbe einer Röhre (nil wenn leer)
function L:TopColor(tube)
    return tube[1]
end

-- Anzahl aufeinanderfolgender gleicher Farben oben
function L:TopCount(tube)
    if #tube == 0 then return 0 end
    local top = tube[1]
    local count = 0
    for i = 1, #tube do
        if tube[i] == top then count = count + 1
        else break end
    end
    return count
end

-- Freie Plätze in einer Röhre
function L:FreeSlots(tube)
    return TUBE_CAPACITY - #tube
end

-- ── Zug-Validierung ───────────────────────────────────────────

-- Gibt zurück: gültig (bool), transferCount (int)
function L:IsValidMove(src, dst)
    -- Quell-Röhre leer?
    if #src == 0 then return false, 0 end
    -- Ziel-Röhre voll?
    if #dst >= TUBE_CAPACITY then return false, 0 end

    local srcTop  = self:TopColor(src)
    local dstTop  = self:TopColor(dst)
    local free    = self:FreeSlots(dst)
    local topCnt  = self:TopCount(src)

    -- Farb-Kompatibilität prüfen
    if dstTop ~= nil and dstTop ~= srcTop then
        return false, 0
    end

    local transfer = math.min(topCnt, free)
    return true, transfer
end

-- ── Zug ausführen ─────────────────────────────────────────────

-- Führt einen validierten Zug direkt auf den Tubes aus.
-- Gibt Anzahl übertragener Schichten zurück.
function L:ExecuteMove(src, dst)
    local valid, count = self:IsValidMove(src, dst)
    if not valid or count == 0 then return 0 end

    for _ = 1, count do
        local color = table.remove(src, 1)
        table.insert(dst, 1, color)
    end
    return count
end

-- ── Sieg-Prüfung ──────────────────────────────────────────────

function L:CheckWin(tubes)
    for _, tube in ipairs(tubes) do
        if #tube > 0 then
            local top = tube[1]
            for _, color in ipairs(tube) do
                if color ~= top then return false end
            end
            if #tube ~= TUBE_CAPACITY then return false end
        end
    end
    return true
end

-- ── Hint-Suche ────────────────────────────────────────────────

-- Gibt srcIdx, dstIdx zurück oder nil wenn kein Zug möglich.
-- Bevorzugt Züge die eine Röhre befüllen (gleiche Farbe oben in Ziel).
function L:FindHint(tubes)
    -- Erst: Züge auf nicht-leere Zielröhren (bessere Züge)
    for i, src in ipairs(tubes) do
        if #src > 0 then
            for j, dst in ipairs(tubes) do
                if i ~= j and #dst > 0 then
                    local valid = self:IsValidMove(src, dst)
                    if valid then return i, j end
                end
            end
        end
    end
    -- Dann: Züge auf leere Röhren
    for i, src in ipairs(tubes) do
        if #src > 0 then
            for j, dst in ipairs(tubes) do
                if i ~= j and #dst == 0 then
                    local valid = self:IsValidMove(src, dst)
                    if valid then return i, j end
                end
            end
        end
    end
    return nil
end

-- ── Deadlock-Erkennung ────────────────────────────────────────

-- Einfache Prüfung: Gibt es irgendeinen gültigen Zug?
function L:HasAnyMove(tubes)
    for i, src in ipairs(tubes) do
        for j, dst in ipairs(tubes) do
            if i ~= j then
                local valid = self:IsValidMove(src, dst)
                if valid then return true end
            end
        end
    end
    return false
end
