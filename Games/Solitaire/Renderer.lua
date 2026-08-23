-- ============================================================
--  Solitaire – Renderer.lua
--  UI-Darstellung: Tisch, Karten, Klick/Doppelklick, Drag & Drop, HUD, Buttons.
--  KEINE Spiellogik hier.
--
--  Blueprint-Koordinaten (relativ zu container, 602×498):
--    Spielfeld:        TOPLEFT +16/-16,  576×416
--    Stock:            TOPLEFT +32/-48,  64×96
--    Waste-3:          TOPLEFT +112/-48  (hinterste)
--    Waste-2:          TOPLEFT +144/-48
--    Waste-1:          TOPLEFT +176/-48  (vorderste, spielbar)
--    Foundation 1-4:   TOPLEFT +272/-48, +352/-48, +432/-48, +512/-48
--    Tableau 1-7:      TOPLEFT +32/-160, +112/-160, ... +512/-160
--    Kontrollzeile:    Y=-392 (Undo, Score, AutoComplete)
--    Controls: CreateGameControlsBar "narrow"
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.SOL_Renderer = {}
local R = ArcadiaNexus.SOL_Renderer

-- ── Registrierung (Datei-Ebene) ───────────────────────────────
ArcadiaNexus.RegisterGame({
    id        = "SOLITAIRE",
    label     = "Solitaire",
    category  = "KARTEN",
    renderer  = "SOL_Renderer",
    engine    = "SOL_Engine",
    container = "_solContainer",
})

-- ── Asset-Pfade ───────────────────────────────────────────────
local ASSET_PATH   = "Interface\\AddOns\\ArcadiaNexus\\Games\\Solitaire\\Assets\\"
local SHARED_PATH  = "Interface\\AddOns\\ArcadiaNexus\\Shared\\"
local SHARED_CARDS = SHARED_PATH .. "Cards\\"

-- Spielfeld-Hintergründe je Theme
local BG_TEXTURES = {
    neutral  = ASSET_PATH .. "background\\background\\neutral",
    alliance = ASSET_PATH .. "background\\background\\alliance",
    horde    = ASSET_PATH .. "background\\background\\horde",
}

-- Kartenrückseiten je Theme
local CARD_BACK_THEMES = {
    neutral  = ASSET_PATH .. "background\\cards_back\\card_back_neutral",
    alliance = ASSET_PATH .. "background\\cards_back\\card_back_alliance",
    horde    = ASSET_PATH .. "background\\cards_back\\card_back_horde",
}

-- Rahmen + Logo
local BORDER_TEXTURE = ASSET_PATH .. "border\\border_solitaire"
local LOGO_TEXTURE   = ASSET_PATH .. "logo\\logo_solitaire"

-- Rank → Asset-Dateiname (J=b, Q=q, K=k, A=a)
local RANK_FILE = {
    ["2"]="2",["3"]="3",["4"]="4",["5"]="5",["6"]="6",
    ["7"]="7",["8"]="8",["9"]="9",["10"]="10",
    ["J"]="b",["Q"]="q",["K"]="k",["A"]="a",
}

-- Foundation-Reihenfolge (C=Kreuz, D=Karo, H=Herz, S=Pik)
local FOUNDATION_KEYS = {"C","D","H","S"}
local FOUNDATION_SUITS = {"kreuz","karo","herz","pik"}

-- ── Layout-Konstanten ─────────────────────────────────────────
local CFG = {
    -- Spielfeld-Frame
    field_w      = 602,   -- Breite des Spielfeld-Frames
    field_h      = 498,   -- Höhe des Spielfeld-Frames
    field_ofs_x  = 0,   -- X-Versatz relativ zum Container (CENTER)
    field_ofs_y  = 0,   -- Y-Versatz relativ zum Container (CENTER)

    -- Hintergrund-Textur
    bg_w         = 730,   -- Breite der Hintergrund-Textur
    bg_h         = 500,   -- Höhe der Hintergrund-Textur
    bg_ofs_x     = 0,   -- X-Versatz (CENTER relativ zu _F.playfield)
    bg_ofs_y     = 10,   -- Y-Versatz (CENTER relativ zu _F.playfield)

    -- Rahmen (FrameLevel +10 über _F.playfield)
    border_w     = 795,   -- Breite des Rahmens
    border_h     = 550,   -- Höhe des Rahmens
    border_ofs_x =   2,   -- X-Versatz (CENTER relativ zu _F.playfield)
    border_ofs_y =   15,   -- Y-Versatz (CENTER relativ zu _F.playfield)

    -- Logo (IDLE-Zustand)
    logo_w       = 448,   -- Breite des Logos
    logo_h       = 436,   -- Höhe des Logos
    logo_ofs_x   =   0,   -- X-Versatz (CENTER relativ zu _F.playfield)
    logo_ofs_y   =   0,   -- Y-Versatz (CENTER relativ zu _F.playfield)

    -- Controls-Widgets
    dd_w         = 120,
    btn_w        = 144,
    btn_h        = 32,

    -- Score- und Zeit-Anzeige
    hud_score_x  =  150,
    hud_score_y  = 0,
    hud_score_w  = 140,
    hud_score_h  = 28,
    hud_score_alpha = 0.75,
    hud_time_x   = 350,
    hud_time_y   = 0,
    hud_time_w   = 140,
    hud_time_h   = 28,
    hud_time_alpha = 0.75,

    -- Karten
    card_w       =  64,
    card_h       =  96,
    tableau_x    = { 32, 112, 192, 272, 352, 432, 512 },
    tableau_y    = -160,
    stock_x      =  32,   stock_y      = -48,
    waste_x_base = 176,   waste_y      = -48,
    waste_offset =  -32,
    fnd_x        = { 272, 352, 432, 512 },
    fnd_y        =  -48,
    ovr_down     =  10,   -- Overlap verdeckte Karten (Normalfall)
    ovr_up       =  15,   -- Overlap aufgedeckte Karten (Normalfall)
    ovr_min_down =   8,   -- Overlap verdeckte Karten (Minimum)
    ovr_min_up   =  14,   -- Overlap aufgedeckte Karten (Minimum)
    ovr_max_h    = 272,   -- Max. Stapelhöhe

    -- Resume-Overlay (zentriert über _F.playfield)
    resume_w     = 350,   -- Breite des Overlays
    resume_h     = 100,   -- Höhe des Overlays
    resume_ofs_x =   0,   -- X-Versatz (CENTER relativ zu _F.playfield)
    resume_ofs_y =   0,   -- Y-Versatz (CENTER relativ zu _F.playfield)
}

-- ── Farben ────────────────────────────────────────────────────
local COL = {
    gold      = {1.0, 0.82, 0.0},
    highlight = {0.3, 0.9, 0.3},
    empty     = {0.2, 0.2, 0.2, 0.6},
    cardBg    = {1, 1, 1, 1},
}

-- ── Frames (werden in Init erstellt) ─────────────────────────
local _F = {
    container    = nil,
    canvas       = nil,
    playfield    = nil,   -- Sub-Frame, Ankerpunkt für alle Spielelemente
    bgTex        = nil,
    borderFrame  = nil,   -- Rahmen-Frame (FrameLevel +10 über playfield)
    borderTex    = nil,
    logoTex      = nil,   -- Logo (sichtbar im IDLE-Zustand)
    stockFrame   = nil,
    wasteFrames  = {},    -- [1]=vorderste (spielbar), [2], [3]=hinterste
    fndFrames    = {},    -- [1..4]
    tabFrames    = {},    -- [1..7] = { frames[] }
    tabSlots     = {},    -- [1..7] permanente Slot-Frames für leere Spalten
    hudScore     = nil,
    hudTime      = nil,
    hudScoreLbl  = nil,   -- "Punkte"-Label
    hudTimeLbl   = nil,   -- "Zeit"-Label
    hudUndoBtn   = nil,
    hudUndoLbl   = nil,
    autocmpBtn   = nil,
    toggleBtn    = nil,   -- Toggle: "Spiel starten" ↔ "Beenden"
    controlsFrame = nil,
    resumeOverlay = nil,
    dragGhost    = nil,
    dragWatcher  = nil,
    ghostCards   = {},
}
-- Doppelklick über Zeitfenster, weil Refresh die Kartenframes neu baut
-- und Frame-OnDoubleClick nach dem ersten Klick nicht mehr greift.
local DBL_CLICK_SEC  = 0.35
local DRAG_THRESHOLD = 8
local MAX_GHOST      = 13
local _lastPointer   = nil  -- { t, zone, index, cardIndex }
local _dragPending   = nil  -- { zone, index, cardIndex, cards, startX, startY, dimFrames }
local _dragActive    = nil  -- { zone, index, cardIndex, cards, dimFrames }
local _justDropped   = 0

-- ── Hilfsfunktionen ───────────────────────────────────────────
local function GetEngine()   return ArcadiaNexus.SOL_Engine   end
local function GetLogic()    return ArcadiaNexus.SOL_Logic    end
local function GetSettings() return ArcadiaNexus.SOL_Settings end
local function GetLocale()
    return ArcadiaNexus.GetLocaleTable and
           ArcadiaNexus.GetLocaleTable("SOLITAIRE") or {}
end

function R:GetCardBack()
    local S = GetSettings()
    local theme = S and S:Get("theme") or "neutral"
    return CARD_BACK_THEMES[theme] or CARD_BACK_THEMES.neutral
end

function R:GetBgTexture()
    local S = GetSettings()
    local theme = S and S:Get("theme") or "neutral"
    return BG_TEXTURES[theme] or BG_TEXTURES.neutral
end

function R:GetCardTexture(card)
    local rankFile = RANK_FILE[card.rank] or card.rank:lower()
    return SHARED_CARDS .. card.suit .. "\\" .. card.suit .. "_" .. rankFile
end

function R:_HandleCardClick(zone, index, cardIndex)
    if _dragActive then return end
    if _justDropped > 0 and (GetTime() - _justDropped) < 0.08 then return end
    local E = GetEngine()
    if not E or E.state ~= "PLAYING" then return end
    local now = GetTime()
    if _lastPointer
        and (now - _lastPointer.t) <= DBL_CLICK_SEC
        and _lastPointer.zone == zone
        and _lastPointer.index == index
        and _lastPointer.cardIndex == cardIndex
    then
        _lastPointer = nil
        E:OnCardDoubleClick(zone, index, cardIndex)
        return
    end
    _lastPointer = { t = now, zone = zone, index = index, cardIndex = cardIndex }
    E:OnCardClick(zone, index, cardIndex)
end

function R:_DimFrames(frames, alpha)
    if not frames then return end
    for _, f in ipairs(frames) do
        if f then
            f:SetAlpha(alpha)
            if f._tex then f._tex:SetAlpha(alpha) end
            if f._cardTex then f._cardTex:SetAlpha(alpha) end
        end
    end
end

function R:_SourceDimFrames(zone, index, cardIndex)
    local frames = {}
    if zone == "tableau" then
        local col = _F.tabFrames[index]
        if col then
            local startIdx = cardIndex or 1
            for i = startIdx, #col do
                frames[#frames+1] = col[i]
            end
        end
    elseif zone == "waste" then
        frames[1] = _F.wasteFrames[1]
    elseif zone == "foundation" then
        frames[1] = _F.fndFrames[index]
    end
    return frames
end

function R:_PositionGhost()
    local ghost  = _F.dragGhost
    local parent = ghost and ghost:GetParent()
    if not ghost or not parent then return end
    local left, bottom = parent:GetLeft(), parent:GetBottom()
    if not left or not bottom then return end
    local cx, cy = GetCursorPosition()
    local scale  = parent:GetEffectiveScale()
    if not scale or scale == 0 then return end
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", parent, "BOTTOMLEFT", cx / scale - left, cy / scale - bottom)
end

function R:_ShowGhost(cards)
    if not _F.dragGhost then return end
    local n = math.min(#cards, MAX_GHOST)
    local h = CFG.card_h + math.max(0, n - 1) * CFG.ovr_up
    _F.dragGhost:SetSize(CFG.card_w, h)
    for i = 1, MAX_GHOST do
        local gf = _F.ghostCards[i]
        if i <= n then
            local card = cards[i]
            gf:ClearAllPoints()
            gf:SetPoint("TOPLEFT", _F.dragGhost, "TOPLEFT", 0, -((i - 1) * CFG.ovr_up))
            gf:SetFrameLevel((_F.dragGhost:GetFrameLevel() or 1) + i)
            if card.faceUp then
                gf._tex:SetTexture(R:GetCardTexture(card))
            else
                gf._tex:SetTexture(R:GetCardBack())
            end
            gf:Show()
        else
            gf:Hide()
        end
    end
    R:_PositionGhost()
    _F.dragGhost:Show()
end

function R:_HideGhost()
    if _F.dragGhost then _F.dragGhost:Hide() end
    for i = 1, MAX_GHOST do
        if _F.ghostCards[i] then _F.ghostCards[i]:Hide() end
    end
end

function R:_CursorOnFrame(frame)
    return frame and frame:IsVisible() and frame:IsMouseOver()
end

function R:_GetDropTarget()
    for i, ff in ipairs(_F.fndFrames) do
        if R:_CursorOnFrame(ff) then
            return { zone = "foundation", index = i }
        end
    end
    for i = 1, 7 do
        local col = _F.tabFrames[i]
        local hit = false
        if col then
            for _, cardFrame in ipairs(col) do
                if R:_CursorOnFrame(cardFrame) then
                    hit = true
                    break
                end
            end
        end
        if not hit then
            local ts = _F.tabSlots[i]
            if ts and ts:IsVisible() and ts:IsMouseOver() then
                hit = true
            end
        end
        if hit then
            return { zone = "tableau", index = i }
        end
    end
    return nil
end

function R:EndDrag()
    if _dragActive and _dragActive.dimFrames then
        R:_DimFrames(_dragActive.dimFrames, 1)
    end
    if _dragPending and _dragPending.dimFrames then
        R:_DimFrames(_dragPending.dimFrames, 1)
    end
    _dragActive  = nil
    _dragPending = nil
    R:_HideGhost()
    if _F.dragWatcher then _F.dragWatcher:Hide() end
end

function R:_ActivateDrag()
    if not _dragPending then return end
    _dragActive = {
        zone      = _dragPending.zone,
        index     = _dragPending.index,
        cardIndex = _dragPending.cardIndex,
        cards     = _dragPending.cards,
        dimFrames = _dragPending.dimFrames,
    }
    _dragPending = nil
    _lastPointer = nil
    R:_DimFrames(_dragActive.dimFrames, 0.35)
    R:_ShowGhost(_dragActive.cards)
end

function R:_StartPointer(zone, index, cardIndex)
    local E = GetEngine()
    if not E or E.state ~= "PLAYING" or not E.gameState then return end
    local L = GetLogic()
    if not L or not L:IsSelectable(E.gameState, zone, index, cardIndex) then return end
    local cards, startIdx = L:GetSelectedCards(E.gameState, zone, index, cardIndex)
    if not cards or #cards == 0 then return end
    local cx, cy = GetCursorPosition()
    _dragPending = {
        zone      = zone,
        index     = index,
        cardIndex = cardIndex or startIdx,
        cards     = cards,
        startX    = cx,
        startY    = cy,
        dimFrames = R:_SourceDimFrames(zone, index, cardIndex or startIdx),
    }
    if _F.dragWatcher then _F.dragWatcher:Show() end
end

function R:_EndPointer(zone, index, cardIndex)
    if _dragActive then return end
    _dragPending = nil
    if _F.dragWatcher then _F.dragWatcher:Hide() end
    R:_HandleCardClick(zone, index, cardIndex)
end

-- ── Init ──────────────────────────────────────────────────────
function R:Init()
    if _F.container then return end

    -- Container selbst erstellen (Blackjack-Pattern)
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_SOL_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    _F.container = f
    _F.canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._solContainer = f end

    local L = GetLocale()

    -- Spielfeld-Sub-Frame: Ankerpunkt für alle Blueprint-Koordinaten
    _F.playfield = CreateFrame("Frame", nil, _F.canvas)
    _F.playfield:SetSize(CFG.field_w, CFG.field_h)
    _F.playfield:SetPoint("CENTER", _F.canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    _F.playfield:SetFrameLevel((_F.container:GetFrameLevel() or 1) + 2)

    -- Hintergrund-Textur an _F.playfield (feste Größe → Konstanten wirken zuverlässig)
    _F.bgTex = _F.playfield:CreateTexture(nil, "BACKGROUND", nil, -1)
    _F.bgTex:SetSize(CFG.bg_w, CFG.bg_h)
    _F.bgTex:SetPoint("CENTER", _F.playfield, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    _F.bgTex:SetTexture(R:GetBgTexture())

    -- Rahmen (FrameLevel +10 über _F.playfield, immer sichtbar)
    _F.borderFrame = CreateFrame("Frame", nil, _F.playfield)
    _F.borderFrame:SetSize(CFG.border_w, CFG.border_h)
    _F.borderFrame:SetPoint("CENTER", _F.playfield, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    _F.borderFrame:SetFrameLevel(_F.playfield:GetFrameLevel() + 10)
    _F.borderTex = _F.borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    _F.borderTex:SetTexture(BORDER_TEXTURE)
    _F.borderTex:SetAllPoints(_F.borderFrame)

    -- Logo (via UI.CreateGameLogo, FrameLevel +10, nur im IDLE-Zustand sichtbar)
    local UI = ArcadiaNexus.UI
    _F.logoTex = UI.CreateGameLogo(
        _F.playfield,
        LOGO_TEXTURE,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )

    -- ── Stock ─────────────────────────────────────────────────
    _F.stockFrame = self:_CreateCardSlot(_F.playfield, CFG.stock_x, CFG.stock_y, "stock")
    _F.stockFrame:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 1)
    _F.stockFrame:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            local E = GetEngine()
            if E then E:OnStockClick() end
        end
    end)
    _F.stockFrame:EnableMouse(true)

    -- ── Waste (3 Slots: Sichtbar im 3-Karten-Modus) ───────────
    for i = 1, 3 do
        -- i=1 vorderste, i=3 hinterste
        local xOff = CFG.waste_x_base + (i-1) * CFG.waste_offset
        local wf = self:_CreateCardSlot(_F.playfield, xOff, CFG.waste_y, "waste_"..i)
        wf:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 1)
        _F.wasteFrames[i] = wf
        wf:EnableMouse(true)
        wf:SetScript("OnMouseUp", nil)
    end

    -- ── Foundation (4 Slots) ──────────────────────────────────
    for i = 1, 4 do
        local ff = self:_CreateCardSlot(_F.playfield, CFG.fnd_x[i], CFG.fnd_y, "foundation_"..i)
        ff:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 1)
        _F.fndFrames[i] = ff
        ff:EnableMouse(true)
        local fi = i
        ff:SetScript("OnMouseDown", function(_, btn)
            if btn ~= "LeftButton" then return end
            R:_StartPointer("foundation", fi, nil)
        end)
        ff:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "LeftButton" then return end
            R:_EndPointer("foundation", fi, nil)
        end)
        ff._emptyLbl = nil
    end

    -- ── Tableau (7 Spalten, dynamische Karten) ─────────────────
    for i = 1, 7 do
        _F.tabFrames[i] = {}
        -- Permanenter Slot-Frame als Klick-Ziel für leere Spalten
        local ts = CreateFrame("Frame", nil, _F.playfield)
        ts:SetSize(CFG.card_w, CFG.card_h)
        ts:SetPoint("TOPLEFT", _F.playfield, "TOPLEFT", CFG.tableau_x[i], CFG.tableau_y)
        ts:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 1)
        ts:EnableMouse(true)
        local col = i
        ts:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "LeftButton" then return end
            R:_EndPointer("tableau", col, nil)
        end)
        _F.tabSlots[i] = ts
    end

    -- ── Controls-Leiste am Content-Footer ─────────────────────
    local bar = UI.CreateGameControlsBar(_F.container, "narrow")
    local cf = bar.frame
    _F.controlsFrame = cf

    -- Score-HUD und Zeit-HUD (Canvas, Blackjack-Kapital-Look)
    local hudParent = _F.canvas or _F.playfield
    _F.hudScoreBox, _F.hudScore = UI.CreateHudStatBox(hudParent, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "TOPLEFT", relativeTo = _F.playfield, relativePoint = "TOPLEFT",
        x = CFG.hud_score_x, y = CFG.hud_score_y,
        alpha = CFG.hud_score_alpha,
        text = (L["lbl_score"] or "Punkte") .. ": 0",
        shown = false,
    })
    _F.hudTimeBox, _F.hudTime = UI.CreateHudStatBox(hudParent, {
        w = CFG.hud_time_w, h = CFG.hud_time_h,
        point = "TOPLEFT", relativeTo = _F.playfield, relativePoint = "TOPLEFT",
        x = CFG.hud_time_x, y = CFG.hud_time_y,
        alpha = CFG.hud_time_alpha,
        text = (L["lbl_time"] or "Zeit") .. ": 00:00",
        shown = false,
    })
    _F.hudScoreLbl, _F.hudTimeLbl = nil, nil

    -- Auto-Complete-Button (unveraendert)
    _F.autocmpBtn = UI.CreateArcadiaButton(_F.playfield, L["btn_auto_complete"] or "Auto-Complete", 144, 32)
    _F.autocmpBtn:SetPoint("TOPLEFT", _F.playfield, "TOPLEFT", 144, -392)
    _F.autocmpBtn:SetScript("OnClick", function()
        local E = GetEngine()
        if E then E:OnAutoComplete() end
    end)
    _F.autocmpBtn:Hide()

    -- Segment 1: Dropdown (Modus)
    local modeOpts = {
        { key="1card", label=L["mode_1card"] or "1 Karte"  },
        { key="3card", label=L["mode_3card"] or "3 Karten" },
    }
    local ddAnchor = CreateFrame("Frame", nil, cf)
    ddAnchor:SetSize(120, 32)
    ddAnchor:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, 120,
        "",
        modeOpts,
        function() local S2 = GetSettings() return S2 and S2:Get("mode") or "1card" end,
        function(key)
            local S2 = GetSettings()
            if S2 then S2:Set("mode", key) end
        end
    )

    -- Segment 2 (x=0): Start (IDLE) / Beenden (Menü + Spiel)
    _F.toggleBtn = UI.CreateArcadiaButton(cf, L["btn_start"] or "Spiel starten", 144, 32)
    _F.toggleBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    _F.toggleBtn:SetScript("OnClick", function()
        R:EnterSlotMenu()
    end)

    _F.exitBtn = UI.CreateArcadiaButton(cf, L["btn_exit"] or "Beenden", 144, 32)
    _F.exitBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    _F.exitBtn:SetScript("OnClick", function()
        if R._uiState == "MENU" then
            R:SetState("IDLE")
            return
        end
        local E = GetEngine()
        if not E then return end
        if E.state == "PLAYING" then
            E:SaveAndPause()
            R:SetState("IDLE")
        else
            E:StopGame()
            R:SetState("IDLE")
        end
    end)
    _F.exitBtn:Hide()

    -- Segment 3 (x=+170): Undo-Button
    _F.hudUndoBtn = UI.CreateArcadiaButton(cf, (L["btn_undo"] or "Rückgängig") .. " (3)", 144, 32)
    _F.hudUndoBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    _F.hudUndoLbl = _F.hudUndoBtn.text
    _F.hudUndoBtn:SetScript("OnClick", function()
        local E = GetEngine()
        if E then E:OnUndo() end
    end)

    -- Ghost-Stapel: Kind vom Playfield, damit er über den Karten und
    -- nicht hinter dem Hub-DIALOG (FrameLevel 100) liegt.
    _F.dragGhost = CreateFrame("Frame", nil, _F.playfield)
    _F.dragGhost:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 80)
    _F.dragGhost:SetSize(CFG.card_w, CFG.card_h)
    _F.dragGhost:EnableMouse(false)
    _F.dragGhost:SetAlpha(0.95)
    _F.dragGhost:Hide()
    for i = 1, MAX_GHOST do
        local gf = CreateFrame("Frame", nil, _F.dragGhost, "BackdropTemplate")
        gf:SetSize(CFG.card_w, CFG.card_h)
        gf:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        gf:SetBackdropColor(1, 1, 1, 1)
        gf:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.9)
        gf:EnableMouse(false)
        gf._tex = gf:CreateTexture(nil, "ARTWORK")
        gf._tex:SetPoint("TOPLEFT", gf, "TOPLEFT", 2, -2)
        gf._tex:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -2, 2)
        gf:Hide()
        _F.ghostCards[i] = gf
    end

    _F.dragWatcher = CreateFrame("Frame", nil, UIParent)
    _F.dragWatcher:Hide()
    _F.dragWatcher:SetScript("OnUpdate", function()
        if _dragPending then
            if not IsMouseButtonDown("LeftButton") then
                -- Klick: MouseUp auf der Karte wertet aus, Pending nicht hier löschen
                _F.dragWatcher:Hide()
                return
            end
            local cx, cy = GetCursorPosition()
            if math.abs(cx - _dragPending.startX) > DRAG_THRESHOLD
                or math.abs(cy - _dragPending.startY) > DRAG_THRESHOLD
            then
                R:_ActivateDrag()
            end
            return
        end

        if _dragActive then
            R:_PositionGhost()
            if not IsMouseButtonDown("LeftButton") then
                local src = {
                    zone      = _dragActive.zone,
                    index     = _dragActive.index,
                    cardIndex = _dragActive.cardIndex,
                }
                local target = R:_GetDropTarget()
                _justDropped = GetTime()
                R:EndDrag()
                local E = GetEngine()
                if E then E:OnDragDrop(src, target) end
            end
            return
        end

        _F.dragWatcher:Hide()
    end)

    -- ── Save-Slot-Menü ─────────────────────────────────────────
    R:_CreateSlotMenu()

    -- OnHide-Handler: SaveAndPause
    _F.container:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("SOLITAIRE", GetEngine(), function(E)
            if E.state == "PLAYING" then
                E:SaveAndPause()
            end
        end)
        if R._uiState == "MENU" then
            R:SetState("IDLE")
        end
        _lastPointer = nil
        R:EndDrag()
    end)

    -- OnShow: IDLE (Slots erst nach „Spiel starten“)
    _F.container:SetScript("OnShow", function()
        local E = GetEngine()
        if not E or E.state ~= "PLAYING" then
            R:SetState("IDLE")
        end
    end)
end

function R:_CreateSlotMenu()
    local UI = ArcadiaNexus.UI
    local L  = GetLocale()
    local S  = GetSettings()
    if not UI or not UI.CreateSaveSlotMenu or not _F.playfield then return end

    _F.slotMenu = UI.CreateSaveSlotMenu({
        parent        = _F.playfield,
        confirmParent = _F.playfield,
        maxSlots      = (S and S.MAX_SLOTS) or 3,
        L             = L,
        title         = L and L.menu_title,
        loadSlot      = function(slot) return S and S:LoadSlot(slot) end,
        deleteSlot    = function(slot) if S then S:DeleteSlot(slot) end end,
        formatInfo    = function(save, loc)
            local modeLabel = loc["mode_" .. (save.mode or "1card")] or save.mode or ""
            local score = (ArcadiaNexus.Format and ArcadiaNexus.Format.Score(save.score or 0))
                or tostring(save.score or 0)
            return string.format(loc.slot_info or "%s · %s", modeLabel, score)
        end,
        isPaused      = function(save) return save.midGame ~= nil end,
        onNewGame     = function(slot)
            local E = GetEngine()
            local S2 = GetSettings()
            if E then
                E:StartGame({ slot = slot, mode = "new", cardMode = S2 and S2:Get("mode") })
            end
        end,
        onContinue    = function(slot)
            local E = GetEngine()
            if E then E:StartGame({ slot = slot, mode = "continue" }) end
        end,
    })
end

function R:EnterSlotMenu()
    R._uiState = "MENU"
    if _F.canvas and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(_F.canvas)
    end
    if _F.logoTex   then _F.logoTex:Hide()   end
    if _F.toggleBtn then _F.toggleBtn:Hide() end
    if _F.exitBtn   then _F.exitBtn:Show()   end
    if _F.slotMenu  then _F.slotMenu:Show()  end
end

-- ── Karten-Slot erstellen (leerer Platzhalter-Frame) ─────────
function R:_CreateCardSlot(parent, x, y, tag)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(CFG.card_w, CFG.card_h)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = {left=1,right=1,top=1,bottom=1},
    })
    f:SetBackdropColor(COL.empty[1], COL.empty[2], COL.empty[3], COL.empty[4])
    f:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.8)
    f._tag = tag
    return f
end

-- ── Karten-Frame erstellen ────────────────────────────────────
function R:_CreateCardFrame(parent, card, x, y, zone, idx, cardIdx)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(CFG.card_w, CFG.card_h)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets   = {left=2,right=2,top=2,bottom=2},
    })
    f:SetBackdropColor(1, 1, 1, 1)
    f:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.9)
    f:EnableMouse(true)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",  f, "TOPLEFT",  2,  -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    f._tex = tex

    -- Textur setzen
    if card.faceUp then
        tex:SetTexture(R:GetCardTexture(card))
    else
        tex:SetTexture(R:GetCardBack())
    end

    -- Metadaten für Event-Handler
    f._card    = card
    f._zone    = zone
    f._idx     = idx
    f._cardIdx = cardIdx

    f:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        R:_StartPointer(self._zone, self._idx, self._cardIdx)
    end)
    f:SetScript("OnMouseUp", function(self, btn)
        if btn ~= "LeftButton" then return end
        R:_EndPointer(self._zone, self._idx, self._cardIdx)
    end)

    f:SetScript("OnEnter", function(self)
        if self._zone ~= "stock" and not (self._card and self._card.faceUp) then return end
        f:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1.0)
    end)
    f:SetScript("OnLeave", function(self)
        f:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.9)
    end)

    return f
end

-- ── Tableau-Karten zeichnen ───────────────────────────────────
function R:_RebuildTableau(gs)
    -- Alle alten Tableau-Frames recyclen
    for i = 1, 7 do
        for _, f in ipairs(_F.tabFrames[i]) do
            f:Hide()
        end
        _F.tabFrames[i] = {}
    end

    for col = 1, 7 do
        local cards = gs.tableau[col]
        local xBase = CFG.tableau_x[col]
        local yOff  = CFG.tableau_y

        -- Dynamischer Overlap: benötigte Höhe berechnen
        local nDown, nUp = 0, 0
        for _, card in ipairs(cards) do
            if card.faceUp then nUp = nUp + 1 else nDown = nDown + 1 end
        end
        local needed = nDown * CFG.ovr_down + nUp * CFG.ovr_up
        local ovDown = CFG.ovr_down
        local ovUp   = CFG.ovr_up
        if needed > CFG.ovr_max_h and (nDown + nUp) > 1 then
            -- Overlap proportional stauchen bis CFG.ovr_max_h passt
            local ratio  = CFG.ovr_max_h / needed
            ovDown = math.max(CFG.ovr_min_down, math.floor(CFG.ovr_down * ratio))
            ovUp   = math.max(CFG.ovr_min_up,   math.floor(CFG.ovr_up   * ratio))
        end

        for row = 1, #cards do
            local card    = cards[row]
            local yPos    = yOff
            local f = self:_CreateCardFrame(_F.playfield, card, xBase, yPos, "tableau", col, row)

            -- FrameLevel relativ zum Parent (Blackjack-Pattern)
            f:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + 2 + row)

            _F.tabFrames[col][row] = f

            -- Nächster Versatz (gestauchter oder normaler Wert)
            if card.faceUp then
                yOff = yOff - ovUp
            else
                yOff = yOff - ovDown
            end
        end

        -- Selektion-Highlight
        if gs.selected and gs.selected.zone == "tableau" and gs.selected.index == col then
            local selIdx = gs.selected.cardIndex or #cards
            for row = selIdx, #cards do
                local f = _F.tabFrames[col][row]
                if f then
                    f:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1.0)
                end
            end
        end
    end
end

-- ── Stock zeichnen ────────────────────────────────────────────
function R:_UpdateStock(gs)
    -- Textur einmalig erstellen
    if not _F.stockFrame._tex then
        _F.stockFrame._tex = _F.stockFrame:CreateTexture(nil, "ARTWORK")
        _F.stockFrame._tex:SetAllPoints(_F.stockFrame)
    end
    if #gs.stock > 0 then
        _F.stockFrame._tex:SetTexture(R:GetCardBack())
        _F.stockFrame._tex:Show()
        _F.stockFrame:SetBackdropColor(1, 1, 1, 1)
    else
        -- Stock leer: Pfeil-Symbol anzeigen
        if _F.stockFrame._tex then _F.stockFrame._tex:SetTexture(nil) end
        _F.stockFrame:SetBackdropColor(COL.empty[1], COL.empty[2], COL.empty[3], COL.empty[4])
        if not _F.stockFrame._emptyLbl then
            local lbl = _F.stockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("CENTER", _F.stockFrame, "CENTER", 0, 0)
            lbl:SetText("NEU")
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            lbl:SetTextColor(0.6, 0.6, 0.6, 0.8)
            _F.stockFrame._emptyLbl = lbl
        end
        _F.stockFrame._emptyLbl:Show()
    end
    if _F.stockFrame._emptyLbl then
        _F.stockFrame._emptyLbl:SetShown(#gs.stock == 0)
    end
end

-- ── Waste zeichnen ────────────────────────────────────────────
function R:_UpdateWaste(gs)
    local waste = gs.waste
    local n     = #waste

    for i = 1, 3 do
        _F.wasteFrames[i]:Hide()
    end

    if n == 0 then return end

    -- Im 1-Karten-Modus: nur 1 Karte sichtbar
    -- Im 3-Karten-Modus: bis zu 3 Karten gestaffelt
    local showCount = gs.mode == "1card" and 1 or math.min(3, n)

    for slot = 1, showCount do
        -- slot=1 = hinterste Karte (älteste), slot=showCount = vorderste (spielbar, neueste)
        -- _F.wasteFrames[1]=X176(vorne/rechts), _F.wasteFrames[3]=X112(hinten/links)
        -- Invertierung: vorderste Karte (slot=showCount) → _F.wasteFrames[1] (X=176)
        local cardIdx = n - (showCount - slot)
        if cardIdx >= 1 and cardIdx <= n then
            local card = waste[cardIdx]
            local wf   = _F.wasteFrames[showCount - slot + 1]
            -- FrameLevel: vorderste Karte (slot=showCount) liegt oben
            wf:SetFrameLevel((_F.playfield:GetFrameLevel() or 1) + slot + 1)
            wf:Show()

            if not wf._tex then
                wf._tex = wf:CreateTexture(nil, "ARTWORK")
                wf._tex:SetAllPoints(wf)
            end
            wf._tex:SetTexture(R:GetCardTexture(card))
            wf:SetBackdropColor(1, 1, 1, 1)

            -- Nur vorderste Karte ist klickbar/selektierbar
            if slot == showCount then
                wf:EnableMouse(true)
                -- Highlight wenn selektiert
                if gs.selected and gs.selected.zone == "waste" then
                    wf:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1.0)
                else
                    wf:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.9)
                end
                wf:SetScript("OnMouseDown", function(_, btn)
                    if btn ~= "LeftButton" then return end
                    R:_StartPointer("waste", n, n)
                end)
                wf:SetScript("OnMouseUp", function(_, btn)
                    if btn ~= "LeftButton" then return end
                    R:_EndPointer("waste", n, n)
                end)
            else
                wf:EnableMouse(false)
                wf:SetBackdropBorderColor(0.25, 0.23, 0.18, 0.7)
            end
        end
    end
end

-- ── Foundation zeichnen ───────────────────────────────────────
function R:_UpdateFoundation(gs)
    for i, fKey in ipairs(FOUNDATION_KEYS) do
        local fnd = gs.foundation[fKey]
        local ff  = _F.fndFrames[i]
        if not ff then break end

        if #fnd == 0 then
            ff:SetBackdropColor(COL.empty[1], COL.empty[2], COL.empty[3], COL.empty[4])
            if ff._cardTex then ff._cardTex:Hide() end
            if ff._emptyLbl then ff._emptyLbl:Show() end
        else
            ff:SetBackdropColor(1, 1, 1, 1)
            if ff._emptyLbl then ff._emptyLbl:Hide() end
            local top = fnd[#fnd]
            if not ff._cardTex then
                ff._cardTex = ff:CreateTexture(nil, "ARTWORK")
                ff._cardTex:SetPoint("TOPLEFT",     ff, "TOPLEFT",     2,  -2)
                ff._cardTex:SetPoint("BOTTOMRIGHT",  ff, "BOTTOMRIGHT", -2,  2)
            end
            ff._cardTex:SetTexture(R:GetCardTexture(top))
            ff._cardTex:Show()
        end

        ff:SetBackdropBorderColor(0.35, 0.33, 0.25, 0.8)

        -- Selektion
        if gs.selected and gs.selected.zone == "foundation" and gs.selected.index == i then
            ff:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1.0)
        end
    end
end

-- ── Haupt-Refresh ─────────────────────────────────────────────
function R:Refresh(gs)
    if not gs then return end
    R:_UpdateStock(gs)
    R:_UpdateWaste(gs)
    R:_UpdateFoundation(gs)
    R:_RebuildTableau(gs)
    R:_UpdateUndoButton(gs)
end

-- ── HUD-Update ────────────────────────────────────────────────
function R:UpdateHUD(gs)
    if not gs then return end
    local L = GetLocale()
    if _F.hudScore then
        _F.hudScore:SetText((L["lbl_score"] or "Punkte") .. ": " .. tostring(gs.score))
    end
    if _F.hudTime then
        _F.hudTime:SetText((L["lbl_time"] or "Zeit") .. ": " .. ArcadiaNexus.Format.SecondsMMSS(gs.elapsed))
    end
    R:_UpdateUndoButton(gs)
end

function R:_UpdateUndoButton(gs)
    if not _F.hudUndoBtn or not gs then return end
    local undosLeft = 3 - #gs.undoStack
    local L = GetLocale()
    if _F.hudUndoLbl then
        _F.hudUndoLbl:SetText(
            (L["btn_undo"] or "Rückgängig") ..
            " (" .. undosLeft .. " " .. (L["lbl_undo_left"] or "übrig") .. ")"
        )
    end
    local canUndo = #gs.undoStack > 0
    if canUndo then
        _F.hudUndoBtn:Enable()
    else
        _F.hudUndoBtn:Disable()
    end
end

-- ── Auto-Complete Button ein/ausblenden ───────────────────────
function R:SetAutoCompleteVisible(visible)
    if _F.autocmpBtn then
        _F.autocmpBtn:SetShown(visible)
    end
end

-- ── State-Anzeige ─────────────────────────────────────────────
function R:ClearBoard()
    -- Tableau-Karten verstecken
    for i = 1, 7 do
        for _, f in ipairs(_F.tabFrames[i]) do f:Hide() end
        _F.tabFrames[i] = {}
    end
    -- Tableau-Slots verstecken
    for i = 1, 7 do
        if _F.tabSlots[i] then _F.tabSlots[i]:Hide() end
    end
    -- Waste verstecken
    for i = 1, 3 do
        if _F.wasteFrames[i] then _F.wasteFrames[i]:Hide() end
    end
    -- Stock verstecken
    if _F.stockFrame then
        _F.stockFrame:Hide()
        if _F.stockFrame._tex then _F.stockFrame._tex:SetTexture(nil) end
        if _F.stockFrame._emptyLbl then _F.stockFrame._emptyLbl:Hide() end
    end
    -- Foundation verstecken
    for i = 1, 4 do
        local ff = _F.fndFrames[i]
        if ff then
            ff:Hide()
            if ff._cardTex then ff._cardTex:Hide() end
        end
    end
    -- HUD verstecken
    if _F.hudScoreBox then _F.hudScoreBox:Hide() end
    if _F.hudTimeBox  then _F.hudTimeBox:Hide()  end
    if _F.hudUndoBtn  then _F.hudUndoBtn:Hide()  end
    if _F.autocmpBtn  then _F.autocmpBtn:Hide()  end
end

function R:SetState(state)
    local L = GetLocale()
    _lastPointer = nil
    R:EndDrag()
    if state == "IDLE" or state == "WIN" or state == "GAMEOVER" then
        R._uiState = "IDLE"
        if state == "IDLE" then
            R:ClearBoard()
        end
        if _F.toggleBtn  then _F.toggleBtn:SetLabel(L["btn_start"] or "Spiel starten"); _F.toggleBtn:Show() end
        if _F.exitBtn    then _F.exitBtn:Hide() end
        if _F.logoTex    then _F.logoTex:Show()  end
        if _F.slotMenu   then _F.slotMenu:Hide() end
        if _F.canvas and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(_F.canvas)
        end
        if _F.resumeOverlay then _F.resumeOverlay:Hide() end
    elseif state == "PLAYING" then
        R._uiState = "PLAYING"
        if _F.toggleBtn  then _F.toggleBtn:Hide() end
        if _F.exitBtn    then _F.exitBtn:Show()  end
        if _F.logoTex    then _F.logoTex:Hide()  end
        if _F.slotMenu   then _F.slotMenu:Hide() end
        -- Slots einblenden
        if _F.stockFrame then _F.stockFrame:Show() end
        for i = 1, 4 do if _F.fndFrames[i]  then _F.fndFrames[i]:Show()  end end
        for i = 1, 7 do if _F.tabSlots[i]   then _F.tabSlots[i]:Show()   end end
        -- HUD einblenden und zurücksetzen
        local Lhud = L
        if _F.hudScoreBox then _F.hudScoreBox:Show() end
        if _F.hudTimeBox  then _F.hudTimeBox:Show()  end
        if _F.hudScore then _F.hudScore:SetText((Lhud["lbl_score"] or "Punkte") .. ": 0") end
        if _F.hudTime  then _F.hudTime:SetText((Lhud["lbl_time"] or "Zeit") .. ": 00:00") end
        if _F.hudUndoBtn  then _F.hudUndoBtn:Show()  ; _F.hudUndoBtn:Disable()      end
        if _F.hudUndoLbl  then _F.hudUndoLbl:SetText("Rückgängig (3 übrig)")        end
        if _F.canvas and ArcadiaNexus.UI then
            ArcadiaNexus.UI.HideResultDialog(_F.canvas)
        end
        if _F.resumeOverlay then _F.resumeOverlay:Hide() end
    end
end

-- ── Theme-Wechsel: Hintergrund + Kartenrücken aktualisieren ──
function R:RefreshBackground()
    if _F.bgTex then
        _F.bgTex:SetTexture(R:GetBgTexture())
    end
end

function R:ShowResult(result, score)
    if not _F.canvas then return end
    local L      = GetLocale()
    local UI     = ArcadiaNexus.UI
    local parent = _F.canvas
    local won    = result == "WIN"

    UI.ShowArcadeResult(parent, {
        title      = won and (L["state_win"] or "Gewonnen!") or (L["state_gameover"] or "Keine Züge mehr!"),
        titleColor = won and {1.0, 0.82, 0.0} or {0.9, 0.3, 0.3},
        score      = score,
        scoreLabel = L["lbl_score"] or "Punkte",
        gameId     = "SOLITAIRE",
        result     = won and "WIN" or "LOSS",
        L          = L,
        onRetry    = function()
            local E = GetEngine()
            local S = GetSettings()
            if E and S then E:StartGame({ mode = "new", cardMode = S:Get("mode") }) end
        end,
        onExit     = function()
            local E = GetEngine()
            if E then E:StopGame() end
            R:SetState("IDLE")
        end,
    })
end
