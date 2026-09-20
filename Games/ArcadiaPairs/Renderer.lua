-- ============================================================
--  ArcadiaNexus
--  Games/Memory/Renderer.lua
--  Version: 2.0.0  (Blueprint v2 – nach Match-3/2048-Muster)
--
--  Layout-Strategie:
--    - Alle Elemente direkt an self.frame (GamesPanel) verankert
--    - CENTER-Ankern für Spielfeld, Border, Logo
--    - HUD (Züge, Paare, Timer) über dem Spielfeld
--    - Controls-Leiste am BOTTOM von self.frame (1:1 wie Match-3)
--    - Border als eigener Frame (FrameLevel +10 über _fieldFrame)
--    - Logo via UI.CreateGameLogo (IDLE-Zustand)
--    - Dropdown (Schwierigkeit) + Timer-Checkbox + Start/Beenden + Neues Spiel
--
--  Board-Aufbau (unverändert):
--    Karte = Button + BackdropTemplate
--    card.icon     = Textur (ARTWORK), beginnt Hidden
--    card.backIcon = Fraktions-Icon (ARTWORK), beginnt Shown
--    UpdateBoard() nach HandleFlip; Flip/Pop/Shake/Deal über GameLoop
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.AP_Renderer = {}
local R = ArcadiaNexus.AP_Renderer

-- ============================================================
-- ASSET-PFADE
-- ============================================================
local AP_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\background\\background_ap",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\logo\\logo_arcadia_pairs",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\ArcadiaPairs\\assets\\border\\border_arcadia_pairs",
}

-- ============================================================
-- LAYOUT-KONSTANTEN (hier anpassen)
-- ============================================================

-- Spielfeld (Karten-Größe dynamisch berechnet)
local BOARD_SIZE   = 450
local FIELD_OFS_X  = 0       -- Spielfeld horizontal (0 = mittig)
local FIELD_OFS_Y  = 15      -- Spielfeld vertikal (positiv = nach oben)

-- Hintergrund (relativ zu _fieldFrame CENTER)
local CFG = {
    bg_w     = 750,
    bg_h     = 530,
    bg_ofs_x = 0,
    bg_ofs_y = -10,
    bg_alpha = 1,
    hud_moves_w     = 140,
    hud_moves_h     = 28,
    hud_moves_x     = -155,
    hud_moves_y     = 251,
    hud_moves_alpha = 0.75,
    hud_pairs_w     = 140,
    hud_pairs_h     = 28,
    hud_pairs_x     = 155,
    hud_pairs_y     = 251,
    hud_pairs_alpha = 0.75,
    hud_time_w      = 140,
    hud_time_h      = 28,
    hud_time_x      = 0,
    hud_time_y      = 251,
    hud_time_alpha  = 0.75,
}

-- Border über dem Spielfeld
local BORDER_W     = 792
local BORDER_H     = 550
local BORDER_OFS_X = 0
local BORDER_OFS_Y = 0

-- Logo im Spielfeld (IDLE-Zustand)
local LOGO_W       = 445
local LOGO_H       = 206
local LOGO_OFS_X   = 0
local LOGO_OFS_Y   = 0

-- HUD (Züge, Paare, Timer) – relativ zu self.frame CENTER
local HUD_Y        = -170
local HUD_L_X      = -150    -- Züge: links
local HUD_C_X      = 0       -- Paare: mittig
local HUD_R_X      = 150     -- Timer: rechts

-- Controls-Widgets
local DD_W         = 120
local CHK_SIZE     = 20    -- CheckButton Größe

-- Buttons
local BTN_W        = 144
local BTN_H        = 32

-- Karten-Farben
local CLR_HIDDEN   = { 0.20, 0.30, 0.50, 1 }
local CLR_FLIPPED  = { 0.80, 0.80, 0.80, 1 }
local CLR_MATCHED  = { 0.15, 0.50, 0.15, 1 }
local CLR_MISMATCH = { 0.60, 0.15, 0.15, 1 }
local CLR_HOVER    = { 0.30, 0.40, 0.60, 1 }

local PAIR_TINTS = {
    { 0.95, 0.45, 0.20 },
    { 0.35, 0.70, 1.00 },
    { 0.95, 0.80, 0.20 },
    { 0.55, 0.90, 0.40 },
    { 0.85, 0.40, 0.90 },
    { 0.20, 0.85, 0.80 },
    { 1.00, 0.55, 0.70 },
    { 0.70, 0.55, 0.30 },
}

local CARD_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false,
    edgeSize = 2,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
}

local FLIP_DUR   = 0.16
local POP_DUR    = 0.22
local SHAKE_DUR  = 0.28
local DEAL_DUR   = 0.20
local DEAL_SPAN  = 0.34
local MATCH_DIM  = 0.82
local STREAK_FLOAT_DUR = 2.55

local _animLoop = ArcadiaNexus.GameLoop and ArcadiaNexus.GameLoop.Create("ArcadiaNexus_AP_AnimLoop")
local _tweens = {}
local _loopOn = false

local function PlaceCard(card)
    if not card or not card._holder or not card._layW then return end
    card:SetScale(1)
    if card._visState == "MATCHED" then
        card:SetAlpha(MATCH_DIM)
    else
        card:SetAlpha(1)
    end
    card:SetSize(card._layW, card._layH)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", card._holder, "TOPLEFT", card._layX, -card._layY)
    if card.icon and card._texSize then card.icon:SetSize(card._texSize, card._texSize) end
    if card.backIcon and card._texSize then card.backIcon:SetSize(card._texSize, card._texSize) end
end

local function ApplyCardVisual(card, state, cardData, canPlay)
    if not card or not cardData then return end
    if state == "MATCHED" then
        card:SetBackdropColor(CLR_MATCHED[1], CLR_MATCHED[2], CLR_MATCHED[3], 1)
        card:SetBackdropBorderColor(0.2, 0.7, 0.2, 1)
        if cardData.icon then
            card.icon:SetTexture("Interface\\Icons\\" .. cardData.icon)
            card.icon:Show()
        end
        card.backIcon:Hide()
        card:Disable()
        card:SetAlpha(MATCH_DIM)
    elseif state == "FLIPPED" then
        card:SetBackdropColor(CLR_FLIPPED[1], CLR_FLIPPED[2], CLR_FLIPPED[3], 1)
        card:SetBackdropBorderColor(0.9, 0.8, 0.4, 1)
        if cardData.icon then
            card.icon:SetTexture("Interface\\Icons\\" .. cardData.icon)
            card.icon:Show()
        end
        card.backIcon:Hide()
        card:Disable()
        card:SetAlpha(1)
    else
        card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], 1)
        card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
        card.icon:Hide()
        card.backIcon:Show()
        card:SetAlpha(1)
        if canPlay then card:Enable() else card:Disable() end
    end
end

local function StopAnimLoop()
    _loopOn = false
    if _animLoop then _animLoop:Stop() end
end

local function FinishTween(tw)
    local card = tw.card
    if not card then return end
    if tw.kind == "streakFloat" then
        card._busy = false
        card:SetAlpha(0)
        card:Hide()
        return
    end
    PlaceCard(card)
    if tw.kind == "flip" then
        ApplyCardVisual(card, tw.toState, tw.cardData, tw.canPlay)
        card._visState = tw.toState
        if tw.pairTint then
            local t = tw.pairTint
            card:SetBackdropColor(t[1] * 0.25, t[2] * 0.25, t[3] * 0.25, 1)
            card:SetBackdropBorderColor(t[1], t[2], t[3], 1)
        end
    elseif tw.kind == "pop" then
        card._visState = "MATCHED"
        card:SetAlpha(MATCH_DIM)
    elseif tw.kind == "shake" then
        card:SetBackdropColor(CLR_MISMATCH[1], CLR_MISMATCH[2], CLR_MISMATCH[3], 1)
    elseif tw.kind == "deal" then
        card:Disable()
        R._dealLeft = (R._dealLeft or 1) - 1
    elseif tw.kind == "winPulse" then
        card:SetBackdropBorderColor(0.2, 0.7, 0.2, 1)
    end
end

local function StepTween(tw, u)
    local card = tw.card
    if not card then return end
    if tw.kind == "streakFloat" then
        local ox = -tw.ampX * math.cos(u * 2 * math.pi)
        local tY = u * u * (3 - 2 * u)
        local oy = tw.y0 + (tw.y1 - tw.y0) * tY
        card:ClearAllPoints()
        card:SetPoint("CENTER", tw.anchor, "CENTER", ox, oy)
        local fade
        if u < 0.08 then
            fade = u / 0.08
        elseif u > 0.72 then
            fade = 1 - (u - 0.72) / 0.28
        else
            fade = 1
        end
        card:SetAlpha(fade)
        local punch = 1
        if u < 0.14 then
            punch = 1.28 - 0.28 * (u / 0.14)
        end
        card:SetScale(tw.baseScale * punch)
        if card._fs then
            local flash = 0
            if u < 0.16 then flash = 1 - u / 0.16 end
            local r = tw.cr + (1 - tw.cr) * flash
            local g = tw.cg + (1 - tw.cg) * flash
            local b = tw.cb + (1 - tw.cb) * flash
            card._fs:SetTextColor(r, g, b)
        end
        if card._glow then
            local burst = (1 - u) * (tw.burst or 0.35)
            card._glow:SetAlpha(burst * fade)
        end
        return
    end
    if not card._holder then return end
    if tw.kind == "flip" then
        if u >= 0.5 and not tw.swapped then
            tw.swapped = true
            ApplyCardVisual(card, tw.toState, tw.cardData, tw.canPlay)
        end
        local sx = math.abs(1 - 2 * u)
        if sx < 0.06 then sx = 0.06 end
        local w = card._layW * sx
        local cx = card._layX + card._layW * 0.5
        local cy = card._layY + card._layH * 0.5
        card:SetWidth(w)
        card:ClearAllPoints()
        card:SetPoint("CENTER", card._holder, "TOPLEFT", cx, -cy)
    elseif tw.kind == "pop" then
        local sc = 1 + 0.16 * math.sin(u * math.pi)
        local sz = (card._texSize or 24) * sc
        if card.icon then card.icon:SetSize(sz, sz) end
        card:SetAlpha(1)
    elseif tw.kind == "shake" then
        local ox = math.sin(u * math.pi * 8) * 5 * (1 - u)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", card._holder, "TOPLEFT", card._layX + ox, -card._layY)
    elseif tw.kind == "deal" then
        local e = u * u * (3 - 2 * u)
        card:SetAlpha(e)
        local drop = (1 - e) * 12
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", card._holder, "TOPLEFT", card._layX, -(card._layY + drop))
    elseif tw.kind == "winPulse" then
        local sc = 1 + 0.22 * math.sin(u * math.pi)
        local sz = (card._texSize or 24) * sc
        if card.icon then card.icon:SetSize(sz, sz) end
        card:SetAlpha(1)
        card:SetBackdropBorderColor(1, 0.84, 0.25, 1)
    end
end

local function TickTweens(dt)
    local i = 1
    while i <= #_tweens do
        local tw = _tweens[i]
        local step = dt
        if (tw.delay or 0) > 0 then
            tw.delay = tw.delay - step
            if tw.delay > 0 then
                i = i + 1
            else
                step = -tw.delay
                tw.delay = 0
                tw.t = tw.t + step
                local u = tw.t / tw.dur
                if u >= 1 then
                    FinishTween(tw)
                    table.remove(_tweens, i)
                else
                    StepTween(tw, u)
                    i = i + 1
                end
            end
        else
            tw.t = tw.t + step
            local u = tw.t / tw.dur
            if u >= 1 then
                FinishTween(tw)
                table.remove(_tweens, i)
            else
                StepTween(tw, u)
                i = i + 1
            end
        end
    end
    if #_tweens == 0 then StopAnimLoop() end
    if R._dealing and (R._dealLeft or 0) <= 0 then
        R._dealing = false
        R:UpdateBoard()
    end
end

local function KickAnimLoop()
    if _loopOn or not _animLoop or #_tweens == 0 then return end
    _loopOn = true
    _animLoop:Start(TickTweens, { maxDt = 0.05 })
end

local function StopCardTweens(card, apply)
    for i = #_tweens, 1, -1 do
        local tw = _tweens[i]
        if tw.card == card then
            if apply then FinishTween(tw) end
            table.remove(_tweens, i)
        end
    end
    if #_tweens == 0 then StopAnimLoop() end
end

local function StopAllCardTweens()
    for i = 1, #_tweens do
        PlaceCard(_tweens[i].card)
    end
    for i = #_tweens, 1, -1 do
        _tweens[i] = nil
    end
    StopAnimLoop()
end

local function StartCardTween(card, tw)
    StopCardTweens(card, false)
    PlaceCard(card)
    if not _animLoop then
        tw.card = card
        FinishTween(tw)
        return
    end
    tw.card = card
    tw.t = 0
    _tweens[#_tweens + 1] = tw
    KickAnimLoop()
end

local function ResetPooledCard(card)
    StopCardTweens(card, false)
    PlaceCard(card)
    card._visState = nil
    card._holder = nil
    card._layX, card._layY, card._layW, card._layH, card._texSize = nil, nil, nil, nil, nil
end

local function CreateCardPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "ArcadiaPairs.Cards",
        create = function(poolParent)
            poolParentRef = poolParent
            local card = CreateFrame("Button", nil, poolParent, "BackdropTemplate")
            card:SetBackdrop(CARD_BACKDROP)
            if card.SetClipsChildren then card:SetClipsChildren(true) end
            local iconTex = card:CreateTexture(nil, "ARTWORK")
            iconTex:SetPoint("CENTER")
            iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            iconTex:Hide()
            card.icon = iconTex
            local backIcon = card:CreateTexture(nil, "ARTWORK")
            backIcon:SetPoint("CENTER")
            backIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            card.backIcon = backIcon
            return card
        end,
        onRelease = function(card)
            ResetPooledCard(card)
            card:Hide()
            card:ClearAllPoints()
            card:Enable()
            card:SetScript("OnClick", nil)
            card:SetScript("OnEnter", nil)
            card:SetScript("OnLeave", nil)
            card._cardIdx = nil
            card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], CLR_HIDDEN[4])
            card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
            if card.icon then
                card.icon:Hide()
                card.icon:SetTexture(nil)
                card.icon:SetVertexColor(1, 1, 1, 1)
            end
            if card.backIcon then
                card.backIcon:Hide()
                card.backIcon:SetTexture(nil)
                card.backIcon:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then card:SetParent(poolParentRef) end
        end,
    })
end

-- ============================================================
-- STATE
-- ============================================================
R.frame          = nil
R._canvas        = nil
R._controlsFrame = nil
R._fieldFrame   = nil
R._bgTex        = nil
R._borderFrame  = nil
R._borderTex    = nil
R._logoTex      = nil
R.state         = "IDLE"
R._lastDiff     = nil

-- Karten-Board
R._boardHolder  = nil
R._cards        = {}

-- HUD
R._movesFS      = nil
R._movesLbl     = nil
R._pairsFS      = nil
R._pairsLbl     = nil
R._timeFS       = nil
R._timeLbl      = nil
R._hintFS       = nil

-- Controls
R._startBtn     = nil
R._newGameBtn   = nil
R._timerCheckbox = nil

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
    self:EnterIdleState()

    local Engine = ArcadiaNexus.Engine
    Engine:On("AP_GAME_STARTED",  function(s) R:OnGameStarted(s)  end)
    Engine:On("AP_TIMER_TICK",    function(s) R:OnTimerTick(s)    end)
    Engine:On("AP_GAME_WON",      function(s) R:OnGameWon(s)      end)
    Engine:On("AP_GAME_LOST",     function(s) R:OnGameLost(s)     end)
    Engine:On("AP_GAME_STOPPED",  function()  R:EnterIdleState()  end)
    -- Flip/Match/Mismatch: UpdateBoard() direkt vom Engine aufgerufen (kein Event-Delay)
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
        outerName = "ArcadiaNexus_AP_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._apContainer = f

    f:SetScript("OnHide", function()
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then
            return
        end
        ArcadiaNexus.GameSession:HandleRendererHide("ARCADIAPAIRS", ArcadiaNexus.AP_Engine, function(eng)
            if eng.mode ~= "hotseat" and (eng.state == "PLAYING" or eng.state == "LOBBY" or eng.state == "FINISHED") then
                eng:HideView()
            elseif eng.state ~= "IDLE" or eng.activeGame then
                eng:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local f  = self._canvas
    local ff = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ff:SetSize(BOARD_SIZE, BOARD_SIZE)
    ff:SetPoint("CENTER", f, "CENTER", FIELD_OFS_X, FIELD_OFS_Y)
    ff:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ff:SetBackdropColor(0.10, 0.10, 0.14, 0)
    ff:SetBackdropBorderColor(0, 0, 0, 0)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff  = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(AP_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    local ff          = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(BORDER_W, BORDER_H)
    borderFrame:SetPoint("CENTER", ff, "CENTER", BORDER_OFS_X, BORDER_OFS_Y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(AP_ASSETS.border)
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
        AP_ASSETS.logo,
        { w = LOGO_W, h = LOGO_H, x = LOGO_OFS_X, y = LOGO_OFS_Y }
    )
end

-- ============================================================
-- HUD
-- ============================================================
function R:_CreateHUD()
    local f = self._canvas
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    self._movesBox, self._movesFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_moves_w, h = CFG.hud_moves_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_moves_x, y = CFG.hud_moves_y,
        alpha = CFG.hud_moves_alpha,
        text = (L["lbl_moves"] or "Züge") .. ": 0",
        shown = false,
    })
    self._pairsBox, self._pairsFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_pairs_w, h = CFG.hud_pairs_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_pairs_x, y = CFG.hud_pairs_y,
        alpha = CFG.hud_pairs_alpha,
        text = (L["lbl_pairs"] or "Paare") .. ": 0/0",
        shown = false,
    })
    self._timeBox, self._timeFS = UI.CreateHudStatBox(f, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        text = (L["lbl_time"] or "Zeit") .. ": --:--",
        shown = false,
    })
    self._movesLbl, self._pairsLbl, self._timeLbl = nil, nil, nil
    self:_RaiseHudAboveField()

    -- Hint (IDLE)
    local hintFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("CENTER", f, "CENTER", FIELD_OFS_X, FIELD_OFS_Y)
    hintFS:SetTextColor(0.80, 0.80, 0.70)
    hintFS:SetJustifyH("CENTER")
    hintFS:SetText("")
    self._hintFS = hintFS
end

function R:_UpdateHUD(board)
    if not board then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")

    if self._movesFS then
        if board.myScore ~= nil then
            self._movesFS:SetText((L["lbl_score"] or "Stand") .. ": " ..
                tostring(board.myScore) .. "–" .. tostring(board.oppScore or 0))
        else
            self._movesFS:SetText((L["lbl_moves"] or "Züge") .. ": " .. tostring(board.moves or 0))
        end
    end
    if self._pairsFS then
        self._pairsFS:SetText((L["lbl_pairs"] or "Paare") .. ": " ..
            tostring(board.matchedPairs or 0) .. "/" .. tostring(board.pairs or 0))
    end
    if board.timerActive and self._timeFS then
        self:_UpdateTimeDisplay(board.timerLeft or 0)
    end
end

function R:_RaiseHudAboveField()
    local base = 1
    if self._borderFrame and self._borderFrame.GetFrameLevel then
        base = self._borderFrame:GetFrameLevel()
    elseif self._fieldFrame and self._fieldFrame.GetFrameLevel then
        base = self._fieldFrame:GetFrameLevel()
    end
    local level = base + 20
    for _, box in ipairs({ self._movesBox, self._pairsBox, self._timeBox }) do
        if box and box.SetFrameLevel then box:SetFrameLevel(level) end
    end
end

function R:_UpdateTimeDisplay(secs)
    if not self._timeFS then return end
    self._timeFS:Show()
    local text, level, r, g, b = ArcadiaNexus.Format.SecondsWithUrgency(secs or 0, {
        warn = 60, crit = 30, padMinutes = false,
    })
    if level ~= "normal" then
        text = string.format("|cff%02x%02x%02x%s|r",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
    end
    self._timeFS:SetText((ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["lbl_time"] or "Zeit") .. ": " .. text)
end

function R:_StopStreakTween()
    for i = #_tweens, 1, -1 do
        local kind = _tweens[i].kind
        if kind == "streakFloat" or kind == "streak" or kind == "streakIn" or kind == "streakOut" then
            local fr = _tweens[i].card
            if fr then
                fr._busy = false
                fr:Hide()
            end
            table.remove(_tweens, i)
        end
    end
    if #_tweens == 0 then StopAnimLoop() end
end

function R:_EnsureStreakPool()
    if self._streakPool then return end
    self._streakPool = {}
end

function R:_NewStreakFloat()
    local parent = self._canvas or self._fieldFrame
    if not parent then return nil end
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(320, 56)
    f:EnableMouse(false)
    local glow = f:CreateFontString(nil, "ARTWORK")
    glow:SetPoint("CENTER", 0, 0)
    glow:SetTextColor(1, 0.9, 0.4)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER")
    f._fs = fs
    f._glow = glow
    f._busy = false
    return f
end

function R:_AcquireStreakFloat()
    self:_EnsureStreakPool()
    for i = 1, #self._streakPool do
        local f = self._streakPool[i]
        if f and not f._busy then return f end
    end
    local f = self:_NewStreakFloat()
    if not f then return nil end
    self._streakPool[#self._streakPool + 1] = f
    return f
end

function R:_ResetStreak()
    self._streak = 0
    self._streakDir = 1
    self:_StopStreakTween()
end

function R:_BreakStreak()
    self._streak = 0
end

local function ApplyStreakFont(fs, size, outline)
    if not fs then return end
    local ok = pcall(function()
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, outline and "OUTLINE" or "")
    end)
    if not ok then
        fs:SetFontObject("GameFontNormalHuge")
    end
end

function R:_SpawnBoardFloat(text, opts)
    opts = opts or {}
    local f = self:_AcquireStreakFloat()
    if not f or not f._fs then return end
    local size = opts.size or 22
    ApplyStreakFont(f._fs, size, true)
    ApplyStreakFont(f._glow, size + 10, true)
    f._fs:SetText(text)
    f._glow:SetText(text)
    local cr, cg, cb = opts.cr or 1, opts.cg or 0.84, opts.cb or 0.22
    f._fs:SetTextColor(cr, cg, cb)
    f._glow:SetTextColor(1, 0.92, 0.45)
    f._glow:SetAlpha(opts.burst or 0.28)
    local base = self._fieldFrame or self._canvas
    local level = 60
    if self._borderFrame and self._borderFrame.GetFrameLevel then
        level = self._borderFrame:GetFrameLevel() + 30
    elseif base and base.GetFrameLevel then
        level = base:GetFrameLevel() + 40
    end
    f:SetParent(self._canvas or base)
    f:SetFrameLevel(level)
    self._streakDir = -(self._streakDir or 1)
    local amp = (opts.amp or 55) * (self._streakDir)
    local y0 = opts.y0 or -165
    local y1 = opts.y1 or 155
    local scale = opts.scale or 1.05
    f._busy = true
    f:Show()
    f:SetAlpha(0)
    f:SetScale(scale * 1.25)
    f:ClearAllPoints()
    f:SetPoint("CENTER", self._fieldFrame or self._canvas, "CENTER", -amp, y0)
    if not _animLoop then
        f:SetAlpha(1)
        f:SetScale(scale)
        return
    end
    _tweens[#_tweens + 1] = {
        card = f,
        kind = "streakFloat",
        t = 0,
        dur = opts.dur or STREAK_FLOAT_DUR,
        delay = 0,
        anchor = self._fieldFrame or self._canvas,
        ampX = amp,
        y0 = y0,
        y1 = y1,
        baseScale = scale,
        cr = cr, cg = cg, cb = cb,
        burst = opts.burst or 0.28,
    }
    KickAnimLoop()
end

function R:_OnStreakMatch()
    self._streak = (self._streak or 0) + 1
    local n = self._streak
    if n < 2 then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local size = 22 + (n - 2) * 5
    if size > 38 then size = 38 end
    local cr, cg, cb = 1, 0.84, 0.22
    if n >= 5 then
        cr, cg, cb = 1, 0.45, 0.12
    elseif n >= 4 then
        cr, cg, cb = 1, 0.62, 0.14
    elseif n >= 3 then
        cr, cg, cb = 1, 0.75, 0.16
    end
    local scale = 1.05 + (n - 2) * 0.16
    if scale > 1.7 then scale = 1.7 end
    self:_SpawnBoardFloat(string.format(L["hud_streak"] or "Serie ×%d", n), {
        size = size,
        amp = 55 + (n - 2) * 8,
        scale = scale,
        cr = cr, cg = cg, cb = cb,
        burst = (n >= 3) and 0.55 or 0.28,
    })
end

function R:PlayWinFlourish(overrideText)
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    self:_SpawnBoardFloat(overrideText or L["hud_win_float"] or "Alle Paare!", {
        size = 34,
        amp = 42,
        y0 = -90,
        y1 = 170,
        scale = 1.45,
        cr = 1, cg = 0.84, cb = 0.15,
        burst = 0.7,
        dur = 2.2,
    })
    if not self._cards then return end
    for idx = 1, #self._cards do
        local card = self._cards[idx]
        if card and card._visState == "MATCHED" then
            StopCardTweens(card, false)
            PlaceCard(card)
            _tweens[#_tweens + 1] = {
                card = card,
                kind = "winPulse",
                t = 0,
                dur = 0.34,
                delay = (idx - 1) * 0.018,
            }
        end
    end
    KickAnimLoop()
end

function R:PlayLoseFlourish(overrideText)
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    self:_SpawnBoardFloat(overrideText or L["hud_lose_float"] or "Zeit abgelaufen!", {
        size = 32,
        amp = 38,
        y0 = -70,
        y1 = 150,
        scale = 1.35,
        cr = 1, cg = 0.28, cb = 0.22,
        burst = 0.45,
        dur = 2.2,
    })
    if not self._cards then return end
    for idx = 1, #self._cards do
        local card = self._cards[idx]
        if card and card._visState ~= "MATCHED" then
            card:SetBackdropColor(CLR_MISMATCH[1], CLR_MISMATCH[2], CLR_MISMATCH[3], 1)
            card:SetBackdropBorderColor(0.85, 0.2, 0.2, 1)
            StopCardTweens(card, false)
            PlaceCard(card)
            _tweens[#_tweens + 1] = {
                card = card,
                kind = "shake",
                t = 0,
                dur = SHAKE_DUR,
                delay = (idx - 1) * 0.012,
            }
        end
    end
    local E = ArcadiaNexus.AP_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    local board = (not mp) and E and E.GetBoardState and E:GetBoardState()
    if board and board.cards then
        self._revealRemain = true
        local delayBase = SHAKE_DUR + 0.10
        for idx = 1, #self._cards do
            local card = self._cards[idx]
            local data = board.cards[idx]
            if card and data and data.state ~= "MATCHED" and data.icon then
                local tint = PAIR_TINTS[(((data.pairID or idx) - 1) % #PAIR_TINTS) + 1]
                _tweens[#_tweens + 1] = {
                    card = card,
                    kind = "flip",
                    t = 0,
                    dur = FLIP_DUR,
                    delay = delayBase + (idx - 1) * 0.022,
                    toState = "FLIPPED",
                    cardData = data,
                    canPlay = false,
                    swapped = false,
                    pairTint = tint,
                }
            end
        end
    end
    KickAnimLoop()
end

-- ============================================================
-- CONTROLS
-- ============================================================
function R:_CreateControls()
    local L  = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local UI = ArcadiaNexus.UI

    local bar = UI.CreateGameControlsBar(self.frame, "wide")
    local cf = bar.frame
    self._controlsFrame = cf

    -- Schwierigkeits-Dropdown (Segment 1)
    local S = ArcadiaNexus.AP_Settings
    local ddOptions = {
        { key = "easy",   label = L["diff_easy"]   },
        { key = "normal", label = L["diff_normal"]  },
        { key = "hard",   label = L["diff_hard"]    },
    }

    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(DD_W, BTN_H)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    self._diffAnchor = ddAnchor

    UI.CreateSimpleDropdown(
        ddAnchor,
        0, 0,
        DD_W,
        "",
        ddOptions,
        function()
            return (S and S:Get("difficulty")) or "easy"
        end,
        function(key)
            R._lastDiff = key
            if S then S:Set("difficulty", key) end
        end
    )

    -- Timer-Checkbox (Segment 4), Label rechts
    local chkHolder, cb = UI.CreateBarCheckbox(cf, L["timer_label"] or "Timer", { w = 110, h = 36, size = CHK_SIZE })
    chkHolder:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[4], bar.y.checkbox)
    self._timerHolder = chkHolder
    cb:SetScript("OnShow", function()
        local S2 = ArcadiaNexus.AP_Settings
        cb:SetChecked(S2 and S2:Get("timerActive") or false)
    end)
    cb:SetScript("OnClick", function()
        local S2 = ArcadiaNexus.AP_Settings
        if S2 then S2:Set("timerActive", cb:GetChecked() and true or false) end
    end)
    self._timerCheckbox = cb

    -- Start / Beenden Button (Segment 2)
    local startBtn = UI.CreateArcadiaButton(cf, L["btn_start"], BTN_W, BTN_H)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AP_Engine
        if not E then return end
        if R.state == "PLAYING" and E.mode and E.mode ~= "hotseat" then
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.ShowEndRoundConfirm then
                Shell.ShowEndRoundConfirm(function()
                    ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
                    E:StopGame()
                end, R._fieldFrame)
                return
            end
        end
        if R.state == "PLAYING" or R.state == "LOBBY" or R.state == "FINISHED" or R.state == "WON" or R.state == "LOST" or R.state == "GAMEOVER" then
            E:StopGame()
        else
            local diff   = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
            local theme  = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
            local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
            E:StartGame({ difficulty = diff, theme = theme, timerActive = timer, mode = "hotseat" })
        end
    end)
    self._startBtn = startBtn

    -- Neues Spiel Button (Segment 3)
    local newGameBtn = UI.CreateArcadiaButton(cf, L["btn_new_game"], BTN_W, BTN_H)
    newGameBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    newGameBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.AP_Engine
        if not E then return end
        local diff   = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
        local theme  = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
        local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
        E:StartGame({ difficulty = diff, theme = theme, timerActive = timer })
    end)
    newGameBtn:Hide()
    self._newGameBtn = newGameBtn
end

-- ============================================================
-- BOARD-AUFBAU (unverändert – Kernlogik Memory)
-- ============================================================
function R:_EnsureCardPool()
    if not self._cardPool then
        self._cardPool = CreateCardPool()
    end
end

function R:BuildBoard(state)
    self:ClearBoard()

    local grid     = state.grid
    local gap      = 4
    local cellSize = math.floor((BOARD_SIZE - gap * (grid - 1)) / grid)
    local total    = cellSize * grid + gap * (grid - 1)

    local holder = self._boardHolder
    if not holder then
        holder = CreateFrame("Frame", nil, self._fieldFrame)
        self._boardHolder = holder
    end
    holder:SetParent(self._fieldFrame)
    holder:SetSize(total, total)
    holder:SetPoint("CENTER", self._fieldFrame, "CENTER", 0, 0)
    holder:Show()

    local SR       = ArcadiaNexus.AP_SymbolResolver
    local S        = ArcadiaNexus.AP_Settings
    local backData = SR:GetCardBack(S:GetAll())
    self:_EnsureCardPool()

    for idx = 1, state.totalCards do
        local row = math.floor((idx - 1) / grid)
        local col = (idx - 1) % grid
        local px  = col * (cellSize + gap)
        local py  = row * (cellSize + gap)

        local card = self._cardPool:Acquire({})
        card:SetParent(holder)
        card._holder = holder
        card._layX = px + 1
        card._layY = py + 1
        card._layW = cellSize - 2
        card._layH = cellSize - 2
        card._texSize = cellSize - 14
        card._visState = nil
        card:Disable()
        card:SetSize(card._layW, card._layH)
        card:SetPoint("TOPLEFT", holder, "TOPLEFT", card._layX, -card._layY)
        card:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], CLR_HIDDEN[4])
        card:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)

        card.icon:SetSize(card._texSize, card._texSize)
        card.backIcon:SetSize(card._texSize, card._texSize)
        card.backIcon:SetTexture(backData.icon)
        card.backIcon:SetVertexColor(backData.tint[1], backData.tint[2], backData.tint[3], 1)
        card._backTint = backData.tint
        card.backIcon:Show()
        card.icon:Hide()

        card._cardIdx = idx
        card:SetScript("OnClick", function(self)
            ArcadiaNexus.AP_Engine:HandleFlip(self._cardIdx)
        end)
        card:SetScript("OnEnter", function(self)
            local E = ArcadiaNexus.AP_Engine
            local board = E and E.GetBoardState and E:GetBoardState()
            local cardData = board and board.cards and board.cards[self._cardIdx]
            if cardData and cardData.state == "HIDDEN" then
                self:SetBackdropColor(CLR_HOVER[1], CLR_HOVER[2], CLR_HOVER[3], 1)
                self:SetBackdropBorderColor(0.95, 0.82, 0.35, 1)
                if self.backIcon then
                    local t = self._backTint or { 1, 1, 1 }
                    self.backIcon:SetVertexColor(
                        math.min(1, t[1] + 0.22),
                        math.min(1, t[2] + 0.22),
                        math.min(1, t[3] + 0.22),
                        1)
                end
            end
        end)
        card:SetScript("OnLeave", function(self)
            local E = ArcadiaNexus.AP_Engine
            local board = E and E.GetBoardState and E:GetBoardState()
            local cardData = board and board.cards and board.cards[self._cardIdx]
            if cardData and cardData.state == "HIDDEN" then
                self:SetBackdropColor(CLR_HIDDEN[1], CLR_HIDDEN[2], CLR_HIDDEN[3], 1)
                self:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
                if self.backIcon then
                    local t = self._backTint or { 1, 1, 1 }
                    self.backIcon:SetVertexColor(t[1], t[2], t[3], 1)
                end
            end
        end)
        card:Show()

        self._cards[idx] = card
    end
end

function R:ClearBoard()
    self._dealing = false
    self._dealLeft = 0
    self._revealRemain = false
    self:_ResetStreak()
    StopAllCardTweens()
    if self._cardPool then
        self._cardPool:ReleaseAll()
    end
    self._cards = {}
    if self._boardHolder then self._boardHolder:Hide() end
end

function R:PlayDealIn(state)
    self._dealing = false
    self._dealLeft = 0
    if not state or not self._cards then return end
    local n = state.totalCards or 0
    if n < 1 then return end
    if state.cards then
        for i = 1, n do
            local data = state.cards[i]
            if data and data.state and data.state ~= "HIDDEN" then
                return
            end
        end
    end
    if not _animLoop then return end

    self._dealing = true
    self._dealLeft = n
    local span = DEAL_SPAN
    for idx = 1, n do
        local card = self._cards[idx]
        if card then
            StopCardTweens(card, false)
            card:Disable()
            card._visState = "HIDDEN"
            card:SetAlpha(0)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", card._holder, "TOPLEFT", card._layX, -(card._layY + 12))
            local delay = (n <= 1) and 0 or ((idx - 1) / (n - 1)) * span
            _tweens[#_tweens + 1] = {
                card = card,
                kind = "deal",
                t = 0,
                dur = DEAL_DUR,
                delay = delay,
            }
        else
            self._dealLeft = self._dealLeft - 1
        end
    end
    if self._dealLeft <= 0 then
        self._dealing = false
        self._dealLeft = 0
        return
    end
    KickAnimLoop()
end

-- ============================================================
-- BOARD UPDATE (synchron, direkt vom Engine aufgerufen)
-- ============================================================
function R:UpdateBoard()
    if self._dealing then return end
    if self._revealRemain then
        local E = ArcadiaNexus.AP_Engine
        local board = E and E.GetBoardState and E:GetBoardState()
        if board then self:_UpdateHUD(board) end
        return
    end
    local E = ArcadiaNexus.AP_Engine
    local board = E and E.GetBoardState and E:GetBoardState()
    if not board then return end

    local mp = E.mode and E.mode ~= "hotseat"
    local canPlay = not board.gameOver and not board.blocked
        and (not mp or board.turn == board.localSeat)

    local newMatches = 0
    local flippedBack = 0
    for idx = 1, board.totalCards do
        local card     = self._cards[idx]
        local cardData = board.cards[idx]
        if card and cardData then
            local nextState = cardData.state
            local prev = card._visState
            if prev == "FLIPPED" and nextState == "MATCHED" then
                newMatches = newMatches + 1
            elseif prev == "FLIPPED" and nextState == "HIDDEN" then
                flippedBack = flippedBack + 1
            end
            if prev == nextState then
                if nextState == "HIDDEN" then
                    local busy = false
                    for i = 1, #_tweens do
                        if _tweens[i].card == card then busy = true; break end
                    end
                    if not busy then
                        ApplyCardVisual(card, nextState, cardData, canPlay)
                    end
                end
            elseif not prev then
                ApplyCardVisual(card, nextState, cardData, canPlay)
                card._visState = nextState
            elseif (prev == "HIDDEN" and nextState == "FLIPPED")
                or (prev == "FLIPPED" and nextState == "HIDDEN") then
                card._visState = nextState
                StartCardTween(card, {
                    kind = "flip",
                    dur = FLIP_DUR,
                    toState = nextState,
                    cardData = cardData,
                    canPlay = canPlay,
                    swapped = false,
                })
            elseif nextState == "MATCHED" then
                card._visState = "MATCHED"
                ApplyCardVisual(card, "MATCHED", cardData, canPlay)
                StartCardTween(card, { kind = "pop", dur = POP_DUR })
            else
                StopCardTweens(card, false)
                PlaceCard(card)
                ApplyCardVisual(card, nextState, cardData, canPlay)
                card._visState = nextState
            end
        end
    end

    if newMatches >= 2 then
        self:_OnStreakMatch()
    elseif flippedBack >= 2 then
        self:_BreakStreak()
    end

    self:_UpdateHUD(board)
end

-- ============================================================
-- MISMATCH-FLASH (direkt vom Engine aufgerufen)
-- ============================================================
function R:FlashMismatch(i1, i2)
    self:_BreakStreak()
    local function shake(card)
        if not card then return end
        card:SetBackdropColor(CLR_MISMATCH[1], CLR_MISMATCH[2], CLR_MISMATCH[3], 1)
        card:SetBackdropBorderColor(0.85, 0.2, 0.2, 1)
        StartCardTween(card, { kind = "shake", dur = SHAKE_DUR })
    end
    shake(self._cards[i1])
    shake(self._cards[i2])
end

-- ============================================================
-- IDLE STATE
-- ============================================================
function R:EnterIdleState()
    self.state = "IDLE"
    self:ClearBoard()

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._newGameBtn  then self._newGameBtn:Hide()  end
    if self._movesBox    then self._movesBox:Hide()    end
    if self._pairsBox    then self._pairsBox:Hide()    end
    if self._timeBox     then self._timeBox:Hide()     end
    if self._goldGrid    then self._goldGrid:Hide()    end
    if self._logoTex     then self._logoTex:Show()     end
    if self._borderFrame then self._borderFrame:Show() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
        self._startBtn:Show()
    end
    if self._diffAnchor then self._diffAnchor:Show() end
    if self._timerHolder then self._timerHolder:Show() end

    if self._hintFS then
        self._hintFS:SetText(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["hint_start"] or "")
        self._hintFS:Show()
    end
    self:_ResetStreak()
end

function R:Render()
    local E = ArcadiaNexus.AP_Engine
    if not E or E.mode == "hotseat" then return end
    local v = E:GetView()
    if not v then return end
    if v.state == "IDLE" or v.state == "ABORTED" then
        self:EnterIdleState()
        return
    end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    if self._diffAnchor then self._diffAnchor:Hide() end
    if self._timerHolder then self._timerHolder:Hide() end
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(L["btn_exit"] or "Beenden")
        self._startBtn:Show()
    end
    if v.state == "LOBBY" then
        self.state = "LOBBY"
        self:ClearBoard()
        if self._fieldFrame and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
        end
        if self._movesBox then self._movesBox:Hide() end
        if self._pairsBox then self._pairsBox:Hide() end
        if self._timeBox then self._timeBox:Hide() end
        if self._goldGrid then self._goldGrid:Hide() end
        if self._logoTex then self._logoTex:Show() end
        return
    end
    if v.state == "PLAYING" or v.state == "FINISHED" then
        local board = E:GetBoardState()
        if not board then return end
        if self._logoTex then self._logoTex:Hide() end
        if self._hintFS then self._hintFS:Hide() end
        if self._movesBox then self._movesBox:Show() end
        if self._pairsBox then self._pairsBox:Show() end
        if self._timeBox then self._timeBox:Hide() end
        if self._goldGrid then self._goldGrid:Show() end
        if self.state ~= "PLAYING" and self.state ~= "GAMEOVER" and self.state ~= "FINISHED"
            and self.state ~= "WON" and self.state ~= "LOST" then
            self.state = "PLAYING"
            self:BuildBoard(board)
            self:PlayDealIn(board)
        end
        if self._dealing then
            self:_UpdateHUD(board)
        else
            self:UpdateBoard()
        end
        if v.state == "FINISHED" then
            self.state = "FINISHED"
        end
    end
end

-- ============================================================
-- EVENT-HANDLER
-- ============================================================
function R:OnGameStarted(state)
    self.state    = "PLAYING"
    self._lastDiff = state.difficulty

    if self._fieldFrame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    end
    if self._hintFS  then self._hintFS:Hide()  end
    if self._logoTex then self._logoTex:Hide() end

    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_exit"])
    end
    local E = ArcadiaNexus.AP_Engine
    if self._newGameBtn then
        self._newGameBtn:SetShown(not (E and E.mode and E.mode ~= "hotseat"))
    end

    if self._movesBox then self._movesBox:Show() end
    if self._pairsBox then self._pairsBox:Show() end
    if self._goldGrid then self._goldGrid:Show() end
    self:_RaiseHudAboveField()

    if state.timerActive then
        if self._timeBox then self._timeBox:Show() end
        if self._timeFS then self._timeFS:Show() end
    else
        if self._timeBox then self._timeBox:Hide() end
    end

    self:BuildBoard(state)
    self:_ResetStreak()
    self:PlayDealIn(state)
    if not self._dealing then
        self:UpdateBoard()
    end
    self:_UpdateHUD(state)
end

function R:OnTimerTick(state)
    if state then
        self:_UpdateHUD(state)
        return
    end
    local game = ArcadiaNexus.AP_Engine.activeGame
    if game then self:_UpdateHUD(game.board) end
end

function R:_StartNewGameFromResult()
    local E = ArcadiaNexus.AP_Engine
    if not E then return end
    local diff  = R._lastDiff or (ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("difficulty")) or "easy"
    local theme = ArcadiaNexus.AP_Settings and ArcadiaNexus.AP_Settings:Get("theme") or "classes"
    local timer = R._timerCheckbox and R._timerCheckbox:GetChecked() and true or false
    E:StartGame({ difficulty = diff, theme = theme, timerActive = timer })
end

function R:OnGameWon(state)
    self.state = "WON"
    self:UpdateBoard()
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
    end

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local parent = self._fieldFrame

    local timeStr = ""
    if state.timerActive and state.timerLeft then
        timeStr = string.format(
            L["result_win_time"] or "\nZeit: %s",
            ArcadiaNexus.Format.SecondsMMSS(state.timerLeft, false))
    end

    UI.ShowArcadeResult(parent, {
        title      = L["result_win_title"] or "|cffffd700Alle Paare gefunden!|r",
        titleColor = {1, 0.84, 0},
        subtitle   = string.format(
            L["result_win_sub"] or "Züge: %d  Paare: %d",
            state.moves, state.pairs) .. timeStr,
        gameId     = "ARCADIAPAIRS",
        result     = "WIN",
        L          = L,
        onRetry    = function() R:_StartNewGameFromResult() end,
        onExit     = function()
            local E = ArcadiaNexus.AP_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:OnGameLost(state)
    self.state = "LOST"
    self:UpdateBoard()
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
    end

    if not self._fieldFrame then return end
    local UI     = ArcadiaNexus.UI
    local L      = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local parent = self._fieldFrame

    UI.ShowArcadeResult(parent, {
        title      = L["result_lose_title"] or "|cffff4444Zeit abgelaufen!|r",
        titleColor = {1, 0.3, 0.3},
        subtitle   = string.format(
            L["result_lose_sub"] or "Paare: %d/%d  Züge: %d",
            state.matchedPairs, state.pairs, state.moves),
        gameId     = "ARCADIAPAIRS",
        result     = "LOSS",
        L          = L,
        onRetry    = function() R:_StartNewGameFromResult() end,
        onExit     = function()
            local E = ArcadiaNexus.AP_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:ShowMatchResult(result, state)
    self.state = "GAMEOVER"
    state = state or {}
    local E = ArcadiaNexus.AP_Engine
    local mp = E and E.mode and E.mode ~= "hotseat"
    self:UpdateBoard()
    if self._newGameBtn then self._newGameBtn:Hide() end
    if self._startBtn then
        self._startBtn:SetLabel(ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")["btn_start"])
    end
    if not self._fieldFrame then return end
    local UI = ArcadiaNexus.UI
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
    local title, titleColor, subtitle
    if result == "WIN" then
        title = L["result_mp_win"] or L["result_win_title"] or "|cffffd700Sieg!|r"
        titleColor = {1, 0.84, 0}
        subtitle = string.format(L["result_mp_sub"] or "Paare: %d–%d  Züge: %d",
            state.myScore or 0, state.oppScore or 0, state.moves or 0)
    elseif result == "LOSS" then
        title = L["result_mp_loss"] or "|cffff4444Niederlage!|r"
        titleColor = {1, 0.3, 0.3}
        subtitle = string.format(L["result_mp_sub"] or "Paare: %d–%d  Züge: %d",
            state.myScore or 0, state.oppScore or 0, state.moves or 0)
    else
        title = L["result_mp_draw"] or "Unentschieden!"
        titleColor = {0.8, 0.8, 0.8}
        subtitle = string.format(L["result_mp_sub"] or "Paare: %d–%d  Züge: %d",
            state.myScore or 0, state.oppScore or 0, state.moves or 0)
        result = "DRAW"
    end
    UI.ShowArcadeResult(self._fieldFrame, {
        title = title,
        titleColor = titleColor,
        subtitle = subtitle,
        gameId = "ARCADIAPAIRS",
        difficulty = "easy",
        result = result,
        L = L,
        onRetry = function()
            if mp then
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("ARCADIAPAIRS") end
                return
            end
            R:_StartNewGameFromResult()
        end,
        onExit = function()
            if E then E:StopGame() end
        end,
        buttons = mp and {
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_new_game or L["btn_new_game"],
                onClick = function()
                    local Shell = ArcadiaNexus.MatchShell
                    if Shell and Shell.Rematch then Shell.Rematch("ARCADIAPAIRS") end
                end,
            },
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_exit or L["btn_exit"],
                onClick = function()
                    if E then E:StopGame() end
                end,
            },
        } or nil,
    })
end

-- ============================================================
-- REGISTRIERUNG (Datei-Ebene)
-- ============================================================
-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "ARCADIAPAIRS",
    label     = "Arcadia Pairs",
    category  = "KARTEN",
    renderer  = "AP_Renderer",
    engine    = "AP_Engine",
    container = "_apContainer",
    matchSeats = 2,
    logo      = AP_ASSETS.logo,
    xp        = 10,
})
