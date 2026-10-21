--[[
    ArcadiaNexus – Core/EventBus.lua
    Zentrales Event-System

    API:
        dispose = ArcadiaNexus.EventBus:On(event, callback)
        ArcadiaNexus.EventBus:Emit(event, data, ...)
        ArcadiaNexus.EventBus:Off(event, callback)
        ArcadiaNexus.EventBus:Clear(event)
        ArcadiaNexus.EventBus:GetListenerCount(event)

    Rückwärtskompatibel:
        ArcadiaNexus.Engine:On()  und  ArcadiaNexus.Engine:Emit()
        delegieren automatisch an EventBus (siehe Engine.lua).
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.EventBus = {}

local EventBus = ArcadiaNexus.EventBus

EventBus._listeners = {}

-- ============================================================
-- REGISTRIERUNG
-- ============================================================

--- Registriert einen Listener für ein Event.
--- WICHTIG: Immer in Init()-Funktionen aufrufen, NICHT auf Modul-Ebene!
--- Gibt eine Dispose-Funktion zurück. Derselbe Callback wird pro Event nur einmal registriert.
function EventBus:On(event, callback)
    if not event or not callback then
        GH_LogWarn("EventBus", "On() mit nil-Argument: event=" .. tostring(event))
        return
    end
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    local list = self._listeners[event]
    for i = 1, #list do
        if list[i] == callback then
            return function()
                EventBus:Off(event, callback)
            end
        end
    end
    table.insert(list, callback)
    return function()
        EventBus:Off(event, callback)
    end
end

-- ============================================================
-- EMISSION
-- ============================================================

--- Feuert ein Event synchron und reicht alle Argumente unverändert weiter, einschließlich nil.
--- Beim Eintritt wird eine Momentaufnahme der Callback-Referenzen gebildet.
--- Diese Teilnehmer werden in Registrierungsreihenfolge jeweils einmal aufgerufen.
--- On, Off und Clear ändern die Registry sofort, den begonnenen Dispatch aber nicht:
--- Selbst- und Fremdabmeldungen, Neuregistrierungen und Clear gelten erst für
--- anschließend gestartete Emissionen. Jeder rekursive Emit-Aufruf erhält eine
--- eigene Momentaufnahme des dann aktuellen Registrierungsstands.
--- Ein Listenerfehler bleibt isoliert; nachfolgende Teilnehmer laufen weiter.
function EventBus:Emit(event, ...)
    local list = self._listeners[event]
    local count = list and #list or 0
    if count == 0 then return end

    local dispatch = {}
    for i = 1, count do
        dispatch[i] = list[i]
    end

    for i = 1, count do
        local ok, err = pcall(dispatch[i], ...)
        if not ok then
            GH_LogError("EventBus", "Listener-Fehler bei '" .. tostring(event) .. "': " .. tostring(err))
        end
    end
end

-- ============================================================
-- DEREGISTRIERUNG
-- ============================================================

--- Entfernt einen spezifischen Listener.
function EventBus:Off(event, callback)
    if not self._listeners[event] then return end
    for i = #self._listeners[event], 1, -1 do
        if self._listeners[event][i] == callback then
            table.remove(self._listeners[event], i)
            return
        end
    end
end

--- Entfernt ALLE Listener für ein Event.
function EventBus:Clear(event)
    if event then
        self._listeners[event] = nil
    else
        self._listeners = {}
    end
end

-- ============================================================
-- DIAGNOSE
-- ============================================================

function EventBus:GetListenerCount(event)
    if event then
        return self._listeners[event] and #self._listeners[event] or 0
    end
    local total = 0
    for _, list in pairs(self._listeners) do
        total = total + #list
    end
    return total
end
