--[[
    Games/ArcadiaPairs/Logic.lua

    Icon-Namen ohne Präfix; der Renderer hängt "Interface\\Icons\\" davor.
    Jedes Deck: 32 Unikate für Hard.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Logic = {}
local Logic = ArcadiaNexus.AP_Logic

local CONFIGS = {
    easy   = { grid = 4, pairs = 8,  timerSec = 120 },
    normal = { grid = 6, pairs = 18, timerSec = 180 },
    hard   = { grid = 8, pairs = 32, timerSec = 300 },
}

-- Nur der Icon-Name ohne Präfix wird gespeichert.
-- Im Renderer wird "Interface\\Icons\\" vorgehängt.
-- Jedes Deck braucht 32 Unikate (Hard). Namen: Retail-Pfade, die als Datei existieren.
local DECKS = {
    classes = {
        name = "Klassentreffen",
        icons = {
            "ClassIcon_Warrior",
            "ClassIcon_Paladin",
            "ClassIcon_Hunter",
            "ClassIcon_Rogue",
            "ClassIcon_Priest",
            "ClassIcon_DeathKnight",
            "ClassIcon_Shaman",
            "ClassIcon_Mage",
            "ClassIcon_Warlock",
            "ClassIcon_Monk",
            "ClassIcon_Druid",
            "ClassIcon_DemonHunter",
            "ClassIcon_Evoker",
            "Ability_Warrior_Charge",
            "Spell_Holy_SealOfMight",
            "Ability_Hunter_AimedShot",
            "Ability_Stealth",
            "Spell_Holy_Heal",
            "Spell_Shadow_DeathAndDecay",
            "Spell_Nature_Lightning",
            "Spell_Fire_FlameBolt",
            "Spell_Shadow_DeathCoil",
            "Ability_Monk_TigerPalm",
            "Ability_Druid_CatForm",
            "Ability_DemonHunter_FelRush",
            "Ability_Evoker_LivingFlame",
            "Spell_Frost_FrostBolt02",
            "Spell_Holy_PowerWordShield",
            "Ability_Warrior_BattleShout",
            "Spell_Nature_StarFall",
            "Spell_Arcane_Blink",
            "Ability_Hunter_BeastTaming",
        },
    },
    items = {
        name = "Beute-Bucht",
        icons = {
            "INV_Potion_54",
            "INV_Potion_81",
            "INV_Potion_76",
            "INV_Drink_05",
            "INV_Misc_Food_19",
            "INV_Misc_Food_32",
            "INV_Scroll_08",
            "INV_Misc_Rune_01",
            "INV_Misc_Key_04",
            "INV_Misc_Book_09",
            "INV_Misc_Bag_08",
            "INV_Pick_02",
            "Trade_Engineering",
            "Trade_Blacksmithing",
            "Trade_Alchemy",
            "Trade_Tailoring",
            "INV_Misc_MonsterClaw_04",
            "INV_Misc_MonsterFang_01",
            "INV_Misc_Bone_HumanSkull_01",
            "INV_Misc_MonsterTail_03",
            "INV_Misc_Pelt_Wolf_01",
            "INV_Misc_Horn_01",
            "INV_Sword_39",
            "INV_Axe_09",
            "INV_Hammer_05",
            "INV_Staff_13",
            "INV_Shield_06",
            "INV_Helmet_74",
            "INV_Chest_Plate06",
            "INV_Gauntlets_04",
            "INV_Misc_Gem_Sapphire_02",
            "INV_Misc_Gem_Ruby_02",
        },
    },
    mounts = {
        name = "Reise durch Azeroth",
        icons = {
            "Ability_Mount_RidingHorse",
            "Ability_Mount_WhiteTiger",
            "Ability_Mount_BlackPanther",
            "Ability_Mount_JungleTiger",
            "Ability_Mount_Raptor",
            "Ability_Mount_Kodo_01",
            "Ability_Mount_Kodo_03",
            "Ability_Mount_WhiteDireWolf",
            "Ability_Mount_BlackDireWolf",
            "Ability_Mount_NightmareHorse",
            "Ability_Mount_Undeadhorse",
            "Ability_Mount_MechaStrider",
            "Ability_Mount_MountainRam",
            "Ability_Mount_RidingElekk",
            "Ability_Mount_Cockatricemount",
            "Ability_Mount_GriffonMount",
            "Ability_Mount_Wyvern_01",
            "Ability_Mount_WarHippogryph",
            "Ability_Mount_Drake_Proto",
            "Ability_Mount_Drake_Blue",
            "Ability_Mount_FlyingCarpet",
            "Spell_Arcane_PortalStormWind",
            "Spell_Arcane_PortalOrgrimmar",
            "Spell_Arcane_PortalDarnassus",
            "Spell_Arcane_PortalIronForge",
            "Spell_Arcane_PortalShattrath",
            "INV_Misc_Map_01",
            "Spell_Nature_AstralRecal",
            "Ability_Druid_TravelForm",
            "Ability_Druid_FlightForm",
            "Spell_Nature_Swiftness",
            "Ability_Hunter_Pathfinding",
        },
    },
}

local function shuffle(t)
    return ArcadiaNexus.ArrayUtils.Shuffle(t)
end

function Logic:NewGame(config)
    local difficulty  = config.difficulty  or "easy"
    local theme       = config.theme       or "classes"
    local timerActive = config.timerActive or false
    local cfg         = CONFIGS[difficulty] or CONFIGS.easy
    local deck        = DECKS[theme]        or DECKS.classes
    local pairs       = cfg.pairs
    local gridSize    = cfg.grid

    local iconPool = {}
    for _, icon in ipairs(deck.icons) do iconPool[#iconPool+1] = icon end
    shuffle(iconPool)

    local cards = {}
    for i = 1, pairs do
        local icon = iconPool[i] or iconPool[((i-1) % #iconPool) + 1]
        cards[#cards+1] = { pairID = i, icon = icon }
        cards[#cards+1] = { pairID = i, icon = icon }
    end
    shuffle(cards)

    local board = {
        cards        = {},
        grid         = gridSize,
        totalCards   = gridSize * gridSize,
        pairs        = pairs,
        matchedPairs = 0,
        moves        = 0,
        flippedIdx   = {},
        phase        = "PLAYING",
        difficulty   = difficulty,
        theme        = theme,
        themeName    = deck.name,
        timerActive  = timerActive,
        timerLeft    = timerActive and cfg.timerSec or nil,
        blocked      = false,
    }
    for i, card in ipairs(cards) do
        board.cards[i] = { pairID = card.pairID, icon = card.icon, state = "HIDDEN" }
    end
    return board
end

function Logic:FlipCard(board, idx)
    if board.phase ~= "PLAYING" then return "game_over" end
    if board.blocked            then return "blocked"    end
    local card = board.cards[idx]
    if not card                   then return "invalid"         end
    if card.state == "MATCHED"    then return "matched"         end
    if card.state == "FLIPPED"    then return "already_flipped" end
    if #board.flippedIdx >= 2     then return "blocked"         end
    card.state = "FLIPPED"
    board.flippedIdx[#board.flippedIdx+1] = idx
    return "flipped"
end

function Logic:CheckMatch(board)
    if #board.flippedIdx ~= 2 then return nil end
    local i1, i2 = board.flippedIdx[1], board.flippedIdx[2]
    local c1, c2 = board.cards[i1], board.cards[i2]
    board.moves = board.moves + 1
    if c1.pairID == c2.pairID then
        c1.state = "MATCHED"
        c2.state = "MATCHED"
        board.flippedIdx   = {}
        board.matchedPairs = board.matchedPairs + 1
        if board.matchedPairs >= board.pairs then board.phase = "WON" end
        return "match"
    else
        return "no_match"
    end
end

function Logic:ResetFlipped(board)
    for _, idx in ipairs(board.flippedIdx) do
        if board.cards[idx] and board.cards[idx].state == "FLIPPED" then
            board.cards[idx].state = "HIDDEN"
        end
    end
    board.flippedIdx = {}
    board.blocked    = false
end

function Logic:TickTimer(board, dt)
    if not board.timerActive or board.phase ~= "PLAYING" then return "ok" end
    board.timerLeft = board.timerLeft - dt
    if board.timerLeft <= 0 then
        board.timerLeft = 0
        board.phase     = "LOST"
        return "expired"
    end
    return "ok"
end

function Logic:GetBoardState(board)
    local cardsCopy   = {}
    local flippedCopy = {}
    for i, c in ipairs(board.cards) do
        cardsCopy[i] = { pairID = c.pairID, icon = c.icon, state = c.state }
    end
    for i, v in ipairs(board.flippedIdx) do flippedCopy[i] = v end
    return {
        cards        = cardsCopy,
        grid         = board.grid,
        totalCards   = board.totalCards,
        pairs        = board.pairs,
        matchedPairs = board.matchedPairs,
        moves        = board.moves,
        flippedIdx   = flippedCopy,
        phase        = board.phase,
        difficulty   = board.difficulty,
        theme        = board.theme,
        themeName    = board.themeName,
        timerActive  = board.timerActive,
        timerLeft    = board.timerLeft,
        blocked      = board.blocked,
        gameOver     = board.phase == "WON" or board.phase == "LOST",
    }
end

function Logic:GetDeckList()
    return {
        { key = "classes", name = DECKS.classes.name },
        { key = "items",   name = DECKS.items.name   },
        { key = "mounts",  name = DECKS.mounts.name  },
    }
end

function Logic:GetDeckIcons(theme)
    local deck = DECKS[theme] or DECKS.classes
    return deck.icons
end

-- ============================================================
-- Match: Duell 2 Sitze, 4×4. Layout nur beim Host (_hostHidden).
-- Public: Zustände + sichtbare Icon-Indizes, keine pairID.
-- Intent FLIP i=Kartenindex; Host sendet RESOLVE nach 0,8s.
-- ============================================================

Logic.GAME_ID = "ARCADIAPAIRS"
Logic.GAME_PROTO = 1
Logic.MP_GRID = 4
Logic.MP_N = 16

local THEME_CODE = { classes = "c", items = "i", mounts = "m" }
local THEME_FROM = { c = "classes", i = "items", m = "mounts" }

local function Enc(n)
    n = tonumber(n) or 0
    if n < 1 then return "0" end
    if n <= 9 then return tostring(n) end
    return string.char(87 + n)
end

local function Dec(ch)
    if not ch or ch == "" or ch == "0" then return 0 end
    local b = ch:byte()
    if b >= 49 and b <= 57 then return b - 48 end
    if b >= 97 and b <= 122 then return b - 87 end
    return 0
end

local function SetChar(s, i, ch)
    return s:sub(1, i - 1) .. ch .. s:sub(i + 1)
end

function Logic.IconIndex(theme, icon)
    local deck = DECKS[theme] or DECKS.classes
    for i, name in ipairs(deck.icons) do
        if name == icon then return i end
    end
    return 1
end

function Logic.IconName(theme, idx)
    local deck = DECKS[theme] or DECKS.classes
    return deck.icons[idx] or deck.icons[1]
end

function Logic.EmptyPublic()
    local n = Logic.MP_N
    return {
        g = Logic.MP_GRID,
        th = "c",
        st = string.rep("H", n),
        ic = string.rep("0", n),
        x = 0,
        y = 0,
        t = 1,
        s1 = 0,
        s2 = 0,
        mv = 0,
        bl = 0,
        o = 0,
        w = 0,
        over = false,
        winner = 0,
        turn = 1,
        blocked = false,
    }
end

function Logic.DealMp(theme)
    theme = theme or "classes"
    local board = Logic:NewGame({
        difficulty = "easy",
        theme = theme,
        timerActive = false,
    })
    local n = board.totalCards
    local p, ic = {}, {}
    for i = 1, n do
        p[i] = Enc(board.cards[i].pairID)
        ic[i] = Enc(Logic.IconIndex(theme, board.cards[i].icon))
    end
    local pub = Logic.EmptyPublic()
    pub.th = THEME_CODE[theme] or "c"
    pub.g = board.grid
    pub.st = string.rep("H", n)
    pub.ic = string.rep("0", n)
    local hid = { p = table.concat(p), ic = table.concat(ic) }
    return pub, hid
end

function Logic.ResolveMatch(pub, hid)
    if not pub or not hid or type(hid.p) ~= "string" then return false end
    local x, y = tonumber(pub.x) or 0, tonumber(pub.y) or 0
    if x < 1 or y < 1 then return false end
    local p1, p2 = Dec(hid.p:sub(x, x)), Dec(hid.p:sub(y, y))
    if p1 < 1 or p2 < 1 then return false end
    pub.mv = (tonumber(pub.mv) or 0) + 1
    local turn = tonumber(pub.t) or 1
    if p1 == p2 then
        pub.st = SetChar(pub.st, x, "M")
        pub.st = SetChar(pub.st, y, "M")
        if turn == 1 then
            pub.s1 = (tonumber(pub.s1) or 0) + 1
        else
            pub.s2 = (tonumber(pub.s2) or 0) + 1
        end
        local matched = (tonumber(pub.s1) or 0) + (tonumber(pub.s2) or 0)
        if matched >= 8 then
            pub.over = true
            pub.o = 1
            local a, b = tonumber(pub.s1) or 0, tonumber(pub.s2) or 0
            if a > b then pub.w = 1
            elseif b > a then pub.w = 2
            else pub.w = 0 end
            pub.winner = pub.w
        end
    else
        pub.st = SetChar(pub.st, x, "H")
        pub.st = SetChar(pub.st, y, "H")
        pub.ic = SetChar(pub.ic, x, "0")
        pub.ic = SetChar(pub.ic, y, "0")
        pub.t = (turn == 1) and 2 or 1
        pub.turn = pub.t
    end
    pub.x, pub.y = 0, 0
    pub.bl = 0
    pub.blocked = false
    return true
end

function Logic.ApplyMatch(pub, intent, seat, hid)
    if not pub or pub.over or tonumber(pub.o) == 1 then return false end
    seat = tonumber(seat) or 0
    local kind = (intent and intent.kind) or "FLIP"
    if kind == "RESOLVE" then
        if seat ~= 1 then return false end
        if tonumber(pub.bl) ~= 1 then return false end
        return Logic.ResolveMatch(pub, hid)
    end
    if seat ~= 1 and seat ~= 2 then return false end
    if tonumber(pub.bl) == 1 then return false end
    if seat ~= (tonumber(pub.t) or 1) then return false end
    local idx = tonumber(intent and intent.i)
    local n = Logic.MP_N
    if not idx or idx < 1 or idx > n then return false end
    if (pub.st or ""):sub(idx, idx) ~= "H" then return false end
    if not hid or type(hid.ic) ~= "string" then return false end
    local ich = hid.ic:sub(idx, idx)
    if ich == "" or ich == "0" then return false end
    pub.st = SetChar(pub.st, idx, "F")
    pub.ic = SetChar(pub.ic, idx, ich)
    local x, y = tonumber(pub.x) or 0, tonumber(pub.y) or 0
    if x < 1 then
        pub.x = idx
    elseif y < 1 then
        pub.y = idx
        pub.bl = 1
        pub.blocked = true
    else
        return false
    end
    return true
end

function Logic.IsFinished(pub)
    return pub and (pub.over == true or tonumber(pub.o) == 1)
end

function Logic.PackPublic(pub)
    if not pub then return {} end
    return {
        g = pub.g or Logic.MP_GRID,
        th = pub.th or "c",
        st = pub.st,
        ic = pub.ic,
        x = pub.x or 0,
        y = pub.y or 0,
        t = pub.t or pub.turn or 1,
        s1 = pub.s1 or 0,
        s2 = pub.s2 or 0,
        mv = pub.mv or 0,
        bl = (pub.blocked or tonumber(pub.bl) == 1) and 1 or 0,
        o = (pub.over or tonumber(pub.o) == 1) and 1 or 0,
        w = pub.winner or pub.w or 0,
    }
end

function Logic.UnpackPublic(pub, f)
    if not pub or not f then return end
    if f.g ~= nil then pub.g = tonumber(f.g) or pub.g end
    if f.th ~= nil and f.th ~= "" then pub.th = f.th end
    if f.st ~= nil and f.st ~= "" then pub.st = f.st end
    if f.ic ~= nil and f.ic ~= "" then pub.ic = f.ic end
    if f.x ~= nil then pub.x = tonumber(f.x) or 0 end
    if f.y ~= nil then pub.y = tonumber(f.y) or 0 end
    if f.t ~= nil then
        pub.t = tonumber(f.t) or pub.t
        pub.turn = pub.t
    end
    if f.s1 ~= nil then pub.s1 = tonumber(f.s1) or 0 end
    if f.s2 ~= nil then pub.s2 = tonumber(f.s2) or 0 end
    if f.mv ~= nil then pub.mv = tonumber(f.mv) or 0 end
    if f.bl ~= nil then
        pub.bl = tonumber(f.bl) or 0
        pub.blocked = pub.bl == 1
    end
    if f.o ~= nil then
        pub.o = tonumber(f.o) or 0
        pub.over = pub.o == 1
    end
    if f.w ~= nil then
        pub.w = tonumber(f.w) or 0
        pub.winner = pub.w
    end
end

function Logic.PackStart(pub)
    return Logic.PackPublic(pub)
end

function Logic.UnpackStart(pub, f)
    Logic.UnpackPublic(pub, f)
end

function Logic.CanTryStart(node)
    if not node then return false end
    local n = 0
    for i = 1, (node.maxSeats or 2) do
        local k = node.seats and node.seats[i]
        if k and k ~= "" then
            n = n + 1
            if not (node.ready and node.ready[i]) then return false end
        end
    end
    return n == 2
end

function Logic.BoardStateFromPublic(pub, localSeat)
    pub = pub or Logic.EmptyPublic()
    local theme = THEME_FROM[pub.th] or "classes"
    local grid = tonumber(pub.g) or Logic.MP_GRID
    local n = grid * grid
    local st, ic = pub.st or "", pub.ic or ""
    local cards = {}
    local flippedIdx = {}
    local map = { H = "HIDDEN", F = "FLIPPED", M = "MATCHED" }
    for i = 1, n do
        local ch = st:sub(i, i)
        if ch == "" then ch = "H" end
        local state = map[ch] or "HIDDEN"
        local icon
        if state ~= "HIDDEN" then
            local idx = Dec(ic:sub(i, i))
            if idx > 0 then icon = Logic.IconName(theme, idx) end
        end
        cards[i] = { state = state, icon = icon }
        if state == "FLIPPED" then
            flippedIdx[#flippedIdx + 1] = i
        end
    end
    localSeat = tonumber(localSeat) or 1
    local over = pub.over == true or tonumber(pub.o) == 1
    local winner = tonumber(pub.winner or pub.w) or 0
    local result
    if over then
        if winner == 0 then result = "DRAW"
        elseif winner == localSeat then result = "WIN"
        else result = "LOSS" end
    end
    local s1, s2 = tonumber(pub.s1) or 0, tonumber(pub.s2) or 0
    return {
        cards = cards,
        grid = grid,
        totalCards = n,
        pairs = 8,
        matchedPairs = s1 + s2,
        score1 = s1,
        score2 = s2,
        myScore = (localSeat == 1) and s1 or s2,
        oppScore = (localSeat == 1) and s2 or s1,
        moves = tonumber(pub.mv) or 0,
        flippedIdx = flippedIdx,
        phase = over and "WON" or "PLAYING",
        difficulty = "easy",
        theme = theme,
        timerActive = false,
        blocked = pub.blocked or tonumber(pub.bl) == 1,
        gameOver = over,
        result = result,
        turn = tonumber(pub.t) or 1,
        localSeat = localSeat,
    }
end

function Logic.MatchOpts(engine)
    return {
        gameId = Logic.GAME_ID,
        gameProto = Logic.GAME_PROTO,
        maxSeats = 2,
        newPublic = Logic.EmptyPublic,
        seedOnStart = function()
            local theme = (engine and engine._mpTheme) or "classes"
            return Logic.DealMp(theme)
        end,
        packPublic = Logic.PackPublic,
        unpackPublic = Logic.UnpackPublic,
        packStart = Logic.PackStart,
        unpackStart = Logic.UnpackStart,
        applyIntent = function(pub, intent, seat, hid)
            return Logic.ApplyMatch(pub, intent, seat, hid)
        end,
        privateForSeat = function()
            return nil
        end,
        isFinished = Logic.IsFinished,
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
            return Logic.CanTryStart(node)
        end,
    }
end
