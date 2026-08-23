--[[
    ArcadiaNexus – Core/TabRegistry.lua

    Zentrale Registry für Bottom-Hub-Tabs.
    Jedes Tab-Modul registriert sich via ArcadiaNexus.RegisterHubTab().

    Öffentliche API:
        ArcadiaNexus.RegisterHubTab(info)   – Facade (Bootstrap.lua)
        ArcadiaNexus.TabRegistry.Register(info)
        ArcadiaNexus.TabRegistry.GetAll()
        ArcadiaNexus.TabRegistry.GetById(id)
        ArcadiaNexus.TabRegistry.Exists(id)
        ArcadiaNexus.TabRegistry.InvokeOnBuild(main, F)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TabRegistry = {}
local TR = ArcadiaNexus.TabRegistry

local byId = {}
local list = {}

local function SortTabs()
    table.sort(list, function(a, b)
        local ao = a.order or 999
        local bo = b.order or 999
        if ao == bo then
            return a.id < b.id
        end
        return ao < bo
    end)
end

local function RequestTabBarRebuild()
    if _G.NexusTabs and NexusTabs.RebuildBottomTabs then
        pcall(NexusTabs.RebuildBottomTabs)
    end
end

--- @param info table
--- @return table|boolean tabDef on success, false on duplicate
function TR.Register(info)
    if not info or not info.id then
        GH_LogError("TabRegistry", "RegisterHubTab requires id")
        return false
    end

    if byId[info.id] then
        GH_LogWarn("TabRegistry", "Hub-Tab bereits registriert: " .. tostring(info.id))
        return false
    end

    info.order = info.order or (#list + 1) * 10
    byId[info.id] = info
    table.insert(list, info)
    SortTabs()
    RequestTabBarRebuild()
    return info
end

--- @param id string
function TR.Unregister(id)
    local tab = byId[id]
    if not tab then return end

    byId[id] = nil
    for i, registered in ipairs(list) do
        if registered.id == id then
            table.remove(list, i)
            break
        end
    end
    RequestTabBarRebuild()
end

--- @return table[]
function TR.GetAll()
    return list
end

--- @param id string
--- @return table|nil
function TR.GetById(id)
    return byId[id]
end

--- @param id string
--- @return boolean
function TR.Exists(id)
    return byId[id] ~= nil
end

--- Ruft onBuild aller registrierten Tabs auf (MainFrame.Init).
--- @param main Frame
--- @param F table
function TR.InvokeOnBuild(main, F)
    for _, tab in ipairs(list) do
        if tab.onBuild then
            pcall(tab.onBuild, main, F)
        end
    end
end
