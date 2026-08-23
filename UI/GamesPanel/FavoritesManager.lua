--[[
    ArcadiaNexus
    UI/GamesPanel/FavoritesManager.lua

    Favoriten-Manager Singleton.
    DB: ArcadiaNexusDB.favorites = { "TICTACTOE", "SNAKE", ... }

    Exportiert:
        ArcadiaNexus.UI.FavMgr  – Singleton mit IsFavorite/Add/Remove/Toggle/GetList
                                + RegisterRebuild/RebuildAll
]]

local ArcadiaNexus = _G.ArcadiaNexus

local FavMgr = {}

function FavMgr:IsFavorite(gameId)
    if not ArcadiaNexusDB or not ArcadiaNexusDB.favorites then return false end
    for _, id in ipairs(ArcadiaNexusDB.favorites) do
        if id == gameId then return true end
    end
    return false
end

function FavMgr:Add(gameId)
    if self:IsFavorite(gameId) then return end
    table.insert(ArcadiaNexusDB.favorites, gameId)
end

function FavMgr:Remove(gameId)
    if not ArcadiaNexusDB or not ArcadiaNexusDB.favorites then return end
    for i, id in ipairs(ArcadiaNexusDB.favorites) do
        if id == gameId then
            table.remove(ArcadiaNexusDB.favorites, i)
            return
        end
    end
end

function FavMgr:Toggle(gameId)
    if self:IsFavorite(gameId) then
        self:Remove(gameId)
    else
        self:Add(gameId)
    end
end

function FavMgr:GetList()
    return ArcadiaNexusDB and ArcadiaNexusDB.favorites or {}
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
