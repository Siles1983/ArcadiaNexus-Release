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
    difficulty = self:NormalizeDifficulty(difficulty)
    local cfg = self.DIFFICULTY[difficulty] or self.DIFFICULTY.NORMAL
    local g   = cfg.gridSize
    local board = {
        difficulty  = difficulty,
        gridSize    = g,
        moleSpeed   = cfg.moleSpeed,
        scoreFactor = cfg.scoreFactor,
        score       = 0,
        hitCount    = 0,
        spawnSerial = 0,
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

function L:NormalizeDifficulty(value)
    local key = type(value)=="string" and value:upper() or "NORMAL"
    return self.DIFFICULTY[key] and key or "NORMAL"
end

function L:GetHole(board, r, c)
    if type(board)~="table" or type(r)~="number" or type(c)~="number"
        or r~=math.floor(r) or c~=math.floor(c) then return nil end
    return board.holes[r] and board.holes[r][c]
end

function L:Spawn(board, r, c, now, isBomb, icon)
    local h=self:GetHole(board,r,c)
    if not h or h.active or not board.gameActive then return nil end
    board.spawnSerial=board.spawnSerial+1
    h.spawnId,h.expiresAt=board.spawnSerial,now+board.moleSpeed
    h.active,h.isBomb,h.icon=true,isBomb,icon
    return h.spawnId
end

function L:Expire(board, r, c, spawnId, now)
    local h=self:GetHole(board,r,c)
    if not h or not h.active or h.spawnId~=spawnId or now<h.expiresAt then return false end
    self:MoleMissed(board,r,c)
    return true
end

function L:Finish(board, hitBomb)
    if not board.gameActive then return false end
    board.gameActive=false
    board.result=hitBomb and "LOSS" or "WIN"
    board.reason=hitBomb and "BOMB" or "TIME"
    for _,row in ipairs(board.holes) do
        for _,h in ipairs(row) do h.active,h.isBomb,h.icon=false,false,nil end
    end
    return true
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

function L:HitMole(board, r, c, now)
    local hole = self:GetHole(board,r,c)
    if not hole then return "invalid" end
    if now and hole.active and hole.expiresAt and now>=hole.expiresAt then
        self:Expire(board,r,c,hole.spawnId,now)
        return "expired"
    end
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
    local hole = self:GetHole(board,r,c)
    if not hole then return end
    if hole.active and not hole.isBomb then
        board.missed = board.missed + 1
    end
    hole.active = false
    hole.isBomb = false
    hole.icon   = nil
end
