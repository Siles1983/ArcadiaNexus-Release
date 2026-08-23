-- ============================================================
--  Solitaire – Logic.lua
--  Reine Spielregeln: Deck, Zug-Validierung, Undo, Scoring.
--  KEIN UI-Code hier.
--  Namespace: SOL_
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SOL_Logic = {}
local Logic = ArcadiaNexus.SOL_Logic

-- ── Kartendefinition ──────────────────────────────────────────
local SUITS = { "herz", "karo", "kreuz", "pik" }
local RANKS = { "A","2","3","4","5","6","7","8","9","10","J","Q","K" }

-- Farb-Gruppierung: Rot = herz/karo, Schwarz = kreuz/pik
local RED_SUITS  = { herz=true, karo=true }
local BLACK_SUITS = { kreuz=true, pik=true }

-- Rang-Reihenfolge (1=2 ... 13=A)
local RANK_ORDER = {}
for i, r in ipairs(RANKS) do RANK_ORDER[r] = i end

-- Foundation-Keys pro Farbe (intern: H,D,C,S)
-- herz=H, karo=D, kreuz=C, pik=S
local SUIT_KEY = { herz="H", karo="D", kreuz="C", pik="S" }

-- Foundation-Slots (intern C/D/H/S). Farbe liegt nicht fest in einem Slot:
-- Asse dürfen auf jeden leeren Stapel, Folgekarten folgen dem Ass.
local FND_KEYS = { "C", "D", "H", "S" }

-- ── Score-Konstanten ──────────────────────────────────────────
local SCORE = {
    WASTE_TO_TABLEAU   =  5,
    WASTE_TO_FOUND     = 10,
    TABLEAU_TO_FOUND   = 10,
    FLIP_CARD          =  5,
    FOUND_TO_TABLEAU   = -15,
    UNDO_PENALTY       = -15,
    WASTE_PASS_PENALTY = -20,   -- pro Karte im Waste ab 4. Durchlauf (3-Karten-Modus)
}

-- ── Hilfsfunktionen ───────────────────────────────────────────
function Logic:IsRed(card)
    return RED_SUITS[card.suit] == true
end

function Logic:IsBlack(card)
    return BLACK_SUITS[card.suit] == true
end

function Logic:RankValue(card)
    return RANK_ORDER[card.rank] or 0
end

function Logic:SuitKey(suit)
    return SUIT_KEY[suit] or suit
end

-- ── Deck & Start-Verteilung ───────────────────────────────────
function Logic:NewDeck()
    local deck = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            deck[#deck+1] = { suit=suit, rank=rank, faceUp=false }
        end
    end
    -- Fisher-Yates Shuffle
    ArcadiaNexus.ArrayUtils.Shuffle(deck)
    return deck
end

function Logic:NewGameState(mode)
    local deck = self:NewDeck()
    local state = {
        mode       = mode or "1card",
        stock      = {},
        waste      = {},
        foundation = { C={}, D={}, H={}, S={} },
        tableau    = { {},{},{},{},{},{},{} },
        score      = 0,
        elapsed    = 0,
        wastePass  = 0,
        undoStack  = {},
        selected   = nil,
    }
    -- Tableau befüllen: T1=1, T2=2, ... T7=7 Karten
    for col = 1, 7 do
        for row = 1, col do
            local card = table.remove(deck)
            card.faceUp = (row == col)  -- nur letzte Karte aufgedeckt
            state.tableau[col][row] = card
        end
    end
    -- Rest → Stock (verdeckt)
    for _, card in ipairs(deck) do
        card.faceUp = false
        state.stock[#state.stock+1] = card
    end
    return state
end

-- ── Zug-Validierung ───────────────────────────────────────────
function Logic:CanPlaceOnTableau(card, targetTop)
    if targetTop == nil then
        return card.rank == "K"
    end
    local altColor  = self:IsRed(card) ~= self:IsRed(targetTop)
    local descend   = self:RankValue(targetTop) - self:RankValue(card) == 1
    return altColor and descend
end

function Logic:CanPlaceOnFoundation(card, foundation)
    if #foundation == 0 then
        return card.rank == "A"
    end
    local top = foundation[#foundation]
    return top.suit == card.suit and
           self:RankValue(card) - self:RankValue(top) == 1
end

-- Welcher Foundation-Slot nimmt diese Karte? Zuerst Stapel mit derselben Farbe, sonst leerer Slot (Ass).
function Logic:FindFoundationKey(state, card)
    for _, key in ipairs(FND_KEYS) do
        local fnd = state.foundation[key]
        if fnd and #fnd > 0 and self:CanPlaceOnFoundation(card, fnd) then
            return key
        end
    end
    for _, key in ipairs(FND_KEYS) do
        local fnd = state.foundation[key]
        if fnd and #fnd == 0 and self:CanPlaceOnFoundation(card, fnd) then
            return key
        end
    end
    return nil
end

-- Kann Karte irgendwo hin (Tableau oder Foundation)?
function Logic:CanPlaceAnywhere(state, card)
    if self:FindFoundationKey(state, card) then
        return true
    end
    -- Tableau prüfen
    for i = 1, 7 do
        local col = state.tableau[i]
        local top = col[#col]
        if self:CanPlaceOnTableau(card, top) then
            return true
        end
    end
    return false
end

-- Ist eine Karte selektierbar?
function Logic:IsSelectable(state, zone, index, cardIdx)
    if zone == "stock" then return true end
    if zone == "waste" then
        return #state.waste > 0 and index == #state.waste
    end
    if zone == "foundation" then
        -- Nur oberste Karte der Foundation selektierbar
        local keys = {"C","D","H","S"}
        local fnd = state.foundation[keys[index]]
        return fnd and #fnd > 0
    end
    if zone == "tableau" then
        local col = state.tableau[index]
        if not col or #col == 0 then return false end
        -- cardIdx ist optional: wenn übergeben, muss genau diese Karte faceUp sein
        -- Verhindert dass verdeckte Karten gegriffen werden können
        if cardIdx then
            local card = col[cardIdx]
            return card ~= nil and card.faceUp == true
        end
        -- Fallback ohne cardIdx: erste aufgedeckte Karte von oben
        for i = 1, #col do
            if col[i].faceUp then return true end
        end
        return false
    end
    return false
end

-- Gibt die Karte(n) zurück die bei Selektion von zone/index bewegt werden
-- Für Tableau: alle Karten ab dem Index der ausgewählten Karte
function Logic:GetSelectedCards(state, zone, index, cardIndex)
    if zone == "waste" then
        return { state.waste[#state.waste] }, #state.waste
    end
    if zone == "foundation" then
        local keys = {"C","D","H","S"}
        local fnd = state.foundation[keys[index]]
        if fnd and #fnd > 0 then
            return { fnd[#fnd] }, #fnd
        end
    end
    if zone == "tableau" then
        local col = state.tableau[index]
        if not col or #col == 0 then return nil end
        local startIdx = cardIndex or #col
        -- Alle Karten ab startIdx
        local cards = {}
        for i = startIdx, #col do
            cards[#cards+1] = col[i]
        end
        return cards, startIdx
    end
    return nil
end

-- ── Zug-Ausführung ────────────────────────────────────────────
-- Gibt score-delta zurück (oder false bei ungültigem Zug)
function Logic:TryMove(state, src, dst)
    -- src/dst: { zone, index, cardIndex }
    local srcZone  = src.zone
    local srcIdx   = src.index
    local srcCardI = src.cardIndex
    local dstZone  = dst.zone
    local dstIdx   = dst.index

    -- Karten holen
    local cards, startIdx = self:GetSelectedCards(state, srcZone, srcIdx, srcCardI)
    if not cards or #cards == 0 then return false end
    local topCard = cards[1]

    -- Ziel: Foundation
    if dstZone == "foundation" then
        if #cards ~= 1 then return false end
        local keys = {"C","D","H","S"}
        local fKey
        if type(dstIdx) == "number" then
            fKey = keys[dstIdx]
        else
            fKey = dstIdx
        end
        local fnd = state.foundation[fKey]
        if not self:CanPlaceOnFoundation(topCard, fnd) then return false end

        self:PushUndo(state)
        -- Karte entfernen
        self:_RemoveFromSource(state, srcZone, srcIdx, startIdx, 1)
        -- Auf Foundation legen
        fnd[#fnd+1] = topCard
        topCard.faceUp = true
        -- Evtl. nächste Karte im Tableau aufdecken
        local flipped = self:_FlipTop(state, srcZone, srcIdx)
        -- Score
        local delta = 0
        if srcZone == "waste" then
            delta = SCORE.WASTE_TO_FOUND
        elseif srcZone == "tableau" then
            delta = SCORE.TABLEAU_TO_FOUND
            if flipped then delta = delta + SCORE.FLIP_CARD end
        elseif srcZone == "foundation" then
            delta = SCORE.FOUND_TO_TABLEAU  -- wird negativ
        end
        state.score = math.max(0, state.score + delta)
        return true, delta

    -- Ziel: Tableau
    elseif dstZone == "tableau" then
        local col = state.tableau[dstIdx]
        local targetTop = col[#col]  -- nil wenn leer
        if not self:CanPlaceOnTableau(topCard, targetTop) then return false end
        -- Foundation → Tableau Penalty
        if srcZone == "foundation" then
            if #cards ~= 1 then return false end
        end

        self:PushUndo(state)
        -- Karten entfernen
        local moveCount = #cards
        self:_RemoveFromSource(state, srcZone, srcIdx, startIdx, moveCount)
        -- Ans Ziel anhängen
        for _, card in ipairs(cards) do
            card.faceUp = true
            col[#col+1] = card
        end
        -- Karte aufdecken
        local flipped = self:_FlipTop(state, srcZone, srcIdx)
        -- Score
        local delta = 0
        if srcZone == "waste" then
            delta = SCORE.WASTE_TO_TABLEAU
        elseif srcZone == "foundation" then
            delta = SCORE.FOUND_TO_TABLEAU
        elseif srcZone == "tableau" and flipped then
            delta = SCORE.FLIP_CARD
        end
        state.score = math.max(0, state.score + delta)
        return true, delta
    end

    return false
end

-- Karten aus Quelle entfernen
function Logic:_RemoveFromSource(state, zone, idx, startIdx, count)
    if zone == "waste" then
        for i = 1, count do table.remove(state.waste) end
    elseif zone == "foundation" then
        local keys = {"C","D","H","S"}
        local fnd = state.foundation[keys[idx]]
        for i = 1, count do table.remove(fnd) end
    elseif zone == "tableau" then
        local col = state.tableau[idx]
        for i = 1, count do table.remove(col, startIdx) end
    end
end

-- Oberste Karte im Tableau aufdecken wenn verdeckt
function Logic:_FlipTop(state, zone, idx)
    if zone ~= "tableau" then return false end
    local col = state.tableau[idx]
    if #col == 0 then return false end
    local top = col[#col]
    if not top.faceUp then
        top.faceUp = true
        return true
    end
    return false
end

-- Direkt zur Foundation versuchen (Doppelklick)
function Logic:TryMoveToFoundation(state, zone, idx, cardIdx)
    if zone == "stock" or zone == "foundation" then return false end
    local cards, startIdx = self:GetSelectedCards(state, zone, idx, cardIdx)
    if not cards or #cards ~= 1 then return false end
    local card = cards[1]
    local fKey = self:FindFoundationKey(state, card)
    if not fKey then return false end
    local fnd = state.foundation[fKey]

    self:PushUndo(state)
    self:_RemoveFromSource(state, zone, idx, startIdx, 1)
    fnd[#fnd+1] = card
    card.faceUp = true
    local flipped = self:_FlipTop(state, zone, idx)
    local delta = (zone == "waste") and SCORE.WASTE_TO_FOUND or SCORE.TABLEAU_TO_FOUND
    if flipped then delta = delta + SCORE.FLIP_CARD end
    state.score = math.max(0, state.score + delta)
    return true
end

-- Versucht die Karte auf eine passende Tableau-Spalte zu legen (Doppelklick-Fallback)
function Logic:TryMoveToTableau(state, zone, idx, cardIdx)
    if zone == "stock" then return false end
    local cards, startIdx = self:GetSelectedCards(state, zone, idx, cardIdx)
    if not cards or #cards == 0 then return false end
    local topCard = cards[1]
    -- Nur faceUp-Karten
    if not topCard.faceUp then return false end

    -- Passende Tableau-Spalte suchen (Präferenz: nicht-leere Spalten zuerst)
    for pass = 1, 2 do
        for i = 1, 7 do
            -- Quelle nicht als Ziel
            if not (zone == "tableau" and idx == i) then
                local col = state.tableau[i]
                local targetTop = col[#col]
                -- Pass 1: nicht-leere Spalten; Pass 2: leere Spalten (für König)
                local isEmpty = (#col == 0)
                if (pass == 1 and not isEmpty) or (pass == 2 and isEmpty) then
                    if self:CanPlaceOnTableau(topCard, targetTop) then
                        self:PushUndo(state)
                        local moveCount = #cards
                        self:_RemoveFromSource(state, zone, idx, startIdx, moveCount)
                        for _, card in ipairs(cards) do
                            card.faceUp = true
                            col[#col+1] = card
                        end
                        local flipped = self:_FlipTop(state, zone, idx)
                        local delta = 0
                        if zone == "waste" then
                            delta = SCORE.WASTE_TO_TABLEAU
                        elseif flipped then
                            delta = SCORE.FLIP_CARD
                        end
                        state.score = math.max(0, state.score + delta)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ── Stock / Waste ─────────────────────────────────────────────
function Logic:DrawFromStock(state)
    -- Stock-Zug als eigenen Undo-Schritt speichern
    self:PushUndo(state)
    if #state.stock == 0 then
        -- Waste umdrehen → neuer Stock
        state.wastePass = state.wastePass + 1
        -- 3-Karten-Modus Penalty ab 4. Durchlauf
        if state.mode == "3card" and state.wastePass >= 4 then
            local penalty = #state.waste * SCORE.WASTE_PASS_PENALTY
            state.score   = math.max(0, state.score + penalty)
        end
        for j = #state.waste, 1, -1 do
            local card = table.remove(state.waste, j)
            card.faceUp = false
            state.stock[#state.stock+1] = card
        end
        return true, "recycle"
    end

    local count = state.mode == "1card" and 1 or 3
    for i = 1, count do
        if #state.stock == 0 then break end
        local card = table.remove(state.stock)
        card.faceUp = true
        state.waste[#state.waste+1] = card
    end
    return true, "draw"
end

-- ── Undo-System ───────────────────────────────────────────────
function Logic:PushUndo(state)
    if #state.undoStack >= 3 then
        table.remove(state.undoStack, 1)
    end
    state.undoStack[#state.undoStack+1] = self:SnapshotState(state)
end

function Logic:Undo(state)
    if #state.undoStack == 0 then return false end
    local snap = table.remove(state.undoStack)
    self:RestoreSnapshot(state, snap)
    state.score = math.max(0, state.score + SCORE.UNDO_PENALTY)
    return true
end

function Logic:SnapshotState(state)
    return {
        stock      = self:DeepCopy(state.stock),
        waste      = self:DeepCopy(state.waste),
        foundation = self:DeepCopy(state.foundation),
        tableau    = self:DeepCopy(state.tableau),
        score      = state.score,
        wastePass  = state.wastePass,
    }
end

function Logic:RestoreSnapshot(state, snap)
    state.stock      = self:DeepCopy(snap.stock)
    state.waste      = self:DeepCopy(snap.waste)
    state.foundation = self:DeepCopy(snap.foundation)
    state.tableau    = self:DeepCopy(snap.tableau)
    state.score      = snap.score
    state.wastePass  = snap.wastePass
    state.selected   = nil
end

function Logic:DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

-- ── Win-Prüfung ───────────────────────────────────────────────
function Logic:IsWin(state)
    for _, fnd in pairs(state.foundation) do
        if #fnd ~= 13 then return false end
    end
    return true
end

-- ── No-Move-Erkennung ─────────────────────────────────────────
function Logic:HasValidMoves(state)
    -- Stock nicht leer → Karte ziehen ist immer ein Zug
    if #state.stock > 0 then return true end

    -- Waste-Karte prüfen: nur wenn legbar (Stock leer = kein Recycle-Zug mehr)
    if #state.waste > 0 then
        local top = state.waste[#state.waste]
        if self:CanPlaceAnywhere(state, top) then return true end
    end

    -- Tableau: oberste Karte jeder Spalte prüfen (col[#col] ist spielbar)
    -- Stapel-Züge: alle aufgedeckten Karten von oben prüfen
    for i = 1, 7 do
        local col = state.tableau[i]
        for j = #col, 1, -1 do
            if col[j].faceUp then
                if self:CanPlaceAnywhere(state, col[j]) then return true end
            else
                break  -- verdeckte Karte erreicht, darunter nichts mehr prüfen
            end
        end
    end

    return false
end

-- ── Auto-Complete ─────────────────────────────────────────────
local function SimPilesFromState(state)
    local piles = {}
    for _, key in ipairs(FND_KEYS) do
        local pile = state.foundation[key] or {}
        piles[key] = {
            count = #pile,
            suit  = pile[1] and pile[1].suit or nil,
        }
    end
    return piles
end

local function SimFindPile(piles, card)
    for _, key in ipairs(FND_KEYS) do
        local p = piles[key]
        if p.suit == card.suit and RANK_ORDER[card.rank] == p.count + 1 then
            return key
        end
    end
    if card.rank == "A" then
        for _, key in ipairs(FND_KEYS) do
            if piles[key].count == 0 then return key end
        end
    end
    return nil
end

-- Alle Karten aufgedeckt?
function Logic:CanAutoComplete(state)
    -- Vorbedingungen: kein Stock, kein Waste, alle Karten face-up
    if #state.stock > 0 then return false end
    if #state.waste  > 0 then return false end
    for i = 1, 7 do
        for _, card in ipairs(state.tableau[i]) do
            if not card.faceUp then return false end
        end
    end

    local piles = SimPilesFromState(state)
    local tab = {}
    for i = 1, 7 do
        tab[i] = {}
        for j, card in ipairs(state.tableau[i]) do
            tab[i][j] = card
        end
    end

    local total = 52
    for _, pile in pairs(state.foundation) do
        total = total - #pile
    end

    local maxIter = total * total
    local iter = 0
    local moved = true
    while moved and total > 0 and iter < maxIter do
        moved = false
        iter = iter + 1
        for i = 1, 7 do
            if #tab[i] > 0 then
                local card = tab[i][#tab[i]]
                local key = SimFindPile(piles, card)
                if key then
                    local p = piles[key]
                    p.count = p.count + 1
                    p.suit = card.suit
                    table.remove(tab[i])
                    total = total - 1
                    moved = true
                end
            end
        end
    end
    return total == 0
end

-- Baut eine vollständige Move-Queue für Auto-Complete.
-- Gibt eine Liste von {type, fromCol, toCol, toKey, card} zurück ODER nil wenn nicht lösbar.
-- type = "foundation" | "tableau"
-- Voraussetzung: CanAutoComplete(state) == true
function Logic:AutoBuildMoveQueue(state)
    local piles = SimPilesFromState(state)
    local tab = {}
    for i = 1, 7 do
        tab[i] = {}
        for j, card in ipairs(state.tableau[i]) do
            tab[i][j] = card
        end
    end

    local function canTableau(card, targetTop)
        if targetTop == nil then return card.rank == "K" end
        local altColor = (RED_SUITS[card.suit] == true) ~= (RED_SUITS[targetTop.suit] == true)
        return altColor and (RANK_ORDER[targetTop.rank] - RANK_ORDER[card.rank] == 1)
    end

    local queue = {}
    local total = 0
    for i = 1, 7 do total = total + #tab[i] end

    local maxIter = (total + 1) * (total + 1)
    local iter = 0

    while total > 0 and iter < maxIter do
        iter = iter + 1
        local madeMove = false

        -- Priorität 1: direkte Foundation-Moves
        for i = 1, 7 do
            if not madeMove and #tab[i] > 0 then
                local card = tab[i][#tab[i]]
                local key = SimFindPile(piles, card)
                if key then
                    local p = piles[key]
                    p.count = p.count + 1
                    p.suit = card.suit
                    table.remove(tab[i])
                    total = total - 1
                    queue[#queue+1] = { type="foundation", fromCol=i, toKey=key, card=card }
                    madeMove = true
                end
            end
        end

        -- Priorität 2: Tableau-Move der eine Foundation-fähige Karte freilegt
        if not madeMove then
            for i = 1, 7 do
                if not madeMove and #tab[i] >= 2 then
                    local cardOnTop = tab[i][#tab[i]]
                    local cardBelow = tab[i][#tab[i]-1]
                    if SimFindPile(piles, cardBelow) then
                        for j = 1, 7 do
                            if not madeMove and j ~= i then
                                local targetTop = #tab[j] > 0 and tab[j][#tab[j]] or nil
                                if canTableau(cardOnTop, targetTop) then
                                    table.remove(tab[i])
                                    tab[j][#tab[j]+1] = cardOnTop
                                    queue[#queue+1] = { type="tableau", fromCol=i, toCol=j, card=cardOnTop }
                                    madeMove = true
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Priorität 3: beliebiger sinnvoller Tableau-Move
        if not madeMove then
            for i = 1, 7 do
                if not madeMove and #tab[i] > 0 then
                    local card = tab[i][#tab[i]]
                    for j = 1, 7 do
                        if not madeMove and j ~= i then
                            local targetTop = #tab[j] > 0 and tab[j][#tab[j]] or nil
                            if canTableau(card, targetTop) then
                                table.remove(tab[i])
                                tab[j][#tab[j]+1] = card
                                queue[#queue+1] = { type="tableau", fromCol=i, toCol=j, card=card }
                                madeMove = true
                            end
                        end
                    end
                end
            end
        end

        if not madeMove then break end
    end

    if total == 0 then
        return queue
    else
        return nil
    end
end

-- ── Zeit-Bonus (WIN) ──────────────────────────────────────────
function Logic:ApplyTimeBonus(state)
    if state.elapsed > 30 then
        local bonus = math.floor(700000 / state.elapsed)
        state.score = state.score + bonus
        return bonus
    end
    return 0
end

-- ── Score-Konstanten exportieren (für Renderer-Tooltips) ──────
Logic.SCORE = SCORE
