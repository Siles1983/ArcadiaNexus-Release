--[[
    Gaming Hub
    Engine.lua

    Event-Facade für das Addon (delegiert an EventBus).
    Spiel-Lifecycle liegt in pro-Spiel-Engines (TTT_Engine, SDK_Engine, …).
    Hub-Spiel-Metadaten: Core/GameRegistry.lua + ArcadiaNexus.RegisterGame().
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.Engine = {}

local Engine = ArcadiaNexus.Engine

-- ==========================================
-- Init
-- ==========================================

function Engine:Init()
    local seed = GetServerTime()
    if _G.math and _G.math.randomseed then
        _G.math.randomseed(seed)
    end

    GH_LogInfo("Engine", "ArcadiaNexus Engine bereit.")
end

-- ==========================================
-- Event System (delegiert an EventBus)
-- ==========================================

function Engine:On(event, callback)
    return ArcadiaNexus.EventBus:On(event, callback)
end

function Engine:Off(event, callback)
    return ArcadiaNexus.EventBus:Off(event, callback)
end

function Engine:Emit(event, ...)
    local LR = ArcadiaNexus.LocalResults
    if LR and LR:BufferEvent(event, ...) then return end
    local GRP = ArcadiaNexus.GameResultProcessor
    if GRP and GRP.BufferEvent and GRP:BufferEvent(event, ...) then return end
    local AM = ArcadiaNexus.AchievementManager
    if AM and AM.BufferEvent and AM:BufferEvent(event, ...) then return end
    ArcadiaNexus.EventBus:Emit(event, ...)
end
