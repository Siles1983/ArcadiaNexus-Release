--[[
    ArcadiaNexus
    Games/2048/Renderer.lua
    Version: 2.1.0

    Layout-Strategie:
      - Panel-großer Lifecycle-Container mit zentriertem 600x498 Design-Canvas
      - Alle Elemente per CENTER-Ankern positioniert
      - Spielfeld oben-mittig, Controls unten in fester Leiste
      - Border einmalig als OVERLAY-Textur über dem Spielfeld
      - Logo via UI.CreateGameLogo
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TDG_Renderer = {}
local Renderer = ArcadiaNexus.TDG_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================

local CFG = {
    -- Spielfeld
    field_w      = 450,
    field_h      = 450,
    field_ofs_x  = 0,
    field_ofs_y  = 5,

    -- Border
    border_w     = 790,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 11,

    -- Hintergrund (eigene Maße, unabhängig vom Rahmen)
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1.0,

    -- Logo (IDLE)
    logo_w       = 452,
    logo_h       = 432,
    logo_ofs_x   = 0,
    logo_ofs_y   = 10,

    -- HUD: Punkte / Highscore (Canvas, unabhängig)
    hud_score_w     = 180,
    hud_score_h     = 28,
    hud_score_x     = -135,
    hud_score_y     = 241,
    hud_score_alpha = 0.75,
    hud_best_w      = 180,
    hud_best_h      = 28,
    hud_best_x      = 135,
    hud_best_y      = 241,
    hud_best_alpha  = 0.75,

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
}


-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld

-- Border über dem Spielfeld

-- Logo im Spielfeld (IDLE-Zustand)

-- Score-Boxen (relativ zum Spielfeld-CENTER)

-- ============================================================
-- FARB-THEMEN
-- ============================================================

local THEMES = {
    CLASSIC = {
        name = "Classic (Orange)", boardBg = {0.44,0.40,0.36}, slotBg = {0.58,0.53,0.49},
        tiles = {
            [2]    = {bg={0.93,0.89,0.85}, fg={0.47,0.43,0.40}},
            [4]    = {bg={0.93,0.88,0.78}, fg={0.47,0.43,0.40}},
            [8]    = {bg={0.95,0.69,0.47}, fg={1.00,0.97,0.92}},
            [16]   = {bg={0.96,0.58,0.39}, fg={1.00,0.97,0.92}},
            [32]   = {bg={0.96,0.49,0.37}, fg={1.00,0.97,0.92}},
            [64]   = {bg={0.96,0.37,0.23}, fg={1.00,0.97,0.92}},
            [128]  = {bg={0.93,0.81,0.45}, fg={1.00,0.97,0.92}},
            [256]  = {bg={0.93,0.80,0.38}, fg={1.00,0.97,0.92}},
            [512]  = {bg={0.93,0.78,0.31}, fg={1.00,0.97,0.92}},
            [1024] = {bg={0.93,0.77,0.25}, fg={1.00,0.97,0.92}},
            [2048] = {bg={1.00,0.84,0.00}, fg={1.00,1.00,1.00}},
            [4096] = {bg={1.00,0.92,0.50}, fg={1.00,1.00,1.00}},
        },
    },
    HORDE = {
        name = "Horde (Rot/Gold)", boardBg = {0.25,0.08,0.08}, slotBg = {0.35,0.12,0.12},
        tiles = {
            [2]    = {bg={0.55,0.18,0.18}, fg={1.00,0.90,0.80}},
            [4]    = {bg={0.65,0.22,0.22}, fg={1.00,0.90,0.80}},
            [8]    = {bg={0.78,0.28,0.18}, fg={1.00,0.95,0.85}},
            [16]   = {bg={0.88,0.32,0.18}, fg={1.00,0.95,0.85}},
            [32]   = {bg={0.90,0.35,0.10}, fg={1.00,0.95,0.85}},
            [64]   = {bg={0.95,0.38,0.05}, fg={1.00,0.95,0.85}},
            [128]  = {bg={0.85,0.65,0.10}, fg={0.20,0.08,0.08}},
            [256]  = {bg={0.90,0.72,0.10}, fg={0.20,0.08,0.08}},
            [512]  = {bg={0.95,0.78,0.12}, fg={0.20,0.08,0.08}},
            [1024] = {bg={0.98,0.84,0.15}, fg={0.20,0.08,0.08}},
            [2048] = {bg={1.00,0.92,0.20}, fg={0.20,0.08,0.08}},
            [4096] = {bg={1.00,0.96,0.40}, fg={0.10,0.04,0.04}},
        },
    },
    ALLIANCE = {
        name = "Allianz (Blau/Silber)", boardBg = {0.10,0.15,0.30}, slotBg = {0.15,0.22,0.42},
        tiles = {
            [2]    = {bg={0.60,0.70,0.90}, fg={0.10,0.15,0.35}},
            [4]    = {bg={0.50,0.62,0.88}, fg={0.10,0.15,0.35}},
            [8]    = {bg={0.35,0.50,0.88}, fg={1.00,1.00,1.00}},
            [16]   = {bg={0.28,0.42,0.85}, fg={1.00,1.00,1.00}},
            [32]   = {bg={0.22,0.35,0.82}, fg={1.00,1.00,1.00}},
            [64]   = {bg={0.18,0.28,0.78}, fg={1.00,1.00,1.00}},
            [128]  = {bg={0.70,0.78,0.85}, fg={0.10,0.15,0.30}},
            [256]  = {bg={0.78,0.84,0.90}, fg={0.10,0.15,0.30}},
            [512]  = {bg={0.85,0.90,0.95}, fg={0.10,0.15,0.30}},
            [1024] = {bg={0.90,0.94,0.98}, fg={0.10,0.15,0.30}},
            [2048] = {bg={1.00,0.96,0.70}, fg={0.10,0.15,0.30}},
            [4096] = {bg={1.00,0.98,0.80}, fg={0.05,0.10,0.20}},
        },
    },
    NIGHTELF = {
        name = "Nachtelf (Lila/Grün)", boardBg = {0.08,0.05,0.18}, slotBg = {0.14,0.08,0.28},
        tiles = {
            [2]    = {bg={0.35,0.20,0.55}, fg={0.90,0.80,1.00}},
            [4]    = {bg={0.42,0.25,0.65}, fg={0.90,0.80,1.00}},
            [8]    = {bg={0.20,0.55,0.35}, fg={0.90,1.00,0.90}},
            [16]   = {bg={0.18,0.62,0.38}, fg={0.90,1.00,0.90}},
            [32]   = {bg={0.55,0.20,0.65}, fg={1.00,0.90,1.00}},
            [64]   = {bg={0.65,0.15,0.75}, fg={1.00,0.90,1.00}},
            [128]  = {bg={0.20,0.75,0.45}, fg={0.05,0.15,0.10}},
            [256]  = {bg={0.25,0.82,0.50}, fg={0.05,0.15,0.10}},
            [512]  = {bg={0.78,0.35,0.90}, fg={1.00,0.95,1.00}},
            [1024] = {bg={0.85,0.42,0.95}, fg={1.00,0.95,1.00}},
            [2048] = {bg={0.55,0.95,0.65}, fg={0.05,0.20,0.10}},
            [4096] = {bg={0.70,1.00,0.78}, fg={0.05,0.20,0.10}},
        },
    },
    GOBLIN = {
        name = "Goblin (Grün/Gelb)", boardBg = {0.08,0.18,0.05}, slotBg = {0.12,0.26,0.08},
        tiles = {
            [2]    = {bg={0.38,0.62,0.22}, fg={0.05,0.15,0.05}},
            [4]    = {bg={0.44,0.70,0.25}, fg={0.05,0.15,0.05}},
            [8]    = {bg={0.55,0.78,0.10}, fg={0.05,0.15,0.05}},
            [16]   = {bg={0.65,0.85,0.10}, fg={0.05,0.15,0.05}},
            [32]   = {bg={0.78,0.88,0.08}, fg={0.05,0.15,0.05}},
            [64]   = {bg={0.88,0.90,0.05}, fg={0.05,0.15,0.05}},
            [128]  = {bg={0.95,0.85,0.10}, fg={0.05,0.15,0.05}},
            [256]  = {bg={0.98,0.78,0.08}, fg={0.05,0.10,0.05}},
            [512]  = {bg={1.00,0.70,0.05}, fg={0.05,0.10,0.05}},
            [1024] = {bg={1.00,0.60,0.02}, fg={0.05,0.10,0.05}},
            [2048] = {bg={1.00,0.92,0.00}, fg={0.05,0.10,0.05}},
            [4096] = {bg={1.00,0.96,0.30}, fg={0.03,0.08,0.03}},
        },
    },
}

local function GetActiveTheme()
    local S  = _G.ArcadiaNexus and _G.ArcadiaNexus.TDG_Settings
    local id = (S and S:Get("colorTheme")) or "CLASSIC"
    return THEMES[id] or THEMES.CLASSIC
end

local function GetTileColor(value)
    local theme = GetActiveTheme()
    return theme.tiles[value] or {bg={0.50,0.20,0.60}, fg={1,1,1}}
end

local function CreateTilePool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "2048.Tiles",
        create = function(poolParent)
            poolParentRef = poolParent
            local tf = CreateFrame("Frame", nil, poolParent)
            local bgTex = tf:CreateTexture(nil, "ARTWORK")
            bgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            bgTex:SetAllPoints(tf)
            local lbl = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            lbl:SetPoint("CENTER")
            lbl:SetJustifyH("CENTER")
            tf._bgTex = bgTex
            tf._label = lbl
            return tf
        end,
        onRelease = function(tf)
            tf:Hide()
            tf:SetAlpha(1)
            tf:SetScale(1)
            tf:ClearAllPoints()
            if tf._bgTex then tf._bgTex:SetVertexColor(0, 0, 0, 0) end
            if tf._label then tf._label:SetText("") end
            if poolParentRef then tf:SetParent(poolParentRef) end
        end,
    })
end

local function CreateSlotPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "2048.Slots",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Frame", nil, poolParent)
            local tex = f:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            tex:SetAllPoints(f)
            f._slotTex = tex
            return f
        end,
        onRelease = function(f)
            f:Hide()
            f:ClearAllPoints()
            if f._slotTex then
                f._slotTex:SetTexture("Interface\\Buttons\\WHITE8X8")
                f._slotTex:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================

Renderer.frame        = nil
Renderer._canvas      = nil
Renderer._controlsFrame = nil
Renderer._fieldFrame  = nil
Renderer._borderFrame = nil
Renderer._borderTex   = nil
Renderer._logoTex     = nil
Renderer.keyFrame     = nil
Renderer.state        = "IDLE"
Renderer.selectedSize = 4
Renderer.boardSize    = 4
Renderer.cellPx       = 0
Renderer.tiles        = {}
Renderer.emptySlots   = {}
Renderer.boardBg      = nil
Renderer.scoreFS      = nil
Renderer.bestFS       = nil
Renderer._scoreBox    = nil
Renderer._bestBox     = nil
Renderer._goldGrid    = nil
Renderer._startBtn    = nil
Renderer._animation = ArcadiaNexus.GameLoop.Create(nil)
Renderer._exitBtn = nil

-- ============================================================
-- INIT
-- ============================================================

function Renderer:Init()
    local S = ArcadiaNexus.TDG_Settings
    self.selectedSize = S:Get("boardSize")
    if not ArcadiaNexus.TDG_Logic:GetDifficulty(self.selectedSize) then self.selectedSize = 4 end
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateScoreBoxes()
    self:_CreateControls()
    self:_CreateKeyFrame()
    self:EnterIdleState()
    local Bus = ArcadiaNexus.Engine
    Bus:On("TDG_GAME_STARTED", function(state)
        Renderer.state = "PLAYING"
        Renderer._slotMenu:Hide()
        ArcadiaNexus.UI.HideResultDialog(Renderer._fieldFrame)
        Renderer:RenderBoard(state)
        Renderer:UpdateScore(state)
        Renderer:RefreshControls()
        Renderer._scoreBox:Show()
        Renderer._bestBox:Show()
        Renderer._goldGrid:Show()
        Renderer.keyFrame:EnableKeyboard(true)
    end)
    Bus:On("TDG_BOARD_UPDATED", function(state)
        Renderer:AnimateBoard(state)
        Renderer:UpdateScore(state)
    end)
    Bus:On("TDG_WIN_PROMPT", function(state, result)
        Renderer:ShowGameOverOverlay(state, result)
    end)
    Bus:On("TDG_GAME_OVER", function(state, result)
        Renderer:ShowGameOverOverlay(state, result)
    end)
    Bus:On("TDG_GAME_CONTINUED", function(state)
        Renderer.state = "PLAYING"
        Renderer:UpdateBoard(state)
        Renderer:RefreshControls()
        Renderer.keyFrame:EnableKeyboard(true)
    end)
    Bus:On("TDG_RESULT_FAILED", function()
        Renderer.state = "RESULT_PENDING"
        Renderer._slotMenu:Hide()
        Renderer:_CancelAnimation()
        local E = ArcadiaNexus.TDG_Engine
        if E.activeGame then
            Renderer:RenderBoard(E.activeGame:GetBoardState())
            Renderer:UpdateScore(E.activeGame:GetBoardState())
        end
        Renderer:RefreshControls()
        Renderer._scoreBox:Show()
        Renderer._bestBox:Show()
        Renderer._goldGrid:Show()
        Renderer.keyFrame:EnableKeyboard(false)
        local L = ArcadiaNexus.GetLocaleTable("2048")
        ArcadiaNexus.UI.ShowArcadeResult(Renderer._fieldFrame, {
            title = L.result_pending, result = "WIN", xp = 0, L = L,
            lines = { L.result_retry_hint },
            buttons = {
                {label=L.btn_retry_result, onClick=function() ArcadiaNexus.TDG_Engine:RetryResult() end},
                {label=L.btn_pause, onClick=function() ArcadiaNexus.TDG_Engine:SaveAndPause(); Renderer:ShowSlotMenu() end},
            },
        })
    end)
    Bus:On("TDG_APPEARANCE_CHANGED", function()
        local E = ArcadiaNexus.TDG_Engine
        if E.activeGame then Renderer:RenderBoard(E.activeGame:GetBoardState()) end
        Renderer:RefreshControls()
    end)
    Bus:On("TDG_GAME_STOPPED", function() Renderer:EnterIdleState() end)
end


-- ============================================================
-- FRAME-AUFBAU
-- ============================================================

function Renderer:_CreateMainFrame()
    if self.frame then return end
    if _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel then
        local gamesPanel = _G.ArcadiaNexusUI.GetGamesPanel()
        local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
            outerName = "ArcadiaNexus_2048_Container",
            designW   = 600,
            designH   = 498,
        })
        local container = viewport.outer
        container:Hide()
        self.frame = container
        self._canvas = viewport.canvas
        if _G.ArcadiaNexus then
            _G.ArcadiaNexus._2048Container = container
        end

        container:SetScript("OnHide", function()
            Renderer:_CancelAnimation()
            if Renderer._slotMenu then Renderer._slotMenu:Hide() end
            local E = ArcadiaNexus.TDG_Engine
            if E.activeGame and not E._sessionId then E:StopGame() end
            ArcadiaNexus.GameSession:HandleRendererHide("2048", ArcadiaNexus.TDG_Engine, function(E)
                if E.activeGame then
                    E:SaveAndPause()
                end
            end)
        end)
    end
end

function Renderer:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_w, CFG.field_h)
    -- Mittig im GamesPanel, leicht nach oben verschoben
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.44, 0.40, 0.36, 1)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function Renderer:_CreateBackground()
    local ff = self._fieldFrame
    if not ff then return end
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\2048\\assets\\background\\background_2048")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function Renderer:_CreateBorderTex()
    -- Border-Frame: eigener Frame eine Ebene über _fieldFrame
    -- Kachel-Frames (CreateFrame-Kinder von _fieldFrame) liegen sonst über
    -- reinen Texturen des Parent — daher braucht der Border einen eigenen Frame
    -- mit explizit höherem FrameLevel.
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\2048\\assets\\border\\border_2048")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, ff)
    end
end

function Renderer:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        "Interface\\AddOns\\ArcadiaNexus\\Games\\2048\\assets\\logo\\logo_2048",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function Renderer:_CreateScoreBoxes()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("2048")
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self.scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["score_label"] or "Punkte") .. ": 0",
        shown = false,
    })
    self._bestBox, self.bestFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_best_x, y = CFG.hud_best_y,
        alpha = CFG.hud_best_alpha,
        text = (L["best_label"] or "Highscore") .. ": 0",
        shown = false,
    })
end

function Renderer:_CreateControls()
    local L, UI, S = ArcadiaNexus.GetLocaleTable("2048"), ArcadiaNexus.UI, ArcadiaNexus.TDG_Settings
    local E = ArcadiaNexus.TDG_Engine
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf
    local anchor = CreateFrame("Frame", nil, cf)
    anchor:SetSize(CFG.dd_w, CFG.btn_h)
    anchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    self._sizeDropdown = UI.CreateSimpleDropdown(anchor, 0, 0, CFG.dd_w, "", {
        {key="3", label=L.size_small}, {key="4", label=L.size_normal}, {key="5", label=L.size_large},
    }, function()
        return tostring(E.activeGame and E.activeGame.board.size or S:Get("boardSize"))
    end, function(key)
        if E.activeGame then Renderer:RefreshControls(); return end
        if S:Set("boardSize", tonumber(key)) then Renderer.selectedSize = tonumber(key) end
    end)
    local startBtn = UI.CreateArcadiaButton(cf, L.btn_start, CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        if E.activeGame then E:SaveAndPause() end
        Renderer:ShowSlotMenu()
    end)
    self._startBtn = startBtn
    local exitBtn = UI.CreateArcadiaButton(cf, L.btn_exit, CFG.btn_w, CFG.btn_h)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    exitBtn:SetScript("OnClick", function() Renderer:EnterIdleState() end)
    self._exitBtn = exitBtn
    self._slotMenu = UI.CreateSaveSlotMenu({
        parent = self._fieldFrame, maxSlots = S.MAX_SLOTS, L = L,
        loadSlot = function(slot) return S:LoadSlot(slot) end,
        deleteSlot = function(slot) S:DeleteSlot(slot) end,
        canContinue = function(save) return E:CanContinueSave(save) end,
        formatInfo = function(save)
            if not ArcadiaNexus.TDG_Logic:ValidateSave(save)
                or ((save.phase ~= "FINISHED" or save.resultPending) and not E:CanContinueSave(save)) then return L.slot_invalid end
            local text = string.format(L.slot_info, save.boardSize, save.boardSize,
                ArcadiaNexus.Format.Score(save.score))
            if save.resultPending then return text .. " · " .. L.result_pending end
            return text .. (save.phase == "FINISHED" and (" · " .. L.slot_finished) or "")
        end,
        isPaused = function(save) return save.phase ~= "FINISHED" or save.resultPending end,
        onNewGame = function(slot)
            E:StartGame({slot=slot, mode="new", size=S:Get("boardSize"), overwrite=true})
        end,
        onContinue = function(slot) E:StartGame({slot=slot, mode="continue"}) end,
        onCancel = function() Renderer:EnterIdleState() end,
    })
end

function Renderer:RefreshControls()
    local E, L = ArcadiaNexus.TDG_Engine, ArcadiaNexus.GetLocaleTable("2048")
    if self._sizeDropdown then
        if E.activeGame and self._sizeDropdown.CloseMenu then self._sizeDropdown:CloseMenu() end
        self._sizeDropdown:SetEnabled(not E.activeGame)
        self._sizeDropdown:RefreshDisplay()
    end
    if self._startBtn then
        self._startBtn:SetLabel(E.activeGame and L.btn_pause or L.btn_start)
        if self.state == "SLOT_MENU" then self._startBtn:Hide() else self._startBtn:Show() end
    end
    if self._exitBtn then
        if self.state == "SLOT_MENU" then self._exitBtn:Show() else self._exitBtn:Hide() end
    end
end

function Renderer:ShowSlotMenu()
    self:EnterIdleState()
    self.state = "SLOT_MENU"
    self._logoTex:Hide()
    self._slotMenu:Show()
    self:RefreshControls()
end

function Renderer:_CreateKeyFrame()
    if self.keyFrame then return end
    local kf = CreateFrame("Frame", "ArcadiaNexus_2048_KeyFrame", self._fieldFrame)
    kf:SetAllPoints(self._fieldFrame)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)

    local keyMap = {
        ["W"]="UP", ["S"]="DOWN", ["A"]="LEFT", ["D"]="RIGHT",
        ["UP"]="UP", ["DOWN"]="DOWN", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT",
    }
    kf:SetScript("OnKeyDown", function(_, key)
        local dir = keyMap[key]
        if dir then
            kf:SetPropagateKeyboardInput(false)
            ArcadiaNexus.TDG_Engine:HandlePlayerMove(dir)
        else
            kf:SetPropagateKeyboardInput(true)
        end
    end)
    self.keyFrame = kf
end

-- ============================================================
-- IDLE STATE
-- ============================================================

function Renderer:_EnsureBoardPools()
    if not self._tilePool then self._tilePool = CreateTilePool() end
    if not self._slotPool then self._slotPool = CreateSlotPool() end
end

function Renderer:_ReleaseBoardVisuals()
    self:_CancelAnimation()
    if self._tilePool then self._tilePool:ReleaseAll() end
    if self._slotPool then self._slotPool:ReleaseAll() end
    self.tiles = {}
    self.emptySlots = {}
end

function Renderer:EnterIdleState()
    self.state = "IDLE"
    local L = ArcadiaNexus.GetLocaleTable("2048")

    self:_ReleaseBoardVisuals()

    if self.boardBg    then self.boardBg:Hide() end
    if self._fieldFrame then self._fieldFrame:SetBackdropColor(0, 0, 0, 0) end
    if self.scoreFS    then self.scoreFS:SetText("0") end
    if self._scoreBox  then self._scoreBox:Hide() end
    if self._bestBox   then self._bestBox:Hide()  end
    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self.keyFrame   then self.keyFrame:EnableKeyboard(false) end
    if self._logoTex    then self._logoTex:Show() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._startBtn   then self._startBtn:SetLabel(L["btn_start"]) end
    if self._slotMenu then self._slotMenu:Hide() end
    self:RefreshControls()
    if self._goldGrid   then self._goldGrid:Hide() end
end

-- ============================================================
-- RENDERBOARD
-- ============================================================

function Renderer:RenderBoard(state)
    if self._logoTex then self._logoTex:Hide() end

    self:_ReleaseBoardVisuals()
    self:_EnsureBoardPools()

    local parent  = self._fieldFrame
    local size    = state.size
    local GAP     = 8
    local boardPx = CFG.field_w
    local cell    = math.floor((boardPx - GAP * (size + 1)) / size)

    self.boardSize = size
    self.cellPx    = cell

    local theme = GetActiveTheme()
    if not self.boardBg then
        self.boardBg = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
        self.boardBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    self.boardBg:ClearAllPoints()
    self.boardBg:SetAllPoints(parent)
    self.boardBg:SetVertexColor(theme.boardBg[1], theme.boardBg[2], theme.boardBg[3], 1)
    self.boardBg:Show()
    self._fieldFrame:SetBackdropColor(theme.boardBg[1], theme.boardBg[2], theme.boardBg[3], 1)

    for r = 1, size do
        self.emptySlots[r] = {}
        for c = 1, size do
            local px = GAP + (c-1) * (cell + GAP)
            local py = GAP + (r-1) * (cell + GAP)
            local slotFrame = self._slotPool:Acquire({})
            slotFrame:SetParent(parent)
            slotFrame:SetSize(cell, cell)
            slotFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", px, -py)
            slotFrame._slotTex:SetVertexColor(theme.slotBg[1], theme.slotBg[2], theme.slotBg[3], 1)
            slotFrame:Show()
            self.emptySlots[r][c] = slotFrame
        end
    end

    for r = 1, size do
        self.tiles[r] = {}
        for c = 1, size do
            local px = GAP + (c-1) * (cell + GAP)
            local py = GAP + (r-1) * (cell + GAP)

            local tf = self._tilePool:Acquire({})
            tf:SetParent(parent)
            tf:SetSize(cell, cell)
            tf:SetPoint("TOPLEFT", parent, "TOPLEFT", px, -py)
            tf._bgTex:SetVertexColor(0, 0, 0, 0)
            tf._label:SetText("")
            tf:Show()

            self.tiles[r][c] = { frame = tf, bgTex = tf._bgTex, label = tf._label }
        end
    end

    if self._borderFrame then self._borderFrame:Show() end

    self:UpdateBoard(state)
end

-- ============================================================
-- UPDATEBOARD
-- ============================================================

function Renderer:_CancelAnimation()
    self._animation:Stop()
    self._animating = nil
end

function Renderer:_TilePoint(frame, row, col)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self._fieldFrame, "TOPLEFT",
        8 + (col - 1) * (self.cellPx + 8), -(8 + (row - 1) * (self.cellPx + 8)))
end

function Renderer:_PaintTile(tile, value)
    local colors = GetTileColor(value)
    tile.frame:SetAlpha(1)
    tile.frame:SetScale(1)
    if value == 0 then
        tile.bgTex:SetVertexColor(0, 0, 0, 0)
        tile.label:SetText("")
    else
        tile.bgTex:SetVertexColor(colors.bg[1], colors.bg[2], colors.bg[3], 1)
        tile.label:SetText(tostring(value))
        tile.label:SetTextColor(colors.fg[1], colors.fg[2], colors.fg[3])
        local digits = #tostring(value)
        tile.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\\\FRIZQT__.TTF",
            math.min(30, math.floor(self.cellPx / math.max(3, digits * 0.65))), "OUTLINE")
    end
    tile.frame:Show()
end

function Renderer:UpdateBoard(state)
    self:_CancelAnimation()
    for r = 1, state.size do
        for c = 1, state.size do
            local tile = self.tiles[r] and self.tiles[r][c]
            if tile then
                self:_TilePoint(tile.frame, r, c)
                self:_PaintTile(tile, state.cells[r][c])
            end
        end
    end
end

function Renderer:AnimateBoard(state)
    self:_CancelAnimation()
    if ArcadiaNexus.TDG_Settings:Get("reducedMotion") or not state.motions then self:UpdateBoard(state); return end
    local E, game = ArcadiaNexus.TDG_Engine, ArcadiaNexus.TDG_Engine.activeGame
    local runId = state.runId
    for r = 1, state.size do
        for c = 1, state.size do self.tiles[r][c].frame:Hide() end
    end
    for _, motion in ipairs(state.motions) do
        self:_PaintTile(self.tiles[motion.fromRow][motion.fromCol], motion.value)
    end
    local elapsed, settled = 0, false
    self._animating = true
    self._animation:Start(function(dt)
        if E.activeGame ~= game or not game or game.runId ~= runId then self:_CancelAnimation(); return end
        elapsed = elapsed + dt
        if elapsed < 0.12 then
            local p = elapsed / 0.12
            p = 1 - (1 - p) * (1 - p)
            for _, motion in ipairs(state.motions) do
                local tile = self.tiles[motion.fromRow][motion.fromCol]
                self:_TilePoint(tile.frame, motion.fromRow + (motion.toRow-motion.fromRow)*p,
                    motion.fromCol + (motion.toCol-motion.fromCol)*p)
            end
        else
            if not settled then
                -- Draw final merge values before spawn/pop feedback.
                for r = 1, state.size do
                    for c = 1, state.size do
                        local tile = self.tiles[r][c]
                        self:_TilePoint(tile.frame, r, c)
                        self:_PaintTile(tile, state.cells[r][c])
                    end
                end
                settled = true
            end
            local p = math.min(1, (elapsed - 0.12) / 0.10)
            for r = 1, state.size do
                for c = 1, state.size do
                    local tile = self.tiles[r][c]
                    if state.lastSpawn and state.lastSpawn.row == r and state.lastSpawn.col == c then
                        tile.frame:SetAlpha(p)
                    elseif state.merged[r][c] then tile.frame:SetScale(1 + math.sin(p*math.pi)*0.06) end
                end
            end
            if p == 1 then self:UpdateBoard(state) end
        end
    end)
end


-- ============================================================
-- SCORE UPDATE
-- ============================================================

function Renderer:UpdateScore(state)
    local L = ArcadiaNexus.GetLocaleTable("2048")
    if self.scoreFS then
        self.scoreFS:SetText((L["score_label"] or "Punkte") .. ": " .. tostring(state.score or 0))
    end
    if self.bestFS then
        self.bestFS:SetText((L["best_label"] or "Highscore") .. ": " .. tostring(state.bestScore or 0))
    end
end

-- ============================================================
-- GAME OVER OVERLAY
-- ============================================================

function Renderer:ShowGameOverOverlay(state, result)
    if not self._fieldFrame then return end
    local E = ArcadiaNexus.TDG_Engine
    local game = E.activeGame
    if not game then return end
    state = state or game:GetBoardState()
    result = result or {}
    local UI, L = ArcadiaNexus.UI, ArcadiaNexus.GetLocaleTable("2048")
    self.state = state.phase == "AWAITING_WIN_CHOICE" and "WIN_PROMPT" or "FINISHED"
    self.keyFrame:EnableKeyboard(false)
    self:RefreshControls()
    local buttons = {}
    if state.phase == "AWAITING_WIN_CHOICE" then
        buttons[#buttons+1] = {label=L.btn_keep_playing, onClick=function() E:ContinueAfterWin() end}
        buttons[#buttons+1] = {label=L.btn_finish, onClick=function() if E:FinishRun() then Renderer:ShowSlotMenu() end end}
    else
        buttons[#buttons+1] = {label=L.btn_slots, onClick=function() E:StopGame(); Renderer:ShowSlotMenu() end}
    end
    local lines = { string.format(L.highest_tile, state.highestTile) }
    if result.localReplay and state.result == "WIN" then lines[#lines+1] = L.win_already_recorded end
    UI.ShowArcadeResult(self._fieldFrame, {
        title = state.result == "WIN" and L.win_title or L.go_title,
        result = state.result, score = state.score, gameId = "2048", difficulty = state.difficulty,
        xp = result.awardedXP or 0, gold = result.awardedGold or 0,
        newHighscore = result.newHighscore == true, highscore = ArcadiaNexus.ScoreManager:GetBestScore("2048", state.difficulty),
        lines = lines, L = L, buttons = buttons,
    })
end


-- ============================================================
-- REGISTRIERUNG
-- ============================================================

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "2048",
    label     = "2048",
    renderer  = "TDG_Renderer",
    engine    = "TDG_Engine",
    container = "_2048Container",
    category  = "DENKSPIELE",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\2048\\assets\\logo\\logo_2048",
    xp        = 12,
})
