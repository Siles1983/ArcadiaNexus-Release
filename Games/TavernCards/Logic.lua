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
        gs.currentPlayer = Rules:NextPlayerIndex(gs, 1)
    elseif starter.type == "REVERSE" then
        if gs.playerCount == 2 then
            gs.currentPlayer = Rules:NextPlayerIndex(gs, 1)
        else
            gs.direction = -1
        end
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

-- ============================================================
-- Match v1: 2–4 Menschen, eine Runde. Stapel nur Host.
-- Private = eigene Hand. Intents: PLAY/COLOR/DRAW/PASS/UNO/CATCH/CHALLENGE/ACCEPT/UNO_EXPIRE
-- ============================================================

L.GAME_ID = "TAVERNCARDS"
L.GAME_PROTO = 1

local COL_C = { GREEN = "g", BLUE = "b", RED = "r", YELLOW = "y", WILD = "w" }
local COL_D = { g = "GREEN", b = "BLUE", r = "RED", y = "YELLOW", w = "WILD" }
local TYP_C = { NUMBER = "n", DRAW2 = "d", SKIP = "s", REVERSE = "v", WILD = "w", WILD4 = "f" }
local TYP_D = { n = "NUMBER", d = "DRAW2", s = "SKIP", v = "REVERSE", w = "WILD", f = "WILD4" }

function L.PackCard(card)
    if not card then return "xxx" end
    local v = card.value
    if v == nil then v = "x" else v = tostring(v) end
    return (COL_C[card.color] or "w") .. (TYP_C[card.type] or "n") .. v
end

function L.UnpackCard(s)
    if type(s) ~= "string" or #s < 3 then return nil end
    local col, typ, val = s:sub(1, 1), s:sub(2, 2), s:sub(3)
    local value = tonumber(val)
    return {
        id = 0,
        color = COL_D[col] or "WILD",
        type = TYP_D[typ] or "NUMBER",
        value = value,
        points = 0,
    }
end

function L.PackHand(hand)
    if type(hand) ~= "table" then return "" end
    local t = {}
    for i = 1, #hand do
        t[#t + 1] = L.PackCard(hand[i])
    end
    return table.concat(t, ",")
end

function L.UnpackHand(s)
    local hand = {}
    if type(s) ~= "string" or s == "" or s == "." then return hand end
    for token in string.gmatch(s, "[^,]+") do
        local c = L.UnpackCard(token)
        if c then hand[#hand + 1] = c end
    end
    return hand
end

function L.UnpackColor(c)
    if not c or c == "" then return nil end
    c = tostring(c)
    if COL_D[c] then return COL_D[c] end
    if COL_C[c] then return c end
    return nil
end

function L:NewMpGameState(n, hostCharKey, rules, theme)
    n = tonumber(n) or 2
    if n < 2 then n = 2 end
    if n > 4 then n = 4 end
    local Npc = ArcadiaNexus.TC_NpcData
    hostCharKey = hostCharKey or "thrall"
    local used = { [hostCharKey] = true }
    local pool = {}
    for _, def in ipairs(Npc.POOL or {}) do
        if not used[def.key] then pool[#pool + 1] = def end
    end
    pool = ArcadiaNexus.ArrayUtils.Shuffle(pool)
    local players = {}
    for i = 1, n do
        local def
        if i == 1 then
            def = Npc:GetByKey(hostCharKey)
        else
            def = pool[i - 1] or Npc.POOL[1]
        end
        players[i] = {
            index = i,
            isAI = false,
            name = def.name,
            charKey = def.key,
            charDef = def,
            hand = {},
            score = 0,
            unoCalled = false,
        }
    end
    return {
        difficulty = "normal",
        aiCount = 0,
        playerCount = n,
        gameMode = "single",
        pointTarget = 500,
        theme = theme or "neutral",
        rules = CopyRules(rules or {}),
        players = players,
        drawPile = {},
        discardPile = {},
        direction = 1,
        currentPlayer = 1,
        activeColor = nil,
        pendingDraw = 0,
        pendingType = nil,
        skipNext = 0,
        roundNumber = 0,
        roundsPlayed = 0,
        stats = {
            unosCalled = 0, unosMissed = 0, unosCaught = 0, wild4Played = 0,
            cardsDrawnAtRoundStart = {},
        },
        unoWindow = nil,
        wild4Challengable = false,
        drawnThisTurn = nil,
        hasDrawnThisTurn = false,
        mpOver = false,
        lastRoundWinner = nil,
    }
end

function L.EmptyPublic()
    return {
        n = 2, t = 1, dir = 1, ac = "", top = "", ds = "",
        pd = 0, pt = "", hs = "0,0", sc = "0,0", ck = "",
        dc = 0, uw = 0, uwp = 0, w4 = 0, pc = 0, hd = 0,
        o = 0, w = 0, th = "n", rl = "11111",
        over = false, winner = 0, turn = 1, blocked = false,
    }
end

function L.SyncPublic(pub, gs)
    if not pub or not gs then return end
    pub.n = gs.playerCount
    pub.t = gs.currentPlayer
    pub.turn = gs.currentPlayer
    pub.dir = (gs.direction or 1) >= 0 and 1 or 0
    local ac = gs.activeColor or ""
    pub.ac = COL_C[ac] or ""
    local top = gs.discardPile and gs.discardPile[#gs.discardPile]
    pub.top = L.PackCard(top)
    local ds = {}
    local pile = gs.discardPile or {}
    local start = math.max(1, #pile - 2)
    for i = start, #pile do
        ds[#ds + 1] = L.PackCard(pile[i])
    end
    pub.ds = table.concat(ds, ",")
    pub.pd = gs.pendingDraw or 0
    pub.pt = gs.pendingType or ""
    local hs, sc, ck = {}, {}, {}
    for i = 1, gs.playerCount do
        local p = gs.players[i]
        hs[i] = tostring(p and p.hand and #p.hand or 0)
        sc[i] = tostring(p and p.score or 0)
        ck[i] = (p and p.charKey) or "thrall"
    end
    pub.hs = table.concat(hs, ",")
    pub.sc = table.concat(sc, ",")
    pub.ck = table.concat(ck, ",")
    pub.dc = gs.drawPile and #gs.drawPile or 0
    pub.uw = (gs.unoWindow and not gs.unoWindow.resolved) and 1 or 0
    pub.uwp = gs.unoWindow and gs.unoWindow.playerIndex or 0
    pub.w4 = gs.wild4Challengable and 1 or 0
    pub.pc = (gs.pendingColorPick and gs.pendingColorPick.playerIndex) or 0
    pub.hd = gs.hasDrawnThisTurn and 1 or 0
    pub.th = (gs.theme == "alliance" and "a") or (gs.theme == "horde" and "h") or "n"
    local r = gs.rules or {}
    pub.rl = (r.stackDraw2 and "1" or "0")
        .. (r.stackDraw4 and "1" or "0")
        .. (r.playDrawn and "1" or "0")
        .. (r.unoCallRule and "1" or "0")
        .. (r.challengeDraw4 and "1" or "0")
    pub.o = gs.mpOver and 1 or 0
    pub.over = gs.mpOver and true or false
    pub.w = gs.lastRoundWinner or 0
    pub.winner = pub.w
end

function L.MpAdvanceTurn(gs)
    gs.turnNotice = nil
    gs.drawnThisTurn = nil
    gs.hasDrawnThisTurn = false
    local Rules = ArcadiaNexus.TC_Rules
    local steps = 1 + (gs.skipNext or 0)
    gs.skipNext = 0
    gs.currentPlayer = Rules:NextPlayerIndex(gs, steps)
    L.MpBeginTurn(gs)
end

function L.MpBeginTurn(gs)
    local Rules = ArcadiaNexus.TC_Rules
    if gs.forceDrawPlayer then
        local victim = gs.forceDrawPlayer
        L:DrawCardsForPlayer(gs, victim, gs.pendingDraw or 4)
        gs.forceDrawPlayer = nil
        gs.pendingDraw = 0
        gs.pendingType = nil
        if victim == gs.currentPlayer then
            L.MpAdvanceTurn(gs)
            return
        end
    end
    if gs.wild4Challengable and gs.currentPlayer ~= gs.wild4PlayedBy then
        return
    end
    L.MpHandlePendingDraw(gs)
end

function L.MpHandlePendingDraw(gs)
    local Rules = ArcadiaNexus.TC_Rules
    local player = gs.players[gs.currentPlayer]
    if gs.pendingDraw and gs.pendingDraw > 0 and gs.pendingType ~= "PENALTY" then
        if Rules:HasPlayableCard(player.hand, gs) then
            return
        end
        L:DrawCardsForPlayer(gs, gs.currentPlayer, gs.pendingDraw)
        gs.pendingDraw = 0
        gs.pendingType = nil
        L.MpAdvanceTurn(gs)
        return
    end
end

function L.MpAfterPlay(gs, playerIndex, played)
    local winner = L:CheckRoundWinner(gs)
    if winner then
        L:ScoreRound(gs, winner)
        gs.lastRoundWinner = winner
        gs.mpOver = true
        return
    end
    if #gs.players[playerIndex].hand == 1 and gs.rules.unoCallRule then
        gs.players[playerIndex].unoCalled = false
        gs.unoWindow = { playerIndex = playerIndex, resolved = false }
        return
    end
    L.MpAdvanceTurn(gs)
end

function L.ApplyMp(gs, intent, seat)
    if not gs or gs.mpOver then return false end
    seat = tonumber(seat) or 0
    if seat < 1 or seat > (gs.playerCount or 0) then return false end
    local kind = (intent and intent.kind) or "PLAY"
    local Rules = ArcadiaNexus.TC_Rules

    if kind == "UNO_EXPIRE" then
        if seat ~= 1 then return false end
        local uw = gs.unoWindow
        if not uw or uw.resolved then return false end
        uw.resolved = true
        if not gs.players[uw.playerIndex].unoCalled then
            gs.players[uw.playerIndex].unoCalled = true
        end
        gs.unoWindow = nil
        L.MpAdvanceTurn(gs)
        return true
    end
    if kind == "UNO" then
        local uw = gs.unoWindow
        if not uw or uw.resolved or uw.playerIndex ~= seat then return false end
        gs.players[seat].unoCalled = true
        gs.stats.unosCalled = (gs.stats.unosCalled or 0) + 1
        uw.resolved = true
        gs.unoWindow = nil
        L.MpAdvanceTurn(gs)
        return true
    end
    if kind == "CATCH" then
        local uw = gs.unoWindow
        if not uw or uw.resolved then return false end
        local target = uw.playerIndex
        if target == seat or gs.players[target].unoCalled then return false end
        gs.stats.unosMissed = (gs.stats.unosMissed or 0) + 1
        gs.stats.unosCaught = (gs.stats.unosCaught or 0) + 1
        L:DrawCardsForPlayer(gs, target, 2)
        uw.resolved = true
        gs.unoWindow = nil
        L.MpAdvanceTurn(gs)
        return true
    end
    if gs.unoWindow and not gs.unoWindow.resolved then return false end

    if kind == "COLOR" then
        local pick = gs.pendingColorPick
        if not pick or pick.playerIndex ~= seat then return false end
        local color = L.UnpackColor(intent.c)
        if not color or color == "WILD" then return false end
        Rules:ApplyCardEffect(gs, pick.card, color)
        gs.pendingColorPick = nil
        gs.currentPlayer = pick.playerIndex
        L.MpAfterPlay(gs, pick.playerIndex, pick.card)
        return true
    end
    if kind == "CHALLENGE" then
        if not gs.wild4Challengable or gs.currentPlayer ~= seat then return false end
        local wins = Rules:PlayerHadPlayableBeforeWild4(gs, gs.wild4PlayedBy)
        Rules:ResolveChallenge(gs, wins)
        gs.wild4Challengable = false
        L.MpBeginTurn(gs)
        return true
    end
    if kind == "ACCEPT" then
        if not gs.wild4Challengable or gs.currentPlayer ~= seat then return false end
        gs.wild4Challengable = false
        L.MpHandlePendingDraw(gs)
        return true
    end
    if gs.pendingColorPick then return false end
    if gs.currentPlayer ~= seat then return false end

    if kind == "PASS" then
        if not gs.drawnThisTurn then return false end
        gs.drawnThisTurn = nil
        L.MpAdvanceTurn(gs)
        return true
    end
    if kind == "DRAW" then
        if gs.hasDrawnThisTurn or gs.drawnThisTurn then return false end
        gs.hasDrawnThisTurn = true
        local drawn = L:DrawCardsForPlayer(gs, seat, 1)
        if #drawn == 0 then
            L.MpAdvanceTurn(gs)
            return true
        end
        gs.drawnThisTurn = drawn[1]
        if gs.rules.playDrawn and Rules:CanPlay(drawn[1], gs) then
            return true
        end
        gs.drawnThisTurn = nil
        L.MpAdvanceTurn(gs)
        return true
    end
    if kind == "PLAY" then
        local player = gs.players[seat]
        local idx = tonumber(intent.i)
        local card = player.hand[idx]
        if not card or not Rules:CanPlay(card, gs) then return false end
        if card.type == "WILD4" then
            gs.wild4Context = {
                playerIndex = seat,
                handSnapshot = {},
                activeColorBefore = Rules:GetActiveColor(gs),
                topCard = Rules:GetTopCard(gs),
            }
            for _, c in ipairs(player.hand) do
                gs.wild4Context.handSnapshot[#gs.wild4Context.handSnapshot + 1] = {
                    color = c.color, type = c.type, value = c.value,
                }
            end
        end
        local played = L:RemoveCardFromHand(player, idx)
        L:AddToDiscard(gs, played)
        gs.drawnThisTurn = nil
        local wildColor = L.UnpackColor(intent.c)
        if Rules:IsWildType(played) and not wildColor then
            gs.pendingColorPick = { playerIndex = seat, card = played }
            return true
        end
        Rules:ApplyCardEffect(gs, played, wildColor)
        gs.pendingColorPick = nil
        L.MpAfterPlay(gs, seat, played)
        return true
    end
    return false
end

function L.IsFinished(pub)
    return pub and (pub.over == true or tonumber(pub.o) == 1)
end

local MP_FIELDS = { "n", "t", "dir", "ac", "top", "ds", "pd", "pt", "hs", "sc",
    "ck", "dc", "uw", "uwp", "w4", "pc", "hd", "o", "w", "th", "rl" }

function L.PackPublic(pub)
    if not pub then return {} end
    local values = {}
    for i, key in ipairs(MP_FIELDS) do values[i] = tostring(pub[key] or "") end
    return { tc = table.concat(values, "/") }
end

function L.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.tc then
        local unpacked, i = {}, 1
        for value in (f.tc .. "/"):gmatch("([^/]*)/") do
            if not MP_FIELDS[i] then return end
            unpacked[MP_FIELDS[i]], i = value, i + 1
        end
        if i ~= #MP_FIELDS + 1 then return end
        f = unpacked
    end
    for _, k in ipairs({
        "n", "t", "dir", "pd", "dc", "uw", "uwp", "w4", "pc", "hd", "o", "w",
    }) do
        if f[k] ~= nil then pub[k] = tonumber(f[k]) or pub[k] end
    end
    for _, k in ipairs({ "ac", "top", "ds", "pt", "hs", "sc", "ck", "th", "rl" }) do
        if f[k] ~= nil then pub[k] = f[k] end
    end
    pub.turn = pub.t
    pub.over = tonumber(pub.o) == 1
    pub.winner = pub.w
end

function L.PackStart(pub)
    -- Initial presentation metadata only; the board follows in SNAPSHOT.
    return { n = pub.n, ck = pub.ck, th = pub.th, rl = pub.rl }
end

function L.UnpackStart(pub, f)
    L.UnpackPublic(pub, f)
end

function L.CanTryStart(node)
    if not node then return false end
    local n = 0
    local max = node.maxSeats or 4
    for i = 1, max do
        local k = node.seats and node.seats[i]
        if k and k ~= "" then
            n = n + 1
            if not (node.ready and node.ready[i]) then return false end
        end
    end
    return n >= 2 and n <= 4
end

function L.BoardStateFromMatch(pub, handStr, localSeat)
    pub = pub or L.EmptyPublic()
    localSeat = tonumber(localSeat) or 1
    local n = tonumber(pub.n) or 2
    local Npc = ArcadiaNexus.TC_NpcData
    local keys, sizes, scores = {}, {}, {}
    local i = 1
    for token in string.gmatch(tostring(pub.ck or "") .. ",", "([^,]*),") do
        keys[i] = token ~= "" and token or "thrall"
        i = i + 1
    end
    i = 1
    for token in string.gmatch(tostring(pub.hs or "") .. ",", "([^,]*),") do
        sizes[i] = tonumber(token) or 0
        i = i + 1
    end
    i = 1
    for token in string.gmatch(tostring(pub.sc or "") .. ",", "([^,]*),") do
        scores[i] = tonumber(token) or 0
        i = i + 1
    end
    local myHand = L.UnpackHand(handStr)
    local players = {}
    for s = 1, n do
        local def = Npc and Npc.GetByKey and Npc:GetByKey(keys[s] or "thrall")
        local hand
        if s == localSeat then
            hand = myHand
        else
            hand = {}
            for _ = 1, (sizes[s] or 0) do
                hand[#hand + 1] = { id = 0, color = "WILD", type = "WILD" }
            end
        end
        players[s] = {
            index = s,
            isAI = false,
            name = def and def.name or ("P" .. s),
            charKey = keys[s] or "thrall",
            charDef = def,
            hand = hand,
            handCount = sizes[s] or #hand,
            score = scores[s] or 0,
            unoCalled = false,
        }
    end
    local discard = {}
    if pub.ds and pub.ds ~= "" then
        for token in string.gmatch(pub.ds, "[^,]+") do
            local c = L.UnpackCard(token)
            if c then discard[#discard + 1] = c end
        end
    elseif pub.top and pub.top ~= "" then
        local c = L.UnpackCard(pub.top)
        if c then discard[1] = c end
    end
    local drawN = tonumber(pub.dc) or 0
    local drawPile = {}
    for _ = 1, drawN do
        drawPile[#drawPile + 1] = { id = 0, color = "WILD", type = "WILD" }
    end
    local theme = (pub.th == "a" and "alliance") or (pub.th == "h" and "horde") or "neutral"
    local rl = tostring(pub.rl or "11111")
    local rules = CopyRules({
        stackDraw2     = rl:sub(1, 1) == "1",
        stackDraw4     = rl:sub(2, 2) == "1",
        playDrawn      = rl:sub(3, 3) == "1",
        unoCallRule    = rl:sub(4, 4) == "1",
        challengeDraw4 = rl:sub(5, 5) == "1",
    })
    local ac = COL_D[pub.ac]
    local over = tonumber(pub.o) == 1
    local winner = tonumber(pub.w) or 0
    local result
    if over then
        if winner == localSeat then result = "WIN" else result = "LOSS" end
    end
    local uw, uwp = tonumber(pub.uw) == 1, tonumber(pub.uwp) or 0
    return {
        players = players,
        playerCount = n,
        currentPlayer = tonumber(pub.t) or 1,
        direction = (tonumber(pub.dir) or 1) == 0 and -1 or 1,
        activeColor = ac,
        pendingDraw = tonumber(pub.pd) or 0,
        pendingType = (pub.pt ~= "" and pub.pt) or nil,
        discardPile = discard,
        drawPile = drawPile,
        theme = theme,
        rules = rules,
        unoWindow = uw and { playerIndex = uwp, resolved = false } or nil,
        wild4Challengable = tonumber(pub.w4) == 1,
        pendingColorPick = (tonumber(pub.pc) or 0) > 0 and { playerIndex = tonumber(pub.pc) } or nil,
        hasDrawnThisTurn = tonumber(pub.hd) == 1,
        drawnThisTurn = nil,
        localSeat = localSeat,
        gameOver = over,
        result = result,
        lastRoundWinner = winner,
        mp = true,
        skipNext = 0,
        stats = {},
    }
end

function L.MatchOpts(engine)
    return {
        gameId = L.GAME_ID,
        gameProto = L.GAME_PROTO,
        maxSeats = 4,
        newPublic = L.EmptyPublic,
        seedOnStart = function()
            local n = 2
            if engine and engine.match then
                local c = 0
                for i = 1, 4 do
                    local k = engine.match.seats and engine.match.seats[i]
                    if k and k ~= "" then c = c + 1 end
                end
                if c >= 2 then n = c end
            end
            local S = ArcadiaNexus.TC_Settings
            local gs = L:NewMpGameState(
                n,
                engine and engine._mpChar or (S and S:Get("playerCharacter")) or "thrall",
                (S and S:Get("rules")) or {},
                (S and S:Get("theme")) or "neutral"
            )
            L:StartRound(gs)
            local pub = L.EmptyPublic()
            L.SyncPublic(pub, gs)
            return pub, gs
        end,
        packPublic = L.PackPublic,
        unpackPublic = L.UnpackPublic,
        packStart = L.PackStart,
        unpackStart = L.UnpackStart,
        applyIntent = function(pub, intent, seat, hid)
            if type(hid) ~= "table" or not hid.players then return false end
            local ok = L.ApplyMp(hid, intent, seat)
            if not ok then return false end
            L.SyncPublic(pub, hid)
            return true
        end,
        privateForSeat = function(seat, _, hid)
            if type(hid) ~= "table" or not hid.players or not hid.players[seat] then
                return "."
            end
            local packed = L.PackHand(hid.players[seat].hand)
            return (packed ~= "" and packed) or "."
        end,
        isFinished = L.IsFinished,
        onState = function(_, st)
            if engine then engine:OnMatchState(st) end
        end,
        onResult = function(node, resultId)
            if engine then engine:OnMatchResult(node, resultId) end
        end,
        onReject = function(_, f)
            if engine then engine:OnMatchReject(f) end
        end,
        onPublic = function()
            if engine then engine:OnMatchPublic() end
        end,
        canTryStart = function(node)
            return L.CanTryStart(node)
        end,
    }
end
