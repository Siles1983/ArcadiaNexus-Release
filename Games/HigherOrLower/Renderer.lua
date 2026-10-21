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

}

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "HIGHERORLOWER",
    label     = "Higher or Lower",
    category  = "KARTEN",
    renderer  = "HOL_Renderer",
    engine    = "HOL_Engine",
    container = "_holContainer",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\HigherOrLower\\Assets\\logo\\logo_hol",
    xp        = 10,
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
local CHIP_WASTE_Y = 272

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
    local joker=currF:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    joker:SetPoint("CENTER",currF,"CENTER",0,0); joker:SetText("JOKER"); joker:Hide(); currF._jokerLabel=joker

    local prevCap = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prevCap:SetPoint("TOP", prevF, "BOTTOM", 0, -3)
    prevCap:SetText(L("previous_card"))
    prevCap:SetTextColor(0.65, 0.60, 0.45)

    local currCap = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currCap:SetPoint("TOP", currF, "BOTTOM", 0, -3)
    currCap:SetText(L("current_card"))
    currCap:SetTextColor(0.85, 0.80, 0.55)
end

-- ── HUD ───────────────────────────────────────────────────────
function R:_CreateHUD()
    local canvas=self._canvas; if not canvas then return end
    self._capitalBox,self._capitalLbl=ArcadiaNexus.UI.CreateHudStatBox(canvas,{
        w=190,h=28,point="TOP",x=0,y=-4,shown=false,
    })
    local fields={
        {"_stateLbl",-35,"GameFontNormalLarge"},{"_aceLbl",-55,"GameFontNormalSmall"},
        {"_betLbl",-82,"GameFontNormal"},{"_streakLbl",-108,"GameFontNormal"},
        {"_multLbl",-132,"GameFontNormalSmall"},{"_pendingLbl",-157,"GameFontNormal"},
        {"_netLbl",-185,"GameFontNormalSmall"},
    }
    for _,field in ipairs(fields) do
        local fs=canvas:CreateFontString(nil,"OVERLAY",field[3]); fs:SetPoint("TOP",canvas,"TOP",0,field[2])
        fs:SetWidth(212); fs:SetJustifyH("CENTER"); fs:SetTextColor(0.95,0.85,0.4); self[field[1]]=fs
    end
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

            if button=="RightButton" then E:AdjustBet(-slotRef.value)
            else E:AdjustBet(slotRef.value) end
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
    self._wasteBet2,self._wasteTableId=nil,nil
end

-- Preserve every unaffected chip; only added chips receive new scatter offsets.
function R:_SyncWasteChips(gs)
    if self._wasteTableId~=gs.tableId then self:_ClearWasteChips() end
    local delta=(gs.bet2-(self._wasteBet2 or 0))/2
    local function AddAmount(amount,restoreLimit)
        for i=#CHIP_SLOTS,1,-1 do
            local slot=CHIP_SLOTS[i]
            while amount>=slot.value and (not restoreLimit or #self._chipWastePile<restoreLimit) do
                self:_AddWasteChip(slot.color,CHIP_ATLAS[slot.color].coords[1],slot.value)
                amount=amount-slot.value
            end
        end
    end
    if delta>0 then AddAmount(delta,self._wasteBet2==nil and 24 or nil)
    elseif delta<0 then
        local remaining=-delta
        -- Right-clicking a denomination takes back its most recently placed chip first.
        for i=#self._chipWastePile,1,-1 do
            local chip=self._chipWastePile[i]
            if chip._value==remaining then
                self._wasteChipPool:Release(chip); table.remove(self._chipWastePile,i)
                remaining=0; break
            end
        end
        -- Remove exact/smaller chips first, without rebuilding or repositioning the survivors.
        for i=#self._chipWastePile,1,-1 do
            local chip=self._chipWastePile[i]
            if chip._value<=remaining then
                remaining=remaining-chip._value
                self._wasteChipPool:Release(chip); table.remove(self._chipWastePile,i)
            end
            if remaining==0 then break end
        end
        if remaining>0 and #self._chipWastePile>0 then
            -- A partial denomination withdrawal replaces only that chip with its change.
            local chip=table.remove(self._chipWastePile)
            local change=chip._value-remaining
            self._wasteChipPool:Release(chip)
            if change>0 then AddAmount(change) end
        end
    end
    self._wasteBet2,self._wasteTableId=gs.bet2,gs.tableId
end

-- Persistent actions: the cashout choice never covers the cards.
function R:_CreateActionButtons()
    local UI=ArcadiaNexus.UI
    local specs={
        {"lower","btn_lower",96,352,144,function() ArcadiaNexus.HOL_Engine:Guess("LOWER") end},
        {"draw","btn_draw",256,352,80,function() ArcadiaNexus.HOL_Engine:DealFirstCard() end},
        {"higher","btn_higher",352,352,144,function() ArcadiaNexus.HOL_Engine:Guess("HIGHER") end},
        {"cashout","btn_cashout",226,394,144,function() ArcadiaNexus.HOL_Engine:CashOut() end},
    }
    for _,spec in ipairs(specs) do
        local btn=UI.CreateArcadiaButton(self._canvas,L(spec[2]),spec[5],32)
        btn:SetPoint("TOPLEFT",self._canvas,"TOPLEFT",spec[3],-spec[4]); btn:SetScript("OnClick",spec[6])
        btn:Hide(); self.actionBtns[spec[1]]=btn
    end
end
function R:_CreateBottomBar()
    local UI=ArcadiaNexus.UI; local bar=UI.CreateGameControlsBar(self.frame,"narrow")
    local cf=bar.frame; self._controlsFrame=cf
    local anchor=CreateFrame("Frame",nil,cf); anchor:SetSize(140,32)
    anchor:SetPoint("CENTER",cf,"CENTER",bar.segX[1],bar.y.dropdownOfs)
    self._diffDD=UI.CreateSimpleDropdown(anchor,0,0,140,nil,{
        {key="standard",label=L("variant_standard")},{key="joker",label=L("variant_joker")},
    },function() return ArcadiaNexus.HOL_Settings:Get("variant") end,
    function(key) ArcadiaNexus.HOL_Engine:SetVariant(key) end)
    local btn=UI.CreateArcadiaButton(cf,L("btn_start"),144,32)
    btn:SetPoint("BOTTOM",cf,"BOTTOM",bar.segX[2],bar.y.button)
    btn:SetScript("OnClick",function()
        local E=ArcadiaNexus.HOL_Engine
        if E.gameState then E:SaveAndPause()
        elseif R.state=="SLOT_MENU" then R:OnGameStopped()
        else R:ShowSlots() end
    end)
    self._toggleBtn=btn; self.actionBtns.start=btn
    -- Keyboard capture is local to this visible game and respects UI overlays.
    self.frame:EnableKeyboard(true); self.frame:SetPropagateKeyboardInput(true)
    self.frame:SetScript("OnKeyDown",function(frame,key)
        frame:SetPropagateKeyboardInput(true)
        local A=ArcadiaNexus; local E=A.HOL_Engine; local GI=A.GameInput
        if not A.GameSession:IsSession(E,E._sessionId) or not E.gameState then return end
        if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
        if GI and (GI._overlayMode or (GI._keyboardOverlays and #GI._keyboardOverlays>0)) then return end
        if E:HandleKey(key) then frame:SetPropagateKeyboardInput(false) end
    end)
end
local function ApplyCardToFrame(cardF,cardTex,card,alpha)
    if not card then cardF:Hide(); return end
    if card.isJoker then
        cardF:SetBackdropColor(0.5,0.05,0.05,1); cardTex:SetTexture(nil)
    else cardF:SetBackdropColor(0.95,0.93,0.88,1); cardTex:SetTexture(CardTexPath(card)) end
    if cardF._jokerLabel then cardF._jokerLabel:SetShown(card.isJoker or false) end
    cardF:SetAlpha(alpha or 1); cardF:Show()
end
function R:RestoreBoard(gs)
    if self._slotMenu then self._slotMenu:Hide() end
    self.state=gs.phase; if self._logo then self._logo:Hide() end
    ArcadiaNexus.UI.HideResultDialog(self._playfield)
    self._capitalBox:Show()
    if self._diffDD then self._diffDD:SetText(L("variant_"..gs.variant)); self._diffDD:SetEnabled(false) end
    self._toggleBtn:SetLabel(L("btn_exit"))
    ApplyCardToFrame(self._prevCardF,self._prevCardTex,gs.previousCard,0.65)
    ApplyCardToFrame(self._currCardF,self._currCardTex,gs.currentCard,1)
    self:_SyncWasteChips(gs)
    self:UpdateHUD(gs)
end
function R:UpdateHUD(gs)
    local F=ArcadiaNexus.Format; local E=ArcadiaNexus.HOL_Engine
    self._capitalLbl:SetText(L("lbl_capital")..": "..F.HalfUnits(gs.chips2).." "..L("lbl_gold"))
    self._betLbl:SetText(L("lbl_bet")..": "..F.HalfUnits(gs.bet2))
    self._streakLbl:SetText(L("lbl_streak")..": "..gs.streak)
    local mult=ArcadiaNexus.HOL_Logic:GetMultiplier(gs.streak,gs.variant)
    self._multLbl:SetText(FormatStr(L("profit_factor"),mult))
    self._pendingLbl:SetText(L("lbl_pending")..": "..F.HalfUnits(gs.payout2))
    self._aceLbl:SetText(gs.currentCard and gs.currentCard.rank=="A" and L("ace_high") or "")
    self._stateLbl:SetText(gs.lastOutcome=="PUSH" and L("result_push") or L("state_"..string.lower(gs.phase)))
    local betting=gs.phase=="BETTING"; local playing=gs.phase=="PLAYING"
    for _,btn in ipairs(self._chipStackBtns) do btn:Show(); btn:SetAlpha(betting and 1 or 0.3); btn:EnableMouse(betting) end
    for _,key in ipairs({"lower","higher"}) do
        local btn=self.actionBtns[key]; btn:Show(); if playing then btn:Enable() else btn:Disable() end
    end
    self.actionBtns.draw:SetShown(betting and gs.bet2>=50)
    self.actionBtns.cashout:SetShown(playing and gs.streak>0)
    if playing and gs.streak>0 then self.actionBtns.cashout:Enable() end
    if gs.streak>0 and self._netLbl then self._netLbl:SetText(L("lbl_net")..": +"..F.HalfUnits(gs.payout2-gs.bet2))
    elseif self._netLbl then self._netLbl:SetText("") end
end
function R:OnStateChanged(state) self.state=state end
function R:OnGameStarted(gs) self:RestoreBoard(gs) end
function R:OnGameStopped()
    self.state="IDLE"
    if self._slotMenu then self._slotMenu:Hide() end
    if self._prevCardF then self._prevCardF:Hide() end
    if self._currCardF then self._currCardF:Hide() end
    if self._capitalBox then self._capitalBox:Hide() end
    for _,btn in ipairs(self._chipStackBtns) do btn:Hide() end
    for _,key in ipairs({"draw","lower","higher","cashout"}) do if self.actionBtns[key] then self.actionBtns[key]:Hide() end end
    for _,key in ipairs({"_stateLbl","_betLbl","_streakLbl","_multLbl","_pendingLbl","_aceLbl","_netLbl"}) do
        if self[key] then self[key]:SetText("") end
    end
    if self._playfield then ArcadiaNexus.UI.HideResultDialog(self._playfield) end
    self:_ClearWasteChips()
    if self._logo then self._logo:Show() end
    if self._diffDD then self._diffDD:SetEnabled(true); self._diffDD:SetText(L("variant_"..ArcadiaNexus.HOL_Settings:Get("variant"))) end
    if self._toggleBtn then self._toggleBtn:SetLabel(L("btn_start")) end
end
function R:_EnterIdleState() self:OnGameStopped() end
function R:ShowSlots()
    self:OnGameStopped(); self._logo:Hide(); self.state="SLOT_MENU"; self._toggleBtn:SetLabel(L("btn_exit"))
    local A=ArcadiaNexus; local S=A.HOL_Settings; local loc=A.GetLocaleTable("HIGHERORLOWER")
    self._slotMenu=A.UI.CreateSaveSlotMenu({parent=self._canvas,maxSlots=3,L=loc,
        loadSlot=function(slot) return S:LoadSlot(slot) end,
        deleteSlot=function(slot) return S:DeleteSlot(slot) end,
        canContinue=function(save) return A.HOL_Engine:CanContinueSave(save) end,
        formatInfo=function(save)
            if not A.HOL_Logic:ValidateSave(save) then return L("slot_invalid") end
            return L("variant_"..save.variant).." · "..A.Format.HalfUnits(save.chips2).." "..L("lbl_gold").." · "..L("state_"..string.lower(save.phase))
        end,
        isPaused=function(save) return save.phase~="GAMEOVER" end,
        onNewGame=function(slot) return A.HOL_Engine:StartGame({slot=slot,overwrite=true}) end,
        onContinue=function(slot) return A.HOL_Engine:StartGame({slot=slot,mode="continue"}) end,
        onCancel=function() R:OnGameStopped() end,
    }); self._slotMenu:Show()
end
function R:ShowResultPending(gs)
    local A=ArcadiaNexus
    A.UI.ShowResultDialog({parent=self._playfield,title=L("state_result_pending"),subtitle=L("result_retry"),
        gameId="HIGHERORLOWER",hideHighscore=true,buttons={
            {label=L("btn_retry"),onClick=function() A.HOL_Engine:RetryResult() end},
            {label=L("btn_exit"),onClick=function() A.HOL_Engine:SaveAndPause() end},
        }})
end
function R:ShowResult(gs)
    local A=ArcadiaNexus; local UI=A.UI; local F=A.Format; local loc=A.GetLocaleTable("HIGHERORLOWER")
    local E=A.HOL_Engine; local awarded=E._lastResult or {}; local bankrupt=gs.phase=="GAMEOVER"
    local function Exit() E:SaveAndPause() end
    local buttons=bankrupt and UI.ResultDialogButtons.Bankrupt(loc,function() Exit(); R:ShowSlots() end,Exit)
        or UI.ResultDialogButtons.Round(loc,function() E:NewRound() end,Exit)
    UI.ShowResultDialog({parent=self._playfield,title=L(bankrupt and "state_gameover" or "result_"..string.lower(gs.reason)),
        subtitle=L("lbl_bet")..": "..F.HalfUnits(gs.bet2).." · "..L("lbl_pending")..": "..F.HalfUnits(gs.return2)
            .."\n"..L("lbl_net")..": "..(gs.net2>0 and "+" or "")..F.HalfUnits(gs.net2)
            .." · "..L("lbl_capital")..": "..F.HalfUnits(gs.chips2).." "..L("lbl_gold")
            .."\n"..L("lbl_streak")..": "..gs.roundBest,
        gameId="HIGHERORLOWER",difficulty=gs.variant,hideHighscore=true,
        xp=awarded.awardedXP or 0,gold=awarded.awardedGold or 0,
        result=gs.net2>0 and "WIN" or gs.net2<0 and "LOSS" or "DRAW",buttons=buttons,
    })
end
