--[[
    Gaming Hub
    UI/Leaderboard_UI.lua
    Version: 4.0.0

    Generischer Score-View-Renderer für das Leaderboard.
    Layout und Metriken kommen aus LeaderboardRegistry (RegisterLeaderboard).
    Wird aufgerufen via ArcadiaNexus.LB.ShowGame(gameId)
]]

local ArcadiaNexus = _G.ArcadiaNexus
local LR = ArcadiaNexus.LeaderboardRegistry

local function L(key, gameId)
    if gameId and ArcadiaNexus.GetLocaleTable then
        local gameTbl = ArcadiaNexus.GetLocaleTable(gameId)
        local gv = gameTbl and gameTbl[key]
        if gv and gv ~= "" and gv ~= key and gv ~= ("[" .. key .. "]") then
            return gv
        end
    end
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return (tbl and tbl[key]) or key
end

-- ============================================================
-- Layout Konstanten
-- ============================================================

local TITLE_OFFSET = 28
local ROW_HEIGHT   = 22
local DIFF_HEIGHT  = 20
local SEP_HEIGHT   = 8
local BOX_BOT_PAD  = 10
local VALUE_COLUMN_OFFSET = 86
local VALUE_COLUMN_WIDTH  = 72

local RANK_COLORS = {
    [1] = { 1.00, 0.82, 0.00 },
    [2] = { 0.75, 0.75, 0.75 },
    [3] = { 0.80, 0.50, 0.20 },
}

-- ============================================================
-- Score-View Renderer
-- ============================================================

local LB = {}
ArcadiaNexus.LB = LB

local _panel         = nil
local _scroll        = nil
local _scrollChild   = nil
local _sectionBoxPool = nil

local function GetPanel()
    if _panel then return _panel end
    _panel = _G.ArcadiaNexusUI and _G.ArcadiaNexusUI.GetScoreboardPanel and
             _G.ArcadiaNexusUI.GetScoreboardPanel()
    return _panel
end

local function EnsureScrollFrame()
    if _scroll then return _scrollChild end

    local panel = GetPanel()
    if not panel then return nil end

    local sf = CreateFrame("ScrollFrame", "NexusLBScoreScroll", panel)
    sf:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 6)
    _scroll = sf

    if CreateNexusScrollbar then
        CreateNexusScrollbar(sf, panel)
    end

    local sc = CreateFrame("Frame", "NexusLBScoreScrollChild", sf)
    sc:SetWidth(sf:GetWidth() or 600)
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    _scrollChild = sc
    return sc
end

local function ResetBoxRegions(box)
    local function hideList(list)
        for i = 1, #(list or {}) do
            local r = list[i]
            if r then
                r:Hide()
                r:ClearAllPoints()
                if r.SetText then r:SetText("") end
                if r.SetTextColor then r:SetTextColor(1, 1, 1) end
                if r.SetJustifyH then r:SetJustifyH("LEFT") end
                if r.GetStringWidth and r.SetWidth then
                    r:SetWidth(0)
                end
                if r.SetVertexColor then r:SetVertexColor(1, 1, 1, 1) end
            end
        end
    end
    hideList(box._normalLabels)
    hideList(box._valueLabels)
    hideList(box._difficultyLabels)
    hideList(box._separators)
    if box._title then
        box._title:Hide()
        box._title:SetText("")
        box._title:ClearAllPoints()
        box._title:SetTextColor(1, 1, 1)
        box._title:SetJustifyH("LEFT")
        box._title:SetWidth(0)
    end
    box._usedNormal = 0
    box._usedValue  = 0
    box._usedDiff   = 0
    box._usedSep    = 0
end

local function AcquireFromCache(box, listKey, usedKey, createFn)
    local used = (box[usedKey] or 0) + 1
    box[usedKey] = used
    local list = box[listKey]
    local region = list[used]
    if not region then
        region = createFn(box)
        list[used] = region
    end
    region:Show()
    return region
end

local function AcquireNormalLabel(box)
    return AcquireFromCache(box, "_normalLabels", "_usedNormal", function(b)
        return b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end)
end

local function AcquireValueLabel(box)
    return AcquireFromCache(box, "_valueLabels", "_usedValue", function(b)
        return b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end)
end

local function AcquireDifficultyLabel(box)
    return AcquireFromCache(box, "_difficultyLabels", "_usedDiff", function(b)
        return b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end)
end

local function AcquireSeparator(box)
    return AcquireFromCache(box, "_separators", "_usedSep", function(b)
        local sep = b:CreateTexture(nil, "ARTWORK")
        sep:SetTexture("Interface\\Buttons\\WHITE8X8")
        sep:SetHeight(1)
        return sep
    end)
end

local function CreateSectionBoxPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Leaderboard.SectionBoxes",
        create = function(poolParent)
            poolParentRef = poolParent
            local box = CreateFrame("Frame", nil, poolParent, "BackdropTemplate")
            box:SetBackdrop({
                bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            box._title            = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            box._normalLabels     = {}
            box._valueLabels      = {}
            box._difficultyLabels = {}
            box._separators       = {}
            box._usedNormal = 0
            box._usedValue  = 0
            box._usedDiff   = 0
            box._usedSep    = 0
            return box
        end,
        onRelease = function(box)
            ResetBoxRegions(box)
            box:Hide()
            box:ClearAllPoints()
            if poolParentRef then box:SetParent(poolParentRef) end
        end,
    })
end

local function EnsureSectionBoxPool()
    if not _sectionBoxPool then _sectionBoxPool = CreateSectionBoxPool() end
end

local function ClearView()
    if _sectionBoxPool then _sectionBoxPool:ReleaseAll() end
    if _scrollChild then
        _scrollChild:SetHeight(1)
        if _scroll then _scroll:SetVerticalScroll(0) end
    end
end

local function MakeBox(parent, yOffset, boxHeight)
    EnsureSectionBoxPool()
    local box = _sectionBoxPool:Acquire({})
    box:SetParent(parent)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT",  parent, "TOPLEFT",  8,  -yOffset)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -yOffset)
    box:SetHeight(boxHeight)
    box:SetBackdropColor(0.05, 0.04, 0.03, 0.80)
    box:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.80)
    ResetBoxRegions(box)
    box:Show()
    return box
end

local function AddSeparator(box, y)
    local sep = AcquireSeparator(box)
    sep:ClearAllPoints()
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  box, "TOPLEFT",  14, y - 2)
    sep:SetPoint("TOPRIGHT", box, "TOPRIGHT", -14, y - 2)
    sep:SetVertexColor(0.50, 0.45, 0.30, 0.4)
    sep:Show()
    return y - SEP_HEIGHT
end

local function GetScoreEntry(SM, gameId, diffId)
    if diffId == "_global" then
        local entries = SM.GetAllEntries and SM:GetAllEntries(gameId) or {}
        if LR and LR.MergeEntries then
            return LR.MergeEntries(entries)
        end
        return entries[1] or {}
    end
    local diff = (diffId ~= "default") and diffId or nil
    return SM:GetScores(gameId, diff)
end

local function SectionDiffs(section, diffs)
    if section and section.scope == "global" then
        return { { id = "_global", labelKey = nil } }
    end
    return diffs
end

local function SectionDiffCount(section, diffs)
    if section and section.scope == "global" then return 1 end
    return #diffs
end

-- ── Sektion: Top Scores ─────────────────────────────────────

local function CalcTopScoresHeight(section, diffCount)
    local count = section.count or 3
    local height = TITLE_OFFSET + (diffCount * count * ROW_HEIGHT)
    if diffCount > 1 then
        height = height + (diffCount * DIFF_HEIGHT) + ((diffCount - 1) * SEP_HEIGHT)
    end
    return height + BOX_BOT_PAD
end

local function RenderTopScores(box, section, gameId, diffs, SM)
    local count = section.count or 3
    local multi = #diffs > 1
    local cy = -TITLE_OFFSET

    for i, diff in ipairs(diffs) do
        local entry = GetScoreEntry(SM, gameId, diff.id)
        local hs = entry.highscores or {}

        if multi then
            local dlbl = AcquireDifficultyLabel(box)
            dlbl:ClearAllPoints()
            dlbl:SetPoint("TOPLEFT", box, "TOPLEFT", 14, cy)
            dlbl:SetText(L(diff.labelKey, gameId))
            dlbl:SetTextColor(0.90, 0.75, 0.30)
            cy = cy - DIFF_HEIGHT
        end

        for rank = 1, count do
            local lbl = AcquireNormalLabel(box)
            lbl:ClearAllPoints()
            lbl:SetPoint("TOPLEFT", box, "TOPLEFT", 18, cy)
            lbl:SetText(string.format("#%d", rank))
            lbl:SetTextColor(0.70, 0.65, 0.50)

            local val = AcquireValueLabel(box)
            val:ClearAllPoints()
            val:SetPoint("TOPRIGHT", box, "TOPRIGHT", -14, cy)
            val:SetWidth(0)
            val:SetJustifyH("RIGHT")
            if hs[rank] then
                val:SetText(LR.FormatValue(hs[rank], { format = "score" }))
                local c = RANK_COLORS[rank]
                val:SetTextColor(c[1], c[2], c[3])
            else
                val:SetText("–")
                val:SetTextColor(0.45, 0.43, 0.36)
            end
            cy = cy - ROW_HEIGHT
        end

        if multi and i < #diffs then
            cy = AddSeparator(box, cy)
        end
    end
end

-- ── Sektion: Statistik-Zeilen ───────────────────────────────

local function CalcStatsHeight(section, diffCount)
    local rows = section.rows or {}
    local multi = diffCount > 1
    local height = TITLE_OFFSET

    if multi then
        for i = 1, diffCount do
            height = height + DIFF_HEIGHT + (#rows * ROW_HEIGHT)
            if i < diffCount then height = height + SEP_HEIGHT end
        end
    else
        height = height + (#rows * ROW_HEIGHT)
    end

    return height + BOX_BOT_PAD
end

local function RenderStatRow(box, row, entry, y, indent)
    if row.hideIfEmpty and not LR.HasAnyData(entry, row) then
        return y
    end

    local value = LR.ResolveRowValue(entry, row)
    local text = LR.FormatValue(value, row)

    local lbl = AcquireNormalLabel(box)
    lbl:ClearAllPoints()
    lbl:SetPoint("TOPLEFT", box, "TOPLEFT", indent, y)
    lbl:SetText(L(row.labelKey or row.id or "", box._gameId))
    lbl:SetTextColor(0.70, 0.65, 0.50)

    local val = AcquireValueLabel(box)
    val:ClearAllPoints()
    val:SetPoint("TOPLEFT", box, "TOPRIGHT", -VALUE_COLUMN_OFFSET, y)
    val:SetWidth(VALUE_COLUMN_WIDTH)
    val:SetJustifyH("RIGHT")

    if text then
        val:SetText(text)
        local c = LR.GetValueColor(row.valueColor or "default")
        val:SetTextColor(c[1], c[2], c[3])
    else
        val:SetText("–")
        val:SetTextColor(0.45, 0.43, 0.36)
    end

    return y - ROW_HEIGHT
end

local function RenderStats(box, section, gameId, diffs, SM)
    local rows = section.rows or {}
    local multi = #diffs > 1
    local sy = -TITLE_OFFSET

    for i, diff in ipairs(diffs) do
        local entry = GetScoreEntry(SM, gameId, diff.id)

        if multi then
            local dlbl = AcquireDifficultyLabel(box)
            dlbl:ClearAllPoints()
            dlbl:SetPoint("TOPLEFT", box, "TOPLEFT", 14, sy)
            dlbl:SetText(L(diff.labelKey, gameId))
            dlbl:SetTextColor(0.90, 0.75, 0.30)
            sy = sy - DIFF_HEIGHT

            for _, row in ipairs(rows) do
                sy = RenderStatRow(box, row, entry, sy, 18)
            end

            if i < #diffs then
                sy = AddSeparator(box, sy)
            end
        else
            for _, row in ipairs(rows) do
                sy = RenderStatRow(box, row, entry, sy, 14)
            end
        end
    end
end

local function UpdateScrollbar(contentHeight)
    if not _scroll or not _scroll.ScrollBar then return end
    local viewHeight = _scroll:GetHeight()
    _scroll.ScrollBar.visibleExtentPercentage = viewHeight / contentHeight

    local show = contentHeight > viewHeight
    if show then
        _scroll.ScrollBar:Show()
        if _scroll.ScrollBar.Track then _scroll.ScrollBar.Track:Show() end
        if _scroll.ScrollBar.TrackBG then _scroll.ScrollBar.TrackBG:Show() end
    else
        _scroll.ScrollBar:Hide()
        if _scroll.ScrollBar.Track then _scroll.ScrollBar.Track:Hide() end
        if _scroll.ScrollBar.TrackBG then _scroll.ScrollBar.TrackBG:Hide() end
    end
end

-- ============================================================
-- ShowGame — Haupt-Renderer
-- ============================================================

function LB.ShowGame(gameId)
    local sc = EnsureScrollFrame()
    if not sc then return end

    ClearView()

    local SM = ArcadiaNexus.ScoreManager
    if not SM then return end

    local schema = LR and LR.GetSchema(gameId)
    if not schema or not schema.sections or #schema.sections == 0 then
        local hint = MakeBox(sc, 8, 60)
        local lbl = hint._title
        lbl:ClearAllPoints()
        lbl:SetPoint("CENTER")
        lbl:SetText(L("lb_no_data"))
        lbl:SetTextColor(0.55, 0.50, 0.40)
        lbl:Show()
        sc:SetHeight(76)
        return
    end

    local diffs = schema.difficulties
    local PAD   = 8
    local yOff  = PAD

    for _, section in ipairs(schema.sections) do
        local secDiffs = SectionDiffs(section, diffs)
        local diffCount = SectionDiffCount(section, diffs)
        local boxHeight
        if section.type == "top_scores" then
            boxHeight = CalcTopScoresHeight(section, diffCount)
        elseif section.type == "stats" then
            boxHeight = CalcStatsHeight(section, diffCount)
        else
            boxHeight = 0
        end

        if boxHeight > 0 then
            local box = MakeBox(sc, yOff, boxHeight)
            box._gameId = gameId

            local title = box._title
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
            title:SetText(L(section.titleKey or "lb_played", gameId))
            title:SetTextColor(1.00, 0.82, 0.00)
            title:Show()

            if section.type == "top_scores" then
                RenderTopScores(box, section, gameId, secDiffs, SM)
            elseif section.type == "stats" then
                RenderStats(box, section, gameId, secDiffs, SM)
            end

            yOff = yOff + boxHeight + PAD
        end
    end

    sc:SetHeight(math.max(yOff, 1))
    UpdateScrollbar(yOff)
end

-- ============================================================
-- Tab-Listener
-- ============================================================

local function RegisterLBTabListener()
    if not _G.NexusTabs or not _G.NexusTabs.OnTabChanged then return end
    NexusTabs.OnTabChanged(function(newTab)
        if newTab ~= "SCOREBOARD" then return end
        local gameId = NexusTabState and NexusTabState.activeScoreGame
        if gameId then
            LB.ShowGame(gameId)
        end
    end)
end

if _G.NexusTabs and _G.NexusTabs.OnTabChanged then
    RegisterLBTabListener()
else
    local _lbInitF = CreateFrame("Frame")
    _lbInitF:RegisterEvent("PLAYER_ENTERING_WORLD")
    _lbInitF:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        RegisterLBTabListener()
    end)
end
