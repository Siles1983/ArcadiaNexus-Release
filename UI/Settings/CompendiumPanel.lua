-- Wiederverwendbare Such- und Artikelseite für die Hub-Einstellungen.
local A = _G.ArcadiaNexus
local UI = A.UI
local C = A.Compendium

local function IsGerman()
    return not GetLocale or GetLocale() == "deDE"
end

local function T(de, en)
    return IsGerman() and de or en
end

local function RefreshHost(parent)
    local HS = A.HubSettings
    if HS and HS._activeTab == "HELP" and HS._RefreshSettingsLayout then
        HS:_RefreshSettingsLayout()
    end
end

local function ShowArticle(parent, article)
    parent._article = article
    parent._list:Hide()
    parent._articleView:Show()
    parent._articleTitle:SetText(article.title)
    parent._articleBody:SetText(article.body)
    local h = math.max(300, parent._articleBody:GetStringHeight() + 180)
    parent._contentHeight = h
    RefreshHost(parent)
end

local function ShowResults(parent)
    parent._article = nil
    parent._articleView:Hide()
    parent._list:Show()
    local results = C.Search(parent._search:GetText())
    for i, row in ipairs(parent._rows) do
        local article = results[i]
        if article then
            row._article = article
            row._title:SetText(article.title)
            row._summary:SetText(article.summary)
            row:Show()
        else
            row._article = nil
            row:Hide()
        end
    end
    parent._empty:SetShown(#results == 0)
    parent._restart:ClearAllPoints()
    parent._restart:SetPoint("TOPLEFT", parent._list, "TOPLEFT", 0, -(#results * 64 + 10))
    parent._contentHeight = math.max(270, 102 + #results * 64 + 55)
    RefreshHost(parent)
end

function C.BuildPanel(parent)
    if parent._compendiumBuilt then return end
    parent._compendiumBuilt = true
    parent._contentHeight = 500

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)
    title:SetText(T("Kompendium", "Compendium"))

    local search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    search:SetSize(300, 24)
    search:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -47)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    parent._search = search

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("LEFT", search, "RIGHT", 12, 0)
    hint:SetText(T("Suche nach Stichworten", "Search by keywords"))
    hint:SetTextColor(0.75, 0.70, 0.55)
    parent._hint = hint

    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -83)
    list:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -83)
    local pageCount = #C.GetPages()
    list:SetHeight(pageCount * 64 + 40)
    parent._list = list
    parent._rows = {}

    for i = 1, pageCount do
        local row = CreateFrame("Button", nil, list, "BackdropTemplate")
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * 64)
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(i - 1) * 64)
        row:SetHeight(58)
        row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = {left=2, right=2, top=2, bottom=2}})
        row:SetBackdropColor(0.10, 0.08, 0.04, 0.85)
        row:SetBackdropBorderColor(0.45, 0.37, 0.18, 0.9)
        local rowTitle = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowTitle:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
        rowTitle:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
        rowTitle:SetJustifyH("LEFT")
        local summary = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        summary:SetPoint("TOPLEFT", rowTitle, "BOTTOMLEFT", 0, -3)
        summary:SetPoint("TOPRIGHT", rowTitle, "BOTTOMRIGHT", 0, -3)
        summary:SetJustifyH("LEFT")
        summary:SetTextColor(0.75, 0.70, 0.55)
        row._title, row._summary = rowTitle, summary
        row:SetScript("OnClick", function(self) if self._article then ShowArticle(parent, self._article) end end)
        parent._rows[i] = row
    end

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8)
    empty:SetText(T("Keine passenden Artikel gefunden.", "No matching articles found."))
    parent._empty = empty

    local restart = UI.CreateButton(list, T("Tour erneut starten", "Restart tour"), 180, 26)
    restart:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(pageCount * 64 + 10))
    restart:SetScript("OnClick", function()
        if A.GuideTour then A.GuideTour:Restart() end
    end)
    parent._restart = restart

    local articleView = CreateFrame("Frame", nil, parent)
    articleView:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -88)
    articleView:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -88)
    articleView:SetHeight(900)
    articleView:Hide()
    parent._articleView = articleView

    local back = UI.CreateButton(articleView, T("Zur Übersicht", "Back to results"), 135, 26)
    back:SetPoint("TOPLEFT", articleView, "TOPLEFT", 0, 0)
    back:SetScript("OnClick", function() ShowResults(parent) end)

    local articleTitle = articleView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    articleTitle:SetPoint("TOPLEFT", articleView, "TOPLEFT", 0, -40)
    articleTitle:SetPoint("TOPRIGHT", articleView, "TOPRIGHT", 0, -40)
    articleTitle:SetJustifyH("LEFT")
    parent._articleTitle = articleTitle

    local articleBody = articleView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    articleBody:SetPoint("TOPLEFT", articleTitle, "BOTTOMLEFT", 0, -14)
    articleBody:SetPoint("RIGHT", articleView, "RIGHT", -4, 0)
    articleBody:SetJustifyH("LEFT")
    articleBody:SetJustifyV("TOP")
    articleBody:SetWordWrap(true)
    articleBody:SetTextColor(0.90, 0.84, 0.70)
    parent._articleBody = articleBody

    search:SetScript("OnTextChanged", function() ShowResults(parent) end)
    ShowResults(parent)
end

function C.RefreshLayout(parent, width)
    if not parent or not parent._compendiumBuilt then return end
    parent._search:SetWidth(math.min(300, math.max(170, width - 240)))
    parent._hint:SetShown(width >= 440)
    if parent._article then
        parent._contentHeight = math.max(300, parent._articleBody:GetStringHeight() + 180)
    end
end

function C.Open(id)
    local HS = A.HubSettings
    if not HS then return end
    if NexusTabs then NexusTabs.SetActive("SETTINGS") end
    HS:SetActiveTab("HELP")
    local panel = HS._tabFrames and HS._tabFrames.HELP
    if not panel then return end
    if not id then ShowResults(panel); return end
    for _, page in ipairs(C.GetPages()) do
        if page.id == id then ShowArticle(panel, page); return end
    end
end
