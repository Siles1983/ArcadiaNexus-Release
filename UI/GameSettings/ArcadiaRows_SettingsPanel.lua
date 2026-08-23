--[[
    ArcadiaRows – Settings Panel
    Layout: Sound | Symbole + Anleitung
]]

local SB = ArcadiaNexus.SymbolBackgroundSettings
local GS = ArcadiaNexus.GameSettings

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
                    "guide_1", "guide_2", "guide_3", "guide_4", "guide_5",
                }),
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
