--[[
    ArcadiaNexus – Core/GameSession.lua

    Zentrale Session-Ownership für Minispiele.
    Verhindert, dass verzögerte OnHide-/StopGame-Callbacks eine neuere Session abmelden.

    API:
      sessionId = GameSession:Begin(gameId)
      sessionId = GameSession:ForceBegin(gameId)  -- Recovery, überschreibt
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

--- Neue Spielsitzung beginnen. Gibt monotone sessionId zurück, oder nil
--- wenn eine fremde Session aktiv bleibt. Eine verwaiste Session desselben
--- Spiels wird ersetzt. Eine fremde Session wird zuerst über
--- GameRegistry.StopActiveGame beendet.
function GS:Begin(gameId, opts)
    opts = opts or {}
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.HasPendingCleanup and GR.HasPendingCleanup() then
        LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – Renderer-Cleanup ausstehend")
        return nil
    end
    if self._current then
        if self._current.gameId == gameId then
            if self:ResumeSaveBlocked(self._current.sessionId) and not opts.force then
                LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – ungesicherter Spielstand")
                return nil
            end
            LogWarn("Begin('" .. tostring(gameId) .. "') ersetzt verwaiste Session " ..
                tostring(self._current.sessionId))
            self._current = nil
        elseif opts.force then
            LogWarn("ForceBegin('" .. tostring(gameId) .. "') überschreibt Session " ..
                tostring(self._current.sessionId) .. " (" .. tostring(self._current.gameId) .. ")")
            self._current = nil
        else
            if self:ResumeSaveBlocked(self._current.sessionId) then
                LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – ungesicherter Spielstand")
                return nil
            end
            local GR = ArcadiaNexus.GameRegistry
            if GR and GR.StopActiveGame then
                GR.StopActiveGame()
            end
            if GR and GR.HasPendingCleanup and GR.HasPendingCleanup() then
                LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – Abschluss unvollständig")
                return nil
            end
            if self._current then
                LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – Session " ..
                    tostring(self._current.sessionId) .. " (" .. tostring(self._current.gameId) ..
                    ", " .. tostring(self._current.status) .. ") noch aktiv")
                return nil
            end
        end
    end
    if GR and GR.HasPendingCleanup and GR.HasPendingCleanup() then
        LogWarn("Begin('" .. tostring(gameId) .. "') abgelehnt – Abschluss unvollständig")
        return nil
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

--- Recovery: aktive Session ohne Engine-Stop überschreiben.
function GS:ForceBegin(gameId)
    return self:Begin(gameId, { force = true })
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
    local endedGame, endedSession = self._current.gameId, self._current.sessionId
    self._current = nil
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.ReleaseConfirm then GR.ReleaseConfirm(endedGame, endedSession) end
    return true
end

function GS:ForceEnd()
    local cur = self._current
    self._current = nil
    local GR = ArcadiaNexus.GameRegistry
    if cur and GR and GR.ReleaseConfirm then GR.ReleaseConfirm(cur.gameId, cur.sessionId) end
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

--- Gescheiterter Speicherversuch dieser Session. Gilt für Hide und Leave,
--- bis eine neue Navigation oder das Öffnen des Hubs den Versuch freigibt.
function GS:MarkResumeFailed(sessionId)
    if sessionId then self._resumeFailed = sessionId end
end

function GS:ResumeSaveBlocked(sessionId)
    return sessionId ~= nil and self._resumeFailed == sessionId
end

function GS:ReleaseResumeFailure()
    self._resumeFailed = nil
end

local function IdleLeftRenderer(gameId, sessionId)
    local GR = ArcadiaNexus.GameRegistry
    if not GR or not GR.IdleRenderer then return false, "blocked" end
    return GR.IdleRenderer(gameId, sessionId)
end

local function NoteHideCleanup(gameId, sessionId, kind)
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.NotePendingCleanup then GR.NotePendingCleanup(gameId, sessionId, kind) end
end

--- Renderer OnHide: nur ausführen wenn Engine die aktuelle Session besitzt.
--- Ein schon gescheiterter Speicherversuch wird nicht wiederholt.
--- Nach erfolgreichem Speichern wird die Ansicht geleert, ohne erneut zu speichern.
--- Rückgabe: "clear" nur nach nachgewiesenem Abschluss, sonst "blocked".
function GS:HandleRendererHide(gameId, engine, fn)
    if not engine or not fn then return "blocked" end
    if not engine._sessionId then
        local GR = ArcadiaNexus.GameRegistry
        if GR and GR.HasPendingCleanup and GR.HasPendingCleanup() then return "blocked" end
        return "clear"
    end
    local sessionId = engine._sessionId
    if self:ResumeSaveBlocked(sessionId) then return "blocked" end
    if not self:IsCurrent(gameId, sessionId) then return "blocked" end
    local returned
    local ok, result = xpcall(function()
        returned = fn(engine)
    end, function(err) return tostring(err) end)
    if not ok or returned == false then
        if engine._sessionId then
            self:MarkResumeFailed(sessionId)
        else
            NoteHideCleanup(gameId, sessionId, "engine")
        end
        if not ok and GH_LogError then GH_LogError("GameSession", "Renderer-OnHide: " .. tostring(result)) end
        return "blocked"
    end
    if engine._sessionId then return "blocked" end
    local idleOk = IdleLeftRenderer(gameId, sessionId)
    if not idleOk then
        NoteHideCleanup(gameId, sessionId, "renderer")
        return "blocked"
    end
    return "clear"
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
