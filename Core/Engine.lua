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
    ArcadiaNexus.EventBus:Emit(event, ...)
end
