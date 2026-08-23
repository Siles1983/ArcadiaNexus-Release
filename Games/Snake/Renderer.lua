-- ============================================================
--  ArcadiaNexus
--  Games/Snake/Renderer.lua
--  Version: 3.0.0  (Blueprint v2 + Tile-Segment-System)
--
--  Layout-Strategie:
--    - self.frame bleibt der panelgroße Lifecycle-Container
--    - Alle Layout-Elemente sitzen auf einem zentrierten 600x498-Canvas
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD: Score links, Highscore rechts (über Spielfeld)
--    - Controls-Leiste am BOTTOM: Dropdown Schwierigkeit + Start/Beenden
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--    - Overlay auf _fieldFrame
--
--  Tile-System:
--    GetSegmentTexture(prevDir, nextDir, isHead, isTail)
--    wählt anhand der Bewegungsrichtungen die korrekte Tile-Textur.
--    Alle 14 Tiles werden genutzt, keine Rotation per Code.
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SNK_Renderer = {}
local R = ArcadiaNexus.SNK_Renderer

-- ============================================================
-- CFG – alle Layout-Konstanten zentral (Upvalue-Limit: max 60)
-- ============================================================
local CFG = {
    field_size   = 425,
    field_ofs_x  = 0,
    field_ofs_y  = 5,
    bg_w         = 750,
    bg_h         = 500,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 0,
    border_w     = 795,
    border_h     = 550,
    border_ofs_x = 0,
    border_ofs_y = 10,
    logo_w       = 409,
    logo_h       = 314,
    logo_ofs_x   = 0,
    logo_ofs_y   = 0,
    hud_y        = 230,
    hud_l_x      =  -132,
    hud_r_x      =  132,
    hud_score_w  = 160,
    hud_score_h  = 28,
    hud_score_alpha = 0.75,
    hud_best_w   = 160,
    hud_best_h   = 28,
    hud_best_alpha = 0.75,
    controls_y   = 0,   -- HUD Score/Best am Canvas-Boden
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
}

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local SNK_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\Snake\\assets\\background\\background_snake",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Snake\\assets\\logo\\logo_snake",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\Snake\\assets\\border\\border_snake",
}

local TILE_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\Snake\\assets\\tiles\\"

local TILES = {
    head_up              = TILE_PATH .. "head_up",
    head_down            = TILE_PATH .. "head_down",
    head_left            = TILE_PATH .. "head_left",
    head_right           = TILE_PATH .. "head_right",
    middle               = TILE_PATH .. "middle",
    middle_horizontal    = TILE_PATH .. "middle_horizontal",
    tail_end_up          = TILE_PATH .. "tail_end_up",
    tail_end_down        = TILE_PATH .. "tail_end_down",
    tail_end_left        = TILE_PATH .. "tail_end_left",
    tail_end_right       = TILE_PATH .. "tail_end_right",
    turn_left_up         = TILE_PATH .. "turn_left_up",
    turn_left_down       = TILE_PATH .. "turn_left_down",
    turn_right_up        = TILE_PATH .. "turn_right_up",
    turn_right_down      = TILE_PATH .. "turn_right_down",
}

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================



-- HUD – relativ zum Canvas-CENTER

-- ============================================================
-- TILE-LOGIK
-- ============================================================
-- Richtungs-Konventionen (wie sie in board.snake gespeichert sind):
--   "UP"    = Zeile nimmt ab  (r-1)
--   "DOWN"  = Zeile nimmt zu  (r+1)
--   "LEFT"  = Spalte nimmt ab (c-1)
--   "RIGHT" = Spalte nimmt zu (c+1)
--
-- prevDir = Richtung aus der das Segment kommt (Richtung vom vorherigen Segment)
-- nextDir = Richtung in die das Segment geht   (Richtung zum nächsten Segment)
--
-- Für Kopf (isHead=true):  nur nextDir relevant (Bewegungsrichtung)
-- Für Schwanz (isTail=true): nur prevDir relevant (aus welcher Richtung der Körper kommt)

local function GetSegmentTexture(prevDir, nextDir, isHead, isTail)
    if isHead then
        -- Kopf zeigt in Bewegungsrichtung (nextDir)
        if nextDir == "UP"    then return TILES.head_up    end
        if nextDir == "DOWN"  then return TILES.head_down  end
        if nextDir == "LEFT"  then return TILES.head_left  end
        if nextDir == "RIGHT" then return TILES.head_right end
        return TILES.head_up

    elseif isTail then
        -- Schwanzspitze zeigt weg vom Körper (prevDir ist woher der Körper kommt)
        if prevDir == "UP"    then return TILES.tail_end_down  end  -- Körper kommt von oben → Spitze zeigt unten
        if prevDir == "DOWN"  then return TILES.tail_end_up    end
        if prevDir == "LEFT"  then return TILES.tail_end_right end
        if prevDir == "RIGHT" then return TILES.tail_end_left  end
        return TILES.tail_end_up

    else
        -- Mittelsegment: gerade oder Kurve
        -- Gerade vertikal
        if (prevDir == "UP"   and nextDir == "UP")   or
           (prevDir == "DOWN" and nextDir == "DOWN")  or
           (prevDir == "UP"   and nextDir == "DOWN")  or
           (prevDir == "DOWN" and nextDir == "UP")    then
            return TILES.middle
        end
        -- Gerade horizontal
        if (prevDir == "LEFT"  and nextDir == "LEFT")  or
           (prevDir == "RIGHT" and nextDir == "RIGHT") or
           (prevDir == "LEFT"  and nextDir == "RIGHT") or
           (prevDir == "RIGHT" and nextDir == "LEFT")  then
            return TILES.middle_horizontal
        end
        -- Kurven
        -- turn_left_up:    Körper kommt von links und geht nach oben ODER kommt von unten und geht nach rechts
        if (prevDir == "LEFT"  and nextDir == "UP")   or
           (prevDir == "DOWN"  and nextDir == "RIGHT") then
            return TILES.turn_left_up
        end
        -- turn_left_down:  Körper kommt von links und geht nach unten ODER kommt von oben und geht nach rechts
        if (prevDir == "LEFT"  and nextDir == "DOWN") or
           (prevDir == "UP"    and nextDir == "RIGHT") then
            return TILES.turn_left_down
        end
        -- turn_right_up:   Körper kommt von rechts und geht nach oben ODER kommt von unten und geht nach links
        if (prevDir == "RIGHT" and nextDir == "UP")   or
           (prevDir == "DOWN"  and nextDir == "LEFT")  then
            return TILES.turn_right_up
        end
        -- turn_right_down: Körper kommt von rechts und geht nach unten ODER kommt von oben und geht nach links
        if (prevDir == "RIGHT" and nextDir == "DOWN") or
           (prevDir == "UP"    and nextDir == "LEFT")  then
            return TILES.turn_right_down
        end
        -- Fallback
        return TILES.middle
    end
end

-- Richtung von Segment A nach Segment B berechnen
local function GetDir(from, to)
    if to.r < from.r then return "UP"    end
    if to.r > from.r then return "DOWN"  end
    if to.c < from.c then return "LEFT"  end
    if to.c > from.c then return "RIGHT" end
    return "UP"
end

-- Alle Segment-Tiles für eine Schlange berechnen
-- Gibt table[i] = texturpfad zurück (index entspricht board.snake[i])
local function CalcAllSegmentTiles(snake)
    local n    = #snake
    local tiles = {}
    for i = 1, n do
        local seg     = snake[i]
        local isHead  = (i == 1)
        local isTail  = (i == n)
        local prevDir = nil
        local nextDir = nil

        if not isHead then
            -- prevDir: Richtung vom Vorgänger zu diesem Segment
            prevDir = GetDir(snake[i - 1], seg)
        end
        if not isTail then
            -- nextDir: Richtung von diesem Segment zum Nachfolger
            nextDir = GetDir(seg, snake[i + 1])
        end

        -- Für Kopf: nextDir = Richtung vom Kopf zu Segment 2
        -- Für Schwanz: prevDir = Richtung vom vorletzten zum letzten
        tiles[i] = GetSegmentTexture(prevDir, nextDir, isHead, isTail)
    end
    return tiles
end

-- ============================================================
-- ZELL-HILFSFUNKTIONEN
-- ============================================================
local function SetCellTile(cell, tilePath)
    if not cell or not cell.tex then return end
    cell.tex:SetTexture(tilePath)
    cell.tex:SetTexCoord(0, 1, 0, 1)
    cell.tex:SetVertexColor(1, 1, 1, 1)
    cell.tex:Show()
    if cell.bg then cell.bg:SetVertexColor(0, 0, 0, 0) end
end

local function ClearCell(cell)
    if not cell then return end
    if cell.tex then cell.tex:Hide() end
    if cell.bg  then cell.bg:SetVertexColor(0.08, 0.08, 0.10, 1) end
end

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Snake.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local cell = CreateFrame("Frame", nil, poolParent)
            local bg = cell:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            cell.bg = bg
            local tex = cell:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:Hide()
            cell.tex = tex
            return cell
        end,
        onRelease = function(cell)
            cell:Hide()
            cell:ClearAllPoints()
            if cell.tex then
                cell.tex:Hide()
                cell.tex:SetTexture(nil)
                cell.tex:SetTexCoord(0, 1, 0, 1)
                cell.tex:SetVertexColor(1, 1, 1, 1)
            end
            if cell.bg then cell.bg:SetVertexColor(0.08, 0.08, 0.10, 1) end
            if poolParentRef then cell:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================
R.frame         = nil
R._canvas       = nil
R._controlsFrame = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"

R.gridHolder    = nil
R.cells         = {}
R._cellPool     = nil
R._lastTail     = nil
R._lastBoard    = nil

R.keyFrame      = nil

R._scoreLbl     = nil
R._scoreFS      = nil
R._hsLbl        = nil
R._hsFS         = nil
R._hintFS       = nil

R._startBtn     = nil
R._lastDiff     = nil

-- ============================================================
-- INIT
-- ============================================================
function R:Init()
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateControls()
    self:_CreateKeyFrame()
    self:EnterIdleState()

    local Eng = ArcadiaNexus.Engine
    Eng:On("SNK_GAME_STARTED", function(b) R:OnGameStarted(b) end)
    Eng:On("SNK_GAME_STOPPED", function()  R:EnterIdleState() end)
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
        outerName = "ArcadiaNexus_SNK_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._snkContainer = f

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("SNAKE", ArcadiaNexus.SNK_Engine, function(E)
            if E._board then
                E:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    ff:SetSize(CFG.field_size, CFG.field_size)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(SNK_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(SNK_ASSETS.border)
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
        SNK_ASSETS.logo,
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
            w="W", a="A", s="S", d="D",
            W="W", A="A", S="S", D="D",
            UP="UP", DOWN="DOWN", LEFT="LEFT", RIGHT="RIGHT",
        }
        local k = mapped[key]
        if k then ArcadiaNexus.SNK_Engine:HandleKey(k) end
    end)
    self.keyFrame = kf
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local canvas = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("SNAKE")
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end

    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_l_x, y = CFG.hud_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Score") .. ": 0",
        shown = false,
    })
    self._bestBox, self._hsFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_best_w, h = CFG.hud_best_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_r_x, y = CFG.hud_y,
        alpha = CFG.hud_best_alpha,
        text = (L["lbl_highscore"] or "Highscore") .. ": 0",
        shown = false,
    })
    self._scoreLbl, self._hsLbl = nil, nil

    local hintFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:UpdateScore(board)
    local L = ArcadiaNexus.GetLocaleTable("SNAKE")
    if self._scoreFS then
        self._scoreFS:SetText((L["lbl_score"] or "Score") .. ": " .. tostring(board.score or 0))
    end
    if self._hsFS then
        local SM = ArcadiaNexus.ScoreManager
        local hs = SM and SM:GetBestScore("SNAKE", board.difficulty) or 0
        self._hsFS:SetText((L["lbl_highscore"] or "Highscore") .. ": " .. tostring(hs))
    end
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("SNAKE")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local S = ArcadiaNexus.SNK_Settings

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, CFG.dd_w, "",
        {
            { key = "easy",   label = L["diff_easy"]   },
            { key = "normal", label = L["diff_normal"]  },
            { key = "hard",   label = L["diff_hard"]    },
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
        local E = ArcadiaNexus.SNK_Engine
        if not E then return end
        if R.state == "PLAYING" then
            E:StopGame()
        else
            R:_StartNewGame()
        end
    end)
    self._startBtn = startBtn
end

function R:_StartNewGame()
    local S = ArcadiaNexus.SNK_Settings
    ArcadiaNexus.SNK_Engine:StartGame({
        difficulty = R._lastDiff or (S and S:Get("difficulty")) or "easy",
        theme      = "tiles",
    })
end

function R:ShowOverlay(won, board, isNewHighscore)
    local L  = ArcadiaNexus.GetLocaleTable("SNAKE")
    local UI = ArcadiaNexus.UI

    UI.ShowArcadeResult(self._fieldFrame, {
        gameId       = "SNAKE",
        difficulty   = board.difficulty,
        result       = won and "WIN" or "LOSS",
        score        = board.score,
        newHighscore = isNewHighscore,
        titleKeys    = {
            WIN  = { "result_win_title" },
            LOSS = { "result_loss_title" },
        },
        lines = { string.format("|cffaaaaaa %s:|r |cffffff00%d|r",
            L["lbl_length"] or "Länge", #board.snake) },
        L = L,
        onRetry = function()
            R:_StartNewGame()
        end,
        onExit = function()
            local E = ArcadiaNexus.SNK_Engine
            if E then E:StopGame() end
        end,
    })
end

-- ============================================================
-- GRID
-- ============================================================
function R:_EnsureCellPool()
    if not self._cellPool then self._cellPool = CreateCellPool() end
end

function R:BuildGrid(board)
    self:ClearGrid()

    local T    = ArcadiaNexus.SNK_Themes
    local diff = T:GetDiff(board.difficulty)
    local g    = diff.gridSize
    local gap  = 1
    local cs   = math.floor((CFG.field_size - (g - 1) * gap) / g)
    local totalPx = g * cs + (g - 1) * gap

    local holder = self.gridHolder
    if not holder then
        holder = CreateFrame("Frame", nil, self._fieldFrame, "BackdropTemplate")
        self.gridHolder = holder
    end
    holder:SetParent(self._fieldFrame)
    holder:SetSize(totalPx, totalPx)
    holder:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    holder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    holder:SetBackdropColor(0.05, 0.06, 0.05, 1)
    holder:SetBackdropBorderColor(0.25, 0.35, 0.20, 1)
    holder:Show()

    self:_EnsureCellPool()
    self.cells = {}
    for row = 1, g do
        self.cells[row] = {}
        for col = 1, g do
            local cx = (col - 1) * (cs + gap)
            local cy = (row - 1) * (cs + gap)

            local cell = self._cellPool:Acquire({})
            cell:SetParent(holder)
            cell:SetSize(cs, cs)
            cell:SetPoint("TOPLEFT", holder, "TOPLEFT", cx, -cy)
            cell.bg:SetVertexColor(0.08, 0.08, 0.10, 1)
            cell.tex:Hide()
            cell:Show()

            self.cells[row][col] = cell
        end
    end

    self:RenderFull(board)
end

function R:RenderFull(board)
    local g = board.gridSize

    -- Alle Zellen leeren
    for r = 1, g do
        for c = 1, g do
            ClearCell(self.cells[r] and self.cells[r][c])
        end
    end

    -- Schlange mit Tile-System zeichnen
    local tilePaths = CalcAllSegmentTiles(board.snake)
    for i, seg in ipairs(board.snake) do
        local cell = self.cells[seg.r] and self.cells[seg.r][seg.c]
        if cell then
            SetCellTile(cell, tilePaths[i])
        end
    end

    -- Futter (weiterhin Icon-basiert aus Theme)
    local T     = ArcadiaNexus.SNK_Themes
    local theme = T:GetTheme(board.theme)
    if board.food then
        local fc = self.cells[board.food.r] and self.cells[board.food.r][board.food.c]
        if fc then
            local f = theme.food
            fc.tex:SetTexture(f.icon)
            fc.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            fc.tex:SetVertexColor(f.color[1], f.color[2], f.color[3])
            fc.tex:Show()
            if fc.bg then fc.bg:SetVertexColor(f.color[1]*0.2, f.color[2]*0.2, f.color[3]*0.2, 1) end
        end
    end
end

function R:OnTick(board, result)
    -- Vollständiges Neuzeichnen der Schlange bei jedem Tick
    -- nötig weil Segment-Tiles sich durch Richtungsänderungen überall ändern können
    local g = board.gridSize

    -- Nur Schlangenzellen neu zeichnen (Futter bleibt)
    local tilePaths = CalcAllSegmentTiles(board.snake)
    for i, seg in ipairs(board.snake) do
        local cell = self.cells[seg.r] and self.cells[seg.r][seg.c]
        if cell then
            SetCellTile(cell, tilePaths[i])
        end
    end

    -- Altes Schwanzende leeren
    if result == "moved" and self._lastTail then
        local lt     = self._lastTail
        local ltCell = self.cells[lt.r] and self.cells[lt.r][lt.c]
        if ltCell then
            local isSnake = false
            for _, seg in ipairs(board.snake) do
                if seg.r == lt.r and seg.c == lt.c then isSnake = true; break end
            end
            local isFood = board.food and board.food.r == lt.r and board.food.c == lt.c
            if not isSnake and not isFood then
                ClearCell(ltCell)
            end
        end
    end

    -- Neues Futter zeichnen
    if result == "ate" and board.food then
        local T     = ArcadiaNexus.SNK_Themes
        local theme = T:GetTheme(board.theme)
        local fc    = self.cells[board.food.r] and self.cells[board.food.r][board.food.c]
        if fc then
            local f = theme.food
            fc.tex:SetTexture(f.icon)
            fc.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            fc.tex:SetVertexColor(f.color[1], f.color[2], f.color[3])
            fc.tex:Show()
            if fc.bg then fc.bg:SetVertexColor(f.color[1]*0.2, f.color[2]*0.2, f.color[3]*0.2, 1) end
        end
    end

    self:UpdateScore(board)
end

function R:ClearGrid()
    if self._cellPool then self._cellPool:ReleaseAll() end
    self.cells      = {}
    self._lastBoard = nil
    self._lastTail  = nil
    if self.gridHolder then self.gridHolder:Hide() end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(board)
    self.state     = "PLAYING"
    self._lastDiff = board.difficulty

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._hintFS      then self._hintFS:Hide()      end
    if self._logoTex     then self._logoTex:Hide()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("SNAKE")["btn_exit"])
    end

    if self._scoreBox then self._scoreBox:Show() end
    if self._bestBox  then self._bestBox:Show()  end
    if self._goldGrid then self._goldGrid:Show() end

    if self.keyFrame then
        self.keyFrame:EnableKeyboard(true)
        self.keyFrame:Show()
    end

    self:BuildGrid(board)
    self:UpdateScore(board)
end

function R:OnGameLost(board, isNewHighscore)
    self.state = "LOST"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("SNAKE")["btn_start"])
    end
    self:ShowOverlay(false, board, isNewHighscore)
end

function R:OnGameWon(board, isNewHighscore)
    self.state = "WON"
    if self.keyFrame then self.keyFrame:EnableKeyboard(false) end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("SNAKE")["btn_start"])
    end
    self:ShowOverlay(true, board, isNewHighscore)
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:ClearGrid()

    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._scoreBox    then self._scoreBox:Hide()    end
    if self._bestBox     then self._bestBox:Hide()     end
    if self._goldGrid    then self._goldGrid:Hide()    end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self.keyFrame then
        self.keyFrame:EnableKeyboard(false)
        self.keyFrame:Hide()
    end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("SNAKE")["btn_start"])
        self._startBtn:Show()
    end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("SNAKE")["hint_start"] or "")
        self._hintFS:Show()
    end
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "SNAKE",
    label     = "Snake",
    renderer  = "SNK_Renderer",
    engine    = "SNK_Engine",
    container = "_snkContainer",
    category  = "ARCADE",
})
