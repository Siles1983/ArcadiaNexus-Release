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

    { id="RS_STRIKES", gameId="REACTIONSTRIKE", category="GESCHICK",
      title_de="Reflexkrieger", title_en="Reflex Warrior",
      desc_de="Erziele gültige Treffer in Reaction Strike.", desc_en="Land valid strikes in Reaction Strike.",
      icon=236205, -- Ability_Mage_ArcaneBarrage
      condition = function(data, db)
          if data.gameId ~= "REACTIONSTRIKE" then return 0 end
          return getTotalWins(db, "REACTIONSTRIKE")
      end,
      tiers = {
          { id="RS_STRIKES_BRONZE", tierName="Bronze", target=10,  xp=15, desc_de="10 gültige Treffer.",  desc_en="10 valid strikes."  },
          { id="RS_STRIKES_SILBER", tierName="Silber", target=50,  xp=30, desc_de="50 gültige Treffer.",  desc_en="50 valid strikes."  },
          { id="RS_STRIKES_GOLD",   tierName="Gold",   target=150, xp=55, desc_de="150 gültige Treffer!", desc_en="150 valid strikes!" },
      },
    },

    { id="RS_SPEED", gameId="REACTIONSTRIKE", category="GESCHICK",
      title_de="Lichtschnell", title_en="Lightning Reflexes",
      desc_de="Reagiere blitzschnell.", desc_en="React lightning fast.",
      icon="Interface\\Icons\\Spell_Holy_BorrowedTime",
      condition = function(data, db)
          if data.gameId ~= "REACTIONSTRIKE" or data.result ~= "WIN" then return 0 end
          local ms=data.reactionMs
          if type(ms)~="number" then return 0 end
          if ms < 50 then return 3 end
          if ms < 200 then return 2 end
          if ms < 400 then return 1 end
          return 0
      end,
      tiers = {
          { id="RS_SPEED_BRONZE", tierName="Bronze", target=1, xp=20, desc_de="Reagiere in unter 400 ms.", desc_en="React in under 400 ms." },
          { id="RS_SPEED_SILBER", tierName="Silber", target=2, xp=45, desc_de="Reagiere in unter 200 ms.", desc_en="React in under 200 ms." },
          { id="RS_SPEED_GOLD", tierName="Gold", target=3, xp=75, desc_de="Reagiere in unter 50 ms!", desc_en="React in under 50 ms!" },
      },
    },

    { id="RS_FAKEOUT", gameId="REACTIONSTRIKE", category="GESCHICK",
      title_de="Ungetäuscht", title_en="Unfooled",
      desc_de="Lass dich nicht von Fakeout-Orbs täuschen.", desc_en="Survive fakeout orbs.",
      icon="Interface\\Icons\\Spell_Fire_FlameBolt",
      condition = function(data, db)
          if data.gameId ~= "REACTIONSTRIKE" or not data.fakeoutEvent then return nil end
          local settings=db.gameSettings and db.gameSettings.REACTIONSTRIKE
          return settings and settings.fakeoutsSurvived or 0
      end,
      tiers = {
          { id="RS_FAKEOUT_BRONZE", tierName="Bronze", target=5,  xp=20, desc_de="5 Fakeouts.",   desc_en="5 fakeouts."   },
          { id="RS_FAKEOUT_SILBER", tierName="Silber", target=20, xp=40, desc_de="20 Fakeouts.",  desc_en="20 fakeouts."  },
          { id="RS_FAKEOUT_GOLD",   tierName="Gold",   target=50, xp=65, desc_de="50 Fakeouts!",  desc_en="50 fakeouts!"  },
      },
    },

})
