--[[
    ArcadiaNexus / Games/TicTacToe/TicTacToe_Achievements.lua
    KI-Erfolge: stats.vsHuman ~= 1. PvP hat TTT_MP.
]]
local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalWins(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0)
    end
    return total
end

local function maxCustom(db, gameId, key)
    local lb = db.leaderboard and db.leaderboard[gameId]
    if not lb then return 0 end
    local best = 0
    for _, entry in pairs(lb) do
        local v = entry.customStats and entry.customStats[key]
        if type(v) == "number" and v > best then best = v end
    end
    return best
end

local function bump(db, groupId)
    local prog = db.achievements and db.achievements.progress
                 and db.achievements.progress[groupId]
    return (prog and prog.current or 0) + 1
end

local function vsAI(data)
    return not data.stats or (data.stats.vsHuman or 0) == 0
end

ArcadiaNexus.RegisterAchievements({

    {
        id="TTT_WINS", gameId="TICTACTOE", category="GESCHICK",
        title_de="Kreis und Kreuz", title_en="X Marks the Spot",
        desc_de="Gewinne Spiele in Tic-Tac-Toe.", desc_en="Win games of Tic-Tac-Toe.",
        icon="Interface\\Icons\\INV_Misc_Rune_01",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" then return 0 end
            return getTotalWins(db, "TICTACTOE")
        end,
        tiers = {
            { id="TTT_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="TTT_WINS_SILBER", tierName="Silber", target=25, xp=30, desc_de="Gewinne 25x.", desc_en="Win 25 games." },
            { id="TTT_WINS_GOLD",   tierName="Gold",   target=75, xp=55, desc_de="Gewinne 75x.", desc_en="Win 75 games." },
        },
    },

    {
        id="TTT_HARD", gameId="TICTACTOE", category="GESCHICK",
        title_de="Kein Kinderspiel", title_en="No Easy Win",
        desc_de="Besiege die KI auf Schwer.", desc_en="Defeat the AI on Hard difficulty.",
        icon="Interface\\Icons\\Ability_Rogue_Shadowstep",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "WIN" then return 0 end
            if not vsAI(data) then return 0 end
            local entry = db.leaderboard and db.leaderboard["TICTACTOE"]
            if not entry then return 0 end
            local h = entry["hard"] or entry["HARD"] or {}
            return h.wins or 0
        end,
        tiers = {
            { id="TTT_HARD_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Gewinne 1x auf Schwer.",  desc_en="Win 1 on Hard."  },
            { id="TTT_HARD_SILBER", tierName="Silber", target=10, xp=40, desc_de="Gewinne 10x auf Schwer.", desc_en="Win 10 on Hard." },
            { id="TTT_HARD_GOLD",   tierName="Gold",   target=30, xp=65, desc_de="Gewinne 30x auf Schwer.", desc_en="Win 30 on Hard." },
        },
    },

    {
        id="TTT_STREAK", gameId="TICTACTOE", category="GESCHICK",
        title_de="Serie halten", title_en="On a Roll",
        desc_de="Gewinne hintereinander gegen die KI.",
        desc_en="Win consecutive games against the AI.",
        icon="Interface\\Icons\\Spell_Nature_BloodLust",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" then return 0 end
            if not vsAI(data) then return maxCustom(db, "TICTACTOE", "winStreak") end
            local now = data.stats and data.stats.winStreak or 0
            local stored = maxCustom(db, "TICTACTOE", "winStreak")
            if now > stored then return now end
            return stored
        end,
        tiers = {
            { id="TTT_STREAK_BRONZE", tierName="Bronze", target=3, xp=20, desc_de="3 Siege in Folge.", desc_en="Win 3 in a row." },
            { id="TTT_STREAK_SILBER", tierName="Silber", target=5, xp=35, desc_de="5 Siege in Folge.", desc_en="Win 5 in a row." },
            { id="TTT_STREAK_GOLD",   tierName="Gold",   target=8, xp=55, desc_de="8 Siege in Folge.", desc_en="Win 8 in a row." },
        },
    },

    {
        id="TTT_LARGE", gameId="TICTACTOE", category="GESCHICK",
        title_de="Großes Feld", title_en="Wide Open",
        desc_de="Gewinne auf dem 5×5-Brett gegen die KI.",
        desc_en="Win on the 5×5 board against the AI.",
        icon="Interface\\Icons\\INV_Misc_Map_01",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "WIN" then return 0 end
            if not vsAI(data) then return 0 end
            if (data.stats and data.stats.boardSize or 3) < 5 then return 0 end
            return bump(db, "TTT_LARGE")
        end,
        tiers = {
            { id="TTT_LARGE_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Ein Sieg auf 5×5.",   desc_en="Win once on 5×5." },
            { id="TTT_LARGE_SILBER", tierName="Silber", target=10, xp=35, desc_de="10 Siege auf 5×5.", desc_en="Win 10 games on 5×5." },
            { id="TTT_LARGE_GOLD",   tierName="Gold",   target=25, xp=55, desc_de="25 Siege auf 5×5.", desc_en="Win 25 games on 5×5." },
        },
    },

    {
        id="TTT_DRAW_HARD", gameId="TICTACTOE", category="GESCHICK",
        title_de="Remis erzwungen", title_en="Forced Draw",
        desc_de="Erreiche Unentschieden gegen die KI auf Schwer.",
        desc_en="Draw against the AI on Hard.",
        icon="Interface\\Icons\\Spell_Holy_DivineSpirit",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "DRAW" then return 0 end
            if not vsAI(data) then return 0 end
            local diff = data.difficulty and tostring(data.difficulty):lower() or ""
            if diff ~= "hard" then return 0 end
            return bump(db, "TTT_DRAW_HARD")
        end,
        tiers = {
            { id="TTT_DRAW_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="1 Unentschieden auf Schwer.",  desc_en="Draw once on Hard." },
            { id="TTT_DRAW_HARD_SILBER", tierName="Silber", target=5,  xp=40, desc_de="5 Unentschieden auf Schwer.",  desc_en="Draw 5 times on Hard." },
            { id="TTT_DRAW_HARD_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="15 Unentschieden auf Schwer.", desc_en="Draw 15 times on Hard." },
        },
    },

    {
        id="TTT_SERIES", gameId="TICTACTOE", category="GESCHICK",
        title_de="Best of Three", title_en="Best of Three",
        desc_de="Gewinne Best-of-3-Serien gegen die KI.",
        desc_en="Win Best-of-3 series against the AI.",
        icon="Interface\\Icons\\Achievement_Arena_2v2_7",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" then return 0 end
            if not vsAI(data) then return 0 end
            if not data.stats or (data.stats.seriesWin or 0) < 1 then return 0 end
            return bump(db, "TTT_SERIES")
        end,
        tiers = {
            { id="TTT_SERIES_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Eine Serie gewinnen.",  desc_en="Win 1 series." },
            { id="TTT_SERIES_SILBER", tierName="Silber", target=5,  xp=40, desc_de="5 Serien gewinnen.",  desc_en="Win 5 series." },
            { id="TTT_SERIES_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="15 Serien gewinnen.", desc_en="Win 15 series." },
        },
    },

    {
        id="TTT_MP", gameId="TICTACTOE", category="GESCHICK",
        title_de="Gegen Spieler", title_en="Versus Player",
        desc_de="Gewinne Mehrspieler-Partien.", desc_en="Win multiplayer matches.",
        icon="Interface\\Icons\\Achievement_PVP_O_H",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "WIN" then return 0 end
            if not data.stats or (data.stats.vsHuman or 0) < 1 then return 0 end
            return bump(db, "TTT_MP")
        end,
        tiers = {
            { id="TTT_MP_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Ein Mehrspieler-Sieg.",  desc_en="Win 1 multiplayer game." },
            { id="TTT_MP_SILBER", tierName="Silber", target=5,  xp=40, desc_de="5 Mehrspieler-Siege.",  desc_en="Win 5 multiplayer games." },
            { id="TTT_MP_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="15 Mehrspieler-Siege.", desc_en="Win 15 multiplayer games." },
        },
    },

    {
        id="TTT_QUICK", gameId="TICTACTOE", category="GESCHICK",
        title_de="Kurzes Spiel", title_en="Short Game",
        desc_de="Gewinne ein klassisches 3×3 in wenigen Zügen.",
        desc_en="Win classic 3×3 in few moves.",
        icon="Interface\\Icons\\Ability_Rogue_Sprint",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "WIN" then return 0 end
            if not vsAI(data) then return 0 end
            if (data.stats and data.stats.boardSize or 3) ~= 3 then return 0 end
            local moves = data.stats and data.stats.moveCount or 999
            if moves <= 5 then return 3 end
            if moves <= 7 then return 2 end
            if moves <= 9 then return 1 end
            return 0
        end,
        tiers = {
            { id="TTT_QUICK_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Sieg in max. 9 Zügen.", desc_en="Win in at most 9 moves." },
            { id="TTT_QUICK_SILBER", tierName="Silber", target=2, xp=35, desc_de="Sieg in max. 7 Zügen.", desc_en="Win in at most 7 moves." },
            { id="TTT_QUICK_GOLD",   tierName="Gold",   target=3, xp=55, desc_de="Sieg in max. 5 Zügen.",  desc_en="Win in at most 5 moves." },
        },
    },

    {
        id="TTT_SECOND", gameId="TICTACTOE", category="GESCHICK",
        title_de="Zweiter Stein", title_en="Second Stone",
        desc_de="Gewinne, obwohl die KI den ersten Zug hatte.",
        desc_en="Win even though the AI moved first.",
        icon="Interface\\Icons\\Ability_Rogue_SurpriseAttack",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" or data.result ~= "WIN" then return 0 end
            if not vsAI(data) then return 0 end
            if (data.stats and data.stats.startedAs or 1) ~= 2 then return 0 end
            return bump(db, "TTT_SECOND")
        end,
        tiers = {
            { id="TTT_SECOND_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Ein Sieg nach KI-Auftakt.",  desc_en="Win once after an AI opening." },
            { id="TTT_SECOND_SILBER", tierName="Silber", target=5,  xp=35, desc_de="5 Siege nach KI-Auftakt.",  desc_en="Win 5 after an AI opening." },
            { id="TTT_SECOND_GOLD",   tierName="Gold",   target=15, xp=55, desc_de="15 Siege nach KI-Auftakt.", desc_en="Win 15 after an AI opening." },
        },
    },
})
