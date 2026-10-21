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
    gs.stats=gs.stats or {}; gs.stats.bySeat=gs.stats.bySeat or {}
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
    gs.roundOver=false; gs.mpOver=false; gs.closingWinner=nil; gs.lastRoundWinner=nil

    for _, p in ipairs(gs.players) do
        p.hand = {}
        p.unoCalled = false
        for _ = 1, 7 do
            p.hand[#p.hand + 1] = Deck:Draw(gs.drawPile)
        end
        gs.stats.cardsDrawnAtRoundStart[p.index] = #p.hand
    end

    local starter, rejected = nil, {}
    repeat
        starter = Deck:Draw(gs.drawPile)
        if starter and Rules:IsWildType(starter) then rejected[#rejected+1]=starter end
    until starter and not Rules:IsWildType(starter)
    for _,card in ipairs(rejected) do gs.drawPile[#gs.drawPile+1]=card end
    if #rejected>0 then Deck:Shuffle(gs.drawPile) end
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

function L:CloneGameState(value)
    if type(value)~="table" then return value end
    local copy={}; for key,item in pairs(value) do copy[key]=self:CloneGameState(item) end
    return copy
end

-- ============================================================
-- Match v2: 2–4 Menschen, eine Runde. Stapel nur Host.
-- Private = eigene Hand. Intents: PLAY/COLOR/DRAW/PASS/UNO/CATCH/CHALLENGE/ACCEPT/UNO_EXPIRE
-- ============================================================

L.GAME_ID = "TAVERNCARDS"
L.GAME_PROTO = 2

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
    s=tostring(s or ""):match("^[^~]*")
    local hand = {}
    if type(s) ~= "string" or s == "" or s == "." then return hand end
    for token in string.gmatch(s, "[^,]+") do
        local c = L.UnpackCard(token)
        if c then c.id=#hand+1; hand[#hand + 1] = c end
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
        isMatch = true,
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
    pub.cl=gs.closingWinner or 0
    local own={}
    for seat=1,gs.playerCount do local st=L:PersonalStats(gs,seat); own[seat]=(st.unosCalled or 0)..":"..(st.wild4Played or 0) end
    pub.ev=table.concat(own,",")
    pub.o = gs.mpOver and 1 or 0
    pub.over = gs.mpOver and true or false
    pub.w = gs.lastRoundWinner or 0
    pub.winner = pub.w
end

-- Shared phase machine for solo and host-authoritative MATCH.
local function Count(gs,seat,key)
    gs.stats=gs.stats or {}; gs.stats.bySeat=gs.stats.bySeat or {}
    local own=gs.stats.bySeat[seat] or {}; gs.stats.bySeat[seat]=own
    own[key]=(own[key] or 0)+1
    if seat==1 then gs.stats[key]=(gs.stats[key] or 0)+1 end
end
function L:PersonalStats(gs,seat)
    return self:CloneGameState(gs.stats and gs.stats.bySeat and gs.stats.bySeat[seat] or {})
end
function L:CanPlayIndex(gs,seat,index)
    if not gs or gs.roundOver or gs.pendingColorPick or gs.unoWindow or gs.currentPlayer~=seat or gs.closingWinner then return false end
    local p=gs.players[seat]; local card=p and p.hand[index]
    if not card or gs.drawnThisTurn and gs.drawnThisTurn.id~=card.id then return false end
    if gs.wild4Challengable and (card.type~="WILD4" or not gs.rules.stackDraw4) then return false end
    return ArcadiaNexus.TC_Rules:CanPlay(card,gs)
end
function L:Phase(gs)
    if gs.roundOver then return "ROUND_END" end
    if gs.pendingColorPick then return "COLOR" end
    if gs.unoWindow then return "UNO" end
    if gs.wild4Challengable then return "CHALLENGE" end
    if (gs.pendingDraw or 0)>0 then return "PENALTY" end
    if gs.drawnThisTurn then return "DRAWN" end
    return "TURN"
end
local function Complete(gs)
    local winner=L:CheckRoundWinner(gs)
    if not winner or (gs.pendingDraw or 0)>0 or gs.pendingColorPick or gs.unoWindow or gs.wild4Challengable then return false end
    gs.lastRoundPoints=L:ScoreRound(gs,winner); gs.lastRoundWinner=winner
    gs.roundOver=true; gs.mpOver=gs.isMatch==true; gs.closingWinner=nil
    return true
end
local function ClearPenalty(gs)
    gs.pendingDraw=0; gs.pendingType=nil; gs.wild4Challengable=false; gs.wild4Context=nil
end
local Advance, BeginTurn
Advance=function(gs)
    gs.turnNotice=nil; gs.drawnThisTurn=nil; gs.hasDrawnThisTurn=false
    local Rules=ArcadiaNexus.TC_Rules; local steps=1+(gs.skipNext or 0); gs.skipNext=0
    gs.currentPlayer=Rules:NextPlayerIndex(gs,steps); BeginTurn(gs)
end
local function TakePenalty(gs)
    L:DrawCardsForPlayer(gs,gs.currentPlayer,gs.pendingDraw); ClearPenalty(gs)
    if not Complete(gs) then Advance(gs) end
end
BeginTurn=function(gs)
    if Complete(gs) or gs.wild4Challengable then return end
    if (gs.pendingDraw or 0)>0 then
        local canStack=false
        if not gs.closingWinner then
            for i in ipairs(gs.players[gs.currentPlayer].hand) do if L:CanPlayIndex(gs,gs.currentPlayer,i) then canStack=true; break end end
        end
        if not canStack then TakePenalty(gs) end
    end
end
function L.AfterPlay(gs,seat,card)
    local p=gs.players[seat]
    if #p.hand==0 then
        if (gs.pendingDraw or 0)>0 then gs.closingWinner=seat; Advance(gs) else Complete(gs) end
    elseif #p.hand==1 and gs.rules.unoCallRule then
        p.unoCalled=false; gs.unoWindow={playerIndex=seat,resolved=false,remainingMs=3000}
    else Advance(gs) end
end
L.MpAdvanceTurn=Advance; L.MpBeginTurn=BeginTurn; L.MpHandlePendingDraw=BeginTurn; L.MpAfterPlay=L.AfterPlay
function L.ApplyAction(gs,intent,seat)
    if not gs or gs.roundOver or gs.mpOver then return false end
    if type(seat)~="number" or seat~=math.floor(seat) or seat<1 or seat>gs.playerCount then return false end
    local kind=intent and intent.kind or "PLAY"; local Rules=ArcadiaNexus.TC_Rules
    local uw=gs.unoWindow
    if uw then
        if kind=="UNO" and seat==uw.playerIndex then gs.players[seat].unoCalled=true; Count(gs,seat,"unosCalled")
        elseif kind=="CATCH" and seat~=uw.playerIndex and not gs.players[uw.playerIndex].unoCalled then
            Count(gs,uw.playerIndex,"unosMissed"); Count(gs,seat,"unosCaught"); L:DrawCardsForPlayer(gs,uw.playerIndex,2)
        elseif kind=="UNO_EXPIRE" and seat==1 then gs.players[uw.playerIndex].unoCalled=true
        else return false end
        gs.unoWindow=nil; Advance(gs); return true
    end
    if gs.pendingColorPick then
        local pick=gs.pendingColorPick; local color=L.UnpackColor(intent.c)
        if kind~="COLOR" or seat~=pick.playerIndex or not color or color=="WILD" then return false end
        gs.pendingColorPick=nil; Rules:ApplyCardEffect(gs,pick.card,color); L.AfterPlay(gs,seat,pick.card); return true
    end
    if gs.currentPlayer~=seat then return false end
    if gs.wild4Challengable then
        if kind=="CHALLENGE" then
            local wins=Rules:PlayerHadPlayableBeforeWild4(gs,gs.wild4PlayedBy)
            local previous=math.max(0,(gs.pendingDraw or 4)-4); local dealer=gs.wild4PlayedBy
            gs.lastChallengeSucceeded=wins
            if wins then
                L:DrawCardsForPlayer(gs,dealer,4); gs.closingWinner=nil
                gs.pendingDraw=previous; gs.pendingType=previous>0 and "WILD4" or nil
                gs.wild4Challengable=false; gs.wild4Context=nil; BeginTurn(gs)
            else
                L:DrawCardsForPlayer(gs,seat,(gs.pendingDraw or 4)+2); ClearPenalty(gs)
                if not Complete(gs) then Advance(gs) end
            end
            return true
        elseif kind=="ACCEPT" or kind=="DRAW" then TakePenalty(gs); return true
        elseif kind~="PLAY" then return false end
    end
    if kind=="PASS" then
        if not gs.drawnThisTurn then return false end
        Advance(gs); return true
    elseif kind=="DRAW" then
        if gs.drawnThisTurn or gs.hasDrawnThisTurn then return false end
        if (gs.pendingDraw or 0)>0 then TakePenalty(gs); return true end
        gs.hasDrawnThisTurn=true
        local drawn=L:DrawCardsForPlayer(gs,seat,1); gs.drawnThisTurn=drawn[1]
        if drawn[1] and gs.rules.playDrawn and Rules:CanPlay(drawn[1],gs) then return true end
        Advance(gs); return true
    elseif kind=="PLAY" then
        local index=tonumber(intent.i)
        if not index or index~=math.floor(index) or not L:CanPlayIndex(gs,seat,index) then return false end
        local color=intent.c and L.UnpackColor(intent.c)
        if intent.c and (not color or color=="WILD") then return false end
        local p=gs.players[seat]; local card=p.hand[index]
        if card.type=="WILD4" then
            gs.wild4Context={playerIndex=seat,activeColorBefore=Rules:GetActiveColor(gs),handSnapshot=L:CloneGameState(p.hand)}
            Count(gs,seat,"wild4Played")
        end
        gs.wild4Challengable=false
        local played=L:RemoveCardFromHand(p,index); L:AddToDiscard(gs,played)
        gs.drawnThisTurn=nil; gs.hasDrawnThisTurn=false
        if Rules:IsWildType(played) and not color then gs.pendingColorPick={playerIndex=seat,card=played}; return true end
        Rules:ApplyCardEffect(gs,played,color); L.AfterPlay(gs,seat,played); return true
    end
    return false
end
L.ApplyMp=L.ApplyAction

function L.IsFinished(pub)
    return pub and (pub.over == true or tonumber(pub.o) == 1)
end

local MP_FIELDS = { "n", "t", "dir", "ac", "top", "ds", "pd", "pt", "hs", "sc",
    "ck", "dc", "uw", "uwp", "w4", "pc", "hd", "o", "w", "th", "rl", "cl", "ev" }

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
        "n", "t", "dir", "pd", "dc", "uw", "uwp", "w4", "pc", "hd", "o", "w", "cl",
    }) do
        if f[k] ~= nil then pub[k] = tonumber(f[k]) or pub[k] end
    end
    for _, k in ipairs({ "ac", "top", "ds", "pt", "hs", "sc", "ck", "th", "rl", "ev" }) do
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
    local packed, drawnId=tostring(handStr or "."):match("^(.-)~(%d+)$")
    local myHand=L.UnpackHand(packed or handStr)
    local drawn; for _,card in ipairs(myHand) do if card.id==tonumber(drawnId) then drawn=card; break end end
    local personal={}; local eventSeat=1
    for u,w in tostring(pub.ev or ""):gmatch("(%d+):(%d+)") do
        if eventSeat==localSeat then personal={unosCalled=tonumber(u),wild4Played=tonumber(w)} end
        eventSeat=eventSeat+1
    end
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
        drawnThisTurn = drawn,
        closingWinner = tonumber(pub.cl)~=0 and tonumber(pub.cl) or nil,
        roundOver = over,
        localSeat = localSeat,
        gameOver = over,
        result = result,
        lastRoundWinner = winner,
        mp = true,
        skipNext = 0,
        stats = personal,
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
            local drawnIndex=0
            if hid.currentPlayer==seat and hid.drawnThisTurn then
                for index,card in ipairs(hid.players[seat].hand) do if card.id==hid.drawnThisTurn.id then drawnIndex=index; break end end
            end
            return ((packed ~= "" and packed) or ".") .. "~" .. tostring(drawnIndex)
        end,
        isFinished = L.IsFinished,
        onState = function(_, st)
            if engine then engine:OnMatchState(st) end
        end,
        onResult = function(node, resultId)
            if engine then return engine:OnMatchResult(node, resultId) end
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

function L:IsDifficulty(value) return value=="easy" or value=="normal" or value=="hard" end
local function Int(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=2147483647 end
function L:ValidateSave(gs)
    if type(gs)~="table" or gs.saveVersion~=2 or gs.isMatch or not self:IsDifficulty(gs.difficulty)
        or not Int(gs.aiCount) or gs.aiCount<1 or gs.aiCount>3 or gs.playerCount~=gs.aiCount+1
        or (gs.gameMode~="single" and gs.gameMode~="multi") or not Int(gs.pointTarget) or gs.pointTarget<1
        or type(gs.runId)~="string" or type(gs.players)~="table" or #gs.players~=gs.playerCount
        or not Int(gs.roundNumber) or not Int(gs.roundsPlayed) or not Int(gs.currentPlayer) or gs.currentPlayer<1 or gs.currentPlayer>gs.playerCount
        or type(gs.rules)~="table" then return false end
    for _,key in ipairs({"stackDraw2","stackDraw4","playDrawn","unoCallRule","challengeDraw4"}) do if type(gs.rules[key])~="boolean" then return false end end
    if gs.direction~=1 and gs.direction~=-1 or not Int(gs.pendingDraw) or not Int(gs.skipNext) then return false end
    if gs.pendingDraw>0 and gs.pendingType~="DRAW2" and gs.pendingType~="WILD4" then return false end
    local seen,total={},0; local deck=ArcadiaNexus.TC_Deck:BuildDeck()
    local function Cards(pile)
        if type(pile)~="table" then return false end
        for _,c in ipairs(pile) do
            local expected=type(c)=="table" and deck[c.id]
            if not expected or seen[c.id] or expected.color~=c.color or expected.type~=c.type or expected.value~=c.value or expected.points~=c.points then return false end
            seen[c.id]=true; total=total+1
        end; return true
    end
    if not Cards(gs.drawPile) or not Cards(gs.discardPile) or #gs.discardPile==0 then return false end
    for seat,p in ipairs(gs.players) do if type(p)~="table" or p.index~=seat or not Int(p.score) or not Cards(p.hand) then return false end end
    if total~=108 then return false end
    local top=gs.discardPile[#gs.discardPile]
    if gs.pendingColorPick and (type(gs.pendingColorPick)~="table" or type(gs.pendingColorPick.card)~="table"
        or gs.pendingColorPick.card.id~=top.id or (top.type~="WILD" and top.type~="WILD4")
        or gs.pendingColorPick.playerIndex~=gs.currentPlayer) then return false end
    if gs.drawnThisTurn then
        if type(gs.drawnThisTurn)~="table" or not gs.hasDrawnThisTurn or gs.pendingColorPick or gs.unoWindow or gs.pendingDraw>0 then return false end
        local found=false; for _,c in ipairs(gs.players[gs.currentPlayer].hand) do if c.id==gs.drawnThisTurn.id then found=true end end
        if not found then return false end
    elseif gs.hasDrawnThisTurn then return false end
    if gs.closingWinner and (not Int(gs.closingWinner) or not gs.players[gs.closingWinner] or #gs.players[gs.closingWinner].hand~=0 or gs.pendingDraw<=0) then return false end
    if type(gs.stats)~="table" or type(gs.stats.bySeat)~="table" then return false end
    for seat,st in pairs(gs.stats.bySeat) do
        if not Int(seat) or not gs.players[seat] or type(st)~="table" then return false end
        for _,key in ipairs({"unosCalled","unosMissed","unosCaught","wild4Played"}) do if st[key]~=nil and not Int(st[key]) then return false end end
    end
    if gs.wild4Challengable then
        local ctx=gs.wild4Context
        if type(ctx)~="table" or not gs.players[ctx.playerIndex] or type(ctx.handSnapshot)~="table"
            or not ctx.activeColorBefore or gs.pendingDraw<4 or gs.pendingType~="WILD4" then return false end
    end
    if gs.unoWindow and (type(gs.unoWindow)~="table" or not Int(gs.unoWindow.remainingMs) or gs.unoWindow.remainingMs>3000 or not gs.players[gs.unoWindow.playerIndex]) then return false end
    if gs.phase~="PLAYING" and gs.phase~="ROUND_END" and gs.phase~="RESULT_PENDING" and gs.phase~="FINISHED" then return false end
    if gs.phase=="ROUND_END" and not gs.roundOver then return false end
    if (gs.phase=="RESULT_PENDING" or gs.phase=="FINISHED") and gs.result~="WIN" and gs.result~="LOSS" then return false end
    return true
end
function L:MigrateSave(old)
    if type(old)~="table" then return nil end
    local gs=self:CloneGameState(old)
    if gs.saveVersion==2 then return self:ValidateSave(gs) and gs or nil end
    -- A pre-deal pause contains no cards; finish that original first deal before exposing the save.
    if (gs.roundNumber or 0)==0 and gs.players and #(gs.players[1].hand or {})==0 then self:StartRound(gs) end
    if gs.wild4Challengable and not gs.wild4Context then return nil end -- preserve the original instead of inventing hidden facts
    local top=gs.discardPile and gs.discardPile[#gs.discardPile]
    -- The old clone removed pendingColorPick entirely: a wild top cannot prove whether
    -- its color was already chosen. Keep this ambiguous legacy state rather than skipping a choice.
    if top and ArcadiaNexus.TC_Rules:IsWildType(top) and not gs.pendingColorPick then return nil end
    local active=gs.players and gs.players[gs.currentPlayer]
    if gs.rules and gs.rules.unoCallRule and active and #active.hand==1 and gs.lastPlayedBy==gs.currentPlayer
        and not active.unoCalled and not gs.unoWindow then return nil end

    -- Old StartRound discarded rejected wild starters. Restore only their canonical missing IDs,
    -- at the bottom of the pile, preserving all known hands, scores and draw order.
    local known={}
    for _,pile in ipairs({gs.drawPile,gs.discardPile}) do for _,card in ipairs(pile or {}) do known[card.id]=true end end
    for _,player in ipairs(gs.players or {}) do for _,card in ipairs(player.hand or {}) do known[card.id]=true end end
    for _,card in ipairs(ArcadiaNexus.TC_Deck:BuildDeck()) do
        if not known[card.id] and (card.type=="WILD" or card.type=="WILD4") then gs.drawPile[#gs.drawPile+1]=card end
    end
    if gs.hasDrawnThisTurn and not gs.drawnThisTurn then
        local hand=gs.players[gs.currentPlayer].hand
        local drawn=hand[#hand]
        if not drawn or not gs.rules.playDrawn or not ArcadiaNexus.TC_Rules:CanPlay(drawn,gs) then return nil end
        gs.drawnThisTurn=self:CloneGameState(drawn)
    end
    gs.saveVersion=2; gs.phase=gs.roundOver and "ROUND_END" or "PLAYING"
    gs.runId="migration-validation"
    gs.legacyActionStats=self:CloneGameState(gs.stats); gs.stats=gs.stats or {}; gs.stats.bySeat={}
    gs.stats.unosCalled=0; gs.stats.wild4Played=0
    if gs.unoWindow then gs.unoWindow.remainingMs=3000 end
    if not self:ValidateSave(gs) then return nil end
    gs.runId=ArcadiaNexus.LocalResults:NewRun("TAVERNCARDS")
    return gs
end
