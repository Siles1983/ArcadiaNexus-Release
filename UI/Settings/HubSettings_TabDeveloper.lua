--[[
    ArcadiaNexus – HubSettings Tab: Entwickler
    UI/Settings/HubSettings_TabDeveloper.lua

    Enthält:
        - _BuildTabDeveloper (DevMode Checkbox + Bestätigungs-Dialog)

    Abhängigkeiten:
        UI/Settings/HubSettings_Core.lua → ArcadiaNexus.HubSettings, _ShowConfirm
]]

local UI          = ArcadiaNexus.UI
local HubSettings = ArcadiaNexus.HubSettings

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key] or nil
end

-- ============================================================
-- TAB: ENTWICKLER (DevMode Checkbox)
-- ============================================================

function HubSettings:_BuildTabDeveloper(parent)
    local P = UI.BOX_PAD
    local devBox, devContent = UI.CreateBox(parent,
        L("hubsettings_dev_section") or "Entwickler",
        P, 0, 0, 120, P)

    local devDesc = devContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    devDesc:SetPoint("TOPLEFT", devContent, "TOPLEFT", 0, 0)
    devDesc:SetPoint("RIGHT",   devContent, "RIGHT",   0, 0)
    devDesc:SetJustifyH("LEFT")
    devDesc:SetWordWrap(true)
    devDesc:SetText(L("hubsettings_dev_devmode_desc") or
        "Aktiviert detaillierte Debug-Logs im Chat. Nur für Entwicklungszwecke.")
    devDesc:SetTextColor(0.75, 0.70, 0.55)

    local devCB = UI.CreateCheckbox(devContent,
        L("hubsettings_dev_devmode") or "Developer-Modus aktivieren", 0, 0)
    devCB:ClearAllPoints()
    devCB:SetPoint("TOPLEFT", devDesc, "BOTTOMLEFT", 0, -8)
    devCB:SetScript("OnClick", function(self)
        local newVal = self:GetChecked() and true or false
        self:SetChecked(not newVal)
        HubSettings:_ShowConfirm(
            newVal and (L("devmode_confirm_enable_title")  or "Developer-Modus aktivieren?")
                   or  (L("devmode_confirm_disable_title") or "Developer-Modus deaktivieren?"),
            newVal and (L("devmode_confirm_enable_body")   or
                "Der Developer-Modus ist ausschließlich für Entwickler bestimmt. Das Addon wird neu geladen.")
                   or  (L("devmode_confirm_disable_body")  or
                "Developer-Modus deaktivieren? Das Addon wird neu geladen."),
            function()
                if not ArcadiaNexusDB.dev then ArcadiaNexusDB.dev = {} end
                ArcadiaNexusDB.dev.devMode = newVal
                ReloadUI()
            end
        )
    end)
    self._devModeCB = devCB
end

-- ============================================================
-- REGISTRY
-- ============================================================

ArcadiaNexus.RegisterHubSettingsTab({
    id            = "DEVELOPER",
    labelKey      = "hubsettings_tab_developer",
    labelFallback = "Entwickler",
    order         = 40,
    buildContent  = function(parent)
        HubSettings:_BuildTabDeveloper(parent)
    end,
})
