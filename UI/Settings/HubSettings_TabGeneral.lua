--[[
    ArcadiaNexus – HubSettings Tab: Allgemein
    UI/Settings/HubSettings_TabGeneral.lua

    Enthält:
        - _BuildTabGeneral (2x2 Grid: Skalierung | Fenster / Toast | GOTD)
        - Toast-Anker (_ToggleAnchor, _ShowAnchor, _HideAnchor)
        - GOTD-Anker (_ToggleGotdAnchor, _ShowGotdAnchor, _HideGotdAnchor)
        - _SaveAnchorPos

    Abhängigkeiten:
        UI/Settings/HubSettings_Core.lua → ArcadiaNexus.HubSettings
]]

local UI          = ArcadiaNexus.UI
local HubSettings = ArcadiaNexus.HubSettings

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

-- ============================================================
-- TAB: ALLGEMEIN (Skalierung, Fenster-Lock, Toast-Anker, GOTD)
-- ============================================================

function HubSettings:_BuildTabGeneral(parent)
    -- 2x2 Grid: [Skalierung | Fenster] / [Toast | GOTD]
    local GAP   = 8
    local P     = UI.BOX_PAD
    local ROW_H = 160
    local COL_W = 200   -- Platzhalter; _RefreshSettingsLayout korrigiert aus ScrollFrame-Breite

    -- ── Box 1: UI-Skalierung (links oben) ────────────────────
    local scaleBox, scaleContent = UI.CreateBox(parent,
        L("hubsettings_scale_section") or "UI-Skalierung",
        P, 0, COL_W, ROW_H)
    UI.CenterBoxTitle(scaleBox)
    self._scaleBox = scaleBox

    -- Beschreibung
    local scaleDesc = scaleContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleDesc:SetPoint("TOPLEFT",  scaleContent, "TOPLEFT",  0,  0)
    scaleDesc:SetPoint("TOPRIGHT", scaleContent, "TOPRIGHT", 0,  0)
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetWordWrap(true)
    scaleDesc:SetText(L("hubsettings_scale_desc") or "Fenstergröße anpassen. 1.0 = Standardgröße.")
    scaleDesc:SetTextColor(0.75, 0.70, 0.55)

    -- Slider darunter (leeres Label, Wertanzeige kommt vom internen valFS)
    local curScale = (ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.uiScale) or 1.0
    local scaleSlider = UI.CreateSlider(
        scaleContent,
        "",          -- kein internes Label, Beschreibung steht bereits als FontString oben
        1.0, 1.5, 0.1, curScale,
        function(value)
            if ArcadiaNexus.UI.ApplyScale then ArcadiaNexus.UI.ApplyScale(value) end
        end
    )
    scaleSlider:SetPoint("TOPLEFT",  scaleContent, "TOPLEFT",  0, -50)
    scaleSlider:SetPoint("TOPRIGHT", scaleContent, "TOPRIGHT", -32, -50)
    self._scaleSlider = scaleSlider

    local function RefreshScaleSlider()
        local cur = (ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.uiScale) or 1.0
        if HubSettings._scaleSlider then HubSettings._scaleSlider:SetValue(cur) end
    end
    self._refreshScaleBtns = RefreshScaleSlider

    -- ── Box 2: Fenster-Lock (rechts oben) ────────────────────
    local lockBox, lockContent = UI.CreateBox(parent,
        L("hubsettings_lock_section") or "Fenster",
        P*2 + COL_W + GAP, 0, COL_W, ROW_H)
    UI.CenterBoxTitle(lockBox)
    self._lockBox = lockBox

    local lockDesc = lockContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockDesc:SetPoint("TOPLEFT", lockContent, "TOPLEFT", 0, 0)
    lockDesc:SetPoint("RIGHT",   lockContent, "RIGHT",   0, 0)
    lockDesc:SetJustifyH("LEFT")
    lockDesc:SetWordWrap(true)
    lockDesc:SetText(L("hubsettings_lock_desc") or "Verhindert, dass das Fenster versehentlich verschoben wird.")
    lockDesc:SetTextColor(0.75, 0.70, 0.55)

    local lockCB = UI.CreateCheckbox(lockContent,
        L("hubsettings_lock_ui") or "Fenster-Position sperren", 0, 0)
    lockCB:ClearAllPoints()
    lockCB:SetPoint("TOPLEFT", lockContent, "TOPLEFT", 0, -38)
    lockCB:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        if not ArcadiaNexusDB.settings then ArcadiaNexusDB.settings = {} end
        ArcadiaNexusDB.settings.lockUI = val
        local fref = ArcadiaNexus.UI and ArcadiaNexus.UI.GetF and ArcadiaNexus.UI.GetF()
        if fref and fref.main then fref.main:SetMovable(not val) end
    end)
    self._lockCB = lockCB

    -- ── Box 3: Achievement Toast (links unten) ───────────────
    local toastBox, toastContent = UI.CreateBox(parent,
        L("hubsettings_toast_section") or "Achievement Toast",
        P, ROW_H + GAP, COL_W, ROW_H)
    UI.CenterBoxTitle(toastBox)
    self._toastBox = toastBox

    local coordFS = toastContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordFS:SetPoint("TOPLEFT", toastContent, "TOPLEFT", 0, 0)
    coordFS:SetJustifyH("LEFT")
    coordFS:SetTextColor(0.60, 0.60, 0.60)
    self._coordFS = coordFS

    local toastDesc = toastContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastDesc:SetPoint("TOPLEFT", coordFS, "BOTTOMLEFT", 0, -4)
    toastDesc:SetPoint("RIGHT",   toastContent, "RIGHT", 0, 0)
    toastDesc:SetJustifyH("LEFT")
    toastDesc:SetWordWrap(true)
    toastDesc:SetText(L("hubsettings_toast_desc") or "Anker anzeigen und an die gewünschte Position ziehen.")
    toastDesc:SetTextColor(0.75, 0.70, 0.55)

    -- Zurücksetzen + Vorschau nebeneinander, zentriert unter Beschreibung
    local resetBtn = UI.CreateButton(toastContent, L("hubsettings_reset") or "Zurücksetzen", 110, 26)
    resetBtn:SetPoint("TOPRIGHT", toastContent, "TOP", -2, -58)
    resetBtn:SetScript("OnClick", function()
        ArcadiaNexusDB.toastAnchor = { x=0, y=-200 }
        local TM = ArcadiaNexus.ToastManager
        if TM and TM.UpdateAnchor then TM:UpdateAnchor() end
        HubSettings:_UpdateCoordDisplay()
        if HubSettings._anchorActive then HubSettings:_HideAnchor() end
    end)

    local previewBtn = UI.CreateButton(toastContent, L("hubsettings_toast_preview") or "Vorschau", 110, 26)
    previewBtn:SetPoint("TOPLEFT", toastContent, "TOP", 2, -58)
    previewBtn:SetScript("OnClick", function()
        local TM = ArcadiaNexus.ToastManager
        if TM and TM.PreviewStack then
            pcall(function() TM:PreviewStack() end)
        elseif TM and TM.Show then
            pcall(function()
                TM:Show({
                    icon     = "Interface\\Icons\\Achievement_General_StayClassy",
                    title_de = "Vorschau-Erfolg",  title_en = "Preview Achievement",
                    desc_de  = "So sieht der Toast aus!", desc_en = "This is how the toast looks!",
                    _preview = true,
                })
            end)
        end
    end)

    -- Anker-Button linksbündig unter Zurücksetzen, Breite passend zum Label
    local anchorBtn = UI.CreateButton(toastContent, L("hubsettings_toast_anchor_show") or "Anker anzeigen & verschieben", 220, 26)
    anchorBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
    anchorBtn:SetScript("OnClick", function() HubSettings:_ToggleAnchor() end)
    self._anchorBtn    = anchorBtn
    self._anchorBtnLbl = anchorBtn

    -- ── Box 4: Spiel des Tages (rechts unten) ────────────────
    local gotdBox, gotdContent = UI.CreateBox(parent,
        L("hubsettings_gotd_section") or "Spiel des Tages",
        P*2 + COL_W + GAP, ROW_H + GAP, COL_W, ROW_H)
    UI.CenterBoxTitle(gotdBox)
    self._gotdBox = gotdBox

    -- Name des heutigen Spiels (wird von _UpdateGotdDisplay befüllt)
    local gotdNameFS = gotdContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gotdNameFS:SetPoint("TOPLEFT",  gotdContent, "TOPLEFT",  0, 0)
    gotdNameFS:SetPoint("TOPRIGHT", gotdContent, "TOPRIGHT", 0, 0)
    gotdNameFS:SetJustifyH("LEFT")
    gotdNameFS:SetTextColor(0.40, 0.90, 0.40)
    self._gotdNameFS = gotdNameFS

    -- Beschreibung
    local gotdDesc = gotdContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gotdDesc:SetPoint("TOPLEFT",  gotdNameFS, "BOTTOMLEFT", 0, -4)
    gotdDesc:SetPoint("TOPRIGHT", gotdContent, "TOPRIGHT",  0, -4)
    gotdDesc:SetJustifyH("LEFT")
    gotdDesc:SetWordWrap(true)
    gotdDesc:SetText(L("hubsettings_gotd_desc") or "Das Spiel des Tages wechselt täglich. Gewinne +25% XP beim Spielen.")
    gotdDesc:SetTextColor(0.75, 0.70, 0.55)

    -- Checkbox: Overlay-Box anzeigen
    local showCB = UI.CreateCheckbox(gotdContent,
        L("hubsettings_gotd_show") or "Box anzeigen", 0, 0)
    showCB:ClearAllPoints()
    showCB:SetPoint("TOPLEFT", gotdContent, "TOPLEFT", 0, -37)
    local showGotd = (ArcadiaNexusDB and ArcadiaNexusDB.settings and ArcadiaNexusDB.settings.showGotd)
    if showGotd == nil then showGotd = true end
    showCB:SetChecked(showGotd)
    showCB:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        if not ArcadiaNexusDB.settings then ArcadiaNexusDB.settings = {} end
        ArcadiaNexusDB.settings.showGotd = val and true or false
        if ArcadiaNexus.UI and ArcadiaNexus.UI.UpdateBadge then
            pcall(ArcadiaNexus.UI.UpdateBadge)
        end
    end)
    self._gotdShowCB = showCB

    -- GOTD-Anker-Button
    local gotdAnchorBtn = UI.CreateButton(gotdContent, L("hubsettings_gotd_anchor_show") or "GOTD-Anker verschieben", 180, 26)
    gotdAnchorBtn:SetPoint("TOPLEFT", showCB, "BOTTOMLEFT", 0, -8)
    gotdAnchorBtn:SetScript("OnClick", function() HubSettings:_ToggleGotdAnchor() end)
    self._gotdAnchorBtn    = gotdAnchorBtn
    self._gotdAnchorBtnLbl = gotdAnchorBtn

    -- Zurücksetzen-Button
    local gotdResetBtn = UI.CreateButton(gotdContent, L("hubsettings_reset") or "Zurücksetzen", 180, 26)
    gotdResetBtn:SetPoint("TOPLEFT", gotdAnchorBtn, "BOTTOMLEFT", 0, -6)
    gotdResetBtn:SetScript("OnClick", function()
        ArcadiaNexusDB.gotdAnchor = { x=0, y=-200 }
        if HubSettings._gotdAnchorActive then HubSettings:_HideGotdAnchor() end
    end)
end

-- ============================================================
-- TOAST-ANKER
-- ============================================================

HubSettings._anchorActive = false
HubSettings._anchorFrame  = nil

function HubSettings:_ToggleAnchor()
    if self._anchorActive then self:_HideAnchor()
    else self:_ShowAnchor() end
end

function HubSettings:_ShowAnchor()
    self._anchorActive = true
    if self._anchorBtnLbl then
        self._anchorBtnLbl:SetLabel(L("hubsettings_toast_anchor_confirm") or "Position bestätigen")
    end

    if not self._anchorFrame then
        local af = CreateFrame("Frame", "NexusToastAnchorDrag", UIParent, "BackdropTemplate")
        af:SetSize(320, 76)
        af:SetFrameStrata("TOOLTIP")
        af:SetFrameLevel(500)
        af:EnableMouse(true)
        af:SetMovable(true)
        af:RegisterForDrag("LeftButton")
        af:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4},
        })
        af:SetBackdropColor(0.10, 0.05, 0.00, 0.70)
        af:SetBackdropBorderColor(1.00, 0.82, 0.00, 1)

        local hint = af:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetAllPoints(af)
        hint:SetJustifyH("CENTER")
        hint:SetJustifyV("MIDDLE")
        hint:SetText(L("hubsettings_anchor_label") or "Toast-Anker  (Ziehen zum Positionieren)")
        hint:SetTextColor(1.00, 0.82, 0.00)

        af:SetScript("OnDragStart", function(self) self:StartMoving() end)
        af:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            HubSettings:_SaveAnchorPos(self, "toastAnchor")
            HubSettings:_UpdateCoordDisplay()
            local TM = ArcadiaNexus.ToastManager
            if TM and TM.UpdateAnchor then TM:UpdateAnchor() end
        end)
        af:SetScript("OnUpdate", function(self)
            HubSettings:_SaveAnchorPos(self, "toastAnchor")
            HubSettings:_UpdateCoordDisplay()
        end)

        self._anchorFrame = af
    end

    local db = ArcadiaNexusDB and ArcadiaNexusDB.toastAnchor
    self._anchorFrame:ClearAllPoints()
    self._anchorFrame:SetPoint("TOP", UIParent, "TOP", (db and db.x) or 0, (db and db.y) or -200)
    self._anchorFrame:Show()
end

function HubSettings:_HideAnchor()
    self._anchorActive = false
    if self._anchorFrame then self._anchorFrame:Hide() end
    if self._anchorBtnLbl then
        self._anchorBtnLbl:SetLabel(L("hubsettings_toast_anchor_show") or "Anker anzeigen & verschieben")
    end
    self:_UpdateCoordDisplay()
end

-- ============================================================
-- GOTD-ANKER
-- ============================================================

HubSettings._gotdAnchorActive = false
HubSettings._gotdAnchorFrame  = nil

function HubSettings:_ToggleGotdAnchor()
    if self._gotdAnchorActive then self:_HideGotdAnchor()
    else self:_ShowGotdAnchor() end
end

function HubSettings:_ShowGotdAnchor()
    self._gotdAnchorActive = true
    if self._gotdAnchorBtnLbl then
        self._gotdAnchorBtnLbl:SetLabel(L("hubsettings_toast_anchor_confirm") or "Position bestätigen")
    end

    if not self._gotdAnchorFrame then
        local af = CreateFrame("Frame", "NexusGotdAnchorDrag", UIParent, "BackdropTemplate")
        af:SetSize(300, 101)
        af:SetFrameStrata("TOOLTIP")
        af:SetFrameLevel(500)
        af:EnableMouse(true)
        af:SetMovable(true)
        af:RegisterForDrag("LeftButton")
        af:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=12,
            insets={left=3,right=3,top=3,bottom=3},
        })
        af:SetBackdropColor(0.05, 0.05, 0.08, 0.90)
        af:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local hint = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetAllPoints(af)
        hint:SetJustifyH("CENTER")
        hint:SetJustifyV("MIDDLE")
        hint:SetText(L("hubsettings_gotd_anchor_label") or "GOTD-Anker  (Ziehen zum Positionieren)")
        hint:SetTextColor(1.00, 0.82, 0.00)

        af:SetScript("OnDragStart", function(self) self:StartMoving() end)
        af:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            HubSettings:_SaveAnchorPos(self, "gotdAnchor")
            local db = ArcadiaNexusDB and ArcadiaNexusDB.gotdAnchor
            local badge = _G["NexusGotdBadge"]
            if badge and db then
                badge:ClearAllPoints()
                badge:SetPoint("TOP", UIParent, "TOP", db.x or 0, db.y or -57)
            end
        end)
        af:SetScript("OnUpdate", function(self)
            HubSettings:_SaveAnchorPos(self, "gotdAnchor")
        end)

        self._gotdAnchorFrame = af
    end

    local db = ArcadiaNexusDB and ArcadiaNexusDB.gotdAnchor
    self._gotdAnchorFrame:ClearAllPoints()
    self._gotdAnchorFrame:SetPoint("TOP", UIParent, "TOP",
        (db and db.x) or 0, (db and db.y) or -220)
    self._gotdAnchorFrame:Show()
end

function HubSettings:_HideGotdAnchor()
    self._gotdAnchorActive = false
    if self._gotdAnchorFrame then self._gotdAnchorFrame:Hide() end
    if self._gotdAnchorBtnLbl then
        self._gotdAnchorBtnLbl:SetLabel(L("hubsettings_gotd_anchor_show") or "GOTD-Anker verschieben")
    end
end

-- ============================================================
-- ANKER-POSITION SPEICHERN
-- ============================================================

function HubSettings:_SaveAnchorPos(frame, dbKey)
    local cx, cy = frame:GetCenter()
    if not cx then return end
    local uw = UIParent:GetWidth()
    local uh = UIParent:GetHeight()
    local fh = frame:GetHeight() or 0
    local nx = cx - uw / 2
    local ny = (cy + fh / 2) - uh
    if not ArcadiaNexusDB[dbKey] then ArcadiaNexusDB[dbKey] = {} end
    ArcadiaNexusDB[dbKey].x = nx
    ArcadiaNexusDB[dbKey].y = ny
    if dbKey == "gotdAnchor" then
        local badge = _G["NexusGotdBadge"]
        if badge then
            badge:ClearAllPoints()
            badge:SetPoint("TOP", UIParent, "TOP", nx, ny)
        end
    end
end

-- ============================================================
-- REGISTRY
-- ============================================================

local function RefreshGeneralLayout(hs, pw)
    local parent = hs._tabFrames and hs._tabFrames["GENERAL"]
    if not parent or not hs._scaleBox then return end

    local GAP   = 8
    local P     = UI.BOX_PAD
    local ROW_H = 160
    local col   = math.floor((pw - P * 2 - GAP) / 2)
    local rightX = P + col + GAP
    local boxes = {
        { hs._scaleBox, P,       0           },
        { hs._lockBox,  rightX,  0           },
        { hs._toastBox, P,       ROW_H + GAP },
        { hs._gotdBox,  rightX,  ROW_H + GAP },
    }
    for _, b in ipairs(boxes) do
        if b[1] then
            b[1]:ClearAllPoints()
            b[1]:SetSize(col, ROW_H)
            b[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", b[2], -b[3])
        end
    end
end

ArcadiaNexus.RegisterHubSettingsTab({
    id            = "GENERAL",
    labelKey      = "hubsettings_tab_general",
    labelFallback = "Allgemein",
    order         = 10,
    buildContent  = function(parent)
        HubSettings:_BuildTabGeneral(parent)
    end,
    refreshLayout = RefreshGeneralLayout,
})
