local ArcadiaNexus = _G.ArcadiaNexus

local function Increment(db,id)
    local prog=db.achievements and db.achievements.progress and db.achievements.progress[id]
    return (prog and prog.current or 0)+1
end

ArcadiaNexus.RegisterAchievements({

    { id="HOL_PROFIT", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Im Gewinn", title_en="In Profit",
      desc_de="Beende mit mehr Chips als gestartet.", desc_en="Finish with more chips than you started.",
      icon="Interface\\Icons\\INV_Misc_Coin_01",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          return data.result=="WIN" and Increment(db,"HOL_PROFIT") or 0
      end,
      tiers = {
          { id="HOL_PROFIT_BRONZE", tierName="Bronze", target=1,  xp=15, desc_de="1x gewonnen.",   desc_en="Win once."        },
          { id="HOL_PROFIT_SILBER", tierName="Silber", target=5,  xp=30, desc_de="5x gewonnen.",   desc_en="Win five times."  },
          { id="HOL_PROFIT_GOLD",   tierName="Gold",   target=15, xp=60, desc_de="15x gewonnen!",  desc_en="Win 15 times!"    },
      },
    },

    { id="HOL_STREAK5", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Glücksserie", title_en="Lucky Streak",
      desc_de="Erreiche Serie 5+.", desc_en="Reach a streak of 5 or more.",
      icon=132173, -- Ability_Hunter_FerociousInspiration
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          if (data.stats and data.stats.maxStreak or 0) < 5 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["HOL_STREAK5"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="HOL_STREAK5_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Einmal Serie 5+.",    desc_en="Serie 5+ once."   },
          { id="HOL_STREAK5_SILBER", tierName="Silber", target=3, xp=40, desc_de="Dreimal Serie 5+.",   desc_en="Serie 5+ thrice." },
          { id="HOL_STREAK5_GOLD",   tierName="Gold",   target=7, xp=65, desc_de="Siebenmal Serie 5+!", desc_en="Serie 5+ 7 times!" },
      },
    },

    { id="HOL_STREAK10", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Unfehlbar", title_en="Infallible",
      desc_de="Erreiche Serie 10+.", desc_en="Reach a streak of 10 or more.",
      icon="Interface\\Icons\\Spell_Holy_BorrowedTime",
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          if (data.stats and data.stats.maxStreak or 0) < 10 then return 0 end
          return math.min(Increment(db,"HOL_STREAK10"),3)
      end,
      tiers = {
          { id="HOL_STREAK10_BRONZE", tierName="Bronze", target=1, xp=35, desc_de="Einmal Serie 10+.",   desc_en="Serie 10+ once."        },
          { id="HOL_STREAK10_SILBER", tierName="Silber", target=3, xp=65, desc_de="Dreimal Serie 10+.",  desc_en="Serie 10+ three times."  },

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
          { id="HOL_HIGHROLLER_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="300 Chips.",  desc_en="Reach 300 Chips."  },
          { id="HOL_HIGHROLLER_SILBER", tierName="Silber", target=2, xp=50, desc_de="500 Chips.",  desc_en="Reach 500 Chips."  },
          { id="HOL_HIGHROLLER_GOLD",   tierName="Gold",   target=3, xp=90, desc_de="1000 Chips!", desc_en="Reach 1000 Chips!" },
      },
    },

    { id="HOL_VETERAN", gameId="HIGHERORLOWER", category="KARTEN",
      title_de="Kartenleser", title_en="Card Reader",
      desc_de="Spiele viele Runden.", desc_en="Play many rounds.",
      icon=134493, -- INV_Misc_Ticket_Tarot_Stack_01
      condition = function(data, db)
          if data.gameId ~= "HIGHERORLOWER" then return 0 end
          return Increment(db,"HOL_VETERAN")
      end,
      tiers = {
          { id="HOL_VETERAN_BRONZE", tierName="Bronze", target=10, xp=15, desc_de="10 Runden.",  desc_en="Play 10 rounds."  },
          { id="HOL_VETERAN_SILBER", tierName="Silber", target=25, xp=30, desc_de="25 Runden.",  desc_en="Play 25 rounds."  },
          { id="HOL_VETERAN_GOLD",   tierName="Gold",   target=50, xp=60, desc_de="50 Runden!",  desc_en="Play 50 rounds!"  },
      },
    },


})
