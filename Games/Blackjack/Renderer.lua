-- ============================================================
--  Blackjack – Renderer.lua
--  UI-Darstellung: Tisch, Karten, Chips, Buttons, Overlays.
--  KEINE Spiellogik hier.
--
--  Blueprint-Koordinaten (relativ zu container/renderer, 600x498):
--    Spielfeld + Hintergrund: TOPLEFT +4/0, 592x432
--    Chip-Stapel (klickbar):  y=-368, x: 160/224/320/384, 48x48
--    Chip-gesetzt (Bet-Pos):  y=-288, x: 176/224/320/368, 48x48
--    Beenden-Button:          TOPLEFT +8/-448,   140x30
--    Schwierigkeit-Dropdown:  TOPLEFT +176/-448, 120x30
--    Mitspieler-Dropdown:      TOPLEFT +304/-448, 120x30
--    Spiel-Starten-Button:    TOPLEFT +448/-448, 140x30
--    Divider links:           x=160/-440
--    Divider rechts:          x=434/-440
--    Mitspieler 1 Avatar:      TOPLEFT +16/-32,   64x64
--    Dealer Avatar:           TOPLEFT +264/-32,  64x64
--    Mitspieler 2 Avatar:      TOPLEFT +520/-32,  64x64
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BJ_Renderer = {}
local R = ArcadiaNexus.BJ_Renderer

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "BLACKJACK",
    label     = "Blackjack",
    category  = "KARTEN",
    renderer  = "BJ_Renderer",
    engine    = "BJ_Engine",
    container = "_bjContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\Blackjack\\assets\\logo\\logo_bj",
    xp        = 10,
})

-- ── Konstanten ────────────────────────────────────────────────
local ADDON_PATH   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Blackjack\\assets\\"
local SHARED_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Shared\\"
local SHARED_CARDS = SHARED_PATH .. "Cards\\"
local SHARED_BACKS = SHARED_PATH .. "CardBacks\\"
local SHARED_CHIPS = SHARED_PATH .. "Chips\\"

-- ── CFG ────────────────────────────────────────────────────────
local CFG = {
    field_w      = 592,
    field_h      = 432,
    field_ofs_x  = 30,
    field_ofs_y  = 10,
    bg_w         = 730,
    bg_h         = 500,
    bg_ofs_x     = -27,
    bg_ofs_y     = -26,
    bg_alpha     = 1.0,
    border_w     = 795,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 15,
    logo_w       = 350,
    logo_h       = 300,
    logo_ofs_x   = -25,
    logo_ofs_y   = 0,
    controls_y   = 25,   -- Reset-Button am Canvas-Boden
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    cap_box_w    = 130,
    cap_box_h    = 32,
    cap_box_x    = 195,
    -- Kapital-Anzeige (StatusBar, Rahmen + dunkler Hintergrund)
    cap_lbl_x    = 35,
    cap_lbl_y    = -515,
    cap_lbl_w    = 200,
    cap_lbl_h    = 28,
    cap_lbl_alpha = 0.75,
    -- Spieler Hand-Wert Label (Punkte-Anzeige unter Spieler-Karten)
    hud_player_x  = 223,
    hud_player_y  = -300,
    hud_player_w  = 100,
    hud_player_h  = 24,
    hud_player_alpha = 0.75,
    -- Chip-Bereich: verschiebt Stapel-Chips, DEAL-Button und BetChip-Pile gemeinsam
    chips_area_x = 0,
    chips_area_y = 50,
    -- Action-Button-Reihe (Hit/Stand/Double/Split/Insurance)
    action_x     = 8,
    action_y     = -380,
}

-- Kartenrückseite je Theme-Ordner
local CARD_BACK_THEMES = {
    neutral  = SHARED_BACKS .. "card_back_neutral",
    alliance = SHARED_BACKS .. "card_back_alliance",
    horde    = SHARED_BACKS .. "card_back_horde",
}

-- Rank → Asset-Dateiname
local RANK_FILE = {
    ["2"]="2",["3"]="3",["4"]="4",["5"]="5",["6"]="6",
    ["7"]="7",["8"]="8",["9"]="9",["10"]="10",
    ["J"]="b",["Q"]="q",["K"]="k",["A"]="a",
}

-- Chip-Atlas: 4 Farben, je 3x3 Grid = 9 Varianten
-- TexCoords: { left, right, top, bottom } (normalisiert)
local CHIP_ATLAS = {
    green = {
        file = SHARED_CHIPS .. "chip_atlas_green",
        coords = {
            {0.0430,0.2930,0.0391,0.2891}, {0.3711,0.6250,0.0391,0.2891}, {0.7031,0.9531,0.0391,0.2891},
            {0.0430,0.2930,0.3711,0.6172}, {0.3711,0.6250,0.3711,0.6172}, {0.7031,0.9531,0.3711,0.6172},
            {0.0430,0.2930,0.6992,0.9453}, {0.3711,0.6250,0.6992,0.9453}, {0.7031,0.9531,0.6992,0.9453},
        },
    },
    red = {
        file = SHARED_CHIPS .. "chip_atlas_red",
        coords = {
            {0.0430,0.2969,0.0352,0.2891}, {0.3711,0.6250,0.0352,0.2891}, {0.7031,0.9531,0.0352,0.2891},
            {0.0430,0.2969,0.3711,0.6211}, {0.3711,0.6250,0.3711,0.6211}, {0.7031,0.9531,0.3711,0.6211},
            {0.0430,0.2969,0.6953,0.9492}, {0.3711,0.6250,0.6953,0.9492}, {0.7031,0.9531,0.6953,0.9492},
        },
    },
    blue = {
        file = SHARED_CHIPS .. "chip_atlas_blue",
        coords = {
            {0.0508,0.2930,0.0430,0.2891}, {0.3789,0.6211,0.0430,0.2891}, {0.7070,0.9492,0.0430,0.2891},
            {0.0508,0.2930,0.3750,0.6172}, {0.3789,0.6211,0.3750,0.6172}, {0.7070,0.9492,0.3750,0.6172},
            {0.0508,0.2930,0.6992,0.9453}, {0.3789,0.6211,0.6992,0.9453}, {0.7070,0.9492,0.6992,0.9453},
        },
    },
    yellow = {
        file = SHARED_CHIPS .. "chip_atlas_yellow",
        coords = {
            {0.0508,0.2930,0.0469,0.2891}, {0.3789,0.6250,0.0469,0.2891}, {0.7070,0.9492,0.0469,0.2891},
            {0.0508,0.2930,0.3750,0.6172}, {0.3789,0.6250,0.3750,0.6172}, {0.7070,0.9492,0.3750,0.6172},
            {0.0508,0.2930,0.7031,0.9453}, {0.3789,0.6250,0.7031,0.9453}, {0.7070,0.9492,0.7031,0.9453},
        },
    },
}

-- Chip-Stapel: 4 Slots mit Farbe, Einsatz-Wert, x-Position (Blueprint)
local CHIP_SLOTS = {
    { color="green",  value=25,  stackX=144,  betX=176 },
    { color="red",    value=50,  stackX=200, betX=224 },
    { color="blue",   value=100, stackX=360, betX=320 },
    { color="yellow", value=500, stackX=416, betX=368 },
}
local CHIP_STACK_Y = 358   -- y-Offset für Stapel (Blueprint y=-368, +10px Korrektur)
local CHIP_BET_Y   = 288   -- y-Offset für gesetzte Position (Blueprint: y=-288)
local CHIP_SIZE    = 48

-- KI-Immersions-Chips (dekorativ)
local AI_CHIP_SIZE = 32
local AI_BET_TO_COLOR = { [25]="green", [50]="red", [100]="blue", [500]="yellow" }
local AI_CHIP_POS = {
    [1] = { x=8,   y=130 },
    [2] = { x=552, y=130 },
}

-- Karten
local CARD_W = 52
local CARD_H = 72
local CARD_GAP = 6

-- ── Zustand ───────────────────────────────────────────────────
R.frame           = nil
R._canvas         = nil
R._controlsFrame  = nil
R._playfield      = nil
R._borderFrame    = nil
R._logo           = nil
R._bgTex          = nil
R._tableTex       = nil
R._toggleBtn      = nil
R._capitalBox     = nil
R.actionBtns      = {}
R.cardFrames      = { player={}, dealer={}, player2={}, ai1={}, ai2={} }
R._chipStackTexs  = {}   -- [slotIdx] = texture (zufällige Variante)
R._chipBetFrames  = {}   -- [slotIdx] = frame (gesetzter Chip, anfangs hidden)
R._activeBetSlot  = nil  -- welcher Slot gerade aktiv gesetzt ist
R._aiDD           = nil
R.betDisplay      = nil
R.capitalDisplay  = nil
R.stateLabel      = nil
R.insurancePrompt = nil

-- ── Hilfsfunktionen ───────────────────────────────────────────
local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("BLACKJACK")
    return (tbl and tbl[key]) or key
end

local function GetTheme()
    local S = ArcadiaNexus.BJ_Settings
    return (S and S:Get("theme")) or "neutral"
end

-- Zufällige Chip-Variante für einen Slot setzen
local function SetRandomChipVariant(tex, color)
    local atlas   = CHIP_ATLAS[color]
    if not atlas  then return end
    local variant = atlas.coords[ math.random(1, #atlas.coords) ]
    tex:SetTexture(atlas.file)
    tex:SetTexCoord(variant[1], variant[2], variant[3], variant[4])
end

local function CreateBetChipPool(chipSize, poolName)
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = poolName,
        create = function(poolParent)
            poolParentRef = poolParent
            local bf = CreateFrame("Frame", nil, poolParent)
            bf:SetSize(chipSize, chipSize)
            bf._tex = bf:CreateTexture(nil, "ARTWORK")
            bf._tex:SetAllPoints(bf)
            return bf
        end,
        onRelease = function(frame)
            frame:ClearAllPoints()
            frame:Hide()
            frame:SetAlpha(1)
            frame:SetScale(1)
            frame._value = nil
            frame._color = nil
            frame._variant = nil
            if frame._tex then
                frame._tex:SetTexture(nil)
                frame._tex:SetTexCoord(0, 1, 0, 1)
                frame._tex:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then
                frame:SetParent(poolParentRef)
            end
        end,
    })
end

-- Karten-Textur-Pfad
function R:_CardTexPath(card)
    local suit = card.suit   -- bereits "herz"/"karo"/"kreuz"/"pik"
    local rank = RANK_FILE[card.rank] or card.rank:lower()
    return SHARED_CARDS .. suit .. "\\" .. suit .. "_" .. rank
end

function R:_CardBackPath()
    return CARD_BACK_THEMES[GetTheme()] or CARD_BACK_THEMES.neutral
end

local function BuildCardFrame(parent)
    local cf = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    cf:SetSize(CARD_W, CARD_H)
    cf:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=false, edgeSize=1, insets={left=1,right=1,top=1,bottom=1},
    })
    cf:SetBackdropColor(0.95, 0.93, 0.88, 1)
    cf:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
    local tex = cf:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",     cf, "TOPLEFT",     2, -2)
    tex:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2,  2)
    cf._tex = tex
    cf:Hide()
    return cf
end

local function CreateCardPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Blackjack.Cards",
        create = function(poolParent)
            poolParentRef = poolParent
            return BuildCardFrame(poolParent)
        end,
        onRelease = function(cf)
            cf:Hide()
            cf:ClearAllPoints()
            cf:SetAlpha(1)
            cf:SetScale(1)
            cf._card = nil
            if cf._tex then
                cf._tex:SetTexture(nil)
                cf._tex:SetTexCoord(0, 1, 0, 1)
                cf._tex:SetVertexColor(1, 1, 1, 1)
                cf._tex:SetAlpha(1)
            end
            cf:SetBackdropColor(0.95, 0.93, 0.88, 1)
            cf:SetBackdropBorderColor(0.3, 0.25, 0.15, 1)
            if poolParentRef then
                cf:SetParent(poolParentRef)
            end
        end,
    })
end

-- Verdeckte Karten im laufenden Spiel nach Theme-Wechsel aktualisieren
function R:RefreshCardBacks()
    if not self.cardFrames then return end
    local path = self:_CardBackPath()
    for _, area in ipairs({ "dealer", "player", "ai1", "ai2" }) do
        for _, cf in ipairs(self.cardFrames[area] or {}) do
            if cf._card and cf._card.hidden and cf._tex then
                cf._tex:SetTexture(path)
            end
        end
    end
end

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreateTableBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateAvatarLabels()
    self:_CreateCardAreas()
    self:_CreateChipSystem()
    self:_CreateStatusBar()
    self:_CreateBottomBar()
    self:_CreateInsurancePrompt()
    self:EnterIdleState()
end

-- ── Hauptframe ────────────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_BJ_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._bjContainer = f end

    f:SetScript("OnHide", function()
        local outcome = ArcadiaNexus.GameSession:HandleRendererHide("BLACKJACK", ArcadiaNexus.BJ_Engine, function(E)
            if E.state ~= "IDLE" then
                return E:StopGame()
            end
        end)
        if outcome == "clear" then R:EnterIdleState() end
    end)
end

-- ── Tisch-Hintergrund ─────────────────────────────────────────
function R:_CreateTableBackground()
    local canvas = self._canvas
    if not canvas then return end

    local pf = CreateFrame("Frame", nil, canvas)
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.field_ofs_x, CFG.field_ofs_y)
    self._playfield = pf

    local tex = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetTexture(ADDON_PATH .. "background\\background_bj")
    tex:SetAlpha(CFG.bg_alpha)
    self._tableTex = tex
end

-- ── Border ─────────────────────────────────────────────────────
function R:_CreateBorderFrame()
    if self._borderFrame then return end
    local canvas = self._canvas
    if not canvas then return end
    local bf = CreateFrame("Frame", nil, canvas)
    bf:SetSize(CFG.border_w, CFG.border_h)
    bf:SetPoint("CENTER", canvas, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    bf:SetFrameLevel((canvas:GetFrameLevel() or 1) + 10)
    local tex = bf:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(bf)
    tex:SetTexture(ADDON_PATH .. "border\\border_bj")
    self._borderFrame = bf
end

-- ── Logo ────────────────────────────────────────────────────────
function R:_CreateLogo()
    if self._logo then return end
    local pf = self._playfield
    if not pf then return end
    local UI = ArcadiaNexus.UI
    if not UI then return end
    self._logo = UI.CreateGameLogo(
        pf,
        ADDON_PATH .. "logo\\logo_bj",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ── Avatar-Labels entfernt ────────────────────────────────────
-- KI1/KI2-Labels oben wurden entfernt.
-- Werte werden direkt unter den Karten angezeigt (_handValueLabels).
function R:_CreateAvatarLabels()
    self._avatarLabels = {}
end

-- ── Karten-Bereiche ───────────────────────────────────────────
function R:_CreateCardAreas()
    if not self._cardPool then
        self._cardPool = CreateCardPool()
    end
    for _, area in ipairs({"dealer","player","player2","ai1","ai2"}) do
        self.cardFrames[area] = {}
    end
    -- Wert-Labels werden beim ersten UpdateBoard erstellt (Playfield muss existieren)
    self._handValueLabels = {}
end

function R:_EnsureHandValueLabels()
    local pf = self._playfield
    if not pf or self._handValueLabels._built then return end
    self._handValueLabels._built = true

    -- Spieler: Box mit dunklem Hintergrund + goldenem Rahmen
    local playerBox = CreateFrame("Frame", nil, pf, "BackdropTemplate")
    playerBox:SetSize(CFG.hud_player_w, CFG.hud_player_h)
    playerBox:SetPoint("TOPLEFT", pf, "TOPLEFT", CFG.hud_player_x, CFG.hud_player_y)
    playerBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    playerBox:SetBackdropColor(0.05, 0.05, 0.05, CFG.hud_player_alpha)
    playerBox:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local playerLbl = playerBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerLbl:SetPoint("CENTER", playerBox, "CENTER", 0, 0)
    playerLbl:SetTextColor(0.95, 0.90, 0.55)
    self._handValueLabels.player     = playerLbl
    self._handValueLabels._playerBox = playerBox
    playerBox:Hide()

    -- Split-Hand: rechts davon
    local player2Lbl = pf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    player2Lbl:SetPoint("TOPLEFT", pf, "TOPLEFT", 310, -190)
    player2Lbl:SetTextColor(0.95, 0.90, 0.55)
    self._handValueLabels.player2 = player2Lbl

    -- Dealer: oben MITTIG im Spielfeld (unter Dealer-Karten)
    local dealerLbl = pf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dealerLbl:SetPoint("TOP", pf, "TOP", 0, -104)
    dealerLbl:SetTextColor(0.75, 0.85, 0.95)
    dealerLbl:SetJustifyH("CENTER")
    self._handValueLabels.dealer = dealerLbl

    -- KI1: UNTER KI1-Karten (links)
    local ai1Lbl = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ai1Lbl:SetPoint("TOPLEFT", pf, "TOPLEFT", 8, -136)
    ai1Lbl:SetTextColor(0.75, 0.90, 0.75)
    self._handValueLabels.ai1 = ai1Lbl

    -- KI2: UNTER KI2-Karten (rechts)
    local ai2Lbl = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ai2Lbl:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -8, -136)
    ai2Lbl:SetTextColor(0.75, 0.90, 0.75)
    ai2Lbl:SetJustifyH("RIGHT")
    self._handValueLabels.ai2 = ai2Lbl
end

-- ── Chip-System ───────────────────────────────────────────────
-- Stapel-Chips (klickbar) + gestapelte Bet-Chips mit Versatz
function R:_CreateChipSystem()
    local canvas = self._canvas
    if not canvas then return end

    if not self._betChipPool then
        self._betChipPool = CreateBetChipPool(CHIP_SIZE, "Blackjack.BetChips")
    end
    if not self._aiChipPool then
        self._aiChipPool = CreateBetChipPool(AI_CHIP_SIZE, "Blackjack.AIChips")
    end
    self._aiLabelPool = self._aiLabelPool or {}
    self._aiBetChips  = {}
    self._aiBetLabels = {}

    self._chipStackTexs  = {}
    self._chipBetFrames  = {}
    self._chipStackBtns  = {}

    -- ── Stapel-Buttons ──
    for i, slot in ipairs(CHIP_SLOTS) do
        local stackFrame = CreateFrame("Button", nil, canvas)
        stackFrame:SetSize(CHIP_SIZE, CHIP_SIZE)
        stackFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT",
            slot.stackX + CFG.chips_area_x,
            -(CHIP_STACK_Y - CFG.chips_area_y))

        local stackTex = stackFrame:CreateTexture(nil, "ARTWORK")
        stackTex:SetAllPoints(stackFrame)
        SetRandomChipVariant(stackTex, slot.color)
        self._chipStackTexs[i] = stackTex

        -- Wert-Label ÜBER dem Stapel
        local valLbl = stackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valLbl:SetPoint("BOTTOM", stackFrame, "TOP", 0, 2)
        valLbl:SetText(slot.value .. "g")
        valLbl:SetTextColor(0.95, 0.85, 0.4)

        local slotRef = slot
        local texRef  = stackTex
        stackFrame:SetScript("OnClick", function(self, button)
            local E = ArcadiaNexus.BJ_Engine
            if not E or E.state ~= "BETTING" then return end
            local gs = E.gameState
            if not gs then return end

            if button == "RightButton" then
                -- Rechtsklick: letzten Chip dieser Farbe zurückziehen
                R:_RemoveLastBetChipOfColor(slotRef.color)
                E:RemoveLastBetOfColor(slotRef.color, slotRef.value)
                return
            end

            -- Linksklick: Chip hinzufügen
            if (gs.bet or 0) + slotRef.value > gs.chips then return end

            local atlas   = CHIP_ATLAS[slotRef.color]
            local variant = atlas.coords[ math.random(1, #atlas.coords) ]
            R:_AddBetChip(slotRef.color, variant, slotRef.value)
            SetRandomChipVariant(texRef, slotRef.color)
            E:SetBet(slotRef.value)
        end)
        stackFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        self._chipStackBtns[i] = stackFrame
        stackFrame:Hide()
    end
    -- Kein Reset-Button mehr — Rechtsklick übernimmt diese Funktion
end

-- Bet-Chip hinzufügen (gestapelt mit Versatz)
function R:_AddBetChip(color, variant, value)
    local canvas = self._canvas
    if not canvas or not self._betChipPool then return end

    local BASE_X = 280 + CFG.chips_area_x
    local BASE_Y = CHIP_BET_Y - 80 - CFG.chips_area_y

    local count   = #self._chipBetFrames
    local offsetX = math.random(-12, 12)
    local offsetY = math.random(-6,  6)
    local stackOffset = math.min(count * 3, 20)

    local bf = self._betChipPool:Acquire({ parent = canvas })
    bf:SetParent(canvas)
    bf:ClearAllPoints()
    bf:SetPoint("TOPLEFT", canvas, "TOPLEFT",
        BASE_X + offsetX,
        -(BASE_Y - stackOffset + offsetY))
    bf:SetFrameLevel((canvas:GetFrameLevel() or 1) + 5 + count)
    bf:SetSize(CHIP_SIZE, CHIP_SIZE)
    bf:SetAlpha(1)
    bf:SetScale(1)
    local atlas = CHIP_ATLAS[color]
    if atlas and bf._tex then
        bf._tex:SetTexture(atlas.file)
        bf._tex:SetTexCoord(variant[1], variant[2], variant[3], variant[4])
        bf._tex:SetVertexColor(1, 1, 1, 1)
    end
    bf._value = value
    bf._color = color
    bf._variant = variant
    bf:Show()

    table.insert(self._chipBetFrames, bf)
end

-- ── KI-Immersions-Chips ───────────────────────────────────────
function R:_AcquireAILabel(pf)
    local lbl = table.remove(self._aiLabelPool)
    if not lbl then
        lbl = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    lbl:Show()
    return lbl
end

function R:_ReleaseAILabel(lbl)
    if not lbl then return end
    lbl:Hide()
    lbl:SetText("")
    lbl:ClearAllPoints()
    lbl:SetTextColor(0.85, 0.80, 0.55)
    table.insert(self._aiLabelPool, lbl)
end

function R:_ShowAIBetChips(gs)
    self:_ClearAIBetChips()
    if not gs or not gs.aiBets then return end
    local pf = self._playfield
    if not pf or not self._aiChipPool then return end
    self._aiBetChips  = self._aiBetChips or {}
    self._aiBetLabels = self._aiBetLabels or {}

    for i, bet in ipairs(gs.aiBets) do
        local pos   = AI_CHIP_POS[i]
        if not pos then break end
        local color = AI_BET_TO_COLOR[bet] or "green"
        local atlas = CHIP_ATLAS[color]
        if not atlas then break end

        local chipCount = 1
        if bet >= 100 then chipCount = 2 end
        if bet >= 500 then chipCount = 3 end

        for c = 1, chipCount do
            local variant = atlas.coords[ math.random(1, #atlas.coords) ]
            local bf = self._aiChipPool:Acquire({ parent = pf })
            bf:SetParent(pf)
            local ox = math.random(-4, 4)
            local oy = (c - 1) * 6
            bf:ClearAllPoints()
            bf:SetPoint("TOPLEFT", pf, "TOPLEFT", pos.x + ox, -(pos.y - oy))
            bf:SetFrameLevel((pf:GetFrameLevel() or 1) + 3 + c)
            bf:SetSize(AI_CHIP_SIZE, AI_CHIP_SIZE)
            bf:SetAlpha(1)
            bf:SetScale(1)
            if bf._tex then
                bf._tex:SetTexture(atlas.file)
                bf._tex:SetTexCoord(variant[1], variant[2], variant[3], variant[4])
                bf._tex:SetVertexColor(1, 1, 1, 1)
            end
            bf._color = color
            bf._variant = variant
            bf:Show()
            table.insert(self._aiBetChips, bf)
        end

        local lbl = self:_AcquireAILabel(pf)
        lbl:SetPoint("TOP", pf, "TOPLEFT", pos.x + AI_CHIP_SIZE / 2, -(pos.y + AI_CHIP_SIZE + 2))
        lbl:SetText(bet .. "g")
        lbl:SetTextColor(0.85, 0.80, 0.55)
        table.insert(self._aiBetLabels, lbl)
    end
end

function R:_ClearAIBetChips()
    if self._aiChipPool then
        self._aiChipPool:ReleaseAll()
    end
    if self._aiBetLabels then
        for _, lbl in ipairs(self._aiBetLabels) do
            self:_ReleaseAILabel(lbl)
        end
    end
    self._aiBetChips  = {}
    self._aiBetLabels = {}
end
function R:_RemoveLastBetChipOfColor(color)
    for i = #self._chipBetFrames, 1, -1 do
        local bf = self._chipBetFrames[i]
        if bf._color == color then
            self._betChipPool:Release(bf)
            table.remove(self._chipBetFrames, i)
            return true
        end
    end
    return false
end

-- Alle Bet-Chips entfernen
function R:_ClearBetChip()
    if self._betChipPool then
        self._betChipPool:ReleaseAll()
    end
    self._chipBetFrames = {}
end

-- ── Status-Bar (Kapital, Einsatz, State-Label) ────────────────
function R:_CreateStatusBar()
    local canvas = self._canvas
    if not canvas then return end

    -- Kapital: Box mit dunklem Hintergrund und goldenem Rahmen (TOPRIGHT)
    local capBox = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    capBox:SetSize(CFG.cap_lbl_w, CFG.cap_lbl_h)
    capBox:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", CFG.cap_lbl_x, CFG.cap_lbl_y)
    capBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    capBox:SetBackdropColor(0.05, 0.05, 0.05, CFG.cap_lbl_alpha)
    capBox:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local capLbl = capBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLbl:SetPoint("CENTER", capBox, "CENTER", 0, 0)
    capLbl:SetTextColor(0.95, 0.85, 0.4)
    self.capitalDisplay = capLbl
    self._capitalBox    = capBox
    capBox:Hide()

    -- Einsatz-Anzeige
    local betLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    betLbl:SetPoint("TOPLEFT", canvas, "TOPLEFT", 160, -344)
    betLbl:SetTextColor(0.95, 0.85, 0.4)
    self.betDisplay = betLbl

    -- State-Label oben Mitte
    local stLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stLbl:SetPoint("TOP", canvas, "TOP", 0, -8)
    stLbl:SetTextColor(0.9, 0.85, 0.6)
    self.stateLabel = stLbl
end

-- ── Bottom-Bar (Buttons + Dropdowns, y=-448) ──────────────────
function R:_CreateBottomBar()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI then return end
    local S = ArcadiaNexus.BJ_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local aiOpts={{key="0",label=L("ai_0")},{key="1",label=L("ai_1")},{key="2",label=L("ai_2")}}
    local anchor=CreateFrame("Frame",nil,cf)
    anchor:SetSize(CFG.dd_w,CFG.btn_h)
    anchor:SetPoint("CENTER",cf,"CENTER",bar.segX[1],bar.y.dropdownOfs)
    self._aiDD=UI.CreateSimpleDropdown(anchor,0,0,CFG.dd_w,"",aiOpts,
        function() return tostring(S:Get("aiCount")) end,
        function(key) ArcadiaNexus.BJ_Engine:SetAICount(tonumber(key)) end)

    -- Segment 2: Toggle-Button Spiel starten / Beenden
    local toggleBtn = UI.CreateArcadiaButton(cf, L("btn_start"), CFG.btn_w, CFG.btn_h)
    toggleBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    toggleBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BJ_Engine
        if not E then return end
        if R.state=="SLOT_MENU" then R:EnterIdleState()
        elseif E.state == "IDLE" then
            R:ShowSlots()
        else
            E:StopGame()
        end
    end)
    self._toggleBtn = toggleBtn

    -- Aktions-Buttons (Hit/Stand/Double/Split/Insurance) — initial versteckt
    local actionDefs = {
        { key="hit",       lk="btn_hit",       x=160 },
        { key="stand",     lk="btn_stand",      x=215 },
        { key="double",    lk="btn_double",     x=270 },
        { key="split",     lk="btn_split",      x=325 },
        { key="insurance", lk="btn_insurance",  x=380 },
    }
    for _, def in ipairs(actionDefs) do
        local d   = def
        local btn = UI.CreateArcadiaButton(canvas, L(d.lk), 54, 26)
        btn:SetPoint("TOPLEFT", canvas, "TOPLEFT", d.x + CFG.action_x, CFG.action_y)
        btn:SetScript("OnClick", function()
            local E = ArcadiaNexus.BJ_Engine
            if not E then return end
            if     d.key == "hit"       then E:PlayerHit()
            elseif d.key == "stand"     then E:PlayerStand()
            elseif d.key == "double"    then E:PlayerDouble()
            elseif d.key == "split"     then E:PlayerSplit()
            elseif d.key == "insurance" then E:PlayerInsurance()
            end
        end)
        btn:Hide()
        self.actionBtns[d.key] = btn
        if btn.SetMotionScriptsWhileDisabled then btn:SetMotionScriptsWhileDisabled(true) end
        btn:SetScript("OnEnter",function(b)
            local E=ArcadiaNexus.BJ_Engine; local gs=E.gameState
            GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText(L("tip_"..d.key))
            if gs then
                if d.key=="double" or d.key=="split" or d.key=="insurance" then
                    local cost=d.key=="insurance" and gs.bet2/2 or gs.handBets2[gs.activeHand] or gs.bet2
                    GameTooltip:AddLine(L("lbl_bet")..": "..ArcadiaNexus.Format.HalfUnits(cost).." "..L("lbl_gold"),1,0.82,0)
                end
                if not E:CanAction(d.key) then GameTooltip:AddLine(L(E:ActionBlockReason(d.key)),1,0.5,0.4,true) end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end

    -- newRound-Button (DEAL — fester State, kein Toggle)
    local newRoundBtn = UI.CreateArcadiaButton(canvas, L("btn_deal"), 80, 28)
    newRoundBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT",
        265 + CFG.chips_area_x,
        -370 + CFG.chips_area_y)
    newRoundBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BJ_Engine
        if not E then return end
        if E.state == "BETTING" then
            E:StartRound()
        else
            E:NewRound()
        end
    end)
    newRoundBtn:Hide()
    self.actionBtns.newRound = newRoundBtn
end

-- ── Insurance-Prompt ─────────────────────────────────────────
function R:_CreateInsurancePrompt()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI then return end

    local ip = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ip:SetSize(280, 80)
    ip:SetPoint("CENTER", self._playfield or canvas, "CENTER", 0, 60)
    ip:SetFrameLevel((canvas:GetFrameLevel() or 1) + 8)
    ip:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=false, edgeSize=12, insets={left=3,right=3,top=3,bottom=3},
    })
    ip:SetBackdropColor(0.05, 0.05, 0.05, 0.93)
    ip:SetBackdropBorderColor(0.8, 0.7, 0.2, 1)

    local lbl = ip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOP", ip, "TOP", 0, -10)
    lbl:SetText(L("btn_insurance") .. "?")
    lbl:SetTextColor(0.9, 0.85, 0.4)

    local yesBtn = UI.CreateArcadiaButton(ip, L("btn_insurance"), 110, 26)
    yesBtn:SetPoint("BOTTOMLEFT", ip, "BOTTOMLEFT", 10, 8)
    yesBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BJ_Engine
        if E then E:PlayerInsurance() end
    end)

    local noBtn = UI.CreateArcadiaButton(ip, L("btn_decline"), 110, 26)
    noBtn:SetPoint("BOTTOMRIGHT", ip, "BOTTOMRIGHT", -10, 8)
    noBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BJ_Engine
        if E then E:DeclineInsurance() end
    end)

    ip:Hide()
    self.insurancePrompt = ip
    self._insuranceYes=yesBtn; self._insuranceNo=noBtn; self._insuranceLabel=lbl
end

-- ── Karten-Frame erstellen ────────────────────────────────────
function R:_MakeCardFrame(parent)
    return BuildCardFrame(parent)
end

-- ── Karte anzeigen ────────────────────────────────────────────
function R:ShowDealtCard(target, card)
    local area
    if     target == "player"        then area = "player"
    elseif target == "dealer_open"   then area = "dealer"
    elseif target == "dealer_hidden" then area = "dealer"
    elseif target == "dealer"        then area = "dealer"
    elseif target == "player2"       then area = "player2"
    elseif target == "ai1"           then area = "ai1"
    elseif target == "ai2"           then area = "ai2"
    else return end

    local pf = self._playfield
    if not pf then return end

    local frames = self.cardFrames[area]
    local idx    = #frames + 1
    local cf     = self._cardPool:Acquire({})
    cf:SetParent(pf)
    frames[idx]  = cf

    -- Y-Positionen: innerhalb des Spielfelds
    local areaY = { dealer=-28, player=-220, player2=-220, ai1=-60, ai2=-60 }

    -- Overlap-Konstante für KI-Karten (Karten überlappen sich halb)
    local AI_OVERLAP_X  = CARD_W - 20   -- 32px sichtbarer Versatz pro Karte
    local AI_COLS       = 2             -- max 2 Karten nebeneinander, dann neue Reihe
    local AI_ROW_H      = CARD_H - 20   -- 52px Versatz pro Reihe (Überlappung)

    local function baseX(a, i)
        local pfw    = 592
        local center = math.floor(pfw / 2) - math.floor(CARD_W / 2)  -- 270px
        local step   = CARD_W + CARD_GAP  -- 58px

        if a == "ai1" then
            local col = (i - 1) % AI_COLS
            return 8 + col * AI_OVERLAP_X
        end
        if a == "ai2" then
            local col = (i - 1) % AI_COLS
            return pfw - CARD_W - 8 - col * AI_OVERLAP_X
        end
        local gs=ArcadiaNexus.BJ_Engine.gameState
        if (a=="player" or a=="player2") and gs and #gs.playerHands==2 then
            local hi=a=="player" and 1 or 2; local n=#gs.playerHands[hi]
            local gap=math.min(38,math.floor(210/math.max(n-1,1)))
            return (hi==1 and 155 or 425)-CARD_W/2-(n-1)*gap/2+(i-1)*gap
        end

        -- Dealer / Spieler: dynamisch
        -- Karte 1 → Mitte
        -- Karte 2 → links  (Mitte − step)
        -- Karte 3 → rechts (Mitte + step)
        -- Karte 4 → links  (Mitte − 2×step)
        -- Karte 5 → rechts (Mitte + 2×step)  usw.
        if i == 1 then
            return center
        end
        local pair  = math.floor(i / 2)         -- 1,1,2,2,3,3,...
        local side  = (i % 2 == 0) and -1 or 1  -- gerade=links, ungerade=rechts
        return center + side * pair * step
    end

    local function baseY(a, i)
        local base = areaY[a] or -110
        if a == "ai1" or a == "ai2" then
            local row = math.floor((i - 1) / AI_COLS)
            return base - row * AI_ROW_H
        end
        return base
    end

    local x = baseX(area, idx)
    local y = baseY(area, idx)

    cf:ClearAllPoints()
    cf:SetPoint("TOPLEFT", pf, "TOPLEFT", x, y)

    if card.hidden then
        cf._tex:SetTexture(self:_CardBackPath())
    else
        cf._tex:SetTexture(self:_CardTexPath(card))
    end
    cf._card = card
    cf:Show()
end

-- ── Dealer-Karte aufdecken ────────────────────────────────────
function R:FlipDealerHiddenCard(card)
    local frames = self.cardFrames.dealer
    -- Verdeckte Karte = die mit hidden=true (meist Index 2)
    for _, cf in ipairs(frames) do
        if cf._card and cf._card.hidden then
            cf._card.hidden = false
            cf._tex:SetTexture(self:_CardTexPath(card))
            cf._card = card
            return
        end
    end
    -- Fallback: zweite Karte
    if frames[2] then
        frames[2]._tex:SetTexture(self:_CardTexPath(card))
        frames[2]._card = card
    end
end

-- ── Board aktualisieren ───────────────────────────────────────
function R:UpdateBoard(gs)
    if not gs then return end
    local Logic = ArcadiaNexus.BJ_Logic

    -- Wert-Labels sicherstellen
    self:_EnsureHandValueLabels()

    -- Kapital
    if self.capitalDisplay then
        self.capitalDisplay:SetText(L("lbl_capital") .. ": " .. ArcadiaNexus.Format.HalfUnits(gs.chips2) .. " " .. L("lbl_gold"))
    end
    -- Einsatz
    self:UpdateBetDisplay(gs)

    -- ── Hand-Wert-Labels ─────────────────────────────────────
    local lv = self._handValueLabels
    if Logic and lv then
        -- Spieler
        local ph = gs.playerHands and gs.playerHands[1]
        if lv.player then
            if ph and #ph > 0 then
                local v = Logic:EvalHand(ph)
                local bust = Logic:IsBust(ph) and " (Bust!)" or ""
                lv.player:SetText((gs.activeHand==1 and gs.phase=="PLAYING" and "> " or "") .. L("lbl_player") .. ": " .. v .. bust .. " · " .. ArcadiaNexus.Format.HalfUnits(gs.handBets2[1] or 0))
                if lv._playerBox then lv._playerBox:Show() end
            else
                lv.player:SetText("")
                if lv._playerBox then lv._playerBox:Hide() end
            end
        end
        -- Split-Hand
        local ph2 = gs.playerHands and gs.playerHands[2]
        if lv.player2 then
            if ph2 and #ph2 > 0 then
                lv.player2:SetText((gs.activeHand==2 and gs.phase=="PLAYING" and "> " or "") .. L("lbl_player") .. " 2: " .. Logic:EvalHand(ph2) .. " · " .. ArcadiaNexus.Format.HalfUnits(gs.handBets2[2] or 0))
            else
                lv.player2:SetText("")
            end
        end
        -- Dealer
        if lv.dealer then
            if gs.dealerHand and #gs.dealerHand > 0 then
                local dVal = (gs.dealerHand[2] and gs.dealerHand[2].hidden)
                    and "?"
                    or tostring(Logic:EvalHand(gs.dealerHand))
                lv.dealer:SetText(L("lbl_dealer") .. ": " .. dVal)
            else
                lv.dealer:SetText("")
            end
        end
        -- KI 1 + 2
        for i = 1, 2 do
            local la = lv["ai" .. i]
            if la then
                if gs.aiCount and gs.aiCount >= i and gs.aiHands and gs.aiHands[i] and #gs.aiHands[i] > 0 then
                    local v  = Logic:EvalHand(gs.aiHands[i])
                    local st = gs.aiStates and gs.aiStates[i] or ""
                    la:SetText(L("lbl_ai_opponents") .. " " .. i .. ": " .. v .. (st == "bust" and "!" or ""))
                    la:Show()
                else
                    la:SetText("")
                end
            end
        end
    end

    self:UpdateActionButtons(gs)
    self:UpdateBetDisplay(gs)
end

-- ── Action-Buttons aktualisieren ─────────────────────────────
function R:UpdateActionButtons(gs)
    if not gs then return end
    local E=ArcadiaNexus.BJ_Engine
    for _,key in ipairs({"hit","stand","double","split","insurance"}) do
        local btn=self.actionBtns[key]
        if btn then
            if E:CanAction(key) then btn:Enable() else btn:Disable() end
        end
    end
    local btn=self.actionBtns.newRound
    if btn then if E.state=="BETTING" and gs.bet2>=50 or E.state=="ROUND_RESULT" then btn:Enable() else btn:Disable() end end
    if self._aiDD and self._aiDD.SetEnabled then self._aiDD:SetEnabled(E.state=="BETTING" or E.state=="ROUND_RESULT") end
    if self._insuranceYes then if E:CanAction("insurance") then self._insuranceYes:Enable() else self._insuranceYes:Disable() end end
end

function R:UpdateBetDisplay(gs)
    if not self.betDisplay or not gs then return end
    local bet = gs.bet or 0
    if bet > 0 then
        self.betDisplay:SetText(L("lbl_bet") .. ": " .. ArcadiaNexus.Format.HalfUnits(gs.bet2) .. " " .. L("lbl_gold"))
    else
        self.betDisplay:SetText(L("lbl_bet") .. ": --")
    end
end

-- ── State-Changed ─────────────────────────────────────────────
function R:OnStateChanged(newState)
    local stateLabels = {
        IDLE        = L("state_idle"),
        DEALING     = L("state_dealing"),
        RESULT_PENDING=L("state_result_pending"),
        BETTING     = L("state_betting"),
        PLAYING     = L("state_playing"),
        DEALER_TURN = L("state_dealer_turn"),
        ROUND_RESULT= "",
        GAMEOVER    = L("state_gameover"),
    }
    if self.stateLabel then
        self.stateLabel:SetText(stateLabels[newState] or "")
    end
    if newState == "BETTING" then
        self:_ClearBetChip()
        self:_ClearAIBetChips()
    end
    if newState == "PLAYING" then
        local E = ArcadiaNexus.BJ_Engine
        if E and E.gameState then
            self:_ShowAIBetChips(E.gameState)
        end
    end
    -- Chip-Stapel: nur im BETTING-State klickbar
    local isBet = newState == "BETTING"
    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do
            btn:SetAlpha(isBet and 1.0 or 0.35)
            btn:EnableMouse(isBet)
        end
    end
end

-- ── Game Started / Stopped ────────────────────────────────────
function R:OnGameStarted(gs)
    self:_ClearAllCards()
    self:_ClearBetChip()
    self:_ClearAIBetChips()
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.insurancePrompt then self.insurancePrompt:Hide() end
    -- Logo verstecken
    if self._logo then self._logo:Hide() end
    -- HUD, Chips, Action-Buttons einblenden
    if self._capitalBox then self._capitalBox:Show() end
    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do btn:Show() end
    end
    for _, key in ipairs({"hit","stand","double","split","insurance","newRound"}) do
        local btn = self.actionBtns[key]
        if btn then btn:Show() end
    end
    -- Toggle-Button auf Beenden
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_exit")) end
    self:UpdateBoard(gs)
    if self._aiDD then
        local ai = tostring(gs.aiCount or 0)
        if self._aiDD.RefreshDisplay then self._aiDD:RefreshDisplay() end
    end
end

function R:OnGameStopped()
    self.state="IDLE"
    if self._aiDD and self._aiDD.SetEnabled then self._aiDD:SetEnabled(true) end
    self:_ClearAllCards()
    self:_ClearBetChip()
    self:_ClearAIBetChips()
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.insurancePrompt  then self.insurancePrompt:Hide() end
    if self.stateLabel       then self.stateLabel:SetText("") end
    if self.betDisplay       then self.betDisplay:SetText("") end
    if self.capitalDisplay   then self.capitalDisplay:SetText("") end
    -- Logo zeigen
    if self._logo then self._logo:Show() end
    -- HUD, Chips, Action-Buttons verstecken
    if self._capitalBox then self._capitalBox:Hide() end
    local pb = self._handValueLabels and self._handValueLabels._playerBox
    if pb then pb:Hide() end
    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do btn:Hide() end
    end
    for _, key in ipairs({"hit","stand","double","split","insurance","newRound"}) do
        local btn = self.actionBtns[key]
        if btn then btn:Hide() end
    end
    -- Toggle-Button zurücksetzen
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_start")) end
end

function R:OnNewRound(gs)
    self:_ClearAllCards()
    self:_ClearBetChip()
    self:_ClearAIBetChips()
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.insurancePrompt  then self.insurancePrompt:Hide() end
    self:UpdateBoard(gs)
end

function R:OnSplit(gs)
    self:_ClearAreaCards("player")
    self:_ClearAreaCards("player2")
    for _, card in ipairs(gs.playerHands[1] or {}) do self:ShowDealtCard("player",  card) end
    for _, card in ipairs(gs.playerHands[2] or {}) do self:ShowDealtCard("player2", card) end
end

-- ── Round Result Overlay ──────────────────────────────────────
function R:ShowRoundResult(gs,results,bankrupt)
    if not self._playfield then return end
    local UI=ArcadiaNexus.UI; local loc=ArcadiaNexus.GetLocaleTable("BLACKJACK")
    local result=gs.net2>0 and "WIN" or gs.net2<0 and "LOSS" or "DRAW"
    local lines={}
    local function money(v) return ArcadiaNexus.Format.HalfUnits(v).." "..L("lbl_gold") end
    for i,r in ipairs(results) do
        lines[#lines+1]=L("lbl_player").." "..i..": "..L("result_"..r.result).." · "..L("lbl_bet").." "..money(r.bet2)
            .." · "..L("lbl_return").." "..money(r.return2).." · "..L("lbl_net").." "..money(r.net2)
    end
    lines[#lines+1]=L("btn_insurance")..": "..L("lbl_bet").." "..money(gs.insurance2).." · "..L("lbl_return").." "..money(gs.insuranceReturn2)
    lines[#lines+1]=L("lbl_net")..": "..money(gs.net2)
    self._lastRoundLines=lines
    local data=ArcadiaNexus.BJ_Engine._lastResult or {}
    local buttons
    if bankrupt then
        buttons=UI.ResultDialogButtons.Bankrupt(loc,
            function() ArcadiaNexus.BJ_Engine:SaveAndPause(); R:ShowSlots() end,
            function() ArcadiaNexus.BJ_Engine:SaveAndPause() end)
    else
        buttons=UI.ResultDialogButtons.Round(loc,
            function() UI.HideResultDialog(R._playfield); ArcadiaNexus.BJ_Engine:NewRound() end,
            function() ArcadiaNexus.BJ_Engine:SaveAndPause() end)
    end
    UI.ShowResultDialog({parent=self._playfield,title=L(bankrupt and "state_gameover" or result=="WIN" and "result_win" or result=="LOSS" and "result_lose" or "result_push"),
        titleColor=result=="WIN" and {0.3,0.9,0.3} or result=="LOSS" and {0.9,0.3,0.3} or {0.8,0.8,0.5},
        subtitle=L("lbl_capital")..": "..money(gs.chips2)..(bankrupt and (" · "..L("below_minimum")) or ""),gameId="BLACKJACK",difficulty="table",hideHighscore=true,
        result=result,lines=lines,xp=data.awardedXP or 0,gold=data.awardedGold or 0,
        buttons=buttons})
end

function R:ShowGameOver(gs)
    self:ShowRoundResult(gs,gs.results,true)
end

function R:ShowInsurancePrompt(gs)
    if self.insurancePrompt then
        self._insuranceLabel:SetText(L("btn_insurance")..": "..ArcadiaNexus.Format.HalfUnits(gs.bet2/2).." "..L("lbl_gold"))
        self.insurancePrompt:Show(); self:UpdateActionButtons(gs)
    end
end

function R:HideInsurancePrompt()
    if self.insurancePrompt then self.insurancePrompt:Hide() end
end

-- ── Hilfsfunktionen ───────────────────────────────────────────
function R:_ClearAreaCards(area)
    if not self.cardFrames[area] then return end
    if self._cardPool then
        for _, cf in ipairs(self.cardFrames[area]) do
            self._cardPool:Release(cf)
        end
    end
    self.cardFrames[area] = {}
end

function R:_ClearAllCards()
    for area in pairs(self.cardFrames) do self:_ClearAreaCards(area) end
    -- Wert-Labels leeren (nur FontStrings, keine Frames)
    if self._handValueLabels then
        for _, lbl in pairs(self._handValueLabels) do
            if type(lbl) ~= "boolean" and lbl.SetText then lbl:SetText("") end
        end
    end
end

function R:EnterIdleState()
    self.state="IDLE"
    if self._aiDD and self._aiDD.SetEnabled then self._aiDD:SetEnabled(true) end
    if self._slotMenu then self._slotMenu:Hide() end
    self:_ClearAllCards()
    self:_ClearBetChip()
    self:_ClearAIBetChips()
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.insurancePrompt  then self.insurancePrompt:Hide() end
    if self.stateLabel       then self.stateLabel:SetText("") end
    if self.betDisplay       then self.betDisplay:SetText("") end
    if self.capitalDisplay   then self.capitalDisplay:SetText("") end
    -- HUD, Chips, Action-Buttons verstecken
    if self._capitalBox      then self._capitalBox:Hide() end
    local pb = self._handValueLabels and self._handValueLabels._playerBox
    if pb then pb:Hide() end
    if self._chipStackBtns   then
        for _, btn in ipairs(self._chipStackBtns) do btn:Hide() end
    end
    for _, key in ipairs({"hit","stand","double","split","insurance","newRound"}) do
        local btn = self.actionBtns[key]
        if btn then btn:Hide() end
    end
    -- Logo zeigen
    if self._logo then self._logo:Show() end
    -- Toggle-Button zurücksetzen
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_start")) end
end

function R:ShowSlots()
    self:EnterIdleState()
    if self._logo then self._logo:Hide() end
    self.state="SLOT_MENU"
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_exit")) end
    local S,A=ArcadiaNexus.BJ_Settings,ArcadiaNexus
    local loc=A.GetLocaleTable("BLACKJACK")
    self._slotMenu= A.UI.CreateSaveSlotMenu({
        parent=self._canvas,maxSlots=3,L=loc,
        loadSlot=function(slot) return S:LoadSlot(slot) end,
        deleteSlot=function(slot) S:DeleteSlot(slot) end,
        canContinue=function(save) return A.BJ_Engine:CanContinueSave(save) end,
        formatInfo=function(save)
            if not A.BJ_Logic:ValidateSave(save) then return loc.slot_invalid end
            return A.Format.HalfUnits(save.chips2).." "..loc.lbl_gold.." · "..loc["state_"..string.lower(save.phase)]
        end,
        isPaused=function(save) return save.phase~="GAMEOVER" end,
        onNewGame=function(slot) A.BJ_Engine:StartGame({slot=slot,overwrite=true}) end,
        onContinue=function(slot) A.BJ_Engine:StartGame({slot=slot,mode="continue"}) end,
        onCancel=function() R:EnterIdleState() end,
    })
    self._slotMenu:Show()
end
function R:RestoreBoard(gs)
    if self._slotMenu then self._slotMenu:Hide() end
    self.state=gs.phase
    self:_ClearAllCards()
    for i,h in ipairs(gs.playerHands) do for _,card in ipairs(h) do self:ShowDealtCard(i==1 and "player" or "player2",card) end end
    for _,card in ipairs(gs.dealerHand) do self:ShowDealtCard("dealer",card) end
    for i=1,gs.aiCount do for _,card in ipairs(gs.aiHands[i]) do self:ShowDealtCard("ai"..i,card) end end
    self:OnStateChanged(gs.phase); self:UpdateBoard(gs)
    if gs.insuranceOpen then self:ShowInsurancePrompt(gs) else self:HideInsurancePrompt() end
end
function R:ShowResultPending(gs)
    local UI=ArcadiaNexus.UI
    UI.ShowResultDialog({parent=self._playfield,title=L("state_result_pending"),subtitle=L("result_retry"),
        gameId="BLACKJACK",hideHighscore=true,buttons={
            {label=L("btn_retry"),onClick=function() ArcadiaNexus.BJ_Engine:RetryResult() end},
            {label=L("btn_exit"),onClick=function() ArcadiaNexus.BJ_Engine:SaveAndPause() end},
        }})
end
