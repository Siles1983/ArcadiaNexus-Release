--[[
    TavernCards – Settings Panel
    Layout: P13 (2×2-Grid) via GameSettingsBuilder.BuildGrid2x2
      Reihe 1: Sound | Hausregeln
      Reihe 2: Theme | Anleitung
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function BuildTavernCardsSettingsPanel(parent)
    local S = ArcadiaNexus.TC_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("TAVERNCARDS") or {}

    GS.BuildGrid2x2(parent, {
        settings    = S,
        locale      = L,
        row1Height  = 180,
        row2Height  = 180,
        boxes = {
            tl = {
                title = L.box_sounds,
                build = function(c)
                    GS.BuildSoundSection(c, S, L, {
                        masterLabel = L.sound_enabled,
                        rowSpacing  = 22,
                        items = {
                            { key = "soundOnPlay",    label = L.sound_play    },
                            { key = "soundOnDraw",    label = L.sound_draw    },
                            { key = "soundOnSpecial", label = L.sound_special },
                            { key = "soundOnWin",     label = L.sound_win     },
                            { key = "soundOnLose",    label = L.sound_lose    },
                        },
                    })
                end,
            },
            tr = {
                title = L.box_rules,
                build = function(c)
                    local settings = S:GetAll()
                    local ruleItems = {
                        { key = "stackDraw2",     label = L.rule_stack2     },
                        { key = "stackDraw4",     label = L.rule_stack4     },
                        { key = "playDrawn",      label = L.rule_play_drawn },
                        { key = "unoCallRule",    label = L.rule_uno        },
                        { key = "challengeDraw4", label = L.rule_challenge  },
                    }
                    for i, item in ipairs(ruleItems) do
                        local cb = UI.CreateCheckbox(c, item.label, 0, (i - 1) * 24)
                        cb:SetChecked(settings.rules[item.key])
                        cb:SetScript("OnClick", function(self)
                            S:SetRule(item.key, self:GetChecked())
                        end)
                        if GS.RegisterRefresh then
                            GS.RegisterRefresh(c, function()
                                cb:SetChecked(S:GetRule(item.key) and true or false)
                            end)
                        end
                    end
                end,
            },
            bl = {
                title = L.box_theme,
                build = function(c, innerW)
                    local settings = S:GetAll()
                    local themeGet = function() return S:Get("theme") end
                    local themeDD = UI.CreateSimpleDropdown(c, 0, 0, innerW - 24,
                        L.lbl_theme,
                        {
                            { key = "neutral",  label = L.theme_neutral  },
                            { key = "alliance", label = L.theme_alliance },
                            { key = "horde",    label = L.theme_horde    },
                        },
                        themeGet,
                        function(key) S:Set("theme", key) end
                    )
                    if GS.TrackDropdown then GS.TrackDropdown(c, themeDD, themeGet) end

                    local charOpts = {}
                    for _, opt in ipairs(ArcadiaNexus.TC_NpcData:GetDropdownOptions()) do
                        charOpts[#charOpts + 1] = opt
                    end
                    local charGet = function() return S:Get("playerCharacter") end
                    local charDD = UI.CreateSimpleDropdown(c, 0, 52, innerW - 24,
                        L.lbl_character, charOpts,
                        charGet,
                        function(key) S:Set("playerCharacter", key) end
                    )
                    if GS.TrackDropdown then GS.TrackDropdown(c, charDD, charGet) end

                    local cbRandom = UI.CreateCheckbox(c, L.random_character, 0, 104)
                    cbRandom:SetChecked(settings.randomPlayerCharacter)
                    local function syncCharDropdown()
                        local disabled = cbRandom:GetChecked()
                        if charDD.SetEnabled then charDD:SetEnabled(not disabled) end
                    end
                    syncCharDropdown()
                    cbRandom:SetScript("OnClick", function(self)
                        S:Set("randomPlayerCharacter", self:GetChecked())
                        syncCharDropdown()
                    end)
                    if GS.TrackCheckbox then
                        GS.TrackCheckbox(c, cbRandom, S, "randomPlayerCharacter")
                    end
                    if GS.RegisterRefresh then
                        GS.RegisterRefresh(c, syncCharDropdown)
                    end
                end,
            },
            br = {
                title = L.box_guide,
                build = function(c)
                    UI.CreateGuideText(c, {
                        L.guide_1, L.guide_2, L.guide_3, L.guide_4, L.guide_5,
                    })
                end,
            },
        },
        rebuild = BuildTavernCardsSettingsPanel,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["TAVERNCARDS"] = BuildTavernCardsSettingsPanel
