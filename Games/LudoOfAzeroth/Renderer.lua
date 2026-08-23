--[[
    Ludo of Azeroth – Renderer.lua
    Asset-Hintergrund, 3D-NPC-Figuren, Positions-Kalibrierung.
]]

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.LOA_Renderer = {}
local R = ArcadiaNexus.LOA_Renderer

local CFG = {
    field_w         = 602,
    field_h         = 498,
    field_ofs_x     = 0,
    field_ofs_y     = 0,
    bg_w            = 480, --480
    bg_h            = 480, --480
    bg_ofs_x        = 0,
    bg_ofs_y        = 15,
    bg_alpha        = 1.0,
    bg2_w           = 790,
    bg2_h           = 550,
    bg2_ofs_x       = 0,
    bg2_ofs_y       = 15,
    bg2_alpha       = 1.0,
    border_w        = 795,
    border_h        = 547,
    border_ofs_x    = 0,
    border_ofs_y    = 17,
    border_alpha    = 1.0,
    logo_w          = 360,
    logo_h          = 280,
    logo_x          = 0,
    logo_y          = 30,
    logo_alpha      = 1.0,
    piece_model_w   = 44,
    piece_model_h   = 56,
    hit_size        = 20,
    dice_w          = 40,
    dice_h          = 40,
    dice_scene_size = 250,
    dice_icon_size  = 35,
    max_piece_models = 16,
    dd_w            = 120,
    btn_w           = 144,
    btn_h           = 32,
    status_left_point  = "TOPRIGHT",
    status_left_rel    = "TOPRIGHT",
    status_left_x      = -88,
    status_left_y      = -515,
    status_right_point = "TOPRIGHT",
    status_right_rel   = "TOPRIGHT",
    status_right_x     = 50,
    status_right_y     = -535,
    status_right_w     = 320,
    hud_w           = 315,
    hud_h           = 50,
    hud_x           = 83.5,
    hud_y           = -256.5,
    hud_alpha       = 0.75,
    hud_pad         = 8,
}

local LOA_PATH = "Interface\\AddOns\\ArcadiaNexus\\Games\\LudoOfAzeroth\\assets\\"
local LOA_ASSETS = {
    background = LOA_PATH .. "background\\background_loa",
    background2 = LOA_PATH .. "background\\background_loa02",
    border     = LOA_PATH .. "border\\loa_border",
    logo       = LOA_PATH .. "logo\\logo_loa",
}

local function AssetExists(path)
    if C_Texture and C_Texture.GetFileIDFromPath then
        return C_Texture.GetFileIDFromPath(path) ~= 0
    end
    return nil
end

R.frame           = nil
R._canvas         = nil
R._fieldFrame     = nil
R._bgFallback     = nil
R._bgTex          = nil
R._borderFrame    = nil
R._borderTex      = nil
R._logoTex        = nil
R._logoFallback   = nil
R._assetsOk       = nil
R._playLayer      = nil
R._debugOverlay   = nil
R._diceFrame      = nil
R._diceScene      = nil
R._diceActor      = nil
R._diceIcon       = nil
R._diceResultFS   = nil
R._diceBtn        = nil
R._pieceModels    = {}
R._pieceHitBtns   = {}
R._highlights     = {}
R.state           = "IDLE"
R._game           = nil
R._running        = false
R._validMoveIdxs  = {}
R._initialized    = false
R._controlsFrame  = nil
R._startBtn       = nil
R._colorDropdown  = nil
R._countDropdown  = nil
R._lastColor      = nil
R._lastAiCount    = nil
R.statusLeft      = nil
R.statusRight     = nil

local function L()
    return ArcadiaNexus.GetLocaleTable("LOA")
end

-- ============================================================
-- Init
-- ============================================================
function R:Init()
    if self._initialized then return end
    self._initialized = true
    self:_EnsureBuilt()
    self:EnterIdleState()

    local Dbg = ArcadiaNexus.LOA_Debug
    if Dbg then Dbg:Init(self) end

    local Eng = ArcadiaNexus.Engine
    Eng:On("LOA_GAME_STARTED",  function(g) R:OnGameStarted(g) end)
    Eng:On("LOA_GAME_STOPPED",  function()   R:EnterIdleState() end)
    Eng:On("LOA_DICE_ROLLED",   function(g,v) R:OnDiceRolled(g,v) end)
    Eng:On("LOA_NO_MOVE",       function(g)   R:OnNoMove(g) end)
    Eng:On("LOA_TURN_CHANGED",  function(g)   R:OnTurnChanged(g) end)
end

function R:_EnsureBuilt()
    self:_CreateMainFrame()
    if not self.frame then return end

    self:_CreateFieldFrame()
    self:_CreateBackground()
    self:_CreateBorder()
    self:_CreateLogo()
    self:_CreatePlayLayer()
    self:_CreatePiecePool()
    self:_CreateDiceButton()
    self:_CreateDebugOverlay()
    self:_CreateControls()
    self:CreateStatusBar()
    self:_UpdateAssetWarning()
end

function R:_UpdateAssetWarning()
    local bgOk     = AssetExists(LOA_ASSETS.background)
    local borderOk = AssetExists(LOA_ASSETS.border)
    local logoOk   = AssetExists(LOA_ASSETS.logo)
    self._assetsOk = (bgOk ~= false) and (logoOk ~= false)

    if bgOk == false or borderOk == false or logoOk == false then
        local missing = {}
        if bgOk == false then missing[#missing+1] = "background/background_loa.tga" end
        if borderOk == false then missing[#missing+1] = "border/loa_border.tga" end
        if logoOk == false then missing[#missing+1] = "logo/logo_loa.tga" end
        print("|cffff8800[LOA]|r Asset fehlt: " .. table.concat(missing, ", ")
            .. " -> Games/LudoOfAzeroth/assets/  dann /reload")
        if self._logoFallback and self.state == "IDLE" then
            self._logoFallback:Show()
            if self._logoTex then self._logoTex:Hide() end
        end
    else
        if self._logoFallback then self._logoFallback:Hide() end
        if self._logoTex and self.state == "IDLE" then
            self:_SetLogoVisible(true)
        end
    end
end

function R:_SetBoardVisible(visible)
    if self._fieldFrame then
        if visible then self._fieldFrame:Show()
        else self._fieldFrame:Hide() end
    end
end

function R:_SetLogoVisible(visible)
    if self._assetsOk == false then
        if self._logoTex      then self._logoTex:Hide() end
        if self._logoFallback then
            if visible then self._logoFallback:Show()
            else self._logoFallback:Hide() end
        end
        return
    end
    if self._logoTex then
        if visible then self._logoTex:Show()
        else self._logoTex:Hide() end
    end
    if self._logoFallback then self._logoFallback:Hide() end
end

function R:_CreateMainFrame()
    if self.frame then return end
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end

    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_LOA_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._loaContainer = f end

    f:SetScript("OnShow", function()
        R:_EnsureBuilt()
        R:_UpdateAssetWarning()
        local Npc = ArcadiaNexus.LOA_NpcData
        if Npc then Npc:WarmupCache() end
    end)

    f:SetScript("OnHide", function()
        ArcadiaNexus.GameSession:HandleRendererHide("LOA", ArcadiaNexus.LOA_Engine, function(E)
            if E.activeGame then
                E:StopGame()
            end
        end)
    end)
end

function R:_CreateFieldFrame()
    if self._fieldFrame then return end
    local pf = CreateFrame("Frame", nil, self._canvas)
    pf:SetSize(CFG.field_w, CFG.field_h)
    pf:SetPoint("CENTER", self._canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = pf
end

function R:_CreateBackground()
    if self._bgFallback then return end
    local pf = self._fieldFrame
    if not pf then return end

    local fallback = pf:CreateTexture(nil, "BACKGROUND", nil, -2)
    fallback:SetTexture("Interface\\Buttons\\WHITE8X8")
    fallback:SetSize(CFG.bg_w, CFG.bg_h)
    fallback:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    fallback:SetVertexColor(0.14, 0.11, 0.08, 1)
    fallback:Show()
    self._bgFallback = fallback

    local tex2 = self._canvas:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex2:SetTexture(LOA_ASSETS.background2)
    tex2:SetSize(CFG.bg2_w, CFG.bg2_h)
    tex2:SetPoint("CENTER", self._canvas, "CENTER", CFG.bg2_ofs_x, CFG.bg2_ofs_y)
    tex2:SetAlpha(CFG.bg2_alpha)
    tex2:Show()
    self._bg2Tex = tex2

    local tex = pf:CreateTexture(nil, "ARTWORK", nil, 0)
    tex:SetTexture(LOA_ASSETS.background)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", pf, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorder()
    if self._borderFrame then return end
    local pf = self._fieldFrame
    if not pf then return end

    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", pf, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(pf:GetFrameLevel() + 20)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(LOA_ASSETS.border)
    tex:SetAllPoints(borderFrame)
    tex:SetAlpha(CFG.border_alpha)

    self._borderFrame = borderFrame
    self._borderTex   = tex
end

function R:_CreateLogo()
    if self._logoTex or self._logoFallback then return end
    local parent = self._canvas
    if not parent then return end

    local fallback = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fallback:SetPoint("CENTER", parent, "CENTER", CFG.logo_x, CFG.logo_y)
    fallback:SetText("|cffffd700Ludo of Azeroth|r")
    fallback:Hide()
    self._logoFallback = fallback

    local UI = ArcadiaNexus.UI
    if UI and UI.CreateGameLogo then
        self._logoTex = UI.CreateGameLogo(
            parent,
            LOA_ASSETS.logo,
            {
                w     = CFG.logo_w,
                h     = CFG.logo_h,
                x     = CFG.logo_x,
                y     = CFG.logo_y,
                alpha = CFG.logo_alpha,
            }
        )
    end
end

function R:_CreatePlayLayer()
    if self._playLayer then return end
    local layer = CreateFrame("Frame", nil, self._fieldFrame)
    layer:SetAllPoints(self._fieldFrame)
    layer:SetFrameLevel(self._fieldFrame:GetFrameLevel() + 5)
    self._playLayer = layer
end

function R:_CreatePiecePool()
    if #self._pieceModels > 0 then return end
    local layer = self._playLayer
    for i = 1, CFG.max_piece_models do
        local model = CreateFrame("PlayerModel", nil, layer)
        model:SetSize(CFG.piece_model_w, CFG.piece_model_h)
        model:SetFrameLevel(layer:GetFrameLevel() + 2)
        model:EnableMouse(false)
        if model.SetKeepModelOnHide then model:SetKeepModelOnHide(true) end
        model:Hide()
        self._pieceModels[i] = model

        local hit = CreateFrame("Button", nil, layer)
        hit:SetSize(CFG.hit_size, CFG.hit_size)
        hit:SetFrameLevel(layer:GetFrameLevel() + 4)
        hit:Hide()
        hit.pieceIdx = nil
        hit:EnableMouse(true)
        local hl = hit:CreateTexture(nil, "OVERLAY")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 0.3, 0.45)
        hl:Hide()
        hit.hl = hl
        self._pieceHitBtns[i] = hit
    end
end

function R:_CreateDiceButton()
    if self._diceFrame then return end
    local layer = self._playLayer
    local Dice  = ArcadiaNexus.LOA_Dice

    local btn = CreateFrame("Button", nil, layer)
    btn:SetSize(CFG.dice_w, CFG.dice_h)
    btn:SetFrameLevel(layer:GetFrameLevel() + 6)
    btn:Hide()

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(1, 1, 0.4, 0.35)

    btn:SetScript("OnClick", function()
        ArcadiaNexus.LOA_Engine:HandleRollClick()
    end)

    -- Keep the hit target compact while allowing the non-interactive 3D
    -- viewport to extend beyond it.
    btn:SetClipsChildren(false)

    local scene
    local ok, created = pcall(CreateFrame, "ModelScene", nil, btn, "ModelSceneFrameTemplate")
    scene = ok and created or CreateFrame("ModelScene", nil, btn)
    scene:SetSize(CFG.dice_scene_size, CFG.dice_scene_size)
    scene:SetPoint("CENTER", btn, "CENTER")
    scene:SetFrameLevel(btn:GetFrameLevel() + 1)
    scene:EnableMouse(false)
    scene:Hide()

    local iconLayer = CreateFrame("Frame", nil, btn)
    iconLayer:SetSize(CFG.dice_icon_size, CFG.dice_icon_size)
    iconLayer:SetPoint("CENTER")
    iconLayer:SetFrameLevel(btn:GetFrameLevel() + 5)

    local icon = iconLayer:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconLayer)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if Dice then
        Dice:ShowIcon(icon, ArcadiaNexus.LOA_Themes:GetTheme(), 1)
    else
        icon:SetTexture("Interface\\Icons\\Ability_Rogue_RollTheBones")
        icon:Show()
    end

    local resultFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    resultFS:SetPoint("CENTER", btn, "CENTER", 0, 2)
    resultFS:SetTextColor(1, 0.88, 0.15)
    resultFS:SetShadowOffset(2, -2)
    resultFS:Hide()

    self._diceFrame    = btn
    self._diceBtn      = btn
    self._diceScene    = scene
    self._diceActor    = nil
    self._diceIcon     = icon
    self._diceResultFS = resultFS
end

function R:_CreateDebugOverlay()
    if self._debugOverlay then return end
    local pf = self._fieldFrame
    local ov = CreateFrame("Button", nil, pf)
    ov:SetAllPoints(pf)
    ov:SetFrameLevel(pf:GetFrameLevel() + 100)
    ov:EnableMouse(true)
    ov:Hide()
    ov:RegisterForClicks("AnyUp")
    ov:SetScript("OnClick", function()
        local Dbg = ArcadiaNexus.LOA_Debug
        if Dbg and Dbg.active then
            Dbg:OnFieldClick(pf)
        end
    end)
    self._debugOverlay = ov
end

function R:SetDebugOverlay(enabled)
    if self._debugOverlay then
        if enabled then
            self._debugOverlay:Show()
            self:_SetBoardVisible(true)
        else
            self._debugOverlay:Hide()
            if self.state == "IDLE" then
                self:_SetBoardVisible(false)
            end
        end
    end
end

-- ============================================================
-- Positionierung
-- ============================================================
function R:PositionAtFrame(frame, pos)
    if not frame or not pos then return end
    if frame._loaPosX == pos.x and frame._loaPosY == pos.y then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", self._fieldFrame, "TOPLEFT", pos.x, -pos.y)
    frame._loaPosX = pos.x
    frame._loaPosY = pos.y
end

function R:_PieceSlot(playerID, pieceIdx)
    return (tonumber(playerID) - 1) * 4 + pieceIdx
end

function R:RenderAllPieces(game)
    if not game then return end
    local Npc = ArcadiaNexus.LOA_NpcData
    local Positions = ArcadiaNexus.LOA_Positions
    local activeSlots = {}

    local playerCount = game.playerCount or 2
    for playerID = 1, playerCount do
        local player = game.players[playerID]
        if player then
            for pieceIdx, piece in ipairs(player.pieces) do
                local slot = self:_PieceSlot(playerID, pieceIdx)
                local model = self._pieceModels[slot]
                local hit   = self._pieceHitBtns[slot]
                if not model or not hit then break end

                if piece.finished then
                    if model:IsShown() then model:Hide() end
                    if hit:IsShown() then hit:Hide() end
                else
                    activeSlots[slot] = true
                    local pos = Positions:GetPixelPos(player.colorIdx, piece.relPos, pieceIdx)
                    self:PositionAtFrame(model, pos)
                    self:PositionAtFrame(hit, pos)

                    hit.pieceIdx = pieceIdx
                    hit.playerID = player.id

                    if Npc:ApplyModel(model, player.colorIdx) then
                        Npc:PlayAnim(model, "idle")
                        if not model:IsShown() then model:Show() end
                    elseif model:IsShown() then
                        model:Hide()
                    end
                    if not hit:IsShown() then hit:Show() end
                end
            end
        end
    end

    for slot = 1, CFG.max_piece_models do
        if not activeSlots[slot] then
            local model = self._pieceModels[slot]
            local hit   = self._pieceHitBtns[slot]
            if model and model:IsShown() then model:Hide() end
            if hit and hit:IsShown() then hit:Hide() end
        end
    end
end

function R:PositionDice(game)
    local btn = self._diceFrame or self._diceBtn
    if not btn then return end
    local Pos  = ArcadiaNexus.LOA_Positions
    local Dice = ArcadiaNexus.LOA_Dice
    local pos  = Pos:GetDice() or { x = CFG.bg_w / 2, y = CFG.bg_h / 2 }
    self:PositionAtFrame(btn, pos)

    local theme = ArcadiaNexus.LOA_Themes:GetTheme()
    if Dice and not Dice:IsRolling() then
        Dice:ShowIdle(self._diceScene, self._diceResultFS, self._diceIcon, theme, game)
    end
    btn:Show()

    if Dice and not Dice._modelVerified and not Dice._warmingUp then
        Dice:Warmup(self._diceScene, function(ok, actor)
            if ok then self._diceActor = actor end
            if not Dice:IsRolling() then
                Dice:ShowIdle(self._diceScene, self._diceResultFS, self._diceIcon, theme, game)
            end
        end)
    end
end

function R:ShowValidMoveHighlights(game)
    self:ClearHighlights()
    if not game then return end

    local Logic  = ArcadiaNexus.LOA_Logic
    local moves  = Logic:GetValidMoves(game)
    local player = game.players[game.current]

    for _, move in ipairs(moves) do
        for _, hit in ipairs(self._pieceHitBtns) do
            if hit:IsShown() and hit.pieceIdx == move.pieceIdx
                    and hit.playerID == game.current then
                if hit.hl then
                    hit.hl:Show()
                    self._highlights[#self._highlights+1] = hit.hl
                end
                local idx = move.pieceIdx
                hit:SetScript("OnClick", function()
                    ArcadiaNexus.LOA_Engine:HandlePieceClick(idx)
                end)
            end
        end
    end
end

function R:ClearHighlights()
    for _, hl in ipairs(self._highlights) do
        if hl then hl:Hide() end
    end
    self._highlights = {}
    for _, hit in ipairs(self._pieceHitBtns) do
        if hit.hl then hit.hl:Hide() end
        hit:SetScript("OnClick", nil)
    end
end

function R:AnimateDice(theme, finalVal, callback)
    local Dice = ArcadiaNexus.LOA_Dice
    if not Dice then if callback then callback() end; return end
    Dice:AnimateRoll(self, theme, finalVal, callback)
end

-- ============================================================
-- Event-Handler
-- ============================================================
function R:OnGameStarted(game)
    self:_EnsureBuilt()
    self.state    = "PLAYING"
    self._game    = game
    self._running = true

    if self._canvas and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._canvas)
    end
    self:HideStartPopup()
    self:_SetLogoVisible(false)
    self:_SetBoardVisible(true)
    self:_UpdateControlsForPlay()

    self:PositionDice(game)

    local function renderPieces(forceReload)
        if self._game ~= game then return end
        if forceReload then
            local Npc = ArcadiaNexus.LOA_NpcData
            for _, model in ipairs(self._pieceModels) do
                if Npc then Npc:ClearModelCache(model) end
            end
        end
        self:RenderAllPieces(game)
    end
    renderPieces(false)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() renderPieces(false) end)
        C_Timer.After(0.15, function() renderPieces(false) end)
        if not self._npcBootstrapDone then
            self._npcBootstrapDone = true
            -- Einmal pro Session: Nachladen falls Assets beim ersten Login noch nicht bereit waren
            C_Timer.After(0.35, function() renderPieces(true) end)
        end
    end

    self:UpdateStatus(game)
end

function R:OnDiceRolled(game, val)
    local theme = ArcadiaNexus.LOA_Themes:GetTheme()
    local loc   = L()
    self:AnimateDice(theme, val, function()
        self:UpdateStatus(game, string.format(loc["dice_result"] or "Würfel: %d", val))
        if game.current == game.humanID and game.phase == "move" then
            self:ShowValidMoveHighlights(game)
        end

        local Eng = ArcadiaNexus.LOA_Engine
        if Eng and Eng._rollContinueFn and Eng._rollContinueGame == game then
            local fn = Eng._rollContinueFn
            Eng._rollContinueFn = nil
            Eng._rollContinueGame = nil
            fn()
        end
    end)
end

function R:OnTurnStart(game)
    self:ClearHighlights()
    self:UpdateStatus(game)
    self:PositionDice(game)

    if self._diceBtn then
        self._diceBtn:EnableMouse(game.current == game.humanID)
        -- Mouse input communicates whose turn it is. Dimming the complete
        -- button also fades the ModelScene during AI rolls.
        self._diceBtn:SetAlpha(1.0)
    end
end

function R:OnTurnChanged(game)
    self:OnTurnStart(game)
end

function R:OnPieceMoved(game, playerID, pieceIdx, result)
    self:ClearHighlights()
    self:RenderAllPieces(game)
    self:UpdateStatus(game)
end

function R:OnNoMove(game)
    self:UpdateStatus(game, L()["status_no_move"])
end

function R:OnGameWon(game, winnerID)
    self.state    = "GAMEOVER"
    self._running = false
    self:ClearHighlights()
    self:RenderAllPieces(game)
    self:ShowOverlay(game, winnerID)
end

-- ============================================================
-- UI Chrome
-- ============================================================
function R:CreateStatusBar()
    if self._statusBox then return end
    local f = self._canvas
    local UI = ArcadiaNexus.UI
    if not f or not UI or not UI.CreateHudStatBox then return end

    local box, line1 = UI.CreateHudStatBox(f, {
        w = CFG.hud_w, h = CFG.hud_h,
        point = "TOPLEFT", relativePoint = "CENTER",
        x = CFG.hud_x, y = CFG.hud_y,
        alpha = CFG.hud_alpha,
        justifyH = "LEFT",
        shown = false,
    })
    self._statusBox = box
    self.statusLeft = line1
    if line1 then
        line1:ClearAllPoints()
        line1:SetPoint("TOPLEFT", box, "TOPLEFT", CFG.hud_pad, -CFG.hud_pad)
        line1:SetJustifyH("LEFT")
        line1:SetWidth(CFG.hud_w - CFG.hud_pad * 2)
    end

    local line2 = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line2:SetPoint("TOPLEFT", line1 or box, line1 and "BOTTOMLEFT" or "TOPLEFT", 0, line1 and -2 or -CFG.hud_pad)
    line2:SetJustifyH("LEFT")
    line2:SetWidth(CFG.hud_w - CFG.hud_pad * 2)
    line2:SetTextColor(0.95, 0.85, 0.4)
    self.statusRight = line2
end

function R:UpdateStatus(game, extraMsg)
    if not game then return end
    local theme     = ArcadiaNexus.LOA_Themes:GetTheme()
    local board     = ArcadiaNexus.LOA_Board
    local humanP    = game.players[game.humanID]
    local currentP  = game.players[game.current]
    local humanClr  = theme.colors[humanP.colorIdx]
    local currentClr = theme.colors[currentP.colorIdx]
    local loc       = L()

    local function countDone(p)
        local n = 0
        for _, pc in ipairs(p.pieces) do if pc.finished then n = n + 1 end end
        return n
    end

    if self.statusLeft then
        self.statusLeft:SetText(string.format(
            loc["status_human"],
            humanClr[1]*255, humanClr[2]*255, humanClr[3]*255,
            board:GetFactionName(humanP.colorIdx), countDone(humanP)))
        self.statusLeft:Show()
    end

    if self._statusBox then self._statusBox:Show() end

    if self.statusRight then
        local turnStr
        if extraMsg then
            turnStr = extraMsg
        elseif game.current == game.humanID then
            turnStr = (game.phase == "roll") and loc["status_roll"] or loc["status_pick"]
        else
            turnStr = loc["status_ai_think"]
        end
        local faction = board:GetFactionName(currentP.colorIdx)
        local name = (game.current == game.humanID)
            and ("Du (" .. faction .. ")")
            or ("KI (" .. faction .. ")")
        self.statusRight:SetText(string.format(
            loc["status_current"],
            currentClr[1]*255, currentClr[2]*255, currentClr[3]*255,
            name, countDone(currentP), turnStr))
        self.statusRight:Show()
    end
end

function R:_CreateControls()
    if self._controlsFrame then return end
    local loc = L()
    local UI = ArcadiaNexus.UI
    local S  = ArcadiaNexus.LOA_Settings
    if not self.frame or not UI then return end

    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf

    local ddGap = 10
    local pair = CreateFrame("Frame", nil, cf)
    pair:SetSize(CFG.dd_w * 2 + ddGap, CFG.btn_h)
    pair:SetPoint("CENTER", cf, "CENTER", bar.segX[1], bar.y.dropdownOfs)

    local ddColorAnchor = CreateFrame("Frame", nil, pair)
    ddColorAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddColorAnchor:SetPoint("LEFT", pair, "LEFT", 0, 0)

    local factionOptions = {
        { key = "fac1", colorIdx = 1, label = loc["faction_stormwind"]     or "Stormwind"     },
        { key = "fac2", colorIdx = 2, label = loc["faction_orgrimmar"]     or "Orgrimmar"     },
        { key = "fac3", colorIdx = 3, label = loc["faction_thunder_bluff"] or "Thunder Bluff" },
        { key = "fac4", colorIdx = 4, label = loc["faction_ironforge"]     or "Ironforge"     },
    }
    local factionDdOpts = {}
    for _, opt in ipairs(factionOptions) do
        factionDdOpts[#factionDdOpts + 1] = { key = opt.key, label = opt.label }
    end

    local function ColorToKey(idx)
        idx = tonumber(idx) or 1
        return "fac" .. tostring(math.max(1, math.min(4, idx)))
    end

    local function KeyToColor(key)
        for _, opt in ipairs(factionOptions) do
            if opt.key == key then return opt.colorIdx end
        end
        return tonumber(R._lastColor or S:Get("playerColor")) or 1
    end

    self._colorDropdown = UI.CreateSimpleDropdown(
        ddColorAnchor, 0, 0, CFG.dd_w, "",
        factionDdOpts,
        function()
            return ColorToKey(R._lastColor or S:Get("playerColor"))
        end,
        function(key)
            R._lastColor = KeyToColor(key)
            S:Set("playerColor", R._lastColor)
        end
    )

    local ddCountAnchor = CreateFrame("Frame", nil, pair)
    ddCountAnchor:SetSize(CFG.dd_w, CFG.btn_h)
    ddCountAnchor:SetPoint("RIGHT", pair, "RIGHT", 0, 0)

    -- Nicht-numerische Keys: WoW-Dropdown liefert sonst 0-basierte Indizes,
    -- die mit "1"/"2"/"3" kollidieren (Index 1 → fälschlich aiCount 1 statt 2).
    local aiOptions = {
        { key = "ai1", aiCount = 1, label = loc["players_1"] or "Du + 1 KI" },
        { key = "ai2", aiCount = 2, label = loc["players_2"] or "Du + 2 KI" },
        { key = "ai3", aiCount = 3, label = loc["players_3"] or "Du + 3 KI" },
    }
    local ddOpts = {}
    for _, opt in ipairs(aiOptions) do
        ddOpts[#ddOpts + 1] = { key = opt.key, label = opt.label }
    end

    local function AiCountToKey(n)
        n = tonumber(n) or 1
        if n <= 1 then return "ai1" end
        if n == 2 then return "ai2" end
        return "ai3"
    end

    local function KeyToAiCount(key)
        for _, opt in ipairs(aiOptions) do
            if opt.key == key then return opt.aiCount end
        end
        return tonumber(R._lastAiCount or S:Get("aiCount")) or 1
    end

    self._countDropdown = UI.CreateSimpleDropdown(
        ddCountAnchor, 0, 0, CFG.dd_w, "",
        ddOpts,
        function()
            return AiCountToKey(R._lastAiCount or S:Get("aiCount") or 1)
        end,
        function(key)
            R._lastAiCount = KeyToAiCount(key)
            S:Set("aiCount", R._lastAiCount)
        end
    )

    local startBtn = UI.CreateArcadiaButton(cf, loc["btn_start"], CFG.btn_w, CFG.btn_h)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = ArcadiaNexus.LOA_Engine
        if not Eng then return end
        if R.state == "PLAYING" then
            Eng:StopGame()
        else
            R:ShowStartPopup()
        end
    end)
    self._startBtn = startBtn

    self._lastColor   = tonumber(S:Get("playerColor")) or 1
    self._lastAiCount = tonumber(S:Get("aiCount")) or 1
end

function R:_UpdateControlsForIdle()
    local loc = L()
    if self._startBtn then
        self._startBtn:SetLabel(loc["btn_start"])
        self._startBtn:Show()
    end
    if self._colorDropdown then self._colorDropdown:SetEnabled(true) end
    if self._countDropdown then self._countDropdown:SetEnabled(true) end
    if self._controlsFrame then self._controlsFrame:Show() end
end

function R:_UpdateControlsForPlay()
    local loc = L()
    if self._startBtn then
        self._startBtn:SetLabel(loc["btn_exit"])
        self._startBtn:Show()
    end
    if self._colorDropdown then self._colorDropdown:SetEnabled(false) end
    if self._countDropdown then self._countDropdown:SetEnabled(false) end
    if self._controlsFrame then self._controlsFrame:Show() end
end

function R:HideStartPopup()
    if self._canvas and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideChoicePopup(self._canvas)
    end
end

function R:ShowStartPopup()
    if not self._canvas then return end
    local loc = L()
    local UI  = ArcadiaNexus.UI
    local Eng = ArcadiaNexus.LOA_Engine
    local hasSave = Eng and Eng:HasSave()

    UI.ShowChoicePopup({
        parent     = self._canvas,
        title      = loc["popup_start_title"],
        titleColor = { 1, 0.82, 0 },
        buttons    = {
            {
                label   = loc["btn_new_game"],
                onClick = function()
                    R:HideStartPopup()
                    R:StartNewGame()
                end,
            },
            {
                label   = loc["btn_resume"],
                enabled = hasSave,
                onClick = function()
                    R:HideStartPopup()
                    if Eng then Eng:ResumeGame() end
                end,
            },
        },
    })
end

function R:StartNewGame()
    local S = ArcadiaNexus.LOA_Settings
    local aiCount = tonumber(self._lastAiCount or S:Get("aiCount")) or 1
    aiCount = math.max(1, math.min(3, aiCount))
    self._lastAiCount = aiCount
    ArcadiaNexus.LOA_Engine:StartGame({
        humanColor = tonumber(self._lastColor or S:Get("playerColor")) or 1,
        aiCount    = aiCount,
    })
end

function R:ShowOverlay(game, winnerID)
    if not self._canvas then return end
    local UI      = ArcadiaNexus.UI
    local loc     = L()
    local parent  = self._canvas
    local isHuman = (winnerID == game.humanID)

    UI.ShowArcadeResult(parent, {
        title      = isHuman and loc["result_win_title"] or loc["result_loss_title"],
        titleColor = isHuman and {1, 0.84, 0} or {1, 0.3, 0.3},
        subtitle   = isHuman and loc["result_win_sub"] or loc["result_loss_sub"],
        gameId     = "LOA",
        result     = isHuman and "WIN" or "LOSS",
        L          = loc,
        onRetry    = function() R:StartNewGame() end,
        onExit     = function() ArcadiaNexus.LOA_Engine:StopGame() end,
    })
end

function R:EnterIdleState()
    self:_EnsureBuilt()
    self:_UpdateAssetWarning()
    self.state    = "IDLE"
    self._running = false
    self._game    = nil

    if self._canvas and ArcadiaNexus.UI then
        ArcadiaNexus.UI.HideResultDialog(self._canvas)
    end
    self:HideStartPopup()
    self:_UpdateControlsForIdle()
    if self._statusBox    then self._statusBox:Hide() end
    if self.statusLeft    then self.statusLeft:Hide() end
    if self.statusRight   then self.statusRight:Hide() end
    if self._diceBtn      then self._diceBtn:Hide() end
    local Dice = ArcadiaNexus.LOA_Dice
    if Dice then Dice:CancelRoll() end

    local Dbg = ArcadiaNexus.LOA_Debug
    local debugActive = Dbg and Dbg.active
    if debugActive then
        self:_SetBoardVisible(true)
    else
        self:_SetBoardVisible(false)
    end
    self:_SetLogoVisible(true)

    local Npc = ArcadiaNexus.LOA_NpcData
    for _, model in ipairs(self._pieceModels) do
        model:Hide()
    end
    for _, hit in ipairs(self._pieceHitBtns) do hit:Hide() end
    self:ClearHighlights()
end

-- [GAMEHUB_REGISTERED]
ArcadiaNexus.RegisterGame({
    id        = "LOA",
    label     = "Ludo of Azeroth",
    renderer  = "LOA_Renderer",
    engine    = "LOA_Engine",
    container = "_loaContainer",
    category  = "STRATEGIE",
})
