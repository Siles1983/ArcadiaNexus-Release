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
        sixCount     = 0,
        phase        = "roll",
        winner       = 0,
    }
end

function L:IsAI(game, playerID)
    return playerID ~= game.humanID
end

function L:RollDice(game)
    if game.rolled then return game.dice end
    local val   = math.random(1, 6)
    game.dice   = val
    game.rolled = true
    game.phase  = "move"
    return val
end

function L:GetValidMoves(game)
    local player = game.players[game.current]
    local dice   = game.dice
    local moves  = {}

    for i, piece in ipairs(player.pieces) do
        if not piece.finished then
            if piece.relPos == 0 then
                if dice == 6 then
                    moves[#moves + 1] = { pieceIdx = i, steps = 0, action = "enter" }
                end
            else
                local newRel = piece.relPos + dice
                if newRel <= 44 then
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
    local result = "moved"

    if piece.relPos == 0 then
        piece.relPos  = 1
        piece.gridIdx = board:GetGridIndex(player.colorIdx, 1)
        result = "entered"
    else
        piece.relPos  = piece.relPos + dice
        piece.gridIdx = board:GetGridIndex(player.colorIdx, piece.relPos)

        if piece.relPos >= 44 then
            piece.relPos   = 45
            piece.finished = true
            piece.gridIdx  = nil
            result = "finished"
        end
    end

    if result == "moved" or result == "entered" then
        if piece.relPos <= 40 then
            if self:CheckCapture(game, player, piece) then
                result = "captured"
            end
        end
    end

    if self:CheckWin(game, game.current) then
        game.winner = game.current
        game.phase  = "gameover"
        return "win"
    end

    return result
end

function L:CheckCapture(game, movingPlayer, movedPiece)
    local board = GetBoard()
    if board.SAFE_FIELDS[movedPiece.gridIdx] then return false end

    local captured = false
    for oppID, opponent in pairs(game.players) do
        if oppID ~= game.current then
            for _, oppPiece in ipairs(opponent.pieces) do
                if not oppPiece.finished and oppPiece.relPos > 0
                        and oppPiece.relPos <= 40
                        and oppPiece.gridIdx == movedPiece.gridIdx then
                    local baseFields = board.BASE_FIELDS[opponent.colorIdx]
                    local usedBases  = {}
                    for _, op2 in ipairs(opponent.pieces) do
                        if op2.relPos == 0 then
                            usedBases[op2.gridIdx] = true
                        end
                    end
                    for _, bf in ipairs(baseFields) do
                        if not usedBases[bf] then
                            oppPiece.relPos  = 0
                            oppPiece.gridIdx = bf
                            captured = true
                            break
                        end
                    end
                end
            end
        end
    end
    return captured
end

function L:CheckWin(game, playerID)
    local player = game.players[playerID]
    for _, piece in ipairs(player.pieces) do
        if not piece.finished then return false end
    end
    return true
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

    game.dice   = 0
    game.rolled = false
    game.phase  = "roll"
end

function L:HasAnyMove(game)
    return #self:GetValidMoves(game) > 0
end

function L:AIPickMove(game)
    local moves  = self:GetValidMoves(game)
    if #moves == 0 then return nil end

    local board  = GetBoard()
    local player = game.players[game.current]
    local best, bestScore = nil, -999

    for _, move in ipairs(moves) do
        local piece = player.pieces[move.pieceIdx]
        local score = 0

        if move.action == "enter" then
            score = 10
        else
            local newRel = piece.relPos + game.dice
            if newRel >= 44 then
                score = 100
            else
                local newGrid = board:GetGridIndex(player.colorIdx, newRel)
                if newRel <= 40 and not board.SAFE_FIELDS[newGrid] then
                    for oppID, opponent in pairs(game.players) do
                        if oppID ~= game.current then
                            for _, op in ipairs(opponent.pieces) do
                                if not op.finished and op.relPos > 0
                                        and op.relPos <= 40
                                        and op.gridIdx == newGrid then
                                    score = score + 50
                                end
                            end
                        end
                    end
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
        sixCount     = game.sixCount,
        phase        = game.phase,
        winner       = game.winner,
    }
end

function L:Deserialize(data)
    if not data or not data.players then return nil end

    local players = {}
    for id, pd in pairs(data.players) do
        local pieces = {}
        for i, pc in ipairs(pd.pieces or {}) do
            pieces[i] = {
                relPos   = pc.relPos or 0,
                gridIdx  = pc.gridIdx,
                finished = pc.finished and true or false,
            }
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
        sixCount     = data.sixCount or 0,
        phase        = data.phase or "roll",
        winner       = data.winner or 0,
    }
end
