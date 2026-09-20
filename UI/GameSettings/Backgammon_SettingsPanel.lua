local A = ArcadiaNexus
local function Build(parent)
    local S, GS, L = A.BG_Settings, A.GameSettings, A.GetLocaleTable("BACKGAMMON")
    local function Refresh() if A.BG_Renderer then A.BG_Renderer:Render() end end
    GS.Build(parent, {
        settings = S, locale = L, layout = "standard",
        sound = { single = true, masterLabel = L.sound_enabled },
        theme = { dropdown = { label = L.box_theme, key = "theme",
            options = { {key = "walnut", label = L.theme_walnut}, {key = "midnight", label = L.theme_midnight} },
            onChange = Refresh } },
        guide = { minHeight = 180, sections = { GS.GuideSection(nil, L, {
            "guide_goal", "guide_moves", "guide_bar", "guide_off", "guide_confirm", "guide_mp" }) } },
        onReset = Refresh,
    })
end
A.SettingsPanel = A.SettingsPanel or {}
A.SettingsPanel._builders = A.SettingsPanel._builders or {}
A.SettingsPanel._builders.BACKGAMMON = Build
