--[[
    ArcadiaNexus – Core/GameSession.lua

    Zentrale Session-Ownership für Minispiele.
    Verhindert, dass verzögerte OnHide-/StopGame-Callbacks eine neuere Session abmelden.

    API:
      sessionId = GameSession:Begin(gameId)
      ok        = GameSession:Pause(gameId, sessionId)
      ok        = GameSession:Resume(gameId, sessionId)
      ok        = GameSession:End(gameId, sessionId)
      bool      = GameSession:IsCurrent(gameId, sessionId)
      GameSession:HandleRendererHide(gameId, engine, fn)

    Status: "PLAYING" | "PAUSED" (keine aktive Session = gestoppt)
    Save-and-Pause speichert den Spielstand und beendet die globale Session
    danach; PAUSED ist nur ein temporaerer Laufzeitstatus.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GameSession = {}
local GS = ArcadiaNexus.GameSession

GS._nextSessionId = 0
GS._current       = nil  -- { gameId, sessionId, status, startTime }

local function LogWarn(msg)
    if GH_LogWarn then GH_LogWarn("GameSession", msg) end
end

local function LogDebug(msg)
    if GH_LogDebug then GH_LogDebug("GameSession", msg) end
end

function GS:_Matches(gameId, sessionId)
    if not self._current then return false end
    if gameId and self._current.gameId ~= gameId then return false end
    if sessionId and self._current.sessionId ~= sessionId then return false end
    return true
end

--- Neue Spielsitzung beginnen. Gibt monotone sessionId zurück.
function GS:Begin(gameId)
    if self._current then
        LogWarn("Begin('" .. tostring(gameId) .. "') während Session " ..
            tostring(self._current.sessionId) .. " (" .. tostring(self._current.gameId) ..
            ", " .. tostring(self._current.status) .. ") noch registriert ist")
    end
    self._nextSessionId = self._nextSessionId + 1
    self._current = {
        gameId    = gameId,
        sessionId = self._nextSessionId,
        status    = "PLAYING",
        startTime = GetTime(),
    }
    LogDebug("Begin " .. tostring(gameId) .. " session " .. tostring(self._nextSessionId))
    return self._nextSessionId
end

--- Laufende Session temporaer pausieren. SaveAndPause-Pfade beenden sie nach
--- erfolgreichem Speichern wieder, damit ein Tabwechsel keine Session blockiert.
function GS:Pause(gameId, sessionId)
    if not self:_Matches(gameId, sessionId) then
        LogWarn("Pause abgelehnt für " .. tostring(gameId) ..
            " session " .. tostring(sessionId))
        return false
    end
    self._current.status = "PAUSED"
    LogDebug("Pause " .. tostring(gameId) .. " session " .. tostring(sessionId))
    return true
end

function GS:Resume(gameId, sessionId)
    if not self:_Matches(gameId, sessionId) then
        LogWarn("Resume abgelehnt für " .. tostring(gameId) ..
            " session " .. tostring(sessionId))
        return false
    end
    self._current.status = "PLAYING"
    return true
end

--- Session beenden – nur bei exakt passender sessionId.
function GS:End(gameId, sessionId)
    if not self._current then
        LogDebug("End ohne aktive Session (" .. tostring(gameId) .. ")")
        return false
    end
    if sessionId and self._current.sessionId ~= sessionId then
        LogWarn("End abgelehnt: session " .. tostring(sessionId) ..
            " != aktuelle " .. tostring(self._current.sessionId) ..
            " (" .. tostring(self._current.gameId) .. ")")
        return false
    end
    if gameId and self._current.gameId ~= gameId then
        LogWarn("End abgelehnt: gameId " .. tostring(gameId) ..
            " != aktuelle " .. tostring(self._current.gameId))
        return false
    end
    LogDebug("End " .. tostring(self._current.gameId) ..
        " session " .. tostring(self._current.sessionId))
    self._current = nil
    return true
end

function GS:ForceEnd()
    self._current = nil
end

function GS:GetCurrent()
    return self._current
end

function GS:GetActiveGameId()
    return self._current and self._current.gameId or nil
end

function GS:GetStatus()
    return self._current and self._current.status or nil
end

function GS:IsCurrent(gameId, sessionId)
    return self:_Matches(gameId, sessionId)
end

function GS:IsActiveGame(gameId)
    if not self._current then return false end
    if gameId and self._current.gameId ~= gameId then return false end
    return true
end

--- Renderer OnHide: nur ausführen wenn Engine die aktuelle Session besitzt.
function GS:HandleRendererHide(gameId, engine, fn)
    if not engine or not fn then return end
    if not engine._sessionId then return end
    if not self:IsCurrent(gameId, engine._sessionId) then return end
    fn(engine)
end

--- Guard für Timer-/State-Callbacks innerhalb einer Session.
function GS:IsSession(engine, sessionId)
    if not engine then return false end
    if sessionId and engine._sessionId ~= sessionId then return false end
    if not engine._sessionId then return false end
    local cur = self._current
    if not cur then return false end
    return cur.sessionId == engine._sessionId
end
