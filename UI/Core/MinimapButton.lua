--[[
    NEXUS GAMING HUB
    Modul: MinimapButton
    Verantwortlich für: Minimap-Button Erstellung

    Abhängigkeiten:
        UI/MainFrame.lua  (F()-Accessor)
        Wird nach PLAYER_ENTERING_WORLD via ArcadiaNexus.UI.CreateMinimapButton() aufgerufen
]]

-- F-Accessor (identisch zu MainFrame.lua)
local function F() return ArcadiaNexus.UI.GetF() end

-- ============================================================
-- Minimap Button
-- ============================================================

local function CreateMinimapButton()

    if _G.ArcadiaNexusMinimapButton then return end

    local btn = CreateFrame("Button", "ArcadiaNexusMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 8)

    -- Icon
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Dice_01")
    icon:SetAllPoints(btn)
    btn.icon = icon

    -- Highlight
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)

    -- Circular Mask (damit er rund aussieht)
    local mask = btn:CreateMaskTexture()
    mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(btn)
    icon:AddMaskTexture(mask)

    -- Position (oben rechts am Minimap Rand)
    btn:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -5, -5)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            -- Hub öffnen + Settings-Tab aktivieren
            if F().main then F().main:Show() end
            NexusTabs.SetActive("SETTINGS")
        else
            if F().main and F().main:IsShown() then
                F().main:Hide()
            else
                F().main:Show()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ArcadiaNexus", 1, 0.82, 0)
        GameTooltip:AddLine("Linksklick: Öffnen / Schließen", 0.85, 0.78, 0.60)
        GameTooltip:AddLine("Rechtsklick: Einstellungen", 0.85, 0.78, 0.60)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Export für Init()-Aufruf in MainFrame.lua
ArcadiaNexus.UI.CreateMinimapButton = CreateMinimapButton
