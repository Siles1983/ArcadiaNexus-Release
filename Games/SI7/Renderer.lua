--[[
    Games/SI7/Renderer.lua
    Azeroth Intelligence — Hotseat + Match-Adapter (kein C_ChatInfo).
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.SI7_Renderer = {}
local R = ArcadiaNexus.SI7_Renderer
R.state = "IDLE"

local COL = {
    R = { 0.72, 0.16, 0.12 },
    B = { 0.16, 0.38, 0.78 },
    N = { 0.72, 0.64, 0.32 },
    X = { 0.08, 0.08, 0.10 },
    H = { 0.12, 0.12, 0.16 },
}

local CFG = {
    field_w      = 560,
    field_h      = 420,
    field_ofs_x  = 0,
    field_ofs_y  = 12,
    bg_w         = 790,
    bg_h         = 550,
    bg_ofs_x     = 0,
    bg_ofs_y     = 5,
    bg_alpha     = 1.0,
    border_w     = 790,
    border_h     = 545,
    border_ofs_x = 0,
    border_ofs_y = 5,
    logo_w       = 360,
    logo_h       = 360,
    logo_ofs_x   = 0,
    logo_ofs_y   = 8,
    -- Zughistorie: frei fuer Layout-Feintuning.
    history_w       = 120,
    history_h       = 58,
    history_point   = "RIGHT",
    history_rel     = "RIGHT",
    history_ofs_x   = 60,
    history_ofs_y   = 121,
    history_alpha   = 0.88,
}

local SI7_ASSETS = {
    bg     = "Interface\\AddOns\\ArcadiaNexus\\Games\\SI7\\assets\\background\\bg_si7",
    border = "Interface\\AddOns\\ArcadiaNexus\\Games\\SI7\\assets\\border\\border_si7",
    logo   = "Interface\\AddOns\\ArcadiaNexus\\Games\\SI7\\assets\\logo\\logo_si7",
}

local function L()
    return ArcadiaNexus.GetLocaleTable("SI7")
end

local function Engine()
    return ArcadiaNexus.SI7_Engine
end

function R:Init()
    if self._initialized then return end
    self._initialized = true
    self._mode = "hotseat"
    self._clueN = 1
    self:_CreateMainFrame()
    self:_CreateField()
    self:_CreateBackground()
    self:_CreateBorderFrame()
    self:_CreateLogo()
    self:_CreateBoard()
    self:_CreateLobby()
    self:_CreateHud()
    self:_CreateClueRow()
    self:_CreateRoles()
    self:_CreateControls()
    self:EnterIdleState()
end

function R:_CreateMainFrame()
    local gamesPanel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetGamesPanel
        and _G.ArcadiaNexusUI.GetGamesPanel()
    if not gamesPanel then return end
    local viewport = ArcadiaNexus.UI.CreateGameViewport(gamesPanel, {
        outerName = "ArcadiaNexus_SI7_Container",
        designW   = 600,
        designH   = 498,
    })
    local f = viewport.outer
    f:Hide()
    self.frame = f
    self._canvas = viewport.canvas
    if _G.ArcadiaNexus then _G.ArcadiaNexus._si7Container = f end

    f:SetScript("OnHide", function()
        if ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell._reparenting then
            return
        end
        ArcadiaNexus.GameSession:HandleRendererHide("SI7", ArcadiaNexus.SI7_Engine, function(E)
            if E.mode ~= "hotseat" and (E.state == "PLAYING" or E.state == "LOBBY" or E.state == "FINISHED") then
                E:HideView()
            elseif E.state ~= "IDLE" then
                E:StopGame()
            end
        end)
    end)
end

function R:_CreateField()
    local canvas = self._canvas
    local ff = CreateFrame("Frame", nil, canvas)
    ff:SetSize(CFG.field_w, CFG.field_h)
    ff:SetPoint("CENTER", canvas, "CENTER", CFG.field_ofs_x, CFG.field_ofs_y)
    self._fieldFrame = ff
end

function R:_CreateBackground()
    local ff = self._fieldFrame
    local tex = ff:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetTexture(SI7_ASSETS.bg)
    tex:SetSize(CFG.bg_w, CFG.bg_h)
    tex:SetPoint("CENTER", ff, "CENTER", CFG.bg_ofs_x, CFG.bg_ofs_y)
    tex:SetAlpha(CFG.bg_alpha)
    self._bgTex = tex
end

function R:_CreateBorderFrame()
    local ff = self._fieldFrame
    local borderFrame = CreateFrame("Frame", nil, self._canvas)
    borderFrame:SetSize(CFG.border_w, CFG.border_h)
    borderFrame:SetPoint("CENTER", ff, "CENTER", CFG.border_ofs_x, CFG.border_ofs_y)
    borderFrame:SetFrameLevel(ff:GetFrameLevel() + 10)

    local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetTexture(SI7_ASSETS.border)
    tex:SetAllPoints(borderFrame)

    self._borderFrame = borderFrame
    self._borderTex = tex
end

function R:_CreateLogo()
    local UI = ArcadiaNexus.UI
    self._logoTex = UI.CreateGameLogo(
        self._fieldFrame,
        SI7_ASSETS.logo,
        { w = CFG.logo_w, h = CFG.logo_h, x = CFG.logo_ofs_x, y = CFG.logo_ofs_y }
    )
end

function R:_CreateBoard()
    local UI = ArcadiaNexus.UI
    local ff = self._fieldFrame
    local holder = CreateFrame("Frame", nil, ff)
    holder:SetSize(430, 278)
    holder:SetPoint("TOP", ff, "TOP", 0, -64)
    self._boardHolder = holder
    self._gold = UI.CreateGoldGridFrame(ff, holder, { pad = 4 })
    self._cells = {}
    local gap = 4
    local cw = (430 - gap * 4) / 5
    local ch = (278 - gap * 4) / 5
    for i = 1, 25 do
        local row = math.floor((i - 1) / 5)
        local col = (i - 1) % 5
        local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
        b:SetSize(cw, ch)
        -- Karten sind ausserhalb eines erlaubten Ratezuges deaktiviert. Hover
        -- bleibt dennoch aktiv, damit abgeschnittene Begriffe immer lesbar sind.
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
        b:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (cw + gap), -row * (ch + gap))
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        b:SetBackdropColor(0.12, 0.12, 0.16, 1)
        b:SetBackdropBorderColor(0.35, 0.32, 0.22, 1)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetTextColor(0.95, 0.92, 0.82)
        fs:SetWidth(cw - 6)
        b._label = fs
        local mark = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mark:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -2)
        mark:SetTextColor(1, 1, 1, 0.9)
        b._mark = mark
        b:SetScript("OnEnter", function(self)
            if self._fullWord and self._fullWord ~= "" and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                -- GameTooltip:SetText nutzt in aktuellen WoW-Versionen keine
                -- einzelnen RGBA-Werte mehr. Der Standardstil ist lesbar und
                -- vermeidet einen Lua-Fehler beim Mouseover.
                GameTooltip:SetText(self._fullWord)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        local idx = i
        b:SetScript("OnClick", function()
            local Eng = Engine()
            if Eng then Eng:Guess(idx) end
        end)
        self._cells[i] = b
    end
end

function R:_CreateLobby()
    local loc = L()
    local UI = ArcadiaNexus.UI
    local ff = self._fieldFrame
    local panel = CreateFrame("Frame", nil, ff)
    panel:SetSize(430, 220)
    panel:SetPoint("CENTER", ff, "CENTER", 0, -10)
    panel:Hide()
    self._lobbyPanel = panel
    self._lobbyRows = {}
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(430, 44)
        row:SetPoint("TOP", panel, "TOP", 0, -((i - 1) * 50))
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", row, "LEFT", 8, 0)
        nameFS:SetWidth(160)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetTextColor(0.95, 0.9, 0.75)
        local readyFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        readyFS:SetPoint("LEFT", nameFS, "RIGHT", 8, 0)
        readyFS:SetWidth(70)
        readyFS:SetJustifyH("LEFT")
        local aBtn = UI.CreateArcadiaButton(row, loc.btn_pair_a, 80, 24)
        aBtn:SetPoint("RIGHT", row, "RIGHT", -90, 0)
        local bBtn = UI.CreateArcadiaButton(row, loc.btn_pair_b, 80, 24)
        bBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        self._lobbyRows[i] = {
            row = row, nameFS = nameFS, readyFS = readyFS, aBtn = aBtn, bBtn = bBtn,
        }
    end
end

function R:_CreateHud()
    local UI = ArcadiaNexus.UI
    local ff = self._fieldFrame
    self._hudTurn, self._hudTurnFS = UI.CreateHudStatBox(ff, {
        w = 170, h = 22, x = 8, y = -8, text = "",
    })
    local turnFlash = self._hudTurn:CreateTexture(nil, "OVERLAY")
    turnFlash:SetAllPoints(self._hudTurn)
    turnFlash:SetTexture("Interface\\Buttons\\WHITE8x8")
    turnFlash:SetBlendMode("ADD")
    turnFlash:SetVertexColor(1, 0.78, 0.12, 0.8)
    turnFlash:SetAlpha(0)
    local turnPulse = turnFlash:CreateAnimationGroup()
    local fade = turnPulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.75)
    fade:SetToAlpha(0)
    fade:SetDuration(0.65)
    turnPulse:SetScript("OnFinished", function() turnFlash:SetAlpha(0) end)
    self._turnFlash, self._turnPulse = turnFlash, turnPulse
    self._hudLeft, self._hudLeftFS = UI.CreateHudStatBox(ff, {
        w = 200, h = 22, point = "TOP", relativePoint = "TOP",
        x = 0, y = -8, text = "",
    })
    self._hudClue, self._hudClueFS = UI.CreateHudStatBox(ff, {
        w = 170, h = 22, point = "TOPRIGHT", relativePoint = "TOPRIGHT",
        x = -8, y = -8, text = "",
    })
    self._noticeFS = ff:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self._noticeFS:SetPoint("BOTTOM", ff, "BOTTOM", 0, 40)
    self._noticeFS:SetTextColor(1, 0.85, 0.4)
    self._historyBox, self._historyFS = UI.CreateHudStatBox(ff, {
        w = CFG.history_w, h = CFG.history_h,
        point = CFG.history_point, relativePoint = CFG.history_rel,
        x = CFG.history_ofs_x, y = CFG.history_ofs_y,
        alpha = CFG.history_alpha, font = "GameFontNormalSmall",
        textColor = { 0.86, 0.9, 1 }, text = "",
    })
    if self._historyFS then
        self._historyFS:SetWidth(CFG.history_w - 12)
        self._historyFS:SetJustifyH("CENTER")
    end
end

function R:_CreateClueRow()
    local UI = ArcadiaNexus.UI
    local loc = L()
    local ff = self._fieldFrame
    local row = CreateFrame("Frame", nil, ff)
    row:SetSize(430, 28)
    row:SetPoint("BOTTOM", ff, "BOTTOM", 0, 8)
    row:EnableMouse(false)
    self._clueRow = row

    local eb = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    eb:SetSize(160, 24)
    eb:SetPoint("LEFT", row, "LEFT", 0, 0)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(16)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    eb:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    eb:SetBackdropBorderColor(0.9, 0.75, 0.3, 0.8)
    eb:SetTextInsets(6, 6, 0, 0)
    self._clueBox = eb
    local placeholder = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", eb, "LEFT", 7, 0)
    placeholder:SetPoint("RIGHT", eb, "RIGHT", -7, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(loc.clue_placeholder or "")
    local function RefreshPlaceholder()
        if eb:HasFocus() or eb:GetText() ~= "" then placeholder:Hide() else placeholder:Show() end
    end
    eb:SetScript("OnEditFocusGained", RefreshPlaceholder)
    eb:SetScript("OnEditFocusLost", RefreshPlaceholder)
    eb:SetScript("OnTextChanged", RefreshPlaceholder)
    self._cluePlaceholder = RefreshPlaceholder

    local nOpts = {}
    for n = 0, 9 do
        nOpts[#nOpts + 1] = { key = tostring(n), label = tostring(n) }
    end
    local nAnchor = CreateFrame("Frame", nil, row)
    nAnchor:SetSize(56, 24)
    nAnchor:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    UI.CreateSimpleDropdown(nAnchor, 0, 0, 56, "", nOpts,
        function() return tostring(self._clueN or 1) end,
        function(v) self._clueN = tonumber(v) or 1 end
    )

    local clueBtn = UI.CreateArcadiaButton(row, loc.btn_clue, 90, 24)
    clueBtn:SetPoint("LEFT", nAnchor, "RIGHT", 8, 0)
    clueBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if not Eng then return end
        Eng:SubmitClue(eb:GetText(), self._clueN or 1)
        eb:SetText("")
    end)
    self._clueBtn = clueBtn

    local passBtn = UI.CreateArcadiaButton(row, loc.btn_pass, 90, 24)
    passBtn:SetPoint("LEFT", clueBtn, "RIGHT", 8, 0)
    passBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if Eng then Eng:Pass() end
    end)
    self._passBtn = passBtn
end

function R:_CreateRoles()
    local loc = L()
    local ff = self._fieldFrame
    local row = CreateFrame("Frame", nil, ff)
    row:SetSize(520, 24)
    row:SetPoint("TOP", ff, "TOP", 0, -34)
    row:SetFrameLevel((ff:GetFrameLevel() or 1) + 30)
    row:EnableMouse(true)
    self._roleRow = row
    self._roleBtns = {}
    local UI = ArcadiaNexus.UI
    for i = 1, 4 do
        local btn = UI.CreateArcadiaButton(row, loc["role_" .. i], 125, 22)
        btn:SetPoint("LEFT", row, "LEFT", (i - 1) * 130, 0)
        local seat = i
        btn:SetScript("OnClick", function()
            local Eng = Engine()
            if Eng then Eng:SetViewSeat(seat) end
        end)
        self._roleBtns[i] = btn
    end
end

function R:_CreateControls()
    local loc = L()
    local UI = ArcadiaNexus.UI
    local bar = UI.CreateGameControlsBar(self.frame, "narrow")
    local cf = bar.frame
    self._controlsFrame = cf
    self._mode = "hotseat"

    local startBtn = UI.CreateArcadiaButton(cf, loc.btn_start, 144, 32)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if not Eng then return end
        if R.state == "PLAYING" and Eng.mode and Eng.mode ~= "hotseat" then
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.ShowEndRoundConfirm then
                Shell.ShowEndRoundConfirm(function()
                    ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
                    Eng:StopGame()
                end, R._fieldFrame)
                return
            end
        end
        if R.state == "PLAYING" or R.state == "LOBBY" or R.state == "FINISHED" then
            ArcadiaNexus.UI.HideResultDialog(R._fieldFrame)
            Eng:StopGame()
        else
            Eng:StartGame({ mode = "hotseat" })
        end
    end)
    self._startBtn = startBtn
end

local function PaintCell(btn, word, revealed, spyColor)
    local col = COL.H
    if revealed and revealed ~= "." then
        col = COL[revealed] or COL.H
    elseif spyColor and spyColor ~= "." then
        local c = COL[spyColor] or COL.H
        col = { c[1] * 0.45, c[2] * 0.45, c[3] * 0.45 }
    end
    btn:SetBackdropColor(col[1], col[2], col[3], 1)
    btn._label:SetText(word or "")
    -- Nicht die Zeichenanzahl, sondern die echte Glyphenbreite entscheidet:
    -- W und M brauchen deutlich mehr Platz als I oder L.
    local maxWidth = (btn:GetWidth() or 0) - 8
    for size = 11, 6, -1 do
        btn._label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        if btn._label:GetStringWidth() <= maxWidth then break end
    end
    btn._fullWord = word or ""
    local settings = ArcadiaNexus.SI7_Settings
    local visible = (revealed and revealed ~= ".") and revealed or spyColor
    if btn._mark then
        if settings and settings:Get("colorblindSymbols") and visible and visible ~= "." then
            btn._mark:SetText(({ R = "R", B = "B", N = "•", X = "X" })[visible] or "")
            btn._mark:Show()
        else
            btn._mark:SetText("")
            btn._mark:Hide()
        end
    end
end

function R:EnterIdleState()
    self.state = "IDLE"
    local loc = L()
    if self._gold then self._gold:Hide() end
    if self._boardHolder then self._boardHolder:Hide() end
    if self._clueRow then self._clueRow:Hide() end
    if self._roleRow then self._roleRow:Hide() end
    if self._hudTurn then self._hudTurn:Hide() end
    if self._hudLeft then self._hudLeft:Hide() end
    if self._hudClue then self._hudClue:Hide() end
    if self._historyBox then self._historyBox:Hide() end
    if self._noticeFS then self._noticeFS:SetText("") end
    if self._historyFS then self._historyFS:SetText("") end
    self._lastTurn = nil
    if self._turnFlash then self._turnFlash:SetAlpha(0) end
    if self._logoTex then self._logoTex:Show() end
    if self._lobbyPanel then self._lobbyPanel:Hide() end
    if self._startBtn and self._startBtn.SetLabel then
        self._startBtn:SetLabel(loc.btn_start)
    end
end

function R:Render()
    local Eng = Engine()
    if not Eng then return end
    local v = Eng:GetView()
    local loc = L()
    self.state = v.state

    if v.state == "IDLE" then
        self:EnterIdleState()
        if v.notice == "nomp" then
            self._noticeFS:SetText(loc.hud_nomp)
        elseif v.notice == "joinhint" then
            self._noticeFS:SetText(loc.hud_joinhint)
        end
        return
    end

    if self._logoTex then self._logoTex:Hide() end

    if v.state == "LOBBY" then
        if self._gold then self._gold:Hide() end
        if self._boardHolder then self._boardHolder:Hide() end
        if self._hudTurn then self._hudTurn:Hide() end
        if self._hudLeft then self._hudLeft:Hide() end
        if self._hudClue then self._hudClue:Hide() end
        if self._historyBox then self._historyBox:Hide() end
        if self._clueRow then self._clueRow:Hide() end
        if self._roleRow then self._roleRow:Hide() end
        if self._lobbyPanel then self._lobbyPanel:Show() end
        local players = v.lobbyPlayers or {}
        for i = 1, 4 do
            local row = self._lobbyRows and self._lobbyRows[i]
            if row then
                local p = players[i]
                if p then
                    row.row:Show()
                    local mark = p.self and "> " or ""
                    row.nameFS:SetText(mark .. p.name)
                    row.readyFS:SetText(p.ready and loc.hud_ready_yes or loc.hud_ready_no)
                    row.readyFS:SetTextColor(p.ready and 0.4 or 1, p.ready and 0.9 or 0.55, p.ready and 0.4 or 0.4)
                    if v.isHost then
                        row.aBtn:Show()
                        row.bBtn:Show()
                        local key = p.key
                        row.aBtn:SetScript("OnClick", function()
                            local Eng = Engine()
                            if Eng then Eng:SetLobbyGroup(key, "A") end
                        end)
                        row.bBtn:SetScript("OnClick", function()
                            local Eng = Engine()
                            if Eng then Eng:SetLobbyGroup(key, "B") end
                        end)
                        if row.aBtn.glow then row.aBtn.glow:SetAlpha(p.group == "A" and 0.45 or 0) end
                        if row.bBtn.glow then row.bBtn.glow:SetAlpha(p.group == "B" and 0.45 or 0) end
                    else
                        row.aBtn:Hide()
                        row.bBtn:Hide()
                    end
                else
                    row.row:Hide()
                end
            end
        end
        if v.notice == "groups" then
            self._noticeFS:SetText(loc.hud_groups_need)
        elseif v.notice == "start-fail" then
            self._noticeFS:SetText(loc.hud_start_fail)
        else
            self._noticeFS:SetText(v.isHost and loc.hud_lobby_host or loc.hud_lobby_guest)
        end
        local lobbySet = ArcadiaNexus.SI7_WordSets and ArcadiaNexus.SI7_WordSets:GetOptions() or {}
        local setName = (loc["wordset_" .. string.lower((v.pub and v.pub.wordSet) or "AZEROTH")] or "Azeroth")
        self._noticeFS:SetText(self._noticeFS:GetText() .. "\n" .. string.format(loc.hud_lobby_set, setName))
        if self._startBtn and self._startBtn.SetLabel then
            self._startBtn:SetLabel(loc.btn_exit)
        end
        return
    end

    if self._lobbyPanel then self._lobbyPanel:Hide() end
    if self._gold then self._gold:Show() end
    if self._boardHolder then self._boardHolder:Show() end
    if self._hudTurn then self._hudTurn:Show() end
    if self._hudLeft then self._hudLeft:Show() end
    if self._hudClue then self._hudClue:Show() end
    if self._historyBox then self._historyBox:Show() end

    local pub = v.pub
    local Logic = ArcadiaNexus.SI7_Logic
    if self._lastTurn and self._lastTurn ~= pub.turn and self._turnPulse then
        self._turnPulse:Stop()
        self._turnFlash:SetAlpha(0)
        self._turnPulse:Play()
    end
    self._lastTurn = pub.turn
    for i = 1, 25 do
        local id = pub.ids and pub.ids[i]
        local word = id and Logic.Word(id, pub.wordSet) or ""
        local mask = pub.mask and pub.mask:sub(i, i) or "."
        local spyC = v.key and v.key:sub(i, i) or nil
        PaintCell(self._cells[i], word, mask, spyC)
        -- Immer aktiv lassen, damit der Karten-Tooltip auch fuer Spione,
        -- wartende Spieler und bereits belegte Felder erreichbar bleibt.
        -- Engine:Guess prueft Zug, Rolle und Maskierung selbst; ein Klick auf
        -- eine nicht erlaubte Karte kann daher keinen Spielzustand aendern.
        self._cells[i]:Enable()
    end

    local neutral = ArcadiaNexus.SI7_WordSets and ArcadiaNexus.SI7_WordSets:IsNeutral(pub.wordSet)
    local teamName = loc[(neutral and "team_neutral_" or "team_") .. (pub.turn or "R")] or pub.turn
    local phaseKey = "hud_phase_" .. (pub.phase or "C")
    self._hudTurnFS:SetText(string.format(loc.hud_turn, teamName) .. " · " .. (loc[phaseKey] or ""))
    self._hudLeftFS:SetText(string.format(neutral and loc.hud_left_neutral or loc.hud_left, pub.red or 0, pub.blue or 0))
    local nTxt = (pub.n == 0 and pub.phase == "G") and "∞" or tostring(pub.n or 0)
    self._hudClueFS:SetText(string.format(loc.hud_clue, pub.clue ~= "" and pub.clue or "—", nTxt))
    local actionTeam = loc[(neutral and "team_neutral_" or "team_") .. (pub.lastTeam or "")] or ""
    local history = ""
    if pub.lastKind == "C" then
        history = string.format(loc.hud_history_clue, actionTeam, pub.clue or "", pub.n or 0)
    elseif pub.lastKind == "G" and pub.lastIndex and pub.lastIndex > 0 then
        history = string.format(loc.hud_history_guess, actionTeam, Logic.Word(pub.ids[pub.lastIndex], pub.wordSet))
    elseif pub.lastKind == "P" then
        history = string.format(loc.hud_history_pass, actionTeam)
    end
    if self._historyFS then self._historyFS:SetText(history) end

    if self._roleBtns then
        for i, btn in ipairs(self._roleBtns) do
            if btn.SetLabel then btn:SetLabel(loc[(neutral and "role_neutral_" or "role_") .. i] or "") end
            local on = (i == (v.seat or 0))
            if btn.glow then btn.glow:SetAlpha(on and 0.45 or 0) end
            if btn.text then
                if on then
                    btn.text:SetTextColor(1, 1, 0.55)
                else
                    btn.text:SetTextColor(1, 0.82, 0)
                end
            end
        end
    end

    local roleName = loc[(neutral and "role_neutral_" or "role_") .. tostring(v.seat or 1)] or ""
    local feedback = v.notice and loc[v.notice]
    if feedback then
        self._noticeFS:SetText(feedback)
    elseif v.canClue then
        self._noticeFS:SetText(string.format(loc.hud_view_clue, roleName))
    elseif v.canGuess then
        self._noticeFS:SetText(string.format(loc.hud_view_guess, roleName))
    else
        self._noticeFS:SetText(string.format(loc.hud_view_wait, roleName))
    end
    self._clueRow:Show()
    if v.canClue then self._clueBtn:Enable() else self._clueBtn:Disable() end
    if v.canGuess then self._passBtn:Enable() else self._passBtn:Disable() end
    if v.mode == "hotseat" or v.duo then
        self._roleRow:Show()
        local owned = {}
        if v.ownedSeats then
            for i = 1, #v.ownedSeats do owned[v.ownedSeats[i]] = true end
        end
        if self._roleBtns then
            for i, btn in ipairs(self._roleBtns) do
                if v.mode == "hotseat" or owned[i] then
                    btn:Show()
                    btn:Enable()
                else
                    btn:Hide()
                end
            end
        end
    else
        self._roleRow:Hide()
    end
    if self._startBtn and self._startBtn.SetLabel then
        self._startBtn:SetLabel(loc.btn_exit)
    end
end

function R:ShowGameOver()
    local Eng = Engine()
    if not Eng then return end
    local v = Eng:GetView()
    local loc = L()
    local pub = v.pub
    local winner = pub and pub.winner
    local neutral = ArcadiaNexus.SI7_WordSets and ArcadiaNexus.SI7_WordSets:IsNeutral(pub and pub.wordSet)
    local titleKey = neutral and "go_win_neutral_" or "go_win_"
    local title = loc[titleKey .. ((winner == "B") and "B" or "R")]
    local reason
    if pub and pub.winReason == "assassin" then
        local guessTeam = (winner == "B") and "R" or "B"
        reason = loc[(neutral and "go_assassin_neutral_" or "go_assassin_") .. guessTeam]
    else
        reason = loc[(neutral and "go_cleared_neutral_" or "go_cleared_") .. (winner or "R")]
    end
    local won = v.team and winner == v.team
    local lines
    if v.mode == "hotseat" then
        lines = { reason, loc.go_hotseat }
        won = true
    else
        lines = { reason, won and loc.go_mp_win or loc.go_mp_loss }
    end
    self.state = "FINISHED"
    ArcadiaNexus.UI.ShowArcadeResult(self._fieldFrame, {
        title = title,
        titleColor = (winner == "R") and { 0.9, 0.25, 0.2 } or { 0.35, 0.55, 1 },
        gameId = "SI7",
        result = won and "WIN" or "LOSS",
        lines = lines,
        L = loc,
        hideHighscore = v.mode == "hotseat",
        onRetry = function()
            if v.mode == "hotseat" then
                Eng:StartGame({ mode = "hotseat" })
            else
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("SI7") end
            end
        end,
        onExit = function()
            Eng:StopGame()
        end,
        buttons = (v.mode ~= "hotseat") and {
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_new_game or loc.btn_retry,
                onClick = function()
                    local Shell = ArcadiaNexus.MatchShell
                    if Shell and Shell.Rematch then Shell.Rematch("SI7") end
                end,
            },
            {
                label = (ArcadiaNexus.GetLocaleTable("UI") or {}).btn_exit or loc.btn_exit,
                onClick = function()
                    Eng:StopGame()
                end,
            },
        } or nil,
    })
end

ArcadiaNexus.RegisterGame({
    id        = "SI7",
    label     = "Azeroth Intelligence",
    renderer  = "SI7_Renderer",
    engine    = "SI7_Engine",
    container = "_si7Container",
    category   = "WORT",
    matchSeats = 4,
    logo      = SI7_ASSETS.logo,
    xp        = 10,
})
