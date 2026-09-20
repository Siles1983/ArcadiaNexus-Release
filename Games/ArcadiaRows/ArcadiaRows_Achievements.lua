--[[
    ArcadiaNexus / Games/ArcadiaRows/ArcadiaRows_Achievements.lua
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
        id="AR_WINS", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Vier im Sturm", title_en="Four in a Storm",
        desc_de="Gewinne Spiele in Arcadia Rows.", desc_en="Win games of Arcadia Rows.",
        icon="Interface\\Icons\\INV_Misc_Gem_Topaz_01",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" then return 0 end
            return getTotalWins(db, "ARCADIAROWS")
        end,
        tiers = {
            { id="AR_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Gewinne 5x.",  desc_en="Win 5 games."  },
            { id="AR_WINS_SILBER", tierName="Silber", target=25, xp=30, desc_de="Gewinne 25x.", desc_en="Win 25 games." },
            { id="AR_WINS_GOLD",   tierName="Gold",   target=75, xp=55, desc_de="Gewinne 75x.", desc_en="Win 75 games." },
        },
    },

    {
        id="AR_QUICK", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Blitzverbindung", title_en="Lightning Connect",
        desc_de="Gewinne in wenigen Zügen.", desc_en="Win in few moves.",
        icon="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" or data.result ~= "WIN" then return 0 end
            if data.recordPlayed == false then return 0 end
            local moves = data.stats and data.stats.moveCount or 999
            if moves <= 7  then return 3 end
            if moves <= 12 then return 2 end
            if moves <= 18 then return 1 end
            return 0
        end,
        tiers = {
            { id="AR_QUICK_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Sieg in max. 18 Zügen.", desc_en="Win in at most 18 moves." },
            { id="AR_QUICK_SILBER", tierName="Silber", target=2, xp=35, desc_de="Sieg in max. 12 Zügen.", desc_en="Win in at most 12 moves." },
            { id="AR_QUICK_GOLD",   tierName="Gold",   target=3, xp=55, desc_de="Sieg in max. 7 Zügen!",  desc_en="Win in at most 7 moves!"  },
        },
    },

    {
        id="AR_FORK", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Die Gabel", title_en="The Fork",
        desc_de="Erzeuge eine Doppelbedrohung (zwei Gewinnzüge gleichzeitig).",
        desc_en="Create a double threat (two winning drops at once).",
        icon="Interface\\Icons\\INV_Misc_Gem_Pearl_04",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" or data.result ~= "WIN" then return 0 end
            if data.recordPlayed == false then return 0 end
            if not data.stats or (data.stats.fork or 0) < 1 then return 0 end
            local moves = data.stats.moveCount or 999
            if moves <= 12 then return 3 end
            if moves <= 18 then return 2 end
            return 1
        end,
        tiers = {
            { id="AR_FORK_BRONZE", tierName="Bronze", target=1, xp=25, desc_de="Sieg mit einer Gabel.", desc_en="Win with a fork." },
            { id="AR_FORK_SILBER", tierName="Silber", target=2, xp=40, desc_de="Gabel-Sieg in max. 18 Zügen.", desc_en="Fork win in at most 18 moves." },
            { id="AR_FORK_GOLD",   tierName="Gold",   target=3, xp=60, desc_de="Gabel-Sieg in max. 12 Zügen.", desc_en="Fork win in at most 12 moves." },
        },
    },

    {
        id="AR_PUZZLE", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Stellungskenner", title_en="Position Master",
        desc_de="Löse Stellungen in Arcadia Rows.", desc_en="Solve Arcadia Rows puzzles.",
        icon="Interface\\Icons\\INV_Misc_Note_01",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" then return 0 end
            local lb = db.leaderboard and db.leaderboard["ARCADIAROWS"]
            if not lb then
                return (data.stats and data.stats.puzzleSolved) or 0
            end
            local best = 0
            for _, entry in pairs(lb) do
                local v = entry.customStats and entry.customStats.puzzleSolved
                if type(v) == "number" and v > best then best = v end
            end
            return best
        end,
        tiers = {
            { id="AR_PUZZLE_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Löse 5 Stellungen.",  desc_en="Solve 5 puzzles."  },
            { id="AR_PUZZLE_SILBER", tierName="Silber", target=25, xp=30, desc_de="Löse 25 Stellungen.", desc_en="Solve 25 puzzles." },
            { id="AR_PUZZLE_GOLD",   tierName="Gold",   target=75, xp=55, desc_de="Löse 75 Stellungen.", desc_en="Solve 75 puzzles." },
        },
    },

    {
        id="AR_POP", gameId="ARCADIAROWS", category="DENKSPIELE",
        title_de="Bodenluke", title_en="Trapdoor",
        desc_de="Gewinne Partien, in denen du Pop-out genutzt hast.",
        desc_en="Win games in which you used pop-out.",
        icon="Interface\\Icons\\INV_Misc_Gear_02",
        condition = function(data, db)
            if data.gameId ~= "ARCADIAROWS" then return 0 end
            local lb = db.leaderboard and db.leaderboard["ARCADIAROWS"]
            if not lb then
                return (data.stats and data.stats.popWins) or 0
            end
            local best = 0
            for _, entry in pairs(lb) do
                local v = entry.customStats and entry.customStats.popWins
                if type(v) == "number" and v > best then best = v end
            end
            return best
        end,
        tiers = {
            { id="AR_POP_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Ein Pop-out-Sieg.",   desc_en="Win once with pop-out." },
            { id="AR_POP_SILBER", tierName="Silber", target=10, xp=35, desc_de="10 Pop-out-Siege.", desc_en="Win 10 games with pop-out." },
            { id="AR_POP_GOLD",   tierName="Gold",   target=25, xp=55, desc_de="25 Pop-out-Siege.", desc_en="Win 25 games with pop-out." },
        },
    },
})
