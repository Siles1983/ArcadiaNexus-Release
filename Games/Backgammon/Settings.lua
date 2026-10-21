local A = ArcadiaNexus
A.BG_Settings = {}
local S = A.BG_Settings
local defaults = { soundEnabled = true, difficulty = "normal", theme = "walnut" }
function S:Get(key)
    local E=A.BG_Engine
    if key=="difficulty" and E and E.mode=="solo" and E.state~="IDLE" and E.difficulty then return E.difficulty end
    local v = A.Persistence:GetGameSettings("BACKGAMMON")[key]
    if key=="difficulty" then return v=="easy" and "easy" or v=="hard" and "hard" or "normal" end
    if v == nil then return defaults[key] end
    return v
end
function S:Set(key, value)
    local E=A.BG_Engine
    if key=="difficulty" then
        if E and E.mode=="solo" and E.state=="PLAYING" then return false end
        value=value=="easy" and "easy" or value=="hard" and "hard" or "normal"
    end
    A.Persistence:SetGameSetting("BACKGAMMON",key,value); return true
end
function S:Reset()
    local db = A.Persistence:GetGameSettings("BACKGAMMON")
    -- Save slots are progress, never reset by appearance preferences.
    local E=A.BG_Engine
    for k in pairs(defaults) do
        if k~="difficulty" or not E or E.mode~="solo" or E.state~="PLAYING" then db[k]=nil end
    end
end
function S:LoadSlot(slot)
    local slots = self:Get("slots")
    return slots and slots[slot]
end
function S:SaveSlot(slot, save)
    if type(slot)~="number" or slot%1~=0 or slot<1 or slot>3 then return false end
    local slots = self:Get("slots") or {}
    slots[slot] = save and A.BG_Logic.Copy(save)
    self:Set("slots", slots)
    return true
end
function S:SavePending(data)
    local db=A.Persistence:GetGameSettings("BACKGAMMON")
    db.pendingResults=db.pendingResults or {}; db.pendingResults[data.runId]=A.BG_Logic.Copy(data)
end
function S:GetPending() return self:Get("pendingResults") or {} end
function S:ClearPending(id)
    local db=A.Persistence:GetGameSettings("BACKGAMMON")
    if db.pendingResults then db.pendingResults[id]=nil end
end
