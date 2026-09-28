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

-- Dieselbe Tabelle bleibt nach dem TOC als Registry für externe Addons erhalten.
ArcadiaNexus._pendingAchievements = ArcadiaNexus._pendingAchievements or {}
ArcadiaNexus.AchievementData = ArcadiaNexus._pendingAchievements

if ArcadiaNexus.AchievementIcons and ArcadiaNexus.AchievementIcons.NormalizeAllRegistered then
    ArcadiaNexus.AchievementIcons:NormalizeAllRegistered()
end
