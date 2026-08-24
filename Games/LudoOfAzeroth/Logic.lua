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
            gridIdx  = baseFields[i],
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
        if piece.relPos > 0 then return true end
    end
    return false
end

function L:MaxRollAttempts(game)
    if self:HasPieceOnBoard(game) then return 1 end
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
    local board = GetBoard()
    local baseFields = board.BASE_FIELDS[player.colorIdx]
    local used = {}
    for _, pc in ipairs(player.pieces) do
        if pc ~= piece and pc.relPos == 0 then
            used[pc.gridIdx] = true
        end
    end
    for _, bf in ipairs(baseFields) do
        if not used[bf] then
            piece.relPos   = 0
            piece.gridIdx  = bf
            piece.finished = false
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
                    and piece.gridIdx == gridIdx then
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
    local occ = self:OccupantAtGrid(game, gridIdx, player.id, pieceIdx)
    return occ ~= nil
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

    local startBlocked = HasOwnAtRel(player, 1)

    for i, piece in ipairs(player.pieces) do
        if piece.relPos == 0 then
            if dice == 6 and not startBlocked then
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
    while true do
        local occPlayer, occPiece = self:OccupantAtGrid(
            game, movedPiece.gridIdx, movingPlayer.id, movedIdx)
        if not occPiece then break end
        if self:SendToBase(occPlayer, occPiece) then
            captured = true
        else
            break
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
            score = 10
        else
            local newRel = piece.relPos + game.dice
            if newRel >= 41 then
                score = 80 + newRel
            else
                if self:WouldCapture(game, player, move.pieceIdx, newRel) then
                    score = score + 50
                end
                score = score + newRel
            end
        end

        if score > bestScore then
            bestScore = score
            best      = move
        end
    end

    return best
end

-- ============================================================
-- Save-State
-- ============================================================
function L:Serialize(game)
    if not game or game.phase == "gameover" or game.winner ~= 0 then return nil end

    local players = {}
    for id, p in pairs(game.players) do
        local pieces = {}
        for i, pc in ipairs(p.pieces) do
            pieces[i] = {
                relPos   = pc.relPos,
                gridIdx  = pc.gridIdx,
                finished = pc.finished,
            }
        end
        players[id] = {
            id       = p.id,
            colorIdx = p.colorIdx,
            isAI     = p.isAI,
            pieces   = pieces,
        }
    end

    return {
        players      = players,
        playerCount  = game.playerCount,
        aiCount      = game.aiCount,
        playerOrder  = game.playerOrder,
        humanColor   = game.humanColor,
        current      = game.current,
        humanID      = game.humanID,
        aiIDs        = game.aiIDs,
        aiID         = game.aiID,
        dice         = game.dice,
        rolled       = game.rolled,
        sixCount      = game.sixCount,
        rollAttempts  = game.rollAttempts,
        phase         = game.phase,
        winner        = game.winner,
    }
end

function L:Deserialize(data)
    if not data or not data.players then return nil end

    local players = {}
    for id, pd in pairs(data.players) do
        local pieces = {}
        for i, pc in ipairs(pd.pieces or {}) do
            pieces[i] = {
                relPos   = math.min(44, math.max(0, pc.relPos or 0)),
                gridIdx  = pc.gridIdx,
                finished = pc.finished and true or false,
            }
            if pieces[i].relPos >= 41 then
                pieces[i].finished = true
            end
        end
        players[id] = {
            id       = pd.id or id,
            colorIdx = pd.colorIdx,
            isAI     = pd.isAI and true or false,
            pieces   = pieces,
        }
    end

    return {
        players      = players,
        playerCount  = data.playerCount or 2,
        aiCount      = data.aiCount or (math.max(1, (data.playerCount or 2) - 1)),
        playerOrder  = data.playerOrder or { 1, 2 },
        humanColor   = data.humanColor or 1,
        current      = data.current or 1,
        humanID      = data.humanID or 1,
        aiIDs        = data.aiIDs or { 2 },
        aiID         = data.aiID or 2,
        dice         = data.dice or 0,
        rolled       = data.rolled or false,
        sixCount      = data.sixCount or 0,
        rollAttempts  = data.rollAttempts or 0,
        phase         = data.phase or "roll",
        winner        = data.winner or 0,
    }
end
