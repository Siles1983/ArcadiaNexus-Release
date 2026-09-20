--[[
    ArcadiaNexus – HubSettings Tab: Statistiken
    UI/Settings/HubSettings_TabStats.lua

    UI für Reset + Export/Import. Codec und Payload: Core/StatsTransfer.lua.
]]

local UI          = ArcadiaNexus.UI
local HubSettings = ArcadiaNexus.HubSettings
local ST          = ArcadiaNexus.StatsTransfer

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

-- ============================================================
-- TAB: STATISTIKEN
-- ============================================================

function HubSettings:_BuildTabStats(parent)
    local GAP = 12
    local P   = UI.BOX_PAD

    -- ── BOX: Statistiken zurücksetzen ────────────────────────
    local BOX_H_RESET = 100
    local resetBox, resetContent = UI.CreateBox(parent,
        L("hubsettings_stats_section") or "Statistiken zurücksetzen",
        P, 0, 0, BOX_H_RESET, P)

    local resetDesc = resetContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetDesc:SetPoint("TOPLEFT", resetContent, "TOPLEFT", 0, 0)
    resetDesc:SetPoint("RIGHT",   resetContent, "RIGHT",   0, 0)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetWordWrap(true)
    resetDesc:SetText(L("hubsettings_stats_reset_desc") or
        "Setzt Bestenliste, Profil, Streak und Challenges zurück. Erfolge bleiben erhalten.")
    resetDesc:SetTextColor(0.75, 0.70, 0.55)

    local statsResetBtn = UI.CreateButton(resetContent, L("hubsettings_stats_reset_btn") or "Statistiken zurücksetzen", 220, 26)
    statsResetBtn:SetPoint("TOPLEFT", resetDesc, "BOTTOMLEFT", 0, -10)
    statsResetBtn:SetScript("OnClick", function()
        HubSettings:_ShowConfirm(
            L("hubsettings_stats_confirm1_title") or "Statistiken zurücksetzen?",
            L("hubsettings_stats_confirm1_body")  or
                "Bestenliste, Profil, Streak und Challenges werden unwiderruflich gelöscht. Fortfahren?",
            function()
                HubSettings:_ShowConfirm(
                    L("hubsettings_stats_confirm2_title") or "Wirklich zurücksetzen?",
                    L("hubsettings_stats_confirm2_body")  or
                        "Letzte Warnung: Alle Statistiken werden auf Startwerte gesetzt.",
                    function() HubSettings:_ResetStats() end
                )
            end
        )
    end)

    -- ── BOX: Export / Import ──────────────────────────────────
    local BOX_H_EXP = 90
    local exportBox, exportContent = UI.CreateBox(parent,
        L("hubsettings_export_section") or "Export / Import",
        P, BOX_H_RESET + GAP, 0, BOX_H_EXP, P)

    local expDesc = exportContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expDesc:SetPoint("TOPLEFT", exportContent, "TOPLEFT", 0, 0)
    expDesc:SetPoint("RIGHT",   exportContent, "RIGHT",   0, 0)
    expDesc:SetJustifyH("LEFT")
    expDesc:SetWordWrap(true)
    expDesc:SetText(
        L("hubsettings_export_desc") or
        "Bestenliste, Profil, Streak und Challenge-Verlauf exportieren oder importieren.")
    expDesc:SetTextColor(0.75, 0.70, 0.55)

    local exportBtn = UI.CreateButton(exportContent, L("hubsettings_export_btn") or "Exportieren", 150, 26)
    exportBtn:SetPoint("TOPLEFT", expDesc, "BOTTOMLEFT", 0, -10)
    exportBtn:SetScript("OnClick", function()
        local b64 = ST.Encode()
        if not b64 then return end
        HubSettings:_ShowExportPopup(b64)
    end)

    local importBtn = UI.CreateButton(exportContent, L("hubsettings_import_btn") or "Importieren", 150, 26)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        HubSettings:_ShowImportPopup()
    end)
end

-- ============================================================
-- EXPORT POPUP
-- ============================================================

function HubSettings:_ShowExportPopup(b64String)
    if not self._exportPopup then
        local d = CreateFrame("Frame", "NexusExportPopup", UIParent, "BackdropTemplate")
        d:SetSize(520, 200)
        d:SetFrameStrata("DIALOG")
        d:SetFrameLevel(700)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=5,right=5,top=5,bottom=5},
        })
        d:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
        d:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local titleFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -14)
        titleFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -14)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(1.00, 0.82, 0.00)
        titleFS:SetText(L("hubsettings_export_popup_title") or "Statistiken exportieren")

        local hint = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -34)
        hint:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -34)
        hint:SetJustifyH("CENTER")
        hint:SetTextColor(0.75, 0.70, 0.55)
        hint:SetText(L("hubsettings_export_popup_hint") or "Den String kopieren und sicher aufbewahren.")

        local ebFrame = CreateFrame("Frame", nil, d, "BackdropTemplate")
        ebFrame:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -54)
        ebFrame:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -54)
        ebFrame:SetHeight(88)
        ebFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=10,
            insets={left=3,right=3,top=3,bottom=3},
        })
        ebFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
        ebFrame:SetBackdropBorderColor(0.45, 0.38, 0.16, 1)

        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetPoint("TOPLEFT",     ebFrame, "TOPLEFT",     5, -5)
        eb:SetPoint("BOTTOMRIGHT", ebFrame, "BOTTOMRIGHT", -5,  5)
        eb:SetMultiLine(false)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        d._eb = eb

        local copyBtn = UI.CreateButton(d, L("hubsettings_export_copy") or "Alles markieren", 160, 26)
        copyBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)
        copyBtn:SetScript("OnClick", function()
            d._eb:SetFocus()
            d._eb:HighlightText()
        end)

        local closeBtn = UI.CreateButton(d, L("hubsettings_export_close") or "Schließen", 120, 26)
        closeBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
        closeBtn:SetScript("OnClick", function() d:Hide() end)

        self._exportPopup = d
    end

    self._exportPopup._eb:SetText(b64String)
    C_Timer.After(0, function()
        if self._exportPopup._eb then
            self._exportPopup._eb:SetFocus()
            self._exportPopup._eb:HighlightText()
        end
    end)
    self._exportPopup:Show()
end

-- ============================================================
-- IMPORT POPUP
-- ============================================================

function HubSettings:_ShowImportPopup()
    if not self._importPopup then
        local d = CreateFrame("Frame", "NexusImportPopup", UIParent, "BackdropTemplate")
        d:SetSize(520, 220)
        d:SetFrameStrata("DIALOG")
        d:SetFrameLevel(700)
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=16,
            insets={left=5,right=5,top=5,bottom=5},
        })
        d:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
        d:SetBackdropBorderColor(0.90, 0.75, 0.30, 1)

        local titleFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -14)
        titleFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -14)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(1.00, 0.82, 0.00)
        titleFS:SetText(L("hubsettings_import_popup_title") or "Statistiken importieren")

        local hint = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -34)
        hint:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -34)
        hint:SetJustifyH("CENTER")
        hint:SetTextColor(0.75, 0.70, 0.55)
        hint:SetText(L("hubsettings_import_popup_hint") or "Export-String einfügen und Importieren klicken.")

        local statusFS = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusFS:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -48)
        statusFS:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -48)
        statusFS:SetJustifyH("CENTER")
        statusFS:SetText("")
        d._statusFS = statusFS

        local ebFrame = CreateFrame("Frame", nil, d, "BackdropTemplate")
        ebFrame:SetPoint("TOPLEFT",  d, "TOPLEFT",  14, -62)
        ebFrame:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -62)
        ebFrame:SetHeight(90)
        ebFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileEdge=true, edgeSize=10,
            insets={left=3,right=3,top=3,bottom=3},
        })
        ebFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
        ebFrame:SetBackdropBorderColor(0.45, 0.38, 0.16, 1)

        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetPoint("TOPLEFT",     ebFrame, "TOPLEFT",     5, -5)
        eb:SetPoint("BOTTOMRIGHT", ebFrame, "BOTTOMRIGHT", -5,  5)
        eb:SetMultiLine(false)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        d._eb = eb

        local confirmBtn = UI.CreateButton(d, L("hubsettings_import_confirm_btn") or "Importieren", 160, 26)
        confirmBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 12)
        confirmBtn:SetScript("OnClick", function()
            local data, err = ST.Decode(d._eb:GetText())
            if not data then
                d._statusFS:SetText("|cffff4444" .. tostring(err) .. "|r")
                return
            end
            d:Hide()
            HubSettings:_ShowConfirm(
                L("hubsettings_import_confirm_title") or "Statistiken importieren?",
                L("hubsettings_import_confirm_body")  or
                    "Aktuelle Statistiken werden überschrieben. Fortfahren?",
                function()
                    ST.ApplyImport(data)
                    d._eb:SetText("")
                    d._statusFS:SetText("")
                end
            )
        end)

        local cancelBtn = UI.CreateButton(d, L("hubsettings_import_cancel") or "Abbrechen", 120, 26)
        cancelBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 12)
        cancelBtn:SetScript("OnClick", function()
            d._eb:SetText("")
            d._statusFS:SetText("")
            d:Hide()
        end)

        self._importPopup = d
    end

    self._importPopup._eb:SetText("")
    self._importPopup._statusFS:SetText("")
    self._importPopup:Show()
    C_Timer.After(0, function()
        if self._importPopup._eb then self._importPopup._eb:SetFocus() end
    end)
end

-- ============================================================
-- STATISTIKEN ZURÜCKSETZEN
-- ============================================================

function HubSettings:_ResetStats()
    ST.Reset()

    GH_LogInfo("HubSettings", "Statistiken wurden zurückgesetzt.")

    local TM = ArcadiaNexus.ToastManager
    if TM and TM.Show then
        pcall(function()
            TM:Show({
                icon     = "Interface\\Icons\\Achievement_General_StayClassy",
                title_de = "Statistiken zurückgesetzt",
                title_en = "Statistics Reset",
                desc_de  = "Alle Statistiken wurden auf Startwerte gesetzt.",
                desc_en  = "All statistics have been reset.",
            })
        end)
    end
end

-- ============================================================
-- REGISTRY
-- ============================================================

ArcadiaNexus.RegisterHubSettingsTab({
    id            = "STATS",
    labelKey      = "hubsettings_tab_stats",
    labelFallback = "Statistiken",
    order         = 30,
    buildContent  = function(parent)
        HubSettings:_BuildTabStats(parent)
    end,
})
