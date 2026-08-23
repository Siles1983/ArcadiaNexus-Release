-- ============================================================
--  Azeroth's Tiny Guardians – Renderer.lua
--  Phase 2–10 + 3D Pet (PlayerModel), 2D-Fallback für Stall/Adoption
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.ATG_Renderer = {}
local R = ArcadiaNexus.ATG_Renderer

local GOLD = { 0.90, 0.75, 0.30, 1 }

local CFG = {
    field_w        = 602,
    field_h        = 498,
    field_ofs_x    = -4,
    field_ofs_y    = 40,
    bg_w           = 600,
    bg_h           = 490,
    bg_ofs_x       = 4,
    bg_ofs_y       = 8,
    bg_alpha       = 1.0,
    border_w       = 795,
    border_h       = 550,
    border_ofs_x   = 5,
    border_ofs_y   = -23,
    border_alpha   = 1.0,
    logo_w         = 512,
    logo_h         = 512,
    logo_x         = 0,
    logo_y         = -18,
    logo_alpha     = 1.0,
    pet_icon_size  = 80,
    pet_model_w    = 200,
    pet_model_h    = 200,
    pet_icon_y     = -38,
    adopt_icon_sz  = 44,
    adopt_card_w   = 150,
    adopt_card_h   = 86,
    adopt_cols     = 2,
    adopt_start_y  = -78,
    adopt_col_gap  = 168,
    adopt_row_gap  = 94,
    bar_w          = 200,
    bar_h          = 10,
    bar_gap        = 14,
    xp_bar_w       = 200,
    xp_bar_h       = 8,
    needs_box_w    = 360,
    needs_box_pad  = 12,
    needs_box_gap  = 10,
    ctrl_btn_w     = 144,
    ctrl_btn_h     = 32,
    btn_w          = 88,
    btn_h          = 26,
    action_block_gap = 14,
    action_btns = {
        feed  = { x = -96, y = 10 },
        pet   = { x = 0,   y = 10 },
        sleep = { x = 96,  y = 10 },
        wash  = { x = -96, y = -22 },
        train = { x = 0,   y = -22 },
        heal  = { x = 96,  y = -22 },
    },
    traits_gap     = 10,
    retire_gap     = 8,
    emote_size     = 20,
    bubble_w       = 150,
    stall_btn_w    = 88,
    stall_btn_h    = 26,
    stall_row_h    = 50,
    stall_row_max  = 8,
    stall_list_y   = -56,
    stall_model_w  = 160,
    stall_model_h  = 160,
    cam_reset_sec  = 10,
}

local ATG_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\AzerothsTinyGuardians\\assets\\"
local ATG_ASSETS = {
    logo       = ATG_PATH .. "logo\\logo_atg",
    border     = ATG_PATH .. "border\\border_atg",
    background = ATG_PATH .. "background\\background_atg",
}

local EMOTE_DURATION   = 2.5
local BUBBLE_DURATION  = 3.5
local SLEEP_EMOTE_EVERY = 4.0

local EMOTE_DEFS = {
    hearts   = { texture = "Interface\\Icons\\Spell_Holy_Heal",          r = 1.0,  g = 0.55, b = 0.75 },
    question = { texture = "Interface\\Icons\\INV_Misc_QuestionMark" },
    anger    = { texture = "Interface\\Icons\\Ability_Warrior_Anger" },
    sick     = { texture = "Interface\\Icons\\Spell_Shadow_Possession", r = 0.55, g = 1.0,  b = 0.55 },
    stars    = { texture = "Interface\\Icons\\Spell_Holy_ChampionsGrace", r = 1.0, g = 0.88, b = 0.25 },
    sleep    = { text = "Z", r = 0.92, g = 0.92, b = 1.0 },
}

local ACTION_EMOTES = {
    pet = "hearts", sleep = "sleep", train = "hearts",
}

local NEED_KEYS = { "hunger", "happiness", "energy", "health", "hygiene" }
local NEED_LABEL_KEYS = {
    hunger = "need_hunger", happiness = "need_happiness",
    energy = "need_energy", health = "need_health", hygiene = "need_hygiene",
}

local ACTION_ROWS = {
    { "feed", "pet", "sleep" },
    { "wash", "train", "heal" },
}

R.frame           = nil
R._canvas         = nil
R._fieldFrame     = nil
R._bgTex          = nil
R._borderFrame    = nil
R._logoTex        = nil
R._petIconFrame   = nil
R._petIcon        = nil
R._petModel       = nil
R._statusFS       = nil
R._phaseFS        = nil
R._xpFS           = nil
R._xpBarFill      = nil
R._adoptPanel     = nil
R._playPanel      = nil
R._needBars       = {}
R._actionBtns     = {}
R._traitsFS       = nil
R._evolveParticles = nil
R._evolvePulse    = 0
R._lastPhase      = nil
R._emoteFrame     = nil
R._emoteTex       = nil
R._emoteFS        = nil
R._emoteLife      = 0
R._bubbleFrame    = nil
R._bubbleText     = nil
R._bubbleLife     = 0
R._sleepEmoteAccum = 0
R._stallPanel     = nil
R._stallRows      = {}
R._stallDetail    = nil
R._stallBtn       = nil
R._startBtn       = nil
R._controlsFrame  = nil
R._retireBtn      = nil
R._retireConfirm  = nil
R._nameDialog     = nil
R._nameEdit       = nil
R._pendingAdoptType = nil
R._stallModel     = nil
R._stallModelIcon = nil
R._stallCareBtn   = nil
R._stallNewBtn    = nil
R._camGuard       = nil
R._modelDrag      = nil
R._initialized    = false

local _L = nil
local function L(key)
    if not _L then
        _L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("AZEROTHTINYGUARDIANS") or {}
    end
    return _L[key] or key
end

local function StageLabel(stage)
    if stage == "YOUTH" then return L("stage_youth") end
    if stage == "ADULT" then return L("stage_adult") end
    return L("stage_baby")
end

local TRAIT_LOCALE = {
    GREEDY        = "trait_greedy",
    PICKY         = "trait_picky",
    WARRIOR       = "trait_warrior",
    CLINGY        = "trait_clingy",
    HYPOCHONDRIAC = "trait_hypochondriac",
    LAZY          = "trait_lazy",
    BALANCED      = "trait_balanced",
}

local function TraitLabel(traitId)
    return L(TRAIT_LOCALE[traitId] or traitId)
end

local function FormatTraits(traits)
    if not traits or #traits == 0 then return nil end
    local parts = {}
    for _, traitId in ipairs(traits) do
        parts[#parts + 1] = TraitLabel(traitId)
    end
    return table.concat(parts, ", ")
end

function R:Init()
    if self._initialized then return end
    self._initialized = true
    self:_CreateMainFrame()
    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateAdoptPanel()
    self:_CreatePlayPanel()
    self:_CreateStallPanel()
    self:_CreateNameDialog()
    self:_CreateControls()
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_ATG_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._atgContainer = f end

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("AZEROTHTINYGUARDIANS", ArcadiaNexus.ATG_Engine, function(eng)
            if eng.state == "PLAYING" then
                eng:SaveAndPause()
            end
        end)
        R:ClearPetModel()
        R:ClearStallModel()
        if R._camGuard then R._camGuard:Cancel() end
        R:EnterIdleState()
    end)

    f:SetScript("OnShow", function()
        R:EnterIdleState()
    end)
end

function R:_CreateFieldFrame()
    local canvas = self._canvas
    if not canvas or self._fieldFrame then return end

    local pf = CreateFrame("Frame", nil, canvas)
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("TOP", canvas, "TOP", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = pf
end

function R:_CreateControls()
    local UI = ArcadiaNexus.UI
    if not UI or not self.frame or self._controlsFrame then return end

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local startBtn = UI.CreateArcadiaButton(cf, L("btn_start"), CFG.ctrl_btn_w, CFG.ctrl_btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetLabel(L("btn_start"))
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.ATG_Engine
        if not Eng then return end
        if Eng.state == "PLAYING" then
            Eng:QuitToIdle()
        else
            Eng:StartGame()
        end
    end)
    self._startBtn = startBtn

    local stallBtn = UI.CreateArcadiaButton(cf, L("btn_stall"), CFG.ctrl_btn_w, CFG.ctrl_btn_h)
    stallBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[3], bar.y.button)
    stallBtn:SetLabel(L("btn_stall"))
    stallBtn:Hide()
    stallBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.ATG_Engine
        if Eng then Eng:OpenStall() end
    end)
    self._stallBtn = stallBtn
    self:_RefreshControls()
end

function R:_RefreshControls()
    local Eng = ArcadiaNexus.ATG_Engine
    local S = ArcadiaNexus.ATG_Settings
    local stallOpen = self._stallPanel and self._stallPanel:IsShown()

    if self._startBtn then
        if Eng and Eng.state == "PLAYING" then
            self._startBtn:SetLabel(L("btn_stop"))
        else
            self._startBtn:SetLabel(L("btn_start"))
        end
    end

    if self._stallBtn then
        local started = Eng and Eng.state == "PLAYING"
        local hasPets = S and S.HasAnyPets and S:HasAnyPets()
        if stallOpen or not started or not hasPets then
            self._stallBtn:Hide()
        else
            self._stallBtn:Show()
        end
    end
end

function R:_EnsureCamGuard()
    if not self._camGuard and ArcadiaNexus.TimerGuard then
        self._camGuard = ArcadiaNexus.TimerGuard.New()
    end
    return self._camGuard
end

function R:_ScheduleCamReset(which)
    local guard = self:_EnsureCamGuard()
    if not guard then return end
    guard:Cancel()
    local key = which or "play"
    guard:After(CFG.cam_reset_sec, function()
        R:_ResetModelRotation(key)
    end)
end

function R:_ResetModelRotation(which)
    local model, default
    if which == "stall" then
        model, default = self._stallModel, self._stallRotDefault
        self._stallRotation = default
    else
        model, default = self._petModel, self._playRotDefault
        self._playRotation = default
    end
    if model and model.SetRotation and default then
        model:SetRotation(default)
    end
end

function R:_EndModelDrag(which)
    local model = (which == "stall") and self._stallModel or self._petModel
    if model then
        model:SetScript("OnUpdate", nil)
    end
    if self._modelDrag and (not which or self._modelDrag.which == which) then
        self._modelDrag = nil
    end
    if which then
        self:_ScheduleCamReset(which)
    end
end

function R:_EnableModelDrag(model, which)
    if not model or not model.EnableMouse then return end
    model:EnableMouse(true)
    model:SetScript("OnLeave", nil)
    model:SetScript("OnMouseDown", function(_, button)
        if button and button ~= "LeftButton" then return end
        local x = GetCursorPosition()
        local rot
        if which == "stall" then
            rot = R._stallRotation or R._stallRotDefault or 0
        else
            rot = R._playRotation or R._playRotDefault or 0
        end
        R._modelDrag = {
            which = which,
            lastX = x,
            rot   = rot,
        }
        local guard = R:_EnsureCamGuard()
        if guard then guard:Cancel() end
        model:SetScript("OnUpdate", function()
            local drag = R._modelDrag
            if not drag or drag.which ~= which then return end
            if not IsMouseButtonDown("LeftButton") then
                R:_EndModelDrag(which)
                return
            end
            local cx = GetCursorPosition()
            local dx = (cx - drag.lastX) * 0.01
            drag.lastX = cx
            drag.rot = drag.rot + dx
            if model.SetRotation then
                model:SetRotation(drag.rot)
            end
            if which == "stall" then
                R._stallRotation = drag.rot
            else
                R._playRotation = drag.rot
            end
        end)
    end)
    model:SetScript("OnMouseUp", function()
        R:_EndModelDrag(which)
    end)
end

function R:_CreateNameDialog()
    local pf = self._fieldFrame
    local UI = ArcadiaNexus.UI
    if not pf or not UI or self._nameDialog then return end

    local dlg = CreateFrame("Frame", nil, pf, "BackdropTemplate")
    dlg:SetSize(280, 140)
    dlg:SetPoint("CENTER", pf, "CENTER", 0, 20)
    dlg:SetFrameLevel(pf:GetFrameLevel() + 30)
    dlg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.08, 0.07, 0.12, 0.97)
    dlg:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    dlg:Hide()
    self._nameDialog = dlg

    local hint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", dlg, "TOP", 0, -14)
    hint:SetText(L("lbl_name_hint"))

    local eb = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    eb:SetSize(200, 24)
    eb:SetPoint("TOP", hint, "BOTTOM", 0, -12)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(16)
    eb:SetFontObject("GameFontHighlight")
    eb:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
        R:HideAdoptNameDialog()
    end)
    eb:SetScript("OnEnterPressed", function()
        R:ConfirmAdoptName()
    end)
    self._nameEdit = eb

    local okBtn = UI.CreateArcadiaButton(dlg, L("btn_confirm"), 90, CFG.btn_h)
    okBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 24, 14)
    okBtn:SetLabel(L("btn_confirm"))
    okBtn:SetScript("OnClick", function()
        R:ConfirmAdoptName()
    end)

    local cancelBtn = UI.CreateArcadiaButton(dlg, L("btn_cancel"), 90, CFG.btn_h)
    cancelBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -24, 14)
    cancelBtn:SetLabel(L("btn_cancel"))
    cancelBtn:SetScript("OnClick", function()
        R:HideAdoptNameDialog()
    end)
end

function R:ShowAdoptNameDialog(petType)
    local P = ArcadiaNexus.ATG_PetData
    if not petType or not self._nameDialog or not self._nameEdit then return end
    self._pendingAdoptType = petType
    local defaultName = P and P:GetDefaultName(petType) or ""
    self._nameEdit:SetText(defaultName)
    self._nameDialog:Show()
    self._nameEdit:SetFocus()
    self._nameEdit:HighlightText()
end

function R:HideAdoptNameDialog()
    self._pendingAdoptType = nil
    if self._nameEdit then
        self._nameEdit:ClearFocus()
        self._nameEdit:SetText("")
    end
    if self._nameDialog then self._nameDialog:Hide() end
end

function R:ConfirmAdoptName()
    local petType = self._pendingAdoptType
    local name = self._nameEdit and self._nameEdit:GetText() or ""
    self:HideAdoptNameDialog()
    local Eng = ArcadiaNexus.ATG_Engine
    if Eng and petType then
        Eng:AdoptPet(petType, name)
    end
end

function R:ClearStallModel()
    if self._stallModel then
        if self._stallModel.ClearModel then self._stallModel:ClearModel() end
        self._stallModel:Hide()
    end
    if self._stallModelIcon then
        self._stallModelIcon:Hide()
    end
end

function R:_ApplyStallModel(entry)
    if not entry then return end
    local P = ArcadiaNexus.ATG_PetData
    local stage = entry.stage or "ADULT"
    if entry.status == "retired" then stage = "ADULT" end

    if P and self._stallModel then
        local ok = P:ApplyModel(self._stallModel, entry.petType, stage)
        local def = P.GetModelDef and P:GetModelDef(entry.petType, stage)
        self._stallRotDefault = (def and def.rotation) or 0
        self._stallRotation = self._stallRotDefault
        if ok then
            self._stallModel:Show()
            if self._stallModelIcon then self._stallModelIcon:Hide() end
            return
        end
        self._stallModel:Hide()
    end
    if self._stallModelIcon and P then
        self._stallModelIcon:SetTexture(P:GetIcon(entry.petType, stage))
        self._stallModelIcon:Show()
    end
end

function R:_AnchorNeedsBox()
    if not self._needsBox or not self._nameFS then return end
    if self._phaseFS and self._phaseFS:IsShown() then
        self._needsBox:SetPoint("TOP", self._phaseFS, "BOTTOM", 0, -CFG.needs_box_gap)
    else
        self._needsBox:SetPoint("TOP", self._nameFS, "BOTTOM", 0, -CFG.needs_box_gap)
    end
    if self._xpFS then
        self._xpFS:SetPoint("TOP", self._needsBox, "TOP", 0, -CFG.needs_box_pad)
    end
end

function R:_CreateBackground()
    local pf = self._fieldFrame
    if not pf or self._bgTex then return end

    local tex = pf:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(ATG_ASSETS.background)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    if self._borderFrame then return end
    local pf = self._fieldFrame
    if not pf then return end

    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetFrameLevel(pf:GetFrameLevel() + 10)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", pf, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)

    local borderTex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    borderTex:SetTexture(ATG_ASSETS.border)
    borderTex:SetAllPoints(borderFrame)
    borderTex:SetAlpha(CFG.border_alpha)

    self._borderFrame = borderFrame
end

function R:_CreateLogo()
    if self._logoTex then return end
    local UI = ArcadiaNexus.UI
    if not UI or not UI.CreateGameLogo then return end

    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        ATG_ASSETS.logo,
        {
            w     = CFG.logo_w,
            h     = CFG.logo_h,
            x     = CFG.logo_x,
            y     = CFG.logo_y,
            alpha = CFG.logo_alpha,
        }
    )
end

function R:_UpdateBrandingVisibility()
    local Eng = ArcadiaNexus.ATG_Engine
    local showLogo = not Eng or Eng.state == "IDLE"

    if self._logoTex then
        if showLogo then
            self._logoTex:Show()
        else
            self._logoTex:Hide()
        end
    end
    self:_RefreshControls()
end

function R:_CreateAdoptPanel()
    local pf = self._fieldFrame
    if not pf or self._adoptPanel then return end

    local panel = CreateFrame("Frame", nil, pf)
    panel:SetAllPoints(pf)
    self._adoptPanel = panel

    local msg = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    msg:SetPoint("TOP", pf, "TOP", 0, -36)
    msg:SetWidth(CFG.field_w - 40)
    msg:SetWordWrap(true)
    msg:SetText(L("state_adopting"))
    self._statusFS = msg

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", msg, "BOTTOM", 0, -4)
    hint:SetText(L("lbl_adopt_hint"))
    self._adoptHintFS = hint

    local P = ArcadiaNexus.ATG_PetData
    if not P then return end

    local cols = CFG.adopt_cols
    for i, petType in ipairs(P.adoptionOrder) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local xOff = -CFG.adopt_col_gap / 2 + col * CFG.adopt_col_gap
        local yOff = CFG.adopt_start_y - row * CFG.adopt_row_gap

        local card = CreateFrame("Button", nil, panel, "BackdropTemplate")
        card:SetSize(CFG.adopt_card_w, CFG.adopt_card_h)
        card:SetPoint("TOP", pf, "TOP", xOff, yOff)
        card:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        card:SetBackdropColor(0.14, 0.13, 0.18, 0.95)
        card:SetBackdropBorderColor(0.45, 0.40, 0.55, 1)

        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(CFG.adopt_icon_sz, CFG.adopt_icon_sz)
        icon:SetPoint("TOP", card, "TOP", 0, -8)
        icon:SetTexture(P:GetIcon(petType, "BABY"))

        local info = P.types[petType]
        local nameFS = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetPoint("TOP", icon, "BOTTOM", 0, -4)
        nameFS:SetText(info and L(info.localeKey) or petType)

        local adoptFS = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        adoptFS:SetPoint("BOTTOM", card, "BOTTOM", 0, 6)
        adoptFS:SetTextColor(0.85, 0.75, 0.35, 1)
        adoptFS:SetText(L("btn_adopt"))

        card:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.75, 0.65, 0.25, 1)
        end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.45, 0.40, 0.55, 1)
        end)
        card:SetScript("OnClick", function()
            R:ShowAdoptNameDialog(petType)
        end)
    end
end

function R:_CreatePlayPanel()
    local pf = self._fieldFrame
    if not pf or self._playPanel then return end

    local panel = CreateFrame("Frame", nil, pf)
    panel:SetSize(CFG.field_w, CFG.field_h)
    panel:SetPoint("CENTER", pf, "CENTER")
    panel:Hide()
    self._playPanel = panel

    local displayFrame = CreateFrame("Frame", nil, panel)
    displayFrame:SetSize(CFG.pet_model_w, CFG.pet_model_h)
    displayFrame:SetPoint("TOP", pf, "TOP", 0, CFG.pet_icon_y)
    self._petIconFrame = displayFrame

    local model = CreateFrame("PlayerModel", nil, displayFrame)
    model:SetAllPoints(displayFrame)
    model:SetFrameLevel(displayFrame:GetFrameLevel() + 1)
    model:Hide()
    self._petModel = model
    self:_EnableModelDrag(model, "play")

    local iconTex = displayFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(displayFrame)
    iconTex:Hide()
    self._petIcon = iconTex

    self:_EnsureCommUI(panel, displayFrame)

    local nameFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFS:SetPoint("TOP", displayFrame, "BOTTOM", 0, -6)
    self._nameFS = nameFS

    local phaseFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    phaseFS:SetPoint("TOP", nameFS, "BOTTOM", 0, -2)
    phaseFS:Hide()
    self._phaseFS = phaseFS

    local needsBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    needsBox:SetWidth(CFG.needs_box_w)
    needsBox:SetPoint("TOP", nameFS, "BOTTOM", 0, -CFG.needs_box_gap)
    needsBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    needsBox:SetBackdropColor(0, 0, 0, 0.45)
    needsBox:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    self._needsBox = needsBox

    local pad = CFG.needs_box_pad
    local xpFS = needsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpFS:SetPoint("TOP", needsBox, "TOP", 0, -pad)
    self._xpFS = xpFS

    local xpBg = CreateFrame("Frame", nil, needsBox, "BackdropTemplate")
    xpBg:SetSize(CFG.xp_bar_w, CFG.xp_bar_h)
    xpBg:SetPoint("TOP", xpFS, "BOTTOM", 0, -6)
    xpBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    xpBg:SetBackdropColor(0.10, 0.10, 0.14, 0.9)
    xpBg:SetBackdropBorderColor(0.35, 0.35, 0.45, 1)
    local xpFill = xpBg:CreateTexture(nil, "ARTWORK")
    xpFill:SetPoint("LEFT", xpBg, "LEFT", 1, 0)
    xpFill:SetHeight(CFG.xp_bar_h - 2)
    xpFill:SetColorTexture(0.45, 0.55, 0.95, 1)
    self._xpBarBg   = xpBg
    self._xpBarFill = xpFill

    local traitsFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    traitsFS:SetWidth(CFG.field_w - 40)
    traitsFS:SetWordWrap(true)
    traitsFS:Hide()
    self._traitsFS = traitsFS

    local prevBar = xpBg
    for i, needKey in ipairs(NEED_KEYS) do
        local lbl = needsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetWidth(72)
        lbl:SetJustifyH("RIGHT")
        lbl:SetText(L(NEED_LABEL_KEYS[needKey]))

        local barBg = CreateFrame("Frame", nil, needsBox, "BackdropTemplate")
        barBg:SetSize(CFG.bar_w, CFG.bar_h)
        barBg:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        barBg:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
        barBg:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

        local barFill = barBg:CreateTexture(nil, "ARTWORK")
        barFill:SetPoint("LEFT", barBg, "LEFT", 1, 0)
        barFill:SetHeight(CFG.bar_h - 2)
        barFill:SetColorTexture(0.35, 0.75, 0.45, 1)

        local valFS = needsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valFS:SetWidth(40)
        valFS:SetJustifyH("LEFT")

        if i == 1 then
            barBg:SetPoint("TOPLEFT", prevBar, "BOTTOMLEFT", 0, -12)
        else
            barBg:SetPoint("TOPLEFT", prevBar, "BOTTOMLEFT", 0, -CFG.bar_gap)
        end
        lbl:SetPoint("RIGHT", barBg, "LEFT", -8, 0)
        valFS:SetPoint("LEFT", barBg, "RIGHT", 6, 0)
        prevBar = barBg

        self._needBars[needKey] = {
            fill = barFill,
            bg   = barBg,
            val  = valFS,
        }
    end

    self._needBarsAnchor = prevBar
    local boxBottomPad = pad + 4
    local topToXp = pad + 14 + 6 + CFG.xp_bar_h
    local barsH = 12 + #NEED_KEYS * CFG.bar_h + (#NEED_KEYS - 1) * CFG.bar_gap
    needsBox:SetHeight(topToXp + barsH + boxBottomPad)

    local UI = ArcadiaNexus.UI
    if not UI then return end

    local actionBlockH = CFG.btn_h + 32
    local actionBlock  = CreateFrame("Frame", nil, panel)
    actionBlock:SetSize(CFG.field_w, actionBlockH)
    actionBlock:SetPoint("TOP", needsBox, "BOTTOM", 0, -CFG.action_block_gap)
    self._actionBlock = actionBlock

    for _, row in ipairs(ACTION_ROWS) do
        for _, action in ipairs(row) do
            local pos = CFG.action_btns[action] or { x = 0, y = 0 }
            local label = L("btn_" .. action)
            local btn = UI.CreateArcadiaButton(panel, label, CFG.btn_w, CFG.btn_h)
            btn:SetPoint("TOP", actionBlock, "TOP", pos.x, pos.y)
            btn:SetLabel(label)
            btn:SetScript("OnClick", function()
                local Eng = ArcadiaNexus.ATG_Engine
                if Eng then Eng:DoAction(action) end
            end)
            self._actionBtns[action] = btn
        end
    end

    if UI then
        traitsFS:SetPoint("TOP", actionBlock, "BOTTOM", 0, -CFG.traits_gap)

        local retireBtn = UI.CreateArcadiaButton(panel, L("btn_retire"), CFG.btn_w + 20, CFG.btn_h)
        retireBtn:SetPoint("TOP", traitsFS, "BOTTOM", 0, -CFG.retire_gap)
        retireBtn:SetLabel(L("btn_retire"))
        retireBtn:Hide()
        retireBtn:SetScript("OnClick", function()
            local E = ArcadiaNexus.ATG_Engine
            if E then E:BeginRetire() end
        end)
        self._retireBtn = retireBtn

        local confirm = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        confirm:SetSize(280, 120)
        confirm:SetPoint("CENTER", pf, "CENTER", 0, 20)
        confirm:SetFrameLevel(panel:GetFrameLevel() + 20)
        confirm:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        confirm:SetBackdropColor(0.10, 0.09, 0.14, 0.97)
        confirm:SetBackdropBorderColor(0.55, 0.48, 0.65, 1)
        confirm:Hide()
        self._retireConfirm = confirm

        local confirmFS = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        confirmFS:SetPoint("TOP", confirm, "TOP", 0, -12)
        confirmFS:SetWidth(250)
        confirmFS:SetWordWrap(true)
        confirmFS:SetText(L("confirm_retire"))
        self._retireConfirmFS = confirmFS

        local okBtn = UI.CreateArcadiaButton(confirm, L("btn_confirm"), 90, CFG.btn_h)
        okBtn:SetPoint("BOTTOMLEFT", confirm, "BOTTOMLEFT", 16, 12)
        okBtn:SetLabel(L("btn_confirm"))
        okBtn:SetScript("OnClick", function()
            local E = ArcadiaNexus.ATG_Engine
            if E then E:ConfirmRetire() end
        end)

        local cancelBtn = UI.CreateArcadiaButton(confirm, L("btn_cancel"), 90, CFG.btn_h)
        cancelBtn:SetPoint("BOTTOMRIGHT", confirm, "BOTTOMRIGHT", -16, 12)
        cancelBtn:SetLabel(L("btn_cancel"))
        cancelBtn:SetScript("OnClick", function()
            local E = ArcadiaNexus.ATG_Engine
            if E then E:CancelRetire() end
        end)
    end
end

function R:_CreateStallPanel()
    local pf = self._fieldFrame
    if not pf or self._stallPanel then return end

    local panel = CreateFrame("Frame", nil, pf)
    panel:SetAllPoints(pf)
    panel:Hide()
    self._stallPanel = panel

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", pf, "TOP", 0, -36)
    title:SetText(L("lbl_stall"))

    local countFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countFS:SetPoint("TOP", title, "BOTTOM", 0, -4)
    self._stallCountFS = countFS

    local emptyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyFS:SetPoint("CENTER", pf, "CENTER", 0, 0)
    emptyFS:SetText(L("lbl_stall_empty"))
    emptyFS:Hide()
    self._stallEmptyFS = emptyFS

    local listArea = CreateFrame("Frame", nil, panel)
    listArea:SetSize(CFG.field_w - 40, CFG.stall_row_max * CFG.stall_row_h)
    listArea:SetPoint("TOP", pf, "TOP", 0, CFG.stall_list_y)
    self._stallListArea = listArea

    self._stallRows = {}
    for i = 1, CFG.stall_row_max do
        local row = CreateFrame("Button", nil, listArea, "BackdropTemplate")
        row:SetSize(CFG.field_w - 48, CFG.stall_row_h - 4)
        row:SetPoint("TOP", listArea, "TOP", 0, -(i - 1) * CFG.stall_row_h)
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        row:SetBackdropColor(0.14, 0.13, 0.18, 0.92)
        row:SetBackdropBorderColor(0.40, 0.36, 0.48, 1)
        row:Hide()

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", row, "LEFT", 8, 0)

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
        nameFS:SetWidth(280)
        nameFS:SetJustifyH("LEFT")

        local metaFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        metaFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2)
        metaFS:SetWidth(280)
        metaFS:SetJustifyH("LEFT")

        row:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.70, 0.62, 0.28, 1)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.40, 0.36, 0.48, 1)
        end)

        self._stallRows[i] = {
            frame  = row,
            icon   = icon,
            nameFS = nameFS,
            metaFS = metaFS,
        }
    end

    local detail = CreateFrame("Frame", nil, panel)
    detail:SetSize(CFG.field_w - 60, 300)
    detail:SetPoint("CENTER", pf, "CENTER", 0, -10)
    detail:Hide()
    self._stallDetail = detail

    local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOP", detail, "TOP", 0, -4)
    self._stallDetailTitle = detailTitle

    local modelFrame = CreateFrame("Frame", nil, detail)
    modelFrame:SetSize(CFG.stall_model_w, CFG.stall_model_h)
    modelFrame:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -28)
    self._stallModelFrame = modelFrame

    local stallModel = CreateFrame("PlayerModel", nil, modelFrame)
    stallModel:SetAllPoints(modelFrame)
    stallModel:Hide()
    self._stallModel = stallModel
    self:_EnableModelDrag(stallModel, "stall")

    local stallIcon = modelFrame:CreateTexture(nil, "ARTWORK")
    stallIcon:SetAllPoints(modelFrame)
    stallIcon:Hide()
    self._stallModelIcon = stallIcon

    local detailBody = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailBody:SetPoint("TOPLEFT", modelFrame, "TOPRIGHT", 12, 0)
    detailBody:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -8, 40)
    detailBody:SetWordWrap(true)
    detailBody:SetJustifyH("LEFT")
    self._stallDetailBody = detailBody

    local UI = ArcadiaNexus.UI
    if UI then
        local careBtn = UI.CreateArcadiaButton(detail, L("btn_care"), CFG.stall_btn_w + 20, CFG.stall_btn_h)
        careBtn:SetPoint("BOTTOM", detail, "BOTTOM", 0, 4)
        careBtn:SetLabel(L("btn_care"))
        careBtn:Hide()
        self._stallCareBtn = careBtn

        local newBtn = UI.CreateArcadiaButton(panel, L("btn_new_pet"), CFG.stall_btn_w + 24, CFG.stall_btn_h)
        newBtn:SetPoint("BOTTOM", pf, "BOTTOM", -90, 24)
        newBtn:SetLabel(L("btn_new_pet"))
        newBtn:SetScript("OnClick", function()
            local Eng = ArcadiaNexus.ATG_Engine
            if Eng then Eng:EnterAdopting() end
        end)
        self._stallNewBtn = newBtn

        local backBtn = UI.CreateArcadiaButton(panel, L("btn_back"), CFG.stall_btn_w + 16, CFG.stall_btn_h)
        backBtn:SetPoint("BOTTOM", pf, "BOTTOM", 90, 24)
        backBtn:SetLabel(L("btn_back"))
        backBtn:SetScript("OnClick", function()
            if R._stallDetail and R._stallDetail:IsShown() then
                R:HideStallDetail()
            else
                local Eng = ArcadiaNexus.ATG_Engine
                if Eng then Eng:CloseStall() end
            end
        end)
        self._stallBackBtn = backBtn
    end
end

function R:OpenStall()
    self:HideAdoptNameDialog()
    if self._retireConfirm then self._retireConfirm:Hide() end
    if self._adoptPanel then self._adoptPanel:Hide() end
    if self._playPanel then self._playPanel:Hide() end
    if self._stallPanel then
        self._stallPanel:Show()
        self:HideStallDetail()
        self:RefreshStallList()
    end
    self:_UpdateBrandingVisibility()
end

function R:CloseStall()
    if self._stallPanel then self._stallPanel:Hide() end
    self:HideStallDetail()
    self:_UpdateBrandingVisibility()
end

function R:HideStallDetail()
    if self._stallDetail then self._stallDetail:Hide() end
    if self._stallCareBtn then self._stallCareBtn:Hide() end
    self:ClearStallModel()
    if self._stallListArea then self._stallListArea:Show() end
    if self._stallEmptyFS and self._stallEmptyFS:IsShown() then
        -- keep empty visible
    elseif self._stallRows then
        for _, row in ipairs(self._stallRows) do
            if row.frame and row.frame.entry then
                row.frame:Show()
            end
        end
    end
end

function R:ShowStallDetail(entry)
    if not entry or not self._stallDetail then return end
    if self._stallListArea then self._stallListArea:Hide() end
    for _, row in ipairs(self._stallRows) do
        if row.frame then row.frame:Hide() end
    end
    if self._stallEmptyFS then self._stallEmptyFS:Hide() end

    local P = ArcadiaNexus.ATG_PetData
    local title = entry.title or entry.name or "?"
    if self._stallDetailTitle then
        self._stallDetailTitle:SetText(title)
    end

    local traitText = FormatTraits(entry.traits) or "-"
    local petLabel = entry.petType or "?"
    if P and P.types and P.types[entry.petType] then
        petLabel = L(P.types[entry.petType].localeKey)
    end

    local statusKey = (entry.status == "retired") and "lbl_retired" or "lbl_living"
    local lines = {
        string.format("%s: %s", L("lbl_stall_detail"), petLabel),
        string.format("%s: %s", L(statusKey), StageLabel(entry.stage or (entry.status == "retired" and "ADULT" or "BABY"))),
        string.format("%s: %s", L("lbl_traits"), traitText),
        string.format("XP: %d", entry.xp or 0),
    }
    if entry.status == "retired" then
        lines[#lines + 1] = string.format("%s: %s", L("lbl_retired_on"), entry.retiredAtText or "-")
    end
    if entry.traitCounters then
        lines[#lines + 1] = string.format(
            "fed:%d wash:%d train:%d pet:%d heal:%d sleep:%d",
            entry.traitCounters.fed or 0, entry.traitCounters.washed or 0,
            entry.traitCounters.trained or 0, entry.traitCounters.petted or 0,
            entry.traitCounters.healed or 0, entry.traitCounters.slept or 0
        )
    end

    if self._stallDetailBody then
        self._stallDetailBody:SetText(table.concat(lines, "\n"))
    end

    self:_ApplyStallModel(entry)

    if self._stallCareBtn then
        if entry.status ~= "retired" and entry.id then
            self._stallCareBtn:Show()
            self._stallCareBtn:SetScript("OnClick", function()
                local Eng = ArcadiaNexus.ATG_Engine
                if Eng then Eng:ResumePet(entry.id) end
            end)
        else
            self._stallCareBtn:Hide()
        end
    end

    self._stallDetail:Show()
end

function R:RefreshStallList()
    local S = ArcadiaNexus.ATG_Settings
    local P = ArcadiaNexus.ATG_PetData
    if not S or not self._stallRows then return end

    local stall = S:GetStall() or {}
    if self._stallCountFS then
        self._stallCountFS:SetText(string.format("%s: %d", L("lbl_stall_count"), #stall))
    end

    for _, row in ipairs(self._stallRows) do
        if row.frame then
            row.frame:Hide()
            row.frame.entry = nil
        end
    end

    if #stall == 0 then
        if self._stallEmptyFS then self._stallEmptyFS:Show() end
        return
    end
    if self._stallEmptyFS then self._stallEmptyFS:Hide() end

    local shown = math.min(#stall, CFG.stall_row_max)
    for i = 1, shown do
        local entry = stall[#stall - i + 1]
        local row = self._stallRows[i]
        if not entry or not row then break end

        row.frame.entry = entry
        if P then
            row.icon:SetTexture(P:GetIcon(entry.petType, entry.stage or "ADULT"))
        end
        row.nameFS:SetText(entry.title or entry.name or "?")
        local traitText = FormatTraits(entry.traits)
        local statusLabel = (entry.status == "retired") and L("lbl_retired") or L("lbl_living")
        row.metaFS:SetText(string.format(
            "%s · %s · %d XP",
            statusLabel,
            traitText or StageLabel(entry.stage),
            entry.xp or 0
        ))

        row.frame:SetScript("OnClick", function()
            R:ShowStallDetail(entry)
        end)
        row.frame:Show()
    end
end

function R:RefreshRetireButton(gs, phase)
    if not self._retireBtn then return end
    local Logic = ArcadiaNexus.ATG_Logic
    local canRetire = Logic and Logic:CanRetire(gs, phase)
    if canRetire then
        self._retireBtn:Show()
        self._retireBtn:SetEnabled(true)
    else
        self._retireBtn:Hide()
    end
end

function R:ShowRetireConfirm(show)
    if self._retireConfirm then
        if show then
            if self._retireConfirmFS then
                self._retireConfirmFS:SetText(L("confirm_retire"))
            end
            self._retireConfirm:Show()
        else
            self._retireConfirm:Hide()
        end
    end
end

function R:_ShowEmotesEnabled()
    local S = ArcadiaNexus.ATG_Settings
    return S and S:Get("showEmotes")
end

function R:_ShowBubbleEnabled()
    local S = ArcadiaNexus.ATG_Settings
    return S and S:Get("showSpeechBubble")
end

function R:_PlayCommentSound()
    local E = ArcadiaNexus.ATG_Engine
    if E and E.PlaySoundEvent then
        E:PlaySoundEvent("comment")
    end
end

function R:_EnsureCommUI(panel, anchor)
    if self._emoteFrame or not panel or not anchor then return end

    local emote = CreateFrame("Frame", nil, panel)
    emote:SetSize(CFG.emote_size, CFG.emote_size)
    emote:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
    emote:SetFrameLevel(panel:GetFrameLevel() + 6)
    emote:Hide()

    local emoteTex = emote:CreateTexture(nil, "OVERLAY")
    emoteTex:SetAllPoints(emote)
    emoteTex:Hide()

    local emoteFS = emote:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emoteFS:SetPoint("CENTER", emote, "CENTER", 0, 0)
    emoteFS:Hide()

    self._emoteFrame = emote
    self._emoteTex   = emoteTex
    self._emoteFS    = emoteFS

    local bubble = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bubble:SetSize(CFG.bubble_w, 40)
    bubble:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    bubble:SetFrameLevel(panel:GetFrameLevel() + 5)
    bubble:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bubble:SetBackdropColor(0.97, 0.96, 0.93, 0.96)
    bubble:SetBackdropBorderColor(0.35, 0.32, 0.38, 1)
    bubble:Hide()

    local bubbleText = bubble:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bubbleText:SetPoint("TOPLEFT", bubble, "TOPLEFT", 8, -6)
    bubbleText:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", -8, 6)
    bubbleText:SetWordWrap(true)
    bubbleText:SetJustifyH("LEFT")
    self._bubbleFrame = bubble
    self._bubbleText  = bubbleText
end

function R:HideComm()
    self._emoteLife = 0
    self._bubbleLife = 0
    self._sleepEmoteAccum = 0
    self._animRevertAccum = 0
    if self._emoteFrame then self._emoteFrame:Hide() end
    if self._emoteTex then self._emoteTex:Hide() end
    if self._emoteFS then self._emoteFS:Hide() end
    if self._bubbleFrame then self._bubbleFrame:Hide() end
end

function R:ClearPetModel()
    if self._petModel then
        self._petModel:ClearModel()
        self._petModel:Hide()
    end
    if self._petIcon then
        self._petIcon:Hide()
    end
    self._animRevertAccum = 0
    self._appliedModelKey = nil
    self._modelDrag = nil
end

function R:PlayPetAnimation(animId, revertAfter)
    local model = self._petModel
    if not model or not model.IsShown or not model:IsShown() then return end
    if not model.SetAnimation then return end

    model:SetAnimation(animId or 0)
    if revertAfter and revertAfter > 0 then
        self._animRevertAccum = revertAfter
    else
        self._animRevertAccum = 0
    end
end

function R:PlayPetAnimDef(animDef, hold)
    if not animDef then return end
    if animDef.visualOnly then
        self._animRevertAccum = 0
        return
    end
    local P = ArcadiaNexus.ATG_PetData
    local animId = P and P.GetPrimaryAnimId and P:GetPrimaryAnimId(animDef)
    if not animId and animDef.visualFallback then
        self:PlayPetAnimation(P and P.ANIM and P.ANIM.idle or 0, 0)
        return
    end
    if animId == nil then return end
    self:PlayPetAnimation(animId, hold and 0 or animDef.duration)
end

function R:PlayPetPhaseAnim(petType, phase)
    local P = ArcadiaNexus.ATG_PetData
    if not P or not P.GetPhaseAnimation then return end
    local animDef = P:GetPhaseAnimation(petType, phase)
    self:PlayPetAnimDef(animDef, true)
end

function R:_ApplyPetModel(gs)
    if not gs then return end
    local P = ArcadiaNexus.ATG_PetData
    if not P or not self._petModel then return end

    local key = tostring(gs.id or gs.petType) .. ":" .. tostring(gs.petType) .. ":" .. tostring(gs.stage)
    if self._appliedModelKey == key and self._petModel:IsShown() then
        return
    end
    self._appliedModelKey = key

    local ok = P:ApplyModel(self._petModel, gs.petType, gs.stage)
    local def = P.GetModelDef and P:GetModelDef(gs.petType, gs.stage)
    self._playRotDefault = (def and def.rotation) or 0
    self._playRotation = self._playRotDefault
    if ok then
        self._petModel:Show()
        self._petModel:SetAlpha(1)
        if self._petIcon then self._petIcon:Hide() end
        local idle = P.ANIM and P.ANIM.idle or 0
        self:PlayPetAnimation(idle)
        return
    end

    if self._petModel then self._petModel:Hide() end
    if self._petIcon then
        self._petIcon:SetTexture(P:GetIcon(gs.petType, gs.stage))
        self._petIcon:Show()
    end
end

function R:_TickPetAnimation(dt)
    if not self._animRevertAccum or self._animRevertAccum <= 0 then return end
    self._animRevertAccum = self._animRevertAccum - dt
    if self._animRevertAccum <= 0 then
        local P = ArcadiaNexus.ATG_PetData
        local E = ArcadiaNexus.ATG_Engine
        local phase = E and E.phase
        local gs = E and E.gameState
        if phase == "SLEEPING" and gs and P then
            self:PlayPetPhaseAnim(gs.petType, "SLEEPING")
        else
            self:PlayPetAnimation(P and P.ANIM and P.ANIM.idle or 0)
        end
    end
end

function R:ShowEmote(emoteId)
    if not self:_ShowEmotesEnabled() or not emoteId then return end
    local def = EMOTE_DEFS[emoteId]
    if not def or not self._emoteFrame then return end

    self._emoteLife = EMOTE_DURATION
    self._emoteFrame:SetAlpha(1)
    self._emoteFrame:Show()

    if def.text then
        self._emoteTex:Hide()
        self._emoteFS:Show()
        self._emoteFS:SetText(def.text)
        self._emoteFS:SetTextColor(def.r or 1, def.g or 1, def.b or 1, 1)
    else
        self._emoteFS:Hide()
        self._emoteTex:Show()
        self._emoteTex:SetTexture(def.texture)
        self._emoteTex:SetVertexColor(def.r or 1, def.g or 1, def.b or 1, 1)
    end
end

function R:ShowSpeechBubble(text)
    if not self:_ShowBubbleEnabled() or not text or text == "" then return end
    if not self._bubbleFrame or not self._bubbleText then return end

    self._bubbleText:SetText(text)
    self._bubbleFrame:SetHeight(math.max(36, self._bubbleText:GetStringHeight() + 14))
    self._bubbleFrame:SetAlpha(1)
    self._bubbleFrame:Show()
    self._bubbleLife = BUBBLE_DURATION
    self:_PlayCommentSound()
end

function R:ShowComment(gs, context)
    if not gs or not context then return end
    local P = ArcadiaNexus.ATG_PetData
    local Logic = ArcadiaNexus.ATG_Logic
    if not P or not P.PickComment then return end

    local dominant = Logic and Logic.GetDominantTrait and Logic:GetDominantTrait(gs)
    local text = P:PickComment(gs.petType, context, dominant)
    if text then
        self:ShowSpeechBubble(text)
    end

    local moodEmotes = {
        angry = "anger", sick = "sick", hungry = "question",
        tired = "sleep", happy = "hearts", evolved = "stars",
    }
    local emote = moodEmotes[context]
    if emote then self:ShowEmote(emote) end
end

function R:OnAction(action, gs)
    if not gs or not action then return end
    self:ShowComment(gs, action)
    local emote = ACTION_EMOTES[action]
    if emote then self:ShowEmote(emote) end

    local P = ArcadiaNexus.ATG_PetData
    local animDef = P and P.GetActionAnimation and P:GetActionAnimation(gs.petType, action)
    if animDef then
        self:PlayPetAnimDef(animDef)
    end
end

function R:OnEvolved(gs)
    if not gs then return end
    self:ShowComment(gs, "evolved")
end

function R:UpdateComm(dt, gs, phase)
    if not gs then return end

    self:_TickPetAnimation(dt)

    if self._emoteLife and self._emoteLife > 0 then
        self._emoteLife = self._emoteLife - dt
        if self._emoteFrame then
            local alpha = math.max(0, self._emoteLife / EMOTE_DURATION)
            self._emoteFrame:SetAlpha(alpha)
            if self._emoteLife <= 0 then
                self._emoteFrame:Hide()
            end
        end
    end

    if self._bubbleLife and self._bubbleLife > 0 then
        self._bubbleLife = self._bubbleLife - dt
        if self._bubbleFrame then
            local alpha = math.max(0, self._bubbleLife / BUBBLE_DURATION)
            self._bubbleFrame:SetAlpha(alpha)
            if self._bubbleLife <= 0 then
                self._bubbleFrame:Hide()
            end
        end
    end

    if phase == "SLEEPING" and self:_ShowEmotesEnabled() then
        self._sleepEmoteAccum = (self._sleepEmoteAccum or 0) + dt
        if self._sleepEmoteAccum >= SLEEP_EMOTE_EVERY and (self._emoteLife or 0) <= 0 then
            self._sleepEmoteAccum = 0
            self:ShowEmote("sleep")
        end
    else
        self._sleepEmoteAccum = 0
    end
end

function R:_ResetPetDisplayFrame()
    if self._petIconFrame then
        self._petIconFrame:SetScale(1)
    end
    if self._petModel then
        self._petModel:SetScale(1)
        self._petModel:SetAlpha(1)
    end
end

function R:_UpdateNeedBar(needKey, value)
    local bar = self._needBars[needKey]
    if not bar then return end
    local pct = math.max(0, math.min(100, value or 0))
    bar.fill:SetWidth(math.max(1, (CFG.bar_w - 2) * (pct / 100)))
    bar.val:SetText(string.format("%d%%", math.floor(pct)))
    if pct < 20 then
        bar.fill:SetColorTexture(0.85, 0.25, 0.2, 1)
    elseif pct < 50 then
        bar.fill:SetColorTexture(0.85, 0.65, 0.15, 1)
    else
        bar.fill:SetColorTexture(0.35, 0.75, 0.45, 1)
    end
end

function R:_UpdateXpBar(gs)
    if not self._xpBarFill or not gs then return end
    local Logic = ArcadiaNexus.ATG_Logic
    if not Logic then return end
    local _, _, pct = Logic:GetXpProgress(gs)
    pct = math.max(0, math.min(1, pct or 0))
    if gs.stage == "ADULT" then pct = 1 end
    self._xpBarFill:SetWidth(math.max(1, (CFG.xp_bar_w - 2) * pct))
    if gs.stage == "ADULT" then
        self._xpBarFill:SetColorTexture(0.95, 0.78, 0.25, 1)
    else
        self._xpBarFill:SetColorTexture(0.45, 0.55, 0.95, 1)
    end
end

function R:_EnsureEvolveParticles()
    if self._evolveParticles then return end
    local parent = self._playPanel
    if not parent then return end

    local pool = {}
    for i = 1, 12 do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(8, 8)
        f:SetFrameLevel(parent:GetFrameLevel() + 4)
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(f)
        t:SetColorTexture(1, 0.88, 0.25, 1)
        f:Hide()
        pool[i] = {
            frame = f,
            active = false,
            ox = 0,
            oy = 0,
            vx = 0,
            vy = 0,
            life = 0,
            maxLife = 0,
        }
    end
    self._evolveParticles = pool
end

function R:StartEvolutionAnim()
    self:_EnsureEvolveParticles()
    if not self._evolveParticles or not self._petIconFrame then return end

    self._evolvePulse = 0
    for i, slot in ipairs(self._evolveParticles) do
        local ang = ((i - 1) / #self._evolveParticles) * math.pi * 2 + math.random() * 0.4
        local speed = 28 + math.random() * 22
        slot.active = true
        slot.ox = 0
        slot.oy = 0
        slot.vx = math.cos(ang) * speed
        slot.vy = math.sin(ang) * speed
        slot.life = 1.1 + math.random() * 0.4
        slot.maxLife = slot.life
        slot.frame:ClearAllPoints()
        slot.frame:SetPoint("CENTER", self._petIconFrame, "CENTER", 0, 0)
        slot.frame:SetAlpha(1)
        slot.frame:Show()
    end
end

function R:UpdateEvolutionAnim(dt)
    if not self._evolveParticles then return end

    for _, slot in ipairs(self._evolveParticles) do
        if slot.active then
            slot.life = slot.life - dt
            slot.ox = slot.ox + slot.vx * dt
            slot.oy = slot.oy + slot.vy * dt
            if slot.life <= 0 then
                slot.active = false
                slot.frame:Hide()
            else
                slot.frame:SetPoint("CENTER", self._petIconFrame, "CENTER", slot.ox, slot.oy)
                slot.frame:SetAlpha(math.max(0, slot.life / slot.maxLife))
            end
        end
    end

    self._evolvePulse = (self._evolvePulse or 0) + dt
    if self._petIcon and self._petIcon:IsShown() then
        local pulse = 0.5 + 0.5 * math.sin(self._evolvePulse * 8)
        self._petIcon:SetVertexColor(1, 0.82 + 0.18 * pulse, 0.25 + 0.35 * pulse, 1)
    elseif self._petModel and self._petModel:IsShown() then
        local pulse = 0.5 + 0.5 * math.sin(self._evolvePulse * 8)
        local scale = 1 + 0.06 * math.sin(self._evolvePulse * 6)
        self._petModel:SetScale(scale)
        self._petModel:SetAlpha(0.75 + 0.25 * pulse)
    end
end

function R:StopEvolutionAnim()
    if self._evolveParticles then
        for _, slot in ipairs(self._evolveParticles) do
            slot.active = false
            slot.frame:Hide()
        end
    end
    self._evolvePulse = 0
    self:_ResetPetDisplayFrame()
    local E = ArcadiaNexus.ATG_Engine
    if E and E.gameState then
        self:_ApplyPetModel(E.gameState)
        self:_ApplyPetVisualState(E.gameState)
    end
end

function R:_ApplyPetVisualState(gs)
    if not gs then return end
    local P = ArcadiaNexus.ATG_PetData
    local Logic = ArcadiaNexus.ATG_Logic
    local E = ArcadiaNexus.ATG_Engine
    local phase = E and E.phase or "ACTIVE"
    local happy = gs.needs and gs.needs.happiness or 50

    if self._petModel and self._petModel:IsShown() then
        local alpha = 1
        if phase == "SLEEPING" then
            alpha = 0.65
        elseif happy < 20 then
            alpha = 0.75
        end
        self._petModel:SetAlpha(alpha)
        return
    end

    self:_ApplyPetIconTint(gs)
end

function R:_ApplyPetIconTint(gs)
    if not self._petIcon or not gs then return end
    local P = ArcadiaNexus.ATG_PetData
    local Logic = ArcadiaNexus.ATG_Logic
    local E = ArcadiaNexus.ATG_Engine
    local phase = E and E.phase or "ACTIVE"

    if phase == "SLEEPING" then
        self._petIcon:SetVertexColor(0.55, 0.55, 0.55, 1)
        return
    end
    if phase == "EVOLVING" then
        return
    end
    if gs.stage == "ADULT" and P and Logic then
        local dominant = Logic:GetDominantTrait(gs)
        if dominant then
            local r, g, b, a = P:GetTraitTint(dominant)
            self._petIcon:SetVertexColor(r, g, b, a)
            return
        end
    end
    self._petIcon:SetVertexColor(1, 1, 1, 1)
end

function R:RefreshHUD(gs)
    if not gs or not self._playPanel then return end
    self:_ApplyPetModel(gs)
    self:_ApplyPetVisualState(gs)
    if self._nameFS then
        if gs.stage == "ADULT" and gs.title and gs.title ~= "" then
            self._nameFS:SetText(gs.title)
        else
            self._nameFS:SetText(gs.name or "")
        end
    end
    if self._traitsFS then
        if gs.stage == "YOUTH" or gs.stage == "ADULT" then
            local traitText = FormatTraits(gs.traits)
            if traitText then
                self._traitsFS:SetText(string.format("%s: %s", L("lbl_traits"), traitText))
                self._traitsFS:Show()
            else
                self._traitsFS:Hide()
            end
        else
            self._traitsFS:Hide()
        end
    end
    if self._xpFS then
        if gs.stage == "ADULT" then
            self._xpFS:SetText(string.format("%s · %d %s", StageLabel(gs.stage), gs.xp or 0, L("lbl_xp")))
        else
            local nextXp = gs.stage == "BABY" and 200 or 600
            self._xpFS:SetText(string.format("%s · %d / %d %s", StageLabel(gs.stage), gs.xp or 0, nextXp, L("lbl_xp")))
        end
    end
    self:_AnchorNeedsBox()
    self:_UpdateXpBar(gs)
    if gs.needs then
        for _, needKey in ipairs(NEED_KEYS) do
            self:_UpdateNeedBar(needKey, gs.needs[needKey])
        end
    end
    local E = ArcadiaNexus.ATG_Engine
    self:RefreshRetireButton(gs, E and E.phase or "ACTIVE")
end

function R:RefreshActionButtons(gs, phase)
    if not gs then return end
    local Logic = ArcadiaNexus.ATG_Logic
    if not Logic then return end
    phase = phase or "ACTIVE"

    for action, btn in pairs(self._actionBtns) do
        local ok = Logic:CanPerformAction(gs, action, phase)
        local cd = (gs.cooldowns and gs.cooldowns[action]) or 0
        local baseLabel = L("btn_" .. action)
        if not ok then
            btn:SetEnabled(false)
            if cd > 0 then
                btn:SetLabel(string.format("%s (%d)", baseLabel, math.ceil(cd)))
            else
                btn:SetLabel(baseLabel)
            end
        else
            btn:SetEnabled(true)
            btn:SetLabel(baseLabel)
        end
    end
end

function R:EnterAdopting()
    self:HideComm()
    self:ClearPetModel()
    self:HideAdoptNameDialog()
    self:ShowRetireConfirm(false)
    if self._stallPanel then self._stallPanel:Hide() end
    if self._adoptPanel then self._adoptPanel:Show() end
    if self._playPanel then self._playPanel:Hide() end
    if self._statusFS then self._statusFS:SetText(L("state_adopting")) end
    self:_UpdateBrandingVisibility()
end

function R:EnterIdleState()
    self:HideComm()
    self:ClearPetModel()
    self:ClearStallModel()
    self:HideAdoptNameDialog()
    self:ShowRetireConfirm(false)
    if self._camGuard then self._camGuard:Cancel() end
    if self._stallPanel then self._stallPanel:Hide() end
    if self._adoptPanel then self._adoptPanel:Hide() end
    if self._playPanel then self._playPanel:Hide() end
    self:_UpdateBrandingVisibility()
end

function R:OnPetStarted(gs)
    if self._stallPanel then self._stallPanel:Hide() end
    if self._adoptPanel then self._adoptPanel:Hide() end
    if self._playPanel then self._playPanel:Show() end
    self:ShowRetireConfirm(false)
    self:HideAdoptNameDialog()
    self:_ResetPetDisplayFrame()
    self:RefreshHUD(gs)
    local E = ArcadiaNexus.ATG_Engine
    local phase = E and E.phase or "ACTIVE"
    self:RefreshActionButtons(gs, phase)
    self:_UpdateBrandingVisibility()
end

function R:OnPhaseChanged(phase)
    local prevPhase = self._lastPhase
    self._lastPhase = phase

    if prevPhase == "EVOLVING" and phase ~= "EVOLVING" then
        self:StopEvolutionAnim()
    end

    if phase == "ADOPTING" then
        self:EnterAdopting()
        return
    end
    if phase == "HUB" then
        return
    end

    local E = ArcadiaNexus.ATG_Engine
    if not E or not E.gameState then return end
    local gs = E.gameState

    if self._adoptPanel then self._adoptPanel:Hide() end
    if self._playPanel then self._playPanel:Show() end

    if self._phaseFS then
        if phase == "SLEEPING" then
            self._phaseFS:SetText(L("state_sleeping"))
            self._phaseFS:Show()
            self:PlayPetPhaseAnim(gs.petType, "SLEEPING")
        elseif phase == "EVOLVING" then
            self._phaseFS:SetText(L("state_evolving"))
            self._phaseFS:Show()
            self:StartEvolutionAnim()
            self:ShowRetireConfirm(false)
        elseif phase == "RETIRING" then
            self:ShowRetireConfirm(true)
        else
            self:ShowRetireConfirm(false)
            self._phaseFS:Hide()
            if prevPhase == "SLEEPING" or prevPhase == "EVOLVING" then
                local P = ArcadiaNexus.ATG_PetData
                self:PlayPetAnimation(P and P.ANIM and P.ANIM.idle or 0)
            end
        end
        if self._xpFS and self._nameFS then
            self:_AnchorNeedsBox()
        end
    end

    if self._petModel and self._petModel:IsShown() then
        self:_ApplyPetVisualState(gs)
    elseif self._petIcon then
        if phase == "SLEEPING" then
            self._petIcon:SetVertexColor(0.55, 0.55, 0.55, 1)
        elseif phase ~= "EVOLVING" then
            self:_ApplyPetIconTint(gs)
        end
    end

    self:RefreshHUD(gs)
    self:RefreshActionButtons(gs, phase)
end

ArcadiaNexus.RegisterGame({
    id        = "AZEROTHTINYGUARDIANS",
    label     = "Azeroth's Tiny Guardians",
    category  = "IDLE",
    renderer  = "ATG_Renderer",
    engine    = "ATG_Engine",
    container = "_atgContainer",
})
