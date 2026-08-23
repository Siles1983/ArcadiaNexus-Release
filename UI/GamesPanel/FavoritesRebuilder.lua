--[[
    NEXUS GAMING HUB
    UI/GamesPanel/FavoritesRebuilder.lua
    Favoriten-Rebuild-Logik: Erzeugt Favoriten-Buttons nach FavMgr-Änderungen neu.

    Exportiert:
        ArcadiaNexus.UI.RebuildFavButtons(sc, namePrefix, btnsKey, refreshConditionFn, clickFn, btnListRef)

    Abhängigkeiten:
        UI/GamesPanel/FavoritesManager.lua  → ArcadiaNexus.UI.FavMgr
        UI/GamesPanel/CategoryButton.lua    → ArcadiaNexus.UI.BuildGameButton
]]

local function FavMgr()         return ArcadiaNexus.UI.FavMgr end
local function BuildGameButton(sc, game, prefix) return ArcadiaNexus.UI.BuildGameButton(sc, game, prefix) end

function ArcadiaNexus.UI.RebuildFavButtons(sc, namePrefix, btnsKey, refreshConditionFn, clickFn, btnListRef)
    local FM = FavMgr()
    local GR = ArcadiaNexus.GameRegistry
    local favIds = FM and FM:GetList() or {}
    for _, id in ipairs(favIds) do
        local info = GR and GR.GetById(id)
        if GR and info and GR.IsVisible(info, GR.FILTER_SIDEBAR) then
            local label = GR.GetLabel(id)
            local btn = BuildGameButton(sc, { id = id, label = label }, namePrefix)
            local function Refresh()
                local active = refreshConditionFn(btn.catID)
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
            btn:SetScript("OnClick", function(self) clickFn(self.catID) end)
            table.insert(btnListRef, btn)
            table.insert(btnsKey, btn)
        end
    end
end
