-- ============================================================
--  Darkmoon Pinball – Renderer.lua
--  Viewport, Debug-Tisch, Input, Result. Keine Spielregeln.
-- ============================================================

ArcadiaNexus.DMP_Renderer = {}
local R = ArcadiaNexus.DMP_Renderer

local GAME_ID = "DARKMOON_PINBALL"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local ASSETS = "Interface\\AddOns\\ArcadiaNexus\\Games\\DarkmoonPinball\\assets\\"
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WORLD_W, WORLD_H = 280, 440
local GOLD_PAD = 2
local MARGIN_Y = 5

local CFG = {
    field_w = WORLD_W,
    field_h = WORLD_H,
    field_ofs_x = 0,
    field_ofs_y = 15,
    worldScale = 1,
    gold_pad = GOLD_PAD,
    border_path = ASSETS .. "border\\border_dp",
    border_w = 800, border_h = 552, border_ofs_x = 0, border_ofs_y = 16, border_alpha = 1,
    bg_path     = ASSETS .. "background\\background_dp",
    bg_w        = 765, bg_h = 512, bg_ofs_x = 0, bg_ofs_y = 10, bg_alpha = 1,
    logo_path   = ASSETS .. "logo\\logo_dp",
    logo_w      = 350, logo_h = 350, logo_ofs_x = 0, logo_ofs_y = 16, logo_alpha = 1,
    hud_left_x = -232,
    hud_right_x = 232,
    hud_stat_y1 = 70,
    hud_stat_y2 = 32,
    hud_score_w = 148, hud_score_h = 28, hud_score_alpha = 0.75,
    hud_balls_w = 148, hud_balls_h = 28, hud_balls_alpha = 0.75,
    hud_combo_w = 148, hud_combo_h = 28, hud_combo_alpha = 0.75,
    hud_mission_w = 200, hud_mission_h = 24, hud_mission_y = -10, hud_mission_alpha = 0.82,
    btn_w = 144, btn_h = 32,
    dd_w = 160,
    eye_x = 140, eye_y = 76, eye_s = 44,
}

local function ApplyFieldLayout()
    local layout = ArcadiaNexus.Layout
    local canvasH = (layout and layout.gameDesign and layout.gameDesign.height) or 498
    CFG.gold_pad = GOLD_PAD
    CFG.field_h = canvasH - 2 * MARGIN_Y - 2 * GOLD_PAD
    CFG.worldScale = CFG.field_h / WORLD_H
    CFG.field_w = WORLD_W * CFG.worldScale
end

local function WS()
    return CFG.worldScale or 1
end

ApplyFieldLayout()

R.state = "IDLE"

local function Loc()
    return ArcadiaNexus.GetLocaleTable(GAME_ID)
end

local function FormatScore(n)
    if ArcadiaNexus.Format and ArcadiaNexus.Format.Score then
        return ArcadiaNexus.Format.Score(n or 0)
    end
    return tostring(n or 0)
end

function R:Init()
    ApplyFieldLayout()
    self:_CreateMainFrame()
    self:_CreateBackground()
    self:_CreateField()
    self:_CreateBorderTex()
    self:_CreateLogo()
    self:_CreateHUD()
    self:_CreateKeyFrame()
    self:_CreateControls()
    self:_CreatePauseOverlay()
    self:_CreateFlash()
    self:_CreateFx()
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_DMP_Container",
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    ArcadiaNexus._dmpContainer = f
    f:SetScript("OnHide", function()
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then return end
        ArcadiaNexus.GameSession:HandleRendererHide(GAME_ID, ArcadiaNexus.DMP_Engine, function(E)
            if E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
    end)
end

function R:_PlaceDecor(frame, w, h, ox, oy)
    frame:SetSize(w, h)
    frame:SetPoint("CENTER", self._canvas, "CENTER", ox or 0, oy or 0)
end

function R:_CreateBackground()
    local canvas = self._canvas
    if not canvas then return end
    local bg = canvas:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(CFG.bg_path)
    bg:SetSize(CFG.bg_w, CFG.bg_h)
    bg:SetPoint("CENTER", canvas, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    bg:SetAlpha(CFG.bg_alpha)
    self._bgTex = bg
end

function R:_CreateBorderTex()
    local canvas = self._canvas
    if not canvas then return end
    local border = CreateFrame("Frame", nil, canvas)
    self:_PlaceDecor(border, CFG.border_w, CFG.border_h, CFG.border_ofs_x, CFG.border_ofs_y)
    border:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 2)
    local tex = border:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(CFG.border_path)
    tex:SetAllPoints(border)
    tex:SetAlpha(CFG.border_alpha)
    self._borderFrame = border
    self._borderTex = tex
end

function R:_CreateField()
    local canvas = self._canvas
    if not canvas then return end
    local field = CreateFrame("Frame", nil, canvas)
    field:SetSize(CFG.field_w, CFG.field_h)
    field:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    field:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 8)
    local fill = field:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(field)
    fill:SetColorTexture(0.07, 0.05, 0.10, 0.98)
    self._fieldFill = fill
    fill:Hide()
    self._fieldFrame = field

    self._sprLayer = CreateFrame("Frame", nil, field)
    self._sprLayer:SetAllPoints(field)
    self._sprLayer:SetFrameLevel(field:GetFrameLevel() + 3)
    self._sprLayer:Hide()
    self._spr = {}
    self._sprUsed = 0

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGoldGridFrame then
        self._goldGrid = UI.CreateGoldGridFrame(canvas, field, { pad = CFG.gold_pad or GOLD_PAD, fillAlpha = 0 })
    end

    self._dbgLayer = CreateFrame("Frame", nil, field)
    self._dbgLayer:SetAllPoints(field)
    self._dbgLayer:SetFrameLevel(field:GetFrameLevel() + 7)
    self._dbgLayer:Hide()
    self._dbgSeg = {}
    self._dbgCirc = {}
    self._dbgUsedSeg = 0
    self._dbgUsedCirc = 0

    local s = WS()
    self._eyeLayer = CreateFrame("Frame", nil, field)
    self._eyeLayer:SetAllPoints(field)
    self._eyeLayer:SetFrameLevel(field:GetFrameLevel() + 4)
    local eyeLayer = self._eyeLayer
    local sclera = eyeLayer:CreateTexture(nil, "ARTWORK", nil, 1)
    sclera:SetSize(CFG.eye_s * s, CFG.eye_s * s)
    sclera:SetPoint("CENTER", field, "TOPLEFT", CFG.eye_x * s, -CFG.eye_y * s)
    sclera:SetTexture(ASSETS .. "sprites\\eye_sclera")
    sclera:Hide()
    self._eyeSclera = sclera
    local pupil = eyeLayer:CreateTexture(nil, "ARTWORK", nil, 2)
    pupil:SetSize(CFG.eye_s * 0.42 * s, CFG.eye_s * 0.42 * s)
    pupil:SetTexture(ASSETS .. "sprites\\eye_pupil")
    pupil:Hide()
    self._eyePupil = pupil
    local lid = eyeLayer:CreateTexture(nil, "ARTWORK", nil, 3)
    lid:SetSize(CFG.eye_s * s, CFG.eye_s * s)
    lid:SetPoint("CENTER", field, "TOPLEFT", CFG.eye_x * s, -CFG.eye_y * s)
    lid:SetTexture(ASSETS .. "sprites\\eye_lid")
    lid:Hide()
    self._eyeLid = lid
    self._eyeLookX, self._eyeLookY = 0, 0
    self._eyeTx, self._eyeTy = 0, 0
    self._eyeWanderT = 1.2
    self._eyeBlinkT = 2.8
    self._eyeBlink = 0
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    if not UI or not UI.CreateGameLogo or not self._canvas then return end
    self._logoTex = UI.CreateGameLogo(self._canvas, CFG.logo_path, {
        w = CFG.logo_w, h = CFG.logo_h,
        x = CFG.logo_ofs_x, y = CFG.logo_ofs_y,
        alpha = CFG.logo_alpha,
    })
end

function R:_CreateHUD()
    local canvas = self._canvas
    local UI = ArcadiaNexus.UI
    if not canvas or not UI or not UI.CreateHudStatBox then return end
    self._scoreBox, self._scoreFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_score_w, h = CFG.hud_score_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_left_x, y = CFG.hud_stat_y1,
        alpha = CFG.hud_score_alpha,
        shown = false,
    })
    self._ballsBox, self._ballsFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_balls_w, h = CFG.hud_balls_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_left_x, y = CFG.hud_stat_y2,
        alpha = CFG.hud_balls_alpha,
        shown = false,
    })
    self._comboBox, self._comboFS = UI.CreateHudStatBox(canvas, {
        w = CFG.hud_combo_w, h = CFG.hud_combo_h,
        point = "CENTER", relativePoint = "CENTER",
        x = CFG.hud_right_x, y = CFG.hud_stat_y1,
        alpha = CFG.hud_combo_alpha,
        shown = false,
    })
    local missionParent = self._fieldFrame or canvas
    self._missionBox, self._missionFS = UI.CreateHudStatBox(missionParent, {
        w = CFG.hud_mission_w, h = CFG.hud_mission_h,
        point = "TOP", relativePoint = "TOP",
        x = 0, y = CFG.hud_mission_y,
        alpha = CFG.hud_mission_alpha,
        shown = false,
        font = "GameFontNormalSmall",
    })
end

function R:_CreateKeyFrame()
    local field = self._fieldFrame
    if not field then return end
    local kf = CreateFrame("Frame", nil, field)
    kf:SetAllPoints(field)
    kf:EnableKeyboard(false)
    kf:SetPropagateKeyboardInput(false)
    kf:SetScript("OnKeyDown", function(_, key)
        local E = ArcadiaNexus.DMP_Engine
        if not E then return end
        if key == "A" or key == "LEFT" then E:HandleKey("LEFT_DOWN")
        elseif key == "D" or key == "RIGHT" then E:HandleKey("RIGHT_DOWN")
        elseif key == "SPACE" then E:HandleKey("LAUNCH")
        elseif key == "Q" then E:HandleKey("NUDGE_LEFT")
        elseif key == "E" then E:HandleKey("NUDGE_RIGHT")
        elseif key == "W" then E:HandleKey("NUDGE_UP")
        elseif key == "P" then E:HandleKey("PAUSE")
        elseif key == "F8" then E:HandleKey("DEBUG")
        end
    end)
    kf:SetScript("OnKeyUp", function(_, key)
        local E = ArcadiaNexus.DMP_Engine
        if not E then return end
        if key == "A" or key == "LEFT" then E:HandleKey("LEFT_UP")
        elseif key == "D" or key == "RIGHT" then E:HandleKey("RIGHT_UP")
        elseif key == "SPACE" then E:HandleKey("LAUNCH_UP")
        end
    end)
    self._keyFrame = kf
end

function R:_CreateControls()
    local UI = ArcadiaNexus.UI
    if not UI or not self.frame then return end
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    self._controlsFrame = bar.frame
    local L = Loc()
    self._controlsBar = bar

    local ddAnchor = CreateFrame("Frame", nil, bar.frame)
    ddAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddAnchor:SetPoint("CENTER", bar.frame, "CENTER", bar.segX[1], bar.y.dropdownOfs)
    local tableOpts = {}
    local Logic = ArcadiaNexus.DMP_Logic
    local list = Logic and Logic.ListTables and Logic:ListTables() or {}
    for i = 1, #list do
        local t = list[i]
        tableOpts[#tableOpts + 1] = {
            key = t.id,
            label = L[t.labelKey] or t.displayName or t.id,
        }
    end
    if #tableOpts < 1 then
        tableOpts[1] = { key = "darkmoon_midway", label = L.dmp_table_midway or "Midway" }
    end
    self._tableDropdown = UI.CreateSimpleDropdown(
        ddAnchor, 0, 0, CFG.dd_w, "",
        tableOpts,
        function()
            local S = ArcadiaNexus.DMP_Settings
            return (S and S:Get("tableId")) or "darkmoon_midway"
        end,
        function(key)
            local S = ArcadiaNexus.DMP_Settings
            if S then S:Set("tableId", key) end
            local Logic = ArcadiaNexus.DMP_Logic
            local def = Logic and Logic.GetTable and Logic:GetTable(key)
            if R.state == "PLAYING" or R.state == "GAMEOVER" then
                R:_ApplyPlayfield(def and def.theme)
            end
        end
    )
    self._tableDdAnchor = ddAnchor

    local startBtn = UI.CreateArcadiaButton(bar.frame, L.btn_start or "Start", CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", bar.frame, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.DMP_Engine
        if not E then return end
        if R.state == "PLAYING" or (E.state == "PLAYING" or E.state == "PAUSED") then
            E:StopGame()
        elseif R.state == "IDLE" or R.state == "GAMEOVER" then
            E:StartGame()
        end
    end)
    self._startBtn = startBtn

    local pauseBtn = UI.CreateArcadiaButton(bar.frame, L.btn_pause or "Pause", CFG.btn_w, CFG.btn_h)
    pauseBtn:SetPoint("BOTTOM", bar.frame, "BOTTOM", bar.segX[3], bar.y.button)
    pauseBtn:SetScript("OnClick", function()
        local E = ArcadiaNexus.DMP_Engine
        if not E then return end
        if E.state == "PLAYING" then
            E:Pause()
        elseif E.state == "PAUSED" then
            E:Resume()
        end
    end)
    pauseBtn:Hide()
    self._pauseBtn = pauseBtn
end

function R:_CreatePauseOverlay()
    local field = self._fieldFrame
    if not field then return end
    local ov = CreateFrame("Frame", nil, field)
    ov:SetAllPoints(field)
    ov:SetFrameLevel(field:GetFrameLevel() + 40)
    ov:Hide()
    local tex = ov:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(ov)
    tex:SetColorTexture(0, 0, 0, 0.45)
    local fs = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    fs:SetTextColor(1, 0.85, 0.4)
    self._pauseFS = fs
    self._pauseOv = ov

    local tiltOv = CreateFrame("Frame", nil, field)
    tiltOv:SetAllPoints(field)
    tiltOv:SetFrameLevel(field:GetFrameLevel() + 35)
    tiltOv:Hide()
    local tiltBg = tiltOv:CreateTexture(nil, "BACKGROUND")
    tiltBg:SetAllPoints(tiltOv)
    tiltBg:SetColorTexture(0.45, 0.05, 0.02, 0.35)
    local tiltFS = tiltOv:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tiltFS:SetPoint("CENTER")
    tiltFS:SetTextColor(1, 0.35, 0.2)
    self._tiltFS = tiltFS
    self._tiltOv = tiltOv
end

function R:_CreateFlash()
    local field = self._fieldFrame
    if not field then return end
    local flash = field:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(field)
    flash:SetColorTexture(1, 0.2, 0.2, 0)
    flash:Hide()
    self._flashTex = flash
end

function R:FlashScreen(r, g, b)
    local S = ArcadiaNexus.DMP_Settings
    if S and S:Get("reducedMotion") then return end
    local tex = self._flashTex
    if not tex then return end
    tex:SetColorTexture(r or 1, g or 0.2, b or 0.2, 0.35)
    tex:Show()
    local guard = ArcadiaNexus.DMP_Engine and ArcadiaNexus.DMP_Engine._timerGuard
    if guard then
        guard:After(0.12, function()
            if tex then tex:Hide() end
        end)
    else
        tex:Hide()
    end
end

function R:_SetTableArtShown(shown)
    if self._fieldFill then
        if shown then self._fieldFill:Show() else self._fieldFill:Hide() end
    end
    if self._sprLayer then
        if shown then self._sprLayer:Show() else self._sprLayer:Hide() end
    end
    if not shown then
        self:_HideSprites()
        self:_HideEye()
        self:_HideDebug()
    end
end

function R:_SetHudShown(shown)
    local boxes = { self._scoreBox, self._ballsBox, self._comboBox, self._missionBox, self._goldGrid }
    for i = 1, #boxes do
        local b = boxes[i]
        if b then
            if shown then b:Show() else b:Hide() end
        end
    end
end

function R:EnterIdleState()
    self.state = "IDLE"
    local L = Loc()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    self:_SetHudShown(false)
    self:_SetTableArtShown(false)
    self:_HideDebug()
    if self._pauseOv then self._pauseOv:Hide() end
    if self._tiltOv then self._tiltOv:Hide() end
    -- A result-dialog retry starts a fresh session before the old flash timer
    -- necessarily runs.  Never carry a game-over flash into the new ball.
    if self._flashTex then
        self._flashTex:SetColorTexture(1, 0.2, 0.2, 0)
        self._flashTex:Hide()
    end
    if self._flashTex then self._flashTex:Hide() end
    if self._keyFrame then
        self._keyFrame:EnableKeyboard(false)
        self._keyFrame:Hide()
    end
    if self._startBtn then
        self._startBtn:SetLabel(L.btn_start or "Start")
        self._startBtn:Show()
    end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._tableDdAnchor then self._tableDdAnchor:Show() end
    if self._logoTex then self._logoTex:Show() end
    self:_HideEye()
    self._trail = {}
    self._pops = {}
    self._rings = {}
    self._shakeT = 0
    self._eyePulseT = 0
    self._jackpotPulseT = 0
    self._multiballPulseT = 0
    self._shakeAmp = 0
    if self._bannerFS then self._bannerFS:Hide() end
    if self._fieldFrame and self._canvas then
        self._fieldFrame:ClearAllPoints()
        self._fieldFrame:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    end
end

function R:OnGameStarted(gs)
    self.state = "PLAYING"
    local L = Loc()
    ArcadiaNexus.UI.HideResultDialog(self._fieldFrame)
    if self._logoTex then self._logoTex:Hide() end
    self:_SetHudShown(true)
    self:_SetTableArtShown(true)
    if self._keyFrame then
        self._keyFrame:Show()
        self._keyFrame:EnableKeyboard(true)
    end
    if self._startBtn then
        self._startBtn:SetLabel(L.btn_end or L.btn_exit or "Beenden")
        self._startBtn:Show()
    end
    if self._pauseBtn then
        self._pauseBtn:SetLabel(L.btn_pause or "Pause")
        self._pauseBtn:Show()
    end
    if self._tableDdAnchor then self._tableDdAnchor:Hide() end
    if self._pauseOv then self._pauseOv:Hide() end
    if self._tiltOv then self._tiltOv:Hide() end
    -- A result-dialog retry starts a fresh session before the old flash timer
    -- necessarily runs.  Never carry a game-over flash into the new ball.
    if self._flashTex then
        self._flashTex:SetColorTexture(1, 0.2, 0.2, 0)
        self._flashTex:Hide()
    end
    self._trail = {}
    self._pops = {}
    self._rings = {}
    self:_ApplyPlayfield(gs and gs.def and gs.def.theme)
    self:UpdateView(gs)
end

function R:ShowPause()
    local L = Loc()
    if self._pauseFS then self._pauseFS:SetText(L.state_paused or "Pause") end
    if self._pauseOv then self._pauseOv:Show() end
    if self._pauseBtn then self._pauseBtn:SetLabel(L.btn_continue or "Weiter") end
    if self._keyFrame then self._keyFrame:EnableKeyboard(true) end
end

function R:OnTilt(gs)
    local L = Loc()
    if self._tiltFS then self._tiltFS:SetText(L.state_tilt or "TILT") end
    if self._tiltOv then self._tiltOv:Show() end
    local S = ArcadiaNexus.DMP_Settings
    if S and S:Get("screenFlash") then
        self:FlashScreen(1, 0.2, 0.1)
    end
    self:_Shake(2.6)
    self:UpdateView(gs)
end

function R:HidePause()
    local L = Loc()
    if self._pauseOv then self._pauseOv:Hide() end
    if self._pauseBtn then self._pauseBtn:SetLabel(L.btn_pause or "Pause") end
end

function R:ShowGameOver(gs)
    self.state = "GAMEOVER"
    if self._keyFrame then self._keyFrame:EnableKeyboard(false) end
    if self._pauseBtn then self._pauseBtn:Hide() end
    if self._tableDdAnchor then self._tableDdAnchor:Show() end
    if self._startBtn then
        self._startBtn:SetLabel(Loc().btn_start or "Start")
        self._startBtn:Show()
    end
    self:UpdateView(gs)
    local L = Loc()
    local UI = ArcadiaNexus.UI
    if not UI or not UI.ShowArcadeResult or not self._fieldFrame then return end
    local isNew = gs and gs.score and gs.highScore and gs.score >= gs.highScore and gs.score > 0
    UI.ShowArcadeResult(self._fieldFrame, {
        gameId       = GAME_ID,
        difficulty   = gs and gs.tableId or "darkmoon_midway",
        result       = "LOSS",
        score        = gs and gs.score or 0,
        newHighscore = isNew,
        title        = L.state_gameover,
        L            = L,
        lines = {
            (L.lbl_combo or "Combo") .. ": " .. tostring(gs and gs.maxCombo or 0),
            (L.dmp_missions or L.lbl_mission or "Mission") .. ": " .. tostring(gs and gs.missionsDone or 0),
            (L.dmp_multiballs or "Multiball") .. ": " .. tostring(gs and gs.multiballs or 0),
            (L.dmp_extra_balls or "Extra Ball") .. ": " .. tostring(gs and gs.extraBalls or 0),
        },
        onRetry = function()
            local E = ArcadiaNexus.DMP_Engine
            if E then E:StartGame() end
        end,
        onExit = function()
            local E = ArcadiaNexus.DMP_Engine
            if E then E:StopGame() end
        end,
    })
end

function R:UpdateHUD(gs)
    local L = Loc()
    if self._scoreFS then
        self._scoreFS:SetText((L.lbl_score or "Score") .. ": " .. FormatScore(gs and gs.score or 0))
        self._scoreFS:SetTextColor(1.0, 0.84, 0.36)
    end
    if self._ballsFS then
        self._ballsFS:SetText((L.lbl_balls or "Balls") .. ": " .. tostring(gs and gs.ballsRemaining or 0))
        self._ballsFS:SetTextColor(0.93, 0.86, 0.70)
    end
    if self._comboFS then
        local hot = gs and ((gs.combo or 0) >= 3 or gs.multiball)
        self._comboFS:SetText((L.lbl_combo or "Combo") .. ": x" .. tostring(gs and gs.combo or 0))
        self._comboFS:SetTextColor(hot and 0.88 or 0.72, hot and 0.62 or 0.54, 1.0)
    end
    if self._missionFS then
        local text = ""
        if gs and gs.tilted then
            text = L.state_tilt or "TILT"
        elseif gs and gs.mission then
            local m = gs.mission
            local name = L["dmp_" .. m.id] or m.id
            text = name .. "  " .. tostring(m.have or 0) .. "/" .. tostring(m.need or 0)
                .. "  " .. tostring(math.ceil(m.t or 0)) .. "s"
        elseif gs and gs.multiball then
            text = L.dmp_multiballs or "Multiball"
        elseif gs and gs.ballSaveT and gs.ballSaveT > 0 then
            text = (L.lbl_ball_save or "Ball Save") .. "  " .. tostring(math.ceil(gs.ballSaveT)) .. "s"
        elseif gs and gs.outlaneSaveT and gs.outlaneSaveT > 0 then
            text = L.lbl_outlane_save or "Save"
        elseif gs and gs.kickbackArmed and (gs.kickbackArmed.left or gs.kickbackArmed.right) then
            text = L.lbl_kickback or "Kickback"
        elseif gs and gs.tiltWarn and gs.tiltWarn > 0 then
            text = (L.lbl_tilt or "Tilt") .. " " .. tostring(gs.tiltWarn)
        end
        self._missionFS:SetText(text)
        if gs and gs.tilted then
            self._missionFS:SetTextColor(1.0, 0.34, 0.24)
        elseif gs and (gs.multiball or gs.mission) then
            self._missionFS:SetTextColor(1.0, 0.80, 0.34)
        else
            self._missionFS:SetTextColor(0.88, 0.72, 1.0)
        end
        if self._missionBox then
            if text ~= "" then self._missionBox:Show() else self._missionBox:Hide() end
        end
    end
end

local function AssetGet(kind, state)
    local A = ArcadiaNexus.DMP_Assets
    if A and A.Get then return A.Get(kind, state) end
    return nil
end

local function HitState(gs, id, idle, hit1, hit2)
    local t = gs and gs.hitCool and gs.hitCool[id]
    if t and t > 0.045 then return hit1 or "hit_01" end
    if t and t > 0 then return hit2 or "hit_02" end
    return idle or "idle"
end

function R:_ApplyPlayfield(theme)
    if not self._fieldFill then return end
    local key = (theme == "carousel") and "carousel" or "midway"
    local path = AssetGet("playfield", key)
    if path then
        self._fieldFill:SetTexture(path)
        self._fieldFill:SetVertexColor(1, 1, 1, 1)
    else
        self._fieldFill:SetColorTexture(0.07, 0.05, 0.10, 0.98)
    end
end

function R:_Spr(path, x, y, w, h, rot, a, mirrorX)
    if not path or not self._sprLayer then return end
    self._sprUsed = (self._sprUsed or 0) + 1
    local tex = self._spr[self._sprUsed]
    if not tex then
        tex = self._sprLayer:CreateTexture(nil, "ARTWORK")
        self._spr[self._sprUsed] = tex
    end
    tex:SetTexture(path)
    if tex.SetTexCoord then
        if mirrorX then tex:SetTexCoord(1, 0, 0, 1) else tex:SetTexCoord(0, 1, 0, 1) end
    end
    tex:Show()
    tex:ClearAllPoints()
    tex:SetSize(w * WS(), h * WS())
    tex:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", x * WS(), -y * WS())
    tex:SetVertexColor(1, 1, 1, a or 1)
    if tex.SetRotation then tex:SetRotation(rot or 0) end
end

function R:_HideSprites()
    for i = 1, #(self._spr or {}) do
        self._spr[i]:Hide()
    end
    self._sprUsed = 0
end

function R:_DrawSprites(gs)
    if not gs or not self._sprLayer then
        self:_HideSprites()
        return
    end
    self._sprLayer:Show()
    self._sprUsed = 0
    local def = gs.def
    local chaseActive = gs.multiball or gs.mission or (gs.combo or 0) >= 3 or (gs.scoreFrenzyT or 0) > 0
    local chaseStep = math.floor((gs.elapsed or 0) * (gs.multiball and 10 or 6))
    if def.slingshots then
        for i = 1, #def.slingshots do
            local s = def.slingshots[i]
            local mx, my = (s.ax + s.bx) * 0.5, (s.ay + s.by) * 0.5
            local rot = -math.atan2(s.by - s.ay, s.bx - s.ax)
            self:_Spr(AssetGet("slingshot", "base"), mx, my, 48, 48, rot, 0.95)
        end
    end
    if def.posts then
        for i = 1, #def.posts do
            local p = def.posts[i]
            self:_Spr(AssetGet("post", "base"), p.x, p.y, p.r * 3, p.r * 3, 0, 1)
        end
    end
    if def.bumpers then
        for i = 1, #def.bumpers do
            local b = def.bumpers[i]
            local st = HitState(gs, b.id, "idle", "hit_01", "hit_02")
            if st == "idle" and gs.bumperLit and gs.bumperLit[b.id] then st = "lit" end
            if st == "idle" and chaseActive and ((i - 1) == (chaseStep % #def.bumpers)) then st = "lit" end
            local d = b.r * 2.15
            self:_Spr(AssetGet("bumper", st), b.x, b.y, d, d, 0, 1)
        end
    end
    if def.targets then
        for i = 1, #def.targets do
            local t = def.targets[i]
            local st = HitState(gs, t.id, "idle", "hit", "hit")
            if st == "idle" and gs.targetLit and gs.targetLit[t.id] then st = "active" end
            if gs.mission and gs.mission.id == "target_hunt" and t.order == gs.mission.nextOrder then
                st = "active"
            elseif st == "idle" and chaseActive and ((i - 1) == (chaseStep % #def.targets)) then
                st = "active"
            end
            self:_Spr(AssetGet("target", st), t.x, t.y, t.r * 3, t.r * 3, 0, 1)
        end
    end
    if def.inlanes then
        for i = 1, #def.inlanes do
            local ln = def.inlanes[i]
            local st = "off"
            if gs.kickbackArmed and gs.kickbackArmed[ln.side] then st = "lit" end
            if chaseActive and ((i - 1) == (chaseStep % #def.inlanes)) then st = "completed" end
            local mx, my = (ln.x1 + ln.x2) * 0.5, (ln.y1 + ln.y2) * 0.5
            self:_Spr(AssetGet("lane", st), mx, my, ln.x2 - ln.x1, 12, 0, 0.9)
        end
    end
    if def.outlanes then
        for i = 1, #def.outlanes do
            local o = def.outlanes[i]
            local st = "idle"
            if gs.kickbackArmed and gs.kickbackArmed[o.side] then st = "armed" end
            if gs.kickbackT and (gs.kickbackT[o.side] or 0) > 0 and gs.kickbackArmed and not gs.kickbackArmed[o.side] then
                st = "fire"
            end
            local mx = (o.x1 + o.x2) * 0.5
            self:_Spr(AssetGet("kickback", st), mx, o.y1 + 8, 22, 22, 0, 0.95)
        end
    end
    if def.lock then
        local lk = def.lock
        local on = gs.mission and gs.mission.id == "arcane_lock"
        self:_Spr(AssetGet("light", on and "on" or "off"), (lk.x1 + lk.x2) * 0.5, (lk.y1 + lk.y2) * 0.5, 16, 16, 0, 1)
    end
    if def.jackpot then
        local jp = def.jackpot
        local flash = gs.multiball
        self:_Spr(AssetGet("light", flash and "flash" or "off"), (jp.x1 + jp.x2) * 0.5, (jp.y1 + jp.y2) * 0.5, 18, 18, 0, 1)
        if flash then
            self:_Spr(AssetGet("arrow", "base"), (jp.x1 + jp.x2) * 0.5, jp.y1 - 10, 16, 16, 0, 1)
        end
    end
    for i = 1, #(gs.flippers or {}) do
        local f = gs.flippers[i]
        local active = math.abs((f.angle or 0) - (f.restAngle or 0)) > 0.08
        local mx = f.px + math.cos(f.angle) * f.length * 0.5
        local my = f.py + math.sin(f.angle) * f.length * 0.5
        local state = active and "activeGlow" or "base"
        local renderAngle = -(f.angle or 0)
        if string.find(f.id or "", "^right") then
            state = active and "activeGlow_right" or "base_right"
            -- The right asset is a horizontal mirror: compensate its reversed
            -- source axis, while preserving the physics-defined flipper angle.
            renderAngle = renderAngle + math.pi
        end
        self:_Spr(AssetGet("flipper", state),
            mx, my, f.length + 14, f.radius * 5, renderAngle, 1
        )
    end
    local lane = def.launchLane or {}
    local x1 = lane.x or def.shooterX or 246
    local x2 = x1 + 20
    local lx = lane.centerX or ((x1 + x2) * 0.5)
    local yLaneBot = lane.yBot or 400
    local spawnY = (def.spawn and def.spawn.y) or 348
    local pull = 0
    if gs.phase == "ready" then pull = gs.plungerPull or 0 end
    local ballY = spawnY + pull * (def.plungerTravel or 22)
    if gs.phase == "ready" and gs.balls and gs.balls[1] and gs.balls[1].locked then
        ballY = gs.balls[1].y
    end
    local ballR = (gs.balls and gs.balls[1] and gs.balls[1].r) or 7
    local springTop = ballY + ballR + 1
    local springBot = yLaneBot - 3
    if springBot < springTop + 10 then springBot = springTop + 10 end
    if springBot > yLaneBot - 2 then springBot = yLaneBot - 2 end
    local springH = springBot - springTop
    local springY = springTop + springH * 0.5
    self:_Spr(AssetGet("plunger", "spring"), lx, springY, 10, springH, 0, 1)
    self:_Spr(AssetGet("plunger", "knob"), lx, springBot - 3, 14, 8, 0, 1)
    for i = 1, #(gs.balls or {}) do
        local b = gs.balls[i]
        if b and b.active then
            local d = b.r * 2.4
            self:_Spr(AssetGet("ball", "base"), b.x, b.y, d, d, 0, b.locked and 0.55 or 1)
            if not b.locked then
                self:_Spr(AssetGet("ball", "highlight"), b.x - 1, b.y - 1, d * 0.85, d * 0.85, 0, 0.65)
            end
        end
    end
    for i = self._sprUsed + 1, #self._spr do
        self._spr[i]:Hide()
    end
end

local function Acquire(list, used, parent)
    local tex = list[used]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(WHITE)
        list[used] = tex
    end
    tex:Show()
    return tex
end

function R:_HideDebug()
    if self._dbgLayer then self._dbgLayer:Hide() end
    if self._dbgInfoFS then self._dbgInfoFS:Hide() end
    for i = 1, #(self._dbgSeg or {}) do
        self._dbgSeg[i]:Hide()
    end
    for i = 1, #(self._dbgCirc or {}) do
        self._dbgCirc[i]:Hide()
    end
    self._dbgUsedSeg = 0
    self._dbgUsedCirc = 0
end

function R:_DrawSeg(ax, ay, bx, by, r, g, b, a)
    self._dbgUsedSeg = self._dbgUsedSeg + 1
    local tex = Acquire(self._dbgSeg, self._dbgUsedSeg, self._dbgLayer)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then len = 1 end
    local s = WS()
    tex:ClearAllPoints()
    tex:SetSize(len * s, 2 * s)
    tex:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", (ax + bx) * 0.5 * s, -((ay + by) * 0.5 * s))
    tex:SetVertexColor(r, g, b, a or 0.9)
    if tex.SetRotation then
        tex:SetRotation(-math.atan2(dy, dx))
    end
end

function R:_DrawCirc(x, y, rad, r, g, b, a)
    self._dbgUsedCirc = self._dbgUsedCirc + 1
    local tex = Acquire(self._dbgCirc, self._dbgUsedCirc, self._dbgLayer)
    local s = WS()
    local d = rad * 2 * s
    tex:SetTexture(AssetGet("fx", "ring") or WHITE)
    if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    tex:ClearAllPoints()
    tex:SetSize(d, d)
    tex:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", x * s, -y * s)
    tex:SetVertexColor(r, g, b, a or 0.85)
    if tex.SetRotation then tex:SetRotation(0) end
end

function R:_DrawTable(gs)
    local S = ArcadiaNexus.DMP_Settings
    local show = not S or S:Get("debugOverlay") ~= false
    if not show or not gs or not self._dbgLayer then
        self:_HideDebug()
        return
    end
    self._dbgLayer:Show()
    self._dbgUsedSeg = 0
    self._dbgUsedCirc = 0
    local def = gs.def
    for i = 1, #def.walls do
        local w = def.walls[i]
        self:_DrawSeg(w.ax, w.ay, w.bx, w.by, 0.75, 0.7, 0.45, 0.95)
    end
    if def.slingshots then
        for i = 1, #def.slingshots do
            local s = def.slingshots[i]
            self:_DrawSeg(s.ax, s.ay, s.bx, s.by, 0.95, 0.55, 0.25, 0.95)
        end
    end
    local d = def.drain
    if d.points and #d.points >= 3 then
        for i = 1, #d.points - 1 do
            local a, b = d.points[i], d.points[i + 1]
            self:_DrawSeg(a.x, a.y, b.x, b.y, 0.9, 0.2, 0.25, 0.8)
        end
    else
        self:_DrawSeg(d.x1, d.y1, d.x2, d.y2, 0.9, 0.2, 0.25, 0.8)
    end
    if def.outlanes then
        for i = 1, #def.outlanes do
            local o = def.outlanes[i]
            local armed = gs.kickbackArmed and gs.kickbackArmed[o.side]
            local save = (gs.outlaneSaveT or 0) > 0
            local r, g, b = 0.85, 0.25, 0.2
            if armed or save then r, g, b = 0.25, 0.9, 0.4 end
            self:_DrawSeg(o.x1, o.y1, o.x2, o.y1, r, g, b, 0.9)
            self:_DrawSeg(o.x1, o.y2, o.x2, o.y2, r, g, b, 0.55)
        end
    end
    if def.inlanes then
        for i = 1, #def.inlanes do
            local o = def.inlanes[i]
            local armed = gs.kickbackArmed and gs.kickbackArmed[o.side]
            local r, g, b = 0.4, 0.7, 1
            if armed then r, g, b = 0.3, 1, 0.55 end
            self:_DrawSeg(o.x1, o.y1, o.x2, o.y1, r, g, b, 0.85)
        end
    end
    for i = 1, #def.bumpers do
        local b = def.bumpers[i]
        local lit = gs.bumperLit and gs.bumperLit[b.id]
        if lit then
            self:_DrawCirc(b.x, b.y, b.r, 0.85, 0.55, 1, 0.95)
        else
            self:_DrawCirc(b.x, b.y, b.r, 0.55, 0.35, 0.95, 0.7)
        end
    end
    if def.ramps then
        for i = 1, #def.ramps do
            local r = def.ramps[i]
            local pulse = 0.55 + 0.35 * math.abs(math.sin((gs.elapsed or 0) * 7))
            local lit = gs.rampQual and r.side and gs.rampQual[r.side]
            local a = lit and pulse or 0.85
            self:_DrawSeg(r.x1, r.y1, r.x2, r.y1, 0.45, 0.85, 1, a)
            self:_DrawSeg(r.x1, r.y2, r.x2, r.y2, 0.45, 0.85, 1, a * 0.6)
        end
    end
    if def.targets then
        for i = 1, #def.targets do
            local t = def.targets[i]
            local lit = gs.targetLit and gs.targetLit[t.id]
            local r, g, b = 0.95, 0.7, 0.25
            if lit then r, g, b = 1, 0.95, 0.4 end
            self:_DrawCirc(t.x, t.y, t.r, r, g, b, 0.8)
        end
    end
    if def.lock then
        local lk = def.lock
        local a = (gs.mission and gs.mission.id == "arcane_lock") and 0.95 or 0.55
        self:_DrawSeg(lk.x1, lk.y1, lk.x2, lk.y1, 0.75, 0.4, 1, a)
        self:_DrawSeg(lk.x1, lk.y2, lk.x2, lk.y2, 0.75, 0.4, 1, a * 0.6)
    end
    if def.jackpot then
        local jp = def.jackpot
        local a = gs.multiball and 1 or 0.4
        self:_DrawSeg(jp.x1, jp.y1, jp.x2, jp.y1, 1, 0.85, 0.25, a)
        self:_DrawSeg(jp.x1, jp.y2, jp.x2, jp.y2, 1, 0.85, 0.25, a * 0.6)
    end
    if def.kickers then
        for i = 1, #def.kickers do
            local k = def.kickers[i]
            self:_DrawCirc(k.x, k.y, k.r, 0.95, 0.55, 0.2, 0.7)
        end
    end
    if def.posts then
        for i = 1, #def.posts do
            local p = def.posts[i]
            self:_DrawCirc(p.x, p.y, p.r, 0.6, 0.6, 0.65, 0.8)
        end
    end
    for i = 1, #gs.flippers do
        local f = gs.flippers[i]
        local tx = f.px + math.cos(f.angle) * f.length
        local ty = f.py + math.sin(f.angle) * f.length
        local active = math.abs((f.angle or 0) - (f.restAngle or 0)) > 0.08
        local r, g, b = 0.95, 0.82, 0.35
        if active then r, g, b = 1, 0.95, 0.55 end
        self:_DrawSeg(f.px, f.py, tx, ty, r, g, b, 1)
        self:_DrawCirc(f.px, f.py, 3, 1, 0.9, 0.4, 1)
        self:_DrawCirc(tx, ty, f.radius, r, g, b, 0.7)
    end
    for i = 1, #gs.balls do
        local ball = gs.balls[i]
        if ball and ball.active then
            self:_DrawCirc(ball.x, ball.y, ball.r, 0.95, 0.95, 1, ball.locked and 0.45 or 1)
            if not ball.locked then
                local sp = math.sqrt((ball.vx or 0) ^ 2 + (ball.vy or 0) ^ 2)
                if sp > 40 then
                    local s = 18 / sp
                    self:_DrawSeg(ball.x, ball.y, ball.x - ball.vx * s, ball.y - ball.vy * s, 0.6, 0.85, 1, 0.55)
                end
            end
        end
    end
    if self._dbgInfoFS then
        local b = gs.balls and gs.balls[1]
        local sp = 0
        if b then sp = math.sqrt((b.vx or 0) ^ 2 + (b.vy or 0) ^ 2) end
        self._dbgInfoFS:SetText(string.format(
            "v %.0f  sub %d  hit %s",
            sp, gs.lastSubsteps or 1, tostring(gs.debug and gs.debug.lastHitId or "")
        ))
        self._dbgInfoFS:Show()
    end
    for i = self._dbgUsedSeg + 1, #self._dbgSeg do
        self._dbgSeg[i]:Hide()
    end
    for i = self._dbgUsedCirc + 1, #self._dbgCirc do
        self._dbgCirc[i]:Hide()
    end
    if not show and self._dbgInfoFS then self._dbgInfoFS:Hide() end
end

function R:_CreateFx()
    local field = self._fieldFrame
    if not field then return end
    self._fxLayer = CreateFrame("Frame", nil, field)
    self._fxLayer:SetAllPoints(field)
    self._fxLayer:SetFrameLevel(field:GetFrameLevel() + 12)
    self._fxCirc = {}
    self._fxUsedCirc = 0
    self._popFS = {}
    self._trail = {}
    self._pops = {}
    self._rings = {}
    self._shakeT = 0
    self._eyePulseT = 0
    self._jackpotPulseT = 0
    self._multiballPulseT = 0
    self._shakeAmp = 0
    self._bannerT = 0
    local banner = field:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner:SetPoint("TOP", field, "TOP", 0, -18)
    banner:SetTextColor(0.95, 0.8, 1)
    banner:Hide()
    self._bannerFS = banner
    local info = field:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOMLEFT", field, "BOTTOMLEFT", 8, 6)
    info:SetTextColor(0.7, 0.72, 0.8)
    info:Hide()
    self._dbgInfoFS = info
end

function R:_Shake(amp)
    local S = ArcadiaNexus.DMP_Settings
    if S and S:Get("reducedMotion") then return end
    self._shakeAmp = math.max(self._shakeAmp or 0, amp or 1.2)
    self._shakeT = 0.18
end

function R:_FindId(list, id)
    if not list then return nil end
    for i = 1, #list do
        if list[i].id == id then return list[i] end
    end
    return nil
end

function R:OnFx(act, gs)
    local Fx = ArcadiaNexus.DMP_Fx
    if not Fx or not act then return end
    local S = ArcadiaNexus.DMP_Settings
    local reduced = S and S:Get("reducedMotion")
    local L = Loc()
    local def = gs and gs.def
    local t = act.type
    if t == "bumper_hit" then
        local b = self:_FindId(def and def.bumpers, act.id)
        if b then
            if not reduced then self._rings[#self._rings + 1] = Fx.Ring(b.x, b.y, 0.75, 0.45, 1) end
            self._pops[#self._pops + 1] = Fx.Popup(b.x, b.y - 16, "+" .. tostring(act.score or 0), 1, 0.85, 0.5)
        end
        self:_Shake(1.6)
    elseif t == "sling_hit" then
        self:_Shake(1.4)
    elseif t == "target_hit" then
        local tg = self:_FindId(def and def.targets, act.id)
        if tg and not reduced then
            self._rings[#self._rings + 1] = Fx.Ring(tg.x, tg.y, 1, 0.8, 0.3)
        end
    elseif t == "flipper_hit" then
        -- swipe is the brighter flipper in debug
    elseif t == "kickback" or t == "outlane_save" or t == "shield_save" then
        self:_Shake(2.2)
        local ball = gs and gs.balls and gs.balls[1]
        if ball then
            self._pops[#self._pops + 1] = Fx.Popup(ball.x, ball.y, L.lbl_kickback or "Save", 0.4, 1, 0.5)
        end
    elseif t == "mission_start" then
        self._bannerT = Fx.BANNER_TTL
        if self._bannerFS then
            self._bannerFS:SetText(L["dmp_" .. (act.id or "")] or act.id or "")
            self._bannerFS:Show()
        end
    elseif t == "mission_complete" then
        self._bannerT = Fx.BANNER_TTL
        if self._bannerFS then
            self._bannerFS:SetText((L["dmp_" .. (act.id or "")] or L.lbl_mission or "Mission") .. "!")
            self._bannerFS:Show()
        end
        self:_Shake(1.2)
    elseif t == "multiball_start" then
        self._multiballPulseT = 1.15
        self._eyePulseT = (def and def.theme == "darkmoon") and 0.95 or 0
        self._bannerT = Fx.BANNER_TTL
        if self._bannerFS then
            self._bannerFS:SetText(L.dmp_multiballs or "Multiball")
            self._bannerFS:Show()
        end
        self:_Shake(2.4)
    elseif t == "jackpot" or t == "super_jackpot" then
        self._jackpotPulseT = (t == "super_jackpot") and 1.15 or 0.72
        self._eyePulseT = (def and def.theme == "darkmoon") and self._jackpotPulseT or 0
        self._bannerT = Fx.BANNER_TTL * 0.7
        if self._bannerFS then
            self._bannerFS:SetText(t == "super_jackpot" and (L.dmp_super_jackpot or "Super Jackpot") or (L.dmp_jackpots or "Jackpot"))
            self._bannerFS:Show()
        end
        self:_Shake(1.8)
    elseif t == "powerup" then
        self._bannerT = Fx.BANNER_TTL * 0.8
        if self._bannerFS then
            self._bannerFS:SetText(L["dmp_power_" .. tostring(act.id or "")] or act.id or (L.lbl_mission or "Bonus"))
            self._bannerFS:Show()
        end
    end
end

function R:_DrawFx(gs, dt)
    local Fx = ArcadiaNexus.DMP_Fx
    local S = ArcadiaNexus.DMP_Settings
    local reduced = S and S:Get("reducedMotion")
    dt = dt or 0
    if self._shakeT and self._shakeT > 0 then
        self._shakeT = self._shakeT - dt
        if self._shakeT < 0 then self._shakeT = 0 end
    end
    local ox, oy = 0, 0
    if Fx then
        ox, oy = Fx.ShakeOffset(self._shakeT, self._shakeAmp)
    end
    if self._fieldFrame then
        self._fieldFrame:ClearAllPoints()
        self._fieldFrame:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x + ox, CFG.field_ofs_y + oy)
    end
    if self._bannerT and self._bannerT > 0 then
        self._bannerT = self._bannerT - dt
        if self._bannerT <= 0 and self._bannerFS then self._bannerFS:Hide() end
    end
    for _, key in ipairs({ "_eyePulseT", "_jackpotPulseT", "_multiballPulseT" }) do
        if self[key] and self[key] > 0 then self[key] = math.max(0, self[key] - dt) end
    end
    if not self._fxLayer then return end
    if Fx then
        Fx.TickList(self._pops, dt)
        Fx.TickList(self._rings, dt)
    end
    self._trail = self._trail or {}
    if gs and not reduced and Fx then
        for i = 1, #gs.balls do
            local b = gs.balls[i]
            if b and b.active and not b.locked then
                Fx.PushTrail(self._trail, b.x, b.y)
            end
        end
    else
        self._trail = {}
    end
    self._fxUsedCirc = 0
    self._fxLayer:Show()
    local function fxCirc(x, y, rad, r, g, b, a, path, useMask)
        self._fxUsedCirc = self._fxUsedCirc + 1
        local tex = Acquire(self._fxCirc, self._fxUsedCirc, self._fxLayer)
        tex:SetTexture(path or WHITE)
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
        if useMask and not tex._dmpMask and self._fxLayer.CreateMaskTexture and tex.AddMaskTexture then
            local mask = self._fxLayer:CreateMaskTexture()
            mask:SetTexture(MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            tex:AddMaskTexture(mask)
            tex._dmpMask = mask
        end
        tex:ClearAllPoints()
        local s = WS()
        tex:SetSize(rad * 2 * s, rad * 2 * s)
        tex:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", x * s, -y * s)
        tex:SetVertexColor(r, g, b, a or 0.7)
    end
    if not reduced and gs and self._jackpotPulseT and self._jackpotPulseT > 0 and gs.def and gs.def.jackpot then
        local jp = gs.def.jackpot
        local u = self._jackpotPulseT / 1.15
        fxCirc((jp.x1 + jp.x2) * 0.5, (jp.y1 + jp.y2) * 0.5, 14 + (1 - u) * 20, 1.0, 0.72, 0.30, u * 0.8, AssetGet("fx", "glow"), false)
    end
    if not reduced and gs and self._multiballPulseT and self._multiballPulseT > 0 and gs.def and gs.def.bumpers then
        local u = self._multiballPulseT / 1.15
        for i = 1, #gs.def.bumpers do
            local b = gs.def.bumpers[i]
            fxCirc(b.x, b.y, b.r + 10 + (1 - u) * 10, 0.70, 0.48, 1.0, u * 0.45, AssetGet("fx", "ring"), false)
        end
    end
    if not reduced then
        for i = 1, #self._trail do
            local p = self._trail[i]
            local a = i / #self._trail * 0.35
            fxCirc(p.x, p.y, 3, 0.7, 0.55, 1, a, WHITE, true)
        end
        local ringPath = AssetGet("fx", "ring")
        for i = 1, #self._rings do
            local ring = self._rings[i]
            local u = ring.t / (Fx and Fx.RING_TTL or 0.28)
            fxCirc(ring.x, ring.y, 10 + (1 - u) * 14, ring.r, ring.g, ring.b, 0.7 * u, ringPath, false)
        end
    end
    for i = 1, #self._pops do
        local p = self._pops[i]
        local fs = self._popFS[i]
        if not fs then
            fs = self._fxLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self._popFS[i] = fs
        end
        local u = p.t / (Fx and Fx.POPUP_TTL or 0.75)
        local s = WS()
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", p.x * s, -((p.y - (1 - u) * 18) * s))
        fs:SetText(p.text)
        fs:SetTextColor(p.r, p.g, p.b, 0.2 + u * 0.8)
        fs:Show()
    end
    for i = #self._pops + 1, #self._popFS do
        self._popFS[i]:Hide()
    end
    for i = self._fxUsedCirc + 1, #self._fxCirc do
        self._fxCirc[i]:Hide()
    end
end

function R:_HideEye()
    if self._eyeSclera then self._eyeSclera:Hide() end
    if self._eyePupil then self._eyePupil:Hide() end
    if self._eyeLid then self._eyeLid:Hide() end
end

function R:_TickEye(dt)
    if self.state ~= "PLAYING" then
        self:_HideEye()
        return
    end
    local sclera, pupil, lid = self._eyeSclera, self._eyePupil, self._eyeLid
    if not sclera or not pupil or not lid then return end
    dt = dt or 0
    local S = ArcadiaNexus.DMP_Settings
    local reduced = S and S:Get("reducedMotion")
    self._eyeWanderT = (self._eyeWanderT or 0) - dt
    if self._eyeWanderT <= 0 then
        self._eyeWanderT = 1.15 + (math.random() * 2.4)
        if math.random() < 0.3 then
            self._eyeTx, self._eyeTy = 0, 0
        else
            local ang = math.random() * 6.283185
            local mag = 0.2 + math.random() * 0.65
            self._eyeTx = math.cos(ang) * mag
            self._eyeTy = math.sin(ang) * mag * 0.5
        end
    end
    local k = 1 - math.exp(-(dt) * (reduced and 2.2 or 5.8))
    self._eyeLookX = (self._eyeLookX or 0) + ((self._eyeTx or 0) - (self._eyeLookX or 0)) * k
    self._eyeLookY = (self._eyeLookY or 0) + ((self._eyeTy or 0) - (self._eyeLookY or 0)) * k
    self._eyeBlinkT = (self._eyeBlinkT or 2.5) - dt
    if self._eyeBlinkT <= 0 then
        self._eyeBlinkT = 2.0 + math.random() * 3.8
        self._eyeBlink = 1
    end
    if (self._eyeBlink or 0) > 0 then
        self._eyeBlink = self._eyeBlink - dt / (reduced and 0.28 or 0.15)
        if self._eyeBlink < 0 then self._eyeBlink = 0 end
    end
    local close = 0
    if (self._eyeBlink or 0) > 0 then
        close = math.sin((1 - self._eyeBlink) * math.pi)
    end
    local s = WS()
    local pulse = math.min(1, self._eyePulseT or 0)
    local eyeScale = 1 + pulse * 0.16
    sclera:Show()
    sclera:ClearAllPoints()
    sclera:SetSize(CFG.eye_s * s * eyeScale, CFG.eye_s * s * eyeScale)
    sclera:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", CFG.eye_x * s, -CFG.eye_y * s)
    local ox = self._eyeLookX * 6.5 * s * (1 - close * 0.85)
    local oy = self._eyeLookY * 5.5 * s * (1 - close * 0.85)
    pupil:Show()
    pupil:ClearAllPoints()
    pupil:SetSize(CFG.eye_s * 0.42 * s * eyeScale, CFG.eye_s * 0.42 * s * eyeScale)
    pupil:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", CFG.eye_x * s + ox, -(CFG.eye_y * s + oy))
    pupil:SetAlpha(1 - close * 0.92)
    lid:Show()
    lid:ClearAllPoints()
    local lidH = CFG.eye_s * s * (0.18 + 0.82 * close)
    lid:SetSize(CFG.eye_s * s * eyeScale, lidH * eyeScale)
    lid:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", CFG.eye_x * s, -CFG.eye_y * s)
    lid:SetAlpha(0.25 + close * 0.75)
end

function R:UpdateView(gs, dt)
    self:UpdateHUD(gs)
    self:_DrawSprites(gs)
    self:_DrawTable(gs)
    self:_DrawFx(gs, dt or 0)
    self:_TickEye(dt or 0)
    if self._tiltOv then
        if gs and gs.tilted then
            if self._tiltFS then
                self._tiltFS:SetText((Loc().state_tilt or "TILT"))
            end
            self._tiltOv:Show()
        else
            self._tiltOv:Hide()
        end
    end
end

ArcadiaNexus.RegisterGame({
    id        = "DARKMOON_PINBALL",
    label     = "Darkmoon Pinball",
    renderer  = "DMP_Renderer",
    engine    = "DMP_Engine",
    container = "_dmpContainer",
    category  = "ARCADE",
    logo      = "Interface\\AddOns\\ArcadiaNexus\\Games\\DarkmoonPinball\\assets\\logo\\logo_dp",
    xp        = 10,
})
