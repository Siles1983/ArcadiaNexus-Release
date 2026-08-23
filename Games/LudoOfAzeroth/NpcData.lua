--[[
    Ludo of Azeroth – NpcData.lua
    3D-NPC-Figuren pro Fraktion (PlayerModel + SetCreature).

    SetCreature(creatureID) kann Varianten würfeln → optional displayID mitgeben.
    Modelle werden nur neu geladen, wenn sich Fraktion oder IDs am Frame ändern.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_NpcData = {}
local N = ArcadiaNexus.LOA_NpcData

N.ANIM = {
    idle = 0,
    walk = 4,
}

-- creatureID = NPC-Template; displayID optional für festes Aussehen
N.models = {
    [1] = { creatureID =  1423, rotation = 0.40, zoom = 0.15, camScale = 0.90, name = "Stormwind",     race = "Mensch" },
    [2] = { creatureID =  3296, rotation = 0.40, zoom = 0.15, camScale = 0.90, name = "Orgrimmar",     race = "Orc"    }, -- Orgrimmar-Grunt
    [3] = { creatureID = 72559, rotation = 0.40, zoom = 0.15, camScale = 0.90, name = "Thunder Bluff", race = "Tauren" },
    [4] = { creatureID =  5595, rotation = 0.40, zoom = 0.15, camScale = 0.90, name = "Ironforge",     race = "Zwerg"  },
}

function N:GetModelDef(colorIdx)
    return self.models[colorIdx]
end

function N:WarmupCache()
    for colorIdx = 1, 4 do
        self:EnsureDisplayID(self.models[colorIdx])
    end
end

function N:EnsureDisplayID(def)
    if not def or (def.displayID and def.displayID > 0) or not def.creatureID then
        return def and def.displayID or nil
    end
    if C_CreatureInfo and C_CreatureInfo.GetCreatureInfo then
        local info = C_CreatureInfo.GetCreatureInfo(def.creatureID)
        if info and info.displayID and info.displayID > 0 then
            def.displayID = info.displayID
            return info.displayID
        end
    end
    return nil
end

function N:ApplyView(modelFrame, def)
    if not modelFrame or not def then return end
    if def.rotation and modelFrame.SetRotation then
        modelFrame:SetRotation(def.rotation)
    end
    if def.zoom and modelFrame.SetPortraitZoom then
        modelFrame:SetPortraitZoom(def.zoom)
    end
    if def.camScale and modelFrame.SetCamDistanceScale then
        modelFrame:SetCamDistanceScale(def.camScale)
    end
    if modelFrame.RefreshCamera then
        modelFrame:RefreshCamera()
    end
end

function N:_ScheduleModelRefresh(modelFrame, def)
    if not modelFrame or not def or not C_Timer or not C_Timer.After then return end
    local delays = { 0.05, 0.12, 0.25 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if not modelFrame or not modelFrame.GetParent then return end
            N:ApplyView(modelFrame, def)
            N:PlayAnim(modelFrame, "idle")
        end)
    end
end

function N:ApplyModel(modelFrame, colorIdx)
    if not modelFrame then return false end
    local def = self:GetModelDef(colorIdx)
    if not def or not def.creatureID then return false end

    local creatureID = def.creatureID
    local displayID = self:EnsureDisplayID(def)

    if modelFrame._loaColorIdx == colorIdx
        and modelFrame._loaCreatureID == creatureID
        and (modelFrame._loaDisplayID or 0) == (displayID or 0) then
        return true
    end

    modelFrame:ClearModel()

    if not modelFrame.SetCreature then return false end
    local ok = pcall(function()
        if displayID and displayID > 0 then
            modelFrame:SetCreature(creatureID, displayID)
        else
            modelFrame:SetCreature(creatureID)
        end
    end)
    if not ok then return false end

    modelFrame._loaColorIdx = colorIdx
    modelFrame._loaCreatureID = creatureID
    modelFrame._loaDisplayID = displayID
    modelFrame._loaAnim = nil
    self:ApplyView(modelFrame, def)
    self:_ScheduleModelRefresh(modelFrame, def)
    return true
end

function N:PlayAnim(modelFrame, animKey)
    if not modelFrame or not modelFrame.SetAnimation then return end
    local id = self.ANIM[animKey] or self.ANIM.idle
    if modelFrame._loaAnim == id then return end
    modelFrame:SetAnimation(id)
    modelFrame._loaAnim = id
end

function N:ClearModelCache(modelFrame)
    if not modelFrame then return end
    modelFrame._loaColorIdx = nil
    modelFrame._loaDisplayID = nil
    modelFrame._loaCreatureID = nil
    modelFrame._loaAnim = nil
end

function N:DumpCreatureInfo(creatureID)
    creatureID = tonumber(creatureID)
    if not creatureID then return nil end
    local info = C_CreatureInfo and C_CreatureInfo.GetCreatureInfo and C_CreatureInfo.GetCreatureInfo(creatureID)
    return {
        creatureID = creatureID,
        name = info and info.name or nil,
        displayID = info and info.displayID or nil,
        cached = info ~= nil,
    }
end
