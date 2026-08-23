-- ============================================================
--  ArcadiaNexus
--  Games/AzerothConquest/Renderer.lua
--  Version: 2.0.0  (Blueprint v3 Typ-2 + Background/Border/Logo)
--
--  Controls: CreateGameControlsBar "narrow"
--    Seg.1 Dropdown Schwierigkeit
--    Seg.2 Toggle Spiel starten / Beenden (deaktiviert bis DD gewaehlt)
--    Seg.3 Button Zufaellig platzieren (nur waehrend PLACEMENT)
--
--  Spielfelder:
--    Spieler und Gegner getrennt positionierbar via CFG (x/y/w/h + scale)
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AC_Renderer = {}
local R = ArcadiaNexus.AC_Renderer

-- ============================================================
-- Farb-Konstanten
-- ============================================================
local CELL_COLOR       = { 0.15, 0.18, 0.25, 1    }
local SHIP_COLOR       = { 0.55, 0.45, 0.30, 1    }
local HIT_COLOR        = { 0.85, 0.15, 0.10, 1    }
local MISS_COLOR       = { 0.25, 0.45, 0.65, 1    }
local SUNK_COLOR       = { 0.25, 0.22, 0.20, 1    }
local GHOST_OK_COLOR   = { 0.20, 0.80, 0.20, 0.45 }
local GHOST_BAD_COLOR  = { 0.85, 0.15, 0.10, 0.45 }
local LABEL_COLOR      = { 0.80, 0.75, 0.60, 1    }

-- ============================================================
-- CFG – alle Layout-Konstanten zentral, unabhaengig positionierbar
-- ============================================================
local CFG = {
    -- _fieldFrame (CENTER-Anker, kein bgFile)
    field_w      = 700,
    field_h      = 520,
    field_ofs_x  = 0,
    field_ofs_y  = 0,

    -- Hintergrund-Textur (relativ zu _fieldFrame CENTER)
    bg_w         = 800,
    bg_h         = 550,
    bg_ofs_x     = 0,
    bg_ofs_y     = 25,
    bg_alpha     = 0.9,

    -- Border-Textur (relativ zu _fieldFrame CENTER)
    border_w     = 800,
    border_h     = 600,
    border_ofs_x = 0,
    border_ofs_y = 0,

    -- Logo-Textur (relativ zu _fieldFrame CENTER)
    logo_w       = 260,
    logo_h       = 260,
    logo_ofs_x   = 0,
    logo_ofs_y   = 30,

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- Spielfeld Spieler (relativ zu _fieldFrame TOPLEFT)
    -- scale: 1.0 = 100%, 0.8 = 80% der Zellgroesse
    player_ofs_x = 55, -- 10
    player_ofs_y = -115, -- -30
    player_w     = 320,
    player_h     = 320,
    player_scale = 0.73,

    -- Spielfeld Gegner (relativ zu _fieldFrame TOPLEFT)
    enemy_ofs_x  = 430,
    enemy_ofs_y  = -115,
    enemy_w      = 320,
    enemy_h      = 320,
    enemy_scale  = 0.73,

    -- Label "Dein Feld" (relativ zu _fieldFrame TOPLEFT, unabhaengig vom Spielfeld)
    lbl_player_ofs_x = 130,
    lbl_player_ofs_y = -91,

    -- Label "Gegner" (relativ zu _fieldFrame TOPLEFT, unabhaengig vom Spielfeld)
    lbl_enemy_ofs_x  = 520,
    lbl_enemy_ofs_y  = -91,

    -- Placement-Hint (relativ zu _fieldFrame TOP CENTER)
    phint_ofs_x  = 0,
    phint_ofs_y  = -400,
    phint_w      = 340,
    phint_h      = 28,
    phint_alpha  = 0.75,

    -- Battle-Hint "Klicke auf das Gegnerfeld..." (relativ zu _fieldFrame TOP CENTER)
    bhint_ofs_x  = 0,
    bhint_ofs_y  = -400,
    bhint_w      = 340,
    bhint_h      = 28,
    bhint_alpha  = 0.75,

    -- Popup (GameOver) – Nonogram-Standard
    ov_w         = 360,
    ov_h         = 200,
    ov_ofs_x     = 0,
    ov_ofs_y     = 0,
    ov_title_y   = 55,
    ov_sub_gap   = -14,
    ov_btn_gap   = -20,
    ov_btn_w     = 160,
    ov_btn_h     = 30,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local AC_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\background\\bg_ac",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\border\\border_ac",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\logo\\logo_ac",
    -- Treffer / Miss Marker
    hit    = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\tiles\\hit",
    miss   = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\tiles\\miss",
}

-- Schiffs-Tile: Icon-Key → { h = horizontal-TGA, v = vertikal-TGA }
-- Zeppelin hat 2 Varianten (3_1 / 3_2), Auswahl per ship.id % 2
local SHIP_TILE_BASE = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothConquest\\assets\\tiles\\"
local SHIP_TILES = {
    ["achievement_fleet_admiral"]         = {
        h = { SHIP_TILE_BASE .. "5h"   },
        v = { SHIP_TILE_BASE .. "5v"   },
    },
    ["ability_vehicle_siegeenginecannon"] = {
        h = { SHIP_TILE_BASE .. "4h"   },
        v = { SHIP_TILE_BASE .. "4v"   },
    },
    ["inv_misc_enggizmos_32"]             = {
        h = { SHIP_TILE_BASE .. "3_1h", SHIP_TILE_BASE .. "3_2h" },
        v = { SHIP_TILE_BASE .. "3_1v", SHIP_TILE_BASE .. "3_2v" },
    },
    ["inv_misc_cannon_01"]                = {
        h = { SHIP_TILE_BASE .. "2h"   },
        v = { SHIP_TILE_BASE .. "2v"   },
    },
}

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R.state          = "IDLE"
R._fieldFrame    = nil
R._borderFrame   = nil
R._bgTex         = nil
R._borderTex     = nil
R._logoTex       = nil
R._controlsFrame = nil
R._startBtn      = nil
R._randomBtn     = nil

R.grids          = { {}, {} }
R.gridFrames     = { nil, nil }
R.gridLabels     = { nil, nil }
R._shipOverlayFrames = {}
R._cellPool      = nil
R._shipOverlayPool = nil
R.cellSize       = 0
R.ghostCells     = {}
R.hoverR         = nil
R.hoverC         = nil
R.keyFrame       = nil

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateControls()
    self:_CreatePlacementHint()
    self:_CreateBattleHint()
    self:_CreateKeyFrame()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine
    Engine:On("AC_GAME_STARTED",      function(state)  R:OnGameStarted(state)      end)
    Engine:On("AC_PLACEMENT_UPDATED", function(state)  R:OnPlacementUpdated(state) end)
    Engine:On("AC_BATTLE_STARTED",    function(state)  R:OnBattleStarted(state)    end)
    Engine:On("AC_SHOT_FIRED",        function(state)  R:OnShotFired(state)        end)
    Engine:On("AC_GAME_OVER",         function(result) R:OnGameOver(result)        end)
    Engine:On("AC_GAME_STOPPED",      function()       R:EnterIdleState()          end)
end

-- ============================================================
-- MAIN FRAME
-- ============================================================
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AC_Container",
        designW   = 700,
        designH   = 520,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._acContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("AZEROTHCONQUEST", ArcadiaNexus.AC_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

-- ============================================================
-- FIELD FRAME (CENTER-Anker, kein bgFile)
-- ============================================================
function R:_CreateFieldFrame()
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas)
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = ff
end

-- ============================================================
-- BACKGROUND
-- ============================================================
function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(AC_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- ============================================================
-- BORDER FRAME
-- ============================================================
function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(AC_ASSETS.border)
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

-- ============================================================
-- LOGO
-- ============================================================
function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        AC_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- CONTROLS – CreateGameControlsBar "narrow"
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.AC_Settings

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Segment 1: Dropdown Schwierigkeit
    local DIFFS = {
        { key = "easy",   label = L["diff_easy"]   or "Einfach" },
        { key = "normal", label = L["diff_normal"]  or "Normal"  },
        { key = "hard",   label = L["diff_hard"]    or "Schwer"  },
    }
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    UI.CreateSimpleDropdown(ddAnchor, 0, 0, CFG.dd_w, "", DIFFS,
        function()
            return S and S:Get("aiDifficulty") or "easy"
        end,
        function(key)
            if S then S:Set("aiDifficulty", key) end
            -- Starttaste aktivieren sobald Schwierigkeit gewaehlt
            if R._startBtn then R._startBtn:Enable() end
        end
    )

    -- Segment 2: Toggle-Button (initial deaktiviert)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.AC_Engine
        if not Eng then return end
        if R.state == "IDLE" then
            local diff = S and S:Get("aiDifficulty") or "easy"
            Eng:StartGame({ size = 10, aiDifficulty = diff })
        else
            Eng:StopGame()
        end
    end)
    -- Initial deaktiviert bis Schwierigkeit gewaehlt
    local hasDiff = S and S:Get("aiDifficulty") ~= nil
    if not hasDiff then startBtn:Disable() end
    self._startBtn = startBtn

    -- Segment 3: Zufaellig-platzieren Button (initial versteckt)
    local randomBtn = UI.CreateArcadiaButton(cf, L["btn_random"] or "Zufällig", CFG.btn_w, CFG.btn_h)
    randomBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    randomBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.AC_Engine
        if Eng then Eng:HandleRandomPlacement() end
    end)
    randomBtn:Hide()
    self._randomBtn = randomBtn
end

-- ============================================================
-- POPUP (GameOver) – Nonogram-Standard
-- ============================================================
-- ============================================================
-- PLACEMENT-HINT FRAME
-- ============================================================
function R:_CreatePlacementHint()
    local ff = self._fieldFrame

    local hintFrame = CreateFrame("Frame", nil, ff, "BackdropTemplate")
    hintFrame:SetSize(CFG.phint_w, CFG.phint_h)
    hintFrame:SetPoint("TOP", ff, "TOP", CFG.phint_ofs_x, CFG.phint_ofs_y)
    hintFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    hintFrame:SetBackdropColor(0, 0, 0, CFG.phint_alpha)
    hintFrame:SetBackdropBorderColor(0.9, 0.75, 0.3, CFG.phint_alpha)
    hintFrame:SetFrameLevel(ff:GetFrameLevel() + 5)
    hintFrame:Hide()
    self._placementHintFrame = hintFrame

    local fs = hintFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    self._placementHintFS = fs
end

-- ============================================================
-- BATTLE-HINT FRAME
-- ============================================================
function R:_CreateBattleHint()
    local ff = self._fieldFrame

    local hintFrame = CreateFrame("Frame", nil, ff, "BackdropTemplate")
    hintFrame:SetSize(CFG.bhint_w, CFG.bhint_h)
    hintFrame:SetPoint("TOP", ff, "TOP", CFG.bhint_ofs_x, CFG.bhint_ofs_y)
    hintFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    hintFrame:SetBackdropColor(0, 0, 0, CFG.bhint_alpha)
    hintFrame:SetBackdropBorderColor(0.9, 0.75, 0.3, CFG.bhint_alpha)
    hintFrame:SetFrameLevel(ff:GetFrameLevel() + 5)
    hintFrame:Hide()
    self._battleHintFrame = hintFrame

    local fs = hintFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    self._battleHintFS = fs
end

-- ============================================================
-- KEY FRAME (R = rotieren waehrend Placement)
-- ============================================================
function R:_CreateKeyFrame()
    if self.keyFrame then return end
    local kf = CreateFrame("Frame", "ArcadiaNexus_AC_KeyFrame", self.frame)
    kf:SetAllPoints(self.frame)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        if key == "R" or key == "r" then
            kf:SetPropagateKeyboardInput(false)
            ArcadiaNexus.AC_Engine:ToggleOrientation()
            if R.hoverR and R.hoverC then
                local state = ArcadiaNexus.AC_Engine.activeGame
                    and ArcadiaNexus.AC_Engine.activeGame:GetBoardState()
                if state then R:UpdateGhost(state) end
            end
        else
            kf:SetPropagateKeyboardInput(true)
        end
    end)
    self.keyFrame = kf
end

-- ============================================================
-- GRID-POOLS
-- ============================================================

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "AzerothConquest.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local tf = CreateFrame("Button", nil, poolParent)
            tf:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
            local bg = tf:GetNormalTexture()

            local markerFrame = CreateFrame("Frame", nil, poolParent)
            local marker = markerFrame:CreateTexture(nil, "ARTWORK")
            marker:SetAllPoints(markerFrame)
            marker:Hide()

            local ghostFrame = CreateFrame("Frame", nil, tf)
            ghostFrame:SetAllPoints(tf)
            ghostFrame:Hide()
            local ghost = ghostFrame:CreateTexture(nil, "BACKGROUND")
            ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
            ghost:SetAllPoints(ghostFrame)
            ghost:SetVertexColor(0, 0, 0, 0)

            tf._acBg = bg
            tf._acMarkerFrame = markerFrame
            tf._acMarker = marker
            tf._acGhostFrame = ghostFrame
            tf._acGhost = ghost

            tf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            tf:SetScript("OnClick", function(self, button)
                if button == "RightButton" and R.state == "PLACEMENT" then
                    ArcadiaNexus.AC_Engine:ToggleOrientation()
                    if R.hoverR and R.hoverC then
                        local st = ArcadiaNexus.AC_Engine.activeGame
                            and ArcadiaNexus.AC_Engine.activeGame:GetBoardState()
                        if st then R:UpdateGhost(st) end
                    end
                else
                    R:OnCellClick(self._acSide, self._acRow, self._acCol)
                end
            end)
            tf:SetScript("OnEnter", function(self)
                if self._acSide == 1 and R.state == "PLACEMENT" then
                    R.hoverR = self._acRow
                    R.hoverC = self._acCol
                    local state = ArcadiaNexus.AC_Engine.activeGame
                        and ArcadiaNexus.AC_Engine.activeGame:GetBoardState()
                    if state then R:UpdateGhost(state) end
                end
            end)
            tf:SetScript("OnLeave", function(self)
                if self._acSide == 1 and R.state == "PLACEMENT" then
                    R:ClearGhost()
                end
            end)

            return tf
        end,
        onRelease = function(tf)
            tf:Hide()
            tf:ClearAllPoints()
            tf._acSide = nil
            tf._acRow = nil
            tf._acCol = nil
            tf:SetAlpha(1)
            tf:EnableMouse(true)
            if tf._acBg then
                tf._acBg:SetTexture("Interface\\Buttons\\WHITE8X8")
                tf._acBg:SetVertexColor(CELL_COLOR[1], CELL_COLOR[2], CELL_COLOR[3], CELL_COLOR[4])
            end
            if tf._acMarker then tf._acMarker:Hide() end
            if tf._acMarkerFrame then
                tf._acMarkerFrame:Hide()
                tf._acMarkerFrame:ClearAllPoints()
            end
            if tf._acGhostFrame then tf._acGhostFrame:Hide() end
            if tf._acGhost then tf._acGhost:SetVertexColor(0, 0, 0, 0) end
            if poolParentRef then
                tf:SetParent(poolParentRef)
                if tf._acMarkerFrame then tf._acMarkerFrame:SetParent(poolParentRef) end
            end
        end,
    })
end

local function CreateShipOverlayPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "AzerothConquest.ShipOverlays",
        create = function(poolParent)
            poolParentRef = poolParent
            local ov = CreateFrame("Frame", nil, poolParent)
            local tex = ov:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(ov)
            ov._acTex = tex
            return ov
        end,
        onRelease = function(ov)
            ov:Hide()
            ov:ClearAllPoints()
            ov._side = nil
            if ov._acTex then
                ov._acTex:SetTexture(nil)
                ov._acTex:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then ov:SetParent(poolParentRef) end
        end,
    })
end

function R:_EnsureGridPools()
    if not self._cellPool then self._cellPool = CreateCellPool() end
    if not self._shipOverlayPool then self._shipOverlayPool = CreateShipOverlayPool() end
end

function R:_ReleaseShipOverlaysExceptSide(keepSide)
    local kept = {}
    for _, ov in ipairs(self._shipOverlayFrames) do
        if ov and ov._side == keepSide then
            kept[#kept + 1] = ov
        elseif ov and self._shipOverlayPool then
            self._shipOverlayPool:Release(ov)
        end
    end
    self._shipOverlayFrames = kept
end

function R:_EnsureGridFrame(side, ff, boardPx, sc)
    if not self.gridFrames[side] then
        local gf = CreateFrame("Frame", nil, ff)
        local gbg = gf:CreateTexture(nil, "BACKGROUND")
        gbg:SetTexture("Interface\\Buttons\\WHITE8X8")
        gbg:SetAllPoints(gf)
        gbg:SetVertexColor(0.08, 0.09, 0.12, 1)
        self.gridFrames[side] = gf
    end
    local gf = self.gridFrames[side]
    gf:SetParent(ff)
    gf:SetSize(boardPx + 2, boardPx + 2)
    gf:SetPoint("TOPLEFT", ff, "TOPLEFT", sc.ofs_x - 1, sc.ofs_y + 1)
    gf:Show()
end

function R:_EnsureGridLabel(side, ff, L)
    if not self.gridLabels[side] then
        self.gridLabels[side] = ff:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    local label = self.gridLabels[side]
    label:ClearAllPoints()
    local lbl_ofs_x = side == 1 and CFG.lbl_player_ofs_x or CFG.lbl_enemy_ofs_x
    local lbl_ofs_y = side == 1 and CFG.lbl_player_ofs_y or CFG.lbl_enemy_ofs_y
    label:SetPoint("TOPLEFT", ff, "TOPLEFT", lbl_ofs_x, lbl_ofs_y)
    label:SetText(side == 1 and L["label_player"] or L["label_enemy"])
    label:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
    label:Show()
end

-- ============================================================
-- GRIDS ERSTELLEN
-- Spieler (side=1) und Gegner (side=2) getrennt via CFG positionierbar
-- ============================================================
function R:BuildGrids(size)
    self:ClearGrids()
    self:_EnsureGridPools()

    local ff = self._fieldFrame
    local L  = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")

    local sideConf = {
        [1] = { ofs_x = CFG.player_ofs_x, ofs_y = CFG.player_ofs_y,
                w = CFG.player_w, h = CFG.player_h, scale = CFG.player_scale },
        [2] = { ofs_x = CFG.enemy_ofs_x,  ofs_y = CFG.enemy_ofs_y,
                w = CFG.enemy_w,  h = CFG.enemy_h,  scale = CFG.enemy_scale  },
    }
    self._sideConf = sideConf

    for side = 1, 2 do
        self.grids[side] = {}
        local sc = sideConf[side]

        local cellBase = math.min(sc.w / size, sc.h / size)
        local cell     = math.max(10, math.floor(cellBase * sc.scale / 2) * 2)
        local boardPx  = cell * size

        self:_EnsureGridFrame(side, ff, boardPx, sc)
        self:_EnsureGridLabel(side, ff, L)

        for r = 1, size do
            self.grids[side][r] = {}
            for c = 1, size do
                local px = sc.ofs_x + (c - 1) * cell
                local py = math.abs(sc.ofs_y) + (r - 1) * cell

                local tf = self._cellPool:Acquire({})
                tf:SetParent(ff)
                tf:SetSize(cell - 1, cell - 1)
                tf:SetPoint("TOPLEFT", ff, "TOPLEFT", px, -py)
                tf:EnableMouse(true)
                tf._acSide = side
                tf._acRow  = r
                tf._acCol  = c
                tf:Show()

                local markerFrame = tf._acMarkerFrame
                markerFrame:SetParent(ff)
                markerFrame:SetAllPoints(tf)
                markerFrame:SetFrameLevel(ff:GetFrameLevel() + 5)
                markerFrame:Show()
                tf._acMarker:Hide()

                tf._acBg:SetTexture("Interface\\Buttons\\WHITE8X8")
                tf._acBg:SetVertexColor(CELL_COLOR[1], CELL_COLOR[2], CELL_COLOR[3], CELL_COLOR[4])
                tf._acGhostFrame:Hide()
                tf._acGhost:SetVertexColor(0, 0, 0, 0)

                self.grids[side][r][c] = {
                    frame       = tf,
                    bg          = tf._acBg,
                    marker      = tf._acMarker,
                    markerFrame = markerFrame,
                    ghost       = tf._acGhost,
                    ghostFrame  = tf._acGhostFrame,
                    r = r, c = c, side = side,
                }
            end
        end
    end
end

-- ============================================================
-- GRIDS LEEREN
-- ============================================================
function R:ClearGrids()
    if self._cellPool then self._cellPool:ReleaseAll() end
    if self._shipOverlayPool then self._shipOverlayPool:ReleaseAll() end

    self.grids = { {}, {} }
    self._shipOverlayFrames = {}

    for side = 1, 2 do
        if self.gridFrames[side] then self.gridFrames[side]:Hide() end
        if self.gridLabels[side] then self.gridLabels[side]:Hide() end
    end

    self.hoverR = nil
    self.hoverC = nil
    self:ClearGhost()
end

-- ============================================================
-- SCHIFFS-TILE HELPER
-- ============================================================

-- Gibt den TGA-Pfad fuer ein Schiff zurueck (h oder v je nach Ausrichtung)
local function GetShipTilePath(ship)
    if not ship or not ship.icon then return nil end
    local entry = SHIP_TILES[ship.icon]
    if not entry then return nil end
    local tiles = ship.horizontal and entry.h or entry.v
    if not tiles then return nil end
    if #tiles == 1 then return tiles[1] end
    -- Zeppelin: ungerade ID → erste Variante, gerade → zweite
    return ship.id % 2 == 1 and tiles[1] or tiles[2]
end

-- Zeichnet einen Overlay-Frame ueber die gesamte Laenge des Schiffes.
-- Wird in _shipOverlayFrames gespeichert und in ClearGrids entfernt.
function R:DrawShipOverlay(side, ship, sideConf)
    local path = GetShipTilePath(ship)
    if not path then return end

    self:_EnsureGridPools()

    local size     = #self.grids[side]
    local cellBase = math.min(sideConf.w / size, sideConf.h / size)
    local cell     = math.max(10, math.floor(cellBase * sideConf.scale / 2) * 2)

    local startR = ship.startR
    local startC = ship.startC
    local horiz  = ship.horizontal
    local length = ship.length

    local px = sideConf.ofs_x + (startC - 1) * cell
    local py = math.abs(sideConf.ofs_y) + (startR - 1) * cell

    local fw = horiz and (length * cell - 1) or (cell - 1)
    local fh = horiz and (cell - 1)          or (length * cell - 1)

    local ff = self._fieldFrame
    local ov = self._shipOverlayPool:Acquire({})
    ov:SetParent(ff)
    ov:SetSize(fw, fh)
    ov:SetPoint("TOPLEFT", ff, "TOPLEFT", px, -py)
    ov:SetFrameLevel(ff:GetFrameLevel() + 4)
    ov._side = side

    local tex = ov._acTex
    tex:SetTexture(path)
    tex:SetAllPoints(ov)
    if side == 2 and ship.sunk then
        tex:SetVertexColor(1.0, 0.45, 0.45, 1.0)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
    ov:Show()

    table.insert(self._shipOverlayFrames, ov)
    return ov
end

-- ============================================================
-- ZELLE FAERBEN
-- ============================================================
function R:ColorCell(side, r, c, color, alpha)
    local cd = self.grids[side] and self.grids[side][r] and self.grids[side][r][c]
    if not cd then return end
    cd.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    cd.bg:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- ============================================================
-- MARKER SETZEN
-- ============================================================
function R:SetMarker(side, r, c, markerType)
    local cd = self.grids[side] and self.grids[side][r] and self.grids[side][r][c]
    if not cd then return end

    if markerType == "HIT" then
        cd.marker:SetTexture(AC_ASSETS.hit)
        cd.marker:SetVertexColor(1, 1, 1, 1)
        cd.marker:ClearAllPoints()
        local s = cd.frame:GetWidth() - 2
        cd.marker:SetSize(s, s)
        cd.marker:SetPoint("CENTER")
        cd.marker:Show()
        cd.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        cd.bg:SetVertexColor(HIT_COLOR[1], HIT_COLOR[2], HIT_COLOR[3], 0.7)

    elseif markerType == "MISS" then
        cd.marker:SetTexture(AC_ASSETS.miss)
        cd.marker:SetVertexColor(1, 1, 1, 1)
        cd.marker:ClearAllPoints()
        local s = cd.frame:GetWidth() - 2
        cd.marker:SetSize(s, s)
        cd.marker:SetPoint("CENTER")
        cd.marker:Show()
        cd.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        cd.bg:SetVertexColor(CELL_COLOR[1], CELL_COLOR[2], CELL_COLOR[3], 1)

    elseif markerType == "SUNK" then
        cd.bg:SetVertexColor(SUNK_COLOR[1], SUNK_COLOR[2], SUNK_COLOR[3], 1)
        cd.marker:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        cd.marker:SetVertexColor(1, 0.5, 0.5, 0.55)
        cd.marker:ClearAllPoints()
        local s = math.floor(cd.frame:GetWidth() * 0.6)
        cd.marker:SetSize(s, s)
        cd.marker:SetPoint("CENTER")
        cd.marker:Show()
    end
end

-- ============================================================
-- GHOST-VORSCHAU
-- ============================================================
function R:ClearGhost()
    for _, cd in ipairs(self.ghostCells) do
        if cd and cd.ghostFrame then
            cd.ghostFrame:Hide()
            cd.ghost:SetVertexColor(0, 0, 0, 0)
        end
    end
    self.ghostCells = {}
end

function R:UpdateGhost(state)
    self:ClearGhost()
    if not self.hoverR or not self.hoverC then return end
    if not state.currentShip then return end

    local ship  = state.currentShip
    local horiz = state.placementHoriz
    local valid = ArcadiaNexus.AC_Logic:IsValidPlacement(
        state.playerBoard, self.hoverR, self.hoverC, ship.length, horiz
    )
    local color = valid and GHOST_OK_COLOR or GHOST_BAD_COLOR

    for i = 0, ship.length - 1 do
        local tr = self.hoverR + (horiz and 0 or i)
        local tc = self.hoverC + (horiz and i or 0)
        local cd = self.grids[1] and self.grids[1][tr] and self.grids[1][tr][tc]
        if cd then
            cd.ghost:SetVertexColor(color[1], color[2], color[3], color[4])
            cd.ghostFrame:Show()
            table.insert(self.ghostCells, cd)
        end
    end
end

-- ============================================================
-- BOARD RENDERN
-- ============================================================
function R:RenderPlayerBoard(state)
    local board = state.playerBoard

    -- Overlays des Spieler-Boards zuruecksetzen
    -- (nur Spieler-Seite: neue Overlays werden unten neu gezeichnet)
    self:_ReleaseShipOverlaysExceptSide(2)

    for r = 1, board.size do
        for c = 1, board.size do
            local shipID = board.cells[r][c]
            local cd = self.grids[1] and self.grids[1][r] and self.grids[1][r][c]
            if cd then
                if cd.ghostFrame then cd.ghostFrame:Hide() end
                cd.ghost:SetVertexColor(0, 0, 0, 0)
                -- Hintergrund immer CELL_COLOR: TGA-Overlay traegt das Schiffsbild
                cd.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
                cd.bg:SetVertexColor(CELL_COLOR[1], CELL_COLOR[2], CELL_COLOR[3], 1)
                if shipID and shipID ~= 0 then
                    cd.frame:SetAlpha(1)
                end
                cd.marker:Hide()

                if board.hits[r][c] then
                    if shipID ~= 0 then
                        local ship = board.ships[shipID]
                        self:SetMarker(1, r, c, ship and ship.sunk and "SUNK" or "HIT")
                    else
                        self:SetMarker(1, r, c, "MISS")
                    end
                end
            end
        end
    end

    -- Schiff-Overlays zeichnen (ein Frame pro Schiff)
    if self._sideConf then
        local drawn = {}
        for _, ship in pairs(board.ships) do
            if not drawn[ship.id] then
                drawn[ship.id] = true
                local ov = self:DrawShipOverlay(1, ship, self._sideConf[1])
                if ov then ov._side = 1 end
            end
        end
    end
end

function R:RenderAiBoard(state)
    local board = state.aiBoard

    -- Gegner-Overlays zuruecksetzen (versenkten Schiffe neu zeichnen)
    self:_ReleaseShipOverlaysExceptSide(1)

    for r = 1, board.size do
        for c = 1, board.size do
            local shipID = board.cells[r][c]
            local wasHit = board.hits[r][c]
            local cd = self.grids[2] and self.grids[2][r] and self.grids[2][r][c]
            if cd then cd.marker:Hide() end

            if wasHit then
                if shipID ~= 0 then
                    local ship = board.ships[shipID]
                    if ship and ship.sunk then
                        self:ColorCell(2, r, c, SUNK_COLOR)
                        self:SetMarker(2, r, c, "SUNK")
                    else
                        self:ColorCell(2, r, c, CELL_COLOR)
                        self:SetMarker(2, r, c, "HIT")
                    end
                else
                    self:ColorCell(2, r, c, CELL_COLOR)
                    self:SetMarker(2, r, c, "MISS")
                end
            else
                self:ColorCell(2, r, c, CELL_COLOR)
            end
        end
    end

    -- Overlays fuer versenkte Schiffe zeichnen
    if self._sideConf then
        local drawn = {}
        for _, ship in pairs(board.ships) do
            if ship.sunk and not drawn[ship.id] then
                drawn[ship.id] = true
                local ov = self:DrawShipOverlay(2, ship, self._sideConf[2])
                if ov then ov._side = 2 end
            end
        end
    end
end

-- ============================================================
-- PLACEMENT-HINT
-- ============================================================
function R:UpdatePlacementHint(state)
    if not self._placementHintFS or not self._placementHintFrame then return end
    local LP = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
    if state.currentShip then
        self._placementHintFS:SetText(
            string.format(LP["placement_place"], state.currentShip.name, state.currentShip.length))
    else
        self._placementHintFS:SetText(LP["placement_done"])
    end
    self._placementHintFrame:Show()
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:ClearGrids()
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._placementHintFrame then self._placementHintFrame:Hide() end
    if self._battleHintFrame   then self._battleHintFrame:Hide()   end
    if self._randomBtn then self._randomBtn:Hide() end
    if self._logoTex   then self._logoTex:Show()   end

    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
        self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
        -- Nur aktivieren wenn Schwierigkeit bereits gesetzt
        local S = ArcadiaNexus.AC_Settings
        if S and S:Get("aiDifficulty") then
            self._startBtn:Enable()
        else
            self._startBtn:Disable()
        end
    end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(state)
    self.state = "PLACEMENT"
    if self._logoTex        then self._logoTex:Hide()         end
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._battleHintFrame then self._battleHintFrame:Hide() end

    self:BuildGrids(state.size)
    self:RenderPlayerBoard(state)

    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
        self._startBtn:SetLabel(L["btn_exit"] or "Beenden")
        self._startBtn:Enable()
    end
    if self._randomBtn  then self._randomBtn:Show()         end
    if self.keyFrame    then self.keyFrame:EnableKeyboard(true) end

    self:UpdatePlacementHint(state)
end

function R:OnPlacementUpdated(state)
    self:RenderPlayerBoard(state)
    self:ClearGhost()
    self:UpdatePlacementHint(state)
end

function R:OnBattleStarted(state)
    self.state = "BATTLE"
    if self._randomBtn then self._randomBtn:Hide() end
    if self._placementHintFrame then self._placementHintFrame:Hide() end

    self:RenderPlayerBoard(state)
    self:RenderAiBoard(state)

    if not self._battleHintFS or not self._battleHintFrame then return end
    self._battleHintFS:SetText(ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")["hint_battle"])
    self._battleHintFrame:Show()
end

function R:OnShotFired(state)
    self:RenderPlayerBoard(state)
    self:RenderAiBoard(state)

    if state.lastAiShot then
        local s  = state.lastAiShot
        local cd = self.grids[1] and self.grids[1][s.r] and self.grids[1][s.r][s.c]
        if cd then
            cd.frame:SetAlpha(0)
            UIFrameFadeIn(cd.frame, 0.25, 0, 1)
        end
    end
end

function R:OnGameOver(result)
    self.state = "GAMEOVER"

    local game = ArcadiaNexus.AC_Engine.activeGame
    if game then
        local state = game:GetBoardState()
        -- Alle nicht versenkten KI-Schiffe aufdecken via Overlay
        if self._sideConf then
            local drawn = {}
            for _, ship in pairs(state.aiBoard.ships) do
                if not drawn[ship.id] then
                    drawn[ship.id] = true
                    -- Noch nicht versenktes Schiff aufdecken
                    if not ship.sunk then
                        local ov = self:DrawShipOverlay(2, ship, self._sideConf[2])
                        if ov then ov._side = 2 end
                    end
                    -- Versenkte Schiffe wurden bereits von RenderAiBoard gezeichnet
                end
            end
        end
    end

    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then
        local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
        self._startBtn:SetLabel(L["btn_start"] or "Spiel starten")
    end

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")
    local parent = self._fieldFrame
    local won    = result == "WIN"

    UI.ShowArcadeResult(parent, {
        title      = won and L["result_win"] or L["result_loss"],
        titleColor = won and {1, 0.84, 0} or {1, 0.3, 0.3},
        subtitle   = won and L["result_win_sub"] or L["result_loss_sub"],
        gameId     = "AZEROTHCONQUEST",
        result     = won and "WIN" or "LOSS",
        L          = L,
        onRetry    = function()
            local Eng = ArcadiaNexus.AC_Engine
            local S   = ArcadiaNexus.AC_Settings
            if Eng and S then
                Eng:StartGame({ size = 10, aiDifficulty = S:Get("aiDifficulty") or "easy" })
            end
        end,
        onExit     = function()
            local Eng = ArcadiaNexus.AC_Engine
            if Eng then Eng:StopGame() end
        end,
    })
end

-- ============================================================
-- CELL CLICK
-- ============================================================
function R:OnCellClick(side, r, c)
    if self.state == "PLACEMENT" and side == 1 then
        ArcadiaNexus.AC_Engine:HandlePlacement(r, c)
    elseif self.state == "BATTLE" and side == 2 then
        ArcadiaNexus.AC_Engine:HandleShot(r, c)
    end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "AZEROTHCONQUEST",
    label     = "Azeroth Conquest",
    renderer  = "AC_Renderer",
    engine    = "AC_Engine",
    container = "_acContainer",
    category  = "STRATEGIE",
})
