local A = _G.ArcadiaNexus
A.GWX_Renderer = {}
local R = A.GWX_Renderer
local GAME_ID = "GALLYWIX"
local ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\wheel\\wheel_gallywix"
local LOGO_ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\logo\\logo_gallywix"
local BORDER_ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\border\\border_gallywix"
local BG_ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\background\\background_gallywix"
local FACTION_ASSETS = {
    Alliance = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions",
    Horde = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions",
    Neutral = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\symbol\\extra_spin_neutral",
}
local POINTER_ASSET = "Interface\\AddOns\\ArcadiaNexus\\Games\\Gallywix\\assets\\pointer\\pointer_gallywix"
local CFG = {
    playfield_fit = false, playfield_padding = 8,
    -- Visible frame decoration extends 12 source pixels beyond the aperture.
    border_aperture_ratio = 0.5, border_visible_ratio = 536/1024,
    wheel_size = 208, wheel_x = -185, wheel_y = -88,
    logo_w = 384, logo_h = 384, logo_ofs_x = 0, logo_ofs_y = 20, logo_alpha = 1,
    -- 50% texture aperture => 592 x 442 UI pixels, clear of existing HUD.
    border_w=790, border_h=545, border_ofs_x=0, border_ofs_y=17, border_alpha=1,
    bg_w=770, bg_h=520, bg_ofs_x=0, bg_ofs_y=17, bg_alpha=1,
    hud_w = 580, hud_h = 28, hud_x = 0, hud_y = -8, hud_alpha = 0.8,
    dd_w = 150, btn_w = 144, btn_h = 32,
    pointer_size_ratio = 48/384, pointer_x = 0, pointer_tip_y_ratio = -29/384,
    pointer_tip_v = 236 / 256,
    diagnostic_radius_ratio = 496/1024, diagnostic_segments = 192, diagnostic_cross_size = 36,
    faction_radius_ratio = 338/1024, faction_size_ratio = 60/1024,
    faction_preview_w = 160, faction_preview_h = 322, faction_preview_x = 8, faction_preview_y = 60,
    gallywix_x=75,gallywix_y=-20,gallywix_w=400,gallywix_h=610,
    -- NPC 35222 (Trade Prince Gallywix) uses CreatureDisplayID 75730.
    gallywix_display_id=75730,gallywix_camera_distance_scale=1.2,gallywix_facing=0,
    gallywix_model_scale=1.5,gallywix_dance_animation=69,gallywix_laugh_file=541902,
    gallywix_animation_fallbacks={197,70,68}, -- DanceOnce, Laugh, Cheer
    -- Canvas coordinates: TOPLEFT x/y except wheel/logo (CENTER). All sizes
    -- are UI pixels. The approved HUD defaults intentionally stay unchanged.
    score_w=184, score_h=38, score_y=-42, score_spacing=194,
    score_offsets={{x=0,y=0,scale=1},{x=0,y=0,scale=1},{x=0,y=0,scale=1}},
    category_x=104, category_y=-88, category_w=480,
    wall_x=104, wall_y=-108, wall_scale=1, wall_pad=4,
    tile_w=28, tile_h=24, tile_gap_x=2, tile_gap_y=2,
    letters_x=250, letters_y=-231, letters_w=24, letters_h=26, letters_gap_x=2, letters_gap_y=4, letters_scale=1,
    vowel_x=250, vowel_y=-303, vowel_w=168, vowel_h=28,
    hint_x=250, hint_y=-339, hint_w=336,
    solution_x=255, solution_y=-365, solution_w=214, solution_h=26,
    solve_x=478, solve_y=-365, solve_w=106, solve_h=26,
    event_x=250, event_y=-405, event_w=336, event_h=36,
    presenter_x=8, presenter_y=-88, presenter_w=86, presenter_h=124,
    presenter_name_x=8, presenter_name_y=-211, presenter_name_w=86, presenter_name_scale=1,
    presenter_camera_distance=4.5, presenter_camera_z=1.1, presenter_fov=0.65,
    presenter_model_scale=1, presenter_model_x=0, presenter_model_y=0, presenter_model_z=0, presenter_yaw=math.pi/2,
    wheel_large_size=384, wheel_large_x=0, wheel_large_y=-8,
    wheel_expand_seconds=0.4, wheel_dock_seconds=0.65, wheel_landing_hold=0.65,
    hud_scale=1, score_scale=1, category_scale=1, hint_scale=1, event_scale=1,
    vowel_scale=1, solution_scale=1, solve_scale=1, presenter_scale=1,
}
R.CFG = CFG
local function Locale() return A.GetLocaleTable(GAME_ID) end
local function IsDevMode() return A.IsDevMode and A.IsDevMode() == true end
local function FieldLabel(index)
    local value = A.GWX_Logic.fields[index]
    return string.format("%02d - %s", index, type(value) == "number" and tostring(value) or Locale()[value])
end

function R:_CreateRotationDiagnostic()
    -- Persistent, stationary overlay. Never parent it to the rotating texture.
    local overlay = CreateFrame("Frame", nil, self._wheelPivot)
    overlay:SetSize(CFG.wheel_size,CFG.wheel_size)
    overlay:SetPoint("CENTER",self._wheelPivot,"CENTER",0,0)
    overlay:SetFrameLevel((self._wheelPivot:GetFrameLevel() or 1) + 1)
    overlay:EnableMouse(false)
    self._rotationDiagnostic = overlay
    self._referenceCircle = {}
    -- Native UI lines: circle chords deviate by <0.03 UI px from the ideal
    -- circle at this radius. No generated bitmap or texture resampling.
    for i = 1, CFG.diagnostic_segments do
        local first = (i - 1) * 2 * math.pi / CFG.diagnostic_segments
        local last = i * 2 * math.pi / CFG.diagnostic_segments
        local line = overlay:CreateLine(nil, "OVERLAY")
        line:SetColorTexture(0, 1, 1, 0.95)
        line:SetThickness(1)
        local radius=CFG.diagnostic_radius_ratio*CFG.wheel_size
        line:SetStartPoint("CENTER", overlay, radius * math.cos(first), radius * math.sin(first))
        line:SetEndPoint("CENTER", overlay, radius * math.cos(last), radius * math.sin(last))
        self._referenceCircle[i] = line
    end
    self._referenceCross = {}
    for i = 1, 2 do
        local arm = overlay:CreateTexture(nil, "OVERLAY")
        arm:SetColorTexture(1, 0.15, 0.8, 0.95)
        arm:SetSize(i == 1 and CFG.diagnostic_cross_size or 1, i == 2 and CFG.diagnostic_cross_size or 1)
        arm:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        self._referenceCross[i] = arm
    end
    overlay:Hide()
end

function R:Init()
    if self.frame then return end
    local panel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel and _G.ArcadiaNexusUI.GetGamesPanel()
    if not panel then return end
    local UI = A.UI
    local v = UI.CreateGameViewport(panel, { outerName = "ArcadiaNexus_GWX_Container" })
    self.frame, self._canvas = v.outer, v.canvas
    self:_CreateBackground()
    self:_CreateBorder()
    self.frame:Hide()
    A._gwxContainer = self.frame
    self.frame:SetScript("OnHide", function()
        if A.MatchShell and A.MatchShell._reparenting then return end
        R._hidden=true
        if R._keyFrame then R._keyFrame:EnableKeyboard(false) end
        R._heldKeys={}
        A.GameSession:HandleRendererHide(GAME_ID, A.GWX_Engine, function(engine)
            if engine.mode and engine.mode~="hotseat" then engine:HideView(); return end
            return engine:SaveAndPause()
        end)
    end)
    self.frame:SetScript("OnShow", function()
        R._hidden=false
        R:FitPlayfield()
        R:RefreshKeyboardCapture()
        R:SetDiagnosticEnabled(R._diagnosticEnabled)
    end)
    -- Unnamed frame: session-scoped input, no global bindings or game events.
    self._keyFrame = CreateFrame("Frame", nil, self._canvas)
    self._keyFrame:SetAllPoints(self._canvas)
    self._keyFrame:EnableKeyboard(true)
    self._keyFrame:SetPropagateKeyboardInput(true)
    self._keyFrame:SetScript("OnKeyDown", function(frame, key)
        local handled = R:HandleKey(key)
        if not (InCombatLockdown and InCombatLockdown()) then
            frame:SetPropagateKeyboardInput(not handled)
        end
    end)
    self._keyFrame:SetScript("OnKeyUp", function(frame,key)
        if R._heldKeys then R._heldKeys[key]=nil end
        if not (InCombatLockdown and InCombatLockdown()) then frame:SetPropagateKeyboardInput(not R:CapturesKey(key)) end
    end)
    -- Approved trade-prince logo; wheel layers belong to gameplay only.
    self.logo = UI.CreateGameLogo(self._canvas, LOGO_ASSET, {
        w = CFG.logo_w, h = CFG.logo_h,
        x = CFG.logo_ofs_x, y = CFG.logo_ofs_y,
        alpha = CFG.logo_alpha,
    })
    self._wheelPivot = CreateFrame("Frame", nil, self._canvas)
    self._wheelPivot:SetSize(CFG.wheel_size, CFG.wheel_size)
    self._wheelPivot:SetPoint("CENTER", self._canvas, "CENTER", CFG.wheel_x, CFG.wheel_y)
    self._wheelPivot:SetFrameLevel((self._canvas:GetFrameLevel() or 1)+35)
    self._wheelSize=CFG.wheel_size
    self.wheel = self._wheelPivot:CreateTexture(nil, "ARTWORK")
    self.wheel:SetTexture(ASSET, "CLAMP", "CLAMP")
    self.wheel:SetSize(CFG.wheel_size, CFG.wheel_size)
    -- Exact SVG geometry: all circles centred at (512,512).
    -- Native rotation now uses that centre; no orbiting position correction.
    self.wheel:SetPoint("CENTER", self._wheelPivot, "CENTER", 0, 0)
    self._factionSymbol = self._wheelPivot:CreateTexture(nil, "OVERLAY", nil, 1)
    self._factionSymbol:SetSize(CFG.faction_size_ratio*CFG.wheel_size,CFG.faction_size_ratio*CFG.wheel_size)
    self._factionMask = self._wheelPivot:CreateMaskTexture(nil, "ARTWORK")
    self._factionMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    self._factionMask:SetAllPoints(self._factionSymbol)
    self._factionSymbol:AddMaskTexture(self._factionMask)
    self._factionPreview = "auto"
    self._factionPreviewHolder = CreateFrame("Frame", nil, self._canvas)
    self._factionPreviewHolder:SetSize(CFG.faction_preview_w, CFG.faction_preview_h)
    self._factionPreviewHolder:SetPoint("BOTTOMLEFT", self._canvas, "BOTTOMLEFT",
        CFG.faction_preview_x, CFG.faction_preview_y)
    self._factionPreviewHolder:SetFrameLevel((self._canvas:GetFrameLevel() or 1)+40)
    self._factionPreviewDropdown = UI.CreateSimpleDropdown(self._factionPreviewHolder, 0, 0,
        CFG.faction_preview_w, Locale().faction_preview, {
            {key = "auto", label = Locale().faction_auto},
            {key = "Alliance", label = Locale().faction_alliance},
            {key = "Horde", label = Locale().faction_horde},
            {key = "Neutral", label = Locale().faction_neutral},
        }, function() return R._factionPreview end,
        function(key) R:SetFactionPreview(key) end)
    self._presenterPreview="auto"
    self._presenterPreviewDropdown=UI.CreateSimpleDropdown(self._factionPreviewHolder,0,52,
        CFG.faction_preview_w,Locale().presenter_preview,{
            {key="auto",label=Locale().faction_auto},
            {key="Jaina",label=Locale().presenter_jaina},
            {key="Sylvanas",label=Locale().presenter_sylvanas},
        },function() return R._presenterPreview end,function(key) R:SetPresenterPreview(key) end)
    self:_CreateRotationDiagnostic()
    -- Separate stationary pointer, never included in the rotating texture.
    self.pointer = self._wheelPivot:CreateTexture(nil, "OVERLAY", nil, 7)
    self.pointer:SetTexture(POINTER_ASSET, "CLAMP", "CLAMP")
    self.pointer:SetSize(CFG.pointer_size_ratio*CFG.wheel_size,CFG.pointer_size_ratio*CFG.wheel_size)
    -- Transparent blade padding and distance to the rim scale with the wheel.
    self.pointer:SetPoint("BOTTOM", self._wheelPivot, "TOP", CFG.pointer_x,
        CFG.wheel_size*(CFG.pointer_tip_y_ratio-CFG.pointer_size_ratio*(1-CFG.pointer_tip_v)))
    self.hud, self.hudText = UI.CreateHudStatBox(self._canvas, {
        w = CFG.hud_w, h = CFG.hud_h, point = "TOP", relativePoint = "TOP",
        x = CFG.hud_x, y = CFG.hud_y, alpha = CFG.hud_alpha, shown = false,
        font = "GameFontNormal", justifyH = "CENTER",
    })
    self.hud:SetScale(CFG.hud_scale)
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    self._controlsFrame = bar.frame
    local anchor = CreateFrame("Frame", nil, bar.frame)
    anchor:SetSize(CFG.dd_w, CFG.btn_h)
    anchor:SetPoint("CENTER", bar.frame, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    self.selection = "random"
    local options = { { key = "random", label = Locale().random } }
    for i = 1, #A.GWX_Logic.fields do options[#options + 1] = { key = i, label = FieldLabel(i) } end
    self._debugFieldDropdown = UI.CreateSimpleDropdown(self._factionPreviewHolder, 0, 104, CFG.faction_preview_w, Locale().debug_field, options,
        function() return R.selection end,
        function(key) R.selection = key end)
    self._interventionPreview,self._interventionTarget="auto","random"
    self._interventionDropdown=UI.CreateSimpleDropdown(self._factionPreviewHolder,0,156,CFG.faction_preview_w,
        Locale().debug_gallywix,{
            {key="auto",label=Locale().debug_auto},{key="off",label=Locale().debug_off},{key="force",label=Locale().debug_force},
        },function() return R._interventionPreview end,function(key)
            if IsDevMode() and R._diagnosticEnabled and (key=="auto" or key=="off" or key=="force") then R._interventionPreview=key end
        end)
    self._interventionTargetDropdown=UI.CreateSimpleDropdown(self._factionPreviewHolder,0,208,CFG.faction_preview_w,
        Locale().debug_gallywix_target,options,function() return R._interventionTarget end,function(key)
            if IsDevMode() and R._diagnosticEnabled and (key=="random" or A.GWX_Logic:IsValidIndex(key)) then R._interventionTarget=key end
        end)
    self.category = "all"
    local categories = {}
    for _, key in ipairs(A.GWX_Words.categories) do categories[#categories+1]={key=key,label=Locale()["category_"..key]} end
    self.dropdown = UI.CreateSimpleDropdown(anchor, 0, 0, CFG.dd_w, "", categories,
        function() return R.category end, function(key) if A.GWX_Engine.state=="IDLE" then R.category=key end end)
    self.spinButton = UI.CreateArcadiaButton(bar.frame, Locale().btn_spin, CFG.btn_w, CFG.btn_h)
    self.spinButton:SetPoint("BOTTOM", bar.frame, "BOTTOM", bar.segX[2], bar.y.button)
    self.spinButton:SetScript("OnClick", function()
        R:PrimaryAction()
    end)
    self.exitButton = UI.CreateArcadiaButton(bar.frame, Locale().btn_exit, CFG.btn_w, CFG.btn_h)
    self.exitButton:SetPoint("BOTTOM", bar.frame, "BOTTOM", bar.segX[3], bar.y.button)
    self.exitButton:SetScript("OnClick", function()
        local E=A.GWX_Engine
        if E.mode~="hotseat" then E:StopGame() else E:SaveAndPause() end
    end)
    self.slots=UI.CreateSaveSlotMenu({parent=self._canvas,maxSlots=3,L=Locale(),
        loadSlot=function(slot) return A.GWX_Settings:LoadSlot(slot) end,
        deleteSlot=function(slot) A.GWX_Settings:SaveSlot(slot,nil) end,
        formatInfo=function(save)
            if not A.GWX_GameLogic:ValidateSave(save) then return Locale().bad_save end
            return string.format(Locale().saved_info,save.game.round,Locale()["category_"..save.game.category])
                ..(save.finished and (" | "..Locale().saved_finished) or "")
        end,
        canContinue=function(save) return A.GWX_Engine:CanContinue(save) end,
        onNewGame=function(slot) A.GWX_Engine:StartGame({slot=slot}) end,
        onContinue=function(slot) A.GWX_Engine:StartGame({slot=slot,resume=true}) end,
        onCancel=function() R:EnterIdleState() end,
    })
    self:_CreateGameUI()
    self:_CreateGallywix()
    self._gallywixDebugText=self._factionPreviewHolder:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    self._gallywixDebugText:SetPoint("TOPLEFT",self._factionPreviewHolder,"TOPLEFT",0,-264)
    self._gallywixDebugText:SetSize(CFG.faction_preview_w,56)
    self._gallywixDebugText:SetJustifyH("LEFT")
    self:RefreshGallywixStatus()
    self.frame:SetScript("OnSizeChanged", function() R:FitPlayfield() end)
    self:FitPlayfield()
    self:SetDiagnosticEnabled(false)
    self:EnterIdleState()
end

function R:SetDiagnosticEnabled(enabled)
    if A.GWX_Engine.mode and A.GWX_Engine.mode~="hotseat" then enabled=false end
    self._diagnosticEnabled = enabled and true or false
    local debugShown = IsDevMode() and self._diagnosticEnabled
    if debugShown then self._factionPreviewHolder:Show() else self._factionPreviewHolder:Hide() end
    if not debugShown then
        self._factionPreview = "auto"
        self._factionPreviewDropdown:RefreshDisplay()
        self._presenterPreview="auto"
        self._presenterPreviewDropdown:RefreshDisplay()
        self.selection = "random"
        self._debugFieldDropdown:RefreshDisplay()
        self._interventionPreview,self._interventionTarget="auto","random"
        self._interventionDropdown:RefreshDisplay(); self._interventionTargetDropdown:RefreshDisplay()
    end
    self:RefreshFactionSymbol()
    self:_RefreshPresenter()
    if IsDevMode() and self._diagnosticEnabled and self._wheelPresented then
        self._rotationDiagnostic:Show()
    else
        self._rotationDiagnostic:Hide()
    end
end

function R:GetInterventionPreview()
    if IsDevMode() and self._diagnosticEnabled then return self._interventionPreview,self._interventionTarget end
    return "auto","random"
end

function R:SetFactionPreview(key)
    if not (IsDevMode() and self._diagnosticEnabled) then return end
    if key ~= "auto" and not FACTION_ASSETS[key] then return end
    self._factionPreview = key
    self:RefreshFactionSymbol()
end

function R:SetPresenterPreview(key)
    if not (IsDevMode() and self._diagnosticEnabled) then return end
    if key~="auto" and key~="Jaina" and key~="Sylvanas" then return end
    self._presenterPreview=key
    self:_RefreshPresenter()
end

function R:RefreshFactionSymbol()
    local faction
    if IsDevMode() and self._diagnosticEnabled and self._factionPreview ~= "auto" then
        faction = self._factionPreview
    else
        faction = UnitFactionGroup and UnitFactionGroup("player")
    end
    if not FACTION_ASSETS[faction] then faction = "Neutral" end
    self._displayFaction = faction
    self._factionSymbol:SetTexture(FACTION_ASSETS[faction], "CLAMP", "CLAMP")
    if self._wheelPresented then self._factionSymbol:Show() else self._factionSymbol:Hide() end
    self:_PositionFactionSymbol(self._visualRotation or 0)
end

function R:_PositionFactionSymbol(clockwiseDegrees)
    local angle = math.rad(A.GWX_Logic:GetFieldDegrees(13) + clockwiseDegrees)
    local size = self._wheelSize or CFG.wheel_size
    local anchor = self._wheelPivot
    local radius = CFG.faction_radius_ratio * size
    local symbolSize = CFG.faction_size_ratio * size
    self._factionSymbol:SetSize(symbolSize,symbolSize)
    self._factionSymbol:ClearAllPoints()
    self._factionSymbol:SetPoint("CENTER", anchor, "CENTER",
        radius * math.sin(angle), radius * math.cos(angle))
    -- Rotate UVs inside the selected atlas half, without SetRotation resetting
    -- its crop. The round mask keeps visible samples inside that faction's half.
    local centreU, widthU = 0.5, 1
    if self._displayFaction == "Alliance" then centreU, widthU = 0.25, 0.5
    elseif self._displayFaction == "Horde" then centreU, widthU = 0.75, 0.5 end
    local cos, sin = math.cos(angle), math.sin(angle)
    local function uv(x, y)
        return centreU + (x * cos + y * sin) * widthU, 0.5 - x * sin + y * cos
    end
    local ulU, ulV = uv(-0.5, -0.5)
    local llU, llV = uv(-0.5, 0.5)
    local urU, urV = uv(0.5, -0.5)
    local lrU, lrV = uv(0.5, 0.5)
    self._factionSymbol:SetTexCoord(ulU, ulV, llU, llV, urU, urV, lrU, lrV)
end

function R:SetRotation(clockwiseDegrees)
    self._visualRotation = clockwiseDegrees
    self.wheel:SetRotation(-math.rad(clockwiseDegrees))
    self:_PositionFactionSymbol(clockwiseDegrees)
end

function R:OnSpinStarted(index)
    self.logo:Hide()
    self.wheel:Show()
    self.pointer:Show()
    self._wheelPresented = true
    self:SetDiagnosticEnabled(self._diagnosticEnabled)
    self.hud:Show()
    self.exitButton:Show()
    self.dropdown:SetEnabled(false)
    self.spinButton:Disable()
    self.spinButton:SetLabel(Locale().btn_spinning)
    self.hudText:SetText(string.format(Locale().hud_spinning, FieldLabel(index)))
    self:SetRotation(A.GWX_Engine.rotationDegrees)
end

function R:OnSpinFinished(index, degrees)
    self.dropdown:SetEnabled(true)
    self.spinButton:Enable()
    self.spinButton:SetLabel(Locale().btn_spin)
    self.hudText:SetText(string.format(Locale().hud_result, FieldLabel(index), degrees))
end

function R:EnterIdleState()
    if self.slots then self.slots:Hide() end
    self:SetGallywixVisible(false)
    self._spotlight,self._wheelTransition=false,nil
    self._heldKeys={}
    if self.pointer then self:_SetWheelPose(CFG.wheel_size,CFG.wheel_x,CFG.wheel_y) end
    A.UI.HideArcadeResult(self._canvas)
    if self._gameUI then self._gameUI:Hide(); self._wallBorder:Hide() end
    if self.solutionInput then self.solutionInput:ClearFocus(); self.solutionInput:SetText("") end
    self._puzzleIdentity, self._flips = nil, nil
    self.wheel:Hide()
    self.pointer:Hide()
    self._wheelPresented = false
    self:SetDiagnosticEnabled(self._diagnosticEnabled)
    self.hud:Hide()
    self.exitButton:Hide()
    self.logo:Show()
    self.dropdown:SetEnabled(true)
    self.spinButton:Enable()
    self.spinButton:SetLabel(Locale().btn_start)
    self:SetRotation(0)
    self:RefreshKeyboardCapture()
end

function R:PrimaryAction()
    local E=A.GWX_Engine
    if E.state=="IDLE" then
        if self.slots:IsShown() then self:EnterIdleState() else self.logo:Hide(); self.slots:Show() end
        return true
    end
    if E.state~="PLAYING" then return false end
    if E.gameState and E.gameState.phase=="ROUND_END" then return E:NextRound() end
    return E:Spin(IsDevMode() and self._diagnosticEnabled and self.selection or "random")
end
function R:FitPlayfield()
    if not self._canvas or not self._borderFrame or not self._bgTex then return end
    if not CFG.playfield_fit then
        self._canvas:SetScale(1)
        self._canvas:ClearAllPoints()
        self._canvas:SetPoint("CENTER",self.frame,"CENTER",0,A.Layout.gameControls.height/2)
        self._borderFrame:SetSize(CFG.border_w,CFG.border_h)
        self._bgTex:SetSize(CFG.bg_w,CFG.bg_h)
        return
    end
    local fallbackW,fallbackH=A.Layout.GetGamesPanelSize()
    local width,height=self.frame:GetWidth(),self.frame:GetHeight()
    if not width or width<=0 then width=fallbackW end
    if not height or height<=0 then height=fallbackH end
    local padding=math.max(0,CFG.playfield_padding)
    local usableW=width-2*padding
    local usableH=height-A.Layout.gameControls.height-2*padding
    if usableW<=0 or usableH<=0 then return end
    -- Fit the actual painted frame, not its large transparent texture reserve.
    local visibleW=CFG.border_w*CFG.border_visible_ratio
    local visibleH=CFG.border_h*CFG.border_visible_ratio
    local scale=math.min(usableW/visibleW,usableH/visibleH)
    self._canvas:SetScale(scale)
    self._canvas:ClearAllPoints()
    -- Anchor offsets use the scaled canvas' coordinate space.
    self._canvas:SetPoint("CENTER",self.frame,"TOP",-CFG.border_ofs_x,
        -(padding+usableH/2)/scale-CFG.border_ofs_y)
    -- Only the scenery/frame stretch horizontally. Game art scales uniformly.
    local borderW=usableW/scale/CFG.border_visible_ratio
    local bgW=CFG.bg_w+(borderW-CFG.border_w)*CFG.border_aperture_ratio
    self._borderFrame:SetSize(borderW,CFG.border_h)
    self._bgTex:SetSize(bgW,CFG.bg_h)
    self._playfieldScale=scale
end
function R:_CreateBackground()
    if self._bgTex then return end
    -- Canvas background stays below the logo and every gameplay frame.
    local texture=self._canvas:CreateTexture(nil,"BACKGROUND")
    texture:SetTexture(BG_ASSET,"CLAMP","CLAMP")
    texture:SetSize(CFG.bg_w,CFG.bg_h)
    texture:SetPoint("CENTER",self._canvas,"CENTER",CFG.bg_ofs_x,CFG.bg_ofs_y)
    texture:SetAlpha(CFG.bg_alpha)
    self._bgTex=texture
end
function R:_CreateBorder()
    if self._borderFrame then return end
    local frame=CreateFrame("Frame",nil,self._canvas)
    frame:SetSize(CFG.border_w,CFG.border_h)
    frame:SetPoint("CENTER",self._canvas,"CENTER",CFG.border_ofs_x,CFG.border_ofs_y)
    frame:SetFrameLevel((self._canvas:GetFrameLevel() or 1)+2)
    frame:EnableMouse(false)
    local texture=frame:CreateTexture(nil,"OVERLAY")
    texture:SetTexture(BORDER_ASSET,"CLAMP","CLAMP")
    texture:SetAllPoints(frame); texture:SetAlpha(CFG.border_alpha)
    self._borderFrame,self._borderTex=frame,texture
end
function R:CapturesKey(key)
    if key=="F8" and IsDevMode() then return true end
    local E=A.GWX_Engine
    local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then return false end
    return E.state=="PLAYING" and E.gameState~=nil and A.GameSession:IsSession(E,E._sessionId)
        and (key:match("^[A-Z]$") or key=="SPACE" or key=="ENTER" or key=="TAB"
            or key=="UP" or key=="DOWN" or key=="LEFT" or key=="RIGHT") and true or false
end
function R:HandleKey(key)
    if not self:CapturesKey(key) then return false end
    self._heldKeys=self._heldKeys or {}
    if self._heldKeys[key] then return true end
    self._heldKeys[key]=true
    if key=="F8" then self:SetDiagnosticEnabled(not self._diagnosticEnabled); return true end
    local E,s=A.GWX_Engine,A.GWX_Engine.gameState
    if key=="SPACE" then self:PrimaryAction()
    elseif key=="ENTER" and s.phase=="ROUND_END" then E:NextRound()
    elseif s.active==(s.localSeat or 1) then
        if (key=="ENTER" or key=="TAB") and s.phase=="CHOICE" then self.solutionInput:SetFocus()
        elseif key=="V" and s.phase=="CHOICE" then E:BuyVowel()
        elseif key:match("^[A-Z]$") then E:GuessLetter(key) end
    end
    return true
end
function R:RefreshKeyboardCapture()
    if not self._keyFrame then return end
    local focused=self.solutionInput and self.solutionInput:HasFocus()
    self._keyFrame:EnableKeyboard(not self._hidden and not focused)
    if not (InCombatLockdown and InCombatLockdown()) then self._keyFrame:SetPropagateKeyboardInput(true) end
end
function R:_SetWheelPose(size,x,y)
    self._wheelSize,self._wheelX,self._wheelY=size,x,y
    self._wheelPivot:ClearAllPoints()
    self._wheelPivot:SetSize(size,size)
    self._wheelPivot:SetPoint("CENTER",self._canvas,"CENTER",x,y)
    self.wheel:SetSize(size,size)
    local factor=size/CFG.wheel_size
    self.pointer:SetSize(size*CFG.pointer_size_ratio,size*CFG.pointer_size_ratio)
    self.pointer:ClearAllPoints()
    self.pointer:SetPoint("BOTTOM",self._wheelPivot,"TOP",CFG.pointer_x*factor,
        size*(CFG.pointer_tip_y_ratio-CFG.pointer_size_ratio*(1-CFG.pointer_tip_v)))
    if self._rotationDiagnostic then self._rotationDiagnostic:SetScale(factor) end
    self:_PositionFactionSymbol(self._visualRotation or 0)
end
function R:BeginWheelMotion(mode)
    self._spotlight=true
    self._wheelTransition={mode=mode,size=self._wheelSize or CFG.wheel_size,x=self._wheelX or CFG.wheel_x,y=self._wheelY or CFG.wheel_y}
    return mode=="expand" and CFG.wheel_expand_seconds or CFG.wheel_dock_seconds
end
function R:AnimateWheel(progress)
    local motion=self._wheelTransition
    if not motion then return end
    local targetSize=motion.mode=="expand" and CFG.wheel_large_size or CFG.wheel_size
    local targetX=motion.mode=="expand" and CFG.wheel_large_x or CFG.wheel_x
    local targetY=motion.mode=="expand" and CFG.wheel_large_y or CFG.wheel_y
    local eased=progress*progress*(3-2*progress)
    self:_SetWheelPose(motion.size+(targetSize-motion.size)*eased,motion.x+(targetX-motion.x)*eased,motion.y+(targetY-motion.y)*eased)
    if progress>=1 then self._wheelTransition=nil; self._spotlight=motion.mode=="expand" end
end
function R:GetWheelHoldDuration() return CFG.wheel_landing_hold end

local function Text(parent, font, x, y, width)
    local text=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormal")
    text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if width then text:SetWidth(width); text:SetJustifyH("CENTER") end
    return text
end
local function Call(object, method, ...)
    if object and object[method] then return pcall(object[method],object,...) end
end
function R:_CreateGameUI()
    local UI, L=A.UI,Locale()
    self._gameUI=CreateFrame("Frame",nil,self._canvas)
    self._gameUI:SetAllPoints(self._canvas)
    self._scoreBoxes,self._scoreTexts={},{}
    for i=1,3 do
        local offset=CFG.score_offsets[i]
        self._scoreBoxes[i],self._scoreTexts[i]=UI.CreateHudStatBox(self._gameUI,{
            w=CFG.score_w,h=CFG.score_h,point="TOP",relativePoint="TOP",x=(i-2)*CFG.score_spacing+offset.x,y=CFG.score_y+offset.y,
            font="GameFontNormalSmall",justifyH="CENTER",
        })
        self._scoreBoxes[i]:SetScale(CFG.score_scale*offset.scale)
    end
    self._categoryText=Text(self._gameUI,"GameFontNormal",CFG.category_x,CFG.category_y,CFG.category_w)
    self._categoryText:SetScale(CFG.category_scale)
    self._wall=CreateFrame("Frame",nil,self._gameUI)
    self._wall:SetSize(16*(CFG.tile_w+CFG.tile_gap_x)-CFG.tile_gap_x,4*(CFG.tile_h+CFG.tile_gap_y)-CFG.tile_gap_y)
    self._wall:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.wall_x,CFG.wall_y)
    self._wall:SetScale(CFG.wall_scale)
    self._wallBorder=UI.CreateGoldGridFrame(self._gameUI,self._wall,{pad=CFG.wall_pad})
    self._tiles={}
    -- Fixed 16 x 4 skeleton; new puzzles only change contents.
    for row=1,4 do for column=1,16 do
        local cell=CreateFrame("Frame",nil,self._wall)
        cell:SetSize(CFG.tile_w,CFG.tile_h)
        cell:SetPoint("TOPLEFT",self._wall,"TOPLEFT",(column-1)*(CFG.tile_w+CFG.tile_gap_x),-(row-1)*(CFG.tile_h+CFG.tile_gap_y))
        local body=CreateFrame("Frame",nil,cell)
        body:SetSize(CFG.tile_w,CFG.tile_h); body:SetPoint("CENTER",cell,"CENTER",0,0)
        local bg=body:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(body)
        local letter=body:CreateFontString(nil,"OVERLAY","GameFontNormal")
        letter:SetPoint("CENTER",body,"CENTER",0,0)
        self._tiles[(row-1)*16+column]={cell=cell,body=body,bg=bg,text=letter}
    end end
    self._letterButtons={}
    self._letters=CreateFrame("Frame",nil,self._gameUI)
    self._letters:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.letters_x,CFG.letters_y)
    self._letters:SetSize(13*(CFG.letters_w+CFG.letters_gap_x)-CFG.letters_gap_x,2*(CFG.letters_h+CFG.letters_gap_y)-CFG.letters_gap_y)
    self._letters:SetScale(CFG.letters_scale)
    for i=0,25 do
        local letter=string.char(65+i)
        local button=UI.CreateArcadiaButton(self._letters,letter,CFG.letters_w,CFG.letters_h)
        button:SetPoint("TOPLEFT",self._letters,"TOPLEFT",(i%13)*(CFG.letters_w+CFG.letters_gap_x),-math.floor(i/13)*(CFG.letters_h+CFG.letters_gap_y))
        button:SetScript("OnClick",function() A.GWX_Engine:GuessLetter(letter) end)
        self._letterButtons[letter]=button
    end
    self.vowelButton=UI.CreateArcadiaButton(self._gameUI,L.btn_vowel,CFG.vowel_w,CFG.vowel_h)
    self.vowelButton:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.vowel_x,CFG.vowel_y)
    self.vowelButton:SetScale(CFG.vowel_scale)
    self.vowelButton:SetScript("OnClick",function() A.GWX_Engine:BuyVowel() end)
    self._actionHint=Text(self._gameUI,"GameFontNormalSmall",CFG.hint_x,CFG.hint_y,CFG.hint_w)
    self._actionHint:SetScale(CFG.hint_scale)
    self.solutionInput=CreateFrame("EditBox",nil,self._gameUI,"InputBoxTemplate")
    self.solutionInput:SetSize(CFG.solution_w,CFG.solution_h)
    self.solutionInput:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.solution_x,CFG.solution_y)
    self.solutionInput:SetScale(CFG.solution_scale)
    self.solutionInput:SetAutoFocus(false); self.solutionInput:SetMaxLetters(64)
    self.solutionInput:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    self.solutionInput:SetScript("OnEditFocusGained",function() R:RefreshKeyboardCapture() end)
    self.solutionInput:SetScript("OnEditFocusLost",function() R._heldKeys={}; R:RefreshKeyboardCapture() end)
    local function submit()
        if A.GWX_Engine:Solve(R.solutionInput:GetText()) then
            R.solutionInput:SetText(""); R.solutionInput:ClearFocus()
        end
    end
    self.solutionInput:SetScript("OnEnterPressed",submit)
    self.solveButton=UI.CreateArcadiaButton(self._gameUI,L.btn_solve,CFG.solve_w,CFG.solve_h)
    self.solveButton:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.solve_x,CFG.solve_y)
    self.solveButton:SetScale(CFG.solve_scale)
    self.solveButton:SetScript("OnClick",submit)
    self._eventText=Text(self._gameUI,"GameFontNormalSmall",CFG.event_x,CFG.event_y,CFG.event_w)
    self._eventText:SetHeight(CFG.event_h); self._eventText:SetScale(CFG.event_scale)
    self:_CreatePresenter()
end
function R:_CreatePresenter()
    local scene
    for _,template in ipairs({"ModelSceneFrameTemplate","ModelSceneMixinTemplate",false}) do
        local ok,created
        if template then ok,created=pcall(CreateFrame,"ModelScene",nil,self._gameUI,template)
        else ok,created=pcall(CreateFrame,"ModelScene",nil,self._gameUI) end
        if ok and created then scene=created; break end
    end
    if not scene then return end
    scene:SetSize(CFG.presenter_w,CFG.presenter_h)
    scene:SetPoint("TOPLEFT",self._gameUI,"TOPLEFT",CFG.presenter_x,CFG.presenter_y)
    scene:SetScale(CFG.presenter_scale)
    scene:SetFrameLevel((self._gameUI:GetFrameLevel() or 1)+25)
    scene:EnableMouse(false)
    local good, actor=Call(scene,"CreateActor","GWX_Presenter","ModelSceneActorTemplate")
    if not good or not actor then good,actor=Call(scene,"CreateActor","GWX_Presenter") end
    if not good or not actor then good,actor=Call(scene,"CreateActor") end
    if not good or not actor then good,actor=Call(scene,"GetActorAtIndex",1) end
    if not good or not actor then scene:Hide(); return end
    self._presenterScene,self._presenter=scene,actor
    Call(scene,"SetCameraPosition",0,CFG.presenter_camera_distance,CFG.presenter_camera_z)
    if scene.SetCameraOrientationByAxisVectors then
        Call(scene,"SetCameraOrientationByAxisVectors",0,-1,0,1,0,0,0,0,1)
    else Call(scene,"SetCameraOrientationByYawPitchRoll",math.pi,0,0) end
    Call(scene,"SetCameraFieldOfView",CFG.presenter_fov)
    Call(scene,"SetCameraNearClip",0.01); Call(scene,"SetCameraFarClip",40)
    Call(scene,"SetLightVisible",true); Call(scene,"SetLightAmbientColor",0.7,0.7,0.7)
    Call(scene,"SetLightDiffuseColor",1,1,1); Call(scene,"SetLightDirection",0.4,-0.7,-1)
    Call(scene,"SetPaused",false,true)
    Call(scene,"SetAlpha",1)
    Call(actor,"SetScale",CFG.presenter_model_scale)
    Call(actor,"SetPosition",CFG.presenter_model_x,CFG.presenter_model_y,CFG.presenter_model_z)
    Call(actor,"SetYaw",CFG.presenter_yaw); Call(actor,"Show")
    self._presenterName=Text(self._gameUI,"GameFontNormalSmall",CFG.presenter_name_x,CFG.presenter_name_y,CFG.presenter_name_w)
    self._presenterName:SetScale(CFG.presenter_name_scale)
end
function R:RefreshGallywixStatus()
    if not self._gallywixDebugText then return end
    local L=Locale()
    self._gallywixDebugText:SetText(string.format(L.debug_gallywix_status,
        L["gallywix_model_"..(self._gallywixModelStatus or "waiting")],
        L["gallywix_sound_"..(self._gallywixSoundStatus or "waiting")],
        self._gallywixDanceID and tostring(self._gallywixDanceID) or "-"))
end
function R:_CreateGallywix()
    if self._gallywixScene then return end
    -- A single character uses PlayerModel's native display camera. Load only
    -- after Show; a model request made on a hidden frame can remain invisible.
    local ok,model=pcall(CreateFrame,"PlayerModel",nil,self._canvas)
    if not ok or not model then self._gallywixModelStatus="failed"; return end
    model:SetSize(CFG.gallywix_w,CFG.gallywix_h)
    model:SetPoint("CENTER",self._canvas,"CENTER",CFG.gallywix_x,CFG.gallywix_y)
    model:SetFrameLevel((self._canvas:GetFrameLevel() or 1)+36)
    model:EnableMouse(false)
    model:SetAlpha(1)
    self._gallywixScene,self._gallywixActor=model,model
    model:SetScript("OnModelLoaded",function()
        R._gallywixModelStatus="ready"
        R._gallywixLoadedDisplayId=R._gallywixRequestedDisplayId
        R:_ConfigureGallywixModel()
        if R._gallywixRequested and A.GWX_Engine._intervention and A.GWX_Engine.gameState then
            R._gallywixVisible=true
            R:SetGallywixDancing(R._gallywixDancing)
            R:RenderGame(A.GWX_Engine.gameState)
        end
        R:RefreshGallywixStatus()
    end)
    model:SetScript("OnAnimFinished",function()
        if R._gallywixDancing and R._gallywixVisible and (R._gallywixAnimationID or 0)>0 then
            R:SetGallywixDancing(true)
        end
    end)
    model:Hide()
end
function R:_ConfigureGallywixModel()
    local model=self._gallywixScene
    if not model then return end
    Call(model,"SetCamera",0)
    Call(model,"SetPortraitZoom",0)
    Call(model,"SetCamDistanceScale",CFG.gallywix_camera_distance_scale)
    Call(model,"SetModelScale",CFG.gallywix_model_scale)
    Call(model,"SetPosition",0,0,0)
    Call(model,"SetFacing",CFG.gallywix_facing)
end
function R:PlayGallywixLaugh(forced)
    if not A.GWX_Sounds:Enabled("soundGallywix") then
        self._gallywixSoundStatus="disabled"; self:RefreshGallywixStatus(); return nil
    end
    if not PlaySoundFile then
        self._gallywixSoundStatus="failed"; self:RefreshGallywixStatus(); return nil
    end
    -- Match the other arcade games' channel. WoW's master mute still applies.
    local ok,played,handle=pcall(PlaySoundFile,CFG.gallywix_laugh_file,"Master")
    self._gallywixSoundStatus=ok and played and "played" or "failed"
    self:RefreshGallywixStatus()
    return ok and played and handle or nil
end
function R:SetGallywixVisible(visible)
    self._gallywixRequested=visible==true
    self._gallywixVisible=false
    self._gallywixDancing=false
    local model=self._gallywixScene
    if not model then
        if visible then self._gallywixModelStatus="failed" end
        self:RefreshGallywixStatus(); return
    end
    if not visible then model:Hide(); return end
    self._gallywixModelStatus="loading"
    local cached=self._gallywixLoadedDisplayId==CFG.gallywix_display_id
    self._gallywixRequestedDisplayId=CFG.gallywix_display_id
    model:Show()
    self:_ConfigureGallywixModel()
    local ok,result=Call(model,"SetDisplayInfo",CFG.gallywix_display_id)
    if not ok or result==false then
        self._gallywixModelStatus="failed"; model:Hide()
    else
        -- Cached models need not fire OnModelLoaded again.
        local queried,fileID=Call(model,"GetModelFileID")
        if cached and queried and type(fileID)=="number" and fileID>0 then
            self._gallywixModelStatus="ready"; self._gallywixVisible=true
            self:_ConfigureGallywixModel()
        end
    end
    self:RefreshGallywixStatus()
end
function R:SetGallywixDancing(dancing)
    self._gallywixDancing=dancing==true
    if self._gallywixActor and self._gallywixVisible then
        local animation=0
        if dancing then
            local candidates={CFG.gallywix_dance_animation}
            for _,id in ipairs(CFG.gallywix_animation_fallbacks) do candidates[#candidates+1]=id end
            for _,id in ipairs(candidates) do
                local checked,supported=Call(self._gallywixActor,"HasAnimation",id)
                if not checked or supported==nil or supported==true then animation=id; break end
            end
        end
        Call(self._gallywixActor,"SetPaused",false)
        local ok,result=Call(self._gallywixActor,"SetAnimation",animation,0)
        if not ok or result==false then animation=0; Call(self._gallywixActor,"SetAnimation",0,0) end
        self._gallywixAnimationID=animation
        if dancing then self._gallywixDanceID=animation end
        self:RefreshGallywixStatus()
    end
end
function R:_RefreshPresenter()
    if not self._presenter then return end
    local horde=UnitFactionGroup and UnitFactionGroup("player")=="Horde"
    local name=horde and "Sylvanas" or "Jaina"
    if IsDevMode() and self._diagnosticEnabled and self._presenterPreview~="auto" then
        name=self._presenterPreview
        horde=name=="Sylvanas"
    end
    if self._presenterIdentity~=name then
        self._presenterIdentity=name
        for _,id in ipairs(horde and {28213,39482,15427} or {80015,73812,30865,17122}) do
            local ok,result=Call(self._presenter,"SetModelByCreatureDisplayID",id)
            if ok and result~=false then break end
        end
        self._presenterName:SetText(name)
    end
    self._presenterScene:Show(); Call(self._presenter,"Show")
    Call(self._presenter,"SetAnimation",self._flips and 25 or 0)
end
function R:PlayerName(index)
    local E=A.GWX_Engine
    if E.mode and E.mode~="hotseat" and E.match then
        local key=E.match.seats[index]
        if key then return index==E.match.seat and Locale().player or key:match("^([^-]+)") end
        return E.match.publicState.bot or ""
    end
    return index==1 and Locale().player or (index==2 and "Gazlowe" or "Rexxar")
end
function R:_RenderWall(s)
    local changed=self._puzzleIdentity~=s.puzzle
    if changed then
        self._puzzleIdentity=s.puzzle; self._tileForIndex={}; self._flips=nil
        for _,tile in ipairs(self._tiles) do
            tile.index=nil; tile.body:SetWidth(CFG.tile_w); tile.text:SetText(""); tile.text:SetAlpha(1)
            tile.bg:SetColorTexture(0.08,0.16,0.17,1)
        end
        local cells=A.GWX_GameLogic:LayoutPuzzle(s.puzzle.answer,16)
        for _,item in ipairs(cells) do
            local tile=self._tiles[(item.row-1)*16+item.column]
            if tile then tile.index=item.index; self._tileForIndex[item.index]=tile end
        end
        self:_RefreshPresenter()
    end
    if s.phase=="REVEAL" and self._lastReveal~=s.event then
        self._lastReveal=s.event
        local E=A.GWX_Engine
        local elapsed=E._restoring and E._pending and math.max(0,0.7+#s.event.positions*0.1-E._pending.remaining) or 0
        self._flips={elapsed=elapsed,positions=s.event.positions}
        Call(self._presenter,"SetAnimation",25)
    elseif s.phase~="REVEAL" then self._flips=nil end
    for index,tile in pairs(self._tileForIndex) do
        local pending=false
        if self._flips then for _,position in ipairs(self._flips.positions) do if position==index then pending=true end end end
        tile.body:SetWidth(CFG.tile_w)
        local revealed=s.puzzle.revealed[index] and not pending
        tile.bg:SetColorTexture(revealed and 0.88 or 0.2,revealed and 0.82 or 0.46,revealed and 0.59 or 0.45,1)
        tile.text:SetText(revealed and s.puzzle.answer:sub(index,index) or "")
        tile.text:SetTextColor(0.1,0.1,0.08,1)
    end
end
function R:AnimateWall(dt)
    local flip=self._flips
    if not flip then return end
    flip.elapsed=flip.elapsed+dt
    for order,index in ipairs(flip.positions) do
        local progress=math.max(0,math.min(1,(flip.elapsed-(order-1)*0.1)/0.6))
        local tile=self._tileForIndex[index]
        if tile then
            tile.body:SetWidth(math.max(1,CFG.tile_w*math.abs(math.cos(progress*math.pi))))
            if progress>=0.5 then
                tile.text:SetText(self._puzzleIdentity.answer:sub(index,index))
                tile.bg:SetColorTexture(0.88,0.82,0.59,1)
            end
            tile.text:SetAlpha(math.abs(math.cos(progress*math.pi)))
        end
    end
    if flip.elapsed>=0.6+#flip.positions*0.1 then
        self._flips=nil; Call(self._presenter,"SetAnimation",0)
        for _,tile in pairs(self._tileForIndex) do tile.body:SetWidth(CFG.tile_w); tile.text:SetAlpha(1) end
    end
end
function R:RenderGame(s)
    local terminal=A.GWX_Engine.state=="FINISHED"
    if self.slots then self.slots:Hide() end
    local L, rules=Locale(),A.GWX_GameLogic
    A.GWX_Sounds:Observe(s)
    if not terminal then A.UI.HideArcadeResult(self._canvas) end
    self.logo:Hide(); self._gameUI:Show(); self._wallBorder:Show()
    self.wheel:Show(); self.pointer:Show(); self.hud:Show(); self.exitButton:Show()
    self._wheelPresented=true
    self:SetDiagnosticEnabled(self._diagnosticEnabled)
    self:SetRotation(A.GWX_Engine.rotationDegrees)
    self.dropdown:RefreshDisplay()
    self.dropdown:SetEnabled(false)
    self.exitButton:SetLabel(s.localSeat and L.btn_exit_match or L.btn_exit)
    local seat=s.localSeat or 1
    local choice=not terminal and s.active==seat and s.phase=="CHOICE"
    local roundEnd=not terminal and s.phase=="ROUND_END"
    self._debugFieldDropdown:SetEnabled(choice)
    self._interventionDropdown:SetEnabled(choice); self._interventionTargetDropdown:SetEnabled(choice)
    self.spinButton:SetEnabled(choice or roundEnd)
    self.spinButton:SetLabel(roundEnd and L.btn_next or s.phase=="SPINNING" and L.btn_spinning or L.btn_spin)
    self.hudText:SetText(string.format(L.hud_round,s.round,rules.ROUND_COUNT,self:PlayerName(s.active)) .. (s.unranked and "  |  "..L.unranked or ""))
    for i,p in ipairs(s.players) do
        self._scoreTexts[i]:SetText(string.format(L.score_card,self:PlayerName(i),p.total,p.bank,p.extra))
    self._scoreTexts[i]:SetTextColor(i==s.active and 1 or 0.7,i==s.active and 0.83 or 0.7,i==s.active and 0.2 or 0.7)
    end
    for i=1,3 do self._scoreBoxes[i]:SetShown(s.players[i]~=nil) end
    self._categoryText:SetText(L["category_"..s.puzzle.category])
    self:_RenderWall(s)
    if A.GWX_Engine._restoring and self._flips then self:AnimateWall(0) end
    for letter,button in pairs(self._letterButtons) do
        local available=not terminal and s.active==seat and not s.puzzle.guessed[letter] and
            ((s.phase=="LETTER" and not rules:IsVowel(letter)) or (s.phase=="VOWEL" and rules:IsVowel(letter)))
        button:SetEnabled(available)
        button:SetAlpha(s.puzzle.guessed[letter] and 0.35 or 1)
    end
    self.vowelButton:SetEnabled(choice and s.players[seat].bank>=rules.VOWEL_COST and #rules:Available(s,true)>0)
    self.solveButton:SetEnabled(choice)
    self.solutionInput:SetEnabled(choice)
    if not choice then self.solutionInput:ClearFocus() end
    local hint=roundEnd and L.hint_round_end or s.active~=seat and (s.localSeat and L.hint_match_wait or L.hint_ai) or L["hint_"..s.phase] or ""
    self._actionHint:SetText(hint)
    local event=s.event or {}
    local message=L["event_"..event.kind] or ""
    if event.kind=="money" then message=string.format(message,event.value)
    elseif event.kind=="hit" then message=string.format(message,event.letter,#event.positions,event.amount)
    elseif event.kind=="miss" then message=string.format(message,event.letter)
    elseif event.kind=="round_won" then message=string.format(message,self:PlayerName(event.winner),event.answer) end
    if event.protected then message=message.."\n"..L.event_protected end
    self._eventText:SetText(message)
    if A.GWX_Engine._intervention then self._actionHint:SetText(L.hint_gallywix) end
    if self._spotlight or self._gallywixVisible then self._gameUI:Hide(); self._wallBorder:Hide(); self.hud:Hide() end
    self:RefreshKeyboardCapture()
end
function R:ShowResult(s,result,data)
    data=data or A.GWX_Engine._terminalData or {}
    A.GWX_Sounds:Result(result)
    self.spinButton:Disable(); self.vowelButton:Disable(); self.solveButton:Disable(); self.solutionInput:ClearFocus()
    for _,button in pairs(self._letterButtons) do button:Disable() end
    local lines={}
    for i,p in ipairs(s.players) do lines[#lines+1]=string.format(Locale().result_player,self:PlayerName(i),p.total,p.rounds) end
    if s.unranked then lines[#lines+1]=Locale().result_unranked end
    A.UI.ShowArcadeResult(self._canvas,{gameId=GAME_ID,difficulty=s.difficulty or "default",result=result,
        score=s.players[s.localSeat or 1].total,L=Locale(),lines=lines,hideHighscore=s.unranked,
        xp=s.unranked and 0 or (data.awardedXP or 0),newHighscore=not s.unranked and data.newHighscore==true,
        isCurrent=function() return A.GWX_Engine.gameState==s and A.GWX_Engine.state=="FINISHED" end,
        onRetry=function()
            if s.localSeat then A.MatchShell.Rematch(GAME_ID) else A.GWX_Engine:StartGame({slot=A.GWX_Engine._slot,category=s.category,locale=s.locale,gallywixEnabled=s.gallywixEnabled}) end
        end,onExit=function() A.GWX_Engine:StopGame() end})
end

A.RegisterGame({
    id = GAME_ID, label = "Gallywix - Wheel of Fortune", category = "WORT",
    renderer = "GWX_Renderer", engine = "GWX_Engine", container = "_gwxContainer",
    logo = LOGO_ASSET, xp = 12, matchSeats = 3,
})
