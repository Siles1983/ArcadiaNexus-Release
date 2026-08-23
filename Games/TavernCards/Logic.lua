-- ============================================================
--  Tavern Cards – Logic.lua
--  GameState, Runden-Setup, Charakter-Zuweisung, Scoring.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Logic = {}
local L = ArcadiaNexus.TC_Logic

local function CopyRules(rules)
    return {
        stackDraw2     = rules.stackDraw2 ~= false,
        stackDraw4     = rules.stackDraw4 ~= false,
        playDrawn      = rules.playDrawn ~= false,
        unoCallRule    = rules.unoCallRule ~= false,
        challengeDraw4 = rules.challengeDraw4 ~= false,
    }
end

local function CopyCard(card)
    return {
        id     = card.id,
        color  = card.color,
        type   = card.type,
        value  = card.value,
        points = card.points,
    }
end

function L:PickRandomPlayerCharacterKey()
    local Npc = ArcadiaNexus.TC_NpcData
    local pool = Npc.POOL
    if not pool or #pool == 0 then return "thrall" end
    return pool[math.random(1, #pool)].key
end

function L:AssignCharacters(numAI, playerCharKey)
    local Npc = ArcadiaNexus.TC_NpcData
    local available = {}
    for _, def in ipairs(Npc.POOL) do
        if def.key ~= playerCharKey then
            available[#available + 1] = def
        end
    end
    local shuffled = ArcadiaNexus.ArrayUtils.Shuffle(available)
    local playerDef = Npc:GetByKey(playerCharKey)
    local ai = {}
    for i = 1, numAI do
        ai[i] = shuffled[i]
    end
    return { player = playerDef, ai = ai }
end

function L:NewGameState(config)
    local aiCount = config.aiCount or 1
    if aiCount < 1 then aiCount = 1 end
    if aiCount > 3 then aiCount = 3 end
    local playerCount = 1 + aiCount
    local chars = self:AssignCharacters(aiCount, config.playerCharacter or "thrall")

    local players = {}
    players[1] = {
        index    = 1,
        isAI     = false,
        name     = chars.player.name,
        charKey  = chars.player.key,
        charDef  = chars.player,
        hand     = {},
        score    = 0,
        unoCalled = false,
    }
    for i = 1, aiCount do
        local def = chars.ai[i]
        players[i + 1] = {
            index    = i + 1,
            isAI     = true,
            name     = def.name,
            charKey  = def.key,
            charDef  = def,
            hand     = {},
            score    = 0,
            unoCalled = false,
        }
    end

    return {
        difficulty      = config.difficulty or "easy",
        aiCount         = aiCount,
        playerCount     = playerCount,
        gameMode        = config.gameMode or "single",
        pointTarget     = config.pointTarget or 500,
        theme           = config.theme or "neutral",
        rules           = CopyRules(config.rules or {}),
        players         = players,
        drawPile        = {},
        discardPile     = {},
        direction       = 1,
        currentPlayer   = 1,
        activeColor     = nil,
        pendingDraw     = 0,
        pendingType     = nil,
        skipNext        = 0,
        roundNumber     = 0,
        roundsPlayed    = 0,
        stats           = {
            unosCalled   = 0,
            unosMissed   = 0,
            unosCaught   = 0,
            wild4Played  = 0,
            cardsDrawnAtRoundStart = {},
        },
        unoWindow       = nil,
        wild4Challengable = false,
        drawnThisTurn   = nil,
        hasDrawnThisTurn = false,
        _gameOverFired  = false,
    }
end

function L:StartRound(gs)
    local Deck  = ArcadiaNexus.TC_Deck
    local Rules = ArcadiaNexus.TC_Rules

    gs.roundNumber = (gs.roundNumber or 0) + 1
    gs.drawPile = Deck:Shuffle(Deck:BuildDeck())
    gs.discardPile = {}
    gs.direction = 1
    gs.currentPlayer = 1
    gs.activeColor = nil
    gs.pendingDraw = 0
    gs.pendingType = nil
    gs.skipNext = 0
    gs.unoWindow = nil
    gs.wild4Challengable = false
    gs.wild4Context = nil
    gs.drawnThisTurn = nil
    gs.hasDrawnThisTurn = false
    gs.forceDrawPlayer = nil

    for _, p in ipairs(gs.players) do
        p.hand = {}
        p.unoCalled = false
        for _ = 1, 7 do
            p.hand[#p.hand + 1] = Deck:Draw(gs.drawPile)
        end
        gs.stats.cardsDrawnAtRoundStart[p.index] = #p.hand
    end

    local starter
    repeat
        starter = Deck:Draw(gs.drawPile)
    until starter and not Rules:IsWildType(starter)
    gs.discardPile[1] = starter
    gs.activeColor = starter.color

    if starter.type == "DRAW2" then
        gs.pendingDraw = 2
        gs.pendingType = "DRAW2"
    elseif starter.type == "SKIP" then
        gs.skipNext = 1
    elseif starter.type == "REVERSE" then
        if gs.playerCount == 2 then
            gs.skipNext = 1
        else
            gs.direction = -1
        end
    end

    if gs.skipNext > 0 or (gs.pendingDraw and gs.pendingDraw > 0) then
        gs.currentPlayer = Rules:NextPlayerIndex(gs, 1 + gs.skipNext)
        gs.skipNext = 0
    end

    return gs
end

function L:SyncUnoCalled(player)
    if player and #player.hand ~= 1 then
        player.unoCalled = false
    end
end

function L:RemoveCardFromHand(player, handIndex)
    local card = table.remove(player.hand, handIndex)
    self:SyncUnoCalled(player)
    return card
end

function L:AddToDiscard(gs, card)
    gs.discardPile[#gs.discardPile + 1] = card
end

function L:DrawCardsForPlayer(gs, playerIndex, count)
    local Deck = ArcadiaNexus.TC_Deck
    local player = gs.players[playerIndex]
    local drawn = {}
    for _ = 1, count do
        if #gs.drawPile == 0 then
            Deck:RecycleDiscardIntoDraw(gs.drawPile, gs.discardPile, gs.discardPile[#gs.discardPile])
        end
        local c = Deck:Draw(gs.drawPile)
        if not c then break end
        player.hand[#player.hand + 1] = c
        drawn[#drawn + 1] = c
    end
    self:SyncUnoCalled(player)
    return drawn
end

function L:CheckRoundWinner(gs)
    for _, p in ipairs(gs.players) do
        if #p.hand == 0 then return p.index end
    end
    return nil
end

function L:ScoreRound(gs, winnerIndex)
    local Rules = ArcadiaNexus.TC_Rules
    local winner = gs.players[winnerIndex]
    local roundPoints = 0
    for _, p in ipairs(gs.players) do
        if p.index ~= winnerIndex then
            roundPoints = roundPoints + Rules:HandPoints(p.hand)
        end
    end
    winner.score = winner.score + roundPoints
    gs.roundsPlayed = (gs.roundsPlayed or 0) + 1
    return roundPoints, winner
end

function L:CheckGameWinner(gs)
    if gs.gameMode ~= "multi" then
        return nil
    end
    for _, p in ipairs(gs.players) do
        if p.score >= gs.pointTarget then return p.index end
    end
    return nil
end

function L:CloneGameState(gs)
    local copy = {}
    for k, v in pairs(gs) do
        if k == "players" then
            copy.players = {}
            for _, p in ipairs(v) do
                local ph = {}
                for _, c in ipairs(p.hand) do ph[#ph + 1] = CopyCard(c) end
                copy.players[#copy.players + 1] = {
                    index = p.index, isAI = p.isAI, name = p.name,
                    charKey = p.charKey, charDef = p.charDef,
                    hand = ph, score = p.score, unoCalled = p.unoCalled,
                }
            end
        elseif k == "drawPile" or k == "discardPile" then
            copy[k] = {}
            for _, c in ipairs(v) do copy[k][#copy[k] + 1] = CopyCard(c) end
        elseif k == "rules" or k == "stats" then
            copy[k] = {}
            for rk, rv in pairs(v) do copy[k][rk] = rv end
        elseif type(v) ~= "table" then
            copy[k] = v
        end
    end
    return copy
end

function L:CalcGameResult(gs)
    local human = gs.players[1]
    local bestAI = gs.players[2]
    for i = 2, gs.playerCount do
        if gs.players[i].score > (bestAI and bestAI.score or 0) then
            bestAI = gs.players[i]
        end
    end
    local result = "LOSS"
    if gs.gameMode == "single" then
        if gs.lastRoundWinner == 1 then result = "WIN" end
    else
        if human.score >= gs.pointTarget then result = "WIN"
        elseif bestAI and bestAI.score >= gs.pointTarget then result = "LOSS"
        elseif human.score >= (bestAI and bestAI.score or 0) then result = "WIN"
        else result = "LOSS" end
    end
    return result, human.score
end
