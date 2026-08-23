--[[
    ArcadiaNexus – UI/Dialogs/SaveSlotMenu.lua
    Gemeinsames Slot-Menü für Spiele mit Speicherständen.

    Ablauf (wie Azeroth Jewels):
      IDLE (Logo) → „Spiel starten“ → Slot-Menü
      Neues Spiel / Fortfahren / Slot löschen (X)

    API:
      menu = UI.CreateSaveSlotMenu(config)
      menu:Show()  menu:Hide()  menu:IsShown()
      menu:Refresh()
      menu:GetSelected()  menu:SetSelected(slot)

    config:
      parent        (Frame, required)
      maxSlots      (number, default 3)
      L             (locale table, optional – fällt auf UI-Locale zurück)
      title         (string, optional)
      loadSlot      function(slot) → save|nil
      deleteSlot    function(slot)
      formatInfo    function(save, L) → string
      isPaused      function(save) → bool
      formatPaused  function(save, L) → string  (optional)
      onNewGame     function(slot)
      onContinue    function(slot)
      confirmParent (Frame, unused – Confirm hängt immer am Slot-Menü, damit es vorne liegt)
      layout        { rowW, rowH, rowGap, rowOfsX, titleY, firstY, btnY, btnW, btnH }
]]

ArcadiaNexus    = ArcadiaNexus or {}
ArcadiaNexus.UI = ArcadiaNexus.UI or {}

local UI = ArcadiaNexus.UI

local DEFAULT_LAYOUT = {
    rowW    = 320,
    rowH    = 52,
    rowGap  = 60,
    rowOfsX = -12,
    titleY  = -60,
    firstY  = -100,
    btnY    = 40,
    btnW    = 144,
    btnH    = 32,
}

local function UILocale()
    return ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI") or {}
end

local function Label(gameL, key, fallback)
    local function ok(val)
        return val and val ~= "" and val ~= key and val ~= ("[" .. key .. "]")
    end
    if gameL then
        local val = gameL[key]
        if ok(val) then return val end
    end
    local ui = UILocale()
    local val = ui[key]
    if ok(val) then return val end
    return fallback or key
end

local function FormatTimestamp(save)
    if not save or not save.timestamp then return "" end
    if type(date) == "function" then
        return date("%d.%m.%y %H:%M", save.timestamp)
    end
    return ""
end

function UI.CreateSaveSlotMenu(config)
    if not config or not config.parent then return nil end

    local parent = config.parent
    local L      = config.L
    local maxSlots = config.maxSlots or 3
    local lay = {}
    for k, v in pairs(DEFAULT_LAYOUT) do
        lay[k] = (config.layout and config.layout[k]) or v
    end

    local menu = CreateFrame("Frame", nil, parent)
    menu:SetAllPoints(parent)
    menu:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    menu:Hide()

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", menu, "TOP", 0, lay.titleY)
    title:SetText("|cffffd700" .. (config.title or Label(L, "slot_menu_title", "Spielstand wählen")) .. "|r")

    local rows = {}
    local selected = 1

    local api = {
        frame    = menu,
        _rows    = rows,
        _selected = selected,
        _contBtn = nil,
        _newBtn  = nil,
    }

    local function Refresh()
        local loadSlot = config.loadSlot
        for slot, row in ipairs(rows) do
            local save = loadSlot and loadSlot(slot)
            row._name:SetText(string.format("|cffffd700" .. Label(L, "slot_label", "Slot %d") .. "|r", slot))
            if save then
                local info = ""
                if config.formatInfo then
                    info = config.formatInfo(save, L) or ""
                end
                if config.isPaused and config.isPaused(save) then
                    local paused = config.formatPaused
                        and config.formatPaused(save, L)
                        or Label(L, "slot_paused", "läuft")
                    info = info .. "  |cff44ff44(" .. paused .. ")|r"
                end
                row._info:SetText(info)
                row._ts:SetText(FormatTimestamp(save))
                row._del:Show()
            else
                row._info:SetText(Label(L, "slot_empty", "— Leer —"))
                row._ts:SetText("")
                row._del:Hide()
            end

            if slot == api._selected then
                row:SetBackdropBorderColor(1, 0.82, 0.1, 1)
            else
                row:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
            end
        end

        local save = loadSlot and loadSlot(api._selected)
        if api._contBtn then
            if save then
                api._contBtn:SetAlpha(1)
                api._contBtn:Enable()
            else
                api._contBtn:SetAlpha(0.4)
                api._contBtn:Disable()
            end
        end
    end

    local function Select(slot)
        api._selected = slot
        Refresh()
    end

    -- Confirm immer Kind des Slot-Menüs, sonst liegt es hinter den Slot-Rows
    local function ConfirmParent()
        return menu
    end

    local function OnNewGame(slot)
        local loadSlot = config.loadSlot
        local save = loadSlot and loadSlot(slot)
        if save then
            UI.ShowChoicePopup({
                parent = ConfirmParent(),
                title  = Label(L, "confirm_overwrite", "Spielstand überschreiben?"),
                body   = string.format(Label(L, "confirm_overwrite_body", "Slot %d enthält einen Spielstand."), slot),
                buttons = {
                    { label = Label(L, "btn_yes", "Ja"), onClick = function()
                        UI.HideChoicePopup(ConfirmParent())
                        if config.onNewGame then config.onNewGame(slot) end
                    end },
                    { label = Label(L, "btn_no", "Abbrechen"), onClick = function()
                        UI.HideChoicePopup(ConfirmParent())
                    end },
                },
            })
        else
            if config.onNewGame then config.onNewGame(slot) end
        end
    end

    local function OnDelete(slot)
        local loadSlot = config.loadSlot
        if not loadSlot or not loadSlot(slot) then return end
        UI.ShowChoicePopup({
            parent = ConfirmParent(),
            title  = Label(L, "confirm_delete", "Spielstand wirklich löschen?"),
            body   = string.format(Label(L, "confirm_delete_body", "Slot %d wird geleert."), slot),
            buttons = {
                { label = Label(L, "btn_yes", "Ja"), onClick = function()
                    UI.HideChoicePopup(ConfirmParent())
                    if config.deleteSlot then config.deleteSlot(slot) end
                    Refresh()
                end },
                { label = Label(L, "btn_no", "Abbrechen"), onClick = function()
                    UI.HideChoicePopup(ConfirmParent())
                end },
            },
        })
    end

    -- Goldrahmen wie Content-Chrome (ContentPanel.lua), um alle Slots
    local GOLD_PAD_X = 16
    local GOLD_PAD_Y = 14
    local DEL_W      = 28
    local spanH      = (maxSlots - 1) * lay.rowGap + lay.rowH
    local gold = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    gold:SetSize(lay.rowW + DEL_W + GOLD_PAD_X * 2, spanH + GOLD_PAD_Y * 2)
    gold:SetPoint("TOP", menu, "TOP", lay.rowOfsX + DEL_W / 2, lay.firstY + GOLD_PAD_Y)
    gold:SetBackdrop({
        bgFile   = nil,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileEdge = true, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    gold:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)
    gold:EnableMouse(false)
    gold:SetFrameLevel((menu:GetFrameLevel() or 1) + 1)
    api._gold = gold

    for slot = 1, maxSlots do
        local row = CreateFrame("Button", nil, menu, "BackdropTemplate")
        row:SetSize(lay.rowW, lay.rowH)
        row:SetPoint("TOP", menu, "TOP", lay.rowOfsX, lay.firstY - (slot - 1) * lay.rowGap)
        row:SetFrameLevel((gold:GetFrameLevel() or 1) + 2)
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        row:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
        row:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
        row._name = name

        local info = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        info:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
        info:SetTextColor(0.7, 0.7, 0.6)
        row._info = info

        local ts = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ts:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 8)
        ts:SetTextColor(0.5, 0.5, 0.45)
        row._ts = ts

        row._slot = slot
        row:SetScript("OnClick", function(btn)
            Select(btn._slot)
        end)

        local del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        del:SetSize(24, 24)
        del:SetPoint("TOPRIGHT", row, "TOPRIGHT", 28, 0)
        del:SetScript("OnClick", function()
            OnDelete(slot)
        end)
        row._del = del

        rows[slot] = row
    end

    -- btn_continue in der UI-Locale ist „Weiter“ (Result-Dialog) – nicht verwenden.
    local function ActionLabel(key, fallback)
        if L then
            local val = L[key]
            if val and val ~= "" and val ~= key and val ~= ("[" .. key .. "]") then
                return val
            end
        end
        return fallback
    end

    local newBtn = UI.CreateArcadiaButton(menu, ActionLabel("btn_new_game", Label(L, "btn_new_game", "Neues Spiel")), lay.btnW, lay.btnH)
    newBtn:SetPoint("BOTTOM", menu, "BOTTOM", -80, lay.btnY)
    newBtn:SetScript("OnClick", function()
        OnNewGame(api._selected)
    end)
    api._newBtn = newBtn

    local contBtn = UI.CreateArcadiaButton(menu, ActionLabel("btn_continue", "Fortfahren"), lay.btnW, lay.btnH)
    contBtn:SetPoint("BOTTOM", menu, "BOTTOM", 80, lay.btnY)
    contBtn:SetScript("OnClick", function()
        local loadSlot = config.loadSlot
        if loadSlot and loadSlot(api._selected) and config.onContinue then
            config.onContinue(api._selected)
        end
    end)
    api._contBtn = contBtn

    function api:Show()
        menu:Show()
        Refresh()
    end

    function api:Hide()
        menu:Hide()
        UI.HideChoicePopup(ConfirmParent())
    end

    function api:IsShown()
        return menu:IsShown()
    end

    function api:Refresh()
        Refresh()
    end

    function api:GetSelected()
        return self._selected
    end

    function api:SetSelected(slot)
        if slot and slot >= 1 and slot <= maxSlots then
            Select(slot)
        end
    end

    Refresh()
    return api
end
