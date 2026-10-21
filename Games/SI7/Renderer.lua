--[[
    Games/SI7/Renderer.lua
    Azeroth Intelligence — Solo-KI, Hotseat + Match-Adapter (kein C_ChatInfo).
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
    self._mode = "solo_ai"
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
            if E.mode ~= "hotseat" and E.mode ~= "solo_ai" and (E.state == "PLAYING" or E.state == "LOBBY" or E.state == "FINISHED") then
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
    self._noticeFS:SetWidth(520)
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
    row:SetSize(530, 28)
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
    self._clueNumber = nAnchor
    nAnchor:SetSize(56, 24)
    nAnchor:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    self._clueNumberPicker = UI.CreateSimpleDropdown(nAnchor, 0, 0, 56, "", nOpts,
        function() return tostring(self._clueN or 1) end,
        function(v) if Engine():GetView().canClue then self._clueN = tonumber(v) or 1 end end
    )

    local clueBtn = UI.CreateArcadiaButton(row, loc.btn_clue, 90, 24)
    clueBtn:SetPoint("LEFT", nAnchor, "RIGHT", 8, 0)
    clueBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if not Eng then return end
        local accepted = Eng:SubmitClue(eb:GetText(), self._clueN or 1)
        if Eng.mode ~= "solo_ai" or accepted then eb:SetText("") end
    end)
    self._clueBtn = clueBtn
    eb:SetScript("OnEnterPressed",function() if clueBtn:IsEnabled() then clueBtn:GetScript("OnClick")() end end)
    eb:SetScript("OnEscapePressed",function() eb:ClearFocus() end)

    local passBtn = UI.CreateArcadiaButton(row, loc.btn_pass, 90, 24)
    passBtn:SetPoint("LEFT", clueBtn, "RIGHT", 8, 0)
    passBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if Eng then Eng:Pass() end
    end)
    self._passBtn = passBtn
    local dictionary = UI.CreateArcadiaButton(row, loc.dictionary_button, 90, 24)
    dictionary:SetPoint("LEFT", passBtn, "RIGHT", 8, 0)
    dictionary:SetScript("OnClick",function()
        local view = Engine():GetView()
        if view.mode ~= "solo_ai" or not view.canClue then return end
        local words = ArcadiaNexus.SI7_Knowledge.Dictionary(view.locale)
        local page, count = 1, math.max(1, math.ceil(#words / 8))
        local function ShowPage()
            local current = Engine():GetView()
            if current.runId ~= view.runId or not current.canClue then UI.HideChoicePopup(self._fieldFrame) return end
            local lines = {loc.dictionary_help,""}
            for i=(page-1)*8+1,math.min(page*8,#words) do lines[#lines+1]=words[i] end
            local canTurn = count > 1
            local function Step(delta)
                if not canTurn then return end
                page = (page - 1 + delta) % count + 1
                ShowPage()
            end
            UI.ShowChoicePopup({parent=self._fieldFrame,width=430,height=250,
                title=loc.dictionary_title .. " (" .. page .. "/" .. count .. ")",body=table.concat(lines,"\n"),
                buttons={
                    {label=loc.dictionary_close,onClick=function() UI.HideChoicePopup(self._fieldFrame) end},
                },
                pageNav={
                    prev={onClick=function() Step(-1) end, enabled=canTurn, tooltip=loc.dictionary_prev},
                    next={onClick=function() Step(1) end, enabled=canTurn, tooltip=loc.dictionary_next},
                }})
        end
        ShowPage()
    end)
    dictionary:Hide()
    self._dictionaryBtn = dictionary
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
    self._mode = "solo_ai"

    local startBtn = UI.CreateArcadiaButton(cf, loc.btn_start, 144, 32)
    startBtn:SetPoint("BOTTOM", cf, "BOTTOM", bar.segX[2], bar.y.button)
    startBtn:SetScript("OnClick", function()
        local Eng = Engine()
        if not Eng then return end
        if R.state == "PLAYING" and Eng.mode and Eng.mode ~= "hotseat" and Eng.mode ~= "solo_ai" then
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
            Eng:StartGame({ mode = self._mode, profile = self._soloProfile, team=self._soloTeam, role=self._soloRole })
        end
    end)
    self._startBtn = startBtn
    self._soloProfile, self._soloTeam, self._soloRole = "normal", "R", "agent"
    local function Picker(segment, xOffset, options, current, change)
        local anchor = CreateFrame("Frame", nil, cf)
        anchor:SetSize(130,32)
        anchor:SetPoint("CENTER", cf, "CENTER", bar.segX[segment] + xOffset, bar.y.dropdownOfs)
        return UI.CreateSimpleDropdown(anchor,0,0,130,"",options,current,function(value)
            if Engine().state ~= "IDLE" then return end
            change(value)
            self:EnterIdleState()
        end)
    end
    self._modePicker = Picker(1,-70,{
        {key="solo_ai",label=loc.mode_solo_ai},{key="hotseat",label=loc.mode_hotseat},
    },function() return self._mode end,function(v) self._mode=v end)
    self._difficultyPicker = Picker(1,70,{
        {key="easy",label=loc.solo_easy},{key="normal",label=loc.solo_normal},
    },function() return self._soloProfile end,function(v)
        if self._mode == "solo_ai" then self._soloProfile=v end
    end)
    self._factionPicker = Picker(3,-70,{
        {key="R",label=loc.faction_horde},{key="B",label=loc.faction_alliance},
    },function() return self._soloTeam end,function(v) self._soloTeam=v end)
    self._rolePicker = Picker(3,70,{
        {key="agent",label=loc.solo_role_agent},{key="spy",label=loc.solo_role_spy},
    },function() return self._soloRole end,function(v) self._soloRole=v end)
end

function R:RefreshConfiguration(enabled)
    for _, picker in ipairs({self._modePicker,self._difficultyPicker,self._factionPicker,self._rolePicker}) do
        if picker then picker:SetEnabled(enabled) picker:RefreshDisplay() end
    end
    if self._difficultyPicker then self._difficultyPicker:SetEnabled(enabled and self._mode == "solo_ai") end

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

local function FrameChildren(parent)
    if not parent or not parent.GetChildren then return {} end
    return { parent:GetChildren() }
end

local function FrameName(frame)
    local name = frame and frame.GetName and frame:GetName()
    return type(name) == "string" and name or ""
end

local function TopMouseLevel(frame, best)
    if frame and frame.IsMouseEnabled and frame:IsMouseEnabled() then
        best = math.max(best or 0, frame.GetFrameLevel and frame:GetFrameLevel() or 0)
    end
    local children = FrameChildren(frame)
    for i = 1, #children do
        best = TopMouseLevel(children[i], best)
    end
    return best or 1
end

--- Sichtbares Ergebnisoverlay dieses Feldes. Es liegt auf FULLSCREEN_DIALOG.
function R:_ShownResultOverlay()
    local children = FrameChildren(self._fieldFrame)
    for i = 1, #children do
        local child = children[i]
        if child and child.IsShown and child:IsShown()
            and FrameName(child):find("ArcadiaNexus_ResultOverlay", 1, true) == 1 then
            return child
        end
    end
end

function R:_NavigationPopup()
    local UI = ArcadiaNexus.UI
    local refs = UI and UI.GetF and UI.GetF()
    local main = refs and refs.main
    local popup = main and UI._choicePopups and UI._choicePopups[main]
    local owner = popup and popup._anOwner
    if popup and popup.IsShown and popup:IsShown()
        and owner and owner.kind == "navigation" and owner.gameId == "SI7" then
        return popup
    end
end

function R:_NavigationShield()
    if self._navShield then return self._navShield end
    local shield = CreateFrame("Frame", "ArcadiaNexus_SI7_NavShield", self._fieldFrame)
    shield:EnableMouse(true)
    if shield.EnableKeyboard then shield:EnableKeyboard(false) end
    shield:Hide()
    self._navShield = shield
    return shield
end

function R:_SoloResultBlocksNavigation()
    local Eng = Engine()
    local UI = ArcadiaNexus.UI
    if not Eng or Eng.mode ~= "solo_ai" or Eng.state ~= "FINISHED" then return false end
    return self._fieldFrame and UI and UI.IsResultDialogVisible
        and UI.IsResultDialogVisible(self._fieldFrame) and true or false
end

--- Merkt sich Strata und FrameLevel, bevor sie für das SOLO-Overlay angehoben werden.
--- ShowChoicePopup setzt davor die kanonischen Werte; nur dieser Stand wird wiederhergestellt.
function R:_RememberNavigationFrame(popup)
    local children = {}
    local raw = FrameChildren(popup)
    for i = 1, #raw do
        local child = raw[i]
        if child and child.IsMouseEnabled and child:IsMouseEnabled() and child.GetFrameLevel then
            children[#children + 1] = { frame = child, level = child:GetFrameLevel() }
        end
    end
    self._navSaved = {
        popup = popup,
        strata = popup.GetFrameStrata and popup:GetFrameStrata() or "DIALOG",
        level = popup.GetFrameLevel and popup:GetFrameLevel() or 1,
        children = children,
    }
end

--- HideChoicePopup ist nicht der Lebenszyklus des Frames: popup:Hide() umgeht ihn,
--- und ShowChoicePopup wechselt den Owner, ohne zu verbergen. Der Hide des Frames bleibt.
function R:_BindNavigationHide(popup)
    if popup._si7HideWrapped then return end
    popup._si7HideWrapped = true
    local hide = popup.Hide
    function popup:Hide(...)
        hide(self, ...)
        if self._si7NavActive and self._si7NavActive == R._navToken then
            R:ReleaseNavigationChrome({ fromHide = true })
        end
    end
end

--- Die zentrale Bestätigung bleibt auf DIALOG und läge sonst unter dem
--- mausaktiven Ergebnisoverlay. Nur dieses SOLO-Overlay wird abgedeckt.
function R:_RaiseNavigationOverResult()
    local popup = self:_NavigationPopup()
    local overlay = self:_ShownResultOverlay()
    if not popup or not overlay or not popup.SetFrameStrata then return end
    local tracked = popup._si7NavActive and popup._si7NavActive == self._navToken and self._navSaved
    if not tracked then
        self._navToken = {}
        popup._si7NavActive = self._navToken
        self._navPopup = popup
        local owner = popup._anOwner
        self._navSessionId = owner and owner.sessionId
        self:_RememberNavigationFrame(popup)
        self:_BindNavigationHide(popup)
    else
        self._navPopup = popup
    end
    local shield = self:_NavigationShield()
    if shield.SetParent then shield:SetParent(self._fieldFrame) end
    if shield.SetAllPoints then shield:SetAllPoints(self._fieldFrame) end
    shield:SetFrameStrata("FULLSCREEN_DIALOG")
    shield:EnableMouse(true)
    local coverLevel = TopMouseLevel(overlay) + 1
    shield:SetFrameLevel(coverLevel)
    shield:Show()
    local popupLevel = coverLevel + 20
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(popupLevel)
    local saved = self._navSaved
    local children = saved and saved.children or {}
    for i = 1, #children do
        local child = children[i].frame
        if child and child.SetFrameLevel then child:SetFrameLevel(popupLevel + 1) end
    end
    if popup.Raise then popup:Raise() end
end

--- Idempotent. Ein fremder Owner wird nicht verborgen und seine Overlay-Ebene nicht geschlossen.
--- keepGamepad lässt die bestehende Ebene für SyncOverlay des neuen Owners stehen.
function R:ReleaseNavigationChrome(opts)
    opts = opts or {}
    if self._navBusy then return end
    local popup = self._navPopup
    local token = self._navToken
    if not popup or not token or popup._si7NavActive ~= token then
        if self._navShield then self._navShield:Hide() end
        self._navPopup, self._navToken, self._navSaved, self._navSessionId = nil, nil, nil, nil
        return
    end
    self._navBusy = true
    popup._si7NavActive = nil
    self._navPopup, self._navToken, self._navSessionId = nil, nil, nil
    local saved = self._navSaved
    self._navSaved = nil
    if self._navShield then self._navShield:Hide() end
    if saved and saved.popup == popup then
        if saved.strata and popup.SetFrameStrata then popup:SetFrameStrata(saved.strata) end
        if saved.level and popup.SetFrameLevel then popup:SetFrameLevel(saved.level) end
        for i = 1, #saved.children do
            local item = saved.children[i]
            if item.frame and item.frame.SetFrameLevel then item.frame:SetFrameLevel(item.level) end
        end
    end
    if not opts.keepGamepad and popup._overlayLive then
        local buttons = popup._overlayButtons
        popup._overlayLive = nil
        local GI = ArcadiaNexus.GameInput
        if buttons and GI and GI.OnUiOverlayClosed then pcall(GI.OnUiOverlayClosed, buttons) end
    end
    self._navBusy = false
    if not opts.keepShown and not opts.fromHide and popup.IsShown and popup:IsShown() then
        popup:Hide()
    end
end

function R:_EnsureNavigationAboveResult()
    local UI = ArcadiaNexus.UI
    if not UI or UI._si7ChoiceShowGuard or type(UI.ShowChoicePopup) ~= "function" then return end
    UI._si7ChoiceShowGuard = true
    local show = UI.ShowChoicePopup
    function UI.ShowChoicePopup(config)
        local parent = config and config.parent
        local existing = parent and UI._choicePopups and UI._choicePopups[parent]
        if existing and existing._si7NavActive and existing._si7NavActive == R._navToken then
            local owner = config and config.owner
            local same = owner and owner.kind == "navigation" and owner.gameId == "SI7"
                and owner.sessionId == R._navSessionId
            if owner and not same then
                R:ReleaseNavigationChrome({ keepGamepad = true, keepShown = true })
            end
        end
        local popup = show(config)
        if popup and R:_SoloResultBlocksNavigation() then
            local owner = popup._anOwner
            if owner and owner.kind == "navigation" and owner.gameId == "SI7" then
                R:_RaiseNavigationOverResult()
            end
        end
        return popup
    end
end

--- Schliesst nur den noch sichtbaren Ergebnisdialog dieses SI:7-Feldes.
function R:HideOwnResultDialog()
    local parent = self._fieldFrame
    local UI = ArcadiaNexus.UI
    if not parent or not UI or not UI.IsResultDialogVisible or not UI.HideResultDialog then return end
    if UI.IsResultDialogVisible(parent) then
        UI.HideResultDialog(parent)
    end
end

function R:EnterIdleState()
    self.state = "IDLE"
    local loc = L()
    self:RefreshConfiguration(true)
    if self._gold then self._gold:Hide() end
    if self._boardHolder then self._boardHolder:Hide() end
    if self._clueRow then self._clueRow:Hide() end
    ArcadiaNexus.UI.HideChoicePopup(self._fieldFrame)
    self:HideOwnResultDialog()
    self:ReleaseNavigationChrome()
    if self._roleRow then self._roleRow:Hide() end
    if self._hudTurn then self._hudTurn:Hide() end
    if self._hudLeft then self._hudLeft:Hide() end
    if self._hudClue then self._hudClue:Hide() end
    if self._historyBox then self._historyBox:Hide() end
    if self._noticeFS then self._noticeFS:SetText("") end
    if self._historyFS then self._historyFS:SetText("") end
    self._lastTurn = nil
    if self._turnFlash then self._turnFlash:SetAlpha(0) end
    if self._logoTex then
        self._logoTex:ClearAllPoints()
        self._logoTex:SetSize(CFG.logo_w, CFG.logo_h)
        self._logoTex:SetPoint("CENTER", self._fieldFrame, "CENTER", CFG.logo_ofs_x,
            CFG.logo_ofs_y)
        self._logoTex:Show()
    end
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
    if v.mode == "solo_ai" and not v.canClue then ArcadiaNexus.UI.HideChoicePopup(self._fieldFrame) end

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
    self:RefreshConfiguration(false)
    if self._modePicker then self._modePicker:SetEnabled(false) end

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
        local word = id and Logic.Word(id, pub.wordSet, v.locale) or ""
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
        history = string.format(loc.hud_history_guess, actionTeam, Logic.Word(pub.ids[pub.lastIndex], pub.wordSet, v.locale))
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
    if v.mode == "solo_ai" and v.notice ~= "solo_blocked" then
        local language = v.locale == "deDE" and "DE" or "EN"
        local strength = loc["solo_" .. (v.profile or "normal")]
        local status = v.canClue and loc.solo_your_clue or (v.canGuess and loc.solo_your_turn or loc.solo_thinking)
        if v.state == "FINISHED" then status = loc.hud_phase_O end
        local message = string.format(loc.solo_status, language, strength, status)
        if pub.lastKind == "P" and v.aiReason then
            message = message .. "\n" .. (loc["solo_" .. v.aiReason] or "")
        end
        if v.notice and v.notice ~= "solo_ai" then message=message .. "\n" .. (loc[v.notice] or "") end
        self._noticeFS:SetText(message)
    elseif feedback then
        self._noticeFS:SetText(feedback)
    elseif v.canClue then
        self._noticeFS:SetText(string.format(loc.hud_view_clue, roleName))
    elseif v.canGuess then
        self._noticeFS:SetText(string.format(loc.hud_view_guess, roleName))
    else
        self._noticeFS:SetText(string.format(loc.hud_view_wait, roleName))
    end
    self._clueRow:Show()
    if v.mode == "solo_ai" and not v.spy then
        self._clueBox:Hide()
        self._clueNumber:Hide()
        self._clueBtn:Hide()
    else
        self._clueBox:Show()
        self._clueNumber:Show()
        self._clueBtn:Show()
    end
    if v.canClue then self._clueBtn:Enable() self._clueBox:Enable() else self._clueBtn:Disable() self._clueBox:Disable() end
    if self._clueNumberPicker then self._clueNumberPicker:SetEnabled(v.canClue) end
    if self._dictionaryBtn then
        self._dictionaryBtn:SetShown(v.mode == "solo_ai" and v.spy)
        if v.canClue then self._dictionaryBtn:Enable() else self._dictionaryBtn:Disable() end
    end
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
    self:_EnsureNavigationAboveResult()
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
    if v.mode == "solo_ai" then
        lines = { reason, loc.solo_result }
    elseif v.mode == "hotseat" then
        lines = { reason, loc.go_hotseat }
        won = true
    else
        lines = { reason, won and loc.go_mp_win or loc.go_mp_loss }
    end
    self.state = "FINISHED"
    ArcadiaNexus.UI.ShowArcadeResult(self._fieldFrame, {
        isCurrent = v.mode == "solo_ai" and function()
            local current = Eng:GetView()
            return current.runId == v.runId and current.state == "FINISHED"
        end or nil,
        title = title,
        titleColor = (winner == "R") and { 0.9, 0.25, 0.2 } or { 0.35, 0.55, 1 },
        gameId = "SI7",
        result = won and "WIN" or "LOSS",
        lines = lines,
        L = loc,
        xp = v.mode == "solo_ai" and 0 or nil,
        hideHighscore = v.mode == "hotseat" or v.mode == "solo_ai",
        onRetry = function()
            if v.mode == "solo_ai" then
                if not Eng:StartGame({ mode="solo_ai", locale=v.locale, profile=v.profile, team=v.team, role=v.role }) then
                    Eng:MaybeShowResult()
                end
            elseif v.mode == "hotseat" then
                Eng:StartGame({ mode = "hotseat" })
            else
                local Shell = ArcadiaNexus.MatchShell
                if Shell and Shell.Rematch then Shell.Rematch("SI7") end
            end
        end,
        onExit = function()
            Eng:StopGame()
        end,
        buttons = (v.mode ~= "hotseat" and v.mode ~= "solo_ai") and {
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
