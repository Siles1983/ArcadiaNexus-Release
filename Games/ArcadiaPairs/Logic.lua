--[[
    Gaming Hub
    Games/Memory/Logic.lua
    Version: 2.0.0

    Icon-Pfade: "Interface\\Icons\\Name" exakt wie im Referenz-Addon MemoryPairs.lua.
    Nur Icons verwendet die im Referenz-Addon ebenfalls vorhanden und bestätigt funktionieren.
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
-- Icons aus dem Referenz-Addon übernommen (garantiert vorhanden).
local DECKS = {
    classes = {
        name = "Klassentreffen",
        icons = {
            "Ability_Warrior_Charge",
            "Ability_Rogue_Stealth",
            "Spell_Fire_FlameBolt",
            "Spell_Frost_FrostBolt02",
            "Spell_Holy_Heal",
            "Spell_Shadow_DeathCoil",
            "Spell_Nature_Lightning",
            "Spell_Arcane_Blink",
            "INV_Sword_39",
            "INV_Axe_09",
            "INV_Hammer_05",
            "INV_Staff_13",
            "INV_Wand_05",
            "INV_Weapon_Bow_07",
            "INV_ThrowingKnife_04",
            "INV_Weapon_Crossbow_05",
            "INV_Shield_06",
            "INV_Helmet_74",
            "INV_Chest_Plate06",
            "INV_Boots_Cloth_03",
            "INV_Gauntlets_04",
            "INV_Belt_12",
            "INV_Shoulder_02",
            "INV_Pants_04",
            "INV_Misc_Gem_01",
            "INV_Misc_Gem_Ruby_02",
            "INV_Misc_Gem_Sapphire_02",
            "INV_Misc_Gem_Emerald_02",
            "INV_Ring_16",
            "INV_Jewelry_Necklace_07",
            "INV_Jewelry_Amulet_04",
            "INV_Jewelry_Ring_15",
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
            "INV_Misc_Gem_01",
            "INV_Misc_Gem_Ruby_02",
        },
    },
    mounts = {
        name = "Reise durch Azeroth",
        icons = {
            "Ability_Mount_RidingHorse",
            "Ability_Mount_GriffonMount",
            "Ability_Warrior_Charge",
            "Spell_Fire_FlameBolt",
            "Spell_Frost_FrostBolt02",
            "Spell_Holy_Heal",
            "Spell_Shadow_DeathCoil",
            "Spell_Nature_Lightning",
            "INV_Sword_39",
            "INV_Axe_09",
            "INV_Hammer_05",
            "INV_Staff_13",
            "INV_Wand_05",
            "INV_Shield_06",
            "INV_Helmet_74",
            "INV_Chest_Plate06",
            "INV_Misc_Gem_01",
            "INV_Misc_Gem_Ruby_02",
            "INV_Misc_Gem_Sapphire_02",
            "INV_Misc_Gem_Emerald_02",
            "INV_Potion_54",
            "INV_Potion_81",
            "INV_Misc_Key_04",
            "INV_Misc_Book_09",
            "Trade_Engineering",
            "Trade_Blacksmithing",
            "INV_Misc_MonsterClaw_04",
            "INV_Misc_MonsterFang_01",
            "INV_Misc_Horn_01",
            "INV_Ring_16",
            "INV_Jewelry_Necklace_07",
            "INV_Jewelry_Ring_15",
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
    }
end

function Logic:GetDeckList()
    return {
        { key = "classes", name = DECKS.classes.name },
        { key = "items",   name = DECKS.items.name   },
        { key = "mounts",  name = DECKS.mounts.name  },
    }
end
