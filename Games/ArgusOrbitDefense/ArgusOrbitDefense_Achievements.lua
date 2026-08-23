local ArcadiaNexus = _G.ArcadiaNexus

local function getTotalGames(db, gameId)
    if not db.leaderboard or not db.leaderboard[gameId] then return 0 end
    local total = 0
    for _, entry in pairs(db.leaderboard[gameId]) do
        total = total + (entry.wins or 0) + (entry.losses or 0) + (entry.draws or 0)
    end
    return total
end

ArcadiaNexus.RegisterAchievements({

    { id="AOD_FIRST", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Erster Orbit", title_en="First Orbit",
      desc_de="Starte dein erstes Spiel.", desc_en="Start your first game.",
      icon=236349, -- Achievement_BG_CaptureFlag_EOS
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          return getTotalGames(db, "ARGUSORBDEFENSE")
      end,
      tiers = {
          { id="AOD_FIRST_BRONZE", tierName="Bronze", target=1, xp=10, desc_de="1 Spiel.", desc_en="1 game." },
      },
    },

    { id="AOD_SCORE", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Punkte-Jäger", title_en="Score Hunter",
      desc_de="Erziele hohe Punktzahlen.", desc_en="Achieve high scores.",
      icon="Interface\\Icons\\Spell_Holy_Heal",
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          return data.score or 0
      end,
      tiers = {
          { id="AOD_SCORE_BRONZE", tierName="Bronze", target=5000,   xp=20, desc_de="5.000 Punkte.",    desc_en="5,000 points."    },
          { id="AOD_SCORE_SILBER", tierName="Silber", target=25000,  xp=45, desc_de="25.000 Punkte.",   desc_en="25,000 points."   },
          { id="AOD_SCORE_GOLD",   tierName="Gold",   target=100000, xp=80, desc_de="100.000 Punkte!",  desc_en="100,000 points!"  },
      },
    },

    { id="AOD_METEORS", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Meteoriten-Jäger", title_en="Meteor Hunter",
      desc_de="Zerstöre Fel-Meteore.", desc_en="Destroy Fel meteors.",
      icon=133231, -- INV_Ingot_FelSteel
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          local killed = data.stats and data.stats.meteorsKilled or 0
          if killed <= 0 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["AOD_METEORS"]
          return (prog and prog.current or 0) + killed
      end,
      tiers = {
          { id="AOD_METEORS_BRONZE", tierName="Bronze", target=50,   xp=20, desc_de="50 Meteore.",    desc_en="50 meteors."    },
          { id="AOD_METEORS_SILBER", tierName="Silber", target=250,  xp=45, desc_de="250 Meteore.",   desc_en="250 meteors."   },
          { id="AOD_METEORS_GOLD",   tierName="Gold",   target=1000, xp=80, desc_de="1.000 Meteore!", desc_en="1,000 meteors!" },
      },
    },

    { id="AOD_HUNTERS", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Jäger-Vernichter", title_en="Hunter Slayer",
      desc_de="Schieße Fel Hunter ab.", desc_en="Shoot down Fel Hunters.",
      icon="Interface\\Icons\\Ability_Hunter_AspectOfTheViper",
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          local killed = data.stats and data.stats.huntersKilled or 0
          if killed <= 0 then return 0 end
          local prog = db.achievements and db.achievements.progress
                       and db.achievements.progress["AOD_HUNTERS"]
          return (prog and prog.current or 0) + killed
      end,
      tiers = {
          { id="AOD_HUNTERS_BRONZE", tierName="Bronze", target=10,  xp=20, desc_de="10 Fel Hunter.",  desc_en="10 Fel Hunters."  },
          { id="AOD_HUNTERS_SILBER", tierName="Silber", target=50,  xp=45, desc_de="50 Fel Hunter.",  desc_en="50 Fel Hunters."  },
          { id="AOD_HUNTERS_GOLD",   tierName="Gold",   target=200, xp=80, desc_de="200 Fel Hunter!", desc_en="200 Fel Hunters!" },
      },
    },

    { id="AOD_WAVE", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Unaufhaltsam", title_en="Unstoppable",
      desc_de="Überlebe viele Wellen.", desc_en="Survive many waves.",
      icon="Interface\\Icons\\Ability_Warrior_Charge",
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          return (data.stats and data.stats.waveReached) or 0
      end,
      tiers = {
          { id="AOD_WAVE_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="Welle 5.",   desc_en="Wave 5."   },
          { id="AOD_WAVE_SILBER", tierName="Silber", target=15, xp=45, desc_de="Welle 15.",  desc_en="Wave 15."  },
          { id="AOD_WAVE_GOLD",   tierName="Gold",   target=30, xp=80, desc_de="Welle 30!",  desc_en="Wave 30!"  },
      },
    },

    { id="AOD_LEVEL", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Exodar-Verteidiger", title_en="Exodar Defender",
      desc_de="Schließe Level ab.", desc_en="Complete levels.",
      icon=236442, -- Achievement_Character_Draenei_Male
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" or data.result ~= "WIN" then return 0 end
          return (data.stats and data.stats.levelReached) or 0
      end,
      tiers = {
          { id="AOD_LEVEL_BRONZE", tierName="Bronze", target=10, xp=20, desc_de="Level 10.",        desc_en="Level 10."         },
          { id="AOD_LEVEL_SILBER", tierName="Silber", target=20, xp=45, desc_de="Level 20.",        desc_en="Level 20."         },
          { id="AOD_LEVEL_GOLD",   tierName="Gold",   target=30, xp=80, desc_de="Alle 30 Level!",   desc_en="All 30 levels!"    },
      },
    },

    { id="AOD_HARD", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Draenei-Krieger", title_en="Draenei Warrior",
      desc_de="Gewinne auf Schwer.", desc_en="Win on Hard.",
      icon=135878, -- Spell_Holy_BlessedResillience (Blizzard spelling)
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          if data.result ~= "WIN" or data.difficulty ~= "hard" then return 0 end
          return 1
      end,
      tiers = {
          { id="AOD_HARD_GOLD", tierName="Gold", target=1, xp=100, desc_de="Einmal auf Schwer.", desc_en="Win on Hard." },
      },
    },

    { id="AOD_NAARU", gameId="ARGUSORBDEFENSE", category="ARCADE",
      title_de="Naaru-Segen", title_en="Naaru Blessing",
      desc_de="Setze die Naaru-Bombe ein und gewinne.", desc_en="Use the Naaru Bomb and win.",
      icon="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      condition = function(data, db)
          if data.gameId ~= "ARGUSORBDEFENSE" then return 0 end
          if data.result ~= "WIN" then return 0 end
          if not (data.stats and data.stats.usedBomb) then return 0 end
          return 1
      end,
      tiers = {
          { id="AOD_NAARU_GOLD", tierName="Gold", target=1, xp=60, desc_de="Bombe + Sieg.", desc_en="Bomb and win." },
      },
    },

})
