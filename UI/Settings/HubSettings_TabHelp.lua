-- Dünne Registry-Anbindung; Suche und Artikel leben im Kompendium-Helper.
ArcadiaNexus.RegisterHubSettingsTab({
    id = "HELP",
    labelFallback = (GetLocale and GetLocale() == "deDE") and "Kompendium" or "Compendium",
    order = 35,
    buildContent = function(parent)
        ArcadiaNexus.Compendium.BuildPanel(parent)
    end,
    refreshLayout = function(hs, width)
        ArcadiaNexus.Compendium.RefreshLayout(hs._tabFrames.HELP, width)
    end,
})
