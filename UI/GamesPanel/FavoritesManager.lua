--[[
    ArcadiaNexus
    UI/GamesPanel/FavoritesManager.lua

    Favoriten-Manager Singleton.
    Persistenz: FavoritesStore.

    Exportiert:
        ArcadiaNexus.UI.FavMgr  – Singleton mit IsFavorite/Add/Remove/Toggle/GetList
                                + RegisterRebuild/RebuildAll
]]

local ArcadiaNexus = _G.ArcadiaNexus

local FavMgr = {}

function FavMgr:IsFavorite(gameId)
    return ArcadiaNexus.FavoritesStore.IsFavorite(gameId)
end

function FavMgr:Add(gameId)
    ArcadiaNexus.FavoritesStore.Add(gameId)
end

function FavMgr:Remove(gameId)
    ArcadiaNexus.FavoritesStore.Remove(gameId)
end

function FavMgr:Toggle(gameId)
    if self:IsFavorite(gameId) then
        self:Remove(gameId)
    else
        self:Add(gameId)
    end
end

function FavMgr:GetList()
    return ArcadiaNexus.FavoritesStore.GetList()
end

-- Rebuild-Callbacks: alle Panels nach Favoriten-Änderung aktualisieren
local _rebuildFavCallbacks = {}

function FavMgr:RegisterRebuild(fn)
    table.insert(_rebuildFavCallbacks, fn)
end

function FavMgr:RebuildAll()
    for _, fn in ipairs(_rebuildFavCallbacks) do
        pcall(fn)
    end
end

function FavMgr:ClearRebuildCallbacks()
    _rebuildFavCallbacks = {}
end

-- Export
ArcadiaNexus.UI.FavMgr = FavMgr
