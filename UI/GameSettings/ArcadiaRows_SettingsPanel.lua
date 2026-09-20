--[[
    ArcadiaRows – Settings Panel
    Layout: Sound | Symbole + Anleitung + Anzeige
]]

local SB = ArcadiaNexus.SymbolBackgroundSettings
local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function BuildArcadiaRowsSettingsPanel(parent)
    local S = ArcadiaNexus.AR_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")

    SB.Build(parent, {
        settings = S,
        locale   = L,
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5", "guide_6", "guide_7", "guide_8", "guide_9", "guide_10",
                }),
            },
        },
        extraBoxes = {
            {
                title  = L.box_display or "Anzeige",
                height = 78,
                build = function(content, _w, settings)
                    local cb = UI.CreateCheckbox(content, L.opt_instant_drops or "Steine sofort setzen", 0, 0)
                    cb:SetChecked(settings:Get("instantDrops") and true or false)
                    cb:SetScript("OnClick", function(self)
                        settings:Set("instantDrops", self:GetChecked() and true or false)
                    end)
                    GS.TrackCheckbox(parent, cb, settings, "instantDrops")
                    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -28)
                    hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -28)
                    hint:SetJustifyH("LEFT")
                    hint:SetText(L.opt_instant_hint or "")
                    hint:SetTextColor(0.80, 0.75, 0.60)
                end,
            },
            {
                title  = L.box_rules or "Regeln",
                height = 78,
                build = function(content, _w, settings)
                    local cb = UI.CreateCheckbox(content, L.opt_pop_out or "Pop-out", 0, 0)
                    cb:SetChecked(settings:Get("popOut") and true or false)
                    cb:SetScript("OnClick", function(self)
                        settings:Set("popOut", self:GetChecked() and true or false)
                    end)
                    GS.TrackCheckbox(parent, cb, settings, "popOut")
                    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -28)
                    hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -28)
                    hint:SetJustifyH("LEFT")
                    hint:SetText(L.opt_pop_out_hint or "")
                    hint:SetTextColor(0.80, 0.75, 0.60)
                end,
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
if ArcadiaNexus.SettingsPanel.RegisterBuilder then
    ArcadiaNexus.SettingsPanel.RegisterBuilder("ARCADIAROWS", BuildArcadiaRowsSettingsPanel)
else
    ArcadiaNexus.SettingsPanel._builders["ARCADIAROWS"] = BuildArcadiaRowsSettingsPanel
end
