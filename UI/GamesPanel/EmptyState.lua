--[[
    NEXUS GAMING HUB
    UI/GamesPanel/EmptyState.lua
    UI-Hilfsmodul: Leerhinweis für leere Favoriten-Gruppe.

    Exportiert:
        ArcadiaNexus.UI.HandleFavEmptyHint(grp, sc, yOff, anyBtn, hintKey, hintFrameName)
            → neues yOff (number)

    Abhängigkeiten:
        UI/Language.lua  → ArcadiaNexus.GetLocaleTable (lazy)
        UI/Core/UIHelpers.lua → ArcadiaNexus.UI.AcquireNamedFrame
]]

local Layout = ArcadiaNexus.Layout
local CAT_W = Layout.sidebar.width

local _L = nil
local function L(key)
    if not _L then _L = ArcadiaNexus.GetLocaleTable("UI") end
    return _L[key]
end

function ArcadiaNexus.UI.HandleFavEmptyHint(grp, sc, yOff, anyBtn, hintKey, hintFrameName)
    if not grp.isFavGrp then
        return yOff
    end

    local hintFrame, reused = ArcadiaNexus.UI.AcquireNamedFrame("Frame", hintFrameName, sc)
    hintFrame:SetSize(CAT_W - 50, 20)

    if not reused then
        local lbl = hintFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER")
        lbl:SetWordWrap(true)
        hintFrame._lbl = lbl
    end

    if not anyBtn then
        if hintFrame._lbl then
            hintFrame._lbl:SetText(L("fav_empty") or "Keine Favoriten vorhanden.")
        end
        hintFrame:ClearAllPoints()
        hintFrame:SetPoint("TOP", sc, "TOP", 8, -yOff)
        hintFrame:Show()
        grp[hintKey] = hintFrame
        return yOff + 22
    end

    hintFrame:Hide()
    grp[hintKey] = hintFrame
    return yOff
end
