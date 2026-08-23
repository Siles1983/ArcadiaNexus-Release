--[[
    ArcadiaNexus – Core/GameLoop.lua

    OnUpdate-Loop-Frame mit Generation-Counter (BlockBreaker-Pattern).

    Öffentliche API:
      local loop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_BB_LoopFrame")
      loop:Start(tickFn, opts)   -- opts.stateCheck, opts.maxDt (default 0.1)
      loop:Stop()
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GameLoop = {}
local GL = ArcadiaNexus.GameLoop

function GL.Create(frameName, parent)
    return setmetatable({
        _frameName = frameName,
        _parent    = parent or UIParent,
        _frame     = nil,
        _gen       = 0,
    }, { __index = GL })
end

function GL:_EnsureFrame()
    if self._frame then return end
    self._frame = CreateFrame("Frame", self._frameName, self._parent)
    self._frame:SetScript("OnUpdate", nil)
end

function GL:Start(tickFn, opts)
    opts = opts or {}
    local maxDt = opts.maxDt or 0.1
    self:_EnsureFrame()
    self._gen = self._gen + 1
    local gen = self._gen
    self._frame:SetScript("OnUpdate", function(_, dt)
        if self._gen ~= gen then return end
        if opts.stateCheck and not opts.stateCheck() then return end
        if dt > maxDt then dt = maxDt end
        tickFn(dt)
    end)
end

function GL:Stop()
    if self._frame then
        self._frame:SetScript("OnUpdate", nil)
    end
    self._gen = self._gen + 1
end
