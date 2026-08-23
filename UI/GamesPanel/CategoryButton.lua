--[[
    NEXUS GAMING HUB
    UI/GamesPanel/CategoryButton.lua
    Widget-Konstruktion: Spiel-Row-Button mit activeBG, Accent, Label, Stern.

    Exportiert:
        ArcadiaNexus.UI.BuildGameButton(sc, game, namePrefix)
            → btn (Button-Frame)

    Abhängigkeiten:
        UI/GamesPanel/StarButton.lua  → ArcadiaNexus.UI.MakeStarButton
]]

local CAT_W = 180

local function MakeStarButton(p, id) return ArcadiaNexus.UI.MakeStarButton(p, id) end

function ArcadiaNexus.UI.BuildGameButton(sc, game, namePrefix)
    local btn, reused = ArcadiaNexus.UI.AcquireNamedFrame("Button", namePrefix .. game.id, sc)
    btn:SetSize(CAT_W - 38, 22)
    btn.catID = game.id
    if reused then
        if btn.lbl then btn.lbl:SetText(game.label) end
        return btn
    end

    local catBG = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    catBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Background")
    catBG:SetPoint("TOPLEFT",  btn, "TOPLEFT")
    catBG:SetPoint("TOPRIGHT", btn, "TOPRIGHT")
    catBG:SetHeight(28)
    catBG:SetTexCoord(0, 0.6640625, 0, 1)

    local activeBG = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    activeBG:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
    activeBG:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0,  0)
    activeBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, -5)
    activeBG:SetTexCoord(0, 0.6640625, 0, 1)
    activeBG:SetBlendMode("ADD")
    activeBG:SetAlpha(0)
    btn.activeBG = activeBG

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT", nil, 0)
    hlTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Category-Highlight")
    hlTex:SetPoint("TOPLEFT",     btn, "TOPLEFT",     0,  0)
    hlTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, -5)
    hlTex:SetTexCoord(0, 0.6640625, 0, 1)
    hlTex:SetBlendMode("ADD")

    local accent = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    accent:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, -1)
    accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0,  1)
    accent:SetWidth(3)
    accent:SetVertexColor(1.00, 0.82, 0.00, 0)
    btn.accent = accent

    local lbl = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("LEFT",  btn, "LEFT",  10, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
    lbl:SetText(game.label)
    lbl:SetWordWrap(false)
    lbl:SetJustifyH("LEFT")
    btn.lbl = lbl

    local star = MakeStarButton(btn, game.id)
    btn._star = star

    -- Rechtsklick auf den gesamten Button öffnet Favoriten-Kontextmenü
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:HookScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            ArcadiaNexus.UI.OpenFavContextMenu(self, game.id)
        end
    end)

    return btn
end
