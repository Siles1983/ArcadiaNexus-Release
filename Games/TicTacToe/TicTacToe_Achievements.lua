--[[
    ArcadiaNexus / Games/TicTacToe/TicTacToe_Achievements.lua
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

ArcadiaNexus.RegisterAchievements({

    {
        id="TTT_WINS", gameId="TICTACTOE", category="GESCHICK",
        title_de="Kreis und Kreuz", title_en="X Marks the Spot",
        desc_de="Gewinne Spiele in Tic-Tac-Toe.", desc_en="Win games of Tic-Tac-Toe.",
        icon="Interface\\Icons\\INV_Misc_Rune_01",
        condition = function(data, db)
            if data.gameId ~= "TICTACTOE" then return 0 end  -- Klasse-D-Fix: Guard korrekt
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
})
