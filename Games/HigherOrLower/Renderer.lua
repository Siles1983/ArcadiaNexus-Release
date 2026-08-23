-- ============================================================
--  HigherOrLower – Renderer.lua
--  UI-Darstellung: Karten, Chips, Buttons, HUD, Overlays.
--  KEINE Spiellogik hier.
--
--  Blueprint-Koordinaten (relativ zu Container/Renderer, 600×498):
--    Spielfeld (Asset):    TOPLEFT +16/-16,   560×384
--    Karte Links (stock):  TOPLEFT +48/-64,   128×192
--    Karte Rechts (waste): TOPLEFT +416/-64,  128×192
--    Guthaben-Box:         TOPLEFT +240/-64,  112×48
--    Chip grün  (25g):     TOPLEFT +80/-272,   64×64
--    Chip rot   (50g):     TOPLEFT +176/-272,  64×64
--    Chip blau  (100g):    TOPLEFT +352/-272,  64×64
--    Chip gelb  (500g):    TOPLEFT +448/-272,  64×64
--    Lower-Button:         TOPLEFT +96/-352,  144×32
--    "Ziehen"-Button:      CENTER  zwischen Lower/Higher, 80×32
--    Higher-Button:        TOPLEFT +352/-352, 144×32
--    Controls: CreateGameControlsBar "narrow"
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.HOL_Renderer = {}
local R = ArcadiaNexus.HOL_Renderer

-- ── Konstanten ─────────────────────────────────────────────────
local CFG = {
    -- Hintergrund (relativ zu frame CENTER)
    bg_w         = 730,
    bg_h         = 500,
    bg_ofs_x     = -66,
    bg_ofs_y     = 18,
    bg_alpha     = 1,
    -- Border
    border_w     = 795,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 15,
    -- Logo
    logo_w       = 350,
    logo_h       = 300,
    logo_ofs_x   = 0,
    logo_ofs_y   = 15,
    -- HUD FontStrings (relativ zu frame TOPLEFT / TOP / TOPRIGHT)
    hud_state_x      = 0,
    hud_state_y      = -8,
    hud_state_w      = 200,
    hud_streak_x     = 16,
    hud_streak_y     = -26,
    hud_streak_w     = 160,
    hud_mult_x       = 0,   -- relativ zu streakLbl BOTTOMLEFT
    hud_mult_y       = -2,
    hud_pending_x    = 0,   -- relativ zu multLbl BOTTOMLEFT
    hud_pending_y    = -2,
    hud_ace_x        = 0,
    hud_ace_y        = -28,
    hud_ace_w        = 160,
    hud_capital_y    = 515,
    hud_capital_x    = 437,
    hud_capital_w    = 200,
    hud_capital_h    = 28,
    hud_capital_alpha = 0.75,
    hud_bet_x        = 16,
    hud_bet_y        = -245,
    hud_bet_w        = 160,
}

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "HIGHERORLOWER",
    label     = "Higher or Lower",
    category  = "KARTEN",
    renderer  = "HOL_Renderer",
    engine    = "HOL_Engine",
    container = "_holContainer",
})

-- ── Asset-Pfade ───────────────────────────────────────────────
local HOL_PATH     = "Interface\\AddOns\\ArcadiaNexus\\Games\\HigherOrLower\\Assets\\"
local SHARED_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Shared\\"
local SHARED_CARDS = SHARED_PATH .. "Cards\\"
local SHARED_BACKS = SHARED_PATH .. "CardBacks\\"
local SHARED_CHIPS = SHARED_PATH .. "Chips\\"

-- Kartenrückseite je Theme (für die linke/vorherige Karte)
local CARD_BACK_THEMES = {
    neutral  = SHARED_BACKS .. "card_back_neutral",
    alliance = SHARED_BACKS .. "card_back_alliance",
    horde    = SHARED_BACKS .. "card_back_horde",
}

local RANK_FILE = {
    ["2"]="2",["3"]="3",["4"]="4",["5"]="5",["6"]="6",
    ["7"]="7",["8"]="8",["9"]="9",["10"]="10",
    ["J"]="b",["Q"]="q",["K"]="k",["A"]="a",
}

-- Chip-Atlas (256×256, 3×3 Grid — identisch Blackjack)
local CHIP_ATLAS = {
    green = {
        file = SHARED_CHIPS .. "chip_atlas_green",
        coords = {
            {0.0430,0.2930,0.0391,0.2891},{0.3711,0.6250,0.0391,0.2891},{0.7031,0.9531,0.0391,0.2891},
            {0.0430,0.2930,0.3711,0.6172},{0.3711,0.6250,0.3711,0.6172},{0.7031,0.9531,0.3711,0.6172},
            {0.0430,0.2930,0.6992,0.9453},{0.3711,0.6250,0.6992,0.9453},{0.7031,0.9531,0.6992,0.9453},
        },
    },
    red = {
        file = SHARED_CHIPS .. "chip_atlas_red",
        coords = {
            {0.0430,0.2969,0.0352,0.2891},{0.3711,0.6250,0.0352,0.2891},{0.7031,0.9531,0.0352,0.2891},
            {0.0430,0.2969,0.3711,0.6211},{0.3711,0.6250,0.3711,0.6211},{0.7031,0.9531,0.3711,0.6211},
            {0.0430,0.2969,0.6953,0.9492},{0.3711,0.6250,0.6953,0.9492},{0.7031,0.9531,0.6953,0.9492},
        },
    },
    blue = {
        file = SHARED_CHIPS .. "chip_atlas_blue",
        coords = {
            {0.0508,0.2930,0.0430,0.2891},{0.3789,0.6211,0.0430,0.2891},{0.7070,0.9492,0.0430,0.2891},
            {0.0508,0.2930,0.3750,0.6172},{0.3789,0.6211,0.3750,0.6172},{0.7070,0.9492,0.3750,0.6172},
            {0.0508,0.2930,0.6992,0.9453},{0.3789,0.6211,0.6992,0.9453},{0.7070,0.9492,0.6992,0.9453},
        },
    },
    yellow = {
        file = SHARED_CHIPS .. "chip_atlas_yellow",
        coords = {
            {0.0508,0.2930,0.0469,0.2891},{0.3789,0.6250,0.0469,0.2891},{0.7070,0.9492,0.0469,0.2891},
            {0.0508,0.2930,0.3750,0.6172},{0.3789,0.6250,0.3750,0.6172},{0.7070,0.9492,0.3750,0.6172},
            {0.0508,0.2930,0.7031,0.9453},{0.3789,0.6250,0.7031,0.9453},{0.7070,0.9492,0.7031,0.9453},
        },
    },
}

-- Blueprint-Positionen
local CHIP_SLOTS = {
    { color="green",  value=25,  stackX=80  },
    { color="red",    value=50,  stackX=176 },
    { color="blue",   value=100, stackX=352 },
    { color="yellow", value=500, stackX=448 },
}
local CHIP_STACK_Y = 272
local CHIP_SIZE    = 64
local CHIP_WASTE_X = 264   -- mittig zwischen Karte links (x=48+128=176) und rechts (x=416)
local CHIP_WASTE_Y = 160

local CARD_W       = 128
local CARD_H       = 192
local CARD_LEFT_X  = 65
local CARD_LEFT_Y  = 64
local CARD_RIGHT_X = 416
local CARD_RIGHT_Y = 64

-- ── Zustand ───────────────────────────────────────────────────
R.frame          = nil
R._canvas        = nil
R._controlsFrame = nil
R._playfield     = nil
R._borderFrame   = nil
R._logo          = nil
R._bgTex         = nil
R._prevCardF     = nil
R._prevCardTex   = nil
R._currCardF     = nil
R._currCardTex   = nil
R._chipStackBtns = {}
R._chipStackTexs = {}
R._chipWastePile = {}
R._capitalLbl    = nil
R._capitalBox    = nil
R._betLbl        = nil
R._stateLbl      = nil
R._streakLbl     = nil
R._multLbl       = nil
R._pendingLbl    = nil
R._aceLbl        = nil
R._diffDD        = nil
R._streakPrompt  = nil
R.actionBtns     = {}

-- ── Locale-Helper ─────────────────────────────────────────────
local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("HIGHERORLOWER")
    return (tbl and tbl[key]) or key
end

local function GetTheme()
    local S = ArcadiaNexus.HOL_Settings
    return (S and S:Get("theme")) or "neutral"
end

local function CardTexPath(card)
    if not card or card.isJoker then return nil end
    local rank = RANK_FILE[card.rank] or card.rank:lower()
    return SHARED_CARDS .. card.suit .. "\\" .. card.suit .. "_" .. rank
end

local function SetRandomChipVariant(tex, color)
    local atlas = CHIP_ATLAS[color]
    if not atlas then return end
    local v = atlas.coords[math.random(1, #atlas.coords)]
    tex:SetTexture(atlas.file)
    tex:SetTexCoord(v[1], v[2], v[3], v[4])
end

local function CreateWasteChipPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "HigherOrLower.WasteChips",
        create = function(poolParent)
            poolParentRef = poolParent
            local bf = CreateFrame("Frame", nil, poolParent)
            bf:SetSize(CHIP_SIZE, CHIP_SIZE)
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

local function FormatStr(template, ...)
    local args = {...}
    return (template:gsub("{(%d+)}", function(i)
        return tostring(args[tonumber(i)+1] or "")
    end))
end

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreatePlayfield()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateCardFrames()
    self:_CreateHUD()
    self:_CreateChipSystem()
    self:_CreateActionButtons()
    self:_CreateBottomBar()
    self:_CreateStreakPrompt()
    self:_EnterIdleState()
end

-- ── Hauptframe ────────────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_HOL_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._holContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("HIGHERORLOWER", ArcadiaNexus.HOL_Engine, function(E)
            if E.state ~= "IDLE" then
                E:SaveAndPause()
            end
        end)
        R:_EnterIdleState()
    end)
end

-- ── Spielfeld ─────────────────────────────────────────────────
function R:_CreatePlayfield()
    local canvas = self._canvas
    if not canvas then return end
    local pf = CreateFrame("Frame", nil, canvas)
    pf:SetSize(CFG.bg_w, CFG.bg_h)
    pf:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.bg_ofs_x, CFG.bg_ofs_y)
    self._playfield = pf
    local bg = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints(pf)
    bg:SetTexture(HOL_PATH .. "background\\background")
    bg:SetAlpha(CFG.bg_alpha)
    self._bgTex = bg
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
    tex:SetTexture(HOL_PATH .. "border\\border_hol")
    self._borderFrame = bf
end

-- ── Logo ────────────────────────────────────────────────────────
function R:_CreateLogo()
    if self._logo then return end
    local UI = ArcadiaNexus.UI
    if not UI then return end
    self._logo = UI.CreateGameLogo(
        self._playfield,
        HOL_PATH .. "logo\\logo_hol",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ── Karten-Frames ─────────────────────────────────────────────
function R:_CreateCardFrames()
    local canvas = self._canvas
    if not canvas then return end

    -- Vorherige Karte (links, verblasst)
    local prevF = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    prevF:SetSize(CARD_W, CARD_H)
    prevF:SetPoint("TOPLEFT", canvas, "TOPLEFT", CARD_LEFT_X, -CARD_LEFT_Y)
    prevF:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=false, edgeSize=2, insets={left=2,right=2,top=2,bottom=2} })
    prevF:SetBackdropColor(0.95, 0.93, 0.88, 1)
    prevF:SetBackdropBorderColor(0.35, 0.30, 0.18, 0.6)
    local prevTex = prevF:CreateTexture(nil, "ARTWORK")
    prevTex:SetPoint("TOPLEFT",     prevF, "TOPLEFT",     3, -3)
    prevTex:SetPoint("BOTTOMRIGHT", prevF, "BOTTOMRIGHT", -3,  3)
    prevF:Hide()
    self._prevCardF   = prevF
    self._prevCardTex = prevTex

    -- Aktuelle Karte (rechts, voll)
    local currF = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    currF:SetSize(CARD_W, CARD_H)
    currF:SetPoint("TOPLEFT", canvas, "TOPLEFT", CARD_RIGHT_X, -CARD_RIGHT_Y)
    currF:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=false, edgeSize=2, insets={left=2,right=2,top=2,bottom=2} })
    currF:SetBackdropColor(0.95, 0.93, 0.88, 1)
    currF:SetBackdropBorderColor(0.55, 0.50, 0.28, 1)
    local currTex = currF:CreateTexture(nil, "ARTWORK")
    currTex:SetPoint("TOPLEFT",     currF, "TOPLEFT",     3, -3)
    currTex:SetPoint("BOTTOMRIGHT", currF, "BOTTOMRIGHT", -3,  3)
    currF:Hide()
    self._currCardF   = currF
    self._currCardTex = currTex

    local prevCap = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prevCap:SetPoint("TOP", prevF, "BOTTOM", 0, -3)
    prevCap:SetText("Vorherige")
    prevCap:SetTextColor(0.65, 0.60, 0.45)

    local currCap = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currCap:SetPoint("TOP", currF, "BOTTOM", 0, -3)
    currCap:SetText("Aktuelle")
    currCap:SetTextColor(0.85, 0.80, 0.55)
end

-- ── HUD ───────────────────────────────────────────────────────
function R:_CreateHUD()
    local canvas = self._canvas
    if not canvas then return end

    -- Kapital: Box mit dunklem Hintergrund und goldenem Rahmen (wie Blackjack)
    local capBox = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    capBox:SetSize(CFG.hud_capital_w, CFG.hud_capital_h)
    capBox:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.hud_capital_x, -CFG.hud_capital_y)
    capBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    capBox:SetBackdropColor(0.05, 0.05, 0.05, CFG.hud_capital_alpha)
    capBox:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local capLbl = capBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLbl:SetPoint("CENTER", capBox, "CENTER", 0, 0)
    capLbl:SetTextColor(0.95, 0.85, 0.4)
    self._capitalLbl = capLbl
    self._capitalBox = capBox
    capBox:Hide()

    local stateLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stateLbl:SetPoint("TOP", canvas, "TOP", CFG.hud_state_x, CFG.hud_state_y)
    stateLbl:SetWidth(CFG.hud_state_w)
    stateLbl:SetTextColor(0.9, 0.85, 0.6)
    self._stateLbl = stateLbl

    local betLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    betLbl:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.hud_bet_x, CFG.hud_bet_y)
    betLbl:SetWidth(CFG.hud_bet_w)
    betLbl:SetTextColor(0.85, 0.75, 0.35)
    self._betLbl = betLbl

    local streakLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    streakLbl:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.hud_streak_x, CFG.hud_streak_y)
    streakLbl:SetWidth(CFG.hud_streak_w)
    streakLbl:SetTextColor(0.4, 0.9, 0.4)
    self._streakLbl = streakLbl

    local multLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    multLbl:SetPoint("TOPLEFT", streakLbl, "BOTTOMLEFT", CFG.hud_mult_x, CFG.hud_mult_y)
    multLbl:SetTextColor(0.5, 0.85, 0.5)
    self._multLbl = multLbl

    local pendingLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pendingLbl:SetPoint("TOPLEFT", multLbl, "BOTTOMLEFT", CFG.hud_pending_x, CFG.hud_pending_y)
    pendingLbl:SetTextColor(0.9, 0.75, 0.2)
    self._pendingLbl = pendingLbl

    local aceLbl = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    aceLbl:SetPoint("TOP", canvas, "TOP", CFG.hud_ace_x, CFG.hud_ace_y)
    aceLbl:SetWidth(CFG.hud_ace_w)
    aceLbl:SetTextColor(0.7, 0.85, 0.9)
    aceLbl:SetJustifyH("CENTER")
    self._aceLbl = aceLbl
end

-- ── Chip-System ───────────────────────────────────────────────
-- Linksklick:  Chip auf Waste-Pile, Einsatz erhöhen
-- Rechtsklick: Letzten Chip dieser Farbe zurückziehen, Einsatz senken
function R:_CreateChipSystem()
    local canvas = self._canvas
    if not canvas then return end
    if not self._wasteChipPool then
        self._wasteChipPool = CreateWasteChipPool()
    end
    self._chipStackBtns = {}
    self._chipStackTexs = {}
    self._chipWastePile = {}

    for i, slot in ipairs(CHIP_SLOTS) do
        local btn = CreateFrame("Button", nil, canvas)
        btn:SetSize(CHIP_SIZE, CHIP_SIZE)
        btn:SetPoint("TOPLEFT", canvas, "TOPLEFT", slot.stackX, -CHIP_STACK_Y)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(btn)
        SetRandomChipVariant(tex, slot.color)
        self._chipStackTexs[i] = tex

        local valLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valLbl:SetPoint("BOTTOM", btn, "TOP", 0, 2)
        valLbl:SetText(slot.value .. "g")
        valLbl:SetTextColor(0.95, 0.85, 0.4)

        local slotRef = slot
        local texRef  = tex
        btn:SetScript("OnClick", function(_, button)
            local E = ArcadiaNexus.HOL_Engine
            if not E or E.state ~= "BETTING" then return end
            local gs = E.gameState
            if not gs then return end

            if button == "RightButton" then
                -- Letzten Chip dieser Farbe zurückziehen
                if R:_RemoveLastWasteChipOfColor(slotRef.color) then
                    E:AdjustBet(-slotRef.value)
                end
                return
            end

            -- Linksklick: Chip hinzufügen
            if (gs.bet or 0) + slotRef.value > gs.chips then return end
            local atlas   = CHIP_ATLAS[slotRef.color]
            local variant = atlas.coords[math.random(1, #atlas.coords)]
            R:_AddWasteChip(slotRef.color, variant, slotRef.value)
            SetRandomChipVariant(texRef, slotRef.color)
            E:AdjustBet(slotRef.value)
        end)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self._chipStackBtns[i] = btn
        btn:Hide()
    end
end

function R:_AddWasteChip(color, variant, value)
    local canvas = self._canvas
    if not canvas or not self._wasteChipPool then return end
    local count    = #self._chipWastePile
    local offsetX  = math.random(-10, 10)
    local offsetY  = math.random(-6, 6)
    local stackOff = math.min(count * 3, 24)

    local bf = self._wasteChipPool:Acquire({
        parent = canvas,
    })
    bf:SetParent(canvas)
    bf:ClearAllPoints()
    bf:SetPoint("TOPLEFT", canvas, "TOPLEFT",
        CHIP_WASTE_X + offsetX,
        -(CHIP_WASTE_Y - stackOff + offsetY))
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
    table.insert(self._chipWastePile, bf)
end

function R:_RemoveLastWasteChipOfColor(color)
    for i = #self._chipWastePile, 1, -1 do
        local bf = self._chipWastePile[i]
        if bf._color == color then
            self._wasteChipPool:Release(bf)
            table.remove(self._chipWastePile, i)
            return true
        end
    end
    return false
end

function R:_ClearWasteChips()
    if self._wasteChipPool then
        self._wasteChipPool:ReleaseAll()
    end
    self._chipWastePile = {}
end

-- ── Aktions-Buttons: Lower / Ziehen / Higher ──────────────────
-- "Ziehen"-Button: erscheint in BETTING wenn bet > 0, verschwindet nach erster Karte
function R:_CreateActionButtons()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI then return end

    -- Lower (Blueprint: x=96, y=-352, 144×32)
    local lowerBtn = UI.CreateArcadiaButton(canvas, L("btn_lower"), 144, 32)
    lowerBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 96, -352)
    lowerBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if E then E:Guess("LOWER") end
    end)
    lowerBtn:Hide()
    self.actionBtns.lower = lowerBtn

    -- "Ziehen"-Button: zentriert zwischen Lower und Higher (x=246, w=80)
    -- Lower endet bei x=96+144=240, Higher beginnt bei x=352 → Mitte = 296 - 40 = 256
    local drawBtn = UI.CreateArcadiaButton(canvas, "Ziehen", 80, 32)
    drawBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 256, -352)
    drawBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if E then E:DealFirstCard() end
    end)
    drawBtn:Hide()
    self.actionBtns.draw = drawBtn

    -- Higher (Blueprint: x=352, y=-352, 144×32)
    local higherBtn = UI.CreateArcadiaButton(canvas, L("btn_higher"), 144, 32)
    higherBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 352, -352)
    higherBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if E then E:Guess("HIGHER") end
    end)
    higherBtn:Hide()
    self.actionBtns.higher = higherBtn
end

-- ── Bottom-Bar ────────────────────────────────────────────────
function R:_CreateBottomBar()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI then return end

    local DD_W  = 120
    local BTN_W = 144
    local BTN_H = 32

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Difficulty-Dropdown (Segment 1)
    local diffOpts = {
        { key="easy",   label=L("diff_easy")   },
        { key="normal", label=L("diff_normal")  },
        { key="hard",   label=L("diff_hard")    },
    }
    local S = ArcadiaNexus.HOL_Settings
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(DD_W, BTN_H)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    local diffDD = UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, DD_W, nil,
        diffOpts,
        function() return S and S:Get("difficulty") or "easy" end,
        function(key)
            S:Set("difficulty", key)
            local E = ArcadiaNexus.HOL_Engine
            if E then E:SetDifficulty(key) end
        end
    )
    self._diffDD = diffDD

    -- Toggle-Button Start/Beenden (Segment 2)
    local toggleBtn = UI.CreateArcadiaButton(cf, L("btn_start"), BTN_W, BTN_H)
    toggleBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    toggleBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            E:StartGame()
        end
    end)
    self._toggleBtn = toggleBtn
    self.actionBtns.start = toggleBtn   -- Kompatibilität

    -- Reset-Kapital (Segment 3, nur bei Bankrott-Nähe)
    local resetBtn = UI.CreateArcadiaButton(cf, "Reset 100g", BTN_W, BTN_H - 8)
    resetBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    resetBtn:SetScript("OnClick", function()
        local E  = ArcadiaNexus.HOL_Engine
        local Sv = ArcadiaNexus.HOL_Settings
        if not E or not Sv then return end
        if E.state ~= "BETTING" then return end
        Sv:ResetChips()
        if E.gameState then
            E.gameState.chips = 100
            E.gameState.bet   = 0
            R:_ClearWasteChips()
            R:UpdateHUD(E.gameState)
        end
    end)
    resetBtn:Hide()
    self.actionBtns.resetChips = resetBtn
end

-- ── Streak-Prompt ─────────────────────────────────────────────
function R:_CreateStreakPrompt()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI then return end

    local ov = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ov:SetSize(300, 160)
    ov:SetPoint("CENTER", self._playfield or canvas, "CENTER", 0, 20)
    ov:SetFrameLevel((canvas:GetFrameLevel() or 1) + 10)
    ov:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=false, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
    ov:SetBackdropColor(0.05, 0.08, 0.05, 0.95)
    ov:SetBackdropBorderColor(0.3, 0.7, 0.3, 1)

    local titleFS = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", ov, "TOP", 0, -14)
    titleFS:SetTextColor(0.4, 0.9, 0.4)

    local pendingFS = ov:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pendingFS:SetPoint("TOP", ov, "TOP", 0, -44)
    pendingFS:SetTextColor(0.9, 0.80, 0.2)

    local multFS = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    multFS:SetPoint("TOP", ov, "TOP", 0, -68)
    multFS:SetTextColor(0.5, 0.85, 0.5)

    local cashoutBtn = UI.CreateArcadiaButton(ov, L("btn_cashout"), 120, 30)
    cashoutBtn:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 12, 12)
    cashoutBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if E then E:CashOut() end
    end)

    local continueBtn = UI.CreateArcadiaButton(ov, L("btn_continue"), 120, 30)
    continueBtn:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", -12, 12)
    continueBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.HOL_Engine
        if E then E:ContinueStreak() end
    end)

    ov._titleFS   = titleFS
    ov._pendingFS = pendingFS
    ov._multFS    = multFS
    ov:Hide()
    self._streakPrompt = ov
end

-- ── Karte in Frame setzen ─────────────────────────────────────
local function ApplyCardToFrame(cardF, cardTex, card, alpha)
    if not card then cardF:Hide(); return end
    if card.isJoker then
        cardF:SetBackdropColor(0.5, 0.05, 0.05, 1)
        cardTex:SetTexture(nil)
    else
        cardF:SetBackdropColor(0.95, 0.93, 0.88, 1)
        cardTex:SetTexture(CardTexPath(card))
    end
    cardF:SetAlpha(alpha or 1.0)
    cardF:Show()
end

-- ── OnRoundStarted (nach DealFirstCard) ───────────────────────
function R:OnRoundStarted(gs)
    if self._prevCardF then self._prevCardF:Hide() end
    ApplyCardToFrame(self._currCardF, self._currCardTex, gs.currentCard, 1.0)
    -- "Ziehen"-Button verstecken — erste Karte ist gezogen
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    self:_UpdateAceHint(gs)
    self:UpdateHUD(gs)
    self:_SetActionButtonsEnabled(true)
end

-- ── ShowNextCard ──────────────────────────────────────────────
function R:ShowNextCard(card)
    if not card then return end
    local gs = ArcadiaNexus.HOL_Engine and ArcadiaNexus.HOL_Engine.gameState
    if self._currCardF and self._currCardF:IsShown() and gs then
        -- Linke Karte = umgedrehte Rückseite des gewählten Themes
        local backPath = CARD_BACK_THEMES[GetTheme()] or CARD_BACK_THEMES.neutral
        self._prevCardTex:SetTexture(backPath)
        self._prevCardTex:SetAlpha(1.0)
        self._prevCardF:SetAlpha(1.0)
        self._prevCardF:Show()
    end
    ApplyCardToFrame(self._currCardF, self._currCardTex, card, 1.0)
    self:_UpdateAceHint(gs)
end

function R:_UpdateAceHint(gs)
    if not self._aceLbl or not gs then return end
    local card = gs.currentCard
    if card and card.rank == "A" then
        -- Easy: Ass ist immer niedrig (value=1) → immer "ace_low" zeigen
        -- Normal/Hard: Ass ist zufällig 1 oder 14 → tatsächlichen Wert zeigen
        self._aceLbl:SetText(L(card.value == 14 and "ace_high" or "ace_low"))
    else
        self._aceLbl:SetText("")
    end
end

-- ── ShowStreakPrompt ──────────────────────────────────────────
function R:ShowStreakPrompt(gs)
    if not self._streakPrompt then return end
    local Logic = ArcadiaNexus.HOL_Logic
    local mult  = Logic and Logic:GetMultiplier(gs.streak) or 1.0
    self._streakPrompt._titleFS:SetText(FormatStr(L("prompt_title"), gs.streak))
    self._streakPrompt._pendingFS:SetText(FormatStr(L("prompt_pending"), gs.pendingWin))
    self._streakPrompt._multFS:SetText(FormatStr(L("prompt_multiplier"), mult))
    self._streakPrompt:Show()
    self:_SetActionButtonsEnabled(false)
end

function R:HideStreakPrompt()
    if self._streakPrompt then self._streakPrompt:Hide() end
    self:_SetActionButtonsEnabled(true)
end

-- ── ShowPushFeedback ──────────────────────────────────────────
function R:ShowPushFeedback()
    if not self._stateLbl then return end
    self._stateLbl:SetText(L("result_push"))
    local E = ArcadiaNexus.HOL_Engine
    if not E or not E._timerGuard then return end
    E._timerGuard:After(1.2, function()
        if self._stateLbl then self._stateLbl:SetText(L("state_playing")) end
    end)
end

-- ── ShowResult / ShowGameOver ─────────────────────────────────
function R:ShowResult(gs, reason, amount)
    if not self._playfield then return end
    if self._streakPrompt then self._streakPrompt:Hide() end
    self:_SetActionButtonsEnabled(false)
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end

    local UI     = ArcadiaNexus.UI
    local loc    = ArcadiaNexus.GetLocaleTable("HIGHERORLOWER")
    local parent = self._playfield

    local title, titleColor, goldVal, result
    if reason == "LOSS" then
        title      = FormatStr(L("result_wrong"), amount)
        titleColor = {0.9, 0.3, 0.3}
        goldVal    = -amount
        result     = "LOSS"
    elseif reason == "CASHOUT" or reason == "CASHOUT_AUTO" then
        local lbl  = reason == "CASHOUT_AUTO" and L("result_deck_empty") or L("result_cashout")
        title      = FormatStr(lbl, amount)
        titleColor = {0.3, 0.9, 0.3}
        goldVal    = amount
        result     = "WIN"
    else
        title      = reason
        titleColor = {0.8, 0.8, 0.8}
        goldVal    = nil
        result     = nil
    end

    UI.ShowResultDialog({
        parent     = parent,
        title      = title,
        titleColor = titleColor,
        subtitle   = L("lbl_capital") .. ": " .. gs.chips .. "g",
        gold       = goldVal,
        score      = (reason == "CASHOUT" or reason == "CASHOUT_AUTO") and amount or nil,
        gameId     = "HIGHERORLOWER",
        difficulty = gs.difficulty,
        hideHighscore = reason == "LOSS",
        result     = result,
        buttons    = UI.ResultDialogButtons.Round(loc,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.HOL_Engine
                if E then E:NewRound() end
            end,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.HOL_Engine
                if E then E:StopGame() end
            end),
    })
end

function R:ShowGameOver(gs)
    if not self._playfield then return end
    if self._streakPrompt then self._streakPrompt:Hide() end
    self:_SetActionButtonsEnabled(false)
    local UI     = ArcadiaNexus.UI
    local loc    = ArcadiaNexus.GetLocaleTable("HIGHERORLOWER")
    local parent = self._playfield

    UI.ShowResultDialog({
        parent     = parent,
        title      = L("state_gameover"),
        titleColor = {0.9, 0.2, 0.2},
        subtitle   = L("lbl_capital") .. ": 0g",
        gameId     = "HIGHERORLOWER",
        difficulty = gs and gs.difficulty,
        hideHighscore = true,
        result     = "LOSS",
        buttons    = UI.ResultDialogButtons.Bankrupt(loc,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.HOL_Engine
                local S = ArcadiaNexus.HOL_Settings
                if E and S then
                    E:StartGame({ difficulty = (gs and gs.difficulty) or S:Get("difficulty") })
                end
            end,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.HOL_Engine
                if E then E:StopGame() end
            end),
    })
end

-- ── UpdateHUD ─────────────────────────────────────────────────
function R:UpdateHUD(gs)
    if not gs then return end
    local E = ArcadiaNexus.HOL_Engine

    if self._capitalLbl then
        self._capitalLbl:SetText(L("lbl_capital") .. ": " .. gs.chips .. "g")
    end
    if self._betLbl then
        local bet = gs.bet or 0
        self._betLbl:SetText(bet > 0 and (L("lbl_bet") .. ": " .. bet .. "g") or "")
    end
    if self._streakLbl then
        self._streakLbl:SetText(gs.streak > 0 and (L("lbl_streak") .. ": " .. gs.streak) or "")
    end
    if self._multLbl then
        local Logic = ArcadiaNexus.HOL_Logic
        self._multLbl:SetText(gs.streak > 0 and Logic
            and (L("lbl_multiplier") .. ": x" .. Logic:GetMultiplier(gs.streak)) or "")
    end
    if self._pendingLbl then
        self._pendingLbl:SetText(gs.pendingWin > 0
            and (L("lbl_pending") .. ": +" .. gs.pendingWin .. "g") or "")
    end

    -- Chips: klickbar nur im BETTING-State
    local isBetting = E and E.state == "BETTING"
    for _, btn in ipairs(self._chipStackBtns) do
        btn:SetAlpha(isBetting and 1.0 or 0.3)
        btn:EnableMouse(isBetting)
    end

    -- "Ziehen"-Button: sichtbar im BETTING wenn bet > 0
    if self.actionBtns.draw then
        local showDraw = isBetting and (gs.bet or 0) > 0
        self.actionBtns.draw:SetShown(showDraw)
        if showDraw then self.actionBtns.draw:Enable() end
    end

    -- Reset-Button: nur bei Bankrott-Nähe im BETTING
    if self.actionBtns.resetChips then
        self.actionBtns.resetChips:SetShown(isBetting and gs.chips < 25 or false)
    end
end

-- ── OnStateChanged ────────────────────────────────────────────
function R:OnStateChanged(newState)
    local labels = {
        IDLE          = L("state_idle"),
        BETTING       = L("state_betting"),
        PLAYING       = L("state_playing"),
        STREAK_PROMPT = L("state_streak_prompt"),
        RESULT        = "",
        GAMEOVER      = L("state_gameover"),
    }
    if self._stateLbl then
        self._stateLbl:SetText(labels[newState] or "")
    end

    -- Higher/Lower: nur in PLAYING aktiv
    self:_SetActionButtonsEnabled(newState == "PLAYING")

    if newState == "BETTING" then
        if self._streakPrompt  then self._streakPrompt:Hide() end
        if self._playfield and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(self._playfield)
        end
        if self._aceLbl        then self._aceLbl:SetText("") end
        -- Chips ausgegraut (UpdateHUD übernimmt das)
        -- Ziehen-Button versteckt bis bet > 0 (UpdateHUD)
    end

    if newState == "PLAYING" then
        -- Ziehen-Button weg (erste Karte wurde gezogen)
        if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    end
end

-- ── Game-Lifecycle ────────────────────────────────────────────
function R:OnGameStarted(gs)
    R.state = "PLAYING"
    if self._logo          then self._logo:Hide()          end
    if self._prevCardF     then self._prevCardF:Hide()     end
    if self._currCardF     then self._currCardF:Hide()     end
    if self._streakPrompt  then self._streakPrompt:Hide()  end
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    self:_ClearWasteChips()
    -- Spielfeld-Hintergrund
    if self._bgTex then
        self._bgTex:SetTexture(HOL_PATH .. "background\\background")
    end
    -- Spielelemente einblenden
    if self._capitalBox then self._capitalBox:Show() end
    for _, btn in ipairs(self._chipStackBtns) do btn:Show() end
    if self.actionBtns.lower  then self.actionBtns.lower:Show()  end
    if self.actionBtns.higher then self.actionBtns.higher:Show() end

    self:UpdateHUD(gs)
    if self._diffDD then
        self._diffDD:SetText(L("diff_" .. (gs.difficulty or "easy")))
    end
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_exit")) end
end

function R:OnGameStopped()
    R.state = "IDLE"
    if self._logo          then self._logo:Show()          end
    if self._prevCardF     then self._prevCardF:Hide()     end
    if self._currCardF     then self._currCardF:Hide()     end
    if self._streakPrompt  then self._streakPrompt:Hide()  end
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    self:_ClearWasteChips()
    -- Spielelemente verstecken
    if self._capitalBox then self._capitalBox:Hide() end
    for _, btn in ipairs(self._chipStackBtns) do btn:Hide() end
    if self.actionBtns.lower  then self.actionBtns.lower:Hide()  end
    if self.actionBtns.higher then self.actionBtns.higher:Hide() end
    for _, key in ipairs({"_stateLbl","_capitalLbl","_betLbl","_streakLbl","_multLbl","_pendingLbl","_aceLbl"}) do
        if self[key] then self[key]:SetText("") end
    end
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_start")) end
end

function R:OnNewRound(gs)
    if self._prevCardF  then self._prevCardF:Hide() end
    if self._currCardF  then self._currCardF:Hide() end
    if self._streakPrompt  then self._streakPrompt:Hide() end
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self._aceLbl        then self._aceLbl:SetText("") end
    self:_ClearWasteChips()
    -- Ziehen-Button wird durch UpdateHUD gesteuert (bet=0 → versteckt)
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    self:UpdateHUD(gs)
end

-- ── Hilfsfunktionen ───────────────────────────────────────────
function R:_SetActionButtonsEnabled(enabled)
    for _, key in ipairs({"higher", "lower"}) do
        local btn = self.actionBtns[key]
        if btn then
            if enabled then btn:Enable() else btn:Disable() end
        end
    end
end

function R:_EnterIdleState()
    if self._prevCardF     then self._prevCardF:Hide()     end
    if self._currCardF     then self._currCardF:Hide()     end
    if self._streakPrompt  then self._streakPrompt:Hide()  end
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
    if self.actionBtns.draw then self.actionBtns.draw:Hide() end
    self:_SetActionButtonsEnabled(false)
    if self.actionBtns.resetChips then self.actionBtns.resetChips:Hide() end
    if self._capitalBox then self._capitalBox:Hide() end
    for _, btn in ipairs(self._chipStackBtns) do btn:Hide() end
    if self.actionBtns.lower  then self.actionBtns.lower:Hide()  end
    if self.actionBtns.higher then self.actionBtns.higher:Hide() end
    if self._logo then self._logo:Show() end
end
