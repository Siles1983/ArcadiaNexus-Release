-- ============================================================
--  ArcadiaNexus
--  Games/GoblinBlast/Renderer.lua
--  Version: 1.0.0
--
--  Layout-Strategie (analog Snake):
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - Spielfeld (13x11 Kacheln à 32px) zentriert
--    - HUD: Leben/Gegner ueber dem Feld, Score/Best in der Controls-Leiste
--    - Controls-Leiste am BOTTOM: Dropdown Schwierigkeit + Start/Beenden
--    - Overlay via UI.ShowArcadeResult auf _fieldFrame
--
--  Sprites:
--    Statische Ebene (Boden/Waende) als feste Zell-Texturen.
--    Dynamische Objekte (Bomben, Explosionen, Power-ups, Gegner) laufen
--    ueber einen Textur-Pool, der pro Frame mit dem Board synchronisiert wird.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.GB_Renderer = {}
local R = ArcadiaNexus.GB_Renderer
local HEART_ICON = "|TInterface\\AddOns\\ArcadiaNexus\\Shared\\Lives\\heart.tga:16:18|t"

-- ============================================================
-- CFG – Layout-Konstanten
-- ============================================================
local CFG = {
    tile         = 32,
    field_ofs_x  = 0,
    field_ofs_y  = 15,

    -- Border (border_gb.tga, 437x418 px) – liegt als OVERLAY ueber dem
    -- Spielfeld (424x360 px). Groesse/Position hier nachjustieren.
    border_w     = 800,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 0,

    -- Hintergrund (relativ zu _fieldFrame CENTER)
    bg_w         = 800,
    bg_h         = 550,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1,

    -- Logo (logo_gb.tga, 465x411 px) – IDLE-Screen, proportional skaliert
    logo_w       = 465,
    logo_h       = 411,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,

    -- Hint-Text im IDLE-Screen (unterhalb des Logos)
    hint_ofs_y   = -130,

    hud_score_w      = 280,
    hud_score_h      = 28,
    hud_score_x      = 0,
    hud_score_y      = -180,
    hud_score_alpha  = 0.75,
    hud_stats_w      = 500,
    hud_stats_h      = 28,
    hud_stats_x      = 0,
    hud_stats_y      = 220,
    hud_stats_alpha  = 0.75,

    controls_y   = 25,   -- HUD Score/Best am Canvas-Boden
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\GoblinBlast\\assets\\"
local TEX    = ASSETS .. "sprites\\"

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._fieldFrame    = nil
R._gridHolder    = nil
R._controlsFrame = nil
R._logoTex       = nil
R._bgTex         = nil
R._borderFrame   = nil
R._borderTex     = nil
R.state          = "IDLE"

R._cellTex       = {}     -- [cellKey] = statische Zell-Textur
R._sprites       = {}     -- [ref] = dynamische Textur
R._spritePool    = {}
R._playerTex     = nil

R.keyFrame       = nil

R._scoreLbl      = nil
R._scoreFS       = nil
R._hsLbl         = nil
R._hsFS          = nil
R._livesFS       = nil
R._enemiesFS     = nil
R._levelFS       = nil
R._timeFS        = nil
R._bombsFS       = nil
R._radiusFS      = nil
R._hintFS        = nil
R._startBtn      = nil
R._resumeBtn     = nil
R._savedHintFS   = nil
R._lastDiff      = nil

-- ============================================================
-- Hilfen
-- ============================================================
local function Loc()
    return ArcadiaNexus.GetLocaleTable("GOBLINBLAST")
end

-- Sprite-Mittelpunkt auf Kachel-Koordinate (float, in Kachel-Einheiten)
local function PlaceSprite(tex, holder, tx, ty)
    local t = CFG.tile
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", holder, "TOPLEFT", tx * t + t / 2, -(ty * t + t / 2))
end

function R:_AcquireSprite(ref)
    local tex = self._sprites[ref]
    if not tex then
        tex = table.remove(self._spritePool)
        if not tex then
            tex = self._gridHolder:CreateTexture(nil, "ARTWORK")
        end
        tex:Show()
        self._sprites[ref] = tex
    end
    return tex
end

function R:_ReleaseAllSprites()
    for ref, tex in pairs(self._sprites) do
        tex:Hide()
        tex:SetVertexColor(1, 1, 1, 1)
        tex:SetAlpha(1)
        table.insert(self._spritePool, tex)
        self._sprites[ref] = nil
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
    self:_CreateHUD()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreateKeyFrame()
    self:EnterIdleState()

    local Eng = ArcadiaNexus.Engine
    Eng:On("GB_GAME_STARTED", function(b) R:OnGameStarted(b) end)
    Eng:On("GB_GAME_STOPPED", function()  R:EnterIdleState() end)
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
        outerName = "ArcadiaNexus_GB_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._gbContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("GOBLINBLAST", ArcadiaNexus.GB_Engine, function(E)
            if E.state == "PLAYING" or E.state == "LEVELWIN" then
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
    local Logic  = ArcadiaNexus.GB_Logic
    local fieldW = Logic.GRID_W * CFG.tile
    local fieldH = Logic.GRID_H * CFG.tile

    local ff = CreateFrame("Frame", nil, self._canvas, "BackdropTemplate")
    ff:SetSize(fieldW + 8, fieldH + 8)
    ff:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ff:SetBackdropColor(0.05, 0.06, 0.05, 0)
    ff:SetBackdropBorderColor(0.25, 0.35, 0.20, 0)
    self._fieldFrame = ff

    local holder = CreateFrame("Frame", nil, ff)
    holder:SetSize(fieldW, fieldH)
    holder:SetPoint("CENTER", ff, "CENTER", 0, 0)
    holder:Hide()
    self._gridHolder = holder
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(ASSETS .. "background\\background_gb")
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

-- Border-Frame: eigener Frame eine Ebene ueber _fieldFrame (Muster 2048).
-- Kachel-Texturen liegen sonst ueber reinen Texturen des Parent — daher
-- braucht der Border einen eigenen Frame mit explizit hoeherem FrameLevel.
function R:_CreateBorderTex()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(ASSETS .. "border\\border_gb")
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ASSETS .. "logo\\logo_gb",
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function R:_CreateKeyFrame()
    if self.keyFrame then return end
    local kf = CreateFrame("Frame", nil, self._canvas)
    kf:SetAllPoints(self._canvas)
    kf:SetPropagateKeyboardInput(false)
    kf:EnableKeyboard(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local mapped = {
            w = "W", a = "A", s = "S", d = "D",
            W = "W", A = "A", S = "S", D = "D",
            UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT",
            SPACE = "SPACE", ESCAPE = "ESCAPE",
        }
        local k = mapped[key]
        if k then ArcadiaNexus.GB_Engine:HandleKeyDown(k) end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local mapped = {
            w = "W", a = "A", s = "S", d = "D",
            W = "W", A = "A", S = "S", D = "D",
            UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT",
        }
        local k = mapped[key]
        if k then ArcadiaNexus.GB_Engine:HandleKeyUp(k) end
    end)
    self.keyFrame = kf
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
        text = (L["lbl_score"] or "Score") .. ": 0   " .. (L["lbl_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })
    self._statsBox, self._statsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_stats_w, h = CFG.hud_stats_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_stats_x, y = CFG.hud_stats_y,
        alpha = CFG.hud_stats_alpha,
        shown = false,
    })

    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, CFG.hint_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_SetHudShown(shown)
    local boxes = { self._scoreBox, self._statsBox }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

function R:UpdateHUD(board)
    local L = Loc()
    local SM = ArcadiaNexus.ScoreManager
    local hs = SM and SM:GetBestScore("GOBLINBLAST", board.difficulty) or 0
    if self._scoreFS then
        self._scoreFS:SetText(string.format("%s: %s   %s: %s",
            L["lbl_score"] or "Score", tostring(board.score or 0),
            L["lbl_highscore"] or "Highscore", tostring(math.max(hs, board.score or 0))))
    end
    if self._statsFS then
        local p = board.player or {}
        local t = ArcadiaNexus.Format.SecondsMMSS(math.floor(board.time or 0), false)
        local bombs = math.max(0, (p.bombsMax or 0) - (p.bombsActive or 0))
        self._statsFS:SetText(string.format(
            "%s: %s   %s: %d/%d   %s: %s   %s: %d/%d   %s: %d   %s: %d",
            L["lbl_lives"] or "Leben", string.rep(HEART_ICON, math.max(0, board.lives or 0)),
            L["lbl_level"] or "Level", board.level or 0, ArcadiaNexus.GB_Levels.COUNT,
            L["lbl_time"] or "Zeit", t,
            L["lbl_bombs"] or "Bomben", bombs, p.bombsMax or 0,
            L["lbl_enemies"] or "Gegner", #(board.enemies or {}),
            L["lbl_radius"] or "Radius", p.radius or 0))
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

    local S = ArcadiaNexus.GB_Settings

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
        function() return (S and S:Get("difficulty")) or "easy" end,
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
        local E = ArcadiaNexus.GB_Engine
        if not E then return end
        if E.state == "GAMEOVER" or E.state == "LEVELWIN" then
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
    local S  = ArcadiaNexus.GB_Settings
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
            local E = ArcadiaNexus.GB_Engine
            local S2 = ArcadiaNexus.GB_Settings
            if E then
                E:StartGame({
                    slot = slot, mode = "new",
                    difficulty = R._lastDiff or (S2 and S2:Get("difficulty")) or "easy",
                })
            end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.GB_Engine
            if E then E:StartGame({ slot = slot, mode = "continue" }) end
        end,
    })
end

function R:EnterSlotMenu()
    self.state = "MENU"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoTex  then self._logoTex:Hide()  end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end
    if self._resumeBtn then self._resumeBtn:Hide() end
    if self._slotMenu then self._slotMenu:Show() end
end

function R:_StartNewGame()
    local S = ArcadiaNexus.GB_Settings
    ArcadiaNexus.GB_Engine:StartGame({
        slot       = S and S:GetActiveSlot() or 1,
        mode       = "new",
        difficulty = R._lastDiff or (S and S:Get("difficulty")) or "easy",
    })
end

-- ============================================================
-- STATISCHES GITTER (Boden / Waende)
-- ============================================================
function R:RebuildStaticGrid(board)
    local Logic = ArcadiaNexus.GB_Logic
    local t     = CFG.tile
    for y = 0, Logic.GRID_H - 1 do
        for x = 0, Logic.GRID_W - 1 do
            local k   = Logic.CellKey(x, y)
            local tex = self._cellTex[k]
            if not tex then
                tex = self._gridHolder:CreateTexture(nil, "BACKGROUND")
                tex:SetSize(t, t)
                tex:SetPoint("TOPLEFT", self._gridHolder, "TOPLEFT", x * t, -y * t)
                self._cellTex[k] = tex
            end
            local cell = board.grid[y][x]
            if cell == Logic.SOLID then
                tex:SetTexture(TEX .. "wall_solid")
            elseif cell == Logic.BRICK then
                tex:SetTexture(TEX .. "wall_destructible")
            else
                tex:SetTexture(TEX .. "floor")
            end
            tex:Show()
        end
    end
end

-- ============================================================
-- DYNAMISCHE SPRITES (jeden Frame mit dem Board synchronisiert)
-- ============================================================
local WALK_FRAMES = { 1, 2, 3, 2 }

function R:_SyncSprites(board)
    local t    = CFG.tile
    local seen = {}

    -- Power-ups (eingefaerbte Bomben-Sprites)
    for _, pu in pairs(board.powerups) do
        seen[pu] = true
        local tex = self:_AcquireSprite(pu)
        tex:SetDrawLayer("BORDER", 0)
        tex:SetTexture(TEX .. "bomb")
        tex:SetSize(t - 10, t - 10)
        if pu.kind == "radius" then
            tex:SetVertexColor(1, 0.55, 0.1)      -- orange = groesserer Radius
        else
            tex:SetVertexColor(0.3, 0.7, 1)       -- blau = mehr Bomben
        end
        PlaceSprite(tex, self._gridHolder, pu.x, pu.y)
    end

    -- Bomben (Puls kurz vor der Explosion)
    for _, b in ipairs(board.bombs) do
        seen[b] = true
        local tex = self:_AcquireSprite(b)
        tex:SetDrawLayer("ARTWORK", 0)
        tex:SetTexture(TEX .. "bomb")
        tex:SetVertexColor(1, 1, 1)
        local pulse = 1 + 0.08 * math.sin(GetTime() * (b.t < 0.8 and 25 or 8))
        tex:SetSize((t - 4) * pulse, (t - 4) * pulse)
        PlaceSprite(tex, self._gridHolder, b.gx, b.gy)
    end

    -- Explosionen
    for _, e in ipairs(board.explosions) do
        for _, c in ipairs(e.cells) do
            seen[c] = true
            local tex = self:_AcquireSprite(c)
            tex:SetDrawLayer("ARTWORK", 1)
            tex:SetTexture(TEX .. c.tex)
            tex:SetVertexColor(1, 1, 1)
            tex:SetSize(t, t)
            PlaceSprite(tex, self._gridHolder, c.x, c.y)
        end
    end

    -- Gegner (rot eingefaerbte Spieler-Sprites)
    for _, e in ipairs(board.enemies) do
        seen[e] = true
        local tex = self:_AcquireSprite(e)
        tex:SetDrawLayer("OVERLAY", 0)
        local frame = e.moving and WALK_FRAMES[(math.floor(e.animT * 6) % 4) + 1] or 1
        tex:SetTexture(TEX .. "player_" .. e.dir .. "_" .. frame)
        tex:SetVertexColor(1, 0.35, 0.35)
        tex:SetSize(t, t)
        PlaceSprite(tex, self._gridHolder, e.px, e.py - 0.15)
    end

    -- Nicht mehr vorhandene Sprites freigeben
    for ref, tex in pairs(self._sprites) do
        if not seen[ref] then
            tex:Hide()
            tex:SetVertexColor(1, 1, 1, 1)
            tex:SetAlpha(1)
            table.insert(self._spritePool, tex)
            self._sprites[ref] = nil
        end
    end

    -- Spieler
    local p = board.player
    if not self._playerTex then
        local tex = self._gridHolder:CreateTexture(nil, "OVERLAY", nil, 1)
        tex:SetSize(t, t)
        self._playerTex = tex
    end
    local pt    = self._playerTex
    local frame = p.moving and WALK_FRAMES[(math.floor(p.animT * 8) % 4) + 1] or 1
    pt:SetTexture(TEX .. "player_" .. p.dir .. "_" .. frame)
    if p.invuln > 0 then
        pt:SetAlpha((math.floor(GetTime() * 8) % 2 == 0) and 0.35 or 1)
    else
        pt:SetAlpha(1)
    end
    PlaceSprite(pt, self._gridHolder, p.px, p.py - 0.15)
    pt:Show()
end

-- ============================================================
-- FRAME-UPDATE (von der Engine pro Tick aufgerufen)
-- ============================================================
function R:OnFrame(board, events)
    for _, ev in ipairs(events) do
        if ev.type == "wall" then
            self:RebuildStaticGrid(board)
        end
    end
    self:_SyncSprites(board)
    self:UpdateHUD(board)
end

-- ============================================================
-- OVERLAYS (Level geschafft / Finale / Niederlage)
-- ============================================================
local function ResultLines(board, withTimeBonus)
    local L = Loc()
    local t = math.floor(board.time or 0)
    local lines = {
        string.format(L["result_level"]   or "Level: %d",  board.level),
        string.format(L["result_walls"]   or "Wände: %d",  board.stats.walls),
        string.format(L["result_enemies"] or "Gegner: %d", board.stats.enemies),
        string.format(L["result_time"] or "Zeit: %s",
            ArcadiaNexus.Format.SecondsMMSS(t, false)),
    }
    if withTimeBonus and (board.lastTimeBonus or 0) > 0 then
        table.insert(lines,
            string.format(L["result_time_bonus"] or "Zeitbonus: +%d", board.lastTimeBonus))
    end
    return lines
end

function R:ShowLevelWin(board, isNewHighscore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "LEVELWIN"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end

    UI.ShowArcadeResult(self._fieldFrame, {
        title        = L["result_level_win_title"] or "Level geschafft!",
        titleColor   = { 0.3, 1, 0.3 },
        score        = board.score,
        gameId       = "GOBLINBLAST",
        difficulty   = board.difficulty,
        result       = "WIN",
        newHighscore = isNewHighscore,
        lines        = ResultLines(board, true),
        L            = L,
        buttons      = UI.ResultDialogButtons.Level(L,
            function() ArcadiaNexus.GB_Engine:ContinueToNextLevel() end,
            function() R:_StartNewGame() end,
            function() ArcadiaNexus.GB_Engine:StopGame() end
        ),
    })
end

function R:ShowFinalWin(board, isNewHighscore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "WON"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then self._startBtn:SetLabel(L["btn_start"]) end

    UI.ShowArcadeResult(self._fieldFrame, {
        title        = L["result_final_win_title"] or "Alle Level geschafft!",
        titleColor   = { 1, 0.84, 0 },
        score        = board.score,
        gameId       = "GOBLINBLAST",
        difficulty   = board.difficulty,
        result       = "WIN",
        newHighscore = isNewHighscore,
        lines        = ResultLines(board, true),
        L            = L,
        onRetry      = function() R:_StartNewGame() end,
        onExit       = function() ArcadiaNexus.GB_Engine:StopGame() end,
    })
end

-- ============================================================
-- LEVEL-WECHSEL (vom Engine nach "Weiter"-Button)
-- ============================================================
function R:OnLevelAdvanced(board)
    self.state = "PLAYING"
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self.keyFrame then
        self.keyFrame:EnableKeyboard(true)
        self.keyFrame:Show()
    end
    self._gridHolder:Show()
    self:RebuildStaticGrid(board)
    self:_ReleaseAllSprites()
    self:_SyncSprites(board)
    self:UpdateHUD(board)
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(board)
    self.state     = "PLAYING"
    self._lastDiff = board.difficulty

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end
    if self._slotMenu then self._slotMenu:Hide() end

    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end

    self:_SetHudShown(true)
    if self._resumeBtn   then self._resumeBtn:Hide()     end
    if self._savedHintFS then self._savedHintFS:SetText("") end

    if self.keyFrame then
        self.keyFrame:EnableKeyboard(true)
        self.keyFrame:Show()
    end

    self._gridHolder:Show()
    self:RebuildStaticGrid(board)
    self:_ReleaseAllSprites()
    self:_SyncSprites(board)
    self:UpdateHUD(board)
end

function R:OnGameLost(board, isNewHighscore)
    local L  = Loc()
    local UI = ArcadiaNexus.UI
    self.state = "LOST"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then self._startBtn:SetLabel(L["btn_start"]) end

    UI.ShowArcadeResult(self._fieldFrame, {
        title        = L["result_loss_title"] or "Game Over!",
        titleColor   = { 1, 0.3, 0.3 },
        score        = board.score,
        gameId       = "GOBLINBLAST",
        difficulty   = board.difficulty,
        result       = "LOSS",
        newHighscore = isNewHighscore,
        lines        = ResultLines(board, false),
        L            = L,
        onRetry      = function() R:_StartNewGame() end,
        onExit       = function() ArcadiaNexus.GB_Engine:StopGame() end,
    })
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_ReleaseAllSprites()
    if self._playerTex  then self._playerTex:Hide()  end
    if self._gridHolder then self._gridHolder:Hide() end

    self:_SetHudShown(false)
    if self._logoTex     then self._logoTex:Show()     end
    if self._slotMenu    then self._slotMenu:Hide()    end
    if self._resumeBtn   then self._resumeBtn:Hide()   end

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
        self._hintFS:SetText("")
        self._hintFS:Hide()
    end
end

-- ============================================================
-- SLASH-BEFEHL – /goblinblast öffnet den Hub direkt bei Goblin Blast
-- ============================================================
SLASH_ARCADIAGOBLINBLAST1 = "/goblinblast"
SLASH_ARCADIAGOBLINBLAST2 = "/gblast"
SlashCmdList["ARCADIAGOBLINBLAST"] = function()
    local main = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetMainFrame
        and _G.ArcadiaNexusUI.GetMainFrame()
    if main and not main:IsShown() and _G.Nexus_UI and _G.Nexus_UI.Toggle then
        _G.Nexus_UI.Toggle()
    end
    if _G.Nexus_UI and _G.Nexus_UI.SetTab then
        _G.Nexus_UI.SetTab("GAMES")
    end
    local fn = ArcadiaNexus.UI and ArcadiaNexus.UI._ActivateGameFn
    if fn then fn("GOBLINBLAST") end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "GOBLINBLAST",
    label     = "Goblin Blast",
    renderer  = "GB_Renderer",
    engine    = "GB_Engine",
    container = "_gbContainer",
    category  = "ARCADE",
})
