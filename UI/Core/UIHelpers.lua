--[[
    ArcadiaNexus – UI/UIHelpers.lua
    Zentralisierte UI-Hilfsfunktionen
    Version: 1.0.0

    Stellt bereit:
      ArcadiaNexus.UI.CreateBox(parent, title, x, y, w, h)
      ArcadiaNexus.UI.CreateHudStatBox(parent, config)
      ArcadiaNexus.UI.CreateGoldGridFrame(parent, anchor, config)
      ArcadiaNexus.UI.CreateCheckbox(parent, label, x, y)
      ArcadiaNexus.UI.SetCheckboxValue(checkbox, value)
      ArcadiaNexus.UI.GetCheckboxValue(checkbox)
      ArcadiaNexus.UI.BindCheckboxToDB(checkbox, settings, key)
      ArcadiaNexus.UI.CreateSimpleDropdown(parent, x, y, w, label, options, getCurrent, onChange)
      – Modern: DropdownButton / WowStyle1DropdownTemplate

    Alle SettingsPanels sollen diese Funktionen nutzen statt
    lokale Duplikate zu pflegen.
]]

ArcadiaNexus    = ArcadiaNexus or {}
ArcadiaNexus.UI = ArcadiaNexus.UI or {}

local UI = ArcadiaNexus.UI

-- ============================================================
-- NAMED-FRAME REUSE (WoW zerstört Frames nicht)
-- ============================================================
-- CreateFrame mit existierendem Globalnamen schlägt fehl bzw. liefert
-- den alten Frame nicht zuverlässig. Rebuilds müssen daher vorhandene
-- benannte Frames wiederverwenden statt sie zu orphanen und neu zu bauen.
function UI.AcquireNamedFrame(frameType, name, parent, template)
    if name then
        local existing = _G[name]
        if existing then
            existing:SetParent(parent)
            existing:ClearAllPoints()
            existing:Show()
            return existing, true
        end
    end
    return CreateFrame(frameType, name, parent, template), false
end

-- ============================================================
-- STYLE CONSTANTS
-- ============================================================

UI.PAD     = 10
UI.BOX_PAD = 8

local DEFAULT_BOX_BG_R,  DEFAULT_BOX_BG_G,  DEFAULT_BOX_BG_B,  DEFAULT_BOX_BG_A  = 0.05, 0.05, 0.08, 0.85
local DEFAULT_BOX_BR_R,  DEFAULT_BOX_BR_G,  DEFAULT_BOX_BR_B,  DEFAULT_BOX_BR_A  = 0.90, 0.75, 0.30, 1
local DEFAULT_LABEL_R,   DEFAULT_LABEL_G,   DEFAULT_LABEL_B                       = 0.90, 0.85, 0.70
local DEFAULT_CB_SIZE = 22

-- ============================================================
-- CreateBox
-- ============================================================
-- Erstellt eine Box im ArcadiaNexus-Stil mit Titel, Divider und Content-Frame.
-- Rückgabe: box, contentFrame
--
-- Identisch mit dem bisherigen lokalen CreateBox-Pattern in allen
-- SettingsPanels. Verwendet BackdropTemplate + WoW-Tooltip-Style.

-- Wenn w == 0: Stretch-Modus – Box spannt von x bis -x (TOPLEFT + TOPRIGHT).
-- inset: optionaler rechter Einzug (Standard = x); nur im Stretch-Modus genutzt.
function UI.CreateBox(parent, title, x, y, w, h, inset)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if w == 0 then
        local ri = inset or x
        box:SetPoint("TOPLEFT",  parent, "TOPLEFT",  x,  -y)
        box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ri, -y)
        box:SetHeight(h)
    else
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        box:SetSize(w, h)
    end
    box:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    box:SetBackdropColor(DEFAULT_BOX_BG_R, DEFAULT_BOX_BG_G, DEFAULT_BOX_BG_B, DEFAULT_BOX_BG_A)
    box:SetBackdropBorderColor(DEFAULT_BOX_BR_R, DEFAULT_BOX_BR_G, DEFAULT_BOX_BR_B, DEFAULT_BOX_BR_A)

    if title and title ~= "" then
        local titleFS = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT", box, "TOPLEFT", UI.PAD, -7)
        titleFS:SetText("|cffffd700" .. title .. "|r")

        local div = box:CreateTexture(nil, "ARTWORK")
        div:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Divider")
        div:SetPoint("TOPLEFT",  box, "TOPLEFT",  4, -22)
        div:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -22)
        div:SetHeight(8)
        div:SetHorizTile(true)
    end

    local contentTopOff = (title and title ~= "") and -32 or -UI.PAD
    local content = CreateFrame("Frame", nil, box)
    content:SetPoint("TOPLEFT",     box, "TOPLEFT",     UI.PAD, contentTopOff)
    content:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -UI.PAD, UI.PAD)

    return box, content
end

-- ============================================================
-- CenterBoxTitle
-- ============================================================
-- Zentriert den Titel einer Box horizontal.
-- Aufruf nach UI.CreateBox wenn zentrierter Titel gewünscht.

function UI.CenterBoxTitle(box)
    if not box then return end
    for _, region in ipairs({box:GetRegions()}) do
        if region:GetObjectType() == "FontString" then
            region:ClearAllPoints()
            region:SetPoint("TOP", box, "TOP", 0, -7)
            region:SetJustifyH("CENTER")
            break
        end
    end
end

-- ============================================================
-- CreateCheckbox
-- ============================================================
-- Erstellt eine Checkbox im ArcadiaNexus-Stil.
-- Rückgabe: checkButton
--
-- Verwendet UICheckButtonTemplate (custom UI, NICHT Blizzard Settings API).
-- Standard-Größe: 22×22 (einheitlich über alle Panels).

function UI.CreateCheckbox(parent, label, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(DEFAULT_CB_SIZE, DEFAULT_CB_SIZE)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)

    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(label)
    lbl:SetTextColor(DEFAULT_LABEL_R, DEFAULT_LABEL_G, DEFAULT_LABEL_B)
    cb._label = lbl

    return cb
end

-- Checkbox in der Controls-Leiste: Label rechts neben der Box.
-- Rückgabe: holder, checkbox
function UI.CreateBarCheckbox(parent, label, config)
    local cfg  = config or {}
    local size = cfg.size or 20
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(cfg.w or 120, cfg.h or 36)
    local chk = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
    chk:SetSize(size, size)
    chk:SetPoint("LEFT", holder, "LEFT", 0, cfg.chkY or -4)
    local lbl = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", chk, "RIGHT", 4, 0)
    lbl:SetText(label or "")
    chk._label = lbl
    holder.checkbox = chk
    return holder, chk
end

-- ============================================================
-- Checkbox State Helpers
-- ============================================================

function UI.SetCheckboxValue(checkbox, value)
    if checkbox then
        checkbox:SetChecked(value and true or false)
    end
end

function UI.GetCheckboxValue(checkbox)
    if checkbox then
        return checkbox:GetChecked() and true or false
    end
    return false
end

-- ============================================================
-- BindCheckboxToDB
-- ============================================================
-- Bindet eine Checkbox an ein Settings-Objekt (S:Get / S:Set Pattern).
-- Setzt den initialen Wert und registriert OnClick automatisch.
--
-- settings: Das Settings-Objekt des Spiels (z.B. ArcadiaNexus.SNK_Settings)
-- key:      Der Settings-Key (z.B. "soundEnabled")
--
-- Optional: onChanged(value) — zusätzlicher Callback nach S:Set

function UI.BindCheckboxToDB(checkbox, settings, key, onChanged)
    if not checkbox or not settings or not key then return end

    checkbox:SetChecked(settings:Get(key) and true or false)

    checkbox:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        settings:Set(key, v)
        if onChanged then
            onChanged(v)
        end
    end)
end

-- ============================================================
-- BindCheckboxToDBRaw
-- ============================================================
-- Alternative für direkte DB-Tabellen (ohne Settings-Objekt).
-- dbTable: z.B. ArcadiaNexusDB.settings
-- key:     z.B. "soundEnabled"
-- default: Fallback-Wert falls nil

function UI.BindCheckboxToDBRaw(checkbox, dbTable, key, default)
    if not checkbox or not dbTable or not key then return end

    if dbTable[key] == nil then
        dbTable[key] = default and true or false
    end

    checkbox:SetChecked(dbTable[key] and true or false)

    checkbox:SetScript("OnClick", function(self)
        dbTable[key] = self:GetChecked() and true or false
    end)
end

-- ============================================================
-- CreateSimpleDropdown (Modern — DropdownButton / WowStyle1DropdownTemplate)
-- ============================================================
-- Erstellt ein Dropdown im modernen Midnight-Stil.
-- Externe API bleibt identisch zu allen Aufrufstellen.
--
-- options: { { key = "xyz", label = "Anzeige" }, ... }
-- getCurrent: function() return currentKey end
-- onChange:   function(selectedKey) ... end
--
-- Rückgabe: DropdownButton frame
--   :SetEnabled(bool)  — aktiviert/deaktiviert das Dropdown
--   :SetText(str)      — überschreibt den angezeigten Text

function UI.CreateSimpleDropdown(parent, x, y, w, label, options, getCurrent, onChange)
    if label and label ~= "" then
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        lbl:SetText(label)
        lbl:SetTextColor(DEFAULT_LABEL_R, DEFAULT_LABEL_G, DEFAULT_LABEL_B)
    end

    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    local labelGap = (label and label ~= "") and 14 or 0
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + labelGap))
    dd:SetWidth(w)

    dd:SetupMenu(function(owner, root)
        for _, opt in ipairs(options) do
            local optKey = opt.key
            local optLabel = opt.label
            root:CreateRadio(optLabel,
                function() return getCurrent() == optKey end,
                function()
                    onChange(optKey)
                    dd:SetText(optLabel)
                end
            )
        end
    end)

    -- Initialen Text setzen
    local function RefreshDisplay()
        local cur = getCurrent()
        for _, opt in ipairs(options) do
            if opt.key == cur then
                dd:SetText(opt.label)
                return
            end
        end
        dd:SetText("")
    end
    RefreshDisplay()
    dd.RefreshDisplay = RefreshDisplay

    return dd
end

-- ============================================================
-- CreateGuideText
-- ============================================================
-- Erstellt eine Liste von Anleitung-Zeilen im Content-Frame.
-- lines: { "Zeile 1", "Zeile 2", ... }
-- Rückgabe: letztes FontString (für Anker-Referenz)

function UI.CreateGuideText(contentFrame, lines)
    local prev = nil
    for _, line in ipairs(lines) do
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if prev then
            fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -3)
        else
            fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
        end
        fs:SetText(line)
        fs:SetTextColor(0.85, 0.80, 0.65)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        prev = fs
    end
    return prev
end

-- ============================================================
-- CreateResetButton
-- ============================================================
-- Standard-Reset unten rechts. Beschriftung fest "Reset" (DE/EN).

function UI.CreateResetButton(parent, _label, onReset)
    local btn = UI.CreateArcadiaButton(parent, "Reset", 140, 30)
    if btn.SetLabel then btn:SetLabel("Reset") end
    btn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -UI.BOX_PAD, UI.BOX_PAD)
    btn:SetScript("OnClick", function()
        if onReset then onReset() end
    end)
    return btn
end

-- ============================================================
-- CreateArcadiaButton
-- ============================================================
-- Erstellt einen Button im Blizzard-nativen Stil.
-- Zwei Texturen: statischer Rahmen + bewegliche Innenfläche.
--
-- Struktur:
--   btn (Button)
--    ├─ btn.frame   (Texture, BACKGROUND, statisch)
--    └─ btn.content (Frame, bewegt sich beim Drücken)
--         ├─ btn.bg   (Texture, BACKGROUND – Oberfläche)
--         ├─ btn.glow (Texture, ARTWORK    – Hover ADD)
--         └─ btn.text (FontString, OVERLAY)
--
-- Parameter:
--   parent  – Parent-Frame
--   label   – Beschriftung (optional)
--   width   – Breite (default: 140)
--   height  – Höhe (default: 30)
--
-- Rückgabe: btn
--   btn:SetLabel(text)  – Text dynamisch ändern
--   btn:Enable()        – aktivieren
--   btn:Disable()       – deaktivieren

local ARCADIA_BTN_SURFACE = "Interface/AddOns/ArcadiaNexus/UI/Assets/Buttons/button01"
local ARCADIA_BTN_FRAME   = "Interface/AddOns/ArcadiaNexus/UI/Assets/Buttons/button02"
local ARCADIA_BTN_W       = 140
local ARCADIA_BTN_H       = 30
local ARCADIA_BTN_FONT    = "Fonts\\FRIZQT__.TTF"

function UI.CreateArcadiaButton(parent, label, width, height)

    width  = width  or ARCADIA_BTN_W
    height = height or ARCADIA_BTN_H

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    -- Rahmen (statisch, bewegt sich nie)
    btn.frame = btn:CreateTexture(nil, "BACKGROUND")
    btn.frame:SetAllPoints()
    btn.frame:SetTexture(ARCADIA_BTN_FRAME)

    -- Content-Frame (bewegt sich beim Drücken)
    btn.content = CreateFrame("Frame", nil, btn)
    btn.content:SetSize(width, height)
    btn.content:SetPoint("CENTER")

    -- Button-Oberfläche
    btn.bg = btn.content:CreateTexture(nil, "BORDER")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(ARCADIA_BTN_SURFACE)

    -- Hover Glow (ADD blend auf Oberfläche)
    btn.glow = btn.content:CreateTexture(nil, "ARTWORK")
    btn.glow:SetAllPoints()
    btn.glow:SetTexture(ARCADIA_BTN_SURFACE)
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetAlpha(0)
    btn.glow:SetVertexColor(1, 0.9, 0.4)

    -- Text
    btn.text = btn.content:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont(ARCADIA_BTN_FONT, 13, "OUTLINE")
    btn.text:SetPoint("CENTER")
    btn.text:SetJustifyH("CENTER")
    btn.text:SetJustifyV("MIDDLE")
    btn.text:SetTextColor(1, 0.82, 0)
    btn.text:SetShadowOffset(1, -1)
    btn.text:SetShadowColor(0, 0, 0, 1)
    btn.text:SetText(label or "")

    -- Hover
    btn:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then return end
        self.glow:SetAlpha(0.35)
        self.text:SetTextColor(1, 0.9, 0.4)
    end)

    btn:SetScript("OnLeave", function(self)
        self.glow:SetAlpha(0)
        self.text:SetTextColor(1, 0.82, 0)
    end)

    -- Press: nur content bewegt sich, Rahmen bleibt statisch
    -- Press
btn:SetScript("OnMouseDown", function(self)
    if not self:IsEnabled() then return end

    self.content:SetPoint("CENTER", 0, -1)

    -- Button wird dunkler
    self.bg:SetVertexColor(0.9, 0.9, 0.9)

    -- Glow verschwindet
    self.glow:SetAlpha(0)

    -- Text minimal tiefer
    self.text:SetShadowOffset(0, -2)
end)

btn:SetScript("OnMouseUp", function(self)

    self.content:SetPoint("CENTER", 0, 0)

    -- Farbe zurück
    self.bg:SetVertexColor(1, 1, 1)

    -- Shadow zurück
    self.text:SetShadowOffset(1, -1)
end)

    -- Disabled
    btn:SetScript("OnDisable", function(self)
        self.bg:SetVertexColor(0.4, 0.4, 0.4)
        self.text:SetTextColor(0.6, 0.6, 0.6)
        self.glow:SetAlpha(0)
    end)

    btn:SetScript("OnEnable", function(self)
        self.bg:SetVertexColor(1, 1, 1)
        self.text:SetTextColor(1, 0.82, 0)
    end)

    -- Helper API
    function btn:SetLabel(text)
        self.text:SetText(text)
    end

    return btn
end

-- Alias: einheitliche API (intern → CreateArcadiaButton, kein UIPanelButtonTemplate)
UI.CreateButton = UI.CreateArcadiaButton

-- ============================================================
-- ============================================================
-- CreateSidebarSearchBox
-- ============================================================
-- Erstellt eine Suchleiste für Sidebar-Panels.
-- Nutzt Blizzard's SearchBoxTemplate (EditBox + eingebauter x-Button).
--
-- Fixes:
--   - Background-Frame für Lesbarkeit
--   - Clear-Button triggert Filter-Reset (userInput-unabhängig)
--   - Scrollbar-TOPRIGHT um SearchBar-Höhe versetzt
--   - Auto-Clear beim Verstecken des Panels (Tab-Wechsel)
--
-- Parameter:
--   parent    -- Kategorie-Panel (cp)
--   sf        -- ScrollFrame des Panels
--   onChanged -- function(query)
--
-- Rückgabe: EditBox (SearchBoxTemplate)

local SB_INSET     = 10   -- je Seite 12px mehr = ~24px schmaler gesamt, optisch zentriert
local SB_TOP_Y     = -7
local SB_H         = 22
local SB_SHIFT     = SB_H + 6    -- 28px: SearchBox-Höhe + Gap
local DEBOUNCE_SEC = 0.05

function UI.CreateSidebarSearchBox(parent, sf, onChanged)
    if parent._sidebarSearchBox then
        return parent._sidebarSearchBox
    end

    -- Background-Frame
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetPoint("TOPLEFT",  parent, "TOPLEFT",   SB_INSET,  SB_TOP_Y)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SB_INSET,  SB_TOP_Y)
    bg:SetHeight(SB_H)
    bg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bg:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    bg:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

    -- SearchBox (Blizzard SearchBoxTemplate) – Kind des bg-Frames
    local sb = CreateFrame("EditBox", nil, bg, "SearchBoxTemplate")
    sb:SetPoint("TOPLEFT",     bg, "TOPLEFT",     4,  0)
    sb:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -4, 0)
    sb:SetAutoFocus(false)

    -- ScrollFrame nach unten verschieben (Platz fuer SearchBox + Gap)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", SB_INSET, -(math.abs(SB_TOP_Y) + SB_SHIFT))

    -- Scrollbar-TOPRIGHT nach unten verschieben
    -- CreateNexusScrollbar setzt TOPRIGHT(parent, -10, -18)
    -- Mit SearchBar muss der Start um SB_SHIFT nach unten
    C_Timer.After(0, function()
        if sf.ScrollBar then
            sf.ScrollBar:ClearAllPoints()
            sf.ScrollBar:SetPoint("TOPRIGHT",    parent, "TOPRIGHT",    -10, -(18 + SB_SHIFT))
            sf.ScrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  -6,  18)
        end
    end)

    -- Filter-Logik
    local timer = nil

    local function FireFilter(query)
        timer = nil
        ArcadiaNexus._filterState.query = query or ""
        if onChanged then onChanged(query or "") end
    end

    local function ClearFilter()
        if timer then timer:Cancel(); timer = nil end
        sb:SetText("")
        FireFilter("")
    end

    -- OnTextChanged: HookScript statt SetScript
    -- SetScript würde den internen SearchBoxTemplate-Handler überschreiben
    -- der den "Suchen"-Instructions-FontString ein/ausblendet
    sb:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        if timer then timer:Cancel(); timer = nil end
        if text == "" then
            FireFilter("")
        else
            timer = C_Timer.NewTimer(DEBOUNCE_SEC, function() FireFilter(text) end)
        end
    end)

    sb:HookScript("OnEscapePressed", function(self)
        self:ClearFocus()
        ClearFilter()
    end)

    -- Auto-Clear bei Tab-Wechsel (Panel OnHide)
    parent:HookScript("OnHide", function()
        if timer then timer:Cancel(); timer = nil end
        sb:SetText("")
        ArcadiaNexus._filterState.query = ""
        -- kein Relayout noetig – Panel ist gerade versteckt
    end)

    parent._sidebarSearchBox = sb
    return sb
end

-- ============================================================
-- CreateSlider  (OptionsSliderTemplate)
-- ============================================================
-- Erstellt einen nativen WoW-Slider.
-- Live-Skalierung: onValueChanged feuert bei jeder Wertänderung.
--
-- Parameter:
--   parent, labelText, minValue, maxValue, step, defaultValue
--   onValueChanged – function(value)
--
-- Rückgabe: frame
--   frame:GetValue()   – aktuellen Wert lesen
--   frame:SetValue(v)  – Wert setzen (kein Callback)

function UI.CreateSlider(parent, labelText, minValue, maxValue, step, defaultValue, onValueChanged)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- OptionsSliderTemplate-Labels ausblenden
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end

    -- Label + Wertanzeige
    local lbl = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    lbl:SetText(labelText or "")
    lbl:SetTextColor(0.90, 0.85, 0.70)
    slider._label = lbl

    local valFS = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valFS:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
    valFS:SetJustifyH("RIGHT")
    valFS:SetTextColor(1.00, 0.82, 0.00)
    slider._valFS = valFS

    local function FormatVal(v)
        if step < 1 then return string.format("%.1f", v) end
        return tostring(math.floor(v + 0.5))
    end

    -- _silent: verhindert Callback bei programmatischem SetValue
    local _silent = false

    slider:SetScript("OnValueChanged", function(self, v)
        valFS:SetText(FormatVal(v))
        if not _silent and onValueChanged then onValueChanged(v) end
    end)

    -- Startwert setzen (ohne Callback)
    _silent = true
    slider:SetValue(defaultValue or minValue)
    valFS:SetText(FormatVal(defaultValue or minValue))
    _silent = false

    -- Public API
    function slider:SetValue(v)
        _silent = true
        getmetatable(self).__index.SetValue(self, v)
        valFS:SetText(FormatVal(v))
        _silent = false
    end

    return slider
end

-- ============================================================
-- CreateGameLogo
-- ============================================================
-- Erstellt eine Logo-Textur im Spielfeld-Frame, zentriert.
-- Wird im IDLE-Zustand angezeigt, beim Spielstart ausgeblendet.
--
-- Parameter:
--   fieldFrame  – der _fieldFrame des Renderers
--   assetPath   – Textur-Pfad ohne .tga (z.B. "Interface\\...\\logo")
--   config      – optionale Tabelle:
--                   w      (Breite,    default 400)
--                   h      (Höhe,      default 200)
--                   x      (X-Offset,  default 0)
--                   y      (Y-Offset,  default 0)
--                   alpha  (0.0–1.0,   default 1.0)
--
-- Rückgabe: logoTex (Texture-Objekt)
--   logoTex:Show()  → in EnterIdleState aufrufen
--   logoTex:Hide()  → in OnGameStarted aufrufen
--
-- Modularitäts-Garantie:
--   Die Funktion erstellt nur eine Textur — keine Frames, keine Events.
--   Wenn ein Spiel aus der TOC ausgeklammert wird, wird diese Funktion
--   nie aufgerufen → kein Lua-Fehler.

-- ============================================================
-- HUD Stat-Box (Blackjack-Kapital-Look)
-- ============================================================
-- Dunkler Tooltip-Hintergrund + goldener Rahmen, zentrierter Text.
-- Keine Default-Größe: w/h müssen gesetzt sein, damit Layouts nicht
-- stillschweigend vereinheitlicht werden.
--
-- config:
--   w, h            Pflicht
--   point           Default "TOPLEFT"
--   relativeTo      Default parent
--   relativePoint   Default = point
--   x, y            Offsets (Default 0)
--   alpha           Fill-Alpha (Default 0.75)
--   font            Default "GameFontNormal"
--   text, textColor
--   shown           Default true; false → Hide (Spielstart)
--   frameLevel      sonst parent+20 (über Background/TGA)
--
-- Rückgabe: box, fontString

local HUD_STAT_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileEdge = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function UI.CreateHudStatBox(parent, config)
    if not parent or not config or not config.w or not config.h then
        return nil, nil
    end

    local box = CreateFrame("Frame", config.name, parent, "BackdropTemplate")
    box:SetSize(config.w, config.h)
    local point    = config.point or "TOPLEFT"
    local rel      = config.relativeTo or parent
    local relPoint = config.relativePoint or point
    box:SetPoint(point, rel, relPoint, config.x or 0, config.y or 0)
    box:SetBackdrop(HUD_STAT_BACKDROP)
    local alpha = config.alpha
    if alpha == nil then alpha = 0.75 end
    box:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    box:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    box:SetFrameLevel(config.frameLevel or ((parent.GetFrameLevel and parent:GetFrameLevel()) or 1) + 20)
    box:EnableMouse(false)

    local fs = box:CreateFontString(nil, "OVERLAY", config.font or "GameFontNormal")
    fs:SetPoint("CENTER", box, "CENTER", 0, 0)
    local tc = config.textColor or { 0.95, 0.85, 0.4 }
    fs:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    if config.justifyH then fs:SetJustifyH(config.justifyH) end
    fs:SetText(config.text or "")

    if config.shown == false then
        box:Hide()
    end
    return box, fs
end

-- Goldener Tooltip-Rahmen um ein bestehendes Grid/Spielfeld.
-- Größe folgt dem Anchor-Frame (kein festes Maß, kein Background-Helper).
--
-- config.pad        Außenabstand in px (Default 0)
-- config.x / y      Extra-Offset relativ zum Anchor-TOPLEFT
-- config.w / h      Optional feste Innengröße (sonst TOPLEFT+BOTTOMRIGHT)
-- config.fillAlpha  Default 0 (transparent, nur Goldkante)
-- config.levelAdd   FrameLevel über Anchor (Default 5)
-- Startet versteckt — Renderer zeigt den Rahmen erst nach Spielstart.

function UI.FitGoldGridFrame(frame, anchor, config)
    if not frame or not anchor then return frame end
    local cfg = config or {}
    local pad = cfg.pad or 0
    local ox  = cfg.x or 0
    local oy  = cfg.y or 0
    frame:ClearAllPoints()
    if cfg.w and cfg.h then
        frame:SetSize(cfg.w + pad * 2, cfg.h + pad * 2)
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad + ox, pad + oy)
    else
        frame:SetPoint("TOPLEFT",     anchor, "TOPLEFT",     -pad + ox,  pad + oy)
        frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT",  pad + ox, -pad + oy)
    end
    return frame
end

function UI.CreateGoldGridFrame(parent, anchor, config)
    if not parent or not anchor then return nil end
    local cfg = config or {}
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(HUD_STAT_BACKDROP)
    f:SetBackdropColor(0.05, 0.05, 0.05, cfg.fillAlpha or 0)
    f:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)
    local base = (anchor.GetFrameLevel and anchor:GetFrameLevel()) or 1
    f:SetFrameLevel(cfg.frameLevel or (base + (cfg.levelAdd or 5)))
    f:EnableMouse(false)
    UI.FitGoldGridFrame(f, anchor, cfg)
    f:Hide()
    return f
end

function UI.CreateGameLogo(fieldFrame, assetPath, config)
    if not fieldFrame or not assetPath then return nil end
    local cfg = config or {}
    local w     = cfg.w     or 400
    local h     = cfg.h     or 200
    local x     = cfg.x     or 0
    local y     = cfg.y     or 0
    local alpha = cfg.alpha or 1.0

    local logo = fieldFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    logo:SetTexture(assetPath)
    logo:SetSize(w, h)
    logo:SetPoint("CENTER", fieldFrame, "CENTER", x, y)
    logo:SetAlpha(alpha)
    logo:Hide()
    return logo
end

-- ============================================================
-- CreateDivider
-- ============================================================
-- Erstellt einen horizontalen oder vertikalen Divider.
-- Goldene Linie (WHITE8X8, WoW-Gold-Farbton).

--
-- orientation: "H" (horizontal) | "V" (vertikal)
-- parent:      Parent-Frame
-- config:      optionale Tabelle:
--   {
--     w         = Breite  (H: Länge,  V: Dicke,  Default H=400 V=2)
--     h         = Höhe    (H: Dicke,  V: Länge,  Default H=16  V=200)
--     x         = SetPoint x-Offset (Default 0)
--     y         = SetPoint y-Offset (Default 0)
--     anchor    = Ankerpunkt am parent (Default "CENTER")
--     relAnchor = relativer Ankerpunkt am parent (Default = anchor)
--   }
-- Rückgabe: divider-Frame

function UI.CreateDivider(parent, orientation, config)
    local cfg       = config or {}
    local isH       = (orientation ~= "V")
    local w         = cfg.w        or (isH and 400 or 2)
    local h         = cfg.h        or (isH and 2   or 200)
    local x         = cfg.x        or 0
    local y         = cfg.y        or 0
    local anchor    = cfg.anchor   or "CENTER"
    local relAnchor = cfg.relAnchor or anchor

    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f:SetPoint(anchor, parent, relAnchor, x, y)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    local col = cfg.color
    if col then
        tex:SetVertexColor(col[1] or 0.60, col[2] or 0.50, col[3] or 0.20, col[4] or 0.9)
    else
        tex:SetVertexColor(0.60, 0.50, 0.20, 0.9)
    end

    return f
end

-- ============================================================
-- ShowChoicePopup / HideChoicePopup
-- ============================================================
-- Zentraler 2-Button-Dialog für Spielstart, Pause, Fortsetzen etc.
-- config:
--   parent      – Anker-Frame (Pflicht)
--   title       – Titelzeile
--   titleColor  – {r,g,b} (Default Gold)
--   body        – optionaler Fließtext
--   anchor      – Anker am parent (Default "CENTER")
--   x, y        – Offset (Default 0, 0)
--   width, height – Popup-Größe (Default 260×148)
--   buttons     – { { label, onClick, enabled=true }, ... } (max 2)

UI._choicePopups = UI._choicePopups or {}
local CHOICE_POPUP_VER = 2

local function EnsureChoicePopup(parent)
    local popup = UI._choicePopups[parent]
    if popup and popup._ver ~= CHOICE_POPUP_VER then
        popup:Hide()
        popup:SetParent(nil)
        UI._choicePopups[parent] = nil
        popup = nil
    end
    if popup then return popup end

    popup = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    popup._ver = CHOICE_POPUP_VER
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    popup:SetBackdropBorderColor(0.9, 0.75, 0.3, 1)

    popup.titleFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.titleFS:SetPoint("TOP", popup, "TOP", 0, -16)

    popup.bodyFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.bodyFS:SetPoint("TOP", popup.titleFS, "BOTTOM", 0, -8)
    popup.bodyFS:SetWidth(240)
    popup.bodyFS:SetTextColor(1, 1, 1, 1)
    popup.bodyFS:SetJustifyH("CENTER")

    popup.btn1 = UI.CreateArcadiaButton(popup, "", 140, 32)
    popup.btn1:SetPoint("BOTTOM", popup, "BOTTOM", 0, 50)

    popup.btn2 = UI.CreateArcadiaButton(popup, "", 140, 32)
    popup.btn2:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)

    popup:Hide()
    UI._choicePopups[parent] = popup
    return popup
end

local function SetChoiceButtonLabel(btn, text)
    if btn.SetLabel then
        btn:SetLabel(text)
    else
        btn:SetText(text)
    end
end

function UI.ShowChoicePopup(config)
    if not config or not config.parent then return end
    local parent = config.parent
    local popup  = EnsureChoicePopup(parent)

    local w = config.width  or 280
    local h = config.height or 172
    popup:SetSize(w, h)
    popup:ClearAllPoints()
    popup:SetPoint(config.anchor or "CENTER", parent, config.anchor or "CENTER",
        config.x or 0, config.y or 0)

    local parentLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 1
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(parentLevel + 80)

    local tc = config.titleColor or { 1, 0.82, 0 }
    popup.titleFS:SetText(config.title or "")
    popup.titleFS:SetTextColor(tc[1], tc[2], tc[3], 1)

    local body = config.body
    if body and body ~= "" then
        popup.bodyFS:SetWidth(w - 32)
        popup.bodyFS:SetText(body)
        popup.bodyFS:Show()
    else
        popup.bodyFS:SetText("")
        popup.bodyFS:Hide()
    end

    local buttons = config.buttons or {}
    for i = 1, 2 do
        local btnCfg = buttons[i]
        local btn    = (i == 1) and popup.btn1 or popup.btn2
        if btnCfg and btnCfg.label then
            SetChoiceButtonLabel(btn, btnCfg.label)
            btn:SetScript("OnClick", btnCfg.onClick or function() end)
            if btnCfg.enabled == false then btn:Disable() else btn:Enable() end
            btn:Show()
        else
            btn:Hide()
        end
    end

    popup:Show()
    popup:Raise()
end

function UI.HideChoicePopup(parent)
    if not parent then return end
    local popup = UI._choicePopups and UI._choicePopups[parent]
    if popup then popup:Hide() end
end
