local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalWins(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0)
    end
    return total
end

local function getTotalGames(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
    end
    return total
end

local function hasHardStreak10(db)
    local entry = db.leaderboard and db.leaderboard["HIGHERORLOWER"]
    local hard = entry and (entry["hard"] or entry["HARD"])
    local stats = hard and hard.customStats
    return (stats and stats.maxStreak or 0) >= 10
end

ArcadiaNexus.RegisterAchievements({

    { id="HOL_PROFIT", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Im Gewinn", title_en="In Profit",
      desc_de="Beende mit mehr Gold als gestartet.", desc_en="Finish with more Gold than you started.",
      icon="Interface\\Icons\\INV_Misc_Coin_01",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          return getTotalWins(db, "HIGHERORLOWER")
      end,
      tiers = {
          { id="HOL_PROFIT_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="1x gewonnen.",   desc_en="Win once."        },
          { id="HOL_PROFIT_SILBER", tierName="Silber", target=5,  xp=30, desc_de="5x gewonnen.",   desc_en="Win five times."  },
          { id="HOL_PROFIT_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="15x gewonnen!",  desc_en="Win 15 times!"    },
      },
    },

    { id="HOL_STREAK5", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Glücksserie", title_en="Lucky Streak",
      desc_de="Erreiche Streak 5+.", desc_en="Reach a streak of 5 or more.",
      icon=132173, -- Ability_Hunter_FerociousInspiration
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          if (data.stats and data.stats.maxStreak or 0) < 5 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["HOL_STREAK5"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="HOL_STREAK5_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Einmal Streak 5+.",    desc_en="Streak 5+ once."   },
          { id="HOL_STREAK5_SILBER", tierName="Silber", target=3, xp=40, desc_de="Dreimal Streak 5+.",   desc_en="Streak 5+ thrice." },
          { id="HOL_STREAK5_GOLD",   tierName="Gold",   target=7, xp=65, desc_de="Siebenmal Streak 5+!", desc_en="Streak 5+ 7 times!" },
      },
    },

    { id="HOL_STREAK10", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Unfehlbar", title_en="Infallible",
      desc_de="Erreiche Streak 10+.", desc_en="Reach a streak of 10 or more.",
      icon="Interface\\Icons\\Spell_Holy_BorrowedTime",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          if (data.stats and data.stats.maxStreak or 0) < 10 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["HOL_STREAK10"]
          local count = math.min(prog and prog.current or 0, 3) + 1
          if count >= 3 and hasHardStreak10(db) then return 4 end
          return math.min(count, 3)
      end,
      tiers = {
          { id="HOL_STREAK10_BRONZE", tierName="Bronze", target=1, xp=35, desc_de="Einmal Streak 10+.",   desc_en="Streak 10+ once."        },
          { id="HOL_STREAK10_SILBER", tierName="Silber", target=3, xp=65, desc_de="Dreimal Streak 10+.",  desc_en="Streak 10+ three times."  },
          { id="HOL_STREAK10_GOLD",   tierName="Gold",   target=4, xp=90,
            desc_de="Davon mindestens eine Streak auf Schwer!", desc_en="Complete at least one of them on Hard!" },
      },
    },

    { id="HOL_CASHOUT", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Sichere Bank", title_en="Safe Bet",
      desc_de="Tätige Cash Outs.", desc_en="Cash out before your streak ends.",
      icon="Interface\\Icons\\INV_Misc_Coin_02",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          local cashouts = data.stats and data.stats.cashouts or 0
          if cashouts <= 0 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["HOL_CASHOUT"]
          return (prog and prog.current or 0) + cashouts
      end,
      tiers = {
          { id="HOL_CASHOUT_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="1 Cash Out.",   desc_en="Cash out once."      },
          { id="HOL_CASHOUT_SILBER", tierName="Silber", target=10, xp=30, desc_de="10 Cash Outs.", desc_en="Cash out 10 times."  },
          { id="HOL_CASHOUT_GOLD",   tierName="Gold",   target=25, xp=55, desc_de="25 Cash Outs!", desc_en="Cash out 25 times!"  },
      },
    },

    { id="HOL_HIGHROLLER", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Hochstapler", title_en="High Roller",
      desc_de="Erreiche hohes Kapital.", desc_en="Reach a high capital.",
      icon="Interface\\Icons\\INV_Misc_Coin_04",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          local chips = data.stats and data.stats.finalChips or 0
          if chips >= 1000 then return 3 end
          if chips >= 500  then return 2 end
          if chips >= 300  then return 1 end
          return 0
      end,
      tiers = {
          { id="HOL_HIGHROLLER_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="300 Gold.",  desc_en="Reach 300 Gold."  },
          { id="HOL_HIGHROLLER_SILBER", tierName="Silber", target=2, xp=50, desc_de="500 Gold.",  desc_en="Reach 500 Gold."  },
          { id="HOL_HIGHROLLER_GOLD",   tierName="Gold",   target=3, xp=90, desc_de="1000 Gold!", desc_en="Reach 1000 Gold!" },
      },
    },

    { id="HOL_VETERAN", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Kartenleser", title_en="Card Reader",
      desc_de="Spiele viele Runden.", desc_en="Play many rounds.",
      icon=134493, -- INV_Misc_Ticket_Tarot_Stack_01
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          return getTotalGames(db, "HIGHERORLOWER")
      end,
      tiers = {
          { id="HOL_VETERAN_BRONZE", tierName="Bronze", target=10, xp=15, desc_de="10 Runden.",  desc_en="Play 10 rounds."  },
          { id="HOL_VETERAN_SILBER", tierName="Silber", target=25, xp=30, desc_de="25 Runden.",  desc_en="Play 25 rounds."  },
          { id="HOL_VETERAN_GOLD",   tierName="Gold",   target=50, xp=60, desc_de="50 Runden!",  desc_en="Play 50 rounds!"  },
      },
    },

    { id="HOL_HARDMODE", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Joker-Jäger", title_en="Joker Hunter",
      desc_de="Gewinne auf Schwer.", desc_en="Win on Hard.",
      icon="Interface\\Icons\\INV_Misc_Dice_02",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" or data.difficulty ~= "hard" then return 0 end
          local entry = db.leaderboard and db.leaderboard["HIGHERORLOWER"]
          local h = entry and (entry["hard"] or entry["HARD"]) or {}
          return h.wins or 0
      end,
      tiers = {
          { id="HOL_HARDMODE_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Einmal auf Schwer.",   desc_en="Win once on Hard."       },
          { id="HOL_HARDMODE_SILBER", tierName="Silber", target=5,  xp=55, desc_de="Fünfmal auf Schwer.",  desc_en="Win five times on Hard."  },
          { id="HOL_HARDMODE_GOLD",   tierName="Gold",   target=10, xp=85, desc_de="Zehnmal auf Schwer!",  desc_en="Win ten times on Hard!"   },
      },
    },

    { id="HOL_HARDSTREAK", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Joker-Trotzer", title_en="Joker Defier",
      desc_de="Streak 7+ auf Schwer.", desc_en="Reach streak 7+ on Hard.",
      icon="Interface\\Icons\\INV_Misc_Dice_01",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" or data.difficulty ~= "hard" then return 0 end
          if (data.stats and data.stats.maxStreak or 0) < 7 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["HOL_HARDSTREAK"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="HOL_HARDSTREAK_BRONZE", tierName="Bronze", target=1, xp=40, desc_de="Einmal Streak 7+ auf Schwer.",   desc_en="Streak 7+ on Hard once."       },
          { id="HOL_HARDSTREAK_SILBER", tierName="Silber", target=3, xp=70, desc_de="Dreimal Streak 7+ auf Schwer.",  desc_en="Streak 7+ on Hard three times." },
          { id="HOL_HARDSTREAK_GOLD",   tierName="Gold",   target=5, xp=95, desc_de="Fünfmal Streak 7+ auf Schwer!",  desc_en="Streak 7+ on Hard five times!"  },
      },
    },

})
