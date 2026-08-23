--[[
    ArcadiaNexus
    UI/GamesPanel/StarButton.lua

    Stern-Button Factory.
    Erzeugt einen kleinen Stern-Button rechts auf einem Game-Button.
    Klick → Favorit togglen + alle Panels neu aufbauen.

    Exportiert:
        ArcadiaNexus.UI.MakeStarButton(parent, gameId) → star frame

    Abhängigkeiten:
        UI/GamesPanel/FavoritesManager.lua  (ArcadiaNexus.UI.FavMgr)
]]

local ArcadiaNexus = _G.ArcadiaNexus

local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

local function MakeStarButton(parent, gameId)
    local FM   = ArcadiaNexus.UI.FavMgr
    local star = CreateFrame("Button", nil, parent)
    star:SetSize(10, 10)
    star:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    star:SetFrameLevel(parent:GetFrameLevel() + 3)

    local starTex = star:CreateTexture(nil, "ARTWORK", nil, 2)
    -- Anker einmalig setzen; SetAtlas(name, false) darf SetSize nicht überschreiben
    starTex:SetAllPoints(star)
    star._tex = starTex

    local function RefreshStar()
        if FM:IsFavorite(gameId) then
            starTex:SetAtlas("auctionhouse-icon-favorite", false)
            starTex:SetVertexColor(1, 1, 1, 1)
        else
            starTex:SetAtlas("auctionhouse-icon-favorite", false)
            starTex:SetVertexColor(0.60, 0.60, 0.60, 0.75)
        end
    end
    star.RefreshStar = RefreshStar
    RefreshStar()

    star:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            FM:Toggle(gameId)
            FM:RebuildAll()
        elseif button == "RightButton" then
            OpenFavContextMenu(self, gameId)
        end
    end)
    star:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    star:SetScript("OnEnter", function(self)
        self:GetParent():LockHighlight()
        if not FM:IsFavorite(gameId) then
            starTex:SetVertexColor(1.00, 0.82, 0.00, 1.0)
        end
    end)

    star:SetScript("OnLeave", function(self)
        self:GetParent():UnlockHighlight()
        if not FM:IsFavorite(gameId) then
            starTex:SetVertexColor(0.60, 0.60, 0.60, 0.75)
        end
    end)

    return star
end

local function OpenFavContextMenu(anchor, gameId)
    local FM  = ArcadiaNexus.UI.FavMgr
    local isFav = FM:IsFavorite(gameId)
    MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
        if isFav then
            rootDescription:CreateTitle(L("ctx_fav_title_remove"))
            rootDescription:CreateButton(L("ctx_fav_remove"), function()
                FM:Remove(gameId)
                FM:RebuildAll()
            end)
        else
            rootDescription:CreateTitle(L("ctx_fav_title_add"))
            rootDescription:CreateButton(L("ctx_fav_add"), function()
                FM:Add(gameId)
                FM:RebuildAll()
            end)
        end
    end)
end

-- Export
ArcadiaNexus.UI.MakeStarButton       = MakeStarButton
ArcadiaNexus.UI.OpenFavContextMenu   = OpenFavContextMenu
