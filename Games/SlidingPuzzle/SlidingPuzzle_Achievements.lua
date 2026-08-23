--[[
    ArcadiaNexus
    Games/SlidingPuzzle/SlidingPuzzle_Achievements.lua
    Achievements für Mosaic of Azeroth (Kategorie: RAETSEL)
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterAchievements({

    -- ── Erstes Puzzle ─────────────────────────────────────────
    {
        id       = "SLP_FIRST_WIN",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Puzzler",
        title_en = "Puzzler",
        desc_de  = "Löse dein erstes Mosaic-of-Azeroth-Puzzle.",
        desc_en  = "Solve your first Mosaic of Azeroth puzzle.",
        icon="Interface\\Icons\\Achievement_General",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local gs = db and db.gameSettings and db.gameSettings["MOSAICOFAZEROTH"]
            local st = gs and gs.stats
            if not st or not st.solved then return 0 end
            local total = (st.solved.easy or 0) + (st.solved.medium or 0) + (st.solved.hard or 0)
            return total >= 1 and 1 or 0
        end,
        tiers = {
            { id="SLP_FIRST_WIN_BRONZE", tierName="Bronze", target=1, xp=10,
              desc_de="1 Puzzle gelöst.", desc_en="Solved 1 puzzle." },
        },
    },

    -- ── Easy-Meister ──────────────────────────────────────────
    {
        id       = "SLP_EASY_MASTER",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Leicht gesagt",
        title_en = "Easy Does It",
        desc_de  = "Löse 10x das einfache Puzzle (3x3).",
        desc_en  = "Solve the easy puzzle (3x3) 10 times.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Topaz_01",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local gs = db and db.gameSettings and db.gameSettings["MOSAICOFAZEROTH"]
            local st = gs and gs.stats
            return (st and st.solved and st.solved.easy) or 0
        end,
        tiers = {
            { id="SLP_EASY_BRONZE", tierName="Bronze", target=1,  xp=10,
              desc_de="1x Easy gelöst.",   desc_en="Solved Easy 1 time."   },
            { id="SLP_EASY_SILBER", tierName="Silber", target=5,  xp=25,
              desc_de="5x Easy gelöst.",   desc_en="Solved Easy 5 times."  },
            { id="SLP_EASY_GOLD",   tierName="Gold",   target=10, xp=50,
              desc_de="10x Easy gelöst!",  desc_en="Solved Easy 10 times!" },
        },
    },

    -- ── Medium-Meister ────────────────────────────────────────
    {
        id       = "SLP_MEDIUM_MASTER",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Geduldsprobe",
        title_en = "Patience Test",
        desc_de  = "Löse 5x das normale Puzzle (6x6).",
        desc_en  = "Solve the normal puzzle (6x6) 5 times.",
        icon     = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local gs = db and db.gameSettings and db.gameSettings["MOSAICOFAZEROTH"]
            local st = gs and gs.stats
            return (st and st.solved and st.solved.medium) or 0
        end,
        tiers = {
            { id="SLP_MEDIUM_BRONZE", tierName="Bronze", target=1, xp=15,
              desc_de="1x Normal gelöst.",  desc_en="Solved Normal 1 time."  },
            { id="SLP_MEDIUM_SILBER", tierName="Silber", target=3, xp=35,
              desc_de="3x Normal gelöst.",  desc_en="Solved Normal 3 times." },
            { id="SLP_MEDIUM_GOLD",   tierName="Gold",   target=5, xp=70,
              desc_de="5x Normal gelöst!",  desc_en="Solved Normal 5 times!" },
        },
    },

    -- ── Hard-Meister ──────────────────────────────────────────
    {
        id       = "SLP_HARD_MASTER",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Meisterpuzzler",
        title_en = "Master Puzzler",
        desc_de  = "Löse 3x das schwere Puzzle (8x8).",
        desc_en  = "Solve the hard puzzle (8x8) 3 times.",
        icon     = "Interface\\Icons\\Achievement_PVP_H_16",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local gs = db and db.gameSettings and db.gameSettings["MOSAICOFAZEROTH"]
            local st = gs and gs.stats
            return (st and st.solved and st.solved.hard) or 0
        end,
        tiers = {
            { id="SLP_HARD_BRONZE", tierName="Bronze", target=1, xp=25,
              desc_de="1x Schwer gelöst.",  desc_en="Solved Hard 1 time."  },
            { id="SLP_HARD_SILBER", tierName="Silber", target=2, xp=55,
              desc_de="2x Schwer gelöst.",  desc_en="Solved Hard 2 times." },
            { id="SLP_HARD_GOLD",   tierName="Gold",   target=3, xp=100,
              desc_de="3x Schwer gelöst!",  desc_en="Solved Hard 3 times!" },
        },
    },

    -- ── Blitzpuzzler ──────────────────────────────────────────
    {
        id       = "SLP_SPEED_RUN",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Blitzpuzzler",
        title_en = "Speed Puzzler",
        desc_de  = "Löse das einfache Puzzle in unter 60 Sekunden.",
        desc_en  = "Solve the easy puzzle in under 60 seconds.",
        icon     = "Interface\\Icons\\Ability_Rogue_Sprint",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local st = data.stats
            if not st then return 0 end
            if not (st.difficulty == "easy" and st.time and st.time < 60) then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["SLP_SPEED_RUN"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="SLP_SPEED_BRONZE", tierName="Bronze", target=1, xp=20,
              desc_de="Einmal unter 60s.",  desc_en="Once under 60s."       },
            { id="SLP_SPEED_SILBER", tierName="Silber", target=3, xp=45,
              desc_de="Dreimal unter 60s.", desc_en="Three times under 60s." },
            { id="SLP_SPEED_GOLD",   tierName="Gold",   target=5, xp=80,
              desc_de="Fünfmal unter 60s!", desc_en="Five times under 60s!"  },
        },
    },

    -- ── Minimalist ────────────────────────────────────────────
    {
        id       = "SLP_LOW_MOVES",
        gameId   = "MOSAICOFAZEROTH",
        category = "RAETSEL",
        title_de = "Minimalist",
        title_en = "Minimalist",
        desc_de  = "Löse das einfache Puzzle in 20 Zügen oder weniger.",
        desc_en  = "Solve the easy puzzle in 20 moves or fewer.",
        icon     = "Interface\\Icons\\INV_Misc_Gear_01",
        condition = function(data, db)
            if data.gameId ~= "MOSAICOFAZEROTH" then return 0 end
            local st = data.stats
            if not st then return 0 end
            if not (st.difficulty == "easy" and st.moves and st.moves <= 20) then return 0 end
            local prog = db.achievements and db.achievements.progress
                         and db.achievements.progress["SLP_LOW_MOVES"]
            return (prog and prog.current or 0) + 1
        end,
        tiers = {
            { id="SLP_LOW_MOVES_BRONZE", tierName="Bronze", target=1, xp=30,
              desc_de="Einmal mit max. 20 Zügen.",    desc_en="Once in at most 20 moves."        },
            { id="SLP_LOW_MOVES_SILBER", tierName="Silber", target=3, xp=65,
              desc_de="Dreimal mit max. 20 Zügen.",   desc_en="Three times in at most 20 moves." },
            { id="SLP_LOW_MOVES_GOLD",   tierName="Gold",   target=5, xp=110,
              desc_de="Fünfmal mit max. 20 Zügen!",   desc_en="Five times in at most 20 moves!"  },
        },
    },

})
