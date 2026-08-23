--[[
    ArcadiaNexus – UI/Core/FramePool.lua

    Homogener Frame-Pool für dynamische UI-Wiederverwendung.
    Verwaltet nur den Lebenszyklus – keine Layout-, Spiel- oder Session-Logik.

    Öffentliche API:
      local pool = ArcadiaNexus.UI.FramePool.New({
          name       = "MyGame.Chips",           -- optional, für Diagnose
          create     = function(poolParent) ... end,  -- Pflicht
          onAcquire  = function(frame, context) ... end,
          onRelease  = function(frame) ... end,
      })
      local frame = pool:Acquire({ parent = parent })
      pool:Release(frame)
      pool:ReleaseAll()
      pool:IsOwned(object)
      pool:IsActive(object)
      local stats = pool:GetStats()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.UI = ArcadiaNexus.UI or {}
ArcadiaNexus.UI.FramePool = {}
local FP = ArcadiaNexus.UI.FramePool

local LOG_SOURCE = "FramePool"

-- ============================================================
-- VERSTECKTER POOL-ROOT (lazy)
-- ============================================================

local _poolRoot = nil

local function _GetPoolRoot()
    if not _poolRoot then
        _poolRoot = CreateFrame("Frame", "ArcadiaNexus_FramePoolRoot", UIParent)
        _poolRoot:Hide()
    end
    return _poolRoot
end

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================

local function _CountActive(active)
    local n = 0
    for _ in pairs(active) do
        n = n + 1
    end
    return n
end

local function _DevLogError(msg)
    if ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() then
        GH_LogError(LOG_SOURCE, msg)
    end
end

local function _SafeQuarantineCall(pool, object, methodName, ...)
    local method = object and object[methodName]
    if type(method) ~= "function" then return end
    local ok, callErr = pcall(method, object, ...)
    if not ok then
        _DevLogError(pool._name .. ": Quarantäne-" .. methodName
            .. " fehlgeschlagen – " .. tostring(callErr))
    end
end

local function _Quarantine(pool, object, callbackKind, err)
    _DevLogError(pool._name .. ": " .. callbackKind .. " fehlgeschlagen – " .. tostring(err))
    pool._callbackErrors = pool._callbackErrors + 1
    if object and pool._quarantined[object] then
        return
    end
    if object then
        pool._quarantined[object] = true
        pool._quarantineCount = pool._quarantineCount + 1
        _SafeQuarantineCall(pool, object, "Hide")
        _SafeQuarantineCall(pool, object, "ClearAllPoints")
        _SafeQuarantineCall(pool, object, "SetParent", _GetPoolRoot())
    end
end

-- ============================================================
-- POOL-INSTANZ
-- ============================================================

function FP.New(config)
    if not config or type(config.create) ~= "function" then
        error("FramePool.New: config.create ist Pflicht", 2)
    end

    return setmetatable({
        _name            = config.name or "FramePool",
        _create          = config.create,
        _onAcquire       = config.onAcquire,
        _onRelease       = config.onRelease,
        _available       = {},
        _active          = {},
        _owned           = {},
        _quarantined     = {},
        _created         = 0,
        _activeCount     = 0,
        _quarantineCount = 0,
        _callbackErrors  = 0,
        _highWatermark   = 0,
    }, { __index = FP })
end

function FP:Acquire(context)
    local frame = table.remove(self._available)

    if not frame then
        local poolParent = _GetPoolRoot()
        frame = self._create(poolParent)
        if not frame then
            _DevLogError(self._name .. ": create() hat nil zurückgegeben")
            return nil
        end
        self._owned[frame] = true
        self._created = self._created + 1
    end

    if self._quarantined[frame] then
        _DevLogError(self._name .. ": Acquire eines quarantänisierten Objekts abgelehnt")
        return nil
    end

    if self._onAcquire then
        local ok, err = pcall(self._onAcquire, frame, context)
        if not ok then
            _Quarantine(self, frame, "onAcquire", err)
            return nil
        end
    end

    self._active[frame] = true
    self._activeCount = self._activeCount + 1
    if self._activeCount > self._highWatermark then
        self._highWatermark = self._activeCount
    end

    return frame
end

function FP:Release(object)
    if not object then return false end

    if not self._owned[object] then
        _DevLogError(self._name .. ": Release eines fremden Objekts abgelehnt")
        return false
    end

    if not self._active[object] then
        _DevLogError(self._name .. ": Doppelter Release abgelehnt")
        return false
    end

    self._active[object] = nil
    self._activeCount = self._activeCount - 1

    if self._onRelease then
        local ok, err = pcall(self._onRelease, object)
        if not ok then
            _Quarantine(self, object, "onRelease", err)
            return false
        end
    end

    table.insert(self._available, object)
    return true
end

function FP:ReleaseAll()
    local toRelease = {}
    for obj in pairs(self._active) do
        toRelease[#toRelease + 1] = obj
    end
    for i = 1, #toRelease do
        self:Release(toRelease[i])
    end
end

function FP:IsOwned(object)
    return object ~= nil and self._owned[object] == true
end

function FP:IsActive(object)
    return object ~= nil and self._active[object] == true
end

function FP:GetStats()
    if ArcadiaNexus.IsDevMode and ArcadiaNexus.IsDevMode() then
        local counted = _CountActive(self._active)
        if counted ~= self._activeCount then
            _DevLogError(self._name .. ": activeCount-Invariante verletzt ("
                .. tostring(self._activeCount) .. " vs " .. tostring(counted) .. ")")
        end
    end

    return {
        name           = self._name,
        created        = self._created,
        active         = self._activeCount,
        available      = #self._available,
        quarantined    = self._quarantineCount,
        callbackErrors = self._callbackErrors,
        highWatermark  = self._highWatermark,
    }
end
