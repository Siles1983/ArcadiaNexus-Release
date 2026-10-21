--[[
    Azeroth's Tiny Guardians – Settings Panel
    Layout: Sound | Visuals + Guide via BuildSoundVisualGuide
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

local function BuildATGSettingsPanel(parent)
    local S = ArcadiaNexus.ATG_Settings
    if not S then return end
    local L = ArcadiaNexus.GetLocaleTable and ArcadiaNexus.GetLocaleTable("AZEROTHTINYGUARDIANS") or {}

    local sections = {
        GS.GuideSection(nil, L, {
            "guide_1", "guide_2", "guide_3", "guide_4",
            "guide_5", "guide_6", "guide_7", "guide_8",
        }),
    }
    local guide = { sections = sections }
    local measured = MeasureGuide(parent, sections)
    if measured then
        guide.minHeight = measured
        if GS.ComputeGuideBoxHeight(guide) > measured then guide.fitContent = true end
    end

    GS.BuildSoundVisualGuide(parent, {
        settings = S,
        locale   = L,
        sound = {
            masterLabel = L.sound_enabled,
            rowSpacing  = 26,
            items = {
                { key = "soundOnInteract", label = L.sound_interact },
                { key = "soundOnEvolve",   label = L.sound_evolve   },
                { key = "soundOnComment",  label = L.sound_comment  },
            },
        },
        visuals = {
            title = L.box_visual,
            items = {
                { key = "showSpeechBubble", label = L.lbl_show_bubbles },
                { key = "showEmotes",       label = L.lbl_show_emotes  },
            },
        },
        guide = guide,
    })
end

ArcadiaNexus.SettingsPanel           = ArcadiaNexus.SettingsPanel or {}
ArcadiaNexus.SettingsPanel._builders = ArcadiaNexus.SettingsPanel._builders or {}
ArcadiaNexus.SettingsPanel._builders["AZEROTHTINYGUARDIANS"] = BuildATGSettingsPanel
