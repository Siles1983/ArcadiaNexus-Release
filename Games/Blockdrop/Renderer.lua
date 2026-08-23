-- ============================================================
--  ArcadiaNexus
--  Games/Blockdrop/Renderer.lua
--  Version: 3.0.0  (Blueprint v2 – Snake-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - _fieldFrame: Spielfeld-Container (CENTER + OFS)
--    - _artFrame: Artwork-TGA (Rahmen + Hintergrund), gesteuert durch Settings "background"
--      classic.tga / bg_alliance.tga / bg_horde.tga ersetzen den Border-Frame
--      FrameLevel unter _fieldFrame (BACKGROUND-Layer)
--    - _logoTex: via UI.CreateGameLogo auf _fieldFrame (IDLE)
--    - _nextFrame: Vorschau-Fenster (nächstes Teil)
--    - _scoreBox: Highscore-Box
--    - Controls-Leiste am BOTTOM: Divider + Pause-Button + Start/Beenden-Button
--    - Pause-Button an Dropdown-Position (Snake-Blueprint, links)
--    - Start/Beenden-Button an CENTER (Snake-Blueprint, mitte)
--    - Overlay auf _fieldFrame (FrameLevel +8)
--    - BG_CONFIG: alle Themes nutzen dieselben Positionen
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.BLD_Renderer = {}
local R = ArcadiaNexus.BLD_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_w      = 304,
    field_h      = 360,
    field_ofs_x  = 0,
    field_ofs_y  = 20,
    art_w        = 640,
    art_h        = 600,
    art_ofs_x    = 0,
    art_ofs_y    = 10,
    logo_w       = 300,
    logo_h       = 240,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    next_cell    = 10,
    score_box_w  = 110,
    score_box_h  = 36,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local BLD_ASSETS = {
    logo = "Interface\\AddOns\\ArcadiaNexus\\Games\\Blockdrop\\assets\\logo\\logo_blockdrop",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- Abgeleitet aus altem Code (BG_CONFIG CLASSIC / _buildPlayLayout).
-- Alle Werte vom Nutzer über diese Konstanten justierbar.
-- ============================================================

-- Spielfeld-Frame (CENTER-Anker an self.frame)

-- Artwork-TGA (Rahmen + Hintergrund) – ersetzt _borderFrame
-- classic.tga / bg_alliance.tga / bg_horde.tga
-- Position relativ zum CENTER von self.frame

-- Logo (IDLE-State, zentriert auf _fieldFrame)

-- Vorschau-Fenster (Next-Piece) – Zellgröße (konstant, unabhängig vom Theme)

-- Score-Boxen – Größe (gemeinsam für alle Themes)

-- ── Label-Sichtbarkeit (true = sichtbar, false = ausgeblendet) ──
local LABEL_VISIBLE = {
    score = false,
    level = false,
    lines = false,
    high  = false,
}

-- ── Box-Transparenz (0.0 = unsichtbar, 1.0 = voll sichtbar) ──
local BOX_ALPHA = {
    score = 0.0,
    level = 0.0,
    lines = 0.0,
    high  = 0.0,
}

-- ── Theme-abhängige Positionen (TOPLEFT relativ zu self.frame CENTER) ──
-- Alle Werte pro Background-Theme einzeln justierbar.
local THEME_LAYOUT = {
    CLASSIC = {
        next  = { x = 188,  y = 120 },
        score = { x = 90,  y = 245 },
        level = { x = -222,  y = 115 },
        lines = { x = -222,  y = -30 },
        high  = { x = 193,  y = -5 },
    },
    ALLIANCE = {
        next  = { x = 189,  y = 108 },
        score = { x = 85,  y = 242 },
        level = { x = -224,  y = 100 },
        lines = { x = -224,  y = -13 },
        high  = { x = 191,  y = -13 },
    },
    HORDE = {
        next  = { x = 189,  y = 108 },
        score = { x = 84,  y = 233 },
        level = { x = -224,  y = 100 },
        lines = { x = -224,  y = -12 },
        high  = { x = 191,  y = -12 },
    },
}

-- ============================================================
-- HINTERGRUND-KONFIGURATION
-- Alle 3 Themes teilen sich dieselben Spielfeld-Positionen.
-- Nur die Hintergrund-Textur unterscheidet sich.
-- ============================================================
-- Artwork-TGAs: steuern Rahmen + Hintergrund gleichzeitig
-- Dateiname ohne .tga-Erweiterung (WoW-Konvention)
local ART_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\Blockdrop\\assets\\border\\"
local ART_FILES = {
    CLASSIC  = ART_PATH .. "classic",
    ALLIANCE = ART_PATH .. "alliance",
    HORDE    = ART_PATH .. "horde",
}

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._fieldFrame    = nil
R._artFrame      = nil   -- Artwork-TGA (Rahmen + Hintergrund, gesteuert durch "background")
R._artTex        = nil

R._logoTex       = nil
R.overlay        = nil
R.state          = "IDLE"

R._gridFrame     = nil
R._cells         = {}
R._builtCS       = nil
R._builtBG       = nil
R._cellSize      = 24

R._nextFrame     = nil
R._nextCells     = nil

R._scoreBox      = nil   -- Score-Frame
R._levelBox      = nil   -- Level-Frame
R._linesBox      = nil   -- Reihen-Frame
R._highBox       = nil   -- Highscore-Frame

R._hintFS        = nil
R._startBtn      = nil
R._pauseBtn      = nil
R._pauseOverlay  = nil
R._sidePanelBuilt = false

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self._E = ArcadiaNexus.BLD_Engine
    self._S = ArcadiaNexus.BLD_Settings
    self._L = ArcadiaNexus.BLD_Logic
    self._T = ArcadiaNexus.BLD_Themes
    if self._E and self._E.Init then self._E:Init() end

    self:_CreateMainFrame()
    self:_CreateArtFrame()
    self:_CreateFieldFrame()
    self:_CreateLogo()

    -- _artFrame muss unter _fieldFrame liegen
    if self._artFrame and self._fieldFrame then
        self._artFrame:SetFrameLevel(
            math.max(1, self._fieldFrame:GetFrameLevel() - 2)
        )
    end
    self:_CreateNextFrame()
    self:_CreateScoreBox()
    self:_CreateHint()
    self:_CreateControls()
    self:_CreateSlotMenu()
    self:_CreateOverlay()
    self:EnterIdleState()
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
        outerName = "ArcadiaNexus_BLD_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._tetContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("BLOCKDROP", ArcadiaNexus.BLD_Engine, function(E)
            if E._board or E.state == "PLAYING" or E.state == "PAUSED" then
                E:SaveAndPause()
            end
        end)
        if R.state == "MENU" then
            R:EnterIdleState()
        end
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local f  = self._canvas
    local ff = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.05, 0.05, 0.07, 0) -- Spielfeld
    ff:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)
    self._fieldFrame = ff
end

-- ============================================================
-- ARTWORK-FRAME (Rahmen + Hintergrund in einem)
-- Liegt unter _fieldFrame → BACKGROUND-Layer
-- ============================================================
function R:_CreateArtFrame()
    if self._artFrame then return end
    local f = self._canvas

    local af = CreateFrame("Frame", nil, f)
    af:SetSize(CFG.art_w, CFG.art_h)
    af:SetPoint("CENTER", f, "CENTER", CFG.art_ofs_x, CFG.art_ofs_y)
    -- Unter _fieldFrame: FrameLevel wird nach _CreateFieldFrame gesetzt
    -- (hier noch nicht verfügbar, daher in Init nach beiden Calls)

    local tex = af:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(af)
    self._artFrame = af
    self._artTex   = tex

    -- Initiale Textur anwenden
    local S_ = ArcadiaNexus.BLD_Settings
    local bg = (S_ and S_:Get("background")) or "CLASSIC"
    self:_ApplyBackground(bg)
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        BLD_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

-- ============================================================
-- VORSCHAU-FENSTER (Next-Piece)
-- ============================================================
function R:_CreateNextFrame()
    if self._nextFrame then return end
    local f  = self._canvas

    local nf = CreateFrame("Frame", nil, f, "BackdropTemplate")
    nf:SetSize(5 * CFG.next_cell + 4, 5 * CFG.next_cell + 4)
    -- Position wird durch _ApplyThemeLayout gesetzt
    nf:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=false, edgeSize=2,
        insets={left=2,right=2,top=2,bottom=2},
    })
    nf:SetBackdropColor(0.05, 0.05, 0.05, 0)
    nf:SetBackdropBorderColor(0.50, 0.42, 0.18, 0)
    nf:Hide()
    self._nextFrame = nf

    -- 5×5 Zellen
    self._nextCells = {}
    for nr = 1, 5 do
        self._nextCells[nr] = {}
        for nc = 1, 5 do
            local cell = CreateFrame("Frame", nil, nf)
            cell:SetSize(CFG.next_cell - 1, CFG.next_cell - 1)
            cell:SetPoint("TOPLEFT", nf, "TOPLEFT",
                (nc - 1) * CFG.next_cell + 2, -((nr - 1) * CFG.next_cell + 2))
            local tex = cell:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(cell)
            tex:Hide()
            cell:Show()
            self._nextCells[nr][nc] = tex
        end
    end
end

-- ============================================================
-- SCORE-BOXEN (Score / Level / Reihen / Highscore – einzeln positionierbar)
-- ============================================================
function R:_CreateScoreBox()
    if self._sidePanelBuilt then return end
    self._sidePanelBuilt = true

    local f  = self._canvas
    local _L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")

    local function mkBox(labelTxt, labelKey, alphaKey)
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetSize(CFG.score_box_w, CFG.score_box_h)
        -- Position wird durch _ApplyThemeLayout gesetzt
        box:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=false, edgeSize=2,
            insets={left=2,right=2,top=2,bottom=2},
        })
        local alpha = BOX_ALPHA[alphaKey] or 1.0
        box:SetBackdropColor(0, 0, 0, 0.65 * alpha)
        box:SetBackdropBorderColor(0.50, 0.42, 0.18, alpha)

        local lbl = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
        lbl:SetText("|cffffff00" .. labelTxt .. "|r")
        if not LABEL_VISIBLE[labelKey] then lbl:Hide() end

        local val = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        val:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -18)
        val:SetText("0")

        box:Hide()
        return box, val
    end

    self._scoreBox, self._scoreFS = mkBox(_L["label_score"], "score", "score")
    self._levelBox, self._levelFS = mkBox(_L["label_level"], "level", "level")
    self._linesBox, self._linesFS = mkBox(_L["label_lines"], "lines", "lines")
    self._highBox,  self._highFS  = mkBox(_L["label_best"],  "high",  "high")
end

-- ============================================================
-- HINT-TEXT (Idle-State)
-- ============================================================
function R:_CreateHint()
    if self._hintFS then return end
    local f = self._canvas
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

-- ============================================================
-- CONTROLS (Snake-Blueprint)
-- Pause-Button an Dropdown-Position (links)
-- Start/Beenden-Button an CENTER (mitte)
-- ============================================================
function R:_CreateControls()
    local _L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Pause-Button: Segment 1
    local pauseBtn = UI.CreateArcadiaButton(cf, _L["btn_pause"], CFG.dd_w, CFG.btn_h)
    pauseBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[1], bar.y.button)
    pauseBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.BLD_Engine
        if not E then return end
        E:TogglePause()
    end)
    pauseBtn:Hide()
    self._pauseBtn = pauseBtn

    -- Start (IDLE) / Beenden (Menü + Spiel)
    local startBtn = UI.CreateArcadiaButton(cf, _L["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)
    self._startBtn = startBtn

    local exitBtn = UI.CreateArcadiaButton(cf, _L["btn_exit"], CFG.btn_w, CFG.btn_h)
    exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    exitBtn:SetScript("OnClick", function()
        if R.state == "MENU" then
            R:EnterIdleState()
            return
        end
        local E = ArcadiaNexus.BLD_Engine
        if E and E.state ~= "IDLE" then
            if E.state == "GAMEOVER" then
                E:StopGame()
            else
                E:SaveAndPause()
            end
            R:EnterIdleState()
        end
    end)
    exitBtn:Hide()
    self._exitBtn = exitBtn
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    local S  = ArcadiaNexus.BLD_Settings
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
            return string.format(loc.slot_info or "Level %d · %s", (save.level or 0) + 1, score)
        end,
        isPaused      = function(save) return save.midGame ~= nil end,
        onNewGame     = function(slot)
            local E = ArcadiaNexus.BLD_Engine
            if E then E:StartGame({ slot = slot, mode = "new" }) end
        end,
        onContinue    = function(slot)
            local E = ArcadiaNexus.BLD_Engine
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
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._hintFS   then self._hintFS:Hide()   end
    if self._slotMenu then self._slotMenu:Show() end
end

-- ============================================================
-- ARTWORK-TEXTUR WECHSELN (wird vom Settings-Panel aufgerufen)
-- ============================================================
function R:_ApplyBackground(bg)
    if not self._artTex then return end
    local file = ART_FILES[bg] or ART_FILES["CLASSIC"]
    self._artTex:SetTexture(file)
    self._artFrame:Show()
end

-- ============================================================
-- THEME-LAYOUT ANWENDEN (Positionen aller Boxen + Next-Fenster)
-- ============================================================
function R:_ApplyThemeLayout(bg)
    local layout = THEME_LAYOUT[bg] or THEME_LAYOUT["CLASSIC"]
    local f = self._canvas

    if self._nextFrame then
        self._nextFrame:ClearAllPoints()
        self._nextFrame:SetPoint("TOPLEFT", f, "CENTER", layout.next.x, layout.next.y)
    end
    if self._scoreBox then
        self._scoreBox:ClearAllPoints()
        self._scoreBox:SetPoint("TOPLEFT", f, "CENTER", layout.score.x, layout.score.y)
    end
    if self._levelBox then
        self._levelBox:ClearAllPoints()
        self._levelBox:SetPoint("TOPLEFT", f, "CENTER", layout.level.x, layout.level.y)
    end
    if self._linesBox then
        self._linesBox:ClearAllPoints()
        self._linesBox:SetPoint("TOPLEFT", f, "CENTER", layout.lines.x, layout.lines.y)
    end
    if self._highBox then
        self._highBox:ClearAllPoints()
        self._highBox:SetPoint("TOPLEFT", f, "CENTER", layout.high.x, layout.high.y)
    end
end

-- ============================================================
-- GRID-AUFBAU (wird beim Spielstart gebaut)
-- ============================================================
function R:_BuildGrid(board)
    local cols = board.cols
    local rows = board.rows
    local S_   = ArcadiaNexus.BLD_Settings
    local bg   = (S_ and S_:Get("background")) or "CLASSIC"

    -- Zellgröße aus _fieldFrame ableiten
    local fw = self._fieldFrame:GetWidth()
    local fh = self._fieldFrame:GetHeight()
    if not fw or fw < 10 then fw = CFG.field_w end
    if not fh or fh < 10 then fh = CFG.field_h end

    local csW = math.floor((fw - 4) / cols)
    local csH = math.floor((fh - 4) / rows)
    local cs  = math.max(math.min(csW, csH, 32), 10)
    self._cellSize = cs

    local gridW = cols * cs
    local gridH = rows * cs

    -- Grid-Frame innerhalb _fieldFrame
    if not self._gridFrame then
        local gf = CreateFrame("Frame", "ArcadiaNexus_BLD_Grid", self._fieldFrame, "BackdropTemplate")
        gf:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile=false, edgeSize=2,
            insets={left=2,right=2,top=2,bottom=2},
        })
        gf:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)
        -- Rechtsklick = Rotieren
        gf:EnableMouse(true)
        gf:SetScript("OnMouseDown", function(_, btn)
            if btn ~= "RightButton" then return end
            local E2 = ArcadiaNexus.BLD_Engine
            if not E2 or E2.state ~= "PLAYING" then return end
            local L2 = ArcadiaNexus.BLD_Logic
            if L2 then L2:Rotate(E2._board) end
            R:UpdatePiece(E2._board)
            local S_ = ArcadiaNexus.BLD_Settings
            if S_ and S_:Get("snd_rotate") then
                PlaySoundFile("Interface\\AddOns\\ArcadiaNexus\\Games\\Blockdrop\\assets\\sounds\\rotate_piece.wav", "Master")
            end
        end)
        self._gridFrame = gf
    end

    local gf = self._gridFrame
    gf:SetSize(gridW + 4, gridH + 4)
    gf:ClearAllPoints()
    gf:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)

    if bg == "CLASSIC" then
        gf:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    else
        gf:SetBackdropColor(0, 0, 0, 0)
    end

    -- Zellen neu dimensionieren wenn Zellgröße oder BG sich geändert hat
    if self._builtCS ~= cs or self._builtBG ~= bg then
        self._builtCS = cs
        self._builtBG = bg
        for _, row in pairs(self._cells or {}) do
            for _, cell in pairs(row) do
                cell:SetSize(cs, cs)
                if bg == "CLASSIC" then
                    cell:SetBackdropColor(0.08, 0.08, 0.12, 1)
                else
                    cell:SetBackdropColor(0, 0, 0, 0)
                end
            end
        end
        if self._nextCells then
            for nr = 1, 5 do
                for nc = 1, 5 do
                    local tex = self._nextCells[nr] and self._nextCells[nr][nc]
                    if tex then tex:Hide() end
                end
            end
        end
    end

    for r, row in pairs(self._cells or {}) do
        for c, cell in pairs(row) do
            if r > rows or c > cols then
                cell:Hide()
            end
        end
    end

    for r = 1, rows do
        if not self._cells[r] then self._cells[r] = {} end
        for c = 1, cols do
            local px = (c - 1) * cs + 2
            local py = -((r - 1) * cs) - 2
            if not self._cells[r][c] then
                local cell = CreateFrame("Frame", nil, gf, "BackdropTemplate")
                cell:SetSize(cs, cs)
                cell:SetPoint("TOPLEFT", gf, "TOPLEFT", px, py)
                cell:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", tile=false, edgeSize=0 })
                if bg == "CLASSIC" then
                    cell:SetBackdropColor(0.08, 0.08, 0.12, 1)
                else
                    cell:SetBackdropColor(0, 0, 0, 0)
                end
                local icon = cell:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(cell)
                icon:Hide()
                cell.icon = icon

                local ghost = cell:CreateTexture(nil, "OVERLAY")
                ghost:SetAllPoints(cell)
                ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
                ghost:SetVertexColor(1, 1, 1, 0)
                ghost:Hide()
                cell.ghost = ghost

                self._cells[r][c] = cell
            else
                local cell = self._cells[r][c]
                cell:SetSize(cs, cs)
                cell:SetPoint("TOPLEFT", gf, "TOPLEFT", px, py)
                cell:Show()
            end
        end
    end
end

-- Vorschau-Zellen neu initialisieren (nach BG-Wechsel oder erstem Aufbau)
function R:_RebuildNextCells()
    if not self._nextFrame then return end
    if not self._nextCells or not self._nextCells[1] then
        self:_CreateNextFrame()
        return
    end
    for nr = 1, 5 do
        for nc = 1, 5 do
            local tex = self._nextCells[nr] and self._nextCells[nr][nc]
            if tex then tex:Hide() end
        end
    end
end

-- ============================================================
-- OVERLAY (Game-Over / Pause)
-- ============================================================
function R:_CreateOverlay()
    if self.overlay then return end
    local ff = self._fieldFrame

    local ov = CreateFrame("Frame", nil, ff, "BackdropTemplate")
    ov:SetAllPoints(ff)
    ov:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ov:SetBackdropColor(0, 0, 0, 0.72)
    ov:SetFrameLevel(ff:GetFrameLevel() + 8)
    ov:Hide()
    self.overlay = ov
end

-- ============================================================
-- EnterIdleState
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"

    if self._gridFrame      then self._gridFrame:Hide()      end
    if self._nextFrame      then self._nextFrame:Hide()      end
    if self._scoreBox       then self._scoreBox:Hide()       end
    if self._levelBox       then self._levelBox:Hide()       end
    if self._linesBox       then self._linesBox:Hide()       end
    if self._highBox        then self._highBox:Hide()        end
    if self._pauseBtn       then self._pauseBtn:Hide()       end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self.overlay         then self.overlay:Hide()         end
    if self._artFrame       then self._artFrame:Show()       end
    if self._logoTex        then self._logoTex:Show()        end
    if self._slotMenu       then self._slotMenu:Hide()       end
    if self._exitBtn        then self._exitBtn:Hide()        end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("BLOCKDROP")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("BLOCKDROP")["hint_start"] or "")
        self._hintFS:Show()
    end

    -- Hintergrund für IDLE zeigen
    local S_ = ArcadiaNexus.BLD_Settings
    local bg = (S_ and S_:Get("background")) or "CLASSIC"
    self:_ApplyBackground(bg)
end

-- ============================================================
-- EnterPlayState (vom Engine aufgerufen)
-- ============================================================
function R:EnterPlayState(board)
    self.state = "PLAYING"

    if self._hintFS     then self._hintFS:Hide()     end
    if self._logoTex    then self._logoTex:Hide()     end
    if self._slotMenu   then self._slotMenu:Hide()    end
    if self.overlay     then self.overlay:Hide()      end
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)

    -- Hintergrund + Theme-Layout anwenden
    local S_ = ArcadiaNexus.BLD_Settings
    local bg = (S_ and S_:Get("background")) or "CLASSIC"
    self:_ApplyBackground(bg)
    self:_ApplyThemeLayout(bg)

    -- Grid bauen
    self:_BuildGrid(board)

    if self._gridFrame then self._gridFrame:Show() end
    if self._nextFrame then self._nextFrame:Show() end
    if self._scoreBox  then self._scoreBox:Show()  end
    if self._levelBox  then self._levelBox:Show()  end
    if self._linesBox  then self._linesBox:Show()  end
    if self._highBox   then self._highBox:Show()   end
    if self._pauseBtn  then self._pauseBtn:Show()  end
    if self._startBtn  then self._startBtn:Hide()  end
    if self._exitBtn   then self._exitBtn:Show()   end
end

-- ============================================================
-- ZELLEN MALEN / LEEREN
-- ============================================================
function R:_PaintCell(cell, entry, alpha)
    if not cell or not entry then return end
    alpha = alpha or 1.0
    local cr, cg, cb = (entry.r or 0.5), (entry.g or 0.5), (entry.b or 0.5)

    if cell.icon then
        if entry.atlas then
            cell:SetBackdropColor(0, 0, 0, 0)
            cell.icon:SetTexture(entry.atlas)
            cell.icon:SetTexCoord(0, 1, 0, 1)
            cell.icon:SetVertexColor(1, 1, 1, alpha)
            cell.icon:Show()
            return
        end
        if entry.icon then
            cell:SetBackdropColor(0, 0, 0, 0)
            cell.icon:SetTexture(entry.icon)
            cell.icon:SetTexCoord(0, 1, 0, 1)
            cell.icon:SetVertexColor(1, 1, 1, alpha)
            cell.icon:Show()
            return
        end
        cell.icon:Hide()
    end
    cell:SetBackdropColor(cr * 0.80 * alpha, cg * 0.80 * alpha, cb * 0.80 * alpha, 1)
end

function R:_ClearCell(cell)
    if not cell then return end
    local S_ = ArcadiaNexus.BLD_Settings
    local bg = (S_ and S_:Get("background")) or "CLASSIC"
    if bg == "CLASSIC" then
        cell:SetBackdropColor(0.08, 0.08, 0.12, 1)
    else
        cell:SetBackdropColor(0, 0, 0, 0)
    end
    if cell.icon  then cell.icon:Hide()  end
    if cell.ghost then cell.ghost:Hide() end
end

-- ============================================================
-- FullRedraw
-- ============================================================
function R:FullRedraw(board)
    local T     = ArcadiaNexus.BLD_Themes
    local S     = ArcadiaNexus.BLD_Settings
    local theme = T and T:Get(S and S:Get("theme") or "CLASSIC") or {}

    for r = 1, board.rows do
        for c = 1, board.cols do
            local cell = self._cells[r] and self._cells[r][c]
            if cell then
                local typ = board.cells[r][c]
                if typ and theme[typ] then
                    self:_PaintCell(cell, theme[typ])
                else
                    self:_ClearCell(cell)
                end
            end
        end
    end

    self:UpdatePiece(board)
    self:_UpdateScorePanel(board)
    self:_UpdateNextPanel(board)
end

-- ============================================================
-- UpdatePiece – aktives Piece + Ghost zeichnen
-- ============================================================
function R:UpdatePiece(board)
    if not board or not board.piece then return end

    local T     = ArcadiaNexus.BLD_Themes
    local S     = ArcadiaNexus.BLD_Settings
    local theme = T and T:Get(S and S:Get("theme") or "CLASSIC") or {}
    local L     = ArcadiaNexus.BLD_Logic
    local p     = board.piece
    local entry = theme[p.type] or {r=0.5, g=0.5, b=0.5}

    -- Board-Zustand wiederherstellen
    for row = 1, board.rows do
        for col = 1, board.cols do
            local cell = self._cells[row] and self._cells[row][col]
            if cell then
                local typ = board.cells[row][col]
                if typ and theme[typ] then
                    self:_PaintCell(cell, theme[typ])
                else
                    self:_ClearCell(cell)
                end
            end
        end
    end

    -- Ghost
    if L then
        local ghostRow = L:GetGhostRow(board)
        local shape    = L:GetShape(p)
        for pr = 1, #shape do
            for pc = 1, #shape[pr] do
                if shape[pr][pc] == 1 then
                    local br = ghostRow + pr - 1
                    local bc = p.col    + pc - 1
                    local cell = self._cells[br] and self._cells[br][bc]
                    if cell and not board.cells[br][bc] then
                        if cell.ghost then
                            cell.ghost:SetVertexColor(entry.r, entry.g, entry.b, 0.20)
                            cell.ghost:Show()
                        end
                    end
                end
            end
        end
    end

    -- Aktives Piece
    local shape = L and L:GetShape(p) or {}
    for pr = 1, #shape do
        for pc = 1, #shape[pr] do
            if shape[pr][pc] == 1 then
                local br = p.row + pr - 1
                local bc = p.col + pc - 1
                local cell = self._cells[br] and self._cells[br][bc]
                if cell then
                    self:_PaintCell(cell, entry)
                    if cell.ghost then cell.ghost:Hide() end
                end
            end
        end
    end

    self:_UpdateScorePanel(board)
    self:_UpdateNextPanel(board)
end

-- ============================================================
-- _UpdateScorePanel
-- ============================================================
function R:_UpdateScorePanel(board)
    if not board then return end
    local S  = ArcadiaNexus.BLD_Settings
    if self._scoreFS then self._scoreFS:SetText(tostring(board.score or 0)) end
    if self._levelFS then self._levelFS:SetText(tostring(board.level or 0)) end
    if self._linesFS then self._linesFS:SetText(tostring(board.lines or 0)) end
    if self._highFS then
        local SM   = ArcadiaNexus.ScoreManager
        local best = SM and SM:GetScores("BLOCKDROP", "normal").highscores[1] or 0
        self._highFS:SetText(tostring(best))
    end
end

-- ============================================================
-- _UpdateNextPanel
-- ============================================================
function R:_UpdateNextPanel(board)
    if not board or not board.nextPiece then return end
    if not self._nextCells then return end

    local T     = ArcadiaNexus.BLD_Themes
    local S     = ArcadiaNexus.BLD_Settings
    local theme = T and T:Get(S and S:Get("theme") or "CLASSIC") or {}
    local L     = ArcadiaNexus.BLD_Logic
    local np    = board.nextPiece
    local entry = theme[np.type] or {r=0.5, g=0.5, b=0.5}

    -- Alle Vorschau-Zellen leeren
    for nr = 1, 5 do
        for nc = 1, 5 do
            local tex = self._nextCells[nr] and self._nextCells[nr][nc]
            if tex then tex:Hide() end
        end
    end

    local shape = L and L:GetShape(np) or {}
    if #shape == 0 then return end
    local offR = math.floor((5 - #shape) / 2) + 1
    local offC = math.floor((5 - (#shape[1] or 0)) / 2) + 1

    for pr = 1, #shape do
        for pc = 1, #shape[pr] do
            if shape[pr][pc] == 1 then
                local nr  = pr + offR - 1
                local nc  = pc + offC - 1
                local tex = self._nextCells[nr] and self._nextCells[nr][nc]
                if tex then
                    if entry.atlas then
                        tex:SetTexture(entry.atlas)
                        tex:SetTexCoord(0, 1, 0, 1)
                        tex:SetVertexColor(1, 1, 1, 1)
                    elseif entry.icon then
                        tex:SetTexture(entry.icon)
                        tex:SetTexCoord(0, 1, 0, 1)
                        tex:SetVertexColor(1, 1, 1, 1)
                    else
                        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                        tex:SetTexCoord(0, 1, 0, 1)
                        tex:SetVertexColor(entry.r, entry.g, entry.b, 1)
                    end
                    tex:Show()
                end
            end
        end
    end
end

-- ============================================================
-- PAUSE
-- ============================================================
function R:ShowPause()
    local _L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    if not self.overlay then return end
    -- Pause-Text in bestehendes Overlay
    if not self.overlay._pauseFS then
        local fs = self.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        fs:SetPoint("CENTER")
        self.overlay._pauseFS = fs
    end
    self.overlay._pauseFS:SetText(_L["pause_text"])
    self.overlay:Show()

    if self._pauseBtn then
        self._pauseBtn:SetLabel(_L["btn_resume"])
    end
    self.state = "PAUSED"
end

function R:HidePause()
    local _L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    if self.overlay then self.overlay:Hide() end
    if self._pauseBtn then
        self._pauseBtn:SetLabel(_L["btn_pause"])
    end
    self.state = "PLAYING"
end

-- ============================================================
-- GAME-OVER-PANEL
-- ============================================================
function R:ShowGameOver(board)
    local _L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    local UI = ArcadiaNexus.UI

    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._startBtn then self._startBtn:Hide() end
    if self._exitBtn  then self._exitBtn:Show()  end

    UI.ShowArcadeResult(self._fieldFrame, {
        title      = _L["gameover_title"],
        titleColor = { 1, 0.3, 0.3 },
        score      = board.score,
        gameId     = "BLOCKDROP",
        difficulty = board.difficulty,
        result     = "LOSS",
        lines      = { _L["gameover_lines"] .. (board.lines or 0) },
        L          = _L,
        onRetry    = function()
            local E = ArcadiaNexus.BLD_Engine
            if E then E:StartGame({ mode = "new" }) end
        end,
        onExit     = function()
            local E = ArcadiaNexus.BLD_Engine
            if E then E:StopGame() end
            R:EnterIdleState()
        end,
    })
end

-- ============================================================
-- RefreshTheme / RefreshBackground (vom Settings-Panel)
-- ============================================================
function R:RefreshTheme()
    local E = ArcadiaNexus.BLD_Engine
    if E and E.state == "PLAYING" and E._board then
        self:FullRedraw(E._board)
    end
end

function R:RefreshBackground()
    local E  = ArcadiaNexus.BLD_Engine
    local S_ = ArcadiaNexus.BLD_Settings
    local bg = (S_ and S_:Get("background")) or "CLASSIC"
    self:_ApplyBackground(bg)
    self:_ApplyThemeLayout(bg)

    if E and E._board then
        -- Zellen-Cache leeren für neuen BG-Aufbau
        self._builtCS  = nil
        self._builtBG  = nil
        if E.state == "PLAYING" then
            self:_BuildGrid(E._board)
            self:FullRedraw(E._board)
        end
    end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "BLOCKDROP",
    label     = "Blockdrop",
    renderer  = "BLD_Renderer",
    engine    = "BLD_Engine",
    container = "_tetContainer",
    category  = "ARCADE",
})
