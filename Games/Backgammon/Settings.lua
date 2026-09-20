local A = ArcadiaNexus
A.BG_Settings = {}
local S = A.BG_Settings
local defaults = { soundEnabled = true, difficulty = "normal", theme = "walnut" }
function S:Get(key)
    local v = A.Persistence:GetGameSettings("BACKGAMMON")[key]
    if v == nil then return defaults[key] end
    return v
end
function S:Set(key, value) A.Persistence:SetGameSetting("BACKGAMMON", key, value) end
function S:Reset()
    local db = A.Persistence:GetGameSettings("BACKGAMMON")
    -- Save slots are progress, never reset by appearance preferences.
    for k in pairs(defaults) do db[k] = nil end
end
function S:LoadSlot(slot)
    local slots = self:Get("slots")
    return slots and slots[slot]
end
function S:SaveSlot(slot, save)
    local slots = self:Get("slots") or {}
    slots[slot] = save
    self:Set("slots", slots)
end
