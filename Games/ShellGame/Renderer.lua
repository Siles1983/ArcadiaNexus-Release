-- ============================================================
--  ShellGame – Renderer.lua
--  UI-Darstellung: Becher, Animation, Bet-System, Overlays.
--  KEINE Spiellogik hier.
--
--  Becher-Modell:
--    _cups[becherIdx]      = { frame, tex, ballFrame, btn }
--    _slotX[slotIdx]       = x-Position (feste Tischpositionen)
--    _cupAtSlot[slotIdx]   = becherIdx
--    _slotOfCup[becherIdx] = slotIdx
--
--  gs.ballCup ist ein becherIdx — bleibt korrekt durch Logic:SwapCups.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SHG_Renderer = {}
local R = ArcadiaNexus.SHG_Renderer

-- ── CFG ───────────────────────────────────────────────────────
local CFG = {
    -- Spielfeld
    field_w       = 600,
    field_h       = 320,
    field_ofs_x   = 0,
    field_ofs_y   = -30,   -- TOP-Anker-Offset (negativ = nach unten)

    -- Hintergrund (TGA)
    bg_w          = 750,
    bg_h          = 500,
    bg_ofs_x      = 5,
    bg_ofs_y      = -35,
    bg_alpha      = 1.0,

    -- Border (TGA)
    border_w      = 800,
    border_h      = 547,
    border_ofs_x  = 0,
    border_ofs_y  = 56,

    -- Logo (TGA)
    logo_w        = 300,
    logo_h        = 300,
    logo_ofs_x    = 0,
    logo_ofs_y    = -20,

    -- Becher
    cup_w              = 180,
    cup_h              = 180,
    cup_y              = 0,
    cup_gap            = 0,
    cup_reveal_lift    = 110,   -- Höhe über Endposition beim REVEAL-Start
    cup_drop_duration  = 0.5,   -- Sekunden für die Drop-Animation

    -- Kugel
    ball_r             = 20,
    ball_mid_y         = 0,     -- Y-Position der Kugel (Mitte des Bechers)

    -- Chip-System (Positionen relativ zu frame TOPLEFT, wie Blackjack)
    chip_stack_y  = 390,   -- y nach unten von TOPLEFT für Stapel-Chips
    chip_bet_x    = 280,   -- Basis-X für Bet-Chip-Stapel
    chip_bet_y    = 288,   -- Basis-Y für Bet-Chip-Stapel
    chip_size     = 48,
    -- Stapel-X-Positionen (relativ zu frame TOPLEFT)
    chip_slots_x  = { 160, 224, 320, 384 },

    -- Controls-Widgets
    dd_w          = 120,
    btn_w         = 144,
    btn_h         = 32,

    -- HUD
    cap_lbl_x     = -10,
    cap_lbl_y     = -8,
    cap_lbl_w     = 160,
    cap_lbl_h     = 28,

    -- State-Label (oben im Spielfeld)
    state_lbl_x   = 0,     -- X-Offset von CENTER
    state_lbl_y   = -8,    -- Y-Offset von TOP (negativ = nach unten)

    -- Einsatz-Label (relativ zu TOPLEFT des MainFrame)
    bet_lbl_x     = 255,    -- X-Offset von TOPLEFT
    bet_lbl_y     = 410,    -- Y-Offset nach unten von TOPLEFT (positiv = nach unten)
    bet_lbl_w     = 200,
    bet_lbl_h     = 28,

    -- Einsatz-Reset-Button (relativ zu TOPLEFT des MainFrame)
    bet_reset_x   = 280,    -- X-Offset: mittig zwischen Chip-Slot 2 und 3
    bet_reset_y   = 350,    -- Y-Offset: gleich wie chip_stack_y
    bet_reset_size = 26,

    -- Overlay
    ov_w          = 320,
    ov_h          = 180,
    ov_title_y    = -24,
    ov_sub_gap    = -28,
    ov_btn_gap    = -70,
    ov_btn_w      = 130,
    ov_btn_h      = 28,
}

-- ── Registrierung ─────────────────────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "SHELLGAME",
    label     = "Gadgetzan Cup Shuffle",
    category  = "GESCHICK",
    renderer  = "SHG_Renderer",
    engine    = "SHG_Engine",
    container = "_shgContainer",
})

-- ── Asset-Pfade ───────────────────────────────────────────────
local ADDON_PATH   = "Interface\\AddOns\\ArcadiaNexus\\Games\\ShellGame\\Assets\\"
local SHARED_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Shared\\"
local SHARED_CHIPS = SHARED_PATH .. "Chips\\"

local ASSET_BORDER = ADDON_PATH .. "border\\border_gcs"
local ASSET_LOGO   = ADDON_PATH .. "logo\\logo_gcs"
local ASSET_BG     = ADDON_PATH .. "background\\bg_gcs"

local BALL_ASSETS = {
    blue    = ADDON_PATH .. "ball\\blue_ball",
    green   = ADDON_PATH .. "ball\\green_ball",
    red     = ADDON_PATH .. "ball\\red_ball",
    violett = ADDON_PATH .. "ball\\violett_ball",
    yellow  = ADDON_PATH .. "ball\\yellow_ball",
}

-- ── Atlas-Definitionen ────────────────────────────────────────
local SLOT_COORDS = {
    { 0.0, 0.5, 0.0, 0.5 },
    { 0.5, 1.0, 0.0, 0.5 },
    { 0.0, 0.5, 0.5, 1.0 },
    { 0.5, 1.0, 0.5, 1.0 },
}

local function MakeThemes(prefix, faction, atlasCount)
    local themes = {}
    local n = 1
    for atlas = 1, atlasCount do
        local file = ADDON_PATH .. faction .. "\\2x2_" .. prefix .. "_atlas_0" .. atlas
        for slot = 1, 4 do
            table.insert(themes, {
                key    = faction:lower():sub(1,3) .. "_" .. string.format("%02d", n),
                label  = faction .. " " .. n,
                file   = file,
                coords = SLOT_COORDS[slot],
            })
            n = n + 1
        end
    end
    return themes
end

local ALL_THEMES = {}
local THEME_MAP  = {}
for _, t in ipairs(MakeThemes("alliance", "Alliance", 3)) do
    table.insert(ALL_THEMES, t); THEME_MAP[t.key] = t
end
for _, t in ipairs(MakeThemes("horde", "Horde", 3)) do
    table.insert(ALL_THEMES, t); THEME_MAP[t.key] = t
end
for _, t in ipairs(MakeThemes("neutral", "Neutral", 1)) do
    table.insert(ALL_THEMES, t); THEME_MAP[t.key] = t
end

-- ── Chip-Atlas ────────────────────────────────────────────────
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

local CHIP_SLOTS = {
    { color="green",  value=25  },
    { color="red",    value=50  },
    { color="blue",   value=100 },
    { color="yellow", value=500 },
}

local CHIP_SIZE = 48

local _animLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_SHG_AnimLoop")

local function StartAnimLoop(tickFn)
    _animLoop:Stop()
    _animLoop:Start(tickFn, { maxDt = 0.1 })
end

local function StopAnimLoop()
    _animLoop:Stop()
end

-- ── Renderer-State ────────────────────────────────────────────
R.frame            = nil
R._canvas          = nil
R._fieldFrame      = nil
R._controlsFrame   = nil
R._bgTex           = nil
R._logoTex         = nil
R._stateLbl        = nil
R._capitalBox      = nil
R._capitalLbl      = nil
R._betDisplay      = nil
R._toggleBtn       = nil
R._roundBtn        = nil
-- Becher: stable by becherIdx
R._cups            = {}   -- [becherIdx] = { frame, tex, ballFrame }
R._slotX           = {}   -- [slotIdx] = x-Position
R._cupAtSlot       = {}   -- [slotIdx] = becherIdx
R._slotOfCup       = {}   -- [becherIdx] = slotIdx
R._slotBtns        = {}   -- [slotIdx] = unsichtbarer Button, fest an Slot-Position
R._cupPool         = nil
R._slotPool        = nil
-- Chip-System (Blackjack-Pattern)
R._chipStackBtns   = {}
R._chipStackTexs   = {}
R._chipBetFrames   = {}   -- Pool dynamischer Bet-Chip-Frames
R._continueOverlay = nil

-- ── Helpers ───────────────────────────────────────────────────
local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("SHELLGAME")
    return (tbl and tbl[key]) or key
end

local function FormatStr(template, ...)
    local args = {...}
    return (template:gsub("{(%d+)}", function(i)
        return tostring(args[tonumber(i)+1] or "")
    end))
end

local function GetCurrentTheme()
    local S      = ArcadiaNexus.SHG_Settings
    local key    = S and S:Get("theme")      or "ali_01"
    local group  = S and S:Get("themeGroup") or "alliance"
    if key == "random" then
        -- Nur innerhalb der aktiven Gruppe zufällig wählen
        local pool = {}
        for _, t in ipairs(ALL_THEMES) do
            if t.key:sub(1,3) == group:sub(1,3) then
                table.insert(pool, t)
            end
        end
        if #pool > 0 then return pool[math.random(1, #pool)] end
        return ALL_THEMES[1]
    end
    return THEME_MAP[key] or ALL_THEMES[1]
end

local BALL_KEYS = { "blue", "green", "red", "violett", "yellow" }

local function GetBallAsset()
    local S   = ArcadiaNexus.SHG_Settings
    local key = S and S:Get("ball") or "yellow"
    if key == "random" then
        key = BALL_KEYS[math.random(1, #BALL_KEYS)]
    end
    return BALL_ASSETS[key] or BALL_ASSETS.yellow
end

local function SetCupTexture(tex, theme)
    if not tex or not theme then return end
    tex:SetTexture(theme.file)
    local c = theme.coords
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
end

local function SetRandomChipVariant(tex, color)
    local atlas = CHIP_ATLAS[color]
    if not atlas then return end
    local v = atlas.coords[math.random(1, #atlas.coords)]
    tex:SetTexture(atlas.file)
    tex:SetTexCoord(v[1], v[2], v[3], v[4])
end

local function CreateBetChipPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ShellGame.BetChips",
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

local function CreateCupPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ShellGame.Cups",
        create = function(poolParent)
            poolParentRef = poolParent
            local cf = CreateFrame("Frame", nil, poolParent)
            cf._tex = cf:CreateTexture(nil, "ARTWORK")
            cf._tex:SetAllPoints(cf)

            local ballF = CreateFrame("Frame", nil, poolParent)
            ballF._tex = ballF:CreateTexture(nil, "ARTWORK")
            ballF._tex:SetAllPoints(ballF)
            cf._ballFrame = ballF
            return cf
        end,
        onRelease = function(cf)
            cf:Hide()
            cf:ClearAllPoints()
            cf:SetAlpha(1)
            cf:SetScale(1)
            if cf._tex then
                cf._tex:SetVertexColor(1, 1, 1, 1)
            end
            if cf._ballFrame then
                cf._ballFrame:Hide()
                cf._ballFrame:ClearAllPoints()
                cf._ballFrame:SetAlpha(1)
                if cf._ballFrame._tex then
                    cf._ballFrame._tex:SetVertexColor(1, 1, 1, 1)
                end
            end
            if poolParentRef then
                cf:SetParent(poolParentRef)
                if cf._ballFrame then cf._ballFrame:SetParent(poolParentRef) end
            end
        end,
    })
end

local function CreateSlotPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ShellGame.SlotButtons",
        create = function(poolParent)
            poolParentRef = poolParent
            local btn = CreateFrame("Button", nil, poolParent)
            btn:SetAlpha(0)
            btn:RegisterForClicks("LeftButtonUp")
            btn:SetScript("OnClick", function(self)
                local E = ArcadiaNexus.SHG_Engine
                if E and self._slotIdx then
                    E:MakeGuess(self._slotIdx)
                end
            end)
            return btn
        end,
        onRelease = function(btn)
            btn:Hide()
            btn:ClearAllPoints()
            btn:EnableMouse(false)
            btn._slotIdx = nil
            btn:SetAlpha(0)
            if poolParentRef then btn:SetParent(poolParentRef) end
        end,
    })
end

local function CalcSlotX(count)
    local step   = CFG.cup_w + CFG.cup_gap
    local total  = count * CFG.cup_w + (count - 1) * CFG.cup_gap
    local startX = -(total / 2) + CFG.cup_w / 2
    local pos    = {}
    for i = 1, count do pos[i] = startX + (i - 1) * step end
    return pos
end

local function MoveCupToX(cup, ff, x)
    cup.frame:ClearAllPoints()
    cup.frame:SetPoint("CENTER", ff, "CENTER", x, CFG.cup_y)
    cup.ballFrame:ClearAllPoints()
    cup.ballFrame:SetPoint("CENTER", ff, "CENTER", x, CFG.ball_mid_y)
end

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    self:_CreateMainFrame()
    self:_CreateBorder()
    self:_CreatePlayfield()
    self:_CreateLogo()
    self:_CreateStatusBar()
    self:_CreateChipSystem()
    self:_CreateControls()
    self:_CreateContinueOverlay()
    self:EnterIdleState()
end

-- ── Hauptframe ────────────────────────────────────────────────
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_SHG_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._shgContainer = f end
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("SHELLGAME", ArcadiaNexus.SHG_Engine, function(E)
            if E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
        R:EnterIdleState()
    end)
end

-- ── Border ────────────────────────────────────────────────────
function R:_CreateBorder()
    local f = self._canvas; if not f then return end
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(CFG.border_w, CFG.border_h)
    b:SetPoint("TOP", f, "TOP", CFG.border_ofs_x, CFG.border_ofs_y - 16)
    -- FrameLevel explizit über dem _fieldFrame setzen (der keinen expliziten Level hat,
    -- also auf dem Basis-Level des parent liegt). +5 reicht, da _fieldFrame kein Level hat.
    b:SetFrameLevel(f:GetFrameLevel() + 5)
    local tex = b:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(b)
    tex:SetTexture(ASSET_BORDER)
end

-- ── Spielfeld ─────────────────────────────────────────────────
-- Analog zu ArcadiaRows: TOP-Anker, feste Größe, kein SetAllPoints
function R:_CreatePlayfield()
    local f = self._canvas; if not f then return end

    local pf = CreateFrame("Frame", nil, f)
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("TOP", f, "TOP", CFG.field_ofs_x, CFG.field_ofs_y)

    -- Hintergrund-Textur (TGA)
    local bgTex = pf:CreateTexture(nil, "BACKGROUND")
    bgTex:SetSize(CFG.bg_w, CFG.bg_h)
    bgTex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    bgTex:SetTexture(ASSET_BG)
    bgTex:SetAlpha(CFG.bg_alpha)
    self._bgTex     = bgTex
    self._fieldFrame = pf
    pf:Show()
end

-- ── Logo ──────────────────────────────────────────────────────
function R:_CreateLogo()
    local ff = self._fieldFrame; if not ff then return end
    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGameLogo then
        self._logoTex = UI.CreateGameLogo(ff, ASSET_LOGO,
            { w=CFG.logo_w, h=CFG.logo_h, x=CFG.logo_ofs_x, y=CFG.logo_ofs_y })
    end
end

-- ── Status-Bar ────────────────────────────────────────────────
function R:_CreateStatusBar()
    local f = self._canvas; if not f then return end
    local UI = ArcadiaNexus.UI
    local BOX_ALPHA = UI and UI.BOX_ALPHA or 0.55

    -- Kapital-Box (TOPRIGHT)
    local capBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    capBox:SetSize(CFG.cap_lbl_w, CFG.cap_lbl_h)
    capBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", CFG.cap_lbl_x, CFG.cap_lbl_y)
    capBox:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileEdge=true,
        tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
    capBox:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
    capBox:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local capLbl = capBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLbl:SetPoint("CENTER", capBox, "CENTER", 0, 0)
    capLbl:SetTextColor(0.95, 0.85, 0.4)
    self._capitalBox = capBox
    self._capitalLbl = capLbl
    capBox:Hide()

    -- Einsatz-Anzeige: an _fieldFrame hängen, damit Level-Hierarchie stimmt
    local ff = self._fieldFrame
    if ff then
        local betWrapper = CreateFrame("Frame", nil, ff)
        betWrapper:SetSize(CFG.bet_lbl_w, CFG.bet_lbl_h)
        betWrapper:SetPoint("TOPLEFT", ff, "TOPLEFT", CFG.bet_lbl_x, -CFG.bet_lbl_y)
        betWrapper:SetFrameLevel(ff:GetFrameLevel() + 12)
        local betLbl = betWrapper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        betLbl:SetPoint("LEFT", betWrapper, "LEFT", 0, 0)
        betLbl:SetTextColor(0.90, 0.85, 0.60)
        self._betDisplay = betLbl
    end

end

-- ── Chip-System (1:1 Blackjack-Pattern) ──────────────────────
function R:_CreateChipSystem()
    local f = self._canvas; if not f then return end

    if not self._betChipPool then
        self._betChipPool = CreateBetChipPool()
    end
    self._chipStackTexs = {}
    self._chipBetFrames = {}
    self._chipStackBtns = {}

    for i, slot in ipairs(CHIP_SLOTS) do
        local stackX = CFG.chip_slots_x[i]

        local stackFrame = CreateFrame("Button", nil, f)
        stackFrame:SetSize(CHIP_SIZE, CHIP_SIZE)
        stackFrame:SetPoint("TOPLEFT", f, "TOPLEFT", stackX, -CFG.chip_stack_y)

        local stackTex = stackFrame:CreateTexture(nil, "ARTWORK")
        stackTex:SetAllPoints(stackFrame)
        SetRandomChipVariant(stackTex, slot.color)
        self._chipStackTexs[i] = stackTex

        -- Wert-Label über dem Stapel
        local valLbl = stackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valLbl:SetPoint("BOTTOM", stackFrame, "TOP", 0, 2)
        valLbl:SetText(slot.value .. "g")
        valLbl:SetTextColor(0.95, 0.85, 0.4)

        local slotRef = slot
        local texRef  = stackTex
        stackFrame:SetScript("OnClick", function(self, button)
            local E = ArcadiaNexus.SHG_Engine
            if not E or E.state ~= "BETTING" then return end
            local gs = E.gameState
            if not gs then return end

            if button == "RightButton" then
                R:_RemoveLastBetChipOfColor(slotRef.color)
                E:RemoveBetOfColor(slotRef.color, slotRef.value)
                return
            end

            -- Linksklick: Chip hinzufügen
            if (gs.bet or 0) + slotRef.value > gs.chips then return end
            local atlas   = CHIP_ATLAS[slotRef.color]
            local variant = atlas.coords[math.random(1, #atlas.coords)]
            R:_AddBetChip(slotRef.color, variant, slotRef.value)
            SetRandomChipVariant(texRef, slotRef.color)
            E:AddBet(slotRef.value)
        end)
        stackFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        self._chipStackBtns[i] = stackFrame
        stackFrame:Hide()
    end

    -- Reset-Button: an _fieldFrame hängen für korrektes Level, Position aus CFG
    local ff = self._fieldFrame
    if ff then
        local resetBtn = CreateFrame("Button", nil, ff)
        resetBtn:SetSize(CFG.bet_reset_size, CFG.bet_reset_size)
        resetBtn:SetPoint("TOPLEFT", ff, "TOPLEFT",
            CFG.bet_reset_x, -CFG.bet_reset_y)
        resetBtn:SetFrameLevel(ff:GetFrameLevel() + 12)

        local resetTex = resetBtn:CreateTexture(nil, "ARTWORK")
        resetTex:SetAllPoints(resetBtn)
        local atlasInfo = C_Texture.GetAtlasInfo("Refresh")
            or C_Texture.GetAtlasInfo("refresh")
        if atlasInfo and atlasInfo.file then
            resetTex:SetTexture(atlasInfo.file)
            resetTex:SetTexCoord(atlasInfo.leftTexCoord, atlasInfo.rightTexCoord,
                atlasInfo.topTexCoord, atlasInfo.bottomTexCoord)
        else
            resetTex:SetTexture("Interface\\Buttons\\UI-RefreshButton")
        end

        resetBtn:SetScript("OnClick", function()
            local E = ArcadiaNexus.SHG_Engine
            if not E or E.state ~= "BETTING" then return end
            local gs = E.gameState; if not gs then return end
            R:_ClearBetChips()
            gs.bet          = 0
            gs.betConfirmed = false
            R:UpdateBetDisplay(gs)
        end)
        resetBtn:RegisterForClicks("LeftButtonUp")
        resetBtn:Hide()
        self._betResetBtn = resetBtn
    end
end

-- Bet-Chip hinzufügen (gestapelt mit Versatz, wie Blackjack)
function R:_AddBetChip(color, variant, value)
    local f = self._canvas; if not f or not self._betChipPool then return end

    local count   = #self._chipBetFrames
    local offsetX = math.random(-12, 12)
    local offsetY = math.random(-6, 6)
    local stackOffset = math.min(count * 3, 20)

    local bf = self._betChipPool:Acquire({ parent = f })
    bf:SetParent(f)
    bf:ClearAllPoints()
    bf:SetPoint("TOPLEFT", f, "TOPLEFT",
        CFG.chip_bet_x + offsetX,
        -(CFG.chip_bet_y - stackOffset + offsetY))
    bf:SetFrameLevel((f:GetFrameLevel() or 1) + 5 + count)
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

-- Letzten Bet-Chip einer Farbe entfernen
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
function R:_ClearBetChips()
    if self._betChipPool then
        self._betChipPool:ReleaseAll()
    end
    self._chipBetFrames = {}
end

-- ── Controls (narrow) ─────────────────────────────────────────
function R:_CreateControls()
    local UI = ArcadiaNexus.UI; if not UI then return end

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Seg.1 – Difficulty-Dropdown via ddAnchor
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local diffOpts = {
        { key="easy",   label=L("diff_easy")   },
        { key="normal", label=L("diff_normal") },
        { key="hard",   label=L("diff_hard")   },
    }
    UI.CreateSimpleDropdown(ddAnchor, 0, 0, CFG.dd_w, "",
        diffOpts,
        function()
            local s = ArcadiaNexus.SHG_Settings
            return s and s:Get("difficulty") or "easy"
        end,
        function(key)
            local E = ArcadiaNexus.SHG_Engine
            if E then E:SetDifficulty(key) end
        end)

    -- Seg.2 – Toggle Spiel starten / Beenden (x=0)
    local toggleBtn = UI.CreateArcadiaButton(cf, L("btn_start"), CFG.btn_w, CFG.btn_h)
    toggleBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    toggleBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SHG_Engine
        if not E then return end
        if E.state == "IDLE" then
            E:StartGame()
        else
            E:StopGame()
        end
    end)
    self._toggleBtn = toggleBtn

    -- Seg.3 – Neue Runde (nur BETTING)
    local roundBtn = UI.CreateArcadiaButton(cf, L("btn_new_round"), CFG.btn_w, CFG.btn_h)
    roundBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    roundBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.SHG_Engine
        if E and E.state == "BETTING" then E:StartRound() end
    end)
    roundBtn:Hide()
    self._roundBtn = roundBtn
end

function R:_UpdateControlButtons(state)
    if self._toggleBtn then
        self._toggleBtn:SetLabel(state == "IDLE" and L("btn_start") or L("btn_exit"))
    end
    if self._roundBtn then
        if state == "BETTING" then
            self._roundBtn:Show()
        else
            self._roundBtn:Hide()
        end
    end
end

-- ── Becher aufbauen ───────────────────────────────────────────
-- Becher-Frames sind beweglich. Slot-Buttons sind FEST an Slot-Positionen.
-- gs.ballCup und MakeGuess verwenden beide Slot-Indizes.
function R:_BuildCups(count)
    StopAnimLoop()
    if not self._cupPool then self._cupPool = CreateCupPool() end
    if not self._slotPool then self._slotPool = CreateSlotPool() end
    self._cupPool:ReleaseAll()
    self._slotPool:ReleaseAll()

    self._cups      = {}
    self._slotX     = {}
    self._cupAtSlot = {}
    self._slotOfCup = {}
    self._slotBtns  = {}

    local ff = self._fieldFrame; if not ff then return end
    local theme = GetCurrentTheme()
    local slotX = CalcSlotX(count)
    self._slotX = slotX

    for i = 1, count do
        local cf = self._cupPool:Acquire({})
        cf:SetParent(ff)
        cf:SetSize(CFG.cup_w, CFG.cup_h)
        cf:SetPoint("CENTER", ff, "CENTER", slotX[i], CFG.cup_y)
        cf:SetFrameLevel(ff:GetFrameLevel() + 2)
        SetCupTexture(cf._tex, theme)
        cf:Show()

        local ballF = cf._ballFrame
        ballF:SetParent(ff)
        ballF:SetSize(CFG.ball_r * 2, CFG.ball_r * 2)
        ballF:SetPoint("CENTER", ff, "CENTER", slotX[i], CFG.ball_mid_y)
        ballF:SetFrameLevel(ff:GetFrameLevel() + 1)
        ballF._tex:SetTexture(GetBallAsset())
        ballF:Hide()

        self._cups[i]      = { frame = cf, tex = cf._tex, ballFrame = ballF }
        self._cupAtSlot[i] = i
        self._slotOfCup[i] = i

        local btn = self._slotPool:Acquire({})
        btn:SetParent(ff)
        btn:SetSize(CFG.cup_w, CFG.cup_h)
        btn:SetPoint("CENTER", ff, "CENTER", slotX[i], CFG.cup_y)
        btn:SetFrameLevel(ff:GetFrameLevel() + 10)
        btn:SetAlpha(0)
        btn:EnableMouse(false)
        btn._slotIdx = i
        btn:Show()
        self._slotBtns[i] = btn
    end
end

function R:_ResetCupPositions()
    local ff = self._fieldFrame; if not ff then return end
    local count = #self._cups
    local slotX = CalcSlotX(count)
    self._slotX = slotX
    for i = 1, count do
        self._cupAtSlot[i] = i
        self._slotOfCup[i] = i
        MoveCupToX(self._cups[i], ff, slotX[i])
    end
end

-- ── Continue Overlay ──────────────────────────────────────────
function R:_CreateContinueOverlay()
    local f = self._canvas; if not f then return end
    local UI = ArcadiaNexus.UI
    local ov = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ov:SetSize(CFG.ov_w, CFG.ov_h)
    ov:SetPoint("CENTER", f, "CENTER", 0, 20)
    ov:SetFrameLevel(110)
    ov:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4} })
    ov:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    ov:SetBackdropBorderColor(0.6, 0.55, 0.3, 1.0)
    local titleFS = ov:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOP", ov, "TOP", 0, CFG.ov_title_y)
    titleFS:SetTextColor(0.95, 0.90, 0.50)
    ov._titleFS = titleFS
    local capitalFS = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    capitalFS:SetPoint("TOP", titleFS, "BOTTOM", 0, -8)
    capitalFS:SetTextColor(0.75, 0.70, 0.45)
    ov._capitalFS = capitalFS
    if UI then
        local btnCont = UI.CreateArcadiaButton(ov, L("btn_continue"), CFG.ov_btn_w, CFG.ov_btn_h)
        btnCont:SetPoint("BOTTOMLEFT", ov, "CENTER", -(CFG.ov_btn_w + 6), CFG.ov_btn_gap)
        btnCont:SetScript("OnClick", function()
            local E = ArcadiaNexus.SHG_Engine; if E then E:ContinuePlaying() end
        end)
        local btnStop = UI.CreateArcadiaButton(ov, L("btn_stop"), CFG.ov_btn_w, CFG.ov_btn_h)
        btnStop:SetPoint("BOTTOMLEFT", ov, "CENTER", 6, CFG.ov_btn_gap)
        btnStop:SetScript("OnClick", function()
            local E = ArcadiaNexus.SHG_Engine; if E then E:EndGame() end
        end)
    end
    ov:Hide()
    self._continueOverlay = ov
end

-- ── Engine-Callbacks ──────────────────────────────────────────
function R:OnGameStarted(gs)
    if self._logoTex then self._logoTex:Hide() end
    self:_ClearBetChips()
    if self._capitalBox then self._capitalBox:Show() end
    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do btn:Show() end
    end
    if self._betResetBtn then self._betResetBtn:Show() end
    if self._fieldFrame then self._fieldFrame:Show() end
    self:_BuildCups(gs.cups or 3)
    for _, cup in ipairs(self._cups) do cup.frame:Show() end
    self:UpdateBetDisplay(gs)
    self:UpdateCapitalDisplay(gs)
    self:_UpdateControlButtons("BETTING")
end

function R:OnGameStopped()
    self:EnterIdleState()
end

function R:OnNewRound(gs)
    self:_ClearBetChips()
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._continueOverlay then self._continueOverlay:Hide() end

    local count = gs.cups or 3
    if count ~= #self._cups then
        self:_BuildCups(count)
    else
        self:_ResetCupPositions()
        self:RefreshCupTheme()
    end
    for _, cup in ipairs(self._cups) do
        cup.frame:SetAlpha(1.0)
        cup.frame:Show()
        cup.ballFrame:Hide()
    end
    for _, btn in ipairs(self._slotBtns or {}) do
        btn:EnableMouse(false)
    end
    self:UpdateBetDisplay(gs)
    self:UpdateCapitalDisplay(gs)
    self:_UpdateControlButtons("BETTING")
end

function R:OnStateChanged(newState)
    local stateKeys = {
        IDLE="state_idle", BETTING="state_betting", REVEAL="state_reveal",
        SHUFFLE="state_shuffle", GUESSING="state_guessing", GAMEOVER="state_gameover",
    }
    if self._stateLbl then
        self._stateLbl:SetText(stateKeys[newState] and L(stateKeys[newState]) or "")
    end
    self:_UpdateControlButtons(newState)

    -- Chip-Stapel: nur im BETTING-State klickbar (wie Blackjack)
    local isBet = (newState == "BETTING")
    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do
            btn:SetAlpha(isBet and 1.0 or 0.35)
            btn:EnableMouse(isBet)
        end
    end
    if self._betResetBtn then
        self._betResetBtn:SetAlpha(isBet and 1.0 or 0.35)
        self._betResetBtn:EnableMouse(isBet)
    end

    -- Bet-Chips beim Rundenstart verstecken
    if newState == "REVEAL" then
        self:_ClearBetChips()
    end

    -- Bet zurücksetzen wenn neuer Einsatz-Zustand
    if newState == "BETTING" then
        self:_ClearBetChips()
    end

    -- Slot-Buttons nur im GUESSING-State aktiv
    for _, btn in ipairs(self._slotBtns or {}) do
        btn:EnableMouse(newState == "GUESSING")
    end

    if newState ~= "RESULT" and newState ~= "GAMEOVER" then
        if self._fieldFrame and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
        end
    end
    if newState ~= "CONTINUE_PROMPT" then
        if self._continueOverlay then self._continueOverlay:Hide() end
    end
end

-- ── REVEAL ───────────────────────────────────────────────────
-- Schritt 1: Ball sofort sichtbar, Cup über dem Ball angehoben.
-- Wird synchron aufgerufen — kein Callback nötig.
function R:ShowRevealOpen(gs)
    if not gs then return end
    local ff       = self._fieldFrame; if not ff then return end
    local ballSlot = gs.ballCup

    for slotIdx, becherIdx in ipairs(self._cupAtSlot) do
        local cup = self._cups[becherIdx]
        if cup then
            local isBallSlot = (slotIdx == ballSlot)
            cup.ballFrame:SetShown(isBallSlot)
            cup.frame:SetAlpha(1.0)
            cup.frame:Show()
            if isBallSlot then
                local slotPosX = self._slotX[slotIdx]
                -- Ball auf Mittehöhe positionieren
                cup.ballFrame:ClearAllPoints()
                cup.ballFrame:SetPoint("CENTER", ff, "CENTER", slotPosX, CFG.ball_mid_y)
                -- Cup angehoben, Ball liegt sichtbar darunter
                cup.frame:ClearAllPoints()
                cup.frame:SetPoint("CENTER", ff, "CENTER", slotPosX,
                    CFG.cup_y + CFG.cup_reveal_lift)
            end
        end
    end
end

-- Schritt 2: Cup fällt auf Endposition herunter (Ease-out).
-- onDone: Callback nach Abschluss der Animation → Shuffle startet.
function R:AnimateCupClose(gs, onDone)
    if not gs then if onDone then onDone() end; return end
    local ff        = self._fieldFrame; if not ff then return end
    local ballSlot  = gs.ballCup
    local becherIdx = self._cupAtSlot[ballSlot]
    local cup       = self._cups[becherIdx]
    if not cup then if onDone then onDone() end; return end

    local slotPosX = self._slotX[ballSlot]
    local startY   = CFG.cup_y + CFG.cup_reveal_lift
    local endY     = CFG.cup_y
    local duration = CFG.cup_drop_duration
    local elapsed  = 0

    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t  = math.min(elapsed / duration, 1)
        local te = 1 - (1 - t) * (1 - t)   -- Ease-out
        cup.frame:ClearAllPoints()
        cup.frame:SetPoint("CENTER", ff, "CENTER", slotPosX,
            startY + (endY - startY) * te)
        if t >= 1 then
            StopAnimLoop()
            cup.frame:ClearAllPoints()
            cup.frame:SetPoint("CENTER", ff, "CENTER", slotPosX, CFG.cup_y)
            if onDone then onDone() end
        end
    end)
end

function R:HideReveal()
    for _, cup in ipairs(self._cups) do cup.ballFrame:Hide() end
end

-- ── Shuffle-Sequenz ───────────────────────────────────────────
function R:RunShuffleSequence(sequence, onDone)
    if not sequence or #sequence == 0 then
        if onDone then onDone() end
        return
    end

    local Logic = ArcadiaNexus.SHG_Logic
    local E     = ArcadiaNexus.SHG_Engine
    local gs    = E and E.gameState

    E._timerGuard:Cancel()
    local gen = E._timerGuard:Generation()
    local idx = 1

    local function nextStep()
        if E._timerGuard:Generation() ~= gen then return end
        if idx > #sequence then
            if onDone then onDone() end
            return
        end
        local step = sequence[idx]
        idx = idx + 1

        if step.fake then
            local becherIdx = self._cupAtSlot[step.a]
            if becherIdx then
                self:_AnimateFakeLift(becherIdx, step.duration, function()
                    if E._timerGuard:Generation() ~= gen then return end
                    E._timerGuard:After(step.pause, function()
                        if E._timerGuard:Generation() ~= gen then return end
                        nextStep()
                    end)
                end)
            else nextStep() end
        else
            local slotA   = step.a
            local slotB   = step.b
            local becherA = self._cupAtSlot[slotA]
            local becherB = self._cupAtSlot[slotB]
            if becherA and becherB then
                self:_AnimateSwap(becherA, becherB, slotA, slotB, step.duration, function()
                    if E._timerGuard:Generation() ~= gen then return end
                    -- gs.ballCup ist Slot-Index → direkt mit Slot-Indizes tauschen
                    if gs then Logic:SwapCups(gs, slotA, slotB) end
                    E._timerGuard:After(step.pause, function()
                        if E._timerGuard:Generation() ~= gen then return end
                        nextStep()
                    end)
                end)
            else nextStep() end
        end
    end
    nextStep()
end

-- ── Swap-Animation ────────────────────────────────────────────
function R:_AnimateSwap(becherA, becherB, slotA, slotB, duration, onDone)
    local cupA = self._cups[becherA]
    local cupB = self._cups[becherB]
    local ff   = self._fieldFrame
    if not cupA or not cupB or not ff then
        if onDone then onDone() end; return
    end

    local startXA = self._slotX[slotA]
    local startXB = self._slotX[slotB]
    local arcH    = 18
    local elapsed = 0

    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t  = math.min(elapsed / duration, 1)
        local te = t * t * (3 - 2 * t)
        local arcA = math.sin(t * math.pi) *  arcH
        local arcB = math.sin(t * math.pi) * -arcH
        local newXA = startXA + (startXB - startXA) * te
        local newXB = startXB + (startXA - startXB) * te

        cupA.frame:ClearAllPoints()
        cupA.frame:SetPoint("CENTER", ff, "CENTER", newXA, CFG.cup_y + arcA)
        cupA.ballFrame:ClearAllPoints()
        cupA.ballFrame:SetPoint("CENTER", ff, "CENTER", newXA, CFG.ball_mid_y + arcA)
        cupB.frame:ClearAllPoints()
        cupB.frame:SetPoint("CENTER", ff, "CENTER", newXB, CFG.cup_y + arcB)
        cupB.ballFrame:ClearAllPoints()
        cupB.ballFrame:SetPoint("CENTER", ff, "CENTER", newXB, CFG.ball_mid_y + arcB)

        if t >= 1 then
            StopAnimLoop()
            -- Slot-Mapping aktualisieren (für _AnimateFakeLift)
            self._cupAtSlot[slotA] = becherB
            self._cupAtSlot[slotB] = becherA
            self._slotOfCup[becherA] = slotB
            self._slotOfCup[becherB] = slotA
            -- Becher-Frames auf Ziel-Slot fixieren
            cupA.frame:ClearAllPoints()
            cupA.frame:SetPoint("CENTER", ff, "CENTER", self._slotX[slotB], CFG.cup_y)
            cupA.ballFrame:ClearAllPoints()
            cupA.ballFrame:SetPoint("CENTER", ff, "CENTER", self._slotX[slotB], CFG.ball_mid_y)
            cupB.frame:ClearAllPoints()
            cupB.frame:SetPoint("CENTER", ff, "CENTER", self._slotX[slotA], CFG.cup_y)
            cupB.ballFrame:ClearAllPoints()
            cupB.ballFrame:SetPoint("CENTER", ff, "CENTER", self._slotX[slotA], CFG.ball_mid_y)
            if onDone then onDone() end
        end
    end)
end

-- ── Fake-Lift ─────────────────────────────────────────────────
function R:_AnimateFakeLift(becherIdx, duration, onDone)
    local cup = self._cups[becherIdx]
    local ff  = self._fieldFrame
    if not cup or not ff then if onDone then onDone() end; return end

    local posX    = self._slotX[self._slotOfCup[becherIdx]]
    local liftH   = 22
    local elapsed = 0
    local halfDur = duration / 2
    local phase   = 1

    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t    = math.min(elapsed / halfDur, 1)
        local yOfs = (phase == 1) and (t * liftH) or ((1 - t) * liftH)
        cup.frame:ClearAllPoints()
        cup.frame:SetPoint("CENTER", ff, "CENTER", posX, CFG.cup_y + yOfs)
        if t >= 1 then
            if phase == 1 then phase = 2; elapsed = 0
            else
                StopAnimLoop()
                cup.frame:ClearAllPoints()
                cup.frame:SetPoint("CENTER", ff, "CENTER", posX, CFG.cup_y)
                if onDone then onDone() end
            end
        end
    end)
end

-- ── RESULT ───────────────────────────────────────────────────
function R:ShowResult(gs, won, payout, bankrupt)
    if not gs then return end
    local ballSlot  = gs.ballCup
    local guessSlot = gs.guess

    -- Balls positionieren (noch verdeckt)
    for slotIdx, becherIdx in ipairs(self._cupAtSlot) do
        local cup = self._cups[becherIdx]
        if cup then
            cup.ballFrame:SetShown(slotIdx == ballSlot)
            if slotIdx == ballSlot then
                local ff = self._fieldFrame
                if ff then
                    cup.ballFrame:ClearAllPoints()
                    cup.ballFrame:SetPoint("CENTER", ff, "CENTER",
                        self._slotX[slotIdx], CFG.ball_mid_y)
                end
            end
        end
    end

    -- Gewählten Cup anheben; wenn falsch: danach auch den richtigen
    self:_LiftRevealCups(guessSlot, ballSlot, function()
        if not self._fieldFrame then return end
        local E = ArcadiaNexus.SHG_Engine
        if bankrupt then
            if E and E.gameState and E._GameOver then E:_GameOver() end
            return
        end
        local UI     = ArcadiaNexus.UI
        local loc    = ArcadiaNexus.GetLocaleTable("SHELLGAME")
        local parent = self._fieldFrame

        local title, titleColor, goldVal
        if won then
            title      = FormatStr(L("result_win"), payout)
            titleColor = {0.3, 0.9, 0.3}
            goldVal    = payout
        else
            title      = FormatStr(L("result_lose"), gs.bet)
            titleColor = {0.9, 0.3, 0.3}
            goldVal    = -gs.bet
        end

        UI.ShowResultDialog({
            parent     = parent,
            title      = title,
            titleColor = titleColor,
            subtitle   = L("lbl_capital") .. ": " .. gs.chips .. " Gold",
            gold       = goldVal,
            goldLabel  = "Gold",
            gameId     = "SHELLGAME",
            difficulty = gs.difficulty,
            hideHighscore = true,
            result     = won and "WIN" or "LOSS",
            buttons    = UI.ResultDialogButtons.Round(loc,
                function()
                    UI.HideResultDialog(parent)
                    local E = ArcadiaNexus.SHG_Engine
                    if not E or not E.gameState then return end
                    E._timerGuard:Cancel()
                    if E.gameState.chips >= 25 then
                        E.gameState.bet = 0
                        E.gameState.betConfirmed = false
                        E:_SetState("BETTING")
                        R:OnNewRound(E.gameState)
                    end
                end,
                function()
                    UI.HideResultDialog(parent)
                    local E = ArcadiaNexus.SHG_Engine
                    if E then
                        E._timerGuard:Cancel()
                        E:StopGame()
                    end
                end),
        })
    end)
    self:UpdateCapitalDisplay(gs)
end

function R:ShowContinuePrompt(gs)
    if not self._continueOverlay then return end
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    self._continueOverlay._titleFS:SetText(L("prompt_title"))
    self._continueOverlay._capitalFS:SetText(FormatStr(L("prompt_capital"), gs.chips))
    self._continueOverlay:Show()
end

function R:ShowGameOver(gs)
    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local loc    = ArcadiaNexus.GetLocaleTable("SHELLGAME")
    local parent = self._fieldFrame

    UI.ShowResultDialog({
        parent     = parent,
        title      = L("state_gameover"),
        titleColor = {0.9, 0.2, 0.2},
        subtitle   = L("lbl_capital") .. ": 0 Gold",
        gameId     = "SHELLGAME",
        difficulty = gs and gs.difficulty,
        hideHighscore = true,
        result     = "LOSS",
        buttons    = UI.ResultDialogButtons.Bankrupt(loc,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.SHG_Engine
                local S = ArcadiaNexus.SHG_Settings
                if E and S then
                    E:StartGame({ difficulty = (gs and gs.difficulty) or S:Get("difficulty") })
                end
            end,
            function()
                UI.HideResultDialog(parent)
                local E = ArcadiaNexus.SHG_Engine
                if E then E:StopGame() end
            end),
    })
end

-- Hebt einen einzelnen Slot-Becher animiert an (Ease-in).
-- slotToLift: Slot-Index des anzuhebenden Bechers
-- onDone: Callback nach Abschluss
function R:_LiftOneCup(slotToLift, onDone)
    local ff        = self._fieldFrame; if not ff then if onDone then onDone() end; return end
    local becherIdx = self._cupAtSlot[slotToLift]
    local cup       = self._cups[becherIdx]
    if not cup then if onDone then onDone() end; return end

    local slotPosX = self._slotX[slotToLift]
    local duration = CFG.cup_drop_duration
    local lift     = CFG.cup_reveal_lift
    local elapsed  = 0

    StartAnimLoop(function(dt)
        elapsed = elapsed + dt
        local t  = math.min(elapsed / duration, 1)
        local te = t * t   -- Ease-in
        cup.frame:ClearAllPoints()
        cup.frame:SetPoint("CENTER", ff, "CENTER", slotPosX, CFG.cup_y + lift * te)
        if t >= 1 then
            StopAnimLoop()
            if onDone then onDone() end
        end
    end)
end

-- Hebt den gewählten Cup an.
-- Wenn guessSlot != ballSlot: nach 0.5s Pause auch den richtigen Cup anheben.
-- Dann 0.3s Pause, Overlay.
function R:_LiftRevealCups(guessSlot, ballSlot, onDone)
    local E = ArcadiaNexus.SHG_Engine
    local correct = (guessSlot == ballSlot)

    -- Schritt 1: gewählten Cup anheben
    self:_LiftOneCup(guessSlot, function()
        if not E or not E._timerGuard then
            if onDone then onDone() end
            return
        end
        if correct then
            E._timerGuard:After(0.3, function()
                if onDone then onDone() end
            end)
        else
            E._timerGuard:After(0.5, function()
                self:_LiftOneCup(ballSlot, function()
                    E._timerGuard:After(0.3, function()
                        if onDone then onDone() end
                    end)
                end)
            end)
        end
    end)
end

-- ── Display ───────────────────────────────────────────────────
function R:UpdateBetDisplay(gs)
    if not self._betDisplay or not gs then return end
    local bet = gs.bet or 0
    if bet > 0 then
        self._betDisplay:SetText(L("lbl_bet") .. ": " .. bet .. "g")
    else
        self._betDisplay:SetText(L("lbl_bet") .. ": --")
    end
end

function R:UpdateCapitalDisplay(gs)
    if not gs or not self._capitalLbl then return end
    self._capitalLbl:SetText(L("lbl_capital") .. ": " .. gs.chips .. "g")
end

function R:UpdateCupCount(gs)
    if not gs then return end
    local count = gs.cups or 3
    if count ~= #self._cups then
        self:_BuildCups(count)
        for _, cup in ipairs(self._cups) do cup.frame:Show() end
    end
end

function R:RefreshCupTheme()
    local theme = GetCurrentTheme()
    for _, cup in ipairs(self._cups) do SetCupTexture(cup.tex, theme) end
end

function R:RefreshBallTex()
    local asset = GetBallAsset()
    for _, cup in ipairs(self._cups) do
        if cup.ballFrame and cup.ballFrame._tex then
            cup.ballFrame._tex:SetTexture(asset)
        end
    end
end

-- ── IDLE ──────────────────────────────────────────────────────
function R:EnterIdleState()
    StopAnimLoop()

    self:_ClearBetChips()
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._continueOverlay then self._continueOverlay:Hide() end
    if self._capitalBox      then self._capitalBox:Hide()      end
    if self._betDisplay      then self._betDisplay:SetText("") end
    if self._stateLbl        then self._stateLbl:SetText(L("state_idle")) end

    if self._cupPool then self._cupPool:ReleaseAll() end
    if self._slotPool then self._slotPool:ReleaseAll() end
    self._cups = {}
    self._slotBtns = {}

    if self._chipStackBtns then
        for _, btn in ipairs(self._chipStackBtns) do
            btn:EnableMouse(false)
            btn:SetAlpha(0.35)
            btn:Hide()
        end
    end
    if self._betResetBtn then
        self._betResetBtn:EnableMouse(false)
        self._betResetBtn:SetAlpha(0.35)
        self._betResetBtn:Hide()
    end

    self:_UpdateControlButtons("IDLE")
    if self._logoTex then self._logoTex:Show() end
end
