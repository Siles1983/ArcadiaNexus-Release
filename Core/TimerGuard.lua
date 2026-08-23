--[[
    ArcadiaNexus – Core/TimerGuard.lua

    Generation-guarded C_Timer wrappers. C_Timer.After cannot be cancelled in
    the WoW API; bumping _gen invalidates all pending callbacks for this guard.

    Öffentliche API:
      local tg = ArcadiaNexus.TimerGuard.New()
      tg:After(delay, fn)              -- one-shot
      tg:EveryAfter(interval, fn)      -- recursive After chain (Match3-style)
      tg:EveryTicker(interval, fn)     -- C_Timer.NewTicker (cancelled on :Cancel)
      tg:RunSequence(steps, onDone)    -- { { delay, fn }, ... } Schrittfolge
      tg:Cancel()                      -- invalidate callbacks + cancel tickers
      tg:Generation()                  -- current generation (debug/tests)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TimerGuard = {}
local TG = ArcadiaNexus.TimerGuard

function TG.New()
    return setmetatable({
        _gen     = 0,
        _tickers = {},
    }, { __index = TG })
end

function TG:Cancel()
    self._gen = self._gen + 1
    for i = 1, #self._tickers do
        local ticker = self._tickers[i]
        if ticker and ticker.Cancel then
            ticker:Cancel()
        end
    end
    self._tickers = {}
end

function TG:Generation()
    return self._gen
end

function TG:After(delay, fn)
    local gen = self._gen
    C_Timer.After(delay, function()
        if gen ~= self._gen then return end
        fn()
    end)
end

--- Rekursive After-Kette: fn() return false → stoppen; sonst nächster Tick nach interval.
function TG:EveryAfter(interval, fn)
    local gen = self._gen
    local function tick()
        if gen ~= self._gen then return end
        if fn() == false then return end
        if gen ~= self._gen then return end
        C_Timer.After(interval, tick)
    end
    C_Timer.After(interval, tick)
end

--- Festes Intervall via NewTicker; wird bei :Cancel() mit abgebrochen.
function TG:EveryTicker(interval, fn)
    local gen = self._gen
    local ticker = C_Timer.NewTicker(interval, function()
        if gen ~= self._gen then return end
        fn()
    end)
    self._tickers[#self._tickers + 1] = ticker
    return ticker
end

--- Schrittweise Sequenz (Deal-Animationen, ShellGame-Shuffle-Vorbereitung).
--- steps = { { delay = 0.3, fn = function() end }, ... }
function TG:RunSequence(steps, onDone)
    self:Cancel()
    local gen = self._gen
    local stepIdx = 1

    local function advance()
        if gen ~= self._gen then return end
        if stepIdx > #steps then
            if onDone then onDone() end
            return
        end
        local step = steps[stepIdx]
        stepIdx = stepIdx + 1

        local function runStep()
            if gen ~= self._gen then return end
            if step.fn then step.fn() end
            advance()
        end

        if step.delay and step.delay > 0 then
            self:After(step.delay, runStep)
        else
            runStep()
        end
    end

    advance()
end
