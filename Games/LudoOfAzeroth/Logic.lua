--[[
    Ludo of Azeroth – Logic.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Logic = {}
local L = ArcadiaNexus.LOA_Logic

local B = nil

-- Uhrzeigersinn um das Brett (Rot → Gelb → Grün → Blau)
local COLOR_TURN_ORDER = { 2, 4, 3, 1 }

local function GetBoard()
    if not B then B = ArcadiaNexus.LOA_Board end
    return B
end

local function MakePlayer(id, colorIdx, isAI)
    local board = GetBoard()
    local pieces = {}
    local baseFields = board.BASE_FIELDS[colorIdx]
    for i = 1, 4 do
        pieces[i] = {
            relPos   = 0,
            gridIdx  = board:GetBaseIdentity(colorIdx,i),
            finished = false,
        }
    end
    return {
        id       = id,
        colorIdx = colorIdx,
        isAI     = isAI and true or false,
        pieces   = pieces,
    }
end

local function BuildPlayerOrder(players, playerCount)
    local order = {}
    for _, colorIdx in ipairs(COLOR_TURN_ORDER) do
        for id = 1, playerCount do
            local p = players[id]
            if p and p.colorIdx == colorIdx then
                order[#order + 1] = id
            end
        end
    end
    return order
end

local function AssignColors(humanColor, aiCount)
    local used = { [humanColor] = true }
    local aiColors = {}
    for _, colorIdx in ipairs(COLOR_TURN_ORDER) do
        if not used[colorIdx] then
            aiColors[#aiColors + 1] = colorIdx
            used[colorIdx] = true
            if #aiColors >= aiCount then break end
        end
    end
    return aiColors
end

function L:NewGame(config)
    local humanColor = tonumber(config.humanColor) or 1
    -- Dropdown-Wert = KI-Anzahl (1 / 2 / 3), nur config.aiCount verwenden
    local aiCount = tonumber(config.aiCount) or 1
    aiCount = math.max(1, math.min(3, aiCount))
    local totalPlayers = 1 + aiCount
    local aiColors = AssignColors(humanColor, aiCount)

    local players = {
        [1] = MakePlayer(1, humanColor, false),
    }
    for i, colorIdx in ipairs(aiColors) do
        players[i + 1] = MakePlayer(i + 1, colorIdx, true)
    end

    local aiIDs = {}
    for id = 2, totalPlayers do
        aiIDs[#aiIDs + 1] = id
    end

    local playerOrder = BuildPlayerOrder(players, totalPlayers)

    return {
        players      = players,
        playerCount  = totalPlayers,
        aiCount      = aiCount,
        playerOrder  = playerOrder,
        humanColor   = humanColor,
        current      = playerOrder[1],
        humanID      = 1,
        aiIDs        = aiIDs,
        aiID         = aiIDs[1],
        dice         = 0,
        rolled       = false,
        sixCount      = 0,
        rollAttempts  = 0,
        phase         = "roll",
        winner        = 0,
    }
end

function L:IsInHome(piece)
    local rel = piece and piece.relPos or 0
    return rel >= 41 and rel <= 44
end

function L:CountHomePieces(player)
    local n = 0
    if not player then return n end
    for _, piece in ipairs(player.pieces) do
        if self:IsInHome(piece) then n = n + 1 end
    end
    return n
end

function L:HasPieceOnBoard(game, playerID)
    local player = game.players[playerID or game.current]
    if not player then return false end
    for _, piece in ipairs(player.pieces) do
        if piece.relPos > 0 and piece.relPos<=40 then return true end
    end
    return false
end

function L:MaxRollAttempts(game)
    if self:HasPieceOnBoard(game) then return 1 end
    if (game.dice or 0)>0 and #self:GetValidMoves(game)>0 then return 1 end
    return 3
end

local function HasOwnAtRel(player, relPos, exceptIdx)
    for i, piece in ipairs(player.pieces) do
        if i ~= exceptIdx and piece.relPos == relPos then
            return true
        end
    end
    return false
end

function L:SendToBase(player, piece)
    for i,pc in ipairs(player.pieces) do if pc==piece then
        piece.relPos,piece.gridIdx,piece.finished=0,GetBoard():GetBaseIdentity(player.colorIdx,i),false
        return true
    end
    end
    return false
end

function L:OccupantAtGrid(game, gridIdx, exceptPlayerID, exceptPieceIdx)
    if not gridIdx then return nil, nil, nil end
    for pID, player in pairs(game.players) do
        for i, piece in ipairs(player.pieces) do
            if not (pID == exceptPlayerID and i == exceptPieceIdx)
                    and piece.relPos > 0 and piece.relPos <= 40
                    and GetBoard():GetGridIndex(player.colorIdx,piece.relPos) == gridIdx then
                return player, piece, i
            end
        end
    end
    return nil, nil, nil
end

function L:WouldCapture(game, player, pieceIdx, destRel)
    if destRel < 1 or destRel > 40 then return false end
    local board = GetBoard()
    local gridIdx = board:GetGridIndex(player.colorIdx, destRel)
    return self:HasEnemyAtGrid(game, gridIdx, player.id)
end

function L:HasEnemyAtGrid(game, gridIdx, movingPlayerID)
    if not gridIdx then return false end
    for _, player in pairs(game.players) do
        if player.id ~= movingPlayerID then
            for _, piece in ipairs(player.pieces) do
                if piece.relPos > 0 and piece.relPos <= 40 and GetBoard():GetGridIndex(player.colorIdx,piece.relPos) == gridIdx then
                    return true
                end
            end
        end
    end
    return false
end

function L:IsAI(game, playerID)
    return playerID ~= game.humanID
end

function L:RollDice(game)
    if game.phase ~= "roll" or game.rolled then return game.dice end
    local val = math.random(1, 6)
    game.dice = val
    game.rollAttempts = (game.rollAttempts or 0) + 1

    local moves = self:GetValidMoves(game)
    if #moves > 0 then
        game.rolled = true
        game.phase  = "move"
    elseif game.rollAttempts < self:MaxRollAttempts(game) then
        game.rolled = false
        game.phase  = "roll"
    else
        game.rolled = true
        game.phase  = "move"
    end
    return val
end

function L:CanReroll(game)
    return game.phase == "roll" and not game.rolled
        and (game.rollAttempts or 0) < self:MaxRollAttempts(game)
end

function L:GetValidMoves(game)
    local player = game.players[game.current]
    local dice   = game.dice
    local moves  = {}
    if not player or not dice or dice < 1 then return moves end

    for i, piece in ipairs(player.pieces) do
        if piece.relPos == 0 then
            if dice == 6 then
                moves[#moves + 1] = { pieceIdx = i, steps = 0, action = "enter" }
            end
        elseif piece.relPos <= 44 then
            local newRel = piece.relPos + dice
            if newRel <= 44 then
                local blockedHome = newRel > 40 and HasOwnAtRel(player, newRel, i)
                if not blockedHome then
                    moves[#moves + 1] = { pieceIdx = i, steps = dice, action = "move" }
                end
            end
        end
    end
    return moves
end

function L:ApplyMove(game, pieceIdx)
    local board  = GetBoard()
    local player = game.players[game.current]
    local piece  = player.pieces[pieceIdx]
    local dice   = game.dice
    local wasHome = self:IsInHome(piece)
    local result = "moved"

    if piece.relPos == 0 then
        piece.relPos  = 1
        piece.gridIdx = board:GetGridIndex(player.colorIdx, 1)
        piece.finished = false
        result = "entered"
    else
        piece.relPos  = piece.relPos + dice
        piece.gridIdx = board:GetGridIndex(player.colorIdx, piece.relPos)
        if self:IsInHome(piece) then
            piece.finished = true
            if not wasHome then result = "finished" end
        else
            piece.finished = false
        end
    end

    if piece.relPos <= 40 then
        if self:CheckCapture(game, player, piece, pieceIdx) then
            result = "captured"
        end
    end

    if self:CheckWin(game, game.current) then
        game.winner = game.current
        game.phase  = "gameover"
        return "win"
    end

    return result
end

function L:CheckCapture(game, movingPlayer, movedPiece, movedIdx)
    if movedPiece.relPos < 1 or movedPiece.relPos > 40 then return false end

    local captured = false
    for _, player in pairs(game.players) do
        if player.id ~= movingPlayer.id then
            for _, piece in ipairs(player.pieces) do
                if piece.relPos > 0 and piece.relPos <= 40
                        and GetBoard():GetGridIndex(player.colorIdx,piece.relPos)==GetBoard():GetGridIndex(movingPlayer.colorIdx,movedPiece.relPos) then
                    if self:SendToBase(player, piece) then
                        captured = true
                    end
                end
            end
        end
    end
    return captured
end

function L:CheckWin(game, playerID)
    local player = game.players[playerID]
    if not player then return false end
    return self:CountHomePieces(player) >= 4
end

function L:NextTurn(game)
    local got6 = (game.dice == 6)

    if got6 and game.sixCount < 2 then
        game.sixCount = game.sixCount + 1
    else
        game.sixCount = 0
        local order = game.playerOrder
        local idx   = 1
        for i, id in ipairs(order) do
            if id == game.current then idx = i; break end
        end
        game.current = order[(idx % #order) + 1]
    end

    game.dice          = 0
    game.rolled        = false
    game.rollAttempts  = 0
    game.phase         = "roll"
end

function L:HasAnyMove(game)
    return #self:GetValidMoves(game) > 0
end

function L:AIPickMove(game)
    local moves  = self:GetValidMoves(game)
    if #moves == 0 then return nil end

    local player = game.players[game.current]
    local best, bestScore = nil, -999

    for _, move in ipairs(moves) do
        local piece = player.pieces[move.pieceIdx]
        local score = 0

        if move.action == "enter" then
            score = 10 + (self:WouldCapture(game,player,move.pieceIdx,1) and 50 or 0)
        else
            local newRel = piece.relPos + game.dice
            if newRel >= 41 then
                score = 80 + newRel
            else
                if self:WouldCapture(game, player, move.pieceIdx, newRel) then
                    score = score + 50
                end
                score = score + newRel
                if piece.relPos==1 then score=score+4 end
            end
        end

        if score > bestScore then
            bestScore = score
            best      = move
        end
    end

    return best
end

-- Logical route: each relative waypoint, never pixel coordinates.
function L:Route(color, from, to)
    local out={}
    if from==0 then out[1]=1 else for rel=from+1,to do out[#out+1]=rel end end
    return out
end
function L:Copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=self:Copy(v) end; return out
end
function L:Serialize(game)
    if not game or game.winner~=0 or game.phase=="gameover" then return nil end
    local out=self:Copy(game)
    if out.pending then
        out.pending.remaining=math.max(0,math.min(out.pending.remaining,(out.pending.deadline or GetTime())-GetTime()))
        out.pending.deadline=nil
    end
    out.resultData=nil
    return out
end
local function int(n,lo,hi) return type(n)=="number" and n%1==0 and n>=lo and n<=hi end
local function array(t,n)
    if type(t)~="table" then return false end
    local count=0; for k in pairs(t) do if not int(k,1,n) then return false end; count=count+1 end
    return count==n
end
function L:Deserialize(data)
    if type(data)~="table" or not int(data.aiCount,1,3) or not int(data.humanColor,1,4)
        or data.playerCount~=data.aiCount+1 or data.humanID~=1 or data.winner~=0
        or not int(data.current,1,data.playerCount) or not int(data.dice,0,6)
        or type(data.rolled)~="boolean" or not int(data.sixCount,0,2) or not int(data.rollAttempts,0,3)
        or not array(data.players,data.playerCount) then return nil end
    local modern=data.version==2
    if data.version~=nil and not modern then return nil end
    if modern and (data.ruleVersion~=2 or data.layoutVersion~=2 or type(data.runId)~="string"
        or not int(data.action,0,2147483647)) then return nil end
    local fresh=self:NewGame({humanColor=data.humanColor,aiCount=data.aiCount})
    if not array(data.playerOrder,data.playerCount) or not array(data.aiIDs,data.aiCount) or data.aiID~=2 then return nil end
    for i,id in ipairs(fresh.playerOrder) do if data.playerOrder[i]~=id then return nil end end
    for i,id in ipairs(fresh.aiIDs) do if data.aiIDs[i]~=id then return nil end end
    local out=self:Copy(data)
    for id,expected in ipairs(fresh.players) do
        local p=data.players[id]
        if type(p)~="table" or p.id~=id or p.colorIdx~=expected.colorIdx or p.isAI~=expected.isAI or not array(p.pieces,4) then return nil end
        local home={}
        for i,pc in ipairs(p.pieces) do
            if type(pc)~="table" or not int(pc.relPos,0,44) then return nil end
            local rel=pc.relPos
            if rel>40 then if home[rel] then return nil end; home[rel]=true end
            out.players[id].pieces[i]={relPos=rel,finished=rel>40,
                gridIdx=rel==0 and GetBoard():GetBaseIdentity(p.colorIdx,i) or GetBoard():GetGridIndex(p.colorIdx,rel)}
        end
        if self:CheckWin(out,id) then return nil end
    end
    if out.phase~="roll" and out.phase~="move" and out.phase~="ROLLING" and out.phase~="MOVE_RESOLVING" and out.phase~="TURN_PENDING" then return nil end
    if out.phase=="roll" and out.rolled or out.phase=="move" and (not out.rolled or out.dice==0) then return nil end
    if not modern then
        if out.phase~="roll" and out.phase~="move" or out.pending then return nil end
        out.legacy=true
        if out.phase=="move" then out.legacyChoice=#self:GetValidMoves(out)>0 end
        return out
    end
    local pending=out.pending
    if pending then
        if type(pending)~="table" or type(pending.remaining)~="number" or pending.remaining~=pending.remaining
            or pending.remaining<0 or pending.remaining>2 or pending.deadline~=nil then return nil end
        local kind=pending.kind
        if kind=="ROLL" then
            if out.phase~="ROLLING" or out.dice==0 or out.rollAttempts<1
                or pending.outcome~="roll" and pending.outcome~="move" then return nil end
            local moves=#self:GetValidMoves(out)
            local outcome=moves>0 or out.rollAttempts>=self:MaxRollAttempts(out)
            if pending.outcome~=(outcome and "move" or "roll") or out.rolled~=outcome then return nil end
        elseif kind=="MOVE" or kind=="TURN" then
            if out.phase~=(kind=="MOVE" and "MOVE_RESOLVING" or "TURN_PENDING") or out.dice==0 or out.rolled then return nil end
        elseif kind=="AI_ROLL" or kind=="AI_MOVE" then
            if out.current==1 or out.phase~=(kind=="AI_ROLL" and "roll" or "move") then return nil end
        else return nil end
    elseif out.phase~="roll" and out.phase~="move" then return nil end
    if out.motion then
        local m=out.motion
        if out.phase~="MOVE_RESOLVING" and out.phase~="TURN_PENDING" or type(m)~="table" or not int(m.player,1,out.playerCount) or m.player~=out.current
            or not int(m.piece,1,4) or not int(m.from,0,43) or not int(m.to,1,44)
            or m.to~=(m.from==0 and 1 or m.from+out.dice) or m.from==0 and out.dice~=6
            or out.players[m.player].pieces[m.piece].relPos~=m.to or type(m.captured)~="table" then return nil end
        local n,seen=0,{}
        for k,c in pairs(m.captured) do
            n=n+1
            if not int(k,1,12) or type(c)~="table" or not int(c.player,1,out.playerCount) or c.player==m.player
                or not int(c.piece,1,4) or not int(c.from,1,40) or out.players[c.player].pieces[c.piece].relPos~=0
                or GetBoard():GetGridIndex(out.players[c.player].colorIdx,c.from)~=GetBoard():GetGridIndex(out.players[m.player].colorIdx,m.to) then return nil end
            local key=c.player..":"..c.piece
            if seen[key] then return nil end; seen[key]=true
        end
        if not array(m.captured,n) then return nil end
        m.route=self:Route(out.players[m.player].colorIdx,m.from,m.to)
        m.travel=m.from==0 and .25 or #m.route*.11
        m.duration=m.travel+(#m.captured>0 and .25 or 0)
        if pending and pending.kind=="MOVE" and pending.remaining>m.duration then return nil end
    elseif out.phase=="MOVE_RESOLVING" then return nil end
    if pending and (pending.kind=="AI_ROLL" and pending.remaining>1.2
        or pending.kind=="AI_MOVE" and pending.remaining>.8 or pending.kind=="TURN" and pending.remaining>(out.motion and .15 or 1)) then return nil end
    return out
end
