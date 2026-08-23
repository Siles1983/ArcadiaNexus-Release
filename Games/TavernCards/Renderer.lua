-- ============================================================
--  Tavern Cards – Renderer.lua
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.TC_Renderer = {}
local R = ArcadiaNexus.TC_Renderer

ArcadiaNexus.RegisterGame({
    id        = "TAVERNCARDS",
    label     = "Tavern Cards",
    category  = "KARTEN",
    renderer  = "TC_Renderer",
    engine    = "TC_Engine",
    container = "_tcContainer",
})

local ADDON = "Interface\\AddOns\\ArcadiaNexus\\Games\\TavernCards\\assets\\"

local CFG = {
    field_w       = 592,
    field_h       = 432,
    field_x       = 4,
    field_y       = 10,
    border_w      = 825,
    border_h      = 565,
    border_x      = 0,
    border_y      = 13,
    logo_w        = 384,
    logo_h        = 256,
    logo_x        = 0,
    logo_y        = 15,
    bg_w          = 700,
    bg_h          = 450,
    bg_x          = -50,
    bg_y          = 10,
    bg_alpha      = 1.0,
    bg_tex        = "background\\tc_background",
    btn_w         = 144,
    btn_h         = 32,
    draw_btn_w    = 100,
    draw_btn_h    = 28,
    draw_btn_x    = -246,
    draw_btn_y    = 10,
    dd_w          = 110,
    card_w        = 52,
    card_h        = 72,
    hand_cards_per_row = 7,
    hand_max_rows = 5,
    hand_row1_y   = 0,
    hand_row_step = 42,
    hand_anchor_y = 40,
    hand_max_step = 56,
    hand_hover_scale  = 1.5,
    hand_hover_lift   = 10,
    discard_y     = 20,
    discard_scatter_x = 10,
    discard_scatter_y = 8,
    discard_visible   = 5,
    discard_layer_base = 10,
    hand_row_layer_step = 3,
    discard_x     = 40,
    color_picker_w    = 200,
    color_picker_h    = 130,
    color_picker_x    = 0,
    color_picker_y    = 50,
    color_btn_size    = 40,
    color_btn_pos     = { { -36, 6 }, { 36, 6 }, { -36, -34 }, { 36, -34 } },
    fly_card_scale    = 2.15,
    fly_start_scale   = 1.0,
    fly_duration      = 0.65,
    fly_center_x      = 0,
    fly_center_y      = 20,
    status_point      = "TOP",
    status_rel        = "TOP",
    status_x          = 0,
    status_y          = -20,
    status_w          = 520,
    score_point       = "TOPRIGHT",
    score_rel         = "TOPRIGHT",
    score_x           = -80,
    score_y           = -20,
    -- Spieler-Slot (Modell + Name am selben Frame)
    char_player = {
        point = "BOTTOMLEFT", rel = "BOTTOMLEFT", x = 12, y = 120,
        slot_w = 96, slot_h = 168,
        model_w = 84, model_h = 120, model_ox = 20, model_oy = 25,
        name_oy = -2, view = "left",
    },
    -- KI-Slots 1–3 (Modell + Name + Kartenanzahl am selben Frame)
    char_ai = {
        [1] = {
            point = "LEFT", rel = "LEFT", x = 18, y = 72,
            slot_w = 88, slot_h = 158,
            model_w = 72, model_h = 108, model_ox = 70, model_oy = 90,
            name_oy = -2, count_oy = -4, view = "left",
        },
        [2] = {
            point = "TOP", rel = "TOP", x = -130, y = -52,
            slot_w = 88, slot_h = 158,
            model_w = 60, model_h = 90, model_ox = 300, model_oy = 80,
            name_oy = -2, count_oy = -4, view = "right",
        },
        [3] = {
            point = "TOP", rel = "TOP", x = 130, y = -52,
            slot_w = 88, slot_h = 158,
            model_w = 60, model_h = 90, model_ox = 80, model_oy = -80,
            name_oy = -2, count_oy = -4, view = "right",
            -- optional: rotation = 2.74, zoom = 0.15, camScale = 0.90
        },
    },
}

local CARD_W = CFG.card_w
local CARD_H = CFG.card_h
local _flyGuard = ArcadiaNexus.TimerGuard.New()

local function CreateHandCardPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "TavernCards.HandCards",
        create = function(poolParent)
            poolParentRef = poolParent
            local cf = CreateFrame("Button", nil, poolParent)
            cf:SetSize(CARD_W, CARD_H)
            cf._tex = cf:CreateTexture(nil, "ARTWORK")
            cf._tex:SetAllPoints(cf)
            return cf
        end,
        onRelease = function(cf)
            cf:Hide()
            cf:ClearAllPoints()
            cf:SetAlpha(1)
            cf:SetScale(1)
            cf:SetSize(CARD_W, CARD_H)
            cf:SetScript("OnClick", nil)
            cf:SetScript("OnEnter", nil)
            cf:SetScript("OnLeave", nil)
            cf._tcPosX = nil
            cf._tcBaseY = nil
            cf._tcBaseLevel = nil
            cf._tcHoverW = nil
            cf._tcHoverH = nil
            if cf._tex then
                cf._tex:SetTexture(nil)
                cf._tex:SetTexCoord(0, 1, 0, 1)
                cf._tex:SetVertexColor(1, 1, 1, 1)
                cf._tex:SetAlpha(1)
            end
            if poolParentRef then
                cf:SetParent(poolParentRef)
            end
        end,
    })
end

local function CreateDiscardCardPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "TavernCards.DiscardCards",
        create = function(poolParent)
            poolParentRef = poolParent
            local fr = CreateFrame("Frame", nil, poolParent)
            fr:SetSize(CARD_W, CARD_H)
            fr._tex = fr:CreateTexture(nil, "ARTWORK")
            fr._tex:SetAllPoints(fr)
            return fr
        end,
        onRelease = function(fr)
            fr:Hide()
            fr:ClearAllPoints()
            fr:SetAlpha(1)
            fr:SetScale(1)
            if fr.SetRotation then fr:SetRotation(0) end
            if fr._tex then
                fr._tex:SetTexture(nil)
                fr._tex:SetTexCoord(0, 1, 0, 1)
                fr._tex:SetVertexColor(1, 1, 1, 1)
            end
            if poolParentRef then
                fr:SetParent(poolParentRef)
            end
        end,
    })
end

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("TAVERNCARDS")
    return (tbl and tbl[key]) or key
end

R.frame = nil
R._canvas = nil
R._playfield = nil
R._controlsFrame = nil
R.state = "IDLE"
R._cardFrames = { player = {}, ai = { {}, {}, {} } }
R._charSlots = { player = nil, ai = { nil, nil, nil } }
R._discardFrames = {}
R._startActive = false

function R:Init()
    self:_CreateMainFrame()
    self:_CreateChrome()
    self:_CreateBackground()
    self:_CreatePlayfield()
    self:_CreateControls()
    self:_CreateActionButtons()
    self:_CreateColorPicker()
    self:_CreateFlyOverlay()
    if ArcadiaNexus.TC_NpcData then
        ArcadiaNexus.TC_NpcData:WarmupCache()
    end
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    if self.frame then return end
    local panel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel and _G.ArcadiaNexusUI.GetGamesPanel()
    if not panel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(panel, {
        outerName = "ArcadiaNexus_TC_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    _G.ArcadiaNexus._tcContainer = f
    f:SetScript("OnShow", function()
        R:_UpdateControlsBar()
    end)
    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("TAVERNCARDS", ArcadiaNexus.TC_Engine, function(E)
            if E.state == "PLAYING" or E.state == "DEALING" then
                E:SaveAndPause()
            elseif E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
        R:EnterIdleState()
    end)
end

function R:_CreateChrome()
    local canvas = self._canvas
    if not canvas then return end
    local UI = ArcadiaNexus.UI
    local bf = CreateFrame("Frame", nil, canvas)
    bf:SetSize(CFG.border_w, CFG.border_h)
    bf:SetPoint("CENTER", canvas, "CENTER", CFG.border_x, CFG.border_y)
    bf:SetFrameLevel((canvas:GetFrameLevel() or 1) + 10)
    local bt = bf:CreateTexture(nil, "ARTWORK")
    bt:SetAllPoints(bf)
    bt:SetTexture(ADDON .. "border\\tc_border")
    self._borderFrame = bf
    if UI then
        self._logo = UI.CreateGameLogo(bf, ADDON .. "logo\\tc_logo", {
            w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_x, y = CFG.logo_y,
        })
        if self._logo and self._logo.SetDrawLayer then
            self._logo:SetDrawLayer("OVERLAY", 7)
        end
    end
end

function R:_CreateBackground()
    local canvas = self._canvas
    if not canvas or self._bgTex then return end
    local bg = canvas:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(CFG.bg_w, CFG.bg_h)
    bg:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.field_x + CFG.bg_x, -(CFG.field_y + CFG.bg_y))
    bg:SetTexture(ADDON .. CFG.bg_tex)
    bg:SetAlpha(CFG.bg_alpha)
    bg:SetDrawLayer("BACKGROUND", 0)
    self._bgTex = bg
end

function R:_CreatePlayfield()
    local canvas = self._canvas
    if not canvas or self._playfield then return end
    local pf = CreateFrame("Frame", nil, canvas)
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("TOPLEFT", canvas, "TOPLEFT", CFG.field_x, -CFG.field_y)
    pf:Hide()
    self._playfield = pf
    pf:SetScript("OnShow", function()
        local E = ArcadiaNexus.TC_Engine
        if E and E.gameState and (E.state == "PLAYING" or E.state == "DEALING") then
            R:_RefreshModels(E.gameState)
        end
    end)

    self._drawTex = pf:CreateTexture(nil, "ARTWORK")
    self._drawTex:SetSize(CARD_W, CARD_H)
    self._drawTex:SetPoint("CENTER", pf, "CENTER", -50, CFG.discard_y)

    self._drawCountFS = pf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._drawCountFS:SetPoint("BOTTOM", self._drawTex, "TOP", 0, 4)

    self._colorRing = pf:CreateTexture(nil, "ARTWORK")
    self._colorRing:SetSize(CARD_W + 8, CARD_H + 8)
    self._colorRing:SetPoint("CENTER", pf, "CENTER", CFG.discard_x, CFG.discard_y)
    self._colorRing:SetTexture("Interface\\Buttons\\WHITE8X8")

    self._statusFS = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self._statusFS:SetPoint(CFG.status_point, pf, CFG.status_rel, CFG.status_x, CFG.status_y)
    self._statusFS:SetWidth(CFG.status_w)

    self._scoreFS = nil

    self._playerHandAnchor = CreateFrame("Frame", nil, pf)
    self._playerHandAnchor:SetSize(420, CARD_H + CFG.hand_row_step * (CFG.hand_max_rows - 1) + 20)
    self._playerHandAnchor:SetPoint("BOTTOM", pf, "BOTTOM", 0, CFG.hand_anchor_y)

    self._charSlots.player = self:_CreateCharSlot(pf, CFG.char_player, false)
    for i = 1, 3 do
        self._charSlots.ai[i] = self:_CreateCharSlot(pf, CFG.char_ai[i], true)
        self._cardFrames.ai[i].anchor = self._charSlots.ai[i].frame
        self._cardFrames.ai[i].nameFS = self._charSlots.ai[i].nameFS
        self._cardFrames.ai[i].countFS = self._charSlots.ai[i].countFS
    end

    if not self._handCardPool then
        self._handCardPool = CreateHandCardPool()
    end
    if not self._discardCardPool then
        self._discardCardPool = CreateDiscardCardPool()
    end
end

function R:_CreateCharSlot(pf, sc, showCount)
    local slot = CreateFrame("Frame", nil, pf)
    slot:SetSize(sc.slot_w or 88, sc.slot_h or 160)
    slot:SetPoint(sc.point or "CENTER", pf, sc.rel or sc.point or "CENTER", sc.x or 0, sc.y or 0)
    local Npc = ArcadiaNexus.TC_NpcData
    local model = CreateFrame("PlayerModel", nil, slot)
    model:SetSize(sc.model_w or 72, sc.model_h or 108)
    model:SetPoint("BOTTOM", slot, "BOTTOM", sc.model_ox or 0, sc.model_oy or 0)
    Npc:PrepareModelFrame(model)
    model:EnableMouse(false)
    local nameFS = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOP", model, "BOTTOM", 0, sc.name_oy or -2)
    nameFS:SetWidth(sc.slot_w or 88)
    nameFS:SetJustifyH("CENTER")
    local countFS
    if showCount then
        countFS = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countFS:SetPoint("TOP", nameFS, "BOTTOM", 0, sc.count_oy or -4)
        countFS:SetWidth(sc.slot_w or 88)
        countFS:SetJustifyH("CENTER")
    end
    return {
        frame = slot, model = model, nameFS = nameFS, countFS = countFS,
        view = sc.view or "left",
        viewOverride = {
            rotation = sc.rotation,
            zoom = sc.zoom,
            camScale = sc.camScale,
        },
    }
end

function R:_SlotViewOverride(slot)
    if not slot or not slot.viewOverride then return nil end
    local o = slot.viewOverride
    if o.rotation or o.zoom or o.camScale then return o end
    return nil
end

function R:_CreateControls()
    if not self.frame or self._controlsFrame then return end
    local UI = ArcadiaNexus.UI
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local ddGap = 10
    local ddAiW = 80
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(CFG.dd_w + ddGap + ddAiW, CFG.btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddDiff = CreateFrame("Frame", nil, pair)
    ddDiff:SetSize(CFG.dd_w, CFG.btn_h)
    ddDiff:SetPoint("LEFT", pair, "LEFT", 0, 0)
    UI.CreateSimpleDropdown(ddDiff, 0, 0, CFG.dd_w, "", {
        { key = "easy", label = L("diff_easy") },
        { key = "normal", label = L("diff_normal") },
        { key = "hard", label = L("diff_hard") },
    }, function() return R._lastDiff or "easy" end, function(k) R._lastDiff = k end)

    local ddAi = CreateFrame("Frame", nil, pair)
    ddAi:SetSize(ddAiW, CFG.btn_h)
    ddAi:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    UI.CreateSimpleDropdown(ddAi, 0, 0, ddAiW, "", {
        { key = "1", label = L("ai_1") }, { key = "2", label = L("ai_2") }, { key = "3", label = L("ai_3") },
    }, function() return tostring(R._lastAI or 1) end, function(k) R._lastAI = tonumber(k) or 1 end)

    self._startBtn = UI.CreateArcadiaButton(cf, L("btn_start"), CFG.btn_w, CFG.btn_h)
    self._startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    self._startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.TC_Engine
        if E.state ~= "IDLE" then
            E:StopGame()
        elseif R:_HasPausedGame() then
            E:ResumeGame()
        else
            E:StartGame({ difficulty = R._lastDiff or "easy", aiCount = R._lastAI or 1,
                gameMode = R._lastMode or "single", pointTarget = R._lastTarget or 500 })
        end
    end)

    self._resumeBtn = UI.CreateArcadiaButton(cf, L("btn_resume"), CFG.btn_w, CFG.btn_h)
    self._resumeBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    self._resumeBtn:Hide()
    self._resumeBtn:SetScript("OnClick", function()
        ArcadiaNexus.TC_Engine:ResumeGame()
    end)

    local ddMode = CreateFrame("Frame", nil, cf)
    ddMode:SetSize(CFG.dd_w, CFG.btn_h)
    ddMode:SetPoint("CENTER", cf, "CENTER", bar.segX[3], bar.y.dropdownOfs)
    self._ddModeAnchor = ddMode
    UI.CreateSimpleDropdown(ddMode, 0, 0, CFG.dd_w, "", {
        { key = "single", label = L("mode_single") }, { key = "multi", label = L("mode_multi") },
    }, function() return R._lastMode or "single" end, function(k) R._lastMode = k end)

    self._newGameBtn = UI.CreateArcadiaButton(cf, L("btn_new_game"), CFG.btn_w, CFG.btn_h)
    self._newGameBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    self._newGameBtn:Hide()
    self._newGameBtn:SetScript("OnClick", function()
        ArcadiaNexus.TC_Engine:StartGame({
            difficulty = R._lastDiff or "easy", aiCount = R._lastAI or 1,
            gameMode = R._lastMode or "single", pointTarget = R._lastTarget or 500,
        })
    end)
end

function R:_CreateActionButtons()
    local pf = self._playfield
    if not pf then return end
    local UI = ArcadiaNexus.UI
    self._drawBtn = UI.CreateArcadiaButton(pf, L("btn_draw"), CFG.draw_btn_w, CFG.draw_btn_h)
    self._drawBtn:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", CFG.draw_btn_x, CFG.draw_btn_y)
    self._drawBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerDraw(false) end)
    self._unoBtn = UI.CreateArcadiaButton(pf, L("btn_uno"), 80, 28)
    self._unoBtn:SetPoint("RIGHT", self._drawBtn, "LEFT", -8, 0)
    self._unoBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerCallUno() end)
    self._catchBtn = UI.CreateArcadiaButton(pf, L("btn_catch"), 90, 28)
    self._catchBtn:SetPoint("RIGHT", self._unoBtn, "LEFT", -8, 0)
    self._catchBtn:Hide()
    self._catchBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerCatchUno() end)
    self._challengeBtn = UI.CreateArcadiaButton(pf, L("btn_challenge"), 90, 28)
    self._challengeBtn:SetPoint("TOP", pf, "TOP", -60, -40)
    self._challengeBtn:Hide()
    self._challengeBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerChallengeWild4() end)
    self._acceptBtn = UI.CreateArcadiaButton(pf, L("btn_accept"), 90, 28)
    self._acceptBtn:SetPoint("LEFT", self._challengeBtn, "RIGHT", 8, 0)
    self._acceptBtn:Hide()
    self._acceptBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerAcceptWild4() end)
end

function R:_CreateColorPicker()
    local pf = self._playfield
    if not pf or self._colorPicker then return end
    local picker = CreateFrame("Frame", nil, pf, "BackdropTemplate")
    picker:SetSize(CFG.color_picker_w, CFG.color_picker_h)
    picker:SetPoint("CENTER", pf, "CENTER", CFG.color_picker_x, CFG.color_picker_y)
    picker:SetFrameLevel(pf:GetFrameLevel() + 30)
    picker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    picker:Hide()
    self._colorPicker = picker
    local lbl = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOP", picker, "TOP", 0, -12)
    lbl:SetText(L("lbl_pick_color"))
    local colors = { "GREEN", "BLUE", "RED", "YELLOW" }
    local Cards = ArcadiaNexus.TC_Cards
    for i, col in ipairs(colors) do
        local pos = CFG.color_btn_pos[i] or { 0, 0 }
        local btn = CreateFrame("Button", nil, picker)
        btn:SetSize(CFG.color_btn_size, CFG.color_btn_size)
        btn:SetPoint("CENTER", picker, "CENTER", pos[1], pos[2])
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(btn)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        local rgb = Cards.COLOR_RGB[col]
        tex:SetVertexColor(rgb[1], rgb[2], rgb[3])
        btn:SetScript("OnClick", function()
            ArcadiaNexus.TC_Engine:PlayerPickColor(col)
            picker:Hide()
        end)
    end
end

function R:_CreateFlyOverlay()
    local pf = self._playfield
    if not pf then return end
    self._flyFrame = CreateFrame("Frame", nil, pf)
    self._flyFrame:SetSize(CARD_W, CARD_H)
    self._flyFrame:SetPoint("CENTER", pf, "CENTER", 0, 20)
    self._flyFrame:SetFrameLevel(pf:GetFrameLevel() + 40)
    self._flyTex = self._flyFrame:CreateTexture(nil, "OVERLAY")
    self._flyTex:SetAllPoints(self._flyFrame)
    self._flyFrame:Hide()
end

function R:_HasPausedGame()
    local S = ArcadiaNexus.TC_Settings
    return S and S:LoadPausedState() ~= nil
end

function R:_UpdateControlsBar()
    local E = ArcadiaNexus.TC_Engine
    local playing = E and E.state ~= "IDLE"
    local paused = self:_HasPausedGame()
    if self._startBtn then
        if playing then
            self._startBtn:SetLabel(L("btn_stop"))
            self._startBtn:SetShown(true)
        elseif paused then
            self._startBtn:SetLabel(L("btn_resume"))
            self._startBtn:SetShown(true)
        else
            self._startBtn:SetLabel(L("btn_start"))
            self._startBtn:SetShown(true)
        end
    end
    if self._newGameBtn then
        self._newGameBtn:SetShown(paused and not playing)
    end
    if self._ddModeAnchor then
        self._ddModeAnchor:SetShown(not paused or playing)
    end
    if self._resumeBtn then
        self._resumeBtn:Hide()
    end
end

function R:HideStartPopup()
    if self.frame and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideChoicePopup(self.frame)
    end
end

function R:ShowStartPopup()
    if not self.frame then return end
    local UI = ArcadiaNexus.UI
    if not UI or not UI.ShowChoicePopup then return end
    UI.ShowChoicePopup({
        parent = self.frame,
        title = L("popup_start_title"),
        titleColor = { 1, 0.82, 0 },
        buttons = {
            {
                label = L("btn_new_game"),
                onClick = function()
                    R:HideStartPopup()
                    ArcadiaNexus.TC_Engine:StartGame({
                        difficulty = R._lastDiff or "easy", aiCount = R._lastAI or 1,
                        gameMode = R._lastMode or "single", pointTarget = R._lastTarget or 500,
                    })
                end,
            },
            {
                label = L("btn_resume"),
                onClick = function()
                    R:HideStartPopup()
                    ArcadiaNexus.TC_Engine:ResumeGame()
                end,
            },
        },
    })
end

function R:EnterIdleState()
    self.state = "IDLE"
    self._startActive = false
    if self._playfield then self._playfield:Hide() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._logo then self._logo:Show() end
    self:_ClearCardFrames()
    self:_ClearDiscardFrames()
    self:_UpdateControlsBar()
end

function R:OnGameStopped() self:EnterIdleState() end
function R:OnStateChanged(state)
    self.state = state
    self:_UpdateControlsBar()
end

function R:OnGameStarted(gs)
    self._startActive = true
    if self._logo then self._logo:Hide() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._playfield then self._playfield:Show() end
    self:_UpdateControlsBar()
    self:UpdateBoard(gs)
    self:_RefreshModels(gs)
end

function R:_ApplyCharModels(gs, forceReload)
    if not gs then return false end
    local Npc = ArcadiaNexus.TC_NpcData
    local allOk = true
    local function applySlot(slot, charDef)
        if not slot or not charDef then return true end
        slot.frame:Show()
        slot.model:Show()
        local ok = Npc:ApplyModel(slot.model, charDef, slot.view, self:_SlotViewOverride(slot), forceReload)
        if ok then Npc:PlayAnim(slot.model, "idle") end
        return ok
    end
    local human = gs.players and gs.players[1]
    if human and human.charDef then
        if not applySlot(self._charSlots.player, human.charDef) then allOk = false end
    end
    for i = 1, 3 do
        local aiIdx = i + 1
        local slot = self._charSlots.ai[i]
        if aiIdx <= gs.playerCount and slot then
            local p = gs.players[aiIdx]
            if p and p.charDef and not applySlot(slot, p.charDef) then allOk = false end
        end
    end
    return allOk
end

function R:_RefreshModels(gs)
    if not gs then return end
    local attempt = 0
    local maxAttempts = 6
    local function step()
        if not R._playfield then return end
        if not R._playfield:IsShown() then
            if attempt < maxAttempts then
                attempt = attempt + 1
                C_Timer.After(0.1, step)
            end
            return
        end
        attempt = attempt + 1
        R:_ApplyCharModels(gs, attempt > 1)
        if attempt < maxAttempts then
            C_Timer.After(0.12, step)
        end
    end
    C_Timer.After(0, step)
end

function R:_ClearCardFrames()
    if self._handCardPool then
        for _, cf in ipairs(self._cardFrames.player) do
            self._handCardPool:Release(cf)
        end
    end
    self._cardFrames.player = {}
end

function R:_ApplyHandCardHover(cf, anchor, baseLevel)
    if not cf or not anchor then return end
    cf._tcBaseLevel = baseLevel
    cf._tcHoverW = CARD_W * CFG.hand_hover_scale
    cf._tcHoverH = CARD_H * CFG.hand_hover_scale
    cf:SetSize(CARD_W, CARD_H)
    cf:SetScript("OnEnter", function(self)
        self:SetSize(self._tcHoverW, self._tcHoverH)
        self:SetFrameLevel(anchor:GetFrameLevel() + CFG.hand_max_rows * CFG.hand_row_layer_step + 10)
        self:SetPoint("BOTTOM", anchor, "BOTTOM", self._tcPosX, self._tcBaseY + CFG.hand_hover_lift)
    end)
    cf:SetScript("OnLeave", function(self)
        self:SetSize(CARD_W, CARD_H)
        self:SetFrameLevel(self._tcBaseLevel or baseLevel)
        self:SetPoint("BOTTOM", anchor, "BOTTOM", self._tcPosX, self._tcBaseY)
    end)
end

function R:_ClearDiscardFrames()
    if self._discardCardPool then
        for _, fr in ipairs(self._discardFrames) do
            self._discardCardPool:Release(fr)
        end
    end
    self._discardFrames = {}
end

function R:_SetCardTexture(tex, card, theme)
    local Cards = ArcadiaNexus.TC_Cards
    if card then tex:SetTexture(Cards:GetCardTexture(card))
    else tex:SetTexture(Cards:GetCardBackTexture(theme or "neutral")) end
    tex:SetTexCoord(0, 1, 0, 1)
end

function R:_ScatterOffset(index)
    local seed = index * 7919
    return (seed % (CFG.discard_scatter_x * 2 + 1)) - CFG.discard_scatter_x,
           ((seed * 3) % (CFG.discard_scatter_y * 2 + 1)) - CFG.discard_scatter_y,
           (seed % 13) - 6
end

function R:_UpdateDiscardPile(gs, theme)
    self:_ClearDiscardFrames()
    local pf = self._playfield
    if not pf then return end
    local pile = gs.discardPile or {}
    local count = math.min(#pile, CFG.discard_visible)
    local startIdx = math.max(1, #pile - count + 1)
    for i = startIdx, #pile do
        local card = pile[i]
        local slot = i - startIdx + 1
        local stackFromTop = count - slot + 1
        local ox, oy, rot = self:_ScatterOffset(i)
        local fr = self._discardCardPool:Acquire({})
        fr:SetParent(pf)
        fr:ClearAllPoints()
        fr:SetSize(CARD_W, CARD_H)
        fr:SetPoint("CENTER", pf, "CENTER", CFG.discard_x + ox, CFG.discard_y + oy + slot * 2)
        if fr.SetRotation then fr:SetRotation(math.rad(rot)) end
        fr:SetFrameLevel(pf:GetFrameLevel() + CFG.discard_layer_base + (count - stackFromTop + 1))
        self:_SetCardTexture(fr._tex, card, theme)
        fr:Show()
        self._discardFrames[#self._discardFrames + 1] = fr
    end
end

function R:_HandRowStep(cardCount)
    cardCount = math.max(1, math.min(cardCount, CFG.hand_cards_per_row))
    if cardCount >= CFG.hand_cards_per_row then
        return CFG.hand_max_step
    end
    return math.min(CFG.hand_max_step, 380 / math.max(cardCount - 1, 1))
end

function R:_LayoutPlayerHand(hand, gs, theme, isHumanTurn)
    local Rules = ArcadiaNexus.TC_Rules
    local anchor = self._playerHandAnchor
    local rows = {}
    for i, card in ipairs(hand) do
        local rowIdx = math.min(
            math.ceil(i / CFG.hand_cards_per_row),
            CFG.hand_max_rows
        )
        rows[rowIdx] = rows[rowIdx] or {}
        rows[rowIdx][#rows[rowIdx] + 1] = { idx = i, card = card }
    end
    local function placeRow(entries, rowIdx)
        if #entries == 0 then return end
        local rowY = CFG.hand_row1_y + (rowIdx - 1) * CFG.hand_row_step
        local step = R:_HandRowStep(#entries)
        local startX = -((#entries - 1) * step) / 2
        local rowLayer = (CFG.hand_max_rows - rowIdx + 1) * CFG.hand_row_layer_step
        local baseLevel = anchor:GetFrameLevel() + rowLayer
        for j, entry in ipairs(entries) do
            local posX = startX + (j - 1) * step
            local cf = self._handCardPool:Acquire({})
            cf:SetParent(anchor)
            cf:SetSize(CARD_W, CARD_H)
            cf._tcPosX = posX
            cf._tcBaseY = rowY
            cf:ClearAllPoints()
            cf:SetPoint("BOTTOM", anchor, "BOTTOM", posX, rowY)
            cf:SetFrameLevel(baseLevel + j)
            self:_SetCardTexture(cf._tex, entry.card, theme)
            local playable = Rules:CanPlay(entry.card, gs) and isHumanTurn and not gs.pendingColorPick and not gs.unoWindow
            cf._tex:SetAlpha(playable and 1 or 0.55)
            local idx = entry.idx
            cf:SetScript("OnClick", function()
                if playable then ArcadiaNexus.TC_Engine:PlayerPlayCard(idx, nil) end
            end)
            self:_ApplyHandCardHover(cf, anchor, baseLevel + j)
            cf:Show()
            self._cardFrames.player[#self._cardFrames.player + 1] = cf
        end
    end
    for rowIdx = 1, CFG.hand_max_rows do
        placeRow(rows[rowIdx] or {}, rowIdx)
    end
end

function R:_GetCenterOffset(fromFrame)
    local pf = self._playfield
    if not pf then return CFG.fly_center_x, CFG.fly_center_y end
    if not fromFrame or not fromFrame.GetCenter then
        return CFG.fly_center_x, CFG.fly_center_y
    end
    local fx, fy = fromFrame:GetCenter()
    local px, py = pf:GetCenter()
    if fx and px then return fx - px, fy - py end
    return CFG.fly_center_x, CFG.fly_center_y
end

function R:_SmoothStep(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function R:ShowCardFly(card, theme, onDone, fromFrame)
    if not self._flyFrame or not card then if onDone then onDone() end return end
    local pf = self._playfield
    if not pf then if onDone then onDone() end return end
    _flyGuard:Cancel()
    self:_SetCardTexture(self._flyTex, card, theme)
    local ff = self._flyFrame
    local fromX, fromY = self:_GetCenterOffset(fromFrame)
    local toX, toY = CFG.fly_center_x, CFG.fly_center_y
    local startSc = CFG.fly_start_scale or 1
    local endSc = CFG.fly_card_scale
    local duration = CFG.fly_duration or 0.65
    local startTime = GetTime()
    ff:Show()
    ff:SetSize(CARD_W * startSc, CARD_H * startSc)
    ff:ClearAllPoints()
    ff:SetPoint("CENTER", pf, "CENTER", fromX, fromY)
    _flyGuard:EveryTicker(0.016, function()
        if not R._flyFrame or not R._playfield then
            _flyGuard:Cancel()
            return
        end
        local t = (GetTime() - startTime) / duration
        local e = R:_SmoothStep(t)
        local x = fromX + (toX - fromX) * e
        local y = fromY + (toY - fromY) * e
        local s = startSc + (endSc - startSc) * e
        ff:ClearAllPoints()
        ff:SetPoint("CENTER", pf, "CENTER", x, y)
        ff:SetSize(CARD_W * s, CARD_H * s)
        if t >= 1 then
            _flyGuard:Cancel()
            ff:Hide()
            if onDone then onDone() end
        end
    end)
end

function R:ShowPlayFeedback(gs, playerIndex, card, onDone)
    self:UpdateBoard(gs)
    local Npc = ArcadiaNexus.TC_NpcData
    local from
    if playerIndex == 1 then
        local slot = self._charSlots.player
        if slot then Npc:PlayAnim(slot.model, "play"); from = slot.model end
    else
        local slot = self._charSlots.ai[playerIndex - 1]
        if slot then Npc:PlayAnim(slot.model, "play"); from = slot.model end
    end
    self:ShowCardFly(card, gs.theme, onDone, from)
end

function R:ShowDrawnCard(card, theme, onDone)
    self:UpdateBoard(ArcadiaNexus.TC_Engine.gameState)
    self:ShowCardFly(card, theme, onDone, self._drawTex)
end

function R:UpdateBoard(gs)
    if not gs or not self._playfield then return end
    local Cards = ArcadiaNexus.TC_Cards
    local Rules = ArcadiaNexus.TC_Rules
    local theme = gs.theme or "neutral"
    self:_SetCardTexture(self._drawTex, nil, theme)
    self._drawCountFS:SetText(tostring(#gs.drawPile))
    self:_UpdateDiscardPile(gs, theme)
    local ac = Rules:GetActiveColor(gs)
    if ac and Cards.COLOR_RGB[ac] and #self._discardFrames > 0 then
        local c = Cards.COLOR_RGB[ac]
        self._colorRing:SetVertexColor(c[1], c[2], c[3], 0.55)
        self._colorRing:ClearAllPoints()
        self._colorRing:SetPoint("CENTER", self._discardFrames[#self._discardFrames], "CENTER")
        self._colorRing:Show()
    else self._colorRing:Hide() end
    local human = gs.players[1]
    local isHumanTurn = gs.currentPlayer == 1 and not human.isAI
    local status = gs.turnNotice or (isHumanTurn and L("lbl_your_turn") or L("lbl_ai_turn"))
    if gs.currentPlayer ~= 1 and not gs.turnNotice then
        status = (gs.players[gs.currentPlayer].name or "") .. " - " .. L("lbl_ai_turn")
    end
    self._statusFS:SetText(status)
    local pSlot = self._charSlots.player
    if pSlot and human.charDef then
        pSlot.nameFS:SetText(human.name)
        pSlot.frame:Show()
    end
    for i = 1, 3 do
        local aiIdx = i + 1
        local slot = self._charSlots.ai[i]
        if aiIdx <= gs.playerCount and slot then
            local p = gs.players[aiIdx]
            slot.frame:Show()
            slot.nameFS:SetText(p.name)
            if slot.countFS then
                slot.countFS:SetText(L("lbl_cards") .. ": " .. tostring(#p.hand))
            end
        elseif slot then
            slot.frame:Hide()
            slot.model:Hide()
        end
    end
    if self._playfield:IsShown() then
        self:_ApplyCharModels(gs, false)
    end
    self:_ClearCardFrames()
    self:_LayoutPlayerHand(human.hand, gs, theme, isHumanTurn)
    local uw = gs.unoWindow
    local showUno = uw and uw.playerIndex == 1 and not uw.resolved
    local showCatch = uw and uw.playerIndex ~= 1 and not gs.players[uw.playerIndex].unoCalled and not uw.resolved
    if self._unoBtn then self._unoBtn:SetShown(showUno) end
    if self._catchBtn then self._catchBtn:SetShown(showCatch) end
    if self._drawBtn then
        local canDraw = isHumanTurn and not gs.pendingColorPick and not gs.unoWindow
            and not gs.hasDrawnThisTurn and not gs.drawnThisTurn
        self._drawBtn:SetShown(canDraw)
    end
    if self._colorPicker then
        if gs.pendingColorPick and gs.pendingColorPick.playerIndex == 1 then self._colorPicker:Show()
        else self._colorPicker:Hide() end
    end
    local showCh = gs.wild4Challengable and gs.currentPlayer == 1
    if self._challengeBtn then self._challengeBtn:SetShown(showCh) end
    if self._acceptBtn then self._acceptBtn:SetShown(showCh) end
end

function R:ShowRoundResult(gs, winnerIndex, roundPts)
    local UI = ArcadiaNexus.UI
    local loc = ArcadiaNexus.GetLocaleTable("TAVERNCARDS")
    local parent = self._playfield
    UI.ShowResultDialog({
        parent = parent, title = L("result_round"),
        subtitle = gs.players[winnerIndex].name .. " +" .. roundPts,
        gameId = "TAVERNCARDS", difficulty = gs.difficulty,
        result = winnerIndex == 1 and "WIN" or "LOSS",
        buttons = UI.ResultDialogButtons.Round(loc,
            function() UI.HideResultDialog(parent); ArcadiaNexus.TC_Engine:NewRound() end,
            function() UI.HideResultDialog(parent); ArcadiaNexus.TC_Engine:StopGame() end),
    })
end

function R:ShowGameEnd(gs, winnerIndex, roundPts, gameWinner)
    local UI = ArcadiaNexus.UI
    local parent = self._playfield
    local win = (winnerIndex == 1 or gameWinner == 1)
    UI.ShowArcadeResult(parent, {
        gameId = "TAVERNCARDS", difficulty = gs.difficulty,
        result = win and "WIN" or "LOSS", hideHighscore = true,
        subtitle = gs.players[winnerIndex].name .. " +" .. tostring(roundPts or 0),
        L = ArcadiaNexus.GetLocaleTable("TAVERNCARDS"),
        onRetry = function()
            ArcadiaNexus.TC_Engine:StopGame()
            ArcadiaNexus.TC_Engine:StartGame({ difficulty = gs.difficulty, aiCount = gs.aiCount, gameMode = gs.gameMode, pointTarget = gs.pointTarget })
        end,
        onExit = function() ArcadiaNexus.TC_Engine:StopGame() end,
    })
end

function R:Show()
    if not self.frame then self:Init() end
    if ArcadiaNexus.TC_NpcData then
        ArcadiaNexus.TC_NpcData:WarmupCache()
    end
    if self.frame then
        self.frame:Show()
        self:_UpdateControlsBar()
    end
end

function R:Hide()
    if self.frame then self.frame:Hide() end
end
