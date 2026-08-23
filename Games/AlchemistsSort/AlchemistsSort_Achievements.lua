local ArcadiaNexus = _G.ArcadiaNexus

local function getSolvedCount(db)
    if not db.leaderboard or not db.leaderboard["ALCHEMISTSSORT"] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard["ALCHEMISTSSORT"]) do
        total = total + (entry.wins or 0)
    end
    return total
end

ArcadiaNexus.RegisterAchievements({

    { id="ALS_FIRST", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Erste Mischung", title_en="First Brew",
      desc_de="Löse dein erstes Puzzle.", desc_en="Solve your first puzzle.",
      icon=236868, -- INV_Alchemy_Elixir_01
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          return getSolvedCount(db) >= 1 and 1 or 0
      end,
      tiers = {
          { id="ALS_FIRST_BRONZE", tierName="Bronze", target=1, xp=10, desc_de="1 Puzzle gelöst.", desc_en="Solve 1 puzzle." },
      },
    },

    { id="ALS_SOLVED", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Puzzle-Meister", title_en="Puzzle Master",
      desc_de="Löse 10 / 50 / 100 Puzzles.", desc_en="Solve 10 / 50 / 100 puzzles.",
      icon="Interface\\Icons\\INV_Alchemy_EndlessFlask_06",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          return getSolvedCount(db)
      end,
      tiers = {
          { id="ALS_SOLVED_BRONZE", tierName="Bronze", target=10,  xp=20,  desc_de="10 Puzzles.",   desc_en="10 puzzles."   },
          { id="ALS_SOLVED_SILBER", tierName="Silber", target=50,  xp=50,  desc_de="50 Puzzles.",   desc_en="50 puzzles."   },
          { id="ALS_SOLVED_GOLD",   tierName="Gold",   target=100, xp=100, desc_de="100 Puzzles!",  desc_en="100 puzzles!"  },
      },
    },

    { id="ALS_PERFECT", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Perfekt", title_en="Perfect",
      desc_de="Löse ohne Undo und ohne Tipp.", desc_en="Solve without Undo or Hint.",
      icon="Interface\\Icons\\Achievement_PVP_A_16",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or st.usedUndo or st.usedHint then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_PERFECT"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_PERFECT_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Einmal perfekt.",  desc_en="Perfect once."       },
          { id="ALS_PERFECT_SILBER", tierName="Silber", target=5,  xp=55, desc_de="Fünfmal perfekt.", desc_en="Perfect five times."  },
          { id="ALS_PERFECT_GOLD",   tierName="Gold",   target=10, xp=90, desc_de="Zehnmal perfekt!", desc_en="Perfect ten times!"   },
      },
    },

    { id="ALS_SPEED", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Blitzlöser", title_en="Lightning Solver",
      desc_de="Löse in unter 60 Sekunden.", desc_en="Solve in under 60 seconds.",
      icon="Interface\\Icons\\Ability_Rogue_Sprint",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or not st.time or st.time >= 60 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_SPEED"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_SPEED_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Einmal unter 60s.",  desc_en="Once under 60s."      },
          { id="ALS_SPEED_SILBER", tierName="Silber", target=5,  xp=45, desc_de="Fünfmal unter 60s.", desc_en="Five times under 60s." },
          { id="ALS_SPEED_GOLD",   tierName="Gold",   target=10, xp=80, desc_de="Zehnmal unter 60s!", desc_en="Ten times under 60s!"  },
      },
    },

    { id="ALS_MOVES", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Effizienz-Experte", title_en="Efficiency Expert",
      desc_de="Löse mit minimalen Zügen.", desc_en="Solve with minimum moves.",
      icon="Interface\\Icons\\INV_Misc_Gear_01",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or not st.moves or not st.minMoves then return 0 end
          if st.minMoves <= 0 or st.moves > st.minMoves then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_MOVES"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_MOVES_BRONZE", tierName="Bronze", target=1,  xp=30,  desc_de="Einmal optimal.",  desc_en="Optimal once."      },
          { id="ALS_MOVES_SILBER", tierName="Silber", target=5,  xp=60,  desc_de="Fünfmal optimal.", desc_en="Optimal five times." },
          { id="ALS_MOVES_GOLD",   tierName="Gold",   target=10, xp=100, desc_de="Zehnmal optimal!", desc_en="Optimal ten times!"  },
      },
    },

    { id="ALS_NOHELP", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Auf eigene Faust", title_en="Flying Solo",
      desc_de="Löse ohne Tipp, Undo oder Extra-Röhre.", desc_en="Solve without Hint, Undo or extra tube.",
      icon="Interface\\Icons\\Achievement_Character_Human_Male",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or st.usedUndo or st.usedHint or st.usedAddTube then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_NOHELP"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_NOHELP_BRONZE", tierName="Bronze", target=1,  xp=20, desc_de="Einmal ohne Hilfe.",  desc_en="Once without help."   },
          { id="ALS_NOHELP_SILBER", tierName="Silber", target=5,  xp=45, desc_de="Fünfmal ohne Hilfe.", desc_en="Five times solo."     },
          { id="ALS_NOHELP_GOLD",   tierName="Gold",   target=10, xp=85, desc_de="Zehnmal ohne Hilfe!", desc_en="Ten times solo!"      },
      },
    },

    { id="ALS_STREAK", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Lösungs-Serie", title_en="Winning Streak",
      desc_de="Löse 5 Puzzles hintereinander.", desc_en="Solve 5 puzzles in a row.",
      icon="Interface\\Icons\\Ability_Warrior_Rallyingcry",
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or not st.streak or st.streak < 5 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_STREAK"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_STREAK_BRONZE", tierName="Bronze", target=1, xp=25, desc_de="Streak von 5.",    desc_en="Streak of 5."         },
          { id="ALS_STREAK_SILBER", tierName="Silber", target=3, xp=55, desc_de="Dreimal Streak.",  desc_en="Streak 3 times."      },
          { id="ALS_STREAK_GOLD",   tierName="Gold",   target=5, xp=90, desc_de="Fünfmal Streak!",  desc_en="Streak 5 times!"      },
      },
    },

    { id="ALS_HARD", gameId="ALCHEMISTSSORT", category="RAETSEL",
      title_de="Meister-Mixer", title_en="Master Mixer",
      desc_de="Löse ein Puzzle ab Level 76.", desc_en="Solve a puzzle from level 76+.",
      icon=134716, -- INV_Potion_05
      condition = function(data, db)
          if data.gameId ~= "ALCHEMISTSSORT" then return 0 end
          local st = data.stats
          if not st or not st.level or st.level < 76 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["ALS_HARD"]
          return (prog and prog.current or 0) + 1
      end,
      tiers = {
          { id="ALS_HARD_BRONZE", tierName="Bronze", target=1,  xp=40,  desc_de="Einmal Level 76+.",  desc_en="Solve level 76+ once."      },
          { id="ALS_HARD_SILBER", tierName="Silber", target=5,  xp=75,  desc_de="Fünfmal Level 76+.", desc_en="Solve level 76+ five times." },
          { id="ALS_HARD_GOLD",   tierName="Gold",   target=10, xp=120, desc_de="Zehnmal Level 76+!", desc_en="Solve level 76+ ten times!"  },
      },
    },

})
