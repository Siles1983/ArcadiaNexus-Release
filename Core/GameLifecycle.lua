--[[
    ArcadiaNexus – Core/GameLifecycle.lua
    Lifecycle-Contract – delegiert an GameSession (Session-Ownership).

    API:
      sessionId = Lifecycle:BeginGame(gameId)
      sessionId = Lifecycle:RestartGame(gameId, previousSessionId)
      ok        = Lifecycle:EndGame(gameId, sessionId)
      ok        = Lifecycle:PauseGame(gameId, sessionId)
      ok        = Lifecycle:ResumeGame(gameId, sessionId)

    Legacy (weiterhin unterstützt, session-aware wo möglich):
      Lifecycle:OnGameStart(gameId)  → BeginGame
      Lifecycle:OnGameStop(gameId, sessionId?)
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.Lifecycle = {}

local LC = ArcadiaNexus.Lifecycle

LC._startCount = 0
LC._stopCount  = 0
LC._pauseCount = 0

local function GS()
    return ArcadiaNexus.GameSession
end

function LC:BeginGame(gameId)
    local sessionId = GS():Begin(gameId)
    self._startCount = self._startCount + 1
    return sessionId
end

--- Eigene laufende Session sauber ersetzen, ohne spielabhängige StopGame-
--- Nebenwirkungen (Save-Loeschung, Ergebnisverbuchung, UI-Reset) auszuloesen.
--- Eine fremde oder bereits ersetzte Session wird nicht beendet; BeginGame
--- behaelt fuer diesen Architekturfehler seine Warnung.
function LC:RestartGame(gameId, previousSessionId)
    if previousSessionId and GS():IsCurrent(gameId, previousSessionId) then
        self:EndGame(gameId, previousSessionId)
    end
    return self:BeginGame(gameId)
end

function LC:EndGame(gameId, sessionId)
    if GS():End(gameId, sessionId) then
        self._stopCount = self._stopCount + 1
        return true
    end
    return false
end

function LC:PauseGame(gameId, sessionId)
    if GS():Pause(gameId, sessionId) then
        self._pauseCount = self._pauseCount + 1
        return true
    end
    return false
end

function LC:ResumeGame(gameId, sessionId)
    return GS():Resume(gameId, sessionId)
end

--- Legacy: gibt sessionId zurück (Engines sollten speichern).
function LC:OnGameStart(gameId)
    return self:BeginGame(gameId)
end

--- Legacy: mit sessionId sicher; ohne sessionId nur End wenn gameId zur aktuellen Session passt.
function LC:OnGameStop(gameId, sessionId)
    if sessionId then
        return self:EndGame(gameId, sessionId)
    end
    local cur = GS():GetCurrent()
    if not cur then return false end
    if gameId and cur.gameId ~= gameId then
        if GH_LogWarn then
            GH_LogWarn("Lifecycle",
                "OnGameStop('" .. tostring(gameId) ..
                "') ohne sessionId abgelehnt (aktiv: " .. tostring(cur.gameId) .. ")")
        end
        return false
    end
    return self:EndGame(cur.gameId, cur.sessionId)
end

function LC:GetActiveGame()
    return GS():GetActiveGameId()
end

function LC:GetActiveSession()
    local cur = GS():GetCurrent()
    return cur and cur.sessionId or nil
end

function LC:IsGameActive(gameId)
    return GS():IsActiveGame(gameId)
end

function LC:IsCurrentSession(gameId, sessionId)
    return GS():IsCurrent(gameId, sessionId)
end

function LC:AssertNoActiveGame(context)
    if GS():GetCurrent() then
        local cur = GS():GetCurrent()
        if GH_LogWarn then
            GH_LogWarn("Lifecycle",
                (context or "?") .. ": Session " .. tostring(cur.sessionId) ..
                " (" .. tostring(cur.gameId) .. ", " .. tostring(cur.status) ..
                ") noch aktiv!")
        end
    end
end

function LC:GetStats()
    local cur = GS():GetCurrent()
    return {
        activeGame    = cur and cur.gameId or nil,
        activeSession = cur and cur.sessionId or nil,
        status        = cur and cur.status or nil,
        starts        = self._startCount,
        stops         = self._stopCount,
        pauses        = self._pauseCount,
        uptime        = cur and cur.startTime and (GetTime() - cur.startTime) or 0,
    }
end

SLASH_ANLIFECYCLE1 = "/anlifecycle"
SlashCmdList["ANLIFECYCLE"] = function()
    local stats = LC:GetStats()
    print("|cff7ec8e3[GH Lifecycle]|r Aktiv: " ..
        (stats.activeGame and ("|cff00ff88" .. stats.activeGame .. "|r") or "|cffaaaaaa-|r"))
    if stats.activeSession then
        print("|cff7ec8e3[GH Lifecycle]|r Session: " .. stats.activeSession ..
            " | Status: " .. (stats.status or "?"))
    end
    print("|cff7ec8e3[GH Lifecycle]|r Starts: " .. stats.starts ..
        " | Stops: " .. stats.stops ..
        " | Pauses: " .. stats.pauses ..
        " | Uptime: " .. string.format("%.1fs", stats.uptime))
end
