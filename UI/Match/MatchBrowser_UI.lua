--[[
    UI/Match/MatchBrowser_UI.lua
    MP-Spieleiste, Sitzungen, Lobby, Canvas-Stage (Option B).
]]

if not ArcadiaNexus.HasMultiplayer or not ArcadiaNexus.HasMultiplayer() then
    return
end

local ArcadiaNexus = _G.ArcadiaNexus
ArcadiaNexus.MatchBrowserUI = {}
local UI = ArcadiaNexus.MatchBrowserUI

local selectedId
local lobbyGameId
UI._hostPolicy = nil
UI._policyTouched = false
UI._joinNotice = nil

local function Loc(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or key
end

local function GameLabel(gameId)
    local GR = ArcadiaNexus.GameRegistry
    return (GR and GR.GetLabel and GR.GetLabel(gameId)) or gameId or "?"
end

local function ShortName(key)
    if not key then return "?" end
    return key:match("^([^-]+)") or key
end

local function Si7Loc(key)
    local tbl = ArcadiaNexus.GetLocaleTable("SI7")
    return tbl and tbl[key] or key
end

local function SelectedGame()
    return ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell.selectedGameId
end

local function MatchSeatsFor(gameId)
    local GR = ArcadiaNexus.GameRegistry
    local info = GR and GR.GetById and gameId and GR.GetById(gameId)
    return (info and info.matchSeats) or 4
end

local function DefaultHostPolicy()
    local MT = ArcadiaNexus.MatchTransport
    local n = (MT and MT.GroupSize and MT.GroupSize()) or 1
    if n > MatchSeatsFor(SelectedGame()) then
        return "INVITE"
    end
    return "OPEN"
end

local function HostPolicy()
    if UI._policyTouched and UI._hostPolicy then
        return UI._hostPolicy
    end
    return UI._hostPolicy or DefaultHostPolicy()
end

local function PolicyLabel(policy)
    policy = policy or "OPEN"
    local key = "match_policy_" .. policy
    local s = Loc(key)
    if s == key then return policy end
    return s
end

local function PinText(panel)
    local P = ArcadiaNexus.MatchProtocol
    local raw = panel and panel._pinBox and panel._pinBox.GetText and panel._pinBox:GetText() or ""
    if P and P.NormalizePin then return P.NormalizePin(raw) end
    return raw
end

function UI.GetHostOpts()
    return { policy = HostPolicy(), pin = PinText(UI._panel) }
end

function UI.SetJoinNotice(reason)
    UI._joinNotice = reason
    if UI._panel and UI._panel._browse and UI._panel._browse:IsShown() then
        UI.Refresh()
    end
end

local function RefreshHeader()
    if NexusTabs and NexusTabs.RefreshPanelVisibility then
        NexusTabs.RefreshPanelVisibility()
    end
end

local PANEL_INSET = 8
local LOBBY_INSET = 16
local PANEL_GAP   = 10
local ROW_H       = 28
local ROW_STEP    = 34
local COL_NAME_W  = 180
local COL_STATUS_W = 80
local COL_LEFT    = 10
local COL_GAP     = 8
local COL_GROUP_GAP = 12

local function StyleGoldPanel(frame)
    if ArcadiaNexus.UI and ArcadiaNexus.UI.StyleHudStatFrame then
        ArcadiaNexus.UI.StyleHudStatFrame(frame, 0.75)
    end
end

local function StyleGoldRow(btn)
    StyleGoldPanel(btn)
    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hlTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    hlTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",     3, -3)
    hlTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3,  3)
    hlTex:SetVertexColor(1, 0.85, 0.30, 0.14)
    hlTex:SetBlendMode("ADD")

    local accent = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    accent:SetPoint("TOPLEFT",    btn, "TOPLEFT",    3, -3)
    accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 3,  3)
    accent:SetWidth(3)
    accent:SetVertexColor(1.00, 0.82, 0.00, 0)
    btn.accent = accent
end

local function StyleCatButton(btn)
    local catBG = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    catBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background")
    catBG:SetPoint("TOPLEFT",  btn, "TOPLEFT")
    catBG:SetPoint("TOPRIGHT", btn, "TOPRIGHT")
    catBG:SetHeight(28)
    catBG:SetTexCoord(0, 0.6640625, 0, 1)

    local activeBG = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    activeBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
    activeBG:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0,  0)
    activeBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, -5)
    activeBG:SetTexCoord(0, 0.6640625, 0, 1)
    activeBG:SetBlendMode("ADD")
    activeBG:SetAlpha(0)
    btn.activeBG = activeBG

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hlTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
    hlTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0,  0)
    hlTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, -5)
    hlTex:SetTexCoord(0, 0.6640625, 0, 1)
    hlTex:SetBlendMode("ADD")

    local accent = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    accent:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, -1)
    accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0,  1)
    accent:SetWidth(3)
    accent:SetVertexColor(1.00, 0.82, 0.00, 0)
    btn.accent = accent
end

local function SetCatActive(btn, on)
    if not btn then return end
    btn._active = on
    if btn.activeBG then btn.activeBG:SetAlpha(on and 1 or 0) end
    if btn.accent then
        btn.accent:SetVertexColor(1.00, 0.82, 0.00, on and 1 or 0)
    end
    if btn.SetBackdropColor and not btn.activeBG then
        if on then
            btn:SetBackdropColor(0.12, 0.10, 0.04, 0.88)
        else
            btn:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
        end
    end
    if btn.lbl then
        if on then
            btn.lbl:SetTextColor(1, 1, 1)
        else
            btn.lbl:SetTextColor(0.85, 0.78, 0.60)
        end
    end
end

local function HideAllViews(panel)
    if panel._empty then panel._empty:Hide() end
    if panel._browse then panel._browse:Hide() end
    if panel._lobby then panel._lobby:Hide() end
    if panel._stage then panel._stage:Hide() end
end

function UI.GetStage()
    return UI._panel and UI._panel._stage
end

function UI.ShowEmpty()
    local panel = UI._panel
    if not panel then return end
    HideAllViews(panel)
    panel._empty:Show()
    UI.RefreshSidebar()
    RefreshHeader()
end

function UI.ShowSessions(gameId)
    local Shell = ArcadiaNexus.MatchShell
    if gameId and Shell then
        Shell.selectedGameId = gameId
    end
    local panel = UI._panel
    if not panel then return end
    if not SelectedGame() then
        UI.ShowEmpty()
        return
    end
    HideAllViews(panel)
    panel._browse:Show()
    UI.Refresh()
    UI.RefreshSidebar()
    RefreshHeader()
end

function UI.ShowLobby(gameId)
    lobbyGameId = gameId
    local Shell = ArcadiaNexus.MatchShell
    if Shell then Shell.selectedGameId = gameId end
    local panel = UI._panel
    if not panel then return end
    HideAllViews(panel)
    panel._lobby:Show()
    UI.RefreshLobby()
    UI.RefreshSidebar()
    RefreshHeader()
end

function UI.ShowStage(gameId)
    local Shell = ArcadiaNexus.MatchShell
    if Shell then Shell.selectedGameId = gameId end
    local panel = UI._panel
    if not panel then return end
    HideAllViews(panel)
    panel._stage:Show()
    UI.RefreshSidebar()
    RefreshHeader()
end

function UI.OnTabSelect()
    local Shell = ArcadiaNexus.MatchShell
    local liveId = Shell and select(1, Shell.LocalMpGame())
    if liveId then
        local eng = Shell.Engine(liveId)
        if eng and (eng.state == "PLAYING" or eng.state == "FINISHED") then
            UI.ShowStage(liveId)
            if Shell.PresentBoard then Shell.PresentBoard(liveId) end
            return
        end
        if eng and eng.state == "LOBBY" then
            UI.ShowLobby(liveId)
            return
        end
    end
    if SelectedGame() then
        UI.ShowSessions(SelectedGame())
    else
        UI.ShowEmpty()
    end
end

function UI.RequestSelectGame(gameId)
    local Shell = ArcadiaNexus.MatchShell
    if not Shell then return end
    local liveId = select(1, Shell.LocalMpGame())
    if liveId and liveId ~= gameId then
        Shell.ShowLeaveConfirm(function()
            Shell.AbortSession()
            Shell.selectedGameId = gameId
            UI.ShowSessions(gameId)
        end)
        return
    end
    if liveId and liveId == gameId then
        UI.OnTabSelect()
        return
    end
    Shell.selectedGameId = gameId
    UI.ShowSessions(gameId)
end

function UI.BuildSidebar(parent)
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs and ArcadiaNexus.UI.GetGamesPanelFrameRefs()
    if not F then return nil end
    F.matchCatBtns = F.matchCatBtns or {}

    local function IsMatchTitle(info)
        return info and info.matchSeats and info.matchSeats > 0
    end

    local function ShouldShowMatch(game)
        local GR = ArcadiaNexus.GameRegistry
        local info = GR and GR.GetById and GR.GetById(game.id)
        if not IsMatchTitle(info) then return false end
        return not GR.IsVisible or GR.IsVisible(info, GR.FILTER_SIDEBAR)
    end

    local cp = ArcadiaNexus.UI.BuildSidebarPanel(parent, {
        frameName        = "NexusMatchCategoryPanel",
        scrollName       = "NexusMatchCatScroll",
        groupStatePrefix = "mp_",
        includeGeneral   = false,
        arrowKey         = "_mpArrow",
        hdrKey           = "_mpHeaderBtn",
        grpFramePrefix   = "NexusMatchCatGrp_",
        btnPrefix        = "NexusMatchCatBtn_",
        gameBtnsKey      = "_mpGameBtns",
        emptyHintKey     = "_mpEmptyHint",
        favBtnPrefix     = "NexusMatchBtnFav_",
        favEmptyHintFrame = "NexusMatchCatGrp_FAV_EMPTY",
        btnListRef       = F.matchCatBtns,
        getActiveId      = function()
            return ArcadiaNexus.MatchShell and ArcadiaNexus.MatchShell.selectedGameId
        end,
        setActiveId      = function(id)
            if ArcadiaNexus.MatchShell then
                ArcadiaNexus.MatchShell.selectedGameId = id
            end
        end,
        activateCallback = function(id)
            UI.RequestSelectGame(id)
        end,
        onEnterTooltipKey = function(id) return "TOOLTIP_CATEGORY_" .. id .. "_BODY" end,
        initialHide      = true,
        withSearchBar    = false,
        relayoutKey      = "MatchPanelRelayout",
        filterGame       = IsMatchTitle,
        shouldShowGame   = ShouldShowMatch,
        suffixForId      = function(id)
            local Shell = ArcadiaNexus.MatchShell
            local n = Shell and Shell.OpenCount and Shell.OpenCount(id) or 0
            if n > 0 then return "(" .. tostring(n) .. ")" end
            return ""
        end,
    })
    UI._sidebar = cp
    F.matchSidebar = cp
    return cp
end

function UI.RefreshSidebar()
    local F = ArcadiaNexus.UI.GetGamesPanelFrameRefs and ArcadiaNexus.UI.GetGamesPanelFrameRefs()
    if not F or not F.matchCatBtns then return end
    local Shell = ArcadiaNexus.MatchShell
    for _, b in ipairs(F.matchCatBtns) do
        if b.Refresh then b.Refresh() end
        if b.SetSuffix then
            local n = Shell and Shell.OpenCount and Shell.OpenCount(b.catID) or 0
            b.SetSuffix(n > 0 and ("(" .. tostring(n) .. ")") or "")
        end
    end
end

function UI.BuildPanel(parent)
    local panel = CreateFrame("Frame", "ArcadiaNexus_MatchBrowser", parent)
    -- Same rect as F.games (ContentPanel MakePanel): gamesPanelTopInset under the
    -- content divider. PresentBoard reparents the game outer onto _stage; if the
    -- stage is full F.content, canvas CENTER + footer reserve sits ~21px too high.
    local frames = ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF()
    local Layout = ArcadiaNexus.Layout
    local inset = Layout and Layout.content and Layout.content.gamesPanelTopInset
    if frames and frames.content and parent == frames.content and inset then
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -inset)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    else
        panel:SetAllPoints(parent)
    end
    panel:Hide()

    local empty = CreateFrame("Frame", nil, panel)
    empty:SetAllPoints(panel)
    panel._empty = empty
    local eTitle = empty:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    eTitle:SetPoint("CENTER", empty, "CENTER", 0, 12)
    eTitle:SetText(Loc("match_pick_empty_title"))
    eTitle:SetTextColor(1, 0.82, 0)
    local eBody = empty:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eBody:SetPoint("TOP", eTitle, "BOTTOM", 0, -10)
    eBody:SetWidth(420)
    eBody:SetJustifyH("CENTER")
    eBody:SetText(Loc("match_pick_empty_body"))
    eBody:SetTextColor(0.85, 0.78, 0.60)

    local browse = CreateFrame("Frame", nil, panel)
    browse:SetAllPoints(panel)
    browse:Hide()
    panel._browse = browse
    browse:SetScript("OnShow", function()
        if not panel._ttlGuard then
            panel._ttlGuard = ArcadiaNexus.TimerGuard.New()
        end
        panel._ttlGuard:Cancel()
        panel._ttlGuard:EveryTicker(3, function()
            if panel._browse and panel._browse:IsShown() then UI.Refresh() end
        end)
    end)
    browse:SetScript("OnHide", function()
        if panel._ttlGuard then panel._ttlGuard:Cancel() end
    end)

    local title = browse:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", browse, "TOPLEFT", PANEL_INSET, -8)
    title:SetTextColor(1, 0.82, 0)
    panel._bTitle = title

    local hint = browse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", browse, "RIGHT", -PANEL_INSET, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.85, 0.78, 0.60)
    panel._hint = hint

    local list = CreateFrame("Frame", nil, browse, "BackdropTemplate")
    list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    list:SetPoint("BOTTOMLEFT", browse, "BOTTOMLEFT", PANEL_INSET, PANEL_INSET)
    list:SetPoint("RIGHT", browse, "CENTER", -math.floor(PANEL_GAP / 2), 0)
    StyleGoldPanel(list)
    panel._list = list
    panel._rows = {}

    local detail = CreateFrame("Frame", nil, browse, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", PANEL_GAP, 0)
    detail:SetPoint("BOTTOMRIGHT", browse, "BOTTOMRIGHT", -PANEL_INSET, PANEL_INSET)
    StyleGoldPanel(detail)
    panel._detail = detail

    local dTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -14)
    dTitle:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    dTitle:SetJustifyH("LEFT")
    dTitle:SetTextColor(1, 0.82, 0)
    panel._dTitle = dTitle

    local dBody = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dBody:SetPoint("TOPLEFT", dTitle, "BOTTOMLEFT", 0, -10)
    dBody:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    dBody:SetJustifyH("LEFT")
    dBody:SetTextColor(0.85, 0.78, 0.60)
    panel._dBody = dBody

    local policyDD = ArcadiaNexus.UI.CreateSimpleDropdown(
        detail, 14, 118, 168,
        Loc("match_policy_label"),
        {
            { key = "OPEN",   label = Loc("match_policy_OPEN"),   tooltip = Loc("match_policy_OPEN_tip") },
            { key = "PIN",    label = Loc("match_policy_PIN"),    tooltip = Loc("match_policy_PIN_tip") },
            { key = "INVITE", label = Loc("match_policy_INVITE"), tooltip = Loc("match_policy_INVITE_tip") },
        },
        function() return HostPolicy() end,
        function(key)
            UI._hostPolicy = key
            UI._policyTouched = true
            UI._joinNotice = nil
            if panel._policyDD and panel._policyDD.RefreshDisplay then
                panel._policyDD:RefreshDisplay()
            end
            UI.Refresh()
        end
    )
    panel._policyDD = policyDD

    local pinLbl = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pinLbl:SetPoint("TOPLEFT", detail, "TOPLEFT", 198, -118)
    pinLbl:SetTextColor(1, 0.82, 0)
    pinLbl:SetText(Loc("match_pin_label"))
    panel._pinLbl = pinLbl

    local pinBox = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
    pinBox:SetAutoFocus(false)
    pinBox:SetMaxLetters(8)
    pinBox:SetSize(110, 22)
    pinBox:SetPoint("TOPLEFT", pinLbl, "BOTTOMLEFT", -4, -4)
    pinBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    pinBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pinBox:SetScript("OnTextChanged", function()
        if panel._browse and panel._browse:IsShown() then
            UI.Refresh()
        end
    end)
    panel._pinBox = pinBox

    local pinHint = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pinHint:SetPoint("TOPLEFT", pinBox, "BOTTOMLEFT", 4, -4)
    pinHint:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    pinHint:SetJustifyH("LEFT")
    pinHint:SetTextColor(0.7, 0.65, 0.5)
    pinHint:SetText(Loc("match_pin_hint"))
    panel._pinHint = pinHint

    local joinBtn = ArcadiaNexus.UI.CreateArcadiaButton(detail, Loc("match_btn_join"), 120, 32)
    joinBtn:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, 14)
    joinBtn:SetScript("OnClick", function()
        local listS = ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser.List()
        local s
        if listS then
            for i = 1, #listS do
                if listS[i].matchId == selectedId then s = listS[i] break end
            end
        end
        if not s or s.localHost then return end
        if (s.taken or 0) >= (s.maxSeats or 4) then return end
        local pin
        if s.policy == "PIN" then
            pin = PinText(panel)
            if pin == "" then return end
        end
        UI._joinNotice = nil
        local Shell = ArcadiaNexus.MatchShell
        if Shell then Shell.Join(s.gameId or SelectedGame(), s.host, { pin = pin }) end
    end)
    panel._joinBtn = joinBtn

    local hostBtn = ArcadiaNexus.UI.CreateArcadiaButton(detail, Loc("match_btn_host"), 130, 32)
    hostBtn:SetPoint("LEFT", joinBtn, "RIGHT", 8, 0)
    hostBtn:SetScript("OnClick", function()
        local Shell = ArcadiaNexus.MatchShell
        local gid = SelectedGame()
        local opts = UI.GetHostOpts()
        if opts.policy == "PIN" and (not opts.pin or opts.pin == "") then return end
        UI._joinNotice = nil
        if Shell and gid then Shell.Host(gid, opts) end
    end)
    panel._hostBtn = hostBtn

    local lobby = CreateFrame("Frame", nil, panel)
    lobby:SetAllPoints(panel)
    lobby:Hide()
    panel._lobby = lobby

    local lTitle = lobby:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lTitle:SetPoint("TOPLEFT", lobby, "TOPLEFT", LOBBY_INSET, -14)
    lTitle:SetTextColor(1, 0.82, 0)
    panel._lTitle = lTitle

    local lHint = lobby:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lHint:SetPoint("TOPLEFT", lTitle, "BOTTOMLEFT", 0, -8)
    lHint:SetPoint("RIGHT", lobby, "RIGHT", -LOBBY_INSET, 0)
    lHint:SetJustifyH("LEFT")
    lHint:SetTextColor(0.85, 0.78, 0.60)
    panel._lHint = lHint

    local lWarn = lobby:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lWarn:SetPoint("TOPLEFT", lHint, "BOTTOMLEFT", 0, -4)
    lWarn:SetPoint("RIGHT", lobby, "RIGHT", -LOBBY_INSET, 0)
    lWarn:SetJustifyH("LEFT")
    lWarn:SetTextColor(0.95, 0.72, 0.35)
    panel._lWarn = lWarn

    local hdr = CreateFrame("Frame", nil, lobby, "BackdropTemplate")
    hdr:SetPoint("TOPLEFT", lWarn, "BOTTOMLEFT", 0, -10)
    hdr:SetPoint("RIGHT", lobby, "RIGHT", -LOBBY_INSET, 0)
    hdr:SetHeight(22)
    StyleGoldPanel(hdr)
    panel._lHeader = hdr

    local function ColHeader(text, x)
        local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", hdr, "LEFT", x, 0)
        fs:SetTextColor(0.95, 0.85, 0.4)
        fs:SetText(text)
        return fs
    end
    local statusX = COL_LEFT + COL_NAME_W + COL_GAP
    local groupX  = statusX + COL_STATUS_W + COL_GROUP_GAP
    panel._lColName   = ColHeader(Loc("match_col_name"), COL_LEFT)
    panel._lColStatus = ColHeader(Loc("match_col_status"), statusX)
    panel._lColGroup  = ColHeader(Loc("match_col_group"), groupX)

    panel._lobbyRows = {}
    for i = 1, 4 do
        local row = CreateFrame("Button", nil, lobby, "BackdropTemplate")
        row:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -8 - ((i - 1) * ROW_STEP))
        row:SetPoint("RIGHT", lobby, "RIGHT", -LOBBY_INSET, 0)
        row:SetHeight(ROW_H)
        StyleGoldRow(row)
        local nameFS = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", COL_LEFT, 0)
        nameFS:SetWidth(COL_NAME_W)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWordWrap(false)
        row.lbl = nameFS
        local readyFS = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        readyFS:SetPoint("LEFT", row, "LEFT", statusX, 0)
        readyFS:SetWidth(COL_STATUS_W)
        readyFS:SetJustifyH("LEFT")
        local aBtn = ArcadiaNexus.UI.CreateArcadiaButton(row, Si7Loc("btn_pair_a"), 80, 22)
        aBtn:SetPoint("LEFT", row, "LEFT", groupX, 0)
        local bBtn = ArcadiaNexus.UI.CreateArcadiaButton(row, Si7Loc("btn_pair_b"), 80, 22)
        bBtn:SetPoint("LEFT", aBtn, "RIGHT", 8, 0)
        panel._lobbyRows[i] = {
            row = row, nameFS = nameFS, readyFS = readyFS, aBtn = aBtn, bBtn = bBtn,
        }
    end

    local readyBtn = ArcadiaNexus.UI.CreateArcadiaButton(lobby, Loc("match_btn_ready"), 120, 32)
    readyBtn:SetPoint("BOTTOMLEFT", lobby, "BOTTOMLEFT", LOBBY_INSET, LOBBY_INSET)
    readyBtn:SetScript("OnClick", function()
        local Shell = ArcadiaNexus.MatchShell
        local eng = Shell and Shell.Engine(lobbyGameId)
        if eng and eng.SetReady then eng:SetReady(true) end
    end)
    panel._lReady = readyBtn

    local startBtn = ArcadiaNexus.UI.CreateArcadiaButton(lobby, Loc("match_btn_start"), 140, 32)
    startBtn:SetPoint("LEFT", readyBtn, "RIGHT", 10, 0)
    startBtn:SetScript("OnClick", function()
        local Shell = ArcadiaNexus.MatchShell
        local eng = Shell and Shell.Engine(lobbyGameId)
        if eng and eng.TryStartMatch then eng:TryStartMatch() end
    end)
    panel._lStart = startBtn

    local leaveBtn = ArcadiaNexus.UI.CreateArcadiaButton(lobby, Loc("match_btn_leave"), 120, 32)
    leaveBtn:SetPoint("BOTTOMRIGHT", lobby, "BOTTOMRIGHT", -LOBBY_INSET, LOBBY_INSET)
    leaveBtn:SetScript("OnClick", function()
        local Shell = ArcadiaNexus.MatchShell
        Shell.ShowLeaveConfirm(function()
            if Shell then Shell.AbortSession() end
        end)
    end)
    panel._lLeave = leaveBtn

    local roster = CreateFrame("Frame", nil, lobby, "BackdropTemplate")
    roster:SetPoint("BOTTOMLEFT", lobby, "BOTTOMLEFT", LOBBY_INSET, LOBBY_INSET + 44)
    roster:SetPoint("BOTTOMRIGHT", lobby, "BOTTOMRIGHT", -LOBBY_INSET, LOBBY_INSET + 44)
    roster:SetHeight(86)
    StyleGoldPanel(roster)
    roster:Hide()
    panel._roster = roster
    local rHint = roster:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rHint:SetPoint("TOPLEFT", roster, "TOPLEFT", 10, -8)
    rHint:SetPoint("RIGHT", roster, "RIGHT", -10, 0)
    rHint:SetJustifyH("LEFT")
    rHint:SetTextColor(0.85, 0.78, 0.60)
    rHint:SetText(Loc("match_invite_hint"))
    panel._rosterHint = rHint
    panel._rosterRows = {}
    for i = 1, 6 do
        local btn = CreateFrame("Button", nil, roster)
        local col = ((i - 1) % 3)
        local rowI = math.floor((i - 1) / 3)
        btn:SetSize(150, 22)
        btn:SetPoint("TOPLEFT", roster, "TOPLEFT", 10 + col * 158, -28 - rowI * 26)
        StyleCatButton(btn)
        local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 10, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        btn._fs = fs
        btn.lbl = fs
        panel._rosterRows[i] = btn
    end
    local function RosterPage(dir)
        panel._rosterOffset = (panel._rosterOffset or 0) + dir
        if panel._rosterOffset < 0 then panel._rosterOffset = 0 end
        UI.RefreshLobby()
    end
    local prevR = CreateFrame("Button", nil, roster)
    prevR:SetSize(22, 22)
    prevR:SetPoint("TOPRIGHT", roster, "TOPRIGHT", -34, -6)
    prevR:SetScript("OnClick", function() RosterPage(-6) end)
    local prevFS = prevR:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prevFS:SetAllPoints()
    prevFS:SetText("<")
    panel._rosterPrev = prevR
    local nextR = CreateFrame("Button", nil, roster)
    nextR:SetSize(22, 22)
    nextR:SetPoint("TOPRIGHT", roster, "TOPRIGHT", -8, -6)
    nextR:SetScript("OnClick", function() RosterPage(6) end)
    local nextFS = nextR:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nextFS:SetAllPoints()
    nextFS:SetText(">")
    panel._rosterNext = nextR
    rHint:SetPoint("RIGHT", prevR, "LEFT", -8, 0)

    local stage = CreateFrame("Frame", "ArcadiaNexus_MatchStage", panel)
    stage:SetAllPoints(panel)
    stage:Hide()
    panel._stage = stage

    UI._panel = panel
    if ArcadiaNexus.MatchBrowser then
        ArcadiaNexus.MatchBrowser.SetOnChange(function()
            local Shell = ArcadiaNexus.MatchShell
            if Shell and Shell.TryPendingJoin then Shell.TryPendingJoin() end
            if panel:IsShown() then
                if panel._browse:IsShown() then UI.Refresh() end
                if panel._lobby and panel._lobby:IsShown() then UI.RefreshLobby() end
                UI.RefreshSidebar()
            end
        end)
    end
    return panel
end

function UI.RefreshLobby()
    local panel = UI._panel
    if not panel or not lobbyGameId then return end
    local Shell = ArcadiaNexus.MatchShell
    local eng = Shell and Shell.Engine(lobbyGameId)
    local v = eng and eng.GetView and eng:GetView()
    panel._lTitle:SetText((Loc("match_lobby_title")) .. " · " .. GameLabel(lobbyGameId))
    if panel._lWarn then
        panel._lWarn:SetText(Loc("match_reload_warn"))
    end
    if not v then
        panel._lHint:SetText("")
        return
    end
    if v.notice == "groups" then
        panel._lHint:SetText(Si7Loc("hud_groups_need"))
    elseif v.notice == "start-fail" then
        panel._lHint:SetText(Si7Loc("hud_start_fail"))
    elseif v.notice == "rejoin" then
        panel._lHint:SetText(Loc("match_rejoin_wait"))
    else
        local nP = #(v.lobbyPlayers or {})
        if nP == 4 and lobbyGameId == "SI7" then
            panel._lHint:SetText(v.isHost and Si7Loc("hud_lobby_quad") or Si7Loc("hud_lobby_quad_guest"))
        elseif nP == 2 and lobbyGameId == "SI7" then
            panel._lHint:SetText(Si7Loc("hud_lobby_duo"))
        elseif lobbyGameId == "SI7" then
            panel._lHint:SetText(v.isHost and Si7Loc("hud_lobby_host") or Si7Loc("hud_lobby_guest"))
        else
            panel._lHint:SetText(v.isHost and Loc("match_lobby_wait_host") or Loc("match_lobby_wait_guest"))
        end
    end
    local node = eng and eng.match
    if v.isHost and node and node.policy == "PIN" then
        local extra = Loc("match_policy_PIN")
        panel._lHint:SetText((panel._lHint:GetText() or "") .. " · " .. extra)
    elseif v.isHost and node and node.policy == "INVITE" then
        panel._lHint:SetText((panel._lHint:GetText() or "") .. " · " .. Loc("match_policy_INVITE"))
    end

    local players = v.lobbyPlayers or {}
    local showPairs = lobbyGameId == "SI7" and v.state == "LOBBY"
    for i = 1, 4 do
        local row = panel._lobbyRows[i]
        local p = players[i]
        if p then
            row.row:Show()
            local mark = p.self and "> " or ""
            row.nameFS:SetText(mark .. p.name)
            SetCatActive(row.row, p.self)
            row.readyFS:SetText(p.ready and Si7Loc("hud_ready_yes") or Si7Loc("hud_ready_no"))
            row.readyFS:SetTextColor(p.ready and 0.4 or 1, p.ready and 0.9 or 0.55, p.ready and 0.4 or 0.4)
            if showPairs then
                row.aBtn:Show()
                row.bBtn:Show()
                local key = p.key
                if v.isHost then
                    row.aBtn:Enable()
                    row.bBtn:Enable()
                    row.aBtn:SetScript("OnClick", function()
                        if eng and eng.SetLobbyGroup then eng:SetLobbyGroup(key, "A") end
                    end)
                    row.bBtn:SetScript("OnClick", function()
                        if eng and eng.SetLobbyGroup then eng:SetLobbyGroup(key, "B") end
                    end)
                else
                    row.aBtn:Disable()
                    row.bBtn:Disable()
                    row.aBtn:SetScript("OnClick", nil)
                    row.bBtn:SetScript("OnClick", nil)
                end
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

    local inLobby = v.state == "LOBBY"
    if inLobby then panel._lReady:Show() else panel._lReady:Hide() end
    if panel._lStart and panel._lStart.SetLabel then
        panel._lStart:SetLabel(Loc("match_btn_start"))
    end
    if inLobby and v.isHost then
        panel._lStart:Show()
        local canStart = false
        if node and node.canTryStart then
            canStart = node.canTryStart(node) == true
        else
            canStart = #players > 0
            for i = 1, #players do
                if not players[i].ready then
                    canStart = false
                    break
                end
            end
        end
        if canStart then panel._lStart:Enable() else panel._lStart:Disable() end
    else
        panel._lStart:Hide()
    end
    if panel._lColName then panel._lColName:SetText(Loc("match_col_name")) end
    if panel._lColStatus then panel._lColStatus:SetText(Loc("match_col_status")) end
    if panel._lColGroup then panel._lColGroup:SetText(Loc("match_col_group")) end

    local showRoster = v.isHost and node and node.policy == "INVITE" and inLobby
    if panel._roster then
        if showRoster then
            panel._roster:Show()
            if panel._rosterHint then panel._rosterHint:SetText(Loc("match_invite_hint")) end
            local MT = ArcadiaNexus.MatchTransport
            local keys = (MT and MT.GroupMemberKeys and MT.GroupMemberKeys()) or {}
            local seated = {}
            local P = ArcadiaNexus.MatchProtocol
            for i = 1, (node.maxSeats or 4) do
                local k = node.seats and node.seats[i]
                if k then seated[k] = true end
            end
            local eligible = {}
            for i = 1, #keys do
                local key = keys[i]
                local taken = seated[key]
                if not taken and P and P.SamePlayer then
                    for sk in pairs(seated) do
                        if P.SamePlayer(sk, key) then taken = true break end
                    end
                end
                if not taken then eligible[#eligible + 1] = key end
            end
            local page = 6
            local off = panel._rosterOffset or 0
            if off > math.max(0, #eligible - page) then off = math.max(0, #eligible - page) end
            if off < 0 then off = 0 end
            panel._rosterOffset = off
            if panel._rosterPrev then
                if #eligible > page then panel._rosterPrev:Show() else panel._rosterPrev:Hide() end
            end
            if panel._rosterNext then
                if #eligible > page then panel._rosterNext:Show() else panel._rosterNext:Hide() end
            end
            local shown = 0
            for i = 1, page do
                local key = eligible[off + i]
                local row = panel._rosterRows[i]
                if row then
                    if key then
                        shown = shown + 1
                        local invited = node.invited and node.invited[key]
                        if not invited and node.invited and P and P.SamePlayer then
                            for ik, v in pairs(node.invited) do
                                if v and P.SamePlayer(ik, key) then invited = true break end
                            end
                        end
                        row:Show()
                        row._fs:SetText(ShortName(key) .. (invited and (" · " .. Loc("match_invited")) or ""))
                        SetCatActive(row, invited and true or false)
                        row:SetScript("OnClick", function()
                            local Shell = ArcadiaNexus.MatchShell
                            if Shell and Shell.Invite then Shell.Invite(key) end
                        end)
                    else
                        row:Hide()
                    end
                end
            end
            for i = shown + 1, #(panel._rosterRows or {}) do
                panel._rosterRows[i]:Hide()
            end
        else
            panel._roster:Hide()
        end
    end
end

function UI.Refresh()
    local panel = UI._panel
    if not panel or not panel._browse:IsShown() then
        if panel and panel._lobby and panel._lobby:IsShown() then
            UI.RefreshLobby()
        end
        return
    end
    local gid = SelectedGame()
    panel._bTitle:SetText(GameLabel(gid))
    local inGroup = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())
    if inGroup then
        panel._hint:SetText(Loc("match_hint_group"))
    else
        panel._hint:SetText(Loc("match_hint_solo"))
    end

    local all = (ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser.List()) or {}
    local sessions = {}
    for i = 1, #all do
        if all[i].gameId == gid then
            sessions[#sessions + 1] = all[i]
        end
    end
    if not selectedId and sessions[1] then
        selectedId = sessions[1].matchId
    end
    local still = false
    for i = 1, #sessions do
        if sessions[i].matchId == selectedId then still = true break end
    end
    if not still then
        selectedId = sessions[1] and sessions[1].matchId
    end

    for i = 1, math.max(#sessions, #(panel._rows or {})) do
        local row = panel._rows[i]
        if not row then
            row = CreateFrame("Button", nil, panel._list)
            local y = -12 - ((i - 1) * 26)
            row:SetPoint("TOPLEFT",  panel._list, "TOPLEFT",  10, y)
            row:SetPoint("TOPRIGHT", panel._list, "TOPRIGHT", -10, y)
            row:SetHeight(22)
            StyleCatButton(row)
            local fs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            fs:SetPoint("LEFT",  row, "LEFT",  10, 0)
            fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            row._fs = fs
            row.lbl = fs
            panel._rows[i] = row
        end
        local s = sessions[i]
        if s then
            row:Show()
            row._fs:SetText(string.format("%s  ·  %d/%d  ·  %s",
                ShortName(s.host), s.taken or 0, s.maxSeats or 4, PolicyLabel(s.policy)))
            SetCatActive(row, s.matchId == selectedId)
            local id = s.matchId
            row:SetScript("OnClick", function()
                selectedId = id
                UI.Refresh()
            end)
        else
            row:Hide()
        end
    end

    local sel
    for i = 1, #sessions do
        if sessions[i].matchId == selectedId then sel = sessions[i] break end
    end
    if sel then
        panel._dTitle:SetText(GameLabel(sel.gameId))
        local body = string.format(Loc("match_detail"),
            ShortName(sel.host), sel.taken or 0, sel.maxSeats or 4, PolicyLabel(sel.policy))
            local notice = UI._joinNotice
            local allowed = ArcadiaNexus.MatchBrowser and ArcadiaNexus.MatchBrowser._invitedMatchId == sel.matchId
            if notice == "pin" then
                body = body .. "\n" .. Loc("match_reject_pin")
            elseif notice == "invite" then
                body = body .. "\n" .. Loc("match_reject_invite")
            elseif notice == "full" then
                body = body .. "\n" .. Loc("match_reject_full")
            elseif notice == "rejoin-timeout" or notice == "no-match" or notice == "no-seat" then
                body = body .. "\n" .. Loc("match_reject_rejoin")
            elseif allowed then
                body = body .. "\n" .. Loc("match_you_invited")
            elseif sel.policy == "PIN" then
                body = body .. "\n" .. Loc("match_join_need_pin")
            elseif sel.policy == "INVITE" then
                body = body .. "\n" .. Loc("match_invite_hint")
            end
        panel._dBody:SetText(body)
        local pinOk = sel.policy ~= "PIN" or PinText(panel) ~= ""
        if sel.localHost or (sel.taken or 0) >= (sel.maxSeats or 4) or not pinOk then
            panel._joinBtn:Disable()
        else
            panel._joinBtn:Enable()
        end
    else
        panel._dTitle:SetText(Loc("match_empty_title"))
        local body = Loc("match_empty_body")
        if UI._joinNotice == "pin" then
            body = Loc("match_reject_pin")
        elseif UI._joinNotice == "invite" then
            body = Loc("match_reject_invite")
        elseif UI._joinNotice == "full" then
            body = Loc("match_reject_full")
        elseif UI._joinNotice == "rejoin-timeout" or UI._joinNotice == "no-match" or UI._joinNotice == "no-seat" then
            body = Loc("match_reject_rejoin")
        end
        panel._dBody:SetText(body)
        panel._joinBtn:Disable()
    end
    if not UI._policyTouched then
        UI._hostPolicy = DefaultHostPolicy()
    end
    if panel._policyDD and panel._policyDD.RefreshDisplay then
        panel._policyDD:RefreshDisplay()
    end
    local needPin = HostPolicy() == "PIN" or (sel and sel.policy == "PIN")
    if panel._pinLbl then
        if needPin then panel._pinLbl:Show() else panel._pinLbl:Hide() end
    end
    if panel._pinBox then
        if needPin then panel._pinBox:Show() else panel._pinBox:Hide() end
    end
    if panel._pinHint then
        if needPin then panel._pinHint:Show() else panel._pinHint:Hide() end
    end
    if panel._hostBtn then
        if HostPolicy() == "PIN" and PinText(panel) == "" then
            panel._hostBtn:Disable()
        else
            panel._hostBtn:Enable()
        end
    end
end
