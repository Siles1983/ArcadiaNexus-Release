-- Frozen metadata must outlive removed game modules. Original IDs are unchanged.
local A=_G.ArcadiaNexus
local reason_de="Match-3 wurde entfernt."
local reason_en="Match-3 has been removed."
A.RegisterAchievements({
    {
        id="M3_WINS",gameId="MATCH3",category="DENKSPIELE",retired=true,
        gameLabel="Match-3",retiredVersion=1,retiredReason_de=reason_de,retiredReason_en=reason_en,
        title_de="Drei-Kombinierer",title_en="Triple Matcher",
        desc_de="Gewinne Match-3-Partien.",desc_en="Win Match-3 games.",
        icon="Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
        tiers={
            {id="M3_WINS_BRONZE",tierName="Bronze",target=5,xp=15,desc_de="Gewinne 5x.",desc_en="Win 5 games."},
            {id="M3_WINS_SILBER",tierName="Silber",target=20,xp=30,desc_de="Gewinne 20x.",desc_en="Win 20 games."},
            {id="M3_WINS_GOLD",tierName="Gold",target=60,xp=55,desc_de="Gewinne 60x.",desc_en="Win 60 games."},
        },
    },
    {
        id="M3_COMBO",gameId="MATCH3",category="DENKSPIELE",retired=true,
        gameLabel="Match-3",retiredVersion=1,retiredReason_de=reason_de,retiredReason_en=reason_en,
        title_de="Kaskadenmeister",title_en="Cascade Master",
        desc_de="Erziele hohe Combos in Match-3.",desc_en="Achieve high combos in Match-3.",
        icon="Interface\\Icons\\Spell_Fire_Fireball",
        tiers={
            {id="M3_COMBO_BRONZE",tierName="Bronze",target=3,xp=20,desc_de="Combo x3.",desc_en="Combo x3."},
            {id="M3_COMBO_SILBER",tierName="Silber",target=5,xp=40,desc_de="Combo x5.",desc_en="Combo x5."},
            {id="M3_COMBO_GOLD",tierName="Gold",target=8,xp=65,desc_de="Combo x8!",desc_en="Combo x8!"},
        },
    },
})

A.RegisterAchievements({
    { id="HOL_HARDMODE", gameId="HIGHERORLOWER", category="KARTEN", retired=true, gameLabel="Higher or Lower", retiredVersion=2,
      retiredReason_de="Die alte Schwierigkeitsvariante Schwer wurde entfernt.", retiredReason_en="The old Hard difficulty has been removed.",
      title_de="Joker-Jäger", title_en="Joker Hunter",
      desc_de="Gewinne auf Schwer.", desc_en="Win on Hard.",
      icon="Interface\\Icons\\INV_Misc_Dice_02",
      tiers = {
          { id="HOL_HARDMODE_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Einmal auf Schwer.",   desc_en="Win once on Hard."       },
          { id="HOL_HARDMODE_SILBER", tierName="Silber", target=5,  xp=55, desc_de="Fünfmal auf Schwer.",  desc_en="Win five times on Hard."  },
          { id="HOL_HARDMODE_GOLD",   tierName="Gold",   target=10, xp=85, desc_de="Zehnmal auf Schwer!",  desc_en="Win ten times on Hard!"   },
      },
    },

    { id="HOL_HARDSTREAK", gameId="HIGHERORLOWER", category="KARTEN", retired=true, gameLabel="Higher or Lower", retiredVersion=2,
      retiredReason_de="Die alte Schwierigkeitsvariante Schwer wurde entfernt.", retiredReason_en="The old Hard difficulty has been removed.",
      title_de="Joker-Trotzer", title_en="Joker Defier",
      desc_de="Streak 7+ auf Schwer.", desc_en="Reach streak 7+ on Hard.",
      icon="Interface\\Icons\\INV_Misc_Dice_01",
      tiers = {
          { id="HOL_HARDSTREAK_BRONZE", tierName="Bronze", target=1, xp=40, desc_de="Einmal Streak 7+ auf Schwer.",   desc_en="Streak 7+ on Hard once."       },
          { id="HOL_HARDSTREAK_SILBER", tierName="Silber", target=3, xp=70, desc_de="Dreimal Streak 7+ auf Schwer.",  desc_en="Streak 7+ on Hard three times." },
          { id="HOL_HARDSTREAK_GOLD",   tierName="Gold",   target=5, xp=95, desc_de="Fünfmal Streak 7+ auf Schwer!",  desc_en="Streak 7+ on Hard five times!"  },
      },
    },

    { id="HOL_STREAK10_LEGACY_GOLD",retiredProgressSource="HOL_STREAK10",gameId="HIGHERORLOWER",category="KARTEN",retired=true,
      gameLabel="Higher or Lower",retiredVersion=2,
      retiredReason_de="Die alte Schwierigkeitsvariante Schwer wurde entfernt.",
      retiredReason_en="The old Hard difficulty has been removed.",
      title_de="Unfehlbar",title_en="Infallible",
      desc_de="Erreiche Streak 10+.",desc_en="Reach a streak of 10 or more.",
      icon="Interface\\Icons\\Spell_Holy_BorrowedTime",
      tiers={{id="HOL_STREAK10_GOLD",tierName="Gold",target=4,xp=90,
        desc_de="Davon mindestens eine Streak auf Schwer!",desc_en="Complete at least one of them on Hard!"}},
    },

})

A.RegisterAchievements({
    {
        id       = "SOL_HIGHSCORE",
        gameId   = "SOLITAIRE",
        category = "KARTEN", retired=true, gameLabel="Solitaire", retiredVersion=3,
        retiredReason_de="Die alte Wertung mit Zeitbonus wurde entfernt.",
        retiredReason_en="The old scoring with time bonus has been removed.",
        title_de = "Punktejäger",
        title_en = "Score Hunter",
        desc_de  = "Erreiche hohe Punktzahlen in einem Spiel.",
        desc_en  = "Reach high scores in a single game.",
        icon     = 236594, -- Achievement_PVP_A_H
        tiers = {
            { id="SOL_HIGHSCORE_BRONZE", tierName="Bronze", target=1000, xp=20, desc_de="Erreiche 1.000 Punkte.",  desc_en="Reach 1,000 points."  },
            { id="SOL_HIGHSCORE_SILBER", tierName="Silber", target=3000, xp=45, desc_de="Erreiche 3.000 Punkte.",  desc_en="Reach 3,000 points."  },
            { id="SOL_HIGHSCORE_GOLD",   tierName="Gold",   target=5000, xp=80, desc_de="Erreiche 5.000 Punkte!",  desc_en="Reach 5,000 points!"  },
        },
    },

})

A.RegisterAchievements({

    {
        id="WRD_WINS", gameId="AZEROTHWORDS", category="WORT", retired=true, gameLabel="Azeroth Words", retiredVersion=4,
        retiredReason_de="Azeroth Words wurde entfernt.", retiredReason_en="Azeroth Words has been removed.",
        title_de="Worte des Lichts", title_en="Words of Light",
        desc_de="Errate Wörter in Azeroth Words.", desc_en="Guess words in Azeroth Words.",
        icon="Interface\\Icons\\INV_Letter_17",
        tiers = {
            { id="WRD_WINS_BRONZE", tierName="Bronze", target=5,  xp=15, desc_de="Errate 5 Wörter.",  desc_en="Guess 5 words."  },
            { id="WRD_WINS_SILBER", tierName="Silber", target=25, xp=35, desc_de="Errate 25 Wörter.", desc_en="Guess 25 words." },
            { id="WRD_WINS_GOLD",   tierName="Gold",   target=75, xp=60, desc_de="Errate 75 Wörter!", desc_en="Guess 75 words!" },
        },
    },

    {
        id="WRD_FIRSTTRY", gameId="AZEROTHWORDS", category="WORT", retired=true, gameLabel="Azeroth Words", retiredVersion=4,
        retiredReason_de="Azeroth Words wurde entfernt.", retiredReason_en="Azeroth Words has been removed.",
        title_de="Arkane Intuition", title_en="Arcane Intuition",
        desc_de="Errate das Wort im ersten Versuch.", desc_en="Guess the word on the first try.",
        icon=135732, -- Spell_Arcane_ArcanePotency
        tiers = {
            { id="WRD_FIRSTTRY_BRONZE", tierName="Bronze", target=1, xp=30, desc_de="Einmal im ersten Versuch.",  desc_en="First try once."  },
            { id="WRD_FIRSTTRY_SILBER", tierName="Silber", target=3, xp=55, desc_de="Dreimal im ersten Versuch.", desc_en="First try 3 times." },
            { id="WRD_FIRSTTRY_GOLD",   tierName="Gold",   target=7, xp=85, desc_de="Siebenmal im ersten Versuch!", desc_en="First try 7 times!" },
        },
    },

    {
        id="WRD_HARD", gameId="AZEROTHWORDS", category="WORT", retired=true, gameLabel="Azeroth Words", retiredVersion=4,
        retiredReason_de="Azeroth Words wurde entfernt.", retiredReason_en="Azeroth Words has been removed.",
        title_de="Meister der Runen", title_en="Rune Master",
        desc_de="Gewinne auf Schwer.", desc_en="Win on Hard difficulty.",
        icon=136206, -- Spell_Shadow_ShadowWordDominate
        tiers = {
            { id="WRD_HARD_BRONZE", tierName="Bronze", target=1,  xp=25, desc_de="Gewinne 1x auf Schwer.",   desc_en="Win 1 on Hard."   },
            { id="WRD_HARD_SILBER", tierName="Silber", target=10, xp=50, desc_de="Gewinne 10x auf Schwer.",  desc_en="Win 10 on Hard."  },
            { id="WRD_HARD_GOLD",   tierName="Gold",   target=25, xp=80, desc_de="Gewinne 25x auf Schwer!",  desc_en="Win 25 on Hard!"  },
        },
    },
})
