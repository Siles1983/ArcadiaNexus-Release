--[[
    ArcadiaNexus – Core/HubSettingsTabRegistry.lua

    Zentrale Registry für Hub-Settings-SubTabs.
    Jedes Tab-Modul registriert sich via ArcadiaNexus.RegisterHubSettingsTab().

    Öffentliche API:
        ArcadiaNexus.RegisterHubSettingsTab(info)   – Facade (Bootstrap.lua)
        ArcadiaNexus.HubSettingsTabRegistry.Register(info)
        ArcadiaNexus.HubSettingsTabRegistry.GetAll()
        ArcadiaNexus.HubSettingsTabRegistry.GetById(id)
        ArcadiaNexus.HubSettingsTabRegistry.Exists(id)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HubSettingsTabRegistry = {}
local HSTR = ArcadiaNexus.HubSettingsTabRegistry

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
    local HS = ArcadiaNexus.HubSettings
    if HS and HS.RebuildTabBar then
        pcall(HS.RebuildTabBar, HS)
    end
end

--- @param info table  { id, labelKey?, labelFallback?, order?, buildContent(parent), onSelect?, refreshLayout(hs, scrollWidth) }
--- @return table|boolean
function HSTR.Register(info)
    if not info or not info.id then
        GH_LogError("HubSettingsTabRegistry", "RegisterHubSettingsTab requires id")
        return false
    end

    if not info.buildContent then
        GH_LogError("HubSettingsTabRegistry", "RegisterHubSettingsTab requires buildContent for: " .. tostring(info.id))
        return false
    end

    if byId[info.id] then
        GH_LogWarn("HubSettingsTabRegistry", "Settings-Tab bereits registriert: " .. tostring(info.id))
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
function HSTR.Unregister(id)
    if not byId[id] then return end

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
function HSTR.GetAll()
    return list
end

--- @param id string
--- @return table|nil
function HSTR.GetById(id)
    return byId[id]
end

--- @param id string
--- @return boolean
function HSTR.Exists(id)
    return byId[id] ~= nil
end

--- @return string|nil
function HSTR.GetDefaultTabId()
    local tabs = HSTR.GetAll()
    return tabs[1] and tabs[1].id or nil
end
