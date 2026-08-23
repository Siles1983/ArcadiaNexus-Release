--[[
    ArcadiaNexus
    UI/Achievements/Achievement_Index.lua

    Aggregiert alle Achievement-Quellen in ArcadiaNexus.AchievementData:
      - Spiel-eigene *_Achievements.lua via ArcadiaNexus.RegisterAchievements()
      - UI/Achievements/Achievement_Global.lua (ALLGEMEIN)
      - Externe Addons via RegisterAchievements() nach RegisterGame()

    Muss als LETZTE Datei im Achievement-Block geladen werden,
    nach allen *_Achievements.lua und Achievement_Global.lua.

    Ladereihenfolge (TOC):
        UI/Achievements/Achievement_Global.lua
        -- Spiel *_Achievements.lua (in je Spiel-Block der TOC)
        UI/Achievements/Achievement_Index.lua   ← diese Datei (immer zuletzt)
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.AchievementData = {}
local D = ArcadiaNexus.AchievementData

for _, group in ipairs(ArcadiaNexus._pendingAchievements or {}) do
    D[#D + 1] = group
end
ArcadiaNexus._pendingAchievements = nil

if ArcadiaNexus.AchievementIcons and ArcadiaNexus.AchievementIcons.NormalizeAllRegistered then
    ArcadiaNexus.AchievementIcons:NormalizeAllRegistered()
end
