-- ============================================================
--  ArcadiaNexus
--  Games/BarrelBrawl/Renderer.lua
--  Version: 1.0.0
--
--  Layout (analog GoblinBlast):
--    - Elemente direkt am GamesPanel-Container verankert
--    - Spielfeld 448x400 (logische Pixel) zentriert
--    - HUD: Leben/Level/Bonus ueber dem Feld, Score/Best in der
--      Controls-Leiste am BOTTOM (Dropdown + Start/Beenden)
--
--  Zero-Leak-Pooling:
--    - Statische Ebene (Traeger/Leitern) und Faesser laufen ueber
--      Textur-Pools; im Loop wird NIE ein Frame/eine Textur erzeugt
--      oder zerstoert – nur acquire/release aus den Pools.
--    - Maximal 10 aktive Faesser (Logic.MAX_BARRELS).
--    - EnterIdleState: Keyboard aus, Pools geleert, Dialog zu.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BRB_Renderer = {}
local R = ArcadiaNexus.BRB_Renderer

local GAME_ID = "BARREL_BRAWL"
local HEART_ICON = "|TInterface\\AddOns\\ArcadiaNexus\\Shared\\Lives\\heart.tga:16:18|t"

-- ============================================================
-- CFG – Layout-Konstanten
-- ============================================================
local CFG = {
    field_ofs_x  = 0,
    field_ofs_y  = 26,

    -- Border (border_bb.tga, 512x512, Goldlinie ~94% der Leinwand) –
    -- liegt als OVERLAY ueber dem Spielfeld (456x408). Hier nachjustieren.
    border_w     = 800,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = -9,

    bg_w         = 770,
    bg_h         = 530,
    bg_ofs_x     = 0,
    bg_ofs_y     = 20,
    bg_alpha     = 1.0,

    -- Logo (bb_logo.tga, 512x512, Inhalt ~473x506) – IDLE-Screen
    logo_w       = 256,
    logo_h       = 256,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,

    -- Hint-Text im IDLE-Screen (unterhalb des Logos)
    hint_ofs_y   = -132,

    -- HUD über dem Spielfeld
    hud_lives_w     = 160,
    hud_lives_h     = 28,
    hud_lives_x     = -148,
    hud_lives_y     = 241,
    hud_lives_alpha = 0.75,
    hud_level_w     = 160,
    hud_level_h     = 28,
    hud_level_x     = 148,
    hud_level_y     = 241,
    hud_level_alpha = 0.75,
    hud_time_w      = 120,
    hud_time_h      = 28,
    hud_time_x      = 0,
    hud_time_y      = 241,
    hud_time_alpha  = 0.75,
    hud_bonus_w     = 140,
    hud_bonus_h     = 28,
    hud_bonus_x     = 0,
    hud_bonus_y     = -190,
    hud_bonus_alpha = 0.75,
    hud_score_w     = 160,
    hud_score_h     = 28,
    hud_score_x     = -149,
    hud_score_y     = -190,
    hud_score_alpha = 0.75,
    hud_hs_w        = 160,
    hud_hs_h        = 28,
    hud_hs_x        = 149,
    hud_hs_y        = -190,
    hud_hs_alpha    = 0.75,

    -- Score / Highscore (Anker BOTTOM am Canvas)
    score_x      = 190,
    score_lbl_y  = -52,
    score_fs_y   = -72,
    hs_x         = 260,
    hs_lbl_y     = -52,
    hs_fs_y      = -72,

    controls_y   = 25,   -- HUD Score/Best am Canvas-Boden
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    player_size  = 32,
    troll_size   = 44,
    princess_size = 34,
    barrel_size  = 26,
    girder_h     = 32,
    ladder_w     = 32,
}

-- ============================================================
-- ASSET-PFADE (Phase-1-Pipeline: Games/BarrelBrawl/assets/sprites/)
-- ============================================================
local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\BarrelBrawl\\assets\\"
local TEX    = ASSETS .. "sprites\\"

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._fieldFrame    = nil
R._holder        = nil
R._controlsFrame = nil
R.keyFrame       = nil
R.state          = "IDLE"

-- Pools
R._staticActive  = {}     -- aktive Traeger-/Leiter-Texturen
R._staticPool    = {}
R._barrelTex     = {}     -- [barrelRef] = Textur
R._barrelPool    = {}
R._levelBuilt    = false

-- Feste Sprites
R._playerTex     = nil
R._trollTex      = nil
R._princessTex   = nil

-- Border & Logo
R._borderFrame   = nil
R._borderTex     = nil
R._logoTex       = nil

-- HUD
R._scoreLbl, R._scoreFS = nil, nil
R._hsLbl, R._hsFS       = nil, nil
R._livesFS, R._levelFS, R._timeFS, R._bonusFS = nil, nil, nil, nil
R._bannerFS      = nil
R._pauseFS       = nil
R._flashTex      = nil
R._hintFS        = nil
R._startBtn      = nil
R._lastDiff      = nil

-- ============================================================
-- Hilfen
-- ============================================================
local function Loc()
    return ArcadiaNexus.GetLocaleTable(GAME_ID)
end

-- Fusspunkt-Anker: Sprite-Unterkante auf logische Position (x, y)
local function PlaceBottom(tex, holder, x, y)
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOM", holder, "TOPLEFT", x, -y)
end

-- Mittelpunkt-Anker
local function PlaceCenter(tex, holder, x, y)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", holder, "TOPLEFT", x, -y)
end

-- ── Statischer Pool (Traeger/Leitern) ────────────────────────
function R:_AcquireStatic()
    local tex = table.remove(self._staticPool)
    if not tex then
        tex = self._holder:CreateTexture(nil, "BACKGROUND")
    end
    tex:SetTexCoord(0, 1, 0, 1)
    tex:Show()
    self._staticActive[#self._staticActive + 1] = tex
    return tex
end

function R:_ReleaseStatics()
    for i = #self._staticActive, 1, -1 do
        local tex = self._staticActive[i]
        tex:Hide()
        tex:ClearAllPoints()
        self._staticPool[#self._staticPool + 1] = tex
        self._staticActive[i] = nil
    end
    self._levelBuilt = false
end

-- ── Fass-Pool (max. Logic.MAX_BARRELS aktiv) ─────────────────
function R:_AcquireBarrel(ref)
    local tex = self._barrelTex[ref]
    if not tex then
        tex = table.remove(self._barrelPool)
        if not tex then
            tex = self._holder:CreateTexture(nil, "ARTWORK")
            tex:SetSize(CFG.barrel_size, CFG.barrel_size)
        end
        tex:Show()
        self._barrelTex[ref] = tex
    end
    return tex
end

function R:_ReleaseAllBarrels()
    for ref, tex in pairs(self._barrelTex) do
        tex:Hide()
        tex:ClearAllPoints()
        self._barrelPool[#self._barrelPool + 1] = tex
        self._barrelTex[ref] = nil
    end
end

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    if not self.frame then return end
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateSprites()
    self:_CreateHUD()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreateKeyFrame()
    self:EnterIdleState()

    local Eng = ArcadiaNexus.Engine
    Eng:On("BRB_GAME_STARTED", function(b) R:OnGameStarted(b) end)
    Eng:On("BRB_GAME_STOPPED", function()  R:EnterIdleState() end)
end

-- ============================================================
-- FRAME-AUFBAU
-- ============================================================
function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_BRB_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._brbContainer = f

    -- Session-aware OnHide: nie blind StopGame()
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide(GAME_ID, ArcadiaNexus.BRB_Engine, function(E)
            if E.state == "PLAYING" or E.state == "PAUSED" then
                E:SaveAndPause()
            end
        end)
        if R.state == "MENU" or R.state == "PLAYING" then
            R:EnterIdleState()
        end
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local Logic = ArcadiaNexus.BRB_Logic

    local ff = CreateFrame("Frame", nil, self._canvas, "BackdropTemplate")
    ff:SetSize(Logic.FIELD_W + 8, Logic.FIELD_H + 8)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ff:SetBackdropColor(0.04, 0.03, 0.08, 1)   -- dunkle Hoehle
    ff:SetBackdropBorderColor(0.35, 0.28, 0.16, 1)
    self._fieldFrame = ff

    local holder = CreateFrame("Frame", nil, ff)
    holder:SetSize(Logic.FIELD_W, Logic.FIELD_H)
    holder:SetPoint("CENTER", ff, "CENTER", 0, 0)
    holder:Hide()
    self._holder = holder

    -- Treffer-Rotblitz (ueber allem im Feld)
    local flash = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    flash:SetAllPoints(holder)
    flash:SetColorTexture(1, 0.1, 0.1, 0.25)
    flash:Hide()
    self._flashTex = flash
end

function R:_CreateBackground()
    if self._bgTex or not self._canvas then return end
    local tex = self._canvas:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex:SetTexture(ASSETS .. "background\\background_bb")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", self._canvas, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- Border-Frame: eigener Frame eine Ebene ueber _fieldFrame (Muster 2048/
-- GoblinBlast). Kachel-Texturen liegen sonst ueber reinen Texturen des
-- Parent — daher braucht der Border einen eigenen Frame mit explizit
-- hoeherem FrameLevel.
function R:_CreateBorderTex()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(ASSETS .. "border\\border_bb")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(self._canvas, ff)
    end
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ASSETS .. "logo\\bb_logo",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function R:_CreateSprites()
    local holder = self._holder

    local player = holder:CreateTexture(nil, "OVERLAY", nil, 2)
    player:SetSize(CFG.player_size, CFG.player_size)
    player:Hide()
    self._playerTex = player

    local troll = holder:CreateTexture(nil, "OVERLAY", nil, 1)
    troll:SetSize(CFG.troll_size, CFG.troll_size)
    troll:SetTexture(TEX .. "troll_idle")
    troll:Hide()
    self._trollTex = troll

    local princess = holder:CreateTexture(nil, "OVERLAY", nil, 1)
    princess:SetSize(CFG.princess_size, CFG.princess_size)
    princess:SetTexture(TEX .. "princess_help")
    princess:Hide()
    self._princessTex = princess
end

function R:_CreateKeyFrame()
    if self.keyFrame then return end
    local mapped = {
        a = "A", d = "D", w = "W", s = "S", p = "P",
        A = "A", D = "D", W = "W", S = "S", P = "P",
        UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT",
        SPACE = "SPACE", ESCAPE = "ESCAPE",
    }
    local kf = CreateFrame("Frame", nil, self._canvas)
    kf:SetAllPoints(self._canvas)
    kf:SetPropagateKeyboardInput(false)
    kf:EnableKeyboard(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local k = mapped[key]
        if k then ArcadiaNexus.BRB_Engine:HandleKeyDown(k) end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local k = mapped[key]
        if k and k ~= "SPACE" and k ~= "ESCAPE" and k ~= "P" then
            ArcadiaNexus.BRB_Engine:HandleKeyUp(k)
        end
    end)
    self.keyFrame = kf
end

-- ============================================================
-- STATISCHE EBENE (Traeger + Leitern) – ausserhalb des Loops
-- ============================================================
function R:_BuildLevel()
    if self._levelBuilt then return end
    local Logic = ArcadiaNexus.BRB_Logic
    local holder = self._holder

    -- Leitern zuerst (liegen unter den Traegern)
    for _, lad in ipairs(Logic.LADDERS) do
        local y = lad.yTop
        while y < lad.yBottom do
            local h = math.min(32, lad.yBottom - y)
            local tex = self:_AcquireStatic()
            tex:SetDrawLayer("BACKGROUND", 0)
            tex:SetTexture(TEX .. "ladder_piece")
            tex:SetSize(CFG.ladder_w, h)
            tex:SetTexCoord(0, 1, 0, h / 32)
            tex:SetPoint("TOPLEFT", holder, "TOPLEFT", lad.x - CFG.ladder_w / 2, -y)
            y = y + h
        end
    end

    -- Traeger: 32er-Stuecke, jede Kachel folgt der Neigung
    for i, pf in ipairs(Logic.PLATFORMS) do
        local x = pf.x0
        while x < pf.x1 do
            local w = math.min(32, pf.x1 - x)
            local sy = Logic.PlatformYAt(i, x + w / 2)
            local tex = self:_AcquireStatic()
            tex:SetDrawLayer("BACKGROUND", 1)
            tex:SetTexture(TEX .. "girder_piece")
            tex:SetSize(w, CFG.girder_h)
            tex:SetTexCoord(0, w / 32, 0, 1)
            tex:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -math.floor(sy + 0.5) + 1)
            x = x + w
        end
    end

    self._levelBuilt = true
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = Loc()
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Score") .. ": 0",
        shown = false,
    })
    self._hsBox, self._hsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_hs_w, h = CFG.hud_hs_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_hs_x, y = CFG.hud_hs_y,
        alpha = CFG.hud_hs_alpha,
        text = (L["lbl_highscore"] or "Best") .. ": 0",
        shown = false,
    })
    self._livesBox, self._livesFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_lives_w, h = CFG.hud_lives_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_lives_x, y = CFG.hud_lives_y,
        alpha = CFG.hud_lives_alpha,
        shown = false,
    })
    self._levelBox, self._levelFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_level_w, h = CFG.hud_level_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_level_x, y = CFG.hud_level_y,
        alpha = CFG.hud_level_alpha,
        shown = false,
    })
    self._timeBox, self._timeFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        shown = false,
    })
    self._bonusBox, self._bonusFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_bonus_w, h = CFG.hud_bonus_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_bonus_x, y = CFG.hud_bonus_y,
        alpha = CFG.hud_bonus_alpha,
        shown = false,
    })

    -- Level-Banner (Rettung)
    local bannerFS = self._holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    bannerFS:SetPoint("CENTER", self._holder, "CENTER", 0, 60)
    bannerFS:SetTextColor(1, 0.84, 0)
    bannerFS:Hide()
    self._bannerFS = bannerFS

    -- Pause-Overlay
    local pauseFS = self._holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pauseFS:SetPoint("CENTER", self._holder, "CENTER", 0, 0)
    pauseFS:SetTextColor(0.9, 0.9, 0.9)
    pauseFS:SetJustifyH("CENTER")
    pauseFS:Hide()
    self._pauseFS = pauseFS

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, CFG.hint_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_SetHudShown(shown)
    local boxes = {
        self._scoreBox, self._hsBox, self._livesBox,
        self._levelBox, self._timeBox, self._bonusBox, self._goldGrid,
    }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

function R:UpdateHUD(board)
    local L = Loc()
    local Format = ArcadiaNexus.Format
    if self._scoreFS then
        self._scoreFS:SetText((L["lbl_score"] or "Score") .. ": " .. Format.Score(board.score or 0))
    end
    if self._hsFS then
        local SM = ArcadiaNexus.ScoreManager
        local hs = SM and SM:GetBestScore(GAME_ID, board.difficulty) or 0
        self._hsFS:SetText((L["lbl_highscore"] or "Best") .. ": " .. Format.Score(math.max(hs, board.score or 0)))
    end
    if self._livesFS then
        self._livesFS:SetFormattedText("|cffffd700%s:|r |cffff6060%s|r",
            L["lbl_lives"] or "Leben", string.rep(HEART_ICON, math.max(0, board.lives)))
    end
    if self._levelFS then
        self._levelFS:SetFormattedText("|cffffd700%s %d|r",
            L["lbl_level"] or "Level", board.level)
    end
    if self._timeFS then
        self._timeFS:SetText("|cffaaaaaa" .. Format.SecondsMMSS(math.floor(board.time or 0), false) .. "|r")
    end
    if self._bonusFS then
        self._bonusFS:SetFormattedText("|cffffd700%s:|r |cff8aff42%s|r",
            L["lbl_bonus"] or "Bonus", Format.Score(board.bonus or 0))
    end
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = Loc()
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local S = ArcadiaNexus.BRB_Settings

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, CFG.dd_w, "",
        {
            { key = "easy",   label = L["diff_easy"]   },
            { key = "normal", label = L["diff_normal"] },
            { key = "hard",   label = L["diff_hard"]   },
        },
        function() return (S and S:Get("difficulty")) or "normal" end,
        function(key)
            R._lastDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._startBtn = startBtn

    local exitBtn = UI.CreateArcadiaButton(cf, L["btn_exit"] or "Beenden", CFG.btn_w, CFG.btn_h)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    exitBtn:SetScript("OnClick", function()
        if R.state == "MENU" then
            R:EnterIdleState()
            return
        end
        local E = ArcadiaNexus.BRB_Engine
        if not E then return end
        if E.state == "GAMEOVER" then
            E:StopGame()
        elseif E.state ~= "IDLE" then
            E:SaveAndPause()
            R:EnterIdleState()
        end
    end)
    exitBtn:Hide()
    self._exitBtn = exitBtn
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = Loc()
    local S  = ArcadiaNexus.BRB_Settings
    if not UI or not UI.CreateSaveSlotMenu or not self._fieldFrame then return end

    self._slotMenu = UI.CreateSaveSlotMenu({
        parent        = self._fieldFrame,
        confirmParent = self._fieldFrame,
        maxSlots      = (S and S.MAX_SLOTS) or 3,
        L             = L,
        title         = L and L.menu_title,
        loadSlot      = function(slot) return S and S:LoadSlot(slot) end,
        deleteSlot    = function(slot) if S then S:DeleteSlot(slot) end end,
        formatInfo    = function(save, loc)
            local score = (ArcadiaNexus.Format and ArcadiaNexus.Format.Score(save.score or 0))
                or tostring(save.score or 0)
            return string.format(loc.slot_info or "Level %d · %s", save.level or 1, score)
        end,
        isPaused      = function() return true end,
        onNewGame     = function(slot)
            local S2 = ArcadiaNexus.BRB_Settings
            ArcadiaNexus.BRB_Engine:StartGame({
                slot = slot, mode = "new",
                difficulty = R._lastDiff or (S2 and S2:Get("difficulty")) or "normal",
            })
        end,
        onContinue    = function(slot)
            ArcadiaNexus.BRB_Engine:StartGame({ slot = slot, mode = "continue" })
        end,
    })
end

function R:EnterSlotMenu()
    self.state = "MENU"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoTex  then self._logoTex:Hide()  end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._hintFS   then self._hintFS:Hide()   end
    if self._slotMenu then self._slotMenu:Show() end
end

function R:_StartNewGame()
    local S = ArcadiaNexus.BRB_Settings
    ArcadiaNexus.BRB_Engine:StartGame({
        slot       = S and S:GetActiveSlot() or 1,
        mode       = "new",
        difficulty = R._lastDiff or (S and S:Get("difficulty")) or "normal",
    })
end

-- ============================================================
-- DYNAMISCHE SPRITES (pro Tick mit dem Board synchronisiert)
-- ============================================================
function R:_SyncSprites(board)
    local Logic  = ArcadiaNexus.BRB_Logic
    local holder = self._holder

    -- Faesser (Pool, max. Logic.MAX_BARRELS)
    local seen = {}
    for _, b in ipairs(board.barrels) do
        seen[b] = true
        local tex = self:_AcquireBarrel(b)
        local frame = (math.floor(b.rollT * 8) % 2 == 0) and 1 or 2
        tex:SetTexture(TEX .. "barrel_roll_" .. frame)
        PlaceCenter(tex, holder, b.x, b.y)
    end
    for ref, tex in pairs(self._barrelTex) do
        if not seen[ref] then
            tex:Hide()
            tex:ClearAllPoints()
            self._barrelPool[#self._barrelPool + 1] = tex
            self._barrelTex[ref] = nil
        end
    end

    -- Spieler
    local p  = board.player
    local pt = self._playerTex
    local sprite
    if p.state == "CLIMB" then
        sprite = (math.floor(p.y / 8) % 2 == 0) and "gnome_climb_1" or "gnome_climb_2"
    elseif p.state == "JUMP" then
        sprite = "gnome_run_1"
    elseif p.moving then
        sprite = (math.floor(p.animT * 8) % 2 == 0) and "gnome_run_1" or "gnome_run_2"
    else
        sprite = "gnome_idle"
    end
    pt:SetTexture(TEX .. sprite)
    if p.dir < 0 and p.state ~= "CLIMB" then
        pt:SetTexCoord(1, 0, 0, 1)
    else
        pt:SetTexCoord(0, 1, 0, 1)
    end
    if p.invuln > 0 then
        pt:SetAlpha((math.floor(GetTime() * 8) % 2 == 0) and 0.35 or 1)
    else
        pt:SetAlpha(1)
    end
    PlaceBottom(pt, holder, p.x, p.y)
    pt:Show()

    -- Troll (Wurf-Animation: kurzes Anheben)
    local troll = board.troll
    local lift = (troll.throwT > 0) and 3 or 0
    PlaceBottom(self._trollTex, holder, troll.x, troll.y - lift)
    self._trollTex:Show()

    -- Prinzessin
    PlaceBottom(self._princessTex, holder, board.princess.x, board.princess.y)
    self._princessTex:Show()

    -- Banner & Treffer-Blitz
    if board.bannerT and board.bannerT > 0 then
        self._bannerFS:SetFormattedText(Loc()["banner_rescue"] or "Level %d", board.level)
        self._bannerFS:SetAlpha(math.min(1, board.bannerT))
        self._bannerFS:Show()
    else
        self._bannerFS:Hide()
    end
    if board.flashT and board.flashT > 0 then
        self._flashTex:SetAlpha(math.min(0.35, board.flashT * 0.4))
        self._flashTex:Show()
    else
        self._flashTex:Hide()
    end
end

-- ============================================================
-- FRAME-UPDATE (von der Engine pro Tick aufgerufen)
-- ============================================================
function R:OnFrame(board, events)
    self:_SyncSprites(board)
    self:UpdateHUD(board)
end

-- ============================================================
-- PAUSE
-- ============================================================
function R:OnPauseChanged(paused)
    if paused then
        self._pauseFS:SetText(Loc()["overlay_paused"] or "PAUSED")
        self._pauseFS:Show()
    else
        self._pauseFS:Hide()
    end
end

-- ============================================================
-- GAME OVER (Standard-Arcade-Dialog: Retry + Exit)
-- ============================================================
function R:OnGameOver(board, isNewHighscore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "GAMEOVER"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    self._pauseFS:Hide()

    local result = (board.stats.rescues > 0) and "WIN" or "LOSS"
    UI.ShowArcadeResult(self._fieldFrame, {
        gameId       = GAME_ID,
        difficulty   = board.difficulty,
        result       = result,
        score        = board.score,
        newHighscore = isNewHighscore,
        lines        = {
            string.format(L["result_level"]   or "Level: %d", board.level),
            string.format(L["result_rescues"] or "Rettungen: %d", board.stats.rescues),
            string.format(L["result_jumped"]  or "Fässer: %d", board.stats.jumped),
            string.format(L["result_time"]    or "Zeit: %s",
                ArcadiaNexus.Format.SecondsMMSS(math.floor(board.time or 0), false)),
        },
        L            = L,
        onRetry      = function() R:_StartNewGame() end,
        onExit       = function() ArcadiaNexus.BRB_Engine:StopGame() end,
    })
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(board)
    self.state     = "PLAYING"
    self._lastDiff = board.difficulty

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS then self._hintFS:Hide() end
    if self._logoTex then self._logoTex:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end
    self._pauseFS:Hide()

    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end

    self:_SetHudShown(true)

    if self.keyFrame then
        self.keyFrame:EnableKeyboard(true)
        self.keyFrame:Show()
    end

    self._holder:Show()
    self:_BuildLevel()
    self:_ReleaseAllBarrels()
    self:_SyncSprites(board)
    self:UpdateHUD(board)
end

-- ============================================================
-- IDLE STATE (kompletter Teardown: Keys, Pools, Dialog)
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_ReleaseAllBarrels()
    self:_ReleaseStatics()
    if self._playerTex   then self._playerTex:Hide()   end
    if self._trollTex    then self._trollTex:Hide()    end
    if self._princessTex then self._princessTex:Hide() end
    if self._bannerFS    then self._bannerFS:Hide()    end
    if self._pauseFS     then self._pauseFS:Hide()     end
    if self._flashTex    then self._flashTex:Hide()    end
    if self._holder      then self._holder:Hide()      end

    self:_SetHudShown(false)
    if self._logoTex  then self._logoTex:Show()  end
    if self._slotMenu then self._slotMenu:Hide() end

    if self.keyFrame then
        self.keyFrame:EnableKeyboard(false)
        self.keyFrame:Hide()
    end

    if self._startBtn then
        self._startBtn:SetLabel(Loc()["btn_start"])
        self._startBtn:Show()
    end
    if self._exitBtn then self._exitBtn:Hide() end

    if self._hintFS then
        self._hintFS:SetText(Loc()["hint_start"] or "")
        self._hintFS:Show()
    end
end

-- ============================================================
-- SLASH-BEFEHL – /barrelbrawl oeffnet den Hub direkt beim Spiel
-- ============================================================
SLASH_ARCADIABARRELBRAWL1 = "/barrelbrawl"
SLASH_ARCADIABARRELBRAWL2 = "/bbrawl"
SlashCmdList["ARCADIABARRELBRAWL"] = function()
    local main = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetMainFrame
        and _G.ArcadiaNexusUI.GetMainFrame()
    if main and not main:IsShown() and _G.Nexus_UI and _G.Nexus_UI.Toggle then
        _G.Nexus_UI.Toggle()
    end
    if _G.Nexus_UI and _G.Nexus_UI.SetTab then
        _G.Nexus_UI.SetTab("GAMES")
    end
    local fn = ArcadiaNexus.UI and ArcadiaNexus.UI._ActivateGameFn
    if fn then fn(GAME_ID) end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = GAME_ID,
    label     = "Barrel Brawl",
    renderer  = "BRB_Renderer",
    engine    = "BRB_Engine",
    container = "_brbContainer",
    category  = "ARCADE",
})
