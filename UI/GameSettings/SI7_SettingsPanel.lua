--[[
    Azeroth Intelligence (SI:7) – Settings Panel
    Layout: P2 (Sound full + Guide)
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function BuildSI7SettingsPanel(parent)
    local S = ArcadiaNexus.SI7_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SI7")

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            single      = true,
            masterLabel = L.sound_enabled,
        },
        guide = {
            sections = {
                GS.GuideSection(nil, L, {
                    "guide_goal", "guide_hotseat", "guide_clue",
                    "guide_guess", "guide_mp",
                }),
            },
        },
        extraBoxes = {
            {
                title = L.box_wordset,
                height = 96,
                build = function(content, innerW, settings)
                    local sets = ArcadiaNexus.SI7_WordSets
                    if not sets then return end
                    local getCurrent = function() return settings:Get("wordSet") end
                    local dd = UI.CreateSimpleDropdown(content, 0, 0, innerW - 24,
                        L.wordset_label, sets:GetOptions(), getCurrent,
                        function(id) settings:Set("wordSet", id) end,
                        { title = L.wordset_label, text = L.wordset_tooltip })
                    GS.TrackDropdown(content, dd, getCurrent)
                end,
            },
            {
                title = L.box_accessibility,
                height = 78,
                build = function(content, innerW, settings)
                    local cb = UI.CreateCheckbox(content, L.colorblind_symbols, 0, 0)
                    cb:SetChecked(settings:Get("colorblindSymbols") and true or false)
                    cb:SetScript("OnClick", function(self)
                        settings:Set("colorblindSymbols", self:GetChecked() and true or false)
                    end)
                    GS.TrackCheckbox(content, cb, settings, "colorblindSymbols")
                end,
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SI7"] = BuildSI7SettingsPanel
