-- Whack-a-Mole – Games/WhackAMole/Logic.lua

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.WAM_Logic = {}
local L = ArcadiaNexus.WAM_Logic

L.DIFFICULTY = {
    EASY   = { gridSize=2, moleSpeed=2.0, scoreFactor=1.0, label="Easy"   },
    NORMAL = { gridSize=3, moleSpeed=1.5, scoreFactor=1.5, label="Normal" },
    HARD   = { gridSize=4, moleSpeed=1.0, scoreFactor=2.5, label="Hard"   },
}

-- WoW-Kreaturen Icons (vollständige Pfade, Midnight-kompatibel)
L.MOLE_ICONS = {
    "Interface\\Icons\\Ability_Hunter_BeastCall",
    "Interface\\Icons\\Ability_Tracking",
    "Interface\\Icons\\Spell_Nature_SpiritArmor",
    "Interface\\Icons\\INV_Misc_MonsterHead_02",
    "Interface\\Icons\\Ability_Warrior_Charge",
    "Interface\\Icons\\INV_Misc_MonsterFang_01",
    "Interface\\Icons\\Spell_Shadow_SummonImp",
}
L.BOMB_ICON = "Interface\\Icons\\INV_Misc_Bomb_04"

function L:NewBoard(difficulty)
    local cfg = self.DIFFICULTY[difficulty] or self.DIFFICULTY.NORMAL
    local g   = cfg.gridSize
    local board = {
        difficulty  = difficulty,
        gridSize    = g,
        moleSpeed   = cfg.moleSpeed,
        scoreFactor = cfg.scoreFactor,
        score       = 0,
        missed      = 0,
        timeLeft    = 30,
        gameActive  = false,
        holes       = {},   -- [r][c] = { active=bool, isBomb=bool, icon=str }
    }
    for r = 1, g do
        board.holes[r] = {}
        for c = 1, g do
            board.holes[r][c] = { active=false, isBomb=false, icon=nil }
        end
    end
    return board
end

function L:GetSpawnInterval(board)
    return 0.55
end

function L:PickSpawnType(board)
    local isBomb = (board.score >= 30) and (math.random(100) <= 25)
    local icon
    if isBomb then
        icon = self.BOMB_ICON
    else
        icon = self.MOLE_ICONS[math.random(#self.MOLE_ICONS)]
    end
    return isBomb, icon
end

function L:GetFreeHoles(board)
    local free = {}
    for r = 1, board.gridSize do
        for c = 1, board.gridSize do
            if not board.holes[r][c].active then
                table.insert(free, {r=r, c=c})
            end
        end
    end
    return free
end

function L:HitMole(board, r, c)
    local hole = board.holes[r][c]
    if not hole.active then return "miss" end
    if hole.isBomb then
        hole.active = false
        return "bomb"
    end
    hole.active = false
    local pts = math.floor(10 * board.scoreFactor)
    board.score    = board.score + pts
    board.hitCount = (board.hitCount or 0) + 1
    return "hit", pts
end

function L:MoleMissed(board, r, c)
    local hole = board.holes[r][c]
    if hole.active and not hole.isBomb then
        board.missed = board.missed + 1
    end
    hole.active = false
    hole.isBomb = false
    hole.icon   = nil
end
