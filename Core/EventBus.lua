--[[
    ArcadiaNexus – Core/EventBus.lua
    Zentrales Event-System

    API:
        ArcadiaNexus.EventBus:On(event, callback)
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
function EventBus:On(event, callback)
    if not event or not callback then
        GH_LogWarn("EventBus", "On() mit nil-Argument: event=" .. tostring(event))
        return
    end
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    table.insert(self._listeners[event], callback)
end

-- ============================================================
-- EMISSION
-- ============================================================

--- Feuert ein Event. Alle registrierten Listener werden aufgerufen.
--- Unterstützt beliebig viele Argumente (data, ...).
function EventBus:Emit(event, ...)
    if not self._listeners[event] then return end
    for _, cb in ipairs(self._listeners[event]) do
        local ok, err = pcall(cb, ...)
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
