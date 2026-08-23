--[[
    Tavern Cards – NpcData.lua
    3D-NPC-Pool (PlayerModel + SetCreature).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_NpcData = {}
local N = ArcadiaNexus.TC_NpcData

N.ANIM = {
    idle = 0, play = 67, draw = 66, uno = 71, win = 53, lose = 6,
}

-- view = "left" | "right" — Fallback; pro Slot in Renderer-CFG überschreibbar via rotation
N.VIEW_LEFT  = { rotation = 0.40,     zoom = 0.15, camScale = 0.90 }
N.VIEW_RIGHT = { rotation = -0.40, zoom = 0.15, camScale = 0.90 } -- math.pi - 0.40

N.POOL = {
    { key = "thrall",    name = "Thrall",     creatureID = 223722 },
    { key = "arthas",    name = "Arthas",     creatureID = 26499  },
    { key = "sylvanas",  name = "Sylvanas",   creatureID = 38609  },
    { key = "illidan",   name = "Illidan",    creatureID = 116146 },
    { key = "jaina",     name = "Jaina",      creatureID = 120590 },
    { key = "anduin",    name = "Anduin",     creatureID = 225897 },
    { key = "muradin",   name = "Muradin",    creatureID = 42928  },
    { key = "tyrande",   name = "Tyrande",    creatureID = 7999   },
    { key = "baine",     name = "Baine",      creatureID = 36648  },
    { key = "lorthemar", name = "Lor'themar", creatureID = 235787 },
    { key = "rokhan",    name = "Rokhan",     creatureID = 85054  },
    { key = "gelbin",    name = "Gelbin",     creatureID = 126326 },
}

function N:GetView(viewSide)
    if viewSide == "right" then return self.VIEW_RIGHT end
    return self.VIEW_LEFT
end

function N:GetByKey(key)
    for _, def in ipairs(self.POOL) do
        if def.key == key then return def end
    end
    return self.POOL[1]
end

function N:GetDropdownOptions()
    local opts = {}
    for _, def in ipairs(self.POOL) do
        opts[#opts + 1] = { key = def.key, label = def.name }
    end
    return opts
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

function N:ResolveView(viewSide, override)
    local base = self:GetView(viewSide)
    if not override then return base end
    return {
        rotation = override.rotation or base.rotation,
        zoom     = override.zoom or base.zoom,
        camScale = override.camScale or base.camScale,
    }
end

function N:WarmupCache()
    for _, def in ipairs(self.POOL) do
        self:EnsureDisplayID(def)
    end
end

function N:ApplyView(modelFrame, viewSide, override)
    if not modelFrame then return end
    local v = self:ResolveView(viewSide, override)
    if v.rotation and modelFrame.SetRotation then
        modelFrame:SetRotation(v.rotation)
    end
    if modelFrame.SetPortraitZoom then
        modelFrame:SetPortraitZoom(v.zoom)
    end
    if modelFrame.SetCamDistanceScale then
        modelFrame:SetCamDistanceScale(v.camScale)
    end
end

function N:_ScheduleModelRefresh(modelFrame, viewSide, override)
    if not modelFrame or not C_Timer or not C_Timer.After then return end
    local delays = { 0, 0.05, 0.12, 0.25 }
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if not modelFrame or not modelFrame.GetParent then return end
            N:ApplyView(modelFrame, viewSide, override)
            if modelFrame.SetAnimation and not modelFrame._tcAnimLock then
                modelFrame:SetAnimation(N.ANIM.idle)
            end
        end)
    end
end

function N:ApplyModel(modelFrame, def, viewSide, override, forceReload)
    if not modelFrame or not def or not def.creatureID then return false end
    viewSide = viewSide or "left"
    if forceReload then
        modelFrame._tcCreatureID = nil
        modelFrame._tcDisplayID = nil
        modelFrame._tcViewSide = nil
        modelFrame._tcViewRot = nil
    end
    local creatureID = def.creatureID
    local displayID = self:EnsureDisplayID(def)
    if not displayID and C_CreatureInfo and C_CreatureInfo.GetCreatureInfo then
        local info = C_CreatureInfo.GetCreatureInfo(creatureID)
        if info and info.displayID and info.displayID > 0 then
            def.displayID = info.displayID
            displayID = info.displayID
        end
    end
    local resolved = self:ResolveView(viewSide, override)

    if not forceReload
        and modelFrame._tcCreatureID == creatureID
        and (modelFrame._tcDisplayID or 0) == (displayID or 0)
        and modelFrame._tcViewSide == viewSide
        and modelFrame._tcViewRot == resolved.rotation then
        self:ApplyView(modelFrame, viewSide, override)
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
    modelFrame._tcCreatureID = creatureID
    modelFrame._tcDisplayID = displayID
    modelFrame._tcViewSide = viewSide
    modelFrame._tcViewOverride = override
    modelFrame._tcViewRot = resolved.rotation
    self:ApplyView(modelFrame, viewSide, override)
    self:_ScheduleModelRefresh(modelFrame, viewSide, override)
    if modelFrame.SetAnimation then
        modelFrame._tcAnimLock = true
        modelFrame:SetAnimation(self.ANIM.idle)
        C_Timer.After(0.3, function()
            if modelFrame then modelFrame._tcAnimLock = nil end
        end)
    end
    return true
end

function N:PlayAnim(modelFrame, animKey)
    if not modelFrame or not modelFrame.SetAnimation then return end
    modelFrame:SetAnimation(self.ANIM[animKey] or self.ANIM.idle)
    if modelFrame._tcViewSide then
        self:ApplyView(modelFrame, modelFrame._tcViewSide, modelFrame._tcViewOverride)
    end
end

function N:ClearModelCache(modelFrame)
    if not modelFrame then return end
    modelFrame._tcCreatureID = nil
    modelFrame._tcDisplayID = nil
    modelFrame._tcViewSide = nil
    modelFrame._tcViewOverride = nil
    modelFrame._tcViewRot = nil
    modelFrame:ClearModel()
end

function N:PrepareModelFrame(modelFrame)
    if not modelFrame then return end
    if modelFrame.SetFrameLevel and modelFrame.GetParent then
        local parent = modelFrame:GetParent()
        modelFrame:SetFrameLevel((parent and parent:GetFrameLevel() or 1) + 20)
    end
    if modelFrame.SetKeepModelOnHide then modelFrame:SetKeepModelOnHide(true) end
    if modelFrame.EnableMouse then modelFrame:EnableMouse(false) end
end
