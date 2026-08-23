--[[
    ArcadiaNexus – UI/Leaderboard/Leaderboard_Index.lua

    Aggregiert pending Leaderboard-Schemas (externe Addons / Spiel-Dateien).
    Muss NACH allen RegisterLeaderboard-Aufrufen (Spiel-*_Leaderboard.lua)
    geladen werden, VOR Leaderboard_UI.lua.
]]

local ArcadiaNexus = _G.ArcadiaNexus
local LR = ArcadiaNexus.LeaderboardRegistry

if LR and LR.RegisterPending then
    LR.RegisterPending(ArcadiaNexus._pendingLeaderboards)
end
ArcadiaNexus._pendingLeaderboards = nil
