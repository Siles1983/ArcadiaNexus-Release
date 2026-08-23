--[[
    ArcadiaNexus – Azeroth Jewels
    Games/AzerothJewels/Levels.lua

    50 Level exakt nach GDD v1.4 §4.2–4.5.

    Felder pro Level:
      grid        Kantenlänge (6 / 7 / 8)
      gems        Anzahl Gem-Typen (6 / 7)
      goalType    "SCORE" | "COLLECT"
      goalScore   Punkte-Ziel (bei SCORE)
      goalCollect { { gemType=N, amount=N }, … } (bei COLLECT)
      moves       Basis-Züge (Difficulty-Malus rechnet Logic)
      timeLimit   Sekunden im Zeitmodus
      obstacles   { { type="ICE"/"STONE"/"LOCKED", row=N, col=N }, … }

    Bänder: 1–10 Anfänger (6×6, 6 Gems, 60s)
            11–20 Lehrling (7×7, 7 Gems, 50s)
            21–35 Veteran (8×8, 7 Gems, 45s, Hindernisse)
            36–50 Held (8×8, 7 Gems, 40s, kombinierte Hindernisse)
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AJ_Levels = {}
local LV = ArcadiaNexus.AJ_Levels

LV.COUNT = 50

local function ICE(r, c)    return { type = "ICE",    row = r, col = c } end
local function STONE(r, c)  return { type = "STONE",  row = r, col = c } end
local function LOCKED(r, c) return { type = "LOCKED", row = r, col = c } end

local LEVELS = {
    -- ── Band: Anfänger (1–10) · 6×6 · 6 Gems · 60s ─────────────
    [1]  = { grid=6, gems=6, goalType="SCORE",   goalScore=1000, moves=30, timeLimit=60, obstacles={} },
    [2]  = { grid=6, gems=6, goalType="SCORE",   goalScore=1200, moves=30, timeLimit=60, obstacles={} },
    [3]  = { grid=6, gems=6, goalType="COLLECT", goalCollect={ { gemType=1, amount=8 } }, moves=28, timeLimit=60, obstacles={} },
    [4]  = { grid=6, gems=6, goalType="SCORE",   goalScore=1400, moves=28, timeLimit=60, obstacles={} },
    [5]  = { grid=6, gems=6, goalType="COLLECT", goalCollect={ { gemType=2, amount=10 } }, moves=28, timeLimit=60, obstacles={} },
    [6]  = { grid=6, gems=6, goalType="SCORE",   goalScore=1600, moves=26, timeLimit=60, obstacles={} },
    [7]  = { grid=6, gems=6, goalType="COLLECT", goalCollect={ { gemType=1, amount=6 }, { gemType=2, amount=6 } }, moves=26, timeLimit=60, obstacles={} },
    [8]  = { grid=6, gems=6, goalType="SCORE",   goalScore=1800, moves=26, timeLimit=60, obstacles={} },
    [9]  = { grid=6, gems=6, goalType="COLLECT", goalCollect={ { gemType=3, amount=14 } }, moves=25, timeLimit=60, obstacles={} },
    [10] = { grid=6, gems=6, goalType="SCORE",   goalScore=2000, moves=25, timeLimit=60, obstacles={} },

    -- ── Band: Lehrling (11–20) · 7×7 · 7 Gems · 50s ────────────
    [11] = { grid=7, gems=7, goalType="SCORE",   goalScore=2200, moves=28, timeLimit=50, obstacles={} },
    [12] = { grid=7, gems=7, goalType="SCORE",   goalScore=2400, moves=28, timeLimit=50, obstacles={} },
    [13] = { grid=7, gems=7, goalType="COLLECT", goalCollect={ { gemType=2, amount=12 } }, moves=26, timeLimit=50, obstacles={} },
    [14] = { grid=7, gems=7, goalType="SCORE",   goalScore=2600, moves=26, timeLimit=50, obstacles={} },
    [15] = { grid=7, gems=7, goalType="COLLECT", goalCollect={ { gemType=3, amount=8 }, { gemType=4, amount=7 } }, moves=26, timeLimit=50, obstacles={} },
    [16] = { grid=7, gems=7, goalType="SCORE",   goalScore=2800, moves=25, timeLimit=50, obstacles={} },
    [17] = { grid=7, gems=7, goalType="COLLECT", goalCollect={ { gemType=1, amount=6 }, { gemType=2, amount=6 }, { gemType=3, amount=6 } }, moves=25, timeLimit=50, obstacles={} },
    [18] = { grid=7, gems=7, goalType="SCORE",   goalScore=3000, moves=24, timeLimit=50, obstacles={} },
    [19] = { grid=7, gems=7, goalType="COLLECT", goalCollect={ { gemType=4, amount=10 }, { gemType=5, amount=10 } }, moves=24, timeLimit=50, obstacles={} },
    [20] = { grid=7, gems=7, goalType="SCORE",   goalScore=3200, moves=23, timeLimit=50, obstacles={} },

    -- ── Band: Veteran (21–35) · 8×8 · 7 Gems · 45s ─────────────
    -- 21–25: Eis (Randbereiche) · 24–25: gesperrte Felder · ab 26: Stein · ab 30: Kombination
    [21] = { grid=8, gems=7, goalType="SCORE",   goalScore=3400, moves=26, timeLimit=45,
             obstacles={ ICE(2,1), ICE(7,8) } },
    [22] = { grid=8, gems=7, goalType="SCORE",   goalScore=3600, moves=25, timeLimit=45,
             obstacles={ ICE(1,3), ICE(4,1), ICE(8,6) } },
    [23] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=1, amount=15 } }, moves=25, timeLimit=45,
             obstacles={ ICE(1,2), ICE(1,7), ICE(8,2), ICE(8,7) } },
    [24] = { grid=8, gems=7, goalType="SCORE",   goalScore=3800, moves=24, timeLimit=45,
             obstacles={ LOCKED(4,4), LOCKED(5,5) } },
    [25] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=2, amount=9 }, { gemType=3, amount=9 } }, moves=24, timeLimit=45,
             obstacles={ LOCKED(1,1), LOCKED(1,8), LOCKED(8,1), LOCKED(8,8) } },
    [26] = { grid=8, gems=7, goalType="SCORE",   goalScore=4000, moves=23, timeLimit=45,
             obstacles={ STONE(3,4), STONE(6,5) } },
    [27] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=4, amount=20 } }, moves=23, timeLimit=45,
             obstacles={ STONE(4,2), STONE(5,7), ICE(2,5), ICE(7,4) } },
    [28] = { grid=8, gems=7, goalType="SCORE",   goalScore=4200, moves=22, timeLimit=45,
             obstacles={ STONE(2,2), STONE(5,5), STONE(7,3) } },
    [29] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=3, amount=11 }, { gemType=5, amount=11 } }, moves=22, timeLimit=45,
             obstacles={ STONE(3,3), STONE(3,6), STONE(6,4), ICE(1,5), ICE(6,8), ICE(8,2) } },
    [30] = { grid=8, gems=7, goalType="SCORE",   goalScore=4400, moves=22, timeLimit=45,
             obstacles={ ICE(2,2), ICE(7,7), STONE(4,5), STONE(5,4), LOCKED(1,8), LOCKED(8,1) } },
    [31] = { grid=8, gems=7, goalType="SCORE",   goalScore=4600, moves=21, timeLimit=45,
             obstacles={ ICE(1,4), ICE(8,5), STONE(3,2), STONE(6,7), LOCKED(4,4), LOCKED(5,5) } },
    [32] = { grid=8, gems=7, goalType="SCORE",   goalScore=4800, moves=21, timeLimit=45,
             obstacles={ ICE(2,6), ICE(4,8), ICE(7,3), STONE(3,5), STONE(5,2), LOCKED(1,1), LOCKED(8,8) } },
    [33] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=1, amount=13 }, { gemType=6, amount=12 } }, moves=20, timeLimit=45,
             obstacles={ ICE(1,3), ICE(8,6), STONE(2,7), STONE(4,4), STONE(5,5), LOCKED(3,8), LOCKED(6,1) } },
    [34] = { grid=8, gems=7, goalType="SCORE",   goalScore=5000, moves=20, timeLimit=45,
             obstacles={ ICE(2,2), ICE(2,7), ICE(7,2), ICE(7,7), STONE(4,5), STONE(5,4), LOCKED(1,5), LOCKED(8,4) } },
    [35] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=2, amount=10 }, { gemType=4, amount=9 }, { gemType=6, amount=9 } }, moves=20, timeLimit=45,
             obstacles={ ICE(1,1), ICE(1,8), ICE(8,1), ICE(8,8), STONE(3,4), STONE(4,6), STONE(6,5), LOCKED(4,7), LOCKED(5,2) } },

    -- ── Band: Held (36–50) · 8×8 · 7 Gems · 40s · Kombinationen ─
    [36] = { grid=8, gems=7, goalType="SCORE",   goalScore=5200, moves=22, timeLimit=40,
             obstacles={ ICE(2,3), ICE(7,6), STONE(4,4), STONE(5,5), LOCKED(1,6), LOCKED(8,3) } },
    [37] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=5, amount=20 } }, moves=22, timeLimit=40,
             obstacles={ ICE(1,2), ICE(4,1), ICE(8,7), STONE(3,6), STONE(6,3), LOCKED(5,8) } },
    [38] = { grid=8, gems=7, goalType="SCORE",   goalScore=5400, moves=21, timeLimit=40,
             obstacles={ ICE(2,5), ICE(7,4), STONE(3,3), STONE(5,2), STONE(6,6), LOCKED(1,1), LOCKED(8,8) } },
    [39] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=3, amount=11 }, { gemType=7, amount=11 } }, moves=21, timeLimit=40,
             obstacles={ ICE(1,4), ICE(1,5), ICE(8,4), ICE(8,5), STONE(4,7), STONE(5,2), LOCKED(3,1), LOCKED(6,8) } },
    [40] = { grid=8, gems=7, goalType="SCORE",   goalScore=5600, moves=20, timeLimit=40,
             obstacles={ ICE(2,2), ICE(2,7), ICE(7,2), ICE(7,7), STONE(4,4), STONE(4,5), STONE(5,4), LOCKED(1,8) } },
    [41] = { grid=8, gems=7, goalType="SCORE",   goalScore=5800, moves=20, timeLimit=40,
             obstacles={ ICE(1,7), ICE(3,5), ICE(6,4), STONE(4,3), STONE(5,6), LOCKED(1,1), LOCKED(8,1), LOCKED(8,8) } },
    [42] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=1, amount=13 }, { gemType=4, amount=12 } }, moves=19, timeLimit=40,
             obstacles={ ICE(2,4), ICE(4,8), ICE(5,1), ICE(7,5), STONE(3,3), STONE(6,6), LOCKED(1,5), LOCKED(8,4) } },
    [43] = { grid=8, gems=7, goalType="SCORE",   goalScore=6000, moves=19, timeLimit=40,
             obstacles={ ICE(1,3), ICE(1,6), ICE(8,3), ICE(8,6), STONE(3,7), STONE(4,4), STONE(5,5), LOCKED(6,2) } },
    [44] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=2, amount=14 }, { gemType=6, amount=14 } }, moves=19, timeLimit=40,
             obstacles={ ICE(2,6), ICE(4,1), ICE(5,8), ICE(7,3), STONE(3,4), STONE(6,5), LOCKED(1,2), LOCKED(8,7) } },
    [45] = { grid=8, gems=7, goalType="SCORE",   goalScore=6200, moves=18, timeLimit=40,
             obstacles={ ICE(2,2), ICE(2,7), ICE(4,5), ICE(7,2), ICE(7,7), STONE(4,6), STONE(5,3), LOCKED(1,4), LOCKED(8,5) } },
    [46] = { grid=8, gems=7, goalType="SCORE",   goalScore=6400, moves=18, timeLimit=40,
             obstacles={ ICE(1,2), ICE(1,7), ICE(8,2), ICE(8,7), STONE(3,3), STONE(4,4), STONE(5,5), STONE(6,6), LOCKED(5,1) } },
    [47] = { grid=8, gems=7, goalType="COLLECT", goalCollect={ { gemType=5, amount=15 }, { gemType=7, amount=15 } }, moves=18, timeLimit=40,
             obstacles={ ICE(1,5), ICE(3,2), ICE(3,7), ICE(6,2), ICE(6,7), STONE(4,5), STONE(5,4), LOCKED(8,1), LOCKED(8,8) } },
    [48] = { grid=8, gems=7, goalType="SCORE",   goalScore=6600, moves=17, timeLimit=40,
             obstacles={ ICE(2,3), ICE(2,6), ICE(4,1), ICE(5,8), ICE(7,3), ICE(7,6), STONE(4,4), STONE(5,5), LOCKED(1,1), LOCKED(1,8) } },
    [49] = { grid=8, gems=7, goalType="COLLECT",
             goalCollect={
                 { gemType=1, amount=5 }, { gemType=2, amount=5 }, { gemType=3, amount=5 },
                 { gemType=4, amount=5 }, { gemType=5, amount=4 }, { gemType=6, amount=4 },
                 { gemType=7, amount=4 },
             }, moves=17, timeLimit=40,
             obstacles={ ICE(1,4), ICE(2,8), ICE(4,2), ICE(5,7), ICE(7,1), ICE(8,5), STONE(3,5), STONE(4,6), STONE(6,4), LOCKED(8,8) } },
    [50] = { grid=8, gems=7, goalType="SCORE",   goalScore=7000, moves=17, timeLimit=40,
             obstacles={ ICE(1,5), ICE(2,2), ICE(2,7), ICE(7,2), ICE(7,7), ICE(8,4), STONE(3,6), STONE(4,4), STONE(5,5), STONE(6,3), LOCKED(1,1), LOCKED(8,8) } },
}

function LV:GetLevel(n)
    n = math.max(1, math.min(n or 1, LV.COUNT))
    return LEVELS[n]
end
