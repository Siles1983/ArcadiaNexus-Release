--[[
    AlchemistsSort – Settings Panel
    Layout: P2 (Sound full + Guide) via GameSettingsBuilder
    Level-Info als zweite Guide-Sektion
]]

local GS = ArcadiaNexus.GameSettings
local UI = ArcadiaNexus.UI

local function MeasureGuide(parent, sections)
    if not parent or not parent.CreateFontString or not GS.GetTotalWidth or not UI then return nil end
    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not measure or not measure.SetWidth then return nil end
    measure:SetWidth(GS.GetTotalWidth(parent) - UI.PAD * 2)
    measure:SetWordWrap(true)
    -- Title chrome (32) plus a small bottom pad. A 64px start stays above this text.
    local guideHeight = 48
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

local function BuildAlchemistsSortSettingsPanel(parent)
    local S = ArcadiaNexus.ALS_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable("ALCHEMISTSSORT")

    local sections = {
        GS.GuideSection(nil, L, {
            "guide_1", "guide_2", "guide_3", "guide_4",
            "guide_5", "guide_6", "guide_7", "guide_8", "guide_9", "guide_10",
        }),
        GS.GuideSection(L.box_level_info, L, {
            "level_info_1", "level_info_2", "level_info_3",
            "level_info_4", "level_info_5", "level_info_6",
        }, 15),
    }
    local guide = { sections = sections }
    local measured = MeasureGuide(parent, sections)
    if measured then
        guide.minHeight = measured
        if GS.ComputeGuideBoxHeight(guide) > measured then guide.fitContent = true end
    end

    GS.Build(parent, {
        settings  = S,
        locale    = L,
        layout    = "noTheme",
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 28,
            items = {
                { key = "soundOnPour",    label = L.sound_pour    },
                { key = "soundOnWin",     label = L.sound_win     },
                { key = "soundOnInvalid", label = L.sound_invalid },
            },
        },
        guide = guide,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["ALCHEMISTSSORT"] = BuildAlchemistsSortSettingsPanel
