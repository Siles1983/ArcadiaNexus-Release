--[[
    TavernCards – Settings Panel
    GS.Build, stackTheme: Sound (volle Breite), Theme, Anleitung, Hausregeln.
    Zufälliger Charakter ist ein Eintrag im Charakter-Dropdown und setzt randomPlayerCharacter.
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI
local RANDOM_CHARACTER = "random"

local function BuildTavernCardsSettingsPanel(parent)
    local S = ArcadiaNexus.TC_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("TAVERNCARDS") or {}

    local guideLines={L.guide_1,L.guide_2,L.guide_3,L.guide_4,L.guide_5,L.guide_stack_challenge,L.guide_closing,L.guide_save,L.guide_mp}
    local guideCfg={title=L.box_guide,sections={{lines=guideLines}}}
    local totalW=GS.GetTotalWidth(parent)
    parent._tcGuideMeasure=parent._tcGuideMeasure or parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    local measure=parent._tcGuideMeasure; measure:SetWidth(totalW-UI.PAD*2); measure:Hide()
    local wrappedHeight=48
    for _,line in ipairs(guideLines) do measure:SetText(line); wrappedHeight=wrappedHeight+measure:GetStringHeight()+3 end
    guideCfg.minHeight=wrappedHeight

    local charOpts={{key=RANDOM_CHARACTER,label=L.random_character}}
    for _,opt in ipairs(ArcadiaNexus.TC_NpcData:GetDropdownOptions()) do
        charOpts[#charOpts+1]=opt
    end
    local function charGet()
        if S:Get("randomPlayerCharacter") then return RANDOM_CHARACTER end
        return S:Get("playerCharacter")
    end
    local function charSet(key)
        if key==RANDOM_CHARACTER then
            S:Set("randomPlayerCharacter", true)
        else
            S:Set("randomPlayerCharacter", false)
            S:Set("playerCharacter", key)
        end
    end

    GS.Build(parent, {
        settings   = S,
        locale     = L,
        stackTheme = true,
        sound = {
            title       = L.box_sounds,
            masterLabel = L.sound_enabled,
            rowSpacing  = 22,
            items = {
                { key = "soundOnPlay",    label = L.sound_play    },
                { key = "soundOnDraw",    label = L.sound_draw    },
                { key = "soundOnSpecial", label = L.sound_special },
                { key = "soundOnWin",     label = L.sound_win     },
                { key = "soundOnLose",    label = L.sound_lose    },
            },
        },
        theme = {
            title = L.box_theme,
            dropdown = {
                label   = L.lbl_theme,
                key     = "theme",
                options = {
                    { key = "neutral",  label = L.theme_neutral  },
                    { key = "alliance", label = L.theme_alliance },
                    { key = "horde",    label = L.theme_horde    },
                },
            },
            build = function(content, width, _, yOff, measureOnly)
                local extraH = 52 + 48
                if measureOnly then return extraH end
                local ddW = width - UI.PAD * 2 - 24
                local charDD = UI.CreateSimpleDropdown(content, 0, yOff, ddW,
                    L.lbl_character, charOpts, charGet, charSet)
                if GS.TrackDropdown then GS.TrackDropdown(content, charDD, charGet) end
                local displayItems={
                    {key="showCardTooltips",label=L.show_card_tooltips},
                    {key="showHouseRulesButton",label=L.show_house_rules_button},
                }
                for index,item in ipairs(displayItems) do
                    local cb=UI.CreateCheckbox(content,item.label,0,yOff+52+(index-1)*24)
                    cb:SetChecked(S:Get(item.key)~=false)
                    cb:SetScript("OnClick",function(self) S:Set(item.key,self:GetChecked() and true or false) end)
                    GS.TrackCheckbox(content,cb,S,item.key,"notfalse")
                end
                return extraH
            end,
        },
        guide = guideCfg,
        extraBoxes = {
            {
                title  = L.box_rules,
                height = 160,
                build  = function(c)
                    local ruleItems = {
                        { key = "stackDraw2",     label = L.rule_stack2     },
                        { key = "stackDraw4",     label = L.rule_stack4     },
                        { key = "playDrawn",      label = L.rule_play_drawn },
                        { key = "unoCallRule",    label = L.rule_uno        },
                        { key = "challengeDraw4", label = L.rule_challenge  },
                    }
                    for i, item in ipairs(ruleItems) do
                        local cb = UI.CreateCheckbox(c, item.label, 0, (i - 1) * 24)
                        cb:SetChecked(S:GetRule(item.key))
                        if S:IsConfigurationLocked() then cb:Disable() else cb:Enable() end
                        cb:SetScript("OnClick", function(self)
                            S:SetRule(item.key, self:GetChecked())
                            self:SetChecked(S:GetRule(item.key) and true or false)
                        end)
                        if GS.RegisterRefresh then
                            GS.RegisterRefresh(c, function()
                                cb:SetChecked(S:GetRule(item.key) and true or false)
                                if S:IsConfigurationLocked() then cb:Disable() else cb:Enable() end
                            end)
                        end
                    end
                end,
            },
        },
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["TAVERNCARDS"] = BuildTavernCardsSettingsPanel
