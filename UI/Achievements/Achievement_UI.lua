--[[
    ArcadiaNexus – Achievement_UI
    UI/Achievement_UI.lua

    Einstiegspunkt des Achievement-Panels.
    Koordiniert ScrollFrame, Stats-Header und Row-Rendering.

    Abhängigkeiten (müssen VOR dieser Datei im TOC stehen):
        UI/Achievement_UI_Helpers.lua
        UI/Achievement_UI_Row.lua
]]

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.AchievementUI = {}
local AUI = ArcadiaNexus.AchievementUI

-- ============================================================
-- Interner State
-- ============================================================
local _panel       = nil
local _sf          = nil
local _sc          = nil
local _rows        = {}   -- { frame, yOff } pro Zeile
local _statHeader  = nil
local _currentGame = nil
local _emptyHint   = nil

local function H()  return ArcadiaNexus.AchUI_H  end
local function Row() return ArcadiaNexus.AUI_Row end

-- Accessor-Funktionen für Summary-Modul (Achievement_Summary.lua)
function AUI:_GetSC()    return _sc end
function AUI:_GetSF()    return _sf end
local function HideEmptyHint()
    if _emptyHint then _emptyHint:Hide() end
end

function AUI:_ClearRows()
    Row().ReleaseAll()
    _rows = {}
    HideEmptyHint()
end

-- ============================================================
-- Scrollbar
-- ============================================================
local function UpdateScrollbar()
    if not _sf or not _sf.ScrollBar then return end
    local sb       = _sf.ScrollBar
    local contentH = _sc:GetHeight()
    local viewH    = _sf:GetHeight()
    sb.visibleExtentPercentage = viewH / math.max(contentH, 1)
    if contentH <= viewH then
        sb:Hide()
        if sb.Track   then sb.Track:Hide()   end
        if sb.TrackBG then sb.TrackBG:Hide() end
    else
        sb:Show()
        if sb.Track   then sb.Track:Show()   end
        if sb.TrackBG then sb.TrackBG:Show() end
    end
end

-- ============================================================
-- ScrollFrame (einmalig)
-- ============================================================
local function BuildScrollFrame()
    if not _panel then return end
    _sf = CreateFrame("ScrollFrame", "AchScrollFrame", _panel)
    _sf:SetPoint("TOPLEFT",     _panel, "TOPLEFT",      4, -4)
    _sf:SetPoint("BOTTOMRIGHT", _panel, "BOTTOMRIGHT", -4,  4)

    _sc = CreateFrame("Frame", nil, _sf)
    _sc:SetHeight(1)
    _sf:SetScrollChild(_sc)

    if _G.CreateNexusScrollbar then
        _G.CreateNexusScrollbar(_sf, _panel)
    end

    _sf:SetScript("OnSizeChanged", function(self, w, h)
        _sc:SetWidth(math.max(w - 6, 10))
    end)
    C_Timer.After(0, function()
        if _sf and _sf:GetWidth() and _sf:GetWidth() > 0 then
            _sc:SetWidth(math.max(_sf:GetWidth() - 6, 10))
        end
    end)
end

-- ============================================================
-- Statistik-Header
-- ============================================================
local function BuildStatsHeader()
    if not _panel or _statHeader then return end
    _statHeader = _panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    _statHeader:SetPoint("TOPRIGHT", _panel, "TOPRIGHT", -32, -8)
    _statHeader:SetTextColor(0.75, 0.70, 0.65)
end

local function UpdateStatsHeader()
    if not _statHeader then return end
    local AM = ArcadiaNexus.AchievementManager
    if not AM then return end
    local ok, stats = pcall(function() return AM:GetStats() end)
    if not ok or not stats then return end
    local Hloc = H() and H().loc or function(de, en)
        return (ArcadiaNexus.ActiveLocale == "deDE") and de or en
    end
    _statHeader:SetText(
        Hloc("Erfolge: ", "Achievements: ") ..
        stats.unlocked .. "/" .. stats.total ..
        "  |  XP: +" .. stats.xpEarned
    )
end

-- ============================================================
-- Zeilen recyceln
-- ============================================================
local function ClearRows()
    Row().ReleaseAll()
    _rows = {}
    HideEmptyHint()
end

local function ShowEmptyHint(parent, text)
    if not _emptyHint then
        _emptyHint = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    end
    _emptyHint:SetParent(parent)
    _emptyHint:ClearAllPoints()
    _emptyHint:SetPoint("TOP", parent, "TOP", 0, -40)
    _emptyHint:SetText(text)
    _emptyHint:Show()
end

-- ============================================================
-- Höhenänderung einer Zeile → alle Folgezeilen verschieben
-- ============================================================
local function OnRowHeightChanged(rowIdx, delta)
    for i = rowIdx + 1, #_rows do
        local entry = _rows[i]
        if entry and entry.frame then
            local f = entry.frame
            f:ClearAllPoints()
            entry.yOff = entry.yOff - delta
            f:SetPoint("TOPLEFT", _sc, "TOPLEFT", 0, entry.yOff)
        end
    end
    -- Content-Höhe neu berechnen
    local totalH = 0
    for _, entry in ipairs(_rows) do
        if entry.frame then
            totalH = math.max(totalH, math.abs(entry.yOff) + entry.frame:GetHeight())
        end
    end
    _sc:SetHeight(math.max(totalH + H().PAD, 1))
    C_Timer.After(0, UpdateScrollbar)
end

-- ============================================================
-- ShowGame
-- ============================================================
function AUI:ShowGame(gameId)
    if not _sc then return end
    _currentGame = gameId
    ClearRows()

    local achData = ArcadiaNexus.AchievementData
    if not achData then return end

    local groups = {}
    for _, group in ipairs(achData) do
        if group.gameId == gameId then
            groups[#groups + 1] = group
        end
    end

    -- Kein Treffer per gameId → als category-Schlüssel interpretieren
    -- (z.B. "DENKSPIELE", "ARCADE" = Spielkategorie mit mehreren Spielen)
    if #groups == 0 then
        for _, group in ipairs(achData) do
            local groupCat = group.category or group.gameId
            if groupCat == gameId then
                groups[#groups + 1] = group
            end
        end
    end

    local W = _sc:GetWidth() or 0
    if W < 10 then
        C_Timer.After(0.05, function() AUI:ShowGame(gameId) end)
        return
    end

    if #groups == 0 then
        ShowEmptyHint(_sc, H().loc("Keine Erfolge für dieses Spiel.", "No achievements for this game."))
        _sc:SetHeight(80)
        C_Timer.After(0, UpdateScrollbar)
        return
    end

    local ROW_GAP = 3
    local yOff    = -(H().PAD)

    for i, group in ipairs(groups) do
        local idx = i  -- Closure-Capture
        local rowFrame = Row().Make(group, _sc, W, yOff, function(delta)
            OnRowHeightChanged(idx, delta)
        end)
        _rows[#_rows + 1] = { frame = rowFrame, yOff = yOff }
        yOff = yOff - H().ROW_H - ROW_GAP
    end

    _sc:SetHeight(math.abs(yOff) + H().PAD)
    if _sf then _sf:SetVerticalScroll(0) end
    C_Timer.After(0, UpdateScrollbar)

    local focusId = AUI._pendingFocusGroup
    if focusId then
        AUI._pendingFocusGroup = nil
        C_Timer.After(0, function() AUI:FocusGroup(focusId) end)
    end
end

--- Klappt die Gruppe auf und scrollt sie in den sichtbaren Bereich.
function AUI:FocusGroup(groupId)
    if not groupId or not _sc then return end
    for _, entry in ipairs(_rows) do
        local row = entry.frame
        if row and row._achGroup and row._achGroup.id == groupId then
            if row._achExpand then
                pcall(row._achExpand)
            end
            if _sf then
                local y = math.abs(entry.yOff or 0)
                local viewH = _sf:GetHeight() or 0
                local maxScroll = math.max(0, (_sc:GetHeight() or 0) - viewH)
                _sf:SetVerticalScroll(math.min(y, maxScroll))
            end
            return
        end
    end
end

-- ============================================================
-- Refresh
-- ============================================================
function AUI:Refresh()
    if self:IsSummary() then
        self:ShowSummary()
    elseif _currentGame then
        self:ShowGame(_currentGame)
    end
end

-- ============================================================
-- Attach
-- ============================================================
function AUI:Attach(panel)
    _panel = panel
    BuildScrollFrame()

    ArcadiaNexus.Engine:On("ACHIEVEMENT_UNLOCKED", function()
        if _panel and _panel:IsShown() then AUI:Refresh() end
    end)

    C_Timer.After(0.1, function()
        local gameId = NexusTabState.activeAchCategory
        if gameId == "ZUSAMMENFASSUNG" then
            if AUI.ShowSummary then AUI:ShowSummary() end
        elseif gameId then
            AUI:ShowGame(gameId)
        end
    end)
end
