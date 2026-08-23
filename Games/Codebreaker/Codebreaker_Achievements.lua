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
        id="CB_WINS", gameId="CODEBREAKER", category="DENKSPIELE",
        title_de="Codeknacker", title_en="Code Breaker",
        desc_de="Knacke Codes in Codebreaker.", desc_en="Crack codes in Codebreaker.",
        icon="Interface\\Icons\\INV_Misc_Gem_Pearl_01",
        condition = function(data, db)
            if data.gameId ~= "CODEBREAKER" then return 0 end
            return getTotalWins(db, "CODEBREAKER")
        end,
        tiers = {
            { id="CB_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Knacke 5 Codes.",  desc_en="Crack 5 codes."  },
            { id="CB_WINS_SILBER", tierName="Silber", target=20, xp=30, desc_de="Knacke 20 Codes.", desc_en="Crack 20 codes." },
            { id="CB_WINS_GOLD",   tierName="Gold",   target=50, xp=55, desc_de="Knacke 50 Codes.", desc_en="Crack 50 codes." },
        },
    },

    {
        id="CB_QUICK", gameId="CODEBREAKER", category="DENKSPIELE",
        title_de="Meisterstratege", title_en="Master Strategist",
        desc_de="Knacke den Code in wenigen Versuchen.", desc_en="Crack the code in few attempts.",
        icon="Interface\\Icons\\Ability_Warrior_WarCry",
        condition = function(data, db)
            if data.gameId ~= "CODEBREAKER" or data.result ~= "WIN" then return 0 end
            local attempts = data.stats and data.stats.attemptCount or 999
            if attempts <= 3 then return 3 end
            if attempts <= 4 then return 2 end
            if attempts <= 5 then return 1 end
            return 0
        end,
        tiers = {
            { id="CB_QUICK_BRONZE", tierName="Bronze", target=1, xp=25, desc_de="Sieg in max. 5 Versuchen.", desc_en="Crack in at most 5 attempts." },
            { id="CB_QUICK_SILBER", tierName="Silber", target=2, xp=45, desc_de="Sieg in max. 4 Versuchen.", desc_en="Crack in at most 4 attempts." },
            { id="CB_QUICK_GOLD",   tierName="Gold",   target=3, xp=70, desc_de="Sieg in max. 3 Versuchen!", desc_en="Crack in at most 3 attempts!" },
        },
    },
})
