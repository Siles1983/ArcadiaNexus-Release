--[[
    ArcadiaNexus – Stats_UI
    UI/Stats_UI.lua
    Spieler-Statistik Profil Panel (Profil-Tab).
    Layout: 2×2 Boxen mit horizontalem + vertikalem Divider.

    Box 1 (oben links)  – Spieler-Profil
    Box 2 (oben rechts) – Spielstatistik
    Box 3 (unten links) – Erfolge + Challenges
    Box 4 (unten rechts)– Titel-Verwaltung
]]

local Stats = {}
ArcadiaNexus.StatsUI = Stats

local UI = ArcadiaNexus.UI

-- ============================================================
-- LAYOUT-KONSTANTEN
-- ============================================================
-- Panel: 821 × 550 px
-- MARGIN: 5px Abstand zum Rahmen rundum
-- GAP: 8px zwischen den Boxen (Divider-Bereich)
local PANEL_W  = 821
local PANEL_H  = 550
local MARGIN   = 5
local GAP      = 8
-- Nutzbare Fläche nach Margin-Abzug
local AVAIL_W  = PANEL_W - MARGIN * 2   -- 811
local AVAIL_H  = PANEL_H - MARGIN * 2   -- 540
-- Boxgröße: (verfügbare Fläche - GAP) / 2, dann nochmal 20px schmaler/niedriger
local BOX_W    = math.floor((AVAIL_W - GAP) / 2) - 20   -- 381
local BOX_H    = math.floor((AVAIL_H - GAP) / 2) - 20   -- 250
local PAD      = 8

-- ============================================================
-- BERECHNUNGS-HELPER
-- ============================================================
function Stats:GetFavoriteGame()
    if not ArcadiaNexusDB or not ArcadiaNexusDB.leaderboard then return nil, 0 end
    local best, bestCount = nil, 0
    for gameId, diffs in pairs(ArcadiaNexusDB.leaderboard) do
        local total = 0
        for _, entry in pairs(diffs) do
            total = total + (entry.wins   or 0)
                          + (entry.losses or 0)
                          + (entry.draws  or 0)
        end
        if total > bestCount then bestCount = total; best = gameId end
    end
    return best, bestCount
end

function Stats:GetHighestScoreEver()
    if not ArcadiaNexusDB or not ArcadiaNexusDB.leaderboard then return 0, nil, nil end
    local best, bestGame, bestDiff = 0, nil, nil
    for gameId, diffs in pairs(ArcadiaNexusDB.leaderboard) do
        for diff, entry in pairs(diffs) do
            for _, hs in ipairs(entry.highscores or {}) do
                if hs > best then best = hs; bestGame = gameId; bestDiff = diff end
            end
        end
    end
    return best, bestGame, bestDiff
end

function Stats:GetWinRate()
    local p = ArcadiaNexusDB and ArcadiaNexusDB.profile
    if not p or (p.totalGames or 0) == 0 then return 0 end
    return math.floor(((p.wins or 0) / p.totalGames) * 100)
end

function Stats:GetAchievementCount()
    if not ArcadiaNexusDB or not ArcadiaNexusDB.achievements then return 0, 0 end
    local unlocked = 0
    for _ in pairs(ArcadiaNexusDB.achievements.unlocked or {}) do unlocked = unlocked + 1 end
    -- BUG-FIX: Gruppen nutzen .tiers, nicht .achievements
    local total = 0
    local AD = ArcadiaNexus.AchievementData
    if AD then
        for _, g in ipairs(AD) do
            total = total + #(g.tiers or {})
        end
    end
    return unlocked, total
end

function Stats:GetGameLabel(gameId)
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.GetLabel then
        return GR.GetLabel(gameId)
    end
    return gameId or "–"
end

function Stats:GetDiffLabel(diff)
    local L = ArcadiaNexus.GetLocaleTable("UI")
    if not diff then return "–" end
    local d = diff:lower()
    if     d == "easy"   then return L["lb_diff_easy"]    or "Einfach"
    elseif d == "normal" then return L["lb_diff_normal"]  or "Normal"
    elseif d == "hard"   then return L["lb_diff_hard"]    or "Schwer"
    end
    return diff
end

-- Gibt sortierte Liste aller freigeschalteten Titel zurück
-- { { key = "Novice of the Nexus Arcade", label = "Novice of the Nexus Arcade" }, ... }
function Stats:GetUnlockedTitles()
    local XPM    = ArcadiaNexus.XPManager
    local prof   = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
    local level  = prof.level or 1
    -- TITLES-Tabelle aus XPManager ist lokal – wir nutzen GetTitle pro Level
    -- Freigeschaltete Titel = alle Titel-Schwellen bis zum aktuellen Level
    local TITLE_LEVELS = {1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50}
    local seen   = {}
    local result = {}
    for _, lvl in ipairs(TITLE_LEVELS) do
        if lvl <= level then
            local t = (XPM and XPM.GetTitle) and XPM:GetTitle(lvl) or nil
            if t and not seen[t] then
                seen[t] = true
                table.insert(result, { key = t, label = t })
            end
        end
    end
    return result
end

-- ============================================================
-- PANEL AUFBAUEN
-- ============================================================
function Stats:BuildPanel(parent)
    if self._panel then return self._panel end

    local p = CreateFrame("Frame", "NexusStatsPanel", parent, "BackdropTemplate")
    p:SetAllPoints(parent)
    p:Hide()
    self._panel = p

    -- Subframes für die 4 Boxen (werden in _Rebuild befüllt)
    self._box1Content = nil
    self._box2Content = nil
    self._box3Content = nil
    self._box4Content = nil

    -- Boxen einmalig aufbauen (Struktur ist statisch)
    self:_BuildBoxes(p)

    -- Auf relevante Events reagieren
    ArcadiaNexus.Engine:On("XP_UPDATED",     function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("GOLD_UPDATED",   function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("STREAK_UPDATED", function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)
    ArcadiaNexus.Engine:On("GAME_RESULT",    function() if p:IsShown() then pcall(function() Stats:_Rebuild() end) end end)

    return p
end

-- ============================================================
-- BOXEN BAUEN (Struktur – einmalig)
-- ============================================================
-- ============================================================
-- BOXEN BAUEN (Struktur – einmalig)
-- ============================================================
function Stats:_BuildBoxes(p)
    local L = ArcadiaNexus.GetLocaleTable("UI")

    -- Gesamtgröße des 2×2-Rasters
    local GRID_W = BOX_W * 2 + GAP   -- 770
    local GRID_H = BOX_H * 2 + GAP   -- 508

    -- Zentrierender Container-Frame
    local grid = CreateFrame("Frame", nil, p)
    grid:SetSize(GRID_W, GRID_H)
    grid:SetPoint("CENTER", p, "CENTER", 0, 0)
    self._grid = grid

    -- Hilfsfunktion: Box ohne CreateBox-Titel, Titel zentriert + Divider
    local function MakeBox(parent, titleText, x, y, w, h)
        -- UI.CreateBox mit echtem Titel (baut intern FontString + UI-Achievement-Divider)
        local box, content = UI.CreateBox(parent, titleText, x, y, w, h)

        -- titleFS via GetRegions() auf CENTER umanchern
        for _, region in ipairs({box:GetRegions()}) do
            if region:IsObjectType("FontString") then
                region:ClearAllPoints()
                region:SetPoint("TOP", box, "TOP", 0, -7)
                break
            end
        end

        -- Eigener Divider mit WHITE8X8 (UI-Achievement-Divider rendert hier nicht)
        local div = box:CreateTexture(nil, "OVERLAY", nil, 7)
        div:SetTexture("Interface\\Buttons\\WHITE8X8")
        div:SetVertexColor(0.35, 0.28, 0.18, 0.7)
        div:SetPoint("TOPLEFT",  box, "TOPLEFT",  20, -22)
        div:SetPoint("TOPRIGHT", box, "TOPRIGHT", -20, -22)
        div:SetHeight(2)

        -- Content 5px unter Divider-Unterkante
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT",     box, "TOPLEFT",     UI.PAD, -35)
        content:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -UI.PAD, UI.PAD)
        return box, content
    end

    -- 4 Boxen relativ zum zentrierten grid-Frame
    local _, c1 = MakeBox(grid, L["stats_header_profile"] or "Spieler-Profil",
        0, 0, BOX_W, BOX_H)
    self._box1Content = c1

    local _, c2 = MakeBox(grid, L["stats_header_games"] or "Spielstatistik",
        BOX_W + GAP, 0, BOX_W, BOX_H)
    self._box2Content = c2

    local _, c3 = MakeBox(grid,
        (L["stats_header_achievements"] or "Erfolge") .. " & " .. (L["stats_header_challenges"] or "Challenges"),
        0, BOX_H + GAP, BOX_W, BOX_H)
    self._box3Content = c3

    local box4, c4 = MakeBox(grid, "Titel",
        BOX_W + GAP, BOX_H + GAP, BOX_W, BOX_H)
    self._box4Content = c4
    self._box4Frame   = box4

    -- ── Horizontaler Divider (zwischen oberer und unterer Zeile) ──
    local hDiv = grid:CreateTexture(nil, "OVERLAY", nil, 7)
    hDiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    hDiv:SetVertexColor(0.35, 0.28, 0.18, 0.7)
    hDiv:SetPoint("TOPLEFT",  grid, "TOPLEFT",  10, -(BOX_H + GAP/2 - 1))
    hDiv:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -10, -(BOX_H + GAP/2 - 3))
    hDiv:SetHeight(1)

    -- ── Vertikaler Divider (20px kürzer oben+unten) ───────────
    local vDiv = grid:CreateTexture(nil, "OVERLAY", nil, 7)
    vDiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    vDiv:SetVertexColor(0.35, 0.28, 0.18, 0.7)
    vDiv:SetPoint("TOPLEFT",    grid, "TOPLEFT",    BOX_W + GAP/2 - 1, -10)
    vDiv:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", BOX_W + GAP/2 - 1,  10)
    vDiv:SetWidth(2)

    -- Initialen Inhalt befüllen
    self:_Rebuild()
end

-- ============================================================
-- REBUILD: Inhalt der 4 Boxen neu zeichnen
-- ============================================================
local ROW_H  = 20
local INDENT = 6

local function CreateStatsRowPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Stats.Rows",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Frame", nil, poolParent)
            wrap:SetHeight(ROW_H)
            wrap._headerFS = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            wrap._labelFS  = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            wrap._valueFS  = wrap:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            return wrap
        end,
        onRelease = function(wrap)
            wrap:Hide()
            wrap:ClearAllPoints()
            wrap._isHeader = nil
            if wrap._headerFS then wrap._headerFS:SetText("") end
            if wrap._labelFS  then wrap._labelFS:SetText("") end
            if wrap._valueFS  then wrap._valueFS:SetText("") end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

local function CreateStatsProgressPool()
    local poolParentRef = nil
    return ArcadiaNexus.UI.FramePool.New({
        name = "Stats.ProgressBars",
        create = function(poolParent)
            poolParentRef = poolParent
            local wrap = CreateFrame("Frame", nil, poolParent)
            wrap._bg = wrap:CreateTexture(nil, "BACKGROUND", nil, 0)
            wrap._bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            wrap._fill = CreateFrame("StatusBar", nil, wrap)
            wrap._fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            wrap._fill:SetMinMaxValues(0, 1)
            wrap._border = CreateFrame("Frame", nil, wrap, "BackdropTemplate")
            wrap._border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileEdge = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            wrap._border:SetBackdropBorderColor(0.42, 0.34, 0.18, 0.85)
            wrap._labelFS = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            return wrap
        end,
        onRelease = function(wrap)
            wrap:Hide()
            wrap:ClearAllPoints()
            if wrap._labelFS then wrap._labelFS:SetText("") end
            if poolParentRef then wrap:SetParent(poolParentRef) end
        end,
    })
end

function Stats:_EnsureContentPools()
    if not self._rowPool then self._rowPool = CreateStatsRowPool() end
    if not self._progressPool then self._progressPool = CreateStatsProgressPool() end
end

function Stats:_Row(parent, yOff, labelText, valueText, isHeader)
    local row = self._rowPool:Acquire({})
    row:SetParent(parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOff)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -yOff)
    row:SetHeight(ROW_H)
    row._isHeader = isHeader

    if isHeader then
        row._headerFS:ClearAllPoints()
        row._headerFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
        row._headerFS:SetTextColor(1.00, 0.82, 0.00)
        row._headerFS:SetText(labelText)
        row._headerFS:Show()
        row._labelFS:Hide()
        row._valueFS:Hide()
    else
        row._headerFS:Hide()
        row._labelFS:ClearAllPoints()
        row._labelFS:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
        row._labelFS:SetTextColor(0.85, 0.78, 0.60)
        row._labelFS:SetText(labelText)
        row._labelFS:Show()
        if valueText then
            row._valueFS:ClearAllPoints()
            row._valueFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, -yOff)
            row._valueFS:SetTextColor(1.00, 1.00, 1.00)
            row._valueFS:SetText(valueText)
            row._valueFS:Show()
        else
            row._valueFS:Hide()
        end
    end
    row:Show()
    return yOff + ROW_H
end

function Stats:_ProgressBar(parent, yOff, fraction, label)
    local BAR_W = math.floor(BOX_W * 0.65)
    local BAR_H = 12

    local wrap = self._progressPool:Acquire({})
    wrap:SetParent(parent)
    wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOff)
    wrap:SetSize(BAR_W + 80, BAR_H)

    wrap._bg:ClearAllPoints()
    wrap._bg:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
    wrap._bg:SetSize(BAR_W, BAR_H)
    wrap._bg:SetVertexColor(0, 0, 0, 0.45)
    wrap._bg:Show()

    wrap._fill:ClearAllPoints()
    wrap._fill:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT, -yOff)
    wrap._fill:SetSize(BAR_W, BAR_H)
    wrap._fill:SetValue(math.min(1, fraction))
    wrap._fill:SetStatusBarColor(0.10, 0.60, 1.00, 1)
    wrap._fill:Show()

    wrap._border:ClearAllPoints()
    wrap._border:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT - 1, -(yOff - 1))
    wrap._border:SetSize(BAR_W + 2, BAR_H + 2)
    wrap._border:SetFrameLevel(wrap._fill:GetFrameLevel() + 1)
    wrap._border:Show()

    if label then
        wrap._labelFS:ClearAllPoints()
        wrap._labelFS:SetPoint("LEFT", wrap._fill, "RIGHT", 6, 0)
        wrap._labelFS:SetTextColor(0.85, 0.78, 0.60)
        wrap._labelFS:SetText(label)
        wrap._labelFS:Show()
    else
        wrap._labelFS:Hide()
    end
    wrap:Show()
    return yOff + BAR_H + 6
end

function Stats:_Rebuild()
    local L       = ArcadiaNexus.GetLocaleTable("UI")
    local profile = (ArcadiaNexusDB and ArcadiaNexusDB.profile) or {}
    local streak  = (ArcadiaNexusDB and ArcadiaNexusDB.streak)  or {}
    local gold    = (ArcadiaNexusDB and ArcadiaNexusDB.tavernGold and ArcadiaNexusDB.tavernGold.balance) or 0
    local XPM     = ArcadiaNexus.XPManager

    local level   = profile.level      or 1
    local totalXP = profile.totalXP    or 0
    local wins    = profile.wins       or 0
    local losses  = profile.losses     or 0
    local draws   = profile.draws      or 0
    local total   = profile.totalGames or 0
    local wr      = self:GetWinRate()
    local cur     = streak.current     or 0
    local best    = streak.best        or 0

    local favGame, favCount       = self:GetFavoriteGame()
    local hsVal, hsGame, hsDiff   = self:GetHighestScoreEver()
    local achUnlocked, achTotal   = self:GetAchievementCount()

    local CM        = ArcadiaNexus.ChallengeManager
    local gotd      = CM and CM.GetGameOfDay and CM:GetGameOfDay()
    local gotdLabel = gotd and self:GetGameLabel(gotd) or "–"
    local hist      = CM and CM:GetHistory() or {}

    local p = self._panel
    if not p then return end

    self:_EnsureContentPools()
    self._rowPool:ReleaseAll()
    self._progressPool:ReleaseAll()

    -- ── BOX 1: Spieler-Profil ─────────────────────────────────
    do
        local newC = self._box1Content
        if not newC then return end

        local y = 4
        y = self:_Row(newC, y, L["stats_level"]       or "Level:",
            level .. "  –  " .. ((XPM and XPM.GetTitle) and XPM:GetTitle(level) or "Arcade Initiate"))
        y = self:_Row(newC, y, L["stats_total_xp"]    or "Gesamt-XP:",    tostring(totalXP))
        y = self:_Row(newC, y, L["stats_tavern_gold"]  or "Tavern Gold:",
            "|cffffd700" .. tostring(gold) .. " Gold|r")
        y = self:_Row(newC, y, L["stats_streak"]       or "Login-Streak:",
            cur .. " " .. (L["stats_days"] or "Tage") ..
            "  (" .. (L["stats_best"] or "Beste:") .. " " .. best .. ")")
        if gotd then
            y = self:_Row(newC, y, L["stats_gotd"] or "Spiel des Tages:",
                gotdLabel .. "  |cff00ff88(+25% EXP)|r")
        end
    end

    -- ── BOX 2: Spielstatistik ─────────────────────────────────
    do
        local newC = self._box2Content
        if not newC then return end

        local y = 4
        y = self:_Row(newC, y, L["stats_total_games"] or "Spiele gesamt:", tostring(total))
        y = self:_Row(newC, y, L["stats_wins"]        or "Gewonnen:",
            tostring(wins) .. "  (" .. wr .. "%)")
        y = self:_Row(newC, y, L["stats_losses"]      or "Verloren:",      tostring(losses))
        y = self:_Row(newC, y, L["stats_draws"]       or "Unentschieden:", tostring(draws))
        if favGame then
            y = self:_Row(newC, y, L["stats_fav_game"] or "Lieblingsspiel:",
                self:GetGameLabel(favGame) .. "  (" .. favCount .. "x)")
        end
        if hsVal > 0 then
            local hsLabel = (self:GetGameLabel(hsGame) or "?") ..
                (hsDiff and ("  ·  " .. self:GetDiffLabel(hsDiff)) or "")
            y = self:_Row(newC, y, L["stats_top_score"] or "Höchster Score:",
                tostring(hsVal) .. "  |cff888888(" .. hsLabel .. ")|r")
        end
    end

    -- ── BOX 3: Erfolge + Challenges ───────────────────────────
    do
        local newC = self._box3Content
        if not newC then return end

        local y = 4
        y = self:_Row(newC, y, L["stats_header_achievements"] or "Erfolge", nil, true)
        local achFrac = achTotal > 0 and (achUnlocked / achTotal) or 0
        local achPct  = math.floor(achFrac * 100)
        y = self:_Row(newC, y, L["stats_ach_count"] or "Freigeschaltet:",
            achUnlocked .. " / " .. achTotal .. "  (" .. achPct .. "%)")
        y = self:_ProgressBar(newC, y, achFrac, achPct .. "%")

        y = y + 6

        y = self:_Row(newC, y, L["stats_header_challenges"] or "Challenges", nil, true)
        y = self:_Row(newC, y, L["stats_challenges_done"] or "Abgeschlossen:",
            tostring(hist.completedTotal or 0))
        y = self:_Row(newC, y, L["stats_challenges_gold"] or "Gold verdient:",
            "|cffffd700" .. tostring(hist.goldEarned or 0) .. " Gold|r")
    end

    -- ── BOX 4: Titel-Verwaltung ───────────────────────────────
    -- Box 4 wird nur beim ersten Rebuild vollständig gebaut (Dropdown braucht stabilen Frame)
    if not self._box4Built then
        self:_BuildBox4()
        self._box4Built = true
    else
        self:_RefreshBox4()
    end
end

-- ============================================================
-- BOX 4: Titel-Dropdown + Sichtbarkeit (einmaliger Aufbau)
-- ============================================================
function Stats:_BuildBox4()
    local c4  = self._box4Content
    if not c4 then return end
    local L   = ArcadiaNexus.GetLocaleTable("UI")
    local prof = (ArcadiaNexusDB and ArcadiaNexusDB.profile) or {}

    -- Label
    local lbl = c4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", c4, "TOPLEFT", INDENT, -4)
    lbl:SetTextColor(0.85, 0.78, 0.60)
    lbl:SetText(L["stats_title_select"] or "Aktiver Titel:")

    -- Dropdown
    local titles = self:GetUnlockedTitles()

    -- Fallback wenn noch kein Titel freigeschaltet
    if #titles == 0 then
        local noTitle = c4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noTitle:SetPoint("TOPLEFT", c4, "TOPLEFT", INDENT, -24)
        noTitle:SetTextColor(0.6, 0.55, 0.45)
        noTitle:SetText(L["stats_no_titles"] or "Noch keine Titel freigeschaltet.")
        self._titleDropdown = nil
    else
        local function getCurrent()
            local p2 = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
            -- Fallback: höchster freigeschalteter (letzter in der sortierten Liste)
            return p2.activeTitle or titles[#titles].key
        end

        local function onChange(key)
            if ArcadiaNexusDB and ArcadiaNexusDB.profile then
                ArcadiaNexusDB.profile.activeTitle = key
            end
            -- Header sofort aktualisieren
            local vis = (ArcadiaNexusDB and ArcadiaNexusDB.profile and
                         ArcadiaNexusDB.profile.titleVisible) ~= false
            if vis and ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
                pcall(ArcadiaNexus.UI.UpdateBadge)
            end
        end

        local dd = UI.CreateSimpleDropdown(c4, INDENT, 18, BOX_W - 40,
            "", titles, getCurrent, onChange)
        self._titleDropdown = dd
    end

    -- Checkbox: Titel anzeigen
    local cb = UI.CreateCheckbox(c4,
        L["stats_title_visible"] or "Titel im Header anzeigen",
        INDENT, 62)
    local initVisible = (prof.titleVisible ~= false)
    UI.SetCheckboxValue(cb, initVisible)
    cb:SetScript("OnClick", function(self_cb)
        local val = UI.GetCheckboxValue(self_cb)
        if ArcadiaNexusDB and ArcadiaNexusDB.profile then
            ArcadiaNexusDB.profile.titleVisible = val
        end
        -- Header sofort aktualisieren
        if ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
            pcall(ArcadiaNexus.UI.UpdateBadge)
        end
    end)
    self._titleCB = cb
end

-- Leichte Aktualisierung bei Rebuild (Checkbox-State, kein Rebuild der Frames)
function Stats:_RefreshBox4()
    if self._titleCB then
        local prof = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
        UI.SetCheckboxValue(self._titleCB, prof.titleVisible ~= false)
    end
    -- Dropdown-Text aktualisieren (falls Titel durch Level-Up neu freigeschaltet)
    if self._titleDropdown then
        local prof   = ArcadiaNexusDB and ArcadiaNexusDB.profile or {}
        local titles = self:GetUnlockedTitles()
        local cur    = prof.activeTitle or (titles[#titles] and titles[#titles].key) or ""
        for _, opt in ipairs(titles) do
            if opt.key == cur then
                self._titleDropdown:SetText(opt.label)
                break
            end
        end
    end
end

-- ============================================================
-- REFRESH / SHOW / HIDE (externe API)
-- ============================================================
function Stats:Refresh()
    if self._panel and self._panel:IsShown() then
        pcall(function() self:_Rebuild() end)
    end
end

function Stats:Show()
    if self._panel then
        self._panel:Show()
        pcall(function() self:_Rebuild() end)
    end
end

function Stats:Hide()
    if self._panel then self._panel:Hide() end
end
