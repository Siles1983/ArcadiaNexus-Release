--[[
    Azeroth Intelligence (SI:7) – Settings Panel
    Layout: shared sound-first (Sound, Guide, puzzle language, card theme, accessibility)
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function BuildSI7SettingsPanel(parent)
    local S = ArcadiaNexus.SI7_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("SI7")

    local section = GS.GuideSection(nil,L,{
        "guide_goal","guide_solo","guide_ai_beta","guide_ai_theme","guide_roles",
        "guide_hotseat","guide_clue","guide_guess","guide_mp",
    })
    local measure = parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    local textWidth = GS.GetTotalWidth(parent) - UI.PAD*2
    measure:SetWidth(textWidth)
    measure:SetWordWrap(true)
    local guideHeight = 64
    for _, line in ipairs(section.lines) do
        measure:SetText(line)
        guideHeight = guideHeight + math.max(14,measure:GetStringHeight()) + 2
    end
    measure:Hide()
    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            single      = true,
            masterLabel = L.sound_enabled,
        },
        guideFirst = false,
        guide = { minHeight=guideHeight, sections={section} },
        extraBoxes = {
            {
                title=L.solo_language, height=96,
                build=function(content,innerW,settings)
                    local getCurrent=function() return settings:Get("puzzleLocale") end
                    local dd=UI.CreateSimpleDropdown(content,0,0,innerW-24,L.solo_language,{
                        {key="deDE",label="Deutsch"},{key="enUS",label="English"},
                    },getCurrent,function(v) settings:Set("puzzleLocale",v) end)
                    GS.TrackDropdown(content,dd,getCurrent,function() dd:SetEnabled(not settings:IsConfigLocked()) end)
                end,
            },
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
                    GS.TrackDropdown(content, dd, getCurrent, function() dd:SetEnabled(not settings:IsConfigLocked()) end)
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
    -- Cached panels must reflect current session locks whenever shown again.
    parent:HookScript("OnShow", function() GS.RefreshPanel(parent) end)
    GS.RefreshPanel(parent)
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["SI7"] = BuildSI7SettingsPanel
