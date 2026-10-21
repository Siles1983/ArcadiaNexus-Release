local A = ArcadiaNexus
local GS = A.GameSettings
local UI = A.UI

local function MeasureGuide(parent, sections)
    if not parent or not parent.CreateFontString or not GS.GetTotalWidth or not UI then return nil end
    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not measure or not measure.SetWidth then return nil end
    measure:SetWidth(GS.GetTotalWidth(parent) - UI.PAD * 2)
    measure:SetWordWrap(true)
    local guideHeight = 64
    for si, section in ipairs(sections) do
        if si > 1 and section.title and section.title ~= "" then
            measure:SetText(section.title)
            guideHeight = guideHeight + math.max(14, measure:GetStringHeight() or 14) + 8
        end
        for _, line in ipairs(section.lines or {}) do
            if line ~= nil and line ~= "" then
                measure:SetText(type(line) == "table" and (line.text or "") or line)
                guideHeight = guideHeight + math.max(14, measure:GetStringHeight() or 14) + 2
            end
        end
    end
    measure:Hide()
    return guideHeight
end

local function Build(parent)
    local L = A.GetLocaleTable("GALLYWIX")
    local sounds={}
    for _,item in ipairs(A.GWX_Sounds.catalog) do sounds[#sounds+1]={key=item.key,label=L[item.key]} end
    local section = GS.GuideSection(nil, L, { "guide_1", "guide_2", "guide_3", "guide_6", "guide_4", "guide_save" })
    local guide = { sections = { section } }
    local measured = MeasureGuide(parent, guide.sections)
    if measured then guide.minHeight = measured end
    GS.Build(parent, {
        settings = A.GWX_Settings, locale = L, layout = "noTheme",
        sound = { items = sounds, columns = 2, masterLabel = L.sound_off,
            masterInverted = true, preserveChecked = true },
        guide = guide,
        extraBoxes = {{title=L.box_rules,height=76,build=function(content,_,settings)
            local cb=A.UI.CreateCheckbox(content,"Gallywix",0,0)
            cb:SetChecked(settings:Get("gallywixEnabled")==true)
            cb:SetScript("OnClick",function(self) settings:Set("gallywixEnabled",self:GetChecked()==true) end)
            cb:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(L.gallywix_tooltip,nil,nil,nil,nil,true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave",function() GameTooltip:Hide() end)
            local function refresh()
                local E=A.GWX_Engine
                local active=E and E.gameState
                cb:SetChecked(active and active.gallywixEnabled==true or not active and settings:Get("gallywixEnabled")==true)
                if settings:IsConfigLocked() then cb:Disable() else cb:Enable() end
            end
            GS.RegisterRefresh(content,refresh); refresh()
        end}},
    })
    if parent.HookScript and GS.RefreshPanel then parent:HookScript("OnShow",function() GS.RefreshPanel(parent) end) end
end
A.SettingsPanel._builders["GALLYWIX"] = Build
