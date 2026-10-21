local A = _G.ArcadiaNexus
A.GWX_Settings = {}
local S = A.GWX_Settings
local defaults = { soundEnabled = true, gallywixEnabled = false }
local soundKeys={"soundWheel","soundWheelStop","soundHit","soundMiss","soundVowel",
    "soundBankrupt","soundSkip","soundExtra","soundRound","soundWin","soundLose","soundGallywix"}
for _,key in ipairs(soundKeys) do defaults[key]=true end
function S:Get(key)
    local E=A.GWX_Engine
    if key=="gallywixEnabled" and E and E.state and E.state~="IDLE" then
        if E.gameState then return E.gameState.gallywixEnabled==true end
        if E.match and E.match.publicState then return E.match.publicState.gallywix==true end
    end
    local value = A.Persistence:GetGameSettings("GALLYWIX")[key]
    if value == nil then
        return defaults[key]
    end
    return value
end
function S:IsConfigLocked()
    local E=A.GWX_Engine
    return E and E.state and E.state~="IDLE" or false
end
function S:Set(key, value)
    if key=="gallywixEnabled" and (self:IsConfigLocked() or type(value)~="boolean") then return false end
    A.Persistence:SetGameSetting("GALLYWIX", key, value)
    if value==false and (key=="soundWheel" or key=="soundEnabled") and A.GWX_Sounds then A.GWX_Sounds:StopWheel(false) end
    if value==false and (key=="soundGallywix" or key=="soundEnabled") then
        local E=A.GWX_Engine
        if E and E._laughHandle and StopSound then StopSound(E._laughHandle); E._laughHandle=nil end
    end
    return true
end
function S:Reset()
    local settings = A.Persistence:GetGameSettings("GALLYWIX")
    for key in pairs(defaults) do if key~="gallywixEnabled" or not self:IsConfigLocked() then settings[key]=nil end end
    if A.GWX_Sounds then A.GWX_Sounds:StopWheel(false) end
    local E=A.GWX_Engine
    if E and E._laughHandle and StopSound then StopSound(E._laughHandle); E._laughHandle=nil end
end

function S:SaveSlot(slot,save)
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    local db=A.Persistence:GetGameSettings("GALLYWIX"); db.slots=db.slots or {}
    db.slots[slot]=A.GWX_GameLogic.Copy(save); return true
end
function S:LoadSlot(slot)
    local db=A.Persistence:GetGameSettings("GALLYWIX")
    return db.slots and A.GWX_GameLogic.Copy(db.slots[slot])
end
