-- Erststart-Tour für Hub-Tabs, Profilboxen und Arcadia-Einstellungen.
-- Weitere Hub- und Settings-Tabs werden aus den Registries übernommen.
local A = _G.ArcadiaNexus
local Tour = {}
A.GuideTour = Tour

local VERSION = 1
local descriptions = {
    GAMES = {de="Wähle links eine Kategorie und ein Spiel. Optionen und Anleitungen der Spiele findest du unter Einstellungen.", en="Choose a category and game on the left. Game options and instructions are in Settings."},
    MATCH = {de="Hier hostest du eine Sitzung oder trittst bei. Lobby und Spielfeld bleiben im Mehrspieler-Tab.", en="Host or join a session here. The lobby and board stay in the Multiplayer tab."},
    SCOREBOARD = {de="Deine lokalen Bestwerte und Ergebnisse sind hier nach Spiel geordnet.", en="Your local records and results are grouped here by game."},
    ACHIEVEMENTS = {de="Hier findest du freigeschaltete und noch offene Erfolge.", en="Find completed and open achievements here."},
    PROFIL = {de="Dein Fortschritt, deine Partien, Challenges und Titel sind hier zusammengefasst.", en="Your progress, matches, challenges, and titles are summarized here."},
    SETTINGS = {de="Hier verwaltest du Arcadia und die Optionen einzelner Spiele.", en="Manage Arcadia and individual game options here."},
    GENERAL = {de="Skalierung, Fenster, Toast und Spiel des Tages werden hier eingestellt.", en="Set scaling, window, toasts, and Game of the Day here."},
    DEVELOPER = {de="Entwickleroptionen erscheinen nur für dafür freigeschaltete Nutzer.", en="Developer options appear only for authorized users."},
    HELP = {de="Das Kompendium durchsucht Anleitungen und Stichworte. Hier kannst du diese Tour erneut starten.", en="Search instructions and keywords in the compendium. You can restart this tour here."},
}

local function IsGerman()
    return not GetLocale or GetLocale() == "deDE"
end

local function T(de, en)
    return IsGerman() and de or en
end

local function State()
    if type(ArcadiaNexusDB) ~= "table" then return nil end
    if type(ArcadiaNexusDB.guideTour) ~= "table" then
        ArcadiaNexusDB.guideTour = {version=VERSION, status="unseen"}
    end
    return ArcadiaNexusDB.guideTour
end

local function TabLabel(tab)
    local L = A.GetLocaleTable("UI")
    return tab.labelKey and L[tab.labelKey] or tab.labelFallback or tab.label or tab.id
end

local function BuildSteps()
    local steps = {{kind="intro", title=T("Willkommen in Arcadia", "Welcome to Arcadia"), body=T("Diese kurze Tour zeigt dir die wichtigsten Bereiche. Du kannst sie jederzeit überspringen und später in den Einstellungen erneut starten.", "This short tour shows the main areas. You can skip it at any time and restart it later in Settings.")}}
    local TR = A.TabRegistry
    if TR then
        for _, tab in ipairs(TR.GetAll()) do
            if not tab.isVisible or tab.isVisible() then
                local desc = descriptions[tab.id]
                steps[#steps + 1] = {kind="hub", id=tab.id, title=TabLabel(tab), body=desc and T(desc.de, desc.en) or T("Dieser Bereich ist Teil des Arcadia-Hubs.", "This area is part of the Arcadia hub.")}
                if tab.id == "PROFIL" then
                    local L = A.GetLocaleTable("UI")
                    local boxes = {
                        {L.stats_header_profile, T("Level, XP, Tavern Gold und Login-Serie zeigen deinen persönlichen Fortschritt.", "Level, XP, Tavern Gold, and login streak show your personal progress.")},
                        {L.stats_header_games, T("Partien, Siege und weitere Spielwerte fassen deine Aktivitäten zusammen.", "Matches, wins, and other game values summarize your activity.")},
                        {L.stats_header_challenges, T("Tägliche und wöchentliche Aufgaben zeigen Fortschritt und Belohnungen.", "Daily and weekly tasks show progress and rewards.")},
                        {L.stats_header_titles, T("Hier wählst du deinen aktiven Titel und seine Anzeige im Header.", "Choose your active title and whether it appears in the header.")},
                    }
                    for i, item in ipairs(boxes) do
                        steps[#steps + 1] = {kind="profile", id=i, title=item[1], body=item[2]}
                    end
                end
            end
        end
    end
    local HSTR = A.HubSettingsTabRegistry
    if HSTR then
        for _, tab in ipairs(HSTR.GetAll()) do
            if not tab.isVisible or tab.isVisible() then
                local desc = descriptions[tab.id]
                steps[#steps + 1] = {kind="settings", id=tab.id, title=TabLabel(tab), body=desc and T(desc.de, desc.en) or T("Hier findest du weitere Arcadia-Einstellungen.", "Find more Arcadia settings here.")}
            end
        end
    end
    steps[#steps + 1] = {kind="end", title=T("Du bist startklar", "You're ready"), body=T("Für ausführliche Hilfe öffne Einstellungen > Hilfe. Dort findest du auch die Multiplayer-Anleitung und den Neustart dieser Tour.", "For detailed help, open Settings > Help. It includes the multiplayer guide and the option to restart this tour.")}
    return steps
end

local function FindTabButton(id)
    local F = A.UI.GetF and A.UI.GetF()
    for _, btn in ipairs(F and F.tabBtns or {}) do
        if btn.tabID == id then return btn end
    end
end

local function FindTarget(step)
    if step.kind == "hub" then return FindTabButton(step.id) end
    if step.kind == "profile" then
        local S = A.StatsUI
        return S and S._tourBoxes and S._tourBoxes[step.id]
    end
    if step.kind == "settings" then
        local HS = A.HubSettings
        return HS and HS._tabBtns and HS._tabBtns[step.id]
    end
end

function Tour:_Build(main)
    if self._card then return end
    local outline = CreateFrame("Frame", nil, main, "BackdropTemplate")
    -- ContentChrome liegt als DIALOG-Child über dem normalen Hub-Inhalt.
    -- Eine eigene höhere Strata hält Fokusrahmen und Tourkarte darüber.
    outline:SetFrameStrata("FULLSCREEN_DIALOG")
    outline:SetFrameLevel(100)
    outline:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=18, insets={left=0,right=0,top=0,bottom=0}})
    outline:SetBackdropBorderColor(1, 0.82, 0, 1)
    outline:EnableMouse(false)
    outline:Hide()
    self._outline = outline

    local card = CreateFrame("Frame", nil, main, "BackdropTemplate")
    card:SetSize(430, 155)
    card:SetFrameStrata("FULLSCREEN_DIALOG")
    card:SetFrameLevel(110)
    card:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16, insets={left=5,right=5,top=5,bottom=5}})
    card:SetBackdropColor(0.04, 0.04, 0.06, 0.98)
    card:SetBackdropBorderColor(1, 0.82, 0, 1)
    self._card = card

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -15)
    title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -15)
    title:SetJustifyH("LEFT")
    self._title = title

    local body = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    body:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -10)
    body:SetHeight(70)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetTextColor(0.90, 0.84, 0.70)
    self._body = body

    local back = A.UI.CreateButton(card, T("Zurück", "Back"), 85, 24)
    back:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12)
    back:SetScript("OnClick", function() Tour:Previous() end)
    self._back = back

    local skip = A.UI.CreateButton(card, T("Überspringen", "Skip"), 110, 24)
    skip:SetPoint("BOTTOM", card, "BOTTOM", 0, 12)
    skip:SetScript("OnClick", function() Tour:Finish("skipped") end)

    local nextBtn = A.UI.CreateButton(card, T("Weiter", "Next"), 95, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
    nextBtn:SetScript("OnClick", function() Tour:Next() end)
    self._next = nextBtn

    local progress = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progress:SetPoint("BOTTOMRIGHT", nextBtn, "TOPRIGHT", 0, 3)
    progress:SetTextColor(0.65, 0.60, 0.48)
    self._progress = progress

    card:Hide()
end

function Tour:_ShowStep()
    local step = self._steps and self._steps[self._index]
    if not step then return end
    if step.kind == "hub" then
        NexusTabs.SetActive(step.id)
    elseif step.kind == "profile" then
        NexusTabs.SetActive("PROFIL")
    elseif step.kind == "settings" then
        NexusTabs.SetActive("SETTINGS")
        local HS = A.HubSettings
        if HS then HS:SetActiveTab(step.id) end
    end

    local main = A.UI.GetF and A.UI.GetF().main
    if not main then return end
    self:_Build(main)
    self._title:SetText(step.title or "")
    self._body:SetText(step.body or "")
    self._progress:SetText(self._index .. " / " .. #self._steps)
    self._back:SetEnabled(self._index > 1)
    local label = self._index == #self._steps and T("Fertig", "Finish") or T("Weiter", "Next")
    self._next:SetLabel(label)
    self._card:ClearAllPoints()
    if step.kind == "profile" and (step.id == 1 or step.id == 2) then
        self._card:SetPoint("BOTTOM", main, "BOTTOM", 0, 55)
    elseif step.kind == "settings" then
        self._card:SetPoint("BOTTOM", main, "BOTTOM", 0, 55)
    else
        self._card:SetPoint("TOP", main, "TOP", 0, -25)
    end

    local target = FindTarget(step)
    self._outline:ClearAllPoints()
    if target and target:IsShown() then
        self._outline:SetPoint("TOPLEFT", target, "TOPLEFT", -5, 5)
        self._outline:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 5, -5)
        self._outline:Show()
    else
        self._outline:Hide()
    end
    self._card:Show()
end

function Tour:Start()
    if self._active then return end
    local main = A.UI.GetF and A.UI.GetF().main
    if not main or not main:IsShown() or not State() then return end
    self._steps = BuildSteps()
    self._index = 1
    self._active = true
    self:_ShowStep()
end

function Tour:StartIfNeeded()
    local state = State()
    if state and state.status == "unseen" then self:Start() end
end

function Tour:Restart()
    local state = State()
    if not state then return end
    state.status = "unseen"
    if self._active then self:Finish(nil) end
    self:Start()
end

function Tour:Finish(status)
    if status then
        local state = State()
        if state then state.status = status; state.version = VERSION end
    end
    self._active = false
    if self._card then self._card:Hide() end
    if self._outline then self._outline:Hide() end
end

function Tour:Next()
    if not self._active then return end
    if self._index >= #self._steps then self:Finish("completed"); return end
    self._index = self._index + 1
    self:_ShowStep()
end

function Tour:Previous()
    if not self._active or self._index <= 1 then return end
    self._index = self._index - 1
    self:_ShowStep()
end

function Tour:OnHubHidden()
    if self._active then self:Finish(nil) end
end
