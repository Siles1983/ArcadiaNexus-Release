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
    matchSeats = 4,
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\TavernCards\\assets\\logo\\tc_logo",
    xp        = 10,
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
    action_inset  = 8,
    action_gap    = 8,
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
    self:_CreateSlotMenu()
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
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then
            return
        end
        R:CancelModelRefresh()
        ArcadiaNexus.GameSession:HandleRendererHide("TAVERNCARDS", ArcadiaNexus.TC_Engine, function(E)
            if E.mode ~= "hotseat" and (E.state == "PLAYING" or E.state == "LOBBY"
                or E.state == "FINISHED" or E.state == "DEALING") then
                E:HideView()
            elseif E.state == "PLAYING" or E.state == "DEALING" then
                E:SaveAndPause()
            elseif E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
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
    self._diffDD = UI.CreateSimpleDropdown(ddDiff, 0, 0, CFG.dd_w, "", {
        { key = "easy", label = L("diff_easy") },
        { key = "normal", label = L("diff_normal") },
        { key = "hard", label = L("diff_hard") },
    }, function() return ArcadiaNexus.TC_Settings:Get("difficulty") end, function(k) ArcadiaNexus.TC_Settings:Set("difficulty",k) end)

    local ddAi = CreateFrame("Frame", nil, pair)
    ddAi:SetSize(ddAiW, CFG.btn_h)
    ddAi:SetPoint("RIGHT", pair, "RIGHT", 0, 0)
    self._aiDD = UI.CreateSimpleDropdown(ddAi, 0, 0, ddAiW, "", {
        { key = "1", label = L("ai_1") }, { key = "2", label = L("ai_2") }, { key = "3", label = L("ai_3") },
    }, function() return tostring(ArcadiaNexus.TC_Settings:Get("aiCount")) end, function(k) ArcadiaNexus.TC_Settings:Set("aiCount",tonumber(k)) end)

    self._ddPair = pair

    self._startBtn = UI.CreateArcadiaButton(cf, L("btn_start"), CFG.btn_w, CFG.btn_h)
    self._startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    self._startBtn:SetScript("OnClick",function()
        local E=ArcadiaNexus.TC_Engine
        if E.state~="IDLE" then E:StopGame() else R:EnterSlotMenu() end
    end)

    local ddMode = CreateFrame("Frame", nil, cf)
    ddMode:SetSize(CFG.dd_w, CFG.btn_h)
    ddMode:SetPoint("CENTER", cf, "CENTER", bar.segX[3], bar.y.dropdownOfs)
    self._ddModeAnchor = ddMode
    self._modeDD = UI.CreateSimpleDropdown(ddMode, 0, 0, CFG.dd_w, "", {
        { key = "single", label = L("mode_single") }, { key = "multi", label = L("mode_multi") },
    }, function() return ArcadiaNexus.TC_Settings:Get("gameMode") end, function(k) ArcadiaNexus.TC_Settings:Set("gameMode",k) end)


end

function R:_CreateActionButtons()
    local pf = self._playfield
    if not pf then return end
    local UI = ArcadiaNexus.UI
    self._drawBtn = UI.CreateArcadiaButton(pf, L("btn_draw"), CFG.draw_btn_w, CFG.draw_btn_h)
    self._drawBtn:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", CFG.draw_btn_x, CFG.draw_btn_y)
    self._drawBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerDraw(false) end)
    self._forfeitBtn=UI.CreateArcadiaButton(pf,L("btn_forfeit"),100,28)
    self._forfeitBtn:SetPoint("BOTTOMLEFT",pf,"BOTTOMLEFT",CFG.action_inset,CFG.draw_btn_y)
    self._forfeitBtn:SetScript("OnClick",function() ArcadiaNexus.TC_Engine:RequestForfeit() end)
    self._rulesBtn=UI.CreateArcadiaButton(pf,L("box_rules"),100,28)
    self._rulesBtn:SetPoint("BOTTOMRIGHT",pf,"BOTTOMRIGHT",-CFG.action_inset,CFG.draw_btn_y)
    self._rulesBtn:SetScript("OnEnter",function(frame) R:ShowRulesTooltip(frame) end)
    self._rulesBtn:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    self._pointsFS=pf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    self._pointsFS:SetPoint("TOP",pf,"TOP",0,-4); self._pointsFS:SetWidth(560)
    self._passBtn = UI.CreateArcadiaButton(pf, L("btn_pass"), 80, 28)
    -- Draw/Pass and UNO/Catch are mutually exclusive phase actions, so each pair shares a slot.
    -- 592px field: Forfeit 8..108, UNO 116..196 / Catch 116..206,
    -- Draw 246..346 / Pass 256..336, Rules 484..584. Minimum edge gap: 8px.
    local decisionX=CFG.field_w+CFG.draw_btn_x-CFG.draw_btn_w/2
    self._passBtn:SetPoint("BOTTOM",pf,"BOTTOMLEFT",decisionX,CFG.draw_btn_y)
    self._passBtn:Hide()
    self._passBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerPassAfterDraw() end)
    self._unoBtn = UI.CreateArcadiaButton(pf, L("btn_uno"), 80, 28)
    self._unoBtn:SetPoint("BOTTOMLEFT",pf,"BOTTOMLEFT",CFG.action_inset+100+CFG.action_gap,CFG.draw_btn_y)
    self._unoBtn:SetScript("OnClick", function() ArcadiaNexus.TC_Engine:PlayerCallUno() end)
    self._catchBtn = UI.CreateArcadiaButton(pf, L("btn_catch"), 90, 28)
    self._catchBtn:SetPoint("BOTTOMLEFT",pf,"BOTTOMLEFT",CFG.action_inset+100+CFG.action_gap,CFG.draw_btn_y)
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
    local tips={_drawBtn="tip_draw",_passBtn="tip_pass",_unoBtn="tip_uno",_catchBtn="tip_catch",_challengeBtn="guide_stack_challenge",_acceptBtn="tip_accept",_forfeitBtn="confirm_forfeit_body"}
    for field,key in pairs(tips) do
        local button=self[field]
        button:HookScript("OnEnter",function(frame)
            if not GameTooltip then return end
            GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText(L(key),1,1,1,1,true); GameTooltip:Show()
        end)
        button:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
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
    self:RefreshDisplayOptions()
    local E,S=ArcadiaNexus.TC_Engine,ArcadiaNexus.TC_Settings
    local mp=E.mode~="hotseat"; local playing=E.state~="IDLE"
    for _,dd in ipairs({self._diffDD,self._aiDD,self._modeDD}) do dd:SetEnabled(not playing); dd:RefreshDisplay() end
    if self._ddPair then self._ddPair:SetShown(not mp) end
    if self._ddModeAnchor then self._ddModeAnchor:SetShown(not mp) end
    if self._startBtn then self._startBtn:SetLabel(playing and L("btn_exit") or L("btn_start")); self._startBtn:Show() end
    if self._forfeitBtn then self._forfeitBtn:SetShown(not mp and E.gameState~=nil and E.gameState.phase~="FINISHED" and E.gameState.phase~="RESULT_PENDING") end
end
function R:_CreateSlotMenu()
    local S=ArcadiaNexus.TC_Settings
    self._slotMenu=ArcadiaNexus.UI.CreateSaveSlotMenu({parent=self._canvas,maxSlots=3,L=ArcadiaNexus.GetLocaleTable("TAVERNCARDS"),title=L("game_title"),
        onCancel=function() R:EnterIdleState() end,
        loadSlot=function(slot) return S:LoadSlot(slot) end,
        deleteSlot=function(slot) S:DeleteSlot(slot) end,
        canContinue=function(save) return ArcadiaNexus.TC_Engine:CanContinueSave(save) end,
        isPaused=function(save) return ArcadiaNexus.TC_Engine:CanContinueSave(save) end,
        formatInfo=function(save) if not ArcadiaNexus.TC_Logic:ValidateSave(save) then return L("slot_unavailable") end; return L("diff_"..save.difficulty).." · "..L("mode_"..save.gameMode).." · "..L("lbl_round").." "..tostring(save.roundNumber)..(save.phase=="FINISHED" and " · "..L("slot_completed") or "") end,
        onNewGame=function(slot) R._menuOpen=false; ArcadiaNexus.TC_Engine:StartGame({slot=slot,overwrite=true}) end,
        onContinue=function(slot) R._menuOpen=false; ArcadiaNexus.TC_Engine:StartGame({slot=slot,mode="continue"}) end,
    })
    self._legacySaveFS=self._slotMenu.frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    self._legacySaveFS:SetPoint("BOTTOM",self._slotMenu.frame,"BOTTOM",0,90)
    self._legacySaveFS:SetWidth(540); self._legacySaveFS:SetTextColor(1,0.82,0); self._legacySaveFS:Hide()
end
function R:EnterSlotMenu()
    if ArcadiaNexus.TC_Engine.gameState then return end
    self._menuOpen=true; self._logo:Hide(); self._playfield:Hide(); self._slotMenu:Show()
    local db=ArcadiaNexus.Persistence:GetGameSettings("TAVERNCARDS")
    self._legacySaveFS:SetText(L("legacy_save_preserved")); self._legacySaveFS:SetShown(db.pausedState~=nil)
    self._startBtn:SetLabel(L("btn_exit"))
    self._startBtn:SetScript("OnClick",function() if R._menuOpen then R:EnterIdleState() else local E=ArcadiaNexus.TC_Engine; if E.state~="IDLE" then E:StopGame() else R:EnterSlotMenu() end end end)
end

function R:EnterIdleState()
    self._menuOpen=false; if self._slotMenu then self._slotMenu:Hide() end
    self:CancelModelRefresh()
    if self._playfield and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._playfield)
    end
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
    self._menuOpen=false; if self._slotMenu then self._slotMenu:Hide() end
    self._startActive = true
    if self._logo then self._logo:Hide() end
    if self._borderFrame then self._borderFrame:Show() end
    if self._playfield then self._playfield:Show() end
    self:_UpdateControlsBar()
    self:UpdateBoard(gs)
    self:_RefreshModels(gs)
end

function R:Render()
    local E = ArcadiaNexus.TC_Engine
    if not E or E.mode == "hotseat" then return end
    local v = E:GetView()
    if not v then return end
    if v.state == "IDLE" or v.state == "ABORTED" then
        self:EnterIdleState()
        return
    end
    self:_UpdateControlsBar()
    if v.state == "LOBBY" then
        self.state = "LOBBY"
        if self._playfield then self._playfield:Hide() end
        if self._logo then self._logo:Show() end
        if self._borderFrame then self._borderFrame:Show() end
        return
    end
    if v.state == "PLAYING" or v.state == "FINISHED" then
        local board = E:GetBoardState()
        if not board then return end
        if self._logo then self._logo:Hide() end
        if self._borderFrame then self._borderFrame:Show() end
        if self._playfield then self._playfield:Show() end
        self:UpdateBoard(board)
        self:_ApplyCharModels(board, false)
        if v.state == "FINISHED" then
            self.state = "FINISHED"
        else
            self.state = "PLAYING"
        end
    end
end

function R:ShowMatchResult(result, state)
    self.state = "FINISHED"
    state = state or {}
    local E = ArcadiaNexus.TC_Engine
    self:UpdateBoard(state)
    if not self._playfield then return end
    local UI = ArcadiaNexus.UI
    local loc = ArcadiaNexus.GetLocaleTable("TAVERNCARDS") or {}
    local uiLoc = ArcadiaNexus.GetLocaleTable("UI") or {}
    local title, titleColor
    if result == "WIN" then
        title = loc.result_mp_win or loc.result_win or "|cffffd700Sieg!|r"
        titleColor = { 1, 0.84, 0 }
    else
        title = loc.result_mp_loss or loc.result_lose or "|cffff4444Niederlage!|r"
        titleColor = { 1, 0.3, 0.3 }
        result = "LOSS"
    end
    UI.ShowArcadeResult(self._playfield, {
        title = title,
        titleColor = titleColor,
        subtitle = loc.result_round or "",
        gameId = "TAVERNCARDS",
        difficulty = "normal",
        result = result,
        hideHighscore = true,
        L = loc,
        onRetry = function()
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.Rematch then Shell.Rematch("TAVERNCARDS") end
        end,
        onExit = function()
            if E then E:StopGame() end
        end,
        buttons = {
            {
                label = uiLoc.btn_new_game or loc.btn_new_game,
                onClick = function()
                    local Shell = ArcadiaNexus.MatchShell
                    if Shell and Shell.Rematch then Shell.Rematch("TAVERNCARDS") end
                end,
            },
            {
                label = uiLoc.btn_exit or loc.btn_exit or loc.btn_stop,
                onClick = function()
                    if E then E:StopGame() end
                end,
            },
        },
    })
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
    local human = gs.players and gs.players[gs.localSeat or 1]
    if human and human.charDef then
        if not applySlot(self._charSlots.player, human.charDef) then allOk = false end
    end
    local slotI = 1
    for i = 1, (gs.playerCount or 0) do
        if i ~= (gs.localSeat or 1) then
            local slot = self._charSlots.ai[slotI]
            local p = gs.players[i]
            if slot and p and p.charDef and not applySlot(slot, p.charDef) then allOk = false end
            slotI = slotI + 1
        end
    end
    for i = slotI, 3 do
        local slot = self._charSlots.ai[i]
        if slot then
            slot.frame:Hide()
            slot.model:Hide()
        end
    end
    return allOk
end

function R:CancelModelRefresh()
    if self._modelGuard then self._modelGuard:Cancel() end
    local function cancel(slot)
        local model = slot and slot.model
        if model and model._tcRefreshGuard then model._tcRefreshGuard:Cancel() end
        if model then model._tcAnimLock = nil end
    end
    cancel(self._charSlots.player)
    for _, slot in pairs(self._charSlots.ai) do cancel(slot) end
end

function R:_RefreshModels(gs)
    if not gs then return end
    self:CancelModelRefresh()
    self._modelGuard = self._modelGuard or ArcadiaNexus.TimerGuard.New()
    local guard = self._modelGuard
    local engine = ArcadiaNexus.TC_Engine
    local sid, node = engine._sessionId, engine.match
    local attempt = 0
    local maxAttempts = 6
    local function step()
        if not ArcadiaNexus.GameSession:IsSession(engine, sid) or engine.match ~= node then return end
        if not node and engine.gameState ~= gs then return end
        if not R._playfield then return end
        if not R._playfield:IsShown() then
            if attempt < maxAttempts then
                attempt = attempt + 1
                guard:After(0.1, step)
            end
            return
        end
        attempt = attempt + 1
        R:_ApplyCharModels(node and engine:GetBoardState() or gs, attempt > 1)
        if attempt < maxAttempts then
            guard:After(0.12, step)
        end
    end
    guard:After(0, step)
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
            local playable = ArcadiaNexus.TC_Logic:CanPlayIndex(gs,gs.localSeat or 1,entry.idx) and isHumanTurn and ArcadiaNexus.TC_Engine.state=="PLAYING"
            cf._tex:SetAlpha(playable and 1 or 0.55)
            local idx = entry.idx
            cf:SetScript("OnClick", function()
                if playable then ArcadiaNexus.TC_Engine:PlayerPlayCard(idx, nil) end
            end)
            self:_ApplyHandCardHover(cf, anchor, baseLevel + j)
            local hover=cf:GetScript("OnEnter"); local leave=cf:GetScript("OnLeave")
            cf:SetScript("OnEnter",function(frame) if hover then hover(frame) end; R:ShowCardTooltip(frame,entry.card,playable) end)
            cf:SetScript("OnLeave",function(frame) if leave then leave(frame) end; if GameTooltip then GameTooltip:Hide() end end)
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
    local localSeat = (gs and gs.localSeat) or 1
    if playerIndex == localSeat then
        local slot = self._charSlots.player
        if slot then Npc:PlayAnim(slot.model, "play"); from = slot.model end
    else
        local n = 0
        for i = 1, (gs.playerCount or 0) do
            if i ~= localSeat then
                n = n + 1
                if i == playerIndex then
                    local slot = self._charSlots.ai[n]
                    if slot then Npc:PlayAnim(slot.model, "play"); from = slot.model end
                    break
                end
            end
        end
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
    local localSeat = gs.localSeat or 1
    local human = gs.players[localSeat]
    if not human then return end
    local isHumanTurn = gs.currentPlayer == localSeat and not human.isAI
    local status = gs.turnNotice or (isHumanTurn and L("lbl_your_turn") or L("lbl_wait_turn"))
    if gs.currentPlayer ~= localSeat and not gs.turnNotice then
        local other = gs.players[gs.currentPlayer]
        status = string.format(L("lbl_wait_turn"), (other and other.name) or "")
    end
    local color=ac and L("color_"..ac) or "–"
    status=status.." · "..L("lbl_active_color")..": "..color
    if (gs.pendingDraw or 0)>0 then status=status.." · +"..gs.pendingDraw end
    self._statusFS:SetText(status)
    if self._pointsFS then
        local entries={}; for _,p in ipairs(gs.players) do entries[#entries+1]=p.name..": "..p.score end
        self._pointsFS:SetText(gs.gameMode=="multi" and (L("lbl_round").." "..gs.roundNumber.." · "..L("lbl_target").." "..gs.pointTarget.."\n"..table.concat(entries," · ")) or "")
    end
    local pSlot = self._charSlots.player
    if pSlot and human.charDef then
        pSlot.nameFS:SetText(human.name)
        pSlot.frame:Show()
    end
    local slotI = 1
    for i = 1, gs.playerCount do
        if i ~= localSeat then
            local slot = self._charSlots.ai[slotI]
            local p = gs.players[i]
            if slot and p then
                slot.frame:Show()
                slot.nameFS:SetText(p.name)
                if slot.countFS then
                    slot.countFS:SetText(L("lbl_cards") .. ": " .. tostring(p.handCount or #p.hand))
                end
            end
            slotI = slotI + 1
        end
    end
    for i = slotI, 3 do
        local slot = self._charSlots.ai[i]
        if slot then
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
    local showUno = uw and uw.playerIndex == localSeat and not uw.resolved
    local showCatch = uw and uw.playerIndex ~= localSeat and not uw.resolved
    if self._unoBtn then self._unoBtn:SetShown(showUno) end
    if self._catchBtn then self._catchBtn:SetShown(showCatch) end
    if self._drawBtn then
        local canDraw = isHumanTurn and not gs.pendingColorPick and not gs.unoWindow
            and not gs.hasDrawnThisTurn and not gs.drawnThisTurn and not gs.wild4Challengable and ArcadiaNexus.TC_Engine.state=="PLAYING"
        self._drawBtn:SetShown(canDraw)
    end
    if self._passBtn then
        self._passBtn:SetShown(isHumanTurn and gs.drawnThisTurn~=nil and not gs.pendingColorPick and not gs.unoWindow)
    end
    if self._colorPicker then
        if gs.pendingColorPick and gs.pendingColorPick.playerIndex == localSeat then self._colorPicker:Show()
        else self._colorPicker:Hide() end
    end
    local showCh = gs.wild4Challengable and gs.currentPlayer == localSeat
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
    local win = gs.result=="WIN"
    UI.ShowArcadeResult(parent, {
        gameId = "TAVERNCARDS", difficulty = "solo_"..gs.difficulty,
        xp=ArcadiaNexus.TC_Engine._lastResult and ArcadiaNexus.TC_Engine._lastResult.awardedXP or 0,
        gold=ArcadiaNexus.TC_Engine._lastResult and ArcadiaNexus.TC_Engine._lastResult.awardedGold or 0,
        result = win and "WIN" or "LOSS", hideHighscore = true,
        subtitle = gs.forfeited and L("result_forfeit") or gs.players[winnerIndex].name .. " +" .. tostring(roundPts or 0),
        L = ArcadiaNexus.GetLocaleTable("TAVERNCARDS"),
        onRetry = function()
            ArcadiaNexus.TC_Engine:StopGame()
            R:EnterSlotMenu()
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

function R:RefreshDisplayOptions()
    local S=ArcadiaNexus.TC_Settings
    if self._rulesBtn then self._rulesBtn:SetShown(S:Get("showHouseRulesButton")~=false) end
    local owner=GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()
    if owner and ((S:Get("showCardTooltips")==false and owner==self._cardTooltipOwner)
        or (S:Get("showHouseRulesButton")==false and owner==self._rulesBtn)) then GameTooltip:Hide() end
end
function R:ShowCardTooltip(frame,card,playable)
    if not GameTooltip or ArcadiaNexus.TC_Settings:Get("showCardTooltips")==false then return end
    self._cardTooltipOwner=frame
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT")
    GameTooltip:SetText(playable and L("tooltip_playable") or L("tooltip_unavailable"),1,0.82,0)
    GameTooltip:Show()
end
function R:ShowRulesTooltip(frame)
    if not GameTooltip or ArcadiaNexus.TC_Settings:Get("showHouseRulesButton")==false then return end
    local gs=ArcadiaNexus.TC_Engine:GetBoardState(); if not gs then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText(L("box_rules"))
    local labels={stackDraw2="rule_stack2",stackDraw4="rule_stack4",playDrawn="rule_play_drawn",unoCallRule="rule_uno",challengeDraw4="rule_challenge"}
    for _,key in ipairs({"stackDraw2","stackDraw4","playDrawn","unoCallRule","challengeDraw4"}) do GameTooltip:AddLine(L(labels[key])..": "..L(gs.rules[key] and "rule_on" or "rule_off"),1,1,1,true) end
    GameTooltip:AddLine(L("guide_stack_challenge"),1,1,1,true); GameTooltip:Show()
end
function R:ConfirmForfeit(sid,runId)
    local UI=ArcadiaNexus.UI
    UI.ShowChoicePopup({parent=self._playfield,title=L("confirm_forfeit"),body=L("confirm_forfeit_body"),buttons={
        {label=L("btn_forfeit"),onClick=function() UI.HideChoicePopup(R._playfield); ArcadiaNexus.TC_Engine:ConfirmForfeit(sid,runId) end},
        {label=L("btn_cancel"),onClick=function() UI.HideChoicePopup(R._playfield) end},
    }})
end
function R:ShowResultPending()
    ArcadiaNexus.UI.ShowArcadeResult(self._playfield,{title=L("result_pending"),hideHighscore=true,buttons={
        {label=L("btn_retry"),onClick=function() ArcadiaNexus.TC_Engine:RetryResult() end},
        {label=L("btn_exit"),onClick=function() ArcadiaNexus.TC_Engine:SaveAndPause() end},
    }})
end
