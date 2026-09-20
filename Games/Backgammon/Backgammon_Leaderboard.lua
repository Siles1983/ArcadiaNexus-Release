local A = ArcadiaNexus
local LR = A.LeaderboardRegistry
if not LR or not LR.SECTION then return end
A.RegisterLeaderboard({ gameId = "BACKGAMMON",
    difficulties = { "easy", "normal", "hard", { id = "multiplayer", labelKey = "multiplayer" } },
    sections = { LR.SECTION.StatsWL() },
})
