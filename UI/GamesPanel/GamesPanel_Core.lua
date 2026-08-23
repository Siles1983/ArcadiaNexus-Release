--[[
    ArcadiaNexus – GamesPanel Core
    UI/GamesPanel/GamesPanel_Core.lua

    Enthält:
        - Frame-Referenzen (Dependency Injection)
        - Lokale Modul-Aliase
        - ShouldShowGame (Filter-Helper)
        - BuildSidebarPanel (gemeinsamer Panel-Builder, exportiert als ArcadiaNexus.UI.BuildSidebarPanel)
        - Exports der vier Build*CategoryPanel-Funktionen

    Abhängigkeiten (müssen vor diesem Modul geladen sein):
        UI/GamesPanel/FavoritesManager.lua    → ArcadiaNexus.UI.FavMgr
        UI/GamesPanel/CategoryBuilder.lua     → ArcadiaNexus.UI.GetCategoryGroups
        UI/GamesPanel/StarButton.lua          → ArcadiaNexus.UI.MakeStarButton
        UI/GamesPanel/SidebarFrameFactory.lua → ArcadiaNexus.UI.UpdateScrollbar / BuildCategoryPanelFrame
        UI/GamesPanel/CategoryHeader.lua      → ArcadiaNexus.UI.BuildGroupHeader
        UI/GamesPanel/CategoryButton.lua      → ArcadiaNexus.UI.BuildGameButton
        UI/GamesPanel/EmptyState.lua          → ArcadiaNexus.UI.HandleFavEmptyHint
        UI/GamesPanel/FavoritesRebuilder.lua  → ArcadiaNexus.UI.RebuildFavButtons
        UI/Core/TabsController.lua            → NexusTabs, NexusTabState
        UI/Core/ContentPanel.lua              → CreateNexusScrollbar

    Exportiert:
        ArcadiaNexus.UI.SetGamesPanelFrameRefs
        ArcadiaNexus.UI.BuildSidebarPanel
        ArcadiaNexus.UI.BuildCategoryPanel            (gesetzt von GamesPanel_Games.lua)
        ArcadiaNexus.UI.BuildSettingsCategoryPanel    (gesetzt von GamesPanel_Settings.lua)
        ArcadiaNexus.UI.BuildLeaderboardCategoryPanel (gesetzt von GamesPanel_Leaderboard.lua)
        ArcadiaNexus.UI.BuildAchievementCategoryPanel (gesetzt von GamesPanel_Achievements.lua)
        ArcadiaNexus.UI.ActivateAchCategory           (gesetzt von GamesPanel_Achievements.lua)
]]

-- Frame-Referenzen (Dependency Injection aus ArcadiaNexus_UI.lua)
local F = {}
function ArcadiaNexus.UI.SetGamesPanelFrameRefs(refs) F = refs end

-- Export-Getter damit Panel-Submodule auf F zugreifen können
function ArcadiaNexus.UI.GetGamesPanelFrameRefs() return F end

-- L lazy (GamesPanel_Core lädt vor Language.lua)
local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

-- Modul-Aliase
local function FavMgr()                        return ArcadiaNexus.UI.FavMgr end
local function GetCategoryGroups(inc)          return ArcadiaNexus.UI.GetCategoryGroups(inc) end
local function UpdateScrollbar(sf, sc)         return ArcadiaNexus.UI.UpdateScrollbar(sf, sc) end
local function BuildCategoryPanelFrame(p,n,s)  return ArcadiaNexus.UI.BuildCategoryPanelFrame(p, n, s) end
local function BuildGroupHeader(sc,grp,ak,hk,fn) return ArcadiaNexus.UI.BuildGroupHeader(sc, grp, ak, hk, fn) end
local function BuildGameButton(sc, game, pfx)  return ArcadiaNexus.UI.BuildGameButton(sc, game, pfx) end
local function HandleFavEmptyHint(grp,sc,y,ab,hk,hfn) return ArcadiaNexus.UI.HandleFavEmptyHint(grp, sc, y, ab, hk, hfn) end
local function RebuildFavButtons(sc,pfx,bk,cFn,cFn2,bl) return ArcadiaNexus.UI.RebuildFavButtons(sc, pfx, bk, cFn, cFn2, bl) end

-- ============================================================
-- FILTER-HELPER (Sidebar-Suche → GameRegistry.ShouldShowGame)
-- ============================================================

local function ShouldShowGame(game)
    local GR = ArcadiaNexus.GameRegistry
    if GR and GR.ShouldShowGame then
        return GR.ShouldShowGame(game, GR.FILTER_SIDEBAR)
    end
    return true
end

ArcadiaNexus.UI.ShouldShowGame = ShouldShowGame

-- ============================================================
-- INTERN: Gemeinsamer Sidebar-Panel-Builder
-- ============================================================
--[[
    cfg = {
        frameName        string   -- CreateFrame-Name für cp
        scrollName       string   -- CreateFrame-Name für sf
        groupStatePrefix string   -- Präfix für categoryGroupState-Keys ("", "lb_", "ach_")
        includeGeneral   bool     -- true → GetCategoryGroups(true) (Achievements)
        arrowKey         string   -- Schlüssel im grp-Table für Pfeil-Textur
        hdrKey           string   -- Schlüssel im grp-Table für Header-Button
        grpFramePrefix   string   -- Präfix für Gruppen-Frame-Name ("NexusCatGrp_", ...)
        btnPrefix        string   -- Präfix für Spiel-Button-Name ("NexusCategoryBtn_", ...)
        gameBtnsKey      string   -- Schlüssel im grp-Table für Spiel-Button-Liste
        emptyHintKey     string   -- Schlüssel im grp-Table für Leerhinweis
        favBtnPrefix     string   -- Präfix für Fav-Rebuild-Buttons
        btnListRef       table    -- F.<x>CatBtns (wird gefüllt)
        getActiveId      fn()     -- gibt aktive catID zurück
        setActiveId      fn(id)   -- setzt aktive catID
        activateCallback fn(id)   -- volles Activate (State + UI)
        onEnterTooltipKey fn(id)  -- optional: Tooltip-Key-Funktion für OnEnter
        initialHide      bool     -- ob cp nach Aufbau versteckt wird (default true)
        afterBuild       fn(cp,sf,sc,groups,RelayoutAll)  -- optional: mode-spezifische Extras
    }
]]
local function BuildSidebarPanel(parent, cfg)
    local cp, sf, sc = BuildCategoryPanelFrame(parent, cfg.frameName, cfg.scrollName)
    local groups     = GetCategoryGroups(cfg.includeGeneral)
    local favEmptyHintFrame = cfg.favEmptyHintFrame or (cfg.grpFramePrefix .. "FAV_EMPTY")

    local function GetEmptyHintFrame()
        return _G[favEmptyHintFrame]
    end

    local function HideEmptyHintFrame()
        local hint = GetEmptyHintFrame()
        if hint then hint:Hide() end
    end

    if sc and sc.GetChildren then
        local children = { sc:GetChildren() }
        for i = 1, #children do
            children[i]:Hide()
        end
    end

    local prefix = cfg.groupStatePrefix or ""

    local function GetGroupOpen(id)
        local db = ArcadiaNexusDB and ArcadiaNexusDB.categoryGroupState
        if db and db[prefix .. id] ~= nil then return db[prefix .. id] end
        return true
    end
    local function SetGroupOpen(id, val)
        if ArcadiaNexusDB and ArcadiaNexusDB.categoryGroupState then
            ArcadiaNexusDB.categoryGroupState[prefix .. id] = val
        end
    end

    local function RelayoutAll()
        HideEmptyHintFrame()

        local yOff = 0
        for _, grp in ipairs(groups) do
            local open = GetGroupOpen(grp.id)

            -- Prüfen ob die Gruppe nach Filter überhaupt sichtbare Buttons hat
            local anyVisible = false
            for _, gbtn in ipairs(grp[cfg.gameBtnsKey] or {}) do
                if ShouldShowGame({ id = gbtn.catID, label = gbtn._labelText }) then
                    anyVisible = true
                    break
                end
            end

            -- Favoriten-Gruppe: immer zeigen (auch leer, wegen EmptyHint)
            if grp.isFavGrp then anyVisible = true end

            if not anyVisible then
                -- ganzen Gruppen-Header + Buttons verstecken
                grp[cfg.hdrKey]:Hide()
                for _, gbtn in ipairs(grp[cfg.gameBtnsKey] or {}) do gbtn:Hide() end
                if grp.isFavGrp then HideEmptyHintFrame() end
            else
                grp[cfg.hdrKey]:ClearAllPoints()
                grp[cfg.hdrKey]:SetPoint("TOP", sc, "TOP", 0, -yOff)
                grp[cfg.hdrKey]:Show()
                yOff = yOff + 26
                if open then
                    local anyBtn = false
                    for _, gbtn in ipairs(grp[cfg.gameBtnsKey] or {}) do
                        local show = ShouldShowGame({ id = gbtn.catID, label = gbtn._labelText })
                        if show then
                            gbtn:ClearAllPoints()
                            gbtn:SetPoint("TOP", sc, "TOP", 0, -yOff)
                            gbtn:Show()
                            yOff = yOff + 24
                            anyBtn = true
                            if gbtn._star and gbtn._star.RefreshStar then gbtn._star.RefreshStar() end
                        else
                            gbtn:Hide()
                        end
                    end
                    yOff = HandleFavEmptyHint(grp, sc, yOff, anyBtn, cfg.emptyHintKey, favEmptyHintFrame)
                else
                    for _, gbtn in ipairs(grp[cfg.gameBtnsKey] or {}) do gbtn:Hide() end
                    if grp.isFavGrp then HideEmptyHintFrame() end
                end
            end
            yOff = yOff + 2
        end
        sc:SetHeight(math.max(yOff, 1))
        UpdateScrollbar(sf, sc)
    end

    -- SearchBox einbauen wenn gewünscht (Games, LB, ACH – nicht Settings)
    cp._relayout = RelayoutAll
    if cfg.withSearchBar then
        if cfg.relayoutKey then
            ArcadiaNexus.UI[cfg.relayoutKey] = RelayoutAll
        end
        ArcadiaNexus.UI.CreateSidebarSearchBox(cp, sf, function()
            if cp._relayout then cp._relayout() end
        end)
    end

    -- Gruppen aufbauen
    for _, grp in ipairs(groups) do
        grp[cfg.gameBtnsKey] = {}
        local hdr = BuildGroupHeader(sc, grp, cfg.arrowKey, cfg.hdrKey, cfg.grpFramePrefix .. grp.id)

        hdr:SetScript("OnClick", function()
            SetGroupOpen(grp.id, not GetGroupOpen(grp.id))
            RelayoutAll()
            for _, g in ipairs(groups) do
                g[cfg.arrowKey]:SetRotation(GetGroupOpen(g.id) and math.pi or math.pi/2)
            end
        end)

        -- Favoriten-Gruppe: eigener Präfix, sonst teilt sich der benannte
        -- Button-Frame mit dem Kategorie-Eintrag desselben Spiels
        local btnPrefix = grp.isFavGrp and cfg.favBtnPrefix or cfg.btnPrefix

        for _, game in ipairs(grp.games) do
            local btn = BuildGameButton(sc, game, btnPrefix)
            btn._labelText = game.label   -- für ShouldShowGame

            if cfg.onEnterTooltipKey then
                local ttKey = cfg.onEnterTooltipKey(game.id)
                btn:SetScript("OnEnter", function(self)
                    if NexusTooltip_Show then NexusTooltip_Show(self, nil, ttKey) end
                end)
                btn:SetScript("OnLeave", function(self)
                    if NexusTooltip_Hide then NexusTooltip_Hide() end
                end)
            end

            local function Refresh()
                local active = cfg.getActiveId() == btn.catID
                if active then
                    btn.activeBG:SetAlpha(1.0)
                    btn.accent:SetVertexColor(1.00, 0.82, 0.00, 1)
                    btn.lbl:SetTextColor(1.00, 1.00, 1.00)
                else
                    btn.activeBG:SetAlpha(0)
                    btn.accent:SetVertexColor(1.00, 0.82, 0.00, 0)
                    btn.lbl:SetTextColor(0.85, 0.78, 0.60)
                end
            end
            btn.Refresh = Refresh
            btn:SetScript("OnClick", function(self) cfg.activateCallback(self.catID) end)
            table.insert(cfg.btnListRef, btn)
            table.insert(grp[cfg.gameBtnsKey], btn)
        end
    end

    -- Initiale Pfeilausrichtung
    for _, grp in ipairs(groups) do
        grp[cfg.arrowKey]:SetRotation(GetGroupOpen(grp.id) and math.pi or math.pi/2)
    end

    -- Mode-spezifische Extras (ScrollFrame-Geometrie) vor finalem Relayout
    if cfg.afterBuild then
        cfg.afterBuild(cp, sf, sc, groups, RelayoutAll)
    end

    RelayoutAll()

    -- Kein initialer Button aktiv → Willkommens-Panel wird von BuildCategoryPanel gesetzt
    for _, b in ipairs(cfg.btnListRef) do b.Refresh() end

    -- Favoriten-Rebuild registrieren
    FavMgr():RegisterRebuild(function()
        if not cp then return end
        local favGrp = groups[1]
        if not favGrp or not favGrp.isFavGrp then return end
        for _, b in ipairs(favGrp[cfg.gameBtnsKey]) do b:Hide() end
        favGrp[cfg.gameBtnsKey] = {}
        RebuildFavButtons(
            sc, cfg.favBtnPrefix, favGrp[cfg.gameBtnsKey],
            function(id) return cfg.getActiveId() == id end,
            cfg.activateCallback, cfg.btnListRef
        )
        RelayoutAll()
        for _, b in ipairs(cfg.btnListRef) do b.Refresh() end
    end)

    if cfg.initialHide ~= false then cp:Hide() end
    return cp
end

-- Export des gemeinsamen Builders für alle Panel-Submodule
ArcadiaNexus.UI.BuildSidebarPanel = BuildSidebarPanel

-- ============================================================
-- EXPORT-PLATZHALTER (werden von den Panel-Submodulen gesetzt)
-- ============================================================
-- Reihenfolge: GamesPanel_Core.lua → Games/Settings/Leaderboard/Achievements.lua
ArcadiaNexus.UI.ActivateAchCategory           = nil  -- gesetzt von GamesPanel_Achievements.lua
ArcadiaNexus.UI.BuildCategoryPanel            = nil  -- gesetzt von GamesPanel_Games.lua
ArcadiaNexus.UI.BuildSettingsCategoryPanel    = nil  -- gesetzt von GamesPanel_Settings.lua
ArcadiaNexus.UI.BuildLeaderboardCategoryPanel = nil  -- gesetzt von GamesPanel_Leaderboard.lua
ArcadiaNexus.UI.BuildAchievementCategoryPanel = nil  -- gesetzt von GamesPanel_Achievements.lua
-- FavMgr wird direkt von FavoritesManager.lua exportiert (ArcadiaNexus.UI.FavMgr)

-- ============================================================
-- SIDEBAR-REBUILD (Late-Registration / Registry-Änderungen)
-- ============================================================

local RELAYOUT_KEYS = {
    "GamesPanelRelayout",
    "SettingsPanelRelayout",
    "LBPanelRelayout",
    "AchPanelRelayout",
}

local function ClearBtnList(list)
    if not list then return end
    for _, btn in ipairs(list) do
        if btn then
            btn:Hide()
        end
    end
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function DestroyPanel(panel)
    if not panel then return end
    panel:Hide()
end

function ArcadiaNexus.UI.RebuildCategorySidebars()
    local Frefs = ArcadiaNexus.UI.GetGamesPanelFrameRefs and ArcadiaNexus.UI.GetGamesPanelFrameRefs()
    if not Frefs or not Frefs.main then return end

    local parent = Frefs.main

    ClearBtnList(Frefs.catBtns)
    ClearBtnList(Frefs.settingsCatBtns)
    ClearBtnList(Frefs.lbCatBtns)
    ClearBtnList(Frefs.achCatBtns)

    DestroyPanel(Frefs.catPanel)
    DestroyPanel(Frefs.settingsCatPanel)
    DestroyPanel(Frefs.lbCatPanel)
    DestroyPanel(Frefs.achCatPanel)

    Frefs.catPanel         = nil
    Frefs.settingsCatPanel = nil
    Frefs.lbCatPanel       = nil
    Frefs.achCatPanel      = nil

    for _, key in ipairs(RELAYOUT_KEYS) do
        ArcadiaNexus.UI[key] = nil
    end

    local FM = ArcadiaNexus.UI.FavMgr
    if FM and FM.ClearRebuildCallbacks then
        FM:ClearRebuildCallbacks()
    end

    if ArcadiaNexus.UI.BuildCategoryPanel then
        ArcadiaNexus.UI.BuildCategoryPanel(parent)
    end
    if ArcadiaNexus.UI.BuildSettingsCategoryPanel then
        ArcadiaNexus.UI.BuildSettingsCategoryPanel(parent)
    end
    if ArcadiaNexus.UI.BuildLeaderboardCategoryPanel then
        ArcadiaNexus.UI.BuildLeaderboardCategoryPanel(parent)
    end
    if ArcadiaNexus.UI.BuildAchievementCategoryPanel then
        ArcadiaNexus.UI.BuildAchievementCategoryPanel(parent)
    end

    if NexusTabs and NexusTabs.RefreshPanelVisibility then
        NexusTabs.RefreshPanelVisibility()
    end
end

function ArcadiaNexus.UI.OnHubRegistryChanged()
    if not ArcadiaNexus.UI._hubUiInitialized then return end
    C_Timer.After(0, function()
        if ArcadiaNexus.UI.RebuildCategorySidebars then
            pcall(ArcadiaNexus.UI.RebuildCategorySidebars)
        end
    end)
end
