--[[
    UI/HubTabs/HubTab_Profil.lua
    Registriert den PROFIL Bottom-Tab (full-width Stats-Panel).
]]

local function L(key)
    local tbl = ArcadiaNexus.GetLocaleTable("UI")
    return tbl and tbl[key]
end

ArcadiaNexus.RegisterHubTab({
    id                = "PROFIL",
    labelKey          = "tab_profil",
    order             = 40,
    hasSidebar        = false,
    externalPanelKey  = "profil",

    getContentLabel = function(state)
        return L("tab_profil") or "Profil"
    end,

    onBuild = function(main, F)
        if not ArcadiaNexus.StatsUI or not ArcadiaNexus.StatsUI.BuildPanel then
            return
        end
        local profilPanel = ArcadiaNexus.StatsUI:BuildPanel(main)
        local Layout = ArcadiaNexus.Layout
        local px, py, brx, bry = Layout.GetFullWidthPanelAnchors()
        profilPanel:SetPoint("TOPLEFT",     main, "TOPLEFT",   px, py)
        profilPanel:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", brx, bry)
        F.profil = profilPanel
    end,

    onSelect = function(tab, prevTab)
        if ArcadiaNexus.StatsUI then
            pcall(function() ArcadiaNexus.StatsUI:Show() end)
        end
    end,
})
