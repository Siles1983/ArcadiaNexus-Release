--[[
    ArcadiaNexus – GameSettingsBuilder
    UI/GameSettings/GameSettingsBuilder.lua

    Vereinheitlichtes Layout für Spiel-Settings:
      Reihe 1: Sound (links) | Theme (rechts)  — oder Sound full width (noTheme)
      Reihe 2: Spielanleitung (100 %), optional mehrere Sektionen

    Siehe docs/GameSettings_Blueprint.md
]]

ArcadiaNexus = ArcadiaNexus or {}
ArcadiaNexus.GameSettings = ArcadiaNexus.GameSettings or {}

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function FallbackGamesPanelWidth()
    if ArcadiaNexus.Layout then
        local w = ArcadiaNexus.Layout.GetGamesPanelSize()
        if w and w > 0 then return w end
    end
    return 580
end

-- ============================================================
-- Layout-Konstanten (Blueprint Abschnitt 10)
-- ============================================================

GS.ROW1_H_MIN = 180
GS.ROW2_H     = 160
GS.COL_SPLIT  = 0.5

local BOX_CHROME_H   = 32   -- Titel + Divider
local SOUND_MASTER_H = 26
local DEFAULT_SUB_SPACING = 26
local SOUND_FOOTER_H = 22
local GUIDE_LINE_H   = 17
local SECTION_GAP    = 8
local SECTION_TITLE_H = 18
local GUIDE_PAD_BOTTOM = 12
local RESET_BTN_SPACE  = 42

-- ============================================================
-- Layout-Hilfen
-- ============================================================

function GS.GetTotalWidth(parent)
    -- Volle Inhaltsbreite (linker + rechter Rand). Spalten-Gap wird in GetColumnWidths abgezogen.
    local pw = parent and parent:GetWidth()
    if not pw or pw <= 0 then pw = FallbackGamesPanelWidth() end
    local totalW = pw - (UI.BOX_PAD * 2)
    if totalW <= 0 then totalW = FallbackGamesPanelWidth() - (UI.BOX_PAD * 2) end
    return totalW
end

function GS.GetColumnWidths(totalW)
    local inner  = totalW - UI.BOX_PAD
    local leftW  = math.floor(inner * GS.COL_SPLIT)
    local rightW = inner - leftW
    return leftW, rightW
end

local function SoundFooterExtra(soundCfg)
    if not soundCfg or not soundCfg.footer or soundCfg.footer == "" then return 0 end
    if type(soundCfg.footer) == "string" and soundCfg.footer:find("\n", 1, true) then
        return SOUND_FOOTER_H + 16
    end
    return SOUND_FOOTER_H
end

function GS.ComputeSoundContentHeight(soundCfg)
    if not soundCfg or soundCfg.enabled == false then return 0 end
    local items   = soundCfg.items or {}
    local spacing = soundCfg.rowSpacing or DEFAULT_SUB_SPACING
    local yStart  = soundCfg.yOffset or 0
    local footer  = SoundFooterExtra(soundCfg)
    if soundCfg.single then
        return yStart + SOUND_MASTER_H + 8 + footer
    end
    if soundCfg.individual then
        return yStart + math.max(8, #items * spacing) + footer
    end
    return yStart + SOUND_MASTER_H + (#items * spacing) + 8 + footer
end

function GS.ComputeSoundBoxHeight(soundCfg)
    local contentH = GS.ComputeSoundContentHeight(soundCfg)
    if contentH <= 0 then return 0 end
    return BOX_CHROME_H + contentH
end

function GS.ComputeThemeContentHeight(themeCfg, settings)
    if not themeCfg or themeCfg.enabled == false then return 0 end
    local h = 0
    if themeCfg.dropdown then
        h = h + 52
    end
    if themeCfg.build then
        local extra = themeCfg.build(nil, 0, settings, 0, true) -- measure mode
        if type(extra) == "number" then
            h = h + extra
        end
    end
    return math.max(h, 8)
end

function GS.ComputeThemeBoxHeight(themeCfg, settings)
    if not themeCfg or themeCfg.enabled == false then return 0 end
    if themeCfg.height then return themeCfg.height end
    local boxH = BOX_CHROME_H + GS.ComputeThemeContentHeight(themeCfg, settings)
    if themeCfg.minHeight then
        boxH = math.max(boxH, themeCfg.minHeight)
    end
    return boxH
end

local function filterLines(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
        if line ~= nil and line ~= "" then
            out[#out + 1] = line
        end
    end
    return out
end

function GS.ComputeGuideContentHeight(guideCfg)
    if not guideCfg or guideCfg.enabled == false then return 0 end

    local h = 0
    if guideCfg.build then
        local extra = guideCfg.build(nil, 0, true)
        if type(extra) == "number" then h = h + extra end
    end
    if guideCfg.icons and #guideCfg.icons > 0 then
        local maxSize = 0
        for _, icon in ipairs(guideCfg.icons) do
            maxSize = math.max(maxSize, icon.size or 30)
        end
        h = h + maxSize + 10
    end

    local sections = guideCfg.sections or {}
    for si, sec in ipairs(sections) do
        if sec.title and sec.title ~= "" and si > 1 then
            h = h + SECTION_TITLE_H
        end
        local lineH = sec.lineSpacing or GUIDE_LINE_H
        for _, line in ipairs(filterLines(sec.lines)) do
            if line == " " then
                h = h + math.floor(lineH * 0.5)
            else
                h = h + lineH
            end
        end
        h = h + SECTION_GAP
    end

    return math.max(h, 8) + GUIDE_PAD_BOTTOM
end

function GS.ComputeGuideBoxHeight(guideCfg)
    if not guideCfg or guideCfg.enabled == false then return 0 end
    local boxH = BOX_CHROME_H + GS.ComputeGuideContentHeight(guideCfg)
    if guideCfg.minHeight then
        boxH = math.max(boxH, guideCfg.minHeight)
    end
    return math.max(boxH, GS.ROW2_H)
end

function GS.FinishPanel(parent, contentBottomY)
    if not parent then return end
    local bottomY = contentBottomY or UI.PAD
    local totalH  = bottomY + RESET_BTN_SPACE
    parent:SetHeight(math.max(totalH, 1))
    parent._gsContentHeight = totalH
end

-- GetLocaleTable liefert fehlende Keys als "[key]" – das ist kein echter Text.
function GS.L(locale, key, fallback)
    local s = locale and locale[key]
    if type(s) ~= "string" or s == "" then return fallback end
    if s:sub(1, 1) == "[" and s:sub(-1) == "]" then return fallback end
    return s
end

function GS.ResetLabel(_locale)
    return "Reset"
end

-- ============================================================
-- Reset / Refresh-Vertrag
-- Widgets werden einmal gebaut; Reset aktualisiert vorhandene Controls.
-- ============================================================

function GS.InitRefreshHost(parent)
    if not parent then return end
    if not parent._gsRefreshers then
        parent._gsRefreshers = {}
    end
end

function GS.RegisterRefresh(host, fn)
    if not host or type(fn) ~= "function" then return end
    local root = host
    local guard = 0
    while root and guard < 12 do
        if root._gsRefreshers then
            root._gsRefreshers[#root._gsRefreshers + 1] = fn
            return
        end
        root = root.GetParent and root:GetParent() or nil
        guard = guard + 1
    end
end

function GS.RefreshPanel(parent)
    if not parent or not parent._gsRefreshers then return end
    for i = 1, #parent._gsRefreshers do
        local fn = parent._gsRefreshers[i]
        if type(fn) == "function" then
            fn()
        end
    end
end

function GS.HandleReset(parent, config, settings)
    local S = settings or (config and config.settings)
    if S and S.Reset then S:Reset() end
    if config and config.onReset then config.onReset(parent) end
    GS.RefreshPanel(parent)
    if config and config.refresh then
        config.refresh(parent, S)
    end
end

function GS.TrackDropdown(host, dd, getCurrent, onChange)
    if not dd then return dd end
    GS.RegisterRefresh(host, function()
        if dd.RefreshDisplay then dd:RefreshDisplay() end
        if onChange and getCurrent then
            onChange(getCurrent())
        end
    end)
    return dd
end

function GS.TrackCheckbox(host, cb, settings, key, mode)
    if not cb or not settings or not key then return cb end
    GS.RegisterRefresh(host, function()
        local v = settings:Get(key)
        if mode == "notfalse" then
            cb:SetChecked(v ~= false)
        else
            cb:SetChecked(v and true or false)
        end
    end)
    return cb
end

-- ============================================================
-- Sound-Section
-- ============================================================

function GS.BuildSoundSection(content, settings, locale, soundCfg)
    if not content or not settings or not soundCfg or soundCfg.enabled == false then
        return
    end

    local masterKey   = soundCfg.masterKey or "soundEnabled"
    local masterLabel = soundCfg.masterLabel or (locale and locale.sound_enabled) or "Sound aktiviert"
    local spacing     = soundCfg.rowSpacing or DEFAULT_SUB_SPACING
    local yStart      = soundCfg.yOffset or 0

    if soundCfg.single then
        local cb = UI.CreateCheckbox(content, masterLabel, 0, yStart)
        cb:SetChecked(settings:Get(masterKey) and true or false)
        cb:SetScript("OnClick", function(self)
            settings:Set(masterKey, self:GetChecked())
        end)
        GS.TrackCheckbox(content, cb, settings, masterKey)
        if soundCfg.footer and soundCfg.footer ~= "" then
            local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hint:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
            hint:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
            hint:SetText(soundCfg.footer)
            hint:SetTextColor(0.80, 0.75, 0.60)
            hint:SetJustifyH("LEFT")
        end
        return
    end

    if soundCfg.individual then
        for i, item in ipairs(soundCfg.items or {}) do
            local cb = UI.CreateCheckbox(content, item.label, 0, yStart + (i - 1) * spacing)
            cb:SetChecked(settings:Get(item.key) ~= false)
            cb:SetScript("OnClick", function(self)
                settings:Set(item.key, self:GetChecked())
            end)
            GS.TrackCheckbox(content, cb, settings, item.key, "notfalse")
        end
        if soundCfg.footer and soundCfg.footer ~= "" then
            local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hint:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
            hint:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
            hint:SetText(soundCfg.footer)
            hint:SetTextColor(0.80, 0.75, 0.60)
            hint:SetJustifyH("LEFT")
        end
        return
    end

    local cbMain = UI.CreateCheckbox(content, masterLabel, 0, yStart)
    cbMain:SetChecked(settings:Get(masterKey) and true or false)

    local subCBs = {}
    for i, item in ipairs(soundCfg.items or {}) do
        local cb = UI.CreateCheckbox(content, item.label, 0, yStart + i * spacing)
        cb:SetChecked(settings:Get(item.key) and true or false)
        cb._key = item.key
        subCBs[#subCBs + 1] = cb
    end

    local function RefreshSubs(enabled)
        for _, cb in ipairs(subCBs) do
            cb:SetAlpha(enabled and 1 or 0.4)
            cb:SetEnabled(enabled)
        end
    end
    RefreshSubs(settings:Get(masterKey))

    GS.RegisterRefresh(content, function()
        cbMain:SetChecked(settings:Get(masterKey) and true or false)
        for _, cb in ipairs(subCBs) do
            cb:SetChecked(settings:Get(cb._key) and true or false)
        end
        RefreshSubs(settings:Get(masterKey))
    end)

    cbMain:SetScript("OnClick", function(self)
        local v = self:GetChecked()
        settings:Set(masterKey, v)
        if not v then
            for _, cb in ipairs(subCBs) do
                cb:SetChecked(false)
            end
        end
        RefreshSubs(v)
    end)

    for _, cb in ipairs(subCBs) do
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            settings:Set(self._key, checked)
            if checked then
                cbMain:SetChecked(true)
                settings:Set(masterKey, true)
                RefreshSubs(true)
            end
        end)
    end

    if soundCfg.footer and soundCfg.footer ~= "" then
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
        hint:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
        hint:SetText(soundCfg.footer)
        hint:SetTextColor(0.80, 0.75, 0.60)
        hint:SetJustifyH("LEFT")
    end
end

-- ============================================================
-- Visuals-Section (Screen-Flash, Emotes, …)
-- ============================================================

function GS.ComputeVisualsContentHeight(visualCfg)
    if not visualCfg or visualCfg.enabled == false then return 0 end
    local spacing = visualCfg.rowSpacing or DEFAULT_SUB_SPACING
    if visualCfg.build then
        local extra = visualCfg.build(nil, nil, true)
        if type(extra) == "number" then return extra end
    end
    return math.max(8, #(visualCfg.items or {}) * spacing)
end

function GS.ComputeVisualsBoxHeight(visualCfg)
    if not visualCfg or visualCfg.enabled == false then return 0 end
    if visualCfg.minHeight then return visualCfg.minHeight end
    return BOX_CHROME_H + GS.ComputeVisualsContentHeight(visualCfg)
end

function GS.BuildVisualsSection(content, settings, visualCfg)
    if not content or not settings or not visualCfg or visualCfg.enabled == false then
        return
    end
    if visualCfg.build then
        visualCfg.build(content, settings, false)
        return
    end
    local spacing = visualCfg.rowSpacing or DEFAULT_SUB_SPACING
    for i, item in ipairs(visualCfg.items or {}) do
        local cb = UI.CreateCheckbox(content, item.label, 0, (i - 1) * spacing)
        if UI.BindCheckboxToDB then
            UI.BindCheckboxToDB(cb, settings, item.key)
        else
            cb:SetChecked(settings:Get(item.key) ~= false)
            cb:SetScript("OnClick", function(self)
                settings:Set(item.key, self:GetChecked())
            end)
        end
        GS.TrackCheckbox(content, cb, settings, item.key, "notfalse")
    end
end

-- ============================================================
-- Theme-Section
-- ============================================================

function GS.BuildThemeSection(content, width, settings, themeCfg)
    if not content or not settings or not themeCfg or themeCfg.enabled == false then
        return 0
    end

    local y = 0

    if themeCfg.dropdown then
        local dd = themeCfg.dropdown
        local key = dd.key or "theme"
        local getCurrent = function() return settings:Get(key) end
        local onChange = function(selectedKey)
            settings:Set(key, selectedKey)
            if dd.onChange then dd.onChange(selectedKey) end
        end
        local ddFrame = UI.CreateSimpleDropdown(
            content, 0, y, width - UI.PAD * 2 - 24,
            dd.label or "",
            dd.options or {},
            getCurrent,
            onChange
        )
        GS.TrackDropdown(content, ddFrame, getCurrent, function(selectedKey)
            if dd.onChange then dd.onChange(selectedKey) end
        end)
        y = y + 52
    end

    if themeCfg.build then
        local extra = themeCfg.build(content, width, settings, y, false)
        if type(extra) == "number" then
            y = y + extra
        end
    end
    if themeCfg.refresh then
        GS.RegisterRefresh(content, function()
            themeCfg.refresh(settings)
        end)
    end

    if themeCfg.footer and themeCfg.footer ~= "" then
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
        hint:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
        hint:SetText(themeCfg.footer)
        hint:SetTextColor(0.80, 0.75, 0.60)
        hint:SetJustifyH("LEFT")
    end

    return y
end

--[[
    Kartenrückseiten-Vorschau (Blackjack / Solitaire / Higher or Lower).
    cfg = {
        label,                -- optional
        keys  = { "neutral", ... },
        files = { "card_back_neutral", ... },  -- oder pathPrefix + "card_back_" .. key
        pathPrefix,
        getSelected = function() return "neutral" end,
        onSelect    = function(key) end,       -- optional, Klick auf Karte
    }
    Rückgabe: extraH, refreshFn
]]
function GS.BuildCardBackPreview(content, yOff, measureOnly, cfg)
    if measureOnly then return 76 end
    if not content or not cfg then return 76 end

    local keys = cfg.keys or {}
    local borders = {}

    local previewLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLbl:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(yOff + 4))
    previewLbl:SetText(cfg.label or "Kartenrückseiten:")
    previewLbl:SetTextColor(0.75, 0.70, 0.55)

    local function Refresh()
        local current = cfg.getSelected and cfg.getSelected() or keys[1]
        for i, key in ipairs(keys) do
            local border = borders[i]
            if border then
                if key == current then
                    border:SetVertexColor(0.90, 0.75, 0.30, 1)
                else
                    border:SetVertexColor(0.30, 0.28, 0.20, 1)
                end
            end
        end
    end

    for i, key in ipairs(keys) do
        local x = (i - 1) * 50
        local file = (cfg.files and cfg.files[i]) or ("card_back_" .. key)

        local border = content:CreateTexture(nil, "BACKGROUND")
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetSize(44, 64)
        border:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(yOff + 20))
        borders[i] = border

        local tex = content:CreateTexture(nil, "ARTWORK")
        tex:SetSize(40, 60)
        tex:SetPoint("TOPLEFT", content, "TOPLEFT", x + 2, -(yOff + 22))
        tex:SetTexture((cfg.pathPrefix or "") .. file)

        if cfg.onSelect then
            local hit = CreateFrame("Button", nil, content)
            hit:SetSize(44, 64)
            hit:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(yOff + 20))
            hit:SetScript("OnClick", function()
                cfg.onSelect(key)
                Refresh()
            end)
        end
    end

    Refresh()
    GS.RegisterRefresh(content, Refresh)
    return 76, Refresh
end

-- ============================================================
-- Guide-Section (Sektionen + optionale Icons)
-- ============================================================

function GS.BuildGuideSection(content, guideCfg)
    if not content or not guideCfg or guideCfg.enabled == false then
        return
    end

    local y = 0

    if guideCfg.build then
        local extra = guideCfg.build(content, y, false)
        if type(extra) == "number" then y = y + extra end
    end

    if guideCfg.icons and #guideCfg.icons > 0 then
        local x = 0
        local maxSize = 0
        for _, icon in ipairs(guideCfg.icons) do
            local size = icon.size or 30
            maxSize = math.max(maxSize, size)
            local f = CreateFrame("Frame", nil, content)
            f:SetSize(size, size)
            f:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(f)
            tex:SetTexture(icon.texture)
            if icon.tint then
                tex:SetVertexColor(icon.tint[1], icon.tint[2], icon.tint[3])
            end
            x = x + size + (icon.gap or 6)
        end
        if guideCfg.iconHint then
            local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hint:SetPoint("TOPLEFT", content, "TOPLEFT", x + 4, -(y + 4))
            hint:SetText(guideCfg.iconHint)
            hint:SetTextColor(0.80, 0.75, 0.60)
        end
        y = y + maxSize + 10
    end

    local sections = guideCfg.sections or {}
    local prev = nil

    for si, sec in ipairs(sections) do
        if sec.title and sec.title ~= "" and si > 1 then
            local titleFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            if prev then
                titleFS:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SECTION_GAP)
            else
                titleFS:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            end
            titleFS:SetText("|cffffd700" .. sec.title .. "|r")
            titleFS:SetTextColor(0.90, 0.85, 0.70)
            prev = titleFS
        end

        local lineH = sec.lineSpacing or GUIDE_LINE_H
        for _, line in ipairs(sec.lines or {}) do
            if line ~= nil and line ~= "" then
                local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                if prev then
                    local gap = (line == " ") and math.floor(lineH * 0.5) or 2
                    fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
                else
                    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                end
                fs:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                fs:SetJustifyH("LEFT")

                if type(line) == "table" then
                    fs:SetText(line.text or "")
                    local c = line.color or { 0.85, 0.80, 0.65 }
                    fs:SetTextColor(c[1], c[2], c[3])
                else
                    fs:SetText(line)
                    fs:SetTextColor(0.85, 0.80, 0.65)
                end
                prev = fs
            end
        end
    end
end

-- ============================================================
-- Panel-Builder
-- ============================================================

--[[
    config:
      settings   – Settings-Modul (S:Get / S:Set / S:Reset)
      locale     – Locale-Tabelle L
      layout     – "standard" | "noTheme" | "noGuide"
      sound      – siehe BuildSoundSection
      theme      – siehe BuildThemeSection (enabled=false bei noTheme)
      guide      – siehe BuildGuideSection (enabled=false bei noGuide)
      extraBoxes – optionale Zeilen unter Guide: { { title, height, build(content,w,S) }, ... }
      showReset  – Reset-Button anzeigen (default true)
      onReset    – optional, nach S:Reset()
      refresh    – optional, nach dem zentralen Widget-Refresh
      rebuild    – ungenutzt (Reset baut nicht mehr neu)
]]
function GS.Build(parent, config)
    if not parent or not config or not config.settings then return end
    GS.InitRefreshHost(parent)

    local S = config.settings
    local L = config.locale or {}
    local layout = config.layout or "standard"

    local soundCfg = config.sound or { enabled = true, items = {} }
    local themeCfg = config.theme
    local guideCfg = config.guide

    local hasTheme = layout ~= "noTheme" and themeCfg and themeCfg.enabled ~= false
    local hasGuide = layout ~= "noGuide" and guideCfg and guideCfg.enabled ~= false

    if layout == "noTheme" and themeCfg then
        themeCfg.enabled = false
    end
    if layout == "noGuide" and guideCfg then
        guideCfg.enabled = false
    end

    local totalW = GS.GetTotalWidth(parent)
    local leftW, rightW = GS.GetColumnWidths(totalW)
    local startY = UI.PAD

    local soundBoxH = GS.ComputeSoundBoxHeight(soundCfg)
    local themeBoxH = hasTheme and GS.ComputeThemeBoxHeight(themeCfg, S) or 0
    local row1H
    if hasTheme then
        row1H = math.max(GS.ROW1_H_MIN, soundBoxH, themeBoxH)
    else
        row1H = math.max(soundBoxH, 72)
    end

    local soundTitle = soundCfg.title or GS.L(L, "box_sounds", "Sound")
    local themeTitle = (themeCfg and themeCfg.title) or GS.L(L, "box_theme", "Theme")
    local guideTitle = (guideCfg and guideCfg.title) or GS.L(L, "box_guide", "Anleitung")

    -- ── Reihe 1: Sound ───────────────────────────────────────
    local soundX = UI.BOX_PAD
    local soundW = hasTheme and leftW or totalW
    local _, cSound = UI.CreateBox(parent, soundTitle, soundX, startY, soundW, row1H)
    GS.BuildSoundSection(cSound, S, L, soundCfg)

    -- ── Reihe 1: Theme (rechts) ──────────────────────────────
    if hasTheme then
        local themeX = UI.BOX_PAD + leftW + UI.BOX_PAD
        local _, cTheme = UI.CreateBox(parent, themeTitle, themeX, startY, rightW, row1H)
        GS.BuildThemeSection(cTheme, rightW - UI.PAD * 2, S, themeCfg)
    end

    -- ── Reihe 2: Guide ───────────────────────────────────────
    local nextY = startY + row1H + UI.BOX_PAD
    if hasGuide then
        local guideH = math.max(GS.ComputeGuideBoxHeight(guideCfg), GS.ROW2_H)
        local _, cGuide = UI.CreateBox(parent, guideTitle, UI.BOX_PAD, nextY, totalW, guideH)
        GS.BuildGuideSection(cGuide, guideCfg)
        nextY = nextY + guideH + UI.BOX_PAD
    end

    -- ── Extra-Boxen (z. B. GGH Punkte-Info) ──────────────────
    for _, boxCfg in ipairs(config.extraBoxes or {}) do
        local boxH = boxCfg.height or 100
        local _, cExtra = UI.CreateBox(parent, boxCfg.title or "", UI.BOX_PAD, nextY, totalW, boxH)
        if boxCfg.build then
            boxCfg.build(cExtra, totalW - UI.PAD * 2, S)
        end
        if boxCfg.refresh then
            GS.RegisterRefresh(parent, function()
                boxCfg.refresh(cExtra, S)
            end)
        end
        nextY = nextY + boxH + UI.BOX_PAD
    end

    -- ── Reset ────────────────────────────────────────────────
    if config.showReset == false then
        GS.FinishPanel(parent, nextY)
        return
    end
    local resetLabel = GS.ResetLabel(L)
    UI.CreateResetButton(parent, resetLabel, function()
        GS.HandleReset(parent, config, S)
    end)
    GS.FinishPanel(parent, nextY)
end

-- Kurz-Helper: Guide-Zeilen aus Locale-Keys
function GS.LinesFromKeys(locale, keys)
    local lines = {}
    for _, key in ipairs(keys or {}) do
        if locale[key] then
            lines[#lines + 1] = locale[key]
        end
    end
    return lines
end

-- Kurz-Helper: eine Guide-Sektion aus Keys
function GS.GuideSection(title, locale, keys, lineSpacing)
    return {
        title = title,
        lines = GS.LinesFromKeys(locale, keys),
        lineSpacing = lineSpacing,
    }
end

-- ============================================================
-- Layout: 2×2-Grid (TavernCards)
-- ============================================================

--[[
    config.boxes = { tl, tr, bl, br }
    Jede Box: { title, build(content, innerW, settings) }
]]
function GS.BuildGrid2x2(parent, config)
    local S = config.settings
    local L = config.locale or {}
    if not parent or not S or not config.boxes then return end
    GS.InitRefreshHost(parent)

    local totalW   = GS.GetTotalWidth(parent)
    local leftW, rightW = GS.GetColumnWidths(totalW)
    local startY   = UI.PAD
    local row1H    = config.row1Height or 180
    local row2H    = config.row2Height or 100
    local gap      = UI.BOX_PAD
    local boxes    = config.boxes

    local function makeBox(slot, x, y, w, h)
        local boxCfg = boxes[slot]
        if not boxCfg then return end
        local _, content = UI.CreateBox(parent, boxCfg.title or "", x, y, w, h)
        if boxCfg.build then
            boxCfg.build(content, w - UI.PAD * 2, S)
        end
    end

    makeBox("tl", UI.BOX_PAD, startY, leftW, row1H)
    makeBox("tr", UI.BOX_PAD + leftW + gap, startY, rightW, row1H)
    makeBox("bl", UI.BOX_PAD, startY + row1H + gap, leftW, row2H)
    makeBox("br", UI.BOX_PAD + leftW + gap, startY + row1H + gap, rightW, row2H)

    local nextY = startY + row1H + gap + row2H + UI.BOX_PAD
    if config.showReset == false then
        GS.FinishPanel(parent, nextY)
        return
    end
    UI.CreateResetButton(parent, GS.ResetLabel(L), function()
        GS.HandleReset(parent, config, S)
    end)
    GS.FinishPanel(parent, nextY)
end

-- ============================================================
-- Layout: Split-Row (Minesweeper)
-- ============================================================

function GS.BuildSplitRow(parent, config)
    local S = config.settings
    local L = config.locale or {}
    if not parent or not S then return end
    GS.InitRefreshHost(parent)

    local totalW = GS.GetTotalWidth(parent)
    local leftW, rightW = GS.GetColumnWidths(totalW)
    local startY = UI.PAD
    local rowH   = config.rowHeight or 290

    if config.left then
        local _, cLeft = UI.CreateBox(parent, config.left.title or "",
            UI.BOX_PAD, startY, leftW, rowH)
        if config.left.build then
            config.left.build(cLeft, leftW - UI.PAD * 2, S)
        end
    end

    if config.right then
        local _, cRight = UI.CreateBox(parent, config.right.title or "",
            UI.BOX_PAD + leftW + UI.BOX_PAD, startY, rightW, rowH)
        if config.right.build then
            config.right.build(cRight, rightW - UI.PAD * 2, S)
        end
    end

    local nextY = startY + rowH + UI.BOX_PAD
    if config.showReset == false then
        GS.FinishPanel(parent, nextY)
        return
    end
    UI.CreateResetButton(parent, GS.ResetLabel(L), function()
        GS.HandleReset(parent, config, S)
    end)
    GS.FinishPanel(parent, nextY)
end

-- ============================================================
-- Layout: Sound | Visuals + optional Theme + Guide (Tower-Defense)
-- ============================================================

--[[
    config:
      sound, visuals  – Reihe 1 (50/50)
      theme           – optionale volle Breite unter Reihe 1
      guide           – wie GS.Build
      extraBoxes      – wie GS.Build
]]
function GS.BuildSoundVisualGuide(parent, config)
    local S = config.settings
    local L = config.locale or {}
    if not parent or not S then return end
    GS.InitRefreshHost(parent)

    local soundCfg  = config.sound
    local visualCfg = config.visuals
    local guideCfg  = config.guide
    local themeCfg  = config.theme

    local totalW = GS.GetTotalWidth(parent)
    local leftW, rightW = GS.GetColumnWidths(totalW)
    local startY = UI.PAD

    local soundH  = GS.ComputeSoundBoxHeight(soundCfg)
    local visualH = GS.ComputeVisualsBoxHeight(visualCfg)
    local row1H   = config.row1Height or math.max(GS.ROW1_H_MIN, soundH, visualH)

    local soundTitle  = (soundCfg and soundCfg.title) or GS.L(L, "box_sounds", "Sound")
    local visualTitle = (visualCfg and visualCfg.title)
        or GS.L(L, "box_visuals", nil)
        or GS.L(L, "box_visual", "Visuelles")

    if soundCfg then
        local _, cSound = UI.CreateBox(parent, soundTitle, UI.BOX_PAD, startY, leftW, row1H)
        GS.BuildSoundSection(cSound, S, L, soundCfg)
    end

    if visualCfg then
        local _, cVisual = UI.CreateBox(parent, visualTitle,
            UI.BOX_PAD + leftW + UI.BOX_PAD, startY, rightW, row1H)
        GS.BuildVisualsSection(cVisual, S, visualCfg)
    end

    local nextY = startY + row1H + UI.BOX_PAD

    if themeCfg and themeCfg.enabled ~= false then
        local themeH = themeCfg.height or GS.ComputeThemeBoxHeight(themeCfg, S)
        local themeTitle = themeCfg.title or GS.L(L, "box_theme", "Theme")
        local _, cTheme = UI.CreateBox(parent, themeTitle, UI.BOX_PAD, nextY, totalW, themeH)
        GS.BuildThemeSection(cTheme, totalW - UI.PAD * 2, S, themeCfg)
        nextY = nextY + themeH + UI.BOX_PAD
    end

    if guideCfg and guideCfg.enabled ~= false then
        local guideTitle = guideCfg.title or GS.L(L, "box_guide", "Anleitung")
        local guideH = math.max(GS.ComputeGuideBoxHeight(guideCfg), GS.ROW2_H)
        local _, cGuide = UI.CreateBox(parent, guideTitle, UI.BOX_PAD, nextY, totalW, guideH)
        GS.BuildGuideSection(cGuide, guideCfg)
        nextY = nextY + guideH + UI.BOX_PAD
    end

    for _, boxCfg in ipairs(config.extraBoxes or {}) do
        local boxH = boxCfg.height or 100
        local _, cExtra = UI.CreateBox(parent, boxCfg.title or "", UI.BOX_PAD, nextY, totalW, boxH)
        if boxCfg.build then
            boxCfg.build(cExtra, totalW - UI.PAD * 2, S)
        end
        if boxCfg.refresh then
            GS.RegisterRefresh(parent, function()
                boxCfg.refresh(cExtra, S)
            end)
        end
        nextY = nextY + boxH + UI.BOX_PAD
    end

    if config.showReset == false then
        GS.FinishPanel(parent, nextY)
        return
    end
    UI.CreateResetButton(parent, GS.ResetLabel(L), function()
        GS.HandleReset(parent, config, S)
    end)
    GS.FinishPanel(parent, nextY)
end

-- ============================================================
-- SettingsPanel Registry (zentral, früher in TicTacToe_SettingsPanel)
-- ============================================================

-- Gutter rechts für MinimalScrollBar — identisch mit SidebarFrameFactory (-28)
local SETTINGS_SCROLL_GUTTER = 28

local function SetSettingsScrollbarShown(sf, shown)
    if not sf or not sf.ScrollBar then return end
    local sb = sf.ScrollBar
    if shown then
        sb:Show()
        if sb.Thumb   then sb.Thumb:Show()   end
        if sb.Track   then sb.Track:Show()   end
        if sb.TrackBG then sb.TrackBG:Show() end
    else
        sb:Hide()
        if sb.Thumb   then sb.Thumb:Hide()   end
        if sb.Track   then sb.Track:Hide()   end
        if sb.TrackBG then sb.TrackBG:Hide() end
    end
end

local function SyncSettingsScrollbar(sf, panel)
    if UI and UI.UpdateScrollbar then
        UI.UpdateScrollbar(sf, panel)
        return
    end
    if not sf or not sf.ScrollBar then return end
    local contentH = panel and panel:GetHeight() or 1
    local viewH    = sf:GetHeight()
    sf.ScrollBar.visibleExtentPercentage = viewH / math.max(contentH, 1)
    SetSettingsScrollbarShown(sf, contentH > viewH)
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builtPanels = ArcadiaNexus.SettingsPanel._builtPanels or {}
ArcadiaNexus.SettingsPanel._builders    = ArcadiaNexus.SettingsPanel._builders    or {}

function ArcadiaNexus.SettingsPanel.RegisterBuilder(id, buildFn)
    ArcadiaNexus.SettingsPanel._builders[id] = buildFn
end

function ArcadiaNexus.SettingsPanel.OnCategoryChange(categoryID)
    local settingsFrame = _G.ArcadiaNexusUI
        and _G.ArcadiaNexusUI.GetSettingsPanel
        and _G.ArcadiaNexusUI.GetSettingsPanel()
    if not settingsFrame then return end

    local GR = ArcadiaNexus.GameRegistry
    if not GR or not GR.Exists(categoryID) then return end

    local panels   = ArcadiaNexus.SettingsPanel._builtPanels
    local builders = ArcadiaNexus.SettingsPanel._builders

    -- Scrollbar sitzt am settingsFrame (nicht am ScrollFrame) — beim Hide
    -- des ScrollFrames explizit mit ausblenden, sonst bleibt Chrome sichtbar.
    for _, p in pairs(panels) do
        p:Hide()
        SetSettingsScrollbarShown(p, false)
    end

    local buildFn = builders[categoryID]
    if buildFn then
        if not panels[categoryID] then
            local scroll = CreateFrame("ScrollFrame",
                "ArcadiaNexus_SettingsScroll_" .. categoryID, settingsFrame)
            scroll:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 0, 0)
            scroll:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT",
                -SETTINGS_SCROLL_GUTTER, 0)

            local panel = CreateFrame("Frame",
                "ArcadiaNexus_Settings_" .. categoryID, scroll)
            panel:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
            local frameW = settingsFrame:GetWidth()
            if not frameW or frameW <= 0 then frameW = FallbackGamesPanelWidth() end
            panel:SetWidth(frameW - SETTINGS_SCROLL_GUTTER)

            scroll:SetScrollChild(panel)
            if CreateNexusScrollbar then
                CreateNexusScrollbar(scroll, settingsFrame)
            end
            -- Sofort verstecken: CreateNexusScrollbar zeigt den Balken sonst
            -- schon während des Builds (Aufblitzen bei kurzen Panels).
            SetSettingsScrollbarShown(scroll, false)

            buildFn(panel)

            local contentH = panel._gsContentHeight or panel:GetHeight() or 400
            panel:SetHeight(contentH)

            panels[categoryID] = scroll
        end
        panels[categoryID]:Show()
        local sf = panels[categoryID]
        local panel = sf:GetScrollChild()
        if sf.SetVerticalScroll then sf:SetVerticalScroll(0) end
        if sf.ScrollBar then sf.ScrollBar:SetScrollPercentage(0) end
        -- Sofort anhand der bekannten Content-Höhe entscheiden, After(0)
        -- in UpdateScrollbar korrigiert danach die exakte Viewport-Höhe.
        local contentH = (panel and (panel._gsContentHeight or panel:GetHeight())) or 1
        local viewH    = sf:GetHeight() or 0
        SetSettingsScrollbarShown(sf, viewH > 0 and contentH > viewH)
        SyncSettingsScrollbar(sf, panel)
    end
end
