--[[
    ArcadiaNexus – Goblin Blast
    Games/GoblinBlast/Levels.lua
    Version: 1.0.0

    12 Level mit ansteigender Schwierigkeit.

    Felder pro Level:
      enemies          Anzahl Gegner (max. 6 Spawnpunkte)
      enemySpeed       Basis-Geschwindigkeit in Kacheln/Sekunde
      brickChance      Anteil zerstoerbarer Waende
      enemyBombChance  Chance pro Gegner-Schritt, eine Bombe zu legen (0 = nie)
      parTime          Ziel-Zeit in Sekunden fuer den vollen Zeitbonus

    Die globale Schwierigkeit (easy/normal/hard) wirkt als Multiplikator
    obendrauf (siehe GB_Logic.DIFFS).
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GB_Levels = {}
local LV = ArcadiaNexus.GB_Levels

LV.COUNT = 12

local LEVELS = {
    --      Gegner  Tempo  Waende  Gegner-Bomben  Par-Zeit
    [1]  = { enemies = 2, enemySpeed = 1.4, brickChance = 0.45, enemyBombChance = 0.00, parTime =  90 },
    [2]  = { enemies = 2, enemySpeed = 1.5, brickChance = 0.50, enemyBombChance = 0.00, parTime = 100 },
    [3]  = { enemies = 3, enemySpeed = 1.6, brickChance = 0.52, enemyBombChance = 0.00, parTime = 110 },
    [4]  = { enemies = 3, enemySpeed = 1.7, brickChance = 0.55, enemyBombChance = 0.10, parTime = 120 },
    [5]  = { enemies = 4, enemySpeed = 1.8, brickChance = 0.55, enemyBombChance = 0.15, parTime = 130 },
    [6]  = { enemies = 4, enemySpeed = 1.9, brickChance = 0.58, enemyBombChance = 0.20, parTime = 140 },
    [7]  = { enemies = 5, enemySpeed = 2.0, brickChance = 0.58, enemyBombChance = 0.25, parTime = 150 },
    [8]  = { enemies = 5, enemySpeed = 2.1, brickChance = 0.60, enemyBombChance = 0.30, parTime = 160 },
    [9]  = { enemies = 5, enemySpeed = 2.2, brickChance = 0.62, enemyBombChance = 0.35, parTime = 170 },
    [10] = { enemies = 6, enemySpeed = 2.3, brickChance = 0.62, enemyBombChance = 0.40, parTime = 180 },
    [11] = { enemies = 6, enemySpeed = 2.4, brickChance = 0.65, enemyBombChance = 0.45, parTime = 190 },
    [12] = { enemies = 6, enemySpeed = 2.5, brickChance = 0.65, enemyBombChance = 0.50, parTime = 200 },
}

function LV:GetLevel(n)
    n = math.max(1, math.min(n or 1, LV.COUNT))
    return LEVELS[n]
end
