--[[
    ArcadiaNexus
    UI/GamesPanel/CategoryBuilder.lua

    Kategorie-Gruppen-Builder.
    Transformiert die Game-Registry in sortierte Kategorie-Gruppen
    für alle Sidebar-Panel (Games, Settings, Leaderboard, Achievements).

    Exportiert:
        ArcadiaNexus.UI.GetCategoryGroups(includeAllgemein) → groups[]

    Abhängigkeiten:
        Core/CategoryRegistry.lua           (ArcadiaNexus.CategoryRegistry)
        Core/GameRegistry.lua               (ArcadiaNexus.GameRegistry)
        UI/GamesPanel/FavoritesManager.lua  (ArcadiaNexus.UI.FavMgr)
        UI/Language.lua (lazy via L-Wrapper)
]]

local ArcadiaNexus = _G.ArcadiaNexus

-- L lazy (CategoryBuilder lädt vor Language.lua)
local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

local function FavMgr()
    return ArcadiaNexus.UI.FavMgr
end

local function CategoryRegistry()
    return ArcadiaNexus.CategoryRegistry
end

local function GameRegistry()
    return ArcadiaNexus.GameRegistry
end

local function ResolveCategoryLabel(catId)
    local CR = CategoryRegistry()
    if CR and CR.GetLabel then
        return CR.GetLabel(catId, function(key) return L(key) end)
    end
    return L("cat_" .. catId) or catId
end

--[[
    GetCategoryGroups(includeAllgemein)

    Gibt geordnete Liste von Kategorien mit ihren Spielen zurück:
    {
        { id="DENKSPIELE", label="Denkspiele", games={ {id, label}, ... } },
        ...
    }
    Favoriten-Gruppe steht immer an erster Stelle (Nutzer-Reihenfolge).
    Spiele innerhalb einer Kategorie: alphabetisch nach Label.
    Kategorien ohne Spiele werden nicht angezeigt.
    includeAllgemein = true → fügt ALLGEMEIN-Gruppe ein (für Achievements-Tab)
]]
local function GetCategoryGroups(includeAllgemein)
    local FM        = FavMgr()
    local groups    = {}
    local gameMap   = {}  -- catID -> { games }
    local gameInfo  = {}  -- id -> { id, label }
    local registry  = ArcadiaNexus.GameRegistry and ArcadiaNexus.GameRegistry.GetAll()
                      or {}

    for _, info in ipairs(registry) do
        local GR = GameRegistry()
        if GR and GR.IsVisible(info, GR.FILTER_SIDEBAR) then
            local catID = info.category or "SONSTIGE"
            gameMap[catID] = gameMap[catID] or {}
            table.insert(gameMap[catID], { id = info.id, label = info.label })
            gameInfo[info.id] = { id = info.id, label = info.label }
        end
    end

    -- ── Favoriten-Gruppe immer als erste ──────────────────────
    local favIds   = FM and FM:GetList() or {}
    local favGames = {}
    for _, id in ipairs(favIds) do
        if gameInfo[id] then
            table.insert(favGames, gameInfo[id])
        end
    end
    table.insert(groups, {
        id       = "FAVORITEN",
        label    = L("cat_FAVORITEN") or "Favoriten",
        games    = favGames,
        isFavGrp = true,
    })

    -- ── Allgemein-Gruppe (nur für Erfolge-Tab) ─────────────────
    if includeAllgemein then
        table.insert(groups, {
            id    = "ALLGEMEIN",
            label = L("cat_ALLGEMEIN") or "Allgemein",
            games = { { id = "ALLGEMEIN", label = L("cat_ALLGEMEIN") or "Allgemein" } },
        })
    end

    -- ── Registrierte Kategorien in definierter Reihenfolge ─────
    local CR           = CategoryRegistry()
    local defs         = CR and CR.GetDefs and CR.GetDefs() or {}
    local registeredIds = {}

    for _, def in ipairs(defs) do
        registeredIds[def.id] = true
        local games = gameMap[def.id]
        if games and #games > 0 then
            table.insert(groups, {
                id    = def.id,
                label = ResolveCategoryLabel(def.id),
                games = games,
            })
        end
    end

    -- Sonstige: explizit SONSTIGE + Spiele mit unbekannter Kategorie-ID
    local misc = {}
    for catID, games in pairs(gameMap) do
        if catID == "SONSTIGE" or not registeredIds[catID] then
            for _, game in ipairs(games) do
                table.insert(misc, game)
            end
        end
    end
    if #misc > 0 then
        table.insert(groups, {
            id    = "SONSTIGE",
            label = L("cat_SONSTIGE") or "Sonstige",
            games = misc,
        })
    end

    -- Anzeige: Spiele pro Kategorie alphabetisch; Favoriten bleiben Nutzer-Reihenfolge.
    local GR = GameRegistry()
    if GR and GR.SortByLabel then
        for _, grp in ipairs(groups) do
            if not grp.isFavGrp then
                GR.SortByLabel(grp.games)
            end
        end
    end

    return groups
end

-- Export
ArcadiaNexus.UI.GetCategoryGroups = GetCategoryGroups
