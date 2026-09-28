--[[
    ArcadiaNexus – Core/DevToolRegistry.lua

    Registry for DevMode tools (level editors, etc.) provided by Arcadia
    or external addons via ArcadiaNexus.RegisterDevTool().

    Öffentliche API:
        ArcadiaNexus.RegisterDevTool(info)
        ArcadiaNexus.DevToolRegistry.Register / GetAll / GetById / Exists / Unregister
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.DevToolRegistry = {}
local Reg = ArcadiaNexus.DevToolRegistry

ArcadiaNexus.DevTools = ArcadiaNexus.DevTools or { apiVersion = 1 }
ArcadiaNexus.DevTools.apiVersion = 1

local byId = {}
local list = {}

local function SortTools()
    table.sort(list, function(a, b)
        local ao = a.order or 999
        local bo = b.order or 999
        if ao == bo then
            return tostring(a.id) < tostring(b.id)
        end
        return ao < bo
    end)
end

--- @param info table  { id, label?, labelKey?, hint?, hintKey?, order?, Toggle, isAvailable? }
--- @return table|boolean
function Reg.Register(info)
    if not info or not info.id then
        if GH_LogError then
            GH_LogError("DevToolRegistry", "RegisterDevTool requires id")
        end
        return false
    end
    if type(info.Toggle) ~= "function" then
        if GH_LogError then
            GH_LogError("DevToolRegistry", "RegisterDevTool requires Toggle for: " .. tostring(info.id))
        end
        return false
    end
    if byId[info.id] then
        if GH_LogWarn then
            GH_LogWarn("DevToolRegistry", "DevTool bereits registriert: " .. tostring(info.id))
        end
        return false
    end

    info.order = info.order or (#list + 1) * 10
    byId[info.id] = info
    table.insert(list, info)
    SortTools()
    return info
end

function Reg.Unregister(id)
    if not byId[id] then return end
    byId[id] = nil
    for i, registered in ipairs(list) do
        if registered.id == id then
            table.remove(list, i)
            break
        end
    end
end

function Reg.GetAll()
    return list
end

function Reg.GetById(id)
    return byId[id]
end

function Reg.Exists(id)
    return byId[id] ~= nil
end

function Reg.GetVisible()
    local out = {}
    for _, tool in ipairs(list) do
        local ok = true
        if type(tool.isAvailable) == "function" then
            local success, result = pcall(tool.isAvailable)
            ok = success and result == true
        end
        if ok then
            out[#out + 1] = tool
        end
    end
    return out
end
