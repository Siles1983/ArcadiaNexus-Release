--[[
    ArcadiaNexus
    Games/ArcadiaRows/Renderer.lua
    Version: 3.1.0

    Feel: Fall-Animation, Geisterstein, Zug-HUD, Drohungen, Brett-Look (Platte + Stege).
    MATCH: nur Public-lastMove animieren; keine KI, kein Best-of-3.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AR_Renderer = {}

local Renderer = ArcadiaNexus.AR_Renderer

local CFG = {
    field_ofs_x      = 16,
    field_ofs_y      = 5,
    field_w      = 560,
    field_h      = 484,
    board_cols   = 7,
    board_rows   = 6,
    cell_pad     = 0,
    grid_w       = 510,
    grid_h       = 400,
    grid_ox      = 3,
    grid_oy      = 5,
    bg_w         = 670,
    bg_h         = 540,
    bg_ofs_x     = 0,
    bg_ofs_y     = 0,
    bg_alpha     = 1,
    border_w     = 794,
    border_h     = 547,
    border_ofs_x = 0,
    border_ofs_y = 4,
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,
    sound_win    = 888,
    sound_draw   = 8959,
    sound_loss   = 847,
    sound_drop   = 856,
    sound_pop    = 863,
    drop_bounce    = 0.14,
    drop_bounce_px = 8,
    logo_w       = 512,
    logo_h       = 512,
    logo_ofs_x   = 0,
    logo_ofs_y   = -20,
    hud_turn_w     = 200,
    hud_turn_h     = 26,
    hud_turn_x     = -150,
    hud_turn_y     = 228,
    hud_turn_alpha = 0.75,
    hud_series_w     = 124,
    hud_series_h     = 26,
    hud_series_x     = 196,
    hud_series_y     = 228,
    hud_series_alpha = 0.75,
    drop_base      = 0.10,
    drop_per_row   = 0.055,
    hole_frac      = 0.70,
    stone_frac     = 0.82,
    rib_w          = 7,
    pop_slide      = 0.22,
    plate_r        = 0.10,
    plate_g        = 0.14,
    plate_b        = 0.28,
    rib_r          = 0.16,
    rib_g          = 0.22,
    rib_b          = 0.42,
    rib_a          = 1,
    well_r         = 0.03,
    well_g         = 0.03,
    well_b         = 0.06,
}

local AR_ASSETS = {
    logo = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\logo\\logo_ar",
}

local DBG_SHOW_GRID      = true
local DBG_SHOW_DISCS     = true
local DBG_SHOW_HIGHLIGHT = true

local function ChipMetrics(cellW, cellH)
    local span = math.min(cellW, cellH)
    local hole = math.floor(span * (CFG.hole_frac or 0.70))
    if hole < 12 then hole = 12 end
    local stone = math.floor(hole * (CFG.stone_frac or 0.82))
    if stone < 8 then stone = 8 end
    return hole, stone
end

local function ChipTopLeft(offX, offY, cellW, cellH, col, row, size)
    local cx = offX + (col - 0.5) * cellW
    local cy = offY + (row - 0.5) * cellH
    return cx - size / 2, cy - size / 2
end

local function CircleMask(parent, tex, slot)
    if not tex or not tex.AddMaskTexture then return end
    local mask = parent[slot]
    if not mask then
        mask = parent:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        tex:AddMaskTexture(mask)
        parent[slot] = mask
    end
    mask:SetAllPoints(tex)
end

local function EnsureWell(f)
    if f.well then return end
    local well = f:CreateTexture(nil, "BACKGROUND")
    f.well = well
    CircleMask(f, well, "wellMask")
end

local function DropLoop()
    if not Renderer._dropLoop and ArcadiaNexus.GameLoop then
        Renderer._dropLoop = ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AR_DropLoop")
    end
    return Renderer._dropLoop
end

local function MoveKey(move, board)
    if not move or not move.col then return "" end
    if move.pop then
        return "p:" .. tostring(move.col) .. ":" .. tostring(board and board.moveCount or 0)
    end
    if not move.row then return "" end
    return tostring(move.col) .. ":" .. tostring(move.row)
end

local function CreateCellPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaRows.Cells",
        create = function(poolParent)
            poolParentRef = poolParent
            local f = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            local well = f:CreateTexture(nil, "BACKGROUND")
            f.well = well
            if well.AddMaskTexture then
                local wmask = f:CreateMaskTexture(nil, "BACKGROUND")
                wmask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                well:AddMaskTexture(wmask)
                f.wellMask = wmask
            end
            local disc = f:CreateTexture(nil, "ARTWORK")
            f.disc = disc
            if disc.AddMaskTexture then
                local mask = f:CreateMaskTexture(nil, "ARTWORK")
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                disc:AddMaskTexture(mask)
                f.discMask = mask
            end
            local pulse = disc:CreateAnimationGroup()
            pulse:SetLooping("BOUNCE")
            local fade = pulse:CreateAnimation("Alpha")
            fade:SetFromAlpha(0.45)
            fade:SetToAlpha(1)
            fade:SetDuration(0.45)
            fade:SetSmoothing("IN_OUT")
            f.discPulse = pulse
            local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            text:SetPoint("CENTER")
            f.text = text
            local atlTex = f:CreateTexture(nil, "OVERLAY")
            atlTex:Hide()
            if atlTex.AddMaskTexture then
                local atlMask = f:CreateMaskTexture(nil, "OVERLAY")
                atlMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                atlTex:AddMaskTexture(atlMask)
                f.atlMask = atlMask
            end
            f.atlTex = atlTex
            return f
        end,
        onRelease = function(f)
            if f.discPulse then f.discPulse:Stop() end
            if f.disc then
                f.disc:SetAlpha(1)
                f.disc:SetTexCoord(0, 1, 0, 1)
                f.disc:SetTexture("Interface\\Buttons\\WHITE8X8")
                f.disc:SetVertexColor(0.1, 0.1, 0.1, 1)
            end
            if f.well then
                f.well:SetVertexColor(CFG.well_r, CFG.well_g, CFG.well_b, 1)
            end
            f:Hide()
            f:ClearAllPoints()
            if f.text then f.text:SetText("") end
            if f.atlTex then f.atlTex:Hide(); f.atlTex:SetTexture(nil); f.atlTex:SetAlpha(1) end
            if poolParentRef then f:SetParent(poolParentRef) end
        end,
    })
end

local function CreatePopFlyerPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaRows.PopFlyers",
        create = function(poolParent)
            poolParentRef = poolParent
            local fl = CreateFrame("Frame", nil, poolParent)
            fl:Hide()
            local disc = fl:CreateTexture(nil, "ARTWORK")
            disc:SetAllPoints(fl)
            fl.disc = disc
            if disc.AddMaskTexture then
                local mask = fl:CreateMaskTexture(nil, "ARTWORK")
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(disc)
                disc:AddMaskTexture(mask)
                fl.discMask = mask
            end
            local atl = fl:CreateTexture(nil, "OVERLAY")
            atl:Hide()
            atl:SetAllPoints(fl)
            fl.atlTex = atl
            fl.text = fl:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fl.text:SetPoint("CENTER")
            return fl
        end,
        onRelease = function(fl)
            fl:Hide()
            fl:ClearAllPoints()
            if fl.disc then fl.disc:SetAlpha(1) end
            if poolParentRef then fl:SetParent(poolParentRef) end
        end,
    })
end

local function CreateColHitPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaRows.ColHits",
        create = function(poolParent)
            poolParentRef = poolParent
            local hit = CreateFrame("Button", nil, poolParent)
            hit:EnableMouse(true)
            hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            return hit
        end,
        onRelease = function(hit)
            hit:Hide()
            hit:ClearAllPoints()
            hit:Enable()
            hit:SetScript("OnClick", nil)
            hit:SetScript("OnEnter", nil)
            hit:SetScript("OnLeave", nil)
            hit._col = nil
            if poolParentRef then hit:SetParent(poolParentRef) end
        end,
    })
end

Renderer.frame          = nil
Renderer._canvas        = nil
Renderer._controlsFrame = nil
Renderer.playfield      = nil
Renderer.dropdown       = nil
Renderer.startBtn       = nil
Renderer.cellButtons    = {}
Renderer.colHitFrames   = {}
Renderer.cellW          = 0
Renderer.cellH          = 0
Renderer.state          = "IDLE"
Renderer.lastResult     = nil
Renderer.selectedDiff    = "easy"
Renderer.selectedStarter = "you"
Renderer.selectedMode    = "play"
Renderer.winLineFrame   = nil
Renderer.winLineTexture = nil
Renderer._logoTex       = nil
Renderer._hoverCol      = nil
Renderer._popShift      = false
Renderer._seenMoveKey   = ""
Renderer._hidingMoveKey = ""
Renderer._hidingPopCol  = nil
Renderer._resultShown   = false
Renderer._animating     = false
Renderer._chromeBusy    = false
Renderer._suppressHover = false

local function PlayGameSound(result)
    local S = ArcadiaNexus.AR_Settings
    if not S or not S:Get("soundEnabled") then return end
    if result == "WIN"  and S:Get("soundOnWin")  then PlaySound(CFG.sound_win,  "SFX") end
    if result == "DRAW" and S:Get("soundOnDraw") then PlaySound(CFG.sound_draw, "SFX") end
    if result == "LOSS" and S:Get("soundOnLoss") then PlaySound(CFG.sound_loss, "SFX") end
end

local function PlayDropSound()
    local S = ArcadiaNexus.AR_Settings
    if not S or not S:Get("soundEnabled") then return end
    PlaySound(CFG.sound_drop, "SFX")
end

local function PlayPopSound()
    local S = ArcadiaNexus.AR_Settings
    if not S or not S:Get("soundEnabled") then return end
    PlaySound(CFG.sound_pop or 863, "SFX")
end

local function InstantDrops()
    local S = ArcadiaNexus.AR_Settings
    return S and S:Get("instantDrops") and true or false
end

local function PopPreviewCol(board)
    if not board or not board.popOut or Renderer._animating then return nil end
    local E = ArcadiaNexus.AR_Engine
    if E and E.mode and E.mode ~= "hotseat" then return nil end
    local col = Renderer._hoverCol
    if not col then return nil end
    if board.gameOver or board.turn ~= (board.localSeat or 1) then return nil end
    local Logic = ArcadiaNexus.AR_Logic
    if not Logic or not Logic.CanPopOut then return nil end
    local you = board.localSeat or 1
    if not Logic:CanPopOut(board, col, you) then return nil end
    local canDrop = Logic.GetLowestRow and Logic:GetLowestRow(board, col)
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    if shift or not canDrop then return col end
    return nil
end

local function ApplyDiscColor(btn, r, g, b, a)
    if not btn or not btn.disc then return end
    btn.disc:SetTexCoord(0, 1, 0, 1)
    btn.disc:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.disc:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
end

local function ApplySymbol(btn, symbolDef, alpha)
    if not DBG_SHOW_DISCS then return end
    alpha = alpha or 1
    if btn.atlTex then btn.atlTex:Hide() end
    if not symbolDef then
        if btn.disc then btn.disc:Hide() end
        if btn.text then btn.text:SetText("") end
        return
    end
    if btn.disc then btn.disc:Show() end

    if symbolDef.mode == "SPRITE" then
        btn.disc:SetTexture(symbolDef.path)
        btn.disc:SetTexCoord(symbolDef.left, symbolDef.right, symbolDef.top, symbolDef.bottom)
        btn.disc:SetVertexColor(1, 1, 1, alpha)
        if btn.text then btn.text:SetText("") end
    else
        ApplyDiscColor(btn, symbolDef.r or 1, symbolDef.g or 1, symbolDef.b or 1, alpha)
        if btn.text then btn.text:SetText("") end
    end
end

local function ResolveSymbols()
    if ArcadiaNexus.AR_SymbolResolver then
        return ArcadiaNexus.AR_SymbolResolver:Resolve()
    end
    return {
        player1 = { mode = "TEXT", r = 1.00, g = 0.85, b = 0.00 },
        player2 = { mode = "TEXT", r = 1.00, g = 0.15, b = 0.15 },
    }
end

function Renderer:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self.playfield,
        AR_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function Renderer:_CreateHud()
    if self._turnBox then return end
    local UI = ArcadiaNexus.UI
    local canvas = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    if not UI or not UI.CreateHudStatBox or not canvas then return end
    self._turnBox, self.turnFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_turn_w, h = CFG.hud_turn_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_turn_x, y = CFG.hud_turn_y,
        alpha = CFG.hud_turn_alpha,
        text = L["hud_your_turn"] or "Dein Zug",
        shown = false,
    })
    self._seriesBox, self.seriesFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_series_w, h = CFG.hud_series_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_series_x, y = CFG.hud_series_y,
        alpha = CFG.hud_series_alpha,
        text = "0 : 0",
        shown = false,
    })
end

function Renderer:_SetHudVisible(visible)
    if self._turnBox then
        if visible then self._turnBox:Show() else self._turnBox:Hide() end
    end
    local E = ArcadiaNexus.AR_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    if self._seriesBox then
        if visible and not mp then self._seriesBox:Show() else self._seriesBox:Hide() end
    end
end

function Renderer:_UpdateHud(board)
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    local E = ArcadiaNexus.AR_Engine
    if not board or not self.turnFS then return end
    local mp = E and E.mode and E.mode ~= "hotseat"
    local myTurn = not board.gameOver and board.turn == (board.localSeat or 1)
    if board.gameOver then
        self.turnFS:SetText("")
        if self._turnBox then self._turnBox:Hide() end
    else
        if self._turnBox then self._turnBox:Show() end
        if myTurn then
            self.turnFS:SetText(L["hud_your_turn"] or "Dein Zug")
        elseif mp then
            self.turnFS:SetText(L["hud_opp_turn"] or "Gegner denkt…")
        else
            self.turnFS:SetText(L["hud_ai_turn"] or "KI denkt…")
        end
    end
    if mp then
        if self._seriesBox then self._seriesBox:Hide() end
        return
    end
    if board.playMode == "puzzle" then
        local left = math.max(0, (board.winIn or 1) - (board.playerPly or 0))
        if self.seriesFS then
            if (board.playerPly or 0) > 0 then
                self.seriesFS:SetText(string.format(L["hud_win_left"] or "Noch %d", left))
            else
                self.seriesFS:SetText(string.format(L["hud_win_in"] or "Gewinn in %d", board.winIn or 1))
            end
        end
        if self._seriesBox then self._seriesBox:Show() end
        return
    end
    local s = E and E.GetSeries and E:GetSeries()
    if self.seriesFS and s then
        self.seriesFS:SetText(string.format("%d : %d", s.you or 0, s.opp or 0))
        if self._seriesBox then self._seriesBox:Show() end
    end
end

function Renderer:Init()
    self:CreateMainFrame()
    self:CreatePlayfield()
    self:_CreateLogo()
    self:_CreateHud()
    self:CreateControls()
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine

    Engine:On("AR_GAME_STARTED", function(board)
        Renderer.state = "PLAYING"
        Renderer._resultShown = false
        Renderer._seenMoveKey = ""
        Renderer._hidingMoveKey = ""
        Renderer._hidingPopCol = nil
        Renderer._hintOn = false
        Renderer._hintCol = nil
        if Renderer._logoTex then Renderer._logoTex:Hide() end
        Renderer:_SetHudVisible(true)
        Renderer:RenderBoard(board)
        Renderer:UpdateStartButton()
        Renderer:_RefreshSeg3()
    end)

    Engine:On("AR_BOARD_UPDATED", function()
        Renderer:OnBoardUpdated()
    end)

    Engine:On("AR_GAME_OVER", function(result)
        Renderer:ShowGameOver(result)
    end)

    Engine:On("AR_WIN_LINE", function(line)
        local E = ArcadiaNexus.AR_Engine
        local board = E and E.GetBoardState and E:GetBoardState()
        if board and board.result then
            Renderer.lastResult = board.result
        end
        Renderer:HighlightWinningLine(line)
    end)

    Engine:On("AR_GAME_STOPPED", function()
        Renderer:EnterIdleState()
    end)
end

function Renderer:CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI.GetGamesPanel()
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_AR_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._arContainer = f

    f:SetScript("OnHide", function()
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then
            return
        end
        ArcadiaNexus.GameSession:HandleRendererHide("ARCADIAROWS", ArcadiaNexus.AR_Engine, function(eng)
            if eng.mode ~= "hotseat" and (eng.state == "PLAYING" or eng.state == "LOBBY" or eng.state == "FINISHED") then
                eng:HideView()
            elseif eng.state ~= "IDLE" or eng.activeGame then
                eng:StopGame()
            end
        end)
    end)
end

function Renderer:_EnsureFxLayers()
    local pf = self.playfield
    if not pf then return end
    if not self._ghost then
        local g = CreateFrame("Frame", nil, pf)
        g:SetFrameLevel(pf:GetFrameLevel() + 18)
        g:Hide()
        local disc = g:CreateTexture(nil, "ARTWORK")
        disc:SetAllPoints(g)
        g.disc = disc
        if disc.AddMaskTexture then
            local mask = g:CreateMaskTexture(nil, "ARTWORK")
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(disc)
            disc:AddMaskTexture(mask)
            g.discMask = mask
        end
        local atl = g:CreateTexture(nil, "OVERLAY")
        atl:Hide()
        atl:SetAllPoints(g)
        g.atlTex = atl
        g.text = g:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        g.text:SetPoint("CENTER")
        self._ghost = g
    end
    if not self._flyer then
        local fl = CreateFrame("Frame", nil, pf)
        fl:SetFrameLevel(pf:GetFrameLevel() + 18)
        fl:Hide()
        local disc = fl:CreateTexture(nil, "ARTWORK")
        disc:SetAllPoints(fl)
        fl.disc = disc
        if disc.AddMaskTexture then
            local mask = fl:CreateMaskTexture(nil, "ARTWORK")
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(disc)
            disc:AddMaskTexture(mask)
        end
        local atl = fl:CreateTexture(nil, "OVERLAY")
        atl:Hide()
        atl:SetAllPoints(fl)
        fl.atlTex = atl
        fl.text = fl:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fl.text:SetPoint("CENTER")
        self._flyer = fl
    end
end

local COL_KEYS = {
    ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7,
    ["NUMPAD1"] = 1, ["NUMPAD2"] = 2, ["NUMPAD3"] = 3, ["NUMPAD4"] = 4,
    ["NUMPAD5"] = 5, ["NUMPAD6"] = 6, ["NUMPAD7"] = 7,
}

local function KeyboardBusy()
    if GetCurrentKeyBoardFocus then
        local focus = GetCurrentKeyBoardFocus()
        if focus then return true end
    end
    local edit = _G.ChatFrame1EditBox
    if edit and edit.HasFocus and edit:HasFocus() then return true end
    return false
end

function Renderer:_EnsureKeyFrame()
    if self._keyFrame or not self.playfield then return end
    local kf = CreateFrame("Frame", nil, self.playfield)
    kf:SetAllPoints(self.playfield)
    kf:EnableMouse(false)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(true)
    kf:SetScript("OnKeyDown", function(frame, key)
        frame:SetPropagateKeyboardInput(true)
        if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT" then
            Renderer:_RefreshPopPreview()
            return
        end
        if KeyboardBusy() then return end
        local col = COL_KEYS[key]
        if not col then return end
        local E = ArcadiaNexus.AR_Engine
        if not E or Renderer._animating or E._busy then return end
        local st = E.GetBoardState and E:GetBoardState()
        if not st or st.gameOver then return end
        local mp = E.mode and E.mode ~= "hotseat"
        if mp and st.turn ~= st.localSeat then return end
        if not mp and st.turn ~= (st.localSeat or 1) then return end
        local wantPop = IsShiftKeyDown and IsShiftKeyDown()
        if wantPop then
            if mp or not st.popOut then return end
            frame:SetPropagateKeyboardInput(false)
            if E.HandlePlayerPopOut then E:HandlePlayerPopOut(col) end
            return
        end
        frame:SetPropagateKeyboardInput(false)
        E:HandlePlayerMove(col)
    end)
    kf:SetScript("OnKeyUp", function(frame, key)
        frame:SetPropagateKeyboardInput(true)
        if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT" then
            Renderer:_RefreshPopPreview()
        end
    end)
    kf:SetScript("OnUpdate", function()
        if Renderer.state ~= "PLAYING" or Renderer._animating then return end
        local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
        if shift == Renderer._popShift then return end
        Renderer:_RefreshPopPreview()
    end)
    self._keyFrame = kf
end

function Renderer:_RefreshPopPreview()
    self._popShift = IsShiftKeyDown and IsShiftKeyDown() and true or false
    self:_SyncHoverFromMouse()
    self:RefreshHover()
end

function Renderer:_SetKeyboard(enable)
    self:_EnsureKeyFrame()
    if self._keyFrame then
        self._keyFrame:EnableKeyboard(enable and true or false)
    end
end

function Renderer:_SyncHoverFromMouse()
    local over = nil
    for col = 1, #self.colHitFrames do
        local hit = self.colHitFrames[col]
        if hit and hit.IsMouseOver and hit:IsVisible() and hit:IsEnabled() and hit:IsMouseOver() then
            over = hit._col
            break
        end
    end
    self._hoverCol = over
end

function Renderer:CreatePlayfield()
    if self.playfield then return end

    local canvas = self._canvas
    local pf = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("TOP", canvas, "TOP", 0, CFG.field_ofs_y)
    pf:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left=1, right=1, top=1, bottom=1 },
    })
    pf:SetBackdropBorderColor(0.2, 0.2, 0.4, 0)

    local bgTex = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgTex:SetSize(CFG.bg_w, CFG.bg_h)
    bgTex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    bgTex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\background\\background_ar")
    bgTex:SetAlpha(CFG.bg_alpha)
    self._bgTex = bgTex

    local borderFrame = CreateFrame("Frame", nil, pf)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", pf, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(pf:GetFrameLevel() + 100)
    borderFrame:EnableMouse(false)
    local borderTex = borderFrame:CreateTexture(nil, "ARTWORK")
    borderTex:SetAllPoints(borderFrame)
    borderTex:SetTexture("Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaRows\\assets\\border\\border_ar")
    self._borderFrame = borderFrame

    self.playfield = pf
    self:_EnsureFxLayers()
    self:_EnsureKeyFrame()
end

function Renderer:CreateControls()
    if self.dropdown then return end

    local L  = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    self._diffAnchor = ddAnchor

    local options = {
        { key = "easy",   label = L["diff_easy"]   },
        { key = "normal", label = L["diff_normal"]  },
        { key = "hard",   label = L["diff_hard"]    },
    }

    self.dropdown = UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        CFG.dd_w,
        "",
        options,
        function() return Renderer.selectedDiff end,
        function(key) Renderer.selectedDiff = key end
    )

    local ddGap = 10
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(CFG.dd_w * 2 + ddGap, CFG.btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[3], bar.y.dropdownOfs)
    self._seg3Pair = pair

    local modeAnchor = CreateFrame("Frame", nil, pair)
    modeAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    modeAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)

    self.modeDropdown = UI.CreateSimpleDropdown(
        modeAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "play",   label = L["mode_play"]   or "Partie" },
            { key = "puzzle", label = L["mode_puzzle"] or "Stellung" },
        },
        function() return Renderer.selectedMode or "play" end,
        function(key)
            Renderer.selectedMode = key
            Renderer:_RefreshSeg3()
        end
    )

    self._modeAnchor = modeAnchor

    local startAnchor = CreateFrame("Frame", nil, pair)
    startAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    startAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    self._startAnchor = startAnchor

    self.startDropdown = UI.CreateSimpleDropdown(
        startAnchor,
        0, 0,
        CFG.dd_w,
        "",
        {
            { key = "you",    label = L["start_you"]    or "Du zuerst" },
            { key = "ai",     label = L["start_ai"]     or "KI zuerst" },
            { key = "random", label = L["start_random"] or "Zufall" },
        },
        function() return Renderer.selectedStarter end,
        function(key) Renderer.selectedStarter = key end
    )

    local tools = CreateFrame("Frame", nil, cf)
    tools:SetSize(CFG.dd_w * 2 + ddGap, CFG.btn_h)
    tools:SetPoint("CENTER", cf, "CENTER", bar.segX[3], bar.y.dropdownOfs)
    self._puzzleTools = tools

    local hintBtn = UI.CreateArcadiaButton(tools, L["btn_hint"] or "Tipp", CFG.dd_w, CFG.btn_h)
    hintBtn:SetPoint("LEFT", tools, "LEFT", 0, 0)
    hintBtn:SetScript("OnClick", function()
        if Renderer._hintOn then
            Renderer._hintOn = false
            Renderer._hintCol = nil
        else
            local E = ArcadiaNexus.AR_Engine
            local board = E and E.GetBoardState and E:GetBoardState()
            Renderer._hintCol = Renderer:_ResolveHintCol(board)
            Renderer._hintOn = Renderer._hintCol ~= nil
        end
        Renderer:RefreshChrome()
    end)
    self._hintBtn = hintBtn

    local skipBtn = UI.CreateArcadiaButton(tools, L["btn_skip"] or "Weiter", CFG.dd_w, CFG.btn_h)
    skipBtn:SetPoint("RIGHT", tools, "RIGHT", 0, 0)
    skipBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AR_Engine
        if not E or not E.SkipPuzzle then return end
        if Renderer.playfield and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(Renderer.playfield)
        end
        Renderer._resultShown = false
        E:SkipPuzzle()
    end)
    self._skipBtn = skipBtn
    tools:Hide()

    local btn = UI.CreateArcadiaButton(cf, L["btn_start"], 144, 32)
    btn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    btn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AR_Engine
        if not E then return end
        if Renderer.state == "PLAYING" and E.mode and E.mode ~= "hotseat" then
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.ShowEndRoundConfirm then
                Shell.ShowEndRoundConfirm(function()
                    ArcadiaNexus.UI.HideResultDialog(Renderer.playfield)
                    E:StopGame()
                end, Renderer.playfield)
                return
            end
        end
        if Renderer.state == "PLAYING" or Renderer.state == "LOBBY" or Renderer.state == "FINISHED" or Renderer.state == "GAMEOVER" then
            E:StopGame()
        else
            E:StartGame({
                cols         = CFG.board_cols,
                rows         = CFG.board_rows,
                aiDifficulty = Renderer.selectedDiff,
                firstPlayer  = Renderer.selectedStarter or "you",
                playMode     = Renderer.selectedMode or "play",
                mode         = "hotseat",
            })
        end
    end)
    self.startBtn = btn

    self:UpdateStartButton()
    self:_RefreshSeg3()
end

function Renderer:_ResolveHintCol(board)
    if not board or board.playMode ~= "puzzle" or board.gameOver then
        return nil
    end
    local you = board.localSeat or 1
    local Logic = ArcadiaNexus.AR_Logic
    if Logic and Logic.GetImmediateWinSlots then
        local slots = Logic:GetImmediateWinSlots(board, you)
        if slots and slots[1] then
            return slots[1].col
        end
    end
    local AI = ArcadiaNexus.AR_AI
    if AI and AI.GetBestMove then
        local col = AI:GetBestMove(board, you, "hard", false)
        if col then return col end
    end
    return board.keyCol
end

function Renderer:_RefreshSeg3()
    local E = ArcadiaNexus.AR_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    local puzzle = (self.selectedMode or "play") == "puzzle"
    local playing = self.state == "PLAYING" or self.state == "GAMEOVER"
    if mp then
        if self._seg3Pair then self._seg3Pair:Hide() end
        if self._puzzleTools then self._puzzleTools:Hide() end
        return
    end
    if playing and puzzle then
        if self._seg3Pair then self._seg3Pair:Hide() end
        if self._puzzleTools then self._puzzleTools:Show() end
        return
    end
    if self._puzzleTools then self._puzzleTools:Hide() end
    if not self._seg3Pair then return end
    self._seg3Pair:Show()
    if puzzle then
        self._seg3Pair:SetSize(CFG.dd_w, CFG.btn_h)
        if self._startAnchor then self._startAnchor:Hide() end
        if self._modeAnchor then
            self._modeAnchor:ClearAllPoints()
            self._modeAnchor:SetPoint("CENTER", self._seg3Pair, "CENTER", 0, 0)
        end
    else
        self._seg3Pair:SetSize(CFG.dd_w * 2 + 10, CFG.btn_h)
        if self._startAnchor then self._startAnchor:Show() end
        if self._modeAnchor then
            self._modeAnchor:ClearAllPoints()
            self._modeAnchor:SetPoint("LEFT", self._seg3Pair, "LEFT", 0, 0)
        end
        if self._startAnchor then
            self._startAnchor:ClearAllPoints()
            self._startAnchor:SetPoint("RIGHT", self._seg3Pair, "RIGHT", 0, 0)
        end
    end
end

function Renderer:UpdateStartButton()
    if not self.startBtn then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    if self.state == "PLAYING" then
        self.startBtn:SetLabel(L["btn_exit"] or "Beenden")
        self:_SetKeyboard(true)
    else
        self.startBtn:SetLabel(L["btn_start"] or "Spiel Starten")
        self:_SetKeyboard(false)
    end
end

function Renderer:_StopDrop()
    self._animating = false
    self._hidingPopCol = nil
    local loop = DropLoop()
    if loop then loop:Stop() end
    if self._flyer then self._flyer:Hide() end
    if self._popFlyerPool then self._popFlyerPool:ReleaseAll() end
end

function Renderer:EnterIdleState()
    self:_SetKeyboard(false)
    self:_StopDrop()
    self.state = "IDLE"
    self._hoverCol = nil
    self._popShift = false
    self._seenMoveKey = ""
    self._hidingMoveKey = ""
    self._resultShown = false
    self.lastResult = nil
    self:ClearBoard()
    self:ClearWinningLine()
    if self._ghost then self._ghost:Hide() end
    self:_HideRibs()
    self:_HideColNumbers()
    self:_SetHudVisible(false)
    if self.playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self.playfield)
    end
    if self._logoTex  then self._logoTex:Show() end
    if self._diffAnchor then self._diffAnchor:Show() end
    self:UpdateStartButton()
    self:_RefreshSeg3()
end

function Renderer:Render()
    local E = ArcadiaNexus.AR_Engine
    if not E or E.mode == "hotseat" then return end
    local v = E:GetView()
    if not v then return end
    if v.state == "IDLE" or v.state == "ABORTED" then
        self:EnterIdleState()
        return
    end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    if self._diffAnchor then self._diffAnchor:Hide() end
    if self._seg3Pair then self._seg3Pair:Hide() end
    if self._puzzleTools then self._puzzleTools:Hide() end
    if self.startBtn then
        self.startBtn:SetLabel(L["btn_exit"] or "Beenden")
        self.startBtn:Show()
    end
    if v.state == "LOBBY" then
        self.state = "LOBBY"
        self:_SetKeyboard(false)
        self:_StopDrop()
        self:ClearBoard()
        self:ClearWinningLine()
        self:_HideRibs()
        self:_HideColNumbers()
        self:_SetHudVisible(false)
        if self.playfield and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(self.playfield)
        end
        if self._logoTex then self._logoTex:Show() end
        return
    end
    if v.state == "PLAYING" or v.state == "FINISHED" then
        local board = E:GetBoardState()
        if not board then return end
        if self._logoTex then self._logoTex:Hide() end
        self:_SetHudVisible(true)
        self:_SetKeyboard(v.state == "PLAYING")
        if self.state ~= "PLAYING" and self.state ~= "GAMEOVER" and self.state ~= "FINISHED" then
            self.state = "PLAYING"
            self._resultShown = false
            self:RenderBoard(board)
        else
            self:OnBoardUpdated()
        end
        if v.state == "FINISHED" then
            self.state = "FINISHED"
        end
    end
end

function Renderer:_EnsureBoardPools()
    if not self._cellPool then self._cellPool = CreateCellPool() end
    if not self._colHitPool then self._colHitPool = CreateColHitPool() end
    if not self._popFlyerPool then self._popFlyerPool = CreatePopFlyerPool() end
end

function Renderer:ClearBoard()
    if self._cellPool then self._cellPool:ReleaseAll() end
    if self._colHitPool then self._colHitPool:ReleaseAll() end
    if self._popFlyerPool then self._popFlyerPool:ReleaseAll() end
    self.cellButtons = {}
    self.colHitFrames = {}
    self:_HideColNumbers()
end

function Renderer:_GridOrigin(board)
    local gridW = CFG.grid_w or CFG.field_w
    local gridH = CFG.grid_h or CFG.field_h
    local cellW = math.floor(gridW / board.cols)
    local cellH = math.floor(gridH / board.rows)
    local offX  = (CFG.field_w - gridW) / 2 + CFG.grid_ox
    local offY  = (CFG.field_h - gridH) / 2 + CFG.grid_oy
    return offX, offY, cellW, cellH
end

local function AcquireRibTex(frame, cache, i)
    local tex = cache[i]
    if not tex then
        tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        cache[i] = tex
    end
    tex:SetVertexColor(CFG.rib_r, CFG.rib_g, CFG.rib_b, CFG.rib_a or 1)
    tex:Show()
    return tex
end

function Renderer:_HideRibs()
    if self._ribFrame then self._ribFrame:Hide() end
end

function Renderer:_HideColNumbers()
    if not self._colNumFs then return end
    for i = 1, #self._colNumFs do
        if self._colNumFs[i] then self._colNumFs[i]:Hide() end
    end
end

function Renderer:_LayoutColNumbers(board)
    local pf = self.playfield
    if not pf or not board then return end
    if not self._colNumFrame then
        local nf = CreateFrame("Frame", nil, pf)
        nf:EnableMouse(false)
        self._colNumFrame = nf
        self._colNumFs = {}
    end
    local nf = self._colNumFrame
    nf:SetParent(pf)
    nf:SetAllPoints(pf)
    nf:SetFrameLevel(pf:GetFrameLevel() + 56)
    nf:Show()

    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    local y = offY + board.rows * cellH + 5
    for col = 1, board.cols do
        local fs = self._colNumFs[col]
        if not fs then
            fs = nf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self._colNumFs[col] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOP", pf, "TOPLEFT", offX + (col - 0.5) * cellW, -y)
        fs:SetText(tostring(col))
        fs:SetTextColor(0.82, 0.76, 0.58, 0.95)
        fs:Show()
    end
    for i = board.cols + 1, #self._colNumFs do
        if self._colNumFs[i] then self._colNumFs[i]:Hide() end
    end
end

function Renderer:_LayoutRibs(board)
    local pf = self.playfield
    if not pf or not board then return end
    if not self._ribFrame then
        local rf = CreateFrame("Frame", nil, pf)
        rf:EnableMouse(false)
        self._ribFrame = rf
        self._ribH = {}
        self._ribV = {}
    end
    local rf = self._ribFrame
    rf:SetParent(pf)
    rf:ClearAllPoints()
    rf:SetAllPoints(pf)
    rf:SetFrameLevel(pf:GetFrameLevel() + 42)
    rf:Show()

    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    local rib = CFG.rib_w or 7
    local gridW = cellW * board.cols
    local gridH = cellH * board.rows

    local nh = board.rows + 1
    for i = 1, nh do
        local tex = AcquireRibTex(rf, self._ribH, i)
        local y = offY + (i - 1) * cellH - rib / 2
        tex:ClearAllPoints()
        tex:SetSize(gridW + rib, rib)
        tex:SetPoint("TOPLEFT", pf, "TOPLEFT", offX - rib / 2, -y)
    end
    for i = nh + 1, #self._ribH do
        if self._ribH[i] then self._ribH[i]:Hide() end
    end

    local nv = board.cols + 1
    for i = 1, nv do
        local tex = AcquireRibTex(rf, self._ribV, i)
        local x = offX + (i - 1) * cellW - rib / 2
        tex:ClearAllPoints()
        tex:SetSize(rib, gridH + rib)
        tex:SetPoint("TOPLEFT", pf, "TOPLEFT", x, -(offY - rib / 2))
    end
    for i = nv + 1, #self._ribV do
        if self._ribV[i] then self._ribV[i]:Hide() end
    end
end

function Renderer:RenderBoard(board)
    self:_StopDrop()
    self:ClearBoard()
    self:ClearWinningLine()
    if self.playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self.playfield)
    end
    if not board then return end

    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    self.cellW = cellW
    self.cellH = cellH
    self:_EnsureBoardPools()
    self:_EnsureFxLayers()

    for row = 1, board.rows do
        self.cellButtons[row] = {}
        for col = 1, board.cols do
            local f = self._cellPool:Acquire({})
            f:SetParent(self.playfield)
            f:SetSize(cellW - CFG.cell_pad * 2, cellH - CFG.cell_pad * 2)
            f:SetPoint("TOPLEFT", self.playfield, "TOPLEFT",
                offX + (col - 1) * cellW + CFG.cell_pad,
                -(offY + (row - 1) * cellH + CFG.cell_pad))
            f:SetFrameLevel(self.playfield:GetFrameLevel() + 2)
            f:SetBackdropColor(CFG.plate_r, CFG.plate_g, CFG.plate_b, 1)
            if not DBG_SHOW_GRID then
                f:SetBackdropColor(0, 0, 0, 0)
            end

            EnsureWell(f)
            local hole, stone = ChipMetrics(cellW, cellH)
            if f.well then
                f.well:ClearAllPoints()
                f.well:SetSize(hole, hole)
                f.well:SetPoint("CENTER", f, "CENTER", 0, 0)
                f.well:SetTexture("Interface\\Buttons\\WHITE8X8")
                f.well:SetVertexColor(CFG.well_r, CFG.well_g, CFG.well_b, 1)
                f.well:Show()
                if f.wellMask then f.wellMask:SetAllPoints(f.well) end
            end
            f.disc:ClearAllPoints()
            f.disc:SetSize(stone, stone)
            f.disc:SetPoint("CENTER", f, "CENTER", 0, 0)
            ApplyDiscColor(f, CFG.well_r, CFG.well_g, CFG.well_b, 1)
            if f.discMask then f.discMask:SetAllPoints(f.disc) end

            f.atlTex:ClearAllPoints()
            f.atlTex:SetSize(stone, stone)
            f.atlTex:SetPoint("CENTER", f, "CENTER", 0, 0)
            f.atlTex:Hide()
            if f.atlMask then f.atlMask:SetAllPoints(f.atlTex) end
            f.text:SetText("")
            f:Show()

            self.cellButtons[row][col] = f
        end
    end

    for col = 1, board.cols do
        local hit = self._colHitPool:Acquire({})
        hit:SetParent(self.playfield)
        hit:SetSize(cellW, board.rows * cellH)
        hit:SetPoint("TOPLEFT", self.playfield, "TOPLEFT",
            offX + (col - 1) * cellW,
            -offY)
        hit._col = col
        hit:SetScript("OnClick", function(_, button)
            if Renderer._animating then return end
            local E = ArcadiaNexus.AR_Engine
            if not E then return end
            if button == "RightButton" then
                if E.HandlePlayerPopOut then E:HandlePlayerPopOut(hit._col) end
            else
                E:HandlePlayerMove(hit._col)
            end
        end)
        hit:SetScript("OnEnter", function()
            if Renderer._suppressHover then return end
            Renderer._hoverCol = hit._col
            Renderer:RefreshHover()
        end)
        hit:SetScript("OnLeave", function()
            if Renderer._suppressHover then return end
            if Renderer._hoverCol == hit._col then Renderer._hoverCol = nil end
            Renderer:RefreshHover()
        end)
        hit:Enable()
        hit:SetFrameLevel(self.playfield:GetFrameLevel() + 55)
        hit:Show()

        self.colHitFrames[col] = hit
    end

    self:_LayoutRibs(board)
    self:_LayoutColNumbers(board)
    self._seenMoveKey = MoveKey(board.lastMove, board)
    self._hidingMoveKey = ""
    self._hidingPopCol = nil
    self:PaintDiscs(board)
    self:RefreshChrome()
    self:_UpdateHud(board)

    if board.gameOver then
        if board.winningLine then
            self.lastResult = board.result
            self:HighlightWinningLine(board.winningLine)
        end
        local E = ArcadiaNexus.AR_Engine
        if E and E.OnDropSettled then E:OnDropSettled() end
    end
end

function Renderer:PaintDiscs(board)
    local symbols = ResolveSymbols()
    local hideKey = self._hidingMoveKey
    for row = 1, board.rows do
        for col = 1, board.cols do
            local btn   = self.cellButtons[row] and self.cellButtons[row][col]
            local value = board.cells[row][col]
            if btn then
                local key = tostring(col) .. ":" .. tostring(row)
                if hideKey ~= "" and key == hideKey then
                    ApplySymbol(btn, nil)
                elseif self._hidingPopCol and col == self._hidingPopCol then
                    ApplySymbol(btn, nil)
                elseif value == 1 then
                    ApplySymbol(btn, symbols.player1)
                elseif value == 2 then
                    ApplySymbol(btn, symbols.player2)
                else
                    ApplySymbol(btn, nil)
                end
                if btn.disc and btn.disc:IsShown() then
                    btn.disc:SetAlpha(1)
                end
                if btn.discPulse then btn.discPulse:Stop() end
            end
        end
    end
end

function Renderer:RefreshHover()
    local E = ArcadiaNexus.AR_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    if not board then return end
    self:_PaintThreats(board)
    self:_UpdateGhost(board)
end

function Renderer:RefreshChrome()
    if self._chromeBusy then return end
    self._chromeBusy = true
    local E = ArcadiaNexus.AR_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    if not board then
        self._chromeBusy = false
        return
    end
    self:_UpdateHits(board)
    self:_SyncHoverFromMouse()
    self:_PaintThreats(board)
    self:_UpdateGhost(board)
    self:_UpdateHud(board)
    self._chromeBusy = false
end

function Renderer:_PaintThreats(board)
    local Logic = ArcadiaNexus.AR_Logic
    local you = board.localSeat or 1
    local opp = (you == 1) and 2 or 1
    local yourWins, oppWins = {}, {}
    if Logic and Logic.GetImmediateWinSlots then
        local yw = Logic:GetImmediateWinSlots(board, you)
        local ow = Logic:GetImmediateWinSlots(board, opp)
        for i = 1, #yw do
            yourWins[yw[i].col .. ":" .. yw[i].row] = true
        end
        for i = 1, #ow do
            oppWins[ow[i].col .. ":" .. ow[i].row] = true
        end
    end
    local yourPops, oppPops = {}, {}
    if board.popOut and Logic and Logic.GetImmediatePopSlots then
        local yp = Logic:GetImmediatePopSlots(board, you)
        local op = Logic:GetImmediatePopSlots(board, opp)
        for i = 1, #yp do yourPops[yp[i].col] = true end
        for i = 1, #op do oppPops[op[i].col] = true end
    end

    local popPrev = PopPreviewCol(board)
    local lm = board.lastMove
    local lastKey = nil
    if lm and lm.col and lm.row and not lm.pop then
        lastKey = lm.col .. ":" .. lm.row
    end
    local hintLand = nil
    local hintCol = Renderer._hintOn and Renderer._hintCol or nil
    if hintCol and Logic then
        hintLand = Logic.GetLowestRow and Logic:GetLowestRow(board, hintCol)
    end

    for row = 1, board.rows do
        for col = 1, board.cols do
            local btn = self.cellButtons[row] and self.cellButtons[row][col]
            if btn then
                btn:SetBackdropColor(CFG.plate_r, CFG.plate_g, CFG.plate_b, 1)
                local well = btn.well
                if well then
                    local key = col .. ":" .. row
                    local empty = board.cells[row][col] == 0
                    local bottom = row == board.rows
                    if btn.disc and btn.disc:IsShown() then
                        btn.disc:SetAlpha(1)
                    end
                    if hintLand and col == hintCol and row == hintLand then
                        well:SetVertexColor(0.20, 0.72, 0.32, 1)
                    elseif empty and oppWins[key] then
                        well:SetVertexColor(0.55, 0.12, 0.12, 1)
                    elseif empty and yourWins[key] then
                        well:SetVertexColor(0.50, 0.40, 0.08, 1)
                    elseif popPrev and col == popPrev and bottom and not empty then
                        well:SetVertexColor(0.85, 0.55, 0.12, 1)
                        if btn.disc then btn.disc:SetAlpha(0.38) end
                    elseif popPrev and col == popPrev and not empty and not bottom then
                        well:SetVertexColor(0.42, 0.36, 0.12, 1)
                    elseif lastKey and key == lastKey then
                        well:SetVertexColor(0.18, 0.52, 0.58, 1)
                        if btn.discPulse and btn.disc and btn.disc:IsShown() then
                            btn.discPulse:Play()
                        end
                    elseif lm and lm.pop and lm.col == col and not empty then
                        well:SetVertexColor(0.18, 0.52, 0.58, 1)
                    elseif bottom and not empty and oppPops[col] then
                        well:SetVertexColor(0.55, 0.12, 0.12, 1)
                    elseif bottom and not empty and yourPops[col] then
                        well:SetVertexColor(0.50, 0.40, 0.08, 1)
                    elseif DBG_SHOW_HIGHLIGHT and empty and self._hoverCol == col then
                        well:SetVertexColor(0.18, 0.24, 0.48, 1)
                    else
                        well:SetVertexColor(CFG.well_r, CFG.well_g, CFG.well_b, 1)
                    end
                end
            end
        end
    end
end

function Renderer:_UpdateGhost(board)
    local g = self._ghost
    if not g then return end
    local col = self._hoverCol
    if Renderer._hintOn and Renderer._hintCol then
        col = Renderer._hintCol
    end
    local E = ArcadiaNexus.AR_Engine
    local myTurn = board and not board.gameOver and board.turn == (board.localSeat or 1)
    if self._animating or not col or not myTurn or not board then
        g:Hide()
        return
    end
    if PopPreviewCol(board) then
        g:Hide()
        return
    end
    local Logic = ArcadiaNexus.AR_Logic
    local row = Logic and Logic.GetLowestRow and Logic:GetLowestRow(board, col)
    if not row then
        g:Hide()
        return
    end
    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    local _, stone = ChipMetrics(cellW, cellH)
    local x, y = ChipTopLeft(offX, offY, cellW, cellH, col, row, stone)
    g:ClearAllPoints()
    g:SetSize(stone, stone)
    g:SetPoint("TOPLEFT", self.playfield, "TOPLEFT", x, -y)
    if self.playfield then
        g:SetFrameLevel(self.playfield:GetFrameLevel() + 18)
    end
    local symbols = ResolveSymbols()
    local seat = board.localSeat or 1
    ApplySymbol(g, (seat == 2) and symbols.player2 or symbols.player1, 0.42)
    g:Show()
end

function Renderer:_UpdateHits(board)
    local E = ArcadiaNexus.AR_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    local canPlay = board
        and not board.gameOver
        and not self._animating
        and not (E and E._busy)
        and (not mp or board.turn == board.localSeat)
    self._suppressHover = true
    for col = 1, #self.colHitFrames do
        local hit = self.colHitFrames[col]
        if hit then
            if canPlay then
                hit:Enable()
            else
                hit:Disable()
            end
        end
    end
    self._suppressHover = false
end

function Renderer:OnBoardUpdated()
    local E = ArcadiaNexus.AR_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    if not board then return end
    if not self.cellButtons[1] then
        self:RenderBoard(board)
        return
    end
    local key = MoveKey(board.lastMove, board)
    if key ~= "" and key ~= self._seenMoveKey then
        self._hintOn = false
        self._hintCol = nil
        self:StartDrop(board)
        return
    end
    self:PaintDiscs(board)
    self:RefreshChrome()
end

function Renderer:StartPopSlide(board)
    local move = board.lastMove
    local E = ArcadiaNexus.AR_Engine
    local function settle()
        self._animating = false
        self._hidingPopCol = nil
        self._hidingMoveKey = ""
        self._seenMoveKey = MoveKey(move, board)
        local live = (E and E.GetBoardState and E:GetBoardState()) or board
        self:PaintDiscs(live)
        if self._popFlyerPool then self._popFlyerPool:ReleaseAll() end
        if E and E.OnDropSettled then E:OnDropSettled() end
        self:RefreshChrome()
    end

    self:_EnsureBoardPools()
    local loop = DropLoop()
    local pf = self.playfield
    if not loop or not pf or not self._popFlyerPool or not move or not move.col then
        settle()
        return
    end

    local col = move.col
    local symbols = ResolveSymbols()
    local actor = move.actor
    if not actor then
        if board.gameOver and board.result == "WIN" then
            actor = 1
        elseif board.gameOver and board.result == "LOSS" then
            actor = 2
        else
            actor = (board.turn == 1) and 2 or 1
        end
    end

    self:_StopDrop()
    self._animating = true
    self._hidingPopCol = col
    self._seenMoveKey = MoveKey(move, board)
    if self._ghost then self._ghost:Hide() end

    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    local _, stone = ChipMetrics(cellW, cellH)
    local tracks = {}

    local function addTrack(fromRow, toRow, symbol, fadeOut)
        if not fromRow or not toRow then return end
        local fl = self._popFlyerPool:Acquire({})
        if not fl then return end
        fl:SetParent(pf)
        fl:SetFrameLevel(pf:GetFrameLevel() + 43)
        local x0, y0 = ChipTopLeft(offX, offY, cellW, cellH, col, fromRow, stone)
        local _, y1 = ChipTopLeft(offX, offY, cellW, cellH, col, toRow, stone)
        fl:ClearAllPoints()
        fl:SetSize(stone, stone)
        fl:SetPoint("TOPLEFT", pf, "TOPLEFT", x0, -y0)
        ApplySymbol(fl, symbol, 1)
        fl:Show()
        tracks[#tracks + 1] = { frame = fl, x = x0, y0 = y0, y1 = y1, fade = fadeOut and true or false }
    end

    local shifts = move.shifts
    if type(shifts) == "table" then
        for i = 1, #shifts do
            local s = shifts[i]
            if s and s.toRow and s.toRow <= board.rows then
                local v = s.player
                addTrack(s.fromRow, s.toRow, (v == 2) and symbols.player2 or symbols.player1)
            end
        end
    else
        for row = 2, board.rows do
            local v = board.cells[row][col]
            if v == 1 or v == 2 then
                addTrack(row - 1, row, (v == 2) and symbols.player2 or symbols.player1)
            end
        end
    end
    addTrack(board.rows, board.rows + 1, (actor == 2) and symbols.player2 or symbols.player1, true)

    self:PaintDiscs(board)
    self:RefreshChrome()
    PlayPopSound()

    local dur = CFG.pop_slide or 0.22
    local t = 0
    loop:Start(function(dt)
        t = t + dt
        local p = t / dur
        if p > 1 then p = 1 end
        p = p * p
        for i = 1, #tracks do
            local tr = tracks[i]
            local y = tr.y0 + (tr.y1 - tr.y0) * p
            tr.frame:ClearAllPoints()
            tr.frame:SetPoint("TOPLEFT", Renderer.playfield, "TOPLEFT", tr.x, -y)
            if tr.fade and tr.frame.disc then
                tr.frame.disc:SetAlpha(1 - p)
            end
        end
        if p >= 1 then
            loop:Stop()
            settle()
        end
    end, {
        stateCheck = function()
            return E and (E.state == "PLAYING" or E.state == "FINISHED")
        end,
    })
end

function Renderer:StartDrop(board)
    local move = board.lastMove
    local E = ArcadiaNexus.AR_Engine
    if InstantDrops() or not move then
        self._animating = false
        self._hidingMoveKey = ""
        self._hidingPopCol = nil
        self._seenMoveKey = MoveKey(move, board)
        self:PaintDiscs(board)
        if E and E.OnDropSettled then E:OnDropSettled() end
        self:RefreshChrome()
        return
    end
    if move.pop then
        self:StartPopSlide(board)
        return
    end
    local loop = DropLoop()
    local flyer = self._flyer
    if not loop or not flyer or not self.playfield then
        self._seenMoveKey = MoveKey(move, board)
        self._hidingMoveKey = ""
        self:PaintDiscs(board)
        local E = ArcadiaNexus.AR_Engine
        if E and E.OnDropSettled then E:OnDropSettled() end
        self:RefreshChrome()
        return
    end

    self:_StopDrop()
    self._animating = true
    self._hidingMoveKey = tostring(move.col) .. ":" .. tostring(move.row)
    self._seenMoveKey = MoveKey(move, board)
    if self._ghost then self._ghost:Hide() end

    local player = board.cells[move.row][move.col]
    local symbols = ResolveSymbols()
    ApplySymbol(flyer, (player == 2) and symbols.player2 or symbols.player1, 1)

    local offX, offY, cellW, cellH = self:_GridOrigin(board)
    local _, stone = ChipMetrics(cellW, cellH)
    local destX, destY = ChipTopLeft(offX, offY, cellW, cellH, move.col, move.row, stone)
    local startY = offY - stone - (CFG.rib_w or 7)
    flyer:SetFrameLevel(self.playfield:GetFrameLevel() + 18)
    flyer:ClearAllPoints()
    flyer:SetSize(stone, stone)
    flyer:SetPoint("TOPLEFT", self.playfield, "TOPLEFT", destX, -startY)
    flyer:Show()

    self:PaintDiscs(board)
    self:RefreshChrome()

    local fallDur = CFG.drop_base + CFG.drop_per_row * move.row
    local bounceDur = CFG.drop_bounce or 0.14
    local bouncePx = CFG.drop_bounce_px or 8
    local t = 0
    local impact = false
    local E = ArcadiaNexus.AR_Engine
    loop:Start(function(dt)
        t = t + dt
        local y
        if t < fallDur then
            local p = t / fallDur
            if p > 1 then p = 1 end
            p = p * p
            y = startY + (destY - startY) * p
        else
            if not impact then
                impact = true
                PlayDropSound()
            end
            local b = (t - fallDur) / bounceDur
            if b > 1 then b = 1 end
            y = destY - math.sin(b * math.pi) * bouncePx
            if b >= 1 then
                loop:Stop()
                flyer:Hide()
                Renderer._animating = false
                Renderer._hidingMoveKey = ""
                Renderer:PaintDiscs(board)
                if E and E.OnDropSettled then E:OnDropSettled() end
                Renderer:RefreshChrome()
                return
            end
        end
        flyer:ClearAllPoints()
        flyer:SetPoint("TOPLEFT", Renderer.playfield, "TOPLEFT", destX, -y)
    end, {
        stateCheck = function()
            return E and (E.state == "PLAYING" or E.state == "FINISHED")
        end,
    })
end

function Renderer:ShowGameOver(result)
    if self._resultShown then return end
    self._resultShown = true
    self.state      = "GAMEOVER"
    self.lastResult = result
    local E      = ArcadiaNexus.AR_Engine
    local mp     = E and E.mode and E.mode ~= "hotseat"

    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
    local UI     = ArcadiaNexus.UI
    local parent = self.playfield
    if not parent then return end

    local dialogResult = (result == "WIN" or result == "LOSS") and result or "DRAW"
    local board = E and E.GetBoardState and E:GetBoardState()
    local puzzle = not mp and board and board.playMode == "puzzle"

    self._suppressHover = true
    for col = 1, #self.colHitFrames do
        local hit = self.colHitFrames[col]
        if hit then
            hit:Disable()
            hit:EnableMouse(false)
        end
    end
    self._suppressHover = false

    local lines = {}
    local seriesOver = false
    local seriesWin = false
    local titleKeys = {
        WIN  = { "result_win" },
        LOSS = { "result_loss" },
        DRAW = { "result_draw" },
    }
    if puzzle then
        lines[#lines + 1] = string.format(L["hud_win_in"] or "Gewinn in %d", (board and board.winIn) or 1)
        titleKeys = {
            WIN  = { "result_puzzle_win", "result_win" },
            LOSS = { "result_puzzle_loss", "result_loss" },
            DRAW = { "result_puzzle_loss", "result_draw" },
        }
    elseif not mp and E and E.GetSeries then
        local s = E:GetSeries()
        seriesOver = E:IsSeriesOver()
        seriesWin = (s.you or 0) > (s.opp or 0)
        if seriesOver then
            dialogResult = seriesWin and "WIN" or "LOSS"
            titleKeys = {
                WIN  = { "result_series_win" },
                LOSS = { "result_series_loss" },
                DRAW = { "result_series_loss" },
            }
            lines[#lines + 1] = L["result_series_bestof"] or "Best of 3"
            lines[#lines + 1] = string.format("%d : %d", s.you or 0, s.opp or 0)
        else
            lines[#lines + 1] = string.format(L["hud_series"] or "Serie %d : %d", s.you or 0, s.opp or 0)
        end
    end

    local function RetryHotseat()
        Renderer._resultShown = false
        ArcadiaNexus.AR_Engine:StartGame({
            cols           = CFG.board_cols,
            rows           = CFG.board_rows,
            aiDifficulty   = Renderer.selectedDiff,
            firstPlayer    = Renderer.selectedStarter or "you",
            playMode       = Renderer.selectedMode or "play",
            mode           = "hotseat",
            seriesContinue = (not puzzle) and (not seriesOver),
        })
    end

    local buttons
    if mp then
        buttons = {
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_new_game or L["btn_start"],
                onClick = function()
                    local Shell = ArcadiaNexus.MatchShell
                    if Shell and Shell.Rematch then Shell.Rematch("ARCADIAROWS") end
                end,
            },
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_exit or L["btn_exit"],
                onClick = function()
                    ArcadiaNexus.AR_Engine:StopGame()
                end,
            },
        }
    elseif puzzle then
        if result == "WIN" then
            buttons = {
                { label = L["btn_next_puzzle"] or "Nächste Stellung", onClick = RetryHotseat },
                { label = L["btn_exit"] or "Beenden", onClick = function() ArcadiaNexus.AR_Engine:StopGame() end },
            }
        else
            buttons = {
                { label = L["btn_retry_puzzle"] or "Nochmal", onClick = RetryHotseat },
                { label = L["btn_skip"] or "Überspringen", onClick = function()
                    Renderer._resultShown = false
                    ArcadiaNexus.UI.HideResultDialog(parent)
                    ArcadiaNexus.AR_Engine:SkipPuzzle()
                end },
                { label = L["btn_exit"] or "Beenden", onClick = function() ArcadiaNexus.AR_Engine:StopGame() end },
            }
        end
    end

    UI.ShowArcadeResult(parent, {
        gameId     = "ARCADIAROWS",
        difficulty = mp and "normal" or Renderer.selectedDiff,
        result     = dialogResult,
        lines      = #lines > 0 and lines or nil,
        titleKeys  = titleKeys,
        L = L,
        onRetry = function()
            if mp then
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("ARCADIAROWS") end
                return
            end
            RetryHotseat()
        end,
        onExit = function()
            ArcadiaNexus.AR_Engine:StopGame()
        end,
        buttons = buttons,
    })

    self:UpdateStartButton()
    self:_RefreshSeg3()
    PlayGameSound(result)
end

function Renderer:ClearWinningLine()
    if self.winLineTexture then
        if self.winLineTexture.pulseAnim then
            self.winLineTexture.pulseAnim:Stop()
        end
        self.winLineTexture:Hide()
    end
    for row = 1, #self.cellButtons do
        local rowData = self.cellButtons[row]
        if rowData then
            for col = 1, #rowData do
                local btn = rowData[col]
                if btn and btn.discPulse then btn.discPulse:Stop() end
                if btn and btn.disc then btn.disc:SetAlpha(1) end
                if btn and btn.atlTex then btn.atlTex:SetAlpha(1) end
            end
        end
    end
end

function Renderer:HighlightWinningLine(line)
    if not line or #line < 2 then return end

    local cellW = self.cellW
    local cellH = self.cellH
    local gridW = cellW * CFG.board_cols
    local gridH = cellH * CFG.board_rows
    local offX  = (CFG.field_w - gridW) / 2 + CFG.grid_ox
    local offY  = (CFG.field_h - gridH) / 2 + CFG.grid_oy

    local p1 = line[1]
    local p2 = line[#line]

    local x1 = offX + (p1.col - 0.5) * cellW
    local y1 = offY + (p1.row - 0.5) * cellH
    local x2 = offX + (p2.col - 0.5) * cellW
    local y2 = offY + (p2.row - 0.5) * cellH

    local dx     = x2 - x1
    local dy     = y1 - y2
    local length = math.sqrt(dx*dx + dy*dy)
    local cx     = (x1 + x2) / 2
    local cy     = (y1 + y2) / 2
    local angle  = math.atan2(dy, dx)

    for i = 1, #line do
        local cell = line[i]
        local btn = self.cellButtons[cell.row] and self.cellButtons[cell.row][cell.col]
        if btn and btn.discPulse then
            btn.discPulse:Stop()
            btn.discPulse:Play()
        end
    end

    if not self.winLineFrame then
        local frame = CreateFrame("Frame", nil, self.playfield)
        frame:SetAllPoints(self.playfield)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(self.playfield:GetFrameLevel() + 150)
        self.winLineFrame = frame

        local tex = frame:CreateTexture(nil, "OVERLAY")
        self.winLineTexture = tex

        local pulse = tex:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.35)
        fade:SetToAlpha(1)
        fade:SetDuration(0.5)
        fade:SetSmoothing("IN_OUT")
        tex.pulseAnim = pulse
    end

    local tex = self.winLineTexture
    if tex.pulseAnim then tex.pulseAnim:Stop() end

    local E = ArcadiaNexus.AR_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    local result = (board and board.result) or self.lastResult
    if result then
        self.lastResult = result
    end
    if result == "LOSS" then
        tex:SetColorTexture(1, 0, 0, 0.9)
    else
        tex:SetColorTexture(0, 1, 0, 0.9)
    end

    tex:SetSize(length, 8)
    tex:SetPoint("CENTER", self.playfield, "TOPLEFT", cx, -cy)
    tex:SetRotation(angle)
    tex:SetAlpha(1)
    tex:Show()
    tex.pulseAnim:Play()
end

ArcadiaNexus.RegisterGame({
    id        = "ARCADIAROWS",
    label     = "Arcadia Rows",
    renderer  = "AR_Renderer",
    engine    = "AR_Engine",
    container = "_arContainer",
    category  = "DENKSPIELE",
    matchSeats = 2,
    logo      = AR_ASSETS.logo,
    xp        = 10,
})
